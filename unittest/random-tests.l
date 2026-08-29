;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(defun generate-random (n limit state)
  (let (nums)
    (dotimes (_ n)
      (push (random limit state) nums))
    nums))

(deftest random-limit ()
  (every #'(lambda (n) (and (<= 0 n) (< n 3)))
         (generate-random 1000 3 nil))
  => t)

;; **上限は fixnum の幅より十分大きく取る。** ここは 10^20 だったが、
;; fixnum の幅は `long' の幅なので**プラットフォームで変わる**:
;; Windows (LLP64) では 2^31 なので 10^20 の乱数は必ず bignum になるが、
;; Linux (LP64) では 2^63 = 約 9.2*10^18 で、10^20 の乱数が fixnum に
;; 収まる確率が 1/10.8 ≈ 9% ある。**実測で 2000 回中 177 回**。
;; つまり Linux の CI が 11 回に 1 回赤くなる flaky で、しかも
;; 「Linux だけ落ちる」ように見えるので環境の違いに見えてしまう。
;; 10^40 なら `long' が 128bit になっても当分持つ。
(deftest random-type ()
  (values
   (si:*fixnump (random 1))
   (si:*bignump (random 10000000000000000000000000000000000000000))
   (type-of (random 1.2))
   (type-of (random 1.2d3))
   (type-of (random 1/2)))
  => t
  => t
  => single-float
  => double-float
  => ratio)

(deftest random-state ()
  (let* ((s1 (make-random-state))
         (s2 (make-random-state t))
         (s3 (make-random-state s1)))
    (let ((r1 (generate-random 1000 100 s1))
          (r2 (generate-random 1000 100 s2))
          (r3 (generate-random 1000 100 s3)))
      (values
       (equal r1 r2)
       (equal r1 r3))))
  => nil
  => t)

(deftest random-state-seed ()
  "連続して random-state を生成しても異なる seed になること"
  (let* ((s1 (make-random-state t))
         (s2 (make-random-state t))
         (s3 (make-random-state t)))
    (let ((r1 (generate-random 1000 100 s1))
          (r2 (generate-random 1000 100 s2))
          (r3 (generate-random 1000 100 s3)))
      (values
       (equal r1 r2)
       (equal r1 r3))))
  => nil
  => nil)
