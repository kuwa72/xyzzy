;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/modeline.l のテスト。
;;;
;;; モード行の見た目そのものは C++ 側が % 指定子を展開して描くので Lisp からは
;;; 確かめられない。確かめられるのは「どういう文字列を渡すか」の組み立てと、
;;; .git/HEAD の読み方である。そこにバグが出ると
;;;
;;;   * % を潰し忘れてブランチ名が書式指定子として食われる
;;;   * 項目が出せないときに区切りだけが残る
;;;   * worktree / submodule の .git (ファイル) を辿れない
;;;
;;; という形で壊れるので、そこを直接突く。

(require "modeline")

(deftest modeline-compose-joins-with-the-separator ()
  "文字列を区切りで繋ぐこと"
  (ed::modeline-compose '("a" "b" "c") " | ")
  => "a | b | c")

(deftest modeline-compose-drops-empty-values ()
  "nil と空文字列は区切りごと落ちること (項目が出せないバッファで区切りが残らない)"
  (values (ed::modeline-compose '("a" nil "" "c") " | ")
	  (ed::modeline-compose '(nil "" nil) " | ")
	  (ed::modeline-compose '() " | "))
  => "a | c"
  => ""
  => "")

(deftest modeline-quote-doubles-percent ()
  "% を %% にすること (C++ 側が書式指定子として食わないように)"
  (values (ed::modeline-quote "100%")
	  (ed::modeline-quote "a%bc%%d")
	  (ed::modeline-quote "plain")
	  (ed::modeline-quote nil))
  => "100%%"
  => "a%%bc%%%%d"
  => "plain"
  => nil)

(deftest modeline-elide-cuts-long-values ()
  "長い値を切って印を付けること。短い値はそのまま"
  (let ((ed::*modeline-ellipsis* ".."))
    (values (ed::modeline-elide "0123456789" 6)
	    (ed::modeline-elide "0123456789" 10)
	    (ed::modeline-elide "0123456789" nil)
	    (ed::modeline-elide nil 4)))
  => "0123.."
  => "0123456789"
  => "0123456789"
  => nil)

(deftest modeline-elide-handles-tiny-limits ()
  "上限が印より短くても落ちないこと"
  (let ((ed::*modeline-ellipsis* ".."))
    (ed::modeline-elide "abcdef" 1))
  => "..")

(deftest modeline-directory-leaf-takes-the-last-component ()
  "末尾のディレクトリ名を取り出すこと"
  (values (ed::modeline-directory-leaf "/a/b/xyzzy/")
	  (ed::modeline-directory-leaf "/a/b/xyzzy")
	  (ed::modeline-directory-leaf "/")
	  (ed::modeline-directory-leaf "")
	  (ed::modeline-directory-leaf nil))
  => "xyzzy"
  => "xyzzy"
  => nil
  => nil
  => nil)

(deftest modeline-parse-head-reads-a-branch ()
  "HEAD の ref からブランチ名を取ること"
  (values (ed::modeline-parse-head "ref: refs/heads/main")
	  (ed::modeline-parse-head "ref: refs/heads/topic/rich-modeline")
	  (ed::modeline-parse-head "ref: refs/heads/main
")
	  (ed::modeline-parse-head "ref:	refs/heads/main"))
  => "main"
  => "topic/rich-modeline"
  => "main"
  => "main")

(deftest modeline-parse-head-shortens-detached-sha ()
  "detached HEAD は短縮 SHA にすること"
  (ed::modeline-parse-head "3adee2ac0ffee1234567890abcdef1234567890a")
  => "3adee2a")

(deftest modeline-parse-head-on-junk ()
  "空や nil で落ちないこと"
  (values (ed::modeline-parse-head "")
	  (ed::modeline-parse-head "   ")
	  (ed::modeline-parse-head nil)
	  (ed::modeline-parse-head "ref: refs/remotes/origin/main"))
  => nil
  => nil
  => nil
  => "refs/remotes/origin/main")

;;; ---- ファイルを実際に置いて .git の探索を試す ----

(defmacro with-temp-repo ((var) &body body)
  "一時ディレクトリを作って BODY を実行し、後で消す。VAR は末尾 / 付きのパス。"
  `(let ((,var (merge-pathnames
		(format nil "modeline-test-~A/" (symbol-name (gensym)))
		(si:system-root))))
     (setq ,var (namestring ,var))
     (create-directory ,var)
     (unwind-protect
	 (progn ,@body)
       (ed::modeline-clear-cache)
       (labels ((rm (d)
		  (dolist (f (ignore-errors (directory d :absolute t :file-only t)))
		    (ignore-errors (delete-file f)))
		  (dolist (s (ignore-errors (directory d :absolute t :directory-only t)))
		    (let ((sd (concat (remove-trail-slash (namestring s)) "/")))
		      (unless (string= sd (concat (remove-trail-slash d) "/"))
			(rm sd))))
		  (ignore-errors (delete-directory d))))
	 (ignore-errors (rm ,var))))))

(setf (get 'with-temp-repo 'lisp-indent-hook) 1)

(defun write-text-file (path text)
  (with-open-file (s path :direction :output :if-exists :supersede
		     :if-does-not-exist :create)
    (princ text s))
  path)

(deftest modeline-finds-a-branch-from-a-parent-directory ()
  "サブディレクトリのファイルからでも上に遡ってブランチが取れること"
  (with-temp-repo (root)
    (let ((git (merge-pathnames ".git/" root))
	  (sub (merge-pathnames "src/deep/" root)))
      (create-directory (namestring git))
      (create-directory (namestring (merge-pathnames "src/" root)))
      (create-directory (namestring sub))
      (write-text-file (merge-pathnames "HEAD" git) "ref: refs/heads/topic/foo
")
      (ed::modeline-clear-cache)
      (values (ed::modeline-git-branch (namestring root))
	      (ed::modeline-git-branch (namestring sub)))))
  => "topic/foo"
  => "topic/foo")

(deftest modeline-follows-a-gitdir-file ()
  ".git がファイル (worktree / submodule) のとき gitdir: を辿れること"
  (with-temp-repo (root)
    (let ((real (merge-pathnames "realgit/" root))
	  (work (merge-pathnames "work/" root)))
      (create-directory (namestring real))
      (create-directory (namestring work))
      (write-text-file (merge-pathnames "HEAD" real) "ref: refs/heads/wt
")
      (write-text-file (merge-pathnames ".git" work)
		       (format nil "gitdir: ~A~%"
			       (remove-trail-slash (namestring real))))
      (ed::modeline-clear-cache)
      (ed::modeline-git-branch (namestring work))))
  => "wt")

(deftest modeline-returns-nil-outside-a-repository ()
  "リポジトリの外では nil を返すこと"
  (with-temp-repo (root)
    (ed::modeline-clear-cache)
    ;; system-root 側に .git があると拾ってしまうので、無いことを前提にしない。
    ;; ここでは「HEAD の無い .git」を置いて nil になることを見る。
    (let ((git (merge-pathnames ".git/" root)))
      (create-directory (namestring git))
      (ed::modeline-clear-cache)
      (ed::modeline-git-branch (namestring root))))
  => nil)

(deftest modeline-git-can-be-turned-off ()
  "*modeline-git-enable* が nil なら読みに行かないこと"
  (with-temp-repo (root)
    (let ((git (merge-pathnames ".git/" root)))
      (create-directory (namestring git))
      (write-text-file (merge-pathnames "HEAD" git) "ref: refs/heads/x
")
      (ed::modeline-clear-cache)
      (let ((ed::*modeline-git-enable* nil))
	(ed::modeline-git-branch (namestring root)))))
  => nil)

;;; ---- 組み立て ----

(deftest modeline-format-string-uses-the-segment-list ()
  "*modeline-segments* の順に並べること。未知の名前は飛ばすこと"
  (let ((ed::*modeline-segments* '(:state :buffer :mode))
	(ed::*modeline-separator* " | ")
	(ed::*modeline-git-enable* nil))
    (ed::modeline-format-string (selected-buffer)))
  => "%* | %b | %M")

(deftest modeline-format-string-skips-unknown-segments ()
  "知らない項目名は落とすこと (設定の書き間違いでモード行が壊れない)"
  (let ((ed::*modeline-segments* '(:state :no-such-segment :mode))
	(ed::*modeline-separator* " ")
	(ed::*modeline-git-enable* nil))
    (ed::modeline-format-string (selected-buffer)))
  => "%* %M")

(deftest modeline-format-string-accepts-literals-and-functions ()
  "文字列と関数もそのまま項目に置けること"
  (let ((ed::*modeline-segments* (list "[" :buffer "]"))
	(ed::*modeline-separator* "")
	(ed::*modeline-git-enable* nil))
    (ed::modeline-format-string (selected-buffer)))
  => "[%b]")

(deftest modeline-segments-accept-plain-symbols ()
  "キーワードでない同名シンボルでも拾えること (.xyzzy はパッケージ user なので、
素の 'state はここの editor::state とは別のシンボルになる)"
  (let ((ed::*modeline-segments* (list (intern "state" "user")
				       (intern "mode" "user")))
	(ed::*modeline-separator* " ")
	(ed::*modeline-git-enable* nil))
    (ed::modeline-format-string (selected-buffer)))
  => "%* %M")

(deftest modeline-position-segment-escapes-the-percent-sign ()
  "位置の %% がリテラルの % として渡ること"
  (ed::modeline-segment-position (selected-buffer))
  => "%P %/%%")

(deftest modeline-refresh-does-nothing-when-disabled ()
  "無効なら mode-line-format を buffer-local にしないこと"
  (let ((ed::*modeline-enable* nil)
	(buf (selected-buffer)))
    (kill-local-variable 'mode-line-format)
    (ed::refresh-modeline buf)
    (local-variable-p 'mode-line-format))
  => nil)

(deftest modeline-refresh-sets-a-buffer-local-format ()
  "有効なら buffer-local に組み立てた文字列を入れること"
  (unwind-protect
      (let ((ed::*modeline-enable* t)
	    (ed::*modeline-segments* '(:state :buffer))
	    (ed::*modeline-separator* " ")
	    (ed::*modeline-git-enable* nil))
	(ed::refresh-modeline (selected-buffer))
	(values (local-variable-p 'mode-line-format)
		mode-line-format))
    (kill-local-variable 'mode-line-format))
  => t
  => "%* %b")

(deftest modeline-toggle-restores-the-stock-format ()
  "無効化で buffer-local の値を外し、素のモード行に戻ること"
  (let ((ed::*modeline-segments* '(:state :buffer))
	(ed::*modeline-git-enable* nil))
    (ed::enable-rich-modeline)
    (let ((on (local-variable-p 'mode-line-format)))
      (ed::disable-rich-modeline)
      (values on
	      (local-variable-p 'mode-line-format)
	      ed::*modeline-enable*)))
  => t
  => nil
  => nil)

(deftest modeline-disable-removes-the-hooks ()
  "無効化でフックを外すこと (無効なのに毎コマンド呼ばれ続けない)"
  (progn
    (ed::enable-rich-modeline)
    (ed::disable-rich-modeline)
    (values (and (member 'ed::modeline-find-file-hook ed::*find-file-hooks*) t)
	    (and (member 'ed::modeline-post-command-hook
			 (and (boundp 'ed::*post-command-hook*)
			      ed::*post-command-hook*))
		 t)))
  => nil
  => nil)

(deftest modeline-setup-respects-a-user-format ()
  "ユーザが mode-line-format を変えていたら自動で有効にしないこと"
  (let ((saved (default-value 'mode-line-format)))
    (unwind-protect
	(progn
	  (setq-default mode-line-format "MY OWN FORMAT")
	  (let ((ed::*modeline-enable* nil)
		(ed::*modeline-auto-enable* t))
	    (ed::modeline-setup)
	    ed::*modeline-enable*))
      (setq-default mode-line-format saved)
      (ed::disable-rich-modeline)))
  => nil)

(deftest modeline-setup-enables-on-the-stock-format ()
  "素の mode-line-format のままなら自動で有効にすること"
  (let ((saved (default-value 'mode-line-format)))
    (unwind-protect
	(progn
	  (setq-default mode-line-format ed::*modeline-stock-format*)
	  (setq ed::*modeline-enable* nil)
	  (ed::modeline-setup)
	  ed::*modeline-enable*)
      (setq-default mode-line-format saved)
      (ed::disable-rich-modeline)))
  => t)

(deftest modeline-leader-binding ()
  "Leader t m に割り当てられていること"
  (lookup-keymap ed::*leader-toggle-map* #\m)
  => toggle-rich-modeline)
