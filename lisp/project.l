;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "project")

(in-package "editor")

(require "fuzzy-complete")

(export '(parent-directory
	  *project-root-markers*
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

(defun parent-directory (dir)
  "DIR の親ディレクトリ。これ以上遡れなければ nil。

**「短くなったこと」で判定するのが要点である。** 上へ遡るのに
`(directory-namestring (remove-trail-slash dir))` を使うが、Windows の `C:` は
「ドライブ C: のカレントディレクトリ」を意味するので、`C:/` を渡すと

    C:/  ->  C:  ->  C:/Users/ykuwa/Downloads/xyzzy-latest/xyzzy-amd64/

と **長い方へ戻ってくる**。「親が自分と同じなら終わり」だけを見ていると、
そこから同じ数ディレクトリを永久に巡回する。**実機の Windows で、起動直後に
CPU 100% で応答が無くなる形で踏んだ。** container の Wine ではカレント
ドライブが Z: だったため `C:` が `C:/` を返し、再現しなかった。

長さが必ず 1 以上減ることを条件にすれば、正の整数が単調減少するので必ず
止まる。親が長くなる場合 (8.3 形式の展開など) はそこで遡るのをやめるが、
「それ以上上に何かを探しに行かない」だけで害は無い。"
  (when (and dir (stringp dir) (plusp (length dir)))
    (let ((parent (ignore-errors
                    (directory-namestring (remove-trail-slash dir)))))
      (and parent
	   (stringp parent)
	   (plusp (length parent))
	   (< (length parent) (length dir))
	   parent))))

(defun project-find-root-directory (start-dir)
  "start-dir から親ディレクトリを遡り、プロジェクトルートを探す。"
  (let* ((tn (truename start-dir))
	 ;; truename は末尾の "/" を落とすことがある (実測済み)。start-dir が
	 ;; ディレクトリだった場合、その結果をそのまま directory-namestring に
	 ;; 通すと最後のディレクトリ名をファイル名と誤認し、1階層上から探索を
	 ;; 始めてしまう (実際に踏んだ)。ディレクトリなら末尾 "/" を補うだけに
	 ;; し、ファイルの場合だけ directory-namestring で親ディレクトリを取る。
	 (dir (if (file-directory-p tn)
		  (concat (remove-trail-slash (namestring tn)) "/")
		(directory-namestring tn))))
    (while (and dir (stringp dir) (not (string= dir "")))
      (dolist (marker *project-root-markers*)
	(let ((path (merge-pathnames marker dir)))
	  (when (file-exist-p path)
	    (return-from project-find-root-directory (directory-namestring path)))))
      (let ((parent (parent-directory dir)))
	(if parent
	    (setq dir parent)
	  (return nil))))
    nil))

(defun project-current-root (&optional dir)
  "現在のバッファまたは指定ディレクトリのプロジェクトルートを取得する。
見つからない場合は現在のディレクトリを返す。"
  (let* ((base (or dir
		   (get-buffer-file-name)
		   (default-directory)))
	 (root (when base (project-find-root-directory base))))
    (if root
	(directory-namestring root)
      (directory-namestring (or base (default-directory))))))

(defun project-remember-project (&optional (root (project-current-root)))
  "プロジェクトルートを *project-list* に追加・更新する。"
  (when (and root (stringp root))
    (setq root (directory-namestring root))
    (setq *project-list* (delete root *project-list* :test #'string-equal))
    (push root *project-list*)
    (when (> (length *project-list*) 50)
      (setq *project-list* (subseq *project-list* 0 50)))))

(defun project-ignored-directory-p (path)
  "PATH が *project-ignored-directories* に載っているディレクトリなら t。

file-directory-p 等が失敗する場合 (実 Windows 環境の CI で、ビルド直後の
ロックされたファイルに対して file I/O エラーになるのを確認済み) は
無視すべきディレクトリではない (=このエントリは結果に残す) ものとして
扱い、その1件のせいで走査全体が失敗しないようにする。"
  (ignore-errors
    (and (file-directory-p path)
	 (member (pathname-name (remove-trail-slash (namestring path)))
		 *project-ignored-directories* :test #'string-equal))))

(defun project-list-files (&optional (root (project-current-root)))
  "プロジェクト内の全ファイル相対パスのリストを返す。

directory の :wild \"*.*\" はドットを含まない名前 (lisp, docs, src, ...)
にマッチするかどうかが処理系・環境で揺れる (Wine 上の実測ではマッチせず、
再帰がほとんどのディレクトリへ降りて行けなかった)。:wild を使わず、
directory 自身の :recursive/:test に丸ごと任せる。:test はディレクトリに
対して呼ばれたとき nil を返すとその配下ごと無視されるので、これで
*project-ignored-directories* を一括で除外できる。"
  (let* ((root-dir (directory-namestring root))
	 (root-len (length root-dir)))
    (mapcar #'(lambda (path) (subseq (namestring path) root-len))
	    (directory root-dir
		       :recursive t
		       :file-only t
		       :absolute t
		       :test #'(lambda (path) (not (project-ignored-directory-p path)))))))

(defun project-find-file (&optional (root (project-current-root)))
  "プロジェクトルート配下のファイルを補完選択して開く。"
  (interactive)
  (let* ((proj-root (or root (project-current-root)))
	 (files (project-list-files proj-root)))
    (unless files
      (message "No files found in project: ~A" proj-root)
      (return-from project-find-file nil))
    (let ((selected (fuzzy-completing-read
		     (format nil "Find in [~A]: "
			     (pathname-name (remove-trail-slash proj-root)))
		     files :must-match t)))
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
  (let ((chosen (fuzzy-completing-read "Switch to project: " *project-list* :must-match t)))
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
