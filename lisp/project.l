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
	  project-list-files
	  *project-frame-history*
	  project-frame-root
	  project-bind-frame
	  project-unbind-frame
	  project-switch-to-project
	  project-restore-project-frames
	  project-frame-save-history
	  *project-build-config-file*
	  *project-build-allowed-variables*
	  project-parse-build-config
	  project-read-build-config
	  project-apply-build-config
	  project-default-build-command))

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
見つからない場合は現在のディレクトリを返す。
DIR を省略した場合は、現在の pseudo-frame にプロジェクトが紐付いていれば
バッファ由来よりそちらを優先する (issue #424)。"
  (let ((frame-root (and (null dir) (project-frame-root))))
    (if frame-root
	frame-root
      (let* ((base (or dir
		       (get-buffer-file-name)
		       (default-directory)))
	     (root (when base (project-find-root-directory base))))
	(if root
	    (directory-namestring root)
	  (directory-namestring (or base (default-directory))))))))

(defun project-remember-project (&optional (root (project-current-root)))
  "プロジェクトルートを *project-list* に追加・更新する。"
  (when (and root (stringp root))
    (setq root (directory-namestring root))
    (setq *project-list* (delete root *project-list* :test #'string-equal))
    (push root *project-list*)
    (when (> (length *project-list*) 50)
      (setq *project-list* (subseq *project-list* 0 50)))))

;;;
;;; pseudo-frame との紐付け (issue #424)
;;;
;;; frame は「プロジェクトの既定 root を持つ workspace」。バッファは隔離
;;; しない (persp-mode ではなく eyebrowse に近い)。紐付けは frame オブジェクト
;;; をキーにした alist で持ち、削除済み frame のエントリはアクセス時に掃除する。
;;; 1 プロジェクトに複数 frame を紐付けられる。

(defvar *project-frame-root-alist* nil
  "pseudo-frame オブジェクトをキー、プロジェクトルートを値とする alist。")

(define-history-variable *project-frame-history* nil
  "永続化する (pseudo-frame 名 . プロジェクトルート) の alist。
frame オブジェクトは再起動で同一性が保てないので、永続化は名前経由にする。")

(defun project-normalize-root (root)
  "ROOT を末尾 \"/\" 付きのディレクトリ名に正規化する。
directory-namestring は末尾 \"/\" の無い入力の最後の要素をファイル名と
みなして落としてしまう (\"Z:/a\" -> \"Z:/\") ので、ここでは文字列として
処理する。"
  (concat (remove-trail-slash (namestring root)) "/"))

(defun project-frame-prune ()
  "削除済み frame のエントリを *project-frame-root-alist* から取り除く。"
  (setq *project-frame-root-alist*
	(remove-if-not #'(lambda (e) (member (car e) *pseudo-frame-list* :test #'eq))
		       *project-frame-root-alist*)))

(defun project-frame-root (&optional (frame (selected-pseudo-frame)))
  "FRAME (省略時は現在の pseudo-frame) に紐付いたプロジェクトルート。
無ければ nil。"
  (project-frame-prune)
  (cdr (assoc frame *project-frame-root-alist*)))

(defun project-find-frame-for-root (root)
  "ROOT に紐付いた pseudo-frame を返す。無ければ nil。"
  (project-frame-prune)
  (car (find root *project-frame-root-alist*
	     :key #'cdr :test #'string-equal)))

(defun project-bind-frame (root &optional frame)
  "FRAME (省略時は現在の pseudo-frame) をプロジェクト ROOT に紐付ける。"
  (interactive (list (read-directory-name "Bind frame to project: "
					  :default (project-current-root))))
  (let ((frame (or frame (selected-pseudo-frame))))
    (unless frame
      (error "pseudo-frame がありません"))
    (setq root (project-normalize-root root))
    (project-frame-prune)
    (let ((e (assoc frame *project-frame-root-alist*)))
      (if e
	  (setf (cdr e) root)
	(push (cons frame root) *project-frame-root-alist*)))
    (project-remember-project root)
    (project-frame-save-history)
    root))

(defun project-unbind-frame (&optional (frame (selected-pseudo-frame)))
  "FRAME (省略時は現在の pseudo-frame) のプロジェクト紐付けを解除する。"
  (interactive)
  (setq *project-frame-root-alist*
	(delete frame *project-frame-root-alist* :key #'car))
  (project-frame-save-history)
  t)

(defun project-frame-name-for-root (root)
  "ROOT から pseudo-frame 名を作る。既存名と重なれば \" (2)\" 等を付ける。"
  (let* ((base (or (pathname-name (remove-trail-slash (namestring root)))
		   "project"))
	 (name base)
	 (n 2))
    (while (find-pseudo-frame name)
      (setq name (format nil "~A (~D)" base n))
      (incf n))
    name))

(defun project-ensure-frame-context ()
  "pseudo-frame が 1 つも無ければ初期フレームを作る。
端末フロントエンド等、init-pseudo-frame が走っていない環境用。"
  (unless *pseudo-frame-list*
    (init-pseudo-frame)))

(defun project-switch-to-project (root)
  "ROOT のプロジェクトに紐付いた pseudo-frame を選択する。
無ければプロジェクト名で frame を新規作成して紐付ける。
値は (frame 新規作成したか)。"
  (project-ensure-frame-context)
  (setq root (project-normalize-root root))
  (let ((frame (project-find-frame-for-root root)))
    (if frame
	(progn
	  (select-pseudo-frame frame)
	  (values frame nil))
      (let ((frame (create-pseudo-frame (project-frame-name-for-root root))))
	(project-bind-frame root frame)
	(values frame t)))))

(defun project-frame-save-history ()
  "現在の紐付けを (frame 名 . root) の形で *project-frame-history* に保存する。
*save-history-hook* から呼ばれ、frame の現在名でスナップショットを取る。"
  (project-frame-prune)
  (setq *project-frame-history*
	(mapcar #'(lambda (e) (cons (pseudo-frame-name (car e)) (cdr e)))
		*project-frame-root-alist*)))

(defun project-restore-project-frames ()
  "*project-frame-history* に保存された紐付けから pseudo-frame を再生成する。
既に同名の frame があれば新規作成せずそれに紐付ける。起動時に使うには
siteinit で (project-restore-project-frames) を呼ぶ。"
  (interactive)
  (let ((current (selected-pseudo-frame)))
    (dolist (e *project-frame-history*)
      (let* ((name (car e))
	     (root (cdr e))
	     (frame (or (find-pseudo-frame name)
			(create-pseudo-frame name))))
	(project-bind-frame root frame)))
    ;; create-pseudo-frame は新しい frame を選択するので、最後に作ったものが
    ;; 残らないよう元の frame に戻す。
    (when (member current *pseudo-frame-list* :test #'eq)
      (select-pseudo-frame current))))

(add-hook '*save-history-hook* 'project-frame-save-history)

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
  "過去に訪れたプロジェクト一覧から選択して切り替える。
プロジェクトに紐付いた pseudo-frame があればそれを選択し、無ければ
プロジェクト名で新規作成して紐付ける (issue #424)。"
  (interactive)
  (unless *project-list*
    (message "No remembered projects.")
    (return-from project-switch-project nil))
  (let ((chosen (fuzzy-completing-read "Switch to project: " *project-list* :must-match t)))
    (when (and chosen (stringp chosen) (not (string= chosen "")))
      (multiple-value-bind (frame created-p)
	  (project-switch-to-project chosen)
	;; 新規 frame は空のウィンドウだけなので、旧来の動作に合わせて
	;; ファイル選択を開く。既存 frame は保存済みの構成をそのまま見せる。
	(when created-p
	  (project-find-file chosen))))))

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
  (define-key *leader-project-map* #\b 'project-bind-frame)

  (when (fboundp 'which-key-add-description)
    (which-key-add-description 'project-find-file "FindFile")
    (which-key-add-description 'project-grep "Grep")
    (which-key-add-description 'project-filer "Filer")
    (which-key-add-description 'project-open-terminal "Terminal")
    (which-key-add-description 'project-switch-project "Switch")
    (which-key-add-description 'project-remember-project "Remember")
    (which-key-add-description 'project-bind-frame "BindFrame")))

;;; ------------------------------------------------------------------
;;; プロジェクトごとのビルド設定 (issue #418)
;;;
;;; <project>/.xyzzy.d/build.l に置く設定を `build' / `wsl-compile'
;;; の既定値として読む。グローバルな .xyzzy に全プロジェクトの
;;; 対応表を書かなくて済むようにするためのもの。

(defvar *project-build-config-file* ".xyzzy.d/build.l"
  "プロジェクトルートからの相対パス。ビルド設定ファイル名。")

(defvar *project-build-allowed-variables* '(*compile-command*)
  "build.l で代入を許す変数のホワイトリスト。
任意コード実行を避けるため、リストに無いシンボルへの代入は
全部捨てる。")

(defun project-safe-config-literal-p (v)
  "build.l で代入を許す「リテラル」か。
文字列・数値・文字・t/nil だけ。リストやフォーム評価は不可。"
  (or (stringp v) (numberp v) (characterp v)
      (or (eq v t) (eq v nil))))

(defun project-parse-build-config (text)
  "build.l の内容 TEXT を (変数 . 値) の alist で返す。

**eval しない。** clone した他人のプロジェクトを開くだけで任意
コードが走るのを防ぐため、(setq VAR LITERAL) / (setq-local VAR
LITERAL) の形で VAR が *project-build-allowed-variables* にあり
LITERAL が `project-safe-config-literal-p' を満たすトップレベル
フォームだけを拾う。それ以外は (コメント含め) 全部無視。"
  (let ((result nil)
	(s (make-string-input-stream text)))
    (loop
      ;; 読めない形 (閉じ忘れ等) で止まっても、そこまで読めた分は返す
      (let ((form (ignore-errors (read s nil :eof))))
	(when (or (null form) (eq form :eof))
	  (return (nreverse result)))
	;; **シンボル名で比較する。** ユーザーの .xyzzy.d/build.l は
	;; *package* が user なので read で user 側に intern されるが、
	;; ホワイトリストは editor 側のシンボルを指す。名前で照合して、
	;; 値は editor 側のシンボルとして持つ (build が見るのはこちら)。
	;; symbol-name はこの処理系では小文字を返す。
	(let* ((car-name (and (symbolp (car form))
			      (symbol-name (car form))))
	       (var-name (and (consp (cdr form))
			      (symbolp (cadr form))
			      (symbol-name (cadr form))))
	       (var (and var-name
			 (find var-name *project-build-allowed-variables*
			       :key #'symbol-name :test #'string=))))
	  (when (and (member car-name '("setq" "setq-local") :test #'string=)
		     var
		     (project-safe-config-literal-p (caddr form)))
	    (push (cons var (caddr form)) result)))))))

(defun project-read-build-config (&optional dir)
  "DIR (省略時はプロジェクトルート) から build.l を探して
project-parse-build-config する。ファイルが無ければ nil。"
  (let ((path (merge-pathnames *project-build-config-file*
			       (or dir (project-current-root)))))
    (and (file-exist-p path)
	 (ignore-errors
	   (let ((buf (get-buffer-create " *project-build-config*")))
	     (save-excursion
	       (set-buffer buf)
	       (erase-buffer buf)
	       (insert-file-contents path)
	       (project-parse-build-config
		(buffer-substring (point-min) (point-max)))))))))

(defun project-apply-build-config (&optional dir)
  "build.l を読んで、許可変数をカレントバッファの buffer-local に
立てる。適用した alist を返す (ファイルが無ければ nil)。"
  (let ((config (project-read-build-config dir)))
    (dolist (cell config)
      (make-local-variable (car cell))
      (set (car cell) (cdr cell)))
    config))

(defun project-default-build-command (&optional dir)
  "`build' の既定値。build.l > *compile-command* > \"make\" の順。"
  (or (cdr (assoc '*compile-command* (project-read-build-config dir)))
      (and (boundp '*compile-command*) *compile-command*)
      "make"))
