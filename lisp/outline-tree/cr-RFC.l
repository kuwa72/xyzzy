;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-RFC.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:05 +0900>

;;; Code:

(provide "outline-tree/cr-RFC")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;; RFC 解析
(defun outline-tree-create-outline-RFC (root-node)
  (goto-char (point-min))
  (let (from name next-from next-name next-point
        range-node-exist-p range-node parent-node
        parent-node-stack parent-node-stack-reverse
        pre-section-split section-split section-split-reverse)
    (setq from (point-min))
    (setq name "<HEADER>")
    (while (scan-buffer "^\n\\([^ \t\n\x0c].*?\\)[ \t]*\n\n" :regexp t)
      (setq next-from (match-beginning 1))
      (setq next-name (match-string 1))
      (setq next-point (match-end 1))
      (if (string-match "^\\([0-9]+\\(\\.[0-9]+\\)*\\)" name)
          (setq section-split (split-string (match-string 1) "."))
        (setq section-split nil))
      (dolist (number section-split)
        (push number section-split-reverse)
        (if (string-equal (pop pre-section-split) number)
            (push (pop parent-node-stack) parent-node-stack-reverse)
          (return)))
      (setq range-node (outline-tree-insert-range-node
                        name
                        (or (car parent-node-stack-reverse) root-node)
                        :whole-range (cons from next-from)
                        :sub-type (if range-node-exist-p :heading-node nil)))
      (setq range-node-exist-p t)
      (push range-node parent-node-stack-reverse)
      (setq parent-node-stack (nreverse parent-node-stack-reverse))
      (setq parent-node-stack-reverse nil)
      (setq pre-section-split (nreverse section-split-reverse))
      (setq section-split-reverse nil)
      (setq from next-from)
      (setq name next-name)
      (goto-char next-point))
    (if (string-match "^\\([0-9]+\\(\\.[0-9]+\\)*\\)" name)
        (setq section-split (split-string (match-string 1) "."))
      (setq section-split nil))
    (dolist (number section-split)
      (push number section-split-reverse)
      (if (string-equal (pop pre-section-split) number)
          (push (pop parent-node-stack) parent-node-stack-reverse)
        (return)))
    (outline-tree-insert-range-node
     name
     (or (car parent-node-stack-reverse) root-node)
     :whole-range (cons from nil)
     :sub-type (if range-node-exist-p :heading-node nil))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-RFC "RFC" '(:type-document :sequential)
 "RFC の見出しをアウトライン表示します。")

;;; cr-RFC.l ends here
