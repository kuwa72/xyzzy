;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; javascript-mode: JavaScript/TypeScript editing support
;;;

(provide "javascript-mode")

(in-package "editor")

(require "cc-mode")
(require "re-kwd")

(export '(*javascript-mode-hook* *javascript-mode-map* javascript-mode
          *javascript-keyword-file* *javascript-indent-tabs-mode*
          javascript-indent-level javascript-continued-statement-offset
          *typescript-mode-hook* typescript-mode *typescript-keyword-file*))

(defvar *javascript-mode-hook* nil)
(defvar *javascript-keyword-file* "JavaScript")
(defvar *javascript-keyword-hash-table* nil)
(defvar *javascript-indent-tabs-mode* nil)

(unless (boundp 'javascript-indent-level)
  (setq javascript-indent-level 2)
  (setq javascript-continued-statement-offset 2))

;;; ============================================================
;;; Syntax table (C++ style: // and /* */ comments)
;;; ============================================================

(defvar *javascript-mode-syntax-table* nil)
(unless *javascript-mode-syntax-table*
  (setq *javascript-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
        (set-syntax-punctuation *javascript-mode-syntax-table* c))))
  (set-syntax-string *javascript-mode-syntax-table* #\")
  (set-syntax-string *javascript-mode-syntax-table* #\')
  (set-syntax-escape *javascript-mode-syntax-table* #\\)
  (set-syntax-symbol *javascript-mode-syntax-table* #\_)
  (set-syntax-symbol *javascript-mode-syntax-table* #\$)
  (set-syntax-match *javascript-mode-syntax-table* #\( #\))
  (set-syntax-match *javascript-mode-syntax-table* #\{ #\})
  (set-syntax-match *javascript-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment *javascript-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *javascript-mode-syntax-table* "*/")
  (set-syntax-start-c++-comment *javascript-mode-syntax-table* #\/)
  (set-syntax-end-c++-comment *javascript-mode-syntax-table* #\LFD))

;;; ============================================================
;;; Keymap
;;; ============================================================

(defvar *javascript-mode-map* nil)
(unless *javascript-mode-map*
  (setq *javascript-mode-map* (make-sparse-keymap))
  (define-key *javascript-mode-map* #\{ 'c-electric-insert)
  (define-key *javascript-mode-map* #\} 'c-electric-close)
  (define-key *javascript-mode-map* #\: 'c-electric-insert)
  (define-key *javascript-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *javascript-mode-map* #\TAB 'c-indent-line)
  (define-key *javascript-mode-map* #\C-M-q 'indent-sexp)
  (define-key *javascript-mode-map* #\RET 'c-newline-and-indent))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *javascript-regexp-keyword-list* nil)

(defun javascript-setup-keywords ()
  (unless *javascript-regexp-keyword-list*
    (setq *javascript-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Arrow functions
             ("=>" nil 0)
             ;; Template literal
             ("`[^`]*`" nil :string)
             ;; Regex literal (simple heuristic)
             ("[ \t=(:,]\\(/[^/\n*][^/\n]*/[gimsuy]*\\)" nil :string)
             ))))
  *javascript-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun javascript-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "JavaScript")
  (setq buffer-mode 'javascript-mode)
  (use-syntax-table *javascript-mode-syntax-table*)
  (use-keymap *javascript-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  (make-local-variable 'c-indent-level)
  (setq c-indent-level javascript-indent-level)
  (make-local-variable 'c-continued-statement-offset)
  (setq c-continued-statement-offset javascript-continued-statement-offset)
  (make-local-variable 'c-brace-offset)
  (setq c-brace-offset 0)
  (make-local-variable 'c-brace-imaginary-offset)
  (setq c-brace-imaginary-offset 0)
  (make-local-variable 'c-label-offset)
  (setq c-label-offset -2)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode *javascript-indent-tabs-mode*)
  (and *javascript-keyword-file*
       (null *javascript-keyword-hash-table*)
       (setq *javascript-keyword-hash-table*
             (load-keyword-file *javascript-keyword-file*)))
  (when *javascript-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *javascript-keyword-hash-table*))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (javascript-setup-keywords))
  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (run-hooks '*javascript-mode-hook*))

;;; ============================================================
;;; TypeScript
;;; ============================================================

(defvar *typescript-mode-hook* nil)
(defvar *typescript-keyword-file* "TypeScript")
(defvar *typescript-keyword-hash-table* nil)

(defun typescript-mode ()
  (interactive)
  (javascript-mode)
  (setq mode-name "TypeScript")
  (setq buffer-mode 'typescript-mode)
  (and *typescript-keyword-file*
       (null *typescript-keyword-hash-table*)
       (setq *typescript-keyword-hash-table*
             (load-keyword-file *typescript-keyword-file*)))
  (when *typescript-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *typescript-keyword-hash-table*))
  (run-hooks '*typescript-mode-hook*))
