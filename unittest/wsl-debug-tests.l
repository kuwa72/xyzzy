;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/wsl-debug.l のテスト。
;;;
;;; WSL 上のコーディングエージェントから Windows 上の xyzzy を操作する
;;; TCP デバッグサーバのプロトコル純粋関数をテストする。ソケットを開かないので
;;; Wine / 実機いずれでも動く。

(require "wsl-debug")

(deftest wsl-debug-single-line-removes-newlines ()
  "改行・復帰を空白に畳み込むこと"
  (ed::wsl-debug-single-line (concat "a" (string #\Newline) "b" (string #\Return) "c"))
  => "a b c")

(deftest wsl-debug-format-ok-prefix ()
  "+OK 応答になること"
  (ed::wsl-debug-format-ok "3")
  => "+OK 3")

(deftest wsl-debug-format-ok-is-single-line ()
  "値に改行が混じっても1行になること"
  (ed::wsl-debug-format-ok (concat "a" (string #\Newline) "b"))
  => "+OK a b")

(deftest wsl-debug-format-error-prefix ()
  "-ERR 応答になること"
  (ed::wsl-debug-format-error "boom")
  => "-ERR boom")

(deftest wsl-debug-check-auth-accepts-token ()
  "正しいトークンを受けること"
  (let ((ed::*wsl-debug-token* "s3cr3t"))
    (ed::wsl-debug-check-auth "AUTH s3cr3t"))
  => t)

(deftest wsl-debug-check-auth-rejects-wrong-token ()
  "誤ったトークンを拒否すること"
  (let ((ed::*wsl-debug-token* "s3cr3t"))
    (ed::wsl-debug-check-auth "AUTH wrong"))
  => nil)

(deftest wsl-debug-check-auth-allows-nil-token ()
  "トークン未設定時は認証を要求しないこと"
  (let ((ed::*wsl-debug-token* nil))
    (ed::wsl-debug-check-auth "AUTH anything"))
  => t)

(deftest wsl-debug-eval-plus ()
  "四則演算を評価して +OK で返すこと"
  (ed::wsl-debug-eval-text "(+ 1 2)")
  => "+OK 3")

(deftest wsl-debug-eval-error-is-err ()
  "未定義変数は -ERR で返すこと (サーバは落ちない)"
  (let ((s (ed::wsl-debug-eval-text "(+ 1 *this-var-is-unbound*)")))
    (and (stringp s) (string-match "^-ERR " s) t))
  => t)

(deftest wsl-debug-generate-token-is-high-entropy ()
  "生成トークンは推測困難な十分な長さを持つこと"
  (let ((ed::*wsl-debug-token* nil))
    (let ((tok (ed::wsl-debug-generate-token)))
      (and (stringp tok)
           (>= (length tok) 32)
           (equal tok ed::*wsl-debug-token*))))
  => t)

(deftest wsl-debug-generate-token-differs-each-call ()
  "連続する 2 回の生成で別のトークンになること"
  (let ((ed::*wsl-debug-token* nil))
    (let ((a (ed::wsl-debug-generate-token))
          (b (ed::wsl-debug-generate-token)))
      (not (equal a b))))
  => t)
