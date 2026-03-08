;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; defs.l --- outline-tree

;; Copyright (C) 2001-2012 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2012/04/03 00:31:00 +0900>

;;; Code:

(provide "outline-tree/defs")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package "outline-tree2")
    (defpackage "outline-tree2"
      (:use "lisp" "editor"))))

(in-package "outline-tree2")

;;----------------------------------------------------------------------------
;; 基本
;;----------------------------------------------------------------------------
(defconstant *outline-tree-version* "2012.04.03")
(defvar *outline-tree-debug* nil)

;;----------------------------------------------------------------------------
;; パス
;;----------------------------------------------------------------------------
;; config ファイル / autoload ディレクトリ
(defvar *outline-tree-base-directory* "~/.outline-tree")
(defvar *outline-tree-config-file*
  (merge-pathnames "config.l" *outline-tree-base-directory*))
(defvar *outline-tree-autoload-directory*
  (merge-pathnames "autoload" *outline-tree-base-directory*))

;;----------------------------------------------------------------------------
;; HOOK
;;----------------------------------------------------------------------------
;; TREEVIEW 作成/削除/アンインストール
(defvar *outline-tree-create-hook* nil
  "outline-tree 開始時に評価する。
outline-tree-create の最後で run-hooks で処理。")
(defvar *outline-tree-delete-hook* nil
  "outline-tree 終了時に評価する。
outline-tree-delete の最後で run-hooks で処理。")

(defvar *outline-tree-startup-hook* nil
  "outline-tree 初期起動時に評価する。
outline-tree-startup の最後で run-hooks で処理。")
(defvar *outline-tree-uninstall-hook* nil
  "outline-tree アンインストール時に評価する。
outline-tree-uninstall のヒストリ変数削除前に run-hooks で処理。")

;; バッファノードの削除
(defvar *outline-tree-delete-buffer-node-hook* nil
  "buffer-node 削除時に評価する。
outline-tree-delete-buffer-node-by-buffer の最後で buffer を引数とした
run-hook-with-args で処理。")

;; アウトラインの作成
(defvar *outline-tree-create-outline-hook* nil
  "バッファのアウトライン作成時に評価する。
outline-tree-create-outline-by-buffer の最後で run-hooks で処理。
outline-tree-create-outline-by-buffer 関数にはバッファのリストも渡すことが
可能だが、バッファのリストを渡した場合も、バッファ毎ではなく一度のみ評価さ
れる。")

;;----------------------------------------------------------------------------
;; 
;;----------------------------------------------------------------------------
;; ヘッダノード名
(defvar *outline-tree-header-node-name* "<HEADER>"
  "ヘッダノード名。
outline-tree-create-outline-regexp-internal,
outline-tree-create-outline-topic-internal 関数にて評価される。")

;; カテゴリノード名
(defvar *outline-tree-visible-buffer-category-node-name* "=== 表示バッファ ==="
  "表示バッファ用カテゴリノード名")
(defvar *outline-tree-invisible-buffer-category-node-name* "=== 非表示バッファ ==="
  "非表示バッファ用カテゴリノード名")

;; サブカテゴリ名検出
(defvar *outline-tree-buffer-category-regexp-list*
  '(("^ *\\(\\*Minibuf\\)"      . " Minibuf")
    ("^ *\\(\\*howm\\)"         . " howm")
    ("^ *\\(\\*Help\\*\\)"      . " Help")
    ("^ *\\(\\*NetInstaller\\)" . " NetInstaller")
    ("^ *\\(\\*RSS\\)"          . " RSS")
    "^ *\\*?\\(.+?\\):"
    ("^\\*untitled\\*"          . " *untitled*"))
  "バッファ名からカテゴリ名を決定する際に用いる。
outline-tree-detect-category-name 関数で使用する。")

;; ノード対応テキストハイライト
(defvar *outline-tree-text-highlight-attribute*
  '(:background 3 :prefix #\T :extend t)
  "ノード対応テキストをハイライトするときの表示属性。
outline-tree-set-text-highlight で処理される。")

;;
(defvar *outline-tree-delete-category-buffers-except-regexp-list*
  '("^\\*scratch\\*$")
  "「カテゴリを閉じる」際に対象外するバッファ名の正規表現をリストに指定する。
outline-tree-delete-category-buffers 関数で使用する。")

;;----------------------------------------------------------------------------
;; app-menu
;;----------------------------------------------------------------------------
(defvar *outline-tree-app-menu* nil
  "outline-tree メニュー")
(defvar *outline-tree-app-menu-position* 'ed::help
  "outline-tree メニュー位置")
(define-history-variable *outline-tree-app-menu-name* "&Outline-Tree"
  "outline-tree メニュー文字列")
(define-history-variable *outline-tree-set-app-menu* t
  "outline-tree メニュー起動状態を記録するためのフラグ")

;;; defs.l ends here
