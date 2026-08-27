;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/memo.l のテスト。
;;;
;;; open-memo は実際にファイルを作るので、*memo-directory* を一時ディレクトリに
;;; 向けてから呼ぶ。向けずに走らせるとユーザの設定ディレクトリを汚す。

(require "memo")

(defmacro with-temp-memo-dir ((var) &body body)
  "一時ディレクトリを *memo-directory* にして BODY を実行し、後で消す。"
  `(let* ((,var (merge-pathnames
		 (format nil "memo-test-~A/" (symbol-name (gensym)))
		 (si:system-root)))
	  (ed::*memo-directory* ,var))
     (unwind-protect
	 (progn ,@body)
       (dolist (f (ignore-errors (directory ,var :absolute t :file-only t)))
	 (ignore-errors (delete-file f)))
       (ignore-errors (delete-directory ,var)))))

(deftest memo-directory-is-created ()
  "無ければディレクトリを作り、末尾を / で揃えて返すこと"
  (with-temp-memo-dir (dir)
    (let ((d (ed::memo-directory)))
      (values (file-exist-p d)
	      (char= (char d (1- (length d))) #\/))))
  => t
  => t)

(deftest memo-file-name-uses-the-date ()
  "ファイル名が日付の書式から作られること"
  (with-temp-memo-dir (dir)
    (let* ((ed::*memo-file-name-format* "%Y-%m-%d.md")
	   (name (file-namestring (ed::memo-file-name))))
      (values (length name)
	      (and (string-match "^[0-9]\\{4\\}-[0-9][0-9]-[0-9][0-9]\\.md$" name) t))))
  => 13
  => t)

(deftest memo-opens-and-writes-a-heading ()
  "その日のファイルを開き、時刻の見出しを付けること"
  (with-temp-memo-dir (dir)
    (let ((ed::*memo-heading-format* "## FIXED-HEADING"))
      (ed::open-memo)
      (let* ((buf (selected-buffer))
	     (contents (buffer-substring (point-min) (point-max)))
	     (has-heading (and (string-match "## FIXED-HEADING" contents) t))
	     ;; 末尾に居ること (すぐ書き始められる)
	     (at-end (= (point) (point-max))))
	;; prog1 は 1 つ目の値しか返さないので、先に取っておいてから片付ける。
	(set-buffer-modified-p nil)
	(delete-buffer buf)
	(values has-heading at-end))))
  => t
  => t)

(deftest memo-does-not-repeat-the-same-heading ()
  "同じ見出しが既にあれば重ねないこと (同じ分に 2 回呼んでも 1 つ)"
  (with-temp-memo-dir (dir)
    (let ((ed::*memo-heading-format* "## FIXED-HEADING"))
      (ed::open-memo)
      (insert "one\n")
      (ed::open-memo)
      (let* ((buf (selected-buffer))
	     (contents (buffer-substring (point-min) (point-max)))
	     (n 0)
	     (start 0))
	(while (setq start (string-match "## FIXED-HEADING" contents start))
	  (incf n)
	  (incf start 1))
	(prog1 n
	  (set-buffer-modified-p nil)
	  (delete-buffer buf)))))
  => 1)

(deftest memo-no-heading-when-format-is-nil ()
  "*memo-heading-format* が nil なら見出しを付けないこと"
  (with-temp-memo-dir (dir)
    (let ((ed::*memo-heading-format* nil))
      (ed::open-memo)
      (let ((buf (selected-buffer))
	    (contents (buffer-substring (point-min) (point-max))))
	(prog1 contents
	  (set-buffer-modified-p nil)
	  (delete-buffer buf)))))
  => "")

(deftest open-scratch-recreates-it ()
  "*scratch* が消えていても作り直して跳べること"
  (save-window-excursion
    (let ((scratch (find-buffer "*scratch*")))
      (when scratch
	(set-buffer-modified-p nil scratch)
	(delete-buffer scratch)))
    (ed::open-scratch)
    (values (buffer-name (selected-buffer))
	    (and (find-buffer "*scratch*") t)))
  => "*scratch*"
  => t)

(deftest memo-leader-bindings ()
  "Leader o s / o m / o M に割り当てられていること"
  (values (lookup-keymap ed::*leader-map* #\o)
	  (lookup-keymap ed::*leader-open-map* #\s)
	  (lookup-keymap ed::*leader-open-map* #\m)
	  (lookup-keymap ed::*leader-open-map* #\M))
  => #.ed::*leader-open-map*
  => open-scratch
  => open-memo
  => open-memo-directory)
