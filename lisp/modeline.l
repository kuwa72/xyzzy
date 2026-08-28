;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; モード行に「いまどこで何をしているか」を出す (doom-modeline の軽い版)。
;;;
;;;   Leader t m   有効・無効の切り替え
;;;   M-x refresh-modeline   いま見ているバッファのモード行を作り直す
;;;
;;; 素の xyzzy のモード行は "--**- foo.l (Lisp) [utf-8:LF] 12:3 File: ..." で、
;;; 「どのリポジトリのどのブランチを触っているか」が出ない。複数のリポジトリを
;;; 開いて作業していると、これが分からないのがそのまま事故になる。
;;;
;;; mode-line-format は C++ 側が % 指定子を展開する *ただの文字列* なので、
;;; Lisp 側で組み立てた文字列を buffer-local に差し込めば済む。逆に言うと
;;; 面が持てるのは文字列 1 本だけで、
;;;
;;;   * 色分けはできない (モード行は 1 色で描かれる)
;;;   * 右寄せもできない (指定子の展開後の幅が Lisp 側から分からない)
;;;
;;; ので、doom-modeline のような左右分割ではなく、左から順に並べる形にした。
;;;
;;; ブランチ名は git を起動せずに .git/HEAD を直接読む。サブプロセスを起こすと
;;; 打鍵のたびに数十 ms 取られてしまうし、Windows ではそれが体感できる。
;;; 上に遡って .git を探す部分だけキャッシュし、HEAD は毎回読む (41 バイトの
;;; ファイル 1 つなので、キャッシュして古い値を出す方が損)。
;;;
;;; Lisp が作った文字列 (ブランチ名・プロジェクト名) は % を含みうる。そのまま
;;; 渡すと C++ 側が書式指定子として食ってしまうので modeline-quote で潰す。
;;;

(provide "modeline")

(in-package "editor")

(require "project")

(export '(*modeline-segments*
	  *modeline-separator*
	  *modeline-segment-alist*
	  *modeline-git-enable*
	  *modeline-branch-prefix*
	  *modeline-max-segment-length*
	  *modeline-ellipsis*
	  *modeline-refresh-interval*
	  *modeline-auto-enable*
	  *modeline-stock-format*
	  *modeline-enable*
	  modeline-compose
	  modeline-quote
	  modeline-elide
	  modeline-directory-leaf
	  modeline-parse-head
	  modeline-head-file
	  modeline-git-branch
	  modeline-format-string
	  modeline-segment-value
	  modeline-clear-cache
	  refresh-modeline
	  enable-rich-modeline
	  disable-rich-modeline
	  toggle-rich-modeline))

(defvar *modeline-separator* " | "
  "モード行の区切り。")

(defvar *modeline-segments*
  '(:state :buffer :project :branch :mode :position :encoding)
  "モード行に並べる項目。*modeline-segment-alist* のキーを並べる。
文字列を混ぜるとそのまま出る。関数を混ぜるとバッファを引数に呼ばれる。")

(defvar *modeline-git-enable* t
  "nil なら Git ブランチを出さない (ファイルを読みに行かなくなる)。")

(defvar *modeline-branch-prefix* "git:"
  "ブランチ名の前に付ける文字列。プロジェクト名との見分けが付くようにする。")

(defvar *modeline-max-segment-length* 24
  "Lisp が作る項目 (プロジェクト名・ブランチ名) の最大幅。nil なら切らない。")

(defvar *modeline-ellipsis* ".."
  "*modeline-max-segment-length* で切ったときに付ける印。")

(defvar *modeline-refresh-interval* 40
  "この回数コマンドを実行するごとにモード行を作り直す。nil なら作り直さない。
ブランチを xyzzy の外で切り替えた場合、これで追い付く。")

(defvar *modeline-auto-enable* t
  "起動時に自動で有効にするか。ユーザが mode-line-format を自分で設定して
いる場合は、この値に関わらず有効にしない。")

(defvar *modeline-stock-format* "--%*- %b (%M) [%k:%l] %P %f"
  "素の xyzzy の mode-line-format。ユーザが触ったかどうかの判定に使う。")

(defvar *modeline-enable* nil
  "有効かどうか。直接触らず toggle-rich-modeline を使う。")

;;; ---------------------------------------------------------------- 文字列

(defun modeline-quote (string)
  "STRING の % を %% にして、モード行の書式指定として解釈されないようにする。"
  (when string
    (let ((out (make-string-output-stream)))
      (dotimes (i (length string))
	(let ((c (char string i)))
	  (when (char= c #\%)
	    (princ "%" out))
	  (princ c out)))
      (get-output-stream-string out))))

(defun modeline-elide (string &optional (limit *modeline-max-segment-length*))
  "STRING が LIMIT より長ければ後ろを落として *modeline-ellipsis* を付ける。"
  (if (or (null string) (null limit) (<= (length string) limit))
      string
    (let ((keep (max 0 (- limit (length *modeline-ellipsis*)))))
      (concat (subseq string 0 keep) *modeline-ellipsis*))))

(defun modeline-compose (values &optional (separator *modeline-separator*))
  "VALUES のうち nil と空文字列を捨て、SEPARATOR で繋いだ文字列を返す。

項目が出せないとき (ファイルの無いバッファのプロジェクト名など) に区切りだけが
残らないよう、捨てるのは繋ぐ前に行う。"
  (let ((out (make-string-output-stream))
	(firstp t))
    (dolist (v values)
      (when (and (stringp v) (not (string= v "")))
	(unless firstp
	  (princ separator out))
	(princ v out)
	(setq firstp nil)))
    (get-output-stream-string out)))

(defun modeline-directory-leaf (dir)
  "\"/a/b/c/\" から \"c\" を取り出す。取り出せなければ nil。"
  (when (and dir (stringp dir) (not (string= dir "")))
    (let* ((s (remove-trail-slash dir))
	   (n (length s)))
      (if (zerop n)
	  nil
	(let ((i (position #\/ s :from-end t)))
	  (let ((leaf (if i (subseq s (1+ i)) s)))
	    ;; "c:" のようなドライブだけの場合は名前として意味が無い。
	    (if (or (string= leaf "") (string= leaf ".") (string= leaf ".."))
		nil
	      leaf)))))))

;;; ---------------------------------------------------------------- Git

(defvar *modeline-head-cache* (make-hash-table :test #'equal)
  "ディレクトリ -> HEAD のパス (無ければ :none)。上に遡る分だけを覚える。")

(defun modeline-clear-cache ()
  "遡って探した .git の位置を忘れる。リポジトリを作った・消した直後に使う。"
  (interactive)
  (clrhash *modeline-head-cache*)
  t)

(defun modeline-read-first-line (path)
  "PATH の 1 行目を返す。読めなければ nil。"
  (ignore-errors
    (with-open-file (s path :direction :input)
      (read-line s nil nil))))

(defun modeline-git-dir (dir)
  "DIR から上に遡って .git を探し、git のメタデータディレクトリを返す。

.git がファイルの場合 (worktree / submodule) は中の \"gitdir: ...\" を辿る。"
  (let ((d (and dir (stringp dir) (not (string= dir "")) dir)))
    (while d
      (let ((dot (merge-pathnames ".git" d)))
	(when (file-exist-p dot)
	  (return-from modeline-git-dir
	    (if (file-directory-p dot)
		(concat (remove-trail-slash (namestring dot)) "/")
	      (let ((line (modeline-read-first-line dot)))
		(when (and line (string-match "^gitdir:[ \t]*\\(.+\\)$" line))
		  (let ((g (string-trim " \t" (match-string 1))))
		    (concat (remove-trail-slash
			     (namestring (merge-pathnames g d)))
			    "/")))))))
	;; 親を取るのは parent-directory に任せる (lisp/project.l)。
	;; **自分で「親が同じなら終わり」と書くと Windows で無限ループになる**:
	;; C:/ の親を尋ねると、ドライブ C: のカレントディレクトリが返ってきて
	;; 長い方へ戻る。
	(setq d (parent-directory d))))
    nil))

(defun modeline-head-file (dir)
  "DIR に効いている .git/HEAD のパス。無ければ nil。遡った結果は覚える。"
  (when (and dir (stringp dir))
    (let ((hit (gethash dir *modeline-head-cache* :miss)))
      (when (eq hit :miss)
	(let ((gd (ignore-errors (modeline-git-dir dir))))
	  (setq hit (if gd
			(let ((head (merge-pathnames "HEAD" gd)))
			  (if (file-exist-p head) (namestring head) :none))
		      :none))
	  (setf (gethash dir *modeline-head-cache*) hit)))
      (if (eq hit :none) nil hit))))

(defun modeline-parse-head (line)
  "HEAD の中身 LINE からブランチ名を返す。detached HEAD なら短縮 SHA。"
  (when (stringp line)
    (let ((s (string-trim " \t\r\n" line)))
      (cond ((string= s "") nil)
	    ((string-match "^ref:[ \t]*refs/heads/\\(.+\\)$" s)
	     (match-string 1))
	    ((string-match "^ref:[ \t]*\\(.+\\)$" s)
	     (match-string 1))
	    ((>= (length s) 7) (subseq s 0 7))
	    (t s)))))

(defun modeline-git-branch (&optional (dir (default-directory)))
  "DIR のリポジトリのブランチ名。リポジトリ外なら nil。"
  (when *modeline-git-enable*
    (let ((head (modeline-head-file dir)))
      (when head
	(modeline-parse-head (modeline-read-first-line head))))))

;;; ---------------------------------------------------------------- 項目

;; 指定子だけの項目は C++ 側が展開する。Lisp が作る項目は modeline-quote を
;; 通してから返す。
(defun modeline-segment-state (buffer) "%*")
(defun modeline-segment-buffer (buffer) "%b")
(defun modeline-segment-file (buffer) "%#F")
(defun modeline-segment-mode (buffer) "%M")
(defun modeline-segment-major-mode (buffer) "%m")
(defun modeline-segment-position (buffer) "%P %/%%")
(defun modeline-segment-line-column (buffer) "%P")
(defun modeline-segment-percent (buffer) "%/%%")
(defun modeline-segment-encoding (buffer) "%k %l")
(defun modeline-segment-ime (buffer) "%i")
(defun modeline-segment-read-only (buffer) "%#r")

(defun modeline-buffer-directory (buffer)
  "BUFFER が置かれているディレクトリ。"
  (let ((file (get-buffer-file-name buffer)))
    (if file
	(directory-namestring file)
      (default-directory buffer))))

(defun modeline-segment-project (buffer)
  "プロジェクトルートのディレクトリ名。プロジェクト外なら nil。"
  (let ((file (get-buffer-file-name buffer)))
    (when file
      (let ((root (ignore-errors (project-find-root-directory file))))
	(when root
	  (modeline-quote (modeline-elide (modeline-directory-leaf root))))))))

(defun modeline-segment-branch (buffer)
  "Git のブランチ名。リポジトリ外なら nil。"
  (let ((branch (ignore-errors
		  (modeline-git-branch (modeline-buffer-directory buffer)))))
    (when branch
      (modeline-quote
       (modeline-elide (concat *modeline-branch-prefix* branch))))))

(defvar *modeline-segment-alist*
  '((:state . modeline-segment-state)
    (:buffer . modeline-segment-buffer)
    (:file . modeline-segment-file)
    (:project . modeline-segment-project)
    (:branch . modeline-segment-branch)
    (:mode . modeline-segment-mode)
    (:major-mode . modeline-segment-major-mode)
    (:position . modeline-segment-position)
    (:line-column . modeline-segment-line-column)
    (:percent . modeline-segment-percent)
    (:encoding . modeline-segment-encoding)
    (:ime . modeline-segment-ime)
    (:read-only . modeline-segment-read-only))
  "項目名 -> それを作る関数。関数は buffer を 1 つ取り、文字列か nil を返す。")

(defun modeline-segment-function (segment)
  "SEGMENT に対応する関数。無ければ nil。

キーは名前で照合する。キーワードにしてあるのは、ユーザが .xyzzy
(パッケージ user) に (setq *modeline-segments* '(:state :buffer)) と書いたとき、
editor パッケージの同名シンボルと一致させるため。素のシンボルを渡されても
名前が合えば拾う。"
  (when (symbolp segment)
    (let ((name (symbol-name segment)))
      (dolist (e *modeline-segment-alist*)
	(when (string-equal name (symbol-name (car e)))
	  (return (cdr e)))))))

(defun modeline-segment-value (segment buffer)
  "SEGMENT の値。項目名なら対応する関数を呼び、文字列ならそのまま、
関数なら呼んだ結果を使う。どれでもなければ nil (設定の書き間違いで
モード行全体が壊れないように)。"
  (let ((fn (modeline-segment-function segment)))
    (cond (fn (ignore-errors (funcall fn buffer)))
	  ((stringp segment) segment)
	  ((or (functionp segment) (and (symbolp segment) (fboundp segment)))
	   (ignore-errors (funcall segment buffer)))
	  (t nil))))

(defun modeline-format-string (&optional (buffer (selected-buffer)))
  "BUFFER 用の mode-line-format を組み立てる。"
  (modeline-compose
   (mapcar #'(lambda (seg) (modeline-segment-value seg buffer))
	   *modeline-segments*)
   *modeline-separator*))

;;; ---------------------------------------------------------------- 適用

(defun refresh-modeline (&optional (buffer (selected-buffer)))
  "BUFFER のモード行を作り直す。"
  (interactive)
  (when (and *modeline-enable* (bufferp buffer))
    (save-excursion
      (set-buffer buffer)
      (make-local-variable 'mode-line-format)
      (setq mode-line-format (modeline-format-string buffer)))
    (update-mode-line buffer))
  t)

(defvar *modeline-command-count* 0)
(defvar *modeline-last-buffer* nil)

(defun modeline-post-command-hook ()
  "バッファが変わったとき、あるいは一定回数ごとにモード行を作り直す。

毎コマンド作り直すと .git/HEAD を打鍵ごとに読むことになるので、
バッファの切り替え以外は *modeline-refresh-interval* まで待つ。"
  (when *modeline-enable*
    (ignore-errors
      (unless (minibuffer-window-p (selected-window))
	(let ((buf (selected-buffer)))
	  (cond ((not (eq buf *modeline-last-buffer*))
		 (setq *modeline-last-buffer* buf)
		 (setq *modeline-command-count* 0)
		 (refresh-modeline buf))
		((and *modeline-refresh-interval*
		      (>= (incf *modeline-command-count*)
			  *modeline-refresh-interval*))
		 (setq *modeline-command-count* 0)
		 (refresh-modeline buf))))))))

(defun modeline-find-file-hook ()
  (refresh-modeline (selected-buffer)))

(defun enable-rich-modeline ()
  "モード行を作り直す形に切り替える。"
  (interactive)
  (setq *modeline-enable* t)
  (add-hook '*find-file-hooks* 'modeline-find-file-hook)
  (add-hook '*post-command-hook* 'modeline-post-command-hook)
  (setq *modeline-last-buffer* nil)
  (refresh-modeline (selected-buffer))
  t)

(defun disable-rich-modeline ()
  "素のモード行に戻す。buffer-local に入れた値を全バッファから外す。"
  (interactive)
  (setq *modeline-enable* nil)
  (delete-hook '*find-file-hooks* 'modeline-find-file-hook)
  (delete-hook '*post-command-hook* 'modeline-post-command-hook)
  (dolist (buf (buffer-list))
    (ignore-errors
      (save-excursion
	(set-buffer buf)
	(kill-local-variable 'mode-line-format))))
  (update-mode-line t)
  t)

(defun toggle-rich-modeline (&optional (arg nil sv))
  "モード行の切り替え。"
  (interactive)
  (if (if sv arg (not *modeline-enable*))
      (enable-rich-modeline)
    (disable-rich-modeline)))

(defun modeline-setup ()
  "起動後に呼ばれる。ユーザが mode-line-format を自分で設定していれば何もしない。"
  (when (and *modeline-auto-enable*
	     (equal (ignore-errors (default-value 'mode-line-format))
		    *modeline-stock-format*))
    (ignore-errors (enable-rich-modeline))))

(add-hook '*post-startup-hook* 'modeline-setup)
