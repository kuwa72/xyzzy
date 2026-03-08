;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; sample.config.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:03:11 +0900>

;;; Code:

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;; extended-key-translate-table 設定
(set-extended-key-translate-table exkey-C-tab #\F23)
(set-extended-key-translate-table exkey-C-return #\F20)

;; Editor <-> TreeView
; Editor -> TreeView
(global-set-key #\F23 'treeview::treeview-focus-treeview)
; TreeView (outline-tree) -> Editor
(define-key outline-tree2::*outline-tree-map* #\F23 'treeview::treeview-focus-editor)
;; outline 更新
(global-set-key #\F20 'outline-tree2::outline-tree-create-outline-and-select-node)
(define-key outline-tree2::*outline-tree-map*
            #\F20 'outline-tree2::outline-tree-create-outline-and-select-node)

;; ノード対応テキストハイライト
(setq *outline-tree-text-highlight-attribute*
      '(:background 3 :prefix #\T :extend t))

;;; sample.config.l ends here
