;;; -*- Mode: Lisp; Package: TREEVIEW -*-
;;; dialog.l --- treeview

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/03/28 23:07:11 +0900>

;;; Code:

(provide "wip/treeview/dialog")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "wip/treeview/defs")
  (require "wip/treeview/macro"))

(require "wip/color")

(in-package "treeview")

(defun treeview-std-dialog ()
  (interactive)
  (let* (dialog-template
         dialog-base-side dialog-side
         dialog-base-height dialog-height
         controls controls-initializers controls-handlers
         (position-alist `(("上" . ,XPIS_TOP) ("下" . ,XPIS_BOTTOM)
                           ("左" . ,XPIS_LEFT) ("右" . ,XPIS_RIGHT)))
         (color-name-alist (append '(("ユーザ設定" . nil))
                                   ed::*color-all-colors-name-alist*))
         (color-name-list (mapcar #'car color-name-alist))
         )
    (treeview-data-save-window-size)
    (treeview-data-save-style)

    ;; ウィンドウ
    (setq dialog-base-side 4)
    (setq dialog-base-height 4)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "ウィンドウ"
            #x50020007 ,dialog-base-side ,dialog-height 94 56) controls)
    (incf dialog-height 9)
    (push `(:static nil "表示位置(&P):" #x50020000
            ,(+ dialog-base-side 4) ,(+ dialog-height 3) 45  8) controls)
    (push `(:combobox pos nil           #x50210843
            ,(+ dialog-base-side 49) ,dialog-height 40 96) controls)
    (incf dialog-height 14)
    (push `(:static nil "表示幅(&W):"   #x50020000
            ,(+ dialog-base-side 4) ,(+ dialog-height 3) 45  8) controls)
    (push `(:edit width nil             #x50812086
            ,(+ dialog-base-side 49) ,dialog-height 40 14) controls)
    (push `(:spin widthspin nil         #x500000b6
            ,(+ dialog-base-side 89) ,dialog-height  9 14) controls)
    (incf dialog-height 14)
    (push `(:static nil "表示高さ(&H):" #x50020000
            ,(+ dialog-base-side 4) ,(+ dialog-height 3) 45  8) controls)
    (push `(:edit height nil            #x50812086
            ,(+ dialog-base-side 49) ,dialog-height 40 14) controls)
    (push `(:spin heightspin nil        #x500000b6
            ,(+ dialog-base-side 89) ,dialog-height  9 14) controls)

    ;; 表示基準
    (setq dialog-base-side 102)
    (setq dialog-base-height 4)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "表示方法"                                #x50020007
            ,dialog-base-side ,dialog-height 144 56) controls)
    (incf dialog-height 11)
    (push `(:button display-style-xyzzy-size "内部に表示(&X)"     #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 116 12) controls)
    (incf dialog-height 12)
    (push `(:button display-style-xyzzy-position "外部に表示(xyzzyの位置固定)(&V)" #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 116 12) controls)
    (incf dialog-height 12)
    (push `(:button display-style-fixed-editor "外部に表示(エディタ部の位置固定)(&E)" #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 116 12) controls)

    ;; フォント
    (setq dialog-base-side 4)
    (setq dialog-base-height 62)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "フォント"                       #x50020007
            ,dialog-base-side ,dialog-height 104 72) controls)
    (incf dialog-height 9)
    (push `(:button font-facename-manual  "(&1):"        #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 20 14) controls)
    (push `(:combobox font-facename       nil            #x50210843
            ,(+ dialog-base-side 24) ,dialog-height 76 112) controls)
    (incf dialog-height 15)
    (push `(:button font-height-manual    "高さ(&2):"    #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 42 14) controls)
    (push `(:edit   font-height           nil            #x50812086
            ,(+ dialog-base-side 46) ,dialog-height 54 14) controls)
    (push `(:spin   font-height-spin      nil            #x500000b6
            ,(+ dialog-base-side 91) ,dialog-height 9 14) controls)
    (incf dialog-height 15)
    (push `(:button font-bold             "太字(&3)"    #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 40 14) controls)
    (incf dialog-height 15)
    (push `(:button font-italic           "斜体(&4)"     #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 40 14) controls)
    (decf dialog-height 15)
    (push `(:button font-underline        "下線(&5)"     #x50010003
            ,(+ dialog-base-side 54) ,dialog-height 40 14) controls)

    ;; 色
    (setq dialog-base-side 112)
    (setq dialog-base-height 62)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "色"                                    #x50020007
            ,dialog-base-side ,dialog-height 134 72) controls)
    (incf dialog-height 9)
    (push `(:button text-color-manual "文字色(&F):"             #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 40 14) controls)
    (push `(:combobox text-color-name nil                       #x50210843
            ,(+ dialog-base-side 49) ,dialog-height 81 112) controls)
    (incf dialog-height 14)
    (push `(:static nil "RGB" #x50020000
            ,(+ dialog-base-side 33) ,(+ dialog-height 3) 14 8) controls)
    (push `(:edit text-color-R nil                              #x50812086
            ,(+ dialog-base-side 49) ,dialog-height 27 14) controls)
    (push `(:spin text-color-R-spin nil                         #x500000b6
            ,(+ dialog-base-side 49) ,dialog-height  9 14) controls)
    (push `(:edit text-color-G nil                              #x50812086
            ,(+ dialog-base-side 76) ,dialog-height 27 14) controls)
    (push `(:spin text-color-G-spin nil                         #x500000b6
            ,(+ dialog-base-side 76) ,dialog-height  9 14) controls)
    (push `(:edit text-color-B nil                              #x50812086
            ,(+ dialog-base-side 103) ,dialog-height 27 14) controls)
    (push `(:spin text-color-B-spin nil                         #x500000b6
            ,(+ dialog-base-side 103) ,dialog-height  9 14) controls)
    (incf dialog-height 16)
    (push `(:button bk-color-manual "背景色(&B):"               #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 40 14) controls)
    (push `(:combobox bk-color-name nil                         #x50210843
            ,(+ dialog-base-side 49) ,dialog-height 81 112) controls)
    (incf dialog-height 14)
    (push `(:static nil "RGB" #x50020000
            ,(+ dialog-base-side 33) ,(+ dialog-height 3) 14 8) controls)
    (push `(:edit bk-color-R nil                              #x50812086
            ,(+ dialog-base-side 49) ,dialog-height 27 14) controls)
    (push `(:spin bk-color-R-spin nil                         #x500000b6
            ,(+ dialog-base-side 49) ,dialog-height  9 14) controls)
    (push `(:edit bk-color-G nil                              #x50812086
            ,(+ dialog-base-side 76) ,dialog-height 27 14) controls)
    (push `(:spin bk-color-G-spin nil                         #x500000b6
            ,(+ dialog-base-side 76) ,dialog-height  9 14) controls)
    (push `(:edit bk-color-B nil                              #x50812086
            ,(+ dialog-base-side 103) ,dialog-height 27 14) controls)
    (push `(:spin bk-color-B-spin nil                         #x500000b6
            ,(+ dialog-base-side 103) ,dialog-height  9 14) controls)

    ;; スタイル
    (setq dialog-base-side 4)
    (setq dialog-base-height 136)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "スタイル"                              #x50020007
            ,dialog-base-side ,dialog-height 242 94) controls)
    (incf dialog-height 8)
    (push `(:button hasbuttons    "ボタンを表示(&N)"            #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 78 14) controls)
    (incf dialog-height 12)
    (push `(:button haslines      "ラインを表示(&L)"            #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 78 14) controls)
    (incf dialog-height 12)
    (push `(:button linesatroot   "ライン・ボタンをルートから表示(&R)" #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 100 14) controls)
    (incf dialog-height 12)
    (push `(:button checkboxes    "チェックボックスを表示(&C)"  #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 78 14) controls)
    (setq dialog-height (+ dialog-base-height 8))
    (push `(:button tooltips      "ツールチップを表示(&S)"      #x50010003
            ,(+ dialog-base-side 106) ,dialog-height 70 14) controls)
    (incf dialog-height 12)
    (push `(:button trackselect   "トラックセレクト(&T)"        #x50010003
            ,(+ dialog-base-side 106) ,dialog-height 70 14) controls)
    (incf dialog-height 12)
    (push `(:button fullrowselect "一行選択表示*(&O)"           #x50010003
            ,(+ dialog-base-side 106) ,dialog-height 70 14) controls)
    (incf dialog-height 14)
    (push `(:static nil "(* ライン表示時は無効)"                #x50020000
            ,(+ dialog-base-side 108) ,dialog-height 66 8) controls)
    ;
    (setq dialog-height (+ dialog-base-height 8))
    (push `(:button indent-manual "インデント量(&J):"           #x50010003
            ,(+ dialog-base-side 178) ,dialog-height 58 14) controls)
    (incf dialog-height 14)
    (push `(:edit   indent nil                                  #x50812086
            ,(+ dialog-base-side 192) ,dialog-height 40 14) controls)
    (push `(:spin   indent-spin nil                             #x500000b6
            ,(+ dialog-base-side 232) ,dialog-height 9 14) controls)
    ;
    (incf dialog-height 20)
    (push `(:button item-height-manual "高さ(&K):"              #x50010003
            ,(+ dialog-base-side 178) ,dialog-height 58 14) controls)
    (incf dialog-height 14)
    (push `(:edit   item-height nil                             #x50812086
            ,(+ dialog-base-side 192) ,dialog-height 40 14) controls)
    (push `(:spin   item-height-spin nil                        #x500000b6
            ,(+ dialog-base-side 232) ,dialog-height 9 14) controls)
    ;
    (incf dialog-height 4)
    (push `(:button icon          "アイコンを表示(&I)"          #x50010003
            ,(+ dialog-base-side 4) ,dialog-height 64 14) controls)
    (incf dialog-height 14)
    (push `(:static nil           "アイコンディレクトリ(&D):"   #x50020000
            ,(+ dialog-base-side 4) ,(+ dialog-height 2) 68 8) controls)
    (push `(:edit icon-dir nil                                  #x50810480
            ,(+ dialog-base-side 64) ,dialog-height 126 14) controls)
    (push `(:button icon-ref      "参照..."                     #x50010000
            ,(+ dialog-base-side 194) ,dialog-height 28 14) controls)

    ;; スクロール
    (setq dialog-base-side 4)
    (setq dialog-base-height 232)
    ; recenter
    (setq dialog-height dialog-base-height)
    (push `(:button nil "表示行 (recenter) (&U)"                #x50020007
            ,dialog-base-side ,dialog-height 112 52) controls)
    (incf dialog-height 10)
    (push `(:button recenter-nil  "制御しない(&/)"              #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 60 12) controls)
    (incf dialog-height 12)
    (push `(:button recenter-t    "センター(&*)"                #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 60 12) controls)
    (incf dialog-height 12)
    (push `(:button recenter-line "マージン行指定(&#)"          #x50000009
            ,(+ dialog-base-side 4) ,dialog-height 60 12) controls)
    (push `(:edit recenter-line-num nil                         #x50812086
            ,(+ dialog-base-side 66) ,dialog-height 40 12) controls)
    (push `(:spin recenter-spin nil                             #x500000b6
            ,(+ dialog-base-side 66) ,dialog-height 9 12) controls)
    ; scroll-margin
    (setq dialog-height dialog-base-height)
    (setq dialog-base-side 118)
    (push `(:button nil "スクロールマージン(&M)"                #x50020007
            ,dialog-base-side ,dialog-height  66 52) controls)
    (incf dialog-height 10)
    (push `(:static nil "(* 表示行 優先)"             #x50020000
            ,(+ dialog-base-side 6) ,dialog-height 50 8) controls)
    (incf dialog-height 24)
    (push `(:edit scroll-margin nil                             #x50812086
            ,(+ dialog-base-side 14) ,dialog-height 40 12) controls)
    (push `(:spin scroll-margin-spin nil                        #x500000b6
            ,(+ dialog-base-side 14) ,dialog-height 9 12) controls)

    ;; ボタン
    (setq dialog-base-side 4)
    (setq dialog-base-height 290)
    (setq dialog-height dialog-base-height)
    (push `(:button IDOK "OK"  #x50010001
            ,(+ dialog-base-side 135) ,dialog-height 50 14) controls)
    (push `(:button IDCANCEL "キャンセル" #x50010000
            ,(+ dialog-base-side 189) ,dialog-height 50 14) controls)
    
    (setq controls (nreverse controls))
    ;; ----------------------------------------
    ;; controls-initializers の生成
    (let* (position-index
           (font-facename-list (treeview-font-facename-list-get))
           font-facename-index text-color-name-index bk-color-name-index)
      (setq position-index (or (position (treeview-data-get 'treeview::window-position) (mapcar 'cdr position-alist))
                               (position XPIS_LEFT (mapcar 'cdr position-alist))))
      (setq font-facename-index
            (or (position (treeview-data-get 'treeview::font-facename) font-facename-list :test #'equal)
                (position "ＭＳ Ｐゴシック" font-facename-list :test 'string=)
                (position "System" font-facename-list :test 'string=)
                0))

      (push `(pos . ,(mapcar 'car position-alist)) controls-initializers)
      (push `(pos . ,position-index) controls-initializers)
      (push `(width . ,(format nil "~D" (treeview-data-get 'treeview::window-width 200))) controls-initializers)
      (push `(height . ,(format nil "~D" (treeview-data-get 'treeview::window-height 200))) controls-initializers)
      (case (treeview-data-get 'treeview::window-display-style)
        (:xyzzy-position
         (push '(display-style-xyzzy-size . nil) controls-initializers)
         (push '(display-style-xyzzy-position . t) controls-initializers)
         (push '(display-style-fixed-editor . nil) controls-initializers))
        (:fixed-editor
         (push '(display-style-xyzzy-size . nil) controls-initializers)
         (push '(display-style-xyzzy-position . nil) controls-initializers)
         (push '(display-style-fixed-editor . t) controls-initializers))
        (t
         (push '(display-style-xyzzy-size . t) controls-initializers)
         (push '(display-style-xyzzy-position . nil) controls-initializers)
         (push '(display-style-fixed-editor . nil) controls-initializers)))
      (push `(text-color-manual . ,(treeview-data-get 'treeview::color-text-manual-p)) controls-initializers)
      (push `(bk-color-manual . ,(treeview-data-get 'treeview::color-bk-manual-p)) controls-initializers)

      ;; text-color
      (let (rgb index)
        (cond
         ;; RGB 値
         ((numberp (treeview-data-get 'treeview::color-text))
          (setq text-color-name-index 0)
          (setq rgb (treeview-data-get 'treeview::color-text)))
         ;; COLOR NAME 文字列
         ((and (stringp (treeview-data-get 'treeview::color-text))
               (setq index (position (treeview-data-get 'treeview::color-text) color-name-list :test 'string=))
               (cdr (nth index color-name-alist)))
          (setq text-color-name-index index)
          (setq rgb (cdr (nth index color-name-alist))))
         ;; TreeView から取得
         ((and (treeview-exist-p) (plusp (treeview-get-text-color)))
          (setq text-color-name-index 0)
          (setq rgb (ed::color-bgr2rgb (treeview-get-text-color))))
         ;; デフォルト
         (t
          (setq text-color-name-index 0)
          (setq rgb #x000000)))
        (push `(text-color-name . ,color-name-list) controls-initializers)
        (push `(text-color-name . ,text-color-name-index) controls-initializers)
        (push '(text-color-name :index t) controls-handlers)
        (push `(text-color-R . ,(format nil "~D" (floor (mod rgb #x1000000) #x10000))) controls-initializers)
        (push `(text-color-G . ,(format nil "~D" (floor (mod rgb #x10000) #x100))) controls-initializers)
        (push `(text-color-B . ,(format nil "~D" (mod rgb #x100))) controls-initializers))

      ;; bk-color
      (let (rgb index)
        (cond
         ;; RGB 値
         ((numberp (treeview-data-get 'treeview::color-bk))
          (setq bk-color-name-index 0)
          (setq rgb (treeview-data-get 'treeview::color-bk)))
         ;; COLOR NAME 文字列
         ((and (stringp (treeview-data-get 'treeview::color-bk))
               (setq index (position (treeview-data-get 'treeview::color-bk) color-name-list :test 'string=))
               (cdr (nth index color-name-alist)))
          (setq bk-color-name-index index)
          (setq rgb (cdr (nth index color-name-alist))))
         ;; TreeView から取得
         ((and (treeview-exist-p) (plusp (treeview-get-bk-color)))
          (setq bk-color-name-index 0)
          (setq rgb (ed::color-bgr2rgb (treeview-get-bk-color))))
         ;; デフォルト
         (t
          (setq bk-color-name-index 0)
          (setq rgb #xFFFFFF)))
        (push `(bk-color-name . ,color-name-list) controls-initializers)
        (push `(bk-color-name . ,bk-color-name-index) controls-initializers)
        (push '(bk-color-name :index t) controls-handlers)
        (push `(bk-color-R . ,(format nil "~D" (floor (mod rgb #x1000000) #x10000))) controls-initializers)
        (push `(bk-color-G . ,(format nil "~D" (floor (mod rgb #x10000) #x100))) controls-initializers)
        (push `(bk-color-B . ,(format nil "~D" (mod rgb #x100))) controls-initializers))

      (push `(indent-manual . ,(treeview-data-get 'treeview::indent-manual-p)) controls-initializers)
      (let ((indent (treeview-data-get 'treeview::indent 19)))
        (unless (and (integerp indent) (plusp indent))
          (setq indent 19))
        (push `(indent . ,(format nil "~D" indent)) controls-initializers))
      (push `(item-height-manual . ,(treeview-data-get 'treeview::item-height-manual-p)) controls-initializers)
      (let ((item-height (treeview-data-get 'treeview::item-height 16)))
        (unless (and (integerp item-height) (plusp item-height))
          (setq item-height 16))
        (push `(item-height . ,(format nil "~D" item-height)) controls-initializers))

      (push `(hasbuttons . ,(treeview-data-get 'treeview::style-hasbuttons)) controls-initializers)
      (push `(haslines . ,(treeview-data-get 'treeview::style-haslines)) controls-initializers)
      (push `(linesatroot . ,(treeview-data-get 'treeview::style-linesatroot)) controls-initializers)
      (push `(checkboxes . ,(treeview-data-get 'treeview::style-checkboxes)) controls-initializers)
      (push `(trackselect . ,(treeview-data-get 'treeview::style-trackselect)) controls-initializers)
      (push `(fullrowselect . ,(treeview-data-get 'treeview::style-fullrowselect)) controls-initializers)
      (push `(tooltips . ,(treeview-data-get 'treeview::style-tooltips)) controls-initializers)
      (push `(icon . ,(treeview-data-get 'treeview::icon)) controls-initializers)
      (push `(icon-dir . ,(treeview-data-get 'treeview::icon-directory)) controls-initializers)

      (push `(font-facename-manual . ,(treeview-data-get 'treeview::font-facename-manual-p)) controls-initializers)
      (push `(font-facename . ,font-facename-list) controls-initializers)
      (push `(font-facename . ,font-facename-index) controls-initializers)

      (push `(font-height-manual . ,(treeview-data-get 'treeview::font-height-manual-p)) controls-initializers)
      (let ((font-height (treeview-data-get 'treeview::font-height 12)))
        (unless (and (integerp font-height) (plusp font-height))
          (setq font-height 12))
        (push `(font-height . ,(format nil "~D" font-height)) controls-initializers))

      (push `(font-bold . ,(treeview-data-get 'treeview::font-bold)) controls-initializers)
      (push `(font-italic . ,(treeview-data-get 'treeview::font-italic)) controls-initializers)
      (push `(font-underline . ,(treeview-data-get 'treeview::font-underline)) controls-initializers)

      ;; scroll
      (push (case (treeview-data-get 'treeview::recenter)
              ((nil) '(recenter-nil . t))
              (:line '(recenter-line . t))
              (t     '(recenter-t . t)))
            controls-initializers)
      (let ((recenter (treeview-data-get 'treeview::recenter-line 0)))
        (unless (and (integerp recenter) (<= 0 recenter))
          (setq recenter 0))
        (push `(recenter-line-num . ,(format nil "~D" recenter)) controls-initializers))
      (let ((scroll-margin (treeview-data-get 'treeview::scroll-margin 0)))
        (unless (and (integerp scroll-margin) (<= 0 scroll-margin))
          (setq scroll-margin 0))
        (push `(scroll-margin . ,(format nil "~D" scroll-margin)) controls-initializers))
      )

    (setq controls-initializers (nreverse controls-initializers))
    ;; ----------------------------------------

    (push '(width :type integer :min 1 :max 10000 :range-error "1から10000を指定してください") controls-handlers)
    (push '(widthspin :min 1 :max 10000) controls-handlers)
    (push '(height :type integer :min 1 :max 10000 :range-error "1から10000を指定してください") controls-handlers)
    (push '(heightspin :min 1 :max 10000) controls-handlers)

    (push '(text-color-R :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(text-color-R-spin :min 0 :max 255) controls-handlers)
    (push '(text-color-G :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(text-color-G-spin :min 0 :max 255) controls-handlers)
    (push '(text-color-B :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(text-color-B-spin :min 0 :max 255) controls-handlers)

    (push '(bk-color-R :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(bk-color-R-spin :min 0 :max 255) controls-handlers)
    (push '(bk-color-G :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(bk-color-G-spin :min 0 :max 255) controls-handlers)
    (push '(bk-color-B :type integer :min 0 :max 255 :range-error "0から255を指定してください") controls-handlers)
    (push '(bk-color-B-spin :min 0 :max 255) controls-handlers)

    (push '(indent :type integer :min 1 :max 10000 :range-error "1以上を指定してください") controls-handlers)
    (push '(indent-spin :type integer :min 1 :max 10000) controls-handlers)
    (push '(item-height :type integer :min 1 :max 10000 :range-error "1以上を指定してください") controls-handlers)
    (push '(item-height-spin :type integer :min 1 :max 10000) controls-handlers)
    (push '(icon-ref :related icon-dir :directory-name-dialog (:title "アイコンディレクトリ")) controls-handlers)
    (push '(font-height :type integer :min 1 :max 10000 :range-error "1以上を指定してください") controls-handlers)
    (push '(font-height-spin :type integer :min 1 :max 10000) controls-handlers)

    (push '(recenter-line-num :type integer :min 0 :max 10000 :range-error "0以上を指定してください") controls-handlers)
    (push '(recenter-spin :type integer :min 0 :max 10000) controls-handlers)
    (push '(scroll-margin :type integer :min 0 :max 10000 :range-error "0以上を指定してください") controls-handlers)
    (push '(scroll-margin-spin :type integer :min 0 :max 10000) controls-handlers)

    (setq controls-handlers (nreverse controls-handlers))

    ;; ----------------------------------------
    (setq dialog-template
          `(dialog 0 0 250 308
                   (:caption ,(concat (treeview-data-get 'treeview::display-name) " : TreeView 設定"))
                   (:font 9  "MS UI Gothic")
                   (:control
                    ,@controls)))
    (multiple-value-bind (result data)
        (dialog-box dialog-template
                    controls-initializers
                    controls-handlers)
      (when result
        ;; window
        (let ((pos (cdr (assoc (cdr (assoc 'pos data)) position-alist :test #'string=))))
          (unless (equal (treeview-data-get 'treeview::window-position) pos)
            (treeview-setpos pos)))
        (treeview-data-set 'treeview::window-width (cdr (assoc 'width data)))
        (treeview-data-set 'treeview::window-height (cdr (assoc 'height data)))
        (treeview-data-load-window-size)

        (cond
         ((cdr (assoc 'display-style-xyzzy-position data))
          (treeview-data-set 'treeview::window-display-style :xyzzy-position))
         ((cdr (assoc 'display-style-fixed-editor data))
          (treeview-data-set 'treeview::window-display-style :fixed-editor))
         (t
          (treeview-data-set 'treeview::window-display-style nil)))

        ;; font
        (treeview-data-set 'treeview::font-facename-manual-p (cdr (assoc 'font-facename-manual data)))
        (treeview-data-set 'treeview::font-facename (cdr (assoc 'font-facename data)))
        (treeview-data-set 'treeview::font-height-manual-p (cdr (assoc 'font-height-manual data)))
        (treeview-data-set 'treeview::font-height (cdr (assoc 'font-height data)))
        (treeview-data-set 'treeview::font-bold (cdr (assoc 'font-bold data)))
        (treeview-data-set 'treeview::font-italic (cdr (assoc 'font-italic data)))
        (treeview-data-set 'treeview::font-underline (cdr (assoc 'font-underline data)))
        (treeview-data-load-font)

        ;; text-color
        (treeview-data-set 'treeview::color-text-manual-p
                           (cdr (assoc 'text-color-manual data)))
        (let* ((index (cdr (assoc 'text-color-name data)))
               (color-name (elt color-name-list index))
               bgr r g b)
          (cond
           ;; ユーザ設定 (index == 0)
           ((= index 0)
            (setq r (cdr (assoc 'text-color-R data)))
            (setq g (cdr (assoc 'text-color-G data)))
            (setq b (cdr (assoc 'text-color-B data)))
            (setq bgr (+ (* b #x10000) (* g #x100) r))
            (treeview-data-set 'treeview::color-text (ed::color-bgr2rgb bgr)))
           ;; 有効な COLOR NAME 文字列
           ((cdr (assoc color-name color-name-alist :test 'string=))
            (setq bgr (ed::color-rgb2bgr (cdr (assoc color-name color-name-alist :test 'string=))))
            (treeview-data-set 'treeview::color-text color-name))))
        ;; bk-color
        (treeview-data-set 'treeview::color-bk-manual-p
                           (cdr (assoc 'bk-color-manual data)))
        (let* ((index (cdr (assoc 'bk-color-name data)))
               (color-name (elt color-name-list index))
               bgr r g b)
          (cond
           ;; ユーザ設定 (index == 0)
           ((= index 0)
            (setq r (cdr (assoc 'bk-color-R data)))
            (setq g (cdr (assoc 'bk-color-G data)))
            (setq b (cdr (assoc 'bk-color-B data)))
            (setq bgr (+ (* b #x10000) (* g #x100) r))
            (treeview-data-set 'treeview::color-bk (ed::color-bgr2rgb bgr)))
           ;; 有効な COLOR NAME 文字列
           ((cdr (assoc color-name color-name-alist :test 'string=))
            (setq bgr (ed::color-rgb2bgr (cdr (assoc color-name color-name-alist :test 'string=))))
            (treeview-data-set 'treeview::color-bk color-name))))
        (treeview-data-load-color)

        ;; style
        (treeview-data-set 'treeview::style-hasbuttons (cdr (assoc 'hasbuttons data)))
        (treeview-data-set 'treeview::style-haslines (cdr (assoc 'haslines data)))
        (treeview-data-set 'treeview::style-linesatroot (cdr (assoc 'linesatroot data)))
        (treeview-data-set 'treeview::style-checkboxes (cdr (assoc 'checkboxes data)))
        (treeview-data-set 'treeview::style-trackselect (cdr (assoc 'trackselect data)))
        (treeview-data-set 'treeview::style-fullrowselect (cdr (assoc 'fullrowselect data)))
        (treeview-data-set 'treeview::style-tooltips (cdr (assoc 'tooltips data)))
        (treeview-data-load-style)

        ;; indent
        (treeview-data-set 'treeview::indent-manual-p (cdr (assoc 'indent-manual data)))
        (treeview-data-set 'treeview::indent (cdr (assoc 'indent data)))
        (treeview-data-load-indent)

        ;; height
        (treeview-data-set 'treeview::item-height-manual-p (cdr (assoc 'item-height-manual data)))
        (treeview-data-set 'treeview::item-height (cdr (assoc 'item-height data)))
        (treeview-data-load-item-height)

        ;; icon
        (treeview-data-set 'treeview::icon (cdr (assoc 'icon data)))
        (treeview-data-set 'treeview::icon-directory (cdr (assoc 'icon-dir data)))
        (let ((func (treeview-data-get 'treeview::initialize-icons-func)))
          (when func (funcall func)))

        ;; scroll
        (cond
         ((cdr (assoc 'recenter-nil data))
          (treeview-data-set 'treeview::recenter nil))
         ((cdr (assoc 'recenter-line data))
          (treeview-data-set 'treeview::recenter :line))
         ((cdr (assoc 'recenter-t data))
          (treeview-data-set 'treeview::recenter t)))
        (treeview-data-set 'treeview::recenter-line (cdr (assoc 'recenter-line-num data)))
        (treeview-data-set 'treeview::scroll-margin (cdr (assoc 'scroll-margin data)))

        nil))))

;;; dialog.l ends here
