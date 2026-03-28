;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-xdoc2txt-pdf.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:34 +0900>

;;; Code:

(provide "outline-tree/cr-xdoc2txt-pdf")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;; xdoc2txt PDF ページ区切り
(defun outline-tree-create-outline-xdoc2txt-pdf (root-node)
  (let (from to title-range title)
    (goto-char (point-min))
    (loop
      (setq from (point))
      (if (scan-buffer "^--[0-9]+/[0-9]+--$" :regexp t)
          (progn
            (setq title (match-string 0))
            (setq title-range (cons (match-beginning 0) (match-end 0)))
            (goto-eol)
            (forward-char)
            (setq to (point))
            (outline-tree-insert-range-node
             title root-node
             :title-range title-range :whole-range (cons from to)
             :sub-type :heading-node))
        (progn
          (goto-char (point-max))
          (when (= from (point))
            (return))
          (outline-tree-insert-range-node
           "" root-node
           :title-range nil :whole-range (cons from nil)
           :sub-type :heading-node)
          (return))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-xdoc2txt-pdf "xdoc2txt : PDF (ページ区切り)" '(:type-data :line-oriented :sequential)
 "xdoc2txt によって変換された PDF フォーマットを、ページ番号で区切られた
テキストを 1 ノードとしてアウトライン表示します。
アウトライン上にはページ番号を表示します。")

;;; cr-xdoc2txt-pdf.l ends here
