;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "leader")

(in-package "editor")

(require "popup-window")

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
	  *leader-open-map*
	  *which-key-mode*
	  *which-key-description-alist*
	  *which-key-buffer-name*
	  *which-key-prefix-mode*
	  which-key-merge-bindings
	  which-key-lines-from-bindings
	  which-key-status-lines
	  which-key-prompt-from-bindings
	  which-key-prefix-hook
	  toggle-which-key-prefix
	  execute-leader-key
	  which-key-guide
	  leader-define-key
	  toggle-which-key))

(defvar *which-key-mode* t
  "nil でなければ、Leader Key やプレフィックスキー入力時に候補一覧を表示する。")

(defvar *which-key-buffer-name* "*Which Key*"
  "候補一覧を出す一時バッファの名前。")

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
(defvar *leader-open-map* (make-sparse-keymap))

;;;
;;; 説明ラベル設定ヘルパー
;;;

(defun which-key-add-description (target label)
  "コマンドまたはキーマップに Which-key ガイダンス用ラベルを登録する。

比較は eq で行う。equal を使うと、まだ空のキーマップ同士が「同じもの」に
なってしまう: sparse keymap はリストなので、中身が空なら構造が一致する。
実際にこれで壊れていた -- *leader-project-map* と *leader-git-map* は
どちらも中身が別ファイル (project.l, git.l) で入るため leader.l の時点では
空で、後から登録した方が前の方の登録を delete していた。その結果
Leader メニューの表示が 「p:Project+」 ではなく 「p:prefix+」 になっていた。"
  (setq *which-key-description-alist*
	(delete target *which-key-description-alist* :key #'car :test #'eq))
  (push (cons target label) *which-key-description-alist*))

(defun which-key-get-description (target)
  "コマンドまたはキーマップの説明ラベルを取得する。"
  (let ((found (assoc target *which-key-description-alist* :test #'eq)))
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
(define-key *leader-toggle-map* #\T 'toggle-color-theme-dark-light)
(define-key *leader-toggle-map* #\C 'select-color-theme)
(define-key *leader-toggle-map* #\m 'toggle-rich-modeline)
(define-key *leader-toggle-map* #\s 'toggle-ts-highlight)
(define-key *leader-toggle-map* #\g 'toggle-golden-ratio)
(define-key *leader-toggle-map* #\f 'toggle-flymake)

(which-key-add-description 'toggle-terminal-drawer "Terminal")
(which-key-add-description 'toggle-line-number "LineNum")
(which-key-add-description 'toggle-truncate-lines "Truncate")
(which-key-add-description 'calc "Calc")
(which-key-add-description 'toggle-autopair "AutoPair")
(which-key-add-description 'toggle-color-theme-dark-light "DarkLight")
(which-key-add-description 'select-color-theme "Theme")
(which-key-add-description 'toggle-rich-modeline "ModeLine")
(which-key-add-description 'toggle-ts-highlight "Syntax")
(which-key-add-description 'toggle-golden-ratio "GoldenRatio")
(which-key-add-description 'toggle-flymake "Flymake")

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
(define-key *leader-code-map* #\r 'iedit)
(define-key *leader-code-map* #\f 'list-function)
(define-key *leader-code-map* #\c 'flymake-check)
(define-key *leader-code-map* #\n 'flymake-next-error)
(define-key *leader-code-map* #\p 'flymake-previous-error)
(define-key *leader-code-map* #\e 'flymake-list-errors)

(which-key-add-description 'imenu "Symbols")
(which-key-add-description 'iedit "RenameAll")
(which-key-add-description 'list-function "FuncDialog")
(which-key-add-description 'flymake-check "Check")
(which-key-add-description 'flymake-next-error "NextError")
(which-key-add-description 'flymake-previous-error "PrevError")
(which-key-add-description 'flymake-list-errors "ListErrors")

;; Open / Notes (o)
(define-key *leader-open-map* #\s 'open-scratch)
(define-key *leader-open-map* #\m 'open-memo)
(define-key *leader-open-map* #\M 'open-memo-directory)

(which-key-add-description 'open-scratch "Scratch")
(which-key-add-description 'open-memo "Memo")
(which-key-add-description 'open-memo-directory "MemoDir")

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
(define-key *leader-map* #\o *leader-open-map*)
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
(which-key-add-description *leader-open-map* "Open")
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
  "キーマップ内の全バインディングを ((key . target) ...) のリストで返す。

**渡されたものが keymapp を通っていない場合もある。** full keymap の中の
プレフィックスは `ctl-x-4-prefix` のようなシンボルで入っているので、
lookup-keymap の結果をそのまま渡されるとシンボルが来る。keymapp は
キーマップそのもの (ベクタまたはリスト) を返すので、それで正規化する。"
  (setq keymap (or (keymapp keymap) keymap))
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

(defun which-key-binding-lessp (a b)
  "ガイダンスの並び順。サブメニュー (キーマップ) を先に、その中では
キーの文字コード順。sparse keymap の中身は定義した順ではなく逆順に
並んでいるので、そのまま出すと読み手には無秩序に見える。"
  (let ((pa (keymapp (cdr a)))
	(pb (keymapp (cdr b))))
    (cond ((and pa (not pb)) t)
	  ((and pb (not pa)) nil)
	  (t (< (char-code (car a)) (char-code (car b)))))))

(defun which-key-format-prompt (title keymap)
  "キーマップの Which-key プロンプト文字列を構築する。"
  (let ((bindings (sort (which-key-collect-bindings keymap)
			#'which-key-binding-lessp))
	(items nil))
    (dolist (b bindings)
      (let* ((k (car b))
	     (target (cdr b))
	     (kstr (which-key-format-key k))
	     (desc (which-key-get-description target))
	     (prefix-p (keymapp target)))
	(push (format nil "~A:~A~:[~;+~]" kstr desc prefix-p) items)))
    (format nil "[~A] ~{~A~^ ~}" title (nreverse items))))

(defun which-key-binding-strings (bindings)
  "((key . target) ...) を 「f  File+」 の形の文字列リストにする。並び順は
which-key-binding-lessp と同じ (サブメニューが先、キーの文字コード順)。"
  (mapcar #'(lambda (b)
	      (format nil "~A  ~A~:[~;+~]"
		      (which-key-format-key (car b))
		      (which-key-get-description (cdr b))
		      (keymapp (cdr b))))
	  (sort (copy-list bindings) #'which-key-binding-lessp)))

(defun which-key-item-strings (keymap)
  "キーマップの候補を 「f  File+」 の形の文字列リストにする。"
  (which-key-binding-strings (which-key-collect-bindings keymap)))

(defun which-key-merge-bindings (keymaps)
  "複数のキーマップの候補を、**前にあるものを優先して** 1 つにまとめる。

コマンドループが渡してくる待機中のキーマップは selection → minor → local →
global の順で、実際に効くのは前にあるものである。同じキーが複数のマップに
あるとき、後ろのものを出すと嘘になる。"
  (let ((seen nil))
    (dolist (m keymaps)
      (dolist (b (ignore-errors (which-key-collect-bindings m)))
	(unless (assoc (car b) seen :test #'eql)
	  (push b seen))))
    (nreverse seen)))

(defun which-key-lines-from-bindings (path bindings width &optional max-rows)
  "一時ウィンドウに出す行のリスト。1 行目は今いる階層の名前。"
  (cons (format nil "[~A]" path)
	(popup-window-columns (which-key-binding-strings bindings)
			      (max 20 (- width 1))
			      max-rows)))

(defun which-key-popup-lines (path keymap width)
  "一時ウィンドウに出す行のリスト。1 行目は今いる階層の名前。"
  (which-key-lines-from-bindings path (which-key-collect-bindings keymap) width))

(defun which-key-status-lines (path bindings)
  "ステータス行 (エコー領域) に出す行のリスト。

**エコー領域は表示量に応じて複数行になる** (issue #97) ので、1 行へ詰め込む
必要が無くなった。`C-x' は 60 個以上あり、1 行では 8 個 +「+55」しか出せて
いなかった (#84)。段組みにして `*max-minibuffer-message-lines*' 行まで使う。
入り切らない分は `popup-window-columns' が「... +N」と個数を書く。"
  (which-key-lines-from-bindings
   path bindings
   (max 20 (1- (popup-window-measured-columns)))
   (max 1 (1- (if (and (boundp '*max-minibuffer-message-lines*)
		       (integerp *max-minibuffer-message-lines*))
		  *max-minibuffer-message-lines*
		2)))))

(defun which-key-prompt-from-bindings (path bindings width)
  "ステータス行に出す 1 行。WIDTH に収まる分だけ出し、入り切らなければ
「あと何個あるか」を書く。**黙って切ると「これで全部だ」と読めてしまう。**

エコー領域が 1 行しか使えない設定 (`*message-in-echo-area*' が nil) の
ときに使う。複数行使えるなら `which-key-status-lines' の方が読める。"
  (let* ((items (which-key-binding-strings bindings))
	 (head (format nil "[~A] " path))
	 (out (make-string-output-stream))
	 (n 0)
	 (used (length head)))
    (dolist (i items)
      ;; 残りの個数を書く分の余地 (" +NN") を残しておく。
      (when (> (+ used (length i) 1 5) width)
	(return))
      (princ i out)
      (princ "  " out)
      (incf used (+ (length i) 2))
      (incf n))
    (let ((body (get-output-stream-string out))
	  (rest (- (length items) n)))
      (if (plusp rest)
	  (format nil "~A~A+~D" head body rest)
	(format nil "~A~A" head body)))))

(defun which-key-read (keymap title popup)
  "キーマップを辿ってコマンドを 1 つ選び、そのコマンドを返す。
選ばれなかった (キャンセル・未定義) ときは nil。

**ここではコマンドを実行しない。** 実行は呼び出し元が一時ウィンドウを
片付けてウィンドウ構成を戻した後に行う。ここで実行してしまうと、
Leader w s のようにウィンドウを分割するコマンドの結果が、直後の
後片付け (ウィンドウ構成の復元) で消える。

POPUP が non-nil なら候補を一時ウィンドウへ、nil ならステータス行へ出す。"
  (let ((current-map keymap)
	(path title))
    (loop
      (unless (keymapp current-map)
	(message "~A is not a valid keymap" current-map)
	(return nil))
      (if popup
	  (popup-window-draw *which-key-buffer-name*
			     (which-key-lines-from-bindings
			      path (which-key-collect-bindings current-map)
			      (popup-window-measured-columns)
			      (popup-window-body-lines 1)))
	(let ((prompt (if *which-key-mode*
			  (which-key-format-prompt path current-map)
			(format nil "[~A] " path))))
	  (message "~A" prompt)))
      (let ((ch (read-char *keyboard*)))
	(cond
	 ((or (char= ch #\C-g) (char= ch #\ESC))
	  (message "Quit")
	  (return nil))
	 (t
	  (let ((target (lookup-keymap current-map ch)))
	    (cond
	     ((null target)
	      (message "Leader: ~A is undefined" (which-key-format-key ch))
	      (return nil))
	     ((keymapp target)
	      (let ((sub-desc (which-key-get-description target)))
		(setq path (format nil "~A > ~A" path sub-desc))
		(setq current-map target)))
	     (t
	      (return target))))))))))

(defun which-key-guide (keymap &optional (title "Leader"))
  "指定したキーマップを Which-key ガイダンス付きで対話的に実行する。

候補は一時ウィンドウ (*Which Key*) に段組みで出す。ステータス行に出す形は
「message を書いた直後に read-char で待つと描かれない」フロントエンドが
あって当てにならない (issue #66)。ウィンドウが出せないとき
(ミニバッファの中、画面が狭い) だけステータス行へ落とす。"
  (if (and *which-key-mode* (popup-window-available-p))
      (let ((conf (current-window-configuration))
	    (target nil))
	(unwind-protect
	    (progn
	      (popup-window-open *which-key-buffer-name* "Which Key")
	      (setq target (which-key-read keymap title t)))
	  ;; 実行の前に元のウィンドウ構成へ戻す。順序が逆だと、選んだ
	  ;; コマンドがウィンドウを触る種類のものだったときに結果が消える。
	  ;;
	  ;; **一時ウィンドウを消すのは popup-window-close の方である。**
	  ;; set-window-configuration は端末フロントエンドでは何もしないので
	  ;; (issue #82)、これに任せていた間、端末では Leader メニューを
	  ;; キャンセルすると *Which Key* が画面に残っていた。
	  (ignore-errors (set-window-configuration conf))
	  (popup-window-close *which-key-buffer-name*)
	  ;; 構成を戻した後で画面全体を描き直させる。広がった行を誰も塗り
	  ;; 直さないと、一時ウィンドウの文字が残る。
	  (popup-window-refresh-frame))
	(when target
	  (message "")
	  (call-interactively target)
	  t))
    (let ((target (which-key-read keymap title nil)))
      (when target
	(message "")
	(call-interactively target)
	t))))

;;;
;;; 標準のプレフィックスキー用の短いラベル
;;;
;;; ラベルが無いとコマンド名がそのまま出る。C-x は 60 個以上あるので段組みの
;;; 1 列が狭くなり、"inverse-add-mode-abbrev" のような名前は途中で切れて
;;; 読めなくなる。**よく使うものだけ短い名前を付ける。** 付いていないものは
;;; コマンド名のまま出る (それでも当たりは付く)。
;;;

(which-key-add-description 'other-window "Other")
(which-key-add-description 'move-previous-window "PrevWin")
(which-key-add-description 'split-window "Split")
(which-key-add-description 'split-window-vertically "SplitV")
(which-key-add-description 'delete-window "DelWin")
(which-key-add-description 'delete-other-windows "OnlyWin")
(which-key-add-description 'enlarge-window "Taller")
(which-key-add-description 'shrink-window "Shorter")
(which-key-add-description 'enlarge-window-horizontally "Wider")
(which-key-add-description 'shrink-window-horizontally "Narrower")
(which-key-add-description 'kill-buffer "KillBuf")
(which-key-add-description 'save-some-buffers "SaveAll")
(which-key-add-description 'insert-file "InsFile")
(which-key-add-description 'find-other-file "OtherFile")
(which-key-add-description 'eval-last-sexp "EvalSexp")
(which-key-add-description 'exchange-point-and-mark "Exchange")
(which-key-add-description 'narrow-to-region "Narrow")
(which-key-add-description 'widen "Widen")
(which-key-add-description 'toggle-read-only "ReadOnly")
(which-key-add-description 'upcase-region "Upcase")
(which-key-add-description 'downcase-region "Downcase")
(which-key-add-description 'transpose-lines "Transpose")
(which-key-add-description 'delete-blank-lines "DelBlank")
(which-key-add-description 'what-cursor-position "CurPos")
(which-key-add-description 'describe-key-briefly "DescKey")
(which-key-add-description 'next-error "NextErr")
(which-key-add-description 'set-variable "SetVar")
(which-key-add-description 'set-fill-column "FillCol")
(which-key-add-description 'set-fill-prefix "FillPfx")
(which-key-add-description 'start-kbd-macro "MacroBeg")
(which-key-add-description 'end-kbd-macro "MacroEnd")
(which-key-add-description 'call-last-kbd-macro "MacroRun")
(which-key-add-description 'dabbrev-expand "Dabbrev")
(which-key-add-description 'expand-abbrev "Abbrev")
(which-key-add-description 'kill-xyzzy "Quit")
(which-key-add-description 'rename "Rename")
(which-key-add-description 'mark-page "MarkPage")
(which-key-add-description 'forward-page "NextPage")
(which-key-add-description 'backward-page "PrevPage")
(which-key-add-description 'scroll-left "ScrollL")
(which-key-add-description 'scroll-right "ScrollR")
(which-key-add-description 'fuzzy-switch-to-buffer "Switch")
(which-key-add-description 'run-console "Console")
(which-key-add-description 'launch-application "Launch")
(which-key-add-description 'execute-subprocess "Subproc")
(which-key-add-description 'filter-buffer "FilterBuf")
(which-key-add-description 'filter-region "FilterRgn")
(which-key-add-description 'pipe-command "Pipe")

;; プレフィックス側にも名前を付ける。full keymap の中ではシンボルで入って
;; いるので、シンボルとキーマップの両方に登録しておく。
(dolist (e (list (cons #\C-k "Kanji") (cons #\4 "OtherWin")
		 (cons #\6 "Frame") (cons #\r "Register")))
  (let ((cx (keymapp (lookup-keymap *global-keymap* #\C-x))))
    (when cx
      (let ((target (lookup-keymap cx (car e))))
	(when target
	  (which-key-add-description target (cdr e))
	  (let ((km (keymapp target)))
	    (when (and km (not (eq km target)))
	      (which-key-add-description km (cdr e)))))))))

;;;
;;; 標準のプレフィックスキー (C-x / C-c など) の候補一覧
;;;
;;; M-m は execute-leader-key という *コマンド* なので、その中で自分でキーを
;;; 読みながら候補を描ける。一方 C-x は *キーマップ* が割り当てられていて、
;;; 次のキーを待つのは C++ 側のコマンドループである。そこには Lisp のフックが
;;; 無かったので、*prefix-key-hook* を足した (issue #73)。
;;;
;;; フックは 2 通りで呼ばれる:
;;;
;;;   (keymaps key)  プレフィックス待ちに入った (keymaps は待機中のキーマップ)
;;;   (nil nil)      待ちが終わった (コマンドが決まった / 未定義だった)
;;;
;;; 終わりの呼び出しは *pre-command-hook* より先に来る。**コマンドが走る前に
;;; 片付けないと、ウィンドウを触るコマンド (C-x 2 など) の結果を後片付けで
;;; 消してしまう。** Leader メニューで実際に踏んだ問題と同じである。
;;;

(defvar *which-key-prefix-mode* t
  "C-x や C-c のような標準のプレフィックスキーでも候補一覧を出すか。")

(defvar *which-key-prefix-state* nil
  "プレフィックス待ちの間だけ non-nil。(keys...) を覚えておくためのもの。
直接触らない。")

(defun which-key-prefix-hook (keymaps key)
  "コマンドループから呼ばれる。KEYMAPS が nil なら待ちの終わり。

**ここで失敗しても打鍵の処理は続けなければならない**ので、全部包んで捨てる。
候補が出ないだけなら困らないが、C-x が動かなくなるのは困る。"
  (ignore-errors
    (if (null keymaps)
	(which-key-prefix-teardown)
      (when (and *which-key-mode* *which-key-prefix-mode*)
	(which-key-prefix-show keymaps key))))
  t)

(defun which-key-prefix-keys ()
  (cdr *which-key-prefix-state*))

(defun which-key-prefix-path (keys)
  (format nil "~{~A~^ ~}" (mapcar #'which-key-format-key keys)))

(defun which-key-prefix-show (keymaps key)
  "プレフィックス待ちの候補をステータス行に出す。

**分割ウィンドウには出さない。** 一時ウィンドウを出す形も書いてみたが、
プレフィックス待ちの最中 (コマンドループの dispatch の中) にウィンドウを
作って消すと、端末フロントエンドで画面が更新されなくなり、続くコマンドが
一時ウィンドウの方で走った (issue #83)。C-x は日常のキーなので、そこで
レイアウトを触るのは危険が大きすぎる。ステータス行ならウィンドウには
触らない。

**ステータス行は表示量に応じて複数行になる** (issue #97) ので、段組みで
出す。`*message-in-echo-area*' が nil のときは 1 行しか使えないので、
そのときだけ 1 行に詰めた形に落とす。"
  (let ((bindings (which-key-merge-bindings keymaps)))
    (when bindings
      (let ((keys (append (which-key-prefix-keys) (list key))))
	(setq *which-key-prefix-state* (cons t keys))
	(if (and (boundp '*message-in-echo-area*) *message-in-echo-area*)
	    (message "~{~A~^~%~}"
		     (which-key-status-lines
		      (which-key-prefix-path keys) bindings))
	  (message "~A" (which-key-prompt-from-bindings
			 (which-key-prefix-path keys) bindings
			 (max 20 (1- (popup-window-measured-columns))))))
	t))))

(defun which-key-prefix-teardown ()
  "待ちが終わったので出したものを片付ける。"
  (when *which-key-prefix-state*
    (setq *which-key-prefix-state* nil)
    (message ""))
  t)

(defun toggle-which-key-prefix (&optional (arg nil sv))
  "C-x / C-c などでの候補一覧の表示を切り替える。"
  (interactive)
  (setq *which-key-prefix-mode* (if sv arg (not *which-key-prefix-mode*)))
  (unless *which-key-prefix-mode*
    (which-key-prefix-teardown))
  (message "which-key (prefix keys): ~:[off~;on~]" *which-key-prefix-mode*)
  *which-key-prefix-mode*)

(add-hook '*prefix-key-hook* 'which-key-prefix-hook)

;;;
;;; コマンド・ユーザー定義ヘルパー
;;;

(defun execute-leader-key ()
  "Leader Key ガイダンスメニューを開始する。"
  (interactive)
  (which-key-guide *leader-map* "Leader"))

(defun leader-define-key (key-seq command &optional label)
  "Leader Key にキーシーケンスとコマンドを登録する。

KEY-SEQ は \"f o\" のようなスペース区切り文字列、または '(#\\f #\\o) のような
文字のリスト。1 文字だけなら文字そのものでもよい。
LABEL は Which-key ガイダンスで表示する短い名称。

**自分で作ったキーマップを M-m へ直接割り当てないこと。** そうすると
xyzzy 標準のプレフィックスキー処理に入り、候補一覧が出なくなる
(ステータス行に \"m-\" と出て次のキーを待つだけになる)。M-m は
execute-leader-key のままにして、項目はこの関数で足す。"
  (let ((keys (cond ((stringp key-seq)
		     (mapcar #'(lambda (s) (char s 0))
			     (split-string key-seq " \t" nil)))
		    ((characterp key-seq) (list key-seq))
		    (t (copy-list key-seq))))
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
