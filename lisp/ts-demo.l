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

(defun ts-apply-highlights (buf spans)
  "Clear ts-face textprops in BUF and apply SPANS."
  (save-excursion
    (set-buffer buf)
    (delete-text-attributes 'ts-face)
    (dolist (s spans)
      (let* ((name  (first s))
             (start (second s))
             (end   (third s))
             (fg    (cond
                      ((string= name "comment")          2)  ; dark green
                      ((string= name "string")           1)  ; dark red
                      ((string= name "constant.numeric") 4)  ; dark blue
                      ((string= name "include")          5)  ; dark magenta
                      ((string= name "function.call")    6)  ; dark cyan
                      (t nil))))
        (when fg
          (set-text-attribute start end 'ts-face :foreground fg))))))

;;; One-shot timer target: highlight visible region and force a repaint.
;;; refresh-screen is needed because refresh_buffer only sets WDF_WINDOW;
;;; the command loop calls refresh_screen at its top (before fetch), so
;;; without an explicit call here the display updates only on the next keypress.
(defun ts-do-highlight ()
  (ignore-errors
    (let* ((buf   (selected-buffer))
           (g     (ts-load-c-grammar))
           (range (ts-visible-range))
           (spans (si:ts-query-buffer g *ts-c-highlight-query*
                                      buf
                                      (car range) (cdr range))))
      (ts-apply-highlights buf spans)
      (refresh-screen))))

;;; Post-command hook: cancel pending timer and schedule a new one.
(defun ts-schedule-highlight ()
  (stop-timer 'ts-do-highlight)
  (start-timer 0.3 'ts-do-highlight t))

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
