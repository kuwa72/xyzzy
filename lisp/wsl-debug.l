;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; WSL 上のコーディングエージェントから Windows 上の xyzzy を操作する
;;; TCP デバッグサーバ (PoC)。
;;;
;;;   M-x wsl-debug-serve   127.0.0.1:11722 で待受し、来た接続に REPL を出す
;;;   WSL 側: tools/wsl-debug.py '(+ 1 2)' で評価結果を受け取る
;;;
;;; プロトコルは行単位・UTF-8。最初の行が認証、その後 1 行 1 S 式:
;;;
;;;   C: AUTH <token>     (トークン未設定時は不要、そのまま S 式を送る)
;;;   S: +OK auth
;;;   C: (+ 1 2)
;;;   S: +OK 3
;;;   C: (+ 1 *unbound*)
;;;   S: -ERR ...
;;;
;;; 応答は必ず 1 行 (改行は空白に畳む)。GUI スレッドで動くため serve 中は
;;; xyzzy がその処理に専念する。C-g / 切断で復帰する。将来の課題は
;;; accept のノンブロック化 (タイマ駆動ポーリング)。

(provide "wsl-debug")

(in-package "editor")

(export '(*wsl-debug-host* *wsl-debug-port* *wsl-debug-token*
          wsl-debug-start wsl-debug-stop wsl-debug-serve
          wsl-debug-generate-token wsl-debug-eval-text))

(defvar *wsl-debug-host* "127.0.0.1"
  "待受アドレス。WSL との localhost 転送用に loopback 固定が既定。")

(defvar *wsl-debug-port* 11722
  "待受ポート。")

(defvar *wsl-debug-token* nil
  "認証トークン。nil のとき認証を要求しない。
loopback とはいえ同じマシン (WSL 含む) のどのプロセスからも Lisp を
評価できるので、他人・他プロセスと共有する環境では
`wsl-debug-generate-token' 等で必ずトークンを設定すること。")

(defvar *wsl-debug-listen-stream* nil
  "待受ソケット。`wsl-debug-start' が作り `wsl-debug-stop' が閉じる。")

(defun wsl-debug-single-line (s)
  "S 中の改行・復帰を空白に畳んで 1 行にする。"
  (with-output-to-string (out)
    (dotimes (i (length s))
      (let ((c (char s i)))
        (write-char (if (or (char= c #\Newline) (char= c #\Return)) #\Space c)
                    out)))))

(defun wsl-debug-format-ok (s)
  "成功応答 \"+OK ...\" を作る。S は 1 行に畳まれる。"
  (concat "+OK " (wsl-debug-single-line s)))

(defun wsl-debug-format-error (s)
  "失敗応答 \"-ERR ...\" を作る。S は 1 行に畳まれる。"
  (concat "-ERR " (wsl-debug-single-line s)))

(defun wsl-debug-check-auth (line)
  "認証行が正しければ t。トークン未設定時はつねに t。"
  (if (null *wsl-debug-token*)
      t
    (and (stringp line)
         (equal line (concat "AUTH " *wsl-debug-token*)))))

(defun wsl-debug-eval-text (text)
  "TEXT を 1 つの Lisp 形として読み評価し、応答行を返す。エラーは -ERR。"
  (handler-case
      (let* ((form (read-from-string text))
             (value (eval form)))
        (wsl-debug-format-ok (prin1-to-string value)))
    (error (c)
      (wsl-debug-format-error (format nil "~A" c)))))

(defun wsl-debug-generate-token ()
  "*wsl-debug-token* に `si:uuid-create' 由来のトークンを設定して返す。
UUID v4 は 122bit の乱数 (Windows は UuidCreate、POSIX は /dev/urandom) で、
予測可能な時刻 + `random' の組み合わせより推測が困難。"
  (setq *wsl-debug-token* (si:uuid-create)))

(defun wsl-debug-start (&optional port)
  "待受ソケットを作る。既にあればそれを返す。"
  (when (and *wsl-debug-listen-stream*
             (ignore-errors (open-stream-p *wsl-debug-listen-stream*)))
    (return-from wsl-debug-start *wsl-debug-listen-stream*))
  (let ((port (or port *wsl-debug-port*)))
    (setq *wsl-debug-port* port)
    (setq *wsl-debug-listen-stream*
          (make-listen-socket *wsl-debug-host* port :reuseaddr t :backlog 5))
    (message "wsl-debug: listening on ~A:~D" *wsl-debug-host* port)
    *wsl-debug-listen-stream*))

(defun wsl-debug-stop ()
  "待受ソケットを閉じる。"
  (when *wsl-debug-listen-stream*
    (ignore-errors (close *wsl-debug-listen-stream*))
    (setq *wsl-debug-listen-stream* nil))
  nil)

(defun wsl-debug-serve-session (client)
  "1 接続分の応答ループ。認証後に 1 行 1 評価。EOF で戻る。"
  (let ((authed (null *wsl-debug-token*)))
    (loop
      (let ((line (read-line client nil nil)))
        (unless line
          (return))
        (setq line (string-trim " \t\r\n" line))
        (unless (zerop (length line))
          (cond ((not authed)
               (if (wsl-debug-check-auth line)
                   (progn
                     (setq authed t)
                     (format client "+OK auth~%")
                     (finish-output client))
                 (progn
                   (format client "-ERR auth~%")
                   (finish-output client)
                   (return))))
              (t
               (format client "~A~%" (wsl-debug-eval-text line))
               (finish-output client))))))))

(defun wsl-debug-serve (&optional port)
  "待受して WSL からの接続に順次応答する (ブロックするデバッグ用)。"
  (interactive "p")
  (wsl-debug-start (or port *wsl-debug-port*))
  (unwind-protect
      (loop
        (with-open-stream (client (accept-connection *wsl-debug-listen-stream*
                                                     :encoding :utf8))
          (wsl-debug-serve-session client)))
    (wsl-debug-stop)))
