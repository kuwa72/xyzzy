;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-grep.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:57 +0900>

;;; Code:

(provide "outline-tree/cr-grep")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

(defun outline-tree-create-outline-grep-possible-p (buffer)
  (buffer-local-value buffer 'ed::*find-error-scanner*))

;; grep 解析
(defun outline-tree-create-outline-grep (root-node)
  (outline-tree-create-outline-range-internal
   :root-node root-node
   :get-range-func #'outline-tree-create-outline-grep-get-range-target
   :create-contents-outline-func
   #'(lambda (root-node range-name)
       (goto-char (point-min))
       (while (scan-buffer "^\\(.+?\\):\\(\\([0-9]+\\):\\(.*\\)\\)$" :regexp t)
         (goto-char (match-end 0))
         (forward-char)
         (outline-tree-insert-range-node
          (match-string 2) root-node
          :whole-range (cons (match-beginning 0)
                             (if (= (point) (buffer-size)) nil (point))))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-grep "Grep結果" '()
 "Grep 結果をアウトライン表示します。")

;;
(defun outline-tree-create-outline-grep-get-range-target ()
  (let (begin-range end-range name target count)
    (save-excursion
      (when (scan-buffer "^\\(.+?\\):\\(\\([0-9]+\\):\\(.*\\)\\)$" :regexp t)
        (setq begin-range (cons (point) (point)))
        (setq target (match-string 1))
        (setq count 1)
        (goto-char (match-end 0))
        (while (scan-buffer "^\\(.+?\\):\\(\\([0-9]+\\):\\(.*\\)\\)$" :regexp t)
          (if (string= target (match-string 1))
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
        (setq name (format nil "[~A] (~D)" target count))
        (return-from outline-tree-create-outline-grep-get-range-target
          (values begin-range end-range name))))))

;;; cr-grep.l ends here
