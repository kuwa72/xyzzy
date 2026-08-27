;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; M-x をファジー絞り込みにする。
;;;
;;; 素の M-x (execute-extended-command) は `interactive' の "C" 指定から
;;; C++ 側の read-command-name を呼ぶので、絞り込み方に手を入れる隙が無い。
;;; ここでは代わりにコマンド名の一覧を Lisp 側で作り、
;;; lisp/fuzzy-complete.l の絞り込みループに渡す。
;;;
;;; コマンド名を集めるのは do-all-symbols + commandp で、autoload の
;;; スタブも commandp なので「まだ読み込んでいないライブラリのコマンド」も
;;; 候補に出る (素の M-x と同じ範囲になる)。
;;;

(provide "fuzzy-mx")

(in-package "editor")

(require "fuzzy-complete")

(export '(fuzzy-execute-extended-command
	  *fuzzy-mx-mode*
	  *fuzzy-mx-annotate*
	  *fuzzy-mx-history*
	  *fuzzy-mx-history-max*))

(defvar *fuzzy-mx-mode* t
  "nil にすると M-x が従来の read-command-name (TAB 補完) に戻る。")

(defvar *fuzzy-mx-history* nil
  "M-x から実行したコマンド名の履歴 (新しいものが先頭)。
クエリが空のときはこの順で候補が並ぶので、直前に使ったコマンドが
すぐ手前に出る。")

(defvar *fuzzy-mx-history-max* 30
  "*fuzzy-mx-history* に残す件数。")

(defvar *fuzzy-mx-annotate* t
  "non-nil なら、候補の右端にそのコマンドの割り当てキーを出す
(Marginalia 相当)。「そのコマンドに近道があるか」が一覧を見るだけで分かる。")

(defun fuzzy-command-table ()
  "対話的に呼べるコマンドの (名前 . シンボル) を名前順に並べて返す。

同名のシンボルが複数のパッケージに居ることは (コマンドでは) 事実上無いので
名前で重複を落とす。do-all-symbols は import されたシンボルを複数回
返してくるため、この重複除去は必要。"
  (let ((table nil)
	(seen (make-hash-table :test #'equal)))
    (do-all-symbols (s)
      (when (and (fboundp s) (commandp s))
	(let ((name (symbol-name s)))
	  (unless (gethash name seen)
	    (setf (gethash name seen) t)
	    (push (cons name s) table)))))
    (sort table #'string< :key #'car)))

(defun fuzzy-mx-order-candidates (names history)
  "NAMES を「HISTORY にあるものが履歴順で先、残りは元の順」に並べ替える。"
  (let ((known (make-hash-table :test #'equal))
	(recent nil))
    (dolist (n names) (setf (gethash n known) t))
    (dolist (h history)
      (when (gethash h known)
	(push h recent)
	;; 同じ名前を 2 度出さない。
	(remhash h known)))
    (append (nreverse recent)
	    (remove-if-not #'(lambda (n) (gethash n known)) names))))

(defun fuzzy-mx-add-history (name)
  (setq *fuzzy-mx-history*
	(cons name (delete name *fuzzy-mx-history* :test #'string=)))
  (when (> (length *fuzzy-mx-history*) *fuzzy-mx-history-max*)
    (setq *fuzzy-mx-history*
	  (subseq *fuzzy-mx-history* 0 *fuzzy-mx-history-max*))))

(defun fuzzy-mx-format-keys (seq)
  "キーシーケンス (文字、または文字のリスト) を表示用の文字列にする。"
  (if (characterp seq)
      (format nil "~:C" seq)
    (format nil "~{~:C~^ ~}" seq)))

(defun fuzzy-mx-key-annotation (sym)
  "SYM に割り当てられているキーのうち一番短いものを返す。無ければ nil。

一番短いものを選ぶのは、一覧の目的が「近道を知る」ことなので、
C-x C-f と F2 が両方あるなら F2 を出したいから。"
  (let ((seqs (ignore-errors
		(expand-command-keys
		 (command-keys sym *global-keymap* (local-keymap))))))
    (when seqs
      (fuzzy-mx-format-keys
       (car (sort seqs #'<
		  :key #'(lambda (s) (if (characterp s) 1 (length s)))))))))

(defun fuzzy-mx-annotator (table)
  "コマンド名から割り当てキーを返す関数を作る。TABLE は
fuzzy-command-table の返り値。"
  #'(lambda (name)
      (let ((sym (cdr (assoc name table :test #'string=))))
	(and sym (fuzzy-mx-key-annotation sym)))))

(defun fuzzy-execute-extended-command (&optional raw arg)
  "コマンド名をファジー絞り込みで選んで実行する (M-x)。

空白で区切って複数のキーワードを打つと、順不同でどれも含むものに絞られる
(\"buf list\" で list-buffers が出る)。"
  (interactive "P\np")
  (if (not *fuzzy-mx-mode*)
      (call-interactively 'execute-extended-command)
    (let* ((table (fuzzy-command-table))
	   (names (fuzzy-mx-order-candidates (mapcar #'car table)
					     *fuzzy-mx-history*))
	   (name (fuzzy-completing-read "M-x " names
					:must-match t
					:annotate (and *fuzzy-mx-annotate*
						       (fuzzy-mx-annotator table)))))
      (if (null name)
	  (progn (message "Quit") nil)
	(let ((command (cdr (assoc name table :test #'string=))))
	  (fuzzy-mx-add-history name)
	  (execute-extended-command command raw arg))))))

(define-key esc-map #\x 'fuzzy-execute-extended-command)
