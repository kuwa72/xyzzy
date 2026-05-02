;;; Usage: xyzzy-batch.exe -q -load lisp/test-ts-batch.l
;;; Exit codes: 0=all pass, 10=T1-fail, 21=T2-nil, 30=T3-fail,
;;;             40=T4-name-fail, 50=T5-fail, 99=setup-fail
;;; Writes tmp/ts-test.log with span details for human/Claude inspection.
(setq *post-startup-hook*
      #'(lambda ()
          (handler-case
              (let* ((dll  (merge-pathnames "tree-sitter-c.dll" (si:system-root)))
                     (g    (si:load-ts-grammar dll "c"))
                     (q    "(comment) @comment
(string_literal) @string
(preproc_include) @include
(call_expression function: (identifier) @function.call)")
                     (logfile (merge-pathnames "tmp/ts-test.log" (si:system-root))))

                ;; helper: poll until spans or max-tries
                (labels ((poll (buf &optional sr er (n 200))
                           (let (r)
                             (dotimes (_ n r)
                               (setq r (if sr
                                           (si:ts-query-buffer g q buf sr er)
                                         (si:ts-query-buffer g q buf)))
                               (when r (return r))))))

                  ;; Collect results; write log; then kill-xyzzy.
                  ;; kill-xyzzy must be OUTSIDE with-open-file or the stream is lost.
                  (let ((exit-code 0)
                        (log-lines nil))

                    (labels ((logf (fmt &rest args)
                               (setq log-lines
                                     (nconc log-lines
                                            (list (apply #'format nil fmt args))))))

                      ;; T1: full-buffer
                      (let* ((buf (create-new-buffer "*ts-t1*"))
                             (spans (progn
                                      (save-excursion (set-buffer buf)
                                        (insert "#include <stdio.h>"))
                                      (poll buf))))
                        (logf "T1 full-buffer: ~D span(s)" (length spans))
                        (dolist (s spans)
                          (logf "  ~A [~D,~D)" (first s) (second s) (third s)))
                        (unless spans (setq exit-code 10)))

                      ;; T2: range query 0..40
                      (when (zerop exit-code)
                        (let* ((buf (create-new-buffer "*ts-t2*"))
                               (spans (progn
                                        (save-excursion (set-buffer buf)
                                          (insert "#include <stdio.h>"))
                                        (poll buf 0 40))))
                          (logf "T2 range 0..40: ~D span(s)" (length spans))
                          (dolist (s spans)
                            (logf "  ~A [~D,~D)" (first s) (second s) (third s)))
                          (unless spans (setq exit-code 21))))

                      ;; T3: multi-line full-buffer
                      (when (zerop exit-code)
                        (let* ((buf (create-new-buffer "*ts-t3*"))
                               (spans (progn
                                        (save-excursion
                                          (set-buffer buf)
                                          (insert "#include <stdio.h>\nint main() { printf(\"x\"); return 0; }"))
                                        (poll buf))))
                          (logf "T3 multiline: ~D span(s)" (length spans))
                          (dolist (s spans)
                            (logf "  ~A [~D,~D)" (first s) (second s) (third s)))
                          (unless spans (setq exit-code 30))))

                      ;; T4: spans must include an "include" capture
                      (when (zerop exit-code)
                        (let* ((buf (create-new-buffer "*ts-t4*"))
                               (spans (progn
                                        (save-excursion (set-buffer buf)
                                          (insert "#include <stdio.h>"))
                                        (poll buf)))
                               (has-include (member "include"
                                                    (mapcar #'first spans)
                                                    :test #'string=)))
                          (logf "T4 include-capture: ~A" (if has-include "yes" "no"))
                          (unless has-include (setq exit-code 40))))

                      ;; T5: range 0..25 (matches ts-visible-range on 25-line window)
                      (when (zerop exit-code)
                        (let* ((buf (create-new-buffer "*ts-t5*"))
                               (spans (progn
                                        (save-excursion (set-buffer buf)
                                          (insert "#include <stdio.h>"))
                                        (poll buf 0 25))))
                          (logf "T5 range 0..25: ~D span(s)" (length spans))
                          (dolist (s spans)
                            (logf "  ~A [~D,~D)" (first s) (second s) (third s)))
                          (unless spans (setq exit-code 50)))))

                    ;; Write log then exit (kill-xyzzy outside with-open-file)
                    (with-open-file (log logfile :direction :output
                                     :if-exists :supersede
                                     :if-does-not-exist :create)
                      (dolist (line log-lines)
                        (format log "~A~%" line)))
                    (kill-xyzzy exit-code))))
            (condition (e)
              (kill-xyzzy 99)))))
