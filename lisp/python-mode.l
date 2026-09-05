;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; python-mode: Python editing support
;;;

(provide "python-mode")

(in-package "editor")

(require "re-kwd")

(export '(*python-mode-hook* *python-mode-map* python-mode
          *python-keyword-file* *python-indent-level*))

(defvar *python-mode-hook* nil)
(defvar *python-mode-map* nil)
(defvar *python-keyword-file* "Python")
(defvar *python-keyword-hash-table* nil)
(defvar *python-indent-level* 4)

(unless *python-mode-map*
  (setq *python-mode-map* (make-sparse-keymap))
  (define-key *python-mode-map* #\RET 'python-newline-and-indent)
  (define-key *python-mode-map* #\TAB 'python-indent-line)
  (define-key *python-mode-map* #\: 'python-electric-colon))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *python-mode-syntax-table* nil)
(unless *python-mode-syntax-table*
  (setq *python-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x)))
      ((>= x #x7f))
    (let ((c (code-char x)))
      (when c
        (set-syntax-punctuation *python-mode-syntax-table* c))))
  ;; Restore word syntax for letters and digits (needed for keyword-hash-table)
  (do ((x #x41 (1+ x))) ((> x #x5a))
    (set-syntax-word *python-mode-syntax-table* (code-char x)))
  (do ((x #x61 (1+ x))) ((> x #x7a))
    (set-syntax-word *python-mode-syntax-table* (code-char x)))
  (do ((x #x30 (1+ x))) ((> x #x39))
    (set-syntax-word *python-mode-syntax-table* (code-char x)))
  (set-syntax-string *python-mode-syntax-table* #\")
  (set-syntax-string *python-mode-syntax-table* #\')
  (set-syntax-escape *python-mode-syntax-table* #\\)
  (set-syntax-match *python-mode-syntax-table* #\( #\))
  (set-syntax-match *python-mode-syntax-table* #\{ #\})
  (set-syntax-match *python-mode-syntax-table* #\[ #\])
  (set-syntax-symbol *python-mode-syntax-table* #\_)
  (set-syntax-start-comment *python-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *python-mode-syntax-table* #\LFD nil t)
  (set-syntax-whitespace *python-mode-syntax-table* #\SPC)
  (set-syntax-whitespace *python-mode-syntax-table* #\TAB)
  (set-syntax-whitespace *python-mode-syntax-table* #\RET))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *python-regexp-keyword-list* nil)

(defun python-setup-keywords ()
  (unless *python-regexp-keyword-list*
    (setq *python-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Decorators
             ("^[ \t]*@[A-Za-z_][A-Za-z0-9_.]*" nil :tag)
             ;; def/class names
             ("\\bdef[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" nil (:keyword 0 :bold))
             ("\\bclass[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)" nil (:keyword 0 :bold))
             ;; self, cls
             ("\\bself\\b\\|\\bcls\\b" nil 2)
             ;; Builtins
             ("\\b\\(print\\|len\\|range\\|int\\|str\\|float\\|list\\|dict\\|set\\|tuple\\|type\\|isinstance\\|hasattr\\|getattr\\|setattr\\|super\\|property\\|staticmethod\\|classmethod\\|enumerate\\|zip\\|map\\|filter\\|sorted\\|reversed\\|open\\|__init__\\|__str__\\|__repr__\\)\\b" nil :tag)
             ;; f-string prefix
             ("\\bf\"" nil :string)
             ))))
  *python-regexp-keyword-list*)

;;; ============================================================
;;; Indentation
;;; ============================================================

(defun python-previous-line-indent ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-bol)
    (skip-chars-forward " \t")
    (current-column)))

(defun python-previous-line-ends-colon-p ()
  (save-excursion
    (forward-line -1)
    (while (and (> (point) 0)
                (progn (goto-bol) (looking-at "^[ \t]*\\(#.*\\)?$")))
      (forward-line -1))
    (goto-eol)
    (skip-chars-backward " \t")
    ;; skip trailing comment
    (let ((eol (point)))
      (goto-bol)
      (let ((in-string nil)
            (last-colon nil))
        (while (< (point) eol)
          (let ((c (following-char)))
            (cond
             (in-string
              (if (char= c in-string)
                  (setq in-string nil)
                (when (char= c #\\)
                  (forward-char 1))))
             ((or (char= c #\") (char= c #\'))
              (setq in-string c))
             ((char= c #\#) (return-from python-previous-line-ends-colon-p last-colon))
             ((char= c #\:) (setq last-colon t))
             (t (setq last-colon nil))))
          (forward-char 1))
        last-colon))))

(defun python-calc-indent ()
  (if (= (save-excursion (goto-bol) (point)) 0)
      0
    (let ((prev-indent (python-previous-line-indent)))
      (if (python-previous-line-ends-colon-p)
          (+ prev-indent *python-indent-level*)
        prev-indent))))

(defun python-indent-line ()
  (interactive)
  (let* ((target (python-calc-indent))
         (col (current-column))
         (cur-indent (save-excursion (goto-bol) (skip-chars-forward " \t") (current-column))))
    (when (= cur-indent target)
      (setq target (max 0 (- target *python-indent-level*))))
    (save-excursion
      (goto-bol)
      (delete-region (point) (progn (skip-chars-forward " \t") (point)))
      (insert (make-sequence 'string target :initial-element #\SPC)))
    (when (< col target)
      (goto-bol)
      (skip-chars-forward " \t"))))

(defun python-newline-and-indent ()
  (interactive)
  (let ((indent (python-calc-indent)))
    (save-excursion
      (goto-eol)
      (skip-chars-backward " \t")
      (let ((c (preceding-char)))
        (when (char= c #\:)
          (setq indent (+ indent *python-indent-level*)))))
    (insert "\n")
    (insert (make-sequence 'string indent :initial-element #\SPC))))

(defun python-electric-colon (&optional (arg 1))
  (interactive "*p")
  (self-insert-command arg)
  ;; Dedent for else:/elif:/except:/finally:/case:
  (save-excursion
    (goto-bol)
    (when (looking-at "^[ \t]*\\(else\\|elif\\|except\\|finally\\|case\\):[ \t]*$")
      (let ((target (max 0 (- (python-previous-line-indent) *python-indent-level*))))
        (goto-bol)
        (delete-region (point) (progn (skip-chars-forward " \t") (point)))
        (insert (make-sequence 'string target :initial-element #\SPC))))))

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun python-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Python")
  (setq buffer-mode 'python-mode)
  (use-keymap *python-mode-map*)
  (use-syntax-table *python-mode-syntax-table*)
  (and *python-keyword-file*
       (null *python-keyword-hash-table*)
       (setq *python-keyword-hash-table*
             (load-keyword-file *python-keyword-file*)))
  (when *python-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *python-keyword-hash-table*))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (python-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable '*python-indent-level*)
  (run-hooks '*python-mode-hook*))


(ignore-errors (ts-register-mode 'python-mode))
(add-hook '*python-mode-hook* 'ts-enable-for-buffer)
