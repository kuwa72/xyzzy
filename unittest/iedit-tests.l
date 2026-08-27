;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/iedit.l のテスト。
;;;
;;; iedit は **バッファを書き換える** ので、位置の計算が 1 文字ずれるとテキストが
;;; 壊れる。壊れ方は「見た目には気づきにくい」形 (別の識別子の途中に文字が
;;; 混ざる) になるので、位置の計算と、書く前の確認をここで固定する。
;;;
;;; 打鍵を読むループ (iedit-loop) はキー入力を伴うのでここでは扱わない。
;;; 代わりに、そのループが呼ぶ部品 (iedit-occurrences / iedit-shifted-positions
;;; / iedit-replace-all) を直接突く。

(require "iedit")

(defmacro with-iedit-buffer ((text) &body body)
  "TEXT を入れた一時バッファで BODY を実行する。"
  `(let ((buf (create-new-buffer " *iedit test*")))
     (unwind-protect
	 (save-excursion
	   (set-buffer buf)
	   (erase-buffer buf)
	   (insert ,text)
	   (goto-char (point-min))
	   ,@body)
       (progn
	 (set-buffer-modified-p nil buf)
	 (delete-buffer buf)))))

(setf (get 'with-iedit-buffer 'lisp-indent-hook) 1)

(deftest iedit-shifted-positions-when-lengths-match ()
  "同じ長さの置き換えなら位置は動かないこと"
  (ed::iedit-shifted-positions '(0 10 20) 3 3)
  => (0 10 20))

(deftest iedit-shifted-positions-when-growing ()
  "長くなると k 番目が (差分 x k) だけ後ろへずれること"
  (ed::iedit-shifted-positions '(0 10 20) 3 5)
  => (0 12 24))

(deftest iedit-shifted-positions-when-shrinking ()
  "短くなると前へずれること"
  (ed::iedit-shifted-positions '(0 10 20) 3 1)
  => (0 8 16))

(deftest iedit-shifted-positions-empty ()
  (ed::iedit-shifted-positions nil 3 5)
  => nil)

(deftest iedit-occurrences-finds-whole-symbols-only ()
  "シンボルの途中に埋まっているものを拾わないこと
(foo を直すときに foobar を巻き込まない)"
  (with-iedit-buffer ("foo foobar barfoo foo")
    (ed::iedit-occurrences "foo"))
  => (0 18))

(deftest iedit-occurrences-can-include-partial ()
  "第 2 引数が nil なら埋まっているものも拾うこと"
  (with-iedit-buffer ("foo foobar")
    (ed::iedit-occurrences "foo" nil))
  => (0 4))

(deftest iedit-occurrences-is-case-sensitive-by-default ()
  "既定では大文字小文字を区別すること (識別子の付け替えに使うので)"
  (with-iedit-buffer ("foo Foo FOO")
    (values (ed::iedit-occurrences "foo")
	    (let ((ed::*iedit-case-fold* t))
	      (length (ed::iedit-occurrences "foo")))))
  => (0)
  => 3)

(deftest iedit-occurrences-none ()
  (with-iedit-buffer ("aaa bbb")
    (ed::iedit-occurrences "zzz"))
  => nil)

(deftest iedit-replace-all-grows ()
  "全部の箇所が置き換わり、他の文字が壊れないこと (長くなる場合)"
  (with-iedit-buffer ("foo = foo + 1; foobar(foo);")
    (let ((positions (ed::iedit-occurrences "foo")))
      (values (and (ed::iedit-replace-all positions "foo" "counter") t)
	      (buffer-substring (point-min) (point-max)))))
  => t
  => "counter = counter + 1; foobar(counter);")

(deftest iedit-replace-all-shrinks ()
  "短くなる場合"
  (with-iedit-buffer ("alpha + alpha")
    (let ((positions (ed::iedit-occurrences "alpha")))
      (ed::iedit-replace-all positions "alpha" "a")
      (buffer-substring (point-min) (point-max))))
  => "a + a")

(deftest iedit-replace-all-returns-new-positions ()
  "置き換え後の位置を返すこと (次の打鍵でそれを使う)"
  (with-iedit-buffer ("xx yy xx")
    (let ((positions (ed::iedit-occurrences "xx")))
      (ed::iedit-replace-all positions "xx" "zzzz")))
  => (0 8))

(deftest iedit-replace-all-can-be-chained ()
  "返ってきた位置で続けて置き換えられること (1 打鍵ずつ足す動きと同じ)"
  (with-iedit-buffer ("ab cd ab")
    (let* ((p0 (ed::iedit-occurrences "ab"))
	   (p1 (ed::iedit-replace-all p0 "ab" "abX"))
	   (p2 (ed::iedit-replace-all p1 "abX" "abXY")))
      (values p2 (buffer-substring (point-min) (point-max)))))
  => (0 8)
  => "abXY cd abXY")

(deftest iedit-replace-all-refuses-when-the-text-moved ()
  "**書く前に確かめて、想定と違えば何も書かないこと。**
位置の計算がずれているということなので、そのまま書くとバッファが壊れる。"
  (with-iedit-buffer ("foo bar foo")
    (let ((positions (ed::iedit-occurrences "foo")))
      ;; 位置を 1 つずらして「間違った位置」を作る
      (let ((bad (mapcar #'1+ positions)))
	(values (ed::iedit-replace-all bad "foo" "zzz")
		;; 何も書かれていないこと
		(buffer-substring (point-min) (point-max))))))
  => nil
  => "foo bar foo")

(deftest iedit-replace-all-refuses-past-the-end ()
  "バッファの外を指していても落ちないこと"
  (with-iedit-buffer ("foo")
    (values (ed::iedit-replace-all '(2) "foo" "z")
	    (buffer-substring (point-min) (point-max))))
  => nil
  => "foo")

(deftest iedit-target-at-point-takes-the-symbol ()
  "カーソル位置のシンボルを取ること"
  (with-iedit-buffer ("alpha beta-gamma")
    (goto-char 2)
    (ed::iedit-target-at-point))
  => ("alpha" 0 5))

(deftest iedit-target-at-point-on-whitespace ()
  "シンボルでない場所では nil を返すこと"
  (with-iedit-buffer ("a  b")
    (goto-char 2)
    (ed::iedit-target-at-point))
  => nil)

(deftest iedit-highlight-marks-every-place ()
  "全部の箇所に色が付くこと (どこが変わるか見えないと使えない)"
  (with-iedit-buffer ("foo bar foo")
    (let ((positions (ed::iedit-occurrences "foo")))
      (ed::iedit-highlight positions 3)
      (let ((n 0)
	    (start (point-min)))
	(loop
	  (multiple-value-bind (from to tag)
	      (find-text-attribute ed::*iedit-tag* :start start)
	    (unless from (return))
	    (incf n)
	    (setq start (1+ from))))
	(ed::iedit-unhighlight)
	(values n (find-text-attribute ed::*iedit-tag*)))))
  => 2
  => nil)

(deftest iedit-leader-binding ()
  "Leader c r に割り当てられていること"
  (lookup-keymap ed::*leader-code-map* #\r)
  => iedit)
