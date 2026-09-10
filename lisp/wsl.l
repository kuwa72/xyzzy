;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; WSL (Windows Subsystem for Linux) integration for xyzzy
;;;

(provide "wsl")

(in-package "editor")

(require "terminal")

(export '(*wsl-distribution* *wsl-unc-prefix* *wsl-path-prefix* *wsl-command*
	  *wsl-mode-map* *wsl-mode-hook* *wsl-project-distro* *wsl-compile-buffer-name*
	  wsl-mode wsl wsl-shell
	  wsl-path-to-windows windows-path-to-wsl
	  wsl-parse-distributions wsl-list-distributions wsl-read-distribution
	  wsl-osc-52-sequence wsl-copy-string wsl-paste-string
	  wsl-copy-region wsl-paste
	  wsl-path-p wsl-extract-distro wsl-current-distro wsl-project-p
	  wsl-open-directory wsl-build-command-line wsl-git-command-line
	  wsl-translate-log-paths wsl-compile wsl-git))

;;; 設定変数
(defvar *wsl-distribution* nil
  "既定の WSL ディストリビューション名 (nil の場合はデフォルトディストリビューション)")

(defvar *wsl-unc-prefix* "\\\\wsl.localhost"
  "WSL ルートへのアクセスに使う UNC プレフィックス (Windows 11: \\\\wsl.localhost, Windows 10: \\\\wsl$)")

(defvar *wsl-path-prefix* "/mnt/"
  "Windows ドライブがマウントされている Linux 側のプレフィックス")

(defvar *wsl-command* "wsl.exe"
  "WSL 実行可能ファイル名")

(defvar *wsl-mode-hook* nil
  "wsl-mode 起動時のフック")

(defvar *wsl-mode-map* nil
  "wsl-mode のキーマップ")

(unless *wsl-mode-map*
  (setq *wsl-mode-map* (make-sparse-keymap))
  (define-key *wsl-mode-map* '(#\C-c #\C-c) 'terminal-send-ctrl-c)
  (define-key *wsl-mode-map* #\C-v 'wsl-paste)
  (define-key *wsl-mode-map* #\S-Insert 'wsl-paste))


;;; ------------------------------------------------------------------
;;; パス変換関数

(defun wsl-path-to-windows (path &optional distro unc-prefix)
  "Linux パス (例: /mnt/c/Users/... や /home/...) を Windows パスに変換する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (zerop (length path))
    (return-from wsl-path-to-windows path))
  ;; 既に Windows ドライブパスまたは UNC パスの場合はそのまま返す
  (when (or (string-match "^[a-zA-Z]:" path)
	    (string-match "^\\\\\\\\" path)
	    (string-match "^//" path))
    (return-from wsl-path-to-windows path))
  ;; /mnt/<drive-letter>... の形式
  (if (string-match "^/mnt/\\([a-zA-Z]\\)\\(/.*\\)?$" path)
      (let* ((drive (char-upcase (char (match-string 1) 0)))
	     (rest (match-string 2)))
	(cond ((or (null rest) (string= rest "") (string= rest "/"))
	       (format nil "~C:/" drive))
	      (t
	       (format nil "~C:~A" drive rest))))
    ;; /home/... などの WSL ルートパス
    (let* ((d (or distro *wsl-distribution* "Ubuntu"))
	   (prefix (or unc-prefix *wsl-unc-prefix* "\\\\wsl.localhost"))
	   (sep (if (string-match "^//" prefix) "/" "\\"))
	   (clean-prefix (substitute-string (substitute-string prefix "[/\\\\]+$" "") "^[/\\\\]+" ""))
	   (lead-sep (if (string-match "^//" prefix) "//" "\\\\"))
	   (body (if (string= sep "\\")
		     (map-slash-to-backslash path)
		   (map-backslash-to-slash path))))
      (unless (string-match "^[/\\\\]" body)
	(setq body (concat sep body)))
      (format nil "~A~A~A~A~A" lead-sep clean-prefix sep d body))))

(defun windows-path-to-wsl (path)
  "Windows パス (例: C:/Users/... や \\\\wsl.localhost\\...) を Linux パスに変換する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (zerop (length path))
    (return-from windows-path-to-wsl path))
  ;; 既に Linux パス (単一のスラッシュで始まる) の場合はそのまま返す
  (when (and (string-match "^/" path)
	     (not (string-match "^//" path)))
    (return-from windows-path-to-wsl path))
  (let ((norm (map-backslash-to-slash path)))
    ;; ドライブレター形式 (C:/... や C:...)
    (if (string-match "^\\([a-zA-Z]\\):\\(/.*\\)?$" norm)
	(let* ((drive (char-downcase (char (match-string 1) 0)))
	       (rest (match-string 2)))
	  (cond ((null rest)
		 (format nil "/mnt/~C" drive))
		((string= rest "")
		 (format nil "/mnt/~C/" drive))
		(t
		 (format nil "/mnt/~C~A" drive rest))))
      ;; WSL UNC パス (//wsl.localhost/... や //wsl$/...)
      (if (string-match "^//\\(wsl\\.localhost\\|wsl\\$\\)/\\([^/]+\\)\\(/.*\\)?$" norm)
	  (let ((rest (match-string 3)))
	    (if (or (null rest) (string= rest ""))
		"/"
	      rest))
	;; それ以外は正規化したスラッシュパスを返す
	norm))))


;;; ------------------------------------------------------------------
;;; ディストリビューション一覧の取得・パース

(defun wsl-parse-distributions (output)
  "wsl.exe -l -q の出力文字列をパースし、ディストリビューション名のリストを返す。
UTF-16LE 出力に含まれる NUL 文字や改行・空白を整形する。"
  (when (or (null output) (zerop (length output)))
    (return-from wsl-parse-distributions nil))
  (let* ((no-nul (substitute-string output "\0" ""))
	 (no-cr (substitute-string no-nul "\r" ""))
	 (lines (split-string no-cr "\n"))
	 (result nil))
    (dolist (line lines)
      (let ((trimmed (string-trim " \t" line)))
	(when (plusp (length trimmed))
	  (push trimmed result))))
    (nreverse result)))

(defun wsl-list-distributions ()
  "wsl.exe -l -q を実行し、利用可能なディストリビューション名のリストを返す。"
  (interactive)
  (let ((buf (create-new-buffer " *wsl-list*")))
    (unwind-protect
	(let ((status (ignore-errors
			(call-process (format nil "~A -l -q" *wsl-command*)
				      :output buf :show :hide :wait t))))
	  (if (and status (zerop status))
	      (save-excursion
		(set-buffer buf)
		(wsl-parse-distributions (buffer-substring (point-min) (point-max))))
	    nil))
      (delete-buffer buf))))

(defun wsl-read-distribution (&optional prompt)
  "ミニバッファからディストリビューション名を選択・入力させる。"
  (let ((distros (wsl-list-distributions)))
    (if distros
	(completing-read (or prompt "WSL Distribution: ")
			 distros
			 :default (or *wsl-distribution* (car distros)))
      (read-string (or prompt "WSL Distribution: ")
		   :default (or *wsl-distribution* "Ubuntu")))))


;;; ------------------------------------------------------------------
;;; クリップボード連携 / OSC 52

(defun wsl-osc-52-sequence (string &optional (target "c"))
  "文字列を base64 エンコードした OSC 52 エスケープシーケンスを生成する。"
  (let ((b64 (si:base64-encode string nil t)))
    (format nil "~C]52;~A;~A~C" (code-char #x1b) (or target "c") b64 (code-char 7))))

(defun wsl-copy-string (string)
  "文字列を Windows クリップボードおよび kill-ring にコピーする。"
  (copy-to-clipboard string)
  (when (fboundp 'kill-new)
    (kill-new string))
  string)

(defun wsl-paste-string ()
  "Windows クリップボードから文字列を取得する。"
  (get-clipboard-data))

(defun wsl-copy-region (start end)
  "カレントバッファの指定リージョンを Windows クリップボードにコピーする。"
  (interactive "r")
  (let ((str (buffer-substring start end)))
    (wsl-copy-string str)
    (message "リージョンをクリップボードにコピーしました")))

(defun wsl-paste ()
  "クリップボードの内容をターミナルプロセスまたはカレントバッファに貼り付ける。"
  (interactive)
  (let ((proc (buffer-process (selected-buffer)))
	(data (get-clipboard-data)))
    (cond ((not (stringp data))
	   (message "クリップボードに文字列がありません"))
	  ((and proc (si:process-terminal-p proc))
	   (si:terminal-paste-string proc data))
	  (t
	   (insert data)))))


;;; ------------------------------------------------------------------
;;; ターミナル連携 (wsl / wsl-shell)

(defun wsl-mode ()
  "WSL ターミナル用のメジャーモード。"
  (setq mode-name "WSL")
  (setq buffer-mode 'wsl-mode)
  (use-keymap *wsl-mode-map*)
  (setq need-not-save t)
  (setq auto-save nil)
  (setq kept-undo-information nil)
  (set-buffer-fold-width 80)
  (run-hooks '*wsl-mode-hook*))

(defun wsl (&optional distro dir)
  "カレントバッファのディレクトリに対応する WSL 側パスで wsl.exe ターミナルを起動する。
プレフィックス引数を与えるとディストリビューションを指定可能。"
  (interactive "P")
  (when (and (interactive-p) distro)
    (setq distro (wsl-read-distribution)))
  (let* ((target-distro (or distro *wsl-distribution*))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (buf-name (if target-distro
		       (format nil "*WSL:~A*" target-distro)
		     "*WSL*"))
	 (buf (get-buffer-create buf-name)))
    (set-buffer buf)
    (let ((proc (buffer-process (selected-buffer))))
      (if (and proc (eq (process-status proc) :run))
	  (switch-to-buffer buf)
	(let ((cmdline (format nil "~A~A~A"
			       *wsl-command*
			       (if target-distro
				   (format nil " -d ~A" target-distro)
				 "")
			       (if (and wsl-dir (plusp (length wsl-dir)))
				   (format nil " --cd ~A" wsl-dir)
				 ""))))
	  (goto-char (point-max))
	  (wsl-mode)
	  (make-process cmdline :output (selected-buffer) :terminal t)
	  (let ((new-proc (buffer-process (selected-buffer))))
	    (when (and new-proc (si:process-terminal-p new-proc))
	      (set-minor-mode-map *terminal-map*)))
	  (switch-to-buffer buf))))
    buf))

(defun wsl-shell (&optional distro dir)
  "wsl と同等のコマンド。"
  (interactive "P")
  (wsl distro dir))


;;; ------------------------------------------------------------------
;;; WSL プロジェクト判定・管理 (Issue #343)

(defvar-local *wsl-project-distro* nil
  "カレントバッファまたはプロジェクトの WSL ディストリビューション名")

(defvar *wsl-compile-buffer-name* "*WSL-Compilation*"
  "WSL コンパイルバッファの既定名")

(defun wsl-path-p (path)
  "PATH が WSL UNC パス (\\\\wsl.localhost\\... や \\\\wsl$\\... など) であれば t を返す。"
  (unless (stringp path)
    (setq path (namestring path)))
  (and (stringp path)
       (let ((norm (map-backslash-to-slash path)))
	 (and (string-matchp "^//\\(wsl\\.localhost\\|wsl\\$\\)/" norm) t))))

(defun wsl-extract-distro (path)
  "WSL UNC パスからディストリビューション名を抽出する。WSL パスでなければ nil を返す。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (and (stringp path) (plusp (length path)))
    (let ((norm (map-backslash-to-slash path)))
      (when (string-match "^//\\(wsl\\.localhost\\|wsl\\$\\)/\\([^/]+\\)" norm)
	(match-string 2)))))

(defun wsl-current-distro (&optional dir)
  "現在のコンテキスト（バッファ、ディレクトリ、または既定値）における WSL ディストリビューション名を返す。"
  (or *wsl-project-distro*
      (when dir (wsl-extract-distro dir))
      (wsl-extract-distro (default-directory))
      *wsl-distribution*
      "Ubuntu"))

(defun wsl-project-p (&optional dir)
  "DIR (省略時は default-directory) が WSL プロジェクト内であれば t を返す。"
  (let ((target (or dir (default-directory))))
    (or (and *wsl-project-distro* t)
	(wsl-path-p target))))

(defun wsl-open-directory (distro wsl-path)
  "ディストリビューション DISTRO の WSL パス WSL-PATH を Windows UNC パスとして開き、プロジェクトルートに設定する。"
  (interactive
   (let* ((d (wsl-read-distribution))
	  (p (read-string "WSL directory: " :default "~")))
     (list d p)))
  (let* ((resolved-wsl-path (cond ((or (string= wsl-path "~") (string= wsl-path "~/"))
				   "/home")
				  ((string-match "^~/" wsl-path)
				   (concat "/home" (subseq wsl-path 1)))
				  (t wsl-path)))
	 (win-path (wsl-path-to-windows resolved-wsl-path distro))
	 (win-dir (if (string-match "[/\\]$" win-path)
		      win-path
		    (concat win-path "/"))))
    (when (file-directory-p win-dir)
      (set-default-directory win-dir))
    (setq *wsl-project-distro* distro)
    (when (fboundp 'project-remember-project)
      (project-remember-project win-dir))
    (message "Opened WSL directory: ~A (~A)" win-dir distro)
    win-dir))


;;; ------------------------------------------------------------------
;;; 外部ツールディスパッチ (compile / git) (Issue #343)

(defun wsl-build-command-line (command &optional distro wsl-dir)
  "WSL 上で COMMAND を実行するための wsl.exe コマンドライン文字列を構築する。"
  (let ((d (or distro *wsl-project-distro* *wsl-distribution*))
	(dir (or wsl-dir
		 (let ((dd (default-directory)))
		   (if (wsl-path-p dd)
		       (windows-path-to-wsl dd)
		     nil)))))
    (format nil "~A~A~A -- sh -c ~S"
	    *wsl-command*
	    (if (and d (plusp (length d)))
		(format nil " -d ~A" d)
	      "")
	    (if (and dir (plusp (length dir)))
		(format nil " --cd ~A" dir)
	      "")
	    command)))

(defun wsl-git-command-line (git-args &optional distro wsl-dir)
  "WSL 上で git を実行するためのコマンドライン文字列を構築する。"
  (wsl-build-command-line (format nil "git ~A" git-args) distro wsl-dir))

(defun wsl-translate-log-paths (log-string &optional distro)
  "コンパイルログ内の Linux パス (/home/... や /mnt/c/... など) を Windows パスに変換する。"
  (unless (stringp log-string)
    (return-from wsl-translate-log-paths log-string))
  (let ((target-distro (or distro *wsl-project-distro* *wsl-distribution* "Ubuntu"))
	(result "")
	(start 0))
    ;; Linux の絶対パスパターン: /mnt/<drive>/... または /<dir>/...
    (while (string-match "\\(/mnt/[a-zA-Z]/[^:() \t'\"<>]+\\|/[^:() \t'\"<>]+\\)" log-string start)
      (let* ((m-start (match-beginning 1))
	     (m-end (match-end 1))
	     (linux-path (subseq log-string m-start m-end))
	     (win-path (wsl-path-to-windows linux-path target-distro)))
	(setq result (concat result
			     (subseq log-string start m-start)
			     win-path))
	(setq start m-end)))
    (concat result (subseq log-string start))))

(defun wsl-compile (command &optional distro dir)
  "WSL 上で COMMAND を実行し、結果を compilation バッファに出力してエラー解析を行う。"
  (interactive
   (list (read-string "WSL compile command: "
		      :default (or (and (boundp '*compile-command*) *compile-command*) "make"))))
  (let* ((target-distro (or distro (wsl-current-distro dir)))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (cmdline (wsl-build-command-line command target-distro wsl-dir))
	 (buf (get-buffer-create *wsl-compile-buffer-name*)))
    (save-excursion
      (set-buffer buf)
      (setq buffer-read-only nil)
      (erase-buffer buf)
      (insert (format nil "-*- mode: compilation; default-directory: ~S -*-\n" target-dir))
      (insert (format nil "WSL: ~A (~A)\nCommand: ~A\n\n" wsl-dir target-distro cmdline))
      (call-process cmdline :output buf :show :hide :wait t)
      ;; ログ内の Linux パスを Windows パスに置換して next-error でジャンプ可能にする
      (let ((translated (wsl-translate-log-paths (buffer-substring (point-min) (point-max)) target-distro)))
	(erase-buffer buf)
	(insert translated))
      (goto-char (point-min)))
    (pop-to-buffer buf)
    (when (fboundp 'set-error-buffer)
      (set-error-buffer buf))
    (when (fboundp 'build-error-list)
      (build-error-list))
    buf))

(defun wsl-git (&optional (git-args "status") dir)
  "WSL 上で Git コマンドを実行し、出力をバッファに表示する。"
  (interactive "sWSL git args: ")
  (let* ((target-distro (wsl-current-distro dir))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (cmdline (wsl-git-command-line git-args target-distro wsl-dir))
	 (buf (get-buffer-create "*WSL Git*")))
    (save-excursion
      (set-buffer buf)
      (setq buffer-read-only nil)
      (erase-buffer buf)
      (call-process cmdline :output buf :show :hide :wait t)
      (let ((translated (wsl-translate-log-paths (buffer-substring (point-min) (point-max)) target-distro)))
	(erase-buffer buf)
	(insert translated))
      (goto-char (point-min)))
    (pop-to-buffer buf)
    buf))

