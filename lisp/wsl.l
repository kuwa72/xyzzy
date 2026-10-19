;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; WSL (Windows Subsystem for Linux) integration for xyzzy
;;;

(provide "wsl")

(in-package "editor")

(require "terminal")

(export '(*wsl-distribution* *wsl-unc-prefix* *wsl-path-prefix* *wsl-command*
	  *wsl-mode-map* *wsl-mode-hook* *wsl-project-distro* *wsl-compile-buffer-name*
	  *wsl-project-list*
	  wsl-mode wsl
	  wsl-path-to-windows windows-path-to-wsl
	  wsl-parse-distributions wsl-list-distributions wsl-read-distribution
	  wsl-osc-52-sequence wsl-copy-string wsl-paste-string
	  wsl-copy-region wsl-paste
	  wsl-path-p wsl-extract-distro wsl-current-distro wsl-project-p
	  wsl-remember-project wsl-project-distro-for
	  wsl-read-distro-or-current
	  wsl-open-directory wsl-read-directory wsl-resolve-directory-path
	  wsl-directory-to-unc
	  wsl-find-file wsl-build-command-line wsl-git-command-line
	  wsl-git-command-for build-wsl-p
	  wsl-translate-log-paths wsl-compile build
	  wsl-call-process
	  wsl-utf16le-string-p wsl-decode-utf16le-string
	  wsl-git))

;;; 設定変数
(defvar *wsl-distribution* nil
  "既定の WSL ディストリビューション名 (nil の場合はデフォルトディストリビューション)")

(defvar *wsl-unc-prefix* "\\\\wsl.localhost"
  "WSL ルートへのアクセスに使う UNC プレフィックス (Windows 11: \\\\wsl.localhost, Windows 10: \\\\wsl$)")

(defvar *wsl-path-prefix* "/mnt/"
  "Windows ドライブがマウントされている Linux 側のプレフィックス")

(defvar *wsl-command* "wsl.exe"
  "WSL 実行可能ファイル名")

(defvar *wsl-mode-hook* nil
  "wsl-mode 起動時のフック")

(defvar *wsl-mode-map* nil
  "wsl-mode のキーマップ")

(unless *wsl-mode-map*
  (setq *wsl-mode-map* (make-sparse-keymap))
  (define-key *wsl-mode-map* '(#\C-c #\C-c) 'terminal-send-ctrl-c)
  (define-key *wsl-mode-map* #\C-v 'wsl-paste)
  (define-key *wsl-mode-map* #\S-Insert 'wsl-paste))


;;; ------------------------------------------------------------------
;;; パス変換関数

(defun wsl-path-to-windows (path &optional distro unc-prefix)
  "Linux パス (例: /mnt/c/Users/... や /home/...) を Windows パスに変換する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (zerop (length path))
    (return-from wsl-path-to-windows path))
  ;; 既に Windows ドライブパスまたは UNC パスの場合はそのまま返す
  (when (or (string-match "^[a-zA-Z]:" path)
	    (string-match "^\\\\\\\\" path)
	    (string-match "^//" path))
    (return-from wsl-path-to-windows path))
  ;; /mnt/<drive-letter>... の形式
  (if (string-match "^/mnt/\\([a-zA-Z]\\)\\(/.*\\)?$" path)
      (let* ((drive (char-upcase (char (match-string 1) 0)))
	     (rest (match-string 2)))
	(cond ((or (null rest) (string= rest "") (string= rest "/"))
	       (format nil "~C:/" drive))
	      (t
	       (format nil "~C:~A" drive rest))))
    ;; /home/... などの WSL ルートパス
    (let* ((d (or distro *wsl-distribution* "Ubuntu"))
	   (prefix (or unc-prefix *wsl-unc-prefix* "\\\\wsl.localhost"))
	   (sep (if (string-match "^//" prefix) "/" "\\"))
	   (clean-prefix (substitute-string (substitute-string prefix "[/\\\\]+$" "") "^[/\\\\]+" ""))
	   (lead-sep (if (string-match "^//" prefix) "//" "\\\\"))
	   (body (if (string= sep "\\")
		     (map-slash-to-backslash path)
		   (map-backslash-to-slash path))))
      (unless (string-match "^[/\\\\]" body)
	(setq body (concat sep body)))
      (format nil "~A~A~A~A~A" lead-sep clean-prefix sep d body))))

(defun windows-path-to-wsl (path)
  "Windows パス (例: C:/Users/... や \\\\wsl.localhost\\...) を Linux パスに変換する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (zerop (length path))
    (return-from windows-path-to-wsl path))
  ;; 既に Linux パス (単一のスラッシュで始まる) の場合はそのまま返す
  (when (and (string-match "^/" path)
	     (not (string-match "^//" path)))
    (return-from windows-path-to-wsl path))
  (let ((norm (map-backslash-to-slash path)))
    ;; ドライブレター形式 (C:/... や C:...)
    (if (string-match "^\\([a-zA-Z]\\):\\(/.*\\)?$" norm)
	(let* ((drive (char-downcase (char (match-string 1) 0)))
	       (rest (match-string 2)))
	  (cond ((null rest)
		 (format nil "/mnt/~C" drive))
		((string= rest "")
		 (format nil "/mnt/~C/" drive))
		(t
		 (format nil "/mnt/~C~A" drive rest))))
      ;; WSL UNC パス (//wsl.localhost/... や //wsl$/...)
      (if (string-match "^//\\(wsl\\.localhost\\|wsl\\$\\)/\\([^/]+\\)\\(/.*\\)?$" norm)
	  (let ((rest (match-string 3)))
	    (if (or (null rest) (string= rest ""))
		"/"
	      rest))
	;; それ以外は正規化したスラッシュパスを返す
	norm))))


;;; ------------------------------------------------------------------
;;; ディストリビューション一覧の取得・パース

(defun wsl-parse-distributions (output)
  "wsl.exe -l -q の出力文字列をパースし、ディストリビューション名のリストを返す。
UTF-16LE 出力に含まれる NUL 文字や改行・空白を整形する。"
  (when (or (null output) (zerop (length output)))
    (return-from wsl-parse-distributions nil))
  (let* ((no-nul (substitute-string output "\0" ""))
	 (no-cr (substitute-string no-nul "\r" ""))
	 (lines (split-string no-cr "\n"))
	 (result nil))
    (dolist (line lines)
      (let ((trimmed (string-trim " \t" line)))
	(when (plusp (length trimmed))
	  (push trimmed result))))
    (nreverse result)))

;;; ------------------------------------------------------------------
;;; プロセス出力の取り込み (Issue #402)
;;;
;;; `call-process' の `:output' はファイル名しか受け付けない。バッファを
;;; 渡すと無視され、子プロセスは xyzzy の標準出力を継承するので出力は
;;; バッファには届かない (GUI 起動なら行方不明、コンソール起動なら
;;; コンソールに出る)。そのため一時ファイル経由で取り込む。
;;;
;;; もうひとつの罠は wsl.exe の出力エンコーディング: wsl.exe は stdout が
;;; パイプのとき UTF-16LE で書く (BOM なし)。`WSL_UTF8=1' を環境変数に
;;; 足すと UTF-8 出力に切り替わる (WSL 0.64.0+ の公式 opt-in)。古い
;;; WSL はこの変数を無視して UTF-16LE のままなので、取り込み時に
;;; UTF-16LE を検出してデコードする。

(defun wsl-utf16le-string-p (s)
  "バイト列文字列 S (1 文字 = 1 バイト) が UTF-16LE らしければ t を返す。
BOM (FF FE) または奇数バイトの NUL 密度で判定する。"
  (when (and (stringp s) (> (length s) 1))
    (or (and (eql (char s 0) #\xff)
	     (eql (char s 1) #\xfe))
	(let ((n (min (length s) 512))
	      (odd-nul 0)
	      (odd-total 0))
	  (do ((i 1 (+ i 2)))
	      ((>= i n))
	    (incf odd-total)
	    (when (zerop (char-code (char s i)))
	      (incf odd-nul)))
	  (and (plusp odd-total) (>= odd-nul (ceiling odd-total 2)))))))

(defun wsl-decode-utf16le-string (s)
  "バイト列文字列 S (1 文字 = 1 バイト) を UTF-16LE としてデコードする。
先頭の BOM は落とし、サロゲートペアは合成する。"
  (with-output-to-string (out)
    (let ((n (length s))
	  (i 0))
      (when (and (> n 1) (eql (char s 0) #\xff) (eql (char s 1) #\xfe))
	(setq i 2))
      (while (< i n)
	(let* ((lo (char-code (char s i)))
	       (hi (if (< (1+ i) n) (char-code (char s (1+ i))) 0))
	       (u (logior lo (ash hi 8))))
	  (setq i (+ i 2))
	  (if (and (>= u #xd800) (< u #xdc00) (< (1+ i) n))
	      (let* ((lo2 (char-code (char s i)))
		     (hi2 (char-code (char s (1+ i))))
		     (u2 (logior lo2 (ash hi2 8))))
		(setq i (+ i 2))
		(if (and (>= u2 #xdc00) (< u2 #xe000))
		    (write-char (code-char (+ #x10000
					      (ash (- u #xd800) 10)
					      (- u2 #xdc00)))
				out)
		  (progn
		    (write-char (code-char u) out)
		    (write-char (code-char u2) out))))
	    (write-char (code-char u) out)))))))

(defun wsl-read-file-as-binary (file &optional limit)
  "FILE を :binary で読み、1 文字 = 1 バイトの文字列として返す。
LIMIT 非 nil なら先頭 LIMIT バイトだけ読む。"
  (with-open-file (s file :direction :input :encoding :binary)
    (with-output-to-string (out)
      (do ((i 0 (1+ i))
	   (c (read-char s nil nil) (read-char s nil nil)))
	  ((or (null c) (and limit (>= i limit))))
	(write-char c out)))))

(defun wsl-insert-command-output (buffer file)
  "FILE の内容を BUFFER の末尾に挿入する。
内容が UTF-16LE ならデコードして挿入し、それ以外は
`insert-file-contents' のエンコーディング自動判定に任せる。"
  (when (and (file-exist-p file) (plusp (file-length file)))
    (save-excursion
      (set-buffer buffer)
      (goto-char (point-max))
      (if (wsl-utf16le-string-p (wsl-read-file-as-binary file 512))
	  (insert (substitute-string
		   (wsl-decode-utf16le-string
		    (wsl-read-file-as-binary file))
		   "\r" ""))
	(insert-file-contents file)))))

(defun wsl-call-process (command-line buffer)
  "COMMAND-LINE を実行し、標準出力と標準エラーを BUFFER の末尾に挿入する。
戻り値は終了コード (`call-process' と同じ)。wsl.exe 向けに
`WSL_UTF8=1' を環境変数に足して起動する (他のプログラムには無害)。"
  (let ((outfile (make-temp-file-name)))
    (unwind-protect
	(prog1
	    (call-process command-line
			  :output outfile
			  :environ '(("WSL_UTF8" . "1"))
			  :show :hide
			  :wait t)
	  (wsl-insert-command-output buffer outfile))
      (ignore-errors (delete-file outfile)))))

(defun wsl-list-distributions ()
  "wsl.exe -l -q を実行し、利用可能なディストリビューション名のリストを返す。"
  (interactive)
  (let ((buf (create-new-buffer " *wsl-list*")))
    (unwind-protect
	(let ((status (ignore-errors
			(wsl-call-process (format nil "~A -l -q" *wsl-command*)
					  buf))))
	  (if (and status (zerop status))
	      (save-excursion
		(set-buffer buf)
		(wsl-parse-distributions (buffer-substring (point-min) (point-max))))
	    nil))
      (delete-buffer buf))))

(defun wsl-read-distribution (&optional prompt)
  "ミニバッファからディストリビューション名を選択・入力させる。"
  (let ((distros (wsl-list-distributions)))
    (if distros
	(completing-read (or prompt "WSL Distribution: ")
			 distros
			 :default (or *wsl-distribution* (car distros)))
      (read-string (or prompt "WSL Distribution: ")
		   :default (or *wsl-distribution* "Ubuntu")))))


;;; ------------------------------------------------------------------
;;; クリップボード連携 / OSC 52

(defun wsl-osc-52-sequence (string &optional (target "c"))
  "文字列を base64 エンコードした OSC 52 エスケープシーケンスを生成する。"
  (let ((b64 (si:base64-encode string nil t)))
    (format nil "~C]52;~A;~A~C" (code-char #x1b) (or target "c") b64 (code-char 7))))

(defun wsl-copy-string (string)
  "文字列を Windows クリップボードおよび kill-ring にコピーする。"
  (copy-to-clipboard string)
  (when (fboundp 'kill-new)
    (kill-new string))
  string)

(defun wsl-paste-string ()
  "Windows クリップボードから文字列を取得する。"
  (get-clipboard-data))

(defun wsl-copy-region (start end)
  "カレントバッファの指定リージョンを Windows クリップボードにコピーする。"
  (interactive "r")
  (let ((str (buffer-substring start end)))
    (wsl-copy-string str)
    (message "リージョンをクリップボードにコピーしました")))

(defun wsl-paste ()
  "クリップボードの内容をターミナルプロセスまたはカレントバッファに貼り付ける。"
  (interactive)
  (let ((proc (buffer-process (selected-buffer)))
	(data (get-clipboard-data)))
    (cond ((not (stringp data))
	   (message "クリップボードに文字列がありません"))
	  ((and proc (si:process-terminal-p proc))
	   (si:terminal-paste-string proc data))
	  (t
	   (insert data)))))


;;; ------------------------------------------------------------------
;;; ターミナル連携 (wsl)

(defun wsl-mode ()
  "WSL ターミナル用のメジャーモード。"
  (setq mode-name "WSL")
  (setq buffer-mode 'wsl-mode)
  (use-keymap *wsl-mode-map*)
  (setq need-not-save t)
  (setq auto-save nil)
  (setq kept-undo-information nil)
  (set-buffer-fold-width 80)
  (run-hooks '*wsl-mode-hook*))

(defun wsl (&optional distro dir)
  "カレントバッファのディレクトリに対応する WSL 側パスで wsl.exe ターミナルを起動する。
プレフィックス引数を与えるとディストリビューションを指定可能。"
  (interactive "P")
  (when (and (interactive-p) distro)
    (setq distro (wsl-read-distribution)))
  (let* ((target-distro (or distro *wsl-distribution*))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (buf-name (if target-distro
		       (format nil "*WSL:~A*" target-distro)
		     "*WSL*"))
	 (buf (get-buffer-create buf-name)))
    (set-buffer buf)
    (let ((proc (buffer-process (selected-buffer))))
      (if (and proc (eq (process-status proc) :run))
	  (switch-to-buffer buf)
	(let ((cmdline (format nil "~A~A~A"
			       *wsl-command*
			       (if target-distro
				   (format nil " -d ~A" target-distro)
				 "")
			       (if (and wsl-dir (plusp (length wsl-dir)))
				   (format nil " --cd ~A" wsl-dir)
				 ""))))
	  (goto-char (point-max))
	  (wsl-mode)
	  (make-process cmdline :output (selected-buffer) :terminal t)
	  (let ((new-proc (buffer-process (selected-buffer))))
	    (when (and new-proc (si:process-terminal-p new-proc))
	      (set-minor-mode-map *terminal-map*)))
	  (switch-to-buffer buf))))
    buf))

;;; ------------------------------------------------------------------
;;; WSL プロジェクト判定・管理 (Issue #343)

(defvar-local *wsl-project-distro* nil
  "カレントバッファまたはプロジェクトの WSL ディストリビューション名")

(define-history-variable *wsl-project-list* nil
  "WSL プロジェクトのルートとディストリビューションの対応一覧。
要素は (ROOT . DISTRO) の alist で、`wsl-open-directory' が登録する。
ヒストリファイルに保存されるので、次回の起動時にもディストロが
覚えられている。")

(defvar *wsl-compile-buffer-name* "*WSL-Compilation*"
  "WSL コンパイルバッファの既定名")

(defun wsl-path-p (path)
  "PATH が WSL UNC パス (\\\\wsl.localhost\\... や \\\\wsl$\\... など) であれば t を返す。"
  (unless (stringp path)
    (setq path (namestring path)))
  (and (stringp path)
       (let ((norm (map-backslash-to-slash path)))
	 (and (string-matchp "^//\\(wsl\\.localhost\\|wsl\\$\\)/" norm) t))))

(defun wsl-extract-distro (path)
  "WSL UNC パスからディストリビューション名を抽出する。WSL パスでなければ nil を返す。"
  (unless (stringp path)
    (setq path (namestring path)))
  (when (and (stringp path) (plusp (length path)))
    (let ((norm (map-backslash-to-slash path)))
      (when (string-match "^//\\(wsl\\.localhost\\|wsl\\$\\)/\\([^/]+\\)" norm)
	(match-string 2)))))

(defun wsl-current-distro (&optional dir)
  "現在のコンテキストにおける WSL ディストリビューション名を返す。
優先順位は、バッファローカルの `*wsl-project-distro*'、
プロジェクトレジストリ `*wsl-project-list*'、DIR (省略時は
`default-directory') の UNC パスから抽出、`*wsl-distribution*'
の順。どれも決まらなければ nil を返す。対話コマンドは
`wsl-read-distro-or-current' で選択を促す。"
  (let ((target (or dir (default-directory))))
    (or *wsl-project-distro*
	(wsl-project-distro-for target)
	(wsl-extract-distro target)
	*wsl-distribution*)))

(defun wsl-read-distro-or-current (&optional prompt dir)
  "現在のコンテキストの WSL ディストリビューション名を返す。
コンテキストから決まらないときはミニバッファから選択させる
(`wsl-read-distribution' に PROMPT を渡す)。"
  (or (wsl-current-distro dir)
      (wsl-read-distribution prompt)))

(defun wsl-project-p (&optional dir)
  "DIR (省略時は default-directory) が WSL プロジェクト内であれば t を返す。"
  (let ((target (or dir (default-directory))))
    (or (and *wsl-project-distro* t)
	(wsl-path-p target))))

;;; ------------------------------------------------------------------
;;; プロジェクトレジストリ (*wsl-project-list*)

(defun wsl-normalize-path (path)
  "経路の比較用に正規化する: スラッシュ区切りに揃え、末尾の
区切りを落とす。バックスラッシュ区切りの Windows パスと
スラッシュ区切りの Linux パスを同じルートとして扱えるようにする。"
  (unless (stringp path)
    (setq path (namestring path)))
  (substitute-string (map-backslash-to-slash path) "/+$" ""))

(defun wsl-remember-project (distro root)
  "WSL プロジェクト ROOT のディストリビューション DISTRO を
`*wsl-project-list*' に追加・更新する。同じルートの既存登録は
上書きして新しいものを先頭に置く (`project-remember-project'
と同型)。ROOT は正規化されて登録される。"
  (unless (and (stringp root) (plusp (length root)))
    (return-from wsl-remember-project nil))
  (let ((normalized (wsl-normalize-path root)))
    (setq *wsl-project-list*
	  (delete (cons normalized distro) *wsl-project-list*
		  :test #'(lambda (new old)
			    (string-equal (car new) (car old)))))
    (push (cons normalized distro) *wsl-project-list*)
    (when (> (length *wsl-project-list*) 50)
      (setq *wsl-project-list* (subseq *wsl-project-list* 0 50))))
  distro)

(defun wsl-project-distro-for (path)
  "PATH を含む WSL プロジェクトのディストリビューション名を返す。
`*wsl-project-list*' のルートのうち、PATH を含む最長のものを採用する。
ルートの途中まで一致するだけのパス (\"/proj\" と \"/project2\") は
別のプロジェクトとして扱う。どのプロジェクトにも属さなければ nil。"
  (unless (stringp path)
    (setq path (namestring path)))
  (let ((norm (wsl-normalize-path path))
	(best nil)
	(best-len 0))
    (dolist (entry *wsl-project-list*)
      (let ((root (car entry)))
	(when (and (plusp (length root))
		   (<= (length root) (length norm))
		   (> (length root) best-len)
		   (string-equal (subseq norm 0 (length root)) root)
		   (or (= (length root) (length norm))
		       (char= (char norm (length root)) #\/)))
	  (setq best (cdr entry)
		best-len (length root)))))
    best))

(defun wsl-resolve-directory-path (path &optional distro)
  "WSL ディレクトリパス (チルダ、UNC パス、Linux パス) を正規化された Linux パスに変換・解決する。"
  (unless (stringp path)
    (setq path (namestring path)))
  (cond ((or (string= path "~") (string= path "~/"))
	 "/home")
	((string-match "^~/" path)
	 (concat "/home" (subseq path 1)))
	((wsl-path-p path)
	 (windows-path-to-wsl path))
	(t path)))

(defun wsl-read-directory (&optional prompt distro default-dir)
  "ディストリビューション DISTRO 内のディレクトリパスを補完付きで入力させる。
Windows UNC パス (\\\\wsl.localhost\\<distro>\\...) を初期値として read-directory-name を呼び出し、
入力された UNC パスまたは Linux パスを Linux 側パスに正規化して返す。"
  (let* ((d (or distro (wsl-read-distro-or-current "WSL distribution: ")))
	 (initial-wsl (or default-dir "~"))
	 (resolved-initial (wsl-resolve-directory-path initial-wsl d))
	 (unc-default (wsl-path-to-windows resolved-initial d))
	 (unc-dir (let ((s (map-backslash-to-slash unc-default)))
		    (if (string-match "/$" s) s (concat s "/"))))
	 (input (read-directory-name (or prompt (format nil "WSL (~A) directory: " d))
				     :default unc-dir)))
    (if (and (stringp input) (plusp (length input)))
	(wsl-resolve-directory-path input d)
      resolved-initial)))

(defun wsl-open-directory (distro wsl-path)
  "ディストリビューション DISTRO の WSL パス WSL-PATH を Windows UNC パスとして開き、プロジェクトルートに設定する。
バッファにはそのディレクトリのエントリ一覧を出し、カレントディレクトリを
当該ディレクトリへ切り替える (#391)。そのため C-x C-f 等の次の操作が
同じ場所から始まり、バッファ上のファイル名からも直接開ける。"
  (interactive
   (let* ((d (wsl-read-distribution))
	  (p (wsl-read-directory "WSL directory: " d "~")))
     (list d p)))
  (let* ((resolved-wsl-path (wsl-resolve-directory-path wsl-path distro))
	 (win-path (wsl-path-to-windows resolved-wsl-path distro))
	 ;; スラッシュ形式に正規化して内部パスの整合性を保つ
	 ;; **POSIX からは WSL の UNC パスは見えない** (\\wsl.localhost\ は
	 ;; POSIX には実在しない)。UNC が開けない環境では Linux パスを
	 ;; そのまま一覧に使う — WSL 内のファイルを POSIX 側が直接
	 ;; 見られる場合 (:wsl.localhost を mount している環境等) は
	 ;; それが本来の読み方になる。
	 (win-dir (let ((s (map-backslash-to-slash win-path)))
		    (if (file-directory-p s)
			s
		      (if (file-directory-p resolved-wsl-path)
			  (concat (map-backslash-to-slash resolved-wsl-path)
				  (if (string-match "/$"
						    (map-backslash-to-slash
						     resolved-wsl-path))
				      "" "/"))
			(if (string-match "/$" s) s (concat s "/"))))))
	 (buf-name (format nil "*WSL: ~A:~A*" distro resolved-wsl-path))
	 (buf (get-buffer-create buf-name)))
    ;; 専用バッファに切り替えて作業ディレクトリを設定
    (set-buffer buf)
    (when (file-directory-p win-dir)
      (ignore-errors (set-default-directory win-dir buf)))
    ;; **バッファローカルに留める。** setq-default で
    ;; *wsl-project-distro* の既定値を書き換えると、開いた
    ;; プロジェクトのディストロが全バッファに漏れる。
    ;; プロジェクトをまたいだ記憶は wsl-remember-project が
    ;; *wsl-project-list* に残す。
    (setq *wsl-project-distro* distro)
    (wsl-remember-project distro win-dir)
    (setq need-not-save t)
    (setq auto-save nil)
    (wsl-open-directory-insert-listing buf win-dir distro resolved-wsl-path)
    (switch-to-buffer buf)
    (when (fboundp 'project-remember-project)
      (project-remember-project win-dir))
    (message "Opened WSL directory: ~A (~A)" win-dir distro)
    win-dir))

(defun wsl-open-directory-insert-listing (buf win-dir distro resolved-wsl-path)
  "BUF に DIR のエントリ一覧を展開する (#391)。説明テキストは置かない。"
  (setq buffer-read-only nil)
  (erase-buffer buf)
  ;; 1 行目は機械的に読めるヘッダ。以降はディレクトリのエントリ。
  (insert (format nil "WSL: ~A (~A)\n" resolved-wsl-path distro))
  (when (file-directory-p win-dir)
    (let ((entries (sort (directory win-dir :absolute t) #'string<)))
      (dolist (e entries)
	(insert (concat (file-namestring e) "\n")))))
  (setq buffer-read-only t)
  (set-buffer-modified-p nil))

(defun wsl-directory-to-unc (wsl-path distro)
  "WSL ディレクトリパス WSL-PATH を DISTRO の UNC ディレクトリ
\(スラッシュ区切り・末尾 / 付き) に正規化して返す。
`wsl-find-file' がプロジェクト外で選んだフォルダを
`project-find-file' のルートと `*wsl-project-list*' のキーに
そのまま使える形にするための変換 (issue #406)。"
  (let* ((resolved (wsl-resolve-directory-path wsl-path distro))
	 (unc (wsl-path-to-windows resolved distro))
	 (s (map-backslash-to-slash unc)))
    (if (string-match "/$" s) s (concat s "/"))))

(defun wsl-find-file (&optional dir distro)
  "WSL プロジェクト内のファイルを補完選択して開く。
WSL プロジェクト外で対話的に呼んだときは、`wsl-open-directory' と
同じくディストロと WSL 内のディレクトリを聞き (補完は
\\\\wsl.localhost\\<distro>\\ から始まる)、選んだフォルダを WSL
プロジェクトとして `*wsl-project-list*' に登録してから、
配下のファイルを補完選択する (issue #406)。
非対話呼び出しでプロジェクト外の DIR だけを渡した場合は従来どおり
`find-file' を対話的に呼ぶ。"
  (interactive
   (let ((dd (default-directory)))
     (if (wsl-project-p dd)
	 (list dd)
       (let* ((d (wsl-read-distro-or-current "WSL distribution: "))
	      (w (wsl-read-directory nil d "~")))
	 (list (wsl-directory-to-unc w d) d)))))
  (let ((target-dir (or dir (default-directory))))
    (if (wsl-project-p target-dir)
	(progn
	  (when distro
	    (wsl-remember-project distro target-dir)
	    (when (fboundp 'project-remember-project)
	      (project-remember-project target-dir)))
	  (if (fboundp 'project-find-file)
	      (project-find-file target-dir)
	    (find-file target-dir)))
      (call-interactively 'find-file))))

(defun build-wsl-p (&optional dir)
  "DIR (省略時は `default-directory') が WSL プロジェクトで
ディストリビューションが決まるならその名前を返す。
Windows 側なら nil。`build' が Windows/WSL の実行側を
選ぶのに使う。"
  (let ((target (or dir (default-directory))))
    (when (wsl-project-p target)
      (wsl-current-distro target))))

(defun wsl-git-command-for (git-args &optional dir)
  "DIR (省略時は `default-directory') が WSL プロジェクトなら、
WSL 経由で git を実行するコマンドラインとディストロの cons
\(コマンドライン . ディストロ) を返す。Windows 側なら nil。
git-status 等の Windows 側コマンドが WSL プロジェクトで
透過的に WSL 側の git を実行するために使う。実行結果中の
Linux パスは `wsl-translate-log-paths' で Windows パスに
戻す。"
  (let ((target (or dir (default-directory))))
    (when (wsl-project-p target)
      (let ((distro (wsl-current-distro target)))
	(cons (wsl-git-command-line git-args distro
				    (windows-path-to-wsl target))
	      distro)))))


;;; ------------------------------------------------------------------
;;; 外部ツールディスパッチ (compile / git) (Issue #343)

(defun wsl-build-command-line (command &optional distro wsl-dir)
  "WSL 上で COMMAND を実行するための wsl.exe コマンドライン文字列を構築する。"
  (let ((d (or distro *wsl-project-distro* *wsl-distribution*))
	(dir (or wsl-dir
		 (let ((dd (default-directory)))
		   (if (wsl-path-p dd)
		       (windows-path-to-wsl dd)
		     nil)))))
    (format nil "~A~A~A -- sh -c ~S"
	    *wsl-command*
	    (if (and d (plusp (length d)))
		(format nil " -d ~A" d)
	      "")
	    (if (and dir (plusp (length dir)))
		(format nil " --cd ~A" dir)
	      "")
	    command)))

(defun wsl-git-command-line (git-args &optional distro wsl-dir)
  "WSL 上で git を実行するためのコマンドライン文字列を構築する。"
  (wsl-build-command-line (format nil "git ~A" git-args) distro wsl-dir))

(defun wsl-path-boundary-p (string pos)
  "POS の文字が絶対パスの開始位置として妥当なトークン境界かを返す。
`/' が `C:/x' の `:' 直後や `src/foo.c' の途中に来るものをパス先頭と
誤認すると、ログ中の Windows パスや相対パスまで壊れる (#402)。"
  (or (zerop pos)
      (find (char string (1- pos)) " \t\n\r'\"(<>=|;&`")))

(defun wsl-translate-log-paths (log-string &optional distro)
  "コンパイルログ内の Linux パス (/home/... や /mnt/c/... など) を Windows パスに変換する。"
  (unless (stringp log-string)
    (return-from wsl-translate-log-paths log-string))
  (let ((target-distro (or distro *wsl-project-distro* *wsl-distribution* "Ubuntu"))
	(result "")
	(start 0))
    ;; Linux の絶対パスパターン: /mnt/<drive>/... または /<dir>/...
    ;; トークン境界に来るものだけを対象にする (wsl-path-boundary-p)。
    (while (string-match "\\(/mnt/[a-zA-Z]/[^:() \t'\"<>]+\\|/[^:() \t'\"<>]+\\)" log-string start)
      (let* ((m-start (match-beginning 1))
	     (m-end (match-end 1)))
	(if (wsl-path-boundary-p log-string m-start)
	    (let* ((linux-path (subseq log-string m-start m-end))
		   (win-path (wsl-path-to-windows linux-path target-distro)))
	      (setq result (concat result
				   (subseq log-string start m-start)
				   win-path))
	      (setq start m-end))
	  ;; 境界でなければそのマッチは素通しする
	  (setq result (concat result (subseq log-string start m-end))
		start m-end))))
    (concat result (subseq log-string start))))

(defun compile-run (cmdline cwd target-dir distro buf-name header)
  "CMDLINE を実行し、結果を compilation バッファ BUF-NAME に出力して
エラー解析の準備をする。CWD が非 nil ならそこで実行する。
DISTRO が非 nil なら WSL 上とみなし、出力中の Linux パスを
Windows パスに変換する (`next-error' でジャンプできるようにする)。
HEADER はコマンドの直後に載せる説明文。"
  (let ((buf (get-buffer-create buf-name)))
    (save-excursion
      (set-buffer buf)
      (setq buffer-read-only nil)
      (erase-buffer buf)
      ;; **バッファ自身の default-directory を実行先にする。** `-*-' 行は
      ;; 表示用で、find-file 経由でないこのバッファでは解釈されない。
      ;; ここがプロセス cwd のままだと find-errors-get-buffer の
      ;; file-exist-p が相対パスを解決できず next-error が黙って失敗する
      ;; (issue #410)。
      (ignore-errors (set-default-directory target-dir buf))
      (insert (format nil "-*- mode: compilation; default-directory: ~S -*-\n"
		      target-dir))
      (insert header)
      ;; **ヘッダは翻訳しない。** バッファ全体を `wsl-translate-log-paths'
      ;; にかけると `default-directory' や `Command:' の表示が実際に
      ;; 実行したコマンドと乖離する (#402)。
      (let ((output-start (point)))
	(if cwd
	    (let ((default-dir (default-directory)))
	      (set-default-directory cwd)
	      (wsl-call-process cmdline buf)
	      (set-default-directory default-dir))
	  (wsl-call-process cmdline buf))
	(when distro
	  (let ((translated (wsl-translate-log-paths
			     (buffer-substring output-start (point-max))
			     distro)))
	    (delete-region output-start (point-max))
	    (goto-char output-start)
	    (insert translated))))
      (goto-char (point-min)))
    (pop-to-buffer buf)
    (when (fboundp 'set-error-buffer)
      (set-error-buffer buf))
    (when (fboundp 'build-error-list)
      (build-error-list))
    buf))

(defun wsl-compile (command &optional distro dir)
  "WSL 上で COMMAND を実行し、結果を compilation バッファに出力してエラー解析を行う。
ディストリビューションが決まらないときは選択を促す。"
  (interactive
   (list (read-string "WSL compile command: "
		      :default (or (and (boundp '*compile-command*) *compile-command*) "make"))))
  (let* ((target-distro (or distro (wsl-read-distro-or-current nil dir)))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (cmdline (wsl-build-command-line command target-distro wsl-dir)))
    (compile-run cmdline nil target-dir target-distro
		 *wsl-compile-buffer-name*
		 (format nil "WSL: ~A (~A)\nCommand: ~A\n\n"
			 wsl-dir target-distro cmdline))))

(defun build (command &optional dir)
  "プロジェクトの側に応じて COMMAND を実行するビルドコマンド。
WSL プロジェクトなら WSL 側で (`wsl-compile' と同じ経路で
wsl.exe を介し、出力中の Linux パスを Windows パスに変換する)、
Windows プロジェクトならカレント側で実行する。結果は
compilation バッファに出力してエラー解析を行う。"
  (interactive
   (list (read-string "Build command: "
		      :default (or (and (boundp '*compile-command*) *compile-command*) "make"))))
  (let* ((target-dir (or dir (default-directory)))
	 (distro (build-wsl-p target-dir)))
    (if distro
	(wsl-compile command distro target-dir)
      (compile-run command target-dir target-dir nil "*compilation*"
		   (format nil "Command: ~A\n\n" command)))))

(defun wsl-git (&optional (git-args "status") dir)
  "WSL 上で Git コマンドを実行し、出力をバッファに表示する。
ディストリビューションが決まらないときは選択を促す。"
  (interactive "sWSL git args: ")
  (let* ((target-distro (wsl-read-distro-or-current nil dir))
	 (target-dir (or dir (default-directory)))
	 (wsl-dir (windows-path-to-wsl target-dir))
	 (cmdline (wsl-git-command-line git-args target-distro wsl-dir))
	 (buf (get-buffer-create "*WSL Git*")))
    (save-excursion
      (set-buffer buf)
      (setq buffer-read-only nil)
      (erase-buffer buf)
      (wsl-call-process cmdline buf)
      (let ((translated (wsl-translate-log-paths (buffer-substring (point-min) (point-max)) target-distro)))
	(erase-buffer buf)
	(insert translated))
      (goto-char (point-min)))
    (pop-to-buffer buf)
    buf))

