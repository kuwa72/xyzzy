;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; WSL (Windows Subsystem for Linux) integration for xyzzy
;;;

(provide "wsl")

(in-package "editor")

(require "terminal")

(export '(*wsl-distribution* *wsl-unc-prefix* *wsl-path-prefix* *wsl-command*
	  *wsl-mode-map* *wsl-mode-hook*
	  wsl-mode wsl wsl-shell
	  wsl-path-to-windows windows-path-to-wsl
	  wsl-parse-distributions wsl-list-distributions wsl-read-distribution
	  wsl-osc-52-sequence wsl-copy-string wsl-paste-string
	  wsl-copy-region wsl-paste))

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
  (let ((buf (generate-new-buffer " *wsl-list*")))
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
