;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-2ch.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:37:36 +0900>

;;; Code:

(provide "outline-tree/cr-2ch")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; 2ch-mode thread
(defun outline-tree-create-outline-2ch-thread (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-2ch-thread-get-range-day
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (outline-tree-create-outline-regexp-internal
        :root-node root-node
        :layer-regexp-list-order :non-miss
        :layer-regexp-list '("^[0-9]+")
        :layer-regexp-list-case-fold t))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-2ch-thread "2ch: Thread" '()
 "2ch-mode のスレッド表示を日にち毎に分類表示します。")

;;
(defun outline-tree-create-outline-2ch-thread-get-range-day ()
  (let (begin-range end-range name day count)
    (save-excursion
      (when (scan-buffer "^[0-9]+ \\[\\([^] ]+\\)" :regexp t)
        (setq begin-range (cons (point) (point)))
        (setq day (match-string 1))
        (setq count 1)
        (goto-char (match-end 0))
        (while (scan-buffer "^[0-9]+ \\[\\([^] ]+\\)" :regexp t)
          (if (string= day (match-string 1))
              (progn
                (incf count)
                (goto-char (match-end 0)))
            (progn
              (setq end-range (cons (point) (point)))
              (return))))
        (unless end-range
          (if (= (point-max) (buffer-size))
              (setq end-range (cons nil nil))
            (setq end-range (cons (point-max) (point-max)))))
        (setq name (format nil "[~A] (~D)" day count))
        (return-from outline-tree-create-outline-2ch-thread-get-range-day
          (values begin-range end-range name))))))

;;; cr-2ch.l ends here
