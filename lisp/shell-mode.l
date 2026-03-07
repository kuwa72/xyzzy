;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; shell-script-mode: Shell script editing support
;;;

(provide "shell-mode")

(in-package "editor")

(require "re-kwd")

(export '(*shell-script-mode-hook* *shell-script-mode-map*
          shell-script-mode *shell-script-keyword-file*
          *shell-script-indent-level*))

(defvar *shell-script-mode-hook* nil)
(defvar *shell-script-mode-map* nil)
(defvar *shell-script-keyword-file* "ShellScript")
(defvar *shell-script-keyword-hash-table* nil)
(defvar *shell-script-indent-level* 2)

(unless *shell-script-mode-map*
  (setq *shell-script-mode-map* (make-sparse-keymap))
  (define-key *shell-script-mode-map* #\RET 'shell-script-newline-and-indent)
  (define-key *shell-script-mode-map* #\TAB 'shell-script-indent-line))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *shell-script-mode-syntax-table* nil)
(unless *shell-script-mode-syntax-table*
  (setq *shell-script-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (when c
        (set-syntax-punctuation *shell-script-mode-syntax-table* c))))
  ;; Restore word syntax for letters and digits
  (do ((x #x41 (1+ x))) ((> x #x5a))
    (set-syntax-word *shell-script-mode-syntax-table* (code-char x)))
  (do ((x #x61 (1+ x))) ((> x #x7a))
    (set-syntax-word *shell-script-mode-syntax-table* (code-char x)))
  (do ((x #x30 (1+ x))) ((> x #x39))
    (set-syntax-word *shell-script-mode-syntax-table* (code-char x)))
  (set-syntax-string *shell-script-mode-syntax-table* #\")
  (set-syntax-string *shell-script-mode-syntax-table* #\')
  (set-syntax-escape *shell-script-mode-syntax-table* #\\)
  (set-syntax-match *shell-script-mode-syntax-table* #\( #\))
  (set-syntax-match *shell-script-mode-syntax-table* #\{ #\})
  (set-syntax-match *shell-script-mode-syntax-table* #\[ #\])
  (set-syntax-symbol *shell-script-mode-syntax-table* #\_)
  (set-syntax-start-comment *shell-script-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *shell-script-mode-syntax-table* #\LFD nil t)
  (set-syntax-whitespace *shell-script-mode-syntax-table* #\SPC)
  (set-syntax-whitespace *shell-script-mode-syntax-table* #\TAB)
  (set-syntax-whitespace *shell-script-mode-syntax-table* #\RET))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *shell-script-regexp-keyword-list* nil)

(defun shell-script-setup-keywords ()
  (unless *shell-script-regexp-keyword-list*
    (setq *shell-script-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Shebang
             ("^#!.*$" nil :comment)
             ;; Variable assignment
             ("^[ \t]*[A-Za-z_][A-Za-z0-9_]*=" nil 0)
             ;; Variable expansion
             ("\\$[A-Za-z_][A-Za-z0-9_]*\\|\\${[^}\n]*}" nil 2)
             ;; Command substitution
             ("\\$([^)\n]*)" nil 2)
             ;; Backtick command substitution
             ("`[^`\n]*`" nil 2)
             ;; Redirections
             ("[0-9]*\\(>>\\|<<\\|[<>]\\)\\(&[0-9]*\\)?" nil :tag)
             ))))
  *shell-script-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun shell-script-previous-nonblank-line-indent ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun shell-script-opens-block-p ()
  "Check if the previous non-blank line opens a block."
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-bol)
    (or (looking-at "^[ \t]*\\(if\\|elif\\|else\\|for\\|while\\|until\\|do\\|then\\|case\\)\\b")
        (progn
          (goto-eol)
          (skip-chars-backward " \t")
          (let ((c (preceding-char)))
            (or (char= c #\{)
                (char= c #\|)))))))

(defun shell-script-closes-block-p ()
  "Check if the current line closes a block."
  (save-excursion
    (goto-bol)
    (looking-at "^[ \t]*\\(fi\\|done\\|esac\\|else\\|elif\\|then\\|}\\)\\b")))

(defun shell-script-calc-indent ()
  (if (= (save-excursion (goto-bol) (point)) 0)
      0
    (let ((prev-indent (shell-script-previous-nonblank-line-indent))
          (indent-delta 0))
      (when (shell-script-opens-block-p)
        (incf indent-delta *shell-script-indent-level*))
      (when (shell-script-closes-block-p)
        (decf indent-delta *shell-script-indent-level*))
      (max 0 (+ prev-indent indent-delta)))))

(defun shell-script-indent-line ()
  (interactive)
  (let* ((target (shell-script-calc-indent))
         (col (current-column)))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun shell-script-newline-and-indent ()
  (interactive)
  (insert "\n")
  (shell-script-indent-line))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun shell-script-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Shell")
  (setq buffer-mode 'shell-script-mode)
  (use-keymap *shell-script-mode-map*)
  (use-syntax-table *shell-script-mode-syntax-table*)
  (and *shell-script-keyword-file*
       (null *shell-script-keyword-hash-table*)
       (setq *shell-script-keyword-hash-table*
             (load-keyword-file *shell-script-keyword-file*)))
  (when *shell-script-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *shell-script-keyword-hash-table*))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (shell-script-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable '*shell-script-indent-level*)
  (run-hooks '*shell-script-mode-hook*))
