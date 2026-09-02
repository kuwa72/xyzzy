;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 外部の文法チェッカを走らせて、間違っている箇所に色と下線を付ける
;;; (Emacs の flymake / flycheck 相当)。issue #137。
;;;
;;; **バッファは書き換えない。** `set-text-attribute' は表示だけを変える
;;; (属性を付けても `buffer-modified-p' は nil のまま) ので、下線と色を足す
;;; ために本文へ何か挿し込む必要が無い。同じ仕組みで色を付けている前例が
;;; `lisp/ispell.l' (綴りの誤りに `:foreground 1 :underline t') と
;;; `lisp/diff.l' にある。
;;;
;;; **検査するのはディスク上のファイルではなく、今のバッファの中身。**
;;; 保存済みの版を検査すると、編集中はずっと古い結果が出続ける。一時ファイル
;;; へ書き出してそれを渡す。**拡張子は保つ** — linter は拡張子で言語を決める。
;;;
;;; **既定は無効。** 保存のたびに外部プロセスが起動するのを望まない使い方と
;;; 両立しないうえ、コマンド行が間違っていると黙ってノイズが出る。
;;; `lisp/formatter.l' の保存時整形と同じ判断。
;;;
;;; 入口は 2 つ: `*flymake-on-save*' (保存時) と `*flymake-idle-delay*'
;;; (入力が止まってから)。**どちらも既定は nil。** 後者は `start-timer' が
;;; 要るので、POSIX では #149 まで書けなかった。

(provide "flymake")

(in-package "editor")

(export '(flymake-check flymake-check-async flymake-clear
	  flymake-next-error flymake-previous-error
	  flymake-list-errors flymake-echo-error
	  toggle-flymake
	  *flymake-on-save* *flymake-idle-delay*
	  *flymake-alist* *flymake-format-alist*
	  *flymake-error-attributes* *flymake-warning-attributes*
	  *flymake-note-attributes*))

(defvar *flymake-on-save* nil
  "non-nil なら、保存のたびに `*flymake-alist*' のチェッカを走らせる。

既定で nil なのは、保存のたびに外部プロセスが起動するのを勝手に入れない
ため。`M-x toggle-flymake' で切り替える。無効でも `M-x flymake-check' は
使える。")

(defvar *flymake-idle-delay* nil
  "秒数なら、**入力が止まってからその時間後に**検査する。nil なら保存時のみ。

`*flymake-on-save*' が nil でもこちらは効く (別の入口)。

**既定は nil。** 打鍵が止まるたびに外部プロセスが起動するので、重い検査
コマンド (`g++` など) では待たされる。速い linter を使うときだけ入れる:

    (setq ed::*flymake-idle-delay* 0.5)

`lisp/ts.l' の遅延ハイライトと同じ形で、`*post-command-hook*' から 1 回だけの
タイマを張り直す。**打鍵ごとに走るのではなく、止まってから 1 回**になる。")

(defvar *flymake-alist*
  '((c-mode            :command "gcc -fsyntax-only -Wall \"~A\"")
    (c++-mode          :command "g++ -fsyntax-only -Wall -std=c++17 \"~A\"")
    (python-mode       :command "python -m pyflakes \"~A\"")
    (shell-script-mode :command "shellcheck -f gcc \"~A\"")
    (ruby-mode         :command "ruby -w -c \"~A\"" :format (:plain))
    (perl-mode         :command "perl -c \"~A\"" :format (:perl)))
  "モード (`buffer-mode' の値) ごとの文法チェッカ。

各要素は (モード . プロパティリスト) で、プロパティは次の 2 つ:

  :command  シェルに渡すコマンド行。`~A' が検査するファイルの名前に
            置き換わる (`formatter-expand-file-name' と同じ規則)。
  :format   出力の読み方の名前の一覧 (`*flymake-format-alist*' のキー)。
            既定は (:gcc)。前から順に試して、最初に読めた形を使う。

標準エラー出力は標準出力へまとめられる (`call-process' の `:error' は
既定で `:output' と同じ)。**ほとんどのチェッカは診断を stderr へ書く**ので、
コマンド行に `2>&1' を足す必要は無い。

Lisp モードを入れていないのは、xyzzy 自身の `byte-compile-file' が
そのまま使えて、外部プロセスを起動する理由が無いため。")

(defvar *flymake-format-alist*
  (list
   ;; gcc / clang / shellcheck -f gcc / pyflakes:
   ;;   file:行:桁: severity: 本文
   ;; 桁が無い形 (file:行: severity: 本文) も同じ 1 本で読めるように、
   ;; 桁の括りを丸ごと省略可能にしてある。
   (list :gcc
	 (compile-regexp
	  "^[^:\n]*:\\([0-9]+\\)\\(:\\([0-9]+\\)\\)?:[ \t]*\\([a-zA-Z][a-zA-Z ]*\\)[ \t]*:[ \t]*\\(.*\\)$")
	 1 3 4 5)
   ;; perl -c: 本文 at file line 行.
   (list :perl
	 (compile-regexp "^\\(.*\\) at [^ \n]+ line \\([0-9]+\\)")
	 2 nil nil 1)
   ;; ruby -c など、種別を出さない形: file:行: 本文
   ;; **緩いので、モードで明示的に選んだときだけ使う。** gcc の出す
   ;; `t.c: In function 'main':' のような行まで診断にしてしまう。
   (list :plain
	 (compile-regexp "^[^:\n]*:\\([0-9]+\\):[ \t]*\\(.*\\)$")
	 1 nil nil 2))
  "出力の読み方の表。各要素は

  (名前 正規表現 行の組番号 桁の組番号 種別の組番号 本文の組番号)

**名前はキーワード。** `.xyzzy' から形を選ぶとき `(quote (plain))' と書くと、
読んだパッケージが editor でなければ別のシンボルになって一致しない。
キーワードならどのパッケージでも同じシンボルになる。

桁・種別・本文の組番号は nil でもよい (その形の出力に無ければ)。種別が
nil のときは error 扱いにする。**「読めた行だけを診断として採る」**方針で、
一致しない行は黙って捨てる: チェッカは要約 (`2 warnings generated.') や
経過を混ぜて出すので、全部を診断にすると嘘が増える。")

(defvar *flymake-error-attributes* '(:foreground 1 :underline t)
  "error の箇所に付ける `set-text-attribute' のキーワード。")

(defvar *flymake-warning-attributes* '(:foreground 11 :underline t)
  "warning の箇所に付ける属性。3 (明るい黄) ではなく 11 (暗い黄) なのは、
明るい背景のテーマで黄が読めないため。")

(defvar *flymake-note-attributes* '(:foreground 4 :underline t)
  "note / info の箇所に付ける属性。")

(defvar-local *flymake-diagnostics* nil
  "このバッファの診断の一覧。要素は (行 桁 種別 本文)。行の順に並ぶ。")

;;;
;;; 出力を読む
;;;

(defun flymake-severity (string)
  "チェッカの出す種別の文字列を :error / :warning / :note のどれかにする。"
  (let ((s (string-downcase (or string "error"))))
    (cond
     ((string-matchp "warn" s) :warning)
     ((or (string-matchp "note" s) (string-matchp "info" s)
	  (string-matchp "remark" s))
      :note)
     ;; **知らない種別は error にする。** 落として黙るより、目に付く方が良い。
     (t :error))))

(defun flymake-match (regnum)
  "直前の `string-match' の REGNUM 番目の組。REGNUM が nil なら nil。"
  (and regnum
       (match-beginning regnum)
       (match-string regnum)))

(defun flymake-parse-line (line spec)
  "出力の 1 行 LINE を SPEC の形として (行 桁 種別 本文) にする。
読めなければ nil。"
  (let ((regexp (second spec))
	(line-regnum (third spec))
	(column-regnum (fourth spec))
	(severity-regnum (fifth spec))
	(message-regnum (sixth spec)))
    (when (string-match regexp line)
      ;; **一致の情報は次の正規表現で消える。** ここで全部の組を文字列として
      ;; 取り出しておく: `flymake-severity' が中で `string-matchp' を呼ぶので、
      ;; 種別を先に解釈すると、そのあと本文の組が取れなくなる (実際に踏んだ)。
      (let ((n (flymake-match line-regnum))
	    (column (flymake-match column-regnum))
	    (severity (flymake-match severity-regnum))
	    (message (flymake-match message-regnum)))
	(let ((line-number (and n (ignore-errors (parse-integer n)))))
	  (when (and line-number (plusp line-number))
	    (list line-number
		  (and column (ignore-errors (parse-integer column)))
		  (flymake-severity severity)
		  (or message line))))))))

(defun flymake-formats (names)
  "形の名前の一覧 NAMES を `*flymake-format-alist*' の項の一覧にする。"
  (let ((result nil))
    (dolist (name (or names '(:gcc)))
      (let ((spec (assoc name *flymake-format-alist* :test #'eq)))
	(when spec
	  (push spec result))))
    (nreverse result)))

(defun flymake-parse-output (string &optional formats)
  "チェッカの出力 STRING を診断の一覧にする。行の順に並べて返す。

FORMATS は試す形の名前の一覧 (既定は (:gcc))。**モードごとに形を選ぶ。**
全部の形を無条件に試すと、緩い形 (`ファイル:行: 本文') が gcc の要約行
まで診断として拾ってしまう。"
  (let ((specs (flymake-formats formats))
	(result nil))
    (dolist (raw (split-string string #\LFD t))
      (let ((line (string-trim " \t\r" raw)))
	(when (plusp (length line))
	  (dolist (spec specs)
	    (let ((d (flymake-parse-line line spec)))
	      (when d
		(push d result)
		(return)))))))
    ;; **`stable-sort'。** 同じ行に複数の診断があるとき、チェッカが出した順を
    ;; 保つ (先に出た方が原因で、後は波及であることが多い)。
    (stable-sort (nreverse result) #'< :key #'car)))

;;;
;;; 装飾
;;;

(defun flymake-attributes-for (severity)
  (case severity
    (:warning *flymake-warning-attributes*)
    (:note *flymake-note-attributes*)
    (t *flymake-error-attributes*)))

(defun flymake-decorate-1 (diagnostic)
  "診断 1 件をバッファに描く。行が無くなっていたら何もしない。"
  (save-excursion
    (when (goto-line (first diagnostic))
      (let ((bol (progn (goto-bol) (point)))
	    (eol (progn (goto-eol) (point))))
	;; 桁が分かっていればそこから行末まで、分からなければ行全体。
	;; **桁だけを 1 文字塗るのはやめた** — 下線 1 文字は見つけられない。
	(let* ((column (second diagnostic))
	       (start (cond ((and column (plusp column)) (+ bol (1- column)))
			    (t bol)))
	       ;; **桁が行末より後ろでも、最後の 1 文字は塗る。** 「`;' が
	       ;; 足りない」系の診断は行末の次の桁を指してくるので、素直に
	       ;; 使うと塗る幅が 0 になって**何も出ない**。実測: gcc の
	       ;; `expected ';' before '}' token' が 5 行目に印を付けられて
	       ;; いなかった。
	       (from (cond ((<= eol bol) bol)   ; 空行: 塗る場所が無い
			   (t (min start (1- eol))))))
	  (when (< from eol)
	    (apply #'set-text-attribute from eol 'flymake
		   (flymake-attributes-for (third diagnostic)))))))))

(defun flymake-clear ()
  "このバッファの flymake の装飾と診断を消す。"
  (interactive)
  (delete-text-attributes 'flymake :test #'eq)
  (setq *flymake-diagnostics* nil)
  t)

(defun flymake-decorate (diagnostics)
  (flymake-clear)
  (setq *flymake-diagnostics* diagnostics)
  (dolist (d diagnostics)
    (flymake-decorate-1 d))
  (length diagnostics))

;;;
;;; チェッカを走らせる
;;;

(defun flymake-spec-for-buffer ()
  "このバッファのチェッカのプロパティリスト。無ければ nil。"
  (cdr (assoc buffer-mode *flymake-alist* :test #'eq)))

(defun flymake-temp-file-name ()
  "検査用の一時ファイルの名前。**元の拡張子を保つ。**"
  (let* ((name (or (get-buffer-file-name) (buffer-name (selected-buffer))))
	 (type (pathname-type name)))
    (cond (type (concat (make-temp-file-name) "." type))
	  (t (make-temp-file-name)))))

(defun flymake-file-contents (file encoding)
  "FILE の中身を文字列で返す。読めなければ nil。"
  (let ((buf (create-new-buffer " *flymake output*")))
    (unwind-protect
	(save-excursion
	  (set-buffer buf)
	  (when encoding
	    (set-buffer-fileio-encoding encoding))
	  (and (ignore-errors (insert-file-contents file))
	       (buffer-substring (point-min) (point-max))))
      (ignore-errors (delete-buffer buf)))))

(defun flymake-run (command file)
  "COMMAND を FILE に対して走らせ、出力を文字列で返す。起動できなければ nil。

**終了コードは見ない。** 文法エラーがあれば 0 以外で終わるのが普通なので、
0 以外を失敗として捨てると診断が全部消える。起動できたかどうかだけを見る。"
  ;; **出力の解釈は `*default-process-encoding*'。** バッファのファイル入出力
  ;; 用のエンコーディングではない: 読むのはファイルの内容ではなく子プロセスの
  ;; 出す文字列で、xyzzy がそれに使う既定はこちら (`lisp/encoding.l' が
  ;; UTF-8 にしてある)。ここを間違えると gcc の出す `‘x’' が化ける。
  (let ((outfile (make-temp-file-name))
	(encoding *default-process-encoding*))
    (unwind-protect
	(multiple-value-bind (cmdline dir)
	    (shell-command-line (formatter-expand-file-name command file)
				(default-directory))
	  (let ((status (call-process cmdline
				      :output outfile
				      :exec-directory dir
				      :show :hide
				      :wait t)))
	    (cond ((null status) nil)
		  (t (or (flymake-file-contents outfile encoding) "")))))
      (ignore-errors (delete-file outfile)))))

(defun flymake-check (&optional quiet)
  "このバッファを外部のチェッカにかけて、間違っている箇所に印を付ける。"
  (interactive)
  (let ((spec (flymake-spec-for-buffer)))
    (cond
     ((null spec)
      (unless quiet
	(message "~A に文法チェッカが設定されていません" buffer-mode))
      nil)
     (t
      (let ((temp (flymake-temp-file-name)))
	(unwind-protect
	    (progn
	      (write-region (point-min) (point-max) temp nil
			    (buffer-fileio-encoding))
	      (let ((output (flymake-run (getf spec :command) temp)))
		(cond
		 ((null output)
		  (unless quiet
		    (message "文法チェッカを起動できませんでした: ~A"
			     (getf spec :command)))
		  nil)
		 (t
		  (let ((n (flymake-decorate
			    (flymake-parse-output output (getf spec :format)))))
		    (unless quiet
		      (cond ((zerop n) (message "文法エラーはありません"))
			    (t (message "~D 件" n))))
		    n)))))
	  (ignore-errors (delete-file temp))))))))

;;;
;;; 自動で走る側は待たない (issue #248)
;;;
;;; **`flymake-check` は同期のままにしてある。** `M-x flymake-check` は戻った
;;; 時点で印が付いていることを期待される対話コマンドで、
;;; `unittest/flymake-tests.l` の 3 件もその形で書いてある。**変えると
;;; 「呼んだのに何も起きない」に見える。**
;;;
;;; 待って困るのは**自動で走る側だけ**である。`*flymake-idle-delay*' を入れると
;;; 入力が止まるたびに走るので、gcc のような重いチェッカでは**止まるたびに
;;; エディタが固まる。** そこだけ非同期にした。
;;;
;;; **経路が 2 本になるのは承知の上。** 共有しているのは書き出し・解析・装飾で、
;;; 違うのは待ち方だけである。
;;;
;;; **`make-process` の出力が取れるようになるまで書けなかった** (issue #250)。
;;; それまでは端末エミュレータへ食わせていたので、非同期にすると「止まらない
;;; けれど何も出ない」に変わるだけだった。

;;; 検査中かどうか。**バッファごとに持つ。**
;;;
;;; **`defvar` を使ってはいけない。** defvar はシンボルを special にし、
;;; special な変数はバッファローカルになれない (`lisp/startup.l' の
;;; `*buffer-package*' の注記と同じ理由)。
(setq-default flymake-checking nil)
(make-variable-buffer-local 'flymake-checking)

;;; 溜めている出力。**バッファごとに持つ。**
(setq-default flymake-output nil)
(make-variable-buffer-local 'flymake-output)

(defun flymake-async-finish (buf temp tick fmt)
  "非同期の検査が終わったときに呼ばれる。**元のバッファへ戻って**装飾する。"
  (ignore-errors (delete-file temp))
  (when (and buf (not (deleted-buffer-p buf)))
    (save-excursion
      (set-buffer buf)
      (let ((output flymake-output))
	(setq flymake-checking nil)
	(setq flymake-output nil)
	;; **編集されていたら結果を捨てる。** 走らせてから終わるまでの間に行が
	;; 動いていれば、印の位置が合わない。**ずれた印を付けるくらいなら
	;; 付けない方がまし**で、入力が止まればまた走る。
	(when (and output (eql tick (buffer-modified-count)))
	  (flymake-decorate (flymake-parse-output output fmt))
	  (refresh-screen)))))
  nil)

(defun flymake-check-async ()
  "**待たずに**このバッファを検査する。エコー領域には何も出さない。

既に走っているときは何もしない。**重ねて起動すると、入力が止まるたびに
プロセスが積み上がる。**"
  (let ((spec (flymake-spec-for-buffer)))
    (when (and spec (not flymake-checking))
      (let ((temp (flymake-temp-file-name))
	    (buf (selected-buffer))
	    (tick (buffer-modified-count))
	    (fmt (getf spec :format))
	    (outbuf nil))
	(handler-case
	    (progn
	      (write-region (point-min) (point-max) temp nil
			    (buffer-fileio-encoding))
	      ;; **`:output` にバッファを渡す必要があるが、中身は使わない。**
	      ;; 出力はフィルタで溜める -- sentinel の時点でバッファが揃って
	      ;; いるかに頼らない形にしてある。`:terminal` は渡さない
	      ;; (端末エミュレータを作られると出力が来ない、issue #250)。
	      (setq outbuf (create-new-buffer " *flymake output*"))
	      (multiple-value-bind (cmdline dir)
		  (shell-command-line
		   (formatter-expand-file-name (getf spec :command) temp)
		   (default-directory))
		(let ((proc (make-process cmdline
					  :output outbuf
					  :exec-directory dir
					  :incode *default-process-encoding*
					  :show :hide)))
		  (setq flymake-checking t)
		  (setq flymake-output "")
		  (set-process-filter
		   proc
		   #'(lambda (p s)
		       (when (and buf (not (deleted-buffer-p buf)))
			 (save-excursion
			   (set-buffer buf)
			   (setq flymake-output
				 (concat (or flymake-output "") s))))))
		  (set-process-sentinel
		   proc
		   #'(lambda (p)
		       (ignore-errors (delete-buffer outbuf))
		       (flymake-async-finish buf temp tick fmt)))
		  proc)))
	  (error (e)
	    ;; 起動できなかった。**印は付けない**が、後片付けはする。
	    (ignore-errors (delete-file temp))
	    (when outbuf
	      (ignore-errors (delete-buffer outbuf)))
	    (setq flymake-checking nil)
	    (setq flymake-output nil)
	    nil))))))

(defun flymake-after-save ()
  "`*after-save-buffer-hook*' から呼ばれる。設定が無いモードでは黙る。"
  (when (and *flymake-on-save* (flymake-spec-for-buffer))
    (ignore-errors (flymake-check-async)))
  nil)

(add-hook '*after-save-buffer-hook* 'flymake-after-save)

(defun flymake-idle-check ()
  "タイマから呼ばれる。**黙って、待たずに検査する** (issue #248)。

以前は `flymake-check' を同期で呼んでいたので、**入力が止まるたびに
チェッカの終わるまでエディタが固まった。**"
  (when (and *flymake-idle-delay* (flymake-spec-for-buffer))
    (ignore-errors (flymake-check-async)))
  nil)

(defun flymake-schedule ()
  "`*post-command-hook*' から、1 回だけのタイマを張り直す。

**打鍵ごとに検査するのではない。** 張り直すので、入力が続いている間は発火せず、
止まってから `*flymake-idle-delay*' 秒後に 1 回だけ走る (`lisp/ts.l' の
`ts-schedule-highlight' と同じ形)。

設定の無いモードでは**タイマを張らない** — 打鍵ごとに張って発火して何もせず
消える、を繰り返す意味が無い。"
  (when (and *flymake-idle-delay* (flymake-spec-for-buffer))
    (stop-timer 'flymake-idle-check)
    (start-timer *flymake-idle-delay* 'flymake-idle-check t))
  nil)

(add-hook '*post-command-hook* 'flymake-schedule)

;;;
;;; 移動と一覧
;;;

(defun flymake-diagnostic-at-line (line)
  (find line *flymake-diagnostics* :key #'car :test #'eql))

(defun flymake-echo-error ()
  "カーソル行に診断があれば、その本文をエコー領域に出す。"
  (interactive)
  (let ((d (flymake-diagnostic-at-line (current-line-number))))
    ;; `~A' はキーワードの `:' を出さないので、:warning は "warning" になる。
    (cond (d (minibuffer-message "~A: ~A" (third d) (fourth d))
	     t)
	  (t nil))))

(defun flymake-goto (diagnostic)
  (goto-line (first diagnostic))
  (goto-bol)
  (when (and (second diagnostic) (plusp (second diagnostic)))
    (goto-column (1- (second diagnostic))))
  (flymake-echo-error)
  t)

(defun flymake-next-error ()
  "次の診断へ移る。"
  (interactive)
  (let* ((line (current-line-number))
	 (d (find-if #'(lambda (x) (> (car x) line)) *flymake-diagnostics*)))
    (cond (d (flymake-goto d))
	  (*flymake-diagnostics*
	   ;; **端で止まらず先頭へ回す。** 一覧が短いので、行き止まりで
	   ;; 「もう無い」と言われるより回った方が速い。
	   (flymake-goto (first *flymake-diagnostics*)))
	  (t (message "診断がありません") nil))))

(defun flymake-previous-error ()
  "前の診断へ移る。"
  (interactive)
  (let* ((line (current-line-number))
	 (d (find-if #'(lambda (x) (< (car x) line))
		     (reverse *flymake-diagnostics*))))
    (cond (d (flymake-goto d))
	  (*flymake-diagnostics*
	   (flymake-goto (car (last *flymake-diagnostics*))))
	  (t (message "診断がありません") nil))))

(defun flymake-list-errors ()
  "診断の一覧から選んで飛ぶ。"
  (interactive)
  (let ((diagnostics *flymake-diagnostics*))
    (cond
     ((null diagnostics) (message "診断がありません") nil)
     (t
      (let* ((items (mapcar #'(lambda (d)
				(format nil "~5D  ~A"
					(first d) (fourth d)))
			    diagnostics))
	     (chosen (completing-read "診断: " items :must-match t
				      :default (car items))))
	(when chosen
	  (let ((i (position chosen items :test #'string=)))
	    (when i
	      (flymake-goto (nth i diagnostics))))))))))

(defun toggle-flymake (&optional (arg nil sv))
  "保存時に文法チェッカを走らせるかどうかを切り替える。"
  (interactive)
  (setq *flymake-on-save*
	(cond (sv (and arg t))
	      (t (not *flymake-on-save*))))
  (when *flymake-on-save*
    (ignore-errors (flymake-check t)))
  (message "保存時の文法チェック: ~:[off~;on~]" *flymake-on-save*)
  *flymake-on-save*)
