;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-regexp.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:24:48 +0900>

;;; Code:

(provide "outline-tree/cr-regexp")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/utils")

(in-package "outline-tree2")

(defvar-local outline-tree-create-outline-regexp-layer-regexp-list nil)
(defvar-local outline-tree-create-outline-regexp-layer-regexp-list-case-fold nil)
(defvar-local outline-tree-create-outline-regexp-layer-regexp-list-order nil)
(let ((variables
       '(outline-tree-create-outline-regexp-layer-regexp-list
         outline-tree-create-outline-regexp-layer-regexp-list-case-fold
         outline-tree-create-outline-regexp-layer-regexp-list-order)))
  ;; ヒストリ変数として設定
  (register-history-variable variables)
  ;; バッファローカル有効/無効の同期
  (push variables *outline-tree-sync-local-variables-list*))

;; 正規表現アウトライン
(defun outline-tree-create-outline-regexp (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order outline-tree-create-outline-regexp-layer-regexp-list-order
   :layer-regexp-list outline-tree-create-outline-regexp-layer-regexp-list
   :layer-regexp-list-case-fold outline-tree-create-outline-regexp-layer-regexp-list-case-fold
   :sub-type :heading-node
   :line-oriented t
   :title-converter nil))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-regexp "**正規表現 (ダイアログ設定有)" '(:type-general :line-oriented :sequential)
 "正規表現で階層を解析し、見出しをアウトライン表示します。

[アウトラインツリー設定]-[正規表現] で解析方法のカスタマイズが可能です。

[アウトライン作成関数の生成]-[「正規表現」設定から] メニューから、
現在の設定を元に、ユーザ定義アウトライン作成関数を生成できます。")

;; property-sheet
(outline-tree-add-option-prop-page
 'outline-tree-create-outline-regexp
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

   ;; 正規表現
   (setq dialog-base-height (+ dialog-base-height 22 4))
   (setq dialog-side dialog-base-side)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "正規表現リスト(&R)"                                   #x50020007
           ,dialog-side ,dialog-height 238 166) controls)
   (incf dialog-side 4)
   (push `(:edit layer-regexp-list nil                                        #x50a110c4
           ,dialog-side ,(incf dialog-height 10) 160 110) controls)
   (incf dialog-side 164)
   (push `(:button layer-order-non-miss "省略不可(&N)"                        #x50000009
           ,dialog-side ,dialog-height 64 12) controls)
   (push `(:button layer-order-top-miss "先頭省略可能(&M)"                    #x50000009
           ,dialog-side ,(incf dialog-height 12) 64 12) controls)
   (push `(:button layer-order-any-miss "任意省略可能(&Y)"                    #x50000009
           ,dialog-side ,(incf dialog-height 12) 64 12) controls)
   (push `(:button layer-order-disorder "見出し(順不同)(&D)"                  #x50000009
           ,dialog-side ,(incf dialog-height 12) 64 12) controls)
   (push `(:button layer-regexp-list-case-fold "大文字小文字を\n区別する(&C)" #x50012006
           ,dialog-side ,(incf dialog-height 16) 60 18) controls)

   (setq dialog-height dialog-base-height)
   (incf dialog-height 120)
   (setq dialog-side dialog-base-side)
   (incf dialog-side 4)
   (push `(:static nil "正規表現のグルーピングを行った場合、最後のグループがタイトルになります。" #x50000000
           ,dialog-side ,(incf dialog-height 10) 226 16) controls)

   (setq controls (nreverse controls))
   `(dialog 0 0 260 220
     (:caption "正規表現")
     (:control
      ,@controls)))
 #'(lambda ()
     (let ((local-p (outline-tree-local-variables-local-p
                     'outline-tree-create-outline-regexp-layer-regexp-list)))
       (list
        ;; 共通/ローカル
        (cons 'setting-default (not local-p))
        (cons 'setting-local local-p)
        (cons 'dummy-trigger (not local-p))

        ;; 正規表現リスト
        (cons 'layer-regexp-list
              (format nil "~{~A\r\n~}"
                      (mapcar 'outline-tree-encode-escape-sequence
                              (cond
                               ((symbolp outline-tree-create-outline-regexp-layer-regexp-list)
                                (symbol-value outline-tree-create-outline-regexp-layer-regexp-list))
                               ((listp outline-tree-create-outline-regexp-layer-regexp-list)
                                outline-tree-create-outline-regexp-layer-regexp-list)
                               (t nil)))))
        (case outline-tree-create-outline-regexp-layer-regexp-list-order
          (:top-miss
           (cons 'layer-order-top-miss t))
          (:any-miss
           (cons 'layer-order-any-miss t))
          (:disorder
           (cons 'layer-order-disorder t))
          (t
           (cons 'layer-order-non-miss t)))
        (cons 'layer-regexp-list-case-fold
              (ed::cfs2dialog outline-tree-create-outline-regexp-layer-regexp-list-case-fold)))))
 '((dummy-trigger :disable (setting-local-to-default)))
 #'(lambda (data)
     (let (local)
       ;; 共通/ローカル
       (cond ((cdr (assoc 'setting-local data))
              (setq local t)
              (outline-tree-sync-local-variables
               'outline-tree-create-outline-regexp-layer-regexp-list local))
             ((cdr (assoc 'setting-local-to-default data))
              (outline-tree-sync-local-variables
               'outline-tree-create-outline-regexp-layer-regexp-list local)))
       (cond (local
              (setq outline-tree-create-outline-regexp-layer-regexp-list
                    (mapcar #'(lambda (str) (decode-escape-sequence str t))
                            (split-string
                             (substitute-string
                              (cdr (assoc 'layer-regexp-list data)) "\r\n" "\n") #\LFD)))
              (setq outline-tree-create-outline-regexp-layer-regexp-list-case-fold
                    (ed::dialog2cfs (cdr (assoc 'layer-regexp-list-case-fold data))))
              (setq outline-tree-create-outline-regexp-layer-regexp-list-order
                    (cond ((cdr (assoc 'layer-order-non-miss data)) :non-miss)
                          ((cdr (assoc 'layer-order-top-miss data)) :top-miss)
                          ((cdr (assoc 'layer-order-any-miss data)) :any-miss)
                          ((cdr (assoc 'layer-order-disorder data)) :disorder))))
             (t
              (setq-default outline-tree-create-outline-regexp-layer-regexp-list
                            (mapcar #'(lambda (str) (decode-escape-sequence str t))
                                    (split-string
                                     (substitute-string
                                      (cdr (assoc 'layer-regexp-list data)) "\r\n" "\n") #\LFD)))
              (setq-default outline-tree-create-outline-regexp-layer-regexp-list-case-fold
                            (ed::dialog2cfs (cdr (assoc 'layer-regexp-list-case-fold data))))
              (setq-default outline-tree-create-outline-regexp-layer-regexp-list-order
                            (cond ((cdr (assoc 'layer-order-non-miss data)) :non-miss)
                                  ((cdr (assoc 'layer-order-top-miss data)) :top-miss)
                                  ((cdr (assoc 'layer-order-any-miss data)) :any-miss)
                                  ((cdr (assoc 'layer-order-disorder data)) :disorder))))))
     ;; アウトラインを最新でないように設定
     (save-excursion
       (dolist (buffer (buffer-list))
         (set-buffer buffer)
         (when (eq (outline-tree-get-create-outline-function-by-buffer buffer)
                   'outline-tree-create-outline-regexp)
           (setq outline-tree-outline-modified nil))))))

;;; cr-regexp.l ends here
