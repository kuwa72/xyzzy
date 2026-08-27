;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; バッファ内の関数・クラス・見出しの一覧から選んでジャンプする
;;; (Emacs の imenu 相当)。
;;;
;;; xyzzy には既に `M-x list-function' (lisp/listfn.l) がある。ただし
;;;
;;;   * Win32 のダイアログボックスなので ncurses フロントエンドでは使えない
;;;   * 索引を作れるのは build-summary-function を持つモードだけで、それは
;;;     Lisp・C 系・Java・Basic の 4 系統しかない (Python・JavaScript・
;;;     Markdown・シェル・Makefile 等は何も出ない)
;;;   * 絞り込みが無い
;;;
;;; ここでは正規表現で索引を作る汎用の仕組みを足し、選択は
;;; lisp/fuzzy-complete.l のファジー絞り込みで行う。既に
;;; build-summary-function を持つモードではそれをそのまま使うので、
;;; C 系の「だいたい」の関数抽出 (lisp/cfns.l) を書き直さずに済む。
;;;

(provide "imenu")

(in-package "editor")

(require "fuzzy-complete")

(export '(imenu imenu-create-index
	  *imenu-create-index-function*
	  *imenu-generic-expression-alist*))

(defvar *imenu-create-index-function* nil
  "バッファローカルに設定すると、そのバッファの索引作成に使われる。
((表示名 . 行番号) ...) を返す関数。")

;;; (種類ラベル 正規表現 グループ番号) の並び。種類ラベルが nil なら
;;; 表示名に何も前置しない。グループ番号を省略すると 1。
;;;
;;; 正規表現は 1 行で完結するものだけにしてある。複数行にまたがる宣言
;;; (C の戻り値型だけ別の行にある関数定義など) を正規表現で当てにいくと
;;; 誤検出のほうが増える。そういうモードは build-summary-function 側に
;;; 任せる。
(defvar *imenu-generic-expression-alist*
  '((lisp-mode
     (nil "^(def[^ \t\n()]*[ \t]+(?\\([^ \t\n()]+\\)" 1))
    (lisp-interaction-mode
     (nil "^(def[^ \t\n()]*[ \t]+(?\\([^ \t\n()]+\\)" 1))
    (python-mode
     ("class" "^[ \t]*class[ \t]+\\([A-Za-z_][A-Za-z_0-9]*\\)" 1)
     (nil     "^[ \t]*def[ \t]+\\([A-Za-z_][A-Za-z_0-9]*\\)" 1))
    (javascript-mode
     ("class" "^[ \t]*\\(?:export[ \t]+\\)?class[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)" 1)
     (nil "^[ \t]*\\(?:export[ \t]+\\)?\\(?:async[ \t]+\\)?function\\*?[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)" 1)
     (nil "^[ \t]*\\(?:const\\|let\\|var\\)[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)[ \t]*=[ \t]*\\(?:async[ \t]+\\)?\\(?:function\\|(\\)" 1))
    (typescript-mode
     ("class" "^[ \t]*\\(?:export[ \t]+\\)?\\(?:abstract[ \t]+\\)?class[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)" 1)
     ("interface" "^[ \t]*\\(?:export[ \t]+\\)?interface[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)" 1)
     (nil "^[ \t]*\\(?:export[ \t]+\\)?\\(?:async[ \t]+\\)?function\\*?[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)" 1)
     (nil "^[ \t]*\\(?:const\\|let\\|var\\)[ \t]+\\([A-Za-z_$][A-Za-z_$0-9]*\\)[ \t]*=[ \t]*\\(?:async[ \t]+\\)?\\(?:function\\|(\\)" 1))
    (perl-mode
     (nil "^[ \t]*sub[ \t]+\\([A-Za-z_][A-Za-z_0-9:]*\\)" 1))
    (shell-script-mode
     (nil "^[ \t]*\\(?:function[ \t]+\\)?\\([A-Za-z_][A-Za-z_0-9]*\\)[ \t]*()" 1))
    (markdown-mode
     (nil "^\\(#+[ \t]*.*\\)$" 1))
    (makefile-mode
     (nil "^\\([A-Za-z0-9_][^ \t\n:=]*\\)[ \t]*::?[^=]" 1))
    (cmake-mode
     (nil "^[ \t]*\\(?:function\\|macro\\)[ \t]*([ \t]*\\([A-Za-z_][A-Za-z_0-9]*\\)" 1))
    (yaml-mode
     (nil "^\\([A-Za-z_0-9][A-Za-z_0-9.-]*\\):" 1))
    (toml-mode
     (nil "^\\[+\\([^]\n]+\\)\\]+" 1))
    (css-mode
     (nil "^\\([^ \t\n{}/][^{}\n]*[^ \t{}\n]\\)[ \t]*{" 1)))
  "モード (buffer-mode の値) ごとの索引の作り方。
各要素は (モード (種類ラベル 正規表現 グループ番号) ...)。")

(defun imenu-generic-expression ()
  (cdr (assoc buffer-mode *imenu-generic-expression-alist* :test #'eq)))

(defun imenu-scan-generic (specs)
  "SPECS に従ってバッファを走査し、((表示名 . 行番号) ...) を行番号順で返す。"
  (let ((result nil))
    (dolist (spec specs)
      (let ((label (first spec))
	    (regexp (second spec))
	    (group (or (third spec) 1)))
	(save-excursion
	  (goto-char (point-min))
	  ;; :tail t で一致の末尾へ進むので、同じ位置で止まって
	  ;; 無限ループになることはない (ここの正規表現はいずれも
	  ;; 1 文字以上を消費する)。
	  (while (scan-buffer regexp :regexp t :tail t)
	    (let ((name (match-string group))
		  (line (save-excursion
			  (goto-char (match-beginning 0))
			  (current-line-number))))
	      (when (and name (plusp (length name)))
		(push (cons (if label (format nil "~A ~A" label name) name)
			    line)
		      result)))))))
    ;; 種類ごとに 1 回ずつ走査するので、そのままだと種類順に並ぶ。
    ;; バッファに現れる順のほうが探しやすい。
    (sort result #'< :key #'cdr)))

(defun imenu-from-build-summary ()
  "モードが build-summary-function を持っていればそれで索引を作る。
返り値の形が (行番号 表示名) なので、こちらの形へ入れ替える。"
  (when (and (boundp 'build-summary-function)
	     build-summary-function)
    (let ((entries (ignore-errors
		     (save-excursion (funcall build-summary-function)))))
      (mapcar #'(lambda (e) (cons (second e) (first e))) entries))))

(defun imenu-create-index ()
  "現在のバッファの索引を ((表示名 . 行番号) ...) で返す。作れなければ nil。"
  (or (and *imenu-create-index-function*
	   (funcall *imenu-create-index-function*))
      (let ((specs (imenu-generic-expression)))
	(and specs (imenu-scan-generic specs)))
      (imenu-from-build-summary)))

(defun imenu-labeled-entries (index)
  "表示名が重複しないようにした ((ラベル . 行番号) ...) を返す。
同名のものには行番号を付けて区別する: 同じ名前の関数が 2 つあるとき、
選んでも必ず片方にしか飛べないのでは一覧の意味が無い。"
  (let ((seen (make-hash-table :test #'equal))
	(result nil))
    (dolist (e index)
      (let ((label (car e)))
	(when (gethash label seen)
	  (setq label (format nil "~A  [~D]" (car e) (cdr e))))
	(setf (gethash label seen) t)
	(push (cons label (cdr e)) result)))
    (nreverse result)))

(defun imenu ()
  "バッファ内の関数・クラス・見出しを一覧から選んでジャンプする。"
  (interactive)
  (let ((index (imenu-create-index)))
    (if (null index)
	(progn
	  (message "~A モードの索引の作り方が登録されていない" mode-name)
	  nil)
      (let* ((entries (imenu-labeled-entries index))
	     (chosen (fuzzy-completing-read "Jump to: " (mapcar #'car entries)
					    :must-match t)))
	(if (null chosen)
	    (progn (message "Quit") nil)
	  (let ((line (cdr (assoc chosen entries :test #'string=))))
	    ;; 大きく飛ぶ前にマークを置く: end-of-buffer 等と同じ作法で、
	    ;; C-x C-x で元の位置へ戻れる。
	    (set-mark-command)
	    (goto-line line)
	    (goto-bol)
	    t))))))
