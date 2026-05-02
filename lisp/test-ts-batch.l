;;; Usage: xyzzy-batch.exe -q -load lisp/test-ts-batch.l
;;; Exit codes: 0=all pass, 10=T1-fail, 20=T2-error, 21=T2-nil, 30=T3-fail, 99=setup-fail
(setq *post-startup-hook*
      #'(lambda ()
          (handler-case
              (let* ((dll  (merge-pathnames "tree-sitter-c.dll" (si:system-root)))
                     (g    (si:load-ts-grammar dll "c"))
                     (q    "(comment) @comment
(string_literal) @string
(preproc_include) @include
(call_expression function: (identifier) @function.call)"))

                ;; helper: poll until spans or max-tries
                (labels ((poll (buf &optional sr er (n 200))
                           (let (r)
                             (dotimes (_ n r)
                               (setq r (if sr
                                           (si:ts-query-buffer g q buf sr er)
                                         (si:ts-query-buffer g q buf)))
                               (when r (return r))))))

                  ;; T1: full-buffer
                  (let* ((buf (create-new-buffer "*ts-t1*"))
                         (spans (progn
                                  (save-excursion (set-buffer buf) (insert "#include <stdio.h>"))
                                  (poll buf))))
                    (unless spans (kill-xyzzy 10)))

                  ;; T2: range query - two calls, second should return spans
                  (let ((buf (create-new-buffer "*ts-t2*")))
                    (save-excursion (set-buffer buf) (insert "#include <stdio.h>"))
                    ;; call1: launch bg thread (expect nil or spans)
                    (handler-case (si:ts-query-buffer g q buf 0 40)
                      (condition (e) (kill-xyzzy 20)))
                    ;; poll for results
                    (let ((spans (poll buf 0 40)))
                      (unless spans (kill-xyzzy 21))))

                  ;; T3: multi-line
                  (let* ((buf (create-new-buffer "*ts-t3*"))
                         (spans (progn
                                  (save-excursion
                                    (set-buffer buf)
                                    (insert "#include <stdio.h>\nint main() { printf(\"x\"); return 0; }"))
                                  (poll buf))))
                    (unless spans (kill-xyzzy 30))))

                (kill-xyzzy 0))
            (condition (e)
              (kill-xyzzy 99)))))
