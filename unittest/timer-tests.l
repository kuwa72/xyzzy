;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `start-timer` / `stop-timer` のテスト (src/core/utimer.cc)。
;;;
;;; **POSIX ではこれが丸ごと動いていなかった** (`Fstart_timer` が nil を返す
;;; スタブ)。既知失敗は `fix-start-timer` の 1 件だけだったが、実際には
;;; `lisp/ts.l` の tree-sitter ハイライトの遅延更新と `lisp/grepd.l` の
;;; 非同期 grep が黙って動かなかった。**1 件の既知失敗の裏に、測られていない
;;; 機能が 2 つあった。**
;;;
;;; **待つのは `sleep-for`。** Win32 はその間メッセージループを回すのでタイマが
;;; 動く。POSIX も同じになるように `sleep-for` / `sit-for` が期限の来たものを
;;; 呼ぶ (src/frontend/ncurses/ncurses-process.cc)。
;;;
;;; 刻みは小さく取る (0.05 秒)。**実時間を待つテストなので、長いとスイート
;;; 全体が遅くなる。**

(defun timer-test-wait (predicate limit)
  "PREDICATE が真になるまで待つ。LIMIT 秒で諦める。真になったら t。"
  (let ((start (get-internal-real-time)))
    (loop
      (when (funcall predicate)
        (return t))
      (when (> (- (get-internal-real-time) start) (* limit 1000))
        (return nil))
      (sleep-for 0.02))))

;; 1 回だけのタイマが 1 回だけ呼ばれること。
(deftest timer-one-shot-fires-once ()
  (let ((n 0))
    (flet ((tick () (incf n)))
      (start-timer 0.05 #'tick t)
      (unwind-protect
          (progn
            (timer-test-wait #'(lambda () (plusp n)) 3)
            ;; **もう 1 回来ないことを確かめる。** :one-shot-p が効いて
            ;; いなければここで増える。
            (sleep-for 0.2)
            n)
        (stop-timer #'tick))))
  => 1)

;; 繰り返すタイマが何度も呼ばれること。
(deftest timer-repeats ()
  (let ((n 0))
    (flet ((tick () (incf n)))
      (start-timer 0.05 #'tick)
      (unwind-protect
          (and (timer-test-wait #'(lambda () (>= n 3)) 3) t)
        (stop-timer #'tick))))
  => t)

;; `stop-timer` で止まること。**止まらないと、テストのあとも呼ばれ続ける。**
(deftest timer-can-be-stopped ()
  (let ((n 0))
    (flet ((tick () (incf n)))
      (start-timer 0.05 #'tick)
      (timer-test-wait #'(lambda () (plusp n)) 3)
      (let ((stopped (and (stop-timer #'tick) t))
            (before n))
        (sleep-for 0.3)
        (list stopped (= before n)))))
  => (t t))

;; 知らない関数を止めようとしたら nil。
(deftest timer-stopping-an-unknown-function-is-nil ()
  (and (stop-timer #'(lambda () nil)) t)
  => nil)

;; **`sleep-for` で待っている間に呼ばれること。** ここが POSIX で壊れていた:
;; 1 回の `select` で寝てしまうと、待っている間はタイマが動かない。
(deftest timer-fires-during-sleep-for ()
  (let ((n 0))
    (flet ((tick () (incf n)))
      (start-timer 0.05 #'tick)
      (unwind-protect
          (progn
            ;; **1 回だけ長く寝る** (timer-test-wait のように細かく回さない)。
            ;; 待ちを刻んでいるのが呼び出し側ではなく sleep-for 自身である
            ;; ことを見たいので。
            (sleep-for 0.4)
            (plusp n))
        (stop-timer #'tick))))
  => t)
