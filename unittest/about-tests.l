;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; 「について」ダイアログとバージョン表示のテスト。
;;;
;;; **ダイアログの見た目はテストできない**ので、そこに出す値の形だけを固定する。
;;; 守りたいのは
;;;
;;;   * リリースでないビルドが名乗るバージョンが、素のバージョンで始まること
;;;     (タイトルバーと「について」の両方がこれを使う)
;;;   * 一覧に必ず 1 行入ること (空の白い箱だけが出ると壊れて見える)

(require "about")

(deftest version-display-string-starts-with-the-plain-version ()
  "表示用バージョンは素のバージョンで始まること。

タグの上なら素のバージョンそのまま (\"0.6.0\")、そうでなければ git describe
(\"0.6.0-36-ga34f898a-dirty\") になる。**どちらでも通る形で見る**: リリース
ビルドでだけ落ちるテストを書くと、リリースのときに気づくことになる。"
  (let* ((plain (software-version))
	 (display (software-version-display-string)))
    (values (and (stringp plain) (plusp (length plain)))
	    (and (stringp display) (plusp (length display)))
	    (and (>= (length display) (length plain))
		 (string= plain (subseq display 0 (length plain))))))
  => t
  => t
  => t)

(deftest about-archiver-rows-are-never-empty ()
  "アーカイバ DLL が 1 つも無くても 1 行返すこと。
空だと「について」に白い箱だけが出て、何の場所か分からない。"
  (let ((rows (ed::about-archiver-dll-rows)))
    (values (and (consp rows) t)
	    (plusp (length rows))))
  => t
  => t)

(deftest about-archiver-rows-have-two-string-columns ()
  "各行が (ファイル名 バージョン) の 2 列であること (:column (40 12) に渡す)"
  (let ((rows (ed::about-archiver-dll-rows)))
    (every #'(lambda (r)
	       (and (consp r)
		    (= (length r) 2)
		    (stringp (first r))
		    (stringp (second r))))
	   rows))
  => t)
