;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; このファイルは長く ASCII のみだったので encoding マーカーが無かった。
;;; **マーカー無しで日本語を書くと、読み込み時に文字列やコメントが壊れて
;;; ファイルが途中で終わる** (cp932 として読まれ、多バイト文字の後半が
;;; 改行を食う)。しかもそれは「テストが 1 件も走らない」という形で出るので、
;;; 足しておく。
(deftest test-make-array-0 ()
  (equalp
   #()
   (make-array 0))
  => t)

(deftest test-make-array-1-1 ()
  (equalp
   #2A((nil))
   (make-array (list 1 1)))
  => t)

(deftest test-make-array-4-1 ()
  (equalp
   #2A((nil) (nil) (nil) (nil))
   (make-array (list 4 1)))
  => t)

(deftest test-make-array-4-2 ()
  (equalp
   #2A((nil nil) (nil nil) (nil nil) (nil nil))
   (make-array (list 4 2)))
  => t)


(deftest test-make-large-array-1 ()
  (make-array (list (expt 2 29) 1))
  !! program-error)

(deftest test-make-large-array-2 ()
  (make-array (list (expt 2 29) 2))
  !! program-error)

(deftest test-make-large-array-3 ()
  (make-array (list (expt 2 30) 1))
  !! program-error)

(deftest test-make-large-array-4 ()
  (make-array (list (- (expt 2 31) 1) 1))
  !! program-error)

(defun array-test-make-refused-p (dims)
  "DIMS で make-array が拒否されるか。

**どの条件が飛ぶかは fixnum の幅で変わる。** fixnum は long と同じ幅なので、
Windows (long は 32bit) では 2^31 が fixnum ではなく fixnum_value が
range-error を出し、64bit の POSIX では fixnum なので配列側の program-error に
なる。**作れないことが要点**なので、種類ではなく拒否されたことを見る。
deftest の本文に handler-case を直接書くと、節が別々のテスト式として
扱われてしまうので、関数に出してある。"
  (handler-case (progn (make-array dims) nil)
    (range-error () t)
    (program-error () t)))

(deftest test-make-large-array-5 ()
  (array-test-make-refused-p (list (expt 2 31) 1))
  => t)

(deftest test-make-large-array-6 ()
  (make-array (list (expt 2 64) 10))
  !! range-error)
