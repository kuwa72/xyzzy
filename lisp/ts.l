;;; -*- Mode: Lisp; Package: EDITOR -*-
;;; tree-sitter: syntax highlighting and indentation
;;;
;;; Usage:
;;;   (load-library "ts")
;;;   (ts-c-mode-install)     ; register C and set up keys (once)
;;;   (ts-c++-mode-install)   ; register C++ (once)
;;;
;;; Keys added to *c-mode-map* by ts-c-mode-install:
;;;   TAB      ts-c-indent-line        ; tree-sitter indent (fallback: calc-c-indent)
;;;   C-c C-t  ts-show-ancestors  ; show node chain at point
;;;   C-c C-i  ts-test-indent     ; show what ts indent column would be

(in-package "editor")

;;; --- Configuration -------------------------------------------------------

(defvar *ts-grammar-directory*
  (merge-pathnames "grammars/" (si:system-root))
  "Root directory for per-language subdirectories (grammars/<lang>/).")

(defvar *ts-grammar-suffix* ".dll"
  "File extension for grammar shared libraries (.dll / .so / .dylib).")

;;; --- Grammar registry ----------------------------------------------------

(defvar *ts-grammar-registry* (make-hash-table)
  "Hash table mapping mode symbol -> (grammar query colors).")

(defun ts-mode-to-lang (mode)
  "Derive grammar lang name from MODE: strip trailing -mode suffix."
  (let* ((name (string-downcase (symbol-name mode)))
         (pos  (- (length name) 5)))
    (if (and (> pos 0) (string= name "-mode" :start1 pos))
        (subseq name 0 pos)
      name)))

(defun ts-grammar-file (lang)
  "Return the path to the grammar DLL for LANG."
  (merge-pathnames (format nil "~A/tree-sitter-~A~A" lang lang *ts-grammar-suffix*)
                   *ts-grammar-directory*))

(defun ts-grammar-query-file (lang)
  "Return the path to highlights.scm for LANG."
  (merge-pathnames (format nil "~A/highlights.scm" lang)
                   *ts-grammar-directory*))

(defun ts-read-query-file (path)
  "Read PATH as text and return its contents as a string, or nil."
  (when (file-exist-p path)
    (with-open-file (s path :direction :input)
      (let ((result ""))
        (loop
          (let ((line (read-line s nil nil)))
            (unless line (return result))
            (setq result (concat result line "\n"))))))))

(defun ts-register-mode (mode &key lang query colors)
  "Register tree-sitter support for MODE.
LANG defaults to MODE name with -mode suffix stripped (c-mode -> \"c\").
QUERY defaults to reading grammars/<lang>/highlights.scm.
COLORS is an alist of (capture-name . fg-color-number)."
  (let* ((lang-name  (or lang (ts-mode-to-lang mode)))
         (query-str  (or query
                         (ts-read-query-file (ts-grammar-query-file lang-name))
                         (error "ts: no query for ~A (tried ~A)"
                                lang-name (ts-grammar-query-file lang-name))))
         (gram       (si:load-ts-grammar (ts-grammar-file lang-name) lang-name)))
    (setf (gethash mode *ts-grammar-registry*)
          (list gram query-str colors))
    gram))

;;; --- Buffer-local state --------------------------------------------------

(defvar-local *ts-highlight-active* nil)
(defvar-local *ts-buffer-grammar*   nil)
(defvar-local *ts-buffer-query*     nil)
(defvar-local *ts-buffer-colors*    nil)

(defun ts-enable-for-buffer ()
  "Enable tree-sitter highlighting for the current buffer (uses buffer-mode)."
  (interactive)
  (let ((entry (gethash buffer-mode *ts-grammar-registry*)))
    (when entry
      (setq *ts-buffer-grammar*   (first  entry)
            *ts-buffer-query*     (second entry)
            *ts-buffer-colors*    (third  entry)
            *ts-highlight-active* t)
      (add-hook '*post-command-hook* 'ts-schedule-highlight)
      (ts-schedule-highlight))))

(defun ts-disable-for-buffer ()
  "Disable tree-sitter highlighting for the current buffer."
  (interactive)
  (setq *ts-highlight-active* nil)
  (stop-timer 'ts-do-highlight)
  (save-excursion
    (delete-text-attributes 'ts-face)))

;;; --- Highlight scheduling (generic) -------------------------------------

(defun ts-visible-range ()
  "Return (start-row . end-row) as 0-based rows for the visible window ±5."
  (let* ((win-start (1- (get-window-start-line)))
         (start-row (max 0 (- win-start 5)))
         (end-row   (+ win-start (window-lines) 5)))
    (cons start-row end-row)))

(defun ts-do-highlight ()
  "Timer target: apply highlights for the current buffer if ts is active."
  (ignore-errors
    (when *ts-highlight-active*
      (let ((range (ts-visible-range)))
        (unless (si:ts-apply-highlights *ts-buffer-grammar* *ts-buffer-query*
                                        (selected-buffer)
                                        (car range) (cdr range)
                                        'ts-face *ts-buffer-colors*)
          (start-timer 0.1 'ts-do-highlight t)))))
  (refresh-screen))

(defun ts-schedule-highlight ()
  "Post-command hook: apply cached highlights immediately, then reschedule."
  (when *ts-highlight-active*
    (ignore-errors
      (let ((range (ts-visible-range)))
        (si:ts-apply-highlights *ts-buffer-grammar* *ts-buffer-query*
                                (selected-buffer)
                                (car range) (cdr range)
                                'ts-face *ts-buffer-colors*)))
    (stop-timer 'ts-do-highlight)
    (start-timer 0.1 'ts-do-highlight t)))

;;; --- C-specific: query and colors ---------------------------------------


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

;;; --- C-specific: indentation --------------------------------------------

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
  "Return the ancestor that owns the innermost compound_statement.
Uses the controlling statement (if/for/function_definition/…) rather than
the compound's own '{' position, so brace placement style does not affect
the base column for indent calculation."
  (do ((rest ancestors (cdr rest)))
      ((null rest) nil)
    (when (string= (first (car rest)) "compound_statement")
      (return (cadr rest)))))

(defun ts-c-calc-indent ()
  "Calculate C indent column using tree-sitter.  Returns column or nil.
nil means no parse tree yet; caller falls back to calc-c-indent."
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

;;; --- Debug utilities ----------------------------------------------------

(defun ts-show-ancestors ()
  "Show tree-sitter node chain at point in *ts-ancestors* buffer."
  (interactive)
  (let* ((g         *ts-buffer-grammar*)
         (ancestors (and g (si:ts-node-ancestors g (selected-buffer) (point)))))
    (if (null ancestors)
        (message "ts: no parse tree yet")
      (progn
        (message "ts: ~A" (first (first ancestors)))
        (with-output-to-temp-buffer ("*ts-ancestors*")
          (dolist (a ancestors)
            (format t "~A  [~D, ~D)~%" (first a) (second a) (third a))))))))

(defun ts-test-indent ()
  "Show what ts-c-calc-indent would return for the current line."
  (interactive)
  (let ((col (ts-c-calc-indent)))
    (if (integerp col)
        (message "ts-indent: ~D  (current: ~D)"
                 col
                 (save-excursion
                   (goto-bol) (skip-chars-forward " \t") (current-column)))
      (message "ts-indent: no parse tree yet"))))

(defun ts-print-spans (&optional buffer)
  "Print tree-sitter capture spans to *ts-demo*."
  (interactive)
  (let ((spans (si:ts-query-buffer *ts-buffer-grammar*
                                   *ts-buffer-query*
                                   buffer)))
    (with-output-to-temp-buffer ("*ts*")
      (format t "ts:~D spans~%" (length spans))
      (dolist (s spans)
        (format t "  ~A  [~D, ~D)~%" (first s) (second s) (third s))))))

;;; --- C-mode setup -------------------------------------------------------

(defun ts-c-mode-install ()
  "Register C grammar and set up keys in *c-mode-map*."
  (interactive)
  (ts-register-mode 'c-mode :colors *ts-c-color-alist*)
  (define-key *c-mode-map* #\TAB           'ts-c-indent-line)
  (define-key *c-mode-map* '(#\C-c #\C-t)  'ts-show-ancestors)
  (define-key *c-mode-map* '(#\C-c #\C-i)  'ts-test-indent)
  (add-hook '*c-mode-hook* 'ts-enable-for-buffer)
  (when (eq buffer-mode 'c-mode)
    (ts-enable-for-buffer))
  (message "ts:c-mode installed (C-c C-t = ancestors, C-c C-i = indent)"))

(defun ts-c++-mode-install ()
  "Register C++ grammar and enable highlighting for c++-mode."
  (interactive)
  (ts-register-mode 'c++-mode :lang "cpp" :colors *ts-c-color-alist*)
  (add-hook '*c++-mode-hook* 'ts-enable-for-buffer)
  (when (eq buffer-mode 'c++-mode)
    (ts-enable-for-buffer))
  (message "ts:c++-mode installed"))

;;; --- Perl-mode setup ----------------------------------------------------

(defvar *ts-perl-color-alist*
  '(("comment"      . 15)   ; gray
    ("string"       .  9)   ; dark red
    ("number"       . 13)   ; purple
    ("variable"     . 14)   ; dark teal
    ("function.def" . 10))) ; dark green

(defun ts-perl-mode-install ()
  "Register Perl grammar and enable highlighting for perl-mode."
  (interactive)
  (ts-register-mode 'perl-mode :colors *ts-perl-color-alist*)
  (add-hook '*perl-mode-hook* 'ts-enable-for-buffer)
  (when (eq buffer-mode 'perl-mode)
    (ts-enable-for-buffer))
  (message "ts:perl-mode installed"))
