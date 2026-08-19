;;; -*- mode: lisp; package: user -*-
;;;
;;; Batch driver for the test suite: loads every *-tests.l, runs them, writes
;;; the report to the file named by the XYZZY_TEST_REPORT environment variable
;;; (default test-report.txt) and exits with a status that says whether
;;; everything passed.
;;;
;;;   xyzzy -q -l unittest/run-tests-batch.l -e "(user::batch-run-all-tests)"
;;;
;;; While it runs it also appends a line per test to the file named by
;;; XYZZY_TEST_PROGRESS, so that a run which stops making progress can be told
;;; apart from a slow one -- and so tools/run-tests.sh can name the test it
;;; stopped on.  The report is only written at the end, which is no help when
;;; the suite never gets there.
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

(defun batch-test-progress-file ()
  (si:getenv "XYZZY_TEST_PROGRESS"))

(defun batch-test-exclusions ()
  "Test files and test names named by XYZZY_TEST_EXCLUDE, comma separated.
Some tests need facilities the host does not have -- OLE automation against
Internet Explorer, say -- and a few of those wait for something that will
never happen, which stops the whole run rather than failing."
  (let ((s (si:getenv "XYZZY_TEST_EXCLUDE")))
    (and s (split-string s #\, t " "))))

(defun batch-excluded-p (name exclusions)
  (and exclusions (find name exclusions :test #'string-equal) t))

(defun batch-test-timeout ()
  ;; milliseconds
  (* 1000 (or (ignore-errors
                (parse-integer (or (si:getenv "XYZZY_TEST_TIMEOUT") "")))
              1800)))

;;; Progress log.  Reopened for every line: the reader is a tail -f in the
;;; shell, and there is no way to flush an open stream from lisp.

(defvar *batch-progress-start* nil)
(defvar *batch-skipped* nil)

(defun batch-log (fmt &rest args)
  (let ((file (batch-test-progress-file)))
    (when file
      (ignore-errors
        (with-open-file (out file :direction :output
                             :if-exists :append :if-does-not-exist :create)
          (format out "[~,1F] ~?~%"
                  (if *batch-progress-start*
                      (/ (- (get-internal-real-time) *batch-progress-start*)
                         internal-time-units-per-second)
                    0)
                  fmt args))))))

;;; The runner already narrates itself through test-message; sending the same
;;; text to the progress log gives one line per test without having to reach
;;; into the runner.
(defun batch-hook-test-message ()
  (let ((original (symbol-function 'test-message)))
    (setf (symbol-function 'test-message)
          #'(lambda (fmt &rest args)
              (apply #'batch-log fmt args)
              (apply original fmt args)))
    t))

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
  (setq *batch-progress-start* (get-internal-real-time))
  ;; A failing test rings the bell, and making noise is one more thing that can
  ;; block when there is no one at the console.
  (setq *beep-on-never* t)
  (batch-log "loading the test framework")
  (load-file (merge-pathnames "simple-test.l" *batch-test-directory*))
  (batch-hook-test-message)
  (let ((excluded (batch-test-exclusions))
        (skipped '()))
    (when excluded
      (batch-log "XYZZY_TEST_EXCLUDE: ~{~A~^ ~}" excluded))
    (let ((*error-on-overwriting-test* t))
      (dolist (file (sort (directory *batch-test-directory*
                                    :absolute t :recursive t :wild "*-tests.l")
                          #'string-lessp))
        (let ((name (file-namestring file)))
          (cond ((batch-excluded-p name excluded)
                 (push name skipped)
                 (batch-log "skipping ~A" name))
                (t
                 (batch-log "loading ~A" name)
                 (load-test-file file))))))
    (let ((tests (remove-if #'(lambda (test)
                                (let ((name (string (test-name test))))
                                  (when (batch-excluded-p name excluded)
                                    (pushnew name skipped :test #'string=)
                                    t)))
                            (reverse *tests*))))
      (setq *batch-skipped* (nreverse skipped))
      (batch-log "~D tests to run~@[, ~D skipped~]"
                 (length tests)
                 (and *batch-skipped* (length *batch-skipped*)))
      (run-tests tests)))
  ;; The runner can finish inside run-all-tests or keep going from a timer, so
  ;; the message loop has to keep running until the session is over.
  (let ((deadline (+ (get-internal-real-time) (batch-test-timeout))))
    (while (and *current-session*
                (< (get-internal-real-time) deadline))
      (sleep-for 0.2)))
  (batch-log "the run is over, writing the report")
  ;; The summary line the runner writes is the result: reading it works whether
  ;; the session object is still around or not.
  (let ((text (batch-test-results-text)))
    (batch-write-report
     (if *batch-skipped*
         (format nil "skipped by XYZZY_TEST_EXCLUDE: ~{~A~^ ~}~2%~A"
                 *batch-skipped* (or text ""))
       text))
    (let ((status (cond ((null text) 3)                          ; nothing ran
                        ((string-match ": All passed" text) 0)
                        ((string-match " failed" text) 1)
                        (t 2))))                                 ; no summary yet
      (batch-log "exiting with ~D" status)
      (kill-xyzzy status))))
