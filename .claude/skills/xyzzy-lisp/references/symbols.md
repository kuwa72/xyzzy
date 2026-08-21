# シンボル (symbols)

reference/reference.xml から自動生成。25 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*apropos-no-regexp*`

- Variable / package: editor / 定義: help.l

```text
non-nil に設定すると、apropos 実行時に、正規表現のメタ文字はエスケープさ
れます。デフォルトは nil です。
```

関連: `apropos`

## `*gensym-counter*`

- Variable / package: lisp / 定義: evalmacs.l

```text
gensym で作られるシンボルの名前につく数字です。
使われるたびにインクリメントされます。
```

関連: `gensym`

## `apropos`

- Function / package: editor / 定義: help.l
- 呼び出し: `apropos STRING &optional PRINT-KEY PRED`

```text
指定した正規表現に一致するシンボルの一覧を表示します。

  STRING    : 検索する文字列
  PRINT-KEY : バインドされているキーを表示するかどうか
        non-nil : 表示する
        nil     : 表示しない
  PRED      : ？？？
```

関連: `*apropos-no-regexp*`, `command-apropos`

## `boundp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `boundp SYMBOL`

```text
シンボルに値が設定されているかどうかを返します。

使用例：
  (boundp 'test)          => nil
  (defvar test "string")  => test
  (boundp 'test)          => t
```

関連: `fboundp`, `macro-function`, `makunbound`

## `command-apropos`

- Function / package: editor / 定義: help.l
- 呼び出し: `command-apropos STRING`

```text
指定した正規表現に一致する interactive 宣言されている関数の一覧を表示し
ます。バインドされたキーがあれば、同時に表示します。
```

関連: `apropos`

## `copy-symbol`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-symbol SYMBOL &optional COPY-PROPS`

```text
同じ名前を持つuninternedなSYMBOLのコピーを返します。
COPY-PROPSがnon-nilなら、初期定義値、プロパティリストもコピーされます。
```

関連: `uninterned`

## `default-value`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `default-value SYMBOL`

```text
シンボルのデフォルトの値を返します。
シンボルがバッファローカルでないならば、symbol-valueと同じ値を返します。
シンボルがバッファローカルの時にデフォルトの値を持たない場合には、エラー
になります。デフォルトの値はsetq-defaultで指定します。

使用例：
  ;;; シンボルがデフォルトの値を持たない場合
  (make-local-variable 'foo)    => t
  (setq foo 123)                => 123
  (default-value 'foo)          => 変数が定義されていません: foo

  ;;; バッファローカルなシンボルの場合
  (defvar-local bar 234)        => bar
  (setq bar 345)                => 345
  (default-value 'bar)          => 234
```

関連: `symbol-value`, `setq-default`

## `describe-function`

- Function / package: editor / 定義: help.l
- 呼び出し: `describe-function SYMBOL`

```text
指定された関数の引数と docstring を表示します。
```

関連: `describe-variable`

## `describe-variable`

- Function / package: editor / 定義: help.l
- 呼び出し: `describe-variable SYMBOL`

```text
指定された変数の現在の値、種類(constant or special)および docstring を表
示します。
```

関連: `describe-function`

## `fboundp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fboundp SYMBOL`

```text
シンボルに関数が定義されているかどうかを返します。

使用例：
  (fboundp 'car)
  => t
  (fboundp 't)
  => nil
```

関連: `boundp`, `fmakunbound`, `macro-function`

## `find-all-symbols`

- Function / package: lisp / 定義: package.l
- 呼び出し: `find-all-symbols NAME`

```text
印字名が NAME であるようなシンボルを各パッケージから探します。
戻り値は見つかったシンボルのリストです。

使用例：
  (find-all-symbols "y")
  => (editor::y system::y lisp::y winapi::y)

  (find-all-symbols "system-root")
  => (system:system-root)

  (find-all-symbols "test")
  => (editor::test test :test lisp::test)
```

関連: `find-symbol`

## `gensym`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `gensym &optional X`

```text
uninterned なシンボルを生成します。印字名は G の後に *gensym-counter* の
値をつなげたものです。

引数 X を指定すると、
  X が整数のときは *gensym-counter* の代わりに X の値が使われます。
  X が文字列のときは "G" の代わりに X の値が使われます。
```

関連: `*gensym-counter*`, `make-symbol`, `unintern`, `uninterned`

## `gentemp`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `gentemp &optional (PREFIX t) (PACKAGE *package*)`

```text
intern されたシンボルを生成します
PACKAGE に intern された PREFIX と内部カウンタをつなげたシンボルを返します

必ず衝突しないシンボルを生成します。
```

関連: `gensym`, `intern`

## `get`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get SYMBOL INDICATOR &optional DEFAULT`

```text
シンボルのプロパティを返します。

  SYMBOL    : プロパティを返すシンボル
  INDICATOR : プロパティのインジケータ

使用例：
  ;;; シンボルにプロパティを設定してみる。
  (get 'clyde 'species)                         => nil 
  (setf (get 'clyde 'species) 'elephant)        => elephant 
  (get 'clyde 'species)                         => elephant

  ;;; 関数の説明を取得してみる。
  (defun foo (x) "increment" (1+ x))            => foo
  (get 'foo 'lisp::function-documentation)      => "increment"
```

関連: `symbol-plist`, `remprop`

## `get-properties`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-properties PLACE INDICATOR-LIST`

```text
2番目の引数がリストになっているgetfです。
一致すると多値で値を返します。

使用例：
  ;;; get-propertiesで値を取得してみる。
  (get-properties '(ind1 10 ind2 20 ind3 30) '(ind2))
  => ind2
     20
     (ind2 20 ind3 30)
```

関連: `getf`

## `getf`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `getf PLACE INDICATOR &optional DEFAULT`

```text
インジケータと値のリストから、インジケータに一致する値を取得します。

  (get x y) == (getf (symbol-plist x) y)

使用例：
  ;;; 実用性は無いけれどgetfを使って取得してみる。
  (getf '(ind1 10 ind2 20 ind3 30) 'ind2)
  => 20
```

関連: `get-properties`, `symbol-plist`

## `lisp-complete-symbol`

- Function / package: editor / 定義: lispmode.l
- 呼び出し: `lisp-complete-symbol`

```text
Lisp のシンボル名を補完します。[ESC TAB]
```

関連: `*lisp-popup-completion-list*`

## `lisp-indent-hook`

- Misc / package: editor

```text
シンボルにプロパティを設定することで lisp-indent-line でのインデント量を制御します。

  数値 n   : n 番目以降の引数を *lisp-body-indent* だけ、
             それより前の引数を (* *lisp-body-indent* 2) だけインデント
  nil      : 通常のインデント
             ただし1番目の引数のインデント量は *lisp-indent-offset* に従う
  それ以外 : すべての引数を *lisp-body-indention* だけインデント

使用例：
  ;;; $XYZZY/lisp/lispmode.l から
  (setf (get 'lambda 'lisp-indent-hook) 'defun)
  (setf (get 'interactive 'lisp-indent-hook) 1)
  (setf (get 'progn 'lisp-indent-hook) 0)
  (setf (get 'if 'lisp-indent-hook) 2)
  (setf (get 'let 'lisp-indent-hook) 1)
  (setf (get 'let* 'lisp-indent-hook) 1)
```

## `make-symbol`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-symbol PRINT-NAME`

```text
印字名がPRINT-NAMEであるuninternedなシンボルを返します。

参考：
  evalmacs.l
```

関連: `intern`, `gensym`, `symbol-package`, `uninterned`

## `remprop`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `remprop SYMBOL INDICATOR`

```text
シンボルのプロパティを削除します。

  SYMBOL    : プロパティを返すシンボル
  INDICATOR : プロパティのインジゲーター

使用例：
  ;;; 関数の説明を削除してみる。
  (defun foo (x) "increment" (1+ x))            => foo
  (get 'foo 'lisp::function-documentation)      => "increment"
  (remprop 'foo 'lisp::function-documentation)  => t
  (get 'foo 'lisp::function-documentation)      => nil
```

関連: `get`

## `symbol-name`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbol-name SYMBOL`

```text
シンボルの名前を印字用の文字列として返します。

使用例：
  ;;; シンボルxyzzyを文字列にしてみる。
  (symbol-name 'xyzzy)
  => "xyzzy"
```

関連: `intern`, `string`

## `symbol-package`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbol-package SYMBOL`

```text
シンボルが属するパッケージを返します。
make-symbol とか gensym で生成されたシンボルはどのパッケージにも属しません。

使用例：
  ;;; uninternedなシンボルとそうでないシンボルを作ってみる。
  (setq foo 2)                          => foo
  (symbol-package 'foo)                 => #<package: user>
  
  (setq bar (make-symbol "bar"))        => #:bar
  (set bar 3)                           => 3
  (symbol-value bar)                    => 3
  (symbol-package bar)                  => nil
```

関連: `make-symbol`, `gensym`, `intern`

## `symbol-plist`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbol-plist SYMBOL`

```text
シンボルのプロパティリストを返す。

使用例：
  ;;; シンボルのプロパティリストを見てみる。
  (symbol-plist 'xyzzy)         => nil
  (setf (get 'xyzzy 'foo) 1)    => 1
  (symbol-plist 'xyzzy)         => (foo 1)
```

関連: `get`

## `symbol-value`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbol-value SYMBOL`

```text
シンボルが束縛されている値を返します。
局所変数の値は参照できません。

  SYMBOL : 値を返すシンボル

使用例：
  ;;; foo というシンボルの値を返してみる
  (set 'foo 3)          => 3
  (symbol-value 'foo)   => 3
  foo                   => 3
  ;;; 局所変数は参照できない
  (let ((foo 1))
    (symbol-value 'foo)) => 3
```

関連: `symbol-function`, `default-value`, `buffer-local-value`

## `型一覧`

- Misc

```text
型は綺麗に階層構造を成す訳ではないのですが、subtypepでロジックに組み込ま
れているところから、嘘にならない程度に階層化したものです。[]付きの物は二
重に出現しています。

  list                                  リスト
  ├null                                ヌル
  └cons                                コンス
  atom                                  アトム
  ├number                              数値
  │├real                              実数
  ││├rational                        有理数
  │││├ratio                         分数
  │││└integer                       整数
  │││  └bignum                      －
  ││└float                           浮動小数点数
  ││  ├short-float                   小精度浮動小数点数
  ││  ├single-float                  単精度浮動小数点数
  ││  ├double-float                  倍精度浮動小数点数
  ││  └long-float                    長精度浮動小数点数
  │└complex                           複素数
  ├symbol                              シンボル
  │├[null]                            －
  │└keyword                           キーワード
  ├character                           文字
  │├base-character                    －
  ││└standard-char                   標準文字
  │└extended-character                －
  ├stream                              ストリーム
  │├two-way-stream                    双方向ストリーム
  │├echo-stream                       －
  │├broadcast-stream                  －
  │├file-stream                       ファイルストリーム
  │├synonym-stream                    文字列ストリーム
  │├string-stream                     －
  │└concatenated-stream               －
  ├sequence                            シーケンス
  │├[list]                            －
  │└[vector]                          －
  └array                               配列
    ├simple-array                      単純配列
    │└simple-string                   単純文字列
    └vector                            ベクタ
      ├simple-vector                   単純ベクタ
      └string                          文字列
        └[simple-string]               －

使用例：
  ;;; listはsequenceで、sequenceはatomだけど、listはatomではない。
  (subtypep 'list 'sequence)    => t
  (subtypep 'sequence 'atom)    => t
  (subtypep 'list 'atom)        => nil

参考：
  typespec.l
```

関連: `deftype`, `subtypep`, `type-of`, `typep`
