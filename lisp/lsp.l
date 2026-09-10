;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; LSP (Language Server Protocol) client for xyzzy
;;;

(provide "lsp")

(in-package "editor")

(export '(*lsp-mode* *lsp-mode-map* *lsp-mode-hook*
	  *lsp-default-servers* *lsp-clients*
	  json-encode json-decode
	  lsp-make-message lsp-parse-messages
	  lsp-make-initialize-params lsp-make-did-open-params
	  lsp-make-did-change-params lsp-make-did-close-params
	  lsp-extract-diagnostics lsp-parse-location
	  lsp-path-to-uri lsp-uri-to-path lsp-wsl-server-command
	  lsp-start-server lsp-stop-server
	  lsp-find-definition lsp-mode))

;;; ------------------------------------------------------------------
;;; 1. 軽量 JSON エンコーダー / デコーダー

(defun json-escape-string (str)
  (let ((s (make-string-output-stream)))
    (dotimes (i (length str))
      (let ((c (char str i)))
	(case c
	  (#\" (write-string "\\\"" s))
	  (#\\ (write-string "\\\\" s))
	  (#\LFD (write-string "\\n" s))
	  (#\RET (write-string "\\r" s))
	  (#\TAB (write-string "\\t" s))
	  (t (write-char c s)))))
    (get-output-stream-string s)))

(defun json-encode (obj)
  "Lisp オブジェクトを JSON 文字列へシリアライズする。"
  (cond ((eq obj t) "true")
	((eq obj :false) "false")
	((eq obj :null) "null")
	((null obj) "[]")
	((numberp obj) (format nil "~D" obj))
	((stringp obj) (format nil "\"~A\"" (json-escape-string obj)))
	((symbolp obj) (format nil "\"~A\"" (json-escape-string (string-downcase (string obj)))))
	((and (consp obj) (consp (car obj)))
	 ;; alist: ((key . val) ...) -> {"key": val, ...}
	 (let ((entries
		(mapcar #'(lambda (pair)
			    (let* ((raw-k (car pair))
				   (k (cond ((symbolp raw-k)
					     (string-downcase (string raw-k)))
					    (t (string raw-k))))
				   (v (cdr pair)))
			      (format nil "\"~A\": ~A" (json-escape-string k) (json-encode v))))
			obj)))
	   (format nil "{~{~A~^, ~}}" entries)))
	((consp obj)
	 ;; list: [item, ...]
	 (format nil "[~{~A~^, ~}]" (mapcar #'json-encode obj)))
	((vectorp obj)
	 (format nil "[~{~A~^, ~}]" (mapcar #'json-encode (coerce obj 'list))))
	(t "null")))

(defun json-decode (str)
  "JSON 文字列をパースして Lisp データ構造へデコードする。"
  (unless (stringp str)
    (return-from json-decode nil))
  (let ((index 0)
	(len (length str)))
    (labels ((skip-ws ()
	       (while (and (< index len)
			   (member (char str index) '(#\SPC #\TAB #\LFD #\RET)))
		 (incf index)))
	     (peek ()
	       (skip-ws)
	       (when (< index len)
		 (char str index)))
	     (next-char ()
	       (skip-ws)
	       (when (< index len)
		 (prog1 (char str index)
		   (incf index))))
	     (parse-value ()
	       (skip-ws)
	       (let ((ch (peek)))
		 (cond ((null ch) nil)
		       ((char= ch #\") (parse-string))
		       ((char= ch #\{) (parse-object))
		       ((char= ch #\[) (parse-array))
		       ((or (digit-char-p ch) (char= ch #\-)) (parse-number))
		       ((char= ch #\t) (parse-literal "true" t))
		       ((char= ch #\f) (parse-literal "false" :false))
		       ((char= ch #\n) (parse-literal "null" :null))
		       (t (error "Invalid JSON character: ~C" ch)))))
	     (parse-string ()
	       (next-char) ; consume #\"
	       (let ((out (make-string-output-stream)))
		 (loop
		   (when (>= index len)
		     (error "Unterminated JSON string"))
		   (let ((c (char str index)))
		     (incf index)
		     (cond ((char= c #\")
			    (return (get-output-stream-string out)))
			   ((char= c #\\)
			    (when (>= index len)
			      (error "Unterminated escape in JSON string"))
			    (let ((esc (char str index)))
			      (incf index)
			      (case esc
				(#\" (write-char #\" out))
				(#\\ (write-char #\\ out))
				(#\/ (write-char #\/ out))
				(#\b (write-char (code-char 8) out))
				(#\f (write-char (code-char 12) out))
				(#\n (write-char #\LFD out))
				(#\r (write-char #\RET out))
				(#\t (write-char #\TAB out))
				(#\u (let ((hex (subseq str index (+ index 4))))
				       (incf index 4)
				       (write-char (code-char (parse-integer hex :radix 16)) out)))
				(t (write-char esc out)))))
			   (t
			    (write-char c out)))))))
	     (parse-number ()
	       (let ((start index))
		 (when (char= (char str index) #\-)
		   (incf index))
		 (while (and (< index len) (digit-char-p (char str index)))
		   (incf index))
		 (let ((is-float nil))
		   (when (and (< index len) (char= (char str index) #\.))
		     (setq is-float t)
		     (incf index)
		     (while (and (< index len) (digit-char-p (char str index)))
		       (incf index)))
		   (when (and (< index len) (member (char str index) '(#\e #\E)))
		     (setq is-float t)
		     (incf index)
		     (when (and (< index len) (member (char str index) '(#\+ #\-)))
		       (incf index))
		     (while (and (< index len) (digit-char-p (char str index)))
		       (incf index)))
		   (let ((num-str (subseq str start index)))
		     (if is-float
			 (read-from-string num-str)
		       (parse-integer num-str))))))
	     (parse-literal (word val)
	       (let ((wlen (length word)))
		 (if (and (<= (+ index wlen) len)
			  (string= (subseq str index (+ index wlen)) word))
		     (progn
		       (incf index wlen)
		       val)
		   (error "Invalid JSON literal starting at: ~A" (subseq str index (min len (+ index 10)))))))
	     (parse-array ()
	       (next-char) ; consume #\[
	       (skip-ws)
	       (if (char= (peek) #\])
		   (progn (next-char) nil)
		 (let ((items nil))
		   (loop
		     (push (parse-value) items)
		     (skip-ws)
		     (let ((ch (next-char)))
		       (cond ((char= ch #\]) (return (nreverse items)))
			     ((char= ch #\,) nil)
			     (t (error "Expected ',' or ']' in JSON array, got ~C" ch))))))))
	     (parse-object ()
	       (next-char) ; consume #\{
	       (skip-ws)
	       (if (char= (peek) #\})
		   (progn (next-char) nil)
		 (let ((pairs nil))
		   (loop
		     (skip-ws)
		     (unless (char= (peek) #\")
		       (error "Expected string key in JSON object"))
		     (let ((key (parse-string)))
		       (skip-ws)
		       (unless (char= (next-char) #\:)
			 (error "Expected ':' after key in JSON object"))
		       (let ((val (parse-value)))
			 (push (cons key val) pairs)))
		     (skip-ws)
		     (let ((ch (next-char)))
		       (cond ((char= ch #\}) (return (nreverse pairs)))
			     ((char= ch #\,) nil)
			     (t (error "Expected ',' or '}' in JSON object, got ~C" ch)))))))))
      (parse-value))))


;;; ------------------------------------------------------------------
;;; 2. Content-Length プロトコルパース / 生成

(defun lsp-make-message (payload)
  "ペイロード (JSON文字列またはLispオブジェクト) に Content-Length ヘッダを付加する。"
  (let* ((json (if (stringp payload) payload (json-encode payload)))
	 (len (if (fboundp 'si:octet-length)
		  (si:octet-length json :encoding *encoding-utf8n*)
		(length json))))
    (format nil "Content-Length: ~D\r\n\r\n~A" len json)))

(defun lsp-parse-messages (buffer)
  "ストリームバッファから Content-Length ヘッダを持つ完全な JSON-RPC メッセージを取り出す。
(values messages-list remaining-buffer) を返す。"
  (let ((messages nil)
	(buf buffer))
    (loop
      (if (string-match "^Content-Length: \\([0-9]+\\)\r\n\r\n" buf)
	  (let* ((header-end (match-end 0))
		 (len (parse-integer (match-string 1)))
		 (total-len (+ header-end len)))
	    (if (>= (length buf) total-len)
		(let* ((json-str (subseq buf header-end total-len))
		       (parsed (ignore-errors (json-decode json-str))))
		  (when parsed
		    (push parsed messages))
		  (setq buf (subseq buf total-len)))
	      ;; ペイロードがまだ全て届いていない
	      (return)))
	;; ヘッダが途中またはゴミがある場合
	(let ((pos (string-match "Content-Length: " buf)))
	  (if (and pos (> pos 0))
	      (setq buf (subseq buf pos))
	    (return)))))
    (values (nreverse messages) buf)))


;;; ------------------------------------------------------------------
;;; 3. URI / パス相互変換 & WSL 透過トランスレータ (Issue #345)

(defun lsp-path-to-uri (path &optional distro)
  "ファイルパス (Windows ローカルパスまたは WSL UNC パス) を LSP 用の file:// URI に変換する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (string-match "^file:" path)
    (return-from lsp-path-to-uri path))
  ;; WSL UNC パス (\\wsl.localhost\... や //wsl.localhost/...)
  (if (and (fboundp 'wsl-path-p) (wsl-path-p path))
      (let ((linux-path (if (fboundp 'windows-path-to-wsl)
			    (windows-path-to-wsl path)
			  path)))
	(concat "file:///" (substitute-string (map-backslash-to-slash linux-path) "^/+" "")))
    (let ((norm (map-backslash-to-slash path)))
      (cond
       ;; ドライブレター形式 (C:/... や c:/...)
       ((string-match "^\\([a-zA-Z]:.*\\)$" norm)
	(concat "file:///" norm))
       ;; Linux パス (/home/... など)
       ((string-match "^/+" norm)
	(concat "file:///" (substitute-string norm "^/+" "")))
       (t
	(concat "file:///" norm))))))

(defun lsp-uri-to-path (uri &optional distro)
  "LSP の file:// URI を xyzzy で開くためのファイルパス (Windows パスまたは WSL UNC パス) に変換する。"
  (unless (stringp uri)
    (return-from lsp-uri-to-path nil))
  (let ((clean (substitute-string uri "^file:/*" "/")))
    ;; ドライブレター形式 (/C:/... -> C:/...)
    (if (string-match "^/\\([a-zA-Z]:/.*\\)$" clean)
	(match-string 1)
      ;; /mnt/<drive>/... -> <drive>:/...
      (if (string-match "^/mnt/\\([a-zA-Z]\\)\\(/.*\\)?$" clean)
	  (if (fboundp 'wsl-path-to-windows)
	      (wsl-path-to-windows clean distro)
	    (let ((drive (char-upcase (char (match-string 1) 0)))
		  (rest (match-string 2)))
	      (format nil "~C:~A" drive (or rest "/"))))
	;; /home/... などの Linux パス -> WSL UNC パス
	(if (string-match "^/" clean)
	    (if (fboundp 'wsl-path-to-windows)
		(wsl-path-to-windows clean distro)
	      clean)
	  clean)))))

(defun lsp-wsl-server-command (command &optional distro dir)
  "WSL 上で言語サーバーを起動するためのコマンドラインを生成する。"
  (let ((d (or distro (and (fboundp 'wsl-current-distro) (wsl-current-distro dir)) "Ubuntu"))
	(wsl (or (and (boundp '*wsl-command*) *wsl-command*) "wsl.exe")))
    (format nil "~A -d ~A -- ~A" wsl d command)))


;;; ------------------------------------------------------------------
;;; 4. ライフサイクル & ドキュメント同期パラメータ構築

(defun lsp-make-initialize-params (root-path &optional pid)
  "initialize リクエストのパラメータ alist を構築する。"
  (let ((uri (lsp-path-to-uri root-path)))
    `(("processId" . ,(or pid :null))
      ("rootPath" . ,root-path)
      ("rootUri" . ,uri)
      ("capabilities" . (("textDocument" . (("synchronization" . (("didSave" . t)))
					    ("definition" . (("dynamicRegistration" . t)))
					    ("publishDiagnostics" . (("relatedInformation" . t))))))))))

(defun lsp-make-did-open-params (uri language-id version text)
  "textDocument/didOpen 通知のパラメータ alist を構築する。"
  `(("textDocument" . (("uri" . ,uri)
		       ("languageId" . ,language-id)
		       ("version" . ,version)
		       ("text" . ,text)))))

(defun lsp-make-did-change-params (uri version text)
  "textDocument/didChange 通知のパラメータ alist を構築する。"
  `(("textDocument" . (("uri" . ,uri)
		       ("version" . ,version)))
    ("contentChanges" . ((("text" . ,text))))))

(defun lsp-make-did-close-params (uri)
  "textDocument/didClose 通知のパラメータ alist を構築する。"
  `(("textDocument" . (("uri" . ,uri)))))


;;; ------------------------------------------------------------------
;;; 4. 診断 & 定義位置パース

(defun lsp-extract-diagnostics (msg)
  "publishDiagnostics 通知から診断項目のリストを抽出する。"
  (let ((params (cdr (assoc "params" msg :test #'string=))))
    (unless params (setq params msg))
    (let* ((uri (cdr (assoc "uri" params :test #'string=)))
	   (raw-diags (cdr (assoc "diagnostics" params :test #'string=)))
	   (result nil))
      (dolist (d raw-diags)
	(let* ((range (cdr (assoc "range" d :test #'string=)))
	       (start (cdr (assoc "start" range :test #'string=)))
	       (line (and start (cdr (assoc "line" start :test #'string=))))
	       (col (and start (cdr (assoc "character" start :test #'string=))))
	       (sev (cdr (assoc "severity" d :test #'string=)))
	       (message (cdr (assoc "message" d :test #'string=))))
	  (push (list :uri uri :line line :col col :severity sev :message message) result)))
      (nreverse result))))

(defun lsp-parse-location (loc)
  "definition レスポンスから URI と line, col を抽出する。"
  (when (and (consp loc) (consp (car loc)) (consp (caar loc)))
    (setq loc (car loc)))
  (let* ((target (if (assoc "result" loc :test #'string=)
		     (cdr (assoc "result" loc :test #'string=))
		   loc)))
    (when (and (consp target) (consp (car target)) (consp (caar target)))
      (setq target (car target)))
    (when target
      (let* ((uri (or (cdr (assoc "uri" target :test #'string=))
		      (cdr (assoc "targetUri" target :test #'string=))))
	     (range (or (cdr (assoc "range" target :test #'string=))
			(cdr (assoc "targetRange" target :test #'string=))
			(cdr (assoc "targetSelectionRange" target :test #'string=))))
	     (start (cdr (assoc "start" range :test #'string=)))
	     (line (and start (cdr (assoc "line" start :test #'string=))))
	     (col (and start (cdr (assoc "character" start :test #'string=)))))
	(list :uri uri :line line :col col)))))


;;; ------------------------------------------------------------------
;;; 5. クライアント接続・セッション管理

(defvar *lsp-clients* nil
  "起動中の LSP クライアント情報のリスト")

(defvar *lsp-default-servers*
  '(("c-mode" . "clangd")
    ("c++-mode" . "clangd")
    ("python-mode" . "pylsp")
    ("rust-mode" . "rust-analyzer")
    ("go-mode" . "gopls"))
  "メジャーモード名と既定の言語サーバーコマンドの対応表")

(defstruct lsp-client
  process
  (recv-buf "")
  (next-id 1)
  (callbacks (make-hash-table :test 'equal))
  root-path
  server-cmd
  wsl-distro)

(defun lsp-send-request (client method params &optional callback)
  "JSON-RPC リクエストを送信する。"
  (let* ((id (lsp-client-next-id client))
	 (req `(("jsonrpc" . "2.0")
		("id" . ,id)
		("method" . ,method)
		("params" . ,params)))
	 (msg (lsp-make-message req)))
    (setf (lsp-client-next-id client) (1+ id))
    (when callback
      (setf (gethash id (lsp-client-callbacks client)) callback))
    (process-send-string (lsp-client-process client) msg)
    id))

(defun lsp-send-notification (client method params)
  "JSON-RPC 通知を送信する。"
  (let* ((notif `(("jsonrpc" . "2.0")
		  ("method" . ,method)
		  ("params" . ,params)))
	 (msg (lsp-make-message notif)))
    (process-send-string (lsp-client-process client) msg)))

(defun lsp-handle-message (client msg)
  "受信した JSON-RPC メッセージをディスパッチする。"
  (let ((id (cdr (assoc "id" msg :test #'string=)))
	(method (cdr (assoc "method" msg :test #'string=))))
    (cond
     ;; レスポンス (id に対するコールバック)
     (id
      (let ((cb (gethash id (lsp-client-callbacks client))))
	(when cb
	  (remhash id (lsp-client-callbacks client))
	  (funcall cb (cdr (assoc "result" msg :test #'string=))))))
     ;; サーバーからの通知
     ((and method (string= method "textDocument/publishDiagnostics"))
      (let ((diags (lsp-extract-diagnostics msg)))
	(when diags
	  (message "LSP Diagnostics: ~D issue(s) reported" (length diags))))))))

(defun lsp-start-server (command &optional root-path distro)
  "言語サーバープロセスを起動してクライアントオブジェクトを返す。
WSL プロジェクト内または明示的に DISTRO が指定された場合は WSL 経由でサーバーを起動する。"
  (let* ((root (or root-path (default-directory)))
	 (target-distro (or distro
			    (and (fboundp 'wsl-path-p) (wsl-path-p root)
				 (fboundp 'wsl-extract-distro) (wsl-extract-distro root))
			    (and (fboundp 'wsl-current-distro) (wsl-current-distro root))))
	 (is-wsl (or distro
		     (and (fboundp 'wsl-path-p) (wsl-path-p root))
		     (and (fboundp 'wsl-project-p) (wsl-project-p root))))
	 (actual-cmd (if is-wsl
			 (lsp-wsl-server-command command target-distro root)
		       command))
	 (client (make-lsp-client :root-path root :server-cmd actual-cmd
				  :wsl-distro (and is-wsl target-distro)))
	 (proc (make-process actual-cmd
			     :exec-directory root
			     :incode *encoding-utf8*
			     :outcode *encoding-utf8*
			     :show :hide)))
    (setf (lsp-client-process client) proc)
    (set-process-filter
     proc
     #'(lambda (p chunk)
	 (setf (lsp-client-recv-buf client)
	       (concat (lsp-client-recv-buf client) chunk))
	 (multiple-value-bind (msgs rem)
	     (lsp-parse-messages (lsp-client-recv-buf client))
	   (setf (lsp-client-recv-buf client) rem)
	   (dolist (m msgs)
	     (lsp-handle-message client m)))))
    ;; initialize 送信
    (lsp-send-request client "initialize" (lsp-make-initialize-params root)
		      #'(lambda (res)
			  (lsp-send-notification client "initialized" '())))
    (push client *lsp-clients*)
    client))

(defun lsp-stop-server (&optional client)
  "言語サーバープロセスを停止する。"
  (let ((c (or client (car *lsp-clients*))))
    (when c
      (ignore-errors (lsp-send-request c "shutdown" nil))
      (ignore-errors (lsp-send-notification c "exit" nil))
      (setq *lsp-clients* (delete c *lsp-clients*)))))


;;; ------------------------------------------------------------------
;;; 6. 対話コマンド & lsp-mode

(defvar-local *lsp-mode* nil)
(defvar *lsp-mode-hook* nil)
(defvar *lsp-mode-map* nil)

(unless *lsp-mode-map*
  (setq *lsp-mode-map* (make-sparse-keymap))
  (define-key *lsp-mode-map* '(#\M-.) 'lsp-find-definition))

(defun lsp-find-definition ()
  "カーソル位置のシンボルの定義位置へジャンプする。"
  (interactive)
  (let ((client (car *lsp-clients*)))
    (unless client
      (message "No active LSP client.")
      (return-from lsp-find-definition nil))
    (let* ((filename (get-buffer-file-name))
	   (distro (and client (lsp-client-wsl-distro client)))
	   (uri (if filename (lsp-path-to-uri filename distro) nil))
	   (line (1- (current-line-number)))
	   (col (current-column)))
      (unless uri
	(message "Buffer has no associated file.")
	(return-from lsp-find-definition nil))
      (lsp-send-request
       client "textDocument/definition"
       `(("textDocument" . (("uri" . ,uri)))
	 ("position" . (("line" . ,line) ("character" . ,col))))
       #'(lambda (res)
	   (let ((loc (lsp-parse-location res)))
	     (if loc
		 (let ((file (lsp-uri-to-path (getf loc :uri) distro)))
		   (find-file file)
		   (goto-line (1+ (getf loc :line)))
		   (goto-column (getf loc :col)))
	       (message "Definition not found."))))))))

(defun lsp-mode (&optional (arg nil sv))
  "LSP マイナーモードのトグル。"
  (interactive)
  (setq *lsp-mode*
	(if sv
	    (plusp (prefix-numeric-value arg))
	  (not *lsp-mode*)))
  (if *lsp-mode*
      (progn
	(set-minor-mode-map *lsp-mode-map*)
	(run-hooks '*lsp-mode-hook*))
    (unset-minor-mode-map *lsp-mode-map*)))
