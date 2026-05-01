;;; tree-sitter demo: parse current buffer and list captures
;;;
;;; Usage:
;;;   (load-library "ts-demo")
;;;   (ts-demo-c-highlight)   ; highlight current buffer as C

(defvar *ts-c-grammar* nil)

(defun ts-load-c-grammar ()
  "Load the C grammar DLL (built by CMake)."
  (unless (and *ts-c-grammar* (si:ts-grammar-p *ts-c-grammar*))
    (let ((dll (merge-pathnames "tree-sitter-c.dll" (si:system-root))))
      (setq *ts-c-grammar* (si:load-ts-grammar dll "c"))))
  *ts-c-grammar*)

(defun ts-demo-query-buffer (&optional buffer)
  "Run a basic highlight query on BUFFER and return the capture list."
  (let ((g (ts-load-c-grammar))
        (query "(comment) @comment
(string_literal) @string
(number_literal) @constant.numeric
(preproc_include) @include
(call_expression function: (identifier) @function.call)"))
    (si:ts-query-buffer g query buffer)))

(defun ts-demo-print-spans (&optional buffer)
  "Print tree-sitter capture spans to *Output*."
  (interactive)
  (let ((spans (ts-demo-query-buffer buffer)))
    (with-output-to-temp-buffer ("*ts-demo*")
      (format t "ts-demo: ~D spans~%" (length spans))
      (dolist (s spans)
        (format t "  ~A  [~D, ~D)~%" (first s) (second s) (third s))))))

;;; Apply textprops based on tree-sitter captures
(defun ts-demo-apply-highlights (&optional buffer)
  "Apply tree-sitter based syntax highlighting to BUFFER as textprops."
  (interactive)
  (let* ((buf (or buffer (selected-buffer)))
         (spans (ts-demo-query-buffer buf)))
    (save-excursion
      (set-buffer buf)
      ;; Clear existing ts textprops first
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
            (set-text-attribute start end 'ts-face :foreground fg)))))))
