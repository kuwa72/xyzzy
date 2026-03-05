;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; defs.l --- treeview

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/11/03 05:59:25 +0900>

;;; Code:

(provide "wip/treeview/defs")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package "treeview")
    (defpackage "treeview"
      (:use "lisp" "editor")
      (:nicknames "tv"))))

(in-package "treeview")

(defvar *treeview-version* "2006.11.03")
(defvar *treeview-prog-name* "TreeView")

(defvar *treeview-buffer-prefix*
  (format nil "*~A " *treeview-prog-name*))

(defvar *treeview-uninstall-hook* nil)
(defvar *treeview-history-variable-list* nil)

(defvar *treeview-delete-hook* nil)

(defvar *treeview-dll-load-path*
  (list
   (user-homedir-pathname)
   (si:system-root)
   (etc-path)
   (merge-pathnames "etc" (si:system-root))
   (merge-pathnames "lisp/wip" (si:system-root))
   (merge-pathnames "lisp/wip/treeview" (si:system-root))
   "")
  "TreeView.dll 検索パス")

(defvar *treeview-id* nil
  "現在の操作対象 treeview-id (直接値の設定は禁止)")
(defvar *treeview-last-id* nil
  "最後の操作対象 treeview-id (直接値の設定は禁止)")
(defvar *treeview-app-id* nil
  "現在の操作対象 app-id (直接値の設定は禁止)")
(defvar *treeview-last-app-id* nil
  "最後の操作対象 app-id (直接値の設定は禁止)")
(defvar *treeview-app-to-treeview-hash* (make-hash-table :test #'eql))
(defvar *treeview-treeview-to-app-hash* (make-hash-table :test #'eql))
(defvar *treeview-app-id-list* nil "app-id のリスト")
(defvar *treeview-data-hash* (make-hash-table :test #'eql) "app-id に関連するデータ")
(defvar *treeview-data-reference-hash* (make-hash-table :test #'eql)
  "app-id に関連するデータを登録する symbol")

(defun treeview-register-history-variables ()
  (register-history-variable *treeview-history-variable-list*))

(defun treeview-unregister-history-variables ()
  "treeview 関連ヒストリの削除"
  ;; 明示的に指定したヒストリを削除
  (dolist (variable *treeview-history-variable-list*)
    (unregister-history-variable variable))
  ;; treeview パッケージのヒストリを全削除
  (let ((package (find-package "treeview")))
    (dolist (x (copy-list ed::*history-variable-list*))
      (if (eq (symbol-package x) package)
          (unregister-history-variable x)))))

(defun treeview-uninstall ()
  "treeview ライブラリのアンインストール"
  (interactive)
  (run-hooks '*treeview-uninstall-hook*)
  (treeview-unregister-history-variables))

;;; defs.l ends here
