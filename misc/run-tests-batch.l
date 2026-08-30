;; Batch test runner - runs unit tests and exits with pass(0)/fail(1)
;; Usage: xyzzy-batch -q -load misc/run-tests-batch.l
;;        (run from XYZZYHOME/repo-root directory)
;;
;; Output format: test-name...OK  /  test-name...Failed
;; Goes to *terminal-io* (console stdout or pipe for CI).

(setq *post-startup-hook*
      #'(lambda ()
          ;; Connect *standard-output* to *terminal-io* so output goes to
          ;; the console (or to the pipe/redirect when captured by cmake/CI).
          (setq *standard-output* *terminal-io*)

          ;; Use cwd as the base directory. The test runner is always invoked
          ;; from the repo root, so (cwd) points there regardless of whether
          ;; XYZZYHOME is set (si:system-root falls back to exe dir otherwise).
          (let ((base-dir (cwd)))

            ;; Load the test framework
            (load (merge-pathnames "unittest/simple-test.l" base-dir))

            ;; Override get-report-buffer-stream: use stdout instead of
            ;; opening a GUI buffer.  The format calls in simple-test.l
            ;; write "test-name...OK/Failed" directly to this stream.
            (setf (symbol-function 'get-report-buffer-stream)
                  #'(lambda () *standard-output*))

            ;; Suppress test-message (GUI status bar) to avoid duplicate
            ;; progress lines alongside the format output above.
            (setf (symbol-function 'test-message)
                  #'(lambda (&rest args) nil))

            ;; Known failures.  XYZZY_TEST_KNOWN_FAILURES holds a comma
            ;; separated list of files, each one test name per line with # for a
            ;; comment; see misc/known-failures/README.md.  The suite is then
            ;; gated on everything outside that list, which is what lets CI stop
            ;; running it as informational: a test that fails without being
            ;; listed fails the run, and so does one that is listed and passes,
            ;; because a list nobody prunes stops meaning anything.
            ;;
            ;; With the variable unset nothing changes: any failure exits 1.
            ;; Where a comment starts on a line, or nil.
            ;;
            ;; **A test name can contain #.**  There is one called
            ;; |fix (cdr '#1='#1#) printing|, and cutting the line at the first
            ;; # read it as "fix (cdr '" -- so the name could not be listed at
            ;; all and the run stayed red no matter what was written here.
            ;; Only a # at the start of a line or right after whitespace begins
            ;; a comment; every # inside that name is preceded by ' or a digit.
            (defun batch-comment-start (line)
              (dotimes (i (length line))
                (when (and (char= (char line i) #\#)
                           (or (zerop i)
                               (member (char line (1- i)) '(#\SPC #\TAB))))
                  (return i))))

            (defun batch-read-known-failures (spec base)
              (let ((names nil))
                (dolist (path (split-string spec #\, nil " "))
                  (let ((file (merge-pathnames path base)))
                    (if (not (file-exist-p file))
                        (format *standard-output*
                                ";; WARNING: no such known-failures file: ~A~%" file)
                      (with-open-file (in file :direction :input)
                        (loop
                          (let ((line (read-line in nil nil)))
                            (unless line (return))
                            ;; read-line drops the newline; a file written on
                            ;; Windows still leaves the CR behind.
                            (let* ((hash (batch-comment-start line))
                                   (name (string-trim
                                          " \t\r\n"
                                          (if hash (subseq line 0 hash) line))))
                              (when (plusp (length name))
                                (pushnew name names :test #'string-equal)))))))))
                (nreverse names)))

            ;; A test is in ssn-finished-tests as (TEST (EXAMPLE . FAILURES)...),
            ;; so the names can be read straight off it.  Deriving them here
            ;; rather than by grepping the output matters: on mingw x86_64 the
            ;; run reports ten failures and prints only nine "...Failed" lines,
            ;; so the log is not a reliable list of what failed.
            (defun batch-test-results ()
              (let ((failed nil) (passed nil))
                (dolist (entry (ssn-finished-tests))
                  (let ((name (string-downcase (string (test-name (car entry))))))
                    (if (some #'cdr (cdr entry))
                        (push name failed)
                      (push name passed))))
                (values (sort failed #'string-lessp) (sort passed #'string-lessp))))

            (defun batch-report-names (label names)
              (when names
                (format *standard-output* "=== ~A ~D: ~{~A~^ ~} ===~%"
                        label (length names) names)))

            (defvar *batch-known-failures* nil)
            (setq *batch-known-failures*
                  (let ((spec (si:getenv "XYZZY_TEST_KNOWN_FAILURES")))
                    (and spec (plusp (length spec))
                         (batch-read-known-failures spec base-dir))))

            ;; Rewrite a list from an actual run instead of editing it by hand.
            ;; Every comment in the file is lost, so this is the start of an
            ;; edit, not a substitute for one.  It always exits 0, which is also
            ;; what keeps it from being left on in CI by accident.
            (defvar *batch-update-known-failures* nil)
            (setq *batch-update-known-failures*
                  (let ((path (si:getenv "XYZZY_TEST_UPDATE_KNOWN_FAILURES")))
                    (and path (plusp (length path)) path)))

            ;; Track exit code via finish hook (called before *current-session*
            ;; is cleared, so we can still read ssn-fail-count).
            (defvar *batch-exit-code* nil)

            ;; A file that fails to load is a failure.  It used to print
            ;; "ERROR loading ..." and nothing else: the exit code was
            ;; unaffected and the known-failures gate never saw it, so
            ;; unittest/formatter-tests.l (an undefined character name) and
            ;; unittest/leader-tests.l (a stale assertion) sat there running
            ;; *none* of their tests while the suite reported green.  A whole
            ;; file dropping out is worse than one test failing, not better.
            (defvar *batch-load-errors* nil)
            (defun batch-load-error (name e)
              (push name *batch-load-errors*)
              (format *standard-output* "ERROR loading ~A: ~A~%" name e))

            (setq *tests-run-finish-hook*
                  #'(lambda (pass fail total)
                      (multiple-value-bind (failed passed) (batch-test-results)
                        (cond
                         (*batch-update-known-failures*
                          (let ((file (merge-pathnames *batch-update-known-failures*
                                                       base-dir)))
                            (with-open-file (out file :direction :output
                                                 :if-exists :supersede
                                                 :if-does-not-exist :create)
                              (format out "# Written by XYZZY_TEST_UPDATE_KNOWN_FAILURES.~%")
                              (format out "# Say why each of these fails; see README.md.~%")
                              (format out "~{~A~%~}" failed))
                            (format *standard-output*
                                    "=== wrote ~D names to ~A ===~%"
                                    (length failed) file))
                          (setq *batch-exit-code* 0))
                         ((null *batch-known-failures*)
                          (setq *batch-exit-code*
                                (if (and (zerop fail) (null *batch-load-errors*)) 0 1)))
                         (t
                          (let ((unexpected (set-difference failed *batch-known-failures*
                                                            :test #'string-equal))
                                (fixed (intersection passed *batch-known-failures*
                                                     :test #'string-equal))
                                (not-run (set-difference *batch-known-failures*
                                                         (append failed passed)
                                                         :test #'string-equal)))
                            (format *standard-output*
                                    "=== known failures: ~D listed, ~D matched ===~%"
                                    (length *batch-known-failures*)
                                    (- (length failed) (length unexpected)))
                            (batch-report-names "unexpected failures" unexpected)
                            (batch-report-names "now passing, remove from the list" fixed)
                            ;; Not a failure: the exclude lists keep a few tests
                            ;; from running at all, and a name can legitimately
                            ;; be listed for a target that skips it.
                            (batch-report-names "listed but did not run" not-run)
                            ;; Files that failed to load count too.  This hook
                            ;; runs last, so without them here it would write
                            ;; the load errors back out of the exit code.
                            (setq *batch-exit-code*
                                  (if (and (null unexpected) (null fixed)
                                           (null *batch-load-errors*))
                                      0 1))))))))

            ;; What to leave out.  A name ending in .l skips a whole file, any
            ;; other name skips that one test, and XYZZY_TEST_EXCLUDE (comma
            ;; separated) replaces the list so CI can vary it per platform.
            ;; XYZZY_TEST_EXCLUDE_EXTRA adds to it instead of replacing it, for
            ;; a platform that has to skip a few more without restating these.
            ;;
            ;; These used to be five whole files, which cost every other test
            ;; in them.  A crashing test takes the process down, so it does have
            ;; to be kept out -- but only that test.
            ;;
            ;;   test-ole-reader-macro-args                      ARM64 segfault, #{} OLE parser
            ;;   make-vector--fill-pointer-and-initial-contents  ARM64 segfault
            ;;   test-print-debug-output-stream                  ARM64 segfault
            ;;   sha-224                                         ARM64 segfault, SHA implementation
            ;;   fix-ole-event-sink-load-typelib                 use after free: trips
            ;;     "Assertion failed: src/lisp.h: 202" in object_typeof, i.e. reads the tag of
            ;;     an object the allocator has free.  Reproduces on i686 and x86_64 under Wine.
            ;;   shell-operation-move-multi                      crash inside
            ;;     SHFileOperationW (FO_MOVE with several sources and one
            ;;     destination directory).  shell-operation-copy-multi does the
            ;;     same thing with FO_COPY and passes, and move-multi2 passes
            ;;     too, so it is that one call.  This used to exclude the whole
            ;;     of pathnames-tests.l, which cost the other 15 tests in it.
            ;;     **Excluded on Win32 only.**  The crash is inside the Win32
            ;;     shell call; the POSIX build implements si:*file-operation
            ;;     with plain file operations (src/core/pathname.cc) and has
            ;;     nothing to crash in, so it runs the test.
            (defvar *batch-default-exclude*
              (append
               '("test-ole-reader-macro-args"
                 "make-vector--fill-pointer-and-initial-contents"
                 "test-print-debug-output-stream"
                 "sha-224"
                 "fix-ole-event-sink-load-typelib")
               #+ncurses '()
               #-ncurses '("shell-operation-move-multi")))
            (defvar *batch-excluded* nil)
            (defvar *batch-exclude* nil)
            (setq *batch-exclude*
                  (let ((env (si:getenv "XYZZY_TEST_EXCLUDE")))
                    (if (and env (plusp (length env)))
                        (split-string env #\, nil " ")
                      *batch-default-exclude*)))
            (let ((extra (si:getenv "XYZZY_TEST_EXCLUDE_EXTRA")))
              (when (and extra (plusp (length extra)))
                (setq *batch-exclude*
                      (append *batch-exclude* (split-string extra #\, nil " ")))))
            (defun batch-excluded-p (name)
              (find name *batch-exclude* :test #'string-equal))

            ;; Load all *-tests.l from unittest/
            (let ((unittest-dir (merge-pathnames "unittest/" base-dir)))
              (format *standard-output*
                      "=== Loading tests from ~A ===~%" unittest-dir)
              (format *standard-output* "=== Excluding: ~{~A~^ ~} ===~%" *batch-exclude*)
              ;; Each file gets its own handler-case: one broken *-tests.l must
              ;; not take every alphabetically-later file down with it silently.
              (dolist (f (sort (directory unittest-dir
                                          :absolute t :wild "*-tests.l")
                                #'string-lessp))
                (if (batch-excluded-p (file-namestring f))
                    (progn
                      (push (file-namestring f) *batch-excluded*)
                      (format *standard-output* "  ~A [SKIPPED]~%" f))
                  (progn
                    (format *standard-output* "  ~A~%" f)
                    (handler-case
                        (load-test-file f)
                      (condition (e)
                        (batch-load-error (file-namestring f) e))))))
              ;; Also load foreign-test.l (named *-test.l not *-tests.l).
              ;; It goes through the same exclude check as the rest: it was the
              ;; one file a platform could not skip.
              (let ((foreign-test (merge-pathnames "unittest/foreign-test.l" base-dir)))
                (handler-case
                    (if (batch-excluded-p "foreign-test.l")
                        (progn
                          (pushnew "foreign-test.l" *batch-excluded* :test #'string=)
                          (format *standard-output* "  ~A [SKIPPED]~%" foreign-test))
                      (progn
                        (format *standard-output* "  ~A~%" foreign-test)
                        (load-test-file foreign-test)))
                  (condition (e)
                    (batch-load-error "foreign-test.l" e)))))

            ;; Patch warn to print-and-return rather than signal a condition.
            ;; In batch mode there is no interactive debugger, so unhandled
            ;; warnings would abort run-all-tests.  Tests that trigger warn
            ;; (e.g. defstruct :print-function #'sym) can still run to completion.
            (setf (symbol-function 'warn)
                  #'(lambda (fmt &rest args)
                      (apply #'format *standard-output*
                             (concatenate 'string "~&;; WARNING: " fmt "~%")
                             args)
                      nil))

            ;; The command line for spawning ourselves as a child now lives in
            ;; unittest/simple-test.l (test-self-command).  It used to be
            ;; overridden here because the version there hardcoded "xyzzy.exe",
            ;; which does not exist on POSIX -- two places building the same
            ;; command line, and only one of them knew about --batch.
            (format *standard-output*
                    "=== Subprocess tests will use: ~A ===~%"
                    (test-self-command))
            ;; Run everything that was not excluded by name.  run-all-tests
            ;; would take *tests* whole, so the list is filtered here.
            (format *standard-output* "=== Running tests ===~%")
            (let ((tests (remove-if #'(lambda (test)
                                        (let ((name (string (test-name test))))
                                          (when (batch-excluded-p name)
                                            (pushnew name *batch-excluded*
                                                     :test #'string=)
                                            t)))
                                    (reverse *tests*))))
              (handler-case
                  (run-tests tests)
                (condition (e)
                  (format *standard-output* "~%=== ERROR during tests: ~A ===~%" e)
                  (setq *batch-exit-code* 1))))
            ;; Say it at the end as well: none of the tests in a file that
            ;; failed to load ran at all, so the pass count on its own lies.
            (when *batch-load-errors*
              (format *standard-output* "=== files that failed to load ~D: ~{~A~^ ~} ===~%"
                      (length *batch-load-errors*) (reverse *batch-load-errors*)))
            ;; Say it again at the end: a pass that skipped things should not
            ;; read as a clean pass.
            (when *batch-excluded*
              (format *standard-output* "=== Skipped ~D: ~{~A~^ ~} ===~%"
                      (length *batch-excluded*) (reverse *batch-excluded*))))

          ;; Exit with determined exit code (0=all pass, 1=some fail/error)
          (kill-xyzzy (or *batch-exit-code* 1))))
