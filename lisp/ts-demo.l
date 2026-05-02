;;; tree-sitter demo: syntax highlighting for the visible window only
;;;
;;; Usage:
;;;   (load-library "ts-demo")
;;;   (ts-demo-highlight-on-idle)  ; enable for current buffer
;;;   (ts-demo-stop-highlight)     ; disable

(defvar *ts-c-grammar* nil)

(defun ts-load-c-grammar ()
  "Load the C grammar DLL (built by CMake)."
  (unless (and *ts-c-grammar* (si:ts-grammar-p *ts-c-grammar*))
    (let ((dll (merge-pathnames "tree-sitter-c.dll" (si:system-root))))
      (setq *ts-c-grammar* (si:load-ts-grammar dll "c"))))
  *ts-c-grammar*)

(defconstant *ts-c-highlight-query*
  "(comment) @comment
(string_literal) @string
(number_literal) @constant.numeric
(preproc_include) @include
(call_expression function: (identifier) @function.call)")

;;; Return (start-row . end-row) as 0-based tree-sitter row numbers for the
;;; visible window.  Row numbers are O(1) to obtain and passed directly to
;;; ts_query_cursor_set_point_range, avoiding the O(N) cp->byte scan.
(defun ts-visible-range ()
  (let* ((start-row (1- (get-window-start-line)))  ; xyzzy 1-based -> 0-based
         (end-row   (+ start-row (window-lines))))
    (cons start-row end-row)))

(defconstant *ts-c-color-alist*
  '(("comment"          . 2)
    ("string"           . 1)
    ("constant.numeric" . 4)
    ("include"          . 5)
    ("function.call"    . 6)))

;;; One-shot timer target: highlight visible region and force a repaint.
;;; si:ts-apply-highlights manages bg parse/query threads and applies textprops
;;; directly in C (no Lisp list).  Returns t when done, nil while pending.
;;; refresh-screen is always called so the display updates without a keypress.
(defun ts-do-highlight ()
  (let (buf)
    (ignore-errors
      (let* ((g     (ts-load-c-grammar))
             (range (ts-visible-range)))
        (setq buf (selected-buffer))
        (unless (si:ts-apply-highlights g *ts-c-highlight-query*
                                        buf
                                        (car range) (cdr range)
                                        'ts-face *ts-c-color-alist*)
          (start-timer 0.1 'ts-do-highlight t))))
    (refresh-screen)))  ; always refresh, even if highlights threw an error

;;; Post-command hook: cancel pending timer and schedule a new one.
(defun ts-schedule-highlight ()
  (stop-timer 'ts-do-highlight)
  (start-timer 0.1 'ts-do-highlight t))

(defun ts-demo-highlight-on-idle ()
  "Enable idle-based tree-sitter highlighting for the current buffer."
  (interactive)
  (ts-load-c-grammar)
  (add-hook '*post-command-hook* 'ts-schedule-highlight)
  (ts-schedule-highlight))

(defun ts-demo-stop-highlight ()
  "Disable idle-based tree-sitter highlighting."
  (interactive)
  (stop-timer 'ts-do-highlight)
  (delete-hook '*post-command-hook* 'ts-schedule-highlight)
  (save-excursion
    (delete-text-attributes 'ts-face)))

;;; One-shot full-buffer query (for comparison / debugging).
(defun ts-demo-print-spans (&optional buffer)
  "Print tree-sitter capture spans to *ts-demo*."
  (interactive)
  (let ((spans (si:ts-query-buffer (ts-load-c-grammar)
                                   *ts-c-highlight-query*
                                   buffer)))
    (with-output-to-temp-buffer ("*ts-demo*")
      (format t "ts-demo: ~D spans~%" (length spans))
      (dolist (s spans)
        (format t "  ~A  [~D, ~D)~%" (first s) (second s) (third s))))))
