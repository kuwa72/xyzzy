;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "about")

(in-package "editor")

(export 'about-dialog)

(let ((dialog-template nil))
  (defun about-dialog ()
    (interactive)
    (unless dialog-template
      (setq dialog-template
	    ;; 幅は 211 -> 260 に広げた。**リリースでないビルドのバージョンは
	    ;; "0.6.0-36-ga34f898a-dirty" のように長く**、元の幅では途中で
	    ;; 切れて「どのビルドか」が読めなかった。
	    `(dialog 0 0 260 162
		     (:caption "について")
		     (:font 9 "MS UI Gothic")
		     (:control
		      (:button IDOK "おけ" #x50010001 220 7 33 14)
		      (:static nil nil #x50020003 7 7 18 20)
		      (:link xyzzy ,(concat "\001xyzzy\002 version "
					    (software-version-display-string))
		       #x50020000 34 7 180 8)
		      (:static nil "Copyright (C) 1996-2005 Tetsuya Kamei"
		       #x50020000 34 19 180 8)
		      (:link org "Copyright (C) 2012-2026 \001xyzzy Project\002"
		       #x50020000 34 28 180 8)
		      (:static nil "Icon designed by Yoshinori Watanabe."
		       #x50020000 34 41 180 8)
		      ;; MD5 の実装は RSA のリファレンス実装 (src/core/md5c.cc)。
		      ;; **その使用条件がこの表示である**: 「この名前で識別する
		      ;; こと」を求めているので、飾りではなく外せない。元は
		      ;; 2 行に割れていて、無関係な 2 つの謝辞のように見えた。
		      (:static nil "RSA Data Security, Inc. MD5 Message-Digest Algorithm."
		       #x50020000 34 54 200 8)
		      ;; 下の箱が何なのか分からないという指摘があったので見出しを
		      ;; 付けた。中身はアーカイバ DLL (UNLHA32.DLL など) とその
		      ;; バージョンで、入れていなければ空になる。空の白い箱だけが
		      ;; 出ていると壊れているように見える。
		      (:static nil "アーカイバ DLL:" #x50020000 34 70 200 8)
		      (:listbox list nil #x50a10111 34 81 219 72)))))
    (dialog-box dialog-template
		(list (cons 'list (about-archiver-dll-rows)))
		'((xyzzy :url "https://github.com/snmsts/xyzzy")
		  (org :url "https://github.com/snmsts/xyzzy")
		  (list :column (40 12))))
    t))

(defun about-archiver-dll-rows ()
  "「について」の一覧に出す (ファイル名 バージョン) の行。

**1 つも見つからないときも 1 行入れる。** 空の白い箱だけが出ていると、
何を出す場所なのか分からず壊れているようにも見える。"
  (let ((rows (long-operation
		(mapcan #'(lambda (x)
			    (let ((version (archiver-dll-version x)))
			      (and version
				   (list (list (get x 'archiver-dll-file-name)
					       version)))))
			*archiver-dll-list*))))
    (or rows (list (list "(見つかりません)" "")))))
