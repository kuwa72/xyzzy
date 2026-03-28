;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-LaTeX.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:38 +0900>

;;; Code:

(provide "outline-tree/cr-LaTeX")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; LaTeX フォーマット
(defun outline-tree-create-outline-LaTeX (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("\\\\chapter\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?"
     "\\\\section\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?"
     "\\\\subsection\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?"
     "\\\\subsubsection\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?"
     "\\\\paragraph\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?"
     "\\\\subparagraph\\*?{\\(\\(?:[^}]\\|{[^}]*}\\)*\\)}?")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :top-miss
   :sub-type :heading-node
   :create-sub-outline-func
   #'(lambda (root-node)
       (outline-tree-create-outline-range-internal
        :root-node root-node
        :get-range-func #'outline-tree-create-outline-LaTeX-get-range-caption))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-LaTeX "LaTeX" '(:type-document :sequential)
 "LaTeX フォーマットを
    \\chapter{}
    \\section{}
    \\subsection{}
    \\subsubsection{}
    \\paragraph{}
    \\subparagraph{}
により階層表示します。")

;;
(defun outline-tree-create-outline-LaTeX-get-range-caption ()
  (let (begin-range end-range name)
    (save-excursion
      (when (scan-buffer "\\\\caption{" :regexp t :tail t)
        (setq begin-range (cons (match-beginning 0) (match-end 0)))
        (backward-char)
        (unless (goto-matched-parenthesis)
          (return-from outline-tree-create-outline-LaTeX-get-range-caption))
        (setq end-range (cons (point) (1+ (point))))
        (setq name (buffer-substring (outline-tree-get-range-to begin-range)
                                     (outline-tree-get-range-from end-range)))
        (values begin-range end-range name)))))

;;; cr-LaTeX.l ends here
