;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; expand.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:09:19 +0900>

;;; Code:

(provide "outline-tree/expand")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defun outline-tree-expand-expand-subtree (node &optional (depth t))
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-expand-expand node :child t :depth depth)))

(defun outline-tree-expand-collapse-subtree (node &optional (depth t))
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-expand-collapse node :child t :depth depth)))

(defun outline-tree-expand-expand-if-has-heading-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (let (child-node)
      (when (outline-tree-node-has-children-p node)
        (setq child-node (treeview::treeview-get-child-item node))
        (while (outline-tree-node-valid-p child-node)
          (when (outline-tree-heading-node-p child-node)
            (treeview::treeview-expand-expand node)
            (return))
          (setq child-node (treeview::treeview-get-next-sibling-item child-node))))))
  t)
(defun outline-tree-expand-expand-subtree-show-heading-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-funcall-recursive-tree-top-down
     node #'outline-tree-expand-expand-if-has-heading-node)))

;;; expand.l ends here
