;;; -*- Mode: Lisp; Package: TREEVIEW -*-
;;; base.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/12/28 23:21:17 +0900>

;;; Commentary:

;; Description:
;;
;;  操作対象の treeview-id への操作を行うように設定した関数群の記述。
;;  主に、以下の 2 点を行っている。
;;    ・dll.l で記述された「treeview-id を明示的に指定した呼び出し」を
;;      treeview-id を渡さなくてよいようにラッピング。
;;    ・winapi 呼び出しをラッピング。
;;

;;; Code:

(provide "wip/treeview/base")

(require "wip/treeview/defs")
(require "wip/treeview/dll")

(in-package "treeview")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Application 認識用 ID
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-app-id-register (app-id)
  "app-id の登録"
  (unless (treeview-app-id-registered-p app-id)
    (pushnew app-id *treeview-app-id-list*)
    (setf (gethash app-id *treeview-app-to-treeview-hash*) nil)
    t))
(defun treeview-app-id-unregister (app-id)
  "app-id の削除"
  (when (treeview-app-id-registered-p app-id)
    (setq *treeview-app-id-list* (delete app-id *treeview-app-id-list*))
    (remhash app-id *treeview-app-to-treeview-hash*)
    (treeview-data-del-all)
    t))
(defun treeview-app-id-registered-p (app-id)
  "app-id が登録されているか"
  (multiple-value-bind (val exist)
      (gethash app-id *treeview-app-to-treeview-hash*)
    exist))
(defun treeview-app-id-set-treeview-id (app-id treeview-id)
  "app-id と treeview-id を関連付ける"
  (treeview-app-id-register app-id)
  (unless (gethash app-id *treeview-app-to-treeview-hash*)
    (setf (gethash app-id *treeview-app-to-treeview-hash*) treeview-id)
    (setf (gethash treeview-id *treeview-treeview-to-app-hash*) app-id)))
(defun treeview-app-id-unset-treeview-id (app-id)
  "app-id と treeview-id の関係を無効化する"
  (let ((treeview-id (gethash app-id *treeview-app-to-treeview-hash*)))
    (when treeview-id
      (remhash app-id *treeview-app-to-treeview-hash*)
      (remhash treeview-id *treeview-treeview-to-app-hash*)
      treeview-id)))
(defun treeview-app-id-get-treeview-id (app-id)
  "app-id から treeview-id を取得する"
  (gethash app-id *treeview-app-to-treeview-hash*))
(defun treeview-treeview-id-get-app-id (treeview-id)
  "treeview-id から app-id を取得する"
  (gethash treeview-id *treeview-treeview-to-app-hash*))

(defun treeview-get-active-app-id ()
  "アクティブ状態の app-id を取得"
  (treeview-treeview-id-get-app-id (treeview-get-active-treeview-id)))

(defun treeview-get-treeview-id-list ()
  "登録されている treeview-id のリストを取得"
  (let (treeview-id treeview-id-list)
    (dolist (app-id *treeview-app-id-list*)
      (when (setq treeview-id (treeview-app-id-get-treeview-id app-id))
        (push treeview-id treeview-id-list)))
    (nreverse treeview-id-list)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; treeview (app) 毎 data 管理
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#|
■2005.02.16 時点での tag 情報
□内部使用
<base>
treeview::window-position
treeview::open-window-size

<frame-work>
treeview::keydown-callback-key-str
treeview::keydown-callback-keymap
treeview::window-width
treeview::window-height

<macro>
treeview::suppress-redraw-count

<setfont>
treeview::hfont

□外部使用 (ユーザによる設定)
<dialog>
treeview::window-width
treeview::window-height
treeview::window-display-style
treeview::font-facename-manual-p
treeview::font-facename
treeview::font-height-manual-p
treeview::font-height
treeview::font-bold
treeview::font-italic
treeview::font-underline
treeview::color-text-manual-p
treeview::color-text
treeview::color-bk-manual-p
treeview::color-bk
treeview::style-hasbuttons
treeview::style-haslines
treeview::style-linesatroot
treeview::style-checkboxes
treeview::style-trackselect
treeview::style-fullrowselect
treeview::style-tooltips
treeview::indent-manual-p
treeview::indent
treeview::item-height-manual-p
treeview::item-height
treeview::icon
treeview::icon-directory
treeview::recenter
treeview::recenter-line
treeview::scroll-margin

□内部/外部で共に使用
treeview::window-width
treeview::window-height

|#
(defun treeview-data-reference-set (tag symbol)
  "現在の app-id で、tag に対応する変数の symbol を設定する"
  (let (hash)
    (unless (setq hash (gethash *treeview-app-id* *treeview-data-reference-hash*))
      (setq hash (make-hash-table :test #'equal))
      (setf (gethash *treeview-app-id* *treeview-data-reference-hash*) hash))
    (setf (gethash tag hash) symbol)))
(defun treeview-data-reference-get (tag)
  "現在の app-id で、tag に対応する変数の symbol を取得する"
  (let ((hash (gethash *treeview-app-id* *treeview-data-reference-hash*)))
    (when hash
      (gethash tag hash))))
(defun treeview-data-reference-del (tag)
  "現在の app-id で、tag に対応する変数の symbol を解除する"
  (let ((hash (gethash *treeview-app-id* *treeview-data-reference-hash*)))
    (when hash
      (remhash tag hash))))
(defun treeview-data-reference-enum ()
  "現在の app-id で、tag と対応する変数の symbol のペアの一覧を返す"
  (let (hash lst)
    (when (setq hash (gethash *treeview-app-id* *treeview-data-reference-hash*))
      (maphash #'(lambda (key data)
                   (push (cons key (treeview-data-reference-get key)) lst))
               hash))
    (sort lst #'string< :key #'(lambda (x) (string (car x))))))

(defun treeview-data-set (tag value)
  "現在の app-id で、tag に対応する value を設定する"
  (let ((reference-symbol (treeview-data-reference-get tag))
        (hash (gethash *treeview-app-id* *treeview-data-hash*)))
    (unless hash
      (setq hash (make-hash-table :test #'equal))
      (setf (gethash *treeview-app-id* *treeview-data-hash*) hash))
    (if reference-symbol
        (progn
          (setf (gethash tag hash) nil)
          (set reference-symbol value))
      (setf (gethash tag hash) value))))
(defun treeview-data-get (tag &optional default)
  "現在の app-id で、tag に対応する value を取得する"
  (let ((reference-symbol (treeview-data-reference-get tag))
        hash)
    (if reference-symbol
        (if (boundp reference-symbol)
            (values (symbol-value reference-symbol) t)
          (values default nil))
      (progn
        (setq hash (gethash *treeview-app-id* *treeview-data-hash*))
        (if hash
            (gethash tag hash default)
          (values default nil))))))
(defun treeview-data-del (tag)
  "現在の app-id で、tag に対応する value を削除する"
  (let ((reference-symbol (treeview-data-reference-get tag))
        (hash (gethash *treeview-app-id* *treeview-data-hash*)))
    (when reference-symbol
      (treeview-data-reference-del tag))
    (when hash
      (remhash tag hash))))
(defun treeview-data-del-all ()
  "現在の app-id で、全ての、tag に対応する変数の symbol, value を削除する"
  (remhash *treeview-app-id* *treeview-data-reference-hash*)
  (remhash *treeview-app-id* *treeview-data-hash*))
(defun treeview-data-enum ()
  "現在の app-id で、tag と対応する value のペアの一覧を返す"
  (let (hash lst)
    (when (setq hash (gethash *treeview-app-id* *treeview-data-reference-hash*))
      (maphash #'(lambda (key data)
                   (push (cons key (treeview-data-get key)) lst))
               hash))
    (when (setq hash (gethash *treeview-app-id* *treeview-data-hash*))
      (maphash #'(lambda (key data)
                   (pushnew (cons key (treeview-data-get key)) lst
                            :key #'car :test #'equal))
               hash))
    (sort lst #'string< :key #'(lambda (x) (string (car x))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 主に dll wrap/拡張
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-exist-p ()
  "treeview が存在するか
    nil: 存在しない
non-nil: 存在する"
  (and (not (or (null *treeview-id*) (eql *treeview-id* 0)))
       (not (zerop (treeview-get-hwnd)))))

(defun treeview-create (app-id)
  "treeview を作成する"
  (when (treeview-app-id-get-treeview-id app-id)
    (return-from treeview-create nil))
  (treeview-create-1 app-id
                     (treeview-dll-create (get-window-handle) (si:plugin-arg))
                     XPIS_LEFT))
(defun treeview-create-ex (app-id &optional (size 400) (pos XPIS_LEFT))
  "treeview をサイズ、位置を指定して作成する"
  (when (treeview-app-id-get-treeview-id app-id)
    (return-from treeview-create-ex nil))
  (treeview-create-1 app-id
                     (treeview-dll-create-ex (get-window-handle)
                                             (si:plugin-arg) size pos)
                     pos))
(defun treeview-create-1 (app-id treeview-id pos)
  "treeview を作成するための内部関数"
  (treeview-app-id-set-treeview-id app-id treeview-id)
  (with-app (app-id)
    (treeview-data-set 'treeview::window-position pos)
    ;;
    (treeview-data-load-window-size)
    (treeview-data-load-color)
    (treeview-data-load-font)
    (treeview-data-load-style)
    (treeview-data-load-indent)
    (treeview-data-load-item-height)
    ;; display style
    (treeview-effect-window-display-style-on-create)
    ;; icon
    (let ((func (treeview-data-get 'treeview::initialize-icons-func)))
      (when func (funcall func)))
    ;; keydown
    (treeview-disable-char-jump t)
    ;; mouse
    (treeview-set-std-click-callback)
    (treeview-set-std-dblclk-callback)
    (treeview-set-std-rclick-callback)
    ;; keymap
    (treeview-set-std-keydown-callback)
    ;; treeview-app-bar
    (treeview-app-bar-add-item app-id (treeview-open-p)))
  treeview-id)
(defun treeview-delete ()
  "treeview を削除する"
  (treeview-data-save-window-size)
  (treeview-data-save-style)
  (treeview-effect-window-display-style-on-delete)
  (run-hooks '*treeview-delete-hook*)
  (when (and (integerp *treeview-id*) (plusp *treeview-id*))
    (treeview-dll-delete *treeview-id*))
  (treeview-app-bar-del-item *treeview-app-id*)
  (treeview-app-id-unset-treeview-id *treeview-app-id*))
(defun treeview-get-hwnd ()
  "treeview の hwnd を取得する(外側のウィンドウ)"
  ;; treeview-exist-p にて treeview-get-hwnd を使用しているため
  ;; *treeview-id* で判定
  (when *treeview-id*  
    (treeview-dll-get-hwnd *treeview-id*)))
(defun treeview-get-htree ()
  "treeview の htree の hwnd を取得する(内側のウィンドウ)"
  ;; treeview-get-hwnd との対称性を考慮指定 *treeview-id* で判定
  (when *treeview-id*
    (treeview-dll-get-htree *treeview-id*)))
(defun treeview-modify-style (remove add flags)
  "treeview の sytle を変更する"
  (treeview-dll-modify-style *treeview-id* remove add flags))
(defun treeview-setsize (size min max step)
  "treeview の size を設定する"
  (treeview-dll-setsize *treeview-id* size min max step))
(defun treeview-setpos (pos)
  "treeview の位置(上下左右)を設定する"
  (treeview-data-save-window-size)
  (treeview-data-set 'treeview::window-position pos)
  (when (treeview-exist-p)
    (treeview-dll-setpos *treeview-id* pos))
  (treeview-data-load-window-size)
  (when (treeview-exist-p)
    (treeview-refresh-screen-force)
    (treeview-suppress-redraw
     (treeview-recenter))))

(defun treeview-get-count ()
  "treeview の item の数を取得。"
  (treeview-dll-get-count *treeview-id*))
(defun treeview-get-next-item (hitem code)
  "item の次のアイテムを取得。"
  (treeview-dll-get-next-item *treeview-id* hitem code))
(defun treeview-get-indent ()
  "treeview の item の indent 幅を取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETINDENT 0 0))
(defun treeview-set-indent (indent)
  "treeview の item の indent 幅を設定。
引数 indent に整数以外が与えられた場合は 0 とみなし、treeview の
デフォルトインデント幅に戻す"
  (unless (integerp indent)
    (setq indent 0))
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETINDENT indent 0))
(defun treeview-item-has-children (hitem)
  "hitem が子 item を持っているかを取得。(1 or 0)
子itemを持っている場合は 1、持っていない場合は 0 を返す。"
  (treeview-dll-item-has-children *treeview-id* hitem))
(defun treeview-item-has-children-p (hitem)
  "hitem が子 item を持っているかを取得。(t or nil)"
  (not (zerop (treeview-item-has-children hitem))))
(defun treeview-get-item (pitem); TVITEM*
  "TVITEM 構造体へのポインタを渡し、item を取得。"
  (treeview-dll-get-item *treeview-id* pitem))
(defun treeview-set-item (hitem mask text icon sicon state statemask lparam)
  "item に各種値を設定。"
  (treeview-dll-set-item *treeview-id* hitem mask (si:make-string-chunk text) icon sicon state statemask lparam))
(defun treeview-get-item-state (hitem statemask)
  "item の state を取得。"
  (treeview-dll-get-item-state *treeview-id* hitem statemask))
(defun treeview-set-item-state (hitem state statamask)
  "item に state を設定。"
  (treeview-dll-set-item-state *treeview-id* hitem state statemask))
(defun treeview-get-item-text (hitem &optional (maxlen 256))
  "item の text を取得。"
  (let ((text (si:make-chunk nil maxlen)))
    (treeview-dll-get-item-text *treeview-id* hitem text maxlen)
    (si:unpack-string text 0)))
(defun treeview-set-item-text (hitem text)
  "item に text を設定。"
  (treeview-dll-set-item-text *treeview-id* hitem (si:make-string-chunk text)))
(defun treeview-get-item-data (hitem)
  "item の Application 固有データを取得。"
  (treeview-dll-get-item-data *treeview-id* hitem))
(defun treeview-set-item-data (hitem data)
  "item に Application 固有データを設定。"
  (treeview-dll-set-item-data *treeview-id* hitem data))
(defun treeview-get-item-rect (hitem &optional textonly)
  "item の座標を取得。(座標順序は 左上右下)"
  (let ((wr (winapi:make-RECT)))
    (if (or (null textonly) (equal textonly 0))
        (setq textonly 0)
      (setq textonly 1))
    (setf (winapi:RECT-left wr) hitem)
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETITEMRECT textonly wr)
    (list (winapi:RECT-left wr)
          (winapi:RECT-top wr)
          (winapi:RECT-right wr)
          (winapi:RECT-bottom wr))))

(defun treeview-get-visible-count ()
  "treeview に縦に表示可能な item の数を取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETVISIBLECOUNT 0 0))

(defun treeview-get-bk-color ()
  "treeview の背景色(BBGGRR)を取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETBKCOLOR 0 0))
(defun treeview-set-bk-color (color)
  "treeview の背景色(BBGGRR)を設定。"
  (cond
   ((eq color t)
    (setq color winapi:CLR_DEFAULT))
   ((eq color nil)
    (setq color winapi:CLR_NONE)))
  (unless (eql color (treeview-get-bk-color))
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETBKCOLOR color color)
    (winapi:RedrawWindow (treeview-get-htree) 0 0
                         (logior winapi:RDW_INVALIDATE winapi:RDW_ALLCHILDREN winapi:RDW_UPDATENOW))))
(defun treeview-get-item-height ()
  "item の高さを取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETITEMHEIGHT 0 0))
(defun treeview-set-item-height (height)
  "item の高さを設定。"
  (unless (integerp height)
    (setq height -1))
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETITEMHEIGHT height 0))

(defun treeview-get-text-color ()
  "treeview の文字色(BBGGRR)を取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETTEXTCOLOR 0 0))
(defun treeview-set-text-color (color)
  "treeview の文字色(BBGGRR)を設定。"
  (cond
   ((eq color t)
    (setq color winapi:CLR_DEFAULT))
   ((eq color nil)
    (setq color winapi:CLR_NONE)))
  (unless (eql color (treeview-get-text-color))
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETTEXTCOLOR color color)
    (winapi:RedrawWindow (treeview-get-htree) 0 0
                         (logior winapi:RDW_INVALIDATE winapi:RDW_ALLCHILDREN winapi:RDW_UPDATENOW))))
(defun treeview-set-insert-mark (hitem &optional (after 1))
  "treeview に insert-mark を設定。"
  (unless (treeview-hitem-valid-p hitem)
    (setq hitem 0))
  (if (or (eq after nil) (and (integerp after) (zerop after)))
      (setq after 0)
    (setq after 1))
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETINSERTMARK after hitem))
(defun treeview-get-insert-mark-color ()
  "treeview の insert-mark の色(BBGGRR)を取得。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_GETINSERTMARKCOLOR 0 0))
(defun treeview-set-insert-mark-color (color)
  "treeview の insert-mark の色(BBGGRR)を設定。"
  (cond
   ((eq color t)
    (setq color winapi:CLR_DEFAULT))
   ((eq color nil)
    (setq color winapi:CLR_NONE)))
  (unless (eql color (treeview-get-insert-mark-color))
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_SETINSERTMARKCOLOR color color)
    (winapi:RedrawWindow (treeview-get-htree) 0 0
                         (logior winapi:RDW_INVALIDATE winapi:RDW_ALLCHILDREN winapi:RDW_UPDATENOW))))
(defun treeview-insert-item (text parent &key icon sicon (insertafter winapi:TVI_LAST)
                                  (state 0) (statemask 0) (lparam 0))
  "treeview に item を追加。"
  (let ((mask winapi:TVIF_TEXT))
    (if (null icon)
        (setq icon 0)
      (setq mask (logior mask winapi:TVIF_IMAGE)))
    (if (null sicon)
        (setq sicon 0)
      (setq mask (logior mask winapi:TVIF_SELECTEDIMAGE)))
    (treeview-dll-insert-item
     *treeview-id* mask (si:make-string-chunk text) icon sicon state statemask lparam parent insertafter)))
(defun treeview-delete-item (hitem)
  "treeview から item を削除。"
  (treeview-dll-delete-item *treeview-id* hitem))
(defun treeview-delete-all-items ()
  "treeview から全ての item を削除。"
  (treeview-dll-delete-all-items *treeview-id*))
(defun treeview-expand (hitem code)
  "item の開閉状態を設定。"
  (treeview-dll-expand *treeview-id* hitem code))
(defun treeview-select (hitem code)
  "item を、指定された code の方法で選択。"
  (treeview-dll-select *treeview-id* hitem code))
(defun treeview-select-item (hitem)
  "item を選択。"
  (treeview-dll-select *treeview-id* hitem winapi:TVGN_CARET))
(defun treeview-select-drop-target (hitem)
  "ドラッグアンドドロップ操作のターゲットとして item を再描画。"
  (treeview-dll-select *treeview-id* hitem winapi:TVGN_DROPHILITE))
(defun treeview-select-set-first-visible (hitem)
  "item を、最初の可視のアイテムとして選択。"
  (treeview-dll-select *treeview-id* hitem winapi:TVGN_FIRSTVISIBLE))
(defun treeview-edit-label (hitem)
  "item のテキストをインプレイス編集。"
  (treeview-dll-edit-label *treeview-id* hitem))
(defun treeview-hittest ()
  "現在のカーソル位置にある item を取得。
item がない場合は 0 を返す。"
  (let ((tvhittestinfo (winapi:make-TVHITTESTINFO))
        (po (winapi::make-POINT))
        (wr (winapi::make-RECT)))
    (winapi::GetCursorPos po)
    (winapi::GetWindowRect (treeview-get-htree) wr)
    (setf (winapi::POINT-x (winapi:TVHITTESTINFO-pt tvhittestinfo))
          (- (winapi::POINT-x po) (winapi::RECT-left wr)))
    (setf (winapi::POINT-y (winapi:TVHITTESTINFO-pt tvhittestinfo))
          (- (winapi::POINT-y po) (winapi::RECT-top wr)))
    (winapi:SendMessage (treeview-get-htree) winapi:TVM_HITTEST 0 tvhittestinfo)))
(defun treeview-sort-children (hitem)
  "指定 item の子 item を text 順にソート。"
  (treeview-dll-sort-children *treeview-id* hitem))
(defun treeview-ensure-visible (hitem)
  "親 item の展開、treeview のスクロールを行い item を表示。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_ENSUREVISIBLE 0 hitem))
(defun treeview-sort-children-cb (psort)
  "TVSORTCB 構造体へのポインタを渡し、任意の方法で item をソート。"
  (winapi:SendMessage (treeview-get-htree) winapi:TVM_SORTCHILDRENCB 0 psort))

;;
(let (callback)
  (c:defun-c-callable c:void treeview-click-callback-imp ((winapi:HTREEITEM hitem))
    (funcall callback hitem))
  (defun treeview-click-callback (fn)
    "treeview 上で左クリック時のコールバック関数を設定。"
    (setq callback fn)
    (not (zerop (treeview-dll-set-click-callback *treeview-id* #'treeview-click-callback-imp)))))
(let (callback)
  (c:defun-c-callable c:void treeview-dblclk-callback-imp ((winapi:HTREEITEM hitem))
    (funcall callback hitem))
  (defun treeview-dblclk-callback (fn)
    "treeview 上で左ダブルクリック時のコールバック関数を設定。"
    (setq callback fn)
    (not (zerop (treeview-dll-set-dblclk-callback *treeview-id* #'treeview-dblclk-callback-imp)))))
(let (callback)
  (c:defun-c-callable c:void treeview-rclick-callback-imp ((winapi:HTREEITEM hitem))
    (funcall callback hitem))
  (defun treeview-rclick-callback (fn)
    "treeview 上で右クリック時のコールバック関数を設定。"
    (setq callback fn)
    (not (zerop (treeview-dll-set-rclick-callback *treeview-id* #'treeview-rclick-callback-imp)))))
(let (callback)
  (c:defun-c-callable c:void treeview-keydown-callback-imp ((winapi:HTREEITEM hitem) (winapi:WORD vkey) (winapi:UINT flag))
    (funcall callback hitem vkey flag))
  (defun treeview-keydown-callback (fn)
    "treeview 上でキー押下時のコールバック関数を設定。"
    (setq callback fn)
    (not (zerop (treeview-dll-set-keydown-callback *treeview-id* #'treeview-keydown-callback-imp)))))
#|
(defun treeview-keydown-callback (fn)
  (let ((callback-imp-symbol (gensym)))
    (eval
     `(progn
        (c:defun-c-callable c:void ,callback-imp-symbol ((winapi:HTREEITEM hitem) (winapi:WORD vkey) (winapi:UINT flag))
          (funcall ,fn hitem vkey flag))
        (not (zerop (treeview-dll-set-keydown-callback *treeview-id* (function ,callback-imp-symbol))))))))
|#
(let ((callback) (maxlen 256))
  (c:defun-c-callable c:void treeview-edit-label-callback-imp ((winapi:HTREEITEM hitem) (winapi:LPCTSTR text))
    (funcall callback hitem (si:unpack-string (si:make-chunk nil maxlen nil text) 0)))
  (defun treeview-edit-label-callback (fn)
    "treeview 上で item のテキスト編集時のコールバック関数を設定。"
    (setq callback fn)
    (not (zerop (treeview-dll-set-edit-label-callback *treeview-id* #'treeview-edit-label-callback-imp)))))

;;
(defun treeview-add-file-icon (filepath)
  "treeview にアイコンを登録。"
  (treeview-dll-add-file-icon *treeview-id* (si:make-string-chunk filepath)))
(defun treeview-set-item-icon (hitem icon sicon)
  "item にアイコンを設定。"
  (if (null icon)
      (setq icon 0))
  (if (null sicon)
      (setq sicon 0))
  (treeview-dll-set-item *treeview-id* hitem (logior winapi:TVIF_IMAGE winapi:TVIF_SELECTEDIMAGE) 0 icon sicon 0 0 0))
(defun treeview-remove-icon (icon)
  "treeview からアイコンを削除。"
  (treeview-dll-remove-icon *treeview-id* icon))
(defun treeview-remove-all-icons ()
  "treeview から全てのアイコンを削除。"
  (treeview-dll-remove-all-icons *treeview-id*))
(defun treeview-simple-track-popup-menu (menu-format)
  "treeview でポップアップメニューを表示。(使用非推奨)"
  (treeview-dll-simple-track-popup-menu (si:make-string-chunk menu-format)))
(defun treeview-disable-char-jump (&optional (disable t))
  "treeview 上で英数字キーを押下した際に item へジャンプする挙動を抑止。"
  (treeview-dll-disable-char-jump *treeview-id* (if disable 1 0)))

;; ----------------------------------------------------------------------
;; 追加
(defvar *treeview-expand-expand-pre-hook* nil
  "treeview-expand-expand で item 展開前の hook")
(defvar *treeview-expand-expand-hook* nil
  "treeview-expand-expand で item 展開後のhook")
(defun treeview-expand-p (hitem)
  "item が展開しているか。
展開時 non-nil。非展開時 nil。"
  (not (zerop (logand winapi:TVIS_EXPANDED (treeview-dll-get-item-state *treeview-id* hitem 0)))))
(defun treeview-expand-expand (hitem &key sibling child visible (depth t))
  "item を展開。
DEPTH: CHILD 指定がある場合、何階層 expand するかを指定
       t          全て展開
       <integer>  指定階層数展開 (絶対値ではなく相対値)"
  (labels ((treeview-expand-expand-child (hitem depth)
             (when (or (eq depth t)
                       (and (integerp depth) (<= 0 (decf depth))))
               (let (child-hitem)
                 (run-hook-with-args '*treeview-expand-expand-pre-hook* hitem)
                 (treeview-dll-expand *treeview-id* hitem winapi:TVE_EXPAND)
                 (run-hook-with-args '*treeview-expand-expand-hook* hitem)
                 (when (or (eq depth t) (and (integerp depth) (plusp depth)))
                   (setq child-hitem (treeview-get-child-item hitem))
                   (while (and child-hitem (not (zerop child-hitem)))
                     (treeview-expand-expand-child child-hitem depth)
                     (setq child-hitem (treeview-get-next-sibling-item child-hitem))))))))
    (let (sibling-hitem)
      (cond
       (sibling
        (setq sibling-hitem (treeview-get-child-item (treeview-get-parent-item hitem)))
        (while (and sibling-hitem (not (zerop sibling-hitem)))
          (if child
              (treeview-expand-expand-child sibling-hitem depth)
            (progn
              (run-hook-with-args '*treeview-expand-expand-pre-hook* hitem)
              (treeview-dll-expand *treeview-id* sibling-hitem winapi:TVE_EXPAND)
              (run-hook-with-args '*treeview-expand-expand-hook* hitem)))
          (setq sibling-hitem (treeview-get-next-sibling-item sibling-hitem))))
       (child
        (treeview-expand-expand-child hitem depth))
       (t
        (run-hook-with-args '*treeview-expand-expand-pre-hook* hitem)
        (treeview-dll-expand *treeview-id* hitem winapi:TVE_EXPAND)
        (run-hook-with-args '*treeview-expand-expand-hook* hitem)))))
  (if visible
      (treeview-ensure-visible hitem)))
(defun treeview-expand-collapse (hitem &key sibling child visible)
  "item を閉じる。"
  (labels ((treeview-expand-collapse-child (hitem)
             (let (child-hitem)
               (treeview-dll-expand *treeview-id* hitem winapi:TVE_COLLAPSE)
               (setq child-hitem (treeview-get-child-item hitem))
               (while (and child-hitem (not (zerop child-hitem)))
                 (treeview-expand-collapse-child child-hitem)
                 (setq child-hitem (treeview-get-next-sibling-item child-hitem))))))
    (let (sibling-hitem)
      (cond
       (sibling
        (setq sibling-hitem (treeview-get-child-item (treeview-get-parent-item hitem)))
        (while (and sibling-hitem (not (zerop sibling-hitem)))
          (if child
              (treeview-expand-collapse-child sibling-hitem)
            (treeview-dll-expand *treeview-id* sibling-hitem winapi:TVE_COLLAPSE))
          (setq sibling-hitem (treeview-get-next-sibling-item sibling-hitem))))
       (child
        (treeview-expand-collapse-child hitem))
       (t
        (treeview-dll-expand *treeview-id* hitem winapi:TVE_COLLAPSE)))))
  (if visible
      (treeview-ensure-visible hitem)))
(defun treeview-expand-toggle (hitem &key sibling child visible)
  "item の開閉状態をトグル。
自身が子 item を持たない場合は、子 item を持つ長兄 item の状態によって
開閉する状態をトグルする。"
  (let ((h1 hitem) h2 flag)
    (if (treeview-hitem-equal h1 winapi:TVGN_ROOT)
        (setq h1 (treeview-get-child-item h1)))
    (unless (treeview-item-has-children-p h1)
      (while (treeview-hitem-valid-p
              (setq h2 (treeview-get-prev-sibling-item h1)))
        (setq h1 h2))
      (while (and (not (treeview-item-has-children-p h1))
                  (treeview-hitem-valid-p
                   (setq h2 (treeview-get-next-sibling-item h1))))
        (setq h1 h2)))
    (if (treeview-expand-p h1)
        (treeview-expand-collapse hitem :sibling sibling :child child :visible visible)
      (treeview-expand-expand hitem :sibling sibling :child child :visible visible))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-close-hook* nil
  "treeview-close 実行後の hook")
(defvar *treeview-open-hook* nil
  "treeview-open 実行後の hook")
(defvar *treeview-window-size-min* 5
  "treeview-close 時の window size")
(defvar *treeview-window-size-threshold* 20
  "treeview が close していると見なす size の閾値")
(defvar *treeview-window-size-default* 200
  "treeview-open 時の最小 window size")

(defun treeview-close-p ()
  "treeview が閉じているか。"
  (when (treeview-exist-p)
    (treeview-data-save-window-size)
    (cond
     ((find (treeview-data-get 'treeview::window-position) (list XPIS_LEFT XPIS_RIGHT))
      (<= (treeview-data-get 'treeview::window-width) *treeview-window-size-threshold*))
     (t
      (<= (treeview-data-get 'treeview::window-height) *treeview-window-size-threshold*)))))
(defun treeview-open-p ()
  "treeview が開いているか。"
  (if (treeview-exist-p) (not (treeview-close-p))))
(defun treeview-close ()
  "treeview を閉じる。"
  (interactive)
  (when (treeview-exist-p)
    (treeview-data-save-window-size)
    (cond
     ((find (treeview-data-get 'treeview::window-position) (list XPIS_LEFT XPIS_RIGHT))
      (treeview-data-set 'treeview::open-window-size (treeview-data-get 'treeview::window-width)))
     (t
      (treeview-data-set 'treeview::open-window-size (treeview-data-get 'treeview::window-height))))
    (treeview-setsize *treeview-window-size-min* *treeview-window-size-min* 10000 1))
  (run-hooks '*treeview-close-hook*))
(defun treeview-open ()
  "treeview を開く。"
  (interactive)
  (when (treeview-exist-p)
    ;; 現在のウィンドウサイズを記録
    (treeview-data-save-window-size)
    (let (window-size)
      (cond
       ((find (treeview-data-get 'treeview::window-position) (list XPIS_LEFT XPIS_RIGHT))
        (setq window-size (treeview-data-get 'treeview::window-width)))
       (t
        (setq window-size (treeview-data-get 'treeview::window-height))))
      ;; 現在のウィンドウサイズが閾値より低い(狭い)場合
      (when (or (not (integerp window-size))
                (>= *treeview-window-size-threshold* window-size))
        (setq window-size (treeview-data-get 'treeview::open-window-size))
        ;; treeview-close 時のウィンドウサイズが閾値より低い(狭い)場合
        (when (or (not (integerp window-size))
                  (>= *treeview-window-size-threshold* window-size))
          ;; デフォルト値
          (setq window-size *treeview-window-size-default*)))
      (treeview-setsize window-size *treeview-window-size-min* 10000 1)))
  (run-hooks '*treeview-open-hook*))
(defun treeview-toggle-open ()
  "treeview の開閉をトグル。"
  (interactive)
  (when (treeview-exist-p)
    (if (treeview-close-p)
        (treeview-open) (treeview-close))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 判定・状態取得
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-hitem-valid-p (hitem)
  "item が non-nil かつ 非 0 であるか。"
  (and hitem (not (eql hitem 0))))
(defun treeview-hitem-equal (hitem1 hitem2)
  "item が等しいか。"
  (eql hitem1 hitem2))
(defun treeview-hitem-not-equal (hitem1 hitem2)
  "item が等しくないか。"
  (not (treeview-hitem-equal hitem1 hitem2)))
(defun treeview-hitem-lessp (hitem1 hitem2)
  "hitem1 が hitem2 よりも上部に存在するか。"
  (let (hitems1 hitems2 hitem)
    (when (and (treeview-exist-p)
               (treeview-hitem-valid-p hitem1)
               (treeview-hitem-valid-p hitem2)
               (not (treeview-hitem-equal hitem1 hitem2)))
      (setq hitem hitem1)
      (while (treeview-hitem-valid-p hitem)
        (push hitem hitems1)
        (setq hitem (treeview-get-parent-item hitem)))
      (setq hitem hitem2)
      (while (treeview-hitem-valid-p hitem)
        (push hitem hitems2)
        (setq hitem (treeview-get-parent-item hitem)))
      (while (and hitems1
                  hitems2
                  (eql (car hitems1) (car hitems2)))
        (pop hitems1)
        (pop hitems2))
      (cond
       ((null hitems1) t)
       ((null hitems2) nil)
       (t
        (setq hitem1 (car hitems1))
        (setq hitem2 (car hitems2))
        (setq hitem (treeview-get-next-sibling-item hitem1))
        (while (treeview-hitem-valid-p hitem)
          (if (eql hitem hitem2)
              (return-from treeview-hitem-lessp t))
          (setq hitem (treeview-get-next-sibling-item hitem)))
        nil)))))
(defun treeview-hitem-greaterp (hitem1 hitem2)
  "hitem1 が hitem2 よりも下部に存在するか。"
  (treeview-hitem-lessp hitem2 hitem1))
(defun treeview-hitem-not-lessp (hitem1 hitem2)
  "hitem1 が hitem2 よりも上部には存在しないか。"
  (not (treeview-hitem-lessp hitem1 hitem2)))
(defun treeview-hitem-not-greaterp (hitem1 hitem2)
  "hitem1 が hitem2 よりも下部には存在しないか。"
  (not (treeview-hitem-greaterp hitem1 hitem2)))

(defun treeview-get-depth (hitem)
  "item の階層レベルを取得。(1 origin)"
  (let ((depth 0))
    (when (and (treeview-exist-p)
               (treeview-hitem-valid-p hitem))
      (incf depth)
      (while (and (setq hitem (treeview-get-parent-item hitem))
                  (treeview-hitem-valid-p hitem))
        (incf depth)))
    depth))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; window
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-set-redraw (arg)
  "treeview の再描画の開始/抑制を設定。"
  (let ((WM_SETREDRAW #x000B) (TRUE 1) (FALSE 0))
    (if (and arg (not (and (numberp arg) (zerop arg))))
        (setq arg TRUE)
      (setq arg FALSE))
    (winapi:SendMessage (treeview-get-htree) WM_SETREDRAW arg 0)))

(defun treeview-window-height ()
  "treeview に縦に表示可能な item の数を取得。
treeview-get-visible-count と同一。"
  (treeview-get-visible-count))
(defun treeview-get-window-line (&optional (hitem (treeview-get-selected-item)))
  "item の window 行番号 (0 origin)"
  (if (treeview-exist-p)
      (car (multiple-value-list
            (truncate (nth 1 (treeview-get-item-rect hitem))
                      (treeview-get-item-height))))))
(defun treeview-item-visible-p (hitem)
  "item が展開表示しているか。"
  (let (parent-hitem)
    (and (treeview-hitem-valid-p hitem)
         (loop
           (setq parent-hitem (treeview-get-parent-item hitem))
           (unless (treeview-hitem-valid-p parent-hitem)
             (return t))
           (if (treeview-expand-p parent-hitem)
               (setq hitem parent-hitem)
             (return nil))))))
(defun treeview-item-window-visible-p (hitem)
  "item が window 内に表示されているか。"
  (and (treeview-item-visible-p hitem)
       (< -1 (treeview-get-window-line hitem) (treeview-window-height))))
(defun treeview-window-top-p ()
  "treeview window が一番上にスクロールしているか。"
  (when (treeview-exist-p)
    (treeview-hitem-equal (treeview-get-first-visible-item)
                          (treeview-get-root-item))))
(defun treeview-window-bottom-p ()
  "treeview window が一番下にスクロールしているか。"
  (when (treeview-exist-p)
    (treeview-hitem-equal (treeview-get-last-window-visible-item)
                          (treeview-get-last-visible-item))))
(defun treeview-scroll-window (arg)
  "treeview window を縦方向にスクロール。
arg に与えられた整数の item 個数分下方向にスクロールする。"
  (when (treeview-exist-p)
    (let ((hwnd (treeview-get-htree)))
      (when (integerp arg)
        (if (plusp arg)
            (dotimes (i arg)
              (winapi:SendMessage hwnd winapi:WM_VSCROLL winapi:SB_LINEDOWN 0))
          (dotimes (i (- arg))
            (winapi:SendMessage hwnd winapi:WM_VSCROLL winapi:SB_LINEUP 0)))))))
(defun treeview-recenter (&optional arg)
  "treeview window を縦方向にスクロールして画面上の表示位置を調整する。"
  (interactive "p")
  (treeview-scroll-window
   (treeview-recenter-scroll-height (treeview-get-selected-item) arg)))
(defun treeview-recenter-scroll-height (&optional hitem arg)
  "treeview-recenter に必要なスクロール量を取得。"
  (when (treeview-item-visible-p hitem)
    (- (treeview-get-window-line hitem)
       (if arg
           (if (minusp arg)
               (max (+ (treeview-window-height) arg) 0)
             (min arg (1- (treeview-window-height))))
         (truncate (treeview-window-height) 2)))))

(defun treeview-hscroll-window (arg)
  "treeview window を横方向にスクロール。"
  (when (treeview-exist-p)
    (let ((hwnd (treeview-get-htree)))
      (when (integerp arg)
        (if (plusp arg)
            (dotimes (i arg)
              (winapi:SendMessage hwnd winapi:WM_HSCROLL winapi:SB_LINERIGHT 0))
          (dotimes (i (- arg))
            (winapi:SendMessage hwnd winapi:WM_HSCROLL winapi:SB_LINELEFT 0)))))))
(defun treeview-hscroll-window-left ()
  "treeview window を左端までスクロール。"
  (interactive)
  (when (treeview-exist-p)
    (let ((hwnd (treeview-get-htree)))
      (winapi:SendMessage hwnd winapi:WM_HSCROLL winapi:SB_LEFT 0))))
(defun treeview-hscroll-window-right ()
  "treeview window を右端までスクロール。"
  (interactive)
  (when (treeview-exist-p)
    (let ((hwnd (treeview-get-htree)))
      (winapi:SendMessage hwnd winapi:WM_HSCROLL winapi:SB_RIGHT 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; フォーカス
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-focus-editor-pre-hook* nil
  "treeview-focus-editor でエディタ部をフォーカスする前の hook")
(defvar *treeview-focus-editor-hook* nil
  "treeview-focus-editor でエディタ部をフォーカスした後の hook")
(defun treeview-focus-editor ()
  "エディタ部をフォーカスする。"
  (interactive)
  (with-app ((treeview-get-active-app-id) t)
    (run-hooks '*treeview-focus-editor-pre-hook*)
    (winapi:SetFocus (get-window-handle))
    (run-hooks '*treeview-focus-editor-hook*)))
(defvar *treeview-focus-treeview-pre-hook* nil
  "treeview-focus-treeview で treeview をフォーカスする前の hook")
(defvar *treeview-focus-treeview-hook* nil
  "treeview-focus-treeview で treeview をフォーカスした後の hook")
(defun treeview-focus-treeview (&optional app-id)
  "treeview をフォーカスする。
treeview をフォーカスする場合は、この function を用いるように。"
  (interactive)
  (with-app ((or app-id *treeview-app-id*
                 (treeview-get-active-app-id)
                 (if (with-app (*treeview-last-app-id*) (treeview-open-p))
                     *treeview-last-app-id*)
                 (find-if #'(lambda (app-id) (with-app (app-id) (treeview-open-p)))
                          *treeview-app-id-list*)
                 *treeview-last-app-id*
                 (car *treeview-app-id-list*)) t)
    (run-hooks '*treeview-focus-treeview-pre-hook*)
    (when (treeview-exist-p)
      ;; フォーカス
      (winapi:SetFocus (treeview-get-hwnd))
      ;; treeview-app-bar の選択タブ更新
      (tab-bar-select-item 'treeview-app-bar *treeview-app-id*)
      ;; 排他的 open 処理
      (let ((active-app-id *treeview-app-id*)
            (exclusive-open-group (treeview-data-get 'treeview::exclusive-open-group)))
        (when exclusive-open-group
          (dolist (tmp-app-id *treeview-app-id-list*)
            (unless (eq tmp-app-id active-app-id)
              (with-app (tmp-app-id)
                (when (and (treeview-exist-p)
                           (equal exclusive-open-group
                                  (treeview-data-get 'treeview::exclusive-open-group)))
                  (treeview-close))))))
        (treeview-open)))
    (run-hooks '*treeview-focus-treeview-hook*)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 複数 item への処理
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-get-item-tree (hitem)
  "item 以下の item-tree を取得する。
root から調べる場合は hitem には 0(winapi::TVGN_ROOT) を指定する。"
  (let (child-hitem (tree (list hitem)))
    (when (treeview-item-has-children-p hitem)
      (setq child-hitem (treeview-get-child-item hitem))
      (while (treeview-hitem-valid-p child-hitem)
        (push (treeview-get-item-tree child-hitem) tree)
        (setq child-hitem (treeview-get-next-sibling-item child-hitem))))
    (nreverse tree)))

(defun treeview-map-item-tree (item-tree func)
  "item-tree のそれぞれの item に対して func を実行した結果の tree を取得。"
  (when item-tree
    (let (tree)
      (setq tree (list (funcall func (car item-tree))))
      (dolist (sub-tree (cdr item-tree))
        (push (treeview-map-item-tree sub-tree func) tree))
      (nreverse tree))))

(defun treeview-get-ancestor-item-list (hitem)
  "自身を含む全ての親 item のリストを、親から子に向かう順で取得。"
  (let (lst)
    (while (treeview-hitem-valid-p hitem)
      (push hitem lst)
      (setq hitem (treeview-get-parent-item hitem)))
    (nreverse lst)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 制御構造 (再帰, その他)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-funcall-recursive-tree-bottom-up (hitem func)
  "子→親の順で、自身を含み item 以下の item 全てに func を実行。"
  (labels ((recursive-call (hitem)
             (let (child-hitem)
               (when (treeview-item-has-children-p hitem)
                 (setq child-hitem (treeview-get-child-item hitem))
                 (while (treeview-hitem-valid-p child-hitem)
                   (recursive-call child-hitem)
                   (setq child-hitem (treeview-get-next-sibling-item child-hitem))))
               (funcall func hitem))))
    (when (treeview-hitem-valid-p hitem)
      (recursive-call hitem))))
(defun treeview-funcall-recursive-tree-top-down (hitem func)
  "親→子の順で、自身を含み item 以下の item 全てに func を実行。
func が nil を返した場合その子ノードは処理しない。"
  (labels ((recursive-call (hitem)
             (when (and (funcall func hitem)
                        (treeview-item-has-children-p hitem))
               (let (child-hitem)
                 (setq child-hitem (treeview-get-child-item hitem))
                 (while (treeview-hitem-valid-p child-hitem)
                   (setq child-hitem
                         (prog1
                             (treeview-get-next-sibling-item child-hitem)
                           (recursive-call child-hitem))))))))
    (when (treeview-hitem-valid-p hitem)
      (recursive-call hitem))))
(defun treeview-funcall-recursive-subtree-bottom-up (hitem func)
  "子→親の順で、自身を含まず item より下の item 全てに func を実行。"
  (labels ((recursive-call (hitem)
             (let (child-hitem)
               (when (treeview-item-has-children-p hitem)
                 (setq child-hitem (treeview-get-child-item hitem))
                 (while (treeview-hitem-valid-p child-hitem)
                   (setq child-hitem
                         (prog1
                             (treeview-get-next-sibling-item child-hitem)
                           (recursive-call child-hitem)
                           (funcall func child-hitem))))))))
    (when (treeview-hitem-valid-p hitem)
      (recursive-call hitem))))
(defun treeview-funcall-recursive-subtree-top-down (hitem func)
  "親→子の順で、自身を含まず item より下の item 全てに func を実行。
func が nil を返した場合その子ノードは処理しない。"
  (labels ((recursive-call (hitem)
             (when (treeview-item-has-children-p hitem)
               (let (child-hitem)
                 (setq child-hitem (treeview-get-child-item hitem))
                 (while (treeview-hitem-valid-p child-hitem)
                   (setq child-hitem
                         (prog1
                             (treeview-get-next-sibling-item child-hitem)
                           (when (funcall func child-hitem)
                             (recursive-call child-hitem)))))))))
    (when (treeview-hitem-valid-p hitem)
      (recursive-call hitem))))
(defun treeview-funcall-continue-up (hitem func)
  "子→親の順で、自身を含み item から上の item 全てに func を実行。"
  (while (treeview-hitem-valid-p hitem)
    (setq hitem
          (prog1
              (treeview-get-parent-item hitem)
            (funcall func hitem)))))

;;; base.l ends here
