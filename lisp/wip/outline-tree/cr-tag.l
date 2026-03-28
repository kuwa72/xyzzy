;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-tag.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:28:51 +0900>

;;; Commentary:

;;; Code:

(provide "outline-tree/cr-tag")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")
(require "outline-tree/public-utils")

(in-package "outline-tree2")

(defun outline-tree-create-outline-tag-possible-p (buffer)
  (let ((table (syntax-table buffer)))
    (and html-highlight-mode
         (syntax-open-tag-p #\< table)
         (syntax-close-tag-p #\> table))))

(defvar *outline-tree-create-outline-tag-syntax-table* nil)
(unless *outline-tree-create-outline-tag-syntax-table*
  (setq *outline-tree-create-outline-tag-syntax-table* (make-syntax-table))
  (set-syntax-tag *outline-tree-create-outline-tag-syntax-table* #\< #\>)
  (set-syntax-string *outline-tree-create-outline-tag-syntax-table* #\"))

;; TAG 解析
(defun outline-tree-create-outline-tag (root-node)
  (let ((org-syntax-table (syntax-table))
        (org-html-highlight-mode html-highlight-mode))
    (unwind-protect
        (progn
          (use-syntax-table *outline-tree-create-outline-tag-syntax-table*)
          (setq html-highlight-mode t)
          (outline-tree-create-outline-tag-1 root-node))
      (progn
        (use-syntax-table org-syntax-table)
        (setq html-highlight-mode org-html-highlight-mode)))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-tag "<タグ> (HTML,XML)" '(:type-document)
 "開始タグ/終了タグのペア、空要素タグからなる階層構造を表示します。")

(defun outline-tree-create-outline-tag-1 (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-tag-get-range-tag
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-tag-1 root-node))))

(defun outline-tree-create-outline-tag-get-range-tag ()
  (let (begin-range end-range name
        matched-tag-range current-tag-range current-tag-type tagname)
    (save-excursion
      (loop
        (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
          (outline-tree-get-matched-tag))
        (when (or (and (eq current-tag-type :start-tag) matched-tag-range)
                  (eq current-tag-type :empty-element-tag))
          (cond
           ((eq current-tag-type :start-tag)
            (setq begin-range current-tag-range
                  end-range matched-tag-range
                  name (buffer-substring (outline-tree-get-range-from begin-range)
                                         (outline-tree-get-range-to begin-range))))
           ((eq current-tag-type :empty-element-tag)
            (setq begin-range current-tag-range
                  end-range (cons (outline-tree-get-range-to begin-range)
                                  (outline-tree-get-range-to begin-range))
                  name (buffer-substring (outline-tree-get-range-from begin-range)
                                         (outline-tree-get-range-to begin-range)))))
          (setq name (substitute-string name "[\t\n]" " "))
          (setq name (substitute-string name " +" " "))
          (return-from outline-tree-create-outline-tag-get-range-tag
            (values begin-range end-range name)))
        (unless (outline-tree-goto-next-tag)
          (return))))))

;; TAG 解析＋属性情報
(defun outline-tree-create-outline-tag2 (root-node)
  (let ((org-syntax-table (syntax-table))
        (org-html-highlight-mode html-highlight-mode))
    (unwind-protect
        (progn
          (use-syntax-table *outline-tree-create-outline-tag-syntax-table*)
          (setq html-highlight-mode t)
          (outline-tree-create-outline-tag2-1 root-node))
      (progn
        (use-syntax-table org-syntax-table)
        (setq html-highlight-mode org-html-highlight-mode)))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-tag2 "<タグ>＋属性 (HTML,XML)" '(:type-document)
 "開始タグ/終了タグのペア、空要素タグからなる階層構造を表示します。")

(defun outline-tree-create-outline-tag2-1 (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-tag-get-range-tag
   :create-begin-outline-func
     #'(lambda (root-node range-name)
         (outline-tree-create-outline-tag-create-begin-attributes root-node))
   :create-contents-outline-func
     #'(lambda (root-node range-name)
         (outline-tree-create-outline-tag2-1 root-node))))

(defun outline-tree-create-outline-tag-create-begin-attributes (root-node)
  (let (from to)
    (save-excursion
      (setq from (point-min) to (point-max))
      (goto-char (point-min))
      (when (scan-buffer "<[ \t\n]*[a-zA-Z0-9]+[ \t\n]*" :regexp t)
        (setq from (point)))
      (when (scan-buffer "/?>$" :regexp t)
        (setq to (point)))
      (narrow-to-region from to)
      (goto-char (point-min))
      (while (scan-buffer "[a-zA-Z0-9]+[ \t\n]*=[ \t\n]*[^ \t\n]+" :regexp t)
        (outline-tree-insert-info-node (match-string 0) root-node)
        (goto-char (match-end 0))))))

;;; cr-tag.l ends here
