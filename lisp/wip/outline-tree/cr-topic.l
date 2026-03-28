;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-topic.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:24:54 +0900>

;;; Code:

(provide "outline-tree/cr-topic")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-topic-internal")
(require "outline-tree/utils")

(in-package "outline-tree2")

;; 見出し解析デフォルト設定
(defvar *outline-tree-create-outline-topic-heading-chars-default*
  "（(［[「『【■□▲△▼▽◆◇○◎●§・※☆★第−＜"
  "単一見出し文字")
(defvar *outline-tree-create-outline-topic-heading-chars-group-list-default*
  '("" "")
  "グループ見出し文字")
(defvar *outline-tree-create-outline-topic-heading-skip-regexp-default*
  "[ 　\t]*"
  "スキップ正規表現")
(defvar *outline-tree-create-outline-topic-heading-regexp-list-default*
  '("[0-9]+[.．:：)）]"
    "[０-９]+[.．:：)）]"
    "[〇一二三四五六七八九十壱弐参伍]+[.．:：)）]")
  "正規表現見出し")
(defvar *outline-tree-create-outline-topic-heading-regexp-list-case-fold-default*
  nil
  "正規表現の大文字小文字を区別")
(defvar *outline-tree-create-outline-topic-enable-skip-width-default*
  t
  "見出し解析でスキップ幅を考慮")

(defvar-local outline-tree-create-outline-topic-heading-chars
  (copy-string *outline-tree-create-outline-topic-heading-chars-default*)
  "バッファローカル：単一見出し文字")
(defvar-local outline-tree-create-outline-topic-heading-chars-group-list
  (copy-tree *outline-tree-create-outline-topic-heading-chars-group-list-default*)
  "バッファローカル：グループ見出し文字")
(defvar-local outline-tree-create-outline-topic-heading-skip-regexp
  (copy-string *outline-tree-create-outline-topic-heading-skip-regexp-default*)
  "バッファローカル：スキップ正規表現")
(defvar-local outline-tree-create-outline-topic-heading-regexp-list
  (copy-tree *outline-tree-create-outline-topic-heading-regexp-list-default*)
  "バッファローカル：正規表現見出し")
(defvar-local outline-tree-create-outline-topic-heading-regexp-list-case-fold
  *outline-tree-create-outline-topic-heading-regexp-list-case-fold-default*
  "バッファローカル：正規表現の大文字小文字を区別")
(defvar-local outline-tree-create-outline-topic-enable-skip-width
  *outline-tree-create-outline-topic-enable-skip-width-default*
  "バッファローカル：見出し解析でスキップ幅を考慮")

(let ((variables
       '(outline-tree-create-outline-topic-heading-chars
         outline-tree-create-outline-topic-heading-chars-group-list
         outline-tree-create-outline-topic-heading-skip-regexp
         outline-tree-create-outline-topic-heading-regexp-list
         outline-tree-create-outline-topic-heading-regexp-list-case-fold
         outline-tree-create-outline-topic-enable-skip-width)))
  ;; ヒストリ変数として設定
  (register-history-variable variables)
  ;; バッファローカル有効/無効の同期
  (push variables *outline-tree-sync-local-variables-list*))

;; 見出し解析
(defun outline-tree-create-outline-topic (root-node)
  (outline-tree-create-outline-topic-internal
   :root-node root-node
   :enable-skip-width outline-tree-create-outline-topic-enable-skip-width
   :heading-skip-regexp outline-tree-create-outline-topic-heading-skip-regexp
   :heading-chars outline-tree-create-outline-topic-heading-chars
   :heading-chars-group-list outline-tree-create-outline-topic-heading-chars-group-list
   :heading-regexp-list outline-tree-create-outline-topic-heading-regexp-list
   :heading-regexp-list-case-fold outline-tree-create-outline-topic-heading-regexp-list-case-fold
   :sub-type :heading-node
   :line-oriented t
   :title-converter nil))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-topic "**見出し解析 (ダイアログ設定有)" '(:type-general :line-oriented :sequential)
 "各行の先頭空白の幅、及び、先頭空白を除いた行頭見出し文字の出現順序に
よって見出しを解析し、アウトライン表示します。

[アウトラインツリー設定]-[見出し解析] で解析方法のカスタマイズが可能です。

[アウトライン作成関数の生成]-[「見出し解析」設定から] メニューから、
現在の設定を元に、ユーザ定義アウトライン作成関数を生成できます。")

;; property-sheet
(outline-tree-add-option-prop-page
 'outline-tree-create-outline-topic
 (let (dialog-base-side dialog-base-height dialog-side dialog-height dialog-size controls)
   ;; 共通/ローカル
   (setq dialog-base-side 4)
   (setq dialog-base-height 4)
   (setq dialog-side dialog-base-side)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "" #x50020007
           ,dialog-side ,dialog-height 238 22) controls)
   (incf dialog-height 6)
   (push `(:button setting-default          "共通設定(&1)"           #x50000009
           ,(incf dialog-side 4) ,dialog-height 50 14) controls)
   (push `(:button setting-local            "ローカル設定(&2)"       #x50000009
           ,(incf dialog-side 50) ,dialog-height 62 14) controls)
   (push `(:button setting-local-to-default "ローカル設定→共通設定(&3)" #x50000009
           ,(incf dialog-side 62) ,dialog-height 95 14) controls)
   (push `(:button dummy-trigger ""                                  #x50000009
           10000 ,dialog-height 0 0) controls)

   ;; 見出し文字
   (setq dialog-base-height (+ dialog-base-height 22 4))
   (setq dialog-side dialog-base-side)
   (setq dialog-height dialog-base-height)
   (push `(:button heading-chars-frame "見出し"                     #x50000007
           ,dialog-side ,dialog-height 170 162) controls)

   (incf dialog-side 4)
   (push `(:static heading-chars-str "単一文字指定(&S):"              #x50020000
           ,dialog-side ,(incf dialog-height 10) 160 8) controls)
   (push `(:edit heading-chars nil                                      #x508100c0
           ,dialog-side ,(incf dialog-height 10) 160 14) controls)
   (push `(:static heading-chars-group-list-str "グループ文字指定(&G):" #x50020000
           ,dialog-side ,(incf dialog-height 18) 160 8) controls)
   (push `(:edit heading-chars-group-list nil                           #x50a110c4
           ,dialog-side ,(incf dialog-height 10) 160 30) controls)
   (setq dialog-height dialog-base-height)

   ;; 見出し正規表現
   (setq dialog-base-height (+ dialog-base-height 74))
   (setq dialog-height dialog-base-height)
   (setq dialog-side dialog-base-side)
   (incf dialog-side 4)
   (push `(:static heading-chars-str "正規表現指定(&R):"              #x50020000
           ,dialog-side ,(incf dialog-height 10) 160 8) controls)
   (push `(:edit heading-regexp-list nil                                        #x50a110c4
           ,dialog-side ,(incf dialog-height 10) 160 60) controls)

   ;;
   (setq dialog-base-height 30)
   (setq dialog-height dialog-base-height)
   (incf dialog-side 172)
   (push `(:static heading-skip-regexp-str "スキップ正規表現(&B):"         #x50020000
           ,dialog-side ,(incf dialog-height 10) 64 8) controls)
   (push `(:edit heading-skip-regexp nil                                #x508100c0
           ,dialog-side ,(incf dialog-height 10) 64 14) controls)

   (push `(:button enable-skip-width "スキップ幅を\n考慮して解析する(&E)" #x50012003
           ,dialog-side ,(incf dialog-height 20) 80 24) controls)

   (push `(:button heading-regexp-list-case-fold "正規表現の大文字\n小文字を区別する(&C)" #x50012006
           ,dialog-side ,(incf dialog-height 40) 80 24) controls)

   ;;
   (push `(:button initialize "デフォルト設定に\n戻す(&I)"             #x50012003
           ,dialog-side ,(incf dialog-height 60) 64 20) controls)

   (setq controls (nreverse controls))
   `(dialog 0 0 260 220
     (:caption "見出し解析")
     (:control
      ,@controls)))
 #'(lambda ()
     (let ((local-p (outline-tree-local-variables-local-p
                     'outline-tree-create-outline-topic-heading-regexp-list)))
       (list
        ;; 共通/ローカル
        (cons 'setting-default (not local-p))
        (cons 'setting-local local-p)
        (cons 'dummy-trigger (not local-p))

        ;; スキップ
        (cons 'heading-skip-regexp
              (outline-tree-encode-escape-sequence
               (cond
                ((symbolp outline-tree-create-outline-topic-heading-skip-regexp)
                 (symbol-value outline-tree-create-outline-topic-heading-skip-regexp))
                ((stringp outline-tree-create-outline-topic-heading-skip-regexp)
                 outline-tree-create-outline-topic-heading-skip-regexp)
                (t ""))))
        (cons 'enable-skip-width
              (cond
               ((symbolp outline-tree-create-outline-topic-enable-skip-width)
                (symbol-value outline-tree-create-outline-topic-enable-skip-width))
               (t
                outline-tree-create-outline-topic-enable-skip-width)))

        ;; 見出し
        (cons 'heading-chars
              (cond
               ((symbolp outline-tree-create-outline-topic-heading-chars)
                (symbol-value outline-tree-create-outline-topic-heading-chars))
               ((stringp outline-tree-create-outline-topic-heading-chars)
                outline-tree-create-outline-topic-heading-chars)
               (t "")))
        (cons 'heading-chars-group-list
              (format nil "~{~A\r\n~}"
                      (cond
                       ((symbolp outline-tree-create-outline-topic-heading-chars-group-list)
                        (symbol-value outline-tree-create-outline-topic-heading-chars-group-list))
                       ((listp outline-tree-create-outline-topic-heading-chars-group-list)
                        outline-tree-create-outline-topic-heading-chars-group-list)
                       (t nil))))

        ;; 正規表現リスト
        (cons 'heading-regexp-list
              (format nil "~{~A\r\n~}"
                      (mapcar 'outline-tree-encode-escape-sequence
                              (cond
                               ((symbolp outline-tree-create-outline-topic-heading-regexp-list)
                                (symbol-value outline-tree-create-outline-topic-heading-regexp-list))
                               ((listp outline-tree-create-outline-topic-heading-regexp-list)
                                outline-tree-create-outline-topic-heading-regexp-list)
                               (t nil)))))
        (cons 'heading-regexp-list-case-fold
              (ed::cfs2dialog outline-tree-create-outline-topic-heading-regexp-list-case-fold)))))
 '((dummy-trigger :disable (setting-local-to-default)))
 #'(lambda (data)
     (let (local)
       ;; 共通/ローカル
       (cond ((cdr (assoc 'setting-local data))
              (setq local t)
              (outline-tree-sync-local-variables
               'outline-tree-create-outline-topic-heading-regexp-list local))
             ((cdr (assoc 'setting-local-to-default data))
              (outline-tree-sync-local-variables
               'outline-tree-create-outline-topic-heading-regexp-list local)))
       (cond (local
              (cond
               ((cdr (assoc 'initialize data))
                ;; スキップ
                (setq outline-tree-create-outline-topic-heading-skip-regexp
                      *outline-tree-create-outline-topic-heading-skip-regexp-default*)
                (setq outline-tree-create-outline-topic-enable-skip-width
                      *outline-tree-create-outline-topic-enable-skip-width-default*)
                ;; 見出し文字
                (setq outline-tree-create-outline-topic-heading-chars
                      *outline-tree-create-outline-topic-heading-chars-default*)
                (setq outline-tree-create-outline-topic-heading-chars-group-list
                      *outline-tree-create-outline-topic-heading-chars-group-list-default*)
                ;; 正規表現リスト
                (setq outline-tree-create-outline-topic-heading-regexp-list
                      *outline-tree-create-outline-topic-heading-regexp-list-default*)
                (setq outline-tree-create-outline-topic-heading-regexp-list-case-fold
                      *outline-tree-create-outline-topic-heading-regexp-list-case-fold-default*))
               (t
                ;; スキップ
                (setq outline-tree-create-outline-topic-heading-skip-regexp
                      (decode-escape-sequence (cdr (assoc 'heading-skip-regexp data)) t))
                (setq outline-tree-create-outline-topic-enable-skip-width
                      (cdr (assoc 'enable-skip-width data)))
                ;; 見出し文字
                (setq outline-tree-create-outline-topic-heading-chars
                      (cdr (assoc 'heading-chars data)))
                (setq outline-tree-create-outline-topic-heading-chars-group-list
                      (mapcar #'(lambda (str) (decode-escape-sequence str t))
                              (split-string
                               (substitute-string
                                (cdr (assoc 'heading-chars-group-list data)) "\r\n" "\n") #\LFD)))
                ;; 正規表現リスト
                (setq outline-tree-create-outline-topic-heading-regexp-list
                      (mapcar #'(lambda (str) (decode-escape-sequence str t))
                              (split-string
                               (substitute-string
                                (cdr (assoc 'heading-regexp-list data)) "\r\n" "\n") #\LFD)))
                (setq outline-tree-create-outline-topic-heading-regexp-list-case-fold
                      (ed::dialog2cfs (cdr (assoc 'heading-regexp-list-case-fold data)))))))
             (t
              (cond
               ((cdr (assoc 'initialize data))
                ;; スキップ
                (setq-default outline-tree-create-outline-topic-heading-skip-regexp
                              *outline-tree-create-outline-topic-heading-skip-regexp-default*)
                (setq-default outline-tree-create-outline-topic-enable-skip-width
                              *outline-tree-create-outline-topic-enable-skip-width-default*)
                ;; 見出し文字
                (setq-default outline-tree-create-outline-topic-heading-chars
                              *outline-tree-create-outline-topic-heading-chars-default*)
                (setq-default outline-tree-create-outline-topic-heading-chars-group-list
                              *outline-tree-create-outline-topic-heading-chars-group-list-default*)
                ;; 正規表現リスト
                (setq-default outline-tree-create-outline-topic-heading-regexp-list
                              *outline-tree-create-outline-topic-heading-regexp-list-default*)
                (setq-default outline-tree-create-outline-topic-heading-regexp-list-case-fold
                              *outline-tree-create-outline-topic-heading-regexp-list-case-fold-default*))
               (t
                ;; スキップ
                (setq-default outline-tree-create-outline-topic-heading-skip-regexp
                              (decode-escape-sequence (cdr (assoc 'heading-skip-regexp data)) t))
                (setq-default outline-tree-create-outline-topic-enable-skip-width
                              (cdr (assoc 'enable-skip-width data)))
                ;; 見出し文字
                (setq-default outline-tree-create-outline-topic-heading-chars
                              (cdr (assoc 'heading-chars data)))
                (setq-default outline-tree-create-outline-topic-heading-chars-group-list
                              (mapcar #'(lambda (str) (decode-escape-sequence str t))
                                      (split-string
                                       (substitute-string
                                        (cdr (assoc 'heading-chars-group-list data)) "\r\n" "\n") #\LFD)))
                ;; 正規表現リスト
                (setq-default outline-tree-create-outline-topic-heading-regexp-list
                              (mapcar #'(lambda (str) (decode-escape-sequence str t))
                                      (split-string
                                       (substitute-string
                                        (cdr (assoc 'heading-regexp-list data)) "\r\n" "\n") #\LFD)))
                (setq-default outline-tree-create-outline-topic-heading-regexp-list-case-fold
                              (ed::dialog2cfs (cdr (assoc 'heading-regexp-list-case-fold data)))))))))
     ;; アウトラインを最新でないように設定
     (save-excursion
       (dolist (buffer (buffer-list))
         (set-buffer buffer)
         (when (eq (outline-tree-get-create-outline-function-by-buffer buffer)
                   'outline-tree-create-outline-topic)
           (setq outline-tree-outline-modified nil))))))

;;; cr-topic.l ends here
