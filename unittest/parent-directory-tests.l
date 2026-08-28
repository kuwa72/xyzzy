;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/project.l の parent-directory のテスト。
;;;
;;; **ここは「必ず止まること」を守るためのテストである。** 上へ遡る処理は
;;; lisp/project.l (プロジェクトルート探索) と lisp/modeline.l (.git 探索) の
;;; 2 箇所で使っていて、止まらないと **起動直後に CPU 100% で応答が無くなる。**
;;; 実機の Windows で実際にそうなった: `C:` は「ドライブ C: のカレント
;;; ディレクトリ」を意味するので、`C:/` の親を尋ねると長い方へ戻ってくる。

(require "project")

(deftest parent-directory-goes-up-one-level ()
  "1 階層上を返すこと。

ドライブ名を書かないパスは Windows でカレントドライブが付くので、ここでは
`C:` を明示したものだけを見る (`/home/x/` は Windows では `Z:/home/` の
ように返る)。"
  (values (ed::parent-directory "C:/Users/ykuwa/Downloads/")
	  (ed::parent-directory "C:/Users/ykuwa/")
	  (ed::parent-directory "C:/Users/"))
  => "C:/Users/ykuwa/"
  => "C:/Users/"
  => "C:/")

(deftest parent-directory-stops-at-the-root ()
  "ルートより上には行かないこと"
  (values (ed::parent-directory "C:/")
	  (ed::parent-directory "/"))
  => nil
  => nil)

(deftest parent-directory-on-junk ()
  "nil や空文字列で落ちないこと"
  (values (ed::parent-directory nil)
	  (ed::parent-directory "")
	  (ed::parent-directory 42))
  => nil
  => nil
  => nil)

(deftest parent-directory-refuses-a-longer-parent ()
  "**上へ遡ったつもりで長い方へ戻ってきたら nil を返すこと。**

Windows の `C:` は「ドライブ C: のカレントディレクトリ」なので、`C:/` の親を
尋ねると `C:/Users/.../xyzzy-amd64/` が返ってくる。「親が自分と同じなら終わり」
だけを見ていると、そこから同じ数ディレクトリを永久に巡回する。
container の Wine ではカレントドライブが Z: だったため再現せず、実機で
初めて出た。ここでその挙動を作って固定する。"
  (let ((orig (symbol-function 'directory-namestring)))
    (unwind-protect
	(progn
	  (setf (symbol-function 'directory-namestring)
		#'(lambda (path)
		    (if (string= path "C:")
			"C:/Users/ykuwa/Downloads/xyzzy-latest/xyzzy-amd64/"
		      (funcall orig path))))
	  (values (ed::parent-directory "C:/")
		  ;; 普通の階層はこの状況でも従来どおり遡れること
		  (ed::parent-directory "C:/Users/ykuwa/")))
      (setf (symbol-function 'directory-namestring) orig)))
  => nil
  => "C:/Users/")

(deftest parent-directory-walk-always-terminates ()
  "遡り続けても必ず終わること (長さが単調に減るので有限回で止まる)"
  (let ((d "C:/a/b/c/d/e/f/")
	(n 0))
    (while (and d (< n 1000))
      (setq d (ed::parent-directory d))
      (incf n))
    (values (null d) (< n 1000)))
  => t
  => t)

(deftest parent-directory-walk-terminates-with-a-lying-namestring ()
  "**directory-namestring が長い方を返しても終わること。** これが本番で
起きたことで、守りたいのはこの性質である。"
  (let ((orig (symbol-function 'directory-namestring)))
    (unwind-protect
	(progn
	  (setf (symbol-function 'directory-namestring)
		#'(lambda (path)
		    (if (string= path "C:")
			"C:/Users/ykuwa/Downloads/xyzzy-latest/xyzzy-amd64/"
		      (funcall orig path))))
	  (let ((d "C:/Users/ykuwa/Downloads/xyzzy-latest/xyzzy-amd64/")
		(n 0))
	    (while (and d (< n 1000))
	      (setq d (ed::parent-directory d))
	      (incf n))
	    (values (null d) (< n 1000))))
      (setf (symbol-function 'directory-namestring) orig)))
  => t
  => t)

;;; ---------------------------------------------------------------------------
;;; 上まで遡り切る経路
;;;
;;; **報告されたバグはここで踏む。** 上の 6 件は parent-directory 単体を見て
;;; いるが、それだけでは CI で捕まらなかった: スイートの中で遡る処理を呼ぶ
;;; テストは一時ディレクトリを si:system-root (= リポジトリ) の下に作るので、
;;; **すぐ上に .git があって、ドライブのルートまで行かない。**
;;;
;;; 実機で固まったのは「上に .git が 1 つも無い場所」(インストール先の
;;; C:/Users/.../xyzzy-amd64/) だった。ルートまで遡り切って初めて
;;; `C:` -> ドライブのカレントディレクトリ の折り返しを踏む。
;;;
;;; なのでここでは **一時ディレクトリ (TEMP の下)** を使う。リポジトリの外なので
;;; 上にマーカーが無く、ルートまで遡る。遡りが止まらなければこのテストが
;;; 返ってこない。

(defun walk-test-temp-directory ()
  "上にプロジェクトマーカーが無いディレクトリ (TEMP の下)。"
  (directory-namestring (make-temp-file-name)))

(deftest modeline-git-branch-walks-to-the-root-and-stops ()
  "上に .git が 1 つも無い場所から呼んでも返ってくること。

**返ってこなければ、それがバグである。** 実機の Windows では、ここで
ドライブのルートまで遡ったあと `C:` がドライブのカレントディレクトリへ
折り返して、同じディレクトリを永久に巡回した。"
  (progn
    (ed::modeline-clear-cache)
    (let ((branch (ed::modeline-git-branch (walk-test-temp-directory))))
      ;; TEMP の上にリポジトリがあれば nil ではないが、それでも「返ってくる」
      ;; ことが要点なので、値ではなく型だけを見る。
      (or (null branch) (stringp branch))))
  => t)

(deftest project-find-root-directory-walks-to-the-root-and-stops ()
  "プロジェクトルート探索も同じ場所から返ってくること。
こちらは元から同じ書き方だったので、モード行より前から固まりえた。"
  (let ((root (ignore-errors
		(ed::project-find-root-directory (walk-test-temp-directory)))))
    (or (null root) (stringp root)))
  => t)

(deftest modeline-git-dir-terminates-when-the-drive-folds-back ()
  "**ドライブのカレントディレクトリへ折り返す状況を作って、`.git` の探索が
有限回で終わることを見る。**

実機の Windows でしか起きない折り返し (`C:` が `C:/Users/.../` を返す) を
ここで再現する。上の 2 件はルートまで遡ることは確かめるが、Wine では折り返しが
起きないので、**折り返し自体はこの形でしか押さえられない。**

呼び出し回数に上限を付けてあるので、止まらなくなってもテストは固まらずに
落ちる (固まると原因が分からないまま CI のタイムアウトになる)。"
  (let ((orig (symbol-function 'directory-namestring))
	(calls 0))
    (unwind-protect
	(progn
	  (setf (symbol-function 'directory-namestring)
		#'(lambda (path)
		    (incf calls)
		    (cond ((> calls 200)
			   ;; 保険。ここへ来たら遡りが止まっていない。
			   (funcall orig path))
			  ((and (stringp path) (string-match "^[A-Za-z]:$" path))
			   (concat path "/a/b/c/d/e/"))
			  (t (funcall orig path)))))
	  (ed::modeline-clear-cache)
	  (ed::modeline-git-branch "C:/a/b/c/d/e/")
	  (<= calls 200))
      (progn
	(setf (symbol-function 'directory-namestring) orig)
	(ed::modeline-clear-cache))))
  => t)
