;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for WSL integration (lisp/wsl.l)
;;;

(require "wsl")

(use-package "editor")

;;; ------------------------------------------------------------------
;;; 1. パス相互変換 (wsl-path-to-windows / windows-path-to-wsl)

(deftest wsl-path-to-windows-drive ()
  "Linux の /mnt/<drive>/... を Windows ドライブパスに変換する"
  (list (wsl-path-to-windows "/mnt/c/Users/user/file.txt")
        (wsl-path-to-windows "/mnt/d/work/project")
        (wsl-path-to-windows "/mnt/c/")
        (wsl-path-to-windows "/mnt/c"))
  => ("C:/Users/user/file.txt" "D:/work/project" "C:/" "C:/"))

(deftest wsl-path-to-windows-unc ()
  "Linux の /home/... などを WSL UNC パスに変換する"
  (let ((*wsl-distribution* "Ubuntu")
        (*wsl-unc-prefix* "\\\\wsl.localhost"))
    (list (wsl-path-to-windows "/home/user/project")
          (wsl-path-to-windows "/etc/hosts")
          (wsl-path-to-windows "/home/user" "Debian")
          (let ((*wsl-unc-prefix* "\\\\wsl$"))
            (wsl-path-to-windows "/home/user" "Ubuntu"))))
  => ("\\\\wsl.localhost\\Ubuntu\\home\\user\\project"
      "\\\\wsl.localhost\\Ubuntu\\etc\\hosts"
      "\\\\wsl.localhost\\Debian\\home\\user"
      "\\\\wsl$\\Ubuntu\\home\\user"))

(deftest wsl-path-to-windows-passthrough ()
  "既に Windows パスになっている場合はそのまま返す"
  (list (wsl-path-to-windows "C:/Users/user")
        (wsl-path-to-windows "\\\\wsl.localhost\\Ubuntu\\home\\user"))
  => ("C:/Users/user" "\\\\wsl.localhost\\Ubuntu\\home\\user"))

(deftest windows-path-to-wsl-drive ()
  "Windows ドライブパス (C:/...) を Linux の /mnt/c/... に変換する"
  (list (windows-path-to-wsl "C:/Users/user/file.txt")
        (windows-path-to-wsl "c:\\Users\\user\\file.txt")
        (windows-path-to-wsl "D:/work")
        (windows-path-to-wsl "d:\\")
        (windows-path-to-wsl "D:"))
  => ("/mnt/c/Users/user/file.txt"
      "/mnt/c/Users/user/file.txt"
      "/mnt/d/work"
      "/mnt/d/"
      "/mnt/d"))

(deftest windows-path-to-wsl-unc ()
  "WSL UNC パス (\\\\wsl.localhost\\... や \\\\wsl$\\...) を Linux パスに変換する"
  (list (windows-path-to-wsl "\\\\wsl.localhost\\Ubuntu\\home\\user\\project")
        (windows-path-to-wsl "\\\\wsl.localhost\\Ubuntu")
        (windows-path-to-wsl "\\\\wsl$\\Debian\\etc\\nginx")
        (windows-path-to-wsl "//wsl.localhost/Ubuntu/home/user")
        (windows-path-to-wsl "//wsl$/Debian/etc/nginx"))
  => ("/home/user/project"
      "/"
      "/etc/nginx"
      "/home/user"
      "/etc/nginx"))

(deftest windows-path-to-wsl-passthrough ()
  "既に Linux パスになっている場合はそのまま返す"
  (list (windows-path-to-wsl "/mnt/c/Users/user")
        (windows-path-to-wsl "/home/user"))
  => ("/mnt/c/Users/user" "/home/user"))

;;; ------------------------------------------------------------------
;;; 2. ディストリビューション名パース (wsl-parse-distributions)

(deftest wsl-parse-distributions-plain ()
  "改行区切りのディストリビューション一覧をパースする"
  (wsl-parse-distributions "Ubuntu\nDebian\nkali-linux\n")
  => ("Ubuntu" "Debian" "kali-linux"))

(deftest wsl-parse-distributions-crlf-and-whitespace ()
  "CRLF や余分な空白・空行を適切に処理する"
  (wsl-parse-distributions "  Ubuntu  \r\n\r\nDebian\r\n  \r\n")
  => ("Ubuntu" "Debian"))

(deftest wsl-parse-distributions-utf16le-nulls ()
  "wsl.exe の UTF-16LE 出力に含まれる NUL 文字を除去してパースする"
  (wsl-parse-distributions "U\0b\0u\0n\0t\0u\0\r\0\n\0D\0e\0b\0i\0a\0n\0\r\0\n\0")
  => ("Ubuntu" "Debian"))

;;; ------------------------------------------------------------------
;;; 3. クリップボード連携 / OSC 52

(deftest wsl-osc-52-sequence-generation ()
  "OSC 52 エスケープシーケンスを生成できる"
  (string= (wsl-osc-52-sequence "hello")
           (format nil "~C]52;c;aGVsbG8=~C" (code-char #x1b) (code-char 7)))
  => t)

(deftest wsl-clipboard-round-trip ()
  "wsl-copy-string と wsl-paste-string でクリップボード経由の読み書きができる"
  (let ((orig (get-clipboard-data)))
    (unwind-protect
        (progn
          (wsl-copy-string "wsl-test-string")
          (wsl-paste-string))
      (when orig
        (copy-to-clipboard orig))))
  => "wsl-test-string")

;;; ------------------------------------------------------------------
;;; 4. コマンド定義とキーマップ

(deftest wsl-commands-and-mode-exist ()
  "wsl, wsl-shell コマンドおよび wsl-mode が定義されている"
  (list (fboundp 'wsl)
        (fboundp 'wsl-shell)
        (fboundp 'wsl-mode)
        (boundp '*wsl-distribution*)
        (boundp '*wsl-unc-prefix*))
  => (t t t t t))
