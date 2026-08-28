;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; encoding マーカーの無い Lisp ファイルに ASCII 以外を書いていないか。
;;;
;;; **1 日に 3 回踏んだ罠なので、機械に見張らせる。**
;;; xyzzy は 1 行目に `-*- ... Encoding: utf-8 -*-` が無いファイルを cp932 と
;;; して読む。純 ASCII だったファイルに UTF-8 の日本語を 1 行足すと、多バイト
;;; 文字の後半が改行や `"` を食ってフォームの構造が変わる。出方が悪い:
;;;
;;;   * misc/run-tests-batch.l -> -load が出力ゼロ・exit 0 で終わる
;;;     (テストが 1 件も走らない)
;;;   * unittest/array-tests.l -> 「文字列が終了していません」でファイルの
;;;     テストが全部消える
;;;   * lisp/ts.l -> バイトコンパイルが「不正なドットリストです」で止まり、
;;;     ライブラリ全体が .lc 無しになる (CI で気づいた)
;;;
;;; どれも「自分が書いたコメントが原因」とは見えない形で出る。

(defvar *encoding-marker-directories* '("lisp/" "unittest/" "misc/")
  "見張る対象。lisp/wip/ はどこからも require されないので外す。")

(defun encoding-marker-present-p (file)
  "FILE の先頭 3 行に Encoding の指定があるか。"
  (with-open-file (s file :direction :input)
    (dotimes (i 3 nil)
      (let ((line (read-line s nil nil)))
	(unless line (return nil))
	(when (string-match "[Ee]ncoding" line)
	  (return t))))))

(defun file-has-non-ascii-p (file)
  "FILE に ASCII 以外の文字があるか。

**符号化を指定しないで読んでよい。** 誤って解釈されても「ASCII 以外が在るか」
は変わらない: 純 ASCII のファイルはどの符号化でも ASCII に解け、ASCII 以外の
バイトはどう解いても 127 より大きい文字になる。ここで見たいのはその一点だけ。"
  (with-open-file (s file :direction :input)
    (loop
      (let ((c (read-char s nil nil)))
	(unless c (return nil))
	(when (> (char-code c) 127)
	  (return t))))))

(defun encoding-marker-offenders ()
  "マーカーが無いのに ASCII 以外を含むファイルの名前のリスト。

**マーカーの有無を先に見る。** ほとんどのファイルはマーカー付きなので、
中身を全部走査するのは残りの十数個だけになる。"
  (let ((bad nil)
	(base (si:system-root)))
    (dolist (dir *encoding-marker-directories*)
      (dolist (f (ignore-errors
		   (directory (merge-pathnames dir base)
			      :absolute t :wild "*.l" :file-only t)))
	(unless (encoding-marker-present-p f)
	  (when (file-has-non-ascii-p f)
	    (push (file-namestring f) bad)))))
    (sort bad #'string<)))

(deftest no-lisp-file-has-non-ascii-without-an-encoding-marker ()
  "**マーカー無しで日本語を書いたファイルが無いこと。**

落ちたら、そのファイルの 1 行目に

    ;;; -*- Mode: Lisp; Encoding: utf-8 -*-

を足すか、そのファイルだけコメントを英語で書く (周りが英語コメントなら
そちらに揃える)。"
  (encoding-marker-offenders)
  => nil)
