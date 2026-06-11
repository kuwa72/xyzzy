;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "c-mode")

(in-package "editor")

(export '(*c-mode-hook* c-indent-level c-continued-statement-offset
	  c-argdecl-indent c-brace-offset c-brace-imaginary-offset
	  c-label-offset c-preprocessor-offset c-comment-indent))
(export '(c-mode c-indent-line c-newline-and-indent c-electric-insert
	  c-electric-close indent-cpp-directive
	  *c-keyword-file* *c-indent-tabs-mode*
	  *c-tab-always-indent* *c-comment-column*
	  *c-comment-c++-style*))

(defvar *c-mode-hook* nil)

(unless (boundp 'c-indent-level)
  (setq c-indent-level 2)
  (setq c-continued-statement-offset 2)
  (setq c-argdecl-indent 5)
  (setq c-brace-offset 0)
  (setq c-brace-imaginary-offset 0)
  (setq c-label-offset -2)
  (setq c-preprocessor-offset nil)
  (setq c-comment-indent 2))

(defvar *c-tab-always-indent* t)

(defvar *c-indent-tabs-mode* nil)
(defvar *c-comment-column* nil)
(defvar *c-comment-c++-style* nil)

(defvar *c-keyword-hash-table* nil)
(defvar *c-keyword-file* "C")

(defvar *c-mode-syntax-table* nil)
(unless *c-mode-syntax-table*
  (setq *c-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
	(set-syntax-punctuation *c-mode-syntax-table* c))))
  (set-syntax-option *c-mode-syntax-table*
		     *syntax-option-c-preprocessor*)
  (set-syntax-string *c-mode-syntax-table* #\")
  (set-syntax-string *c-mode-syntax-table* #\')
  (set-syntax-escape *c-mode-syntax-table* #\\)
  (set-syntax-symbol *c-mode-syntax-table* #\_)
  (set-syntax-symbol *c-mode-syntax-table* #\#)
  (set-syntax-match *c-mode-syntax-table* #\( #\))
  (set-syntax-match *c-mode-syntax-table* #\{ #\})
  (set-syntax-match *c-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment *c-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *c-mode-syntax-table* "*/")
  (set-syntax-start-c++-comment *c-mode-syntax-table* #\/)
  (set-syntax-end-c++-comment *c-mode-syntax-table* #\LFD))

(defvar *c-mode-map* nil)
(unless *c-mode-map*
  (setq *c-mode-map* (make-sparse-keymap))
  (define-key *c-mode-map* #\{ 'c-electric-insert)
  (define-key *c-mode-map* #\: 'c-electric-insert)
  (define-key *c-mode-map* #\# 'c-electric-insert)
  (define-key *c-mode-map* #\} 'c-electric-close)
  (define-key *c-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *c-mode-map* #\TAB 'c-indent-line)
  (define-key *c-mode-map* #\C-M-q 'indent-sexp)
  (define-key *c-mode-map* #\RET 'c-newline-and-indent))

(defvar *c-mode-abbrev-table* nil)
(unless *c-mode-abbrev-table*
  (define-abbrev-table '*c-mode-abbrev-table*))

(defun c-indent-line ()
  (interactive "*")
  (if (or (not (interactive-p))
	  *c-tab-always-indent*
	  (save-excursion
	    (skip-chars-backward " \t")
	    (bolp)))
      (case (save-excursion
	      (goto-bol)
	      (parse-point-syntax))
	(:string)
	(:comment
	 (let ((column (calc-c-comment-indent)))
	   (when (integerp column)
	     (smart-indentation column))))
	(t
	 (let ((column (calc-c-indent)))
	   (when (integerp column)
	     (smart-indentation column)))))
    (insert "\t"))
  t)

(defun c-newline-and-indent (&optional (arg 1))
  (interactive "*p")
  (delete-trailing-spaces)
  (insert #\LFD arg)
  (c-indent-line))

(defun c-electric-insert (&optional (arg 1))
  (interactive "*p")
  (unless (prog1
	      (parse-point-syntax)
	    (self-insert-command arg))
    (c-indent-line))
  t)

(defun c-electric-close (&optional (arg 1))
  (interactive "*p")
  (unless (prog1
	      (parse-point-syntax)
	    (self-insert-command arg))
    (c-indent-line))
  (save-excursion
    (forward-char -1)
    (and (goto-matched-parenthesis)
	 (show-matched-parenthesis)))
  t)

(defun cpp-indent-to (to)
  (skip-chars-forward " \t")
  (when (/= to (current-column))
    (delete-horizontal-spaces)
    (indent-to to)))

(defun indent-cpp-directive ()
  (interactive)
  (save-excursion
    (let ((nest 0))
      (goto-char (point-min))
      (while (scan-buffer "^[ \t]*#" :regexp t :tail t)
	(cond ((looking-at "[ \t]*if")
	       (cpp-indent-to (+ (current-column) nest))
	       (incf nest))
	      ((looking-at "[ \t]*el\\(se\\|if\\)")
	       (cpp-indent-to (+ (current-column) (1- nest))))
	      ((looking-at "[ \t]*endif")
	       (decf nest)
	       (when (minusp nest)
		 (error "Unmatched \"#endif\" at line ~d" (current-line-number)))
	       (cpp-indent-to (+ (current-column) nest)))
	      (t (cpp-indent-to (+ (current-column) nest))
		 (if (looking-for "define")
		     (while (and (progn
				   (goto-eol)
				   (forward-char -1)
				   (looking-for "\\"))
				 (forward-line 1))
		       (c-indent-line))))))
      (when (/= nest 0)
	(error "Unmatched \"#if\" or \"#ifdef\""))))
  t)

(defun c-comment-indent ()
  (save-excursion
    (let ((opoint (point)))
      (goto-bol)
      (cond ((looking-at "/\\*\\|//")
	     0)
	    (t
	     (skip-chars-forward " \t")
	     (cond ((looking-at "}[ \t]*\\($\\|/\\*\\|//\\)")
		    (+ (current-column) 2))
		   ((looking-at "#[ \t]*\\(endif\\|else\\)\\>")
		    (goto-char (match-end 1))
		    (+ (current-column) 2))
		   ((or (looking-at "/\\*\\|//")
			(eolp))
		    (calc-c-indent))
		   ((zerop comment-column)
		    0)
		   (t
		    (goto-char opoint)
		    (skip-chars-backward " \t")
		    (max (1+ (current-column)) comment-column))))))))

(defvar-local c-comment-indent-variable 'c-comment-indent)

(defun calc-c-comment-indent ()
  (save-excursion
    (goto-bol)
    (skip-chars-forward " \t")
    (let ((eolp (eolp)))
      (when (and (or eolp (looking-for "*"))
		 (scan-buffer "/*" :reverse t))
	(while (and (eq (parse-point-syntax) ':comment)
		    (scan-buffer "/*" :reverse t :no-dup t)))
	(+ (current-column)
	   (if eolp
	       (if (symbolp c-comment-indent-variable)
		   (symbol-value c-comment-indent-variable)
		 0)
	     1))))))

(autoload 'c-build-summary-of-functions "cfns" nil)
(autoload 'c-maketags "cfns")
(pushnew '(c-maketags "*.c" "*.cpp" "*.cxx" "*.cc" "*.h" "*.hpp" "*.hxx" "*.inl")
	 *maketags-list* :key #'car)

(defun c-tags-find-target ()
  (let* ((opoint (point))
	 (tail (progn
		 (skip-chars-forward "a-zA-Z0-9_")
		 (point)))
	 (name (buffer-substring tail
				 (progn
				   (skip-chars-backward "a-zA-Z0-9_")
				   (when (or (looking-back "::~")
					     (looking-back "->~")
					     (looking-back ".~"))
				     (forward-char -1))
				   (point))))
	 class)
    (cond ((looking-back "::")
	   (forward-char -2)
	   (let ((point (point)))
	     (when (looking-back ">")
	       (let ((depth 1))
		 (loop
		   (forward-char -1)
		   (skip-chars-backward "^<>")
		   (cond ((looking-back ">")
			  (incf depth))
			 ((looking-back "<")
			  (decf depth)
			  (when (zerop depth)
			    (forward-char -1)
			    (return)))
			 (t
			  (return)))))
	       (skip-chars-backward " \t\n\f")
	       (setq point (point)))
	     (setq class (buffer-substring point
					   (progn
					     (skip-chars-backward "a-zA-Z0-9_")
					     (point))))))
	  (t
	   (goto-char tail)
	   (when (looking-for "::")
	     (forward-char 2)
	     (setq class name)
	     (setq name (buffer-substring
			 (point)
			 (progn
			   (skip-chars-forward "a-zA-Z0-9_")
			   (point)))))))
    (goto-char opoint)
    (values class name '(function structure))))

(defun c-tags-find-point-1 (re start reverse structurep lgoal)
  (let* ((limit (if reverse
		    (- start *jump-tag-limit*)
		  (+ start *jump-tag-limit*)))
	 (goal (progn
		 (goto-char start)
		 (while (scan-buffer re :regexp t :limit limit :tail t :reverse reverse)
		   (let ((opoint (point))
			 (point0 (match-beginning 0))
			 (start (match-end 1)))
		     (unless structurep
		       (forward-char -1)
		       (forward-sexp 1 t))
		     (skip-white-forward)
		     (unless (looking-for ";")
		       (return start))
		     (goto-char (if reverse (1- point0) opoint)))))))
    (if lgoal
	(if goal
	    (if (< (abs (- lgoal start)) (abs (- goal start)))
		lgoal goal)
	  lgoal)
      goal)))

(defun c-tags-find-point (class name type point)
  (let* ((structurep (eq type 'structure))
	 (re (compile-regexp (if structurep
				 (concat "\\_<\\(?:struct\\|class\\|interface\\)[ \t\n\f]+\\("
					 name "\\)\\_>")
			       (concat "\\_<\\(" name "\\)[ \t\n\f]*("))))
	 goal)
    (setq goal (c-tags-find-point-1 re point t structurep nil))
    (setq goal (c-tags-find-point-1 re point nil structurep goal))
    goal))

(defun c-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "C")
  (setq buffer-mode 'c-mode)
  (use-syntax-table *c-mode-syntax-table*)
  (use-keymap *c-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode *c-indent-tabs-mode*)
  (make-local-variable 'tags-find-target)
  (setq tags-find-target #'c-tags-find-target)
  (make-local-variable 'tags-find-point)
  (setq tags-find-point #'c-tags-find-point)
  (make-local-variable 'build-summary-function)
  (setq build-summary-function 'c-build-summary-of-functions)
  (and *c-keyword-file*
       (null *c-keyword-hash-table*)
       (setq *c-keyword-hash-table*
	     (load-keyword-file *c-keyword-file*)))
  (when *c-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *c-keyword-hash-table*))
  (setq *local-abbrev-table* *c-mode-abbrev-table*)
  (if *c-comment-c++-style*
      (setq comment-start "// " comment-end "")
    (setq comment-start "/* " comment-end " */"))
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (setq comment-indent-function 'c-comment-indent)
  (when *c-comment-column*
    (setq comment-column *c-comment-column*))
  (run-hooks '*c-mode-hook*))

;;; --- tree-sitter: C -------------------------------------------------------

(defvar *ts-c-color-alist*
  '(("comment"          . 15)   ; gray
    ("string"           .  9)   ; dark red
    ("number"           . 13)   ; purple
    ("preproc"          . 14)   ; teal
    ("keyword"          . 12)   ; dark blue
    ("keyword.type"     . 12)
    ("keyword.modifier" . 12)
    ("type.builtin"     . 12)
    ("type"             . 13)   ; purple
    ("function.def"     . 10)   ; dark green
    ("function.call"    . 10)))

(defun ts-c-indent-of-cp (cp)
  "Column of the first non-whitespace char on the line containing CP."
  (save-excursion
    (goto-char cp)
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun ts-c-find-ancestor (ancestors &rest types)
  "Return the first entry in ANCESTORS whose type is one of TYPES."
  (dolist (a ancestors)
    (when (member (first a) types :test #'string=)
      (return a))))

(defun ts-c-compound-owner (ancestors)
  "Return the ancestor controlling the innermost compound_statement."
  (do ((rest ancestors (cdr rest)))
      ((null rest) nil)
    (when (string= (first (car rest)) "compound_statement")
      (return (cadr rest)))))

(defun ts-c-calc-indent ()
  "Calculate C indent column using tree-sitter.  Returns column or nil."
  (save-excursion
    (goto-bol)
    (skip-chars-forward " \t")
    (let* ((g         *ts-buffer-grammar*)
           (ancestors (and g (si:ts-node-ancestors g (selected-buffer) (point)))))
      (when (null ancestors)
        (return-from ts-c-calc-indent nil))
      (let* ((compound  (ts-c-find-ancestor ancestors "compound_statement"))
             (owner     (ts-c-compound-owner ancestors))
             (base-cp   (second (or owner compound)))
             (case-stmt (ts-c-find-ancestor ancestors "case_statement")))
        (cond
          ((looking-for "}")
           (if base-cp (ts-c-indent-of-cp base-cp) 0))
          ((looking-for "#")
           (if c-preprocessor-offset c-preprocessor-offset 0))
          ((looking-at "\\(case[^A-Za-z0-9_]\\|default[ \t]*:\\)")
           (if base-cp
               (max 0 (+ (ts-c-indent-of-cp base-cp)
                         c-indent-level c-label-offset))
             0))
          (case-stmt
           (+ (ts-c-indent-of-cp (second case-stmt)) c-indent-level))
          (compound
           (+ (ts-c-indent-of-cp base-cp) c-indent-level))
          (t 0))))))

(defun ts-c-indent-line ()
  "TAB handler: tree-sitter indent with fallback to calc-c-indent."
  (interactive "*")
  (if (or (not (interactive-p))
          *c-tab-always-indent*
          (save-excursion
            (skip-chars-backward " \t")
            (bolp)))
      (case (save-excursion
              (goto-bol)
              (parse-point-syntax))
        (:string)
        (:comment
         (let ((column (calc-c-comment-indent)))
           (when (integerp column)
             (smart-indentation column))))
        (t
         (let ((column (or (ts-c-calc-indent) (calc-c-indent))))
           (when (integerp column)
             (smart-indentation column)))))
    (insert "\t"))
  t)

(defun ts-c-mode-enable ()
  (setq *ts-calc-indent-function* #'ts-c-calc-indent)
  (ts-enable-for-buffer))

(ignore-errors (ts-register-mode 'c-mode :colors *ts-c-color-alist*))
(define-key *c-mode-map* #\TAB           'ts-c-indent-line)
(define-key *c-mode-map* '(#\C-c #\C-t)  'ts-show-ancestors)
(define-key *c-mode-map* '(#\C-c #\C-i)  'ts-test-indent)
(add-hook '*c-mode-hook* 'ts-c-mode-enable)
