;; Batch benchmark runner - runs misc/benchmark.l and exits.
;; Usage: xyzzy-batch.exe -q -load misc/benchmark-batch.l
;;        (run from XYZZYHOME/repo-root directory)
;;
;; Output goes to *standard-output* (console stdout, or a pipe/redirect
;; when captured by CI), the same convention as misc/run-tests-batch.l.

(setq *post-startup-hook*
      #'(lambda ()
          (setq *standard-output* *terminal-io*)
          (setq *post-startup-hook* nil)
          (handler-case
              (progn
                (load (merge-pathnames "misc/benchmark.l" (si:system-root))
                      :verbose nil)
                (funcall (read-from-string "benchmark:run-all"))
                (kill-xyzzy 0))
            (condition (e)
              (format *standard-output* "~%=== ERROR: ~A ===~%" e)
              (kill-xyzzy 1)))))
