;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

;;; Author: 服部さん(gyo@he.mirai.ne.jp)

;;; ・Cスタイルのコメントは無視することにした。
;;; ・正規表現は一切認識しない。正規表現で "'# 等を使用する場合は
;;;   エスケープするなりして逃げてちょーだい。

(provide "perl")

(in-package "editor")

(export '(perl-mode *perl-keyword-file* *perl-mode-hook*
	  *perl-mode-syntax-table* *perl-mode-map*
	  *perl-mode-abbrev-table* *perl-comment-column*))

(defvar *perl-mode-hook* nil)
(defvar *perl-comment-column* nil)

(defvar *perl-keyword-hash-table* nil)
(defvar *perl-keyword-file* "Perl")

(defvar *perl-mode-syntax-table* nil)
(unless *perl-mode-syntax-table*
  (setq *perl-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
	(set-syntax-punctuation *perl-mode-syntax-table* c))))
  (set-syntax-string *perl-mode-syntax-table* #\")
  (set-syntax-string *perl-mode-syntax-table* #\')
  ;(set-syntax-string *perl-mode-syntax-table* #\`)
  (set-syntax-escape *perl-mode-syntax-table* #\\)
  (set-syntax-symbol *perl-mode-syntax-table* #\_)
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\$)
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\@)
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\%)
  (set-syntax-match *perl-mode-syntax-table* #\( #\))
  (set-syntax-match *perl-mode-syntax-table* #\{ #\})
  (set-syntax-match *perl-mode-syntax-table* #\[ #\])
  ;(set-syntax-start-multi-comment *perl-mode-syntax-table* "/*")
  ;(set-syntax-end-multi-comment *perl-mode-syntax-table* "*/")
  (set-syntax-start-comment *perl-mode-syntax-table* #\#)
  (set-syntax-end-comment *perl-mode-syntax-table* #\LFD nil t))

(defvar *perl-mode-map* nil)
(unless *perl-mode-map*
  (setq *perl-mode-map* (make-sparse-keymap))
  (define-key *perl-mode-map* #\{ 'c-electric-insert)
  (define-key *perl-mode-map* #\: 'c-electric-insert)
  (define-key *perl-mode-map* #\} 'c-electric-close)
  (define-key *perl-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *perl-mode-map* #\TAB 'c-indent-line)
  (define-key *perl-mode-map* #\C-M-q 'indent-sexp)
  (define-key *perl-mode-map* #\RET 'c-newline-and-indent))

(defvar *perl-mode-abbrev-table* nil)
(unless *perl-mode-abbrev-table*
  (define-abbrev-table '*perl-mode-abbrev-table*))

(defun perl-comment-start-skip ()
  (let ((eol (save-excursion (goto-eol) (point))))
    (while (scan-buffer "\\(^\\|[ \t]\\);?\\(#+\\)[ \t]*"
			:regexp t :limit eol :tail t)
      (unless (eq (parse-point-syntax (match-end 2)) :string)
	(goto-char (match-beginning 2))
	(return-from perl-comment-start-skip (match-end 0)))))
  (goto-eol)
  nil)

(defun perl-comment-indent ()
  (generic-comment-indent "#" #'calc-c-indent))

(defun tags-find-perl-point (class name functionp point)
  (goto-char (- point *jump-tag-limit*))
  (and (scan-buffer (concat "^[ \t]*sub[ \t]+"
			    (regexp-quote name)
			    "\\($\\|[ \t\r\n\f#]\\)")
		    :regexp t :limit (+ point *jump-tag-limit*))
       (point)))

(defun perl-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Perl")
  (setq buffer-mode 'perl-mode)
  (use-syntax-table *perl-mode-syntax-table*)
  (use-keymap *perl-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode *c-indent-tabs-mode*)
  (make-local-variable 'tags-find-target)
  (setq tags-find-target #'tags-find-target-simple)
  (make-local-variable 'tags-find-point)
  (setq tags-find-point #'tags-find-perl-point)
  (and *perl-keyword-file*
       (null *perl-keyword-hash-table*)
       (setq *perl-keyword-hash-table*
	     (load-keyword-file *perl-keyword-file*)))
  (when *perl-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *perl-keyword-hash-table*))
  (setq *local-abbrev-table* *perl-mode-abbrev-table*)
  (setq comment-start "# ")
  (setq comment-end "")
  (setq comment-start-skip-function 'perl-comment-start-skip)
  (setq comment-indent-function 'perl-comment-indent)
  (when *perl-comment-column*
    (setq comment-column *perl-comment-column*))
  (run-hooks '*perl-mode-hook*))

(pushnew '(perl-maketags "*.pl" "*.pm" "*.cgi") *maketags-list* :key #'car)

(defun perl-maketags (file count)
  (goto-char (point-min))
  (while (scan-buffer "^[ \t]*sub[ \t]+" :regexp t :tail t)
    (do-events)
    (let ((opoint (point)))
      (skip-chars-forward "A-Za-z0-9_")
      (unless (= opoint (point))
	(format t "~A~A~D" (buffer-substring opoint (point)) file opoint)
	(incf count))))
  count)

;;; --- tree-sitter: Perl ---------------------------------------------------

(defvar *ts-perl-color-alist*
  '(("comment"      . 15)   ; gray
    ("string"       .  9)   ; dark red
    ("number"       . 13)   ; purple
    ("variable"     . 14)   ; dark teal
    ("function.def" . 10))) ; dark green

(defun ts-perl-block-owner (ancestors)
  "Return the ancestor controlling the innermost Perl block."
  (do ((rest ancestors (cdr rest)))
      ((null rest) nil)
    (when (string= (first (car rest)) "block")
      (return (cadr rest)))))

(defun ts-perl-calc-indent ()
  "Calculate Perl indent column using tree-sitter.  Returns column or nil."
  (save-excursion
    (goto-bol)
    (skip-chars-forward " \t")
    (let* ((g         *ts-buffer-grammar*)
           (ancestors (and g (si:ts-node-ancestors g (selected-buffer) (point)))))
      (when (null ancestors)
        (return-from ts-perl-calc-indent nil))
      (let* ((block    (ts-c-find-ancestor ancestors "block"))
             (owner    (ts-perl-block-owner ancestors))
             (base-cp  (second (or owner block))))
        (cond
          ((looking-for "}")
           (if base-cp (ts-c-indent-of-cp base-cp) 0))
          (block
           (+ (ts-c-indent-of-cp base-cp) c-indent-level))
          (t 0))))))

(defun ts-perl-indent-line ()
  "TAB handler for Perl: tree-sitter indent with fallback to calc-c-indent."
  (interactive "*")
  (if (or (not (interactive-p))
          (save-excursion
            (skip-chars-backward " \t")
            (bolp)))
      (let ((column (or (ts-perl-calc-indent) (calc-c-indent))))
        (when (integerp column)
          (smart-indentation column)))
    (insert "\t"))
  t)

(defun ts-perl-mode-enable ()
  (setq *ts-calc-indent-function* #'ts-perl-calc-indent)
  (ts-enable-for-buffer))

(ignore-errors (ts-register-mode 'perl-mode :colors *ts-perl-color-alist*))
(define-key *perl-mode-map* #\TAB           'ts-perl-indent-line)
(define-key *perl-mode-map* '(#\C-c #\C-t)  'ts-show-ancestors)
(define-key *perl-mode-map* '(#\C-c #\C-i)  'ts-test-indent)
(add-hook '*perl-mode-hook* 'ts-perl-mode-enable)
