;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "project")

(in-package "editor")

(export '(*project-root-markers*
	  *project-list*
	  *project-ignored-directories*
	  project-current-root
	  project-find-file
	  project-grep
	  project-filer
	  project-open-terminal
	  project-switch-project
	  project-remember-project
	  project-list-files))

(defvar *project-root-markers*
  '(".git" ".project" "CMakeLists.txt" "package.json" "Cargo.toml"
    "go.mod" "pyproject.toml" "Makefile" "pom.xml" "build.gradle"
    ".hg" ".svn")
  "プロジェクトルートを判定するためのマーカーファイルまたはディレクトリのリスト。")

(defvar *project-ignored-directories*
  '(".git" ".svn" ".hg" ".bzr" "_build" "build" "node_modules"
    "target" "dist" ".xyzzy.d" ".idea" ".vscode" "__pycache__")
  "プロジェクト内ファイル走査時に無視するディレクトリ名のリスト。")

(define-history-variable *project-list* nil
  "過去に開いたプロジェクトルートのリスト。")

(defun project-find-root-directory (start-dir)
  "start-dir から親ディレクトリを遡り、プロジェクトルートを探す。"
  (let ((dir (namestring (directory-namestring (truename start-dir)))))
    (while (and dir (stringp dir) (not (string= dir "")))
      (dolist (marker *project-root-markers*)
	(let ((path (merge-pathnames marker dir)))
	  (when (file-exist-p path)
	    (return-from project-find-root-directory (namestring (directory-namestring path))))))
      (let ((parent (namestring (directory-namestring (remove-trail-slash dir)))))
	(if (or (null parent) (string= parent dir) (string= parent ""))
	    (return nil)
	  (setq dir parent))))
    nil))

(defun project-current-root (&optional dir)
  "現在のバッファまたは指定ディレクトリのプロジェクトルートを取得する。
見つからない場合は現在のディレクトリを返す。"
  (let* ((base (or dir
		   (get-buffer-file-name)
		   (default-directory)))
	 (root (when base (project-find-root-directory base))))
    (if root
	(namestring (directory-namestring root))
      (namestring (directory-namestring (or base (default-directory)))))))

(defun project-remember-project (&optional (root (project-current-root)))
  "プロジェクトルートを *project-list* に追加・更新する。"
  (when (and root (stringp root))
    (setq root (namestring (directory-namestring root)))
    (setq *project-list* (delete root *project-list* :test #'string-equal))
    (push root *project-list*)
    (when (> (length *project-list*) 50)
      (setq *project-list* (subseq *project-list* 0 50)))))

(defun project-collect-files-recursive (dir root-len)
  "ディレクトリを再帰走査して相対ファイルパスのリストを返す。"
  (let (results)
    (dolist (entry (directory dir :wild "*.*" :file-only t))
      (let* ((full (namestring entry))
	     (rel (subseq full root-len)))
	(push rel results)))
    (dolist (subdir (directory dir :wild "*.*" :directory-only t))
      (let* ((name (pathname-name (remove-trail-slash (namestring subdir)))))
	(unless (member name *project-ignored-directories* :test #'string-equal)
	  (setq results (nconc results
			       (project-collect-files-recursive (namestring subdir) root-len))))))
    results))

(defun project-list-files (&optional (root (project-current-root)))
  "プロジェクト内の全ファイル相対パスのリストを返す。"
  (let* ((root-dir (namestring (directory-namestring root)))
	 (root-len (length root-dir)))
    (project-collect-files-recursive root-dir root-len)))

(defun project-find-file (&optional (root (project-current-root)))
  "プロジェクトルート配下のファイルを補完選択して開く。"
  (interactive)
  (let* ((proj-root (or root (project-current-root)))
	 (files (project-list-files proj-root)))
    (unless files
      (message "No files found in project: ~A" proj-root)
      (return-from project-find-file nil))
    (let ((selected (completing-read (format nil "Find in [~A]: "
					    (pathname-name (remove-trail-slash proj-root)))
				     files
				     :must-match t)))
      (when (and selected (stringp selected) (not (string= selected "")))
	(project-remember-project proj-root)
	(find-file (merge-pathnames selected proj-root))))))

(defun project-filer (&optional (root (project-current-root)))
  "プロジェクトルートでファイラを開く。"
  (interactive)
  (let ((proj-root (or root (project-current-root))))
    (project-remember-project proj-root)
    (open-filer proj-root)))

(defun project-open-terminal (&optional (root (project-current-root)))
  "プロジェクトルートを作業ディレクトリとしてターミナルを起動する。"
  (interactive)
  (let ((proj-root (or root (project-current-root))))
    (project-remember-project proj-root)
    (let ((default-dir (default-directory)))
      (set-default-directory proj-root)
      (if (fboundp 'terminal)
	  (funcall (symbol-function 'terminal))
	(open-filer proj-root)))))

(defun project-switch-project ()
  "過去に訪れたプロジェクト一覧から選択して切り替える。"
  (interactive)
  (unless *project-list*
    (message "No remembered projects.")
    (return-from project-switch-project nil))
  (let ((chosen (completing-read "Switch to project: " *project-list* :must-match t)))
    (when (and chosen (stringp chosen) (not (string= chosen "")))
      (project-find-file chosen))))

(defun project-grep (pattern &optional (root (project-current-root)))
  "プロジェクトルート配下のファイルを対象に Grep を実行する。"
  (interactive "sProject Grep: ")
  (let* ((proj-root (or root (project-current-root)))
	 (files (project-list-files proj-root)))
    (project-remember-project proj-root)
    (long-operation
      (with-output-to-temp-buffer ("*compilation*")
	(let ((sbuffer (buffer-stream-buffer *standard-output*))
	      (scanner (compile-regexp pattern *case-fold-search*))
	      (match-count 0))
	  (dolist (rel files)
	    (let ((full (merge-pathnames rel proj-root)))
	      (when (file-exist-p full)
		(with-open-file (stream full :direction :input :if-does-not-exist nil)
		  (when stream
		    (let ((line-num 0))
		      (while (let ((line (read-line stream nil nil)))
			       (when line
				 (setq line-num (1+ line-num))
				 (when (string-match scanner line)
				   (setq match-count (1+ match-count))
				   (format t "~A:~D:~A~%" full line-num line))
				 t)))))))))
	  (format t "~%~D matches found in ~A~%" match-count proj-root)
	  (setup-temp-buffer sbuffer))))))

;;;
;;; Leader Key への登録
;;;

(when (boundp '*leader-project-map*)
  (define-key *leader-project-map* #\f 'project-find-file)
  (define-key *leader-project-map* #\g 'project-grep)
  (define-key *leader-project-map* #\d 'project-filer)
  (define-key *leader-project-map* #\t 'project-open-terminal)
  (define-key *leader-project-map* #\p 'project-switch-project)
  (define-key *leader-project-map* #\r 'project-remember-project)

  (when (fboundp 'which-key-add-description)
    (which-key-add-description 'project-find-file "FindFile")
    (which-key-add-description 'project-grep "Grep")
    (which-key-add-description 'project-filer "Filer")
    (which-key-add-description 'project-open-terminal "Terminal")
    (which-key-add-description 'project-switch-project "Switch")
    (which-key-add-description 'project-remember-project "Remember")))
