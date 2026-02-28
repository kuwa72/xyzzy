;;; -*- Mode: Lisp; Package: TREEVIEW -*-
;;; get-item.l --- treeview

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/11/03 05:58:38 +0900>

;;; Code:

(provide "wip/treeview/get-item")

(require "wip/treeview/defs")
(require "wip/treeview/dll")

(in-package "treeview")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; item 取得
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-get-selected-item ()
  "現在選択しているアイテムを取得。"
  (treeview-dll-get-selected-item *treeview-id*))

(defun treeview-get-child-item (hitem)
  "item の先頭子アイテムを取得。
子 item が存在しない場合は 0 を返す。"
  (treeview-dll-get-child-item *treeview-id* hitem))
(defun treeview-get-next-sibling-item (hitem)
  "item の次の兄弟アイテム(下のアイテム)を取得。"
  (treeview-dll-get-next-sibling-item *treeview-id* hitem))
(defun treeview-get-prev-sibling-item (hitem)
  "item の前の兄弟アイテム(上のアイテム)を取得。"
  (treeview-dll-get-prev-sibling-item *treeview-id* hitem))
(defun treeview-get-parent-item (hitem)
  "item の親アイテムを取得。"
  (treeview-dll-get-parent-item *treeview-id* hitem))
(defun treeview-get-next-visible-item (hitem)
  "次の表示アイテムを取得。"
  (treeview-dll-get-next-item *treeview-id* hitem winapi:TVGN_NEXTVISIBLE))
(defun treeview-get-prev-visible-item (hitem)
  "前の表示アイテムを取得。"
  (treeview-dll-get-next-item *treeview-id* hitem winapi:TVGN_PREVIOUSVISIBLE))

(defun treeview-get-root-item ()
  "treeview の一番上のアイテムを取得。"
  (treeview-dll-get-root-item *treeview-id*))
(defun treeview-get-first-visible-item ()
  "画面先頭表示アイテムを取得。"
  (treeview-dll-get-next-item *treeview-id* 0 winapi:TVGN_FIRSTVISIBLE))
; (setf (symbol-function 'treeview-get-first-window-visible-item)
;       #'treeview-get-first-visible-item)
(defun treeview-get-last-visible-item ()
  "展開している中で末尾のアイテムを取得"
  (treeview-dll-get-next-item *treeview-id* 0 winapi:TVGN_LASTVISIBLE))
(defun treeview-get-last-window-visible-item ()
  "画面末尾表示アイテムを取得"
  (let (hitem1 hitem2)
    (setq hitem1 (treeview-get-first-visible-item))
    (dotimes (i (1- (treeview-get-visible-count)))
      (setq hitem2 (treeview-get-next-visible-item hitem1))
      (if (treeview-hitem-valid-p hitem2)
          (setq hitem1 hitem2)
        (return)))
    (if (treeview-hitem-valid-p hitem2)
        hitem2 hitem1)))

;;----------------------------------------------------------------------------
;; item 取得拡張
;;----------------------------------------------------------------------------
(defun treeview-get-first-sibling-item (hitem)
  "最初の兄弟アイテム(一番上)を取得。"
  (let ((return-hitem hitem))
    (loop
      (setq hitem (treeview-get-prev-sibling-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(defun treeview-get-last-sibling-item (hitem)
  "最後の兄弟アイテム(一番下)を取得。"
  (let ((return-hitem hitem))
    (loop
      (setq hitem (treeview-get-next-sibling-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(defun treeview-get-youngest-child-item (hitem)
  "item の一番下の子アイテムを取得。"
  (unless (and (treeview-hitem-valid-p hitem)
               (treeview-item-has-children-p hitem))
    (return-from treeview-get-youngest-child-item 0))
  (setq hitem (treeview-get-child-item hitem))
  (let ((return-hitem hitem))
    (loop
      (setq hitem (treeview-get-next-sibling-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(defun treeview-get-ancestor-item (hitem)
  "一番親のアイテムを取得。"
  (let ((return-hitem 0))
    (loop
      (setq hitem (treeview-get-parent-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(defun treeview-get-descendants-item (hitem)
  "一番下の子アイテムの取得を繰り返した結果のアイテムを取得。"
  (let ((return-hitem 0))
    (loop
      (setq hitem (treeview-get-youngest-child-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(defun treeview-get-eldest-descendants-item (hitem)
  "一番上の子アイテムの取得を繰り返した結果のアイテムを取得。"
  (let ((return-hitem 0))
    (loop
      (setq hitem (treeview-get-child-item hitem))
      (unless (treeview-hitem-valid-p hitem)
        (return return-hitem))
      (setq return-hitem hitem))))
(setf (symbol-function 'treeview-get-youngest-descendants-item)
      #'treeview-get-descendants-item)
(defun treeview-get-up-item (hitem)
  "表示/非表示に関わらず一つ上のアイテムを取得。"
  (unless (treeview-hitem-valid-p hitem)
    (return-from treeview-get-up-item 0))
  (let (hitem1 hitem2)
    (cond
     ((treeview-hitem-valid-p (setq hitem1 (treeview-get-prev-sibling-item hitem)))
      (if (treeview-hitem-valid-p (setq hitem2 (treeview-get-descendants-item hitem1)))
          hitem2
        hitem1))
     ((treeview-hitem-valid-p (setq hitem1 (treeview-get-parent-item hitem)))
      hitem1)
     (t 0))))
(defun treeview-get-down-item (hitem)
  "表示/非表示に関わらず一つ下のアイテムを取得。"
  (unless (treeview-hitem-valid-p hitem)
    (return-from treeview-get-down-item 0))
  (let (hitem1 hitem2)
    (cond
     ((treeview-hitem-valid-p (setq hitem1 (treeview-get-child-item hitem)))
      hitem1)
     ((treeview-hitem-valid-p (setq hitem1 (treeview-get-next-sibling-item hitem)))
      hitem1)
     (t
      (setq hitem1 hitem)
      (while (treeview-hitem-valid-p (setq hitem1 (treeview-get-parent-item hitem1)))
        (if (treeview-hitem-valid-p (setq hitem2 (treeview-get-next-sibling-item hitem1)))
            (return-from treeview-get-down-item hitem2)))
      0))))
(defun treeview-get-bottom-item ()
  "表示/非表示に関わらず treeview の一番下のアイテムを取得。"
  (unless (and (treeview-exist-p)
               (treeview-hitem-valid-p (treeview-get-root-item)))
    (return-from treeview-get-bottom-item 0))
  (let ((hitem1 (treeview-get-last-sibling-item (treeview-get-root-item)))
        hitem2)
    (if (treeview-hitem-valid-p
         (setq hitem2 (treeview-get-descendants-item hitem1)))
        hitem2
      hitem1)))

;;----------------------------------------------------------------------------
;; カーソルキーエミュレート
;;----------------------------------------------------------------------------
(defun treeview-get-up-key-item (hitem)
  "item で Up キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (treeview-get-prev-visible-item hitem)))
(defun treeview-get-down-key-item (hitem)
  "item で Down キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (treeview-get-next-visible-item hitem)))
(defun treeview-get-left-key-item (hitem)
  "item で Left キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (if (treeview-expand-p hitem)
        hitem
      (treeview-get-parent-item hitem))))
(defun treeview-get-right-key-item (hitem)
  "item で Right キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (if (treeview-expand-p hitem)
        (treeview-get-child-item hitem)
      hitem)))
(defun treeview-get-pageup-key-item (hitem)
  "item で PageUp キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (let (next-hitem)
      (dotimes (i (1- (treeview-window-height)))
        (setq next-hitem (treeview-get-prev-visible-item hitem))
        (if (treeview-hitem-valid-p next-hitem)
            (setq hitem next-hitem)
          (return)))
      hitem)))
(defun treeview-get-pagedown-key-item (hitem)
  "item で PageDown キー押下時に選択するアイテムを取得。"
  (when (treeview-hitem-valid-p hitem)
    (let (next-hitem)
      (dotimes (i (1- (treeview-window-height)))
        (setq next-hitem (treeview-get-next-visible-item hitem))
        (if (treeview-hitem-valid-p next-hitem)
            (setq hitem next-hitem)
          (return)))
      hitem)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; item 選択、実行
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-select-act-item-1 (hitem item-mover &optional select-only)
  "item を選択、実行する際の内部関数。"
  (let* (func-gen func
         (treeview-recenter (treeview-data-get 'treeview::recenter)) ; t, nil, :line
         (recenter-line (treeview-data-get 'treeview::recenter-line)); 0 origin
         (scroll-margin (treeview-data-get 'treeview::scroll-margin)); recenter 優先
         (selected-hitem (treeview-get-selected-item))
         (current-window-line (treeview-get-window-line selected-hitem))
         need-not-recenter-p)
    ;; 選択する item の取得
    (unless hitem
      (setq hitem (treeview-get-selected-item)))
    (if (and (treeview-hitem-valid-p hitem)
             (functionp item-mover))
        (setq hitem (funcall item-mover hitem)))
    (unless (treeview-hitem-valid-p hitem)
      (return-from treeview-select-act-item-1 nil))
    ;; recenter/scroll-margin 後の表示行の計算
    (cond
     ;; 行指定 recenter
     ((eq treeview-recenter :line)
      (unless (integerp recenter-line)
        (setq need-not-recenter-p t)))
     ;; recenter
     (treeview-recenter
      (setq recenter-line (truncate (treeview-window-height) 2)))
     ;; scroll-margin
     ((and (integerp scroll-margin) (plusp scroll-margin))
      (setq scroll-margin
            (min scroll-margin (truncate (treeview-window-height) 2)))
      (cond
       ;; 同一ノードの場合
       ((treeview-hitem-equal selected-hitem hitem)
        (when (and (<= scroll-margin current-window-line)
                   (<= current-window-line (- (1- (treeview-window-height)) scroll-margin)))
          (setq need-not-recenter-p t)))
       ;; 上に移動している場合
       ((treeview-hitem-greaterp selected-hitem hitem)
        (setq recenter-line scroll-margin)
        (when (>= (treeview-get-window-line hitem) recenter-line)
          (setq need-not-recenter-p t)))
       ;; 下に移動している場合
       (t
        (setq recenter-line (- (1- (treeview-window-height)) scroll-margin))
        (when (< (treeview-get-window-line hitem) recenter-line)
          (setq need-not-recenter-p t)))))
     (t
      (setq need-not-recenter-p t)))
    ;; item の選択と recenter/scroll-margin でのスクロール量の計算/スクロール
    (if (or need-not-recenter-p
            (and (treeview-item-window-visible-p hitem)
                 (let ((scroll (treeview-recenter-scroll-height hitem recenter-line)))
                   (cond ((not (numberp scroll)) nil)
                         ((zerop scroll) t)
                         ((plusp scroll) (treeview-window-bottom-p))
                         (t              (treeview-window-top-p))))))
        ;; スクロールの必要がない場合
        (treeview-select-item hitem)
      ;; スクロールの必要がある場合
      (treeview-suppress-redraw
       (treeview-select-item hitem)
       (treeview-recenter recenter-line)))
    ;; item の実行
    (when (and (not select-only)
               (setq func-gen (treeview-data-get 'implicit-func-gen)))
      (when (setq func (funcall func-gen hitem))
        (funcall func)))))

(defun treeview-select-act-item (&optional hitem select-only)
  "item を選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem nil select-only))

(defun treeview-select-act-child-item (&optional hitem select-only)
  "item の先頭子アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-child-item select-only))
(defun treeview-select-act-next-sibling-item (&optional hitem select-only)
  "item の次の兄弟アイテム (下のアイテム)を選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-next-sibling-item select-only))
(defun treeview-select-act-prev-sibling-item (&optional hitem select-only)
  "item の前の兄弟アイテム (上のアイテム)を選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-prev-sibling-item select-only))
(defun treeview-select-act-parent-item (&optional hitem select-only)
  "item の前の親アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-parent-item select-only))
(defun treeview-select-act-first-visible-item (&optional hitem select-only)
  "画面先頭表示アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-first-visible-item select-only))
(defun treeview-select-act-last-visible-item (&optional hitem select-only)
  "展開している中で末尾のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-last-visible-item select-only))
(defun treeview-select-act-last-window-visible-item (&optional hitem select-only)
  "画面末尾表示アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-last-window-visible-item select-only))
(defun treeview-select-act-next-visible-item (&optional hitem select-only)
  "次の表示アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-next-visible-item select-only))
(defun treeview-select-act-prev-visible-item (&optional hitem select-only)
  "前の表示アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-prev-visible-item select-only))
(defun treeview-select-act-root-item (&optional select-only)
  "treeview の一番上のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 (treeview-get-root-item) nil select-only))
(defun treeview-select-act-youngest-child-item (&optional hitem select-only)
  "item の一番下の子アイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-youngest-child-item select-only))
(defun treeview-select-act-ancestor-item (&optional hitem select-only)
  "一番親のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-ancestor-item select-only))
(defun treeview-select-act-descendants-item (&optional hitem select-only)
  "一番下の子アイテムの取得を繰り返した結果のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-descendants-item select-only))
(defun treeview-select-act-eldest-descendants-item (&optional hitem select-only)
  "一番上の子アイテムの取得を繰り返した結果のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-eldest-descendants-item select-only))
(defun treeview-select-act-youngest-descendants-item (&optional hitem select-only)
  "一番下の子アイテムの取得を繰り返した結果のアイテムを選択、実行。
treeview-select-act-descendants-item と同一。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-youngest-descendants-item select-only))
(defun treeview-select-act-up-item (&optional hitem select-only)
  "表示/非表示に関わらず一つ上のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-up-item select-only))
(defun treeview-select-act-down-item (&optional hitem select-only)
  "表示/非表示に関わらず一つ下のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-down-item select-only))
(defun treeview-select-act-bottom-item (&optional select-only)
  "表示/非表示に関わらず treeview の一番下のアイテムを選択、実行。"
  (interactive)
  (treeview-select-act-item-1 (treeview-get-bottom-item) nil select-only))

;;----------------------------------------------------------------------------
;; カーソルキーエミュレート
;;----------------------------------------------------------------------------
(defun treeview-select-act-up-key-item (&optional hitem select-only)
  "Up キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-up-key-item select-only))
(defun treeview-select-act-down-key-item (&optional hitem select-only)
  "Down キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-down-key-item select-only))
(defun treeview-select-act-left-key-item (&optional hitem select-only)
  "Left キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (unless hitem
    (setq hitem (treeview-get-selected-item)))
  (when (treeview-hitem-valid-p hitem)
    (let ((next-hitem (treeview-get-left-key-item hitem)))
      (treeview-suppress-redraw
       (when (treeview-expand-p hitem)
         (treeview-expand-collapse hitem))
       (treeview-select-act-item-1 next-hitem nil select-only)))))
(defun treeview-select-act-right-key-item (&optional hitem select-only)
  "Right キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (unless hitem
    (setq hitem (treeview-get-selected-item)))
  (when (treeview-hitem-valid-p hitem)
    (let ((next-hitem (treeview-get-right-key-item hitem)))
      (treeview-suppress-redraw
       (when (and (treeview-item-has-children-p hitem)
                  (not (treeview-expand-p hitem)))
         (treeview-expand-expand hitem))
       (treeview-select-act-item-1 next-hitem nil select-only)))))
(defun treeview-select-act-pageup-key-item (&optional hitem select-only)
  "PageUp キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-pageup-key-item select-only))
(defun treeview-select-act-pagedown-key-item (&optional hitem select-only)
  "PageDown キー押下時の動作をエミュレートし、その後アイテムを実行。"
  (interactive)
  (treeview-select-act-item-1 hitem #'treeview-get-pagedown-key-item select-only))

;;----------------------------------------------------------------------------
;; 特殊
;;----------------------------------------------------------------------------
(defvar *treeview-select-act-item-delay-sec* 0.01
  "treeview-select-act-item-delay 用変数。")
(defun treeview-select-act-item-delay ()
  "一瞬待機し、現在のアイテムを改めて選択、実行。"
  (interactive)
  (let* ((selected-hitem (treeview-get-selected-item))
         (app-id *treeview-app-id*) fn)
    (setq fn #'(lambda ()
                 (with-app (app-id)
                   (let ((hitem (treeview-get-selected-item)))
                     (when (treeview-hitem-valid-p hitem)
;                       (treeview-select-act-item selected-hitem);表示上の問題
                       (treeview-select-item selected-hitem)
                       (treeview-select-act-item hitem))))))
    (start-timer *treeview-select-act-item-delay-sec* fn t)))

;;; get-item.l ends here
