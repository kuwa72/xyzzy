;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/imenu.l のテスト。
;;;
;;; 索引は正規表現で作るので、間違いは「拾えない」か「拾いすぎる」の
;;; どちらかになる。モードごとに「拾ってほしい行」と「拾ってほしくない行」を
;;; 同じバッファに混ぜて、結果を丸ごと比較している。

(require "imenu")

(defun imenu-test-index (mode text)
  "MODE のバッファに TEXT を入れて索引を作り、((表示名 . 行番号) ...) を返す。"
  (funcall mode)
  (insert text)
  (ed::imenu-create-index))

(deftest imenu-lisp ()
  "Lisp: 行頭の def... を拾い、途中の def... や呼び出しは拾わないこと"
  (with-temp-buffer
    (imenu-test-index 'ed::lisp-mode
		      ";;; comment
(defvar *foo* 1)

(defun bar (x)
  (defun not-toplevel () 1)
  (bar x))

(defmacro baz (&rest body)
  body)
"))
  => (("*foo*" . 2) ("bar" . 4) ("baz" . 8)))

(deftest imenu-lisp-defmethod-with-setf ()
  "Lisp: (defmethod (setf foo) ...) の形でも落ちないこと"
  (with-temp-buffer
    (imenu-test-index 'ed::lisp-mode "(defmethod (setf foo) (v x)
  v)
"))
  => (("setf" . 1)))

(deftest imenu-python ()
  "Python: class と def を種類付きで拾い、入れ子の def も拾うこと"
  (with-temp-buffer
    (imenu-test-index 'ed::python-mode
		      "import os

class Foo:
    def method(self):
        pass

def top():
    x = def_not_a_def = 1
    return x
"))
  => (("class Foo" . 3) ("method" . 4) ("top" . 7)))

(deftest imenu-markdown ()
  "Markdown: 見出しを階層の記号ごと拾うこと (深さが目で分かる)"
  (with-temp-buffer
    (imenu-test-index 'ed::markdown-mode
		      "# Title

本文に # は出てこない。

## Section
### Sub
"))
  => (("# Title" . 1) ("## Section" . 5) ("### Sub" . 6)))

(deftest imenu-shell-script ()
  "シェル: function 付き・無しの両方の関数定義を拾うこと"
  (with-temp-buffer
    (imenu-test-index 'ed::shell-script-mode
		      "#!/bin/sh
foo() {
  echo hi
}
function bar () {
  foo
}
baz=1
"))
  => (("foo" . 2) ("bar" . 5)))

(deftest imenu-makefile ()
  "Makefile: ターゲットを拾い、変数代入は拾わないこと"
  (with-temp-buffer
    (imenu-test-index 'ed::makefile-mode
		      "CC = gcc
CFLAGS := -O2

all: build

build:
	$(CC) -o x x.c
"))
  => (("all" . 4) ("build" . 6)))

(deftest imenu-cmake ()
  "CMake: function と macro を拾うこと"
  (with-temp-buffer
    (imenu-test-index 'ed::cmake-mode
		      "cmake_minimum_required(VERSION 3.16)

function(my_helper arg)
endfunction()

macro(my_macro)
endmacro()
"))
  => (("my_helper" . 3) ("my_macro" . 6)))

(deftest imenu-toml ()
  "TOML: テーブル見出しを拾うこと ([[array]] も含む)"
  (with-temp-buffer
    (imenu-test-index 'ed::toml-mode
		      "key = 1

[package]
name = \"x\"

[[bin]]
name = \"y\"
"))
  => (("package" . 3) ("bin" . 6)))

(deftest imenu-sorted-by-line ()
  "種類ごとに走査しても、結果はバッファに現れる順で並ぶこと"
  (with-temp-buffer
    (mapcar #'cdr
	    (imenu-test-index 'ed::python-mode
			      "def a():
    pass
class B:
    pass
def c():
    pass
")))
  => (1 3 5))

(deftest imenu-falls-back-to-build-summary ()
  "正規表現の登録が無いモードでは build-summary-function を使うこと
(C++ は lisp/cfns.l の抽出をそのまま使う)"
  (with-temp-buffer
    (let ((index (imenu-test-index 'ed::c++-mode
				   "#include <stdio.h>

int
main (int argc, char **argv)
{
  return 0;
}
")))
      (values (ed::imenu-generic-expression)
	      ;; cfns.l は引数リストまで名前に含める。そのまま比べる。
	      index)))
  => nil
  => (("main(int argc, char **argv)" . 4)))

(deftest imenu-no-index-for-plain-text ()
  "text-mode のように索引の作り方が無いモードでは nil を返すこと"
  (with-temp-buffer
    (imenu-test-index 'ed::text-mode "just some text
and more
"))
  => nil)

(deftest imenu-create-index-function-wins ()
  "*imenu-create-index-function* を設定するとそれが優先されること"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "(defun foo () 1)\n")
    (let ((ed::*imenu-create-index-function*
	   #'(lambda () '(("custom" . 1)))))
      (ed::imenu-create-index)))
  => (("custom" . 1)))

(deftest imenu-labeled-entries-disambiguates ()
  "同名の項目には行番号を付けて区別すること
(区別しないと選んでも片方にしか飛べない)"
  (ed::imenu-labeled-entries '(("foo" . 3) ("bar" . 5) ("foo" . 9)))
  => (("foo" . 3) ("bar" . 5) ("foo  [9]" . 9)))

(deftest imenu-leader-binding ()
  "Leader c s に割り当てられていること"
  (values (lookup-keymap ed::*leader-map* #\c)
	  (lookup-keymap ed::*leader-code-map* #\s))
  => #.ed::*leader-code-map*
  => imenu)
