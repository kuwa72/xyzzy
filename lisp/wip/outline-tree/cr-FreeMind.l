;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-FreeMind.l --- outline-tree

;; Copyright (C) 2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:28:58 +0900>

;;; Commentary:

;; Description:
;;
;;  FreeMind フォーマット解析
;;

;;; Code:

(provide "outline-tree/cr-FreeMind")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")
(require "outline-tree/public-utils")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-FreeMind-syntax-table* nil)
(unless *outline-tree-create-outline-FreeMind-syntax-table*
  (setq *outline-tree-create-outline-FreeMind-syntax-table* (make-syntax-table))
  (set-syntax-tag *outline-tree-create-outline-FreeMind-syntax-table* #\< #\>)
  (set-syntax-string *outline-tree-create-outline-FreeMind-syntax-table* #\"))

;; FreeMind フォーマット
(defun outline-tree-create-outline-FreeMind (root-node)
  (let ((org-syntax-table (syntax-table))
        (org-html-highlight-mode html-highlight-mode))
    (unwind-protect
        (progn
          (use-syntax-table *outline-tree-create-outline-FreeMind-syntax-table*)
          (setq html-highlight-mode t)
          (outline-tree-create-outline-FreeMind-1 root-node))
      (progn
        (use-syntax-table org-syntax-table)
        (setq html-highlight-mode org-html-highlight-mode)))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-FreeMind "FreeMind" '(:type-document)
 "FreeMind 用ファイル (.mm) を階層表示します。")

(defun outline-tree-create-outline-FreeMind-1 (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-FreeMind-get-range-tag
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-FreeMind-1 root-node))))

(defun outline-tree-create-outline-FreeMind-get-range-tag ()
  (let (begin-range end-range name
        matched-tag-range current-tag-range current-tag-type tagname)
    (save-excursion
      (loop
        (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
          (outline-tree-get-matched-tag))
        (when (and (string-equal tagname "node")
                   (or (and (eq current-tag-type :start-tag) matched-tag-range)
                       (eq current-tag-type :empty-element-tag)))
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
          (setq name (substitute-string name "^<.+? TEXT=\"\\(.*?\\)\".*$" "\\1"))
          (setq name (outline-tree-create-outline-FreeMind-entity-to-character name))
          (return-from outline-tree-create-outline-FreeMind-get-range-tag
            (values begin-range end-range name)))
        (unless (outline-tree-goto-next-tag)
          (return))))))

(defun outline-tree-create-outline-FreeMind-entity-to-character (str)
  (let ((return-str ""))
    (while (string-matchp "\\(\\(?:.\\|\n\\)*?\\)&#x\\([0-9a-f]+\\);\\(\\(?:.\\|\n\\)*\\)" str)
      (setq return-str (concat return-str
                               (match-string 1)
                               (string (unicode-char (parse-integer (match-string 2) :radix 16))))
            str (match-string 3)))
    (setq return-str (concat return-str str))
    return-str))

;;; cr-FreeMind.l ends here
