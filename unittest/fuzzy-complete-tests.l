;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Tests for fuzzy narrowing (lisp/fuzzy-complete.l)
;;;

(unless (member "test-helpers" *modules* :test #'string=)
  (load-file (merge-pathnames "test-helpers.l" (directory-namestring *load-pathname*))))
(require "fuzzy-complete")

(in-package "editor")

(defun test-fuzzy-score-basics ()
  ;; 部分列として一致すればスコアが返る
  (assert-true (fuzzy-score "project.l" "prl"))
  (assert-true (fuzzy-score "project.l" "project.l"))
  ;; 順序を守らない・存在しない文字を含むものは不一致
  (assert-equal nil (fuzzy-score "project.l" "lpr"))
  (assert-equal nil (fuzzy-score "project.l" "xyz"))
  ;; 大文字小文字を無視する
  (assert-true (fuzzy-score "Project.l" "PL"))
  ;; 空クエリは常に一致 (スコア0)
  (assert-equal 0 (fuzzy-score "anything" "")))

(defun test-fuzzy-score-prefers-boundaries-and-consecutive ()
  ;; 連続一致・単語区切り直後の一致が多いほど高スコアになること
  (assert-true (> (fuzzy-score "foo_bar_baz.l" "fbb")
		  (fuzzy-score "xfooxbarxbazx" "fbb")))
  (assert-true (> (fuzzy-score "project.l" "proj")
		  (fuzzy-score "myproject.l" "proj"))))

(defun test-fuzzy-filter-sorts-and-limits ()
  (let ((candidates '("lisp/project.l" "lisp/leader.l" "lisp/git.l"
		      "unittest/project-tests.l" "docs/user/lisp-libraries.md")))
    ;; マッチしないものは除外される
    (assert-equal nil (fuzzy-filter candidates "zzz"))
    ;; 一致するものだけが返り、より良い一致が先頭に来る
    (let ((result (fuzzy-filter candidates "projl")))
      (assert-true (member "lisp/project.l" result :test #'string=))
      (assert-equal "lisp/project.l" (car result)))
    ;; limit で件数を絞れる
    (assert-equal 2 (length (fuzzy-filter candidates "l" 2)))
    ;; 空クエリでは全件を元の順序のまま (limit 適用) 返す
    (assert-equal (subseq candidates 0 3) (fuzzy-filter candidates "" 3))))

(defun run-fuzzy-complete-unit-tests ()
  (format t "Running fuzzy-complete unit tests...~%")
  (test-fuzzy-score-basics)
  (test-fuzzy-score-prefers-boundaries-and-consecutive)
  (test-fuzzy-filter-sorts-and-limits)
  (format t "All fuzzy-complete unit tests PASSED.~%"))

(run-fuzzy-complete-unit-tests)
