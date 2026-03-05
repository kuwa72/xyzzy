;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; sort.l --- treeview

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/10/21 17:08:57 +0900>

;;; Code:

(provide "wip/treeview/sort")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi")
  (require "wip/treeview/defs")
  (require "wip/treeview/winapi"))

(in-package "win-user")

(unless (boundp 'treeview-compare-lparam-ascending-proc)
  (defun-c-callable int treeview-compare-lparam-ascending-proc
    ((LPARAM lParam1) (LPARAM lParam2) (LPARAM lParamSort))
    (cond ((< lParam1 lParam2) -1)
          ((> lParam1 lParam2)  1)
          (t                    0))))

(in-package "treeview")

(defun treeview-sort-children-cb-lparam-ascending (hitem)
  (let ((tv-sort-cb (winapi::make-TVSORTCB))
        (hscrollp (zerop (logand winapi:TVS_NOHSCROLL
                                 (winapi:GetWindowStyle (treeview-get-htree))))))
    (setf (winapi::TVSORTCB-hParent tv-sort-cb) hitem)
    (setf (winapi::TVSORTCB-lpfnCompare tv-sort-cb) #'win-user::treeview-compare-lparam-ascending-proc)
    ;; 横スクロール停止
    (treeview-modify-style 0 winapi:TVS_NOHSCROLL 0)
;    (setf (winapi::TVSORTCB-lParam tv-sort-cb) 0)
    (treeview-sort-children-cb tv-sort-cb)
    ;; 横スクロール設定を元に戻す
    (when hscrollp
      (treeview::treeview-modify-style winapi:TVS_NOHSCROLL 0 0))))

;;; sort.l ends here
