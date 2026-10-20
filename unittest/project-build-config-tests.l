;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for .xyzzy.d/build.l parsing (lisp/project.l, issue #418).
;;; ファイルシステムには触らず project-parse-build-config に
;;; 文字列を渡して検証する。
;;;

(require "project")

(use-package "editor")

(deftest build-config-parses-setq-local ()
  "(setq-local *compile-command* \"...\") が読める"
  (project-parse-build-config
   "(setq-local *compile-command* \"cargo build --workspace\")\n")
  => ((ed::*compile-command* . "cargo build --workspace")))

(deftest build-config-parses-setq ()
  "(setq *compile-command* \"...\") も同様に読める"
  (project-parse-build-config
   ";;; comment\n(setq *compile-command* \"make -j4\") ; tail\n")
  => ((ed::*compile-command* . "make -j4")))

(deftest build-config-rejects-non-literal ()
  "関数呼び出し・式を値に持つ代入は捨てる"
  (project-parse-build-config
   "(setq-local *compile-command* (concat \"a\" \"b\"))\n(setq-local *compile-command* \"ok\")\n")
  => ((ed::*compile-command* . "ok")))

(deftest build-config-rejects-non-whitelist-var ()
  "ホワイトリスト外の変数への代入は捨てる"
  (project-parse-build-config
   "(setq-local *evil-var* \"rm -rf /\")\n(setq-local *compile-command* \"ok\")\n")
  => ((ed::*compile-command* . "ok")))

(deftest build-config-ignores-other-forms ()
  "defun や関数呼び出しのトップレベルフォームは無視する"
  (project-parse-build-config
   "(defun f () (shell-command \"rm -rf /\"))\n(shell-command \"x\")\n(setq-local *compile-command* \"ok\")\n")
  => ((ed::*compile-command* . "ok")))

(deftest build-config-empty-and-junk ()
  "空・コメントのみ・読めない断片は全部 nil/無視"
  (list (project-parse-build-config "")
	(project-parse-build-config ";;; only comments\n")
	(project-parse-build-config "(unbalanced\n(setq-local *compile-command* \"x\")\n"))
  => (nil nil nil))

(deftest build-config-literal-types ()
  "変数参照 (シンボル) はリテラルでないので捨て、文字列は残す"
  (list (project-parse-build-config
	 "(setq-local *compile-command* other-var)\n(setq-local *compile-command* \"ok\")\n")
	(project-parse-build-config
	 "(setq-local *compile-command* 42)\n"))
  => (((ed::*compile-command* . "ok"))
      ((ed::*compile-command* . 42))))
