;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; json-mode: JSON editing support
;;;

(provide "json-mode")

(in-package "editor")

(require "re-kwd")

(export '(*json-mode-hook* *json-mode-map* json-mode))

(defvar *json-mode-hook* nil)
(defvar *json-mode-map* nil)

(unless *json-mode-map*
  (setq *json-mode-map* (make-sparse-keymap))
  (define-key *json-mode-map* #\RET 'json-newline-and-indent)
  (define-key *json-mode-map* #\} 'json-electric-close)
  (define-key *json-mode-map* #\] 'json-electric-close)
  (define-key *json-mode-map* #\TAB 'json-indent-line))

(defvar *json-indent-level* 2)

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *json-mode-syntax-table* nil)
(unless *json-mode-syntax-table*
  (setq *json-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (when c
        (set-syntax-punctuation *json-mode-syntax-table* c))))
  (set-syntax-string *json-mode-syntax-table* #\")
  (set-syntax-escape *json-mode-syntax-table* #\\)
  (set-syntax-match *json-mode-syntax-table* #\{ #\})
  (set-syntax-match *json-mode-syntax-table* #\[ #\])
  (set-syntax-symbol *json-mode-syntax-table* #\_)
  (set-syntax-word *json-mode-syntax-table* #\-)
  (set-syntax-word *json-mode-syntax-table* #\.)
  (set-syntax-word *json-mode-syntax-table* #\+)
  (do ((x #x30 (1+ x)))
      ((> x #x39))
    (set-syntax-word *json-mode-syntax-table* (code-char x)))
  (set-syntax-word *json-mode-syntax-table* #\e)
  (set-syntax-word *json-mode-syntax-table* #\E)
  (set-syntax-whitespace *json-mode-syntax-table* #\SPC)
  (set-syntax-whitespace *json-mode-syntax-table* #\TAB)
  (set-syntax-whitespace *json-mode-syntax-table* #\RET))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *json-regexp-keyword-list* nil)

(defun json-setup-keywords ()
  (unless *json-regexp-keyword-list*
    (setq *json-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Keys (quoted strings before colon)
             ("\"\\([^\"\\\\]\\|\\\\[^\n]\\)*\"[ \t\n]*:" nil 0)
             ;; String values
             ("\"\\([^\"\\\\]\\|\\\\[^\n]\\)*\"" nil :string)
             ;; Keywords: true, false, null
             ("\\btrue\\b\\|\\bfalse\\b" nil 2)
             ("\\bnull\\b" nil :comment)
             ))))
  *json-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun json-count-braces (limit)
  "Count net open braces/brackets from LIMIT to current point."
  (let ((count 0)
        (in-string nil))
    (save-excursion
      (goto-char limit)
      (while (< (point) (save-excursion (goto-eol) (point)))
        (let ((c (following-char)))
          (cond
           (in-string
            (if (char= c #\")
                (setq in-string nil)
              (when (char= c #\\)
                (forward-char 1))))
           ((char= c #\") (setq in-string t))
           ((or (char= c #\{) (char= c #\[)) (incf count))
           ((or (char= c #\}) (char= c #\])) (decf count))))
        (forward-char 1)))
    count))

(defun json-calc-indent ()
  "Calculate the indentation for the current line."
  (let ((indent 0)
        (cur-close nil))
    (save-excursion
      (goto-bol)
      (skip-chars-forward " \t")
      (let ((c (following-char)))
        (when (or (char= c #\}) (char= c #\]))
          (setq cur-close t))))
    (save-excursion
      (goto-bol)
      (when (> (point) 0)
        (forward-line -1)
        (goto-bol)
        (let ((prev-indent (progn (skip-chars-forward " \t")
                                  (current-column)))
              (net (json-count-braces (point))))
          (setq indent (+ prev-indent (* net *json-indent-level*))))))
    (when cur-close
      (setq indent (- indent *json-indent-level*)))
    (max indent 0)))

(defun json-indent-line ()
  (interactive)
  (let ((target (json-calc-indent))
        (col (current-column)))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun json-newline-and-indent ()
  (interactive)
  (insert "\n")
  (json-indent-line))

(defun json-electric-close (&optional (arg 1))
  (interactive "*p")
  (self-insert-command arg)
  (json-indent-line))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun json-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "JSON")
  (setq buffer-mode 'json-mode)
  (use-keymap *json-mode-map*)
  (use-syntax-table *json-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (json-setup-keywords))
  (make-local-variable '*json-indent-level*)
  (run-hooks '*json-mode-hook*))
