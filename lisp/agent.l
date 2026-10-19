;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; CLI agent integration for xyzzy (issue #408)
;;;
;;; xyzzy の中で CLI エージェント (claude code など) を pty 端末として
;;; 起動し、編集中のコードからコンテキストを送り、変更差分の確認と
;;; ビルドまでを一連の流れで行うための層。
;;;
;;; 起動側の部品は既存のものを組み合わせる:
;;;   - pty 端末        make-process :terminal t + terminal.l のキーマップ
;;;   - WSL 起動        wsl-project-p / wsl-current-distro / windows-path-to-wsl
;;;   - 差分表示        git-run-command-to-buffer + git-diff-mode
;;;   - プロジェクト    project-current-root
;;;

(provide "agent")

(in-package "editor")

(require "terminal")
(require "project")
(require "git")
(require "wsl")

(export '(*agent-command* *agent-command-list* *agent-file-reference-prefix*
	  *agent-mode-map* *agent-mode-hook*
	  *agent-project-root* *agent-distro* *agent-launched-command*
	  agent agent-mode agent-command-line agent-buffer-name
	  agent-file-reference agent-default-command
	  agent-restart-needed-p agent-restart
	  agent-find-buffer agent-send-text agent-send-file
	  agent-send-region agent-send-error agent-diff
	  agent-revert-changed toggle-agent-drawer))

;;; ------------------------------------------------------------------
;;; 設定変数

(defvar *agent-command* nil
  "起動する CLI エージェントのコマンドライン文字列。
nil の場合は *agent-command-list* の先頭を使う。
\"claude\" のような単独コマンドのほか、ラッパ経由 (例: \"ax claude\")
もそのまま書ける。")

(defvar *agent-command-list* '("claude")
  "C-u M-x agent で選択できるエージェントコマンドの一覧。")

(defvar *agent-file-reference-prefix* "@"
  "agent-send-file がプロンプトに挿入するときのプレフィックス。
claude code 系の @path 参照に合わせた既定値。")

(defvar *agent-mode-hook* nil
  "agent-mode 起動時のフック")

(defvar *agent-mode-map* nil
  "agent-mode のキーマップ")

(defvar-local *agent-project-root* nil
  "この agent バッファが紐づくプロジェクトルート")

(defvar-local *agent-distro* nil
  "この agent バッファが動いている WSL ディストロ (ネイティブなら nil)")

(defvar-local *agent-launched-command* nil
  "この agent バッファを起動したコマンド文字列。
`agent' が再起動が要るか判断するのに使う (issue #412)")

(unless *agent-mode-map*
  (setq *agent-mode-map* (make-sparse-keymap))
  (define-key *agent-mode-map* '(#\C-c #\C-c) 'terminal-send-ctrl-c)
  (define-key *agent-mode-map* #\C-v 'terminal-paste)
  (define-key *agent-mode-map* #\S-Insert 'terminal-paste)
  (define-key *agent-mode-map* '(#\C-c #\d) 'agent-diff)
  (define-key *agent-mode-map* '(#\C-c #\r) 'agent-revert-changed))

;;; ------------------------------------------------------------------
;;; コマンドライン構築

(defun agent-default-command ()
  "既定のエージェントコマンドを返す。
*agent-command* が設定されていればそれ、なければ
*agent-command-list* の先頭。"
  (or *agent-command* (car *agent-command-list*)))

(defun agent-command-line (command &key distro dir windows-p)
  "COMMAND を起動するためのコマンドライン文字列を返す。
DISTRO が指定されていれば wsl.exe 経由で WSL 内の login shell
(nvm/fnm 系で ~/.profile 以降に PATH が入る CLI を拾うため) から
起動し、DIR をそのカレントディレクトリにする。
WINDOWS-P は Windows ネイティブ側で実行する場合に non-nil。
どちらでもなければ POSIX の sh から起動する。"
  (cond (distro
	 (format nil "~A -d ~A~A -- bash -lc ~S"
		 (if (boundp '*wsl-command*) *wsl-command* "wsl.exe")
		 distro
		 (if (and dir (plusp (length dir)))
		     (format nil " --cd ~A" dir) "")
		 command))
	(windows-p
	 (format nil "cmd.exe /c ~A" command))
	(t
	 (format nil "sh -lc ~S" command))))

;;; ------------------------------------------------------------------
;;; バッファ名 / プロジェクトとの対応付け

(defun agent-buffer-name (root)
  "プロジェクトルート ROOT に対応する agent バッファ名を返す。
ルートの末尾要素を使い、取れなければ汎用名 *Agent* にする。"
  (let* ((s (map-backslash-to-slash (or root "")))
	 (trimmed (if (and (> (length s) 1) (string-match "/$" s))
		      (subseq s 0 (1- (length s)))
		    s))
	 ;; file-namestring は空文字列にカレントディレクトリの
	 ;; 末尾要素を返すので、空のときは呼ばない。
	 (base (and (plusp (length trimmed))
		    (file-namestring trimmed))))
    (if (and (stringp base) (plusp (length base))
	     (not (string-match "/" base)))
	(format nil "*Agent:~A*" base)
      "*Agent*")))

;;; ------------------------------------------------------------------
;;; ファイル参照

(defun agent--slash-dir (dir)
  "DIR をスラッシュ区切り・末尾 / 付きのディレクトリパスに正規化する。"
  (let ((s (map-backslash-to-slash (or dir ""))))
    (if (or (zerop (length s)) (string-match "/$" s))
	s
      (concat s "/"))))

(defun agent-file-reference (filename root &key distro)
  "FILENAME をエージェントへ渡す参照文字列にする。
ROOT 配下ならルートからの相対パス、外なら絶対パスに
*agent-file-reference-prefix* を付ける。DISTRO が指定されていれば
エージェントは WSL 内にいるので、UNC パスを WSL 側パスへ変換する
(エージェントの cwd は ROOT に対応する WSL 側ディレクトリ)。"
  (let* ((convert (if (and distro (fboundp 'windows-path-to-wsl))
		      #'windows-path-to-wsl
		    #'identity))
	 (path (map-backslash-to-slash (funcall convert filename)))
	 (prefix (agent--slash-dir (funcall convert root)))
	 (ref (if (and (plusp (length prefix))
		       (<= (length prefix) (length path))
		       (string-equal (subseq path 0 (length prefix)) prefix))
		  (subseq path (length prefix))
		path)))
    (concat *agent-file-reference-prefix* ref)))

;;; ------------------------------------------------------------------
;;; agent-mode / 起動

(defun agent-mode ()
  "CLI エージェント用のメジャーモード。
端末としてのキー操作は *terminal-map* (マイナーモード) に任せ、
ここには差分確認やバッファ反映への入口だけを置く。"
  (setq mode-name "Agent")
  (setq buffer-mode 'agent-mode)
  (use-keymap *agent-mode-map*)
  (setq need-not-save t)
  (setq auto-save nil)
  (setq kept-undo-information nil)
  (set-buffer-fold-width 80)
  (run-hooks '*agent-mode-hook*))

(defun agent-restart-needed-p (launched requested)
  "LAUNCHED (起動中のコマンド) と REQUESTED (要求されたコマンド) が
異なるときだけ t を返す。どちらかが nil (未起動・コマンド未指定)
なら nil。"
  (and launched requested (not (string-equal launched requested))))

(defun agent (&optional command restart)
  "プロジェクトルートで CLI エージェントを pty 端末として起動する。
WSL プロジェクトでは wsl.exe 経由で WSL 内に、そうでなければ
カレント側で起動する。プレフィックス引数を与えると
*agent-command-list* から起動コマンドを選択できる。
既に agent が動いている場合は、要求コマンドが起動時と同じなら
そのバッファへ接続し、違うなら再起動するか確認する
\(issue #412 -- 以前は要求を見ずに再接続するだけで、
*agent-command* を変えても反映されなかった)。
RESTART が non-nil なら確認せず再起動する。"
  (interactive "P")
  (when (and (interactive-p) command)
    (setq command (completing-read "Agent command: " *agent-command-list*
				   :default (agent-default-command))))
  (let* ((cmd (or command (agent-default-command)))
	 (root (project-current-root))
	 (distro (and (fboundp 'wsl-project-p) (wsl-project-p root)
		      (fboundp 'wsl-current-distro) (wsl-current-distro root)))
	 (buf (get-buffer-create (agent-buffer-name root))))
    (set-buffer buf)
    (let ((proc (buffer-process buf)))
      (when (and proc (eq (process-status proc) :run))
	(let ((needed (agent-restart-needed-p *agent-launched-command* cmd)))
	  (cond
	   ;; 同じコマンド: 明示 restart でなければ接続するだけ
	   ((and (not needed) (not restart))
	    (switch-to-buffer buf)
	    (return-from agent buf))
	   ;; 別コマンド: restart 指定か対話確認が無ければ接続に留める
	   ((and needed (not restart)
		 (or (not (interactive-p))
		     (not (yes-or-no-p
			   (format nil "~A を実行中です。~A で起動しなおしますか? "
				   *agent-launched-command* cmd)))))
	    (switch-to-buffer buf)
	    (return-from agent buf))
	   ;; ここに来たら再起動が確定なので古いプロセスを止める
	   (t
	    (kill-process proc)
	    (sit-for 0)))))
      (let ((cmdline (agent-command-line
		      cmd :distro distro
		      :dir (and distro (fboundp 'windows-path-to-wsl)
				(windows-path-to-wsl root))
		      :windows-p (featurep :windows-nt))))
	(goto-char (point-max))
	(agent-mode)
	(setq *agent-project-root* root
	      *agent-distro* distro
	      *agent-launched-command* cmd)
	;; wsl() と同じく :terminal t が要る (issue #250)。
	;; TUI のエージェントは画面を持つ子なので、渡さないと出力が
	;; 素のテキストとしてバッファに入ってしまう。
	(make-process cmdline :output (selected-buffer) :terminal t)
	(let ((new-proc (buffer-process (selected-buffer))))
	  (when (and new-proc (si:process-terminal-p new-proc))
	    (set-minor-mode-map *terminal-map*)))
	(switch-to-buffer buf)))
    buf))

(defun agent-restart ()
  "agent バッファのプロセスを止めて、現在の *agent-command* で
起動しなおす。起動中のバッファまたはプロジェクトの agent
バッファに対して行う。"
  (interactive)
  (let ((buf (agent-find-buffer)))
    (if buf
	(save-excursion
	  (set-buffer buf)
	  (agent nil t))
      (agent))))

;;; ------------------------------------------------------------------
;;; コンテキスト送信 (コードバッファ側から呼ぶ)

(defun agent-find-buffer (&optional root)
  "現在のプロジェクトに対応する agent-mode のバッファを返す。
ルートが一致するものを優先し、なければ agent-mode のバッファの
うち最初に見つかったものを返す。ひとつも無ければ nil。"
  (let ((target (or root (ignore-errors (project-current-root))))
	(fallback nil))
    (dolist (buf (buffer-list))
      (save-excursion
	(set-buffer buf)
	(when (eq buffer-mode 'agent-mode)
	  (if (and *agent-project-root*
		   (string-equal *agent-project-root* target))
	      (return-from agent-find-buffer buf)
	    (unless fallback
	      (setq fallback buf))))))
    fallback))

(defun agent-send-text (text &optional paste)
  "agent バッファのプロセスへ TEXT を送る。
改行を含むか PASTE が non-nil のときは bracketed-paste で送る
(対応している TUI では一塊の入力として扱われる)。それ以外は
プロンプトへのタイプ入力として送るだけで、実行まではしない。"
  (let ((buf (agent-find-buffer)))
    (unless buf
      (error "agent バッファがありません (M-x agent で起動してください)"))
    (let ((proc (buffer-process buf)))
      (unless (and proc (eq (process-status proc) :run))
	(error "agent プロセスが動作していません"))
      (if (and (si:process-terminal-p proc)
	       (or paste (string-match "\n" text)))
	  (si:terminal-paste-string proc text)
	(process-send-string proc text))
      buf)))

(defun agent-send-file (&optional filename)
  "現在のファイルを @path 参照として agent のプロンプトへ挿入する。
プロジェクト内なら相対パス、WSL 上のエージェントには WSL 側パスを送る。"
  (interactive)
  (let* ((file (or filename (get-buffer-file-name)
		   (error "ファイルに関連づいたバッファではありません")))
	 (buf (agent-find-buffer))
	 (distro (and buf (save-excursion
			    (set-buffer buf) *agent-distro*)))
	 (ref (agent-file-reference file
				    (or (and buf (save-excursion
						   (set-buffer buf)
						   *agent-project-root*))
					(project-current-root))
				    :distro distro)))
    (agent-send-text (concat ref " "))
    (message "Sent: ~A" ref)))

(defun agent-send-region (start end)
  "リージョンの内容を agent のプロンプトへ貼り付ける。
複数行でも一塊として扱われるよう bracketed-paste で送る。"
  (interactive "r")
  (agent-send-text (buffer-substring start end) t))

(defun agent-send-error ()
  "カーソルのある行 (compilation や grep のエラー行など) を
agent のプロンプトへ貼り付ける。"
  (interactive)
  (let ((line (save-excursion
		(goto-bol)
		(skip-chars-forward " \t")
		(buffer-substring (point) (progn (goto-eol) (point))))))
    (unless (plusp (length line))
      (error "送信できる行がありません"))
    (agent-send-text line t)
    (message "Sent: ~A" line)))

;;; ------------------------------------------------------------------
;;; 変更のレビュー

(defun agent-diff (&optional arg)
  "agent が加えた変更を git diff で確認する。
既定は作業ツリーの diff、C-u で HEAD との差分 (staged 込み)。"
  (interactive "P")
  (let* ((root (project-current-root))
	 (buf (git-run-command-to-buffer "*Agent-Diff*"
					 (if arg "diff HEAD" "diff")
					 root)))
    (pop-to-buffer buf)
    (git-diff-mode)
    (goto-char (point-min))
    buf))

(defun agent-revert-changed ()
  "ディスク上で変更された未編集バッファをまとめて再読み込みする。
エージェントはエディタの外でファイルを書き換えるので、開いて
いるバッファは古いまま残る。編集中 (buffer-modified-p) のものは
コンフリクトを避けて触らない。"
  (interactive)
  (let ((reverted nil))
    (dolist (buf (buffer-list))
      (save-excursion
	(set-buffer buf)
	(when (and (get-buffer-file-name)
		   (not (buffer-modified-p))
		   (not (verify-visited-file-modtime buf))
		   (ignore-errors (revert-buffer) t))
	  (push (buffer-name buf) reverted))))
    (when (interactive-p)
      (if reverted
	  (message "reverted: ~{~A~^, ~}" (nreverse reverted))
	(message "変更されたバッファはありません")))
    (nreverse reverted)))

;;; ------------------------------------------------------------------
;;; ドロワー

(defun toggle-agent-drawer ()
  "画面下部のドロワーに agent バッファをトグル表示する。
まだ起動していなければ M-x agent と同じく起動する。"
  (interactive)
  (let* ((existing (agent-find-buffer))
	 (name (or (and existing (buffer-name existing))
		   (agent-buffer-name
		    (ignore-errors (project-current-root))))))
    (toggle-buffer-drawer
     name
     #'(lambda ()
	 (if existing
	     (switch-to-buffer existing)
	   (agent))))))

;;; ------------------------------------------------------------------
;;; Leader キーへの登録 (leader.l が読み込まれているとき)

(when (boundp '*leader-map*)
  (defvar *leader-agent-map* (make-sparse-keymap))
  (define-key *leader-agent-map* #\a 'agent)
  (define-key *leader-agent-map* #\A 'agent-restart)
  (define-key *leader-agent-map* #\t 'toggle-agent-drawer)
  (define-key *leader-agent-map* #\f 'agent-send-file)
  (define-key *leader-agent-map* #\r 'agent-send-region)
  (define-key *leader-agent-map* #\e 'agent-send-error)
  (define-key *leader-agent-map* #\d 'agent-diff)
  (define-key *leader-agent-map* #\v 'agent-revert-changed)
  (define-key *leader-agent-map* #\b 'build)
  (define-key *leader-map* #\a *leader-agent-map*)
  (when (fboundp 'which-key-add-description)
    (which-key-add-description *leader-agent-map* "Agent")
    (which-key-add-description 'agent "Start")
    (which-key-add-description 'agent-restart "Restart")
    (which-key-add-description 'toggle-agent-drawer "Drawer")
    (which-key-add-description 'agent-send-file "SendFile")
    (which-key-add-description 'agent-send-region "SendRegion")
    (which-key-add-description 'agent-send-error "SendError")
    (which-key-add-description 'agent-diff "Diff")
    (which-key-add-description 'agent-revert-changed "Revert")
    (which-key-add-description 'build "Build")))
