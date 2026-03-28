;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; output-dialog.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:28:20 +0900>

;;; Code:

(provide "outline-tree/output-dialog")

(require "outline-tree/outline-tree")
(require "outline-tree/output")
(require "outline-tree/output-html")

(in-package "outline-tree2")

;; header, footer, frame 部分に nil を指定した場合は、デフォルトの関数を用いる
;; header, footer, frame には、関数、文字列、シンボルを指定可能
;;   シンボルに関数が関連づいていれば関数として、そうでなければ変数として扱う。
(defvar *outline-tree-output-html-html-alist*
  '(("デフォルト(CSS変更可)" . (outline-tree-output-html-header
                                outline-tree-output-html-footer
                                outline-tree-output-html-frame))
    ("シンプル(CSS変更不可)" . (outline-tree-output-html-header-simple
                                outline-tree-output-html-footer-simple
                                outline-tree-output-html-frame-simple)))
  "HTML出力: header, footer, frame の定義のセットを指定する。
header, footer, frame 部分に nil を指定した場合は、デフォルトの関数を用いる。
header, footer, frame には、関数、文字列、シンボルを指定可能。
シンボルに関数が関連づいていれば関数として、そうでなければ変数として扱う。")
(defvar *outline-tree-output-html-css-alist*
  '(("デフォルト"  . outline-tree-output-html-css)
    ("ini2cssのみ" . buf2html-get-ini2css-string))
  "HTML出力: CSS を設定する。HTML の header 部出力で用いられる。
関数、文字列、シンボルを指定可能。
シンボルに関数が関連づいていれば関数として、そうでなければ変数として扱う。")

(defun outline-tree-output-html-dialog (&optional arg)
  "HTML 出力用ダイアログを表示
HTML 生成対象のバッファは、引数 arg の指定による。
arg: ノードが渡された場合、ノードの属するバッファ
     バッファが渡された場合、渡されたバッファ
     ウィンドウが渡された場合、ウィンドウが表示しているバッファ
     何も渡されない場合、outline-tree 対象ウィンドウに表示されているバッファ"
  (interactive)
  (let* ((target-buffer (or (outline-tree-get-buffer arg)
                            (outline-tree-get-target-buffer)))
         type-heading-valid-p
         scope-selected-node-valid-p
         (headerfooter-list (mapcar 'car *outline-tree-output-html-html-alist*))
         (css-list (mapcar 'car *outline-tree-output-html-css-alist*))
         (dialog-size-height 160) (dialog-size-width 276)
         dialog-base-side dialog-size
         dialog-base-height dialog-height
         dialog-template
         controls controls-initializers controls-handlers)
    ;; アウトラインの事前チェック
    (unless (outline-tree-output-pre-check target-buffer)
      (return-from outline-tree-output-html-dialog nil))
    ;; 対象バッファのアウトラインに見出しノードが含まれているか確認
    (setq type-heading-valid-p
          (outline-tree-has-heading-node-p target-buffer))
    ;; 対象バッファのバッファノード以外が選択されているか確認
    (setq scope-selected-node-valid-p
          (and (eq (outline-tree-get-buffer-by-node (outline-tree-get-selected-node))
                   target-buffer)
               (not (outline-tree-buffer-node-p (outline-tree-get-selected-node)))))

    ;; controls の生成

    ;; 出力タイプ
    (setq dialog-base-side 4)
    (setq dialog-base-height 4)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "基本タイプ" #x50020007
            ,dialog-base-side ,dialog-height 90 38) controls)
    (incf dialog-height 10)
    (push `(:button type-range "範囲ノード型" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)
    (incf dialog-height 12)
    (push `(:button type-heading "見出しノード型"
            ,(if type-heading-valid-p #x50000009 #x58000009)
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)

    ;; ・「見出しノード」タイプでは、「見出し」に出力した行は「本文」に出力しません。
    ;; ・「範囲ノード」タイプでは、「見出し」に出力した行も「本文」に出力します。

    ;; ・「見出しノード」とは、赤いアイコンのノードです。
    ;; ・「範囲ノード」とは、灰色のノードです。また、「見出しノード」も「範囲ノード」です。

    ;; 「見出しノード」は「範囲ノード」のうち、特殊なノードです。

    ;; 範囲
    (setq dialog-base-side 4)
    (setq dialog-base-height 44)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "対象範囲" #x50020007
            ,dialog-base-side ,dialog-height 90 38) controls)
    (incf dialog-height 10)
    (push `(:button scope-buffer-node "バッファ全体" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)
    (incf dialog-height 12)
    (push `(:button scope-selected-node "選択ノード以下"
            ,(if scope-selected-node-valid-p #x50000009 #x58000009)
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)

    ;; 見出し化
    (setq dialog-base-side 4)
    (setq dialog-base-height 84)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "HTML 見出し化対象" #x50020007
            ,dialog-base-side ,dialog-height 90 38) controls)
    (incf dialog-height 10)
    (push `(:button heading-whole-node "全ノード" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)
    (incf dialog-height 12)
    (push `(:button heading-visible-node "画面上表示ノード" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 62 10) controls)

    ;; HTML 形式
    (setq dialog-base-side 98)
    (setq dialog-base-height 4)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "HTML 形式" #x50020007
            ,dialog-base-side ,dialog-height 90 38) controls)
    (incf dialog-height 10)
    (push `(:button format-single-html "フレーム無し" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)
    (incf dialog-height 12)
    (push `(:button format-frame-html "フレーム有り" #x50000009
            ,(+ dialog-base-side 8) ,dialog-height 58 10) controls)

    ;; カスタマイズ
    (setq dialog-base-side 98)
    (setq dialog-base-height 44)
    (setq dialog-height dialog-base-height)
    (push `(:button nil "カスタマイズ" #x50020007
            ,dialog-base-side ,dialog-height 172 46) controls)
    (incf dialog-height 10)
    (push `(:static nil "ヘッダ・フッタ:" #x50020000
            ,(+ dialog-base-side 8) ,(+ dialog-height 2) 50 8) controls)
    (push `(:combobox headerfooter-list nil  #x50210003
            ,(+ dialog-base-side 52) ,dialog-height 112 96) controls)
    (incf dialog-height 18)
    (push `(:static nil "CSS:" #x50020000
            ,(+ dialog-base-side 8) ,(+ dialog-height 2) 50 8) controls)
    (push `(:combobox css-list nil #x50210003
            ,(+ dialog-base-side 52) ,dialog-height 112 96) controls)

    ;;
    (push `(:button IDOK      "OK"        #x50010001
            ,(- dialog-size-width 120) ,(- dialog-size-height 20) 50 14) controls)
    (push `(:button IDCANCEL "キャンセル" #x50010000
            ,(- dialog-size-width 60) ,(- dialog-size-height 20) 50 14) controls)
    (setq controls (nreverse controls))

    ;; controls-initializers の生成
    (cond (type-heading-valid-p
           (push '(type-heading . t) controls-initializers)
           (push '(type-range . nil) controls-initializers))
          (t
           (push '(type-heading . nil) controls-initializers)
           (push '(type-range . t) controls-initializers)))
    ;
    (push '(scope-buffer-node . t) controls-initializers)
    (push '(scope-selected-node . nil) controls-initializers)
    ;
    (push '(heading-whole-node . t) controls-initializers)
    (push '(heading-visible-node . nil) controls-initializers)
    ;
    (push '(format-single-html . t) controls-initializers)
    (push '(format-frame-html . nil) controls-initializers)
    ;
    (push `(headerfooter-list . ,headerfooter-list) controls-initializers)
    (push '(headerfooter-list . 0) controls-initializers)
    (push `(css-list . ,css-list) controls-initializers)
    (push '(css-list . 0) controls-initializers)

    (setq controls-initializers (nreverse controls-initializers))

    ;; controls-handlers の生成
    (push '(headerfooter-list :index t) controls-handlers)
    (push '(css-list :index t) controls-handlers)
    (setq controls-handlers (nreverse controls-handlers))

    (setq dialog-template
          `(dialog 0 0 ,dialog-size-width ,dialog-size-height
                   (:caption ,(format nil "outline-tree HTML 出力: <~A>"
                                      (buffer-name target-buffer)))
                   (:font 9 "MS UI Gothic")
                   (:control
                    ,@controls)))
    (multiple-value-bind (result data)
        (dialog-box dialog-template
                    controls-initializers
                    controls-handlers)
      (when result
        (let (output-type output-scope output-heading output-frame
              output-custom-html output-custom-css)
          (setq output-type
                (cond ((cdr (assoc 'type-heading data))
                       'type-heading)
                      ((cdr (assoc 'type-range data))
                       'type-range)))
          (setq output-scope
                (cond ((cdr (assoc 'scope-buffer-node data))
                       'scope-buffer-node)
                      ((cdr (assoc 'scope-selected-node data))
                       'scope-selected-node)))
          (setq output-heading
                (cond ((cdr (assoc 'heading-whole-node data))
                       'heading-whole-node)
                      ((cdr (assoc 'heading-visible-node data))
                       'heading-visible-node)))
          (setq output-frame
                (cond ((cdr (assoc 'format-single-html data))
                       'format-single-html)
                      ((cdr (assoc 'format-frame-html data))
                       'format-frame-html)))
          (setq output-custom-html
                (elt *outline-tree-output-html-html-alist*
                     (cdr (assoc 'headerfooter-list data))))
          (setq output-custom-css
                (elt *outline-tree-output-html-css-alist*
                     (cdr (assoc 'css-list data))))

          (outline-tree-output-html
           (if (eq output-type 'type-range) :range :heading)
           (if (eq output-scope 'scope-buffer-node) nil (outline-tree-get-selected-node))
           (if (eq output-heading 'heading-visible-node) :expand nil)
           (if (eq output-frame 'format-frame-html) t nil)
           (or (nth 1 output-custom-html) 'outline-tree-output-html-header)
           (or (nth 2 output-custom-html) 'outline-tree-output-html-footer)
           (or (nth 3 output-custom-html) 'outline-tree-output-html-frame)
           (or (cdr output-custom-css) 'outline-tree-output-html-css))
          nil)))))

;;; output-dialog.l ends here
