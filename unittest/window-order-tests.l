;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; ウィンドウの配置格子 (w_order) が壊れないことのテスト。issue #83。
;;;
;;; ウィンドウを消すと、そのウィンドウが使っていた境界番号が誰にも参照されなく
;;; なる。**次に分割すると、その空いた番号のところへ新しい境界が挿し込まれ、**
;;; `compute_geometry` が初期化されていない座標を読む。端末フロントエンドでは
;;; そこでゼロ高のウィンドウができ、しかもそれが選択されたままになるので、
;;; **以降どのキーを打っても画面が変わらない** (プレフィックスキー待ちの間に
;;; 一時ウィンドウを出して消すと起きた)。
;;;
;;; ここで見ているのは「消してから分割しても、まともな大きさの 2 枚になる」
;;; という結果だけである。w_order は Lisp から見えないので、症状の側から見る。
;;;
;;; **`refresh-screen` を挟む必要がある。** Win32 では分割した直後の
;;; ウィンドウは `window-lines` が 1 を返し、実際の大きさになるのは次の描画の
;;; ときである (issue #96)。挟まないと、何を測っても 1 になる。
;;;
;;; **`delete-other-windows` から始める。** テストスイートを走らせている間は
;;; ウィンドウが 1 枚とは限らないので (`count-windows` が 2 だった)、
;;; 数を当てにする書き方は環境で落ちる。

(deftest window-grid-survives-delete-then-split ()
  "消してから分割しても、同じくらいの大きさの 2 枚になること。

**ここが落ちると、片方がゼロ高になって画面から消える。** しかもそれが
選択されたままなので、打鍵の行き先が見えなくなる。"
  (save-window-excursion
    (delete-other-windows)
    (refresh-screen)
    (split-window)
    (refresh-screen)
    (delete-window)
    (refresh-screen)
    (split-window)
    (refresh-screen)
    (let* ((a (window-lines))
	   (b (progn (other-window 1) (window-lines))))
      (list (count-windows) (> a 2) (> b 2) (<= (abs (- a b)) 1))))
  => (2 t t t))

(deftest window-space-comes-back-after-delete ()
  "消したら残ったウィンドウが場所を取り戻すこと"
  (save-window-excursion
    (delete-other-windows)
    (refresh-screen)
    (let ((full (window-lines)))
      (split-window)
      (refresh-screen)
      (delete-window)
      (refresh-screen)
      (list (count-windows) (>= (window-lines) (- full 1)))))
  => (1 t))

(deftest window-space-does-not-leak-over-repeats ()
  "分割と削除を繰り返しても行が減り続けないこと。

1 回目に 1 行減るのは分割の境界を畳んだ分で、そこから先は減らない。
**減り続けるなら格子に番号が溜まっている。**"
  (save-window-excursion
    (delete-other-windows)
    (refresh-screen)
    (split-window)
    (refresh-screen)
    (delete-window)
    (refresh-screen)
    (let ((after-first (window-lines)))
      (dotimes (i 4)
	(split-window)
	(refresh-screen)
	(delete-window)
	(refresh-screen))
      (list (count-windows) (eql (window-lines) after-first))))
  => (1 t))

(deftest window-grid-survives-a-vertical-split ()
  "縦分割でも同じであること (境界の配列は桁側にもある)"
  (save-window-excursion
    (delete-other-windows)
    (refresh-screen)
    (split-window-horizontally)
    (refresh-screen)
    (delete-window)
    (refresh-screen)
    (split-window-horizontally)
    (refresh-screen)
    (let* ((a (window-columns))
	   (b (progn (other-window 1) (window-columns))))
      (list (count-windows) (> a 4) (> b 4) (<= (abs (- a b)) 2))))
  => (2 t t t))
