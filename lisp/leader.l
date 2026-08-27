;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "leader")

(in-package "editor")

(export '(*leader-map*
	  *leader-file-map*
	  *leader-buffer-map*
	  *leader-project-map*
	  *leader-search-map*
	  *leader-git-map*
	  *leader-toggle-map*
	  *leader-window-map*
	  *leader-help-map*
	  *leader-code-map*
	  *which-key-mode*
	  *which-key-description-alist*
	  execute-leader-key
	  which-key-guide
	  leader-define-key
	  toggle-which-key))

(defvar *which-key-mode* t
  "nil でなければ、Leader Key やプレフィックスキー入力時にミニバッファへ候補一覧を表示する。")

(defvar *which-key-description-alist* nil
  "コマンドまたはキーマップの短い表示用ラベルの alist。
((command-or-map . \"label\") ...)")

;;;
;;; キーマップ定義
;;;

(defvar *leader-map* (make-sparse-keymap))
(defvar *leader-file-map* (make-sparse-keymap))
(defvar *leader-buffer-map* (make-sparse-keymap))
(defvar *leader-project-map* (make-sparse-keymap))
(defvar *leader-search-map* (make-sparse-keymap))
(defvar *leader-git-map* (make-sparse-keymap))
(defvar *leader-toggle-map* (make-sparse-keymap))
(defvar *leader-window-map* (make-sparse-keymap))
(defvar *leader-help-map* (make-sparse-keymap))
(defvar *leader-code-map* (make-sparse-keymap))

;;;
;;; 説明ラベル設定ヘルパー
;;;

(defun which-key-add-description (target label)
  "コマンドまたはキーマップに Which-key ガイダンス用ラベルを登録する。"
  (setq *which-key-description-alist*
	(delete target *which-key-description-alist* :key #'car :test #'equal))
  (push (cons target label) *which-key-description-alist*))

(defun which-key-get-description (target)
  "コマンドまたはキーマップの説明ラベルを取得する。"
  (let ((found (assoc target *which-key-description-alist* :test #'equal)))
    (if found
	(cdr found)
      (cond ((symbolp target)
	     (let ((name (symbol-name target)))
	       (subseq name 0 (min (length name) 16))))
	    ((keymapp target)
	     "prefix")
	    (t "cmd")))))

;;;
;;; キー割り当てとラベル登録
;;;

;; File (f)
(define-key *leader-file-map* #\f 'find-file)
(define-key *leader-file-map* #\r 'recentf-open)
(define-key *leader-file-map* #\s 'save-buffer)
(define-key *leader-file-map* #\w 'write-file)
(define-key *leader-file-map* #\d 'open-filer)

(which-key-add-description 'find-file "Find")
(which-key-add-description 'recentf-open "Recent")
(which-key-add-description 'save-buffer "Save")
(which-key-add-description 'write-file "WriteAs")
(which-key-add-description 'open-filer "Filer")

;; Buffer (b)
(define-key *leader-buffer-map* #\b 'switch-to-buffer)
(define-key *leader-buffer-map* #\k 'kill-selected-buffer)
(define-key *leader-buffer-map* #\l 'list-buffers)
(define-key *leader-buffer-map* #\r 'revert-buffer)
(define-key *leader-buffer-map* #\n 'next-buffer)
(define-key *leader-buffer-map* #\p 'previous-buffer)

(which-key-add-description 'switch-to-buffer "Switch")
(which-key-add-description 'kill-selected-buffer "Kill")
(which-key-add-description 'list-buffers "List")
(which-key-add-description 'revert-buffer "Revert")
(which-key-add-description 'next-buffer "Next")
(which-key-add-description 'previous-buffer "Prev")

;; Search (s)
(define-key *leader-search-map* #\s 'isearch-forward)
(define-key *leader-search-map* #\r 'isearch-backward)
(define-key *leader-search-map* #\g 'grep)
(define-key *leader-search-map* #\q 'query-replace)

(which-key-add-description 'isearch-forward "IsearchFwd")
(which-key-add-description 'isearch-backward "IsearchBack")
(which-key-add-description 'grep "Grep")
(which-key-add-description 'query-replace "Replace")

;; Toggle (t)
(define-key *leader-toggle-map* #\t 'toggle-terminal-drawer)
(define-key *leader-toggle-map* #\l 'toggle-line-number)
(define-key *leader-toggle-map* #\w 'toggle-truncate-lines)
(define-key *leader-toggle-map* #\c 'calc)
(define-key *leader-toggle-map* #\p 'toggle-autopair)

(which-key-add-description 'toggle-terminal-drawer "Terminal")
(which-key-add-description 'toggle-line-number "LineNum")
(which-key-add-description 'toggle-truncate-lines "Truncate")
(which-key-add-description 'calc "Calc")
(which-key-add-description 'toggle-autopair "AutoPair")

;; Window (w)
(define-key *leader-window-map* #\s 'split-window)
(define-key *leader-window-map* #\v 'split-window-vertically)
(define-key *leader-window-map* #\2 'split-window)
(define-key *leader-window-map* #\5 'split-window-vertically)
(define-key *leader-window-map* #\3 'split-window-vertically)
(define-key *leader-window-map* #\o 'other-window)
(define-key *leader-window-map* #\d 'delete-window)
(define-key *leader-window-map* #\0 'delete-window)
(define-key *leader-window-map* #\m 'delete-other-windows)
(define-key *leader-window-map* #\1 'delete-other-windows)
(define-key *leader-window-map* #\u 'winner-undo)
(define-key *leader-window-map* #\r 'winner-redo)

(which-key-add-description 'split-window "SplitBelow")
(which-key-add-description 'split-window-vertically "SplitRight")
(which-key-add-description 'other-window "Other")
(which-key-add-description 'delete-window "Close")
(which-key-add-description 'delete-other-windows "Maximize")
(which-key-add-description 'winner-undo "LayoutUndo")
(which-key-add-description 'winner-redo "LayoutRedo")

;; Code (c)
(define-key *leader-code-map* #\s 'imenu)
(define-key *leader-code-map* #\f 'list-function)

(which-key-add-description 'imenu "Symbols")
(which-key-add-description 'list-function "FuncDialog")

;; Help (h)
(define-key *leader-help-map* #\k 'describe-key)
(define-key *leader-help-map* #\f 'describe-function)
(define-key *leader-help-map* #\v 'describe-variable)
(define-key *leader-help-map* #\b 'describe-bindings)
(define-key *leader-help-map* #\a 'apropos)

(which-key-add-description 'describe-key "DescKey")
(which-key-add-description 'describe-function "DescFunc")
(which-key-add-description 'describe-variable "DescVar")
(which-key-add-description 'describe-bindings "Bindings")
(which-key-add-description 'apropos "Apropos")

;; Root Leader Map へのカテゴリバインド
(define-key *leader-map* #\f *leader-file-map*)
(define-key *leader-map* #\b *leader-buffer-map*)
(define-key *leader-map* #\p *leader-project-map*)
(define-key *leader-map* #\s *leader-search-map*)
(define-key *leader-map* #\g *leader-git-map*)
(define-key *leader-map* #\t *leader-toggle-map*)
(define-key *leader-map* #\w *leader-window-map*)
(define-key *leader-map* #\c *leader-code-map*)
(define-key *leader-map* #\h *leader-help-map*)

;; ダイレクトショートカット
(define-key *leader-map* #\SPC 'fuzzy-execute-extended-command)
(define-key *leader-map* #\/ 'grep)
(define-key *leader-map* #\v 'expand-region)
(define-key *leader-map* #\V 'contract-region)

(which-key-add-description *leader-file-map* "File")
(which-key-add-description *leader-buffer-map* "Buffer")
(which-key-add-description *leader-project-map* "Project")
(which-key-add-description *leader-search-map* "Search")
(which-key-add-description *leader-git-map* "Git")
(which-key-add-description *leader-toggle-map* "Toggle")
(which-key-add-description *leader-window-map* "Window")
(which-key-add-description *leader-code-map* "Code")
(which-key-add-description *leader-help-map* "Help")
(which-key-add-description 'fuzzy-execute-extended-command "M-x")
(which-key-add-description 'expand-region "Expand")
(which-key-add-description 'contract-region "Contract")

;;;
;;; ガイダンス生成とキー解釈
;;;

(defun which-key-format-key (key)
  "キー文字を表示用にフォーマットする。"
  (cond ((char= key #\SPC) "SPC")
	((char= key #\TAB) "TAB")
	((char= key #\RET) "RET")
	((char= key #\ESC) "ESC")
	((graphic-char-p key) (string key))
	(t (format nil "~:C" key))))

(defun which-key-collect-bindings (keymap)
  "キーマップ内の全バインディングを ((key . target) ...) のリストで返す。"
  (let (bindings)
    (if (consp keymap)
	;; sparse keymap
	(dolist (pair (cdr keymap))
	  (when (and (consp pair) (car pair) (cdr pair))
	    (push (cons (car pair) (cdr pair)) bindings)))
      ;; full vector keymap
      (dotimes (i (min (length keymap) *full-keymap-length*))
	(let ((target (elt keymap i)))
	  (when target
	    (push (cons (*keymap-index-char i) target) bindings)))))
    (nreverse bindings)))

(defun which-key-format-prompt (title keymap)
  "キーマップの Which-key プロンプト文字列を構築する。"
  (let ((bindings (which-key-collect-bindings keymap))
	(items nil))
    (dolist (b bindings)
      (let* ((k (car b))
	     (target (cdr b))
	     (kstr (which-key-format-key k))
	     (desc (which-key-get-description target))
	     (prefix-p (keymapp target)))
	(push (format nil "~A:~A~:[~;+~]" kstr desc prefix-p) items)))
    (format nil "[~A] ~{~A  ~}" title (nreverse items))))

(defun which-key-guide (keymap &optional (title "Leader"))
  "指定したキーマップを Which-key ガイダンス付きで対話的に実行する。"
  (let ((current-map keymap)
	(path title))
    (loop
      (unless (keymapp current-map)
	(message "~A is not a valid keymap" current-map)
	(return nil))
      (let ((prompt (if *which-key-mode*
			(which-key-format-prompt path current-map)
		      (format nil "[~A] " path))))
	(message "~A" prompt)
	(let ((ch (read-char *keyboard*)))
	  (cond
	   ;; キャンセルキー
	   ((or (char= ch #\C-g) (char= ch #\ESC))
	    (message "Quit")
	    (return nil))
	   ;; キーマップから検索
	   (t
	    (let ((target (lookup-keymap current-map ch)))
	      (cond
	       ((null target)
		(message "Leader: ~A is undefined" (which-key-format-key ch))
		(return nil))
	       ((keymapp target)
		;; サブキーマップへ遷移
		(let ((sub-desc (which-key-get-description target)))
		  (setq path (format nil "~A > ~A" path sub-desc))
		  (setq current-map target)))
	       (t
		;; コマンド実行
		(message "")
		(call-interactively target)
		(return t)))))))))))

;;;
;;; コマンド・ユーザー定義ヘルパー
;;;

(defun execute-leader-key ()
  "Leader Key ガイダンスメニューを開始する。"
  (interactive)
  (which-key-guide *leader-map* "Leader"))

(defun leader-define-key (key-seq command &optional label)
  "Leader Key にキーシーケンスとコマンドを登録する。
key-seq は \"f o\" のようなスペース区切り文字列、または '(#\\f #\\o) のようなリスト。
label は Which-key ガイダンスで表示する短い名称。"
  (let ((keys (if (stringp key-seq)
		  (mapcar #'(lambda (s) (char s 0))
			  (split-string key-seq #\SPC t))
		keys))
	(map *leader-map*))
    (while (cdr keys)
      (let* ((k (car keys))
	     (next-map (lookup-keymap map k)))
	(unless (keymapp next-map)
	  (setq next-map (make-sparse-keymap))
	  (define-key map k next-map))
	(setq map next-map)
	(pop keys)))
    (when keys
      (define-key map (car keys) command)
      (when label
	(which-key-add-description command label)))))

(defun toggle-which-key (&optional (arg nil sv))
  "Which-key ミニバッファガイダンスの有効/無効を切り替える。"
  (interactive "p")
  (toggle-mode '*which-key-mode* arg sv)
  (message "Which-key guidance is ~:[disabled~;enabled~]" *which-key-mode*))

;;;
;;; デフォルトキーバインド登録
;;;

(global-set-key '(#\M-m) 'execute-leader-key)
(global-set-key '(#\C-c #\SPC) 'execute-leader-key)
