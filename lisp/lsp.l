;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; LSP (Language Server Protocol) client for xyzzy
;;;

(provide "lsp")

(in-package "editor")

(export '(*lsp-mode* *lsp-mode-map* *lsp-mode-hook*
	  *lsp-default-servers* *lsp-clients* *lsp-server-installers*
	  json-encode json-decode
	  lsp-make-message lsp-parse-messages
	  lsp-make-initialize-params lsp-make-did-open-params
	  lsp-make-did-change-params lsp-make-did-close-params
	  lsp-extract-diagnostics lsp-parse-location
	  lsp-path-to-uri lsp-uri-to-path lsp-wsl-server-command
	  lsp-start-server lsp-stop-server
	  lsp-server-installed-p lsp-install-server *lsp-last-install-log*
	  lsp-decode-utf8 lsp-notify-open lsp-notify-change lsp-notify-save
	  lsp-notify-close lsp-request-definition
	  lsp-connect lsp-disconnect lsp-sync-buffer
	  *lsp-language-ids* *lsp-idle-delay*
	  lsp-find-definition lsp-mode))

;;; ------------------------------------------------------------------
;;; 1. 軽量 JSON エンコーダー / デコーダー

(defun json-escape-string (str)
  (let ((s (make-string-output-stream)))
    (dotimes (i (length str))
      (let ((c (char str i)))
	(case c
	  (#\" (write-char #\\ s) (write-char #\" s))
	  (#\\ (write-char #\\ s) (write-char #\\ s))
	  (#\LFD (write-char #\\ s) (write-char #\n s))
	  (#\RET (write-char #\\ s) (write-char #\r s))
	  (#\TAB (write-char #\\ s) (write-char #\t s))
	  (t (write-char c s)))))
    (get-output-stream-string s)))

(defun json-key-string (key)
  "オブジェクトのキーを JSON のキー文字列へ変換する。"
  (cond ((symbolp key) (string-downcase (string key)))
	((stringp key) key)
	(t (format nil "~A" key))))

(defun json-object-p (obj)
  "OBJ が JSON オブジェクト ((キー . 値) のリスト) かどうか。

**`(consp (car obj))' だけで判定してはいけない。** 値がオブジェクトの
配列、たとえば `(((\"text\" . \"hello\")))' (didChange の `contentChanges'
がこの形) も car が cons になるので、オブジェクトと取り違えると値の側を
さらにキーと値の組として読み、`(\"text\" . \"hello\")' をキーとして
文字列化しようとして型エラーになる。キーは文字列かシンボルなので、
そこで見分ける。"
  (and (consp obj)
       (let ((result t))
	 (dolist (pair obj)
	   (unless (and (consp pair)
			(or (stringp (car pair)) (symbolp (car pair))))
	     (setq result nil)))
	 result)))

(defun json-encode (obj)
  "Lisp オブジェクトを JSON 文字列へシリアライズする。

オブジェクトは `((キー . 値) ...)'、配列は vector か値のリストで表す。
値がリストのときは「そのまま配列」になる。オブジェクトにしたいときは
`(キー . ((キー . 値) ...))' のように cons の cdr へオブジェクトを置く。"
  (cond ((eq obj t) "true")
	((eq obj :false) "false")
	((eq obj :null) "null")
	((null obj) "[]")
	((numberp obj) (format nil "~D" obj))
	((stringp obj) (format nil "\"~A\"" (json-escape-string obj)))
	((symbolp obj) (format nil "\"~A\"" (json-escape-string (string-downcase (string obj)))))
	((json-object-p obj)
	 (format nil "{~{~A~^, ~}}"
		 (mapcar #'(lambda (pair)
			     (format nil "\"~A\": ~A"
				     (json-escape-string (json-key-string (car pair)))
				     (json-encode (cdr pair))))
			 obj)))
	((vectorp obj)
	 (format nil "[~{~A~^, ~}]" (mapcar #'json-encode (coerce obj 'list))))
	((consp obj)
	 ;; list: [item, ...]
	 (format nil "[~{~A~^, ~}]" (mapcar #'json-encode obj)))
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
	 ;; **バイト数で数える。** Content-Length はバイト数であって文字数では
	 ;; ない。`length' で数えると、日本語を含むメッセージで相手が待ち続ける。
	 (len (si:octet-length json :encoding *encoding-utf8n*)))
    (format nil "Content-Length: ~D\r\n\r\n~A" len json)))

(defun lsp-decode-utf8 (bytes)
  "UTF-8 のバイト列を文字列へ復号する。

`make-process' の `:incode' に `*encoding-binary*' を渡しているので、
フィルタが受け取る文字列は 1 文字 = 1 バイトである。Content-Length は
バイト数なので、本文を切り出すにはこの形で受け取る必要がある。"
  (let ((out (make-string-output-stream))
	(n (length bytes))
	(i 0))
    (labels ((continuation ()
	       (incf i)
	       (logand (char-code (char bytes i)) #x3F)))
      (while (< i n)
	(let* ((b (char-code (char bytes i)))
	       (cp nil))
	  (cond ((< b #x80)
		 (setq cp b)
		 (incf i))
		((= (logand b #xE0) #xC0)
		 (setq cp (logior (ash (logand b #x1F) 6) (continuation)))
		 (incf i))
		((= (logand b #xF0) #xE0)
		 (setq cp (logior (ash (logand b #x0F) 12) (ash (continuation) 6)))
		 (setq cp (logior cp (continuation)))
		 (incf i))
		((= (logand b #xF8) #xF0)
		 (setq cp (logior (ash (logand b #x07) 18) (ash (continuation) 12)))
		 (setq cp (logior cp (ash (continuation) 6)))
		 (setq cp (logior cp (continuation)))
		 (incf i))
		(t
		 (setq cp b)
		 (incf i)))
	  (write-char (code-char cp) out))))
    (get-output-stream-string out)))

(defun lsp-parse-messages (buffer)
  "ストリームバッファから Content-Length ヘッダを持つ完全な JSON-RPC メッセージを取り出す。
(values messages-list remaining-buffer) を返す。"
  (let ((messages nil)
	(buf buffer))
    (loop
      ;; **ヘッダの終わりを探してから中身を見る。** 以前は
      ;; `^Content-Length: N\r\n\r\n' を決め打ちで照合していたので、
      ;; Content-Type のような別のヘッダが 1 行あるだけで一致しなくなり、
      ;; 届いたものは溜まる一方で**何も読めなくなっていた** (clangd は
      ;; Content-Length の次に Content-Type を送る)。
      ;; **CRLF でも LF でも受ける。** プロセスの `:eol-code' が CRLF の
      ;; ままだと、フロントエンドが受信した `\r' を落としてヘッダが
      ;; `\n\n' で届く (Windows の既定)。`lsp-start-server' は `*eol-lf*'
      ;; を渡して変換を止めているが、そこで救えない経路 (WSL の
      ;; `wsl.exe' 越しなど) でも読めるようにしておく。
      (let* ((crlf-end (string-match "\r\n\r\n" buf))
	     (lf-end (string-match "\n\n" buf))
	     (header-end (cond ((null crlf-end) lf-end)
			       ((null lf-end) crlf-end)
			       (t (min crlf-end lf-end))))
	     (sep-len (if (eql header-end crlf-end) 4 2)))
	(if (null header-end)
	    ;; ヘッダがまだ全部届いていない。届くまでそのまま溜める。
	    (return)
	  (let* ((header (subseq buf 0 header-end))
		 (len (and (string-match "Content-Length:[ \t]*\\([0-9]+\\)" header)
			   (parse-integer (match-string 1)))))
	    (if (null len)
		;; ヘッダの形をしていないものが前に残っている。読み飛ばす。
		(setq buf (subseq buf (+ header-end sep-len)))
	      (let ((total (+ header-end sep-len len)))
		(if (< (length buf) total)
		    ;; 本文がまだ全部届いていない。
		    (return)
		  (let* ((body (subseq buf (+ header-end sep-len) total))
			 (parsed (ignore-errors (json-decode (lsp-decode-utf8 body)))))
		    (when parsed
		      (push parsed messages))
		    (setq buf (subseq buf total))))))))))
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

(defun lsp-make-did-save-params (uri)
  "textDocument/didSave 通知のパラメータ alist を構築する。"
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
	;; **位置が無ければ nil。** 以前は uri が nil でも plist を返していたので、
	;; 呼び出し側の `(if loc ...)' が常に真になり、「定義が見つかりません」の
	;; 代わりに空のバッファを開こうとしていた。
	(when uri
	  (list :uri uri :line line :col col))))))


;;; ------------------------------------------------------------------
;;; 5. クライアント接続・セッション管理

(defvar *lsp-clients* nil
  "起動中の LSP クライアント情報のリスト")

(defvar *lsp-default-servers*
  '(("c-mode" . "clangd")
    ("c++-mode" . "clangd")
    ("python-mode" . "pylsp")
    ("rust-mode" . "rust-analyzer")
    ("go-mode" . "gopls")
    ("javascript-mode" . "typescript-language-server --stdio")
    ("yaml-mode" . "yaml-language-server --stdio")
    ("json-mode" . "vscode-json-language-server --stdio"))
  "メジャーモード名と既定の言語サーバーコマンドの対応表")

(defvar *lsp-language-ids*
  '(("c-mode" . "c")
    ("c++-mode" . "cpp")
    ("python-mode" . "python")
    ("rust-mode" . "rust")
    ("go-mode" . "go")
    ("javascript-mode" . "javascript")
    ("typescript-mode" . "typescript")
    ("yaml-mode" . "yaml")
    ("json-mode" . "json"))
  "メジャーモード名と LSP の languageId の対応表。無いモードは plaintext。")

;;; ------------------------------------------------------------------
;;; 5-a. LSP サーバーインストーラ

(defvar *lsp-last-install-log* nil
  "直近に lsp-install-server が失敗したときのログファイルのパス。")

(defvar *lsp-server-installers*
  '(("clangd"
     (:windows "winget install LLVM.LLVM" nil)
     (:wsl     "sudo apt install -y clangd" "sudo"))
    ("pylsp"
     (:windows "pip install python-lsp-server" "pip")
     (:wsl     "sudo -n apt install -y python3-pylsp" "apt"))
    ("gopls"
     (:windows "go install golang.org/x/tools/gopls@latest" "go")
     (:wsl     "go install golang.org/x/tools/gopls@latest" "go"))
    ("rust-analyzer"
     (:windows "rustup component add rust-analyzer" "rustup")
     (:wsl     "rustup component add rust-analyzer" "rustup"))
    ("typescript-language-server"
     (:windows "npm install -g typescript-language-server typescript" "npm")
     (:wsl     "npm install -g typescript-language-server typescript" "npm"))
    ("yaml-language-server"
     (:windows "npm install -g yaml-language-server" "npm")
     (:wsl     "npm install -g yaml-language-server" "npm"))
    ("json-language-server"
     (:windows "npm install -g vscode-langservers-extracted" "npm")
     (:wsl     "npm install -g vscode-langservers-extracted" "npm")))
  "サーバー名とインストールコマンドの対応表。
各エントリは (SERVER-NAME . PROPERTIES)。
PROPERTIES は ((:windows CMD PREREQ) (:wsl CMD PREREQ))。
PREREQ が nil なら前提ツール不要、文字列なら which で存在確認する。")

(defun lsp-server-installed-p (server)
  "SERVER コマンドが PATH 上に存在するか判定する。
Windows では `where`、POSIX では `which` を使用する。"
  (let* ((is-win (let ((p (os-platform)))
		   (and (symbolp p)
			(string-match "^windows" (symbol-name p)))))
	 (probe-cmd (if is-win
			(format nil "where ~A" server)
		      (format nil "which ~A" server)))
	 (buf (create-new-buffer " *lsp-probe*")))
    (unwind-protect
	(let ((rc (call-process probe-cmd :output buf :show :hide :wait t)))
	  (zerop rc))
      (delete-buffer buf))))

(defun lsp--wsl-installed-p (server &optional distro)
  "WSL ディストロ上で SERVER コマンドの存在を確認する。"
  (let ((wsl (or (and (boundp '*wsl-command*) *wsl-command*) "wsl.exe"))
        (buf (create-new-buffer " *lsp-probe*")))
    (unwind-protect
        (let ((rc (call-process (format nil "~A -d ~A -- which ~A" wsl (or distro "Ubuntu") server)
                                :output buf :show :hide :wait t)))
          (zerop rc))
      (delete-buffer buf))))

(defun lsp--installed-p (server is-wsl distro)
  "コンテキストに応じた存在確認。WSL なら WSL 側で which する。"
  (if is-wsl
      (lsp--wsl-installed-p server distro)
    (lsp-server-installed-p server)))

(defun lsp--server-entry (name)
  "*lsp-server-installers* から NAME のエントリを検索する。"
    (assoc name *lsp-server-installers* :test #'string=))

(defun lsp--install-cmd (entry context)
  "ENTRY から CONTEXT (:windows か :wsl) のインストールコマンドと prereq を返す。
  (values command prerequisite)。該当がなければ (values nil nil)。"
  (let ((prop (assoc context entry)))
    (if prop
	(let ((cmd (cadr prop))
	      (prereq (caddr prop)))
	  (values cmd prereq))
      (values nil nil))))

(defun lsp--check-prereq (prereq)
  "PREREQ ツールの存在を確認する。nil なら t を返す。"
  (or (null prereq) (lsp-server-installed-p prereq)))

(defun lsp--permission-error-p (output)
  "OUTPUT 文字列に権限エラーを示すパターンが含まれるか判定する。"
  (or (string-match "Permission denied" output)
      (string-match "EACCES" output)
      (string-match "Access is denied" output)
      (string-match "require administrator" output)
      (string-match "no tty present" output)
      (string-match "a password is required" output)))

(defun lsp--finish-failed-install (server cmd actual-cmd rc buf)
  "インストール失敗時の後処理。ログをバッファとファイルに残して表示する。"
  (let ((logfile (format nil "~A/xyzzy-lsp-install-~A.log"
                         (or (si:getenv "TEMP") (si:getenv "TMP") ".")
                         server)))
    (save-excursion
      (set-buffer buf)
      (goto-char (point-min))
      (insert (format nil "Command: ~A~%Exit code: ~D~%~%" actual-cmd rc))
      (write-region (point-min) (point-max) logfile))
    (setq *lsp-last-install-log* logfile)
    (kill-new logfile)
    (let ((err-text (save-excursion
                      (set-buffer buf)
                      (buffer-substring (point-min) (point-max)))))
      (if (lsp--permission-error-p err-text)
          (progn
            (message "Permission denied (exit ~D). Run manually: ~A" rc cmd)
            (kill-new cmd))
        (message "Failed to install ~A (exit ~D). Log: ~A" server rc logfile)))
    (pop-to-buffer buf)))

(defun lsp-install-server (server)
  "言語サーバー SERVER をインストールする。
カレントバッファが WSL パスなら WSL 側で、そうでなければ Windows 側で実行する。"
  (interactive
   (let* ((default (and (boundp '*lsp-default-servers*)
			(cdr (assoc (symbol-name (or buffer-mode 'fundamental-mode))
				    *lsp-default-servers*
				    :test #'string=))))
	  (candidates (mapcar #'car *lsp-server-installers*))
	  (prompt (if default
		      (format nil "Install LSP server (default ~A): " default)
		    "Install LSP server: "))
	  (sel (completing-read prompt candidates :default default :must-match t)))
     (list sel)))
  (let ((entry (lsp--server-entry server)))
    (unless entry
      (error "Unknown server: ~A" server))
    (let* ((is-wsl (and (fboundp 'wsl-path-p)
			(wsl-path-p (default-directory))))
	   (distro (and is-wsl (fboundp 'wsl-current-distro) (wsl-current-distro (default-directory))))
	   (prop (assoc (if is-wsl :wsl :windows) entry))
	   (cmd (and prop (cadr prop)))
	   (prereq (and prop (caddr prop))))
      (unless cmd
	(error "No installer defined for ~A" server))
      (cond
       ((lsp--installed-p server is-wsl distro)
	(message "~A is already installed." server))
       ((and prereq (not (lsp--installed-p prereq is-wsl distro)))
	(message "~A requires ~A. Please install ~A first."
		 server prereq prereq))
       (t
	        (message "Installing ~A ..." server)
        (let ((actual-cmd (if is-wsl
                              (lsp-wsl-server-command cmd distro)
                            cmd))
              (buf (create-new-buffer "*lsp-install*")))
          (let ((rc (call-process actual-cmd :output buf :show :hide :wait t)))
            (if (zerop rc)
                (progn
                  ;; **入れた側で確認する。** WSL プロジェクトでは wsl.exe 越しに
                  ;; WSL 側へ入れたのに、ここだけ Windows 側 (where) を見ていた
                  ;; ため、WSL 側にしかコマンドが無いと「入ったのに PATH に無い」
                  ;; と誤って報告し、*lsp-install* バッファを開いていた。
                  (if (lsp--installed-p server is-wsl distro)
                      (progn
                        (message "~A installed successfully." server)
                        (delete-buffer buf)
                        (when *lsp-last-install-log*
                        (delete-file *lsp-last-install-log* :if-does-not-exist :skip)))
                    (progn
                      (pop-to-buffer buf)
                      (message "~A installed, but ~A is not on PATH. Add it to PATH and restart xyzzy." server server))))
              (lsp--finish-failed-install server cmd actual-cmd rc buf)))))))))
(defstruct lsp-client
  process
  (recv-buf "")
  (next-id 1)
  (callbacks (make-hash-table :test 'equal))
  root-path
  ;; 起動に使った生のコマンド。同じサーバーを二重に起動しないための照合に使う。
  command
  ;; 実際に起動したコマンド行 (WSL 経由なら wsl.exe ... が入る)。
  server-cmd
  wsl-distro
  ;; 子の出力を受ける捨てバッファ。`:output' を省略すると make-process は
  ;; 「今のバッファ」に結び付く (lsp-start-server の注記を見よ)。
  output-buffer
  ;; URI -> 版番号。didOpen で 1 から数え始める。
  (versions (make-hash-table :test 'equal))
  ;; URI -> 診断のリスト。
  (diagnostics (make-hash-table :test 'equal))
  ;; こちらから止めたのか。sentinel でメッセージを出し分けるため。
  stopping)

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

(defun lsp-send-response (client id result)
  "サーバーからの要求への応答を送る。"
  (process-send-string (lsp-client-process client)
		       (lsp-make-message `(("jsonrpc" . "2.0")
					   ("id" . ,id)
					   ("result" . ,result)))))

(defun lsp-handle-message (client msg)
  "受信した JSON-RPC メッセージをディスパッチする。"
  (let ((id (cdr (assoc "id" msg :test #'string=)))
	(method (cdr (assoc "method" msg :test #'string=))))
    (cond
     ;; **サーバーからの要求 (id と method が両方ある) を先に見る。**
     ;; 応答にも id はあるので、順序を逆にすると要求を応答として扱い、
     ;; コールバックを呼んで**サーバーは応答を待ち続ける。** 中身は
     ;; `workspace/configuration' のように「答えないと先へ進まない」ものが
     ;; あるので、断るにしても必ず 1 つ返す。
     ((and id method)
      (lsp-send-response client id :null))
     (id
      (let ((cb (gethash id (lsp-client-callbacks client))))
	(when cb
	  (remhash id (lsp-client-callbacks client))
	  (let ((err (cdr (assoc "error" msg :test #'string=))))
	    (if err
		(progn
		  (message "LSP error: ~A"
			   (cdr (assoc "message" err :test #'string=)))
		  (funcall cb nil))
	      (funcall cb (cdr (assoc "result" msg :test #'string=))))))))
     ;; サーバーからの通知
     ((and method (string= method "textDocument/publishDiagnostics"))
      (let* ((diags (lsp-extract-diagnostics msg))
	     (uri (getf (car diags) :uri)))
	(when uri
	  (setf (gethash uri (lsp-client-diagnostics client)) diags))
	(message "LSP Diagnostics: ~D issue(s) reported" (length diags))))
     (t nil))
    nil))

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
	 (outbuf (create-new-buffer " *lsp server output*"))
	 (client (make-lsp-client :root-path root :command command
				  :server-cmd actual-cmd
				  :output-buffer outbuf
				  :wsl-distro (and is-wsl target-distro)))
	 (proc (make-process actual-cmd
			     ;; **`:output' は省略できない。** 省略すると
			     ;; make-process は「今のバッファ」に結び付き、
			     ;; (1) フィルタを張る前に子が書いた分がそのまま
			     ;; 編集中のファイルへ挿入され、(2) そのバッファでは
			     ;; もう 1 つプロセスを起こせなくなる
			     ;; (`buffer_has_process')。2 つ目の症状は
			     ;; 「最初の 1 つ以外は起動できない」形で出る。
			     :output outbuf
			     ;; **生バイトで受ける。** Content-Length はバイト数
			     ;; なので、文字列へ復号した後では本文を切り出せない
			     ;; (改行の変換は下の `:eol-code' で止める)。
			     :incode *encoding-binary*
			     ;; **BOM 無しの UTF-8 で送る。** `*encoding-utf8*'
			     ;; は `:signature t' なので、送るたびに先頭へ
			     ;; BOM (EF BB BF) が付く。サーバーはそれを
			     ;; ヘッダの一部として読むので、最初の 1 文字が
			     ;; 化けて**どのメッセージも解釈されない**
			     ;; (initialize の応答が返らない、の正体)。
			     :outcode *encoding-utf8n*
			     ;; **改行変換を止める。** `:eol-code' の既定は
			     ;; プラットフォーム任せで、Windows は CRLF。
			     ;; CRLF 変換は受信した `\r' を**全部**落とすので、
			     ;; Content-Length ヘッダの区切りが `\n\n' に化け、
			     ;; パーサがいつまでも本文を待つ。`*eol-lf*' は
			     ;; 変換なしの意味 (`eol_noconv')。
			     :eol-code *eol-lf*
			     :exec-directory root
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
    (set-process-sentinel
     proc
     #'(lambda (p) (lsp--server-exited client)))
    ;; initialize 送信
    (lsp-send-request client "initialize" (lsp-make-initialize-params root)
		      #'(lambda (res)
			  (lsp-send-notification client "initialized" '())))
    (push client *lsp-clients*)
    client))

(defun lsp--server-exited (client)
  "サーバーが終わったときの後片付け。"
  (setq *lsp-clients* (delete client *lsp-clients*))
  (let ((buf (lsp-client-output-buffer client)))
    (when (and buf (not (deleted-buffer-p buf)))
      (ignore-errors (delete-buffer buf))))
  (unless (lsp-client-stopping client)
    (message "LSP server exited: ~A" (lsp-client-server-cmd client)))
  nil)

(defun lsp-stop-server (&optional client)
  "言語サーバープロセスを停止する。"
  (let ((c (or client (car *lsp-clients*))))
    (when c
      (setf (lsp-client-stopping c) t)
      (ignore-errors (lsp-send-request c "shutdown" nil))
      (ignore-errors (lsp-send-notification c "exit" nil))
      (let ((proc (lsp-client-process c)))
	(when (and proc (eq (process-status proc) :run))
	  ;; **`shutdown'/`exit' を送るだけではプロセスは残る。** 応答しない
	  ;; サーバー (起動に失敗した、既に死んでいる) を待つ相手はいないので、
	  ;; 少しだけ待ってから殺す。待たずに殺すと、行儀の良いサーバーが
	  ;; `shutdown' を処理する前に消える。
	  (let ((start (get-internal-real-time)))
	    (while (and (eq (process-status proc) :run)
			(< (- (get-internal-real-time) start) 1000))
	      (sleep-for 0.05)))
	  (when (eq (process-status proc) :run)
	    (ignore-errors (kill-process proc)))))
      (setq *lsp-clients* (delete c *lsp-clients*))
      (let ((buf (lsp-client-output-buffer c)))
	(when (and buf (not (deleted-buffer-p buf)))
	  (ignore-errors (delete-buffer buf)))))
    nil))


;;; ------------------------------------------------------------------
;;; 6. ドキュメント同期 (didOpen / didChange / didSave / didClose)

(defun lsp-notify-open (client uri language-id text)
  "textDocument/didOpen を送り、版番号を 1 から数え始める。"
  (setf (gethash uri (lsp-client-versions client)) 1)
  (lsp-send-notification client "textDocument/didOpen"
			 (lsp-make-did-open-params uri language-id 1 text)))

(defun lsp-notify-change (client uri text)
  "textDocument/didChange を送る。版番号は送るたびに 1 つ増える。"
  (let ((version (1+ (or (gethash uri (lsp-client-versions client)) 0))))
    (setf (gethash uri (lsp-client-versions client)) version)
    (lsp-send-notification client "textDocument/didChange"
			   (lsp-make-did-change-params uri version text))))

(defun lsp-notify-save (client uri)
  "textDocument/didSave を送る。"
  (lsp-send-notification client "textDocument/didSave"
			 (lsp-make-did-save-params uri)))

(defun lsp-notify-close (client uri)
  "textDocument/didClose を送り、版番号を忘れる。"
  (remhash uri (lsp-client-versions client))
  (lsp-send-notification client "textDocument/didClose"
			 (lsp-make-did-close-params uri)))

(defun lsp-request-definition (client uri line col callback)
  "textDocument/definition を送る。CALLBACK は位置 (無ければ nil) を受ける。"
  (lsp-send-request client "textDocument/definition"
		    `(("textDocument" . (("uri" . ,uri)))
		      ("position" . (("line" . ,line) ("character" . ,col))))
		    #'(lambda (res)
			(funcall callback (lsp-parse-location res)))))


;;; ------------------------------------------------------------------
;;; 7. バッファとの連動 & 対話コマンド

(defvar-local *lsp-mode* nil)
(defvar *lsp-mode-hook* nil)
(defvar *lsp-mode-map* nil)

(defvar *lsp-idle-delay* 0.5
  "打鍵が止まってから didChange を送るまでの秒数。")

;;; **`defvar' を使ってはいけない。** defvar はシンボルを special にし、
;;; special な変数はバッファローカルになれない (`lisp/flymake.l' の
;;; `flymake-checking' と同じ理由)。
(setq-default lsp-client nil)
(make-variable-buffer-local 'lsp-client)

(setq-default lsp-document-uri nil)
(make-variable-buffer-local 'lsp-document-uri)

(setq-default lsp-last-synced nil)
(make-variable-buffer-local 'lsp-last-synced)

(unless *lsp-mode-map*
  (setq *lsp-mode-map* (make-sparse-keymap))
  (define-key *lsp-mode-map* '(#\M-.) 'lsp-find-definition))

(defun lsp-mode-name ()
  "このバッファのメジャーモード名。"
  (symbol-name (or buffer-mode 'fundamental-mode)))

(defun lsp-buffer-language-id ()
  "このバッファをサーバーへ伝える languageId。"
  (or (cdr (assoc (lsp-mode-name) *lsp-language-ids* :test #'string=))
      "plaintext"))

(defun lsp-buffer-uri ()
  "このバッファのファイルの URI。ファイルを訪ねていなければ nil。"
  (let ((file (get-buffer-file-name)))
    (and file (lsp-path-to-uri (namestring file)))))

(defun lsp-connect ()
  "このバッファの言語サーバーにつなぎ、didOpen を送る。"
  (let ((server (cdr (assoc (lsp-mode-name) *lsp-default-servers* :test #'string=)))
	(uri (lsp-buffer-uri)))
    (cond
     ((null server)
      (message "No language server configured for ~A" (lsp-mode-name))
      nil)
     ((null uri)
      (message "This buffer is not visiting a file.")
      nil)
     (t
      (let ((client (or (find server *lsp-clients*
			       :key #'lsp-client-command :test #'string=)
			(lsp-start-server server))))
	(setq lsp-client client)
	(setq lsp-document-uri uri)
	(setq lsp-last-synced (buffer-modified-count))
	(lsp-notify-open client uri (lsp-buffer-language-id)
			 (buffer-substring (point-min) (point-max)))
	t)))))

(defun lsp-disconnect ()
  "didClose を送って、このバッファとサーバーの縁を切る。

**プロセスは止めない。** 同じサーバーを別のバッファも使っていることがあり、
こちらから切っただけで相手を落とすのは行き過ぎである。落とすのは
`lsp-stop-server' の仕事。"
  (when (and lsp-client lsp-document-uri)
    (ignore-errors (lsp-notify-close lsp-client lsp-document-uri)))
  (setq lsp-client nil)
  (setq lsp-document-uri nil)
  (setq lsp-last-synced nil)
  nil)

(defun lsp-sync-buffer ()
  "変わっていれば didChange を送る。タイマから呼ばれる。"
  (when (and *lsp-mode* lsp-client lsp-document-uri)
    (let ((tick (buffer-modified-count)))
      (unless (eql tick lsp-last-synced)
	(setq lsp-last-synced tick)
	(ignore-errors
	  (lsp-notify-change lsp-client lsp-document-uri
			     (buffer-substring (point-min) (point-max)))))))
  nil)

(defun lsp-schedule-sync ()
  "`*post-command-hook*' から、1 回だけのタイマを張り直す。

**打鍵ごとに送るのではない。** 張り直すので、入力が続いている間は発火せず、
止まってから `*lsp-idle-delay*' 秒後に 1 回だけ走る (`lisp/flymake.l' の
`flymake-schedule' と同じ形)。"
  (when (and *lsp-mode* lsp-client)
    (stop-timer 'lsp-sync-buffer)
    (start-timer *lsp-idle-delay* 'lsp-sync-buffer t))
  nil)

(add-hook '*post-command-hook* 'lsp-schedule-sync)

(defun lsp-after-save ()
  "`*after-save-buffer-hook*' から didChange と didSave を送る。"
  (when (and *lsp-mode* lsp-client lsp-document-uri)
    (ignore-errors
      (lsp-notify-change lsp-client lsp-document-uri
			 (buffer-substring (point-min) (point-max)))
      (lsp-notify-save lsp-client lsp-document-uri)))
  nil)

(add-hook '*after-save-buffer-hook* 'lsp-after-save)

(defun lsp-find-definition ()
  "カーソル位置のシンボルの定義位置へジャンプする。"
  (interactive)
  (let ((client (or lsp-client (car *lsp-clients*)))
	(uri (or lsp-document-uri (lsp-buffer-uri))))
    (unless client
      (message "No active LSP client.")
      (return-from lsp-find-definition nil))
    (unless uri
      (message "Buffer has no associated file.")
      (return-from lsp-find-definition nil))
    (let ((distro (lsp-client-wsl-distro client)))
      (lsp-request-definition
       client uri (1- (current-line-number)) (current-column)
       #'(lambda (loc)
	   (cond
	    ((null loc)
	     (message "Definition not found."))
	    (t
	     (find-file (lsp-uri-to-path (getf loc :uri) distro))
	     (goto-line (1+ (getf loc :line)))
	     (goto-column (getf loc :col))))))
      t)))

(defun lsp-mode (&optional (arg nil sv))
  "LSP マイナーモードのトグル。"
  (interactive "p")
  (toggle-mode '*lsp-mode* arg sv)
  (if *lsp-mode*
      (progn
	(set-minor-mode-map *lsp-mode-map*)
	(ignore-errors (lsp-connect))
	(run-hooks '*lsp-mode-hook*))
    (progn
      (ignore-errors (lsp-disconnect))
      (unset-minor-mode-map *lsp-mode-map*)))
  *lsp-mode*)
