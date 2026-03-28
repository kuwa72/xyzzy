;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-sted.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:09 +0900>

;;; Commentary:

;; Description:
;;
;;  構造化エディタ (http://www008.upp.so-net.ne.jp/momotan)
;;  フォーマット解析
;;

;;; Code:

(provide "outline-tree/cr-sted")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;; STED フォーマット
(defun outline-tree-create-outline-sted (root-node)
  (let (node sequence-line node-hierarchy title
        whole-range from to title-range)
    (push root-node node-hierarchy)
    (save-excursion
      (goto-char (point-min))
      (setq from (point))
      ;; シーケンス行
      (while (scan-buffer "^\\(\t ?\\| +\t? *\\)$" :regexp t)
        (setq sequence-line (match-string 1))
        (setq to (point))
        (save-excursion
          (goto-char from)
          (setq whole-range (cons from to))
          (save-restriction
            (narrow-to-region from to)
            ;; タイトル行
            (cond
             ((scan-buffer "^[ \t]*\\(.*[^ \t\n]\\)\\([ \t]\\| \t\\)$" :regexp t)
              (setq title (match-string 1))
              (setq title-range (cons (match-beginning 1) (match-end 1))))
             ((progn
                (goto-char (point-min))
                (scan-buffer "^[ \t]*\\(.*[^ \t\n]\\)$" :regexp t))
              (setq title (match-string 1))
              (setq title-range (cons (match-beginning 1) (match-end 1))))
             (t
              (setq title "")
              (setq title-range nil))))
          (setq node (outline-tree-insert-range-node
                      title (car node-hierarchy)
                      :title-range title-range :whole-range whole-range
                      :sub-type :heading-node)))
        ;; 階層処理
        (push node node-hierarchy)
        (cond
         ((string-match "^\t" sequence-line))
         ((string-match "^ " sequence-line)
          (let ((j 0))
            (dotimes (i (length sequence-line))
              (incf j)
              ;; 改行を範囲に含める
              (when (= i (1- (length sequence-line)))
                (incf j))
              (when (eql (char sequence-line i) #\SPC)
                (setq node (pop node-hierarchy))
                (setq whole-range (outline-tree-data-get-whole-range node))
                (outline-tree-update-range-node
                 node :whole-range (cons (outline-tree-get-range-from whole-range)
                                         (+ to j))))))
          (when (null node-hierarchy)
            (push root-node node-hierarchy))))
        (goto-char to)
        (next-line)
        (setq from (point))))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-sted "構造化テキスト(STED)" '(:type-document :line-oriented)
 "構造化テキストフォーマットをアウトライン表示します。

この解析において、構造化テキスト仕様で規定されている「ブックマーク」
「フォーカスセクション」「ツリーの開閉状況」はなんら意味を持ちません。")

;;; cr-sted.l ends here
