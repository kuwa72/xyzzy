;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; outline-tree.l

;; Copyright (C) 2001-2012 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2012/03/30 21:35:44 +0900>

;;; Commentary:

;; Description:
;;
;;  TreeView.dll を用いて、バッファリストのツリー表示、バッファ内のア
;;  ウトライン表示を行います。
;;

;;; Code:

(provide "outline-tree/outline-tree")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "wip/treeview/setup"))

(require "outline-tree/defs")
(require "outline-tree/public-utils")
(require "outline-tree/utils")

(in-package "outline-tree2")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; config ファイル / autoload ディレクトリ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun outline-tree-create-base-directory ()
  (let ((dir *outline-tree-base-directory*))
    (unless (file-directory-p dir)
      (when (yes-or-no-p "ディレクトリ ~A が存在しません。~%作成しますか？"  dir)
        (create-directory dir)))
    (file-directory-p dir)))

(defun outline-tree-check-autoload-directory ()
  (let ((dir *outline-tree-autoload-directory*))
    (unless (file-directory-p dir)
      (when (yes-or-no-p "ディレクトリ ~A が存在しません。~%作成しますか？"  dir)
        (create-directory dir)))
    (file-directory-p dir)))

(let (loaded-p)
  (defun outline-tree-config-load ()
    "設定ファイルを読み込む"
    (when *outline-tree-config-file*
      (let ((lc (concat *outline-tree-config-file* "c")))
        (cond
         ((and (file-exist-p lc) (not (file-directory-p lc)))
          (load lc)
          (setq loaded-p t))
         ((and (file-exist-p *outline-tree-config-file*)
               (not (file-directory-p *outline-tree-config-file*)))
          (load *outline-tree-config-file*)
          (setq loaded-p t))))))
  (defun outline-tree-config-loaded-p ()
    "設定ファイルを読み込み済み"
    loaded-p))
(defun outline-tree-autoload ()
  (interactive)
  (unless (and (file-exist-p *outline-tree-autoload-directory*)
               (file-directory-p *outline-tree-autoload-directory*))
    (return-from outline-tree-autoload))
  (dolist (f (directory *outline-tree-autoload-directory*
                        :wild "*.l"
                        :absolute t
                        :file-only t
                        :recursive t))
    (let ((lc (concat f "c")))
      (if (file-exist-p lc)
          (load lc)
        (load f)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TREEVIEW ライブラリ用 (共通)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; TREEVIEW ライブラリ用 基本変数
;;----------------------------------------------------------------------------
(defvar *outline-tree-app-id* 'outline-tree)

(define-history-variable *outline-tree-use* nil
  "nil, t, :one-shot")
(define-history-variable *outline-tree-window-position* treeview:XPIS_LEFT)
(define-history-variable *outline-tree-window-width* 200)
(define-history-variable *outline-tree-window-height* 200)
(define-history-variable *outline-tree-window-display-style* nil)

(define-history-variable *outline-tree-font-facename-manual-p* nil)
(define-history-variable *outline-tree-font-facename* nil)
(define-history-variable *outline-tree-font-height-manual-p* nil)
(define-history-variable *outline-tree-font-height* nil)
(define-history-variable *outline-tree-font-bold* nil)
(define-history-variable *outline-tree-font-italic* nil)
(define-history-variable *outline-tree-font-underline* nil)

(define-history-variable *outline-tree-color-text-manual-p* nil)
(define-history-variable *outline-tree-color-text* nil)
(define-history-variable *outline-tree-color-bk-manual-p* nil)
(define-history-variable *outline-tree-color-bk* nil)

(define-history-variable *outline-tree-style-hasbuttons* t)
(define-history-variable *outline-tree-style-haslines* t)
(define-history-variable *outline-tree-style-linesatroot* nil)
(defvar *outline-tree-style-editlabels* :ignore)
(defvar *outline-tree-style-enabledragdrop* :ignore)
(defvar *outline-tree-style-showselalways* t)
(defvar *outline-tree-style-rtlreading* :ignore)
(define-history-variable *outline-tree-style-checkboxes* nil)
(define-history-variable *outline-tree-style-trackselect* nil)
(defvar *outline-tree-style-singleexpand* :ignore)
(defvar *outline-tree-style-infotip* nil)
(define-history-variable *outline-tree-style-fullrowselect* t)
(define-history-variable *outline-tree-style-tooltips* t)
(defvar *outline-tree-style-scroll* :ignore)
(defvar *outline-tree-style-nonevenheight* :ignore)
(defvar *outline-tree-style-hscroll* :ignore)

(define-history-variable *outline-tree-indent-manual-p* nil)
(define-history-variable *outline-tree-indent* nil)
(define-history-variable *outline-tree-item-height-manual-p* nil)
(define-history-variable *outline-tree-item-height* nil)

(define-history-variable *outline-tree-icon* t)
(define-history-variable *outline-tree-icon-directory*
  (merge-pathnames "lisp/outline-tree/icon/default" (si:system-root))
  "outline-tree: icon ディレクトリ")

(define-history-variable *outline-tree-exclusive-open-group* nil)

(define-history-variable *outline-tree-treeview-recenter* nil "t, nil, :line")
(define-history-variable *outline-tree-treeview-recenter-line* 3)
(define-history-variable *outline-tree-treeview-scroll-margin* 3)

(defvar *outline-tree-map* nil)
(unless *outline-tree-map*
  (setq *outline-tree-map* (copy-keymap treeview::*treeview-map*))
  (define-key *outline-tree-map* #\TAB 'treeview::treeview-other-treeview-window)
  (define-key *outline-tree-map* #\C-g 'quit)
  (define-key *outline-tree-map* #\RET 'outline-tree-node-action)
  (define-key *outline-tree-map* #\Delete 'outline-tree-delete-outline-by-node)
  (define-key *outline-tree-map* #\C-p 'outline-tree-select-up-key-node)
  (define-key *outline-tree-map* #\C-n 'outline-tree-select-down-key-node)
  (define-key *outline-tree-map* #\C-b 'outline-tree-select-left-key-node)
  (define-key *outline-tree-map* #\C-f 'outline-tree-select-right-key-node)
  (define-key *outline-tree-map* #\C-z 'outline-tree-select-pageup-key-node)
  (define-key *outline-tree-map* #\C-v 'outline-tree-select-pagedown-key-node)
  (define-key *outline-tree-map* #\C-a 'outline-tree-select-ancestor-node)
  (define-key *outline-tree-map* #\C-e 'outline-tree-select-eldest-descendants-node)
  (define-key *outline-tree-map* #\C-s
              (treeview::treeview-make-tv-command outline-tree-isearch-forward))
  (define-key *outline-tree-map* #\C-r
              (treeview::treeview-make-tv-command outline-tree-isearch-backward))
  (define-key *outline-tree-map* #\P 'outline-tree-swap-region-by-prev-range-node)
  (define-key *outline-tree-map* #\N 'outline-tree-swap-region-by-next-range-node)
  (define-key *outline-tree-map* #\D 'outline-tree-delete-region-by-range-node))

(defvar *outline-tree-fix-map* nil
   "outline-tree: treeview keymap (デフォルト動作対策)")
(unless *outline-tree-fix-map*
  ;; キーバインド変更不可
  (setq *outline-tree-fix-map* (copy-keymap treeview::*treeview-fix-map*))
  (define-key *outline-tree-fix-map* #\Up         'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\Down       'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\Left       'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\Right      'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-Up       'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-Down     'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-Left     'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-Right    'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\PageUp     'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\PageDown   'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\Home       'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\End        'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-PageUp   'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-PageDown 'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-Home     'outline-tree-select-node-delay)
  (define-key *outline-tree-fix-map* #\S-End      'outline-tree-select-node-delay))

;;----------------------------------------------------------------------------
;; TREEVIEW ライブラリ用 関数
;;----------------------------------------------------------------------------
(defun outline-tree-node-implicit-func-gen (&optional node)
  "outline-tree: 暗黙的にノードに対して行う処理用関数を生成"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (if (outline-tree-data-get-implicit-func node)
        (outline-tree-data-get-implicit-func node)
      (case (outline-tree-data-get-type node)
        (:buffer-node
         (when (outline-tree-chase-node-p)
           #'(lambda () (interactive)
               (outline-tree-set-buffer-by-node node))))
        (t
         (when (outline-tree-chase-node-p)
           (outline-tree-node-explicit-func-gen node)))))))

(defun outline-tree-node-explicit-func-gen (&optional node)
  "outline-tree: 明示的にノードに対して行う処理用関数を生成"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (if (outline-tree-data-get-explicit-func node)
        (outline-tree-data-get-explicit-func node)
      (case (outline-tree-data-get-type node)
        (:category-node
         nil)
        (:folder-node
         nil)
        (:section-node
         (outline-tree-node-implicit-func-gen
          (outline-tree-get-buffer-node-by-node node)))
        (:info-node
         (treeview::with-app (*outline-tree-app-id*)
           (let ((parent-node (treeview::treeview-get-parent-item node)))
             (outline-tree-node-implicit-func-gen parent-node))))
        (:buffer-node
         (if (outline-tree-chase-node-p)
             #'(lambda () (interactive)
                 (outline-tree-create-outline-by-node node))
           #'(lambda () (interactive)
               (outline-tree-set-buffer-by-node node))))
        (:range-node
         #'(lambda () (interactive)
             (treeview::with-app (*outline-tree-app-id*)
               (let ((node node)
                     (whole-range (outline-tree-data-get-whole-range node))
                     (swindow (selected-window))
                     (window (outline-tree-get-target-window))
                     (buffer (outline-tree-get-buffer-by-node node)))
                 (when (and whole-range (bufferp buffer))
                   (set-window window)
                   (set-buffer buffer)
                   (unless (eq (outline-tree-get-node-by-window) node)
                     (goto-char (outline-tree-get-range-from whole-range))
                     (cond ((and (eq *outline-tree-editor-recenter* :line)
                                 (numberp *outline-tree-editor-recenter-line*)
                                 (integerp *outline-tree-editor-recenter-line*))
                            (recenter *outline-tree-editor-recenter-line*))
                           (*outline-tree-editor-recenter*
                            (recenter))))
                   (when (outline-tree-text-highlight-p)
                     (outline-tree-set-text-highlight whole-range))
                   (set-window swindow)
                   (winapi:InvalidateRect (get-window-handle) 0 1)
                   (winapi:UpdateWindow (get-window-handle))
                   (refresh-screen))))))
        (:point-node
         #'(lambda () (interactive)
             (treeview::with-app (*outline-tree-app-id*)
               (let ((node node)
                     (point (outline-tree-data-get-point node))
                     (swindow (selected-window))
                     (window (outline-tree-get-target-window))
                     (buffer (outline-tree-get-buffer-by-node node)))
                 (when (and point (bufferp buffer))
                   (set-window window)
                   (set-buffer buffer)
                   (goto-char point)
                   (cond ((and (eq *outline-tree-editor-recenter* :line)
                               (numberp *outline-tree-editor-recenter-line*)
                               (integerp *outline-tree-editor-recenter-line*))
                          (recenter *outline-tree-editor-recenter-line*))
                         (*outline-tree-editor-recenter*
                          (recenter)))
                   (set-window swindow)
                   (winapi:InvalidateRect (get-window-handle) 0 1)
                   (winapi:UpdateWindow (get-window-handle))
                   (refresh-screen))))))
        ))))

(defun outline-tree-menu-gen (node)
  "outline-tree: node に対応するメニューを生成
※実装上の注意: 選択しているノードのバッファとカレントバッファは異なる
                場合がありえるので注意。"
  (setq *outline-tree-context-menu-node* node)
  (let ((menu (create-popup-menu 'outline-tree-menu))
        (context-menu-buffer (outline-tree-get-buffer-by-node node))
        (context-menu-folder (outline-tree-get-folder-by-node node)))

    ;; ユーザ定義 menu が存在する場合、そちらを使用
    (case (outline-tree-data-get-type node)
      (:buffer-node
       (when *outline-tree-buffer-menu*
         (return-from outline-tree-menu-gen *outline-tree-buffer-menu*)))
      (:folder-node
       (when *outline-tree-folder-menu*
         (return-from outline-tree-menu-gen *outline-tree-folder-menu*))))

    ;; category-node の場合
    (when (outline-tree-category-node-p node)
      (add-menu-item menu 'outline-tree-category-close
                     "カテゴリを閉じる(&C)"
                     #'(lambda () (interactive)
                         (outline-tree-delete-category-buffers node))))

    ;; folder-node の場合
    (when (outline-tree-folder-node-p node)
      (add-menu-item menu 'outline-tree-folder-close
                     "フォルダを閉じる(&C)"
                     #'(lambda () (interactive)
                         (outline-tree-kill-folder-file-buffers context-menu-folder)))
      (unless *filer-modal*
        (add-menu-item menu 'outline-tree-filer-open
                       "ファイラを開く(&F)"
                       #'(lambda () (interactive)
                           (treeview::with-app (*outline-tree-app-id*)
                             (if (outline-tree-filer-open-p)
                                 (filer-chdir (outline-tree-data-get-folder-name node))
                               (progn
                                 (unless *filer-left-window-p*
                                   (setq *filer-secondary-directory* *filer-primary-directory*)
                                   (setq *filer-left-window-p* t))
                                 (setq *filer-primary-directory*
                                       (outline-tree-data-get-folder-name node))
                                 (open-filer)))
                             (ed::filer-focus)))))
      (add-menu-separator menu))

    (if context-menu-buffer
        ;; buffer-node 以下の場合
        (progn
          (add-menu-item menu 'kill-buffer
                         "バッファを閉じる(&C)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (kill-buffer context-menu-buffer)
                               (winapi:InvalidateRect (get-window-handle) 0 1)
                               (winapi:UpdateWindow (get-window-handle))
                               (refresh-screen))))
          (setq ed::*buffer-bar-context-menu-buffer* context-menu-buffer)
          (add-popup-menu menu ed::*buffer-bar-context-menu*
                          "バッファバーメニュー(&M)")
          (add-menu-separator menu)
          (add-menu-item menu 'outline-tree-create-outline-by-node
                         "アウトラインの作成/更新(&A)"
                         #'(lambda () (interactive)
                             (outline-tree-create-outline-by-node node)
                             (refresh-screen)))
          (add-menu-item menu 'outline-tree-delete-outline-by-node
                         "アウトラインの削除(&B)"
                         #'(lambda () (interactive)
                             (outline-tree-delete-outline-by-node node))
                         #'(lambda ()
                             (or (outline-tree-exist-outline-p-by-node node)
                                 :disable)))
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
                                 (outline-tree-gen-cr-user-topic)))
                            (:item 'outline-tree-gen-cr-user-regexp
                             "「正規表現」設定から(&R)"
                             #'(lambda () (interactive)
                                 (treeview::treeview-focus-editor)
                                 (outline-tree-gen-cr-user-regexp))))
                          "アウトライン作成関数の生成(&G)")
          (add-menu-separator menu))
      ;; buffer-node 以下でない場合
      (progn
        (add-popup-menu menu
                        *outline-tree-create-outline-function-info-menu*
                        "アウトラインタイプ説明(&P)")
        (add-menu-separator menu)))

    ;; tab-bar 用 menu の生成でない場合
    (unless (eql node -1)
      ;; ノードの開閉
      (add-popup-menu menu
                      (define-popup-menu
                        (:item nil
                         "ここから全て開く(&C)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree node))
                         #'(lambda () (or (and (outline-tree-node-valid-p node)
                                               (outline-tree-node-has-children-p node)) :disable)))
                        (:item nil
                         "ここから全て閉じる(&D)"
                         #'(lambda () (interactive) (outline-tree-expand-collapse-subtree node))
                         #'(lambda () (or (and (outline-tree-node-valid-p node)
                                               (outline-tree-node-has-children-p node)) :disable)))
                        :sep
                        (:item nil
                         "ここから 2 階層開く(&2)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree node 2))
                         #'(lambda () (or (and (outline-tree-node-valid-p node)
                                               (outline-tree-node-has-children-p node)) :disable)))
                        (:item nil
                         "ここから 3 階層開く(&3)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree node 3))
                         #'(lambda () (or (and (outline-tree-node-valid-p node)
                                               (outline-tree-node-has-children-p node)) :disable)))
                        :sep
                        (:item nil
                         "以下の見出しノードが全て見えるように開く(&H)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree-show-heading-node node))
                         #'(lambda () (or (and (outline-tree-node-valid-p node)
                                               (outline-tree-node-has-children-p node)) :disable)))
                        :sep
                        (:item nil
                         "ノードを全て開く(&A)"
                         #'(lambda () (interactive) (outline-tree-expand-expand-subtree 0)))
                        (:item nil
                         "ノードを全て閉じる(&B)"
                         #'(lambda () (interactive) (outline-tree-expand-collapse-subtree 0))))
                      "ノード開閉(&E)")
      (add-menu-separator menu))

    ;; range-node の場合
    (let (whole-range)
      (when (and (outline-tree-range-node-p node)
                 (setq whole-range (outline-tree-data-get-whole-range node)))
        (add-popup-menu menu
                        (define-popup-menu
                          (:item nil
                           "ノードを上へ移動(&P)"
                           #'(lambda () (interactive)
                               (outline-tree-swap-region-by-prev-range-node node))
                           #'(lambda ()
                               (or (outline-tree-get-swap-target-range-node node t)
                                   :disable)))
                          (:item nil
                           "ノードを下へ移動(&N)"
                           #'(lambda () (interactive)
                               (outline-tree-swap-region-by-next-range-node node))
                           #'(lambda ()
                               (or (outline-tree-get-swap-target-range-node node nil)
                                   :disable)))
                          (:item nil
                           "ノードを削除(&D)"
                           #'(lambda () (interactive)
                               (outline-tree-delete-region-by-range-node node)))
                          :separator
                          (:item nil
                           "ノードのコピー(&C)"
                           #'(lambda () (interactive)
                               (copy-region-to-clipboard
                                (outline-tree-get-range-from whole-range)
                                (outline-tree-get-range-to whole-range))))
                          (:item nil
                           "ノードの先頭に移動(&<)"
                           #'(lambda () (interactive)
                               (goto-char (outline-tree-get-range-from whole-range))
                               (refresh-screen)))
                          (:item nil
                           "ノードの末尾に移動(&>)"
                           #'(lambda () (interactive)
                               (goto-char (1- (outline-tree-get-range-to whole-range)))
                               (refresh-screen))))
                        "範囲ノード操作(&F)")
        (add-menu-separator menu)))

    ;; tab-bar 用 menu の生成でない場合
    (unless (eql node -1)
      ;; 出力
      (add-popup-menu menu
                      (define-popup-menu
                        (:item 'outline-tree-insert-tree-text-root
                         "ツリー構造全てをテキスト出力(&A)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (treeview::treeview-insert-tree-text 0);node
                               (treeview::treeview-focus-editor))))
                        (:item 'outline-tree-insert-tree-text-node
                         "このノード以下のツリー構造をテキスト出力(&B)"
                         #'(lambda () (interactive)
                             (treeview::with-app (*outline-tree-app-id*)
                               (treeview::treeview-insert-tree-text node)
                               (treeview::treeview-focus-editor)))))
                      "ツリー構造出力(&L)")
      (add-menu-item menu 'outline-tree-output-html-dialog
                     "HTML出力(&H)..."
                     #'(lambda ()
                         (interactive)
                         (outline-tree-output-html-dialog node)))
      (add-menu-separator menu))

    ;; tab-bar 用 menu の生成でない場合
    (unless (eql node -1)
      (add-popup-menu menu
                      (outline-tree-define-target-window-popup-menu)
                      "アウトライン対象ウィンドウ(&U)"))
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
                   #'(lambda ()
                       (interactive)
                       (save-window-excursion
                         (save-excursion
                           (set-buffer (outline-tree-get-buffer-by-node node))
                           (outline-tree-option-property-sheet)))))
    (add-menu-separator menu)
    (add-menu-item menu 'treeview::treeview-std-dialog
                   "TreeView 設定(&D)..."
                   #'(lambda () (interactive)
                       (treeview::with-app (*outline-tree-app-id*)
                         (treeview::treeview-std-dialog)
                         (treeview::treeview-focus-treeview))))
    (add-popup-menu menu
                    (treeview::treeview-popup-menu-position)
                    "ウィンドウ位置変更(&W)")
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
    (add-menu-item menu 'outline-tree-open
                   "outline-tree を開く(&T)"
                   'outline-tree-open
                   #'(lambda () (and (outline-tree-open-p) :disable)))
    (add-menu-item menu 'outline-tree-close
                   "outline-tree を閉じる(&T)"
                   'outline-tree-close
                   #'(lambda () (and (outline-tree-close-p) :disable)))
    (add-menu-item menu 'outline-tree-delete
                   "outline-tree の終了(&X)" 'outline-tree-delete)
    (when *outline-tree-debug*
      (add-menu-item menu 'outline-tree-get-enum-node-data-msgbox
                     "ノードデータ"
                     #'(lambda () (interactive)
                         (msgbox "~{~S~%~}" (outline-tree-get-enum-node-data node)))))
    menu))

(defun outline-tree-initialize-icons ()
  "treeview の icon を設定"
  (treeview::with-app (*outline-tree-app-id*)
    (when (outline-tree-exist-p)
      (treeview::treeview-remove-all-icons)
      (if *outline-tree-icon*
          (dolist (x *outline-tree-icon-symbol-file-alist*)
            (set (car x)
                 (treeview::treeview-add-file-icon
                  (map-slash-to-backslash
                   (merge-pathnames (cdr x) *outline-tree-icon-directory*)))))
        (dolist (x *outline-tree-icon-symbol-file-alist*)
          (set (car x) nil)))
      (treeview::treeview-refresh-treeview))))

;;----------------------------------------------------------------------------
;; TREEVIEW ライブラリへ登録
;;----------------------------------------------------------------------------
(treeview::treeview-app-id-register *outline-tree-app-id*)
(defun outline-tree-initialize-treeview ()
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-data-set 'treeview::display-name "outline-tree")
    ;; window position/size/display
    (treeview::treeview-data-reference-set 'treeview::window-position '*outline-tree-window-position*)
    (treeview::treeview-data-reference-set 'treeview::window-width '*outline-tree-window-width*)
    (treeview::treeview-data-reference-set 'treeview::window-height '*outline-tree-window-height*)
    (treeview::treeview-data-reference-set 'treeview::window-display-style '*outline-tree-window-display-style*)
    ;; color
    (treeview::treeview-data-reference-set 'treeview::color-text-manual-p '*outline-tree-color-text-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::color-text '*outline-tree-color-text*)
    (treeview::treeview-data-reference-set 'treeview::color-bk-manual-p '*outline-tree-color-bk-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::color-bk '*outline-tree-color-bk*)
    ;; font
    (treeview::treeview-data-reference-set 'treeview::font-facename-manual-p '*outline-tree-font-facename-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::font-facename '*outline-tree-font-facename*)
    (treeview::treeview-data-reference-set 'treeview::font-height-manual-p '*outline-tree-font-height-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::font-height '*outline-tree-font-height*)
    (treeview::treeview-data-reference-set 'treeview::font-bold '*outline-tree-font-bold*)
    (treeview::treeview-data-reference-set 'treeview::font-italic '*outline-tree-font-italic*)
    (treeview::treeview-data-reference-set 'treeview::font-underline '*outline-tree-font-underline*)
    ;; style
    (treeview::treeview-data-reference-set 'treeview::style-hasbuttons '*outline-tree-style-hasbuttons*)
    (treeview::treeview-data-reference-set 'treeview::style-haslines '*outline-tree-style-haslines*)
    (treeview::treeview-data-reference-set 'treeview::style-linesatroot '*outline-tree-style-linesatroot*)
    (treeview::treeview-data-reference-set 'treeview::style-editlabels '*outline-tree-style-editlabels*)
    (treeview::treeview-data-reference-set 'treeview::style-enabledragdrop '*outline-tree-style-enabledragdrop*)
    (treeview::treeview-data-reference-set 'treeview::style-showselalways '*outline-tree-style-showselalways*)
    (treeview::treeview-data-reference-set 'treeview::style-rtlreading '*outline-tree-style-rtlreading*)
    (treeview::treeview-data-reference-set 'treeview::style-tooltips '*outline-tree-style-tooltips*)
    (treeview::treeview-data-reference-set 'treeview::style-checkboxes '*outline-tree-style-checkboxes*)
    (treeview::treeview-data-reference-set 'treeview::style-trackselect '*outline-tree-style-trackselect*)
    (treeview::treeview-data-reference-set 'treeview::style-singleexpand '*outline-tree-style-singleexpand*)
    (treeview::treeview-data-reference-set 'treeview::style-infotip '*outline-tree-style-infotip*)
    (treeview::treeview-data-reference-set 'treeview::style-fullrowselect '*outline-tree-style-fullrowselect*)
    (treeview::treeview-data-reference-set 'treeview::style-scroll '*outline-tree-style-scroll*)
    (treeview::treeview-data-reference-set 'treeview::style-nonevenheight '*outline-tree-style-nonevenheight*)
    (treeview::treeview-data-reference-set 'treeview::style-hscroll '*outline-tree-style-hscroll*)
    ;; indent
    (treeview::treeview-data-reference-set 'treeview::indent-manual-p '*outline-tree-indent-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::indent '*outline-tree-indent*)
    ;; height
    (treeview::treeview-data-reference-set 'treeview::item-height-manual-p '*outline-tree-item-height-manual-p*)
    (treeview::treeview-data-reference-set 'treeview::item-height '*outline-tree-item-height*)
    ;; icon
    (treeview::treeview-data-reference-set 'treeview::icon '*outline-tree-icon*)
    (treeview::treeview-data-reference-set 'treeview::icon-directory '*outline-tree-icon-directory*)
    (treeview::treeview-data-set 'treeview::initialize-icons-func 'outline-tree-initialize-icons)
    ;; keymap
    (treeview::treeview-data-set 'treeview::fix-keymap-symbol '*outline-tree-fix-map*)
    (treeview::treeview-data-set 'treeview::keymap-symbol '*outline-tree-map*)
    ;; mouse
    (treeview::treeview-data-set 'treeview::menu-gen 'outline-tree-menu-gen)
    ;; func
    (treeview::treeview-data-set 'treeview::implicit-func-gen 'outline-tree-node-implicit-func-gen)
    (treeview::treeview-data-set 'treeview::explicit-func-gen 'outline-tree-node-explicit-func-gen)
    ;; exclusive-open-group
    (treeview::treeview-data-reference-set 'treeview::exclusive-open-group '*outline-tree-exclusive-open-group*)
    ;; scroll
    (treeview::treeview-data-reference-set 'treeview::recenter '*outline-tree-treeview-recenter*)
    (treeview::treeview-data-reference-set 'treeview::recenter-line '*outline-tree-treeview-recenter-line*)
    (treeview::treeview-data-reference-set 'treeview::scroll-margin '*outline-tree-treeview-scroll-margin*)
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; エディタ表示行
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-editor-recenter* :line "t, nil, :line")
(define-history-variable *outline-tree-editor-recenter-line* 3)

;;----------------------------------------------------------------------------
;; 作成時展開階層 (buffer-node からの深さ)
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-expand-on-create-outline* :depth "t, nil, :depth")
(define-history-variable *outline-tree-expand-depth-on-create-outline* 1)

;;----------------------------------------------------------------------------
;; カーソル追従時展開階層 (buffer-node からの深さ)
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-expand-on-chase-cursor* :depth "t, nil, :depth")
(define-history-variable *outline-tree-expand-depth-on-chase-cursor* 3)

;;----------------------------------------------------------------------------
;; TreeView ライブラリラッパ関数
;;----------------------------------------------------------------------------
(defun outline-tree-exist-p ()
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-exist-p)))
(defun outline-tree-open ()
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-open)))
(defun outline-tree-close ()
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-close)))
(defun outline-tree-open-p ()
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-open-p)))
(defun outline-tree-close-p ()
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-close-p)))
(defun outline-tree-node-valid-p (node)
  (treeview::treeview-hitem-valid-p node))
(defun outline-tree-node-has-children-p (node)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-item-has-children-p node)))
(defun outline-tree-get-selected-node ()
  (when (outline-tree-exist-p)
    (treeview::with-app (*outline-tree-app-id*)
      (treeview::treeview-get-selected-item))))

;;----------------------------------------------------------------------------
;; 基本ユーザ操作コマンド
;;----------------------------------------------------------------------------
(defun outline-tree-node-implicit-action (&optional node)
  (interactive)
  (let ((func (outline-tree-node-implicit-func-gen node)))
    (when func (funcall func))))
(defun outline-tree-node-explicit-action (&optional node)
  (interactive)
  (let ((func (outline-tree-node-explicit-func-gen node)))
    (when func (funcall func))))
(defun outline-tree-node-action (&optional node)
  (interactive)
  (let ((func (or (outline-tree-node-explicit-func-gen node)
                  (outline-tree-node-implicit-func-gen node))))
    (when func (funcall func))))

;;----------------------------------------------------------------------------
;; TREEVIEW 作成/削除/アンインストール
;;----------------------------------------------------------------------------
(defun outline-tree-create ()
  "outline-tree: アウトラインツリー作成"
  (interactive)
  (outline-tree-autoload)
  (outline-tree-config-load)
  (when (eq *outline-tree-use* nil)
    (setq *outline-tree-use* t))
  (outline-tree-initialize-treeview)
  (outline-tree-create-outline-function-menu-gen)
  (outline-tree-create-outline-function-info-menu-gen)
  (unless (outline-tree-exist-p)
    (treeview::treeview-create-ex
     *outline-tree-app-id*
     (if (find *outline-tree-window-position*
               (list treeview::XPIS_LEFT treeview::XPIS_RIGHT))
         *outline-tree-window-width*
       *outline-tree-window-height*)
     *outline-tree-window-position*)
    (clrhash *outline-tree-node-hash*)
    (clrhash *outline-tree-folder-hash*)
    (clrhash *outline-tree-category-hash*)
    (clrhash *outline-tree-buffer-hash*)
    (add-hook '*create-buffer-hook* 'outline-tree-create-buffer-node-by-buffer)
    (add-hook '*find-file-hooks* 'outline-tree-create-buffer-node-by-buffer)
    (add-hook '*after-save-buffer-hook* 'outline-tree-create-buffer-node-by-buffer)
    (add-hook '*delete-buffer-hook* 'outline-tree-delete-buffer-node-by-buffer)
    (add-hook '*pre-command-hook* 'outline-tree-delete-text-highlight)
    (add-hook '*post-command-hook* 'outline-tree-select-node-by-window-for-hook)
    (when (boundp 'ed::*after-rename-buffer-hook*)
      (add-hook 'ed::*after-rename-buffer-hook* 'outline-tree-create-buffer-node-by-buffer))
    (treeview::with-app (*outline-tree-app-id*)
      ;; 起動時固有処理 - 開始
      (outline-tree-create-buffer-node-by-buffer (buffer-list))
      (outline-tree-initialize-expand-node)
      (outline-tree-sort-folder-node)
      (outline-tree-select-node)
      (outline-tree-update-modified-buffer-node-name-view)
      ;; 起動時固有処理 - 終了
      (treeview::treeview-focus-editor)
      (treeview::treeview-refresh-treeview)))
  (run-hooks '*outline-tree-create-hook*))

(defun outline-tree-delete ()
  "outline-tree: アウトラインツリー削除"
  (interactive)
  (when (eq *outline-tree-use* t)
    (setq *outline-tree-use* nil))
  (maphash #'(lambda (buffer node)
               (if (and (not (deleted-buffer-p buffer))
                        (gethash buffer *outline-tree-buffer-hash*))
                   (outline-tree-delete-buffer-node-by-buffer buffer)))
           *outline-tree-buffer-hash*)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-delete))
  (delete-hook '*create-buffer-hook* 'outline-tree-create-buffer-node-by-buffer)
  (delete-hook '*find-file-hooks* 'outline-tree-create-buffer-node-by-buffer)
  (delete-hook '*after-save-buffer-hook* 'outline-tree-create-buffer-node-by-buffer)
  (delete-hook '*delete-buffer-hook* 'outline-tree-delete-buffer-node-by-buffer)
  (delete-hook '*pre-command-hook* 'outline-tree-delete-text-highlight)
  (delete-hook '*post-command-hook* 'outline-tree-select-node-by-window-for-hook)
  (when (boundp 'ed::*after-rename-buffer-hook*)
    (delete-hook 'ed::*after-rename-buffer-hook* 'outline-tree-create-buffer-node-by-buffer))
  (treeview::treeview-focus-editor)
  (refresh-screen)
  (run-hooks '*outline-tree-delete-hook*))

(defun outline-tree-toggle ()
  "outline-tree: アウトラインツリーの使用トグル"
  (interactive)
  (if (outline-tree-exist-p)
      (outline-tree-delete)
    (outline-tree-create)))

(defun outline-tree-uninstall ()
  "outline-tree: アンインストール"
  (outline-tree-delete)
  (outline-tree-delete-menu)
  (run-hooks '*outline-tree-uninstall-hook*)
  (let ((package (find-package "outline-tree2")))
    (dolist (x (copy-list ed::*history-variable-list*))
      (if (eq (symbol-package x) package)
          (unregister-history-variable x)))))

;;----------------------------------------------------------------------------
;; メニュー登録/削除
;;----------------------------------------------------------------------------
(defun outline-tree-insert-menu-items (&key menu position head-sep tail-sep)
  "outline-tree: メニューへ登録"
  (treeview::with-app (*outline-tree-app-id*)
    (if (and (not (menup menu)) (menup *app-menu*))
        (setq menu (get-menu *app-menu* 'ed::view)))
    (when (menup menu)
      (outline-tree-delete-menu menu)
      (unless (and (numberp position) (integerp position) (not (minusp position))
                   (get-menu menu position t))
        (setq position -1)
        (while (get-menu menu (incf position) t)))
      (decf position)
      (if (and head-sep
               (not (minusp position))
               (get-menu menu position t))
          (insert-menu-separator menu (incf position) 'outline-tree-sep))
      (insert-menu-item menu (incf position) 'outline-tree-toggle
                        "アウトラインツリー(&O)"
                        'outline-tree-toggle
                        #'(lambda ()
                            (and (outline-tree-exist-p) :check)))
      (if (and tail-sep
               (get-menu menu (incf position) t))
          (insert-menu-separator menu position 'outline-tree-sep)))))
(defun outline-tree-delete-menu (&optional menu)
  "outline-tree: メニューから削除"
  (if (and (not (menup menu)) (menup *app-menu*))
      (setq menu (get-menu *app-menu* 'ed::view)))
  (when (menup menu)
    (while (delete-menu menu 'outline-tree-toggle))
    (while (delete-menu menu 'outline-tree-sep))))

;;----------------------------------------------------------------------------
;; 固有アイコン
;;----------------------------------------------------------------------------
(defvar *outline-tree-icon-id-buffer* nil)
(defvar *outline-tree-icon-id-file* nil)
(defvar *outline-tree-icon-id-folder* nil)
(defvar *outline-tree-icon-id-category* nil)
(defvar *outline-tree-icon-id-range* nil)
(defvar *outline-tree-icon-id-range1* nil)
(defvar *outline-tree-icon-id-range2* nil)
(defvar *outline-tree-icon-id-point* nil)
(defvar *outline-tree-icon-id-info* nil)
(defvar *outline-tree-icon-id-section* nil)
(defvar *outline-tree-icon-id-heading* nil)
(defvar *outline-tree-icon-id-heading1* nil)
(defvar *outline-tree-icon-id-heading2* nil)
(defvar *outline-tree-icon-id-header* nil)

(defvar *outline-tree-icon-symbol-file-alist*
  '((*outline-tree-icon-id-buffer*   . "buffer.ico")
    (*outline-tree-icon-id-file*     . "file.ico")
    (*outline-tree-icon-id-folder*   . "folder.ico")
    (*outline-tree-icon-id-category* . "category.ico")
    (*outline-tree-icon-id-range*    . "range.ico")
    (*outline-tree-icon-id-range1*   . "range1.ico")
    (*outline-tree-icon-id-range2*   . "range2.ico")
    (*outline-tree-icon-id-point*    . "point.ico")
    (*outline-tree-icon-id-info*     . "info.ico")
    (*outline-tree-icon-id-section*  . "section.ico")
    (*outline-tree-icon-id-heading*  . "heading.ico")
    (*outline-tree-icon-id-heading1* . "heading1.ico")
    (*outline-tree-icon-id-heading2* . "heading2.ico")
    (*outline-tree-icon-id-header*   . "header.ico")))

;;----------------------------------------------------------------------------
;; データ保存機構
;;----------------------------------------------------------------------------
(defvar *outline-tree-node-hash* (make-hash-table)
  "node に対応する情報を取得")

(defun outline-tree-data-hash (node)
  (let ((hash (gethash node *outline-tree-node-hash*)))
    (unless hash
      (setq hash (make-hash-table :test #'equal))
      (setf (gethash node *outline-tree-node-hash*) hash))
    hash))
(defun outline-tree-data-set (node key value &optional hash)
  (unless hash
    (setq hash (outline-tree-data-hash node)))
  (setf (gethash key hash) value))
(defun outline-tree-data-get (node key &optional default hash)
  (unless hash
    (setq hash (gethash node *outline-tree-node-hash*)))
  (if hash
      (gethash key hash default)
    (values default nil)))
(defun outline-tree-data-del (node)
  (remhash node *outline-tree-node-hash*))
(defun outline-tree-get-enum-node-data (node)
  (let ((hash (gethash node *outline-tree-node-hash*)) lst)
    (when hash
      (maphash #'(lambda (key data)
                   (pushnew (cons key data) lst
                            :key #'car :test #'equal))
               hash))
    (sort lst #'string<= :key #'car)))

;;----------------------------------------------------------------------------
;; データ構造
;;----------------------------------------------------------------------------
;; 各種データ取得
(defun outline-tree-data-get-type (node)
  (outline-tree-data-get node "type"))
(defun outline-tree-data-get-node-name (node)
  (outline-tree-data-get node "node-name"))
(defun outline-tree-data-get-implicit-func (node)
  (outline-tree-data-get node "implicit-func"))
(defun outline-tree-data-get-explicit-func (node)
  (outline-tree-data-get node "explicit-func"))

(defun outline-tree-data-get-sub-type (node)
  (outline-tree-data-get node "sub-type"))
(defun outline-tree-data-get-group-count (node)
  (outline-tree-data-get node "group-count" 0))
(defun outline-tree-data-get-folder-name (node)
  (outline-tree-data-get node "folder-name"))
(defun outline-tree-data-get-category-name (node)
  (outline-tree-data-get node "category-name"))
(defun outline-tree-data-get-buffer (node)
  (outline-tree-data-get node "buffer"))
(defun outline-tree-data-get-buffer-name (node)
  (outline-tree-data-get node "buffer-name"))
(defun outline-tree-data-get-namestring (node)
  (outline-tree-data-get node "namestring"))
(defun outline-tree-data-get-range-name (node)
  (outline-tree-data-get node "range-name"))
(defun outline-tree-data-get-point-name (node)
  (outline-tree-data-get node "point-name"))
(defun outline-tree-data-get-info-name (node)
  (outline-tree-data-get node "info-name"))
(defun outline-tree-data-get-section-name (node)
  (outline-tree-data-get node "section-name"))
(defun outline-tree-data-get-title-range (node)
  (outline-tree-data-get node "title-range"))
(defun outline-tree-data-get-contents-range (node)
  (outline-tree-data-get node "contents-range"))
(defun outline-tree-data-get-whole-range (node)
  (outline-tree-data-get node "whole-range"))
(defun outline-tree-data-get-point (node)
  (outline-tree-data-get node "point"))

;; 特定コマンド用データ設定/取得
(defun outline-tree-data-set-output-range (node output-range)
  (outline-tree-data-set node "output-range" (copy-list output-range)))
(defun outline-tree-data-get-output-range (node)
  (outline-tree-data-get node "output-range"))

;; ノード型チェック
(defun outline-tree-buffer-node-p (node)
  (eq (outline-tree-data-get-type node) :buffer-node))
(defun outline-tree-folder-node-p (node)
  (eq (outline-tree-data-get-type node) :folder-node))
(defun outline-tree-category-node-p (node)
  (eq (outline-tree-data-get-type node) :category-node))
(defun outline-tree-range-node-p (node)
  (eq (outline-tree-data-get-type node) :range-node))
(defun outline-tree-point-node-p (node)
  (eq (outline-tree-data-get-type node) :point-node))
(defun outline-tree-info-node-p (node)
  (eq (outline-tree-data-get-type node) :info-node))
(defun outline-tree-section-node-p (node)
  (eq (outline-tree-data-get-type node) :section-node))
(defun outline-tree-heading-node-p (node)
  (and (eq (outline-tree-data-get-type node) :range-node)
       (eq (outline-tree-data-get-sub-type node) :heading-node)))
(defun outline-tree-header-node-p (node)
  (and (eq (outline-tree-data-get-type node) :range-node)
       (eq (outline-tree-data-get-sub-type node) :header-node)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 固有処理
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; データから特定ノードの逆引き
;;----------------------------------------------------------------------------
;; folder-node
(defvar *outline-tree-folder-hash* (make-hash-table :test #'equalp)
  "folder-name に対応する node を取得")
(defun outline-tree-revdata-set-folder-node (folder-name node)
  (setf (gethash folder-name *outline-tree-folder-hash*) node))
(defun outline-tree-revdata-get-folder-node (folder-name)
  (gethash folder-name *outline-tree-folder-hash*))
(defun outline-tree-revdata-del-folder-node (folder-name)
  (remhash folder-name *outline-tree-folder-hash*))

;; category-node
(defvar *outline-tree-category-hash* (make-hash-table :test #'equalp)
  "category-name に対応する node を取得")
(defun outline-tree-revdata-set-category-node (category-name node)
  (treeview::with-app (*outline-tree-app-id*)
    (let ((parent-node (treeview::treeview-get-parent-item node)))
      (setf (gethash (cons category-name parent-node) *outline-tree-category-hash*) node))))
(defun outline-tree-revdata-get-category-node (category-name &optional (parent-node 0))
  (if (and (numberp parent-node) (minusp parent-node))
      (setq parent-node 0))
  (gethash (cons category-name parent-node) *outline-tree-category-hash*))
(defun outline-tree-revdata-del-category-node (node); node 指定に注意
  (treeview::with-app (*outline-tree-app-id*)
    (let ((name (outline-tree-data-get-category-name node))
          (parent-node (treeview::treeview-get-parent-item node)))
      (remhash (cons name parent-node) *outline-tree-category-hash*))))

;; buffer-node
(defvar *outline-tree-buffer-hash* (make-hash-table)
  "buffer に対応する node を取得")
(defun outline-tree-revdata-set-buffer-node (buffer node)
  (setf (gethash buffer *outline-tree-buffer-hash*) node))
(defun outline-tree-revdata-get-buffer-node (buffer)
  (gethash buffer *outline-tree-buffer-hash*))
(defun outline-tree-revdata-del-buffer-node (buffer)
  (remhash buffer *outline-tree-buffer-hash*))

;;----------------------------------------------------------------------------
;; ノードデータ登録
;;----------------------------------------------------------------------------
(defun outline-tree-register-node (node type node-name implicit-func explicit-func)
  (outline-tree-data-set node "type" type)
  (outline-tree-data-set node "node-name" node-name)
  (outline-tree-data-set node "implicit-func" implicit-func)
  (outline-tree-data-set node "explicit-func" explicit-func)
  node)
(defun outline-tree-update-node (node &key (group-count nil group-count-sv)
                                           (node-name nil node-name-sv)
                                           (implicit-func nil implicit-func-sv)
                                           (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when group-count-sv
      (outline-tree-data-set node "group-count" group-count hash))
    (when node-name-sv
      (outline-tree-data-set node "node-name" node-name hash))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; folder-node
(defun outline-tree-register-folder-node (folder-name node &key implicit-func explicit-func)
  (outline-tree-revdata-set-folder-node folder-name node)
  (outline-tree-data-set node "folder-name" folder-name)
  (outline-tree-register-node node :folder-node folder-name implicit-func explicit-func))
(defun outline-tree-unregister-folder-node (node)
  (let ((name (outline-tree-data-get-folder-name node)))
    (outline-tree-revdata-del-folder-node name)
    (outline-tree-data-del node)))
(defun outline-tree-update-folder-node (node &key (folder-name nil folder-name-sv)
                                                  (implicit-func nil implicit-func-sv)
                                                  (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when folder-name-sv
      (outline-tree-revdata-del-folder-node (outline-tree-data-get-folder-name node))
      (outline-tree-revdata-set-folder-node folder-name node)
      (outline-tree-data-set node "folder-name" folder-name hash)
      (outline-tree-data-set node "node-name" folder-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node folder-name)))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; category-node
(defun outline-tree-register-category-node (category-name node &key implicit-func explicit-func)
  (outline-tree-revdata-set-category-node category-name node)
  (outline-tree-data-set node "category-name" category-name)
  (outline-tree-register-node node :category-node category-name implicit-func explicit-func))
(defun outline-tree-unregister-category-node (node)
  (outline-tree-revdata-del-category-node node)
  (outline-tree-data-del node))
(defun outline-tree-update-category-node (node &key (category-name nil category-name-sv)
                                                    (implicit-func nil implicit-func-sv)
                                                    (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when category-name-sv
      (outline-tree-revdata-del-category-node (outline-tree-data-get-category-name node))
      (outline-tree-revdata-set-category-node category-name node)
      (outline-tree-data-set node "category-name" category-name hash)
      (outline-tree-data-set node "node-name" category-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node category-name)))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; buffer-node
(defun outline-tree-register-buffer-node (buffer node &key buffer-name namestring implicit-func explicit-func)
  (outline-tree-revdata-set-buffer-node buffer node)
  (outline-tree-data-set node "buffer" buffer)
  (outline-tree-data-set node "buffer-name" buffer-name)
  (outline-tree-data-set node "namestring" namestring)
  (let ((node-name (if namestring (file-namestring namestring) buffer-name)))
    (outline-tree-register-node node :buffer-node node-name implicit-func explicit-func)))
(defun outline-tree-unregister-buffer-node (node)
  (let ((buffer (outline-tree-data-get-buffer node)))
    (outline-tree-revdata-del-buffer-node buffer)
    (outline-tree-data-del node)))
(defun outline-tree-update-buffer-node (node &key (buffer nil buffer-sv)
                                                  (implicit-func nil implicit-func-sv)
                                                  (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node))
        buffer-name namestring file-name node-name)
    (when buffer-sv
      (outline-tree-revdata-del-buffer-node (outline-tree-data-get-buffer node))
      (outline-tree-revdata-set-buffer-node buffer node)
      (outline-tree-data-set node "buffer" buffer hash)
      (setq buffer-name (buffer-name buffer))
      (setq namestring (get-buffer-file-name buffer))
      (when namestring
        (setq file-name (file-namestring namestring)))
      (setq node-name (or file-name buffer-name))
      (outline-tree-data-set node "buffer-name" buffer-name hash)
      (outline-tree-data-set node "namestring" namestring hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node node-name)))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; range-node
(defun outline-tree-register-range-node (range-name node
                                         &key title-range contents-range whole-range sub-type
                                              implicit-func explicit-func)
  (outline-tree-data-set node "range-name" range-name)
  (outline-tree-data-set node "title-range" title-range)
  (outline-tree-data-set node "contents-range" contents-range)
  (outline-tree-data-set node "whole-range" whole-range)
  (outline-tree-data-set node "sub-type" sub-type)
  (outline-tree-register-node node :range-node range-name implicit-func explicit-func))
(defun outline-tree-unregister-range-node (node)
  (outline-tree-data-del node))
(defun outline-tree-update-range-node (node &key (range-name nil range-name-sv)
                                                 (title-range nil title-range-sv)
                                                 (contents-range nil contents-range-sv)
                                                 (whole-range nil whole-range-sv)
                                                 (implicit-func nil implicit-func-sv)
                                                 (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when range-name-sv
      (outline-tree-data-set node "range-name" range-name hash)
      (outline-tree-data-set node "node-name" range-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node range-name)))
    (when title-range-sv
      (outline-tree-data-set node "title-range" (copy-list title-range) hash))
    (when contents-range-sv
      (outline-tree-data-set node "contents-range" (copy-list contents-range) hash))
    (when whole-range-sv
      (outline-tree-data-set node "whole-range" (copy-list whole-range) hash))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" (copy-list implicit-func) hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" (copy-list explicit-func) hash))
    node))

;; point-node
(defun outline-tree-register-point-node (point-name node &key point implicit-func explicit-func)
  (outline-tree-data-set node "point-name" point-name)
  (outline-tree-data-set node "point" point)
  (outline-tree-register-node node :point-node point-name implicit-func explicit-func))
(defun outline-tree-unregister-point-node (node)
  (outline-tree-data-del node))
(defun outline-tree-update-point-node (node &key (point-name nil point-name-sv)
                                                 (point nil point-sv)
                                                 (implicit-func nil implicit-func-sv)
                                                 (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when point-name-sv
      (outline-tree-data-set node "point-name" point-name hash)
      (outline-tree-data-set node "node-name" point-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node point-name)))
    (when point-sv
      (outline-tree-data-set node "point" point hash))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; info-node
(defun outline-tree-register-info-node (info-name node &key implicit-func explicit-func)
  (outline-tree-data-set node "info-name" info-name)
  (outline-tree-register-node node :info-node info-name implicit-func explicit-func))
(defun outline-tree-unregister-info-node (node)
  (outline-tree-data-del node))
(defun outline-tree-update-info-node (node &key (info-name nil info-name-sv)
                                                (implicit-func nil implicit-func-sv)
                                                (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when info-name-sv
      (outline-tree-data-set node "info-name" info-name hash)
      (outline-tree-data-set node "node-name" info-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node info-name)))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;; section-node
(defun outline-tree-register-section-node (section-name node &key implicit-func explicit-func)
  (outline-tree-data-set node "section-name" section-name)
  (outline-tree-register-node node :section-node section-name implicit-func explicit-func))
(defun outline-tree-unregister-section-node (node)
  (outline-tree-data-del node))
(defun outline-tree-update-section-node (node &key (section-name nil section-name-sv)
                                                   (implicit-func nil implicit-func-sv)
                                                   (explicit-func nil explicit-func-sv))
  (let ((hash (outline-tree-data-hash node)))
    (when section-name-sv
      (outline-tree-data-set node "section-name" section-name hash)
      (outline-tree-data-set node "node-name" section-name hash)
      (treeview::with-app (*outline-tree-app-id*)
        (treeview::treeview-set-item-text node section-name)))
    (when implicit-func-sv
      (outline-tree-data-set node "implicit-func" implicit-func hash))
    (when explicit-func-sv
      (outline-tree-data-set node "explicit-func" explicit-func hash))
    node))

;;----------------------------------------------------------------------------
;; ノード単体追加
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-abbreviate-display-folder-name-length* 0
  "フォルダノード名の表示幅
0 を指定した場合、表示の省略なし")
(defun outline-tree-abbreviate-display-folder-name (&optional length)
  "フォルダノード名の表示幅を変更する。"
  (treeview::with-app (*outline-tree-app-id*)
    (let (folder-node-list folder-name)
      (maphash
       #'(lambda (folder-name folder-node) (push folder-node folder-node-list))
       outline-tree2::*outline-tree-folder-hash*)
      (dolist (folder-node folder-node-list)
        (setq folder-name (outline-tree-data-get-folder-name folder-node))
        (treeview::treeview-set-item-text
         folder-node
         (if (and (integerp length) (plusp length))
             (abbreviate-display-string folder-name length t)
           folder-name))))))
(defun outline-tree-sort-folder-node ()
  "フォルダノードをフォルダノード名でソートする。
outline-tree-insert-folder-node 関数内で使用される。"
  (treeview::with-app (*outline-tree-app-id*)
    (let (folder-node-cell-list node (i 0))
      (setq node (outline-tree-revdata-get-category-node
                  *outline-tree-invisible-buffer-category-node-name*))
      (when (outline-tree-node-valid-p node)
        (treeview::treeview-set-item-data node (incf i)))
      (setq node (outline-tree-revdata-get-category-node
                  *outline-tree-visible-buffer-category-node-name*))
      (when (outline-tree-node-valid-p node)
        (treeview::treeview-set-item-data node (incf i)))
      (maphash
       #'(lambda (folder-name folder-node) (push (cons folder-name folder-node) folder-node-cell-list))
       outline-tree2::*outline-tree-folder-hash*)
      (setq folder-node-cell-list (stable-sort folder-node-cell-list #'string-lessp :key #'car))
      (dolist (folder-node-cell folder-node-cell-list)
        (setq node (cdr folder-node-cell))
        (treeview::treeview-set-item-data node (incf i)))
      (treeview::treeview-sort-children-cb-lparam-ascending winapi::TVI_ROOT))))
(defun outline-tree-insert-folder-node (folder-name parent-node &key (insertafter winapi:TVI_SORT)
                                                                     implicit-func explicit-func)
  "フォルダノードを追加する。
insertafter 引数はインターフェース統一のために存在するが無効。"
  (treeview::with-app (*outline-tree-app-id*)
    (prog1
        (outline-tree-register-folder-node
         folder-name
         (treeview::treeview-insert-item
          (if (and (integerp *outline-tree-abbreviate-display-folder-name-length*)
                   (plusp *outline-tree-abbreviate-display-folder-name-length*))
              (abbreviate-display-string folder-name
                                         *outline-tree-abbreviate-display-folder-name-length*
                                         t)
            folder-name)
          parent-node
          :insertafter insertafter
          :icon *outline-tree-icon-id-folder*
          :sicon *outline-tree-icon-id-folder*)
         :implicit-func implicit-func
         :explicit-func explicit-func)
      (outline-tree-sort-folder-node))))
(defun outline-tree-insert-category-node (category-name parent-node &key (insertafter winapi:TVI_SORT)
                                                                         implicit-func explicit-func)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-register-category-node
     category-name
     (treeview::treeview-insert-item category-name parent-node
                                     :insertafter insertafter
                                     :icon *outline-tree-icon-id-category*
                                     :sicon *outline-tree-icon-id-category*)
     :implicit-func implicit-func
     :explicit-func explicit-func)))

(defvar *outline-tree-update-modified-buffer-node-name-view-p* t)
(defun outline-tree-update-modified-buffer-node-name-view ()
  (unless *outline-tree-update-modified-buffer-node-name-view-p*
    (return-from outline-tree-update-modified-buffer-node-name-view nil))
  (treeview::with-app (*outline-tree-app-id*)
    (let (buffer-node-name-view)
      (maphash
       #'(lambda (buffer buffer-node)
           (setq buffer-node-name-view
                 (if (buffer-modified-p buffer)
                     (concat "* " (outline-tree-data-get-node-name buffer-node))
                   (outline-tree-data-get-node-name buffer-node)))
           (unless (string-equal buffer-node-name-view
                                 (treeview::treeview-get-item-text buffer-node))
             (treeview::treeview-set-item-text buffer-node buffer-node-name-view)))
       outline-tree2::*outline-tree-buffer-hash*))))
(add-hook 'ed::*post-command-hook* 'outline-tree-update-modified-buffer-node-name-view)
(defun outline-tree-sort-node (parent-node)
  "指定した parent-node の子ノードをノード名でソートする。
outline-tree-insert-buffer-node 関数内で使用される。"
  (treeview::with-app (*outline-tree-app-id*)
    (let (node node-cell-list (i 0))
      (setq node (treeview::treeview-get-child-item parent-node))
      (while (outline-tree-node-valid-p node)
        (push (cons (outline-tree-data-get-node-name node) node) node-cell-list)
        (setq node (treeview::treeview-get-next-sibling-item node)))
      (setq node-cell-list (stable-sort node-cell-list #'string< :key #'car))
      (dolist (node-cell node-cell-list)
        (setq node (cdr node-cell))
        (treeview::treeview-set-item-data node (incf i)))
      (treeview::treeview-sort-children-cb-lparam-ascending parent-node))))
(defun outline-tree-insert-buffer-node (buffer parent-node &key (insertafter winapi:TVI_SORT)
                                                                implicit-func explicit-func)
  (treeview::with-app (*outline-tree-app-id*)
    (let* ((buffer-name (buffer-name buffer))
           (namestring (get-buffer-file-name buffer))
           (file-name (and namestring (file-namestring namestring))))
      (prog1
          (outline-tree-register-buffer-node
           buffer
           (if namestring
               (treeview::treeview-insert-item file-name parent-node
                                               :insertafter insertafter
                                               :icon *outline-tree-icon-id-file*
                                               :sicon *outline-tree-icon-id-file*)
             (treeview::treeview-insert-item buffer-name parent-node
                                             :insertafter insertafter
                                             :icon *outline-tree-icon-id-buffer*
                                             :sicon *outline-tree-icon-id-buffer*))
           :buffer-name buffer-name
           :namestring namestring
           :implicit-func implicit-func
           :explicit-func explicit-func)
        (outline-tree-sort-node parent-node)))))

(defvar *outline-tree-range-node-group-p* nil
  "内部処理用。
outline-tree-insert-range-node 関数で評価される。
outline-tree-create-outline-range-internal 関数内にて一時的に値が設定される。")
(defun outline-tree-insert-range-node (range-name parent-node
                                       &key (insertafter winapi:TVI_LAST)
                                            title-range whole-range sub-type
                                            implicit-func explicit-func)
  (let (icon group-count)
    (cond ((eq sub-type :header-node)
           (setq icon *outline-tree-icon-id-header*))
          ((and *outline-tree-range-node-group-p*
                (plusp (setq group-count (outline-tree-data-get-group-count parent-node))))
           (cond ((eq sub-type :heading-node)
                  (cond ((= (mod group-count 2) 1)
                         (setq icon *outline-tree-icon-id-heading1*))
                        ((= (mod group-count 2) 0)
                         (setq icon *outline-tree-icon-id-heading2*))))
                 (t
                  (cond ((= (mod group-count 2) 1)
                         (setq icon *outline-tree-icon-id-range1*))
                        ((= (mod group-count 2) 0)
                         (setq icon *outline-tree-icon-id-range2*))))))
          (t
           (cond ((eq sub-type :heading-node)
                  (setq icon *outline-tree-icon-id-heading*))
                 (t
                  (setq icon *outline-tree-icon-id-range*)))))
    (treeview::with-app (*outline-tree-app-id*)
      (outline-tree-register-range-node
       range-name
       (treeview::treeview-insert-item range-name parent-node
                                       :insertafter insertafter
                                       :icon icon :sicon icon)
       :title-range title-range
       :whole-range whole-range
       :sub-type sub-type
       :implicit-func implicit-func
       :explicit-func explicit-func))))
(defun outline-tree-insert-point-node (point-name parent-node &key (insertafter winapi:TVI_LAST)
                                                                   point
                                                                   implicit-func explicit-func)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-register-point-node
     point-name
     (treeview::treeview-insert-item point-name parent-node
                                     :insertafter insertafter
                                     :icon *outline-tree-icon-id-point*
                                     :sicon *outline-tree-icon-id-point*)
     :point point
     :implicit-func implicit-func
     :explicit-func explicit-func)))
(defun outline-tree-insert-info-node (info-name parent-node &key (insertafter winapi:TVI_LAST)
                                                                 implicit-func explicit-func)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-register-info-node
     info-name
     (treeview::treeview-insert-item info-name parent-node
                                     :insertafter insertafter
                                     :icon *outline-tree-icon-id-info*
                                     :sicon *outline-tree-icon-id-info*)
     :implicit-func implicit-func
     :explicit-func explicit-func)))
(defun outline-tree-insert-section-node (section-name parent-node &key (insertafter winapi:TVI_LAST)
                                                                       implicit-func explicit-func)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-register-section-node
     section-name
     (treeview::treeview-insert-item section-name parent-node
                                     :insertafter insertafter
                                     :icon *outline-tree-icon-id-section*
                                     :sicon *outline-tree-icon-id-section*)
     :implicit-func implicit-func
     :explicit-func explicit-func)))

;;----------------------------------------------------------------------------
;; ノード(単純)削除
;;----------------------------------------------------------------------------
(defun outline-tree-remove-node-tree (node)
  (treeview::treeview-funcall-recursive-tree-bottom-up
   node #'outline-tree-remove-node))
(defun outline-tree-remove-node (node)
  (case (outline-tree-data-get-type node)
    (:range-node
     (outline-tree-remove-range-node node))
    (:point-node
     (outline-tree-remove-point-node node))
    (:buffer-node
     (outline-tree-remove-buffer-node node))
    (:folder-node
     (outline-tree-remove-folder-node node))
    (:category-node
     (outline-tree-remove-category-node node))
    (:info-node
     (outline-tree-remove-info-node node))
    (:section-node
     (outline-tree-remove-section-node node)))
  t)
(defun outline-tree-remove-range-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-range-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-point-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-point-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-buffer-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-buffer-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-folder-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-folder-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-category-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-category-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-info-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-info-node node)
    (treeview::treeview-delete-item node)))
(defun outline-tree-remove-section-node (node)
  (treeview::with-app (*outline-tree-app-id*)
    (outline-tree-unregister-section-node node)
    (treeview::treeview-delete-item node)))

;;----------------------------------------------------------------------------
;; window/node -> buffer での関数呼び出し
;;----------------------------------------------------------------------------
(defun outline-tree-funcall-buffer-by-window (func window)
  (unless window
    (setq window (outline-tree-get-target-window)))
  (let ((gcolumn (goal-column)))
    (prog1
        (save-window-excursion
          (set-window window)
          (funcall func (selected-buffer)))
      (set-goal-column gcolumn))))
(defun outline-tree-funcall-buffer-by-node (func node)
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (let (buffer)
      (when (and (outline-tree-node-valid-p node)
                 (setq buffer (outline-tree-get-buffer-by-node node)))
        (funcall func buffer)))))

;;----------------------------------------------------------------------------
;; contents-range の設定
;;    contents-range とは？:
;;      
;;----------------------------------------------------------------------------
(defun outline-tree-set-data-contents-range-tree (arg)
  (case (type-of arg)
    (integer ; node
     (outline-tree-set-data-contents-range-tree-by-node arg))
    (buffer
     (outline-tree-set-data-contents-range-tree-by-buffer arg))
    (window
     (outline-tree-set-data-contents-range-tree-by-window arg))))
(defun outline-tree-set-data-contents-range-tree-by-node (&optional node)
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (setq node (outline-tree-get-buffer-node-by-node node))
    (unless node
      (return-from outline-tree-set-data-contents-range-tree-by-node))
    (let ((line-oriented-p
           (member :line-oriented (outline-tree-get-create-outline-function-type
                                   (outline-tree-get-create-outline-function-by-node node)))))
      (save-excursion
        (save-restriction
          (set-buffer (outline-tree-get-buffer-by-node node))
          (widen)
          (treeview::treeview-funcall-recursive-subtree-top-down
           node
           #'(lambda (heading-node)
               ;; ノードが heading-node で、まだ contents-range が設定されていない場合
               (when (and (outline-tree-heading-node-p heading-node)
                          (not (outline-tree-data-get-contents-range heading-node)))
                 (let ((range (outline-tree-data-get-whole-range heading-node))
                       (title-range (outline-tree-data-get-title-range heading-node))
                       child-node)
                   ;; 出力範囲から、タイトルの範囲の除く。
                   ;; 現在はタイトルが全範囲の先頭にある場合しか考慮していない。
                   (setq range (outline-tree-range-narrow
                                range
                                (progn
                                  (goto-char (cdr title-range))
                                  (when line-oriented-p
                                    (goto-eol)
                                    (forward-char))
                                  (point))
                                nil))
                   ;; 子ノードがある場合
                   (when (outline-tree-node-has-children-p heading-node)
                     (setq child-node (treeview::treeview-get-child-item heading-node))
                     (while (outline-tree-node-valid-p child-node)
                       (when (outline-tree-heading-node-p child-node)
                         ;; 出力範囲から、子ノードの範囲を除く。
                         ;; 現在は子ノードが親ノードの末尾にある場合しか考慮していない。
                         (setq range (outline-tree-range-narrow
                                      range
                                      nil
                                      (car (outline-tree-data-get-whole-range child-node)))))
                       (setq child-node (treeview::treeview-get-next-sibling-item child-node))))
                   (outline-tree-update-range-node heading-node :contents-range range))))))))
    t))
(defun outline-tree-set-data-contents-range-tree-by-buffer (&optional buffer)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
    (when buffer-node
      (outline-tree-set-data-contents-range-tree-by-node buffer-node))))
(defun outline-tree-set-data-contents-range-tree-by-window (&optional window)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-set-data-contents-range-tree-by-buffer window))

;;----------------------------------------------------------------------------
;; output-range の設定
;;   output-range とは？:
;;     heading-node の出力範囲として設定する「範囲」。
;;     全範囲から、自ノードのタイトルの範囲、子ノードの範囲を除いた部分。
;;----------------------------------------------------------------------------
(defun outline-tree-set-data-output-range-tree (arg)
  (case (type-of arg)
    (integer ; node
     (outline-tree-set-data-output-range-tree-by-node arg))
    (buffer
     (outline-tree-set-data-output-range-tree-by-buffer arg))
    (window
     (outline-tree-set-data-output-range-tree-by-window arg))))
(defun outline-tree-set-data-output-range-tree-by-node (&optional node)
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (setq node (outline-tree-get-buffer-node-by-node node))
    (unless node
      (return-from outline-tree-set-data-output-range-tree-by-node))
    (let ((line-oriented-p
           (member :line-oriented (outline-tree-get-create-outline-function-type
                                   (outline-tree-get-create-outline-function-by-node node)))))
      (save-excursion
        (save-restriction
          (set-buffer (outline-tree-get-buffer-by-node node))
          (widen)
          (treeview::treeview-funcall-recursive-subtree-top-down
           node
           #'(lambda (heading-node)
               ;; ノードが 表示されていて、heading-node の場合
               (when (and (treeview::treeview-item-visible-p heading-node)
                          (outline-tree-heading-node-p heading-node))
                 (let ((range (outline-tree-data-get-whole-range heading-node))
                       (title-range (outline-tree-data-get-title-range heading-node))
                       child-node)
                   ;; 出力範囲から、タイトルの範囲の除く。
                   ;; 現在はタイトルが全範囲の先頭にある場合しか考慮していない。
                   (setq range (outline-tree-range-narrow
                                range
                                (progn
                                  (goto-char (cdr title-range))
                                  (when line-oriented-p
                                    (goto-eol)
                                    (forward-char))
                                  (point))
                                nil))
                   ;; ノードの子ノードが表示されている場合
                   (when (and (outline-tree-node-has-children-p heading-node)
                              (treeview::treeview-expand-p heading-node))
                     (setq child-node (treeview::treeview-get-child-item heading-node))
                     (while (outline-tree-node-valid-p child-node)
                       (when (outline-tree-heading-node-p child-node)
                         ;; 出力範囲から、子ノードの範囲を除く。
                         ;; 現在は子ノードが親ノードの末尾にある場合しか考慮していない。
                         (setq range (outline-tree-range-narrow
                                      range
                                      nil
                                      (car (outline-tree-data-get-whole-range child-node)))))
                       (setq child-node (treeview::treeview-get-next-sibling-item child-node))))
                   (outline-tree-data-set-output-range heading-node range))))))))
    t))
(defun outline-tree-set-data-output-range-tree-by-buffer (&optional buffer)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
    (when buffer-node
      (outline-tree-set-data-output-range-tree-by-node buffer-node))))
(defun outline-tree-set-data-output-range-tree-by-window (&optional window)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-set-data-output-range-tree-by-buffer window))

;;----------------------------------------------------------------------------
;; バッファノードの作成
;;----------------------------------------------------------------------------
(defun outline-tree-create-buffer-node (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-create-buffer-node-by-buffer arg))
    (window
     (outline-tree-create-buffer-node-by-window arg))
    (integer ; node
     (outline-tree-create-buffer-node-by-node arg))))
(defun outline-tree-create-buffer-node-by-buffer (&optional buffer)
  (interactive)
  "バッファに対応するノードの作成/更新"
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-exist-p)
      (return-from outline-tree-create-buffer-node-by-buffer))
    (cond
     ((listp buffer)
      (dolist (x buffer)
        (outline-tree-create-buffer-node-by-buffer x)))
     ((bufferp buffer)
      ;; 既存の buffer-node をチェック
      (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
        (if buffer-node
            (if (outline-tree-buffer-node-obsolete-p buffer-node)
                ;; 古い buffer-node を削除
                (outline-tree-delete-buffer-node-by-buffer buffer)
              ;; 最新の buffer-node の場合は終了
              (return-from outline-tree-create-buffer-node-by-buffer))))
      ;; 登録
      (when (not (deleted-buffer-p buffer))
        (let* ((buffer-name (buffer-name buffer))
               (namestring (and (get-buffer-file-name buffer)
                                (file-exist-p (directory-namestring (get-buffer-file-name buffer)))
                                (get-buffer-file-name buffer)))
               (folder-name (namestring
                             (or (and namestring
                                      (truename (directory-namestring namestring)))
                                 (default-directory buffer))))
               (visible-buffer-p (not (string-match "^ " buffer-name)))
               folder-node buffer-node category-name category-node
               parent-node)
          (cond
           ;; file
           (namestring
            (setq folder-node (outline-tree-get-folder-node-by-folder-name folder-name))
            (unless folder-node
              (setq folder-node (outline-tree-insert-folder-node folder-name winapi:TVI_ROOT)))
            (setq parent-node folder-node))
           ;; visible/invisible buffer
           (t
            ;; category 登録
            (if visible-buffer-p
                (setq category-name *outline-tree-visible-buffer-category-node-name*)
              (setq category-name *outline-tree-invisible-buffer-category-node-name*))
            (unless (setq category-node (outline-tree-revdata-get-category-node category-name))
              (setq category-node (outline-tree-insert-category-node category-name winapi:TVI_ROOT)))
            (setq parent-node category-node)
            ;; sub category (があれば) 登録
            (when (setq category-name (outline-tree-detect-category-name buffer-name))
              (unless (setq category-node
                            (outline-tree-revdata-get-category-node category-name parent-node))
                (setq category-node (outline-tree-insert-category-node category-name parent-node)))
              (setq parent-node category-node))))
          (setq buffer-node (outline-tree-insert-buffer-node buffer parent-node))
          (save-excursion
            (save-window-excursion
              (when (minibuffer-window-p (selected-window))
                (other-window))
              (set-buffer buffer)
              (setq outline-tree-outline-modified nil)))
          (when (or namestring visible-buffer-p)
            (treeview::treeview-expand-expand parent-node))
          (unless (outline-tree-node-valid-p (outline-tree-get-selected-node))
            (outline-tree-select-node-by-buffer buffer))))))))
(defun outline-tree-create-buffer-node-by-window (&optional window)
  (interactive)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-create-buffer-node-by-buffer window))
(defun outline-tree-create-buffer-node-by-node (&optional node)
  (interactive)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-create-buffer-node-by-buffer node))

(defun outline-tree-buffer-node-obsolete-p (buffer-node)
  "バッファノードが最新の状態でないことの判定
outline-tree-create-buffer-node-by-buffer 内で用いられる補助関数"
  (let* ((buffer-name (outline-tree-data-get-buffer-name buffer-node))
         (namestring (outline-tree-data-get-namestring buffer-node))
         (buffer (outline-tree-data-get-buffer buffer-node))
         (current-buffer-name (buffer-name buffer))
         (current-namestring (get-buffer-file-name buffer)))
    (or (not buffer)
        (and namestring (not (equalp namestring current-namestring)))
        (and (not namestring) (not (equal buffer-name current-buffer-name))))))

;;----------------------------------------------------------------------------
;; バッファノードの削除
;;----------------------------------------------------------------------------
(defvar *outline-tree-delete-buffer-node-kill-xyzzy-command-list*
  '(ed::kill-xyzzy)
  "ed::*this-command* がリストに指定されている場合
outline-tree-delete-buffer-node-by-buffer は処理を行わずに終了する。")
(defun outline-tree-delete-buffer-node (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-delete-buffer-node-by-buffer arg))
    (window
     (outline-tree-delete-buffer-node-by-window arg))
    (integer ; node
     (outline-tree-delete-buffer-node-by-node arg))))
(defun outline-tree-delete-buffer-node-by-buffer (&optional buffer)
  (interactive)
  "バッファに対応するノードを削除"
  (when (member ed::*this-command* *outline-tree-delete-buffer-node-kill-xyzzy-command-list*)
    (return-from outline-tree-delete-buffer-node-by-buffer t))
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-exist-p)
      (return-from outline-tree-delete-buffer-node-by-buffer t))
    (cond
     ((listp buffer)
      (dolist (x buffer)
        (outline-tree-delete-buffer-node-by-buffer x)))
     ((bufferp buffer)
      (let* ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer))
             (node buffer-node) parent-node parent-node-list)
        (when (outline-tree-node-valid-p buffer-node)
          (while (and (outline-tree-node-valid-p
                       (setq parent-node (treeview::treeview-get-parent-item node)))
                      (not (outline-tree-node-valid-p
                            (treeview::treeview-get-next-sibling-item
                             (treeview::treeview-get-child-item parent-node)))))
            (push parent-node parent-node-list)
            (setq node parent-node))
          (outline-tree-remove-buffer-node buffer-node)
          (dolist (parent-node (nreverse parent-node-list))
            (case (outline-tree-data-get-type parent-node)
              (:folder-node
               (outline-tree-remove-folder-node parent-node))
              (:category-node
               (outline-tree-remove-category-node parent-node))))))
      (run-hook-with-args '*outline-tree-delete-buffer-node-hook* buffer))))
  t)
(defun outline-tree-delete-buffer-node-by-window (&optional window)
  (interactive)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-delete-buffer-node-by-buffer window))
(defun outline-tree-delete-buffer-node-by-node (&optional node)
  (interactive)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-delete-buffer-node-by-buffer node))

;;----------------------------------------------------------------------------
;; サブカテゴリ名検出
;;----------------------------------------------------------------------------
(defun outline-tree-detect-category-name (name)
  "name から category 分類し、分類可能の場合 category 名を返す"
  (let (category-name)
    (dolist (category-regexp *outline-tree-buffer-category-regexp-list*
                             (setq category-name nil))
      (setq category-name nil)
      (when (listp category-regexp)
        (setq category-name (cdr category-regexp))
        (setq category-regexp (car category-regexp)))
      (when (string-match category-regexp name)
        (unless category-name
          (setq category-name (concat " " (match-string 1))))
        (return)))
    category-name))

;;----------------------------------------------------------------------------
;; アウトラインの作成関数の取得
;;----------------------------------------------------------------------------
(defvar-local outline-tree-create-outline-function-interactive nil
  "対話的にユーザによって設定されるアウトライン作成関数(最優先)")
(defvar-local outline-tree-create-outline-function nil
  "一般的にユーザが mode hook 等で設定するアウトライン作成関数(優先度3)")
(defvar *outline-tree-get-default-create-outline-function*
  'outline-tree-get-default-create-outline-function)

(defun outline-tree-get-create-outline-function (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-get-create-outline-function-by-buffer arg))
    (window
     (outline-tree-get-create-outline-function-by-window arg))
    (integer ; node
     (outline-tree-get-create-outline-function-by-node arg))))
(defun outline-tree-get-create-outline-function-by-buffer (&optional buffer)
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (unless buffer
      (setq buffer (outline-tree-get-target-buffer)))
    (save-excursion
      (unless (eq buffer (selected-buffer))
        (set-buffer buffer))
      (let (func)
        (cond (outline-tree-create-outline-function-interactive
               outline-tree-create-outline-function-interactive)
              ((setq func (outline-tree-create-get-outline-function-auto-mode))
               func)
              (outline-tree-create-outline-function
               outline-tree-create-outline-function)
              (*outline-tree-get-default-create-outline-function*
               (funcall *outline-tree-get-default-create-outline-function* buffer)))))))
(defun outline-tree-get-create-outline-function-by-window (&optional window)
  (interactive)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-get-create-outline-function-by-buffer window))
(defun outline-tree-get-create-outline-function-by-node (&optional node)
  (interactive)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-get-create-outline-function-by-buffer node))

;;----------------------------------------------------------------------------
;; アウトライン作成関数を auto-mode-parameter から取得
;;----------------------------------------------------------------------------
(defvar *outline-tree-find-file-outline-create-function-alist* nil)
(push '("outline-tree" . outline-tree-find-file-outline-create-function)
      ed::*auto-mode-parameter-alist*)
(defun outline-tree-find-file-outline-create-function (string)
  (let ((package (find-package "outline-tree2"))
        (function-list (mapcar #'car *outline-tree-create-outline-function-alist*))
        function-symbol function-alist)
    (when (or (and (setq function-symbol (find-symbol string package))
                   (find function-symbol function-list))
              (and (setq function-symbol (find-symbol (concat "outline-tree-create-outline-" string) package))
                   (find function-symbol function-list))
              (and (setq function-symbol (find-symbol (concat "outline-tree-create-outline-" (string-downcase string)) package))
                   (find function-symbol function-list)))
      (dolist (x *outline-tree-find-file-outline-create-function-alist*)
        (unless (deleted-buffer-p (car x))
          (push x function-alist)))
      (setq *outline-tree-find-file-outline-create-function-alist*
            (nreverse function-alist))
      (push (cons (selected-buffer) function-symbol)
            *outline-tree-find-file-outline-create-function-alist*)
      t)))
(defun outline-tree-create-get-outline-function-auto-mode (&optional buffer)
  (unless buffer
    (setq buffer (selected-buffer)))
  (cdr (find buffer *outline-tree-find-file-outline-create-function-alist*
             :key #'car)))

;;----------------------------------------------------------------------------
;; アウトラインの作成関数情報の取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-create-outline-function-all-info (func-symbol)
  (find func-symbol *outline-tree-create-outline-function-alist* :key #'car))
(defun outline-tree-get-create-outline-function-name (func-symbol)
  (let* ((all-info (outline-tree-get-create-outline-function-all-info func-symbol))
         (func-name (second all-info)) (func-type (third all-info))
         (func-doc (fourth all-info)))
    func-name))
(defun outline-tree-get-create-outline-function-type (func-symbol)
  (let* ((all-info (outline-tree-get-create-outline-function-all-info func-symbol))
         (func-name (second all-info)) (func-type (third all-info))
         (func-doc (fourth all-info)))
    func-type))
(defun outline-tree-get-create-outline-function-doc (func-symbol)
  (let* ((all-info (outline-tree-get-create-outline-function-all-info func-symbol))
         (func-name (second all-info)) (func-type (third all-info))
         (func-doc (fourth all-info)))
    func-doc))

;;----------------------------------------------------------------------------
;; アウトラインの作成
;;----------------------------------------------------------------------------
(defun outline-tree-create-outline (&optional arg)
  (interactive)
  (case (type-of arg)
    (buffer
     (outline-tree-create-outline-by-buffer arg))
    (window
     (outline-tree-create-outline-by-window arg))
    (integer ; node
     (outline-tree-create-outline-by-node arg))
    (t
     (outline-tree-create-outline-by-window))))
(defun outline-tree-create-outline-by-buffer (&optional buffer)
  (interactive)
  (unless (outline-tree-exist-p)
    (outline-tree-create))
  (treeview::with-app (*outline-tree-app-id*)
    (unless buffer
      (setq buffer (outline-tree-get-target-buffer)))
    (unless (listp buffer)
      (setq buffer (list buffer)))
    (unless (outline-tree-exist-p)
      (outline-tree-create))
    (unless (outline-tree-open-p)
      (outline-tree-open))
    (save-excursion
      (let ((buffer-list buffer) buffer-node create-outline-function)
        (dolist (buffer buffer-list)
          (unless (eq buffer (selected-buffer))
            (set-buffer buffer))
          (save-restriction
            (widen)
            (setq buffer-node (outline-tree-get-buffer-node-by-buffer buffer))
            ;; 既存の outline を削除
            (outline-tree-delete-outline buffer)
            ;; outline の作成
            (when (setq create-outline-function
                        (outline-tree-get-create-outline-function-by-buffer buffer))
              (long-operation
                (funcall create-outline-function buffer-node)))
            ;; 作成後のノード展開
            (treeview::treeview-expand-expand
             buffer-node :child t :visible nil
             :depth (if (eq *outline-tree-expand-on-create-outline* :depth)
                        *outline-tree-expand-depth-on-create-outline*
                      *outline-tree-expand-on-create-outline*))
            ;; 最新のアウトラインと認識するよう設定
            (setq outline-tree-outline-modified (buffer-modified-count))))))
    (treeview::treeview-refresh-treeview)
    (refresh-screen)
    (run-hooks '*outline-tree-create-outline-hook*)))
(defun outline-tree-create-outline-by-window (&optional window)
  (interactive)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-create-outline-by-buffer window))
(defun outline-tree-create-outline-by-node (&optional node)
  (interactive)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-create-outline-by-buffer node))

;;----------------------------------------------------------------------------
;; アウトラインの削除
;;----------------------------------------------------------------------------
(defun outline-tree-delete-outline (&optional arg)
  (case (type-of arg)
    (integer ; node
     (outline-tree-delete-outline-by-node arg))
    (window
     (outline-tree-delete-outline-by-window arg))
    (buffer
     (outline-tree-delete-outline-by-buffer arg))))
(defun outline-tree-delete-outline-by-buffer (&optional buffer)
  (interactive)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-exist-outline-p buffer)
      (return-from outline-tree-delete-outline-by-buffer))
    (save-excursion
      (set-buffer buffer)
      (setq outline-tree-outline-modified nil))
    (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)) node)
      (when buffer-node
        (treeview::treeview-expand-collapse buffer-node)
        (treeview::treeview-funcall-recursive-subtree-bottom-up
         buffer-node #'outline-tree-remove-node)
        (outline-tree-update-node buffer-node :group-count 0)))))
(defun outline-tree-delete-outline-by-window (&optional window)
  (interactive)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-delete-outline-by-buffer window))
(defun outline-tree-delete-outline-by-node (&optional node)
  (interactive)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-delete-outline-by-buffer node))

;;----------------------------------------------------------------------------
;; アウトラインの存在確認
;;----------------------------------------------------------------------------
(defvar-local outline-tree-outline-modified nil)
(defun outline-tree-exist-outline-p (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-exist-outline-p-by-buffer arg))
    (window
     (outline-tree-exist-outline-p-by-window arg)
    (integer ; node
     (outline-tree-exist-outline-p-by-node arg)))))
(defun outline-tree-exist-outline-p-by-buffer (&optional buffer)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
      (and (outline-tree-node-valid-p buffer-node)
           (outline-tree-node-has-children-p buffer-node)))))
(defun outline-tree-exist-outline-p-by-window (&optional window)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-exist-outline-p-by-buffer window))
(defun outline-tree-exist-outline-p-by-node (&optional node)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-exist-outline-p-by-buffer node))

;;----------------------------------------------------------------------------
;; アウトラインの最新確認
;;----------------------------------------------------------------------------
(defun outline-tree-latest-outline-p (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-latest-outline-p-by-buffer arg))
    (window
     (outline-tree-latest-outline-p-by-window arg))
    (integer ; node
     (outline-tree-latest-outline-p-by-node arg))
    (t
     (outline-tree-latest-outline-p-by-window))))
(defun outline-tree-latest-outline-p-by-buffer (&optional buffer)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (save-excursion
    (unless (eq buffer (selected-buffer))
      (set-buffer buffer))
    (and (outline-tree-exist-p)
         (eql outline-tree-outline-modified (buffer-modified-count)))))
(defun outline-tree-latest-outline-p-by-window (&optional window)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-latest-outline-p-by-buffer window))
(defun outline-tree-latest-outline-p-by-node (&optional node)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-latest-outline-p-by-buffer node))

;;----------------------------------------------------------------------------
;; ユーザ定義アウトラインメニュー用変数
;;----------------------------------------------------------------------------
(defvar *outline-tree-context-menu-node* nil
  "ノード対応メニュー作成時に、対象ノードを保持する。
ユーザ定義メニューである、*outline-tree-buffer-menu*,
*outline-tree-folder-menu* 内で用いることを想定")
(defvar *outline-tree-buffer-menu* nil
  "バッファノードに対するユーザ定義メニュー")
(defvar *outline-tree-folder-menu* nil
  "フォルダノードに対するユーザ定義メニュー")

;;----------------------------------------------------------------------------
;; アウトラインツリー作成時補助関数
;;----------------------------------------------------------------------------
(defun outline-tree-initialize-expand-node ()
  "ノードの開閉状態を初期状態にする
初期状態：フォルダノードを展開
          非表示バッファカテゴリノード以外のカテゴリノードを展開
outline-tree-create 内で用いられる補助関数"
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-exist-p)
      (return-from outline-tree-initialize-expand-node))
    (let ((invisible-node
           (outline-tree-revdata-get-category-node
            *outline-tree-invisible-buffer-category-node-name* winapi:TVI_ROOT)))
      (treeview::treeview-map-item-tree
       (treeview::treeview-get-item-tree 0)
       #'(lambda (node)
           (case (outline-tree-data-get-type node)
             (:folder-node
              (treeview::treeview-expand-expand node))
             (:category-node
              (unless (find invisible-node
                            (treeview::treeview-get-ancestor-item-list node)
                            :test #'treeview::treeview-hitem-equal)
                (treeview::treeview-expand-expand node)))))))))

;;----------------------------------------------------------------------------
;; 対象ウィンドウ
;;----------------------------------------------------------------------------
(defvar *outline-tree-target-window* nil
  "アウトライン対象ウィンドウ")
(defun outline-tree-define-target-window-popup-menu ()
  "アウトライン対象ウィンドウ選択ポップアップメニュー生成"
  (let ((menu (create-popup-menu 'outline-tree-define-target-window))
        (window-list (mapcar 'car (caddr (current-window-configuration)))))
    (add-menu-item menu nil
                   "アクティブウィンドウ"
                   #'(lambda () (interactive)
                       (setq *outline-tree-target-window* nil))
                   #'(lambda ()
                       (and (eq *outline-tree-target-window* nil) :check)))
    (add-menu-separator menu)
    (dolist (window window-list)
      (let ((window window))
        (add-menu-item menu window
                       (format nil "~A~S :: <~A>"
                               (if (eq window (selected-window)) "* " "  ")
                               window (buffer-name (window-buffer window)))
                       #'(lambda () (interactive)
                           (setq *outline-tree-target-window* window))
                       #'(lambda ()
                           (and (eq *outline-tree-target-window* window) :check)))))
    menu))

;;----------------------------------------------------------------------------
;; 対象ウィンドウ/バッファの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-target-window ()
  "処理対象 window の取得と *outline-tree-target-window* の更新"
  (let ((window-list (mapcar 'car (caddr (current-window-configuration))))
        window)
    (if (and (windowp *outline-tree-target-window*)
             (not (minibuffer-window-p *outline-tree-target-window*))
             (member *outline-tree-target-window* window-list))
        (setq window *outline-tree-target-window*)
      (progn
        (setq *outline-tree-target-window* nil)
        (setq window (selected-window))))
    window))

(defun outline-tree-get-target-buffer ()
  "処理対象 buffer の取得"
  (window-buffer (outline-tree-get-target-window)))

;;----------------------------------------------------------------------------
;; バッファの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-buffer (arg)
  "引数の型に応じ、各種方法で buffer を取得し返す"
  (case (type-of arg)
    (integer ; node
     (outline-tree-get-buffer-by-node arg))
    (window
     (window-buffer arg))
    (buffer
     arg)))
(defun outline-tree-get-buffer-by-node (&optional node)
  "node が属する buffer を返す"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (setq node (outline-tree-get-buffer-node-by-node node))
    (when node
      (outline-tree-data-get-buffer node))))

;;----------------------------------------------------------------------------
;; バッファノードの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-buffer-node (arg)
  "引数の型に応じ、各種方法で buffer-node を取得し返す"
  (case (type-of arg)
    (window
     (outline-tree-get-buffer-node-by-window arg))
    (buffer
     (outline-tree-get-buffer-node-by-buffer arg))
    (integer ; node
     (outline-tree-get-buffer-node-by-node arg))))
(defun outline-tree-get-buffer-node-by-node (&optional node)
  "node が属する buffer-node を返す"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (loop
      (unless (outline-tree-node-valid-p node)
        (return-from outline-tree-get-buffer-node-by-node nil))
      (if (outline-tree-buffer-node-p node)
          (return-from outline-tree-get-buffer-node-by-node node)
        (setq node (treeview::treeview-get-parent-item node))))))
(defun outline-tree-get-buffer-node-by-buffer (&optional buffer)
  "buffer に対応する buffer-node を返す"
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (outline-tree-revdata-get-buffer-node buffer))
(defun outline-tree-get-buffer-node-by-window (&optional window)
  "window に対応する buffer-node を返す"
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-get-buffer-node-by-buffer window))

;;----------------------------------------------------------------------------
;; フォルダノードの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-folder-node (arg)
  "引数の型に応じ、各種方法で folder-node を取得し返す"
  (case (type-of arg)
    ((string simple-string) ; folder-name
     (outline-tree-get-folder-node-by-folder-name arg))
    (integer ; node
     (outline-tree-get-folder-node-by-node arg))
    (buffer
     (outline-tree-get-folder-node-by-buffer arg))
    (window
     (outline-tree-get-folder-node-by-window arg))))
(defun outline-tree-get-folder-node-by-folder-name (folder-name)
  "folder-name に対応する folder-node を返す"
  (outline-tree-revdata-get-folder-node folder-name))
(defun outline-tree-get-folder-node-by-node (&optional node)
  "node が属する folder-node を返す"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (loop
      (unless (outline-tree-node-valid-p node)
        (return-from outline-tree-get-folder-node-by-node nil))
      (if (outline-tree-folder-node-p node)
          (return-from outline-tree-get-folder-node-by-node node)
        (setq node (treeview::treeview-get-parent-item node))))))
(defun outline-tree-get-folder-node-by-buffer (&optional buffer)
  "buffer に対応する folder-node を返す
buffer の (default-directory) からの判定ではなく、buffer に対応する
buffer-node と TreeView 上の階層構造から判定する。"
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
    (when buffer-node
      (outline-tree-get-folder-node-by-node buffer-node))))
(defun outline-tree-get-folder-node-by-window (&optional window)
  "window に対応する folder-node を返す"
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-get-folder-node-by-buffer window))

;;----------------------------------------------------------------------------
;; フォルダの取得 ((default-directory) からでなく TreeView から取得)
;;----------------------------------------------------------------------------
(defun outline-tree-get-folder (arg)
  "引数の型に応じ、各種方法で folder を取得し返す"
  (case (type-of arg)
    (integer ; node
     (outline-tree-get-folder-node-by-node arg))
    (buffer
     (outline-tree-get-folder-node-by-buffer arg))
    (window
     (outline-tree-get-folder-node-by-window arg))))
(defun outline-tree-get-folder-by-node (&optional node)
  "node に対応する folder を返す"
  (let ((folder-node (outline-tree-get-folder-node-by-node node)))
    (when folder-node
      (outline-tree-data-get-folder-name folder-node))))
(defun outline-tree-get-folder-by-buffer (&optional buffer)
  "buffer に対応する folder を返す"
  (let ((folder-node (outline-tree-get-folder-node-by-buffer buffer)))
    (when folder-node
      (outline-tree-data-get-folder-name folder-node))))
(defun outline-tree-get-folder-by-window (&optional window)
  "window に対応する folder を返す"
  (let ((folder-node (outline-tree-get-folder-node-by-window window)))
    (when folder-node
      (outline-tree-data-get-folder-name folder-node))))

;;----------------------------------------------------------------------------
;; カテゴリノードの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-category-node (arg)
  "引数の型に応じ、各種方法で category-node を取得し返す"
  (case (type-of arg)
    (integer ; node
     (outline-tree-get-category-node-by-node arg))
    (buffer
     (outline-tree-get-category-node-by-buffer arg))
    (window
     (outline-tree-get-category-node-by-window arg))))
(defun outline-tree-get-category-node-by-node (&optional node)
  "node が属する category-node を返す"
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (loop
      (unless (outline-tree-node-valid-p node)
        (return-from outline-tree-get-category-node-by-node nil))
      (if (outline-tree-category-node-p node)
          (return-from outline-tree-get-category-node-by-node node)
        (setq node (treeview::treeview-get-parent-item node))))))
(defun outline-tree-get-category-node-by-buffer (&optional buffer)
  "buffer が属する category-node を返す"
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)))
    (when buffer-node
      (outline-tree-get-category-node-by-node buffer-node))))
(defun outline-tree-get-category-node-by-window (&optional window)
  "window が属する category-node を返す"
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-get-category-node-by-buffer window))

;;----------------------------------------------------------------------------
;; ノードの取得
;;----------------------------------------------------------------------------
(defun outline-tree-get-node (arg)
  "引数の型に応じ、各種方法で node を取得し返す"
  (case (type-of arg)
    (window
     (outline-tree-get-node-by-window arg))
    (buffer
     (outline-tree-get-node-by-buffer arg))))

;; 1.  現在のノードをチェック
;; 2.1 範囲に含まれる場合 (自ノードがバッファノードの場合を含む)
;;       -> 子ノード以下を調べ、該当ノードがあればそれを、
;;          なければ自ノードを返す。
;; 2.2 範囲に含まれない場合
;;       -> 親ノード以下(自ノード以外)をチェック
;; 2.3 範囲が不明の場合
;;       -> 子ノード以下を調べ、該当ノードがあればそれを、
;;          なければ親ノード以下(自ノード以外)をチェック
;;
(defun outline-tree-get-node-by-buffer (&optional buffer)
  "buffer と point に対応する node を返す"
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (let ((visible-buffer-p (not (string-match "^ " (buffer-name buffer))))
          (namestring (get-buffer-file-name buffer))
          (buffer-node (outline-tree-get-buffer-node-by-buffer buffer))
          (selected-node (outline-tree-get-selected-node))
          point)
      (unless (and buffer-node (or namestring visible-buffer-p))
        (return-from outline-tree-get-node-by-buffer nil))
      (labels (;; checked-node を除き、mover-func で取得可能な全ての node 以下をチェック
               (outline-tree-get-node-by-buffer-sub-tree-1 (node checked-node mover-func depth-from-buffer-node)
                 (let (whole-range child-node)
                   (while (outline-tree-node-valid-p node)
                     (when (treeview::treeview-hitem-not-equal node checked-node)
                       (case (outline-tree-data-get-type node)
                         ((:range-node)
                          (setq whole-range (outline-tree-data-get-whole-range node))
                          (when (eq (outline-tree-get-range-relation whole-range point) :inside)
                            (return-from outline-tree-get-node-by-buffer-sub-tree-1
                              (or (outline-tree-get-node-by-buffer-sub-tree
                                   node nil nil (1+ depth-from-buffer-node))
                                  node))))
                         (t
                          (when (setq child-node (outline-tree-get-node-by-buffer-sub-tree
                                                  node nil nil (1+ depth-from-buffer-node)))
                            (return-from outline-tree-get-node-by-buffer-sub-tree-1 child-node)))))
                     (setq node (funcall mover-func node)))))
               ;; checked-node 以下の階層を除外した parent-node より下の階層で該当ノードを取得
               (outline-tree-get-node-by-buffer-sub-tree (parent-node checked-node direction depth-from-buffer-node)
                 (unless (outline-tree-node-valid-p parent-node)
                   (return-from outline-tree-get-node-by-buffer-sub-tree nil))
                 (let (node)
                   (if checked-node
                       ;; checked-node が指定されている場合、parent-node は expand 状態
                       (cond
                        ((eq direction :less)
                         (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                           (treeview::treeview-get-prev-sibling-item checked-node)
                                           nil
                                           #'treeview::treeview-get-prev-sibling-item
                                           depth-from-buffer-node))
                           (return-from outline-tree-get-node-by-buffer-sub-tree node))
                         (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                           (treeview::treeview-get-next-sibling-item checked-node)
                                           nil
                                           #'treeview::treeview-get-next-sibling-item
                                           depth-from-buffer-node))
                           (return-from outline-tree-get-node-by-buffer-sub-tree node)))
                        ((eq direction :greater)
                         (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                           (treeview::treeview-get-next-sibling-item checked-node)
                                           nil
                                           #'treeview::treeview-get-next-sibling-item
                                           depth-from-buffer-node))
                           (return-from outline-tree-get-node-by-buffer-sub-tree node))
                         (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                           (treeview::treeview-get-prev-sibling-item checked-node)
                                           nil
                                           #'treeview::treeview-get-prev-sibling-item
                                           depth-from-buffer-node))
                           (return-from outline-tree-get-node-by-buffer-sub-tree node)))
                        (t
                         (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                           (treeview::treeview-get-child-item parent-node)
                                           checked-node
                                           #'treeview::treeview-get-next-sibling-item
                                           depth-from-buffer-node))
                           (return-from outline-tree-get-node-by-buffer-sub-tree node))))
                     ;; checked-node が指定されていない場合、parent-node の expand/collapse 状態は不明。
                     ;; collapse 状態の場合、確認し制限内ならば expand
                     (when (and (outline-tree-node-has-children-p parent-node)
                                (or (treeview::treeview-expand-p parent-node)
                                    (cond ((eq *outline-tree-expand-on-chase-cursor* :depth)
                                           (<= depth-from-buffer-node *outline-tree-expand-depth-on-chase-cursor*))
                                          (*outline-tree-expand-on-chase-cursor* t))))
                       (when (setq node (outline-tree-get-node-by-buffer-sub-tree-1
                                         (treeview::treeview-get-child-item parent-node)
                                         nil
                                         #'treeview::treeview-get-next-sibling-item
                                         depth-from-buffer-node))
                         (return-from outline-tree-get-node-by-buffer-sub-tree node))))
                   nil))
               ;; 指定ノード以下で見つからなかった場合、親ノード以下で探す
               (outline-tree-get-node-by-buffer-1 (node checked-child-node direction depth-from-buffer-node)
                 (let (whole-range parent-node)
                   (setq parent-node (treeview::treeview-get-parent-item node))
                   (cond
                    ;; 範囲不明の場合 (子ノード以下で探し、なければ親ノード以下で探す)
                    ((not (member (outline-tree-data-get-type node) '(:buffer-node :range-node)))
                     (or (outline-tree-get-node-by-buffer-sub-tree node checked-child-node direction
                                                                   (1+ depth-from-buffer-node))
                         (outline-tree-get-node-by-buffer-1 parent-node node nil (1- depth-from-buffer-node))))
                    ;; 範囲に含まれない場合 (親ノード以下で探す)
                    ((and (member (outline-tree-data-get-type node) '(:range-node))
                          (not (eq (outline-tree-get-range-relation
                                    (setq whole-range (outline-tree-data-get-whole-range node))
                                    point) :inside)))
                     (cond
                      ((null whole-range)
                       (outline-tree-get-node-by-buffer-1 parent-node node nil (1- depth-from-buffer-node)))
                      ((< point (outline-tree-get-range-from whole-range))
                       (outline-tree-get-node-by-buffer-1 parent-node node :less (1- depth-from-buffer-node)))
                      (t
                       (outline-tree-get-node-by-buffer-1 parent-node node :greater (1- depth-from-buffer-node)))))
                    ;; 範囲に含まれる場合 (子ノード以下で探し、なければ自ノードを返す)
                    (t
                     (or (outline-tree-get-node-by-buffer-sub-tree node checked-child-node direction
                                                                   (1+ depth-from-buffer-node))
                         node))))))
        (save-excursion
          (set-buffer buffer)
          (setq point (point))
          (if (treeview::treeview-hitem-equal buffer-node (outline-tree-get-buffer-node-by-node selected-node))
              (outline-tree-get-node-by-buffer-1 selected-node nil nil
                                                 (- (treeview::treeview-get-depth selected-node)
                                                    (treeview::treeview-get-depth buffer-node)))
            (outline-tree-get-node-by-buffer-1 buffer-node nil nil 0)))))))

(defun outline-tree-get-node-by-window (&optional window)
  "window の buffer と point に対応する node を返す"
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-get-node-by-buffer window))

;;----------------------------------------------------------------------------
;; ノードの選択
;;----------------------------------------------------------------------------
(defun outline-tree-select-node (&optional arg)
  "引数の型に応じ、各種方法で node を取得し、選択する"
  (interactive)
  (case (type-of arg)
    (integer ; node
     (outline-tree-select-node-by-node arg))
    (window
     (outline-tree-select-node-by-window arg))
    (buffer
     (outline-tree-select-node-by-buffer arg))
    (t
     (outline-tree-select-node-by-window))))
(defun outline-tree-select-node-by-node (&optional node select-only)
  "渡された node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-item node select-only)))
(defun outline-tree-select-node-by-buffer (&optional buffer (select-only t))
  "buffer に対応する node を選択する"
  (interactive)
  (let ((node (outline-tree-get-node-by-buffer buffer)))
    (when node
      (outline-tree-select-node-by-node node select-only))))
(defun outline-tree-select-node-by-window (&optional window (select-only t))
  "window に対応する node を選択する"
  (interactive)
  (let ((node (outline-tree-get-node-by-window window)))
    (when node
      (outline-tree-select-node-by-node node select-only))))

(defun outline-tree-select-up-key-node (&optional node select-only)
  "node を基準とし、Up キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-up-key-item node select-only)))
(defun outline-tree-select-down-key-node (&optional node select-only)
  "node を基準とし、Down キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-down-key-item node select-only)))
(defun outline-tree-select-left-key-node (&optional node select-only)
  "node を基準とし、Left キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-left-key-item node select-only)))
(defun outline-tree-select-right-key-node (&optional node select-only)
  "node を基準とし、Right キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-right-key-item node select-only)))
(defun outline-tree-select-pageup-key-node (&optional node select-only)
  "node を基準とし、PageUp キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-pageup-key-item node select-only)))
(defun outline-tree-select-pagedown-key-node (&optional node select-only)
  "node を基準とし、PageDown キーを押した際の移動先となる node を選択する"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-pagedown-key-item node select-only)))
(defun outline-tree-select-ancestor-node (&optional node select-only)
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-ancestor-item node select-only)))
(defun outline-tree-select-eldest-descendants-node (&optional node select-only)
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-eldest-descendants-item node select-only)))
(defun outline-tree-select-youngest-descendants-node (&optional node select-only)
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-youngest-descendants-item node select-only)))
(defun outline-tree-select-node-delay ()
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-select-act-item-delay)))

;;----------------------------------------------------------------------------
;; バッファが heading-node を所持しているかの取得
;;----------------------------------------------------------------------------
(defun outline-tree-has-heading-node-p (&optional arg)
  (case (type-of arg)
    (buffer
     (outline-tree-has-heading-node-p-by-buffer arg))
    (window
     (outline-tree-has-heading-node-p-by-window arg))
    (integer ; node
     (outline-tree-has-heading-node-p-by-node arg)
    (t
     (outline-tree-has-heading-node-p-by-window)))))
(defun outline-tree-has-heading-node-p-by-buffer (&optional buffer)
  (unless buffer
    (setq buffer (outline-tree-get-target-buffer)))
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-exist-outline-p buffer)
      (return-from outline-tree-has-heading-node-p-by-buffer nil))
    (let ((buffer-node (outline-tree-get-buffer-node-by-buffer buffer)) node)
      (when buffer-node
        (treeview::treeview-funcall-recursive-subtree-top-down
         buffer-node
         #'(lambda (node)
             (when (outline-tree-heading-node-p node)
               (return-from outline-tree-has-heading-node-p-by-buffer t))))
        nil))))
(defun outline-tree-has-heading-node-p-by-window (&optional window)
  (outline-tree-funcall-buffer-by-window
   #'outline-tree-has-heading-node-p-by-buffer window))
(defun outline-tree-has-heading-node-p-by-node (&optional node)
  (outline-tree-funcall-buffer-by-node
   #'outline-tree-has-heading-node-p-by-buffer node))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 各種機能
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; カーソル追従 (ノードの選択 (hook))
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-chase-cursor* t)
(defun outline-tree-chase-cursor-p ()
  *outline-tree-chase-cursor*)
(defun outline-tree-toggle-chase-cursor (&optional (arg nil sv))
  (interactive "p")
  (if (null sv)
      (setq *outline-tree-chase-cursor* (not *outline-tree-chase-cursor*))
    (setq *outline-tree-chase-cursor* arg)))

(defvar *outline-tree-except-commands-for-select-node-by-window* nil)
(defvar *outline-tree-apply-commands-for-select-node-by-window*
  '(outline-tree-delete-region-by-range-node
    outline-tree-swap-region-by-next-range-node
    outline-tree-swap-region-by-prev-range-node))
(defun outline-tree-select-node-by-window-for-hook ()
  "対象ウィンドウに関連付いたバッファのポイントに対応するノードを選択する。
アウトラインが最新で、常にハイライトの設定がなされていれば、範囲の
ハイライトも行う。
大抵のコマンドの後では hook 動作を行うが、基本的に treeview、outline-tree を
明示的に操作しているコマンドの場合は安全のため、動作を行わない。"
  (unless *outline-tree-chase-cursor*
    (return-from outline-tree-select-node-by-window-for-hook nil))
  (treeview::with-app (*outline-tree-app-id*)
    (when (and
           ;; outline-tree が開いている
           (outline-tree-open-p)
           ;; 矩形選択時の表示がおかしくなるバグ？の回避
           (not (get-selection-type))
           (or
            ;; コマンドがシンボルではない
            (not (symbolp *this-command*))
            ;; シンボルだったとしても、treeview, outline-tree2 パッケージのシンボルではない
            (not (find (package-name (symbol-package *this-command*))
                       '("treeview" "outline-tree2") :test #'string=))
            ;; treeview, outline-tree2 パッケージのシンボルでも、明示的に許可されている
            (find *this-command* *outline-tree-apply-commands-for-select-node-by-window*))
           ;; 明示的に除外されているコマンドではない
           (not (find *this-command*
                      *outline-tree-except-commands-for-select-node-by-window*)))
      (if (not (outline-tree-latest-outline-p-by-window))
          ;; アウトラインが最新でない場合
          (let ((buffer-node-by-window (outline-tree-get-buffer-node-by-window))
                (buffer-node-by-node (outline-tree-get-buffer-node-by-node
                                      (outline-tree-get-selected-node)))
                (namestring
                 (get-buffer-file-name (outline-tree-get-target-buffer)))
                (visible-buffer-p
                 (not (string-match "^ " (buffer-name (outline-tree-get-target-buffer))))))
            ;; 現在の選択しているノードの上位のバッファノードが、ウィンドウに
            ;; 対応するバッファノードと異なる場合、ウィンドウに対応するバッファ
            ;; ノードを選択
            (when (and (or namestring visible-buffer-p)
                       (not (treeview::treeview-hitem-equal buffer-node-by-window buffer-node-by-node)))
              (outline-tree-select-node-by-node buffer-node-by-window t)))
        ;; アウトラインが最新の場合
        (progn
          ;; ウィンドウの point に対応するノードを選択
          (outline-tree-select-node-by-window)
          ;; ノード範囲を常にハイライトの場合は、対応範囲をハイライト
          (when (and (outline-tree-text-highlight-always-p)
                     (outline-tree-text-highlight-p))
            (let ((node (outline-tree-get-selected-node)))
              (when (outline-tree-range-node-p node)
                (outline-tree-set-text-highlight (outline-tree-data-get-whole-range node))))))))))

;;----------------------------------------------------------------------------
;; ノード追従
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-chase-node* t)
(defun outline-tree-chase-node-p ()
  *outline-tree-chase-node*)
(defun outline-tree-toggle-chase-node (&optional (arg nil sv))
  (interactive "p")
  (if (null sv)
      (setq *outline-tree-chase-node* (not *outline-tree-chase-node*))
    (setq *outline-tree-chase-node* arg)))

;;----------------------------------------------------------------------------
;; ノード対応テキストハイライト
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-text-highlight* nil)
(defvar *outline-tree-text-highlight-tag* 'outline-tree-text-highlight)
(defun outline-tree-text-highlight-p ()
  *outline-tree-text-highlight*)
(defun outline-tree-toggle-text-highlight (&optional (arg nil sv))
  (interactive "p")
  (prog1
      (if (null sv)
          (setq *outline-tree-text-highlight* (not *outline-tree-text-highlight*))
        (setq *outline-tree-text-highlight* arg))
    (unless *outline-tree-text-highlight*
      (outline-tree-delete-text-highlight))))
(defun outline-tree-delete-text-highlight ()
  (when *outline-tree-text-highlight*
    (delete-text-attributes *outline-tree-text-highlight-tag*)))
(defun outline-tree-set-text-highlight (range)
  (outline-tree-delete-text-highlight)
  (let ((text-attributes (list-text-attributes (outline-tree-get-range-from range)
                                               (outline-tree-get-range-to range))))
    (apply #'set-text-attribute
           (append (list (outline-tree-get-range-from range)
                         (outline-tree-get-range-to range)
                         *outline-tree-text-highlight-tag*)
                   *outline-tree-text-highlight-attribute*))
    (when text-attributes
;      (sit-for 0.05)
      (dolist (text-attribute text-attributes)
        (apply #'set-text-attribute text-attribute)))))


;;----------------------------------------------------------------------------
;; ノード対応テキストハイライトを常に
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-text-highlight-always* nil)
(defun outline-tree-text-highlight-always-p ()
  *outline-tree-text-highlight-always*)
(defun outline-tree-toggle-text-highlight-always (&optional (arg nil sv))
  (interactive "p")
  (if (null sv)
      (setq *outline-tree-text-highlight-always* (not *outline-tree-text-highlight-always*))
    (setq *outline-tree-text-highlight-always* arg)))

;;----------------------------------------------------------------------------
;; インクリメンタルサーチ
;;----------------------------------------------------------------------------
(defun outline-tree-isearch-forward (&optional reverse)
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (treeview::treeview-isearch-forward reverse)))
(defun outline-tree-isearch-backward ()
  (interactive)
  (outline-tree-isearch-forward t))

;;----------------------------------------------------------------------------
;; アウトラインツリー表示順でのバッファリスト操作
;;----------------------------------------------------------------------------
(defun outline-tree-buffer-list (&optional top-node)
  (treeview::with-app (*outline-tree-app-id*)
    (unless top-node
      (setq top-node winapi:TVI_ROOT))
    (let ((stop-node (if (and top-node (plusp top-node))
                       (treeview::treeview-get-next-sibling-item top-node)
                     nil))
          (node (treeview::treeview-get-down-item top-node))
          buffer-list)
      (while (and (outline-tree-node-valid-p node)
                  (or (not (outline-tree-node-valid-p stop-node))
                      (treeview::treeview-hitem-lessp node stop-node)))
        (when (outline-tree-buffer-node-p node)
          (push (outline-tree-data-get-buffer node) buffer-list))
        (setq node (treeview::treeview-get-down-item node)))
      (nreverse buffer-list))))

(defun outline-tree-get-next-buffer (&optional buffer reverse)
  (unless buffer
    (setq buffer (selected-buffer)))
  (let ((buffer-list (outline-tree-buffer-list)))
    (if reverse
        (setq buffer-list (reverse buffer-list)))
    (setq buffer-list
          (safe-cdr (member buffer (append buffer-list buffer-list))))
    (dolist (buffer buffer-list)
      (unless (string-match "^ " (buffer-name buffer))
        (return-from outline-tree-get-next-buffer buffer))))
  nil)

(defun outline-tree-next-buffer ()
  (interactive)
  (let* ((cur (selected-buffer))
         (next (outline-tree-get-next-buffer cur nil)))
    (if (and (bufferp next) (not (eq cur next)))
        (set-buffer next)
      nil)))

(defun outline-tree-previous-buffer ()
  (interactive)
  (let* ((cur (selected-buffer))
         (prev (outline-tree-get-next-buffer cur t)))
    (if (and (bufferp prev) (not (eq cur prev)))
        (set-buffer prev)
      nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; プロパティーシート
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *outline-tree-option-prop-page* nil)
(defvar *outline-tree-option-prop-page-no* nil)

(defun outline-tree-add-option-prop-page (ident tmpl init handlers result)
  (setq *outline-tree-option-prop-page* (delete ident *outline-tree-option-prop-page* :test #'eq
                                           :key #'(lambda (x) (if (consp x) (car x) nil))))
  (setf (get ident 'outline-tree-prop-result) result)
  (push (list ident tmpl init handlers) *outline-tree-option-prop-page*))

(defun outline-tree-option-property-sheet ()
  (interactive)
  (let (sheet result)
    (dolist (page *outline-tree-option-prop-page*)
      (cond ((symbolp page)
             (push page sheet))
            (t
             (push (list (car page)
                         (cadr page)
                         (let ((init (caddr page)))
                           (when init
                             (funcall init)))
                         (cadddr page))
                   sheet))))
    (multiple-value-setq (result *outline-tree-option-prop-page-no*)
      (property-sheet sheet
                      (format nil "outline-tree (~A) 設定" *outline-tree-version*)
                      *outline-tree-option-prop-page-no*))
    (dolist (r result)
      (let ((f (get (car r) 'outline-tree-prop-result)))
        (when f
          (funcall f (cdr r)))))))

;;----------------------------------------------------------------------------
;; 基本プロパティーシート
;;----------------------------------------------------------------------------
(outline-tree-add-option-prop-page
 'basic
 (let (dialog-base-side dialog-size
       dialog-base-height dialog-height
       controls)
   ;;
   (setq dialog-base-side 4)
   (setq dialog-base-height 4)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "動作設定"                              #x50020007
           ,dialog-base-side ,dialog-height 112 74) controls)
   (incf dialog-height 10)
   (push `(:button chase-cursor "カーソル追従(&C)"             #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 100 12) controls)
   (incf dialog-height 12)
   (push `(:button chase-node "ノード追従(&N)"                 #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 100 12) controls)
   (incf dialog-height 12)
   (push `(:button text-highlight "ノード範囲ハイライト(&H)"   #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 100 12) controls)
   (incf dialog-height 12)
   (push `(:button text-highlight-always "ノード範囲を常にハイライト(&A)" #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 100 12) controls)
   (incf dialog-height 12)
   (push `(:button swap-discontinuous-range-node "不連続ノード入替え可(&D)" #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 100 12) controls)
   ;;
   (setq dialog-base-side 120)
   (setq dialog-base-height 4)
   (setq dialog-height dialog-base-height)
;   (push `(:button nil "アウトラインツリー起動"                #x50020007
;           ,dialog-base-side ,dialog-height 112 74) controls)
   (push `(:button nil "アウトラインツリー起動"                #x50020007
           ,dialog-base-side ,dialog-height 112 40) controls)
   (incf dialog-height 10)
   (push `(:button one-shot-create "xyzzy 起動時はアウトライン\nツリーを起動しない(&O)" #x50012003
           ,(+ dialog-base-side 4) ,dialog-height 100 24) controls)
   ;;
   (setq dialog-base-side 120)
   (setq dialog-height (+ dialog-base-height 44))
   (push `(:button nil "ノード表示"                            #x50020007
           ,dialog-base-side ,dialog-height 112 30) controls)
   (incf dialog-height 10)
   (push `(:static nil "フォルダ名表示幅(&W):"                 #x50020000
           ,(+ dialog-base-side 4) ,(+ dialog-height 3) 64 8) controls)
   (push `(:edit folder-name-length-num nil                    #x50812086
           ,(+ dialog-base-side 72) ,dialog-height 30 12) controls)
   (push `(:spin folder-name-length-spin nil                   #x500000b6
           ,(+ dialog-base-side 72) ,dialog-height 9 12) controls)

   ;;
   (setq dialog-base-side 4)
   (incf dialog-base-height 78)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "エディタ表示行"                        #x50020007
           ,dialog-base-side ,dialog-height 72 64) controls)
   (incf dialog-height 10)
   (push `(:button recenter-nil  "制御しない(&1)"              #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button recenter-t    "センター(&2)"                #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button recenter-line "マージン行指定(&3)"          #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 64 12) controls)
   (incf dialog-height 12)
   (push `(:edit recenter-line-num nil                         #x50812086
           ,(+ dialog-base-side 24) ,dialog-height 40 12) controls)
   (push `(:spin recenter-spin nil                             #x500000b6
           ,(+ dialog-base-side 24) ,dialog-height 9 12) controls)
   ;;
   (setq dialog-base-side 80)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "作成時展開階層"                        #x50020007
           ,dialog-base-side ,dialog-height 72 64) controls)
   (incf dialog-height 10)
   (push `(:button expand-on-create-nil "展開しない(&4)"       #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button expand-on-create-t   "全展開(&5)"           #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button expand-on-create-depth "階層指定(&6)"       #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 58 12) controls)
   (incf dialog-height 12)
   (push `(:edit expand-on-create-depth-num nil                #x50812086
           ,(+ dialog-base-side 24) ,dialog-height 40 12) controls)
   (push `(:spin expand-on-create-depth-spin nil               #x500000b6
           ,(+ dialog-base-side 24) ,dialog-height 9 12) controls)
   ;;
   (setq dialog-base-side 156)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "追従時展開階層"                        #x50020007
           ,dialog-base-side ,dialog-height 72 64) controls)
   (incf dialog-height 10)
   (push `(:button expand-on-chase-nil "展開しない(&7)"        #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button expand-on-chase-t   "全展開(&8)"            #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 50 12) controls)
   (incf dialog-height 12)
   (push `(:button expand-on-chase-depth "階層指定(&9)"        #x50000009
           ,(+ dialog-base-side 4) ,dialog-height 58 12) controls)
   (incf dialog-height 12)
   (push `(:edit expand-on-chase-depth-num nil                 #x50812086
           ,(+ dialog-base-side 24) ,dialog-height 40 12) controls)
   (push `(:spin expand-on-chase-depth-spin nil                #x500000b6
           ,(+ dialog-base-side 24) ,dialog-height 9 12) controls)
   ;;
   (setq dialog-base-side 4)
   (incf dialog-base-height 68)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "アウトライン対象ウィンドウ(&U)"        #x50020007
           ,dialog-base-side ,dialog-height 180 28) controls)
   (incf dialog-height 10)
   (push `(:combobox target-window nil                         #x50210843
           ,(+ dialog-base-side 4) ,dialog-height 170 96) controls)
   ;;
   (setq dialog-base-side 4)
   (incf dialog-base-height 32)
   (setq dialog-height dialog-base-height)
   (push `(:button nil "メニュー"                              #x50020007
           ,dialog-base-side ,dialog-height 230 28) controls)
   (incf dialog-height 10)
   (push `(:button menu "メニューを追加(&M)"                   #x50010003
           ,(+ dialog-base-side 4) ,dialog-height 80 14) controls)
   (push `(:static nil "メニュー文字列(&T):"                   #x50020000
           ,(+ dialog-base-side 90) ,(+ dialog-height 3) 56 8) controls)
   (push `(:edit menu-name nil                                 #x50810480
           ,(+ dialog-base-side 146) ,dialog-height 74 14) controls)

   (setq controls (nreverse controls))
   `(dialog 0 0 260 220
     (:caption "基本設定")
     (:control
      ,@controls)))
 #'(lambda ()
     (let (controls-initializers)
       (push `(chase-cursor . ,*outline-tree-chase-cursor*) controls-initializers)
       (push `(chase-node . ,*outline-tree-chase-node*) controls-initializers)
       (push `(text-highlight . ,*outline-tree-text-highlight*) controls-initializers)
       (push `(text-highlight-always . ,*outline-tree-text-highlight-always*) controls-initializers)
       (push `(swap-discontinuous-range-node . ,*outline-tree-available-swap-discontinuous-range-node*)
             controls-initializers)
       ;;
       (when (eq *outline-tree-use* :one-shot)
         (push '(one-shot-create . t) controls-initializers))
       ;;
       (cond
        ((and (integerp *outline-tree-abbreviate-display-folder-name-length*)
              (plusp *outline-tree-abbreviate-display-folder-name-length*))
         (push `(folder-name-length-num
                 . ,(format nil "~D" *outline-tree-abbreviate-display-folder-name-length*))
               controls-initializers))
        (t
         (push `(folder-name-length-num . "0") controls-initializers)))
       ;;
       (push (case *outline-tree-editor-recenter*
               ((nil) '(recenter-nil . t))
               (:line '(recenter-line . t))
               (t     '(recenter-t . t)))
             controls-initializers)
       (let ((recenter *outline-tree-editor-recenter-line*))
         (unless (and (integerp recenter) (<= 0 recenter))
           (setq recenter 0))
         (push `(recenter-line-num . ,(format nil "~D" recenter)) controls-initializers))
       ;;
       (push (case *outline-tree-expand-on-create-outline*
               ((nil)  '(expand-on-create-nil . t))
               (:depth '(expand-on-create-depth . t))
               (t      '(expand-on-create-t . t)))
             controls-initializers)
       (let ((depth *outline-tree-expand-depth-on-create-outline*))
         (unless (and (integerp depth) (<= 0 depth))
           (setq depth 0))
         (push `(expand-on-create-depth-num . ,(format nil "~D" depth)) controls-initializers))
       ;;
       (push (case *outline-tree-expand-on-chase-cursor*
               ((nil)  '(expand-on-chase-nil . t))
               (:depth '(expand-on-chase-depth . t))
               (t      '(expand-on-chase-t . t)))
             controls-initializers)
       (let ((depth *outline-tree-expand-depth-on-chase-cursor*))
         (unless (and (integerp depth) (<= 0 depth))
           (setq depth 0))
         (push `(expand-on-chase-depth-num . ,(format nil "~D" depth)) controls-initializers))
       ;;
       (let ((window-list (mapcar 'car (caddr (current-window-configuration))))
             window-name-list window-position)
         (setq window-name-list
               (mapcar #'(lambda (window)
                           (format nil "~A~S:: <~A>"
                                   (if (eq window (selected-window)) "※ " "　  ")
                                   window (buffer-name (window-buffer window))))
                       window-list))
         (push "　  アクティブウィンドウ" window-name-list)
         (push `(target-window . ,window-name-list) controls-initializers)
         (if (setq window-position (position *outline-tree-target-window* window-list))
             (incf window-position)
           (setq window-position 0))
         (push `(target-window . ,window-position) controls-initializers))
       ;;
       (push `(menu . ,*outline-tree-set-app-menu*) controls-initializers)
       (push `(menu-name . ,(if (and (stringp *outline-tree-app-menu-name*)
                                     (string/= *outline-tree-app-menu-name* ""))
                                *outline-tree-app-menu-name* "&Outline-Tree"))
             controls-initializers)
       (nreverse controls-initializers)))
 '((folder-name-length-num :type integer :min 0 :max 10000 :range-error "0以上を指定してください")
   (folder-name-length-spin :type integer :min 0 :max 10000)
   (recenter-line-num :type integer :min 0 :max 10000 :range-error "0以上を指定してください")
   (recenter-spin :type integer :min 0 :max 10000)
   (expand-on-create-depth-num :type integer :min 0 :max 10000 :range-error "0以上を指定してください")
   (expand-on-create-depth-spin :type integer :min 0 :max 10000)
   (expand-on-chase-depth-num :type integer :min 0 :max 10000 :range-error "0以上を指定してください")
   (expand-on-chase-depth-spin :type integer :min 0 :max 10000)
   (target-window :index t))
 #'(lambda (data)
     ;;
     (setq *outline-tree-chase-cursor* (cdr (assoc 'chase-cursor data)))
     (setq *outline-tree-chase-node* (cdr (assoc 'chase-node data)))
     (setq *outline-tree-text-highlight* (cdr (assoc 'text-highlight data)))
     (setq *outline-tree-text-highlight-always* (cdr (assoc 'text-highlight-always data)))
     (setq *outline-tree-available-swap-discontinuous-range-node*
           (cdr (assoc 'swap-discontinuous-range-node data)))
     ;;
     (cond
      ((cdr (assoc 'one-shot-create data))
       (setq *outline-tree-use* :one-shot))
      (t
       (setq *outline-tree-use* (outline-tree-exist-p))))
     ;;
     (setq *outline-tree-abbreviate-display-folder-name-length*
           (cdr (assoc 'folder-name-length-num data)))
     (outline-tree-abbreviate-display-folder-name
      *outline-tree-abbreviate-display-folder-name-length*)

     ;;
     (cond
      ((cdr (assoc 'recenter-nil data))
       (setq *outline-tree-editor-recenter* nil))
      ((cdr (assoc 'recenter-line data))
       (setq *outline-tree-editor-recenter* :line))
      ((cdr (assoc 'recenter-t data))
       (setq *outline-tree-editor-recenter* t)))
     (setq *outline-tree-editor-recenter-line*
           (cdr (assoc 'recenter-line-num data)))
     ;;
     (cond
      ((cdr (assoc 'expand-on-create-nil data))
       (setq *outline-tree-expand-on-create-outline* nil))
      ((cdr (assoc 'expand-on-create-depth data))
       (setq *outline-tree-expand-on-create-outline* :depth))
      ((cdr (assoc 'expand-on-create-t data))
       (setq *outline-tree-expand-on-create-outline* t)))
     (setq *outline-tree-expand-depth-on-create-outline*
           (cdr (assoc 'expand-on-create-depth-num data)))
     ;;
     (cond
      ((cdr (assoc 'expand-on-chase-nil data))
       (setq *outline-tree-expand-on-chase-cursor* nil))
      ((cdr (assoc 'expand-on-chase-depth data))
       (setq *outline-tree-expand-on-chase-cursor* :depth))
      ((cdr (assoc 'expand-on-chase-t data))
       (setq *outline-tree-expand-on-chase-cursor* t)))
     (setq *outline-tree-expand-depth-on-chase-cursor*
           (cdr (assoc 'expand-on-chase-depth-num data)))
     ;;
     (let ((window-list-index (cdr (assoc 'target-window data)))
           (window-list (mapcar 'car (caddr (current-window-configuration)))))
       (if (plusp window-list-index)
           (setq *outline-tree-target-window* (nth (1- window-list-index) window-list))
         (setq *outline-tree-target-window* nil)))
     ;;
     (unless (and (equal *outline-tree-set-app-menu* (cdr (assoc 'menu data)))
                  (equal *outline-tree-app-menu-name* (cdr (assoc 'menu-name data))))
       (setq *outline-tree-set-app-menu* (cdr (assoc 'menu data)))
       (setq *outline-tree-app-menu-name* (cdr (assoc 'menu-name data)))
       (if *outline-tree-set-app-menu*
           (outline-tree-insert-app-menu)
         (outline-tree-delete-app-menu)))
     ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; buffer-node 対応機能
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun outline-tree-set-buffer-by-node (&optional node)
  (treeview::with-app (*outline-tree-app-id*)
    (unless node
      (setq node (outline-tree-get-selected-node)))
    (setq node (outline-tree-get-buffer-node-by-node node))
    (let ((window-list (mapcar 'car (caddr (current-window-configuration))))
          (buffer (outline-tree-get-buffer-by-node node))
          (current-window (selected-window)))
      (when (and (windowp *outline-tree-target-window*)
                 (not (eq *outline-tree-target-window* (selected-window)))
                 (not (minibuffer-window-p *outline-tree-target-window*))
                 (member *outline-tree-target-window* window-list))
        (set-window *outline-tree-target-window*))
      (set-buffer buffer)
      (set-window current-window))
    (winapi:InvalidateRect (get-window-handle) 0 1)
    (winapi:UpdateWindow (get-window-handle))
    (refresh-title-bar)
    (refresh-screen 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; range-node 編集機能
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; range-node 削除
;;----------------------------------------------------------------------------
(defun outline-tree-valid-delete-range-node-region-p (range-node)
  (save-excursion
    (set-buffer (outline-tree-get-buffer-by-node range-node))
    (and (<= (point-min)
             (outline-tree-get-range-from (outline-tree-data-get-whole-range range-node)))
         (<= (outline-tree-get-range-to (outline-tree-data-get-whole-range range-node))
             (point-max)))))

(defun outline-tree-delete-region-by-range-node (&optional range-node)
  "range-node とともに、リージョンを削除"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (unless range-node
      (setq range-node (outline-tree-get-selected-node)))
    (unless (outline-tree-range-node-p range-node)
      (message "~A" "範囲ノードではありません")
      (return-from outline-tree-delete-region-by-range-node))
    (unless (outline-tree-latest-outline-p-by-node range-node)
      (message "~A" "アウトラインが最新でありません")
      (return-from outline-tree-delete-region-by-range-node))
    (let* ((buffer (outline-tree-get-buffer-by-node range-node))
           (whole-range (outline-tree-data-get-whole-range range-node))
           (from (outline-tree-get-range-from whole-range))
           (to (outline-tree-get-range-to whole-range)))
      (when (outline-tree-buffer-read-only-p buffer)
        (message "~A" "書込み禁止バッファです")
        (return-from outline-tree-delete-region-by-range-node))
      (unless (outline-tree-valid-region-by-range-node-p range-node)
        (message "~A" "対象範囲がナローイングされています")
        (return-from outline-tree-delete-region-by-range-node))
      (save-excursion
        (set-buffer buffer)
        ;; ノード削除 / データ修正
        (outline-tree-delete-region-update-node-data-tree
         (outline-tree-get-buffer-node-by-node range-node)
         (cons from to))
        ;; 実際の delete
        (delete-region from to)
        ;; undo boundary を設定
        (undo-boundary)
        ;; 最新のアウトラインと認識するよう設定
        (setq outline-tree-outline-modified (buffer-modified-count)))
      ;; 移動
      (outline-tree-select-node-by-node (outline-tree-get-selected-node) nil)
      (refresh-screen))))
(defun outline-tree-delete-region-update-node-data (node delete-range)
  (let ((buffer (outline-tree-get-buffer-by-node node))
        (delete-length (- (outline-tree-get-range-to delete-range)
                          (outline-tree-get-range-from delete-range)))
        range point)
    (case (outline-tree-data-get-type node)
      (:range-node
       (setq range (outline-tree-data-get-whole-range node))
       (case (outline-tree-get-range-relation delete-range range)
         (:before
          nil)
         (:after
          (outline-tree-set-offset-node-data-tree node (- delete-length))
          nil)
         ((:equal :inside)
          (outline-tree-remove-node-tree node)
          nil)
         (:outside
          (unless (outline-tree-range-to-unlimited-p range)
            (outline-tree-update-range-node
             node :whole-range (cons (outline-tree-get-range-from range)
                                     (- (outline-tree-get-range-to range) delete-length))))
          t)
         (:part-share
          (outline-tree-remove-node-tree node)
          nil)
         (t
          t)))
      (:point-node
       (setq point (outline-tree-data-get-point node))
       (case (outline-tree-get-range-relation delete-range point)
         (:before
          nil)
         (:after
          (outline-tree-set-offset-node-data-tree node (- delete-length))
          nil)
         (:inside
          (outline-tree-remove-node-tree node)
          nil)
         (t
          t)))
      (t
       t)
      )))

(defun outline-tree-delete-region-update-node-data-tree (node delete-range)
  (treeview::treeview-funcall-recursive-tree-top-down
   node #'(lambda (node) (outline-tree-delete-region-update-node-data node delete-range))))

;;----------------------------------------------------------------------------
;; range-node 入替え
;;----------------------------------------------------------------------------
(define-history-variable *outline-tree-available-swap-discontinuous-range-node* nil
  "不連続の range-node であっても入替えを許すか")
(defun outline-tree-available-swap-discontinuous-range-node-p ()
  "不連続の range-node であっても入替えを許すか"
  *outline-tree-available-swap-discontinuous-range-node*)
(defun outline-tree-toggle-available-swap-discontinuous-range-node (&optional (arg nil sv))
  "不連続の range-node であっても入替えを許すかの設定をトグル"
  (interactive "p")
  (if (null sv)
      (setq *outline-tree-available-swap-discontinuous-range-node*
            (not *outline-tree-available-swap-discontinuous-range-node*))
    (setq *outline-tree-available-swap-discontinuous-range-node* arg)))
(defun outline-tree-valid-region-by-range-node-p (range-node)
  "range-node のリージョンが、編集可能な領域か判定 (narrowing されていないか)"
  (save-excursion
    (set-buffer (outline-tree-get-buffer-by-node range-node))
    (let ((whole-range (outline-tree-data-get-whole-range range-node)))
      (and (<= (point-min) (outline-tree-get-range-from whole-range))
           (<= (outline-tree-get-range-to whole-range) (point-max))))))
(defun outline-tree-get-swap-target-range-node (range-node &optional prev)
  "入替え可能な range-node を返す"
  (treeview::with-app (*outline-tree-app-id*)
    (unless (and (outline-tree-node-valid-p range-node)
                 (outline-tree-range-node-p range-node))
      (return-from outline-tree-get-swap-target-range-node
        (values nil "指定されたノードが範囲ノードではありません")))
    (let (lower-node upper-node target-node)
      (if prev
          (progn
            (setq lower-node range-node)
            (setq upper-node (treeview::treeview-get-prev-sibling-item range-node))
            (setq target-node upper-node)
            (unless (outline-tree-node-valid-p upper-node)
              (return-from outline-tree-get-swap-target-range-node
                (values nil "入替え可能なノードが存在しません"))))
        (progn
          (setq upper-node range-node)
          (setq lower-node (treeview::treeview-get-next-sibling-item range-node))
          (setq target-node lower-node)
          (unless (outline-tree-node-valid-p lower-node)
            (return-from outline-tree-get-swap-target-range-node
              (values nil "入替え可能なノードが存在しません")))))
      (unless (and (outline-tree-range-node-p upper-node)
                   (outline-tree-range-node-p lower-node))
        (return-from outline-tree-get-swap-target-range-node
          (values nil "入替え対象ノードが範囲ノードではありません")))
      (unless (and (not (outline-tree-header-node-p upper-node))
                   (not (outline-tree-header-node-p lower-node)))
        (return-from outline-tree-get-swap-target-range-node
          (values nil "ヘッダノードは入替えできません")))
      (unless (eq (outline-tree-data-get-sub-type upper-node)
                  (outline-tree-data-get-sub-type lower-node))
        (return-from outline-tree-get-swap-target-range-node
          (values nil "異なる種類のノードは入替えできません")))
      (unless (or (outline-tree-available-swap-discontinuous-range-node-p)
                  (eql (outline-tree-get-range-to (outline-tree-data-get-whole-range upper-node))
                       (outline-tree-get-range-from (outline-tree-data-get-whole-range lower-node))))
        (return-from outline-tree-get-swap-target-range-node
          (values nil "ノードの範囲が連続していません")))
      target-node)))
(defun outline-tree-swap-region-by-next-range-node (&optional range-node prev)
  "range-node を次の range-node と入替え、リージョンの内容も入替える"
  (interactive)
  (treeview::with-app (*outline-tree-app-id*)
    (unless range-node
      (setq range-node (outline-tree-get-selected-node)))
    (unless (outline-tree-latest-outline-p-by-node range-node)
      (message "~A" "アウトラインが最新でありません")
      (return-from outline-tree-swap-region-by-next-range-node))
    (let (target-node error-reason upper-node lower-node buffer)
      (multiple-value-setq (target-node error-reason)
        (outline-tree-get-swap-target-range-node range-node prev))
      (unless target-node
        (if error-reason
            (message "~A" error-reason)
          (message "~A" "入替え可能なノードが存在しません"))
        (return-from outline-tree-swap-region-by-next-range-node))
      (if prev
          (setq upper-node target-node
                lower-node range-node)
        (setq upper-node range-node
              lower-node target-node))
      (setq buffer (outline-tree-get-buffer-by-node range-node))
      (save-excursion
        (set-buffer buffer)
        (when (outline-tree-buffer-read-only-p)
          (message "~A" "書込み禁止バッファです")
          (return-from outline-tree-swap-region-by-next-range-node))
        (unless (and (outline-tree-valid-region-by-range-node-p upper-node)
                     (outline-tree-valid-region-by-range-node-p lower-node))
          (message "~A" "対象範囲がナローイングされています")
          (return-from outline-tree-swap-region-by-next-range-node))
        ;; 範囲がバッファ末尾まで(to が nil)の場合
        ;;   ・:blank-line-oriented の場合、末尾に "\n\n" が必ずあるように
        ;;   ・上記以外の場合、末尾に "\n" が必ずあるように
        (when (outline-tree-range-to-unlimited-p
               (outline-tree-data-get-whole-range lower-node))
          (goto-char (point-max))
          (cond
           ((member :blank-line-oriented
                    (nth 2 (find (outline-tree-get-create-outline-function-by-buffer)
                                 *outline-tree-create-outline-function-alist* :key #'car)))
            (unless (and (char= (char-before (point)) #\LFD)
                         (char= (char-before (1- (point))) #\LFD))
              (if (char= (char-before (point)) #\LFD)
                  (insert "\n")
                (insert "\n\n"))))
           (t
            (unless (char= (char-before (point)) #\LFD)
              (insert "\n")))))
        ;; 実際のスワップ
        (let* ((lower-whole-range (outline-tree-data-get-whole-range lower-node))
               (upper-whole-range (outline-tree-data-get-whole-range upper-node))
               (lower-from (outline-tree-get-range-from lower-whole-range))
               (lower-to (outline-tree-get-range-to lower-whole-range))
               (upper-from (outline-tree-get-range-from upper-whole-range))
               (upper-to (outline-tree-get-range-to upper-whole-range))
               (lower-length (- lower-to lower-from))
               (upper-length (- upper-to upper-from))
               (lower-offset (- upper-from lower-from))
               (upper-offset (+ (- lower-offset) lower-length (- upper-length)))
               (lower-string (buffer-substring lower-from lower-to))
               (upper-string (buffer-substring upper-from upper-to)))
          ;; ノードデータ修正
          (outline-tree-swap-region-update-node-data-tree
           (outline-tree-get-buffer-node-by-node lower-node)
           upper-whole-range lower-whole-range)
          ;; 編集領域の移動
          (delete-region lower-from lower-to)
          (delete-region upper-from upper-to)
          (goto-char upper-from)
          (insert lower-string)
          (goto-char (+ lower-from lower-length (- upper-length)))
          (insert upper-string)
          ;; undo boundary を設定
          (undo-boundary))
        ;; ノードを表示上スワップ
        (let ((parent-node (treeview::treeview-get-parent-item range-node))
              node (i 0))
          (when (outline-tree-node-has-children-p parent-node)
            (setq node (treeview::treeview-get-child-item parent-node))
            (while (outline-tree-node-valid-p node)
              (treeview::treeview-set-item-data node (incf i))
              (setq node (treeview::treeview-get-next-sibling-item node))))
          (setq i (treeview::treeview-get-item-data upper-node))
          (treeview::treeview-set-item-data upper-node (treeview::treeview-get-item-data lower-node))
          (treeview::treeview-set-item-data lower-node i)
          (treeview::treeview-sort-children-cb-lparam-ascending parent-node))
        ;; 最新のアウトラインと認識するよう設定
        (setq outline-tree-outline-modified (buffer-modified-count)))
      ;; 移動
      (outline-tree-select-node-by-node range-node nil)
      (refresh-screen))))
(defun outline-tree-swap-region-by-prev-range-node (&optional range-node)
  "range-node を前の range-node と入替え、リージョンの内容も入替える"
  (interactive)
  (outline-tree-swap-region-by-next-range-node range-node t))

(defun outline-tree-set-offset-node-data (node offset)
  (let ((buffer (outline-tree-get-buffer-by-node node))
        range from to point)
    (case (outline-tree-data-get-type node)
      (:range-node
       (when (setq range (outline-tree-data-get-whole-range node))
         (outline-tree-update-range-node
          node
          :whole-range (cons (+ (outline-tree-get-range-from range) offset)
                             (+ (outline-tree-get-range-to range buffer) offset))))
       (when (setq range (outline-tree-data-get-title-range node))
         (outline-tree-update-range-node
          node
          :title-range (cons (+ (outline-tree-get-range-from range) offset)
                             (+ (outline-tree-get-range-to range buffer) offset)))))
      (:point-node
       (when (setq point (outline-tree-data-get-point node))
         (outline-tree-update-point-node node (+ point offset))))
      ((:buffer-node :folder-node :category-node :info-node :section-node)
       nil))))
(defun outline-tree-set-offset-node-data-tree (node offset)
  (treeview::treeview-funcall-recursive-tree-top-down
   node #'(lambda (node) (outline-tree-set-offset-node-data node offset) t)))

(defun outline-tree-swap-region-update-node-data (node upper-range lower-range)
  (let ((buffer (outline-tree-get-buffer-by-node node))
        (upper-length (- (outline-tree-get-range-to upper-range)
                         (outline-tree-get-range-from upper-range)))
        (lower-length (- (outline-tree-get-range-to lower-range)
                         (outline-tree-get-range-from lower-range)))
        (interval-length (- (outline-tree-get-range-from lower-range)
                            (outline-tree-get-range-to upper-range)))
        range point upper-relation lower-relation)
    (case (outline-tree-data-get-type node)
      (:range-node
       (setq range (outline-tree-data-get-whole-range node))
       (setq upper-relation (outline-tree-get-range-relation upper-range range))
       (setq lower-relation (outline-tree-get-range-relation lower-range range))
       (cond
        ((or (eq upper-relation :part-share) (eq lower-relation :part-share))
         (outline-tree-remove-node-tree node)
         nil)
        ((eq upper-relation :before)
         nil)
        ((or (eq upper-relation :inside) (eq upper-relation :equal))
         (outline-tree-set-offset-node-data-tree node (+ lower-length interval-length))
         nil)
        ((and (eq upper-relation :after) (eq lower-relation :before))
         (outline-tree-set-offset-node-data-tree node (+ lower-length (- upper-length)))
         nil)
        ((or (eq lower-relation :inside) (eq lower-relation :equal))
         (outline-tree-set-offset-node-data-tree node (+ (- upper-length) (- interval-length)))
         nil)
        ((eq lower-relation :after)
         nil)
        ((and (eq upper-relation :outside) (eq lower-relation :outside))
         t)
        ((eq upper-relation :outside)
         (unless (outline-tree-range-to-unlimited-p range)
           (outline-tree-update-range-node
            node :whole-range (cons (outline-tree-get-range-from range)
                                    (+ (outline-tree-get-range-to range)
                                       (- upper-length) lower-length))))
         t)
        ((eq lower-relation :outside)
         (outline-tree-update-range-node
          node :whole-range (cons (+ (outline-tree-get-range-from range)
                                     (- upper-length) lower-length)
                                  (if (outline-tree-range-to-unlimited-p range)
                                      nil (outline-tree-get-range-to range))))
         t)))
      (:point-node
       (setq point (outline-tree-data-get-point node))
       (setq upper-relation (outline-tree-get-range-relation upper-range point))
       (setq lower-relation (outline-tree-get-range-relation lower-range point))
       (cond
        ((eq upper-relation :before))
        ((eq upper-relation :inside)
         (outline-tree-set-offset-node-data-tree node (+ lower-length interval-length)))
        ((and (eq upper-relation :after) (eq lower-relation :before))
         (outline-tree-set-offset-node-data-tree node (+ lower-length (- upper-length))))
        ((eq lower-relation :inside)
         (outline-tree-set-offset-node-data-tree node (+ (- upper-length) (- interval-length))))
        ((eq lower-relation :after)))
       nil)
      (t
       t))))

(defun outline-tree-swap-region-update-node-data-tree (node upper-range lower-range)
  (treeview::treeview-funcall-recursive-tree-top-down
   node #'(lambda (node) (outline-tree-swap-region-update-node-data node upper-range lower-range))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 内部関数
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; 範囲
;;----------------------------------------------------------------------------
(defun outline-tree-get-range-from (range &optional buffer)
  (or (car range) (buffer-size buffer)))
(defun outline-tree-get-range-to (range &optional buffer)
  (or (cdr range) (buffer-size buffer)))
(defun outline-tree-range-to-unlimited-p (range)
  (null (cdr range)))

;;----------------------------------------------------------------------------
;; 範囲との関係を判定
;;----------------------------------------------------------------------------
(defun outline-tree-get-range-relation (base-range range-or-point &optional buffer)
  (let ((base-from (outline-tree-get-range-from base-range buffer))
        (base-to (outline-tree-get-range-to base-range buffer))
        (base-to-unlimited-p (not (cdr base-range)))
        range point target-from target-to)
    (if (consp range-or-point)
        (progn
          (setq range range-or-point)
          (setq target-from (outline-tree-get-range-from range buffer))
          (setq target-to (outline-tree-get-range-to range buffer)))
      (setq point range-or-point))
    (cond
     ;; range の場合
     (range
      (cond
       ;; 前の場合
       ((<= target-to base-from)
        :before)
       ;; 後ろの場合
       ((<= base-to target-from)
        :after)
       ;; 一致する場合
       ((and (= base-from target-from) (= base-to target-to))
        :equal)
       ;; base-range に内包される場合
       ((and (<= base-from target-from) (<= target-to base-to))
        :inside)
       ;; base-range を内包する場合
       ((and (<= target-from base-from) (<= base-to target-to))
        :outside)
       (t
        :part-share)))
     ;; point の場合
     (t
      (cond
       ((< point base-from)
        :before)
       (base-to-unlimited-p
        :inside)
       ((<= base-to point)
        :after)
       (t
        :inside))))))

;;----------------------------------------------------------------------------
;; 範囲を狭め、新しい範囲を返す (2004/11/29)
;;----------------------------------------------------------------------------
(defun outline-tree-range-narrow (range from to)
  "range の値を from と to で狭め、新しい range を返す"
  (let ((return-range '(nil . nil)))
    (if (and from (or (not (car range)) (< (car range) from)))
        (rplaca return-range from)
      (rplaca return-range (car range)))
    (if (and to (or (not (cdr range)) (< to (cdr range))))
        (rplacd return-range to)
      (rplacd return-range (cdr range)))
    return-range))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; outline 作成関数
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;----------------------------------------------------------------------------
;; outline 作成関数情報登録機構
;;----------------------------------------------------------------------------
(defvar *outline-tree-create-outline-function-alist* nil)
(defun outline-tree-add-create-outline-function (func-symbol func-name func-type &optional func-doc)
  (delete func-symbol *outline-tree-create-outline-function-alist* :key #'car)
  (setq *outline-tree-create-outline-function-alist*
        (stable-sort
         (nconc *outline-tree-create-outline-function-alist*
                (list (list func-symbol func-name func-type func-doc)))
         #'string-lessp :key #'second)))
(defvar *outline-tree-create-outline-function-menu* nil)
(defun outline-tree-create-outline-function-menu-gen ()
  (let ((outline-type-alist '((:all                  . "全て(&A)")
                              (nil                   . nil)
                              (:type-program         . "プログラミング個別(&P)")
                              (:type-program-general . "プログラミング汎用(&Q)")
                              (:type-document        . "文書フォーマット(&W)")
                              (:type-data            . "データフォーマット(&D)")
                              (:type-general         . "汎用(&G)")
                              (:type-misc            . "その他(&M)")
                              (:user                 . "ユーザ(&U)")))
        (outline-type-hash (make-hash-table))
        outline-type-symbol outline-type-name gen popup-menu)
    ;; ショートカットジェネレータ
    (setq gen (let (ccode)
                #'(lambda (&optional init)
                    (if init
                        (setq ccode nil)
                      (progn
                        (cond ((null ccode) (setq ccode (char-code #\A)))
                              ((and (>= ccode (char-code #\A))
                                    (< ccode (char-code #\Z))) (incf ccode))
                              ((= ccode (char-code #\Z)) (setq ccode (char-code #\0)))
                              ((< ccode (char-code #\9)) (incf ccode))
                              (t (setq ccode (char-code #\A))))
                        (code-char ccode))))))
    (setq *outline-tree-create-outline-function-menu*
          (create-popup-menu 'outline-tree-create-outline-function))
    ;; 作成関数の分類
    (dolist (x *outline-tree-create-outline-function-alist*)
      (setq x (copy-tree x))
      (let ((func-symbol (first x)) (func-name (second x)) (func-type (third x)))
        (cond ((member :user func-type)
               (push x (gethash :user outline-type-hash)))
              ((member :type-program func-type)
               (push x (gethash :type-program outline-type-hash)))
              ((member :type-program-general func-type)
               (push x (gethash :type-program-general outline-type-hash)))
              ((member :type-document func-type)
               (push x (gethash :type-document outline-type-hash)))
              ((member :type-data func-type)
               (push x (gethash :type-data outline-type-hash)))
              ((member :type-general func-type)
               (push x (gethash :type-general outline-type-hash)))
              (t
               (push x (gethash :type-misc outline-type-hash))))
        (push x (gethash :all outline-type-hash))))
    ;; メニュー作成
    (dolist (outline-type outline-type-alist)
      (setq outline-type-symbol (car outline-type)
            outline-type-name (cdr outline-type))
      (cond
       ((eq outline-type-symbol nil)
        (add-menu-separator *outline-tree-create-outline-function-menu*))
       (t
        (funcall gen t)
        (setq popup-menu (create-popup-menu outline-type-symbol))
        (add-popup-menu *outline-tree-create-outline-function-menu*
                        popup-menu outline-type-name)
        (dolist (x (nreverse (gethash outline-type-symbol outline-type-hash)))
          (setq x (copy-tree x))
          (let ((func-symbol (first x)) (func-name (second x)) (func-type (third x)))
            (add-menu-item popup-menu
                           func-symbol
                           (concat func-name (format nil "(&~A)" (funcall gen)))
                           #'(lambda () (interactive)
                               (save-excursion
                                 (set-buffer (outline-tree-get-buffer-by-node))
                                 (setq outline-tree-create-outline-function-interactive func-symbol)
                                 (outline-tree-create-outline-by-node)
                                 (treeview::treeview-message "~A" func-name)))
                           #'(lambda ()
                               (cond
                                ((not (outline-tree-exist-p))
                                 :disable)
                                ((not (outline-tree-get-buffer-node-by-node))
                                 :disable)
                                ((eq (outline-tree-get-create-outline-function-by-node) func-symbol)
                                 :check)))))))))
    ;; app-menu 内メニューの更新
    (when (menup *outline-tree-app-menu*)
      (let ((pos (get-menu-position *outline-tree-app-menu*
                                    'outline-tree-create-outline-function)))
        (when pos
          (delete-menu *outline-tree-app-menu* 'outline-tree-create-outline-function)
          (insert-popup-menu *outline-tree-app-menu* pos
                             *outline-tree-create-outline-function-menu*
                             "アウトラインタイプ選択(&S)"))))))

;;----------------------------------------------------------------------------
;; outline 作成関数情報表示機構
;;----------------------------------------------------------------------------
(defvar *outline-tree-create-outline-function-info-menu* nil)
(defun outline-tree-create-outline-function-info-menu-gen ()
  (let ((outline-type-alist '((:all                  . "全て(&A)")
                              (nil                   . nil)
                              (:type-program         . "プログラミング個別(&P)")
                              (:type-program-general . "プログラミング汎用(&Q)")
                              (:type-document        . "文書フォーマット(&W)")
                              (:type-data            . "データフォーマット(&D)")
                              (:type-general         . "汎用(&G)")
                              (:type-misc            . "その他(&M)")
                              (:user                 . "ユーザ(&U)")))
        (outline-type-hash (make-hash-table))
        outline-type-symbol outline-type-name gen popup-menu)
    ;; ショートカットジェネレータ
    (setq gen (let (ccode)
                #'(lambda (&optional init)
                    (if init
                        (setq ccode nil)
                      (progn
                        (cond ((null ccode) (setq ccode (char-code #\A)))
                              ((and (>= ccode (char-code #\A))
                                    (< ccode (char-code #\Z))) (incf ccode))
                              ((= ccode (char-code #\Z)) (setq ccode (char-code #\0)))
                              ((< ccode (char-code #\9)) (incf ccode))
                              (t (setq ccode (char-code #\A))))
                        (code-char ccode))))))
    (setq *outline-tree-create-outline-function-info-menu*
          (create-popup-menu 'outline-tree-create-outline-function-info))
    ;; 作成関数の分類
    (dolist (x *outline-tree-create-outline-function-alist*)
      (setq x (copy-tree x))
      (let ((func-symbol (first x)) (func-name (second x)) (func-type (third x)))
        (cond ((member :user func-type)
               (push x (gethash :user outline-type-hash)))
              ((member :type-program func-type)
               (push x (gethash :type-program outline-type-hash)))
              ((member :type-program-general func-type)
               (push x (gethash :type-program-general outline-type-hash)))
              ((member :type-document func-type)
               (push x (gethash :type-document outline-type-hash)))
              ((member :type-data func-type)
               (push x (gethash :type-data outline-type-hash)))
              ((member :type-general func-type)
               (push x (gethash :type-general outline-type-hash)))
              (t
               (push x (gethash :type-misc outline-type-hash))))
        (push x (gethash :all outline-type-hash))))
    ;; メニュー作成
    (add-menu-item *outline-tree-create-outline-function-info-menu* nil
                   "一覧(&0)"
                   #'(lambda () (interactive)
                       (with-output-to-temp-buffer ("*outline-tree: info*")
                         (dolist (outline-type outline-type-alist)
                           (setq outline-type-symbol (car outline-type)
                                 outline-type-name (cdr outline-type))
                           (when (member outline-type-symbol '(:all))
                             (setq outline-type-symbol nil
                                   outline-type-name nil))
                           (when outline-type-symbol
                             (string-match "^\\(.+\\)(.+)$" outline-type-name)
                             (format t "【~A】~%" (match-string 1)))
                           (dolist (x (reverse (gethash outline-type-symbol outline-type-hash)))
                             (setq x (copy-tree x))
                             (let ((func-symbol (first x)) (func-name (second x))
                                   (func-type (third x)) (func-doc (fourth x)))
                               (format t "■~A~%" func-name)
                               (format t "□説明~%~A~%~%" (or func-doc ""))
                               (format t "□AUTO-MODE 指定~%  -*- outline-tree: ~A -*-~%~%"
                                       (let ((str (symbol-name func-symbol)))
                                         (when (string-matchp "^outline-tree2:+\\(.+\\)" str)
                                           (setq str (match-string 1)))
                                         (when (string-match "^outline-tree-create-outline-\\(.+\\)" str)
                                           (setq str (match-string 1)))
                                         str))
                               (format t "□シンボル名~%  ~S~%~%" func-symbol)
                               (format t "□分類・付加情報~%")
                               (if func-type
                                   (let* ((func-type-main (car func-type))
                                          (func-type-sub (cdr func-type))
                                          (func-type-main-name (cdr (find func-type-main outline-type-alist :key #'car))))
                                     (if func-type-main-name
                                         (progn
                                           (string-match "^\\(.+\\)(.+)$" func-type-main-name)
                                           (format t "  ~A~%" (or (match-string 1) func-type-main-name)))
                                       (format t "~%"))
                                     (dolist (x func-type-sub)
                                       (cond
                                        ((eq x :line-oriented)
                                         (format t "    - 行指向~%"))
                                        ((eq x :blank-line-oriented)
                                         (format t "    - 空行指向~%"))
                                        ((eq x :sequential)
                                         (format t "    - シーケンシャル~%"))
                                        (t
                                         (format t "~%")))))
                                 (format t "  なし~%"))
                               (format t "~%")))))
                       (refresh-screen)))
    (add-menu-separator *outline-tree-create-outline-function-info-menu*)
    (dolist (outline-type outline-type-alist)
      (setq outline-type-symbol (car outline-type)
            outline-type-name (cdr outline-type))
      (cond
       ((eq outline-type-symbol nil)
        (add-menu-separator *outline-tree-create-outline-function-info-menu*))
       (t
        (funcall gen t)
        (setq popup-menu (create-popup-menu outline-type-symbol))
        (add-popup-menu *outline-tree-create-outline-function-info-menu*
                        popup-menu outline-type-name)
        (dolist (x (reverse (gethash outline-type-symbol outline-type-hash)))
          (setq x (copy-tree x))
          (let ((func-symbol (first x)) (func-name (second x)) (func-type (third x)) (func-doc (fourth x)))
            (add-menu-item popup-menu
                           func-symbol
                           (concat func-name (format nil "(&~A)" (funcall gen)))
                           #'(lambda () (interactive)
                               (with-output-to-temp-buffer ("*outline-tree: info*")
                                 (format t "■~A~%" func-name)
                                 (format t "□説明~%~A~%~%" (or func-doc ""))
                                 (format t "□AUTO-MODE 指定~%  -*- outline-tree: ~A -*-~%~%"
                                         (let ((str (symbol-name func-symbol)))
                                           (when (string-matchp "^outline-tree2:+\\(.+\\)" str)
                                             (setq str (match-string 1)))
                                           (when (string-match "^outline-tree-create-outline-\\(.+\\)" str)
                                             (setq str (match-string 1)))
                                           str))
                                 (format t "□シンボル名~%  ~S~%~%" func-symbol)
                                 (format t "□分類・付加情報~%")
                                 (if func-type
                                     (let ((func-type-main (car func-type))
                                           (func-type-sub (cdr func-type)))
                                       (format t "  ~S" func-type-main)
                                       (if (find func-type-main outline-type-alist :key #'car)
                                           (format t "        : ~A~%~%"
                                                   (cdr (find func-type-main outline-type-alist :key #'car)))
                                         (format t "~%~%"))
                                       (dolist (x func-type-sub)
                                         (format t "  ~S" x)
                                         (cond
                                          ((eq x :line-oriented)
                                           (format t "    : 行指向~%"))
                                          ((eq x :blank-line-oriented)
                                           (format t "    : 空行指向~%"))
                                          ((eq x :sequential)
                                           (format t "    : シーケンシャル~%"))
                                          (t
                                           (format t "~%")))))
                                   (format t "  なし~%"))
                                 (format t "~%"))
                               (refresh-screen))
                           #'(lambda ()
                               (and (eq (outline-tree-get-create-outline-function-by-node) func-symbol)
                                    :check))))))))
    ;; app-menu 内メニューの更新
    (when (menup *outline-tree-app-menu*)
      (let ((pos (get-menu-position *outline-tree-app-menu*
                                    'outline-tree-create-outline-function-info)))
        (when pos
          (delete-menu *outline-tree-app-menu* 'outline-tree-create-outline-function-info)
          (insert-popup-menu *outline-tree-app-menu* pos
                             *outline-tree-create-outline-function-info-menu*
                             "アウトラインタイプ説明(&P)"))))))

;;----------------------------------------------------------------------------
;; ノード開閉関数
;;----------------------------------------------------------------------------
(gc)
(require "outline-tree/expand")

;;----------------------------------------------------------------------------
;; outline 作成関数
;;----------------------------------------------------------------------------
; バイトコンパイル済みの場合、ある程度のタイミングで gc を
; 入れておかないと、outline-tree.l ロード時に access violation となる。
(gc)
(require "outline-tree/cr-range-internal")
(require "outline-tree/cr-regexp-internal")
(require "outline-tree/cr-topic-internal")
(require "outline-tree/cr-hierarchy-internal")
(require "outline-tree/cr-regexp-inheritance")
(require "outline-tree/cr-hierarchy-inheritance")
(require "outline-tree/cr-topic")
(require "outline-tree/cr-regexp")
(require "outline-tree/cr-tag")
(require "outline-tree/cr-css")
(require "outline-tree/cr-hiki")
(require "outline-tree/cr-html-heading")
(require "outline-tree/cr-html-info-and-heading")
(require "outline-tree/cr-ini")
(require "outline-tree/cr-texinfo")
(require "outline-tree/cr-rd")
(require "outline-tree/cr-Markdown")
(require "outline-tree/cr-LaTeX")
(require "outline-tree/cr-lisp")
(require "outline-tree/cr-perl")
(require "outline-tree/cr-VB-like")
(require "outline-tree/cr-ASP")
(require "outline-tree/cr-XTAGS")
(require "outline-tree/cr-ctags")
(require "outline-tree/cr-global")
(require "outline-tree/cr-list-function")
(require "outline-tree/cr-grep")
(require "outline-tree/cr-2ch")
(require "outline-tree/cr-indent")
(require "outline-tree/cr-sted")
(require "outline-tree/cr-eMemoPad")
(require "outline-tree/cr-FreeMind")
(require "outline-tree/cr-RFC")
(require "outline-tree/cr-xsv")
(require "outline-tree/cr-blank-line")
(require "outline-tree/cr-xdoc2txt-pdf")
(require "outline-tree/cr-xdoc2txt-excel")
(require "outline-tree/get-outline-function")

;;----------------------------------------------------------------------------
;; outline 作成関数の生成関数
;;----------------------------------------------------------------------------
(gc)
(require "outline-tree/gen-cr-user-topic")
(require "outline-tree/gen-cr-user-regexp")

;;----------------------------------------------------------------------------
;; 出力関数
;;----------------------------------------------------------------------------
(gc)
(require "outline-tree/output")
(require "outline-tree/output-html")
(require "outline-tree/output-html-range")
(require "outline-tree/output-html-heading")
(require "outline-tree/output-dialog")

;;----------------------------------------------------------------------------
;; ツールバー/app-menu
;;----------------------------------------------------------------------------
(gc)
(require "outline-tree/toolbar")
(require "outline-tree/app-menu")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ユーティリティ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun outline-tree-save-some-buffers (verbose buffers &optional (fn #'ed::write-file))
  (long-operation
    (let ((count 0))
      (save-excursion
        (handler-case
            (dolist (buffer buffers)
              (when (need-buffer-save-p buffer)
                (set-buffer buffer)
                (if (not (file-visited-p))
                    (progn
                      (refresh-screen)
                      (if (yes-no-or-cancel-p "~aをセーブしますか?" buffer)
                          (when (call-interactively fn)
                            (setq count (1+ count)))
                        (not-modified)))
                  (when (or (not verbose)
                            (progn
                              (refresh-screen)
                              (yes-no-or-cancel-p "~a~%をセーブしますか?"
                                                  (get-buffer-file-name))))
                    (save-buffer)
                    (setq count (1+ count))))))
          (error (c)
            (msgbox "~a~%" (si:*condition-string c))
            (return-from outline-tree-save-some-buffers nil))))
      (message "~d個のファイルをセーブしました" count)
      t)))

(defun outline-tree-kill-folder-file-buffers (folder &optional not-verbose)
  (let (file buffers)
    (if (file-exist-p folder)
        (dolist (buffer (buffer-list))
          (when (and (setq file (get-buffer-file-name buffer))
                     (path-equal folder (directory-namestring file)))
            (push buffer buffers)))
      (progn
        (dolist (buffer (buffer-list))
          (when (and (setq file (get-buffer-file-name buffer))
                     (string-equal
                      (string-right-trim "/" folder)
                      (string-right-trim "/" (directory-namestring file))))
            (push buffer buffers)))))
    (setq buffers (nreverse buffers))
    (when (outline-tree-save-some-buffers (not not-verbose) buffers)
      (dolist (buffer buffers t)
        (kill-buffer buffer)))
    (winapi:InvalidateRect (get-window-handle) 0 1)
    (winapi:UpdateWindow (get-window-handle))
    (refresh-screen)))

(defun outline-tree-delete-category-buffers (category-node)
  (let (delete-buffer-p)
    (dolist (buffer (buffer-list))
      (when (and (eq category-node (outline-tree-get-category-node-by-buffer buffer))
                 (not (find (buffer-name buffer) *outline-tree-delete-category-buffers-except-regexp-list*
                            :test #'(lambda (buffer-name regexp) (string-match regexp buffer-name)))))
        (delete-buffer buffer)
        (setq delete-buffer-p t)))
    (when delete-buffer-p
      (winapi:InvalidateRect (get-window-handle) 0 1)
      (winapi:UpdateWindow (get-window-handle))
      (refresh-screen))))

(defun outline-tree-create-outline-and-select-node ()
  (interactive)
  (unless (outline-tree-latest-outline-p-by-window)
    (outline-tree-create-outline-by-window))
  (unless (outline-tree-open-p)
    (outline-tree-open))
  ;; 連続でコマンドが実行された場合、ノードの expand を toggle する。
  (when (eq *last-command* 'outline-tree-create-outline-and-select-node)
    (treeview::with-app (*outline-tree-app-id*)
      (let ((node (outline-tree-get-selected-node)))
        (when (outline-tree-node-has-children-p node)
          (treeview::treeview-expand-toggle node)))))
  (outline-tree-select-node-by-window nil nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; xyzzy 起動時処理
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun outline-tree-startup ()
  (outline-tree-initialize-treeview)
  (outline-tree-create-outline-function-menu-gen)
  (outline-tree-create-outline-function-info-menu-gen)
  (when (eq *outline-tree-use* t)
    ;; (outline-tree-create) をそのまま実行すると起動時に *app-menu* の
    ;; トップレベルに追加するメニュー (ex. browserex) が環境により正常動作
    ;; しなくなる。
    ;; タイミングの問題に思えるため、start-timer で回避。
;   (outline-tree-create)
    (start-timer 0.01 #'outline-tree-create t))
  (run-hooks '*outline-tree-startup-hook*))

(if (menup ed::*app-menu*)
    (outline-tree-insert-menu-items :head-sep t)
  (add-hook 'ed::*init-app-menus-hook*
            #'(lambda () (outline-tree-insert-menu-items :head-sep t))))

(add-hook 'ed::*post-startup-hook* 'outline-tree-startup)

;;; outline-tree.l ends here
