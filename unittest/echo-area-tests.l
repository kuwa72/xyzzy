;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; ステータス行 (エコー領域) の複数行化のテスト。issue #97。
;;;
;;; **見ているのは「表示量に応じて高さが変わり、戻ること」である。** 高さが
;;; 変わると他のウィンドウの高さも変わるので、伸びたまま戻らないと編集領域が
;;; じわじわ減っていく。伸びる側だけを確かめても足りない。

(require "misc")

(defun echo-area-lines ()
  "エコー領域の今の行数。"
  (ignore-errors (window-lines (minibuffer-window))))

(defun echo-area-long-text (n)
  "折り返しが必ず起きる長さの文字列。"
  (make-sequence 'string n :initial-element #\x))

(deftest echo-area-grows-for-a-long-message ()
  "長いメッセージで伸び、消すと 1 行に戻ること。

**戻ることの方が大事である。** 伸びたまま戻らないと、メッセージを 1 回
出すごとに編集できる行が減る。"
  (let ((width (or (ignore-errors (window-columns (minibuffer-window))) 80)))
    (unwind-protect
	(progn
	  (message "~A" (echo-area-long-text (* width 3)))
	  (refresh-screen)
	  (let ((grown (echo-area-lines)))
	    (message "")
	    (refresh-screen)
	    (list (and (integerp grown) (> grown 1))
		  (echo-area-lines))))
      (progn (message "") (ignore-errors (refresh-screen)))))
  => (t 1))

(deftest echo-area-splits-on-a-newline ()
  "メッセージの改行で行が変わること。

短い 3 行なら、折り返しではなく改行だけで 3 行になる。"
  (unwind-protect
      (progn
	(message "one~%two~%three")
	(refresh-screen)
	(echo-area-lines))
    (progn (message "") (ignore-errors (refresh-screen))))
  => 3)

(deftest echo-area-respects-the-line-limit ()
  "*max-minibuffer-message-lines* を超えて伸びないこと。

上限が無いと、長いエラーメッセージ 1 本で画面がほぼ埋まる。"
  (let ((*max-minibuffer-message-lines* 3))
    (unwind-protect
	(progn
	  (message "~{~A~^~%~}" '("1" "2" "3" "4" "5" "6" "7" "8"))
	  (refresh-screen)
	  (echo-area-lines))
      (progn (message "") (ignore-errors (refresh-screen)))))
  => 3)

(deftest echo-area-one-line-limit-is-the-old-behaviour ()
  "上限 1 なら、どれだけ長くても 1 行のままであること"
  (let ((*max-minibuffer-message-lines* 1)
	(width (or (ignore-errors (window-columns (minibuffer-window))) 80)))
    (unwind-protect
	(progn
	  (message "~A" (echo-area-long-text (* width 3)))
	  (refresh-screen)
	  (echo-area-lines))
      (progn (message "") (ignore-errors (refresh-screen)))))
  => 1)

(deftest echo-area-still-runs-format-directives ()
  "message は従来どおり書式指定を通すこと。

**ここを落とすと `~%' がそのまま出る。** 出力先を差し替えたときに
`(apply #\'format nil fmt args)' を通さない書き方をして実際にそうなった
(引数が無ければ書式文字列をそのまま使う、という近道は誤り)。"
  (unwind-protect
      (progn
	(message "~A~%~A" "one" "two")
	(refresh-screen)
	(echo-area-lines))
    (progn (message "") (ignore-errors (refresh-screen))))
  => 2)

(deftest clear-message-collapses-the-echo-area ()
  "clear-message でエコー領域が 1 行に戻ること"
  (unwind-protect
      (progn
	(message "one~%two~%three")
	(refresh-screen)
	(clear-message)
	(refresh-screen)
	(echo-area-lines))
    (progn (message "") (ignore-errors (refresh-screen))))
  => 1)
