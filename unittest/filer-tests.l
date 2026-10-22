;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for open-filer / project-filer (issue #426).
;;;
;;; `filer' は GUI の選択ダイアログを出す C++ 組み込みなので、バッチでは
;;; symbol-function を差し替えて「何が渡されたか」だけを見る。
;;; `get-ime-mode' も同様に差し替える (端末では stub のことがある)。
;;; `*filer-modal*' を nil に束縛するのは、unwind-protect が抜けるときの
;;; (toggle-ime omode) を避けつつ modelessp 引数を確定値にするため。

(require "filer")
(require "project")

(use-package "editor")

(defmacro with-stubbed-filer (&body body)
  `(let ((ed::orig-filer (symbol-function 'filer))
	 (ed::orig-ime (symbol-function 'get-ime-mode))
	 (ed::got nil))
     (unwind-protect
	  (progn
	    (setf (symbol-function 'filer)
		  #'(lambda (&rest args) (setq ed::got args) (values nil nil)))
	    (setf (symbol-function 'get-ime-mode) #'(lambda () nil))
	    (let ((*filer-modal* nil))
	      ,@body)
	    ed::got)
       (setf (symbol-function 'filer) ed::orig-filer)
       (setf (symbol-function 'get-ime-mode) ed::orig-ime))))

(deftest open-filer-forwards-path ()
  "open-filer は &optional path を filer の初期ディレクトリに渡す。
0 引数だった頃は (open-filer dir) が「引数が多すぎます」で失敗した
(issue #426)。"
  (with-stubbed-filer (open-filer "Z:/x/"))
  => ("Z:/x/" t nil t t))

(deftest open-filer-without-path-is-unchanged ()
  "引数無しの open-filer は従来通り path=nil で filer を開く"
  (with-stubbed-filer (open-filer))
  => (nil t nil t t))

(deftest project-filer-passes-root ()
  "project-filer はプロジェクトルートを open-filer 経由で filer に渡す"
  (let ((ed::*project-list* nil))
    (with-stubbed-filer (project-filer "Z:/p/")))
  => ("Z:/p/" t nil t t))
