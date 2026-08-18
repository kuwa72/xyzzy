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

(defun batch-test-results-text ()
  (let ((buffer (find-buffer "*Test Results*")))
    (and buffer
         (save-excursion
           (set-buffer buffer)
           (buffer-substring (point-min) (point-max))))))

(defun batch-write-report (text)
  (with-open-file (out (batch-test-report-file) :direction :output
                       :if-exists :supersede :if-does-not-exist :create)
    (princ (or text "no *Test Results* buffer") out)))

(defun batch-run-all-tests ()
  (load-file (merge-pathnames "simple-test.l" *batch-test-directory*))
  (let ((*error-on-overwriting-test* t))
    (dolist (file (sort (directory *batch-test-directory*
                                  :absolute t :recursive t :wild "*-tests.l")
                        #'string-lessp))
      (load-test-file file)))
  (run-all-tests)
  ;; The runner can finish inside run-all-tests or keep going from a timer, so
  ;; the message loop has to keep running until the session is over.
  (let ((deadline (+ (get-internal-real-time) (batch-test-timeout))))
    (while (and *current-session*
                (< (get-internal-real-time) deadline))
      (sleep-for 0.2)))
  ;; The summary line the runner writes is the result: reading it works whether
  ;; the session object is still around or not.
  (let ((text (batch-test-results-text)))
    (batch-write-report text)
    (kill-xyzzy (cond ((null text) 3)                          ; nothing ran
                      ((string-match ": All passed" text) 0)
                      ((string-match " failed" text) 1)
                      (t 2)))))                                ; no summary yet
