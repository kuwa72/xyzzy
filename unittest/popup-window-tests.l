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

(deftest popup-window-fit-cuts-long-strings ()
  "幅に収まらない文字列を切ること"
  (values (ed::popup-window-fit "abcdef" 3)
	  (ed::popup-window-fit "ab" 3)
	  (ed::popup-window-fit "abc" nil))
  => "abc"
  => "ab"
  => "abc")

(deftest popup-window-columns-adds-columns-to-fit-max-rows ()
  "行数の上限を渡すと、列を増やして (1 列を狭めて) 収めること。
項目が長いと自然な段組みは 2 列 6 行になるが、上限 4 行なら 3 列 4 行になる。"
  (let ((items (let (l)
		 (dotimes (i 12)
		   (push (format nil "~D-~A" i
				 (make-sequence 'string 43 :initial-element #\a))
			 l))
		 (nreverse l))))
    (values (length (ed::popup-window-columns items 100))
	    (length (ed::popup-window-columns items 100 4))))
  => 6
  => 4)

(deftest popup-window-columns-reports-what-it-dropped ()
  "列を増やしても収まらないときは、落とした件数を書くこと
(黙って切ると「これで全部だ」と読めてしまう)"
  (let* ((items (let (l) (dotimes (i 40) (push (format nil "item~D" i) l))
			 (nreverse l)))
	 (rows (ed::popup-window-columns items 40 3)))
    (values (<= (length rows) 3)
	    (and (string-match "^\\.\\.\\. \\+[0-9]+$" (car (last rows))) t)))
  => t
  => t)

(deftest popup-window-columns-ignores-max-rows-when-it-fits ()
  "上限に収まっているときは何も変えないこと"
  (ed::popup-window-columns '("a" "b" "c" "d" "e" "f") 12 10)
  => ("a  c  e" "b  d  f"))
