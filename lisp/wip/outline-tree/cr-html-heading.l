;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-html-heading.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/05/22 12:44:36 +0900>

;;; Code:

(provide "outline-tree/cr-html-heading")

(require "outline-tree/outline-tree")
(require "outline-tree/public-utils")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; HTML見出し 解析
(defun outline-tree-create-outline-html-heading (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-html-heading-get-range-body
   :child-only t
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-regexp-internal
        :root-node root-node
        :layer-regexp-list-order :any-miss
        :layer-regexp-list
        '("[ \t]*<h1[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h1>"
          "[ \t]*<h2[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h2>"
          "[ \t]*<h3[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h3>"
          "[ \t]*<h4[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h4>"
          "[ \t]*<h5[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h5>"
          "[ \t]*<h6[^>]*>[ \t\n]*\\(\\(?:.\\|\n\\)*?\\)[ \t\n]*</h6>")
        :layer-regexp-list-case-fold t
        :sub-type :heading-node
        :title-converter #'outline-tree-create-outline-html-heading-title-converter
        :create-sub-outline-func #'outline-tree-create-outline-html-heading-listing))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-html-heading "HTML (見出し)" '(:type-document)
 "HTML ファイルを <H[1-6]>, <li> タグを元に見出し表示します。")

;;
(defun outline-tree-create-outline-html-heading-get-range-body ()
  (let (begin-range end-range (name "") body-exist-p
        matched-tag-range current-tag-range current-tag-type tagname)
    (save-excursion
      (save-excursion
        (goto-char (point-min))
        (loop
          (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
            (outline-tree-get-matched-tag))
          (when (and matched-tag-range (eq current-tag-type :start-tag)
                     (string-equal tagname "body"))
            (setq body-exist-p t)
            (return))
          (unless (outline-tree-goto-next-tag)
            (return))))
      (loop
        (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
          (outline-tree-get-matched-tag))
        (when (and matched-tag-range (eq current-tag-type :start-tag)
                   (string-equal tagname "body"))
          (setq begin-range current-tag-range
                end-range matched-tag-range
                name tagname)
          (goto-char (outline-tree-get-range-to begin-range))
          (skip-chars-forward " \t")
          (if (char= (char-after (point)) #\LFD)
              (forward-char))
          (when (<= (point) (outline-tree-get-range-from end-range))
            (rplacd begin-range (point)))
          (return-from outline-tree-create-outline-html-heading-get-range-body
            (values begin-range end-range name)))
        (unless (outline-tree-goto-next-tag)
          (if (/= (point) (point-max))
              (progn
                (setq begin-range (cons (point) (point)))
                (setq end-range (cons (point-max) (point-max)))
                (return-from outline-tree-create-outline-html-heading-get-range-body
                  (values begin-range end-range name)))
            (return-from outline-tree-create-outline-html-heading-get-range-body)))))))
(defun outline-tree-create-outline-html-heading-get-range-listing ()
  (let (begin-range end-range name
        matched-tag-range current-tag-range current-tag-type tagname)
    (save-excursion
      (loop
        (multiple-value-setq (matched-tag-range current-tag-range current-tag-type tagname)
          (outline-tree-get-matched-tag))
        (when (and matched-tag-range (eq current-tag-type :start-tag)
                   (or (string-equal tagname "ul") (string-equal tagname "ol")
                       (string-equal tagname "dl")))
          (setq begin-range current-tag-range
                end-range matched-tag-range
                name tagname)
          (return-from outline-tree-create-outline-html-heading-get-range-listing
            (values begin-range end-range name)))
        (unless (outline-tree-goto-next-tag)
          (return))))))
(defun outline-tree-create-outline-html-heading-get-range-listing-item ()
  (let (begin-range end-range name name-from name-to
        tag-range tag-type tagname
        matched-tag-range current-tag-range current-tag-type)
    (save-excursion
      (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag))
      (unless tag-range
        (outline-tree-goto-next-tag)
        (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag)))
      (unless (and tag-range (string-equal tagname "li") (eq tag-type :start-tag))
        (return-from outline-tree-create-outline-html-heading-get-range-listing-item))
      (setq begin-range tag-range)
      (goto-char (outline-tree-get-range-to tag-range))
      (loop
        (unless (outline-tree-goto-next-tag)
          (return))
        (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag))
        (cond ((string-equal tagname "li")
               (if (eq tag-type :start-tag)
                   (setq end-range (cons (outline-tree-get-range-from tag-range)
                                         (outline-tree-get-range-from tag-range)))
                 (setq end-range tag-range))
               (return))
              ((eq tag-type :start-tag)
               (outline-tree-goto-matched-tag))))
      (unless end-range
        (setq end-range (cons (point-max) (point-max))))
      (save-restriction
        (narrow-to-region (outline-tree-get-range-to begin-range)
                          (outline-tree-get-range-from end-range))
        (goto-char (point-min))
        (when (looking-at "[ \t\n]+")
          (goto-char (match-end 0)))
        (setq name-from (point))
        (unless (scan-buffer "\\(<\\(\/?li\\|ul\\|ol\\)\\)" :regexp t :case-fold t)
          (goto-char (point-max)))
        (while (member (char-before (point)) '(#\SPC #\TAB #\LFD))
          (backward-char))
        (setq name-to (point))
        (setq name (buffer-substring name-from name-to))
        (setq name (outline-tree-create-outline-html-heading-title-converter name)))
      (return-from outline-tree-create-outline-html-heading-get-range-listing-item
        (values begin-range end-range name)))))
(defun outline-tree-create-outline-html-heading-get-range-listing-definition ()
  (let (begin-range end-range name name-from name-to
        tag-range tag-type tagname
        matched-tag-range current-tag-range current-tag-type)
    (save-excursion
      (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag))
      (unless tag-range
        (outline-tree-goto-next-tag)
        (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag)))
      (unless (and tag-range (string-equal tagname "dt") (eq tag-type :start-tag))
        (return-from outline-tree-create-outline-html-heading-get-range-listing-definition))
      (setq begin-range tag-range)
      (goto-char (outline-tree-get-range-to tag-range))
      (loop
        (unless (outline-tree-goto-next-tag)
          (return))
        (multiple-value-setq (tag-range tag-type tagname) (outline-tree-get-current-tag))
        (cond ((and (string-equal tagname "dt") (eq tag-type :start-tag))
               (setq end-range (cons (outline-tree-get-range-from tag-range)
                                     (outline-tree-get-range-from tag-range)))
               (return))
              ((eq tag-type :start-tag)
               (outline-tree-goto-matched-tag))))
      (unless end-range
        (setq end-range (cons (point-max) (point-max))))
      (save-restriction
        (narrow-to-region (outline-tree-get-range-to begin-range)
                          (outline-tree-get-range-from end-range))
        (goto-char (point-min))
        (when (looking-at "[ \t\n]+")
          (goto-char (match-end 0)))
        (setq name-from (point))
        (unless (scan-buffer "\\(<\\(\/?dt\\|dd\\|dl\\)\\)" :regexp t :case-fold t)
          (goto-char (point-max)))
        (while (member (char-before (point)) '(#\SPC #\TAB #\LFD))
          (backward-char))
        (setq name-to (point))
        (setq name (buffer-substring name-from name-to))
        (setq name (outline-tree-create-outline-html-heading-title-converter name)))
      (return-from outline-tree-create-outline-html-heading-get-range-listing-definition
        (values begin-range end-range name)))))
(defun outline-tree-create-outline-html-heading-listing (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-html-heading-get-range-listing
   :child-only t
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (cond
        ((or (string-equal range-name "ul") (string-equal range-name "ol"))
         (outline-tree-create-outline-range-internal
          :root-node root-node
          :get-range-func #'outline-tree-create-outline-html-heading-get-range-listing-item
          :create-contents-outline-func
          #'(lambda (root-node range-node)
              (outline-tree-create-outline-html-heading-listing root-node))))
        ((string-equal range-name "dl")
         (outline-tree-create-outline-range-internal
          :root-node root-node
          :get-range-func #'outline-tree-create-outline-html-heading-get-range-listing-definition
          :create-contents-outline-func
          #'(lambda (root-node range-node)
              (outline-tree-create-outline-html-heading-listing root-node))))))))
(defun outline-tree-create-outline-html-heading-title-converter (str)
  (let ((org-str str)
        (string-encofing-alist '((" " . "&nbsp;") ("<" . "&lt;") (">" . "&gt;")
                                 ( "\"" . "&quot;") ("&" . "&amp;"))))
    (setq str (substitute-string str "[\n\t ]+" " "))
    (setq str (substitute-string str "<.+?>" ""))
    (dolist (x string-encofing-alist)
      (setq str (substitute-string str (cdr x) (car x))))
    (setq str (substitute-string str "[\n\t ]+" " "))
    (when (and (plusp (length str)) (char= (char str 0) #\SPC))
      (setq str (substring str 1)))
    (if (plusp (length str))
        str org-str)))

;;; cr-html-heading.l ends here
