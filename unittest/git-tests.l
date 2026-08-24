;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Tests for Git and Toggle Terminal
;;;

(unless (member "test-helpers" *modules* :test #'string=)
  (load-file (merge-pathnames "test-helpers.l" (directory-namestring *load-pathname*))))
(require "leader")
(require "project")
(require "terminal")
(require "git")

(in-package "editor")

(defun test-git-commands-exist ()
  (assert-true (fboundp 'git-status))
  (assert-true (fboundp 'git-diff))
  (assert-true (fboundp 'git-log))
  (assert-true (fboundp 'git-blame))
  (assert-true (fboundp 'git-status-mode)))

(defun test-git-status-mode-map ()
  (assert-true (keymapp *git-status-mode-map*))
  (assert-equal 'kill-selected-buffer (lookup-keymap *git-status-mode-map* #\q))
  (assert-equal 'git-status (lookup-keymap *git-status-mode-map* #\g))
  (assert-equal 'git-diff (lookup-keymap *git-status-mode-map* #\d))
  (assert-equal 'git-log (lookup-keymap *git-status-mode-map* #\l)))

(defun test-toggle-terminal ()
  (assert-true (fboundp 'toggle-terminal-drawer))
  (assert-equal 'toggle-terminal-drawer (lookup-keymap *leader-toggle-map* #\t)))

(defun test-git-leader-bindings ()
  (assert-equal 'git-status (lookup-keymap *leader-git-map* #\s))
  (assert-equal 'git-diff (lookup-keymap *leader-git-map* #\d))
  (assert-equal 'git-log (lookup-keymap *leader-git-map* #\l))
  (assert-equal 'git-blame (lookup-keymap *leader-git-map* #\b)))

(defun run-git-unit-tests ()
  (format t "Running git & terminal unit tests...~%")
  (test-git-commands-exist)
  (test-git-status-mode-map)
  (test-toggle-terminal)
  (test-git-leader-bindings)
  (format t "All git & terminal unit tests PASSED.~%"))

(run-git-unit-tests)
