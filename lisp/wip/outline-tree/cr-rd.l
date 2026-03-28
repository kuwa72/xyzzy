;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-rd.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/09/29 13:22:40 +0900>

;;; Code:

(provide "outline-tree/cr-rd")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; RD フォーマット
(defun outline-tree-create-outline-rd (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-rd-get-range-begin-end
   :child-only t
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-regexp-internal
        :root-node root-node
        :layer-regexp-list-order :any-miss
        :layer-regexp-list-case-fold nil
        :layer-regexp-list
        '("^=\\{1\\} \\(.*\\)"
          "^=\\{2\\} \\(.*\\)"
          "^=\\{3\\} \\(.*\\)"
          "^=\\{4\\} \\(.*\\)"
          "^\\+\\{1\\} \\(.*\\)"
          "^\\+\\{2\\} \\(.*\\)")
        :sub-type :heading-node
        :line-oriented t
        :title-converter #'outline-tree-create-outline-rd-text-converter
        :create-sub-outline-func #'outline-tree-create-outline-rd-listing))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-rd "RD" '(:type-document :line-oriented)
 "RD フォーマットをアウトライン表示します。")

;;
(defun outline-tree-create-outline-rd-listing (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-rd-get-range-listing
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-rd-listing root-node))))
(defun outline-tree-create-outline-rd-text-converter (str)
  (let ((org-str str))
    (setq str (substitute-string str "[ \t\n]+" " "))
    (when (and (plusp (length str)) (char= (char str 0) #\SPC))
      (setq str (substring str 1)))
    (if (plusp (length str))
        str org-str)))
(defun outline-tree-create-outline-rd-get-range-begin-end ()
  (let (begin-range end-range (name "") begin-end-p)
    (save-excursion
      (save-excursion
        (goto-char (point-min))
        (when (and (scan-buffer "^=begin[ \t]*$" :regexp t)
                   (scan-buffer "^=end[ \t]*$" :regexp t))
          (setq begin-end-p t)))
      (if begin-end-p
          (progn
            (when (scan-buffer "^=begin[ \t]*$" :regexp t)
              (forward-line)
              (setq begin-range (cons (point) (point)))
              (scan-buffer "^=end[ \t]*$" :regexp t)
              (setq end-range (cons (point) (point)))
              (return-from outline-tree-create-outline-rd-get-range-begin-end
                (values begin-range end-range name))))
        (when (/= (point) (point-max))
          (setq begin-range (cons (point) (point)))
          (setq end-range (cons (point-max) (point-max)))
          (values begin-range end-range name))))))
(defun outline-tree-create-outline-rd-get-range-listing ()
  (let (begin-range end-range name
        headchar headchar-column baseline-column headchar-regexp baseline-regexp)
    (save-excursion
      (when (scan-buffer "^\\( *\\)\\(\\(\\(\\*\\|([0-9]+)\\) *\\).*\\)" :regexp t)
        (setq headchar-column (progn (goto-char (match-end 1)) (current-column)))
        (setq baseline-column (progn (goto-char (match-end 3)) (current-column)))
        (setq headchar (string (char (match-string 2) 0)))
        (setq name (match-string 2))
        (setq begin-range (cons (match-beginning 0) (match-end 0)))
        (setq headchar-regexp
              (compile-regexp (format nil "^~V@{~A~:*~}~A" headchar-column " " headchar)))
        (setq baseline-regexp
              (compile-regexp (format nil "^~V@{~A~:*~}" baseline-column " ")))
        (setq name (substitute-string name "\\(^[^ ]+\\) +" "\\1 "))
        (loop
          (unless (forward-line)
            (goto-eol)
            (return))
          (unless (or (looking-at headchar-regexp)
                      (looking-at baseline-regexp))
            (setq end-range (cons (point) (point)))
            (return)))
        (unless end-range
          (setq end-range (cons (point-max) (point-max))))
        (values begin-range end-range name)))))

;;; cr-rd.l ends here
