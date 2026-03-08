;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-hiki.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:24 +0900>

;;; Code:

(provide "outline-tree/cr-hiki")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-hierarchy-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; Hiki フォーマット
(defun outline-tree-create-outline-hiki (root-node)
  (outline-tree-create-outline-hierarchy-internal
   :root-node root-node
   :char #\!
   :depth 5
   :sub-type :heading-node
   :create-sub-outline-func
   #'(lambda (root-node)
       (outline-tree-create-outline-range-internal
        :root-node root-node
        :get-range-func #'outline-tree-create-outline-hiki-get-range-listing
        :child-only t
        :create-contents-outline-func
        #'(lambda (root-node range-name)
            (if (string= range-name "*")
                (outline-tree-create-outline-hiki-listing-item-asterisk root-node)
              (outline-tree-create-outline-hiki-listing-item-sharp root-node)))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-hiki "Hiki" '(:type-document :line-oriented :sequential)
 "Hiki フォーマットをアウトライン表示します。")

;;
(defun outline-tree-create-outline-hiki-get-range-listing ()
  (let (begin-range end-range name regexp)
    (save-excursion
      (when (scan-buffer "^[*#]" :regexp t)
        (setq begin-range (cons (point) (point)))
        (setq name (match-string 0))
        (setq regexp (compile-regexp (format nil "^~A" (regexp-quote name))))
        (loop
          (unless (forward-line)
            (return))
          (unless (looking-at regexp)
            (setq end-range (cons (point) (point)))
            (return)))
        (unless end-range
          (setq end-range (cons (point-max) (point-max))))))
    (values begin-range end-range name)))
(defun outline-tree-create-outline-hiki-listing-item-asterisk (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order :top-miss
   :layer-regexp-list '("^\\*\\{1\\}\\([^*].*\\)$"
                        "^\\*\\{2\\}\\([^*].*\\)$"
                        "^\\*\\{3\\}\\([^*].*\\)$")
   :layer-regexp-list-case-fold nil
   :line-oriented t))
(defun outline-tree-create-outline-hiki-listing-item-sharp (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order :top-miss
   :layer-regexp-list '("^#\\{1\\}\\([^#].*\\)$"
                        "^#\\{2\\}\\([^#].*\\)$"
                        "^#\\{3\\}\\([^#].*\\)$")
   :layer-regexp-list-case-fold nil
   :line-oriented t))

;;; cr-hiki.l ends here
