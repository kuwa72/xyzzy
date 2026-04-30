;;; tree-sitter demo: parse current buffer and list captures
;;;
;;; Usage:
;;;   (load-library "ts-demo")
;;;   (ts-demo-c-highlight)   ; highlight current buffer as C

(defvar *ts-c-grammar* nil)

(defun ts-load-c-grammar ()
  "Load the C grammar DLL (MSYS2 CLANGARM64 location)."
  (unless (and *ts-c-grammar* (si:ts-grammar-p *ts-c-grammar*))
    (let ((dll "C:/msys64/clangarm64/lib/nvim/parser/c.so"))
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
    (with-output-to-buffer ("*ts-demo*")
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
      (remove-text-attributes 1 (buffer-size) 'ts-face)
      (dolist (s spans)
        (let* ((name   (first s))
               (start  (1+ (second s)))   ; xyzzy uses 1-based points
               (end    (1+ (third s)))
               (face   (cond
                         ((string= name "comment")        'comment)
                         ((string= name "string")         'string)
                         ((string= name "constant.numeric") 'keyword1)
                         ((string= name "include")        'keyword2)
                         ((string= name "function.call")  'keyword3)
                         (t nil))))
          (when face
            (set-text-attribute start end 'ts-face face)))))))
