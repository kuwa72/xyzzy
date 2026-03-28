;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-css.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:05 +0900>

;;; Code:

(provide "outline-tree/cr-css")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; CSS フォーマット
(defun outline-tree-create-outline-css (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-css-get-range-selector
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-range-internal
        :root-node root-node
        :get-range-func #'outline-tree-create-outline-css-get-range-attribute))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-css "CSS" '(:type-document)
 "Cascading Style Sheets ファイルを selector, property 毎に表示します。")

;;
(defun outline-tree-create-outline-css-get-range-selector ()
  (let (begin-range end-range name)
    (save-excursion
      (while (scan-buffer "^[ \t]*\\(.+?\\)[ \t\n]*{" :regexp t :tail t)
        (setq begin-range (cons (match-beginning 0) (match-end 0)))
        (setq name (match-string 1))
        (backward-char)
        (when (goto-matched-parenthesis)
          (setq end-range (cons (point) (1+ (point))))
          (return-from outline-tree-create-outline-css-get-range-selector
            (values begin-range end-range name)))))))
(defun outline-tree-create-outline-css-get-range-attribute ()
  (let (begin-range end-range name)
    (save-excursion
      (when (scan-buffer "[ \t]*\\([^ :\n]+\\)[ \t]*:[^;]*" :regexp t)
        (setq begin-range (cons (match-beginning 0) (match-beginning 0)))
        (setq end-range (cons (match-end 0) (match-end 0)))
        (setq name (match-string 1))
        (return-from outline-tree-create-outline-css-get-range-attribute
          (values begin-range end-range name))))))

;;; cr-css.l ends here
