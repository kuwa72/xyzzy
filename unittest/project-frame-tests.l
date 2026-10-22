;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for project ↔ pseudo-frame binding (lisp/project.l, issue #424).
;;;
;;; バッチでは init-pseudo-frame が走らず *pseudo-frame-list* は空なので、
;;; フレームはテストごとに create-pseudo-frame で作る。
;;; 各テストは *pseudo-frame-list* 等を動的に再束縛してグローバル状態を
;;; 汚さない。

(require "project")

(use-package "editor")

(defmacro with-isolated-project-frames (&body body)
  `(let ((ed::*pseudo-frame-list* nil)
	 (ed::*current-pseudo-frame* nil)
	 (ed::*pseudo-frame-counter* 1)
	 (ed::*project-frame-root-alist* nil))
     ,@body))

(deftest project-frame-bind-and-lookup ()
  "project-bind-frame で紐付けた root が project-frame-root で返る。
末尾 / の無い root は directory-namestring で正規化される。"
  (with-isolated-project-frames
   (let ((f (ed::create-pseudo-frame "proj-a")))
     (project-bind-frame "Z:/a" f)
     (project-frame-root f)))
  => "Z:/a/")

(deftest project-frame-default-frame-is-selected ()
  "frame 引数の省略時は現在の pseudo-frame が使われる"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "p")
   (project-bind-frame "Z:/cur/")
   (project-frame-root))
  => "Z:/cur/")

(deftest project-frame-current-root-prefers-frame ()
  "紐付いた frame ではバッファ由来より frame の root が優先される"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "p")
   (project-bind-frame "Z:/a/")
   (project-current-root))
  => "Z:/a/")

(deftest project-frame-explicit-dir-ignores-frame ()
  "dir 引数を渡した project-current-root は frame 紐付けを見ない。
実在する temp dir を使う (project-current-root は truename を通すので
存在しないパスを渡せない)。"
  (with-temp-dirs (d)
    (with-isolated-project-frames
     (ed::create-pseudo-frame "p")
     (project-bind-frame "Z:/a/")
     (string-equal (project-current-root d) "Z:/a/")))
  => nil)

(deftest project-frame-switch-creates ()
  "未紐付け root への switch はプロジェクト名の frame を作って紐付ける"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "init")
   (multiple-value-bind (frame created-p)
       (project-switch-to-project "Z:/myproj/")
     (list created-p
	   (ed::pseudo-frame-name frame)
	   (project-frame-root frame))))
  => (t "myproj" "Z:/myproj/"))

(deftest project-frame-switch-selects-existing ()
  "紐付き済み root への switch は新規作成せず既存 frame を選び直す"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "init")
   (let ((f (project-switch-to-project "Z:/p/")))
     (ed::create-pseudo-frame "other")
     (multiple-value-bind (frame created-p)
	 (project-switch-to-project "Z:/p/")
       (list (eq frame f)
	     created-p
	     (eq (ed::selected-pseudo-frame) f)
	     (length ed::*pseudo-frame-list*)))))
  => (t nil t 3))

(deftest project-frame-multiple-frames-per-project ()
  "1 つのプロジェクトに複数の frame を紐付けられる"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "init")
   (project-switch-to-project "Z:/p/")
   (project-bind-frame "Z:/p/" (ed::create-pseudo-frame "p2"))
   (list (project-frame-root (ed::find-pseudo-frame "p"))
	 (project-frame-root (ed::find-pseudo-frame "p2"))))
  => ("Z:/p/" "Z:/p/"))

(deftest project-frame-deleted-frame-is-pruned ()
  "frame を削除すると紐付けも消える"
  (with-isolated-project-frames
   (ed::create-pseudo-frame "init")
   (let ((f (project-switch-to-project "Z:/p/")))
     (ed::create-pseudo-frame "other")
     (ed::delete-pseudo-frame f)
     (project-frame-root f)))
  => nil)

(deftest project-frame-unbind ()
  "project-unbind-frame で紐付けを解除すると buffer 由来に戻る。
現在バッファ由来の解決はスイート内のバッファ状態に左右されるので、
実在する temp dir を明示して確認する。"
  (with-temp-dirs (d)
    (with-isolated-project-frames
     (ed::create-pseudo-frame "p")
     (project-bind-frame "Z:/a/")
     (project-unbind-frame)
     (list (project-frame-root)
	   (string-equal (project-current-root d) "Z:/a/"))))
  => (nil nil))

(deftest project-frame-history-snapshot ()
  "project-frame-save-history が (frame名 . root) を保存する"
  (let ((ed::*project-frame-history* nil))
    (with-isolated-project-frames
     (ed::create-pseudo-frame "init")
     (project-switch-to-project "Z:/p/")
     (project-frame-save-history)
     ed::*project-frame-history*))
  => (("p" . "Z:/p/")))

(deftest project-frame-restore-frames ()
  "*project-frame-history* から frame を再生成して紐付けを戻す"
  (let ((ed::*project-frame-history* '(("projx" . "Z:/x/"))))
    (with-isolated-project-frames
     (project-restore-project-frames)
     (list (mapcar #'ed::pseudo-frame-name ed::*pseudo-frame-list*)
	   (project-frame-root (ed::find-pseudo-frame "projx")))))
  => (("projx") "Z:/x/"))

(deftest project-frame-switch-without-frames ()
  "pseudo-frame が 1 つも無い環境でも switch は初期 frame を作って動く"
  (with-isolated-project-frames
   (project-switch-to-project "Z:/p/")
   (mapcar #'ed::pseudo-frame-name ed::*pseudo-frame-list*))
  => ("Frame 1" "p"))
