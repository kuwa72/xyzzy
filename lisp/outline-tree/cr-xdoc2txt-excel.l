;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-xdoc2txt-excel.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:28 +0900>

;;; Code:

(provide "outline-tree/cr-xdoc2txt-excel")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")

(in-package "outline-tree2")

;; xdoc2txt Excel フォーマット
(defun outline-tree-create-outline-xdoc2txt-excel (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^\\[\\(.+\\)\\]$")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :non-miss
   :sub-type :heading-node))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-xdoc2txt-excel "xdoc2txt : Excel" '(:type-data :line-oriented :sequential)
 "xdoc2txt によって変換された Excel フォーマットをアウトライン表示します。
アウトライン上にはシート名を表示します。")

;;; cr-xdoc2txt-excel.l ends here
