;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-Markdown.l --- outline-tree

;; Copyright (C) 2012 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2012/03/30 21:29:34 +0900>

;;; Code:

(provide "outline-tree/cr-Markdown")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")

(in-package "outline-tree2")

;; Markdown フォーマット
(defun outline-tree-create-outline-Markdown (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order :any-miss
   :layer-regexp-list '("^\\(\\(# .+\\)\\|\\(.+\\)\n=+\\)"
                        "^\\(\\(## .+\\)\\|\\(.+\\)\n-+\\)"
                        "^\\(### .+\\)"
                        "^\\(#### .+\\)"
                        "^\\(##### .+\\)"
                        "^\\(###### .+\\)")
   :layer-regexp-list-case-fold nil
   :sub-type :heading-node
   :line-oriented nil
   :title-converter #'outline-tree-create-outline-Markdown-title-converter))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-Markdown "Markdown" '(:type-document :line-oriented :sequential)
 "Markdown フォーマットをアウトライン表示します。")

;;
(defun outline-tree-create-outline-Markdown-title-converter (str)
  (if (string-match "^#" str)
      (progn
        (setq str (substitute-string str "^#+ " ""))
        (setq str (substitute-string str " #+$" ""))
        str)
    str))

;;; cr-Markdown.l ends here
