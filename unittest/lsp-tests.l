;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for LSP client (lisp/lsp.l)
;;;

(require "lsp")

(use-package "editor")

;;; ------------------------------------------------------------------
;;; 1. JSON エンコード / デコード

(deftest json-encode-primitives ()
  "プリミティブ値の JSON エンコード"
  (list (json-encode 123)
        (json-encode -45)
        (json-encode "hello")
        (json-encode t)
        (json-encode :false)
        (json-encode :null))
  => ("123" "-45" "\"hello\"" "true" "false" "null"))

(deftest json-encode-structures ()
  "配列とオブジェクトの JSON エンコード"
  (list (json-encode '(1 2 3))
        (json-encode '((:name . "xyzzy") (:version . 1))))
  => ("[1, 2, 3]" "{\"name\": \"xyzzy\", \"version\": 1}"))

(deftest json-encode-nested-objects ()
  "入れ子のオブジェクトと、オブジェクト 1 個だけの配列の JSON エンコード"
  ;; 値がオブジェクトのリスト (didChange の contentChanges がこの形) を
  ;; 「キーと値の組」と取り違えると、キー側を文字列化しようとして
  ;; 型エラーになる。
  (list (json-encode '(("textDocument" . (("uri" . "file:///x")))))
        (json-encode '(("contentChanges" . ((("text" . "hello"))))))
        (json-encode '(("a" . (1 2 3)))))
  => ("{\"textDocument\": {\"uri\": \"file:///x\"}}"
      "{\"contentChanges\": [{\"text\": \"hello\"}]}"
      "{\"a\": [1, 2, 3]}"))

(deftest json-escape-string-special-chars ()
  "引用符・バックスラッシュ・改行を逃がすこと (未定義 write-string の回帰)"
  ;; json-escape-string は editor 内部関数のため公開 API の json-encode 越しに検証する。
  (list (json-encode "\"")
        (json-encode "\\")
        (json-encode (string #\LFD)))
  => ("\"\\\"\"" "\"\\\\\"" "\"\\n\""))

(deftest json-decode-primitives ()
  "プリミティブ値の JSON デコード"
  (list (json-decode "123")
        (json-decode "\"hello\"")
        (json-decode "true")
        (json-decode "false")
        (json-decode "null"))
  => (123 "hello" t :false :null))

(deftest json-decode-structures ()
  "配列とオブジェクトの JSON デコード"
  (list (json-decode "[1, 2, 3]")
        (cdr (assoc "name" (json-decode "{\"name\": \"xyzzy\", \"version\": 1}") :test #'string=)))
  => ((1 2 3) "xyzzy"))

;;; ------------------------------------------------------------------
;;; 2. Content-Length プロトコルパース / 生成

(deftest lsp-make-message-test ()
  "Content-Length ヘッダ付きメッセージの生成"
  (let* ((body "{\"jsonrpc\":\"2.0\"}")
         (msg (lsp-make-message body)))
    (string-match "^Content-Length: \\([0-9]+\\)\r\n\r\n\\(.*\\)$" msg)
    (list (parse-integer (match-string 1)) (match-string 2)))
  => (17 "{\"jsonrpc\":\"2.0\"}"))

(deftest lsp-parse-messages-test ()
  "ヘッダ付きメッセージストリームのパース"
  (let* ((payload "{\"jsonrpc\":\"2.0\",\"method\":\"test\"}")
         (stream (format nil "Content-Length: ~D\r\n\r\n~A" (length payload) payload)))
    (multiple-value-bind (msgs rem) (lsp-parse-messages stream)
      (list (length msgs) (cdr (assoc "method" (car msgs) :test #'string=)) rem)))
  => (1 "test" ""))

(deftest lsp-parse-messages-partial ()
  "メッセージが途中で切れている場合のバッファリング"
  (let ((partial "Content-Length: 50\r\n\r\n{\"jsonrpc\":"))
    (multiple-value-bind (msgs rem) (lsp-parse-messages partial)
      (list msgs rem)))
  => (nil "Content-Length: 50\r\n\r\n{\"jsonrpc\":"))

(deftest lsp-parse-messages-lf-only-header ()
  "ヘッダの区切りが LF だけでもメッセージを読めること"
  ;; **Windows ではこれが実際に起きる。** `make-process' の `:eol-code' は
  ;; 既定が CRLF で、受信した `\r' を全部落とすため、ヘッダが `\n\n' で
  ;; 届く。CRLF 決め打ちのままだと initialize の応答が永遠に来ない。
  (let* ((payload "{\"jsonrpc\":\"2.0\",\"method\":\"test\"}")
         (stream (format nil "Content-Length: ~D\n\n~A" (length payload) payload)))
    (multiple-value-bind (msgs rem) (lsp-parse-messages stream)
      (list (length msgs) (cdr (assoc "method" (car msgs) :test #'string=)) rem)))
  => (1 "test" ""))

;;; ------------------------------------------------------------------
;;; 3. ライフサイクル & ドキュメントメッセージ構築

(deftest lsp-initialize-params-test ()
  "initialize リクエストのパラメータ構築"
  (let ((params (lsp-make-initialize-params "C:/project" 1234)))
    (list (cdr (assoc "rootPath" params :test #'string=))
          (cdr (assoc "processId" params :test #'string=))))
  => ("C:/project" 1234))

(deftest lsp-did-open-params-test ()
  "didOpen 通知のパラメータ構築"
  (let* ((params (lsp-make-did-open-params "file:///test.c" "c" 1 "int main() {}"))
         (doc (cdr (assoc "textDocument" params :test #'string=))))
    (list (cdr (assoc "uri" doc :test #'string=))
          (cdr (assoc "languageId" doc :test #'string=))
          (cdr (assoc "version" doc :test #'string=))))
  => ("file:///test.c" "c" 1))

;;; ------------------------------------------------------------------
;;; 4. 診断 (Diagnostics) & 定義位置パース

(deftest lsp-parse-diagnostics-test ()
  "publishDiagnostics 通知のパース"
  (let* ((diag-json "{\"uri\":\"file:///test.c\",\"diagnostics\":[{\"range\":{\"start\":{\"line\":10,\"character\":5},\"end\":{\"line\":10,\"character\":12}},\"severity\":1,\"message\":\"Syntax error\"}]}")
         (parsed (json-decode diag-json))
         (diags (lsp-extract-diagnostics parsed)))
    (list (length diags)
          (getf (car diags) :line)
          (getf (car diags) :message)))
  => (1 10 "Syntax error"))

(deftest lsp-parse-definition-location-test ()
  "definition レスポンスの位置パース"
  (let* ((loc-json "{\"uri\":\"file:///test.h\",\"range\":{\"start\":{\"line\":25,\"character\":4},\"end\":{\"line\":25,\"character\":10}}}")
         (loc (lsp-parse-location (json-decode loc-json))))
    (list (getf loc :uri) (getf loc :line) (getf loc :col)))
  => ("file:///test.h" 25 4))

;;; ------------------------------------------------------------------
;;; 5. WSL 透過連携 (Issue #345)

(deftest lsp-path-to-uri-wsl-test ()
  "WSL UNC パスおよび Windows パスの URI 変換"
  (list (lsp-path-to-uri "\\\\wsl.localhost\\Ubuntu\\home\\user\\project\\main.rs")
        (lsp-path-to-uri "//wsl.localhost/Ubuntu/home/user/project/main.rs")
        (lsp-path-to-uri "C:/project/test.c"))
  => ("file:///home/user/project/main.rs"
      "file:///home/user/project/main.rs"
      "file:///C:/project/test.c"))

(deftest lsp-uri-to-path-wsl-test ()
  "URI から WSL UNC パスおよび Windows パスへの逆変換"
  (let ((*wsl-unc-prefix* "\\\\wsl.localhost"))
    (list (lsp-uri-to-path "file:///home/user/project/main.rs" "Ubuntu")
          (lsp-uri-to-path "file:///mnt/c/project/test.c")
          (lsp-uri-to-path "file:///C:/project/test.c")))
  => ("\\\\wsl.localhost\\Ubuntu\\home\\user\\project\\main.rs"
      "C:/project/test.c"
      "C:/project/test.c"))

(deftest lsp-wsl-server-command-test ()
  "WSL 言語サーバー起動コマンドラインの構築"
  (lsp-wsl-server-command "rust-analyzer" "Ubuntu")
  => "wsl.exe -d Ubuntu -- rust-analyzer")

(deftest lsp-make-initialize-params-wsl-test ()
  "WSL パスに対する initialize パラメータの構築"
  (let* ((params (lsp-make-initialize-params "\\\\wsl.localhost\\Ubuntu\\home\\user\\project" 1234))
         (root-uri (cdr (assoc "rootUri" params :test #'string=))))
    root-uri)
  => "file:///home/user/project")

;;; ------------------------------------------------------------------
;;; 6. LSP サーバーインストーラ

(deftest lsp-server-installers-defined-test ()
  "*lsp-server-installers* が定義されている"
  (and (boundp '*lsp-server-installers*)
       (listp *lsp-server-installers*)
       (> (length *lsp-server-installers*) 0))
  => t)

(deftest lsp-server-installers-has-expected-servers ()
  "*lsp-server-installers* に主要サーバーが登録されている"
  (mapcar #'car *lsp-server-installers*)
  => ("clangd" "pylsp" "gopls" "rust-analyzer"
      "typescript-language-server" "yaml-language-server"
      "json-language-server"))

(deftest lsp-server-installers-pylsp-wsl-test ()
  "pylsp の WSL インストーラは apt を使う (PEP 668 の system pip を避ける)"
  (cdr (assoc :wsl (cdr (assoc "pylsp" *lsp-server-installers* :test #'string=))))
  => ("sudo -n apt install -y python3-pylsp" "apt"))

(deftest lsp-server-installed-p-true-test ()
  "存在するコマンドに対して t を返す (Windows: cmd / POSIX: sh)"
  (not (null (or (lsp-server-installed-p "cmd")
                (lsp-server-installed-p "sh"))))
  => t)

(deftest lsp-install-server-wsl-verifies-on-wsl-side ()
  "WSL 側へ入れた直後の確認は WSL 側で行う。

`lsp-install-server' は WSL プロジェクトでは wsl.exe 越しに WSL 側へ入れるのに、
入れた後の確認だけ Windows 側 (where) を見ていた。WSL 側にしかコマンドが無いと
「installed, but ... is not on PATH」と誤って報告し、*lsp-install* バッファを
開いてしまう。"
  (let ((wsl-installed nil)
        (windows-probe nil)
        (popped nil)
        (ran nil)
        (orig (mapcar #'(lambda (name) (cons name (symbol-function name)))
                      '(wsl-path-p wsl-current-distro ed::lsp--wsl-installed-p
                        lsp-server-installed-p call-process pop-to-buffer))))
    (unwind-protect
        (progn
          (setf (symbol-function 'wsl-path-p) #'(lambda (path) t))
          (setf (symbol-function 'wsl-current-distro) #'(lambda (&optional dir) "Ubuntu"))
          ;; WSL 側の確認だけが「入った」と言う。Windows 側には無い。
          ;; 前提ツール (clangd の WSL 版は sudo) は入っている前提にする。
          (setf (symbol-function 'ed::lsp--wsl-installed-p)
                #'(lambda (server &optional distro)
                    (if (string= server "clangd") wsl-installed t)))
          (setf (symbol-function 'lsp-server-installed-p)
                #'(lambda (server) (setq windows-probe t) nil))
          (setf (symbol-function 'call-process)
                #'(lambda (command &rest options)
                    (setq ran command)
                    (setq wsl-installed t)
                    0))
          (setf (symbol-function 'pop-to-buffer)
                #'(lambda (&rest args) (setq popped t)))
          (lsp-install-server "clangd")
          (values ran (null windows-probe) (null popped)))
      (dolist (pair orig)
        (setf (symbol-function (car pair)) (cdr pair)))))
  => "wsl.exe -d Ubuntu -- sudo apt install -y clangd"
  => t
  => t)

(deftest lsp-install-server-local-verifies-with-local-probe ()
  "WSL でないときは従来どおりローカル側で確認する。

上のテストの裏返し。WSL 側の確認に寄せ過ぎて、ローカルのインストールまで
wsl.exe 越しに確かめに行かないこと。"
  (let ((local-installed nil)
        (wsl-probe nil)
        (popped nil)
        (ran nil)
        (orig (mapcar #'(lambda (name) (cons name (symbol-function name)))
                      '(wsl-path-p wsl-current-distro ed::lsp--wsl-installed-p
                        lsp-server-installed-p call-process pop-to-buffer))))
    (unwind-protect
        (progn
          (setf (symbol-function 'wsl-path-p) #'(lambda (path) nil))
          (setf (symbol-function 'wsl-current-distro) #'(lambda (&optional dir) "Ubuntu"))
          (setf (symbol-function 'ed::lsp--wsl-installed-p)
                #'(lambda (server &optional distro) (setq wsl-probe t) nil))
          (setf (symbol-function 'lsp-server-installed-p)
                #'(lambda (server) local-installed))
          (setf (symbol-function 'call-process)
                #'(lambda (command &rest options)
                    (setq ran command)
                    (setq local-installed t)
                    0))
          (setf (symbol-function 'pop-to-buffer)
                #'(lambda (&rest args) (setq popped t)))
          (lsp-install-server "clangd")
          (values ran (null wsl-probe) (null popped)))
      (dolist (pair orig)
        (setf (symbol-function (car pair)) (cdr pair)))))
  => "winget install LLVM.LLVM"
  => t
  => t)

;;; ------------------------------------------------------------------
;;; 7. lsp-mode トグル (prefix-numeric-value 未定義の回帰)

(deftest lsp-mode-toggle-test ()
  "(lsp-mode t) で有効化できる (Emacs流 prefix-numeric-value を使わない)"
  (unwind-protect
      (progn
        (lsp-mode -1)
        (lsp-mode t)
        *lsp-mode*)
    (lsp-mode -1))
  => t)
