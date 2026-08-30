;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/flymake.l のテスト。
;;;
;;; **本物の linter は使わない。** gcc も shellcheck も CI の Windows には
;;; 無いので、あるものに頼ると「環境に無いから落ちた」が既知失敗に積まれる。
;;; 出力の読み方は文字列を直に渡して見て、起動する経路だけ `echo` で確かめる
;;; (`echo` は cmd.exe の内部コマンドにも sh の組み込みにもある)。
;;;
;;; **装飾がバッファを書き換えていないことを毎回見る。** そこが崩れると
;;; 「エラーを表示したらファイルが変わった」になり、いちばん困る壊れ方。

(require "flymake")

(defun flymake-test-buffer ()
  "テスト用のバッファを作って選択する。3 行入れておく。"
  (let ((buf (create-new-buffer "*flymake test*")))
    (set-buffer buf)
    (erase-buffer buf)
    (insert "first line here\nsecond line here\nthird line here\n")
    (set-buffer-modified-p nil)
    buf))

(defun flymake-test-cleanup (buf)
  (ignore-errors (delete-buffer buf)))

;;;
;;; 出力を読む
;;;

;; gcc の形。桁があってもなくても読めること。
(deftest flymake-parses-gcc-output ()
  (ed::flymake-parse-output
   "t.c:3:5: error: 'x' undeclared here
t.c:7: warning: unused variable 'y'
t.c:9:1: note: declared here")
  => ((3 5 :error "'x' undeclared here")
      (7 nil :warning "unused variable 'y'")
      (9 1 :note "declared here")))

;; **診断でない行は捨てること。** チェッカは要約や経過を混ぜて出す。
;; 全部を診断にすると、行番号の無いものを 1 行目のエラーとして描いてしまう。
(deftest flymake-drops-lines-that-are-not-diagnostics ()
  (ed::flymake-parse-output
   "gcc: warning: nothing to be done
t.c: In function 'main':
2 warnings generated.
t.c:4:1: error: real one")
  => ((4 1 :error "real one")))

;; 種別の語の対応。
;;
;; **最後の 1 行が診断にならないのは正しい。** 種別として読むのは
;; `[a-zA-Z][a-zA-Z ]*' なので `something-else' はハイフンで外れる。
;; 「種別が読めなかったから error にする」ではなく「その行は診断ではない」
;; と判断される。ファイル名に数字と `:' が並ぶ普通の行を拾わないために、
;; 種別の綴りは狭く取ってある。
(deftest flymake-severity-words-are-mapped ()
  (mapcar #'third
	  (ed::flymake-parse-output
	   "t.c:1:1: fatal error: a
t.c:2:1: warning: b
t.c:3:1: note: c
t.c:4:1: remark: d
t.c:5:1: something-else: e"))
  => (:error :warning :note :note))

;; 種別が読めた上で知らない語だったときは error にする。
(deftest flymake-treats-unknown-severity-as-error ()
  (third (first (ed::flymake-parse-output "t.c:1:1: bogus: a")))
  => :error)

;; 行の順に並ぶこと。gcc は行番号の順に出さない (上の実測でも 3, 5, 4 の順)。
(deftest flymake-sorts-by-line ()
  (mapcar #'first
	  (ed::flymake-parse-output
	   "t.c:9:1: error: c
t.c:2:1: error: a
t.c:5:1: error: b"))
  => (2 5 9))

;; :plain は明示的に選んだときだけ使う。**gcc の形で読むと、種別の無い行は
;; 診断にならない** — 緩い形を常に試すと gcc の要約まで拾ってしまうため。
(deftest flymake-plain-format-is-opt-in ()
  (list (ed::flymake-parse-output "foo.rb:12: syntax error, unexpected end")
	(ed::flymake-parse-output "foo.rb:12: syntax error, unexpected end"
				  '(:plain)))
  => (nil ((12 nil :error "syntax error, unexpected end"))))

;; perl の形 (本文 at ファイル line 行)。
(deftest flymake-parses-perl-output ()
  (ed::flymake-parse-output
   "syntax error at foo.pl line 4, near \"}\"
foo.pl had compilation errors."
   '(:perl))
  => ((4 nil :error "syntax error")))

;; 知らない形の名前は黙って無視する (設定の書き間違いでエラーにしない)。
(deftest flymake-unknown-format-name-is-ignored ()
  (ed::flymake-parse-output "t.c:1:1: error: x" '(:nosuch))
  => nil)

;;;
;;; 装飾
;;;

;; **装飾してもバッファは変わらないこと。** ここが本命。
(deftest flymake-decoration-does-not-modify-the-buffer ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(let ((before (buffer-substring (point-min) (point-max))))
	  (ed::flymake-decorate '((1 1 :error "boom") (2 nil :warning "hmm")))
	  (list (buffer-modified-p)
		(string= before (buffer-substring (point-min) (point-max)))))
      (flymake-test-cleanup buf)))
  => (nil t))

;; 装飾が実際に付き、消せること。
(deftest flymake-decoration-can-be-cleared ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(progn
	  (ed::flymake-decorate '((2 3 :error "boom")))
	  (goto-line 2)
	  (let ((attributed (and (find-text-attribute 'ed::flymake) t)))
	    (flymake-clear)
	    (list attributed
		  (and (find-text-attribute 'ed::flymake) t)
		  ed::*flymake-diagnostics*)))
      (flymake-test-cleanup buf)))
  => (t nil nil))

;; **桁が行末より後ろでも印が付くこと。** 「`;' が足りない」系の診断は行末の
;; 次の桁を指してくる。素直に使うと塗る幅が 0 になって何も出ない (gcc の
;; `expected ';' before '}' token' で実際に踏んだ)。
(deftest flymake-column-past-end-of-line-still-marks ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(progn
	  ;; 1 行目は "first line here" = 15 文字。桁 99 は行末より後ろ。
	  (ed::flymake-decorate '((1 99 :error "expected ; here")))
	  (goto-line 1)
	  (and (find-text-attribute 'ed::flymake) t))
      (flymake-test-cleanup buf)))
  => t)

;; 空行に対する診断では何も塗らない (塗る場所が無い)。落ちないことを見る。
(deftest flymake-diagnostics-on-an-empty-line-are-harmless ()
  (let ((buf (create-new-buffer "*flymake empty test*")))
    (unwind-protect
	(progn
	  (set-buffer buf)
	  (erase-buffer buf)
	  (insert "

")
	  (set-buffer-modified-p nil)
	  (list (ed::flymake-decorate '((1 1 :error "boom")))
		(buffer-modified-p)
		(progn (goto-line 1)
		       (and (find-text-attribute 'ed::flymake) t))))
      (flymake-test-cleanup buf)))
  => (1 nil nil))

;; **無い行を指す診断で落ちないこと。** 保存してから編集で行が減ると起きる。
(deftest flymake-diagnostics-past-end-of-buffer-are-harmless ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(list (ed::flymake-decorate '((1 1 :error "ok") (9999 1 :error "gone")))
	      (buffer-modified-p))
      (flymake-test-cleanup buf)))
  => (2 nil))

;;;
;;; 移動
;;;

(deftest flymake-navigation-moves-between-diagnostics ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(progn
	  (ed::flymake-decorate '((1 1 :error "a") (3 1 :error "b")))
	  (goto-char (point-min))
	  ;; **1 行目に診断があっても、そこからの「次」は 3 行目。**
	  ;; カーソル行より後ろを探す (今いる場所を「次」と言われても動かない)。
	  (let ((first-jump (progn (flymake-next-error) (current-line-number)))
		;; **端で止まらず回る。** 一覧が短いので行き止まりより速い。
		(wrapped (progn (flymake-next-error) (current-line-number)))
		(again (progn (flymake-next-error) (current-line-number)))
		(back (progn (goto-line 3) (flymake-previous-error)
			     (current-line-number))))
	    (list first-jump wrapped again back)))
      (flymake-test-cleanup buf)))
  => (3 1 3 1))

;; 診断が無いときは動かないし、エラーにもならない。
(deftest flymake-navigation-without-diagnostics-is-quiet ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(progn
	  (flymake-clear)
	  (goto-line 2)
	  (list (flymake-next-error)
		(flymake-previous-error)
		(current-line-number)))
      (flymake-test-cleanup buf)))
  => (nil nil 2))

;;;
;;; 起動する経路
;;;

;; **`echo` を偽のチェッカにして、起動から装飾までを 1 度通す。**
;; 本物の linter は CI に無いので、経路だけを見る。
(deftest flymake-check-runs-the-command-and-decorates ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(let ((ed::*flymake-alist*
	       (list (list buffer-mode
			   :command "echo x.c:2:1: error: fake-diagnostic"))))
	  (let ((n (flymake-check t)))
	    (goto-line 2)
	    (list n
		  (buffer-modified-p)
		  (and (find-text-attribute 'ed::flymake) t)
		  (fourth (first ed::*flymake-diagnostics*)))))
      (flymake-test-cleanup buf)))
  => (1 nil t "fake-diagnostic"))

;; 設定の無いモードでは何もしない (nil を返す)。
(deftest flymake-check-without-a-checker-does-nothing ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(let ((ed::*flymake-alist* nil))
	  (flymake-check t))
      (flymake-test-cleanup buf)))
  => nil)

;; 起動できないコマンドでも落ちないこと。**シェル越しなので終了コードは
;; 127 で返り、出力は「見つからない」というシェルのメッセージ。それを
;; 診断として読まないこと。**
(deftest flymake-check-with-a-missing-command-finds-nothing ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(let ((ed::*flymake-alist*
	       (list (list buffer-mode
			   :command "no-such-checker-exists-anywhere"))))
	  (list (flymake-check t) (buffer-modified-p)))
      (flymake-test-cleanup buf)))
  => (0 nil))

;; 保存時の自動実行は既定で無効。
(deftest flymake-is-off-by-default ()
  *flymake-on-save*
  => nil)

;; フックは無効なら何もしない。**設定の無いモードでも黙ること** —
;; 保存のたびにエコー領域へ何か出ると邪魔になる。
(deftest flymake-after-save-is-quiet-when-off ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
	(let ((*flymake-on-save* nil))
	  (ed::flymake-after-save))
      (flymake-test-cleanup buf)))
  => nil)

;;;
;;; 入力が止まってから検査する (`*flymake-idle-delay*')
;;;

;; **既定は nil** (保存時の入口と同じく、勝手に外部プロセスを起動しない)。
(deftest flymake-idle-is-off-by-default ()
  *flymake-idle-delay*
  => nil)

;; nil なら `*post-command-hook*' はタイマを張らないこと。
;; **張ってしまうと、打鍵ごとに張って発火して何もせず消えるのを繰り返す。**
(deftest flymake-schedule-does-nothing-when-off ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
        (let ((*flymake-idle-delay* nil))
          (list (ed::flymake-schedule)
                ;; 張られていないので、止めるものが無い
                (and (stop-timer 'ed::flymake-idle-check) t)))
      (flymake-test-cleanup buf)))
  => (nil nil))

;; 設定の無いモードでは、`*flymake-idle-delay*' があってもタイマを張らない。
(deftest flymake-schedule-does-nothing-without-a-checker ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
        (let ((*flymake-idle-delay* 0.05)
              (ed::*flymake-alist* nil))
          (ed::flymake-schedule)
          (and (stop-timer 'ed::flymake-idle-check) t))
      (flymake-test-cleanup buf)))
  => nil)

;; **入力が止まったあとに 1 回走ること。** `echo` を偽のチェッカにして、
;; `flymake-schedule` のあと待つと装飾が付いている。
(deftest flymake-idle-check-runs-after-a-pause ()
  (let ((buf (flymake-test-buffer)))
    (unwind-protect
        (let ((*flymake-idle-delay* 0.05)
              (ed::*flymake-alist*
               (list (list buffer-mode
                           :command "echo x.c:2:1: error: idle-diagnostic"))))
          (ed::flymake-schedule)
          ;; タイマが動くのは待っている間 (sleep-for が期限を見る)。
          (sleep-for 0.5)
          (list (and ed::*flymake-diagnostics* t)
                (fourth (first ed::*flymake-diagnostics*))
                (buffer-modified-p)))
      (progn (ignore-errors (stop-timer 'ed::flymake-idle-check))
             (flymake-test-cleanup buf))))
  => (t "idle-diagnostic" nil))
