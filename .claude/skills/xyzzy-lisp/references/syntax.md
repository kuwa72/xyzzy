# シンタックス (syntax)

reference/reference.xml から自動生成。51 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `copy-syntax-table`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `copy-syntax-table FROM-SYNTAX-TABLE TO-SYNTAX-TABLE`

```text
FROM-SYNTAX-TABLE を TO-SYNTAX-TABLE へコピーします。
```

関連: `make-syntax-table`

## `html-highlight-mode`

- BufferLocal / package: editor

```text
non-nilならばシンタックスの :tag が利用可能になります。
```

関連: `set-syntax-tag`, `parse-point-syntax`

## `make-syntax-table`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-syntax-table`

```text
シンタックステーブルを作成します。基本的に各文字にシンタックスコードを割
り振りますが、他にも目的の構文に応じて以下の設定を行います。

  ・文字列中のエスケープ文字の設定
  ・タグや括弧などの対応付けのある文字の設定
  ・単なる対になった区切り文字の設定
  ・コメントの設定
      ・開始終了を一文字で行うコメント
      ・開始終了を文字列で行うコメント
      ・C++スタイルのコメント
  ・特定行に文字があった場合のコメントの設定

これらの設定は set-syntax-... 系の関数を使って行います。設定に応じて、画
面の色付けや skip-syntax-spec-forward / skip-syntax-spec-backward での動作
が変わったりします。

デフォルト値：
  Num           Char            SyntaxCode
  ---           ----            ----------
  0x00          #\NUL           SCjunk
  0x01 .. 0x08  #\C-a .. #\C-h  SCjunk
  0x09          #\TAB           SCwhite
  0x0a          #\LFD           SCwhite
  0x0b          #\C-k           SCjunk
  0x0c          #\C-l           SCwhite
  0x0d          #\RET           SCwhite
  0x0e .. 0x1a  #\C-n .. #\C-z  SCjunk
  0x1b          #\ESC           SCjunk
  0x1c          #\C-\\          SCjunk
  0x1d          #\C-]           SCjunk
  0x1e          #\C-^           SCjunk
  0x1f          #\C-_           SCjunk
  0x20          #\SPC           SCwhite
  0x21 .. 0x2f  #\! .. #\/      SCpunct
  0x30 .. 0x39  #\0 .. #\9      SCword
  0x3a          #\:             SCpunct
  0x3b          #\;             SCpunct
  0x3c          #\<             SCpunct
  0x3d          #\=             SCpunct
  0x3e          #\>             SCpunct
  0x3f          #\?             SCpunct
  0x40          #\@             SCpunct
  0x41 .. 0x5a  #\A .. #\Z      SCword
  0x5b          #\[             SCpunct
  0x5c          #\\             SCpunct
  0x5d          #\]             SCpunct
  0x5e          #\^             SCpunct
  0x5f          #\_             SCpunct
  0x60          #\`             SCpunct
  0x61 .. 0x7a  #\a .. #\z      SCword
  0x7b          #\{             SCpunct
  0x7c          #\|             SCpunct
  0x7d          #\}             SCpunct
  0x7e          #\~             SCpunct
  0x7f          #\DEL           SCjunk
  0x80                          SCjunk
  0x81 ..0x9f   #\x81 .. #\x9f  SCkanji
  0xa0                          SCkanji
  0xa1 .. 0xb0  #\｡ .. #\ｰ      SCkana
  0xb1 .. 0xdd  #\ｱ .. #\ﾝ      SCkana
  0xde          #\ﾞ             SCkana
  0xdf          #\ﾟ             SCkana
  0xe0 .. 0xfc  #\xe0 .. #\xfc  SCkanji
  0xfd                          SCjunk
  0xfe                          SCjunk
  0xff                          SCjunk
```

関連: `copy-syntax-table`, `syntax-table-p`, `use-syntax-table`

## `parse-point-syntax`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `parse-point-syntax &optional POINT`

```text
指定された位置のシンタックスを返します。

  :string  set-syntax-string で指定されたキャラクタに囲まれた領域           
  :comment set-syntax-comment-column
           set-syntax-start-c++-comment
           set-syntax-end-c++-comment
           set-syntax-start-comment
           set-syntax-end-comment
           set-syntax-start-multi-comment
           set-syntax-end-multi-comment
           set-syntax-start-column-comment
           で指定された領域
  :tag     set-syntax-tag で指定されたキャラクタに囲まれた領域
           (ただし html-highlight-mode がnon-nilのときのみ)
  nil      上記以外の領域
```

関連: `syntax-table`, `html-highlight-mode`, `set-syntax-string`, `set-syntax-comment-column`, `set-syntax-start-c++-comment`, `set-syntax-end-c++-comment`, `set-syntax-start-comment`, `set-syntax-end-comment`, `set-syntax-start-multi-comment`, `set-syntax-end-multi-comment`, `set-syntax-start-column-comment`, `set-syntax-tag`

## `set-syntax-comment-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-comment-column SYNTAX-TABLE COLUMN`

```text
指定された列に#\SPC以外のキャラクタがある場合にコメント行と見な
します。特定のキャラクタだけにしたい場合には、
set-syntax-option を参照して下さい。
  
使用例：
  ;;; cobol-mode.lの定義
  (set-syntax-comment-column *cobol-mode-syntax-table* 6)
```

関連: `set-syntax-option`, `set-syntax-start-column-comment`, `syntax-table`, `parse-point-syntax`

## `set-syntax-end-c++-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-end-c++-comment SYNTAX-TABLE CHAR &optional PARSE-SEXP-IGNORE-COMMENT-P`

```text
文字CHARをC++スタイルのコメントの終了文字として規定します。
開始文字と異なり、終了文字は同じ文字を二つ連ねません。

使用例：
  ;;; cc-mode.l
  (set-syntax-end-c++-comment *c++-mode-syntax-table* #\LFD)
```

関連: `set-syntax-start-c++-comment`, `syntax-end-c++-comment-p`

## `set-syntax-end-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-end-comment SYNTAX-TABLE CHAR &optional PARSE-SEXP-IGNORE-COMMENT-P MAYBE-COMMENT-END-P`

```text
文字CHARをコメント終了文字として規定します。

使用例：
  ;;; perl.l
  (set-syntax-end-comment *perl-mode-syntax-table* #\LFD)
```

関連: `set-syntax-start-comment`, `syntax-end-comment-p`

## `set-syntax-end-multi-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-end-multi-comment SYNTAX-TABLE STRING`

```text
文字列STRINGをSYNTAX-TABLEに複数行のコメント終了を表す文字列として規定します。

使用例：
  ;;; c-mode.lの定義
  (set-syntax-end-multi-comment *c-mode-syntax-table* "*/")
```

関連: `set-syntax-start-multi-comment`, `syntax-start-multi-comment-1-p`, `syntax-start-multi-comment-2-p`

## `set-syntax-escape`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-escape SYNTAX-TABLE CHAR`

```text
文字CHARをエスケープ文字として規定します。
文字列中に限らず次の一文字の構文上の機能を抑制します。

使用例：
  ;;; c-mode.l
  (set-syntax-escape *c-mode-syntax-table* #\\)
```

関連: `set-syntax-string`, `syntax-escape-p`

## `set-syntax-junk`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-junk SYNTAX-TABLE CHAR`

```text
文字CHARをゴミ文字として規定します。
skip-syntax-spec-forward / skip-syntax-spec-backward でゴミ文字をスキッ
プするのに役に立つかもしれません。
```

関連: `syntax-junk-p`, `skip-syntax-spec-forward`

## `set-syntax-match`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-match SYNTAX-TABLE OPEN-CHAR CLOSE-CHAR`

```text
文字OPEN-CHARとCLOSE-CHARをSYNTAX-TABLEに対応付けのある文字として規定します。

使用例：
  ;;; c-mode.lの定義
  (set-syntax-match *c-mode-syntax-table* #\( #\))
  (set-syntax-match *c-mode-syntax-table* #\{ #\})
  (set-syntax-match *c-mode-syntax-table* #\[ #\])
```

関連: `syntax-open-p`, `syntax-close-p`, `skip-syntax-spec-forward`, `goto-matched-parenthesis`, `*show-matched-parenthesis*`

## `set-syntax-math`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-math SYNTAX-TABLE CHAR`

```text
文字CHARを対になった区切り文字として規定します。
Latexの数式モードの区切りに相当します。

使用例：
  ;;; Latex.l
  (set-syntax-math *LaTeX-mode-syntax-table* #\$)
```

関連: `syntax-math-p`, `skip-syntax-spec-forward`

## `set-syntax-option`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-option SYNTAX-TABLE OPTION`

```text
シンタックスの補助的な設定をします。

  *syntax-option-c-preprocessor* : （詳細不明）
  *syntax-option-indent-c++*     : （詳細不明）
  *syntax-option-indent-java*    : （詳細不明）
  *syntax-option-indent-csharp*  : （詳細不明）
  *syntax-option-indent-c++/cli* :
        属性や ref class など C++/CLI 用のインデントを有効にします。
  *syntax-option-column-comment-char* :
        set-syntax-comment-column だけでは、指定カラムに空白以外が来ると
        コメントと見なしますが、特定のキャラクタが現れた場合にだけにした
        い場合に設定します。以下の二つを設定しなければなりません。

        1) set-syntax-option に *syntax-option-comment-column-char* を指定する。
        2) set-syntax-start-column-comment でそのキャラクタを指定する。

使用例：
  ;;; fortran.lの定義
  ;;; 0桁目に'C'か'c'が現れたらその行はコメントと見なす。
  (set-syntax-comment-column fortran-mode-syntax-table 0)
  (set-syntax-option fortran-mode-syntax-table
                     *syntax-option-column-comment-char*)
  (set-syntax-start-column-comment fortran-mode-syntax-table #\C)
  (set-syntax-start-column-comment fortran-mode-syntax-table #\c)

参考：
  [xyzzy:07988]を参照のこと
```

関連: `set-syntax-comment-column`, `set-syntax-start-column-comment`, `[xyzzy:07988]`

## `set-syntax-punctuation`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-punctuation SYNTAX-TABLE CHAR`

```text
文字CHARを句読点文字として規定します。
ほとんど使うことはないでしょう。
```

関連: `syntax-punctuation-p`

## `set-syntax-quote`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-quote SYNTAX-TABLE CHAR`

```text
SYNTAX-TABLEにCHARをquoteとして規定します。
lispでリストで使う`''(quote)や、マクロで使う``'(backquote) `,'(comma)、
ベクタで使う`#'等があります。シンタックス上では意味付けをすることができ
ますが、どのような違いが出るかは不明。

使用例：
  ; lisp/lispmode.l
  (set-syntax-quote *lisp-mode-syntax-table* #\#)
  (set-syntax-quote *lisp-mode-syntax-table* #\')
  (set-syntax-quote *lisp-mode-syntax-table* #\,)
  (set-syntax-quote *lisp-mode-syntax-table* #\`)
```

関連: `syntax-quote-p`, `skip-syntax-spec-forward`

## `set-syntax-start-c++-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-start-c++-comment SYNTAX-TABLE CHAR &optional PARSE-SEXP-IGNORE-COMMENT-P`

```text
文字CHARをC++スタイルのコメントの開始文字として規定します。
「C++スタイルのコメント」とは同じ文字を二つ連ねる形式のことを指しています。

使用例：
  ;;; cc-mode.l
  (set-syntax-start-c++-comment *c++-mode-syntax-table* #\/)
```

関連: `syntax-c++-comment-p`, `set-syntax-end-c++-comment`, `set-syntax-start-comment`, `set-syntax-start-multi-comment`, `set-syntax-comment-column`, `parse-point-syntax`

## `set-syntax-start-column-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-start-column-comment SYNTAX-TABLE CHAR &optional PARSE-SEXP-IGNORE-COMMENT-P`

```text
set-syntax-comment-column の補助的な設定をします。
set-syntax-optionに *syntax-option-comment-column-char* を指定した場合に
のコメント開始用のキャラクタを設定します。
詳細は set-syntax-option を参照して下さい。
```

関連: `set-syntax-option`, `set-syntax-comment-column`, `syntax-start-column-comment-p`, `parse-point-syntax`

## `set-syntax-start-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-start-comment SYNTAX-TABLE CHAR &optional PARSE-SEXP-IGNORE-COMMENT-P`

```text
文字CHARをコメント開始文字として規定します。

使用例：
  ;;; perl.l
  (set-syntax-start-comment *perl-mode-syntax-table* #\#)
```

関連: `set-syntax-end-comment`, `syntax-start-comment-p`, `set-syntax-start-c++-comment`, `set-syntax-start-multi-comment`, `parse-point-syntax`

## `set-syntax-start-multi-comment`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-start-multi-comment SYNTAX-TABLE STRING`

```text
文字列STRINGをSYNTAX-TABLEに複数行のコメント開始を表す文字列として規定します。

使用例：
  ;;; c-mode.lの定義
  (set-syntax-start-multi-comment *c-mode-syntax-table* "/*")
```

関連: `set-syntax-end-multi-comment`, `syntax-start-multi-comment-1-p`, `syntax-start-multi-comment-2-p`, `parse-point-syntax`

## `set-syntax-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-string SYNTAX-TABLE CHAR`

```text
SYNTAX-TABLEにCHARを文字列の区切り文字として規定します。ここで指定した文
字で囲まれた領域はリテラルの文字列として色づけされます。

使用例：
  ; | を 文字列の区切り文字とする場合
  (set-syntax-string *user-mode-syntax-table* #\|)
```

関連: `syntax-string-p`, `set-syntax-escape`, `skip-syntax-spec-forward`, `parse-point-syntax`

## `set-syntax-symbol`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-symbol SYNTAX-TABLE CHAR`

```text
文字CHARがSYNTAX-TABLEでシンボル名を構成する文字（単語構成文字は除く）と
して規定します。

使用例：
  ;;; c-mode.lの定義
  (set-syntax-symbol *c-mode-syntax-table* #\_)
  (set-syntax-symbol *c-mode-syntax-table* #\#)
```

関連: `syntax-symbol-p`, `skip-syntax-spec-forward`

## `set-syntax-symbol-prefix`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-symbol-prefix SYNTAX-TABLE CHAR`

```text
文字をシンボルの前置子として規定します。

  SYNTAX-TABLE : シンタクッステーブルを指定します。
  CHAR         : 文字を指定します。  

HTMLの`&'(実体参照)や、Perlの`$'(変数)、`@'(配列)、`%'(連想配列)等が
相当するようです。Emacsの構文テーブルには相当するものが無いように思います。

使用例：
  ;;; perl.l
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\$)
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\@)
  (set-syntax-symbol-prefix *perl-mode-syntax-table* #\%)
```

関連: `syntax-symbol-prefix-p`

## `set-syntax-tag`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-tag SYNTAX-TABLE OPEN-CHAR CLOSE-CHAR`

```text
シンタックステーブルにタグの開始記号と終了記号を設定します。
HTMLやXML系のモードに設定するといいみたいです。
実際に利用する際にはさらに html-highlight-mode をnon-nilにす
る必要があります。

使用例：
  ;;; htmlmode.lでの定義
  (set-syntax-tag *html-mode-syntax-table* #\< #\>)
```

関連: `html-highlight-mode`, `syntax-open-tag-p`, `syntax-close-tag-p`, `skip-syntax-spec-forward`

## `set-syntax-whitespace`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-whitespace SYNTAX-TABLE CHAR`

```text
SYNTAX-TABLEにCHARをwhitespaceとして規定します。whitespaceとして規定され
た文字は skip-white-forward / skip-white-backwardでスキップされるように
なります。

使用例：
  ; lisp/lispmode.l
  (set-syntax-whitespace *lisp-mode-syntax-table* #\SPC)
  (set-syntax-whitespace *lisp-mode-syntax-table* #\TAB)
  (set-syntax-whitespace *lisp-mode-syntax-table* #\C-l)
  (set-syntax-whitespace *lisp-mode-syntax-table* #\RET)
```

関連: `syntax-whitespace-p`, `skip-white-forward`, `skip-white-backward`, `skip-syntax-spec-forward`, `skip-syntax-spec-backward`

## `set-syntax-word`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-syntax-word SYNTAX-TABLE CHAR`

```text
文字を単語を構成する文字として規定します。
skip-syntax-spec-forward / skip-syntax-spec-backwardに影響します。

  SYNTAX-TABLE : シンタクッステーブルを指定します。
  CHAR         : 文字を指定します。

デフォルトでは#\0 .. #\9, #\A .. #\Z, #\a .. #\z です。
余程特殊でない限り新たに設定する必要は無いでしょう。
```

関連: `syntax-word-p`, `skip-syntax-spec-forward`

## `syntax-c++-comment-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-c++-comment-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがC++スタイルのコメントの開始文字として規定されているかを返します。

  t     開始文字である。
  nil   開始文字でない。
```

関連: `set-syntax-start-c++-comment`

## `syntax-close-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-close-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARが括弧などの終了文字として規定されているかを返します。

  t     終了文字である。
  nil   終了文字でない。
```

関連: `set-syntax-match`, `syntax-open-p`

## `syntax-close-tag-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-close-tag-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがタグの終了文字として規定されているかを返します。

  t     タグの終了文字である。
  nil   タグの終了文字でない。
```

関連: `set-syntax-close-tag`

## `syntax-end-c++-comment-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-end-c++-comment-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがC++スタイルのコメントの終了文字として規定されているかを返します。

  t     終了文字である。
  nil   終了文字でない。
```

関連: `set-syntax-end-c++-comment`

## `syntax-end-comment-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-end-comment-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがコメント終了文字として規定されているかを返します。

  t     コメント終了文字である。
  nil   コメント終了文字でない。
```

関連: `set-syntax-end-comment`

## `syntax-end-multi-comment-1-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-end-multi-comment-1-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがコメント終了の文字列の1文字目として規定されているかを返します。

  t     コメント終了文字列の1文字目である。
  nil   コメント終了文字列の1文字目でない。
```

関連: `set-syntax-end-multi-comment`, `syntax-end-multi-comment-2-p`

## `syntax-end-multi-comment-2-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-end-multi-comment-2-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがコメント終了の文字列の2文字目として規定されているかを返します。

  t     コメント終了文字列の2文字目である。
  nil   コメント終了文字列の2文字目でない。
```

関連: `set-syntax-end-multi-comment`, `syntax-end-multi-comment-1-p`

## `syntax-escape-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-escape-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがエスケープ文字として規定されているかを返します。

  t     エスケープ文字である。
  nil   エスケープ文字でない。
```

関連: `set-syntax-escape`

## `syntax-junk-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-junk-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがゴミ文字として規定されているかを返します。

  t     ゴミ文字である。
  nil   ゴミ文字でない。
```

関連: `set-syntax-junk`

## `syntax-math-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-math-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARが対になった区切り文字として規定されているかを返します。

  t     対になった区切り文字である。
  nil   対になった区切り文字でない。
```

関連: `set-syntax-math`

## `syntax-open-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-open-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARが括弧などの開始文字として規定されているかを返します。

  t     開始文字である。
  nil   開始文字でない。
```

関連: `set-syntax-match`, `syntax-close-p`

## `syntax-open-tag-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-open-tag-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがタグの開始文字として規定されているかを返します。

  t     タグの開始文字である。
  nil   タグの開始文字でない。
```

関連: `set-syntax-tag`, `syntax-close-tag-p`

## `syntax-punctuation-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-punctuation-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARが句読点文字として規定されているかを返します。

  t     句読点文字である。
  nil   句読点文字である。
```

関連: `set-syntax-punctuation`

## `syntax-quote-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-quote-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがSYNTAX-TABLEでquote(?)として規定されているか否か返します。

  t    CHARはquoteである。
  nil  CHARはquoteでない。
```

関連: `set-syntax-quote`

## `syntax-start-column-comment-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-start-column-comment-p CHAR &optional SYNTAX-TABLE`

```text
set-syntax-start-column-comment で指定した文字か否かを判定します。
```

関連: `set-syntax-start-column-comment`

## `syntax-start-comment-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-start-comment-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがコメント開始文字として規定されているかを返します。

  t     コメント開始文字である。
  nil   コメント開始文字でない。
```

関連: `set-syntax-start-comment`

## `syntax-start-multi-comment-1-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-start-multi-comment-1-p CHAR &optional SYNTAX-TABLE`

```text
文字がコメント開始の文字列の1文字目として規定されているかを返します。

  CHAR         : コメント開始の1文字目を指定します。
  SYNTAX-TABLE : シンタックステーブルを指定します。指定しないと、カレン
                 トバッファにしようされているシンタックステーブルが使用
                 されます。

  t     コメント開始文字列の1文字目である。
  nil   コメント開始文字列の1文字目でない。
```

関連: `set-syntax-start-multi-comment`, `syntax-start-multi-comment-2-p`

## `syntax-start-multi-comment-2-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-start-multi-comment-2-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがコメント開始の文字列の2文字目として規定されているかを返します。

  t     コメント開始文字列の2文字目である。
  nil   コメント開始文字列の2文字目でない。
```

関連: `set-syntax-start-multi-comment`, `syntax-start-multi-comment-1-p`

## `syntax-string-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-string-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがSYNTAX-TABLEで文字列の区切りとして規定されているか否かを返します。

  t    CHARは文字列の区切り文字である。
  nil  CHARは文字列の区切り文字でない。
```

関連: `set-syntax-string`

## `syntax-symbol-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-symbol-p CHAR &optional SYNTAX-TABLE`

```text
文字がシンボル名を構成する文字として規定されているかを返します。
ただし単語構成文字は除きます。

  CHAR : 文字を指定します。  

  t     シンボル名を構成する文字である。
  nil   シンボル名を構成する文字でない。
```

関連: `set-syntax-symbol`

## `syntax-symbol-prefix-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-symbol-prefix-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがシンボルの前置子として規定されているかを返します。

  CHAR : 文字を指定します。  

  t     シンボルの前置子である。
  nil   シンボルの前置子でない。
```

関連: `set-syntax-symbol-prefix`

## `syntax-table`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-table &optional BUFFER`

```text
現在のシンタックステーブルを取り出します。

使用例：
  ;;; evalして挿入
  (defun xmldoc-eval-and-insert ()
    (interactive "p")
    (let ((syntab (syntax-table)))  ;;現在のxmldocモードのsyntax-tableを取り出し
      (let (from to col str start end)
        (cond ((selection-start-end (start end)
                 (setq from start to end)))
              (t
               ;;一時的にlispに切り替えて
               (use-syntax-table ed::*lisp-mode-syntax-table*)
               (unwind-protect
                   (setq from (progn
                                (backward-sexp)
                                (point))
                         to (progn
                              (forward-sexp)
                              (point)))
                 ;; また元に戻す
                 (use-syntax-table syntab))))
```

関連: `make-syntax-table`, `syntax-table-p`, `use-syntax-table`, `parse-point-syntax`

## `syntax-table-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-table-p OBJECT`

```text
指定されてオブジェクトOBJECTがシンタックステーブルか否かを返します。

  t    シンタックステーブルである。
  nil  シンタックステーブルでない。
```

関連: `make-syntax-table`

## `syntax-whitespace-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-whitespace-p CHAR &optional SYNTAX-TABLE`

```text
文字CHARがSYNTAX-TABLEでwhitespaceとして規定されてるか否かを返します。

  t    CHARはwhitespaceでない。
  nil  CHARはwhitespaceである。
```

関連: `set-syntax-whitespace`

## `syntax-word-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `syntax-word-p CHAR &optional SYNTAX-TABLE`

```text
文字が単語を構成する文字として規定されているかを返します。

  CHAR : 判定する文字を指定します。

  t     単語を構成する文字である。
  nil   単語を構成する文字でない。
```

関連: `set-syntax-word`

## `use-syntax-table`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `use-syntax-table SYNTAX-TABLE &optional BUFFER (INVALIDATE-P T)`

```text
バッファで使用するシンタックステーブルを設定します。

使用例：
  ;;; lispmode.lの例
  (use-syntax-table *lisp-mode-syntax-table*)
  => t
```

関連: `syntax-table-p`, `syntax-table`
