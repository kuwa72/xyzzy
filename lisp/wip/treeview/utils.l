;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; utils.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 13:03:34 +0900>

;;; Code:

(provide "wip/treeview/utils")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "wip/treeview/defs")
  (require "wip/treeview/macro"))

(in-package "treeview")

(defun treeview-get-tree-string (&optional (root-item (treeview-get-selected-item)))
  "treeview の階層構造テキストを返す。"
  (let ((item-text-tree (treeview-map-item-tree
                         (treeview-get-item-tree root-item) 'treeview-get-item-text))
        blank-output-p)
    (with-output-to-string (out)
      (labels ((treeview-get-tree-string-1 (sub-item-text-tree &optional (base-str ""))
                 (let ((last-sub-item-text-tree (car (last sub-item-text-tree))))
                   (dolist (item-text-tree sub-item-text-tree)
                     (setq blank-output-p nil)
                     (if (eq item-text-tree last-sub-item-text-tree)
                         (progn
                           (format out "~A~A[ ~A ]~%" base-str "└" (car item-text-tree))
                           (treeview-get-tree-string-1
                            (cdr item-text-tree) (concat base-str "   "))
                           (unless blank-output-p
                             (string-match "^.*[^ ]" base-str)
                             (format out "~A~%" (or (match-string 0) ""))
                             (setq blank-output-p t)))
                       (progn
                         (format out "~A~A[ ~A ]~%" base-str "├" (car item-text-tree))
                         (treeview-get-tree-string-1
                          (cdr item-text-tree) (concat base-str "｜ "))))))))
        (when item-text-tree
          (if (treeview-hitem-valid-p root-item)
              (format out "[ ~A ]~%" (car item-text-tree))
            (format out "~A~%" "<ROOT>"))
          (treeview-get-tree-string-1 (cdr item-text-tree) " "))))))

(defun treeview-insert-tree-text (&optional (root-item (treeview-get-selected-item)))
  "treeview の階層構造テキストを *TreeView* バッファに出力。"
  (interactive)
  (with-output-to-temp-buffer ("*TreeView*")
    (format t "~A" (treeview-get-tree-string root-item)))
  (refresh-screen))

;;; utils.l ends here
