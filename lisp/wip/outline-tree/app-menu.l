;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; app-menu.l --- outline-tree

;; Copyright (C) 2001-2007 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2007/02/10 22:29:38 +0900>

;;; Code:

(provide "outline-tree/app-menu")

(require "outline-tree/defs")
(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defun outline-tree-create-app-menu ()
  "メニューを作成"
  (setq *outline-tree-app-menu* nil)
  (unless *outline-tree-app-menu*
    (let ((menu (create-popup-menu 'outline-tree)))
      (add-menu-item menu 'outline-tree-create-outline-by-node
                     "アウトラインの作成/更新(&A)"
                     'outline-tree-create-outline-by-node
                     #'(lambda () (or (and (outline-tree-exist-p)
                                           (outline-tree-get-buffer-by-node)) :disable)))
      (add-menu-item menu 'outline-tree-delete-outline-by-node
                     "アウトラインの削除(&B)"
                     'outline-tree-delete-outline-by-node
                     #'(lambda ()
                         (or (and (outline-tree-exist-p)
                                  (outline-tree-exist-outline-p-by-node)) :disable)))
      (add-popup-menu menu
                      *outline-tree-create-outline-function-menu*
                      "アウトラインタイプ選択(&S)")
      (add-popup-menu menu
                      *outline-tree-create-outline-function-info-menu*
                      "アウトラインタイプ説明(&P)")
      (add-popup-menu menu
                      (define-popup-menu
                        (:item 'outline-tree-gen-cr-user-topic
                         "「見出し解析」設定から(&T)"
                         #'(lambda () (interactive)
                             (treeview::treeview-focus-editor)
                             (outline-tree-gen-cr-user-topic))
                         #'(lambda () (or (and (outline-tree-exist-p)
                                               (outline-tree-get-buffer-node-by-node)) :disable)))
                        (:item 'outline-tree-gen-cr-user-regexp
                         "「正規表現」設定から(&R)"
                         #'(lambda () (interactive)
                             (treeview::treeview-focus-editor)
                             (outline-tree-gen-cr-user-regexp))
                         #'(lambda () (or (and (outline-tree-exist-p)
                                               (outline-tree-get-buffer-node-by-node)) :disable))))
                      "アウトライン作成関数の生成(&G)")
      (add-menu-separator menu)
      ;; ノードの開閉
      (add-popup-menu menu
                      (define-popup-menu
                        (:item nil
                         "ここから全て開く(&C)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree
                                                     (outline-tree-get-selected-node)))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-node-valid-p node)
                                             (outline-tree-node-has-children-p node))))
                                 :disable)))
                        (:item nil
                         "ここから全て閉じる(&D)"
                         #'(lambda () (interactive) (outline-tree-expand-collapse-subtree
                                                     (outline-tree-get-selected-node)))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-node-valid-p node)
                                             (outline-tree-node-has-children-p node))))
                                 :disable)))
                        :sep
                        (:item nil
                         "ここから 2 階層開く(&2)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree
                                                     (outline-tree-get-selected-node) 2))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-node-valid-p node)
                                             (outline-tree-node-has-children-p node))))
                                 :disable)))
                        (:item nil
                         "ここから 3 階層開く(&3)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree
                                                     (outline-tree-get-selected-node) 3))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-node-valid-p node)
                                             (outline-tree-node-has-children-p node))))
                                 :disable)))
                        :sep
                        (:item nil
                         "以下の見出しノードが全て見えるように開く(&H)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree-show-heading-node
                                                     (outline-tree-get-selected-node)))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-node-valid-p node)
                                             (outline-tree-node-has-children-p node))))
                                 :disable)))
                        :sep
                        (:item nil
                         "ノードを全て開く(&A)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree 0))
                         #'(lambda () (or (outline-tree-exist-p) :disable)))
                        (:item nil
                         "ノードを全て閉じる(&B)"
                         #'(lambda () (interactive) (outline-tree-expand-collapse-subtree 0))
                         #'(lambda () (or (outline-tree-exist-p) :disable))))
                      "ノード開閉(&E)")
      (add-menu-separator menu)
      ;; 範囲ノード操作
      (add-popup-menu menu
                      (define-popup-menu
                        (:item nil
                         "ノードを上へ移動(&P)"
                         #'(lambda () (interactive)
                             (outline-tree-swap-region-by-prev-range-node))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (outline-tree-get-swap-target-range-node
                                       (outline-tree-get-selected-node) t))
                                 :disable)))
                        (:item nil
                         "ノードを下へ移動(&N)"
                         #'(lambda () (interactive)
                             (outline-tree-swap-region-by-next-range-node))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (outline-tree-get-swap-target-range-node
                                       (outline-tree-get-selected-node) nil))
                                 :disable)))
                        (:item nil
                         "ノードを削除(&D)"
                         #'(lambda () (interactive)
                             (outline-tree-delete-region-by-range-node))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-range-node-p node)
                                             (outline-tree-data-get-whole-range node))))
                                 :disable)))
                        :separator
                        (:item nil
                         "ノードのコピー(&C)"
                         #'(lambda () (interactive)
                             (let ((node (outline-tree-get-selected-node)) whole-range)
                               (when (and (outline-tree-range-node-p node)
                                          (setq whole-range (outline-tree-data-get-whole-range node)))
                                 (copy-region-to-clipboard
                                  (outline-tree-get-range-from whole-range)
                                  (outline-tree-get-range-to whole-range)))))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-range-node-p node)
                                             (outline-tree-data-get-whole-range node))))
                                 :disable)))
                        (:item nil
                         "ノードの先頭に移動(&<)"
                         #'(lambda () (interactive)
                             (let ((node (outline-tree-get-selected-node)) whole-range)
                               (when (and (outline-tree-range-node-p node)
                                          (setq whole-range (outline-tree-data-get-whole-range node)))
                                 (goto-char (outline-tree-get-range-from whole-range))
                                 (refresh-screen))))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-range-node-p node)
                                             (outline-tree-data-get-whole-range node))))
                                 :disable)))
                        (:item nil
                         "ノードの末尾に移動(&>)"
                         #'(lambda () (interactive)
                             (let ((node (outline-tree-get-selected-node)) whole-range)
                               (when (and (outline-tree-range-node-p node)
                                          (setq whole-range (outline-tree-data-get-whole-range node)))
                                 (goto-char (1- (outline-tree-get-range-to whole-range)))
                                 (refresh-screen))))
                         #'(lambda ()
                             (or (and (outline-tree-exist-p)
                                      (let ((node (outline-tree-get-selected-node)))
                                        (and (outline-tree-range-node-p node)
                                             (outline-tree-data-get-whole-range node))))
                                 :disable))))
                      "範囲ノード操作(&F)")
      (add-menu-separator menu)
      ;; 出力
      (add-popup-menu menu
                      (define-popup-menu
                        (:item 'outline-tree-insert-tree-text-root
                         "ツリー構造全てをテキスト出力(&A)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (treeview::treeview-insert-tree-text 0);node
                               (treeview::treeview-focus-editor)))
                         #'(lambda () (or (outline-tree-exist-p) :disable)))
                        (:item 'outline-tree-insert-tree-text-node
                         "このノード以下のツリー構造をテキスト出力(&B)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (treeview::treeview-insert-tree-text
                                (outline-tree-get-selected-node))
                               (treeview::treeview-focus-editor)))
                         #'(lambda () (or (outline-tree-exist-p) :disable))))
                      "ツリー構造出力(&L)")
      (add-menu-item menu 'outline-tree-output-html-dialog
                     "HTML出力(&H)..."
                     'outline-tree-output-html-dialog)
      (add-menu-separator menu)
      (add-popup-menu menu
                      (outline-tree-define-target-window-popup-menu)
                      "アウトライン対象ウィンドウ(&U)")
      ;; アウトラインツリー簡易設定
      (add-popup-menu menu
                      (define-popup-menu
                        (:item 'outline-tree-toggle-chase-cursor
                         "カーソル追従(&C)"
                         'outline-tree-toggle-chase-cursor
                         #'(lambda ()
                             (and (outline-tree-chase-cursor-p) :check)))
                        (:item 'outline-tree-toggle-chase-node
                         "ノード追従(&N)"
                         'outline-tree-toggle-chase-node
                         #'(lambda ()
                             (and (outline-tree-chase-node-p) :check)))
                        (:item 'outline-tree-toggle-text-highlight
                         "ノード範囲ハイライト(&H)"
                         'outline-tree-toggle-text-highlight
                         #'(lambda ()
                             (and (outline-tree-text-highlight-p) :check)))
                        (:item 'outline-tree-toggle-text-highlight-always
                         "ノード範囲を常にハイライト(&A)"
                         'outline-tree-toggle-text-highlight-always
                         #'(lambda ()
                             (and (outline-tree-text-highlight-always-p) :check)))
                        (:item 'outline-tree-toggle-available-swap-discontinuous-range-node
                         "不連続ノード入替え可(&D)"
                         'outline-tree-toggle-available-swap-discontinuous-range-node
                         #'(lambda ()
                             (and (outline-tree-available-swap-discontinuous-range-node-p) :check))))
                      "アウトラインツリー簡易設定(&Y)")
      (add-menu-item menu 'outline-tree-option-property-sheet
                     "アウトラインツリー設定(&Z)..."
                     #'(lambda () (interactive)
                         (save-window-excursion
                           (save-excursion
                             (if (outline-tree-exist-p)
                                 (set-buffer (outline-tree-get-buffer-by-node)))
                             (outline-tree-option-property-sheet)))))
      (add-menu-separator menu)
      (add-menu-item menu 'treeview::treeview-std-dialog
                     "TreeView 設定(&D)..."
                     #'(lambda () (interactive)
                         (treeview::with-app (*outline-tree-app-id*)
                           (treeview::treeview-std-dialog)
                           (treeview::treeview-focus-treeview))))
      (treeview::with-app (*outline-tree-app-id*)
        (add-popup-menu menu
                        (treeview::treeview-popup-menu-position)
                        "ウィンドウ位置変更(&W)"))
      (add-popup-menu menu
                      (define-popup-menu
                        (:item 'treeview::treeview-describe-bindings
                         "キー割り当て一覧(&K)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (treeview::treeview-describe-bindings))))
                        (:item 'treeview::treeview-describe-key-briefly
                         "キー説明(&B)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (call-interactively 'treeview::treeview-describe-key-briefly)))))
                      "ヘルプ(&?)")
      (add-menu-separator menu)
      (add-menu-item menu 'outline-tree-folder-close
                     "フォルダを閉じる(&C)"
                     #'(lambda () (interactive)
                         (let ((folder (outline-tree-get-folder-by-node)))
                           (outline-tree-kill-folder-file-buffers folder)))
                     #'(lambda ()
                         (or (and (outline-tree-exist-p)
                                  (outline-tree-folder-node-p (outline-tree-get-selected-node)))
                             :disable)))
      (add-menu-item menu 'outline-tree-category-close
                     "カテゴリを閉じる(&C)"
                     #'(lambda () (interactive)
                         (outline-tree-delete-category-buffers (outline-tree-get-category-node-by-node)))
                     #'(lambda ()
                         (or (and (outline-tree-exist-p)
                                  (outline-tree-category-node-p (outline-tree-get-selected-node)))
                             :disable)))
      (add-menu-item menu 'kill-buffer
                     "バッファを閉じる(&C)"
                     #'(lambda () (interactive)
                         (treeview::with-app (*outline-tree-app-id*)
                           (let ((buffer (outline-tree-get-buffer-by-node)))
                             (kill-buffer buffer)
                             (winapi:InvalidateRect (get-window-handle) 0 1)
                             (winapi:UpdateWindow (get-window-handle))
                             (refresh-screen))))
                     #'(lambda ()
                         (or (and (outline-tree-exist-p)
                                  (outline-tree-get-buffer-by-node))
                             :disable)))
      (add-menu-separator menu)
      (add-popup-menu menu ed::*buffer-bar-context-menu*
                      "バッファバーメニュー(&M)")
      (add-menu-separator menu)
      (add-menu-item menu 'outline-tree-open
                     "outline-tree を開く(&T)"
                     'outline-tree2::outline-tree-open
                     #'(lambda () (or (and (outline-tree-exist-p)
                                           (outline-tree-close-p))
                                      :disable)))
      (add-menu-item menu 'outline-tree-close
                     "outline-tree を閉じる(&T)"
                     'outline-tree2::outline-tree-close
                     #'(lambda () (or (and (outline-tree-exist-p)
                                           (outline-tree-open-p))
                                      :disable)))
      (add-menu-separator menu)
      (add-menu-item menu 'outline-tree-create
                     "outline-tree の起動(&X)"
                     'outline-tree2::outline-tree-create
                     #'(lambda () (and (outline-tree-exist-p) :disable)))
      (add-menu-item menu 'outline-tree-delete
                     "outline-tree の終了(&X)"
                     'outline-tree2::outline-tree-delete
                     #'(lambda ()
                         ;; イレギュラーだが、ここで他のメニューの更新を行う。
                         (ignore-errors
                          (when (menup *outline-tree-app-menu*)
                            ;; 「アウトライン対象ウィンドウ」メニューの更新
                            (let ((pos (get-menu-position
                                        *outline-tree-app-menu*
                                        'outline-tree-define-target-window)))
                              (when pos
                                (delete-menu *outline-tree-app-menu* 'outline-tree-define-target-window)
                                (insert-popup-menu *outline-tree-app-menu* pos
                                                   (outline-tree-define-target-window-popup-menu)
                                                   "アウトライン対象ウィンドウ(&U)")))
                            ;; ed::*buffer-bar-context-menu-buffer* の更新
                            (setq ed::*buffer-bar-context-menu-buffer*
                                  (outline-tree-get-buffer-by-node))
                            ))
                         ;; INIT 本来の動作はここから
                         (and (not (outline-tree-exist-p)) :disable)))
      (setq *outline-tree-app-menu* menu)))
  *outline-tree-app-menu*)

(defun outline-tree-delete-app-menu (&optional (menu (current-menu)))
  (when (menup menu)
    (while (delete-menu menu 'outline-tree))))

(defun outline-tree-insert-app-menu (&key (menu (current-menu))
                                          (position *outline-tree-app-menu-position*)
                                          (menu-name *outline-tree-app-menu-name*))
  (outline-tree-create-app-menu)
  (when (menup menu)
    (outline-tree-delete-app-menu menu)
    (cond
     ((and (numberp position) (integerp position))
      (insert-popup-menu menu position *outline-tree-app-menu* menu-name))
     ((and (symbolp position) (get-menu-position menu position))
      (insert-popup-menu menu (get-menu-position menu position)
                         *outline-tree-app-menu* menu-name))
     (t
      (add-popup-menu menu *outline-tree-app-menu* menu-name)))))

(defun outline-tree-startup-app-menu ()
  (when *outline-tree-set-app-menu*
    (if (menup ed::*app-menu*)
        (outline-tree-insert-app-menu)
      (add-hook 'ed::*init-app-menus-hook* 'outline-tree-insert-app-menu))))

(add-hook '*outline-tree-startup-hook* 'outline-tree-startup-app-menu)
(add-hook '*outline-tree-uninstall-hook* 'outline-tree-delete-app-menu)

;;; app-menu.l ends here
