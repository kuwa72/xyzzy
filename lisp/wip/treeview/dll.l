;;; -*- Mode: Lisp; Package: TREEVIEW -*-
;;; dll.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 12:53:56 +0900>

;;; Code:

(provide "wip/treeview/dll")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi"))

(require "wip/treeview/defs")

(in-package "treeview")

(export '(treeview-dll-define-function
          treeview-dll-pathname))

(if (and (fboundp 'treeview-exist-p)
         (treeview-exist-p))
    (treeview-delete))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; xpi.h
(c:*define XPIS_LEFT    0)
(c:*define XPIS_TOP     1)
(c:*define XPIS_RIGHT   2)
(c:*define XPIS_BOTTOM  3)
(c:*define XPIS_NOMOVE  4)
(c:*define XPIS_POSMASK 7)
(c:*define XPIS_ORDMASK #x30)
(c:*define XPIS_OUTSIDE #x10)
(c:*define XPIS_INSIDE  #x20)
(c:*define XPIS_NOORDER #x30)
(c:*define XPIS_GROUP   #x40)

(defun treeview-dll-define-function (dll)
  "treeview.dll を直接用いる関数の定義"
  (let* ((dll-exist-p (and (file-exist-p dll)
                           (not (file-directory-p dll))))
         (fullpath (if dll-exist-p (truename dll) dll)))
    (if (and (fboundp 'treeview-exist-p)
             (treeview-exist-p))
        (treeview-delete))
    (c:define-dll-entry c:int treeview-dll-create (winapi:HWND (c:void *)) dll "Create")
    (c:define-dll-entry c:int treeview-dll-create-ex (winapi:HWND (c:void *) c:int winapi:DWORD) dll "CreateEx")
    (c:define-dll-entry c:int treeview-dll-delete (c:int) dll "Close")
    (c:define-dll-entry winapi:HWND treeview-dll-get-hwnd (c:int) dll "GetHwnd")
    (c:define-dll-entry winapi:HWND treeview-dll-get-htree (c:int) dll "GetHtree")
    (c:define-dll-entry winapi:BOOL treeview-dll-modify-style (c:int winapi:DWORD winapi:DWORD winapi:UINT) dll "ModifyStyle")
    (c:define-dll-entry winapi:BOOL treeview-dll-setsize (c:int c:int c:int c:int c:int) dll "SetSize")
    (c:define-dll-entry winapi:BOOL treeview-dll-setpos (c:int winapi:DWORD) dll "SetPos")
    
    (c:define-dll-entry winapi:UINT treeview-dll-get-count (c:int) dll "GetCount")
    ;; GetIndent
    ;; SetIndent
    ; GetImageList
    ; SetImageList
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-next-item (c:int winapi:HTREEITEM winapi:UINT) dll "GetNextItem")
    (c:define-dll-entry winapi:BOOL treeview-dll-item-has-children (c:int winapi:HTREEITEM) dll "ItemHasChildren")
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-child-item (c:int winapi:HTREEITEM) dll "GetChildItem")
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-next-sibling-item (c:int winapi:HTREEITEM) dll "GetNextSiblingItem")
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-prev-sibling-item (c:int winapi:HTREEITEM) dll "GetPrevSiblingItem")
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-parent-item (c:int winapi:HTREEITEM) dll "GetParentItem")
    ;; GetFirstVisibleItem
    ;; GetNextVisibleItem
    ;; GetPrevVisibleItem
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-selected-item (c:int) dll "GetSelectedItem")
    ; GetDropHilightItem
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-get-root-item (c:int) dll "GetRootItem")
    (c:define-dll-entry winapi:BOOL treeview-dll-get-item (c:int (winapi:TVITEM *)) dll "GetItem")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-item
      (c:int winapi:HTREEITEM winapi:UINT winapi:LPCTSTR c:int c:int winapi:UINT winapi:UINT winapi:LPARAM) dll "SetItem")
    (c:define-dll-entry winapi:UINT treeview-dll-get-item-state (c:int winapi:HTREEITEM winapi:UINT) dll "GetItemState")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-item-state (c:int winapi:HTREEITEM winapi:UINT winapi:UINT) dll "SetItemState")
    ; GetItemImage
    ; SetItemImage
    (c:define-dll-entry winapi:BOOL treeview-dll-get-item-text (c:int winapi:HTREEITEM winapi:LPTSTR c:int) dll "GetItemText")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-item-text (c:int winapi:HTREEITEM winapi:LPCTSTR) dll "SetItemText")
    (c:define-dll-entry winapi:DWORD treeview-dll-get-item-data (c:int winapi:HTREEITEM) dll "GetItemData")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-item-data (c:int winapi:HTREEITEM winapi:DWORD) dll "SetItemData")
    ;; GetItemRect
    ; GetEditControl
    ;; GetVisibleCount
    ; GetToolTips
    ;; GetBkColor
    ;; SetBkColor
    ;; GetItemHeight
    ;; SetItemHeight
    ;; GetTextColor
    ;; SetTextColor
    ;; SetInsertMark
    ; GetCheck
    ; SetCheck
    ;; GetInsertMarkColor
    ;; SetInsertMarkColor

    ;; 操作
    (c:define-dll-entry winapi:HTREEITEM treeview-dll-insert-item
      (c:int winapi:UINT winapi:LPCTSTR c:int c:int winapi:UINT winapi:UINT winapi:LPARAM winapi:HTREEITEM winapi:HTREEITEM) dll "InsertItem")
    (c:define-dll-entry winapi:BOOL treeview-dll-delete-item (c:int winapi:HTREEITEM) dll "DeleteItem")
    (c:define-dll-entry winapi:BOOL treeview-dll-delete-all-items (c:int) dll "DeleteAllItems")
    (c:define-dll-entry winapi:BOOL treeview-dll-expand (c:int winapi:HTREEITEM winapi:UINT) dll "Expand")
    (c:define-dll-entry winapi:BOOL treeview-dll-select (c:int winapi:HTREEITEM winapi:UINT) dll "Select")
    ;; SelectItem
    ; SelectDropTarget
    ; SelectSetFirstVisible
    (c:define-dll-entry winapi:HWND treeview-dll-edit-label (c:int winapi:HTREEITEM) dll "EditLabel")
    ;; HitTest
    ; CreateDragImage
    (c:define-dll-entry winapi:UINT treeview-dll-sort-children (c:int winapi:HTREEITEM) dll "SortChildren")
    ;; EnsureVisible
    ;; SortChildrenCB

    ;; callback
    (c:define-dll-entry winapi:BOOL treeview-dll-set-click-callback (c:int (c:void *)) dll "SetClickCallback")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-dblclk-callback (c:int (c:void *)) dll "SetDblclkCallback")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-rclick-callback (c:int (c:void *)) dll "SetRclickCallback")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-keydown-callback (c:int (c:int *)) dll "SetKeyDownCallback")
    (c:define-dll-entry winapi:BOOL treeview-dll-set-edit-label-callback (c:int (c:void *)) dll "SetEditLabelCallback")

    ;; icon
    (c:define-dll-entry c:int treeview-dll-add-file-icon (c:int winapi:LPCTSTR) dll "AddFileIcon")
    (c:define-dll-entry c:int treeview-dll-add-icon (c:int winapi:HICON) dll "AddIcon")
    (c:define-dll-entry winapi:BOOL treeview-dll-remove-icon (c:int c:int) dll "RemoveIcon")
    (c:define-dll-entry winapi:BOOL treeview-dll-remove-all-icons (c:int) dll "RemoveAllIcons")

    ;; その他
    (c:define-dll-entry winapi:BOOL treeview-dll-disable-char-jump (c:int winapi:BOOL) dll "DisableCharJump")
    (c:define-dll-entry c:int treeview-dll-simple-track-popup-menu (winapi:LPCTSTR) dll "SimpleTrackPopupMenu")

    (defun treeview-dll-pathname ()
      "使用している dll のパスを返す"
      fullpath)
    (gc)
    dll-exist-p))

(let (dll (dll-filename "TreeView.dll"))
  (dolist (dir *treeview-dll-load-path*
               (treeview-dll-define-function dll-filename))
    (when (and dir
               (file-exist-p (setq dll (merge-pathnames dll-filename dir))))
      (treeview-dll-define-function dll)
      (return))))

;;; dll.l ends here
