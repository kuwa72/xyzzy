;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-perl.l --- outline-tree

;; Copyright (C) 2006-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:43 +0900>

;;; Code:

(provide "outline-tree/cr-perl")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-perl-separate-comment* nil)

;; perl 解析
(defun outline-tree-create-outline-perl (root-node)
  (flet ((outline-tree-create-outline-perl-use (root-node section-name)
           (let (section-node range-node from to range-name)
             (goto-char (point-min))
             (setq section-node (outline-tree-insert-section-node section-name root-node))
             (while (scan-buffer "^use[ \t]+\\([^ \t\n]+\\)[ \t]*;" :regexp t)
               (setq from (point))
               (setq range-name (match-string 1))
               (goto-char (match-end 0))
               (setq to (1+ (match-end 0)))
               (setq range-node (outline-tree-insert-range-node
                                 range-name section-node :whole-range (cons from to))))
             (unless range-node
               (outline-tree-remove-section-node section-node))))
         (outline-tree-create-outline-perl-sub (root-node section-name)
           (let (section-node range-node range-name next-point from to
                 sub-from sub-to comment-from comment-to)
             (goto-char (point-min))
             (setq section-node (outline-tree-insert-section-node section-name root-node))
             (while (scan-buffer "^sub[ \t]+\\(.+?\\)[ \n]*{" :regexp t)
               (setq next-point (match-end 0))
               (setq sub-from (point))
               (setq range-name (match-string 1))
               (goto-char (match-end 0))
               (backward-char)
               (when (goto-matched-parenthesis)
                 (setq sub-to (1+ (point)))
                 (setq comment-from sub-from
                       comment-to sub-from)
                 (goto-char sub-from)
                 (goto-bol)
                 (while (previous-line)
                   (if (looking-at "^[ \t]*\\(#.*\\)?$")
                       (when (match-string 1)
                         (setq comment-from (point)))
                     (return)))
                 (if (< comment-from comment-to)
                     (setq from comment-from)
                   (setq from sub-from))
                 (setq to sub-to)
                 (setq range-node (outline-tree-insert-range-node
                                   range-name section-node :whole-range (cons from to)))
                 (when (and *outline-tree-create-outline-perl-separate-comment*
                            (< comment-from comment-to))
                   (outline-tree-insert-range-node
                    "コメント" range-node :whole-range (cons comment-from comment-to))
                   (outline-tree-insert-range-node
                    "定義" range-node :whole-range (cons sub-from sub-to))))
               (goto-char next-point))
             (unless range-node
               (outline-tree-remove-section-node section-node)))))
    (outline-tree-create-outline-perl-use root-node "[use]")
    (outline-tree-create-outline-perl-sub root-node "[sub]")))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-perl "Perl" '(:type-program)
 "Perl 言語の各種定義を列挙します。")

;;; cr-perl.l ends here
