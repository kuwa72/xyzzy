;;; -*- mode: lisp; package: user -*-
;;;
;;; Batch driver for the test suite: loads every *-tests.l, runs them, writes
;;; the report to the file named by the XYZZY_TEST_REPORT environment variable
;;; (default test-report.txt) and exits with a status that says whether
;;; everything passed.
;;;
;;;   xyzzy -q -l unittest/run-tests-batch.l -e "(user::batch-run-all-tests)"
;;;
;;; run-tests.bat drives the same tests interactively instead; tools/run-tests.sh
;;; uses this one.

(in-package :user)

(defvar *batch-test-directory*
  (if *load-pathname*
      (directory-namestring *load-pathname*)
    "./unittest/"))

(defun batch-test-report-file ()
  (or (si:getenv "XYZZY_TEST_REPORT") "test-report.txt"))

(defun batch-test-timeout ()
  ;; milliseconds
  (* 1000 (or (ignore-errors
                (parse-integer (or (si:getenv "XYZZY_TEST_TIMEOUT") "")))
              1800)))

(defun batch-write-report (session)
  (with-open-file (out (batch-test-report-file) :direction :output
                       :if-exists :supersede :if-does-not-exist :create)
    (let ((buffer (find-buffer "*Test Results*")))
      (if buffer
          (princ (save-excursion
                   (set-buffer buffer)
                   (buffer-substring (point-min) (point-max)))
                 out)
        (format out "no *Test Results* buffer~%")))
    (when session
      (format out "~&pass=~D fail=~D~%"
              (session-pass-count session)
              (session-fail-count session)))))

(defun batch-run-all-tests ()
  (load-file (merge-pathnames "simple-test.l" *batch-test-directory*))
  (let ((*error-on-overwriting-test* t))
    (dolist (file (sort (directory *batch-test-directory*
                                  :absolute t :recursive t :wild "*-tests.l")
                        #'string-lessp))
      (load-test-file file)))
  (run-all-tests)
  ;; run-all-tests drives itself from a timer, so the message loop has to keep
  ;; running until the session is over.
  (let ((session *current-session*)
        (deadline (+ (get-internal-real-time) (batch-test-timeout))))
    (while (and *current-session*
                (< (get-internal-real-time) deadline))
      (sleep-for 0.2))
    (batch-write-report session)
    (kill-xyzzy (cond ((null session) 3)          ; nothing ran
                      (*current-session* 2)       ; timed out
                      ((zerop (session-fail-count session)) 0)
                      (t 1)))))
