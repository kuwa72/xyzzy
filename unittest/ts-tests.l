;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; tree-sitter の構文解析そのもののテスト (src/core/ts.cc)。
;;;
;;; ts-highlight-tests.l が見ているのは切り替えの Lisp だけで、**解析と問い
;;; 合わせが本当に動いているかは、どちらのプラットフォームでも測られて
;;; いなかった。** POSIX では 9 個の関数が nil を返すスタブだったが、
;;; `lisp/ts.l' は例外を出さずに諦めるので、**既定で有効になっているのに
;;; ユーザからは「色が付かない」だけに見えていた** (issue #150)。
;;;
;;; **文法の共有ライブラリはビルドの生成物**である。CMake が
;;; tree-sitter-c-grammar を作って grammars/c/ に置く (POST_BUILD) ので、
;;; ここが落ちるならビルドが文法を作っていないか、拡張子
;;; (`*ts-grammar-suffix*') がプラットフォームと合っていない。
;;;
;;; **問い合わせは非同期**で、解析中は nil が返る。1 回呼んで nil を見ても
;;; 「無い」ではないので、`ts-test-spans' で揃うまで待つ。

(require "ts")

(defun ts-test-grammar (lang)
  "LANG の文法を読み込む。**拡張子はプラットフォームで違う。**"
  (si:load-ts-grammar (ed::ts-grammar-file lang) lang))

(defun ts-test-call-with-buffer (text fn)
  "TEXT を入れた一時バッファで FN を呼ぶ。
**キャッシュを必ず外す。** 解析用の裏スレッドがバッファを掴んだままだと、
テストのあとまで走り続ける。"
  (let ((buf (create-new-buffer " *ts-tests*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (insert text)
          (funcall fn buf))
      (progn
        (ignore-errors (si:ts-free-buffer-cache buf))
        (set-buffer-modified-p nil buf)
        (ignore-errors (delete-buffer buf))))))

(defun ts-test-spans (grammar query buf)
  "spans が揃うまで待って返す。揃わなければ nil。"
  (dotimes (i 250)
    (let ((spans (si:ts-query-buffer grammar query buf)))
      (when spans
        (return spans))
      (sleep-for 0.02))))

(defun ts-test-apply (grammar query buf colors)
  "色が塗られるまで待つ。塗れたら t。"
  (dotimes (i 250)
    (when (si:ts-apply-highlights grammar query buf nil nil 'ts-face colors)
      (return t))
    (sleep-for 0.02)))

;;; --- 文法の読み込み ------------------------------------------------------

(deftest ts-grammar-loads ()
  "文法の共有ライブラリが開けて grammar オブジェクトになること。"
  (let ((g (ts-test-grammar "c")))
    (values (si:ts-grammar-p g)
            (si:ts-grammar-p "c")))
  => t
  => nil)

(deftest ts-grammar-suffix-matches-platform ()
  "探す拡張子がプラットフォームと合っていること。
**ここが合っていないと C++ 側が動いていてもファイルが見つからず、
例外も出ないまま色が付かない。**"
  (list (equal ed::*ts-grammar-suffix* (if (featurep :unix) ".so" ".dll"))
        (and (file-exist-p (ed::ts-grammar-file "c")) t))
  => (t t))

;;; --- 問い合わせ ----------------------------------------------------------

(deftest ts-query-returns-captures ()
  "捕捉した名前と範囲が返ること。"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x = 42;\n"
      #'(lambda (buf)
          (ts-test-spans g "(primitive_type) @type.builtin
(number_literal) @number" buf))))
  => (("type.builtin" 0 3) ("number" 8 10)))

(deftest ts-query-positions-are-characters-not-bytes ()
  "位置が文字単位であること。

**tree-sitter が返すのはバイト位置**で、バッファは UTF-16 の符号単位で
持っている。ASCII だけのバッファでは 3 つが一致してしまうので、日本語を
混ぜて測る。バイトで返っていれば 21、UTF-16 の符号単位なら 15 になる。"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "/* 日本語のコメント */ int x = 42;\n"
      #'(lambda (buf)
          (ts-test-spans g "(primitive_type) @type.builtin
(number_literal) @number" buf))))
  => (("type.builtin" 15 18) ("number" 23 25)))

(deftest ts-query-source-can-hold-non-ascii ()
  "問い合わせの文面に非 ASCII があっても壊れないこと。

**これは実際に踏んでいた。** POSIX の `WideCharToMultiByte' は符号ページを
見ずに下位バイトへ切り落とすので、`grammars/markdown/highlights.scm' の
1 行目 (全角ダッシュの入ったコメント) が壊れる。長さも NUL を含んだ値に
なっていたので、**ASCII だけの問い合わせでも余分な NUL を渡していた。**"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x = 42;\n"
      #'(lambda (buf)
          (ts-test-spans g "; 日本語のコメント — 全角ダッシュ入り
(number_literal) @number" buf))))
  => (("number" 8 10)))

(deftest ts-invalid-query-is-an-error ()
  "文法として通らない問い合わせが例外になること。

**問い合わせが組み立てられるのは木ができてから**なので、先に通る問い合わせで
解析を済ませておく。解析中に呼ぶと、まだ nil が返るだけで例外は出ない。"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x;\n"
      #'(lambda (buf)
          (ts-test-spans g "(primitive_type) @t" buf)
          (handler-case
              (progn (si:ts-query-buffer g "(no-such-node) @x" buf) :no-error)
            (error (e) :error)))))
  => :error)

;;; --- 木の状態 ------------------------------------------------------------

(deftest ts-node-ancestors-reaches-the-root ()
  "点の位置から根まで辿れること。**根は translation_unit。**"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int main (void) { return 0; }\n"
      #'(lambda (buf)
          ;; 木ができるまで待つのに問い合わせを使う (解析を起こすのがこれ)。
          (ts-test-spans g "(primitive_type) @t" buf)
          (let ((chain (mapcar #'car (si:ts-node-ancestors g buf 4))))
            (list (car (last chain)) (and (member "identifier" chain :test #'equal) t))))))
  => ("translation_unit" t))

(deftest ts-free-buffer-cache-drops-the-tree ()
  "キャッシュを外すと木が無くなること。
**外れていないと、裏スレッドがバッファを掴んだまま残る。**"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x = 1;\n"
      #'(lambda (buf)
          (ts-test-spans g "(primitive_type) @t" buf)
          (let ((before (si:ts-buffer-cached-p buf)))
            (si:ts-free-buffer-cache buf)
            (list (and before t) (si:ts-buffer-cached-p buf))))))
  => (t nil))

;;; --- 色を塗るところ ------------------------------------------------------

(deftest ts-apply-highlights-paints-text-attributes ()
  "捕捉した範囲に `ts-face' のテキスト属性が付くこと。

`si:ts-query-buffer' は位置を Lisp のリストで返すが、**色付けの経路は
Lisp を経由せず C の中で属性を付ける** (大きなファイルで打鍵が止まらない
ようにするため)。別の経路なので別に測る。"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x = 42;\n"
      #'(lambda (buf)
          (ts-test-apply g "(primitive_type) @type.builtin
(number_literal) @number" buf
                         '(("type.builtin" . 12) ("number" . 13)))
          (list-text-attributes))))
  => ((0 3 ts-face :foreground 12) (8 10 ts-face :foreground 13)))

(deftest ts-apply-highlights-skips-captures-with-no-color ()
  "色表に無い捕捉は塗らないこと。**塗ってしまうと色番号 0 で潰れる。**"
  (let ((g (ts-test-grammar "c")))
    (ts-test-call-with-buffer "int x = 42;\n"
      #'(lambda (buf)
          (ts-test-apply g "(primitive_type) @type.builtin
(number_literal) @number" buf
                         '(("number" . 13)))
          (list-text-attributes))))
  => ((8 10 ts-face :foreground 13)))
