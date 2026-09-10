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
