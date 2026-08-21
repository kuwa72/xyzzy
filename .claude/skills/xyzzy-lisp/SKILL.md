---
name: xyzzy-lisp
description: xyzzy の Lisp API リファレンス (1837 エントリ) と拡張の書き方。xyzzy の .l ファイルを書く・読む・直すとき、xyzzy 組み込み関数のシグネチャや挙動を確認するとき、メジャーモード / キーマップ / シンタックステーブル / 正規表現ハイライトを定義するときに使う。
---

# xyzzy Lisp

xyzzy は Common Lisp のサブセット + 独自のエディタ API で拡張する。ANSI CL でも
Emacs Lisp でもない。**存在しない関数を推測で書かないこと** — このスキルの一番の
役目は「あるかないか」を確定させることにある。

## 引き方 (必ずこの順)

`references/` はこのスキルからの相対パス。全文を読まず、grep で必要な分だけ引く。

**1. 索引で存在確認とシグネチャ** — `references/index.tsv` は
`name / type / package / section / arguments` のタブ区切り。

```bash
grep -P '^set-text-attribute\t' references/index.tsv
# set-text-attribute  Function  editor  text  set-text-attribute FROM TO TAG &key :foreground ...
```

前方一致で探すなら `grep -P '^re-search' references/index.tsv`、
用途から探すなら `grep -iP '\tbuffers\t' references/index.tsv | cut -f1,5` のように section で絞る。

**2. 本文は section の md から該当見出しだけ抜く** — 各エントリは
`` ## `name` `` という見出しになっている。

```bash
awk '/^## `set-text-attribute`$/{f=1} f&&/^## /&&!/set-text-attribute/{exit} f' references/text.md
```

**3. 索引に無ければ xyzzy には無い。** CL や Emacs Lisp にあるからといって使わない。
代替を探すときは section 内を眺めるか、`lisp/*.l` の実際の使用例を grep する。

**4. 実装を読むなら** 索引の section md にある「定義: <file>」を見る。
`lisp/builtin.l` の `si::defun-builtin` は**宣言だけ**で、実体は `src/` の C++ にある。

## セクション一覧

`datatypes variables control-flow packages functions macros symbols numbers
characters strings sequences lists arrays hashtables evaluation errors io
filesystem processes system datetime buffers windows frames positions regions
text search-regexp syntax keymaps modes minibuffer menus dialogs filer chunks misc`

## パッケージ

| パッケージ | 用途 | エントリ数 |
|---|---|---|
| `editor` | エディタ API (バッファ、ウィンドウ、キーマップ…) | 1118 |
| `lisp` | Common Lisp 由来 | 635 |
| `system` (`si`) | 内部・低レベル | 47 |
| `keyword` | キーワード | 9 |

拡張は `(in-package "editor")` で書く。

## 間違えやすい差分

**Common Lisp との差**

- **CLOS が無い。** `defclass` / `defgeneric` / `defmethod` は存在しない。`defstruct` を使う (`lisp/struct.l`)。
- **スレッドが無い。** 非同期は `make-process` + `set-process-filter` / `set-process-sentinel`、
  もしくは `start-timer` の 2 通りだけ。
- 数値・シーケンス系はおおむね CL 準拠だが欠けているものも多い。必ず索引で確認する。
- **JSON のパーサ/シリアライザは無い**(`json-mode.l` はメジャーモードであって codec ではない)。**TLS も無い** — HTTPS が要るなら `make-process` で curl を叩く。

**Emacs Lisp との差**

- 正規表現は Emacs 風のバックスラッシュ記法 (`\\(...\\)`, `\\{4\\}`, `\\b`)。**PCRE ではない**。
- **overlay が無い。** テキストの装飾は `set-text-attribute` (tag ベース) で、
  `delete-text-attributes` / `clear-all-text-attributes` で消す。
- 表示エンジンにバッファ外テキストを描く手段が無い (ゴーストテキスト不可)。
- 関数名が微妙に違うものが多い。索引を引かずに書かない。

## 定型パターン

### メジャーモード

`lisp/toml-mode.l` が最小の実例。骨格:

```lisp
;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-

(provide "foo-mode")
(in-package "editor")
(require "re-kwd")

(export '(*foo-mode-hook* *foo-mode-map* foo-mode))

(defvar *foo-mode-hook* nil)
(defvar *foo-mode-map* nil)
(unless *foo-mode-map*
  (setq *foo-mode-map* (make-sparse-keymap)))

(defvar *foo-mode-syntax-table* nil)
(unless *foo-mode-syntax-table*
  (setq *foo-mode-syntax-table* (make-syntax-table))
  (set-syntax-string *foo-mode-syntax-table* #\")
  (set-syntax-escape *foo-mode-syntax-table* #\\)
  (set-syntax-start-comment *foo-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *foo-mode-syntax-table* #\LFD nil t)
  (set-syntax-match *foo-mode-syntax-table* #\[ #\]))

(defvar *foo-regexp-keyword-list* nil)
(defun foo-setup-keywords ()
  (unless *foo-regexp-keyword-list*
    (setq *foo-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(("^[ \t]*\\[[^]\n]+\\]" nil 0)      ; (正規表現 大小無視 色指定)
             ("\\btrue\\b\\|\\bfalse\\b" nil 2)))))
  *foo-regexp-keyword-list*)

(defun foo-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Foo")
  (setq buffer-mode 'foo-mode)
  (use-keymap *foo-mode-map*)
  (use-syntax-table *foo-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (foo-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (run-hooks '*foo-mode-hook*))
```

拡張子との対応づけは `lisp/defs.l` の `*auto-mode-alist*` に足し、あわせて
`(export 'foo-mode)` と `(autoload 'foo-mode "foo-mode" t)` を書く。

### キーマップ

```lisp
(define-key *foo-mode-map* #\C-j 'newline-and-indent)
(define-key *foo-mode-map* '(#\C-c #\C-t) 'foo-do-something)  ; プレフィックスキー
```

### 非同期プロセス

```lisp
(let ((proc (make-process "cmd args" :output buffer :exec-directory dir)))
  (set-process-filter proc #'(lambda (proc string) ...))
  (set-process-sentinel proc #'(lambda (proc) ...))
  (process-send-string proc "input\n"))
```

`lisp/process.l:245` に `set-process-sentinel` の実使用例がある。

### タイマー / デバウンス

```lisp
(stop-timer 'foo-do-it)
(start-timer 0.1 'foo-do-it t)   ; 第3引数 non-nil でワンショット
```

`lisp/ts.l` (tree-sitter ハイライト) と `lisp/grepd.l` (非同期 grep) が実例。

### バッファ内テキストの装飾

```lisp
(set-text-attribute from to 'my-tag :underline t :foreground 3)
(delete-text-attributes 'my-tag)
```

## 落とし穴

- ファイル先頭に `;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-` を付ける。
- `(provide "name")` を書かないと `require` できない。
- `(export '(...))` を忘れるとユーザから呼べない。
- `.l` はバイトコンパイルされて `.lc` になる。追加したら
  `cmake --build build --config Release --target bytecompile` を通す。
- テストは `unittest/` に既存のフレームワークがある。Lisp を足したらここにテストを書く。

## 参照ファイルの再生成

`reference/reference.xml` を直したら:

```bash
python3 misc/gen-reference-skill.py          # 再生成
python3 misc/gen-reference-skill.py --check  # 最新かどうかだけ確認 (CI 用)
```

`references/` 以下は自動生成。直接編集しない。
