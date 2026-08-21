# 文字 (characters)

reference/reference.xml から自動生成。35 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*unicode-to-half-width*`

- Variable / package: editor

```text
non-nil なら、UNICODE 文字の表示に半角文字を使用します。
デフォルトでは t が xyzzy ソース内で設定されています。

使用例：
  ;;; 半角文字で表示
  (setq *unicode-to-half-width* t)   => t
  (unicode-char 180)                 => #\x0134
  ;;; 全角文字で表示
  (setq *unicode-to-half-width* nil) => nil
  (unicode-char 180)                 => #\´
```

関連: `unicode-char`, `char-columns`

## `both-case-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `both-case-p CHAR`

```text
CHAR が大文字小文字のある文字なら t 、そうでなければ nil を返します。

使用例：  
  (both-case-p #\a)
  => t
  (both-case-p #\A)
  => t
  (both-case-p #\RET)
  => nil
```

関連: `lower-case-p`, `upper-case-p`, `alpha-char-p`

## `char-after`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-after POINT &optional NOT-USED`

```text
カレントバッファの POINT 位置の文字を返します。
(point-min)以下の値が指定された場合(point-min)の文字を返す。
(point-max)以上の値が指定された場合 #\NUL を返す。

  POINT    : INTEGER か MARKER でポイントを指定
  NOT-USED : 不使用

戻り値：
  文字

使用例：
  ;;; ポイント c の位置で ESC ESC (char-after (point)) した場合
  abcdefg
    ^ このポイントで ESC ESC (char-after (point)) => #\c
```

関連: `following-char`, `char-before`

## `char-before`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-before POINT &optional NOT-USED`

```text
カレントバッファの POINT の前の位置の文字を返します。
(point-max)以上の値が指定された場合(point-max)の前の位置の文字を返す。
(point-min)以下の値が指定された場合 #\NUL を返す。

  POINT    : INTEGER か MARKER でポイントを指定
  NOT-USED : 不使用

戻り値:
  文字

使用例：
  ;;; ポイント c の位置で ESC ESC (char-before (point)) した場合
  abcdefg
    ^ このポイントで ESC ESC (char-before (point)) => #\b
```

関連: `char-after`, `preceding-char`

## `char-code`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-code CHAR`

```text
CHAR の文字コードを返します。
文字コードとキャラクタの間の相互変換には、code-charを使います。

使用例：
  (char-code #\a)
  => 97
  (code-char (char-code #\a))
  => #\a
```

関連: `code-char`, `char-unicode`, `unicode-char`, `iso-code-char`

## `char-columns`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-columns CHAR`

```text
文字 CHAR の文字幅を返します。

使用例：
  (char-columns #\a)        => 1
  (char-columns #\あ)       => 2
  (char-columns #\asterisk) => 1
  ;;; UNICODE 半角表示時
  (setq *unicode-to-half-width* t)   => t
  (char-columns (unicode-char 180))  => 1
  ;;; UNICODE 全角表示時
  (setq *unicode-to-half-width* nil) => nil
  (char-columns (unicode-char 180))  => 2
```

関連: `count-column`, `current-line-columns`, `*unicode-to-half-width*`

## `char-downcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-downcase CHAR`

```text
CHARを小文字にして返します。

使用例：  
  (char-downcase #\A)
  => #\a
```

関連: `char-upcase`, `lower-case-p`, `string-downcase`

## `char-equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-equal CHARACTER &rest MORE-CHARACTERS`

```text
引数がすべて大文字小文字関係なく等しければt、そうでなければnilを返します。

使用例：  
  (char-equal #\A #\a)
  => t
```

関連: `equalp`, `char=`

## `char-greaterp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-greaterp CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て大文字小文字関係なく降順ならt、そうでなければnilを返します。

使用例：
  (char-greaterp #\c #\b #\a)
  => t
  (char-greaterp #\c #\b #\b)
  => nil
  (char-greaterp #\b #\A)
  => t
  (char-greaterp #\B #\a)
  => t
```

関連: `char>`

## `char-lessp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-lessp CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て大文字小文字関係なく昇順ならt、そうでなければnilを返します。

使用例：  
  (char-lessp #\a #\b #\c)
  => t
  (char-lessp #\a #\b #\b)
  => nil
  (char-lessp #\A #\b)
  => t
  (char-lessp #\a #\B)
  => t
```

関連: `char<`

## `char-name`

- Function / package: editor / 定義: misc.l
- 呼び出し: `char-name C`

```text
文字の英字名称を返します。
この英字名称はどこで定義されたものなのでしょうか？

使用例：
  ;;; いろいろと英字名称を見てみる。
  (char-name #\x00)     => "null"
  (char-name #\x0a)     => "line_feed"
  (char-name #\x0d)     => "carriage_return"
  (char-name #\a)       => "latin_small_letter_a"
  (char-name #\が)      => "hiragana_letter_ga"
  (char-name #\ヲ)      => "katakana_letter_wo"
  (char-name #\漢)      => nil
```

## `char-not-equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-not-equal CHARACTER &rest MORE-CHARACTERS`

```text
引数がすべて大文字小文字関係なく等しくなければt、そうでなければnilを返します。

使用例：
  (char-not-equal #\a #\b #\c)
  => t
  (char-not-equal #\a #\A)
  => nil
```

関連: `char/=`

## `char-not-greaterp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-not-greaterp CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て大文字小文字関係なく昇順か等しければt、そうでなければnil
を返します。

使用例：  
  (char-not-greaterp #\a #\B #\c)
  => t
```

関連: `char<=`

## `char-not-lessp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-not-lessp CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て大文字小文字関係なく降順か等しければt、そうでなければnil
を返します。

使用例：  
  (char-not-lessp #\c #\B #\a)
  => t
```

関連: `char>=`

## `char-unicode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-unicode CHAR`

```text
文字のUNICODEのコード値を返します。

使用例：
  ;;; UNICODEのコード値を取得してみる。
  (char-unicode #\x00)  => 0
  (char-unicode #\a)    => 97
  (char-unicode #\漢)   => 28450
```

関連: `unicode-char`, `char-code`

## `char-upcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char-upcase CHAR`

```text
CHARを大文字にして返します。

使用例：  
  (char-upcase #\x)
  => #\X
```

関連: `char-downcase`, `upper-case-p`, `string-upcase`

## `char/=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char/= CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て等しくなければt、そうでなければnilを返します。

使用例：  
  (char/= #\a #\b #\c)
  => t
  (char/= #\a #\b #\a)
  => nil
  (char/= #\a #\A)
  => t
```

関連: `char-not-equal`

## `char<`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char< CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て昇順ならt、そうでなければnilを返します。

使用例：  
  (char< #\a #\b #\c)
  => t
  (char< #\a #\b #\b)
  => nil
  (char< #\A #\b)
  => t
  (char< #\a #\B)
  => nil
```

関連: `char-lessp`

## `char<=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char<= CHARACTER &rest MORE-CHARACTERS`

```text
隣り合った引数の関係がすべて昇順か等しければt、そうでなければnilを返します。

使用例：  
  (char<= #\a #\b #\b #\c)
  => t
  (char<= #\a #\b #\c #\b)
  => nil
```

関連: `char-not-greaterp`

## `char=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char= CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字がすべて等しければt、そうでなければnilを返します。

使用例：  
  (char= #\a #\a #\a)
  => t
  (char= #\a #\d)
  => nil
  (char= #\a #\A)
  => nil

参考：
  case-sensitive        case-insensitive
  ----                  ----
  char=                 char-equal
  char/=                char-not-equal
  char<                 char-lessp
  char>                 char-greaterp
  char<=                char-not-greaterp
  char>=                char-not-lessp
```

関連: `eql`, `equal`, `char-equal`

## `char>`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char> CHARACTER &rest MORE-CHARACTERS`

```text
引数の文字が全て降順ならt、そうでなければnilを返します。

使用例：  
  (char> #\c #\b #\a)
  => t
  (char> #\c #\b #\d)
  => nil
  (char> #\b #\A)
  => t
  (char> #\a #\B)
  => t
```

関連: `char-greaterp`

## `char>=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char>= CHARACTER &rest MORE-CHARACTERS`

```text
隣り合った引数の関係がすべて降順か等しければt、そうでなければnilを返します。

使用例：  
  (char>= #\c #\b #\b #\a)
  => t
  (char>= #\c #\b #\d)
  => nil
```

関連: `char-not-lessp`

## `character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `character OBJECT`

```text
OBJECTを可能ならばcharacterに変換して返します。

  (character 'x) == (coerce 'x 'character)

使用例：
  (character 'x)        => #\x
  (character "A")       => #\A
  (character "1")       => #\1
  (character "10")      => 文字への変換はサポートされていません: "10"
```

関連: `coerce`

## `code-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `code-char CODE`

```text
文字コードがCODEの文字を返します。
キャラクタと文字コードとの間の相互変換には、 char-code を使います。

使用例：  
  (code-char 110)
  => #\n
```

関連: `char-code`, `unicode-char`, `iso-char-code`, `char-unicode`

## `digit-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `digit-char WEIGHT &optional (RADIX 10)`

```text
RADIX を基数とした場合の WEIGHT の表示上の文字を返します。
下の例ですと、 (digit-char 12 16) は16進表記した場合の12は、
#\C になります。WEIGHT が RADIX 以上になると nil が返ります。

使用例：
  (digit-char 7)
  => #\7
  (digit-char 12)
  => nil
  (digit-char 12 16)
  => #\C
  (digit-char 6 2)
  => nil
  (digit-char 1 2)
  => #\1
```

関連: `digit-char-p`

## `digit-char-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `digit-char-p CHAR &optional (RADIX 10)`

```text
CHAR が数字ならその数字の10進表現での値を、そうでなければ nil を返します。

  RADIX : 基数

使用例：  
  (digit-char-p #\1)
  => 1
  (digit-char-p #\a)
  => nil
  (digit-char-p #\a 16)
  => 10
  (digit-char-p #\RET)
  => nil
```

関連: `digit-char`, `characterp`

## `display-first-tab-char`

- Variable / package: editor / 定義: defs.l

```text
タブの表示に使用する文字を設定します。最初の文字は
display-first-tab-charで設定し、以降の文字は
display-rest-tab-charで設定します。
xyzzy 0.2.2.215～

使用例：
  (setq-default display-first-tab-char #\rightwards_arrow_to_bar)
  (setq-default display-rest-tab-char nil)
```

関連: `display-rest-tab-char`

## `display-newline-char`

- Variable / package: editor / 定義: defs.l

```text
改行の表示に使用する文字を設定します。
  半角文字  指定した文字で表示
  nil       空白で表示
  上記以外  従来の文字で表示

使用例：
  (setq-default display-newline-char #\downwards_arrow_with_tip_leftwards)
```

## `display-rest-tab-char`

- Variable / package: editor / 定義: defs.l

```text
タブの表示に使用する文字を設定します。
詳しくは display-first-tab-char を参照してください。
```

関連: `display-first-tab-char`

## `lower-case-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `lower-case-p CHAR`

```text
CHAR が小文字なら t 、そうでなければ nil を返します。

使用例：
  (lower-case-p #\a)
  => t
  (lower-case-p #\A)
  => nil
  (lower-case-p #\RET)
  => nil
```

関連: `upper-case-p`, `both-case-p`, `char-downcase`

## `quote-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `quote-char &optional (ARG 1)`

```text
プロンプトを表示して、入力に従ってバッファに文字を挿入します。[C-q]
制御文字の入力などに使われます。
文字コードによる入力も可能です。
```

## `set-meta-bit`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-meta-bit CHAR SET`

```text
CHAR を Meta付き、無しの文字に相互変換します。

  SET: non-nil の時、CHAR の Meta付きの文字を返します。
       nil の時、    CHAR の Meta無しの文字を返します。

例:
  (set-meta-bit #\S-C-Right t)
  =>#\S-C-M-Right
  
  (set-meta-bit #\M-S-C-Right nil)
  =>#\S-C-Right
```

## `unicode-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `unicode-char CODE`

```text
UNICODEのコード値に対応した文字を返します。

使用例：
  ;;; UNICODEから文字を出してみる。
  (unicode-char 28450)
  => #\漢
```

関連: `char-unicode`, `code-char`, `*unicode-to-half-width*`

## `upper-case-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `upper-case-p CHAR`

```text
CHAR が大文字なら t 、そうでなければ nil を返します。

使用例：  
  (upper-case-p #\A)
  => t
  (upper-case-p #\a)
  => nil
  (upper-case-p #\RET)
  => nil
```

関連: `lower-case-p`, `both-case-p`, `char-upcase`

## `zap-to-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `zap-to-char C &optional (N 1)`

```text
ポイントから指定されたキャラクタまでをkillします。[ESC z]
```

関連: `kill-region`
