(let ((dir (if *load-pathname*
               (directory-namestring *load-pathname*)
             "."))
      (tests))
  (load-file (merge-pathnames "simple-test.l" dir))

  (defun process-command-line (arg)
    (cond ((string= "--run-all-tests" arg)
           (let ((*error-on-overwriting-test* t))
             (if tests
                 (dolist (test (reverse tests))
                   (load-test-file test))
               (dolist (test (sort (directory dir :absolute t :recursive t :wild "*-tests.l")
                                   #'string-lessp))
                 (load-test-file test))))
           ;(test-changes)
           (run-all-tests))
          (t
           (push (merge-pathnames arg *command-line-args-base-directory*)
                 tests))))

  (setq *tests-run-finish-hook*
        (lambda (pass fail total)
          (handler-case
              (with-open-file (out (merge-pathnames "build-clangarm64/test-results.txt"
                                                    (si:system-root))
                               :direction :output
                               :if-exists :supersede
                               :if-does-not-exist :create)
                (format out "Total ~D tests: ~D passed, ~D failed~%" total pass fail))
            (error ()))
          (kill-xyzzy (if (zerop fail) 0 1))))

  (add-hook '*process-command-line-hook* 'process-command-line)
  (setq si:*command-line-args* (append si:*command-line-args* (list "--run-all-tests")))
  )
