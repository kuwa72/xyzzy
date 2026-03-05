;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; unicode.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/12/14 02:06:28 +0900>

;;; Code:

(provide "wip/treeview/unicode")

(require "wip/treeview/defs")
(require "wip/treeview/winapi")

(in-package "treeview")

(defun treeview-insert-item (text parent &key icon sicon (insertafter winapi:TVI_LAST)
                                  (state 0) (statemask 0) (lparam 0))
  "treeview に item を追加。(unicode版)"
  (let ((mask winapi:TVIF_TEXT)
        (lpitemex (winapi::make-TVITEMEXW))
        (lpis (winapi::make-TVINSERTSTRUCTW)))
    (si:clear-chunk lpitemex)
    (si:clear-chunk lpis)
    (if (null icon)
        (setq icon 0)
      (setq mask (logior mask winapi:TVIF_IMAGE)))
    (if (null sicon)
        (setq sicon 0)
      (setq mask (logior mask winapi:TVIF_SELECTEDIMAGE)))
    (setf (winapi:TVITEMEXW-mask lpitemex) mask)
    (setf (winapi:TVITEMEXW-hItem lpitemex) 0)
    (setf (winapi:TVITEMEXW-state lpitemex) state)
    (setf (winapi:TVITEMEXW-stateMask lpitemex) statemask)
    (setf (winapi:TVITEMEXW-pszText lpitemex) (si:make-string-chunk (map-internal-to-ucs-2 (concat text "\0"))))
    (setf (winapi:TVITEMEXW-cchTextMax lpitemex) 0)
    (setf (winapi:TVITEMEXW-iImage lpitemex) icon)
    (setf (winapi:TVITEMEXW-iSelectedImage lpitemex) sicon)
    (setf (winapi:TVITEMEXW-cChildren lpitemex) 0)
    (setf (winapi:TVITEMEXW-lParam lpitemex) lparam)
    (setf (winapi:TVITEMEXW-iIntegral lpitemex) 0)
    (setf (winapi:TVINSERTSTRUCTW-hParent lpis) parent)
    (setf (winapi:TVINSERTSTRUCTW-hInsertAfter lpis) insertafter)
    (setf (winapi:TVINSERTSTRUCTW-itemex lpis) lpitemex)
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_INSERTITEMW 0 lpis)))

(defun treeview-get-item (pitem); TVITEMW*
  "TVITEM 構造体へのポインタを渡し、item を取得。(unicode版)"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETITEMW 0 pitem))

(defun treeview-get-item-state (hitem statemask)
  "item の state を取得。(unicode版)"
  (let ((pitem (winapi:make-TVITEMW)))
    (si:clear-chunk pitem)
    (setf (winapi:TVITEMW-mask pitem) winapi:TVIF_STATE)
    (setf (winapi:TVITEMW-hItem pitem) hitem)
    (setf (winapi:TVITEMW-stateMask pitem) statemask)
    (treeview-get-item pitem)
    (si:unpack-uint32 pitem (c:c-struct-offset-of winapi::TVITEMW winapi::state))))

(defun treeview-get-item-text (hitem &optional (maxlen 1024))
  "item の text を取得。(unicode版)"
  (let ((text (si:make-chunk nil maxlen))
        (pitem (winapi:make-TVITEMW)))
    (si:clear-chunk text)
    (si:clear-chunk pitem)
    (setf (winapi:TVITEMW-mask pitem) winapi:TVIF_TEXT)
    (setf (winapi:TVITEMW-hItem pitem) hitem)
    (setf (winapi:TVITEMW-pszText pitem) (si:chunk-data text))
    (setf (winapi:TVITEMW-cchTextMax pitem) maxlen)
    (treeview-get-item pitem)
    (string-right-trim "\0" (map-ucs-2-to-internal
                             (si:unpack-string text 0 maxlen nil)))))

(defun treeview-get-item-data (hitem)
  "item の Application 固有データを取得。(unicode版)"
  (let ((pitem (winapi:make-TVITEMW)))
    (si:clear-chunk pitem)
    (setf (winapi:TVITEMW-mask pitem) winapi:TVIF_PARAM)
    (setf (winapi:TVITEMW-hItem pitem) hitem)
    (treeview-get-item pitem)
    (si:unpack-int32 pitem (c:c-struct-offset-of winapi::TVITEMW winapi::lParam))))

(defun treeview-set-item (hitem mask text icon sicon state statemask lparam)
  "item に各種値を設定。(unicode版)"
  (let ((pitem (winapi:make-TVITEMW)))
    (si:clear-chunk pitem)
    (setf (winapi::TVITEMW-mask pitem) mask)
    (setf (winapi::TVITEMW-hItem pitem) hitem)
    (setf (winapi::TVITEMW-state pitem) state)
    (setf (winapi::TVITEMW-stateMask pitem) statemask)
    (setf (winapi::TVITEMW-pszText pitem) (si:make-string-chunk (map-internal-to-ucs-2 (concat text "\0"))))
    (setf (winapi::TVITEMW-cchTextMax pitem) 0)
    (setf (winapi::TVITEMW-iImage pitem) icon)
    (setf (winapi::TVITEMW-iSelectedImage pitem) sicon)
    (setf (winapi::TVITEMW-cChildren pitem) 0)
    (setf (winapi::TVITEMW-lParam pitem) lparam)
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETITEMW 0 pitem)))

(defun treeview-set-item-state (hitem state statamask)
  "item に state を設定。(unicode版)"
  (treeview-set-item hitem winapi:TVIF_STATE "" 0 0 state statemask 0))

(defun treeview-set-item-text (hitem text)
  "item に text を設定。(unicode版)"
  (treeview-set-item hitem winapi:TVIF_TEXT text 0 0 0 0 0))

(defun treeview-set-item-data (hitem data)
  "item に Application 固有データを設定。(unicode版)"
  (treeview-set-item hitem winapi:TVIF_PARAM "" 0 0 0 0 data))

;;; unicode.l ends here
