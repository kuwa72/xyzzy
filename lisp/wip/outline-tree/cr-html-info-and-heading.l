;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-html-info-and-heading.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:28 +0900>

;;; Code:

(provide "outline-tree/cr-html-info-and-heading")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")
(require "outline-tree/cr-html-heading")
(require "outline-tree/cr-css")

(in-package "outline-tree2")

;; HTML情報&見出し 解析
(defun outline-tree-create-outline-html-info-and-heading (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-html-info-and-heading-get-range-css
   :child-only nil
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-css root-node)))
  (outline-tree-create-outline-html-heading root-node))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-html-info-and-heading "HTML (情報＆見出し)" '(:type-document)
 "HTML ファイルを各種情報とともに <H[1-6]>, <li> タグを元に見出し表示します。")

;;
(defun outline-tree-create-outline-html-info-and-heading-get-range-css ()
  (let (begin-range end-range
        matched-tag-range current-tag-range current-tag-type tagname)
    (save-excursion
      (when (scan-buffer "<style[^>]*>" :regexp t :case-fold t)
        (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
          (outline-tree-get-matched-tag))
        (when matched-tag-range
          (setq begin-range current-tag-range
                end-range matched-tag-range)
          (return-from outline-tree-create-outline-html-info-and-heading-get-range-css
            (values begin-range end-range "[CSS]")))))
    nil))
  

;;; cr-html-info-and-heading.l ends here
