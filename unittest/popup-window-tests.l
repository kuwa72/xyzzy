;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/popup-window.l のテスト。
;;;
;;; 段組みの詰め方が本体。ウィンドウの開け閉めは画面が要るので、
;;; 「開いて書いて閉じたらバッファが残らない」ところだけ見る。

(require "popup-window")

(deftest popup-window-columns-single-column ()
  "幅が足りなければ 1 列になること"
  (ed::popup-window-columns '("aaaa" "bbbb" "cccc") 5)
  => ("aaaa" "bbbb" "cccc"))

(deftest popup-window-columns-fills-down-first ()
  "縦に読んで順番になるよう列優先で詰めること
(横優先だと項目が増えたときに同じものが毎回違う列に来る)"
  (ed::popup-window-columns '("a" "b" "c" "d" "e" "f") 12)
  => ("a  c  e" "b  d  f"))

(deftest popup-window-columns-pads-to-align ()
  "列を揃えるために右へ詰めること。行末に空白は残さないこと"
  (ed::popup-window-columns '("ab" "c" "de" "f") 10)
  => ("ab  de" "c   f"))

(deftest popup-window-columns-uneven-last-column ()
  "端数が出ても落ちないこと"
  (ed::popup-window-columns '("a" "b" "c" "d" "e") 12)
  => ("a  c  e" "b  d"))

(deftest popup-window-columns-empty ()
  "項目が無ければ行も無いこと"
  (ed::popup-window-columns nil 80)
  => nil)

(deftest popup-window-columns-one-item ()
  (ed::popup-window-columns '("only") 80)
  => ("only"))

(deftest popup-window-draw-and-close ()
  "開いて書いて閉じたらバッファが残らないこと"
  (save-window-excursion
    (let ((name " *popup test*"))
      (ed::popup-window-open name "Test")
      (ed::popup-window-draw name '("one" "two" "three") 1)
      (let ((contents (buffer-substring (point-min) (point-max)))
	    (line (current-line-number)))
	(ed::popup-window-close name)
	(values contents line (find-buffer name)))))
  => "one\ntwo\nthree\n"
  => 2
  => nil)

(deftest popup-window-body-lines-is-bounded ()
  "使える行数が上限と画面の小さい方に収まること"
  (let ((ed::*popup-window-max-lines* 4))
    (values (<= (ed::popup-window-body-lines) 4)
	    (>= (ed::popup-window-body-lines) 1)
	    (<= (ed::popup-window-body-lines 2) 2)))
  => t
  => t
  => t)
