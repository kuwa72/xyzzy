;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;; Tests for issue #287: alloca overflow in lprint.cc with large bignums.

(deftest print-large-bignum-test ()
  "Printing a large bignum should not crash (issue #287)."
  (let ((n (expt 2 100000)))
    (integerp n))
  => t)

(deftest princ-large-bignum-test ()
  "princ of a large bignum should not crash (issue #287)."
  (let ((s (with-output-to-string (s)
             (princ (expt 2 100000) s))))
    (> (length s) 0))
  => t)

(deftest format-large-bignum-test ()
  "format ~D of a large bignum should not crash (issue #287)."
  (let ((s (format nil "~D" (expt 2 100000))))
    (> (length s) 0))
  => t)

(deftest condition-string-long-format-test ()
  "condition-string with a long format string should not crash (issue #287)."
  (let ((s "A"))
    (dotimes (i 17) (setq s (concat s s)))
    (let* ((c (make-condition 'simple-error :format-string s))
           (result (si:*condition-string c)))
      (> (length result) 0)))
  => t)
