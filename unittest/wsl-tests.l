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

(deftest wsl-list-distributions-callable ()
  "wsl-list-distributions が未定義関数エラー (generate-new-buffer 等) を起こさず呼べる"
  (let ((res (ignore-errors (wsl-list-distributions))))
    (or (null res) (listp res)))
  => t)

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
  "wsl コマンドおよび wsl-mode が定義されている"
  (list (fboundp 'wsl)
        (fboundp 'wsl-mode)
        (boundp '*wsl-distribution*)
        (boundp '*wsl-unc-prefix*))
  => (t t t t))

(deftest wsl-shell-is-removed ()
  "wsl-shell は削除済み (#390)。M-x wsl に統合された"
  (fboundp 'wsl-shell)
  => nil)

;;; ------------------------------------------------------------------
;;; 5. WSL プロジェクト判定・ディストリビューション抽出 (Issue #343)

(deftest wsl-extract-distro-test ()
  "WSL UNC パスからディストリビューション名を抽出する"
  (list (wsl-extract-distro "\\\\wsl.localhost\\Ubuntu\\home\\user")
        (wsl-extract-distro "//wsl.localhost/Debian/etc")
        (wsl-extract-distro "\\\\wsl$\\arch\\home")
        (wsl-extract-distro "//wsl$/kali-linux/opt")
        (wsl-extract-distro "C:/Users/user"))
  => ("Ubuntu" "Debian" "arch" "kali-linux" nil))

(deftest wsl-project-p-test ()
  "パスが WSL プロジェクト内かどうかを判定する"
  (list (wsl-project-p "\\\\wsl.localhost\\Ubuntu\\home\\user")
        (wsl-project-p "//wsl$/Debian/var")
        (wsl-project-p "C:/Users/user/project"))
  => (t t nil))

;;; ------------------------------------------------------------------
;;; 6. WSL コマンドライン構築とコンパイル・git連携 (Issue #343)

(deftest wsl-build-command-line-test ()
  "WSL 実行コマンドラインを正しく構築する"
  (list (wsl-build-command-line "make" "Ubuntu" "/home/user/proj")
        (wsl-build-command-line "cargo build" nil "/mnt/c/work"))
  => ("wsl.exe -d Ubuntu --cd /home/user/proj -- sh -c \"make\""
      "wsl.exe --cd /mnt/c/work -- sh -c \"cargo build\""))

(deftest wsl-git-command-line-test ()
  "WSL 上で git を実行するコマンドラインを構築する"
  (wsl-git-command-line "status --short" "Ubuntu" "/home/user/proj")
  => "wsl.exe -d Ubuntu --cd /home/user/proj -- sh -c \"git status --short\"")

(deftest wsl-translate-log-paths-test ()
  "コンパイルログのエラー行の Linux パスを Windows パスに変換する"
  (let ((*wsl-unc-prefix* "\\\\wsl.localhost"))
    (list (wsl-translate-log-paths "/home/user/main.c:10:5: error: syntax error" "Ubuntu")
          (wsl-translate-log-paths "/mnt/c/Users/user/proj/test.c(20): warning C4000" "Ubuntu")
          (wsl-translate-log-paths "make[1]: Entering directory '/home/user/proj'" "Ubuntu")
          (wsl-translate-log-paths "Building target all" "Ubuntu")))
  => ("\\\\wsl.localhost\\Ubuntu\\home\\user\\main.c:10:5: error: syntax error"
      "C:/Users/user/proj/test.c(20): warning C4000"
      "make[1]: Entering directory '\\\\wsl.localhost\\Ubuntu\\home\\user\\proj'"
      "Building target all"))

;;; ------------------------------------------------------------------
;;; WSL ディレクトリオープン (Issue #391)

(defun wslt-make-temp-dir ()
  "テスト用に実在する一時ディレクトリを返す ( obligation: 実在する唯一の手段)。"
  (let* ((root (directory-namestring (make-temp-file-name)))
         (dir (merge-pathnames "wslt-opendir/" root)))
    (create-directory dir)
    dir))

(defun wslt-cleanup (dir)
  (when (file-directory-p dir)
    (dolist (f (directory dir :absolute t))
      (ignore-errors
       (if (file-directory-p f)
           (delete-directory f)
         (delete-file f))))
    (ignore-errors (delete-directory dir))))

(deftest wsl-open-directory-test ()
  "wsl-open-directory がディストリビューションとパスから Windows UNC パスを設定し、開ける画面にする"
  (let ((dir (wsl-open-directory "Ubuntu" "/home/user/project")))
    (list (and (string-matchp "Ubuntu" dir) t)
          (and (string-matchp "home/user/project" dir) t)
          *wsl-project-distro*
          (stringp (buffer-name (selected-buffer)))))
  => (t t "Ubuntu" t))

(deftest wsl-open-directory-opens-an-interactive-view ()
  "説明テキストの代わりにディレクトリのエントリ一覧を載せたバッファを開く (#391)

次の操作が進められることは (1) 既定ディレクトリが指定パスに写る
(2) バッファにヘッダ以外に実在するエントリが並ぶ、の 2 点で見る
(既定ディレクトリが動けば C-x C-f が同じ場所から始まり、並んだ名前は
そのまま find-file に渡せる)。静的な説明文字列は載せない。

**POSIX では (1) を期待しない。** 既定ディレクトリに指定するのは WSL の
UNC パス (`\\\\\\\\wsl.localhost\\\\...`) で、Windows 上の xyzzy では実在する
ディレクトリだが POSIX では開けない (`set-default-directory' が
\"指定されたパスはディレクトリではありません\" で失敗)。UNC が実在できる
プラットフォームだけ意味がある検査なので、Windows でのみ見る。"
  (let* ((dir (wslt-make-temp-dir))
         (fname "a.txt")
         (hdr (format nil "*WSL: Ubuntu:~A*" (namestring dir)))
         (unixp (featurep :unix)))
    (unwind-protect
        (progn
          (with-open-file (s (merge-pathnames fname dir)
                             :direction :output :if-exists :supersede)
            (princ "x" s))
          (let ((returned (ignore-errors
                            (wsl-open-directory "Ubuntu" (namestring dir)))))
            (list (and returned (string-matchp "wslt-opendir" returned) t)
                  ;; **POSIX では既定ディレクトリは移らない。** 既定ディレ
                  ;; クトリに指定するのは WSL の UNC パス (`\\\\wsl.localhost\\...`)
                  ;; で、Windows では実在するが POSIX では開けない。UNC が
                  ;; 実在できるプラットフォームだけ意味がある検査なので、
                  ;; POSIX では (1) の検査そのものをスキップする (=> 期待値
                  ;; はリテラル評価なので、期待値側で分岐できない)。
                  (or (and unixp t)
                      (string= (default-directory)
                               (concat (map-backslash-to-slash
                                        (namestring dir)) "/")))
                  (save-excursion
                    (set-buffer hdr)
                    (and (string-match fname
                                       (buffer-substring (point-min) (point-max)))
                         t)))))
      (wslt-cleanup dir)))
  => (t t t))

(deftest wsl-find-file-defined ()
  "wsl-find-file コマンドが定義されている"
  (fboundp 'wsl-find-file)
  => t)

(deftest wsl-read-directory-defined ()
  "wsl-read-directory 関数が定義されている"
  (fboundp 'wsl-read-directory)
  => t)

;;; ------------------------------------------------------------------
;;; 7. プロジェクトコンテキスト (レジストリ・ディストロ解決)

(deftest wsl-remember-project-test ()
  "wsl-remember-project がルートとディストロの対応を登録・更新する
末尾の区切りの違いは正規化されて同じルートになる"
  (let ((*wsl-project-list* nil))
    (wsl-remember-project "Ubuntu" "//wsl.localhost/Ubuntu/home/user/proj/")
    (wsl-remember-project "Debian" "//wsl.localhost/Debian/home/user/proj")
    ;; 同じルートを再登録すると上書きされ、リストの先頭に来る
    (wsl-remember-project "Debian" "//wsl.localhost/Ubuntu/home/user/proj")
    (list (length *wsl-project-list*)
          (cdr (assoc "//wsl.localhost/Ubuntu/home/user/proj"
                      *wsl-project-list* :test #'string-equal))
          (cdr (assoc "//wsl.localhost/Debian/home/user/proj"
                      *wsl-project-list* :test #'string-equal))
          (car (car *wsl-project-list*))))
  => (2 "Debian" "Debian" "//wsl.localhost/Ubuntu/home/user/proj"))

(deftest wsl-project-distro-for-test ()
  "wsl-project-distro-for がルート以下のパスからディストロを解決する
ルートの途中まで一致するだけのパス (proj と project2) は別物として扱う"
  (let ((*wsl-project-list*
         (list (cons "//wsl.localhost/Ubuntu/home/user/proj" "Ubuntu")
               (cons "//wsl.localhost/Debian/home/other" "Debian"))))
    (list (wsl-project-distro-for "//wsl.localhost/Ubuntu/home/user/proj")
          (wsl-project-distro-for "//wsl.localhost/Ubuntu/home/user/proj/src")
          (wsl-project-distro-for "//wsl.localhost/Debian/home/other/lib")
          (wsl-project-distro-for "//wsl.localhost/Ubuntu/home/user/project2")
          (wsl-project-distro-for "C:/Users/user/proj")))
  => ("Ubuntu" "Ubuntu" "Debian" nil nil))

(deftest wsl-project-distro-for-longest-match ()
  "重なり合うルートでは最長のものを採用する"
  (let ((*wsl-project-list*
         (list (cons "//wsl.localhost/Ubuntu/home" "Ubuntu")
               (cons "//wsl.localhost/Ubuntu/home/user/proj" "Debian"))))
    (list (wsl-project-distro-for "//wsl.localhost/Ubuntu/home/user/proj/src")
          (wsl-project-distro-for "//wsl.localhost/Ubuntu/home/other")))
  => ("Debian" "Ubuntu"))

(deftest wsl-project-distro-for-backslash ()
  "バックスラッシュ区切りの Windows パスでも解決する"
  (let ((*wsl-project-list*
         (list (cons "//wsl.localhost/Ubuntu/home/user/proj" "Ubuntu"))))
    (wsl-project-distro-for "\\\\wsl.localhost\\Ubuntu\\home\\user\\proj\\src"))
  => "Ubuntu")

(deftest wsl-current-distro-precedence ()
  "ディストロ解決の優先順位: バッファローカル > レジストリ > UNC パス > *wsl-distribution*"
  (let* ((*wsl-project-list*
          (list (cons "//wsl.localhost/Ubuntu/home/user/proj" "Ubuntu")))
         (*wsl-distribution* "GlobalDistro")
         (buf (get-buffer-create " *wsl-ctx-precedence*"))
         (other (get-buffer-create " *wsl-ctx-plain*")))
    (unwind-protect
        (progn
          (save-excursion
            (set-buffer other)
            (setq *wsl-project-distro* nil))
          (save-excursion
            (set-buffer buf)
            (list (wsl-current-distro "//wsl.localhost/Ubuntu/home/user/proj/src")
                  (wsl-current-distro "//wsl.localhost/Debian/var")
                  (wsl-current-distro "C:/Users/user")
                  (progn
                    (setq *wsl-project-distro* "LocalDistro")
                    (wsl-current-distro "C:/Users/user")))))
      (ignore-errors (kill-buffer buf))
      (ignore-errors (kill-buffer other))))
  => ("Ubuntu" "Debian" "GlobalDistro" "LocalDistro"))

(deftest wsl-current-distro-unknown-is-nil ()
  "何もディストロを決められないときは nil を返す (Ubuntu を暗黙に仮定しない)"
  (let ((*wsl-project-list* nil)
        (*wsl-distribution* nil)
        (buf (get-buffer-create " *wsl-ctx-nil*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (setq *wsl-project-distro* nil)
          (wsl-current-distro "C:/Users/user/project"))
      (ignore-errors (kill-buffer buf))))
  => nil)

(deftest wsl-open-directory-keeps-distro-buffer-local ()
  "wsl-open-directory のディストロ設定が他バッファに漏れない
setq-default で既定値を書き換えていた事故 (全バッファ汚染) の回帰試験"
  (let* ((hdr (format nil "*WSL: Ubuntu:/home/user/project*"))
         (other (get-buffer-create " *wsl-ctx-keep*")))
    (unwind-protect
        (progn
          (wsl-open-directory "Ubuntu" "/home/user/project")
          (list (save-excursion
                  (set-buffer other)
                  *wsl-project-distro*)
                (save-excursion
                  (set-buffer hdr)
                  *wsl-project-distro*)))
      (ignore-errors (kill-buffer other))
      (ignore-errors (kill-buffer hdr))))
  => (nil "Ubuntu"))

(deftest wsl-git-command-for-test ()
  "wsl-git-command-for が WSL プロジェクトなら wsl.exe 経由の
(コマンドライン . ディストロ) を返し、Windows 側なら nil"
  (let ((*wsl-project-distro* nil))
    (list (wsl-git-command-for "status --short"
                               "//wsl.localhost/Ubuntu/home/user/proj")
          (wsl-git-command-for "status --short" "C:/Users/user/proj")))
  => (("wsl.exe -d Ubuntu --cd /home/user/proj -- sh -c \"git status --short\""
       . "Ubuntu")
      nil))

(deftest build-wsl-p-test ()
  "build-wsl-p が WSL プロジェクトのディストロを返し、Windows 側では nil"
  (let ((*wsl-project-distro* nil))
    (list (build-wsl-p "//wsl.localhost/Ubuntu/home/user/proj")
          (build-wsl-p "C:/Users/user/proj")))
  => ("Ubuntu" nil))

(deftest build-defined ()
  "build コマンドが定義されている"
  (fboundp 'build)
  => t)

(deftest wsl-resolve-directory-path-test ()
  "wsl-resolve-directory-path がチルダや UNC パスを正しく Linux パスに解決する"
  (list (wsl-resolve-directory-path "~" "Ubuntu")
        (wsl-resolve-directory-path "~/work" "Ubuntu")
        (wsl-resolve-directory-path "/home/user/test" "Ubuntu")
        (wsl-resolve-directory-path "\\\\wsl.localhost\\Ubuntu\\home\\user" "Ubuntu")
        (wsl-resolve-directory-path "//wsl.localhost/Ubuntu/home/user/dir/" "Ubuntu"))
  => ("/home" "/home/work" "/home/user/test" "/home/user" "/home/user/dir/"))

