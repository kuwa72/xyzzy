# データ型 (datatypes)

reference/reference.xml から自動生成。55 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `alpha-char-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `alpha-char-p CHAR`

```text
文字が英字[A-Za-z]かどうかを判定します。

  CHAR : 判定する文字
```

関連: `both-case-p`, `alphanumericp`, `characterp`

## `alphanumericp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `alphanumericp CHAR`

```text
文字が英数字[A-Za-z0-9]かどうかを判定します。

  CHAR : 判定する文字
```

関連: `alpha-char-p`, `characterp`

## `arrayp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `arrayp OBJECT`

```text
OBJECT が array なら t 、それ以外なら nil を返します。
```

## `atom`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `atom OBJECT`

```text
OBJECTがconsでなければt、それ以外ならnilを返します。

  (atom x) == (typep x 'atom) == (not (typep x 'cons))

注意：(atom '()) は '() == nilなのでt
```

関連: `consp`

## `characterp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `characterp OBJECT`

```text
OBJECT が character なら t 、それ以外なら nil を返します。
```

関連: `alpha-char-p`, `alphanumericp`, `digit-char-p`, `kana-char-p`, `kanji-char-p`, `standard-char-p`, `extended-alphabet-char-p`, `word-char-p`

## `check-type`

- Macro / package: lisp / 定義: condition.l
- 呼び出し: `check-type PLACE TYPESPEC &optional STRING`

```text
（詳細不明）

使用例：
  ;;; nの型チェックをしてみる。
  (check-type n integer)
```

## `coerce`

- Function / package: lisp / 定義: typespec.l
- 呼び出し: `coerce OBJECT TYPE`

```text
OBJECT を TYPE 型に変換します。

TYPE はシンボルまたはリストで、それぞれ以下の型に変換されます。
  'list         ──→ リスト
  'array        ─┬→ 配列
  'simple-array ─┘
  'character    ──→ 文字
  'float        ─┬→ 単精度浮動小数点数
  'short-float  ─┤
  'single-float ─┘
  'double-float ─┬→ 倍精度浮動小数点数
  'long-float   ─┘
  'complex      ──→ 複素数
  'function     ──→ 関数
リストの場合、その最初の要素で型が決まります。
2番目以降の要素は、最初の要素が array、simple-array、complex の場合のみ
意味を持ち、それぞれ以下のように動作します。
  '(array ...)        ─┬→ make-sequence の TYPE と同じ
  '(simple-array ...) ─┘
  '(complex ...)      ──→ 実部、虚部を二番目の要素の型に変換
  
使用例:
  (coerce "abc" 'list)                         ; 文字列を文字のリストに
  => (#\a #\b #\c)
  (coerce #(1 2 3) 'list)                      ; 配列をリストに
  => (1 2 3)
  (coerce '(a b c) '(array t 1))               ; リストを配列に
  => #(a b c)
  (coerce "abc" '(array t 1))                  ; 文字列を文字の配列に
  => #(#\a #\b #\c)
  (coerce '(#\a #\b #\c) '(array character 1)) ; 文字のリストを文字列に
  => "abc"
  (coerce "abc" '(array character 1))          ; 意味なし
  => "abc"

  (coerce "a" 'character)                      ; 文字列を文字に
  => #\a
  
  (coerce 1 'float)
  => 1.0
  (coerce 1 'double-float)
  => 1.0d0
  (coerce 1.0 'complex)
  => #C(1.0 0.0)
  (coerce #C(1 2) '(complex float))            ; 単精度の複素数に
  => #C(1.0 2.0)
  
  (coerce 'let 'function)                      ; シンボル名の関数を返す
  => #<function: let>
  (coerce '(lambda (x) (* x 2)) 'function)     ; 関数を作ることも
  => #<lexical-closure: (anonymous)>
  (funcall (coerce '(lambda (x) (* x 2)) 'function) 12)
  => 24
```

関連: `type-of`

## `compiled-function-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `compiled-function-p OBJECT`

```text
OBJECTがcompiled code objectならt、それ以外ならnilを返します。

使用例：
  ;;; carの型を調べてみる。
  (type-of #'car)
  => compiled-function
  (compiled-function-p #'car)
  => t
```

## `complexp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `complexp OBJECT`

```text
OBJECT が complex number なら t 、それ以外なら nil を返します。
```

## `consp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `consp OBJECT`

```text
OBJECTがconsならt、それ以外ならnilを返します。

  (consp x) == (typep x 'cons) == (not (typep x 'atom))

注意： (consp '()) は '() == nilなのでnil。
```

関連: `atom`

## `deftype`

- Macro / package: lisp / 定義: typespec.l
- 呼び出し: `deftype NAME (&rest LAMBDA-LIST) &rest BODY`

```text
NAME と言う名前のデータ型を定義します。
定義したデータ型は typep や subtypep などで使うことができます。
ただし typep で使う場合には、使用前に si:canonicalize-type で
処理することが必要なようです。

使用例:
  ;; lisp/typespec.l より
  ;; mod という型を定義
  (deftype mod (n)
    `(integer 0 ,(1- n))) ; 0 以上 n 未満の整数
  (typep 3 (si:canonicalize-type '(mod 5)))
  => t

  ;; 奇数型を作ってみる
  (deftype odd ()
    `(and integer
          (satisfies oddp)))
  (typep 3 (si:canonicalize-type 'odd))
  => t
  (subtypep 'odd 'integer)
  => t
  => t
```

関連: `si:canonicalize-type`, `subtypep`, `typep`, `型一覧`

## `double-float-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `double-float-p OBJECT`

```text
OBJECT が double-float なら t 、それ以外なら nil を返します。
```

## `eq`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `eq X Y`

```text
X と Y が同一オブジェクトならt、そうでないならnilを返します。数値や文字
列に対しては見かけ上同じでもtとなる保証はありません。xyzzyでは、数値はt
となるが文字列ではnilとなるように実装されているようです。

使用例：
  ;;; eqで比較してみる。
  (eq 'foo 'foo)        => t    ; 仕様
  (eq 2 2)              => t    ; 処理系依存
  (eq "foo" "foo")      => nil  ; 処理系依存
  (eq '(1 2) '(1 2))    => nil  ; 処理系依存
```

関連: `eql`, `equal`, `equalp`

## `eql`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `eql X Y`

```text
X と Y が同一オブジェクトか、同じ型の数値または文字型で値が等しいかを返
します。等しければtを、そうでなければnilを返します。eqとは異なり、値とし
て等しいかを判断します。ただし、中身までは見ないので文字列は対象外となり
ます。

使用例：
  ;;; eqlで比較してみる。
  (eql 'foo 'foo)       => t    ; 仕様
  (eql 2 2)             => t    ; 仕様
  (eql "foo" "foo")     => nil  ; 処理系依存
  (eql '(1 2) '(1 2))   => nil  ; 処理系依存
```

関連: `eq`, `equal`, `equalp`, `char=`

## `equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `equal X Y`

```text
X と Y が同じ構造を持っていればtを、そうでなければnilを返します。

使用例：
  ;;; equalで比較してみる。
  (equal 'foo 'foo)     => t    ; 仕様
  (equal 2 2)           => t    ; 仕様
  (equal "foo" "foo")   => t    ; 仕様
  (equal '(1 2) '(1 2)) => t    ; 仕様
```

関連: `eq`, `eql`, `equalp`, `=`, `char=`, `string=`

## `equalp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `equalp X Y`

```text
equalと同じように X と Y を比較します。
ただし、一部の差異を許容します。
例えば文字・文字列の比較では大文字と小文字を区別しません。

使用例：
  ;;; equalpで比較してみる。
  (equalp "Foo" "foo")  => t
```

関連: `eq`, `eql`, `equal`, `=`, `char-equal`, `string-equal`

## `extended-alphabet-char-p`

- Function / package: editor
- 呼び出し: `extended-alphabet-char-p CHAR`

```text
CHAR が欧文(ISO8859)の単語構成文字かを判定します。
```

関連: `characterp`

## `floatp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `floatp OBJECT`

```text
OBJECTがfloatならt、それ以外ならnilを返します。
```

関連: `numberp`

## `functionp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `functionp OBJECT`

```text
OBJECTが関数ならt、それ以外ならnilを返します。
```

## `graphic-char-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `graphic-char-p CHAR`

```text
CHAR が印字文字かどうかを判定します。

  (graphic-char-p #\A)
  =>t
  (graphic-char-p #\SPC)
  =>t
  (graphic-char-p #\TAB)
  =>nil
```

## `integerp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `integerp OBJECT`

```text
OBJECTがintegerならt、それ以外ならnilを返します。

  (integerp x) == (typep x 'integer)
```

関連: `numberp`

## `kana-char-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kana-char-p CHAR`

```text
文字が半角カナ文字かを返します。

  t    半角カナ文字である。
  nil  半角カナ文字でない。

カナ文字は以下の範囲です。
  Code          Char
  ----          ----
  0xa1 .. 0xb0  #\｡ .. #\ｰ
  0xb1 .. 0xdd  #\ｱ .. #\ﾝ
  0xde          #\ﾞ
  0xdf          #\ﾟ
```

関連: `kanji-char-p`, `characterp`

## `kanji-char-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kanji-char-p CHAR`

```text
文字CHARが漢字かを返します。
（詳細不明）
```

関連: `kana-char-p`, `characterp`

## `keymapp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `keymapp OBJECT`

```text
指定されたOBJECTがキーマップかを返します。

  non-nil   OBJECTはキーマップ
  nil       OBJECTはキーマップではない
```

関連: `make-keymap`

## `keywordp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `keywordp OBJECT`

```text
与えられたオブジェクト OBJECT がキーワードか否かを返します。 OBJECT がシ
ンボルであり、かつ keyword パッケージに所属するときに t を返しているよう
です。

  (symbol-package 'a)
  =>#<package: user>
  (symbol-package :a)
  =>#<package: keyword>
  
  (symbolp 'a)
  =>t
  (keywordp 'a)
  =>nil
  
  (symbolp :a)
  =>t
  (keywordp :a)
  =>t
```

## `listp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `listp OBJECT`

```text
OBJECTがconsか空リスト()ならt、それ以外ならnilを返します。

  (listp x) == (typep x 'list) == (typep x '(or cons null))
```

## `local-variable-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `local-variable-p SYMBOL &optional BUFFER`

```text
指定されたシンボルがバッファローカル変数かどうかを判定します。

使用例：
  ;;; buffer: foo
  (local-variable-p 'abc)
  => nil
  (make-local-variable 'abc)
  => t
  (local-variable-p 'abc)
  => t

  ;;; buffer: bar
  (local-variable-p 'abc)
  => nil
```

関連: `make-local-variable`, `defvar-local`

## `long-float-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `long-float-p OBJECT`

```text
OBJECTがlong-floatならt、それ以外ならnilを返します。
```

## `markerp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `markerp OBJECT`

```text
指定されたOBJECTがマーカーかを返します。

  t     OBJECTはマーカー
  nil   OBJECTはマーカーではない
```

関連: `make-marker`

## `null`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `null OBJECT`

```text
OBJECTが()ならば t 、それ以外なら nil を返します。

  (null x) == (typep x 'null) == (eq x '())
```

関連: `not`, `endp`

## `numberp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `numberp OBJECT`

```text
OBJECTが数値ならばt、それ以外ならnilを返します。

  (numberp x) == (typep x 'number)
```

関連: `integerp`, `floatp`

## `oledatap`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `oledatap OBJECT`

```text
OBJECTがOLEオブジェクトならばt、それ以外ならnilを返します。

  (oledatap x) == (typep x 'oledata)
```

関連: `OLEオートメーションの使用例`

## `packagep`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `packagep OBJECT`

```text
OBJECTがpackageならt、それ以外ならnilを返します。

使用例：
  ;;; 指定された文字列のパッケージがあるかを調べる。
  (setq pkg (find-package "win32"))     => nil
  (packagep pkg)                        => nil
  (setq pkg (find-package "winapi"))    => #<package: winapi>
  (packagep pkg)                        => t
```

## `processp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `processp OBJECT`

```text
指定されたOBJECTがプロセスかを返します。

  t     OBJECTはプロセス
  nil   OBJECTはプロセスではない
```

## `rationalp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rationalp OBJECT`

```text
OBJECTがratioかintegerならt、それ以外ならnilを返します。

  (rationalp x) == (typep x 'rational)
```

## `realp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `realp OBJECT`

```text
OBJECT が real number なら t 、それ以外なら nil を返します。
```

## `regexpp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `regexpp OBJECT`

```text
指定されたOBJECTがコンパイル済み正規表現かを返します。

  t     OBJECTはコンパイル済み正規表現
  nil   OBJECTはコンパイル済み正規表現ではない
```

関連: `compile-regexp`

## `sequencep`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `sequencep OBJECT`

```text
OBJECT が sequence なら t 、そうでなければnilを返します。
```

## `short-float-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `short-float-p OBJECT`

```text
OBJECTがshort-floatならt、それ以外ならnilを返します。
```

## `si:*builtin-function-p`

- Function / package: system / 定義: builtin.l
- 呼び出し: `*builtin-function-p OBJECT`

```text
オブジェクトがビルトイン関数かどうかを調べます。

使用例：
  ;;; carを調べてみる。
  (si:*builtin-function-p #'car)
  => t
```

## `si:*builtin-package-p`

- Function / package: system / 定義: package.l
- 呼び出し: `*builtin-package-p OBJECT`

```text
オブジェクトがビルトイン・パッケージかどうかを調べます。

使用例：
  ;;; lisp パッケージを調べてみる。
  (si:*builtin-package-p :lisp)
  => t
  (si:*builtin-package-p "editor")
  => t
  (si:*builtin-package-p (find-package :user))
  => t

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `si:list-builtin-packages`

## `si:canonicalize-type`

- Function / package: system / 定義: typespec.l
- 呼び出し: `canonicalize-type TYPE`

```text
deftype で宣言されたデータ型 TYPE を展開し、標準の型に直します。

たとえば typep は標準の型しか処理しないため、
deftype で宣言された型を使いたい場合にはこの関数で処理する必要があります。

使用例:
  (si:canonicalize-type '(mod 5))
  => (integer 0 4)
```

関連: `deftype`, `typep`

## `simple-string`

- Misc / package: lisp

```text
simple-string とはシンプルな文字列のことを指します。
共有可能でなく、フィルポインタを持たず、サイズ変更不可能な文字列のことで
す。formatやconcatを使って文字列を操作する場合にはsimple-stringのままです。

使用例：
  ;;; simple-stringの場合
  (type-of "abc") 
  => simple-string
```

関連: `simple-string-p`, `schar`

## `simple-string-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `simple-string-p OBJECT`

```text
OBJECTがsimple-stringならt、それ以外ならnilを返します。

使用例：
  ;;; make-vectorを使ってsimple-stringでないstringを作ります。
  (setq var1 (make-vector 10 :element-type 'character)
        var2 (make-vector 10 :element-type 'character :fill-pointer 0))
  => ""
  (type-of var1)                => simple-string
  (type-of var2)                => string
  (simple-string-p var1)        => t
  (simple-string-p var2)        => nil
```

関連: `simple-string`

## `simple-vector-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `simple-vector-p OBJECT`

```text
OBJECTがsimple-vectorならt、それ以外ならnilを返します。
```

関連: `vectorp`

## `single-float-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `single-float-p OBJECT`

```text
OBJECTがsingle-floatならt、それ以外ならnilを返します。
```

## `standard-char-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `standard-char-p CHAR`

```text
文字が、改行文字もしくは [ -~] かどうかを判定します。
表示可能な文字は SJIS 文字コードで 10, 32-126 です。

  CHAR : 判定する文字

戻り値：
  t   standard-char である
  nil standard-char でない

補足：
  ;;; 改行文字(SJIS 10) 以外の standard-char 文字一覧出力 (SJIS 32-126)
  (do ((i (char-code #\SPC) (1+ i)))
      ((= i (char-code #\DEL)))
    (format t "~A" (code-char i)))
```

関連: `characterp`

## `stringp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `stringp OBJECT`

```text
OBJECTがstringならt、それ以外ならnilを返します。
```

## `subtypep`

- Function / package: lisp / 定義: typespec.l
- 呼び出し: `subtypep TYPE1 TYPE2`

```text
ある型が他の型の副型かどうか調べて多値で返します。
（詳細不明）

  TYPE1 : 副型を指定します。
  TYPE2 : 型を指定します。

  t   t         TYPE1は明確にTYPE2の副型
  nil t         TYPE1は明確にTYPE1の副型ではない
  nil nil       関係を判断できない

使用例：
  ;;; サブタイプかどうかを調べる。
  (subtypep 'single-float 'number)
  => (single-float double-float long-float)
  (subtypep 'cons 'number)
  => nil
```

関連: `deftype`, `typep`, `型一覧`

## `symbolp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbolp OBJECT`

```text
OBJECTがsymbolならt、それ以外ならnilを返します。

  (symbolp x) == (typep x 'symbol)
```

## `type-of`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `type-of OBJECT`

```text
与えられたオブジェクトの型を返します。
(typep OBJECT (type-of OBJECT))は必ずtになります。

使用例：
  ;;; それぞれの型を調べてみる。
  (type-of 1)
  => integer
  (type-of 2.2)
  => single-float
  (type-of #'car)
  => compiled-function
```

関連: `型一覧`

## `typep`

- Function / package: lisp / 定義: typespec.l
- 呼び出し: `typep OBJECT TYPE`

```text
OBJECT が TYPE の型であれば、non-nil な値を返します。

TYPE に与えることのできる引数には以下のようなものがあります。

1. 一般の型 
  builtin 関数（characterp、listp など）で判定します。

  'atom                'null           'ed:buffer
  'base-character      'number         'ed:marker
  'bignum              'package        'ed:process
  'character           'random-state   'ed:regexp
  'compiled-function   'ratio          'ed:syntax-table
  'cons                'real           'ed:menu
  'fixnum              'readtable      'ed:dde-handle
  'function            'sequence       'ed:window
  'hash-table          'stream         'ed:oledata
  'keyword             'symbol
  'list

2. 条件式・複合型
  条件を満たす場合に non-nil な値を返します。

  '(satisfies FUNC)      OBJECT を引数に FUNC を funcall した結果を返す
  '(member ELEMENTS)     OBJECT が ELEMENTS に含まれる
  '(eql OBJ)             OBJECT が OBJ に等しい
  '(not TYPE1)           OBJECT が TYPE2 の型でない
  '(and TYPE1 TYPE2 ...) OBJECT が TYPE1, TYPE2, ... すべての型である
  '(or TYPE1 TYPE2 ...)  OBJECT が TYPE1, TYPE2, ... いずれかの型である
  't                     常に真
  'nil                   常に偽

3. 文字
  'standard-char         文字のうち standard-char-p なもの
  'extended-char (*)     常に nil を返す（extended-char は存在しない？）

4. 数値
  範囲を指定できます。省略することも可能。
  MIN および MAX に、数値の代わりに * を与えると、
  下限（上限）を指定しなかったとみなされます。

  '(integer MIN MAX)
  '(float MIN MAX)
  '(rational MIN MAX)
  '(short-float MIN MAX)
  '(single-float MIN MAX)
  '(double-float MIN MAX)
  '(long-float MIN MAX)

  '(complex TYPE1)      integer 型、float 型などで区別可能。範囲指定はできない。

5. 一次元配列
  長さを指定できます。
  長さには整数値か * を指定します。省略も可能。

  '(simple-vector LENGTH)
  '(simple-string LENGTH)
  '(string LENGTH)
  
  '(vector TYPE1 LENGTH)       TYPE1 は t（普通のベクタ）または character（文字列）
  
6. 一次元以上の配列
  '(simple-array TYPE1 DIM)    TYPE1 は t（普通のベクタ）または character（文字列）
  '(array TYPE1 DIM)           DIM は次元

  '(simple-array TYPE1 (DIMS)) TYPE1 は t（普通のベクタ）または character（文字列）
  '(array TYPE1 (DIMS))        DIMS は各次元のサイズ（たとえば 2x3 なら (2 3) ）

7. defstruct で定義された構造体

使用例:
  ;; 一般の型
  (typep #\a 'character)
  => t
  (typep (selected-buffer) 'buffer)
  => t

  ;; 複合型
  (typep 3 '(satisfies oddp))       ; 奇数（関数 oddp による判定）
  => t
  (typep 'b '(member a b c))        ; a b c がリストとしてまとめられる
  => (b c)
  (typep 3 '(and atom number))      ; atom かつ number
  => t
  (typep 3 '(and atom number list)) ; atom かつ number かつ list
  => nil
  (typep 3 '(or atom number list))  ; atom または number または list
  => t

  ;; 数値
  (typep 3 'integer)                ; 範囲指定しないならリストにする必要なし
  => t
  (typep 3 '(integer 1 5))
  => t
  (typep x '(integer * 5))
  => t
  (typep x '(integer 5 *))
  => nil
  
  (typep #C(1 2) 'complex)
  => t
  (typep #C(1 2) '(complex float))
  => nil

  ;; 一次元配列
  (typep #(1 2 3) '(simple-vector 3))
  => t
  (typep #(1 2 3) '(vector t 3))
  => t
  (typep "abc" '(vector character 3))
  => t

  ;; 一次元以上の配列
  (setf a (make-array '(3 4)))
  => #2A((nil nil nil nil) (nil nil nil nil) (nil nil nil nil))
  (typep a '(array t *))     ; 次元を指定しない
  => t
  (typep a '(array t 2))     ; 2 次元配列
  => t
  (typep a '(array t (3 4))) ; サイズも一致
  => t
  (typep a '(array t (* 4))) ; サイズの一部だけを指定することも可能
  => t

  ;; 構造体
  (typep (selected-pseudo-frame) 'ed::pseudo-frame)
  => t
```

関連: `si:canonicalize-type`, `type-of`, `subtypep`, `deftype`, `型一覧`

## `vectorp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `vectorp OBJECT`

```text
OBJECTがvectorならt、それ以外ならnilを返します。
```

関連: `simple-vector-p`, `vector`

## `windowp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `windowp OBJECT`

```text
指定されたOBJECTがウィンドウかを返します。

  t     OBJECTがウィンドウ
  nil   OBJECTはウィンドウではない
```

## `word-char-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `word-char-p CHAR`

```text
CHAR が単語構成文字かどうかを判定します。
```

関連: `syntax-word-p`, `characterp`
