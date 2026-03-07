;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; xml-mode: XML editing support
;;;

(provide "xml-mode")

(in-package "editor")

(require "re-kwd")

(export '(*xml-mode-hook* *xml-mode-map* xml-mode *xml-indent-level*))

(defvar *xml-mode-hook* nil)
(defvar *xml-mode-map* nil)
(defvar *xml-indent-level* 2)

(unless *xml-mode-map*
  (setq *xml-mode-map* (make-sparse-keymap))
  (define-key *xml-mode-map* #\RET 'xml-newline-and-indent)
  (define-key *xml-mode-map* #\TAB 'xml-indent-line)
  (define-key *xml-mode-map* #\> 'xml-electric-close-tag))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *xml-mode-syntax-table* nil)
(unless *xml-mode-syntax-table*
  (setq *xml-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
        (set-syntax-punctuation *xml-mode-syntax-table* c))))
  (set-syntax-symbol-prefix *xml-mode-syntax-table* #\&)
  (set-syntax-symbol *xml-mode-syntax-table* #\-)
  (set-syntax-symbol *xml-mode-syntax-table* #\:)
  (set-syntax-symbol *xml-mode-syntax-table* #\_)
  (set-syntax-symbol *xml-mode-syntax-table* #\.)
  (set-syntax-string *xml-mode-syntax-table* #\")
  (set-syntax-string *xml-mode-syntax-table* #\')
  (set-syntax-tag *xml-mode-syntax-table* #\< #\>))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *xml-regexp-keyword-list* nil)

(defun xml-setup-keywords ()
  (unless *xml-regexp-keyword-list*
    (setq *xml-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; XML declaration
             ("^<\\?xml[^?]*\\?>" nil 0)
             ;; Processing instructions
             ("<\\?[A-Za-z_][^?]*\\?>" nil :tag)
             ;; CDATA
             ("<!\\[CDATA\\[" nil :comment)
             ("\\]\\]>" nil :comment)
             ;; Comments (single-line only)
             ("<!--.*-->" nil :comment)
             ;; Tag names (open)
             ("</?\\([A-Za-z_][A-Za-z0-9_:.-]*\\)" nil 0)
             ;; Attribute names
             ("[ \t]\\([A-Za-z_][A-Za-z0-9_:.-]*\\)=" nil :tag)
             ;; Entity references
             ("&[A-Za-z_][A-Za-z0-9_]*;" nil 2)
             ("&#[0-9]+;" nil 2)
             ("&#x[0-9A-Fa-f]+;" nil 2)
             ))))
  *xml-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun xml-previous-nonblank-indent ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*$")))
      (forward-line -1))
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun xml-previous-line-opens-tag-p ()
  "Check if the previous non-blank line has an unclosed open tag."
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*$")))
      (forward-line -1))
    (goto-bol)
    (let ((opens 0))
      (while (not (eolp))
        (let ((c (following-char)))
          (cond
           ((char= c #\<)
            (forward-char 1)
            (cond
             ((eolp))
             ;; Closing tag </
             ((char= (following-char) #\/)
              (decf opens))
             ;; Comment/CDATA/PI
             ((or (char= (following-char) #\!)
                  (char= (following-char) #\?)))
             ;; Opening tag
             (t (incf opens))))
           ;; Self-closing />
           ((and (char= c #\/)
                 (< (1+ (point)) (save-excursion (goto-eol) (point)))
                 (progn (forward-char 1) (char= (following-char) #\>)))
            (decf opens)
            (forward-char 1))
           (t (forward-char 1)))))
      (> opens 0))))

(defun xml-current-line-closes-p ()
  (save-excursion
    (goto-bol)
    (skip-chars-forward " \t")
    (looking-at "</")))

(defun xml-calc-indent ()
  (if (= (save-excursion (goto-bol) (point)) 0)
      0
    (let ((prev-indent (xml-previous-nonblank-indent))
          (delta 0))
      (when (xml-previous-line-opens-tag-p)
        (incf delta *xml-indent-level*))
      (when (xml-current-line-closes-p)
        (decf delta *xml-indent-level*))
      (max 0 (+ prev-indent delta)))))

(defun xml-indent-line ()
  (interactive)
  (let* ((target (xml-calc-indent))
         (col (current-column)))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun xml-newline-and-indent ()
  (interactive)
  (insert "\n")
  (xml-indent-line))

(defun xml-electric-close-tag (&optional (arg 1))
  (interactive "*p")
  (self-insert-command arg)
  (xml-indent-line))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun xml-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "XML")
  (setq buffer-mode 'xml-mode)
  (use-keymap *xml-mode-map*)
  (use-syntax-table *xml-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (xml-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "<!-- ")
  (make-local-variable 'comment-end)
  (setq comment-end " -->")
  (make-local-variable '*xml-indent-level*)
  (run-hooks '*xml-mode-hook*))
