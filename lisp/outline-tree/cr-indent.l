;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-indent.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:24:36 +0900>

;;; Code:

(provide "outline-tree/cr-indent")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-indent-skip-chars* " \t　")
(defvar *outline-tree-create-outline-indent-adjust-title* "***INDENT ADJUST***")

;; インデント量 解析
(defun outline-tree-create-outline-indent (root-node)
  (labels ((outline-tree-create-outline-indent-1 (parent-node indent-alist point-max)
             (let (range-node whole-range title-range
                   point-min min-indent pos next-pos from to)
               (setq point-min (cdr (first indent-alist))
                     min-indent (apply #'min (mapcar #'car indent-alist))
                     pos (position min-indent indent-alist :test #'= :key #'car)
                     next-pos (position min-indent indent-alist :test #'= :key #'car :start (1+ pos))
                     from (cdr (nth pos indent-alist))
                     to (if next-pos (cdr (nth next-pos indent-alist)) point-max))
               ;; 最もインデント量が少ない行までのアウトラインを作成
               (when (/= pos 0)
                 (setq whole-range (cons point-min from))
                 (setq range-node (outline-tree-insert-range-node
                                   *outline-tree-create-outline-indent-adjust-title*
                                   parent-node :whole-range whole-range))
                 (outline-tree-create-outline-indent-1 range-node (subseq indent-alist 0 pos) from))
               (while pos
                 (setq whole-range (cons from to))
                 (goto-char from)
                 (skip-chars-forward *outline-tree-create-outline-indent-skip-chars*)
                 (setq title-range (cons (point) (progn (goto-eol) (point))))
                 (setq range-node
                       (outline-tree-insert-range-node
                        (buffer-substring (car title-range) (cdr title-range)) parent-node
                        :whole-range whole-range :title-range title-range))
                 (cond
                  ;; 同じインデント量の行が次行でない場合
                  ((and next-pos (/= (1+ pos) next-pos))
                   (outline-tree-create-outline-indent-1
                    range-node (subseq indent-alist (1+ pos) next-pos) to))
                  ;; 同じインデント量の行が存在せず、現在の行が最終行でない場合
                  ((and (null next-pos) (/= (1+ pos) (length indent-alist)))
                   (outline-tree-create-outline-indent-1 range-node (subseq indent-alist (1+ pos)) point-max)))
                 (setq pos next-pos
                       from to)
                 (when pos
                   (setq next-pos (position min-indent indent-alist :test #'= :key #'car :start (1+ pos))
                         to (if next-pos (cdr (nth next-pos indent-alist)) point-max)))))))
    (let (indent-alist from)
      (save-excursion
        (goto-char (point-min))
        (loop
          (setq from (point))
          (skip-chars-forward *outline-tree-create-outline-indent-skip-chars*)
          (unless (eolp)
            (push (cons (current-column) from) indent-alist))
          (unless (forward-line)
            (return)))
        (setq indent-alist (nreverse indent-alist))
        (outline-tree-create-outline-indent-1
         root-node indent-alist (if (= (buffer-size) (point-max)) nil (point-max)))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-indent "インデント量" '(:type-general :line-oriented :sequential)
 "各行行頭のインデント量を元に階層表示します。")

;;; cr-indent.l ends here
