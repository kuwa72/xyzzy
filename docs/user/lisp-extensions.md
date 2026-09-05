Lisp で拡張する
================

xyzzy は Common Lisp のサブセット + 独自のエディタ API で拡張できます。ANSI
Common Lisp でも Emacs Lisp でもないので、他のエディタや処理系にある関数が
そのまま使えるとは限りません。

初期化ファイル
--------------

起動時に `~/.xyzzy` (ファイルシステムがロングファイル名に対応していなければ
`~/_xyzzy`) が読み込まれます。無ければ何も起きません。`-q`/`-no-init-file`
で読み込みをスキップできます。詳細は [コマンドラインオプション](command-line.md)、
このファイルと GUI の設定ダイアログの関係は [設定](configuration.md) を
参照してください。

最小の例:

```lisp
; ~/.xyzzy

; 独自のコマンドを定義する
(defun my-insert-datetime ()
  (interactive)
  (insert (format-date-string "%Y-%m-%d %H:%M" (get-universal-time))))

; 独自のキーバインドを足す (単発のキーは global-set-key、
; C-x に続く2打鍵目は ctl-x-map に define-key)
(global-set-key #\F13 'my-insert-datetime)
(define-key ctl-x-map #\d 'my-insert-datetime)
```

追加の `.l` ファイルを読み込みたい場合は `*load-path*` にディレクトリを足してから
`require`/`load` します。

```lisp
(pushnew (merge-pathnames "my-lisp/" (si:system-root)) *load-path* :test #'equal)
(require "my-extension")
```

関数リファレンス
----------------

組み込み関数・特殊形式・変数の一覧は `reference/reference.xml` にあります
(インストーラ・ZIP 版では `docs/reference/` にコピーされます)。XML の編集・表示には
`xml-mode` を使えますが、この配布物には専用の `xmldoc-mode` は含まれていません。
XML の説明は過去の Xyzzy Documentation Project のリファレンスであり、現在の Lisp/C++
ソースから自動生成されたものではありません。**存在しない関数を推測で使わないこと** —
Common Lisp や Emacs Lisp にあるからといって xyzzy にあるとは限りません。まずここで確認してください。

サンプル・実例
--------------

同梱の `lisp/` 以下にあるファイル (`cmds.l`, `files.l`, `buffer.l` など) が、
実際に動いている拡張のいちばん確実なサンプルです。標準添付されている全モード・ライブラリ
の一覧や概要は [標準添付 Lisp ライブラリ・モード](lisp-libraries.md) を参照してください。
あるコマンドがどう実装されているか知りたいときは、`M-x describe-bindings` (メニューの「ヘルプ」→
「キー割り当て一覧」) でコマンド名を調べてから、そのファイル群を検索してください。
