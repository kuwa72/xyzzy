;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-list-function.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:27:03 +0900>

;;; Code:

(provide "outline-tree/cr-list-function")

(require "listfn")
(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defun outline-tree-create-outline-list-function-possible-p (buffer)
  (save-excursion
    (set-buffer buffer)
    (and (boundp 'ed::build-summary-function)
         ed::build-summary-function)))

;; ed::build-summary-function 解析
(defun outline-tree-create-outline-list-function (root-node)
  (unless (boundp 'ed::build-summary-function)
    (return-from outline-tree-create-outline-list-function nil))
  (unless (and (eq ed::*list-function-buffer* (selected-buffer))
               (eql ed::*list-function-modified* (buffer-modified-count)))
    (setq ed::*list-function-list* (long-operation
                                     (save-excursion
                                       (funcall ed::build-summary-function)))
          ed::*list-function-selected* nil
          ed::*list-function-buffer* (selected-buffer)
          ed::*list-function-modified* (buffer-modified-count)))
  (when ed::*list-function-list*
    (let (from to title (list-function-list ed::*list-function-list*))
      (goto-char (point-min))
      (goto-line (car (car list-function-list)))
      (setq from (point))
      (setq title (cadr (car list-function-list)))
      (setq list-function-list (cdr list-function-list))
      (dolist (x list-function-list)
        (goto-line (car x))
        (setq to (point))
        (outline-tree-insert-range-node
         title root-node
         :whole-range (cons from to))
        (setq from to)
        (setq title (cadr x)))
      (outline-tree-insert-range-node
       title root-node
       :whole-range (cons from nil)))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-list-function "List Function" '(:type-program-general)
 "バッファに対応する ed::build-summary-function の関数を元に関数一覧を
作成し表示します。")

;;; cr-list-function.l ends here
