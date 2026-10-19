;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for CLI agent integration (lisp/agent.l, issue #408)
;;;

(require "agent")

(use-package "editor")

;;; ------------------------------------------------------------------
;;; コマンドライン構築 (agent-command-line)

(deftest agent-command-line-wsl ()
  "WSL ディストロ指定時は wsl.exe 経由で login shell から起動する"
  (list (agent-command-line "claude" :distro "Ubuntu"
			    :dir "/home/user/xyzzy")
	(agent-command-line "ax claude" :distro "Debian" :dir "/home/u/p"))
  => ("wsl.exe -d Ubuntu --cd /home/user/xyzzy -- bash -lc \"claude\""
      "wsl.exe -d Debian --cd /home/u/p -- bash -lc \"ax claude\""))

(deftest agent-command-line-wsl-no-dir ()
  "ディレクトリが無い WSL 起動は --cd を付けない"
  (agent-command-line "claude" :distro "Ubuntu" :dir nil)
  => "wsl.exe -d Ubuntu -- bash -lc \"claude\"")

(deftest agent-command-line-windows ()
  "Windows ネイティブ側は cmd.exe /c 経由"
  (agent-command-line "claude" :windows-p t)
  => "cmd.exe /c claude")

(deftest agent-command-line-posix ()
  "POSIX 側は sh -lc 経由"
  (agent-command-line "claude")
  => "sh -lc \"claude\"")

;;; ------------------------------------------------------------------
;;; バッファ名 (agent-buffer-name)

(deftest agent-buffer-name-project ()
  "プロジェクトルートの末尾要素をバッファ名に使う"
  (list (agent-buffer-name "C:/ghq/xyzzy/")
	(agent-buffer-name "C:/ghq/xyzzy")
	(agent-buffer-name "\\\\wsl.localhost\\Ubuntu\\home\\u\\repo\\"))
  => ("*Agent:xyzzy*" "*Agent:xyzzy*" "*Agent:repo*"))

(deftest agent-buffer-name-root ()
  "ルート直下や空なら汎用名にする"
  (list (agent-buffer-name "/")
	(agent-buffer-name ""))
  => ("*Agent*" "*Agent*"))

;;; ------------------------------------------------------------------
;;; ファイル参照 (agent-file-reference)

(deftest agent-file-reference-relative ()
  "プロジェクト内のファイルはルートからの相対パスに @ を付ける"
  (list (agent-file-reference "C:/ghq/xyzzy/lisp/agent.l" "C:/ghq/xyzzy/")
	(agent-file-reference "C:/ghq/xyzzy/lisp/agent.l" "C:/ghq/xyzzy"))
  => ("@lisp/agent.l" "@lisp/agent.l"))

(deftest agent-file-reference-boundary ()
  "ルート名が前方一致するだけの別プロジェクトは相対化しない"
  (agent-file-reference "C:/ghq/xyzzy2/foo.c" "C:/ghq/xyzzy/")
  => "@C:/ghq/xyzzy2/foo.c")

(deftest agent-file-reference-wsl ()
  "WSL 側のエージェントには UNC パスを WSL パスへ変換して渡す"
  (list (agent-file-reference "//wsl.localhost/Ubuntu/home/u/repo/src/a.c"
			      "//wsl.localhost/Ubuntu/home/u/repo/"
			      :distro "Ubuntu")
	(agent-file-reference "//wsl.localhost/Ubuntu/home/u/other/b.c"
			      "//wsl.localhost/Ubuntu/home/u/repo/"
			      :distro "Ubuntu"))
  => ("@src/a.c" "@/home/u/other/b.c"))

(deftest agent-file-reference-prefix ()
  "参照プレフィックスは *agent-file-reference-prefix* で変えられる"
  (let ((*agent-file-reference-prefix* "file:"))
    (agent-file-reference "C:/p/a.c" "C:/p/"))
  => "file:a.c")

;;; ------------------------------------------------------------------
;;; コマンド既定値

(deftest agent-default-command ()
  "既定は *agent-command*、未設定なら *agent-command-list* の先頭"
  (let ((*agent-command* nil)
	(*agent-command-list* '("claude" "devin")))
    (list (agent-default-command)
	  (let ((*agent-command* "ax codex"))
	    (agent-default-command))))
  => ("claude" "ax codex"))

;;; ------------------------------------------------------------------
;;; 定義の存在確認

(deftest agent-definitions-exist ()
  "agent 関連コマンドが定義されている"
  (list (fboundp 'agent)
	(fboundp 'agent-mode)
	(fboundp 'agent-send-file)
	(fboundp 'agent-send-region)
	(fboundp 'agent-send-error)
	(fboundp 'agent-diff)
	(fboundp 'agent-revert-changed)
	(fboundp 'toggle-agent-drawer)
	(fboundp 'agent-find-buffer)
	;; xyzzy の keymapp は keymap そのものを返す (t ではない)
	(and (keymapp *agent-mode-map*) t)
	(boundp '*agent-command*)
	(boundp '*agent-command-list*))
  => (t t t t t t t t t t t t))

;;; ------------------------------------------------------------------
;;; 起動コマンドとの不一致判定 (agent-restart-needed-p, issue #412)

(deftest agent-restart-needed-p-test ()
  "起動中コマンドと要求コマンドが違うときだけ再起動が要る"
  (list (agent-restart-needed-p "claude" "claude")
	(agent-restart-needed-p "claude" "agy")
	(agent-restart-needed-p nil "agy")
	(agent-restart-needed-p "claude" nil)
	(agent-restart-needed-p nil nil))
  => (nil t nil nil nil))

(deftest agent-launched-command-var ()
  "起動コマンド記録用のバッファローカル変数が定義されている。
バッファごとに別の値を持ち、他バッファに漏れないことを確認する。"
  (let ((b1 (create-new-buffer " *agent-lc-1*"))
	(b2 (create-new-buffer " *agent-lc-2*")))
    (unwind-protect
	(progn
	  (save-excursion
	    (set-buffer b1)
	    (setq *agent-launched-command* "claude"))
	  (list (save-excursion (set-buffer b1) *agent-launched-command*)
		(save-excursion (set-buffer b2) *agent-launched-command*)
		(fboundp 'agent-restart)))
      (delete-buffer b1)
      (delete-buffer b2)))
  => ("claude" nil t))

;;; ------------------------------------------------------------------
;;; 変更済みバッファの revert (agent-revert-changed)

(deftest agent-revert-changed ()
  "ディスク上で変更された未編集バッファが再読み込みされる"
  ;; make-temp-file-name はファイル自体を作成するのでそのまま使う
  (let* ((file (make-temp-file-name))
	 (buf nil)
	 (result nil))
    (unwind-protect
	(progn
	  (with-open-file (s file :direction :output :if-exists :supersede)
	    (princ "version-1\n" s))
	  (find-file file)
	  (setq buf (get-file-buffer file))
	  ;; エージェントが外部で書き換えた状況を再現する。
	  ;; modtime 比較なので確実に未来の時刻を置く。
	  (with-open-file (s file :direction :output :if-exists :supersede)
	    (princ "version-2\n" s))
	  (set-file-write-time file (+ (get-universal-time) 60))
	  (agent-revert-changed)
	  (save-excursion
	    (set-buffer buf)
	    (setq result (buffer-substring (point-min) (point-max)))))
      (when buf (delete-buffer buf))
      (ignore-errors (delete-file file)))
    result)
  => "version-2\n")
