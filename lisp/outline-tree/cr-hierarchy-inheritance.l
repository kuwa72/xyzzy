;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-hierarchy-inheritance.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:20 +0900>

;;; Code:

(provide "outline-tree/cr-hierarchy-inheritance")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-hierarchy-internal")

(in-package "outline-tree2")

;; 階層付きテキストフォーマット
(defun outline-tree-create-outline-hierarchy-dot (root-node)
  (outline-tree-create-outline-hierarchy-internal
   :root-node root-node
   :char #\.
   :sub-type :heading-node))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-hierarchy-dot "階層付きテキスト" '(:type-document :line-oriented :sequential)
 "階層付きテキストを階層表示します。
階層レベルは行頭の . (ドット)の数で指定します。")

;;; cr-hierarchy-inheritance.l ends here
