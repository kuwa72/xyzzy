;;; -*- Mode: Lisp; Encoding: utf-8 -*-

(deftest test-sensible-defaults-backup-settings ()
  "バックアップディレクトリと階層バックアップがデフォルトで有効になっていること"
  (values
   (stringp ed::*backup-directory*)
   ed::*hierarchic-backup-directory*
   ;; merge-pathnames が第1引数の末尾 "/" を落とすことがある (実測済み) ため、
   ;; ディレクトリとして正しく "/" 終端されているかを明示的に確認する。
   (char= (char ed::*backup-directory* (1- (length ed::*backup-directory*))) #\/))
  => t
  => t
  => t)

(deftest test-sensible-defaults-backup-hook ()
  "make-backup-directory-hook が指定バックアップディレクトリ配下のパスを返すこと"
  (let* ((test-file (merge-pathnames "test-backup-sample.txt" (si:system-root)))
	 (backup-dir (ed::make-backup-directory-hook test-file)))
    (values
     (stringp backup-dir)
     (and (stringp backup-dir)
	  (not (null (string-matchp (directory-namestring ed::*backup-directory*) backup-dir))))))
  => t
  => t)

(deftest test-sensible-defaults-saveplace ()
  "saveplace によるカーソル位置の記録と復元ができること"
  (with-temp-files (file)
    (let ((ed::*save-place-alist* nil)
	  (ed::*save-place* t))
      ;; ファイルを準備
      (with-temp-buffer
	(insert "Line 1\nLine 2\nLine 3\nLine 4\n")
	(write-file file))
      ;; ファイルを開いてカーソルを移動し、位置を記録
      (let ((buf (ed::find-file-internal file)))
	(unwind-protect
	    (progn
	      (set-buffer buf)
	      (goto-char 10)
	      (ed::save-place-record-point buf))
	  (delete-buffer buf)))
      ;; 再度開いたときに位置が復元されるか
      (let ((buf (ed::find-file-internal file)))
	(unwind-protect
	    (progn
	      (set-buffer buf)
	      (point))
	  (delete-buffer buf)))))
  => 10)

(deftest test-sensible-defaults-saveplace-nonexistent-file ()
  "存在しないファイルに対して saveplace がエラーを起こさないこと。
コマンドラインで存在しないファイルを開くと空バッファができるが、
save-place-find-file-hook/save-place-record-point が truename を無条件に
呼んでいると、ファイルが無いだけで Win32 の raw error が飛び、find-file
自体や (バッファを閉じる際の) *before-delete-buffer-hook* が失敗していた。"
  (let ((ed::*save-place-alist* nil)
	(ed::*save-place* t)
	(file (merge-pathnames "xyzzy-saveplace-nonexistent-test.txt"
			       (si:system-root))))
    (when (file-exist-p file)
      (delete-file file))
    ;; 存在しないファイルを開くこと自体が (save-place-find-file-hook 経由で)
    ;; エラーにならないこと
    (let ((buf (ed::find-file-internal file)))
      (unwind-protect
	  (progn
	    (set-buffer buf)
	    ;; バッファを閉じる際に呼ばれる *before-delete-buffer-hook* 相当の
	    ;; 処理もエラーにならないこと
	    (ed::save-place-record-point buf)
	    t)
	(delete-buffer buf))))
  => t)

(deftest test-sensible-defaults-recentf ()
  "recentf による最近開いたファイルの記録とクリーンアップができること"
  (with-temp-files (file1 file2)
    (let ((ed::*recentf-list* nil))
      (with-temp-buffer (insert "test1") (write-file file1))
      (with-temp-buffer (insert "test2") (write-file file2))
      (ed::recentf-add-file file1)
      (ed::recentf-add-file file2)
      (let ((first-item (car ed::*recentf-list*))
	    (len (length ed::*recentf-list*)))
	(ed::recentf-add-file file1)
	(let ((new-first (car ed::*recentf-list*))
	      (new-len (length ed::*recentf-list*)))
	  (values
	   (path-equal first-item file2)
	   len
	   (path-equal new-first file1)
	   new-len)))))
  => t
  => 2
  => t
  => 2)
