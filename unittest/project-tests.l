;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Tests for Project Management (project.l)
;;;

(require "unittest")
(require "leader")
(require "project")

(in-package "editor")

(defun test-project-root-detection ()
  ;; 現在のリポジトリルート（CMakeLists.txt や .git がある）を正しく検出できるか
  (let ((root (project-current-root (si:system-root))))
    (assert-true (stringp root))
    (assert-true (file-exist-p (merge-pathnames "CMakeLists.txt" root)))))

(defun test-project-remember-list ()
  (let ((*project-list* nil))
    (project-remember-project "Z:/work/")
    (project-remember-project "Z:/foo/bar/")
    (assert-equal 2 (length *project-list*))
    ;; 重複追加の防止
    (project-remember-project "Z:/work/")
    (assert-equal 2 (length *project-list*))
    (assert-equal "Z:/work/" (car *project-list*))))

(defun test-project-list-files ()
  (let* ((root (project-current-root (si:system-root)))
	 (files (project-list-files root)))
    (assert-true (consp files))
    ;; lisp/defs.l や CMakeLists.txt が含まれているか
    (assert-true (member "CMakeLists.txt" files :test #'string-equal))
    ;; .git ディレクトリの中身は無視されているか
    (assert-false (some #'(lambda (f) (string-match "^\\.git/" f)) files))))

(defun test-project-leader-bindings ()
  (assert-equal 'project-find-file (lookup-keymap *leader-project-map* #\f))
  (assert-equal 'project-grep (lookup-keymap *leader-project-map* #\g))
  (assert-equal 'project-filer (lookup-keymap *leader-project-map* #\d))
  (assert-equal 'project-open-terminal (lookup-keymap *leader-project-map* #\t))
  (assert-equal 'project-switch-project (lookup-keymap *leader-project-map* #\p)))

(defun run-project-unit-tests ()
  (format t "Running project unit tests...~%")
  (test-project-root-detection)
  (test-project-remember-list)
  (test-project-list-files)
  (test-project-leader-bindings)
  (format t "All project unit tests PASSED.~%"))

(run-project-unit-tests)
