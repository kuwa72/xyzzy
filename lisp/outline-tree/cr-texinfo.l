;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-texinfo.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:15 +0900>

;;; Code:

(provide "outline-tree/cr-texinfo")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; Texinfo フォーマット
(defun outline-tree-create-outline-texinfo (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^[ \t]*@\\(?:top\\|majorheading\\)[ \t]+\\(.*\\)"
     "^[ \t]*@\\(?:chapter\\|unnumbered\\|appendix\\|chapheading\\)[ \t]+\\(.*\\)"
     "^[ \t]*@\\(?:section\\|unnumberedsec\\|appendixsec\\|heading\\)[ \t]+\\(.*\\)"
     "^[ \t]*@\\(?:subsection\\|unnumberedsubsec\\|appendixsubsec\\|subheading\\)[ \t]+\\(.*\\)"
     "^[ \t]*@\\(?:subsubsection\\|unnumberedsubsubsec\\|appendixsubsubsec\\|subsubheading\\)[ \t]+\\(.*\\)")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :top-miss
   :sub-type :heading-node
   :create-sub-outline-func
   #'(lambda (root-node)
       (outline-tree-create-outline-range-internal
        :root-node root-node
        :get-range-func #'outline-tree-create-outline-texinfo-get-range-item))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-texinfo "Texinfo" '(:type-document :line-oriented :sequential)
 "Texinfo フォーマットをアウトライン表示します。")

;;
(defun outline-tree-create-outline-texinfo-get-range-item ()
  (let (begin-range end-range name begin-to end-from end-from1 end-from2)
    (save-excursion
      (when (scan-buffer "^[ \t]*@item[ \t\n]+" :regexp t)
        (setq begin-range (cons (point) (match-end 0)))
        (setq begin-to (match-end 0))
        (goto-char begin-to)
        (if (scan-buffer "^[ \t]*@item[ \t\n]+" :regexp t)
            (setq end-from1 (point))
          (setq end-from1 (point-max)))
        (goto-char begin-to)
        (if (scan-buffer "^$" :regexp t)
            (setq end-from2 (point))
          (setq end-from2 (point-max)))
        (if (< end-from1 end-from2)
            (setq end-from end-from1)
          (setq end-from end-from2))
        (setq end-range (cons end-from end-from))
        (setq name (buffer-substring (cdr begin-range) (car end-range)))
        (setq name (substitute-string name "[ \t\n]+" " "))))
    (values begin-range end-range name)))

;;; cr-texinfo.l ends here
