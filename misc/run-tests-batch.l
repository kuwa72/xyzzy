;; Batch test runner - runs unit tests and exits with pass(0)/fail(1)
;; Usage: XYZZYHOME=/path/to/xyzzy xyzzy-batch -q -load misc/run-tests-batch.l
;;        (run from XYZZYHOME directory)
;;
;; Output format: test-name...OK  /  test-name...Failed
;; Goes to *terminal-io* (console stdout or pipe for CI).

(setq *post-startup-hook*
      #'(lambda ()
          ;; Connect *standard-output* to *terminal-io* so output goes to
          ;; the console (or to the pipe/redirect when captured by cmake/CI).
          (setq *standard-output* *terminal-io*)

          ;; Load the test framework
          (load-file (merge-pathnames "unittest/simple-test.l"
                                      (si:system-root)))

          ;; Override get-report-buffer-stream: use stdout instead of
          ;; opening a GUI buffer.  The format calls in simple-test.l
          ;; write "test-name...OK/Failed" directly to this stream.
          (setf (symbol-function 'get-report-buffer-stream)
                #'(lambda () *standard-output*))

          ;; Suppress test-message (GUI status bar) to avoid duplicate
          ;; progress lines alongside the format output above.
          (setf (symbol-function 'test-message)
                #'(lambda (&rest args) nil))

          ;; Track exit code via finish hook (called before *current-session*
          ;; is cleared, so we can still read ssn-fail-count).
          (defvar *batch-exit-code* nil)
          (setq *tests-run-finish-hook*
                #'(lambda (pass fail total)
                    (setq *batch-exit-code* (if (zerop fail) 0 1))))

          ;; Load all *-tests.l from unittest/
          (let ((unittest-dir (merge-pathnames "unittest/" (si:system-root))))
            (format *standard-output*
                    "=== Loading tests from ~A ===~%" unittest-dir)
            (handler-case
                (dolist (f (sort (directory unittest-dir
                                           :absolute t :wild "*-tests.l")
                                 #'string-lessp))
                  (format *standard-output* "  ~A~%" f)
                  (load-test-file f))
              (condition (e)
                (format *standard-output* "ERROR loading tests: ~A~%" e))))

          ;; Run all tests; catch errors that escape the test framework
          (format *standard-output* "=== Running tests ===~%")
          (handler-case
              (run-all-tests)
            (condition (e)
              (format *standard-output* "~%=== ERROR during tests: ~A ===~%" e)
              (setq *batch-exit-code* 1)))

          ;; Exit with determined exit code (0=all pass, 1=some fail/error)
          (kill-xyzzy (or *batch-exit-code* 1))))
