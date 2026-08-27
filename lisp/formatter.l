;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 外部フォーマッタでバッファを整形する / 保存時に整形する
;;; (Emacs の format-all / prettier 連携相当)。
;;;
;;; 一番大事なのは「失敗したときにバッファを壊さない」ことである。
;;; フォーマッタは入っていないこともあれば、構文エラーで何も出さずに
;;; 終わることもある。そのまま差し替えるとファイルが空になる。
;;; formatter-run は
;;;
;;;   * コマンドが起動できなかった
;;;   * 終了コードが 0 でなかった
;;;   * 出力が空だった
;;;
;;; のいずれでもバッファに触らず nil を返す。差し替えるのは
;;; 「0 で終わって、空でない出力が、今の内容と違う」ときだけ。
;;;
;;; 保存時の整形 (*format-on-save*) と空白の掃除
;;; (*on-save-trim-trailing-whitespace*, *on-save-ensure-final-newline*) は
;;; **どれも既定で無効** にしてある。保存のたびにユーザのファイルを黙って
;;; 書き換える設定を、こちらが勝手に入れるべきではない。既にある行末空白を
;;; 一斉に落とすと、共同作業しているリポジトリでは差分が本題を埋めてしまう。
;;; M-x format-buffer は既定でも使えるので、まずそれで様子を見て、気に入れば
;;; 1 行で有効にできる。
;;;

(provide "formatter")

(in-package "editor")

(export '(format-buffer
	  *formatter-alist*
	  *format-on-save*
	  *on-save-trim-trailing-whitespace*
	  *on-save-ensure-final-newline*
	  toggle-format-on-save))

(defvar *formatter-alist*
  '((c-mode          . "clang-format")
    (c++-mode        . "clang-format")
    (csharp-mode     . "clang-format")
    (java-mode       . "clang-format")
    (python-mode     . "black -q -")
    (javascript-mode . "prettier --stdin-filepath \"~A\"")
    (typescript-mode . "prettier --stdin-filepath \"~A\"")
    (json-mode       . "prettier --stdin-filepath \"~A\"")
    (css-mode        . "prettier --stdin-filepath \"~A\"")
    (yaml-mode       . "prettier --stdin-filepath \"~A\"")
    (markdown-mode   . "prettier --stdin-filepath \"~A\"")
    (html+-mode      . "prettier --stdin-filepath \"~A\"")
    (xml-mode        . "prettier --stdin-filepath \"~A\"")
    (shell-script-mode . "shfmt")
    (cmake-mode      . "cmake-format -"))
  "モード (buffer-mode の値) ごとの整形コマンド。

コマンドは標準入力からバッファ全体を受け取り、整形結果を標準出力へ書く
ものであること。文字列に `~A' が含まれていればバッファのファイル名に
置き換わる: prettier のように、内容ではなくファイル名で書式を決める
フォーマッタのため。

Lisp モードを入れていないのは、xyzzy が自前のインデント
(`lisp-indent-line') を持っており、外部に出す理由が無いため。")

(defvar *format-on-save* nil
  "non-nil なら、保存時に *formatter-alist* のコマンドで整形する。
既定で nil なのは、保存のたびにファイルを黙って書き換える設定を
勝手に入れないため。")

(defvar *on-save-trim-trailing-whitespace* nil
  "non-nil なら、保存時に行末の空白を落とす。
既定で nil なのは、既にある行末空白を一斉に落とすと共同作業している
リポジトリで差分が本題を埋めてしまうため。")

(defvar *on-save-ensure-final-newline* nil
  "non-nil なら、保存時にファイル末尾へ改行が無ければ足す。")

;;;
;;; 外部フォーマッタ
;;;

(defun formatter-command-for-buffer ()
  "このバッファに使う整形コマンドの文字列。無ければ nil。"
  (let ((spec (cdr (assoc buffer-mode *formatter-alist* :test #'eq))))
    (and spec
	 (if (find #\~ spec)
	     (format nil spec (or (get-buffer-file-name) (buffer-name (selected-buffer))))
	   spec))))

(defun formatter-file-contents (file encoding)
  "FILE の中身を文字列で返す。読めなければ nil。"
  (let ((buf (create-new-buffer " *formatter output*")))
    (unwind-protect
	(save-excursion
	  (set-buffer buf)
	  (when encoding
	    (set-buffer-fileio-encoding encoding))
	  (and (ignore-errors (insert-file-contents file))
	       (buffer-substring (point-min) (point-max))))
      (ignore-errors (delete-buffer buf)))))

(defun formatter-run (command &optional quiet)
  "COMMAND にバッファ全体を流し込み、結果で差し替える。
差し替えたら t、何もしなかったら nil。壊さない側に倒してあり、
失敗と空出力ではバッファに一切触らない。"
  (let ((infile (make-temp-file-name))
	(outfile (make-temp-file-name))
	(encoding (buffer-fileio-encoding))
	(line (current-line-number))
	(column (current-column)))
    (unwind-protect
	(progn
	  (write-region (point-min) (point-max) infile nil encoding)
	  (multiple-value-bind (cmdline dir)
	      (shell-command-line command (default-directory))
	    (let ((status (call-process cmdline
					:input infile
					:output outfile
					:exec-directory dir
					:show :hide
					:wait t)))
	      (cond
	       ((null status)
		(unless quiet
		  (message "フォーマッタを起動できませんでした: ~A" command))
		nil)
	       ((not (zerop status))
		(unless quiet
		  (message "フォーマッタが失敗しました (終了コード ~D): ~A"
			   status command))
		nil)
	       (t
		(let ((new (formatter-file-contents outfile encoding))
		      (old (buffer-substring (point-min) (point-max))))
		  (cond
		   ((null new)
		    (unless quiet
		      (message "フォーマッタの出力が読めませんでした: ~A" command))
		    nil)
		   ;; 空の出力で差し替えるとファイルが消える。0 で終わって
		   ;; いても信用しない。
		   ((zerop (length new))
		    (unless quiet
		      (message "フォーマッタが何も出力しませんでした: ~A" command))
		    nil)
		   ((string= new old)
		    (unless quiet (message "整形済みです"))
		    nil)
		   (t
		    (delete-region (point-min) (point-max))
		    (insert new)
		    (goto-line line)
		    (goto-column column)
		    (unless quiet (message "~A で整形しました" command))
		    t))))))))
      (ignore-errors (delete-file infile))
      (ignore-errors (delete-file outfile)))))

(defun format-buffer (&optional quiet)
  "外部フォーマッタ (*formatter-alist*) でバッファ全体を整形する。"
  (interactive "*")
  (let ((command (formatter-command-for-buffer)))
    (if (null command)
	(progn
	  (unless quiet
	    (message "~A モードの整形コマンドが *formatter-alist* にありません"
		     mode-name))
	  nil)
      (formatter-run command quiet))))

;;;
;;; 保存時の掃除
;;;

(defun formatter-trim-trailing-whitespace ()
  "行末の空白を落とす。落とした箇所の数を返す。"
  (let ((n 0))
    (save-excursion
      (goto-char (point-min))
      (while (scan-buffer "[ \t]+$" :regexp t)
	(delete-region (match-beginning 0) (match-end 0))
	(incf n)))
    n))

(defun formatter-ensure-final-newline ()
  "末尾に改行が無ければ足す。足したら t。"
  (save-excursion
    (goto-char (point-max))
    (when (and (/= (point-min) (point-max))
	       (not (bolp)))
      (insert "\n")
      t)))

(defun formatter-before-save ()
  "*before-save-buffer-hook* から呼ばれる。

このフックは run-hook-until-success なので、**non-nil を返すと保存が
中止される**。整形は保存の前処理であって代わりではないので、必ず nil を
返すこと。"
  (when (and (not buffer-read-only)
	     (get-buffer-file-name))
    (when *on-save-trim-trailing-whitespace*
      (formatter-trim-trailing-whitespace))
    (when *on-save-ensure-final-newline*
      (formatter-ensure-final-newline))
    (when *format-on-save*
      (ignore-errors (format-buffer t))))
  nil)

(defun toggle-format-on-save (&optional (arg nil sv))
  "保存時の整形の有効/無効を切り替える。"
  (interactive "p")
  (toggle-mode '*format-on-save* arg sv)
  (message "Format on save is ~:[disabled~;enabled~]" *format-on-save*))

(add-hook '*before-save-buffer-hook* 'formatter-before-save)
