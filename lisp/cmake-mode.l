;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; cmake-mode: CMake editing support
;;;

(provide "cmake-mode")

(in-package "editor")

(require "re-kwd")

(export '(*cmake-mode-hook* *cmake-mode-map* cmake-mode *cmake-indent-level*))

(defvar *cmake-mode-hook* nil)
(defvar *cmake-mode-map* nil)
(defvar *cmake-indent-level* 2)

(unless *cmake-mode-map*
  (setq *cmake-mode-map* (make-sparse-keymap))
  (define-key *cmake-mode-map* #\RET 'cmake-newline-and-indent)
  (define-key *cmake-mode-map* #\TAB 'cmake-indent-line))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *cmake-mode-syntax-table* nil)
(unless *cmake-mode-syntax-table*
  (setq *cmake-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
        (set-syntax-punctuation *cmake-mode-syntax-table* c))))
  (set-syntax-string *cmake-mode-syntax-table* #\")
  (set-syntax-escape *cmake-mode-syntax-table* #\\)
  (set-syntax-match *cmake-mode-syntax-table* #\( #\))
  (set-syntax-symbol *cmake-mode-syntax-table* #\_)
  (set-syntax-symbol *cmake-mode-syntax-table* #\-)
  (set-syntax-start-comment *cmake-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *cmake-mode-syntax-table* #\LFD nil t)
  (set-syntax-whitespace *cmake-mode-syntax-table* #\SPC)
  (set-syntax-whitespace *cmake-mode-syntax-table* #\TAB)
  (set-syntax-whitespace *cmake-mode-syntax-table* #\RET))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *cmake-regexp-keyword-list* nil)

(defun cmake-setup-keywords ()
  (unless *cmake-regexp-keyword-list*
    (setq *cmake-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Commands (common)
             ("\\b\\(project\\|cmake_minimum_required\\|add_executable\\|add_library\\|add_subdirectory\\|target_link_libraries\\|target_include_directories\\|target_compile_definitions\\|target_compile_options\\|target_sources\\|find_package\\|find_library\\|find_path\\|find_program\\|include\\|include_directories\\|link_directories\\|install\\|set\\|unset\\|option\\|message\\|string\\|list\\|file\\|get_filename_component\\|configure_file\\|execute_process\\|add_custom_command\\|add_custom_target\\|set_target_properties\\|get_target_property\\|add_dependencies\\|enable_testing\\|add_test\\)(" nil 0)
             ;; Control flow
             ("\\b\\(if\\|elseif\\|else\\|endif\\|foreach\\|endforeach\\|while\\|endwhile\\|function\\|endfunction\\|macro\\|endmacro\\|return\\|break\\|continue\\)\\b" nil 0)
             ;; Variable references
             ("\\${[^}\n]*}" nil 2)
             ;; Generator expressions
             ("\\$<[^>\n]*>" nil :tag)
             ;; Boolean/constants
             ("\\b\\(TRUE\\|FALSE\\|ON\\|OFF\\|YES\\|NO\\|AND\\|OR\\|NOT\\|STREQUAL\\|MATCHES\\|VERSION_LESS\\|VERSION_GREATER\\|DEFINED\\|COMMAND\\|TARGET\\|EXISTS\\|IS_DIRECTORY\\)\\b" nil 2)
             ))))
  *cmake-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun cmake-previous-nonblank-indent ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun cmake-opens-block-p ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-bol)
    (looking-at "^[ \t]*\\(if\\|elseif\\|else\\|foreach\\|while\\|function\\|macro\\)[ \t]*(\\|^[ \t]*\\(if\\|elseif\\|else\\|foreach\\|while\\|function\\|macro\\)$")))

(defun cmake-closes-block-p ()
  (save-excursion
    (goto-bol)
    (looking-at "^[ \t]*\\(endif\\|endforeach\\|endwhile\\|endfunction\\|endmacro\\|else\\|elseif\\)[ \t]*(\\|^[ \t]*\\(endif\\|endforeach\\|endwhile\\|endfunction\\|endmacro\\|else\\|elseif\\)$")))

(defun cmake-calc-indent ()
  (if (= (save-excursion (goto-bol) (point)) 0)
      0
    (let ((prev-indent (cmake-previous-nonblank-indent))
          (delta 0))
      (when (cmake-opens-block-p)
        (incf delta *cmake-indent-level*))
      (when (cmake-closes-block-p)
        (decf delta *cmake-indent-level*))
      (max 0 (+ prev-indent delta)))))

(defun cmake-indent-line ()
  (interactive)
  (let* ((target (cmake-calc-indent))
         (col (current-column)))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun cmake-newline-and-indent ()
  (interactive)
  (insert "\n")
  (cmake-indent-line))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun cmake-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "CMake")
  (setq buffer-mode 'cmake-mode)
  (use-keymap *cmake-mode-map*)
  (use-syntax-table *cmake-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (cmake-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable '*cmake-indent-level*)
  (run-hooks '*cmake-mode-hook*))


(ignore-errors (ts-register-mode 'cmake-mode))
(add-hook '*cmake-mode-hook* 'ts-enable-for-buffer)
