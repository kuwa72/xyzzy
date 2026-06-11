;;; -*- Mode: Lisp; Package: EDITOR -*-
;;; tree-sitter: generic syntax highlighting infrastructure
;;;
;;; Language-specific support lives in the respective mode files:
;;;   c-mode.l   — C and C++ (colors, indentation, key bindings)
;;;   cc-mode.l  — C++ key bindings and grammar registration
;;;   perl.l     — Perl (colors, indentation, key bindings)
;;;   markdown.l — Markdown (colors)
;;;
;;; Debug commands bound by mode setup:
;;;   C-c C-t  ts-show-ancestors  — show node chain at point
;;;   C-c C-i  ts-test-indent     — show ts indent column for current line

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

(defun ts-grammar-outline-file (lang)
  "Return the path to outline.scm for LANG."
  (merge-pathnames (format nil "~A/outline.scm" lang)
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

(defun ts-register-mode (mode &key lang query colors outline-query)
  "Register tree-sitter support for MODE.
LANG defaults to MODE name with -mode suffix stripped (c-mode -> \"c\").
QUERY defaults to reading grammars/<lang>/highlights.scm.
COLORS is an alist of (capture-name . fg-color-number).
OUTLINE-QUERY defaults to reading grammars/<lang>/outline.scm if present."
  (let* ((lang-name    (or lang (ts-mode-to-lang mode)))
         (query-str    (or query
                           (ts-read-query-file (ts-grammar-query-file lang-name))
                           (error "ts: no query for ~A (tried ~A)"
                                  lang-name (ts-grammar-query-file lang-name))))
         (outline-str  (or outline-query
                            (ts-read-query-file (ts-grammar-outline-file lang-name))))
         (gram         (si:load-ts-grammar (ts-grammar-file lang-name) lang-name)))
    (setf (gethash mode *ts-grammar-registry*)
          (list gram query-str colors outline-str))
    gram))

;;; --- Buffer-local state --------------------------------------------------

(defvar-local *ts-highlight-active* nil)
(defvar-local *ts-buffer-grammar*   nil)
(defvar-local *ts-buffer-query*     nil)
(defvar-local *ts-buffer-colors*    nil)
(defvar-local *ts-outline-query*    nil)
(defvar-local *ts-calc-indent-function* nil
  "Mode-specific indent calculator. Set by each mode's ts enable hook.
Called by ts-test-indent with no arguments; should return a column or nil.")

(defun ts-enable-for-buffer ()
  "Enable tree-sitter highlighting for the current buffer (uses buffer-mode)."
  (interactive)
  (let ((entry (gethash buffer-mode *ts-grammar-registry*)))
    (when entry
      (setq *ts-buffer-grammar*   (first  entry)
            *ts-buffer-query*     (second entry)
            *ts-buffer-colors*    (third  entry)
            *ts-outline-query*    (fourth entry)
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

;;; --- Highlight scheduling ------------------------------------------------

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

;;; --- Debug utilities -----------------------------------------------------

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
  "Show what the ts indent calculator would return for the current line."
  (interactive)
  (if (null *ts-calc-indent-function*)
      (message "ts-indent: not available in this mode")
    (let ((col (funcall *ts-calc-indent-function*)))
      (if (integerp col)
          (message "ts-indent: ~D  (current: ~D)"
                   col
                   (save-excursion
                     (goto-bol) (skip-chars-forward " \t") (current-column)))
        (message "ts-indent: no parse tree yet")))))

(defun ts-print-spans (&optional buffer)
  "Print tree-sitter capture spans to *ts*."
  (interactive)
  (let ((spans (si:ts-query-buffer *ts-buffer-grammar*
                                   *ts-buffer-query*
                                   buffer)))
    (with-output-to-temp-buffer ("*ts*")
      (format t "ts:~D spans~%" (length spans))
      (dolist (s spans)
        (format t "  ~A  [~D, ~D)~%" (first s) (second s) (third s))))))

;;; --- Outline -----------------------------------------------------------------

(defvar *ts-outline-keymap* nil)
(unless *ts-outline-keymap*
  (setq *ts-outline-keymap* (make-sparse-keymap))
  (define-key *ts-outline-keymap* #\Return 'ts-outline-goto)
  (define-key *ts-outline-keymap* #\q      'delete-window)
  (define-key *ts-outline-keymap* #\g      'ts-outline-refresh))

(defvar *ts-outline-source-buffer* nil
  "Buffer name of the source buffer for the current *outline* display.")

(defvar *ts-outline-positions* nil
  "List of start-cp values, one per outline line (1-indexed by line number).")

(defun ts-outline-func-name (text)
  "Find function/method name in TEXT: last identifier before first '('."
  (let ((paren (position #\( text)))
    (when paren
      (let* ((i (do ((j (1- paren) (1- j)))
                    ((< j 0) -1)
                  (unless (member (char text j) '(#\space #\tab #\newline #\* #\&))
                    (return j))))
             (id-end (1+ i))
             (id-start (do ((j (1- id-end) (1- j)))
                           ((< j 0) 0)
                         (let ((c (char text j)))
                           (unless (or (alphanumericp c)
                                       (char= c #\_)
                                       (char= c #\~)
                                       (char= c #\:))
                             (return (1+ j)))))))
        (when (< id-start id-end)
          (subseq text id-start id-end))))))

(defun ts-outline-keyword-name (text)
  "Extract name after class/struct/namespace/enum/sub keyword in TEXT."
  (let ((len (length text)))
    (dolist (kw (list "class " "struct " "namespace " "enum " "sub "))
      (let ((pos (search kw text)))
        (when pos
          (let* ((s0 (+ pos (length kw)))
                 (s1 (do ((i s0 (1+ i)))
                         ((>= i len) s0)
                       (unless (member (char text i) '(#\space #\tab))
                         (return i))))
                 (s2 (do ((i s1 (1+ i)))
                         ((>= i len) len)
                       (let ((c (char text i)))
                         (unless (or (alphanumericp c)
                                     (char= c #\_)
                                     (char= c #\:))
                           (return i))))))
            (when (< s1 s2)
              (return (subseq text s1 s2)))))))))

(defun ts-outline-display-text (buf start end)
  "Extract display text for outline node [START,END) in BUF."
  (ts-llog (format nil "disp: buf-sub ~D ~D" start (min (+ start 300) end)))
  (let* ((limit (min (+ start 300) end))
         (raw   (buffer-substring start limit buf)))
    (ts-llog (format nil "disp: raw len=~D" (length raw)))
    (let* ((brace (position #\{ raw))
           (sig   (string-right-trim " \t\r\n" (if brace (subseq raw 0 brace) raw))))
      (ts-llog (format nil "disp: sig=~S" sig))
      (or (ts-outline-func-name sig)
          (ts-outline-keyword-name sig)
          (let ((nl (position #\newline sig)))
            (string-trim " \t" (if nl (subseq sig 0 nl) sig)))))))

(defun ts-outline-build (nodes buf)
  "Build list of (depth text start-cp) from raw ts-query NODES for BUF."
  (ts-llog (format nil "build: start nodes=~S" nodes))
  (let ((sorted (sort (copy-list nodes) #'(lambda (a b) (< (second a) (second b)))))
        (stack  nil)
        (result nil))
    (ts-llog (format nil "build: sorted ok ~D entries" (length sorted)))
    (dolist (node sorted)
      (let ((start (second node))
            (end   (third  node)))
        (ts-llog (format nil "build: node start=~D end=~D" start end))
        (do () ((not (and stack (<= (third (car stack)) start))))
          (pop stack))
        (let ((depth (length stack)))
          (ts-llog (format nil "build: calling display-text start=~D end=~D" start end))
          (let ((text (ts-outline-display-text buf start end)))
            (ts-llog (format nil "build: text=~S" text))
            (push (list depth text start) result)
            (push node stack)))))
    (ts-llog "build: done")
    (nreverse result)))

(defun ts-outline-show (entries src-buf-name)
  "Render ENTRIES into *outline* buffer and display it."
  (ts-llog "show: start")
  (let ((out (get-buffer-create "*outline*")))
    (ts-llog "show: get-buffer-create ok")
    (save-excursion
      (set-buffer out)
      (ts-llog "show: set-buffer ok")
      (let ((buffer-read-only nil))
        (declare (special buffer-read-only))
        (erase-buffer out)
        (ts-llog "show: erase-buffer ok")
        (make-local-variable '*ts-outline-positions*)
        (make-local-variable '*ts-outline-source-buffer*)
        (setq *ts-outline-source-buffer* src-buf-name)
        (setq *ts-outline-positions*
              (mapcar #'third entries))
        (ts-llog "show: positions set")
        (dolist (entry entries)
          (insert (make-string (* (first entry) 2) :initial-element #\space))
          (insert (second entry))
          (insert #\LFD))
        (ts-llog "show: insert done")
        (goto-char (point-min))
        (set-buffer-modified-p nil))
      (ts-llog "show: let done, setting read-only")
      (setq buffer-read-only t)
      (ts-llog "show: use-keymap")
      (use-keymap *ts-outline-keymap*)))
  (ts-llog "show: display-buffer")
  (display-buffer (find-buffer "*outline*"))
  (ts-llog "show: done"))

(defun ts-llog (msg)
  (with-open-file (f "C:/tmp/ts-outline.log"
                     :direction :output
                     :if-exists :append
                     :if-does-not-exist :create)
    (format f "lisp: ~A~%" msg)))

(defvar *ts-outline-pending-buf*   nil)
(defvar *ts-outline-pending-gram*  nil)
(defvar *ts-outline-pending-oq*    nil)
(defvar *ts-outline-pending-ticks* 0)
(defvar *ts-outline-max-ticks*   100) ; 100 * 0.15s = 15s timeout

(defun ts-outline ()
  "Show tree-sitter outline for the current buffer (async)."
  (interactive)
  (unless *ts-buffer-grammar*
    (error "ts-outline: no tree-sitter grammar for this buffer"))
  (unless *ts-outline-query*
    (error "ts-outline: no outline.scm for this language"))
  (let* ((buf  (selected-buffer))
         (gram *ts-buffer-grammar*)
         (oq   *ts-outline-query*)
         (nodes (si:ts-query-buffer-sync gram oq buf)))
    (if nodes
        (ts-outline-show (ts-outline-build nodes buf) (buffer-name buf))
      (progn
        (setq *ts-outline-pending-buf*   (buffer-name buf)
              *ts-outline-pending-gram*  gram
              *ts-outline-pending-oq*    oq
              *ts-outline-pending-ticks* 0)
        (stop-timer 'ts-outline-poll)
        (start-timer 0.15 'ts-outline-poll t)
        (message "ts-outline: waiting for parse...")))))

(defun ts-outline-poll ()
  "Timer callback: retry outline once bg query is ready."
  (stop-timer 'ts-outline-poll)
  (let ((src (and *ts-outline-pending-buf*
                  (find-buffer *ts-outline-pending-buf*))))
    (unless src
      (setq *ts-outline-pending-buf* nil)
      (return-from ts-outline-poll nil))
    (incf *ts-outline-pending-ticks*)
    (when (>= *ts-outline-pending-ticks* *ts-outline-max-ticks*)
      (setq *ts-outline-pending-buf* nil)
      (message "ts-outline: timed out after ~D polls" *ts-outline-pending-ticks*)
      (return-from ts-outline-poll nil))
    (let ((nodes (si:ts-query-buffer-sync *ts-outline-pending-gram*
                                          *ts-outline-pending-oq*
                                          src)))
      (if nodes
          (progn
            (ts-llog (format nil "poll: got ~D nodes, calling build" (length nodes)))
            (let ((entries (ts-outline-build nodes src)))
              (ts-llog (format nil "poll: build done ~D entries, calling show" (length entries)))
              (ts-outline-show entries *ts-outline-pending-buf*)
              (ts-llog "poll: show done"))
            (setq *ts-outline-pending-buf* nil))
        (progn
          (message "ts-outline: waiting... (~D)" *ts-outline-pending-ticks*)
          (start-timer 0.15 'ts-outline-poll t))))))

(defun ts-outline-goto ()
  "Jump to source position for the current outline line."
  (interactive)
  (let* ((line  (current-line-number))
         (pos   (nth (1- line) *ts-outline-positions*))
         (src   *ts-outline-source-buffer*))
    (unless pos
      (error "ts-outline-goto: no entry at line ~D" line))
    (let ((src-buf (find-buffer src)))
      (unless src-buf
        (error "ts-outline-goto: source buffer ~S not found" src))
      (pop-to-buffer src-buf)
      (goto-char pos))))

(defun ts-outline-refresh ()
  "Re-run ts-outline for the source buffer."
  (interactive)
  (let ((src (find-buffer *ts-outline-source-buffer*)))
    (unless src
      (error "ts-outline-refresh: source buffer not found"))
    (save-excursion
      (set-buffer src)
      (ts-outline))))
