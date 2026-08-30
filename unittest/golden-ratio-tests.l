;;; -*- Encoding: utf-8 -*-
;;; 選択中のウィンドウを黄金比まで広げる (lisp/golden-ratio.l)。
;;;
;;; **「広げた結果の行数」を期待値に書かない。** 画面の大きさが環境で違う
;;; (CI の端末は 80x24、GUI はフォントで変わる) ので、数を書くとその環境
;;; でしか意味を持たない。代わりに次を見る:
;;;
;;;   * 既定では何もしないこと (勝手にレイアウトを動かさない)
;;;   * 入れると、選択中のウィンドウが「もう一方より広くなる」こと
;;;   * 目標の計算そのもの (画面の大きさ ÷ φ)
;;;   * 除外リストのバッファでは何もしないこと

(defun golden-test-cleanup ()
  (setq *golden-ratio-mode* nil)
  (ignore-errors (delete-other-windows)))

;; 目標の計算。**ここだけは数で書ける** (入力を自分で決められるので)。
(deftest golden-ratio-target-is-total-over-phi ()
  (list (golden-ratio-target 100)
        (golden-ratio-target 24)
        ;; 1 より小さくならないこと。狭い画面で 0 を返すと enlarge-window が
        ;; 「変えられない」と言い続ける。
        (golden-ratio-target 1))
  => (62 15 1))

;; 既定は無効。**呼んでもレイアウトが動かないこと。**
(deftest golden-ratio-does-nothing-by-default ()
  (unwind-protect
      (progn
        (golden-test-cleanup)
        (split-window)
        (let ((before (window-height)))
          (golden-ratio-adjust)
          (= before (window-height))))
    (golden-test-cleanup))
  => t)

;; 入れると選択中のウィンドウが広くなる。
(deftest golden-ratio-grows-the-selected-window ()
  (unwind-protect
      (progn
        (golden-test-cleanup)
        (split-window)
        ;; next-window は引数が必須 (lisp/builtin.l の宣言がそうなっている)。
        ;; C++ 側の coerce_to_window は nil を「選択中」と読むが、Lisp から
        ;; 省略はできない。
        (let ((other (window-height (next-window (selected-window)))))
          (setq *golden-ratio-mode* t)
          (golden-ratio-adjust)
          ;; 選択中の方が、もう一方より広い
          (> (window-height) other)))
    (golden-test-cleanup))
  => t)

;; ウィンドウが 1 つのときは何もしない。**1 つしかないのに広げようとすると
;; enlarge-window がエラーを上げるので、そこを踏まないこと。**
(deftest golden-ratio-single-window-is-untouched ()
  (unwind-protect
      (progn
        (golden-test-cleanup)
        (setq *golden-ratio-mode* t)
        (let ((before (window-height)))
          (golden-ratio-adjust)
          (= before (window-height))))
    (golden-test-cleanup))
  => t)

;; 除外リストのバッファでは何もしない。候補一覧のような一時ウィンドウは
;; 出した側が大きさを決めているので、割り込むと候補が読めなくなる。
(deftest golden-ratio-skips-excluded-buffers ()
  (unwind-protect
      (let ((*golden-ratio-exclude-buffer-names*
             (list (buffer-name (selected-buffer)))))
        (golden-test-cleanup)
        (split-window)
        (setq *golden-ratio-mode* t)
        (let ((before (window-height)))
          (golden-ratio-adjust)
          (= before (window-height))))
    (golden-test-cleanup))
  => t)
