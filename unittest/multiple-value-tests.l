;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;; #16 Phase 2: 多値関連の ANSI CL 準拠テスト。
;;; C++ 実装 (src/core/eval.cc) の監査では実際の不整合は見つからなかった
;;; が、これらの意味論を検証するテストが一切無かったため追加する。

(deftest multiple-value-setq--primary-value ()
  ;; multiple-value-setq は最後に setq した変数の値ではなく、
  ;; フォームの第1値 (primary value) を返す。
  (let (a b)
    (values
     (multiple-value-setq (a b) (values 1 2))
     a
     b))
  => 1
  => 1
  => 2)

(deftest multiple-value-setq--extra-values-discarded ()
  (let (a b)
    (values
     (multiple-value-setq (a b) (values 1 2 3))
     a
     b))
  => 1
  => 1
  => 2)

(deftest multiple-value-setq--missing-values-become-nil ()
  (let (a b c)
    (values
     (multiple-value-setq (a b c) (values 1 2))
     a
     b
     c))
  => 1
  => 1
  => 2
  => nil)

(deftest multiple-value-prog1--returns-all-original-values ()
  ;; 最初のフォームの多値を丸ごと保持したまま返す。後続のフォームは
  ;; 副作用のためだけに評価され、戻り値には影響しない。
  (let (side-effect)
    (values
     (multiple-value-list
      (multiple-value-prog1
          (values 1 2 3)
        (setq side-effect t)
        (values 100 200)))
     side-effect))
  => (1 2 3)
  => t)

(deftest multiple-value-call--flattens-all-argument-values ()
  (values
   (multiple-value-call #'+ (values 1 2) (values 3 4))
   (multiple-value-call #'list 1 (values) 2 (values 3 4))
   (multiple-value-call #'list (values)))
  => 10
  => (1 2 3 4)
  => nil)

(deftest nth-value--basic ()
  (values
   (nth-value 0 (floor 7 2))
   (nth-value 1 (floor 7 2)))
  => 3
  => 1)

(deftest nth-value--out-of-range-is-nil ()
  (values
   (nth-value 5 (values 1 2 3))
   (nth-value 0 (values)))
  => nil
  => nil)

(deftest values-list--basic ()
  (values
   (multiple-value-list (values-list '(1 2 3)))
   (multiple-value-list (values-list nil)))
  => (1 2 3)
  => nil)

(deftest multiple-value-bind--basic ()
  (multiple-value-bind (q r) (floor 130 11)
    (list q r))
  => (11 9))

(deftest multiple-value-gc-roots-only-live-values ()
  (dotimes (i 10000)
    (multiple-value-prog1
        (values i (+ 100000000000000000000 i))
      (gc)))
  => nil)
