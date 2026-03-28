;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-eMemoPad.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:14 +0900>

;;; Commentary:

;; Description:
;;
;;  eMemoPad (http://www.ememopad.net/) フォーマット解析
;;

;;; Code:

(provide "outline-tree/cr-eMemoPad")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;; eMemoPad フォーマット
(defun outline-tree-create-outline-eMemoPad (root-node)
  (let (node layer-level current-layer-level
        node-hierarchy
        whole-range whole-from whole-to
        own-range own-from own-to
        title-range title)
    (push root-node node-hierarchy)
    (setq layer-level -1)
    (save-excursion
      (goto-char (point-min))
      (while (scan-buffer "^::Page::\n\\([0-9]+\\)\n\\(.*\\)" :regexp t)
        (setq current-layer-level (parse-integer (match-string 1)))
        (setq title (match-string 2))
        (setq title-range (cons (match-beginning 2) (match-end 2)))
        (setq whole-from (match-beginning 0))
        (goto-char (match-end 0))
        (when (scan-buffer "^begin{{$" :regexp t)
          (forward-line)
          (setq own-from (point))
          (when (scan-buffer "^}}end$" :regexp t)
            (setq own-to (point))
            (forward-line 2)
            (setq whole-to (point))
            (setq whole-range (cons whole-from whole-to))
            (setq own-range (cons own-from own-to))
            (cond
             ((> current-layer-level layer-level))
             ((= current-layer-level layer-level)
              (pop node-hierarchy))
             (t
              (let (whole-to value)
                (setq whole-to (outline-tree-get-range-to
                                (outline-tree-data-get-whole-range (pop node-hierarchy))))
                (dotimes (i (- layer-level current-layer-level))
                  (setq node (pop node-hierarchy))
                  (when (outline-tree-range-node-p node)
                    (outline-tree-update-range-node
                     node :whole-range (cons (outline-tree-get-range-from
                                              (outline-tree-data-get-whole-range node))
                                             whole-to)))))
              (when (null node-hierarchy)
                (push root-node node-hierarchy))))
            (push (outline-tree-insert-range-node title (car node-hierarchy)
                                                  :title-range title-range :whole-range whole-range
                                                  :sub-type :heading-node)
                  node-hierarchy)
            (setq layer-level current-layer-level)))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-eMemoPad "eMemoPad" '(:type-document :line-oriented)
 "eMemoPad 用ファイル (.edf) を階層表示します。")

;;; cr-eMemoPad.l ends here
