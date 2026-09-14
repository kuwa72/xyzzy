; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; lisp/lsp.l の端から端までのテスト。
;;;
;;; **本物の言語サーバーは使わない。** clangd も rust-analyzer も CI の
;;; Windows ランナーには無いので、あるものに頼ると「環境に無いから落ちた」が
;;; 既知失敗に積まれる。相手は tools/fake-lsp-server.py (python だけで動く
;;; 最小の LSP サーバー) で、起動・initialize・通知・応答の経路だけを見る。
;;;
;;; **プロセスを相手にするので、待ちは実時間で書く。** 固定の `sleep-for' で
;;; 済ませると、機械が混んでいるときに落ちる (`unittest/flymake-tests.l' の
;;; `flymake-test-wait' と同じ形)。

(require "lsp")

(use-package "editor")

;;;
;;; 下ごしらえ
;;;

(defvar *lsp-test-python* nil
  "fake サーバーを動かす python。調べた結果を覚えておく (:none は無し)。")

(defun lsp-test-python-runs-p (cmd)
  "CMD がこの環境で本当に走るかどうか。

**`where' の戻り値だけでは足りない。** Wine は `where python3' に 0 を
返し、出力は空だ。つまり「見つかった」と「走らない」を区別できない。
Wine が見せる PATH には Linux の PATH が混ざっているので名前だけは
引っかかるが、Windows のプロセスとして起動できるのは PE だけなので、
fake サーバーは 1 つも起動しない (CI で 5 テストが 30 秒ずつ待って落ちた)。
**実際に走らせて版を言わせる。**"
  (let ((buf (create-new-buffer " *lsp-python-probe*")))
    (unwind-protect
	(progn
	  (ignore-errors
	    (call-process (format nil "~A --version" cmd)
			  :output buf :show :hide :wait t))
	  (save-excursion
	    (set-buffer buf)
	    (not (null (string-match "ython"
				     (buffer-substring (point-min) (point-max)))))))
      (delete-buffer buf))))

(defun lsp-test-python ()
  "fake サーバーを起動できる python のコマンド名。無ければ nil。

**`python3' を先に見る。** Linux の CI には `python3' だけがあり、Windows に
`python3' は無い (あるのは `python')。"
  (unless *lsp-test-python*
    (setq *lsp-test-python*
	  (cond ((lsp-test-python-runs-p "python3") "python3")
		((lsp-test-python-runs-p "python") "python")
		(t :none))))
  (and (stringp *lsp-test-python*) *lsp-test-python*))

(defun lsp-test-script ()
  "fake サーバーのパス。"
  (namestring (merge-pathnames "tools/fake-lsp-server.py" (si:system-root))))

(defun lsp-test-log-path (name)
  "テストごとのログファイル。"
  (merge-pathnames (format nil "xyzzy-lsp-e2e-~A.log" name) (si:system-root)))

(defun lsp-test-server-command (log &optional content-type)
  "fake サーバーを起動するコマンド行。"
  (format nil "~A ~A --log ~A~A"
	  (lsp-test-python) (lsp-test-script) (namestring log)
	  (if content-type " --content-type" "")))

(defun lsp-test-log-text (path)
  "ログファイルの中身。まだ無ければ空文字列。"
  (if (not (file-exist-p path))
      ""
    ;; **`:share :read-write' が要る。** Windows の `open' は既定が共有なし
    ;; なので、こちらが読んでいる間は書き手 (fake サーバー) の append が
    ;; `PermissionError' で落ち、**サーバーごと死ぬ。** ポーリングは
    ;; 1 行目 (ファイルがまだ無いので開かない) は無事で、2 行目から
    ;; 当たる — つまり「didOpen だけ届かない」に見える。POSIX には
    ;; この差が無いので、Linux では最後まで気付けない。
    (let ((in (open path :direction :input :if-does-not-exist nil
                    :share :read-write)))
      (if (null in)
	  ""
	(unwind-protect
	    (let ((out (make-string-output-stream))
		  (c nil))
	      (while (setq c (read-char in nil nil))
		(write-char c out))
	      (get-output-stream-string out))
	  (close in))))))

(defun lsp-test-log-has (path line)
  "ログに LINE が現れていれば t。"
  (not (null (string-match (format nil "~A" line) (lsp-test-log-text path)))))

(defun lsp-test-wait (predicate limit)
  "PREDICATE が真になるまで待つ。LIMIT 秒で諦める。"
  (let ((start (get-internal-real-time)))
    (loop
      (when (funcall predicate)
	(return t))
      (when (> (- (get-internal-real-time) start) (* limit 1000))
	(return nil))
      (sleep-for 0.02))))

(defun lsp-test-clean-log (path)
  (ignore-errors (delete-file path :if-does-not-exist :skip)))

(defun lsp-test-uri (name)
  "テスト用の URI。"
  (format nil "file:///~A" name))

;;;
;;; 起動と initialize
;;;

(deftest lsp-e2e-initialize-completes ()
  "サーバーが起動し、initialize の応答を受けて initialized を送ること。"
  (if (null (lsp-test-python))
      '(t t)
    (let ((log (lsp-test-log-path "init"))
	  (client nil))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log)
					   (si:system-root)))
	    (list (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
		  (and client t)))
	(when client (lsp-stop-server client))
	(lsp-test-clean-log log))))
  => (t t))

(deftest lsp-e2e-content-type-header-is-skipped ()
  "Content-Length 以外のヘッダがあってもメッセージを読めること。

clangd は Content-Type を送る。ヘッダを 1 行決め打ちで照合していると、
そこで止まったまま**何も届かなくなる**。"
  (if (null (lsp-test-python))
      '(t t)
    (let ((log (lsp-test-log-path "ctype"))
	  (client nil))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log t)
					   (si:system-root)))
	    (list (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
		  (and client t)))
	(when client (lsp-stop-server client))
	(lsp-test-clean-log log))))
  => (t t))

;;;
;;; ドキュメント同期と診断
;;;

(deftest lsp-e2e-did-open-and-diagnostics ()
  "didOpen がサーバーへ届き、返ってきた診断を溜めること。"
  (if (null (lsp-test-python))
      '(t t 1 "fake-diagnostic")
    (let ((log (lsp-test-log-path "open"))
	  (client nil)
	  (uri (lsp-test-uri "lsp-e2e-open.c")))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log)
					   (si:system-root)))
	    (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
	    (lsp-notify-open client uri "c" "int main() { return 0; }")
	    (lsp-test-wait #'(lambda () (gethash uri (ed::lsp-client-diagnostics client))) 30)
	    (let ((diags (gethash uri (ed::lsp-client-diagnostics client))))
	      (list (lsp-test-log-has log (format nil "didOpen ~A" uri))
		    (and diags t)
		    (length diags)
		    (getf (car diags) :message))))
	(when client (lsp-stop-server client))
	(lsp-test-clean-log log))))
  => (t t 1 "fake-diagnostic"))

(deftest lsp-e2e-did-change-and-close ()
  "didChange と didClose がサーバーへ届くこと。"
  (if (null (lsp-test-python))
      '(t t)
    (let ((log (lsp-test-log-path "change"))
	  (client nil)
	  (uri (lsp-test-uri "lsp-e2e-change.c")))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log)
					   (si:system-root)))
	    (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
	    (lsp-notify-open client uri "c" "int main() {}")
	    (lsp-test-wait #'(lambda () (lsp-test-log-has log "didOpen")) 30)
	    (lsp-notify-change client uri "int main() { return 1; }")
	    (lsp-notify-close client uri)
	    (list (lsp-test-wait #'(lambda () (lsp-test-log-has log "didChange")) 30)
		  (lsp-test-wait #'(lambda () (lsp-test-log-has log "didClose")) 30)))
	(when client (lsp-stop-server client))
	(lsp-test-clean-log log))))
  => (t t))

;;;
;;; 定義ジャンプ
;;;

(deftest lsp-e2e-definition-request ()
  "definition の応答を位置として読めること。"
  (if (null (lsp-test-python))
      '(t "file:///fake-target.c" 2 4)
    (let ((log (lsp-test-log-path "def"))
	  (client nil)
	  (uri (lsp-test-uri "lsp-e2e-def.c"))
	  (loc nil))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log)
					   (si:system-root)))
	    (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
	    (lsp-request-definition client uri 0 4
				    #'(lambda (l) (setq loc l)))
	    (list (lsp-test-wait #'(lambda () loc) 30)
		  (getf loc :uri) (getf loc :line) (getf loc :col)))
	(when client (lsp-stop-server client))
	(lsp-test-clean-log log))))
  => (t "file:///fake-target.c" 2 4))

;;;
;;; 後片付け
;;;

(deftest lsp-e2e-stop-server-kills-the-process ()
  "lsp-stop-server がプロセスを止め、一覧から外すこと。"
  (if (null (lsp-test-python))
      '(t t)
    (let ((log (lsp-test-log-path "stop"))
	  (client nil)
	  (proc nil))
      (lsp-test-clean-log log)
      (unwind-protect
	  (progn
	    (setq client (lsp-start-server (lsp-test-server-command log)
					   (si:system-root)))
	    (setq proc (ed::lsp-client-process client))
	    (lsp-test-wait #'(lambda () (lsp-test-log-has log "initialized")) 30)
	    (lsp-stop-server client)
	    (list (lsp-test-wait #'(lambda () (not (eq (process-status proc) :run))) 30)
		  (not (member client ed::*lsp-clients*))))
	(ignore-errors (kill-process proc))
	(lsp-test-clean-log log))))
  => (t t))
