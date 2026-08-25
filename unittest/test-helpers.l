;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; assert-true / assert-equal for *-tests.l files written in the ad-hoc
;;; defun+assert style (as opposed to the deftest/=> style in simple-test.l).
;;;

(provide "test-helpers")

(in-package "editor")

(export '(assert-true assert-false assert-equal))

(defmacro assert-true (form)
  `(unless ,form
     (error "assert-true failed: ~S" ',form)))

(defmacro assert-false (form)
  `(when ,form
     (error "assert-false failed: ~S" ',form)))

(defmacro assert-equal (expected form)
  `(let ((%expected ,expected) (%actual ,form))
     (unless (equal %expected %actual)
       (error "assert-equal failed: expected ~S but got ~S: ~S" %expected %actual ',form))))
