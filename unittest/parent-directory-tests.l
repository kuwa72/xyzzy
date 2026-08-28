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
