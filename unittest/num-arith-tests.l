;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(deftest test-number-negate-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (- shortint)
     (- longint)
     (- bignum)))
  => -2
  => -1073741824
  => -4294967296)

(deftest test-number-add-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (+ shortint shortint)
     (+ shortint longint)
     (+ shortint bignum)
     (+ longint shortint)
     (+ longint longint)
     (+ longint bignum)
     (+ bignum shortint)
     (+ bignum longint)
     (+ bignum bignum)
     ))
  => 4
  => 1073741826
  => 4294967298
  => 1073741826
  => 2147483648
  => 5368709120
  => 4294967298
  => 5368709120
  => 8589934592)

(deftest test-number-subtract-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (- shortint shortint)
     (- shortint longint)
     (- shortint bignum)
     (- longint shortint)
     (- longint longint)
     (- longint bignum)
     (- bignum shortint)
     (- bignum longint)
     (- bignum bignum)
     ))
  => 0
  => -1073741822
  => -4294967294
  => 1073741822
  => 0
  => -3221225472
  => 4294967294
  => 3221225472
  => 0)

(deftest test-number-multiply-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (* shortint shortint)
     (* shortint longint)
     (* shortint bignum)
     (* longint shortint)
     (* longint longint)
     (* longint bignum)
     (* bignum shortint)
     (* bignum longint)
     (* bignum bignum)
     ))
  => 4
  => 2147483648
  => 8589934592
  => 2147483648
  => 1152921504606846976
  => 4611686018427387904
  => 8589934592
  => 4611686018427387904
  => 18446744073709551616)

(deftest test-number-divide-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (/ shortint shortint)
     (/ shortint longint)
     (/ shortint bignum)
     (/ longint shortint)
     (/ longint longint)
     (/ longint bignum)
     (/ bignum shortint)
     (/ bignum longint)
     (/ bignum bignum)
     ))
  => 1
  => 1/536870912
  => 1/2147483648
  => 536870912
  => 1
  => 1/4
  => 2147483648
  => 4
  => 1)

(deftest test-fix-number-int64 ()
  (let ((shortint 2)
        (longint (expt 2 30))
        (bignum (expt 2 32)))
    (values
     (mod shortint -1)
     (mod longint -1)
     (mod bignum -1)
     ))
  => 0
  => 0
  => 0)

;;; upstream: xyzzy-022/xyzzy#422
;;; 型の幅以上のシフトは未定義で、x86 はシフト量をマスクするため
;;; (ash 64 -64) が 64 を返していた。

(deftest test-ash-right-beyond-width ()
  (values
   (ash 64 -6)
   (ash 64 -7)
   (ash 64 -32)
   (ash 64 -64)
   (ash 64 -1000)
   (ash -64 -32)
   (ash -64 -64)
   (ash (expt 2 40) -64)
   (ash (- (expt 2 40)) -64))
  => 1
  => 0
  => 0
  => 0
  => 0
  => -1
  => -1
  => 0
  => -1)

;;; 右シフトでリムを全部落とす場合。リム数を超えて読んでいたため、
;;; bignum_rep が使い回されていると残っていた値が結果に出ていた。

(deftest test-ash-right-drop-all-limbs ()
  (values
   (ash (expt 2 40) -48)
   (ash (- (expt 2 40)) -48)
   (ash (expt 2 64) -80)
   (ash (- (expt 2 64)) -80))
  => 0
  => -1
  => 0
  => -1)

;;; fixnum の端での足し算・引き算・符号反転。**bignum へ上がるべき所で
;;; 黙って巻き戻っていた。**
;;;
;;; `long' の幅は処理系で変わる。`most-positive-fixnum' は Windows (LLP64) で
;;; 2^31-1、Linux (LP64) で 2^63-1。src/num-arith.d の整数どうしの足し算は
;;; `int64_t (x) + int64_t (y)` を計算していて、これは long が 32bit なら
;;; 必ず収まるが 64bit だと溢れる。例外にもならず、符号だけ反転した値が
;;; 返っていた:
;;;
;;;   (+ most-positive-fixnum 1)  =>  most-negative-fixnum
;;;   (- most-negative-fixnum 1)  =>  most-positive-fixnum
;;;   (abs most-negative-fixnum)  =>  most-negative-fixnum
;;;
;;; 掛け算の同じ穴は issue #49 で直したが、足し算・引き算・符号反転が
;;; 残っていた。
;;;
;;; **期待値を数値で書かない。** fixnum の幅がプラットフォームで違うので、
;;; 数値で書くと片方でしか意味を持たない。代わりに「大小関係」と
;;; 「既に正しいと分かっている掛け算との一致」で見る。

(deftest fixnum-boundary-add-goes-to-bignum ()
  (values
   ;; 溢れると most-negative-fixnum になるので、大小で捕まる
   (> (+ most-positive-fixnum 1) most-positive-fixnum)
   (> (1+ most-positive-fixnum) most-positive-fixnum)
   ;; 掛け算は既に正しいので、突き合わせれば値まで確かめられる
   (= (+ most-positive-fixnum most-positive-fixnum)
      (* most-positive-fixnum 2)))
  => t
  => t
  => t)

(deftest fixnum-boundary-subtract-goes-to-bignum ()
  (values
   (< (- most-negative-fixnum 1) most-negative-fixnum)
   (< (1- most-negative-fixnum) most-negative-fixnum)
   ;; mpf - mnf = 2*mpf + 1
   (= (- most-positive-fixnum most-negative-fixnum)
      (+ (* most-positive-fixnum 2) 1)))
  => t
  => t
  => t)

(deftest fixnum-boundary-negate-goes-to-bignum ()
  (values
   (plusp (- most-negative-fixnum))
   (plusp (abs most-negative-fixnum))
   ;; -mnf = mpf + 1
   (= (- most-negative-fixnum) (+ most-positive-fixnum 1))
   (= (abs most-negative-fixnum) (- most-negative-fixnum)))
  => t
  => t
  => t
  => t)
