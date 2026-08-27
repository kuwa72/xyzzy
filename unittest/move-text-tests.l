;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/move-text.l のテスト。
;;;
;;; 行の入れ替えは「バッファ最終行に改行が無い」場合に壊れやすいので、
;;; その形を明示的に並べてある。

(require "move-text")

(deftest move-text-down-middle ()
  "現在行が 1 行下へ移り、点はその行に付いて行くこと"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc\n")
    (goto-line 2)
    (goto-column 1)
    (ed::move-text-down)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)
	    (current-column)))
  => "aaa\nccc\nbbb\n"
  => 3
  => 1)

(deftest move-text-up-middle ()
  "現在行が 1 行上へ移ること"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc\n")
    (goto-line 2)
    (goto-column 2)
    (ed::move-text-up)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)
	    (current-column)))
  => "bbb\naaa\nccc\n"
  => 1
  => 2)

(deftest move-text-up-at-first-line ()
  "先頭行より上へは動かせず、バッファも点も変わらないこと"
  (with-temp-buffer
    (insert "aaa\nbbb\n")
    (goto-line 1)
    (ed::move-text-up)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)))
  => "aaa\nbbb\n"
  => 1)

(deftest move-text-down-at-last-line ()
  "最終行より下へは動かせないこと。末尾に改行があるので \"最終行\" は
改行の後ろの空行ではなく bbb の行であること (空行を 1 行とみなすと
bbb と空行が入れ替わって末尾の改行が消える)"
  (with-temp-buffer
    (insert "aaa\nbbb\n")
    (goto-line 2)
    (ed::move-text-down)
    (buffer-substring (point-min) (point-max)))
  => "aaa\nbbb\n")

(deftest move-text-down-into-unterminated-last-line ()
  "最終行に改行が無いとき、その手前の行を下へ動かしても行が潰れないこと"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc")
    (goto-line 2)
    (ed::move-text-down)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)))
  => "aaa\nccc\nbbb"
  => 3)

(deftest move-text-up-from-unterminated-last-line ()
  "改行で終わっていない最終行を上へ動かしても行が潰れないこと"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc")
    (goto-line 3)
    (ed::move-text-up)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)))
  => "aaa\nccc\nbbb"
  => 2)

(deftest move-text-round-trip ()
  "下げてから上げると元に戻ること (改行なし最終行を含む形でも)"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc")
    (goto-line 1)
    (ed::move-text-down)
    (ed::move-text-up)
    (buffer-substring (point-min) (point-max)))
  => "aaa\nbbb\nccc")

(deftest move-text-prefix-arg ()
  "引数の回数だけ動くこと"
  (with-temp-buffer
    (insert "1\n2\n3\n4\n5\n")
    (goto-line 1)
    (ed::move-text-down 3)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)))
  => "2\n3\n4\n1\n5\n"
  => 4)

(deftest move-text-prefix-arg-clamped-at-edge ()
  "端に着いたらそこで止まり、それ以上は何も壊さないこと"
  (with-temp-buffer
    (insert "1\n2\n3\n")
    (goto-line 3)
    (ed::move-text-up 99)
    (values (buffer-substring (point-min) (point-max))
	    (current-line-number)))
  => "3\n1\n2\n"
  => 1)

(deftest move-text-does-not-touch-kill-ring ()
  "kill-ring を汚さないこと (kill-line + yank で実装していない理由)"
  (with-temp-buffer
    (insert "aaa\nbbb\n")
    (let ((ed::*kill-ring* nil)
	  (ed::*kill-ring-yank-pointer* nil))
      (goto-line 1)
      (ed::move-text-down)
      ed::*kill-ring*))
  => nil)

(deftest move-text-empty-line ()
  "空行でも動かせること"
  (with-temp-buffer
    (insert "aaa\n\nccc\n")
    (goto-line 2)
    (ed::move-text-up)
    (buffer-substring (point-min) (point-max)))
  => "\naaa\nccc\n")

(deftest move-text-region-moves-whole-block ()
  "選択範囲の行がまとめて動き、移動後も同じテキストが選択されていること"
  (with-temp-buffer
    (insert "1\n2\n3\n4\n")
    (goto-line 2)
    (goto-bol)
    (start-selection 2 nil)
    (goto-line 3)
    (goto-eol)
    (ed::move-text-down)
    (values (buffer-substring (point-min) (point-max))
	    (buffer-substring (min (selection-mark) (selection-point))
			      (max (selection-mark) (selection-point)))))
  => "1\n4\n2\n3\n"
  => "2\n3")

(deftest move-text-region-ending-at-bol-excludes-that-line ()
  "選択終端がちょうど行頭のとき、その行は移動対象に入らないこと"
  (with-temp-buffer
    (insert "1\n2\n3\n4\n")
    (goto-line 2)
    (goto-bol)
    (start-selection 2 nil)
    (goto-line 3)
    (goto-bol)
    (ed::move-text-down)
    (buffer-substring (point-min) (point-max)))
  => "1\n3\n2\n4\n")

(deftest move-text-keymap ()
  "M-Up / M-Down に割り当てられていること"
  (values (lookup-keymap *global-keymap* #\M-Up)
	  (lookup-keymap *global-keymap* #\M-Down))
  => move-text-up
  => move-text-down)

(deftest move-text-does-not-move-past-the-final-newline ()
  "バッファ末尾の改行の後ろ (行ではなく位置) では何も動かないこと。

弾かずに進むと空の塊と隣の行を入れ替える形になり、末尾の改行が消えた上に
空行が 1 本前に現れる。文字数は変わらないので長さの比較では見つからない。
上下を繰り返すとその空行が行間を渡り歩く (報告された症状)。"
  (with-temp-buffer
    (insert "aaa\nbbb\n")
    (goto-char (point-max))
    (values (ed::move-text-move -1)
	    (buffer-substring (point-min) (point-max))
	    (ed::move-text-move 1)
	    (buffer-substring (point-min) (point-max))))
  => nil
  => "aaa\nbbb\n"
  => nil
  => "aaa\nbbb\n")

(deftest move-text-empty-buffer ()
  "空のバッファでも落ちないこと"
  (with-temp-buffer
    (values (ed::move-text-move -1) (ed::move-text-move 1)))
  => nil
  => nil)

(deftest move-text-last-real-line-still-moves ()
  "末尾の改行の後ろを弾いても、最後の実在する行はちゃんと動くこと"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc\n")
    (goto-line 3)
    (ed::move-text-up)
    (buffer-substring (point-min) (point-max)))
  => "aaa\nccc\nbbb\n")

(deftest move-text-replace-refuses-length-change ()
  "長さが合わない置き換えは書かずに nil を返すこと。

move-text は必ず「同じ文字を並べ替える」操作なので、置き換えの前後で
バッファの長さが変わることは無い。変わるならこちらの計算が狂っている
ということなので、書き込まずに諦める。"
  (with-temp-buffer
    (insert "abcdef")
    (values (ed::move-text-replace 0 3 "XY")
	    (buffer-substring (point-min) (point-max))
	    (ed::move-text-replace 0 3 "XYZW")
	    (buffer-substring (point-min) (point-max))
	    (ed::move-text-replace 0 3 "XYZ")
	    (buffer-substring (point-min) (point-max))))
  => nil
  => "abcdef"
  => nil
  => "abcdef"
  => t
  => "XYZdef")

(deftest move-text-length-never-changes ()
  "あらゆる形・位置・方向で、バッファの長さが変わらないこと。
報告された「テキストが増殖する」に対する総当たりの回帰テスト。"
  (let ((bad nil))
    (dolist (shape (list "aaaa
bbbb" "aaaa
bbbb
" "aaaa
bbbb
cccc" "aaaa
bbbb
cccc
" "aaaa
" "aaaa" "
" ""))
      (dotimes (p (1+ (length shape)))
	(dolist (dir '(-1 1))
	  (with-temp-buffer
	    (insert shape)
	    (goto-char p)
	    (let ((before (length (buffer-substring (point-min) (point-max)))))
	      (dotimes (i 3)
		(ed::move-text-move dir))
	      (let ((after (length (buffer-substring (point-min) (point-max)))))
		(unless (= before after)
		  (push (list shape p dir before after) bad))))))))
    bad)
  => nil)
