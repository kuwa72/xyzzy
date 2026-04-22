;; GUI test runner - runs unit tests with results visible in a buffer.
;; Usage: XYZZYHOME=/path/to/xyzzy xyzzy.exe -q -load misc/run-tests-gui.l

(setq *post-startup-hook*
      #'(lambda ()
          ;; Load the test framework
          (load-file (merge-pathnames "unittest/simple-test.l"
                                      (si:system-root)))

          ;; Load all *-tests.l from unittest/
          (let ((unittest-dir (merge-pathnames "unittest/" (si:system-root)))
                (skip-files '("ole-tests.l" "sequence-tests.l"
                              "stream-tests.l" "system-tests.l"
                              "pathnames-tests.l")))
            (handler-case
                (dolist (f (sort (directory unittest-dir
                                           :absolute t :wild "*-tests.l")
                                 #'string-lessp))
                  (if (member (file-namestring f) skip-files :test #'string=)
                      (test-message "~A [SKIPPED]" f)
                    (load-test-file f)))
              (condition (e)
                (test-message "ERROR loading tests: ~A" e)))
            ;; Also load foreign-test.l
            (let ((foreign-test (merge-pathnames "unittest/foreign-test.l"
                                                 (si:system-root))))
              (handler-case
                  (load-test-file foreign-test)
                (condition (e)
                  (test-message "ERROR loading foreign-test.l: ~A" e)))))

          ;; Patch warn for safety
          (setf (symbol-function 'warn)
                #'(lambda (fmt &rest args)
                    (apply #'format t
                           (concatenate 'string "~&;; WARNING: " fmt "~%")
                           args)
                    nil))

          ;; Run all tests - results go to the test report buffer
          (run-all-tests)))
