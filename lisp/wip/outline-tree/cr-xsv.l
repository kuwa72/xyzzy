;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-xsv.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/06 12:26:52 +0900>

;;; Code:

(provide "outline-tree/cr-xsv")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-xsv-record-num-padding* 5)
(defvar *outline-tree-create-outline-xsv-syntax-table* nil)
(unless *outline-tree-create-outline-xsv-syntax-table*
  (setq *outline-tree-create-outline-xsv-syntax-table* (make-syntax-table))
  (set-syntax-string *outline-tree-create-outline-xsv-syntax-table* #\"))

;; CSV 解析
(defun outline-tree-create-outline-csv (root-node)
  (outline-tree-create-outline-xsv root-node ","))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-csv "CSV" '(:type-data)
 "CSV ファイルをアウトライン表示します。")

;; TSV 解析
(defun outline-tree-create-outline-tsv (root-node)
  (outline-tree-create-outline-xsv root-node "\t"))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-tsv "TSV" '(:type-data)
 "TSV ファイルをアウトライン表示します。")

;;
(defun outline-tree-create-outline-xsv (root-node sep)
  (goto-char (point-min))
  (let (from name (record-num 1) range-node column-count
        (org-syntax-table (syntax-table)))
    (unwind-protect
        (progn
          (use-syntax-table *outline-tree-create-outline-xsv-syntax-table*)
          ;; レコードの登録
          (setq from (point-min))
          (loop
            (goto-eol)
            (forward-char)
            (if (= from (point))
                (return-from outline-tree-create-outline-xsv nil))
            (if (or (eq (parse-point-syntax) nil) (eobp))
                (progn
                  (setq name (format nil "~V,'0D"
                                     *outline-tree-create-outline-xsv-record-num-padding*
                                     record-num))
                  (setq range-node (outline-tree-insert-range-node
                                    name
                                    root-node
                                    :whole-range (cons from (point))))
                  (setq column-count
                        (outline-tree-create-outline-xsv-column range-node sep))
                  (outline-tree-update-range-node
                   range-node
                   :range-name (format nil "~A(~D)" name column-count))
                  (setq from (point))
                  (incf record-num)))))
      (use-syntax-table org-syntax-table))))

(defun outline-tree-create-outline-xsv-column (root-node sep)
  (let (whole-range parent-from parent-to from to name range-node (node-count 0))
    (save-excursion
      (save-restriction
        (setq whole-range (outline-tree-data-get-whole-range root-node))
        (setq parent-from (outline-tree-get-range-from whole-range)
              parent-to  (outline-tree-get-range-to whole-range))
        (narrow-to-region (outline-tree-get-range-from whole-range)
                          (outline-tree-get-range-to whole-range))
        (goto-char (point-min))
        (setq from (point))
        (loop
          (if (scan-buffer sep)
              (if (eq (parse-point-syntax) nil)
                  (progn
                    (setq name (buffer-substring from (point)))
                    (outline-tree-insert-range-node
                     name
                     root-node
                     :whole-range (cons from (point)))
                    (incf node-count)
                    (goto-char (match-end 0))
                    (setq from (point)))
                (forward-char))
            (progn
              (goto-char (point-max))
              (if (and (bolp) (/= from (point)))
                  (backward-char))
              (setq name (buffer-substring from (point)))
              (outline-tree-insert-range-node
               name
               root-node
               :whole-range (cons from (point)))
              (incf node-count)
              (return))))
        node-count))))

;;; cr-xsv.l ends here
