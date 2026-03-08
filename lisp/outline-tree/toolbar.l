;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; toolbar.l --- outline-tree

;; Copyright (C) 2001-2007 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2007/07/04 17:14:53 +0900>

;;; Code:

(provide "outline-tree/toolbar")

(require "outline-tree/defs")
(require "wip/treeview/virtual-keys")

(in-package "outline-tree2")

(defun outline-tree-tool-bar-toggle-open-close ()
  (interactive)
  "アウトラインツリーを開閉する。
未起動時  ：起動し、オープン
クローズ時：オープン
オープン時：クローズ。Ctrl を押している場合終了"
  (let ((ctrl (or (minusp (winapi:GetKeyState winapi:VK_CONTROL))
                  (minusp (winapi:GetKeyState winapi:VK_LCONTROL))
                  (minusp (winapi:GetKeyState winapi:VK_RCONTROL)))))
    (cond
     ((not (outline-tree-exist-p))
      (outline-tree-create)
      (outline-tree-open))
     ((outline-tree-open-p)
      (if ctrl
          (outline-tree-delete)
        (outline-tree-close)))
     (t
      (outline-tree-open)))))

(defun outline-tree-tool-bar-toggle-exist ()
  (interactive)
  "アウトラインツリーを起動/終了する。
起動時    ：終了
未起動時  ：起動"
  (if (outline-tree-exist-p)
      (outline-tree-delete)
    (progn
      (outline-tree-create)
      (outline-tree-open))))

(defun outline-tree-tool-bar ()
  (create-tool-bar
   'outline-tree-tool-bar
   (merge-pathnames "etc/toolbar-outline-tree.bmp" (si:system-root))
   `(
;     ("アウトラインツリー" 0 outline-tree-tool-bar-toggle-open-close
;      ,#'(lambda () (and (outline-tree-open-p) :check)))
     ("アウトラインツリー" 0 outline-tree-tool-bar-toggle-exist
      ,#'(lambda () (and (outline-tree-exist-p) :check)))
     )))

(define-command-bar 'outline-tree-tool-bar "アウトラインツリー(&O)")

(add-hook '*outline-tree-uninstall-hook*
          #'(lambda () (delete-command-bar 'outline-tree-tool-bar)))

;;; toolbar.l ends here
