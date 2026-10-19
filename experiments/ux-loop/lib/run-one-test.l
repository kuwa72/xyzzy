;;; Run one unittest file on the linux --batch build and print the results.
;;;   tools/x run env XYZZYHOME=/work _build/linux/xyzzy --batch \
;;;     -load experiments/ux-loop/lib/run-one-test.l -e '(run-one "errors-tests")'
(defun run-one (stem)
  (load "unittest/simple-test.l")
  (load-test-file (format nil "unittest/~A.l" stem))
  (run-tests (reverse *tests*))
  (let ((b (find-buffer "*Test Results*")))
    (when b
      (save-excursion
	(set-buffer b)
	(format *standard-output* "~A"
		(buffer-substring (point-min) (point-max))))))
  (kill-xyzzy))
