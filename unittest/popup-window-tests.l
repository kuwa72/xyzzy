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

(deftest popup-window-open-splits-the-selected-window ()
  "**別のウィンドウを奪わず、今いるウィンドウを分割すること。**

pop-to-buffer は「画面が既に分割されていたら新たに分割せず、別のウィンドウへ
移ってそこに出す」ので、シェルなどを出している無関係なウィンドウを奪っていた
(端末を並べた状態で M-m を打つと、モード行だけ *Which Key* になってシェルの
画面が残るという報告があった)。"
  (save-window-excursion
    (delete-other-windows)
    (let ((name " *popup split test*")
	  (other (get-buffer-create " *popup other*")))
      (unwind-protect
	  (progn
	    ;; 2 枚にして、片方に別のバッファを出しておく
	    (split-window)
	    (let* ((before (ed::popup-window-window-list))
		   (n-before (length before))
		   (keep (buffer-name (selected-buffer))))
	      (ed::popup-window-open name "Test")
	      (let ((after (ed::popup-window-window-list)))
		(ed::popup-window-close name)
		(values (- (length after) n-before)
			;; 奪われていないこと: 元のウィンドウはまだ生きている
			(every #'(lambda (w) (member w after)) before)))))
	(progn
	  (set-buffer-modified-p nil other)
	  (ignore-errors (delete-buffer other))))))
  => 1
  => t)

(deftest popup-window-open-reuses-its-own-window ()
  "既にそのバッファを出しているウィンドウがあれば増やさないこと
(打鍵ごとに描き直す間、同じウィンドウを使い続ける)"
  (save-window-excursion
    (delete-other-windows)
    (let ((name " *popup reuse test*"))
      (ed::popup-window-open name "Test")
      (let ((n1 (length (ed::popup-window-window-list))))
	(ed::popup-window-open name "Test")
	(let ((n2 (length (ed::popup-window-window-list))))
	  (ed::popup-window-close name)
	  (values n1 n2)))))
  => 2
  => 2)

(deftest popup-window-open-realizes-the-window-size ()
  "**開いた直後に大きさが取れること。**

Win32 では split-window の直後のウィンドウは window-lines / window-columns が
1 を返し、実際の大きさになるのは次の描画のときである (フレームのウィンドウ配置
は refresh_screen で反映される)。1 行 1 桁として段組みを組むと候補が 1 個しか
出ない。実際に Leader メニューが

    [Leader]
    b  Buffer+
    ... +13

になった。popup-window-open が開いた後に refresh-screen を呼ぶ。"
  (save-window-excursion
    (delete-other-windows)
    (let ((name " *popup size test*"))
      (ed::popup-window-open name "Test")
      (let ((lines (ed::popup-window-measured-lines))
	    (cols (ed::popup-window-measured-columns 0)))
	(ed::popup-window-close name)
	(values (and lines (> lines 2) t)
		(> cols 20)))))
  => t
  => t)

(deftest popup-window-columns-in-a-fresh-window-keeps-everything ()
  "開いた直後の一時ウィンドウで段組みを組んでも項目が落ちないこと。
落ちると Leader メニューが「1 個 + ... +N」になる (上のテストの続き)。"
  (save-window-excursion
    (delete-other-windows)
    (let ((name " *popup fresh test*")
	  (items (list "a  A" "b  B" "c  C" "d  D" "e  E" "f  F"
		       "g  G" "h  H" "i  I" "j  J" "k  K" "l  L")))
      (ed::popup-window-open name "Test")
      (let ((rows (ed::popup-window-columns
		   items
		   (ed::popup-window-measured-columns)
		   (ed::popup-window-body-lines 1))))
	(ed::popup-window-close name)
	(not (some #'(lambda (r) (and (string-match "^\\.\\.\\. \\+" r) t))
		   rows)))))
  => t)
