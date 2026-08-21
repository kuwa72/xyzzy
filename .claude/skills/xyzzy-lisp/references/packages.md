# パッケージ (packages)

reference/reference.xml から自動生成。26 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*package*`

- Variable / package: lisp

```text
実行中のパッケージを保持しています。
in-packageで別のパッケージに移ることができます。

使用例：
  *package*
  => #<package: user>
```

関連: `パッケージ`, `defpackage`, `in-package`

## `defpackage`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `defpackage PACKAGE-NAME &rest OPTIONS`

```text
新しくパッケージを作ります。

  :nicknames              パッケージの別名 (複数指定可能)
  :documentation          パッケージのドキュメント (docstring)
  :use                    useするパッケージのリスト
  :shadow                 shadowするシンボルのリスト
  :shadowing-import-from  指定したパッケージからshadowing-importするシンボルのリスト
  :import-from            指定したパッケージからimportするシンボルのリスト
  :export                 exportするシンボルのリスト
  :intern                 internするシンボルのリスト
  :internal-size          内部シンボルのハッシュサイズ
  :external-size          外部シンボルのハッシュサイズ

:internal-size 及び :external-size の大きさは、だいたい登録するシンボル
数の1/3ぐらいの値でいいでしょう。この値が足らないからといって、新しいシ
ンボルが登録できない訳ではないので、たいして気にする必要はないでしょう。
ハッシューがチェーンされて、検索(intern時のみ）がちょっと遅くなるだけで
す。こだわる方は素数を選ぶでしょう。

使用例：

  ;;; henmiというパッケージを作る。
  ;;; lisp, editorをuseしています。
  (defpackage "henmi"
     (:use "lisp" "editor")
     (:documentation "henmi's package")
     (:internal-size 200)
     (:external-size 10))
  => #<package: henmi>

  (documentation (find-package "henmi") t)
  => "henmi's package"

互換性:
  :internal-size, :external-size はCommon Lispにはない。

補足：
  :documentation引数は xyzzy 0.2.2.236 から利用可能です。
```

関連: `make-package`, `find-package`, `use-package`, `delete-package`, `rename-package`, `in-package`, `package-name`, `package-nicknames`, `パッケージ`

## `delete-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete-package PACKAGE`

```text
パッケージを削除します。

使用例：
  ;;; test 用パッケージを作る
  (defpackage "test")
  => #<package: test>
  (find-package "test")
  => #<package: test>
  ;;; test パッケージを削除する
  (delete-package "test")
  => t
  (find-package "test")
  => nil
```

関連: `make-package`, `defpackage`, `rename-package`, `パッケージ`

## `do-all-symbols`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `do-all-symbols (VAR &optional RESULT-FORM) &body BODY`

```text
全シンボルを列挙します。

  VAR         : 列挙されたシンボルを格納する変数名を指定します。
  RESULT-FORM : （詳細不明）
  BODY        : 実行するフォームを指定します。

使用例：
  ;;; シンボルを列挙して変数・関数・マクロ・パッケージを出力してみる。
  (do-all-symbols (sym)
    (and (or (boundp sym)
             (fboundp sym))
         (format t "~:[ ~;V~]~:[ ~;F~]~:[ ~;M~] ~A ~S~%"
                 (boundp sym)
                 (fboundp sym)
                 (macro-function sym)
                 (package-name (symbol-package sym))
                 sym)))
```

関連: `with-package-iterator`

## `export`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `export SYMBOLS &optional PACKAGE`

```text
シンボルをパッケージの外部から参照できるようにします。

引数で指定された シンボル（変数や関数）はパッケージからエクスポートされ、
別のパッケージから修飾子無しで参照できるようになります。ただし、修飾子無
しで参照するには、別のパッケージからもuse-packageもしておかないといけませ
ん。
                   use  ┌system──┐
                    ┌─┤          │
  ┌lisp───┐←─┘  └─────┘        ┌user───┐
  │          │←────────────┬─┤          │
  └─────┘←─┐  ┌editor──┐    │  └─────┘
        ↑          └─┤          │←─┘
        │              └─────┘←─┐
  ┌common-lisp ┐                        │  ┌common-lisp-user┐
  │            │←───────────┴─┤                │
  └──────┘                            └────────┘


上の図はどのパッケージをuse-pakcageしているかを示しています。
パッケージがuseする他のパッケージはpackage-use-listを使って確認すること
ができます。userは、lispとeditorをuse-packageしています。

si:system-rootはsystemからexportされていますが、userがsystemを
use-packageしていないので修飾子が必要です。

  ;;; system-rootがsystemからexportされていることを確認する。
  (find-symbol "system-root" "system")
  => system:system-root
     :external

このためuserからsystem-rootを使用する場合には(si:system-root)という呼び
出し方になります。

使用例：
    ;;; 引数で指定された aset, file-name-sans-versions, ...は
    ;;; エクスポートされ、別のパッケージから参照できるようになる。
    (export '(aset file-name-directory file-name-nondirectory
          file-name-sans-versions))

備考：
  common-lisp パッケージと common-lisp-user パッケージは
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `パッケージ`, `use-package`, `どの関数の頭に何がつくのでしょうか？`

## `find-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find-package NAME`

```text
パッケージを名前で検索して、そのパッケージを返します。

  NAME : パッケージの名前

使用例：
  ;;; lispとsystemパッケージを取得してみる。
  (find-package "lisp")
  => #<package: lisp>
  (find-package "si")
  => #<package: system>

  ;;; "baz"という名のパッケージは存在しない
  (find-package "baz")
  => nil
```

関連: `パッケージ`, `list-all-packages`, `defpackage`, `delete-package`

## `find-symbol`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find-symbol STRING &optional PACKAGE`

```text
パッケージ中にシンボルが登録されているかを調べます。

  STRING  : シンボルの名前
  PACKAGE : パッケージの名前

戻り値は多値で返されます。

  nil     シンボルが見つからなかった場合はnilを返します。
  nil以外 シンボルが見つかった場合はそのシンボルをそのまま返します。

使用例：
  ;;; find-fileとfind-file-internalというシンボルを調べてみる。
  (find-symbol "find-file" "lisp")
  => nil
     nil
  (find-symbol "find-file" "editor")
  => find-file
     :external
  (find-symbol "find-file-internal" "editor")
  => editor::find-file-internal
     :internal
```

関連: `intern`, `パッケージ`

## `import`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `import SYMBOLS &optional PACKAGE`

```text
シンボルのリストを指定して、その全てのシンボルをパッケージ内でパッケージ
名指定なしでアクセスできるようにします。シンボルが既にパッケージ内に存在
する場合は例外を発生します。
```

関連: `パッケージ`

## `in-package`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `in-package NAME`

```text
どのパッケージで実行するかを変更します。変更した後に作られたシンボルは、
指定されたパッケージに登録されます。

使用例：
    ;;; これ以降新しく作られるシンボルは、"editor"パッケージに登録さ
    ;;; れるようになる。
    (in-package "editor")
```

関連: `use-package`, `パッケージ`, `*package*`

## `intern`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `intern STRING &optional PACKAGE`

```text
文字列からシンボルを作成します。作成したシンボルは指定されたパッケージに
internされます。make-symbolも文字列からシンボルを作り出しますが、パッケ
ージにinternされません。

  STRING  : 文字列
  PACKAGE : 作成したシンボルを登録するパッケージ

使用例：
  ;;; foobarというシンボルが*package*に登録される
  (intern "foobar")
  => foobar

  ;;; foobazというシンボルがlispパッケージに登録される。
  (intern "foobaz" (find-package "lisp"))
  => foobaz
```

関連: `find-symbol`, `symbol-name`, `unintern`, `make-symbol`, `パッケージ`

## `list-all-packages`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `list-all-packages`

```text
xyzzy内に存在するパッケージ一覧をリストで返します。

使用例：
  (list-all-packages)
  =>  (#<package: win-user> #<package: winapi> #<package: 
     foreign>  #<package: lisp> #<package: system> #<package: 
     keyword> #<package: user> #<package: editor>
     #<package: common-lisp> #<package: common-lisp-user>)

備考：
  common-lisp パッケージと common-lisp-user パッケージは
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `defpackage`, `si:list-builtin-packages`, `パッケージ`

## `make-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-package PACKAGE-NAME &key :nicknames :use :internal-size :external-size`

```text
パッケージを作成します。defpackageとの違いは？（詳細不明）

使用例：
  (make-package name :external-size 0)
```

関連: `defpackage`, `delete-package`, `rename-package`, `in-package`, `パッケージ`

## `package-name`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `package-name PACKAGE`

```text
パッケージの名称を取得します。

使用例：
  (package-name (find-package "ed"))
  => "editor"
```

関連: `package-nicknames`, `find-package`

## `package-use-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `package-use-list PACKAGE`

```text
指定されたパッケージが使用しているパッケージを返します

  PACKAGE : パッケージそのものもしくはパッケージ名の文字列

使用例：
  (package-use-list "user")
  =>(#<package: lisp> #<package: editor>)
```

関連: `package-used-by-list`, `use-package`

## `package-used-by-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `package-used-by-list PACKAGE`

```text
指定されたパッケージが使用されているパッケージを返します

  PACKAGE : パッケージそのものもしくはパッケージ名の文字列

使用例:
  (package-used-by-list (find-package "lisp"))
  =>(#<package: system> #<package: editor> #<package: user>)
```

関連: `use-package`, `package-use-list`

## `rename-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rename-package PACKAGE NEW-NAME &optional NEW-NICKNAMES`

```text
パッケージの名前と別名を変更します。

  PACKAGE       : パッケージを指定します。
  NEW-NAME      : 変更後の名前を指定します。
  NEW-NICKNAMES : 変更後の別名をリストで指定します。

使用例：

 (make-package 'temporary :nicknames '("temp"))
 => #<package: temporary>
 (rename-package 'temp 'ephemeral)
 => #<package: ephemeral>
 (package-nicknames (find-package 'ephemeral))
 => nil
 (find-package 'temporary)
 => nil
 (rename-package 'ephemeral 'temporary '(temp fleeting))
 => #<package: temporary>
 (package-nicknames (find-package 'temp))
 => ("fleeting" "temp")
```

関連: `defpackage`, `delete-package`, `in-package`, `パッケージ`

## `si:list-builtin-packages`

- Function / package: system / 定義: package.l
- 呼び出し: `list-builtin-packages`

```text
xyzzy内に存在する組み込みのパッケージ一覧をリストで返します。

使用例：
  (si:list-builtin-packages)
  => (#<package: lisp> #<package: system> #<package: keyword>
      #<package: user> #<package: editor> #<package: common-lisp>
      #<package: common-lisp-user>)

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `list-all-packages`, `si:*builtin-package-p`, `パッケージ`

## `unexport`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `unexport SYMBOLS &optional PACKAGE`

```text
シンボルのリストを指定して、その全てのシンボルをパッケージの外部から参照
できないようにします。

  ;; find-file は editor パッケージの外部シンボル
  (find-symbol "find-file" "editor")
  =>find-file
    :external

  ;; よって editor パッケージを use している user パッケージから参照できる
  (find-symbol "find-file" "user")
  =>find-file
    :inherited

  ;; 外部から参照できなくする
  (unepxport 'find-file "editor")
  =>t

  ;; 内部シンボルになった
  (find-symbol "find-file" "editor")
  =>editor::find-file
    :internal

  ;; user パッケージから参照できなくなった
  (find-symbol "find-file" "user")
  =>nil
    nil

  ;; 元に戻す
  (export 'ed::find-file "editor")
  =>t
```

関連: `export`, `パッケージ`

## `unintern`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `unintern SYMBOL &optional PACKAGE`

```text
パッケージにシンボルがあれば削除してtを、なければnilを返します。
```

関連: `intern`

## `uninterned`

- Misc

```text
uninterned とは intern されていない状態を表します。
すなわちどのパッケージにも属していない状態です。

使用例：
  ;;; make-symbolでパッケージに属さないシンボルを作ってみる。
  (setq a (make-symbol "foo"))  => #:foo
  (symbol-package a)            => nil
```

関連: `make-symbol`, `gensym`

## `unuse-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `unuse-package PACKAGES-TO-UNUSE &optional PACKAGE`

```text
パッケージが別のパッケージを使用しないようにします。

使用例：
  ;;; 使用例はcalc.lを参照
  (unuse-package "lisp" *calc-package*)
  => t
```

関連: `use-package`

## `use-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `use-package PACKAGES-TO-USE &optional PACKAGE`

```text
指定されたパッケージ（省略された場合はカレントのパッケージ）が使
用する他のパッケージを設定します。
```

関連: `export`, `defpackage`, `パッケージ`

## `with-package-iterator`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `with-package-iterator (MNAME PACKAGE-LIST &rest SYMBOL-TYPE) &body BODY`

```text
指定されたパッケージのシンボルを列挙する関数を作ってもらいます。
作られた関数を呼び出すたびにシンボルが列挙されます。

  MNAME        : シンボルを返す関数名を指定します。
  PACKAGE-LIST : パッケージのリストを指定します。
  SYMBOL-TYPE  : どんなシンボルを返すかを指定するようです。

使用例：
  ;;; 全シンボルを列挙します。
  ;;; 呼ぶたびに次のシンボルを返すfooという関数を定義してもらう。
  (with-package-iterator (foo (list-all-packages) :internal :external)
    (loop
      (multiple-value-bind (f sym type package)
          (foo)             ; 呼ぶと次のシンボルが返ってくる。
        (unless f           ; なければ終わり。
          (return))
        (and (or (boundp sym)
                 (fboundp sym))
             (format t "~:[ ~;V~]~:[ ~;F~]~:[ ~;M~] ~A ~S ~S~%"
                     (boundp sym)
                     (fboundp sym)
                     (macro-function sym)
                     (package-name package)
                     sym
                     type)))))
```

関連: `do-all-symbols`

## `どの関数の頭に何がつくのでしょうか？`

- Tips

```text
| パッケージという概念に関係があるんだと思いますが、どの関数の頭に何がつくの
| かというのはどこを見ればわかるんでしょうか。

  M-x apropos make-chunk RET

としたときに、

  system:make-chunk

のように表示されるものはパッケージが必要なものです。ちなみに、
si は system パッケージの、c は foreign パッケージのニックネー
ムです。
----------------------------------

  editor::xyzzy-mode  `:'が2つ表示される場合はexportされていない
        ^^
  editor:xyzzy-mode   `:'が1つ表示される場合はexportされている
        ^
  xyzzy-mode          パッケージが表示されない場合は現在のパッケージから
                      直接アクセスできる
```

関連: `パッケージの概要`

## `パッケージ`

- Tips

```text
パッケージは簡単に言うと、いわゆる oblist とか obarray といったものが
いっぱいあって、リーダがシンボルを読んだときにどの obarray を使って
find-symbol や intern をするかを指定するものです。

さらに、一つのパッケージに 内部用と外部用の二つの obarray があり、通常
は内部用に intern されます。関数 export で、内部用から外部用に移動するこ
とができます。

内部用と外部用の違いは、パッケージを作るときに(作るときじゃなくてもい
いけど)他のパッケージを使用(use)すると宣言すると、ある名前を find-symbol
するときに、そのシンボルが指定されたパッケージに存在しない場合、そのパッ
ケージが使用しているパッケージの外部用にあるかを見にいくようになっています。

exportの仕組み：
  exportしても全部のパッケージから見えるわけじゃなくて、そのパッ
  ケージをuseしているパッケージから見えるようになるだけです。

  (package-use-list "user")
  => (#<package: lisp> #<package: editor>)

  (package-use-list "editor")
  => (#<package: lisp>)

  なので、editorパッケージから見えるのは、editorのシンボルとlispのexportさ
  れたシンボルだけです。
  ※「見える」というのはパッケージの修飾子なしで参照できるという意味合いです。
```

関連: `どの関数の頭に何がつくのでしょうか？`, `export`, `use-package`, `パッケージの概要`

## `パッケージの概要`

- Tips

```text
パッケージには外部から参照されるシンボル用の空間と、内部のシンボル用の空
間があります。シンボルは最初は内部に登録されます。exportすると外部に移動
させられます。
     system        lisp        editor        user
   ┌───┐   ┌───┐   ┌───┐   ┌───┐
   │s-exp │   │l-exp │   │e-exp │   │u-exp │ <- 外部
   ├───┤   ├───┤   ├───┤   ├───┤
   │s-int │   │l-int │   │e-int │   │u-int │ <- 内部
   └───┘   └───┘   └───┘   └───┘


通常は user で作業をしています。 user は lisp, editor を利用すると宣言し
ています。そのため、l-exp, e-exp, u-exp, u-int に登録されたシンボルをパ
ッケージの修飾子無しで参照できるようになっています（太枠の部分です）。
     system        lisp        editor        user
   ┌───┐   ┏━━━┓   ┏━━━┓   ┏━━━┓
   │s-exp │   ┃l-exp ┃   ┃e-exp ┃   ┃u-exp ┃ <- 外部
   ├───┤   ┗━━━┛   ┗━━━┛   ┠───┨
   │s-int │   │l-int │   │e-int │   ┃u-int ┃ <- 内部
   └───┘   └───┘   └───┘   ┗━━━┛


プログラムを書いて新しいシンボルが出てくると、u-int に登録されます。
(in-package "editor") を実行後にシンボルを書くと e-int に登録されます。
     system        lisp        editor        user
   ┌───┐   ┏━━━┓   ┏━━━┓   ┏━━━┓
   │      │   ┃      ┃   ┃      ┃   ┃      ┃ <- 外部
   │ ...  │   ┃ ...  ┃   ┃ ...  ┃   ┃ ...  ┃
   ├───┤   ┗━━━┛   ┗━━━┛   ┠───┨
   │      │   │      │   │ bar  │   ┃ foo  ┃ 
   │ ...  │   │ ...  │   │ ...  │   ┃ ...  ┃ <- 内部
   └───┘   └───┘   └───┘   ┗━━━┛
このあたりまでは分かりやすいと思うのですが、難しいのは「自分(editor)を
useしているパッケージ(user)に既にあるシンボル(foo)をexportしようとしてエ
ラーがでる」というトラブルです。


u-intとe-intのそれぞれにfooというシンボルを定義している状態を考えます。
この状態自体は問題ありませんが、この状態でeditor::fooをexportしようとす
るとエラーが発生します。
     system        lisp        editor        user
   ┌───┐   ┏━━━┓   ┏━━━┓   ┏━━━┓
   │      │   ┃      ┃   ┃  Ｘ  ┃   ┃      ┃ <- 外部
   │ ...  │   ┃ ...  ┃   ┃ .↑  ┃   ┃ ...  ┃
   ├───┤   ┗━━━┛   ┗━│━┛   ┠───┨
   │      │   │      │   │ foo  │   ┃ foo  ┃ 
   │ ...  │   │ ...  │   │ ...  │   ┃ ...  ┃ <- 内部
   └───┘   └───┘   └───┘   ┗━━━┛
user が参照可能な範囲からすると、u-intに既にあるシンボルと同じ名前のシン
ボルがe-expに入れられようとするため、「名前が衝突するためexportできませ
ん: editor::foo」と怒られます。

  (setq foo "user")
  => "user"
  (setq ed::foo "editor")
  => "editor"
  (export '(ed::foo) "ed")
  => 名前が衝突するためexportできません: editor::foo

これ以外にもこんな形でも起きます。lisp::fooとeditor::fooの間の問題のよう
ですが、実はuserがlispとeditorをuseしていることが原因です。
     system        lisp        editor        user
   ┌───┐   ┏━━━┓   ┏━━━┓   ┏━━━┓
   │      │   ┃ foo  ┃   ┃  Ｘ  ┃   ┃      ┃ <- 外部
   │ ...  │   ┃ ...  ┃   ┃ .↑  ┃   ┃ ...  ┃
   ├───┤   ┗━━━┛   ┗━│━┛   ┠───┨
   │      │   │      │   │ foo  │   ┃      ┃ 
   │ ...  │   │ ...  │   │ ...  │   ┃ ...  ┃ <- 内部
   └───┘   └───┘   └───┘   ┗━━━┛
```

関連: `パッケージ`
