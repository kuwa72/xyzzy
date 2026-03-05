;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; frame-work.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 12:54:35 +0900>

;;; Code:

(provide "wip/treeview/frame-work")

(require "cmdbar")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "wip/treeview/defs")
  (require "wip/treeview/macro"))

(in-package "treeview")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-nop (&optional hitem)
  "何もしない処理。"
  (interactive)
  nil)

(defun treeview-message (fmt &rest args)
  "display-name を先頭につけた message を出力。"
  (apply #'message
         (concat (treeview-data-get 'treeview::display-name "TreeView") ": "
                 fmt) args))

(defun treeview-minibuffer-prompt (fmt &rest args)
  "display-name を先頭につけた minibuffer-prompt を出力。"
  (apply #'minibuffer-prompt
         (concat (treeview-data-get 'treeview::display-name "TreeView") ": "
                 fmt) args))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; treeview-id
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-get-active-treeview-id ()
  "現在アクティブな treeview の treeview-id を返す。"
  (let ((htree (winapi::GetFocus)))
    (dolist (treeview-id (treeview-get-treeview-id-list))
      (with-treeview (treeview-id)
        (when (eql htree (treeview-get-htree))
          (return-from treeview-get-active-treeview-id treeview-id))))))

(defun treeview-get-mouse-htree ()
  "現在マウスの乗っている treeview の htree を返す。"
  (let ((po (winapi:make-POINT)))
    (winapi:GetCursorPos po)
    (winapi:WindowFromPoint (winapi:POINT-x po) (winapi:POINT-y po))))

(defun treeview-get-mouse-treeview-id ()
  "現在マウスの乗っている treeview の treeview-id を返す。"
  (let ((htree (treeview-get-mouse-htree)))
    (dolist (treeview-id (treeview-get-treeview-id-list))
      (with-treeview (treeview-id)
        (when (eql htree (treeview-get-htree))
          (return-from treeview-get-mouse-treeview-id treeview-id))))))

(defun treeview-get-treeview-id ()
  "現在、もしくは直近の treeview-id を返す。"
  (or *treeview-id* *treeview-last-id* 0))

(defun treeview-get-any-treeview-id ()
  "適切と思える優先度で、なんらかの treeview-id を返す。"
  (or *treeview-id*
      *treeview-last-id*
      (treeview-get-active-treeview-id)
      (treeview-get-mouse-treeview-id)
      (car (treeview-get-treeview-id-list))
      0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; keymap
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-fix-map* nil
  "treeview keymap (デフォルト動作対策) (サンプル)。
treeview ライブラリ内では使用していないが、ライブラリを使用する側から
copy-keymap 元として用いられることを想定して用意している。")
(unless *treeview-fix-map*
  ;; キーバインド変更不可
  (setq *treeview-fix-map* (make-sparse-keymap))
  (define-key *treeview-fix-map* #\SPC          'treeview-nop)
;  (define-key *treeview-fix-map* #\Up           'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\Down         'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\Left         'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\Right        'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-Up         'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-Down       'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-Left       'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-Right      'treeview-select-node-delay)
  (define-key *treeview-fix-map* #\C-Up         'treeview-nop)
  (define-key *treeview-fix-map* #\C-Down       'treeview-nop)
  (define-key *treeview-fix-map* #\C-Left       'treeview-nop)
  (define-key *treeview-fix-map* #\C-Right      'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-Up       'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-Down     'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-Left     'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-Right    'treeview-nop)
;  (define-key *treeview-fix-map* #\PageUp       'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\PageDown     'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\Home         'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\End          'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-PageUp     'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-PageDown   'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-Home       'treeview-select-node-delay)
;  (define-key *treeview-fix-map* #\S-End        'treeview-select-node-delay)
  (define-key *treeview-fix-map* #\C-PageUp     'treeview-nop)
  (define-key *treeview-fix-map* #\C-PageDown   'treeview-nop)
  (define-key *treeview-fix-map* #\C-Home       'treeview-nop)
  (define-key *treeview-fix-map* #\C-End        'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-PageUp   'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-PageDown 'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-Home     'treeview-nop)
  (define-key *treeview-fix-map* #\S-C-End      'treeview-nop))

(defvar *treeview-map* nil
 "treeview keymap (サンプル)。
treeview ライブラリ内では使用していないが、ライブラリを使用する側から
copy-keymap 元として用いられることを想定して用意している。")
(unless *treeview-map*
  (setq *treeview-map* (make-keymap))
  ;;
  (define-key *treeview-map* '(#\C-c #\C-f) 'open-filer)
;  (define-key *treeview-map* #\TAB 'treeview-focus-editor)
  (define-key *treeview-map* #\TAB 'treeview-other-treeview-window)
;  (define-key *treeview-map* #\C-g 'treeview-focus-editor)
  (define-key *treeview-map* #\C-g 'quit)
  (define-key *treeview-map* #\Apps 'treeview-std-track-popup-menu)
  (define-key *treeview-map* #\C-l 'treeview-recenter)
  ;;
  (define-key *treeview-map* '(#\C-x #\o) 'treeview-other-window)
  (define-key *treeview-map* '(#\C-x #\p) 'treeview-move-previous-window)
  (define-key *treeview-map* '(#\C-x #\0) 'treeview-close)
  (define-key *treeview-map* '(#\C-x #\1) 'treeview-open)
  (define-key *treeview-map* '#\C-: 'treeview-toggle-open)
  ;;
  (define-key *treeview-map* #\< 'treeview-hscroll-window-left)
  (define-key *treeview-map* #\> 'treeview-hscroll-window-right)
  ;;
  (define-key *treeview-map* '(#\C-c #\w #\t) 'treeview-setpos-top)
  (define-key *treeview-map* '(#\C-c #\w #\b) 'treeview-setpos-bottom)
  (define-key *treeview-map* '(#\C-c #\w #\l) 'treeview-setpos-left)
  (define-key *treeview-map* '(#\C-c #\w #\r) 'treeview-setpos-right)
  (define-key *treeview-map* '(#\C-c #\w #\w) 'treeview-setpos-rotate)
  ;;
  (define-key *treeview-map* '(#\C-x #\?) 'treeview-describe-key-briefly))

;; TreeView が複数存在しても、call-back function はひとつしか設定できないか？
(defun treeview-set-std-keydown-callback ()
  "treeview ライブラリで標準的に用いる keydown-callback。
keydown-callback を他のものに変更することは想定していない。"
  (let (fix-keymap-symbol keymap-symbol key x)
    (treeview-keydown-callback
     #'(lambda (hitem vkey flag)
         (with-app ((treeview-get-active-app-id))
           (setq fix-keymap-symbol (treeview-data-get 'treeview::fix-keymap-symbol))
           (setq keymap-symbol (treeview-data-get 'treeview::keymap-symbol))
           (unless (keymapp (treeview-data-get 'treeview::keydown-callback-keymap))
             (treeview-data-set 'treeview::keydown-callback-keymap (symbol-value keymap-symbol))
             (treeview-data-set 'treeview::keydown-callback-key-str ""))
           (when (setq key (win-user:vkey-to-key vkey))
             (run-hooks 'ed::*pre-command-hook*)
             (setq x (lookup-keymap (symbol-value fix-keymap-symbol) key))
             (if x
                 ;; fix-keymap に該当
                 (progn
                   (treeview-data-set 'treeview::keydown-callback-keymap nil)
                   (treeview-data-set 'treeview::keydown-callback-key-str "")
                   (treeview-message "[fix] ~A" (key-to-string key))
                   (when (and (fboundp x) (commandp x))
                     (setq ed::*last-command* ed::*this-command*)
                     (setq ed::*this-command* x)
                     (call-interactively x)
                     (run-hooks 'ed::*post-command-hook*)))
               ;; fix-keymap に非該当
               (progn
                 (setq x (lookup-keymap (treeview-data-get 'treeview::keydown-callback-keymap) key))
                 (if (keymapp x)
                     (progn
                       (if (string= (treeview-data-get 'treeview::keydown-callback-key-str) "")
                           (treeview-data-set 'treeview::keydown-callback-key-str (key-to-string key))
                         (treeview-data-set 'treeview::keydown-callback-key-str
                                            (concat (treeview-data-get 'treeview::keydown-callback-key-str)
                                                    " " (key-to-string key))))
                       (treeview-message "~A-" (treeview-data-get 'treeview::keydown-callback-key-str))
                       (treeview-data-set 'treeview::keydown-callback-keymap x))
                   (progn
                     (if (string/= (treeview-data-get 'treeview::keydown-callback-key-str) "")
                         (progn
                           (treeview-data-set 'treeview::keydown-callback-key-str
                                              (concat (treeview-data-get 'treeview::keydown-callback-key-str)
                                                      " " (key-to-string key)))
                           (treeview-message "~A" (treeview-data-get 'treeview::keydown-callback-key-str)))
                       (message " "))
                     (treeview-data-set 'treeview::keydown-callback-keymap nil)
                     (when (and (fboundp x) (commandp x))
                       (setq ed::*last-command* ed::*this-command*)
                       (setq ed::*this-command* x)
                       (call-interactively x)
                       (refresh-screen)
                       (do-events)
                       (run-hooks 'ed::*post-command-hook*))))))))))))

(require "keymap")
(defun treeview-describe-bindings ()
  "treeview ウィンドウでのキーバインディング一覧を表示する。
「固定バインディング」「バインディング」「インクリメンタルサーチバインディ
ング」の 3 種類を表示する。"
  (interactive)
  (let ((shadow nil)
        (fix-keymap (symbol-value (treeview-data-get 'treeview::fix-keymap-symbol)))
        (keymap (symbol-value (treeview-data-get 'treeview::keymap-symbol))))
    (long-operation
      (treeview-message "Building binding list...")
      (with-output-to-temp-buffer ("*Help*")
        (format t "~A Fix Bindings:~%key~20Tbinding~%---~20T-------~%"
                (treeview-data-get 'treeview::display-name))
        (ed::describe-bindings-1 "" fix-keymap nil)
        (push fix-keymap shadow)
        (format t "~%~A Bindings:~%key~20Tbinding~%---~20T-------"
                (treeview-data-get 'treeview::display-name))
        (ed::describe-bindings-1 "" keymap shadow)
        (format t "~%~A I-search Bindings:~%key~20Tbinding~%---~20T-------"
                (treeview-data-get 'treeview::display-name))
        (ed::describe-bindings-1 "" *treeview-isearch-map* nil)
        (goto-char 0))
      (refresh-screen)
      (treeview-message "Building binding list...done"))))

;; ヘルプ (help.l)
(defun treeview-describe-key-briefly (key &optional arg)
  "treeview ウィンドウでの、指定されたキーのバインド情報を表示する。"
  (interactive
      (list
       (let (key one-key (keymap (symbol-value (treeview-data-get 'treeview::keymap-symbol))) x (key-str ""))
         (loop
           (treeview-focus-editor)
           (treeview-minibuffer-prompt "Describe key briefly: ~A" key-str)
           (setq one-key (read-char *keyboard*))
           (push one-key key)
           (when (lookup-keymap (symbol-value (treeview-data-get 'treeview::fix-keymap-symbol)) one-key)
             (setq key (list one-key))
             (return))
           (setq x (lookup-keymap keymap one-key))
           (if (keymapp x)
               (progn
                 (setq key-str (concat key-str (key-to-string one-key) " "))
                 (setq keymap x))
             (return)))
         (minibuffer-message "")
         (nreverse key))
       nil))
  (let (command)
    (if (setq command (lookup-keymap (symbol-value (treeview-data-get 'treeview::fix-keymap-symbol)) key))
        (progn
          (setq key (key-to-string key))
          (cond
           (arg
            (save-excursion
              (insert (format nil "~a: [fix] ~a (~a)"
                              (treeview-data-get 'treeview::display-name) key command))))
           (t
            (treeview-message "[fix] ~a runs the command ~A" key command))))
      (progn
        (setq command (lookup-keymap (symbol-value (treeview-data-get 'treeview::keymap-symbol)) key))
        (setq key (key-to-string key))
        (cond ((null command)
               (treeview-message "~a is not bound" key))
              (arg
               (save-excursion
                 (insert (format nil "~a: ~a (~a)"
                                 (treeview-data-get 'treeview::display-name) key command))))
              (t
               (treeview-message "~a runs the command ~A" key command)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mouse
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; click の処理が終了してから rclick が動作するように
(defvar *treeview-interval-click* 0.01
  "treeview 上で左クリック動作させるための interval タイム。")
(defvar *treeview-interval-dblclk* 0.01
  "treeview 上で左ダブルクリック動作させるための interval タイム。")
(defvar *treeview-interval-rclick* 0.1
  "treeview 上で右クリック動作させるための interval タイム。
右クリック時に、暗黙的に先に左クリック動作をさせるために、
*treeview-interval-rclick* の値は、*treeview-interval-click*、
*treeview-interval-dblclk* よりもある程度大きい値(長い interval)でなければ
ならない。")

(defun click (&optional x y)
  "マウス位置に対して左クリック動作を発生させる。
xyzzy 上に限らず、クリック動作は発生する。"
  (let ((po (winapi::make-POINT)))
    (winapi::GetCursorPos po)
    (when (or x y)
      (winapi::SetCursorPos (or x (winapi::POINT-x po))
                            (or y (winapi::POINT-y po))))
    (winapi:mouse_event winapi:MOUSEEVENTF_LEFTDOWN 0 0 0 0)
    (winapi:mouse_event winapi:MOUSEEVENTF_LEFTUP 0 0 0 0)
    (when (or x y)
      (winapi::SetCursorPos (winapi::POINT-x po)
                            (winapi::POINT-y po)))
    (refresh-screen)))

(defun treeview-set-std-click-callback ()
  "treeview ライブラリで標準的に用いる 左クリックコールバック関数。
他のものに変更することは想定していない。"
  (let (pre-time pre-hitem time)
    (treeview-click-callback
     #'(lambda (hitem)
         (setq time (get-internal-real-time))
         (with-app ((treeview-treeview-id-get-app-id (treeview-get-mouse-treeview-id)))
           ;; treeview フォーカスを先に行う
           (treeview-focus-treeview)
           (setq hitem (treeview-hittest))
           (when (treeview-hitem-valid-p hitem)
             (treeview-select-item hitem))
           (let* (func-gen func)
             (when (and (setq func-gen (treeview-data-get 'treeview::implicit-func-gen))
                        (setq func (funcall func-gen hitem)))
               (stop-timer func)
               (start-timer *treeview-interval-click* func t))))))))
(defun treeview-set-std-dblclk-callback ()
  "treeview ライブラリで標準的に用いる 左ダブルクリックコールバック関数。
他のものに変更することは想定していない。"
  (treeview-dblclk-callback
   #'(lambda (hitem)
       (with-app ((treeview-treeview-id-get-app-id (treeview-get-mouse-treeview-id)))
         (setq hitem (treeview-hittest))
         (when (treeview-hitem-valid-p hitem)
           (treeview-select-item hitem))
         (let* (func-gen func)
           (when (and (setq func-gen (treeview-data-get 'treeview::explicit-func-gen))
                      (setq func (funcall func-gen hitem)))
             (stop-timer func)
             (start-timer *treeview-interval-dblclk* func t)))))))
(defun treeview-set-std-rclick-callback ()
  "treeview ライブラリで標準的に用いる 右クリックコールバック関数。
右クリックされた場合には、左クリックを発生させ、先に左クリック時処理を行い、
その後右クリック動作としてポップアップメニューを表示する。
treeview-set-std-rclick-callback を他のものに変更することは想定していない。"
  (treeview-rclick-callback
   #'(lambda (hitem)
       ; 左クリックをまず発生させ、処理を行う
       (click)
       (with-app ((treeview-treeview-id-get-app-id (treeview-get-mouse-treeview-id)))
         (setq hitem (treeview-hittest))
         (let* (func-gen func)
           (when (setq func
                       (let* ((popup-menu-gen (treeview-data-get 'treeview::menu-gen))
                              (popup-menu (and popup-menu-gen (funcall popup-menu-gen hitem))))
                         (when (menup popup-menu)
                           #'(lambda ()
                               (track-popup-menu popup-menu :button2)))))
             (stop-timer func)
             (start-timer *treeview-interval-rclick* func t)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; menu
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-std-track-popup-menu (&optional hitem)
  "treeview ライブラリで標準的に用いるポップアップメニューコマンド。
右クリックコールバック関数内から呼ばれる。"
  (interactive)
  (with-app ((treeview-treeview-id-get-app-id (treeview-get-treeview-id)))
    (unless hitem
      (setq hitem (treeview-get-selected-item)))
    (let* ((popup-menu-gen (treeview-data-get 'treeview::menu-gen))
           (popup-menu (and popup-menu-gen (funcall popup-menu-gen hitem))))
      (when (menup popup-menu)
        (track-popup-menu popup-menu)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; treeview 配置位置変更
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-setpos-top ()
  "treeview の位置を上に設定する。"
  (interactive)
  (treeview-setpos XPIS_TOP))
(defun treeview-setpos-bottom ()
  "treeview の位置を下に設定する。"
  (interactive)
  (treeview-setpos XPIS_BOTTOM))
(defun treeview-setpos-left ()
  "treeview の位置を左に設定する。"
  (interactive)
  (treeview-setpos XPIS_LEFT))
(defun treeview-setpos-right ()
  "treeview の位置を右に設定する。"
  (interactive)
  (treeview-setpos XPIS_RIGHT))
(defun treeview-setpos-rotate ()
  "treeview の位置を左上右下の順に変更する。"
  (interactive)
  (let ((pos-list (list XPIS_LEFT XPIS_TOP XPIS_RIGHT XPIS_BOTTOM)) pos)
    (setq pos (cadr (member (treeview-data-get 'treeview::window-position) pos-list)))
    (unless pos
      (setq pos XPIS_LEFT))
    (treeview-setpos pos)))

(defun treeview-popup-menu-position ()
  "現在の app-id の treeview の位置を変更するポップアップメニューを生成する。"
  (let ((menu (create-popup-menu 'position))
        (app-id *treeview-app-id*))
    (add-menu-item menu 'treeview-setpos-top "上(&T)"
     #'(lambda () (interactive) (with-app (app-id) (treeview-setpos-top)))
     #'(lambda ()
         (with-app (app-id)
           (and (eql (treeview-data-get 'treeview::window-position) XPIS_TOP) :check))))
    (add-menu-item menu 'treeview-setpos-bottom "下(&B)"
     #'(lambda () (interactive) (with-app (app-id) (treeview-setpos-bottom)))
     #'(lambda ()
         (with-app (app-id)
           (and (eql (treeview-data-get 'treeview::window-position) XPIS_BOTTOM) :check))))
    (add-menu-item menu 'treeview-setpos-left "左(&L)"
     #'(lambda () (interactive) (with-app (app-id) (treeview-setpos-left)))
     #'(lambda ()
         (with-app (app-id)
           (and (eql (treeview-data-get 'treeview::window-position) XPIS_LEFT) :check))))
    (add-menu-item menu 'treeview-setpos-right "右(&R)"
     #'(lambda () (interactive) (with-app (app-id) (treeview-setpos-right)))
     #'(lambda ()
         (with-app (app-id)
           (and (eql (treeview-data-get 'treeview::window-position) XPIS_RIGHT) :check))))
    menu))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; window size
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-data-save-window-size ()
  "treeview の window サイズを保存する。
位置が上下の場合は高さを、左右の場合は幅を保存する。"
  (when (treeview-exist-p)
    (let ((pos (treeview-data-get 'treeview::window-position)))
      (cond
       ((find pos (list XPIS_LEFT XPIS_RIGHT))
        (treeview-data-set 'treeview::window-width
                           (win-user::get-wwindow-width (treeview-get-hwnd))))
       ((find pos (list XPIS_TOP XPIS_BOTTOM))
        (treeview-data-set 'treeview::window-height
                           (win-user::get-wwindow-height (treeview-get-hwnd))))))))

(defun treeview-data-load-window-size ()
  "treeview の window サイズを、保存しておいたサイズに従い変更する。"
  (when (treeview-exist-p)
    (let ((pos (treeview-data-get 'treeview::window-position)))
      (cond
       ((find pos (list XPIS_LEFT XPIS_RIGHT))
        (treeview-setsize
         (treeview-data-get 'treeview::window-width *treeview-window-size-default*)
         *treeview-window-size-min* 10000 1))
       ((find pos (list XPIS_TOP XPIS_BOTTOM))
        (treeview-setsize
         (treeview-data-get 'treeview::window-height *treeview-window-size-default*)
         *treeview-window-size-min* 10000 1))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; window display style
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-effect-window-display-style-on-create ()
  "treeview 作成時 xyzzy の内部にそのまま表示しない場合のための window 制御。"
  (when (treeview-exist-p)
    (case (treeview-data-get 'treeview::window-display-style)
      (:xyzzy-position
       (win-user::enlarge-xyzzy-by-wwindow-size
        (treeview-get-hwnd)
        (treeview-data-get 'treeview::window-position)
        t))
      (:fixed-editor
       (win-user::enlarge-xyzzy-by-wwindow-size
        (treeview-get-hwnd)
        (treeview-data-get 'treeview::window-position)
        nil)))))

(defun treeview-effect-window-display-style-on-delete ()
  "xyzzy の内部にそのまま表示していない場合の treeview を削除時 window 制御。"
  (when (treeview-exist-p)
    (case (treeview-data-get 'treeview::window-display-style)
      (:xyzzy-position
       (win-user::shrink-xyzzy-by-wwindow-size
        (treeview-get-hwnd)
        (treeview-data-get 'treeview::window-position)
        t))
      (:fixed-editor
       (win-user::shrink-xyzzy-by-wwindow-size
        (treeview-get-hwnd)
        (treeview-data-get 'treeview::window-position)
        nil)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; color
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-data-load-color ()
  "設定から文字色・背景色を取得し、treeview に反映させる。"
  (let (rgb color-name)
    (when (treeview-exist-p)
      ;; text-color
      (if (treeview-data-get 'treeview::color-text-manual-p)
          (progn
            (cond
             ((numberp (setq rgb (treeview-data-get 'treeview::color-text)))
              (treeview-set-text-color (ed::color-rgb2bgr rgb)))
             ((stringp (setq color-name (treeview-data-get 'treeview::color-text)))
              (setq rgb (cdr (assoc color-name ed::*color-all-colors-name-alist*
                                    :test 'string=)))))
            (when rgb
              (treeview-set-text-color (ed::color-rgb2bgr rgb))))
        (treeview-set-text-color -1))
      ;; bk-color
      (if (treeview-data-get 'treeview::color-bk-manual-p)
          (progn
            (cond
             ((numberp (setq rgb (treeview-data-get 'treeview::color-bk)))
              (treeview-set-bk-color (ed::color-rgb2bgr rgb)))
             ((stringp (setq color-name (treeview-data-get 'treeview::color-bk)))
              (setq rgb (cdr (assoc color-name ed::*color-all-colors-name-alist*
                                    :test 'string=)))))
            (when rgb
              (treeview-set-bk-color (ed::color-rgb2bgr rgb))))
        (treeview-set-bk-color -1)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; font
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-data-load-font ()
  "設定からフォント設定を取得し、treeview に反映させる。"
  (when (treeview-exist-p)
    (treeview-font-set
     :font-facename (and (treeview-data-get 'treeview::font-facename-manual-p)
                         (treeview-data-get 'treeview::font-facename))
     :font-height (if (treeview-data-get 'treeview::font-height-manual-p)
                      (treeview-data-get 'treeview::font-height) 12)
     :font-bold (treeview-data-get 'treeview::font-bold)
     :font-italic (treeview-data-get 'treeview::font-italic)
     :font-underline (treeview-data-get 'treeview::font-underline))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; style
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-style-list*
  ;  SYMBOL                     REV TAG                            LABEL
  '((winapi:TVS_HASBUTTONS      nil treeview::style-hasbuttons     "ﾎﾞﾀﾝを表示(&N)")
    (winapi:TVS_HASLINES        nil treeview::style-haslines       "ﾗｲﾝを表示(&L)")
    (winapi:TVS_LINESATROOT     nil treeview::style-linesatroot    "ﾗｲﾝ・ﾎﾞﾀﾝをﾙｰﾄから表示(&R)")
    (winapi:TVS_EDITLABELS      nil treeview::style-editlabels     "ﾗﾍﾞﾙ編集可能(&E)")
    (winapi:TVS_DISABLEDRAGDROP   t treeview::style-enabledragdrop "ﾄﾞﾗｯｸﾞｱﾝﾄﾞﾄﾞﾛｯﾌﾟ可(&D)")
    (winapi:TVS_SHOWSELALWAYS   nil treeview::style-showselalways  "ｾﾙを常に選択表示(&A)")
    (winapi:TVS_RTLREADING      nil treeview::style-rtlreading     "右から左に表示(&U)")
    (winapi:TVS_NOTOOLTIPS        t treeview::style-tooltips       "ﾂｰﾙﾁｯﾌﾟを表示(&S)")
    (winapi:TVS_CHECKBOXES      nil treeview::style-checkboxes     "ﾁｪｯｸﾎﾞｯｸｽを表示(&C)")
    (winapi:TVS_TRACKSELECT     nil treeview::style-trackselect    "ﾄﾗｯｸｾﾚｸﾄ(&T)")
    (winapi:TVS_SINGLEEXPAND    nil treeview::style-singleexpand   "一つのみ展開(&G)")
    (winapi:TVS_INFOTIP         nil treeview::style-infotip        "ﾂｰﾙﾁｯﾌﾟ情報取得(&I)")
    (winapi:TVS_FULLROWSELECT   nil treeview::style-fullrowselect  "一行選択表示(ﾗｲﾝ表示時無効)(&O)")
    (winapi:TVS_NOSCROLL          t treeview::style-scroll         "縦ｽｸﾛｰﾙ(&V)")
    (winapi:TVS_NONEVENHEIGHT   nil treeview::style-nonevenheight  "ｾﾙ毎の高さの設定(&F)")
    (winapi:TVS_NOHSCROLL         t treeview::style-hscroll        "横ｽｸﾛｰﾙ(&H)"))
  "treeview のスタイルの保存、適用の実施、および、設定ダイアログのための情報。")

(defun treeview-data-save-style ()
  "treeview から現在の sytle 設定を取得し、保存する。"
  (when (treeview-exist-p)
    (let ((current-style (winapi:GetWindowStyle (treeview-get-htree)))
          symbol rev tag label)
      (dolist (x *treeview-style-list*)
        (setq symbol (nth 0 x) rev (nth 1 x) tag (nth 2 x) label (nth 3 x))
        (unless (eq (treeview-data-get tag) :ignore)
          (if (zerop (logand current-style (symbol-value symbol)))
              (treeview-data-set tag (if rev t nil))
            (treeview-data-set tag (if rev nil t))))))))

(defun treeview-data-load-style ()
  "設定から style 設定を取得し、treeview に反映させる。"
  (when (treeview-exist-p)
    (let ((current-style (winapi:GetWindowStyle (treeview-get-htree)))
          symbol rev tag label val)
      (dolist (x *treeview-style-list*)
        (setq symbol (nth 0 x) rev (nth 1 x) tag (nth 2 x) label (nth 3 x))
        (setq val (treeview-data-get tag :ignore))
        (cond
         ((eq val :ignore))
         (val
          (if rev
              (treeview-modify-style (symbol-value symbol) 0 0)
            (treeview-modify-style 0 (symbol-value symbol) 0)))
         (t
          (if rev
              (treeview-modify-style 0 (symbol-value symbol) 0)
            (treeview-modify-style (symbol-value symbol) 0 0))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; indent
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-data-load-indent ()
  "設定からインデント設定を取得し、treeview に反映させる。"
  (when (treeview-exist-p)
    (if (treeview-data-get 'treeview::indent-manual-p)
        (if (integerp (treeview-data-get 'treeview::indent))
            (treeview-set-indent (treeview-data-get 'treeview::indent)))
      (treeview-set-indent 0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; item-height
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-data-load-item-height ()
  "設定からアイテムの高さ設定を取得し、treeview に反映させる。"
  (when (treeview-exist-p)
    (if (treeview-data-get 'treeview::item-height-manual-p)
        (if (integerp (treeview-data-get 'treeview::item-height))
            (treeview-set-item-height (treeview-data-get 'treeview::item-height)))
      (treeview-set-item-height -1))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; window 移動
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-other-window-pre-hook* nil
  "treeview-other-window 前 hook")
(defvar *treeview-other-window-hook* nil
  "treeview-other-window 後 hook")
(defun treeview-other-treeview-window (&optional (arg 1 f) no-error)
  "treeview ウィンドウのみを対象として other-window 動作を行う。"
  (interactive "p")
  (treeview-other-window arg no-error t))

(defun treeview-other-window (&optional (arg 1 f) no-error treeview-only)
  "treeview ウィンドウを含めて other-window 動作を行う。"
  (interactive "p")
  (run-hooks '*treeview-other-window-pre-hook*)
  (let* ((first-window (car (caaddr (current-window-configuration))))
         window-list hwnd-list target-list target current next pos)
    (push first-window window-list)
    (setq next (next-window first-window))
    (while (not (eq first-window next))
      (push next window-list)
      (setq next (next-window next)))
    (setq window-list (nreverse window-list))
    (setq hwnd-list
          (delete 0
                  (mapcar #'(lambda (treeview-id)
                              (with-treeview (treeview-id) (treeview-get-htree)))
                          (treeview-get-treeview-id-list))
                  :test 'eql))
    (if (treeview-get-active-app-id)
        (setq current
              (with-app ((treeview-get-active-app-id))
                (treeview-get-htree)))
      (setq current (selected-window)))
    (when treeview-only
      (setq window-list nil))
    (setq target-list (append window-list hwnd-list))
    (setq pos (position current target-list :test 'eql))
    (when pos
      (setq target-list (cdr (append (subseq target-list pos)
                                     (subseq target-list 0 pos)))))
    (if (plusp arg)
        (dotimes (x arg)
          (setq target (pop target-list)))
      (progn
        (setq target-list (nreverse target-list))
        (dotimes (x (- arg))
          (setq target (pop target-list)))))
    (when (null target)
      (and f (not no-error)
           (error 'range-error :datum arg)))
    (if (windowp target)
        ;; target が (xyzzy での) window の場合
        (progn
          (treeview-focus-editor)
          (set-window target)
          (refresh-screen))
      ;; target が hwnd の場合
      (progn
        ;; hwnd を取得しているが、treeview-focus-treeview を用いるために
        ;; あえて対応する treeview-id を取得しなおすことにする
        (with-app ((treeview-treeview-id-get-app-id
                    (dolist (treeview-id (treeview-get-treeview-id-list))
                      (with-treeview (treeview-id)
                        (when (eq target (treeview-get-htree))
                          (return treeview-id)))))
                   t)
          (treeview-focus-treeview)))))
  (run-hooks '*treeview-other-window-hook*))

(defun treeview-move-previous-window (&optional (arg 1 f))
  "treeview ウィンドウを含めて move-previous-window 動作を行う。"
  (interactive "p")
  (treeview-other-window (- arg) (null f)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 再描画
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-refresh-treeview ()
  "treeview を再描画する。"
  (winapi:InvalidateRect (treeview-get-hwnd) 0 0))

(defun treeview-refresh-screen-force ()
  "画面全体を再描画する。"
  (winapi:InvalidateRect 0 0 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tab-bar
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-app-bar ()
  "treeview タブバーを表示する。"
  (create-tab-bar 'treeview-app-bar
                  'treeview-app-bar-func)
  (mapc #'(lambda (app-id)
            (with-app (app-id)
              (when (treeview-exist-p)
                (treeview-app-bar-add-item app-id))))
        (reverse *treeview-app-id-list*))
;  (tab-bar-select-item 'treeview-app-bar (car *treeview-app-id-list*))
  )
(define-command-bar 'treeview-app-bar "TreeView(&T)")

(defun treeview-app-bar-func (app-id)
  "treeview タブバーを選択した際の処理。"
  (let ((treeview-active-p (treeview-get-active-app-id)))
    (with-app (app-id)
      (treeview-focus-treeview)
      (unless treeview-active-p
        (focus-tool-bar)))))

(defun treeview-app-bar-add-item (&optional app-id select)
  "treeview タブバー管理下に treeview を追加する。"
  (unless (tool-bar-exist-p 'treeview-app-bar)
    (treeview-app-bar))
  (unless app-id
    (setq app-id *treeview-app-id*))
  (unless (tab-bar-find-item 'treeview-app-bar app-id)
    (with-app (app-id)
      (let* ((popup-menu-gen (treeview-data-get 'treeview::menu-gen))
             (popup-menu (and popup-menu-gen (funcall popup-menu-gen -1))))
        (tab-bar-add-item 'treeview-app-bar app-id
                          (treeview-data-get 'treeview::display-name (symbol-name app-id))
                          nil
                          popup-menu))))
  (when select
    (tab-bar-select-item 'treeview-app-bar app-id))
  (refresh-screen))
(defun treeview-app-bar-del-item (&optional app-id)
  "treeview タブバー管理下から treeview を削除する。"
  (unless (tool-bar-exist-p 'treeview-app-bar)
    (treeview-app-bar))
  (unless app-id
    (setq app-id *treeview-app-id*))
  (tab-bar-delete-item 'treeview-app-bar app-id)
  ;; 何故か判らないがTABバーにゴミが残る場合があるので以下も検討
;;  (while (tab-bar-delete-item 'treeview-app-bar app-id)
;;    t)
  (refresh-screen))
(defun treeview-app-bar-delete ()
  "treeview タブバーを削除する。"
  (delete-command-bar 'treeview-app-bar))
(add-hook '*treeview-uninstall-hook* 'treeview-app-bar-delete)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun treeview-operation-on-kill-xyzzy ()
  "xyzzy 終了時に実行する treeview 処理。
・ウィンドウサイズ設定の保存
・各種データの保存
・xyzzy ウィンドウ位置、サイズの修正"
  (maphash
   #'(lambda (app-id treeview-id)
       (with-app (app-id)
         (when (treeview-exist-p)
           (treeview-data-save-window-size)
           (treeview-data-save-style)
           (treeview-effect-window-display-style-on-delete))))
   *treeview-app-to-treeview-hash*))

(add-hook 'ed::*kill-xyzzy-hook* 'treeview-operation-on-kill-xyzzy)

;;; frame-work.l ends here
