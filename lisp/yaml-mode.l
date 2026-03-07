;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; yaml-mode: YAML editing support
;;;

(provide "yaml-mode")

(in-package "editor")

(require "re-kwd")

(export '(*yaml-mode-hook* *yaml-mode-map* yaml-mode *yaml-indent-level*))

(defvar *yaml-mode-hook* nil)
(defvar *yaml-mode-map* nil)
(defvar *yaml-indent-level* 2)

(unless *yaml-mode-map*
  (setq *yaml-mode-map* (make-sparse-keymap))
  (define-key *yaml-mode-map* #\RET 'yaml-newline-and-indent)
  (define-key *yaml-mode-map* #\TAB 'yaml-indent-line)
  (define-key *yaml-mode-map* '(#\C-c #\C-n) 'yaml-next-section)
  (define-key *yaml-mode-map* '(#\C-c #\C-p) 'yaml-previous-section))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *yaml-mode-syntax-table* nil)
(unless *yaml-mode-syntax-table*
  (setq *yaml-mode-syntax-table* (make-syntax-table))
  (set-syntax-string *yaml-mode-syntax-table* #\")
  (set-syntax-string *yaml-mode-syntax-table* #\')
  (set-syntax-escape *yaml-mode-syntax-table* #\\)
  (set-syntax-start-comment *yaml-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *yaml-mode-syntax-table* #\LFD nil t)
  (set-syntax-symbol *yaml-mode-syntax-table* #\_)
  (set-syntax-symbol *yaml-mode-syntax-table* #\-)
  (set-syntax-match *yaml-mode-syntax-table* #\[ #\])
  (set-syntax-match *yaml-mode-syntax-table* #\{ #\}))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *yaml-regexp-keyword-list* nil)

(defun yaml-setup-keywords ()
  (unless *yaml-regexp-keyword-list*
    (setq *yaml-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Keys
             ("^[ \t]*\\([A-Za-z0-9_][A-Za-z0-9_ .-]*\\):" nil 0)
             ;; Document markers
             ("^---$\\|^\\.\\.\\.$" nil (:keyword 2 :bold))
             ;; Anchors and aliases
             ("\\(&\\|\\*\\)[A-Za-z0-9_.-]+" nil :tag)
             ;; Tags
             ("!![A-Za-z]+" nil :tag)
             ;; Boolean and null
             ("\\btrue\\b\\|\\bfalse\\b\\|\\byes\\b\\|\\bno\\b\\|\\bon\\b\\|\\boff\\b" nil 2)
             ("\\bnull\\b\\|~" nil :comment)
             ))))
  *yaml-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun yaml-previous-line-indent ()
  "Get the indentation of the previous non-blank line."
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*$")))
      (forward-line -1))
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun yaml-previous-line-opens-block-p ()
  "Check if the previous non-blank line ends with a block opener."
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*$")))
      (forward-line -1))
    (goto-eol)
    (skip-chars-backward " \t")
    (and (> (point) (progn (goto-bol) (point)))
         (progn (goto-eol)
                (skip-chars-backward " \t")
                (let ((c (preceding-char)))
                  (or (char= c #\:)
                      (char= c #\-)
                      (char= c #\|)
                      (char= c #\>)))))))

(defun yaml-calc-indent ()
  "Calculate indentation for the current line."
  (if (= (save-excursion (goto-bol) (point)) 0)
      0
    (let ((prev-indent (yaml-previous-line-indent)))
      (if (yaml-previous-line-opens-block-p)
          (+ prev-indent *yaml-indent-level*)
        prev-indent))))

(defun yaml-indent-line ()
  (interactive)
  (let* ((target (yaml-calc-indent))
         (col (current-column))
         (cur-indent (save-excursion (goto-bol) (skip-chars-forward " \t") (current-column))))
    ;; Cycle through indent levels: calculated, +1 level, 0, ...
    (when (= cur-indent target)
      (setq target (+ target *yaml-indent-level*)))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun yaml-newline-and-indent ()
  (interactive)
  (let ((indent (yaml-calc-indent)))
    ;; Check if current line opens a block
    (save-excursion
      (goto-eol)
      (skip-chars-backward " \t")
      (let ((c (preceding-char)))
        (when (or (char= c #\:) (char= c #\|) (char= c #\>))
          (setq indent (+ indent *yaml-indent-level*)))))
    ;; Check for list continuation
    (save-excursion
      (goto-bol)
      (when (looking-at "^\\([ \t]*\\)- ")
        (setq indent (+ (length (match-string 1)) 2))))
    (insert "\n")
    (insert (make-sequence 'string indent :initial-element #\SPC))))

;;; ============================================================
;;; Navigation
;;; ============================================================

(defun yaml-next-section ()
  (interactive)
  (forward-line 1)
  (unless (scan-buffer "^[A-Za-z]" :regexp t :tail nil)
    (message "No more top-level sections")))

(defun yaml-previous-section ()
  (interactive)
  (goto-bol)
  (unless (scan-buffer "^[A-Za-z]" :regexp t :reverse t :tail nil)
    (message "No more top-level sections")))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun yaml-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "YAML")
  (setq buffer-mode 'yaml-mode)
  (use-keymap *yaml-mode-map*)
  (use-syntax-table *yaml-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (yaml-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable '*yaml-indent-level*)
  (run-hooks '*yaml-mode-hook*))
