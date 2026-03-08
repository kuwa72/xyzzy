;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-regexp-internal.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:21:05 +0900>

;;; Code:

(provide "outline-tree/cr-regexp-internal")

(require "search"); dialog2cfs, cfs2dialog
(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;;; アウトライン作成関数
(defun outline-tree-create-outline-regexp-internal
  (&key root-node
        layer-regexp-list layer-regexp-list-case-fold (layer-regexp-list-order :non-miss)
        create-sub-outline-func title-converter sub-type line-oriented)
  "正規表現アウトライン作成内部 function
ROOT-NODE
LAYER-REGEXP-LIST
LAYER-REGEXP-LIST-CASE-FOLD
LAYER-REGEXP-LIST-ORDER: :top-miss, :any-miss, :non-miss, :disorder"
  (labels (;; ************************************************************
           ;; 階層検索 
           ;; ************************************************************
           (outline-tree-create-outline-regexp-order (&key root-node
                                                           layer-regexp-list
                                                           layer-regexp-list-order
                                                           create-sub-outline-func
                                                           line-oriented)
             (let ((current-regexp (car layer-regexp-list))
                   (layer-regexp-list (cdr layer-regexp-list))
                   header-node range-node value-list from next-from title-from title-to
                   whole-range title-range contents-from regnum title)
               (save-excursion
                 (goto-char (point-min))
                 ;; ****************************************
                 ;; サブアウトライン作成
                 ;; ****************************************
                 (unless current-regexp
                   (when create-sub-outline-func
                     (funcall create-sub-outline-func root-node))
                   (return-from outline-tree-create-outline-regexp-order))
                 ;; ****************************************
                 ;; 現在の正規表現でのマッチ情報を取得
                 ;; ****************************************
                 (when current-regexp
                   (while (scan-buffer current-regexp :regexp t)
                     (setq from next-from
                           next-from (point))
                     (setq whole-range (cons from next-from)
                           title-range (cons title-from title-to))
                     ;; from が nil のものもとりあえず push
                     (push (list whole-range title-range contents-from) value-list)
                     (setq contents-from (match-end 0))
                     (when line-oriented
                       (goto-char contents-from)
                       (unless (bolp)
                         (goto-eol)
                         (forward-char)
                         (setq contents-from (point))))
                     (if (setq regnum (dotimes (i 9) (if (match-string (- 9 i)) (return (- 9 i)))))
                         ;; 正規表現からタイトル取得
                         (setq title-from (match-beginning regnum)
                               title-to (match-end regnum))
                       ;; 先頭行からタイトル取得
                       (save-excursion
                         (goto-char (match-beginning 0))
                         (setq title-from (point)
                               title-to (progn (goto-eol) (point)))))
                     (goto-char contents-from))
                   ;; 最後の一回分を push
                   (when next-from
                     (setq whole-range (cons next-from (if (= (point-max) (buffer-size)) nil (point-max)))
                           title-range (cons title-from title-to))
                     (push (list whole-range title-range contents-from) value-list))
                   ;; 順番を逆にした上で、from が nil のものを取り除く
                   (setq value-list (cdr (nreverse value-list))))
                 ;; ******************************
                 ;; 正規表現マッチ情報に従い処理実施
                 ;; ******************************
                 (cond
                  ;; 現在の正規表現にマッチする部分が見つかった場合
                  (value-list
                   ;; layer-regexp-list-order を更新
                   (when (eq layer-regexp-list-order :top-miss)
                     (setq layer-regexp-list-order :non-miss))
                   ;; 現在の正規表現にマッチ開始するまでの範囲を処理
                   (if line-oriented
                       (setq whole-range
                             (cons (save-excursion
                                     (goto-char (point-min))
                                     (if (bolp) (point) (progn (goto-eol) (forward-char) (point))))
                                   (car (first (car value-list)))))
                     (setq whole-range (cons (point-min) (car (first (car value-list))))))
                   (when (< (outline-tree-get-range-from whole-range)
                            (outline-tree-get-range-to whole-range))
                     (save-excursion
                       (save-restriction
                         ;; サブアウトライン作成
                         (narrow-to-region (outline-tree-get-range-from whole-range)
                                           (outline-tree-get-range-to whole-range))
                         (setq header-node
                               (outline-tree-insert-range-node *outline-tree-header-node-name*
                                                               root-node
                                                               :whole-range whole-range
                                                               :sub-type :header-node))
                         (outline-tree-create-outline-regexp-order
                          :root-node header-node
                          :create-sub-outline-func create-sub-outline-func)
                         (when (and (not (outline-tree-node-has-children-p header-node))
                                    (not (and (eq sub-type :heading-node)
                                              (outline-tree-buffer-node-p root-node))))
                           (outline-tree-remove-range-node header-node)))))
                   ;; 現在の正規表現にマッチした箇所から開始するそれぞれの範囲を処理
                   ;; (階層定義正規表現リスト)
                   (dolist (value value-list)
                     (setq whole-range (first value)
                           title-range (second value)
                           contents-from (third value))
                     (setq title (buffer-substring (outline-tree-get-range-from title-range)
                                                   (outline-tree-get-range-to title-range)))
                     (when title-converter
                       (setq title (funcall title-converter title)))
                     (setq range-node (outline-tree-insert-range-node
                                       title root-node :title-range title-range :whole-range whole-range
                                       :sub-type sub-type))
                     (when (< contents-from (outline-tree-get-range-to whole-range))
                       (save-restriction
                         (narrow-to-region contents-from
                                           (outline-tree-get-range-to whole-range))
                         (outline-tree-create-outline-regexp-order
                          :root-node range-node
                          :layer-regexp-list layer-regexp-list
                          :layer-regexp-list-order layer-regexp-list-order
                          :create-sub-outline-func create-sub-outline-func
                          :line-oriented line-oriented))))
                   (caaar value-list))
                  ;; 正規表現にマッチする部分が見つからず、それが許容される場合
                  ((member layer-regexp-list-order '(:top-miss :any-miss))
                   (outline-tree-create-outline-regexp-order
                    :root-node root-node
                    :layer-regexp-list layer-regexp-list
                    :layer-regexp-list-order layer-regexp-list-order
                    :create-sub-outline-func create-sub-outline-func
                    :line-oriented line-oriented))
                  (t
                   (outline-tree-create-outline-regexp-order
                    :root-node root-node
                    :create-sub-outline-func create-sub-outline-func))))))
           ;; ************************************************************
           ;; 階層解析
           ;; ************************************************************
           (outline-tree-create-outline-regexp-disorder (&key root-node
                                                              layer-regexp-list
                                                              create-sub-outline-func
                                                              line-oriented)
             (let (current-regexp match-alist regexp-position regnum header-node title)
               (save-excursion
                 ;; ****************************************
                 ;; 今回の階層をどの正規表現で作成するか解析
                 ;; ****************************************
                 ;; 各正規表現がマッチする最初のポイントを取得
                 (dolist (regexp layer-regexp-list)
                   (goto-char (point-min))
                   (when (and regexp
                              (scan-buffer regexp :regexp t))
                     (push (cons regexp (point)) match-alist)))
                 ;; どの正規表現に始めにマッチしたか確認
                 (when match-alist
                   (setq current-regexp (caar (stable-sort match-alist #'< :key #'cdr)))
                   (setq regexp-position
                         (position current-regexp layer-regexp-list :test 'equal))
                   (setq layer-regexp-list
                         (append (subseq layer-regexp-list 0 regexp-position)
                                 (subseq layer-regexp-list (1+ regexp-position)))))
                 (goto-char (point-min))
                 ;; ****************************************
                 ;; サブアウトライン作成
                 ;; ****************************************
                 (unless current-regexp
                   (when create-sub-outline-func
                     (funcall create-sub-outline-func root-node))
                   (return-from outline-tree-create-outline-regexp-disorder))
                 ;; ****************************************
                 ;; 現在の正規表現でのマッチ情報を取得
                 ;; ****************************************
                 (when current-regexp
                   (let (range-node value-list
                         from next-from title-from title-to
                         whole-range title-range contents-from)
                     (while (scan-buffer current-regexp :regexp t)
                       (setq from next-from
                             next-from (point))
                       (setq whole-range (cons from next-from)
                             title-range (cons title-from title-to))
                       ;; from が nil のものもとりあえず push
                       (push (list whole-range title-range contents-from) value-list)
                       (setq contents-from (match-end 0))
                       (when line-oriented
                         (goto-char contents-from)
                         (unless (bolp)
                           (goto-eol)
                           (forward-char)
                           (setq contents-from (point))))
                       (if (setq regnum (dotimes (i 9) (if (match-string (- 9 i)) (return (- 9 i)))))
                           ;; 正規表現からタイトル取得
                           (setq title-from (match-beginning regnum)
                                 title-to (match-end regnum))
                         ;; 先頭行からタイトル取得
                         (save-excursion
                           (goto-char (match-beginning 0))
                           (setq title-from (point)
                                 title-to (progn (goto-eol) (point)))))
                       (goto-char contents-from))
                     ;; 最後の一回分を push
                     (when next-from
                       (setq whole-range (cons next-from (if (= (point-max) (buffer-size)) nil (point-max)))
                             title-range (cons title-from title-to))
                       (push (list whole-range title-range contents-from) value-list))
                     ;; 順番を逆にした上で、from が nil のものを取り除く
                     (setq value-list (cdr (nreverse value-list)))
                     (cond
                      (value-list
                       ;; 現在の正規表現にマッチ開始するまでの範囲を処理
                       (if line-oriented
                           (setq whole-range
                                 (cons (save-excursion
                                         (goto-char (point-min))
                                         (if (bolp) (point) (progn (goto-eol) (forward-char) (point))))
                                       (car (first (car value-list)))))
                         (setq whole-range (cons (point-min) (car (first (car value-list))))))
                       (when (< (outline-tree-get-range-from whole-range)
                                (outline-tree-get-range-to whole-range))
                         (save-excursion
                           (save-restriction
                             ;; サブアウトライン作成
                             (narrow-to-region (outline-tree-get-range-from whole-range)
                                               (outline-tree-get-range-to whole-range))
                             (setq header-node
                                   (outline-tree-insert-range-node *outline-tree-header-node-name*
                                                                   root-node
                                                                   :whole-range whole-range
                                                                   :sub-type :header-node))
                             (outline-tree-create-outline-regexp-disorder
                              :root-node header-node
                              :create-sub-outline-func create-sub-outline-func)
                             (when (and (not (outline-tree-node-has-children-p header-node))
                                        (not (and (eq sub-type :heading-node)
                                                  (outline-tree-buffer-node-p root-node))))
                               (outline-tree-remove-range-node header-node)))))
                       ;; 現在の正規表現にマッチした箇所から開始するそれぞれの範囲を処理
                       ;; (階層定義正規表現リスト)
                       (dolist (value value-list)
                         (setq whole-range (first value)
                               title-range (second value)
                               contents-from (third value))
                         (setq title (buffer-substring (outline-tree-get-range-from title-range)
                                                       (outline-tree-get-range-to title-range)))
                         (when title-converter
                           (setq title (funcall title-converter title)))
                         (setq range-node (outline-tree-insert-range-node
                                           title root-node :title-range title-range :whole-range whole-range
                                           :sub-type sub-type))
                         (when (< contents-from (outline-tree-get-range-to whole-range))
                           (save-restriction
                             (narrow-to-region contents-from
                                               (outline-tree-get-range-to whole-range))
                             (outline-tree-create-outline-regexp-disorder
                              :root-node range-node
                              :layer-regexp-list layer-regexp-list
                              :create-sub-outline-func create-sub-outline-func
                              :line-oriented line-oriented))))
                       (caaar value-list))
                      ;; 正規表現にマッチする部分が見つからず、検索終了の場合
                      (t
                       (outline-tree-create-outline-regexp-disorder
                        :root-node root-node
                        :create-sub-outline-func create-sub-outline-func)))))))))
    ;; 処理開始部
    ;; layer-regexp-list の各要素を compiled-regexp 形式に
    (when (symbolp layer-regexp-list)
      (setq layer-regexp-list (symbol-value layer-regexp-list)))
    (setq layer-regexp-list
          (mapcar #'(lambda (regexp)
                      (if (stringp regexp)
                          (compile-regexp regexp layer-regexp-list-case-fold)
                        regexp))
                  layer-regexp-list))
    (cond
     ;; 階層解析
     ((member layer-regexp-list-order '(:disorder))
      (outline-tree-create-outline-regexp-disorder
       :root-node root-node
       :layer-regexp-list layer-regexp-list
       :create-sub-outline-func create-sub-outline-func
       :line-oriented line-oriented))
     ;; 階層検索
     (t
      (unless (member layer-regexp-list-order '(:top-miss :any-miss :non-miss))
        (setq layer-regexp-list-order :non-miss))
      (outline-tree-create-outline-regexp-order
       :root-node root-node
       :layer-regexp-list layer-regexp-list
       :layer-regexp-list-order layer-regexp-list-order
       :create-sub-outline-func create-sub-outline-func
       :line-oriented line-oriented)))
    (outline-tree-node-has-children-p root-node)))

;;; cr-regexp-internal.l ends here
