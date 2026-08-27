;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; split-string の第 3 引数の意味を固定するテスト。
;;;
;;; この引数は長らく ignore-empty という名前で宣言されていたが、実装
;;; (src/core/string.cc の Fsplit_string) は empty_ok で、**non-nil のときに
;;; 空要素を「残す」**。名前と意味が逆だったので #57 で empty-ok に改名した。
;;;
;;; 改名は宣言だけの変更なので、間違って「本当に ignore-empty にする」方向へ
;;; 直されると、呼び出し側が全部裏返る。ここでそれを止める。

(deftest split-string-drops-empty-elements-by-default ()
  "第 3 引数を省略すると空要素は落ちること"
  (values (split-string "a,,b" #\,)
	  (split-string "a,,b" #\, nil)
	  (split-string ",a," #\,))
  => ("a" "b")
  => ("a" "b")
  => ("a"))

(deftest split-string-keeps-empty-elements-when-non-nil ()
  "第 3 引数が non-nil だと空要素が残ること (名前の見た目と逆)"
  (values (split-string "a,,b" #\, t)
	  (split-string ",,a" #\, t))
  => ("a" "" "b")
  => ("" "" "a"))

(deftest split-string-never-makes-a-trailing-empty-element ()
  "**末尾の区切りに対しては空要素を作らない** (先頭側とは非対称)。

実装の走査が do { ... } while (++p < pe) なので、最後の区切りを踏んだ時点で
ループを抜ける。Emacs の split-string とは違うので、行の数を数える用途で
そのまま置き換えられない。"
  (values (split-string ",a," #\, t)
	  (split-string "a,b," #\, t)
	  (split-string "a\nb\n" #\LFD t))
  => ("" "a")
  => ("a" "b")
  => ("a" "b"))

(deftest split-string-trims-with-char-bag ()
  "第 4 引数の文字群を分割後の前後から落とすこと"
  (values (split-string "a , b ,c" #\, nil " ")
	  (split-string "121,,12321" #\, t "1"))
  => ("a" "b" "c")
  => ("2" "" "232"))

(deftest split-string-trim-can-create-empty-elements ()
  "トリムの結果として空になった要素も第 3 引数の扱いに従うこと
(空白しかない要素は nil で消え、t で残る)"
  (values (split-string "a,  ,b" #\, nil " ")
	  (split-string "a,  ,b" #\, t " "))
  => ("a" "b")
  => ("a" "" "b"))

(deftest split-string-multi-char-separator-is-a-character-set ()
  "セパレータが 2 文字以上の文字列のときは「そのどれか」で切ること
(部分文字列ではない)"
  (values (split-string "a b\tc" " \t" nil)
	  (split-string "a/b:c" "/:" nil))
  => ("a" "b" "c")
  => ("a" "b" "c"))

(deftest split-string-on-runs-of-whitespace ()
  "空白が連続していても空トークンを作らないこと (ファジー絞り込みのクエリ分割)"
  (split-string "  a   b  " " \t" nil)
  => ("a" "b"))

(deftest split-string-on-an-empty-string ()
  "空文字列は nil を返すこと (第 3 引数に関わらず)"
  (values (split-string "" #\,)
	  (split-string "" #\, t))
  => nil
  => nil)

(deftest split-string-with-no-separator-present ()
  "区切りが無ければ 1 要素のリストになること"
  (split-string "abc" #\,)
  => ("abc"))

(deftest split-string-accepts-a-character-or-a-string-separator ()
  "セパレータは文字でも文字列でもよいこと"
  (values (split-string "a,b" #\,)
	  (split-string "a,b" ","))
  => ("a" "b")
  => ("a" "b"))
