;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for lisp/errors.l — build-error-list / first-error / next-error.
;;;
;;; issue #410 の退行テスト。直前の調査で見つかった 3 つの壊れ方を固定する:
;;;   1. `next-error' が「最初のエラー」を visit しない — goto-error が
;;;      visit 前にエントリを *rerror-list* へ移すので、1 件だけなら
;;;      必ず「これ以上エラーはありません」。
;;;   2. エラーリスト未構築のバッファ (grep 出力など) で最初の next-error
;;;      が必ず失敗する — first-error の wrap 経路が build-error-list
;;;      を呼ばない。
;;;   3. build-error-list がポイント位置以降しか走査しない — *compilation*
;;;      を再利用したりジャンプで point が動くと先頭のエラーを取りこぼす。
;;;
;;; ファイルシステムには触らない。ジャンプ先は `<名前>' 形式 (find-buffer
;;; 経路) で作る。

(require "errors")

(use-package "editor")

(defun errors-test-target (name nlines)
  "NAME という名のバッファに NLINES 行入れて返す。"
  (let ((buf (create-new-buffer name)))
    (save-excursion
      (set-buffer buf)
      (erase-buffer buf)
      (dotimes (i nlines)
	(insert (format nil "line ~A of ~A\n" (1+ i) name))))
    buf))

(defun errors-test-compilation (name &rest lines)
  "NAME のバッファに LINES を書き、選択して先頭に置く。
build-error-list はポイントから前方向に走査するので、呼ぶ側が
(point-min) に置くのが作り手側の責任。"
  (let ((buf (get-buffer-create name)))
    (set-buffer buf)
    (setq buffer-read-only nil)
    (erase-buffer buf)
    (dolist (l lines)
      (insert l) (insert "\n"))
    (goto-char (point-min))
    buf))

(defun errors-test-reset ()
  (setq ed::*error-list* nil
	ed::*rerror-list* nil
	ed::*error-buffer* nil
	ed::*last-error* nil))

(defun errors-test-cleanup (&rest bufs)
  (ignore-errors (delete-other-windows))
  (dolist (b bufs)
    (ignore-errors (delete-buffer b)))
  (errors-test-reset))

(defun errors-test-visit ()
  "現在のバッファ名と行番号を返す (ジャンプ先の検証用)。"
  (list (buffer-name (selected-buffer)) (current-line-number)))

;;; ------------------------------------------------------------------
;;; 1. エラー 1 件で next-error が失敗する

(deftest next-error-visits-single-error ()
  "構築済みリストが 1 件だけでも最初の next-error でそこに飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-single" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-single>:3:boom"))
	  (ed::build-error-list)
	  (and (ed::next-error)
	       (equal (errors-test-visit) '("err-single" 3))))
      (errors-test-cleanup target comp)))
  => t)

;;; ------------------------------------------------------------------
;;; 2. 複数エラーで先頭がスキップされる

(deftest next-error-visits-first-then-second ()
  "構築済みリスト [3 7] で next-error が順に 3 行目、7 行目へ飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-multi" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-multi>:3:one"
					      "<err-multi>:7:two"))
	  (ed::build-error-list)
	  (list (progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))))
      (errors-test-cleanup target comp)))
  => (3 7))

;;; ------------------------------------------------------------------
;;; 3. リスト未構築 (grep など) で最初の next-error が失敗する

(deftest next-error-builds-list-when-empty ()
  "リストが無いバッファでの最初の next-error がその場で構築して飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-fresh" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*grep-out*"
					      "<err-fresh>:5:hit"))
	  ;; build-error-list を呼ばないまま next-error する
	  (and (ed::next-error)
	       (equal (errors-test-visit)
		      '("err-fresh" 5))))
      (errors-test-cleanup target comp)))
  => t)

;;; ------------------------------------------------------------------
;;; 4. first-error からの連続ジャンプ

(deftest first-error-then-next-error ()
  "first-error が先頭を visit し、続く next-error が 2, 3 件目へ進む"
  (errors-test-reset)
  (let ((target (errors-test-target "err-seq" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-seq>:2:a"
					      "<err-seq>:4:b"
					      "<err-seq>:9:c"))
	  (list (progn (ed::first-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))))
      (errors-test-cleanup target comp)))
  => (2 4 9))

(deftest next-error-at-end-says-no-more ()
  "全部 visit した後の next-error は nil を返す"
  (errors-test-reset)
  (let ((target (errors-test-target "err-end" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-end>:2:only"))
	  (ed::build-error-list)
	  (list (and (ed::next-error) t)   ; 1 件目に行ける
		(and (ed::next-error) t))) ; 次は無い -> nil
      (errors-test-cleanup target comp)))
  => (t nil))

;;; ------------------------------------------------------------------
;;; 5. build-error-list はポイント位置によらずバッファ全体を見る

(deftest build-error-list-scans-from-point-min ()
  "ポイントが末尾にあっても全行を走査する

*compilation* は再利用されるので、前の表示位置が末尾なら
先頭のエラーを取りこぼす。issue #410 の調査中に確認した実害。"
  (errors-test-reset)
  (let ((target (errors-test-target "err-tail" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (let ((buf (get-buffer-create "*compilation*")))
	    (set-buffer buf)
	    (setq buffer-read-only nil)
	    (erase-buffer buf)
	    (insert "<err-tail>:3:one\n<err-tail>:8:two\n")
	    (goto-char (point-max))   ; 前の利用で末尾に残っていた想定
	    (setq comp buf))
	  (ed::build-error-list)
	  (and (ed::next-error)
	       (equal (errors-test-visit)
		      '("err-tail" 3))))
      (errors-test-cleanup target comp)))
  => t)

;;; ------------------------------------------------------------------
;;; ツールチェーン別のエラー出力形式
;;;
;;; next-error は *error-regexp-list* の形でしか行を拾えない。
;;; gcc/clang の file:line:col は古くからあるが、python の
;;; `  File "x.py", line 5' や rustc の `  --> src/main.rs:3:5' は
;;; 別形式なので、実出力そのままの形でジャンプできることを固定する。
;;;
;;; ファイル名解決は *find-errors-find-buffers* を立てて開いている
;;; バッファ名で通す (実ファイルは要らない)。

(defun errors-test-jump (target-name nlines comp-lines)
  "TARGET-NAME という NLINES 行のバッファを作り、COMP-LINES を
*compilation* に書いてリスト構築 → next-error で
(buffer-name . line-number) を返す。"
  (errors-test-reset)
  (let ((target (errors-test-target target-name nlines))
	(comp nil))
    (unwind-protect
	(let ((ed::*find-errors-find-buffers* t))
	  (setq comp (apply #'errors-test-compilation
			    "*compilation*" comp-lines))
	  (ed::build-error-list)
	  (ed::next-error)
	  (list (buffer-name (selected-buffer)) (current-line-number)))
      (errors-test-cleanup target comp))))

(deftest error-format-gcc ()
  "gcc/clang: file:line:col: error: ..."
  (errors-test-jump "prog.c" 20
		    '("prog.c:12:8: error: expected ';' before 'x'"))
  => ("prog.c" 12))

(deftest error-format-python ()
  "python traceback:   File \"x.py\", line N, in ..."
  (errors-test-jump "app.py" 20
		    '("Traceback (most recent call last):"
		      "  File \"app.py\", line 7, in <module>"
		      "    run()"
		      "NameError: name 'run' is not defined"))
  => ("app.py" 7))

(deftest error-format-typescript ()
  "tsc: file.ts(line,col): error TSxxxx: ..."
  (errors-test-jump "main.ts" 20
		    '("main.ts(9,14): error TS2322: Type 'string' is not assignable to type 'number'."))
  => ("main.ts" 9))

(deftest error-format-rust ()
  "rustc:   --> file.rs:line:col"
  (errors-test-jump "main.rs" 20
		    '("error[E0308]: mismatched types"
		      "  --> main.rs:4:18"
		      "   |"
		      "4  |     let x: i32 = \"hi\";"
		      "   |                  ^^^^ expected `i32`, found `&str`"))
  => ("main.rs" 4))

(deftest error-format-go ()
  "go build/vet: file.go:line:col: ..."
  (errors-test-jump "main.go" 20
		    '("./main.go" "main.go:6:2: undefined: y"))
  => ("main.go" 6))

;;; ------------------------------------------------------------------
;;; Lisp/Scheme 系処理系のエラー出力形式
;;;
;;; elisp/racket/chicken は file:line[:col] 系に乗る。clojure は
;;; `(file.clj:line:col)' という括弧つき、chez は `of file' という
;;; 語尾指定なので、それぞれ固有の形で固定する。
;;; SBCL は `; file: x' と `Line: N, Column: C' が別行に分かれるので
;;; 1 行正規表現では拾えない (下のテストはその現状を文書化する)。

(deftest error-format-emacs-lisp ()
  "elisp batch byte-compile: foo.el:line:col: Error:"
  (errors-test-jump "foo.el" 20
		    '("In toplevel form:"
		      "foo.el:8:4: Error: reference to free variable 'x'"))
  => ("foo.el" 8))

(deftest error-format-racket ()
  "racket: foo.rkt:line:col: ..."
  (errors-test-jump "prog.rkt" 20
		    '("prog.rkt:6:10: x: unbound identifier"))
  => ("prog.rkt" 6))

(deftest error-format-chicken ()
  "chicken csc: foo.scm:line や call-history の file:line"
  (errors-test-jump "prog.scm" 20
		    '("Error: unbound variable: y"
		      ""
		      "	Call history:"
		      "	prog.scm:9: g"))
  => ("prog.scm" 9))

(deftest error-format-clojure-stack ()
  "clojure stack trace: at user$eval.invoke(foo.clj:line)"
  (errors-test-jump "foo.clj" 20
		    '("Execution error at user/eval1 (REPL:1)."
		      "Syntax error compiling at (foo.clj:11:2)."))
  => ("foo.clj" 11))

(deftest error-format-chez ()
  "chez: Exception ... at line N, char C of file.ss"
  (errors-test-jump "prog.ss" 20
		    '("Exception in y: unbound variable"
		      " at line 13, char 5 of prog.ss"))
  => ("prog.ss" 13))
