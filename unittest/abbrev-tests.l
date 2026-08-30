;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `abbreviate-display-string' のテスト。
;;;
;;; **端末ではこれが「引数をそのまま返すスタブ」だった** (issue #50)。呼んで
;;; いるのは `lisp/app-menu.l` (最近使ったファイルの一覧) と `lisp/mouse.l`
;;; (URL の表示) で、長いパスが縮まないまま出ていた。桁で数える実装を
;;; `src/core/abbrev-columns.cc` に書いた。
;;;
;;; **数える単位がプラットフォームで違う。** Win32 は GDI で可変幅フォントの
;;; ピクセルを測り、上限は「平均文字幅 x 引数」である。端末は文字セルの格子
;;; なので桁で測る。したがって**同じ入力に同じ答えを期待できない**:
;;; 38 文字のパスは 40 桁には収まるが、40 文字ぶんの平均幅には収まらない
;;; ことがある (既知失敗 `fix-abbreviate-display-string` がそれ)。
;;;
;;; **なのでここは、どちらの数え方でも成り立つ性質で書く。** 十分に長いものは
;;; 縮む、`...` が入る、末尾のファイル名は残る、短いものは触らない。
;;; 桁数そのものを見るテストだけ `(featurep :unix)` で囲んである。

(defun abbrev-test-long-path ()
  "どちらの数え方でも上限 30 に収まらないパス。"
  "/very/long/directory/name/that/does/not/fit/anywhere/wordlist.h")

(deftest abbreviate-display-string-leaves-short-strings ()
  "入るものには触らないこと。"
  (values (abbreviate-display-string "abc" 40 t)
          (abbreviate-display-string "abc" 40 nil))
  => "abc"
  => "abc")

(deftest abbreviate-display-string-zero-width-is-empty ()
  "上限 0 なら空文字列。"
  (values (abbreviate-display-string "abcdef" 0 t)
          (abbreviate-display-string "abcdef" 0 nil))
  => ""
  => "")

(deftest abbreviate-display-string-shortens-a-long-path ()
  "長いパスは縮み、`...' が入り、**末尾のファイル名は残ること。**
名前が消えるとどのファイルか分からなくなるので、そこが要点である。"
  (let* ((path (abbrev-test-long-path))
         (r (abbreviate-display-string path 30 t)))
    (list (< (length r) (length path))
          (and (string-match "\\.\\.\\." r) t)
          (and (string-match "wordlist\\.h$" r) t)))
  => (t t t))

(deftest abbreviate-display-string-shortens-plain-text ()
  "パス名でないものも縮むこと。**真ん中を抜く**ので、前後が残る。"
  (let* ((s (make-sequence 'string 100 :initial-element #\a))
         (r (abbreviate-display-string s 20 nil)))
    (list (< (length r) 100)
          (and (string-match "\\.\\.\\." r) t)
          (and (string-match "^a" r) t)
          (and (string-match "a$" r) t)))
  => (t t t t))

(deftest abbreviate-display-string-keeps-the-drive ()
  "ドライブが入るなら残すこと。**`D:/.../name' の形。**"
  (let ((r (abbreviate-display-string "D:/src/cmigemo-1.3c-MIT/src/wordlist.h" 30 t)))
    (list (and (string-match "^D:/" r) t)
          (and (string-match "wordlist\\.h$" r) t)))
  => (t t))

(deftest abbreviate-display-string-fits-the-column-budget ()
  "**桁で数える側だけの約束。** Win32 は可変幅フォントのピクセルで測るので、
桁数の上限に収まるとは限らない。"
  (if (featurep :unix)
      (let ((path (abbrev-test-long-path)))
        (list (<= (length (abbreviate-display-string path 30 t)) 30)
              (<= (length (abbreviate-display-string path 12 t)) 12)))
    '(t t))
  => (t t))

(deftest abbreviate-display-string-counts-wide-characters-as-two ()
  "全角は 2 桁で数えること。**文字数で数えていると、全角ばかりのパスが
上限の 2 倍の幅になる。** ここも桁で数える側だけの約束。"
  (if (featurep :unix)
      (abbreviate-display-string "日本語のとても長いファイル名をもつパス/名前.txt" 20 t)
    ".../名前.txt")
  => ".../名前.txt")
