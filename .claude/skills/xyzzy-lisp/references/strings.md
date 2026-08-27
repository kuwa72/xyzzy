# 文字列 (strings)

reference/reference.xml から自動生成。50 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `abbreviate-display-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `abbreviate-display-string STRING LENGTH &optional PATHNAMEP`

```text
文字列を表示幅に収まるように[...]で省略して返します。

  STRING    : 表示する文字列を指定します。
  LENGTH    : 表示幅を指定します。
  PATHNAMEP : 文字列がファイル名かどうかを指定します。
              ファイル名の場合には先頭の3文字(例："C:/"）だけ残して省略します。

使用例：
 (abbreviate-display-string "c:/xyzzy/lisp/builtin.l" 20 nil)
 => "c:/xyzzy.../builtin.l"
 (abbreviate-display-string "c:/xyzzy/lisp/builtin.l" 20 t)
 => "c:/.../lisp/builtin.l"
```

## `buffer-substring`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-substring FROM TO &optional BUFFER`

```text
バッファの指定された範囲の文字列を返します。

  FROM   : 開始位置のポイント
  TO     : 終了位置のポイント
  BUFFER : バッファを指定します。
           指定がなければカレントバッファになります。

補足：
  BUFFER 引数は xyzzy 0.2.2.243 から指定可能です。
```

関連: `substring`

## `capitalize-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `capitalize-word &optional (ARG 1)`

```text
前方の単語の先頭の文字を大文字に、それ以外の文字を小文字に変換します。
[ESC c]
カーソルが単語の途中にある場合は、カーソル位置の文字を大文字に、それ以
降の文字を小文字に変換します。
```

関連: `upcase-word`, `downcase-word`, `capitalize-region`, `capitalize-selection`, `forward-word`

## `char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `char STRING INDEX`

```text
STRINGのINDEX番目の文字を返します。
INDEXは0を基底とします。

使用例：
  ;;; 先頭から最後まで取得する。
  (char "foo" -1) => 範囲外の値です: -1
  (char "foo" 0)  => #\f
  (char "foo" 1)  => #\o
  (char "foo" 2)  => #\o
  (char "foo" 3)  => 範囲外の値です: 3
```

関連: `schar`

## `compare-buffer-substrings`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `compare-buffer-substrings BUFFER1 START1 END1 BUFFER2 START2 END2 &optional CASE-FOLD`

```text
BUFFER1 と BUFFER2 の指定された区間の内容が等しいか比べます。
両者の内容が与えられた区間のうち短い方の長さの間等しいとき、
戻り値の絶対値はその長さ + 1 です。
戻り値が 0 となる事はありません。

  CASE-FOLD : non-nil で、大文字・小文字を区別しません。
```

関連: `compare-windows`

## `concat`

- Function / package: editor / 定義: misc.l
- 呼び出し: `concat &rest SEQ`

```text
指定された文字列を連結します。

使用例：
  ;;; concatを使ってみる。
  (setq foo "It's ")            => "It's "
  (setq bar "show time!!!")     => "show time!!!"
  (concat foo bar)              => "It's show time!!!"
  (concat "It's " "show " "time!!!")
  =>"It's show time!!!"
```

関連: `concatenate`

## `copy-string`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-string STRING`

```text
STRINGのコピーを返します。

使用例：
  ;;; 単にsetqしただけでは同じオブジェクトになっている。
  (setq foo "abc")              => "abc"
  (setq bar foo)                => "abc"
  (eq foo bar)                  => t

  ;;; コピーすると別のオブジェクトになる。
  (setq bar (copy-string foo))  => "abc"
  (eq foo bar)                  => nil
```

関連: `substring`, `copy-seq`

## `decode-escape-sequence`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `decode-escape-sequence STRING REGEXPP`

```text
エスケープシーケンスをデコードします。

  STRING ：デコードするエスケープシーケンス
  REGEXPP：STRING が正規表現か否かを指定します。

使用できるエスケープシーケンスは以下の通りです。
  \t     タブ
  \n     改行
  \r     復帰
  \f     改頁
  \v     垂直タブ
  \xNN   2桁までの16進数
  \XNNNN 4桁までの16進数

使用例：
  ;;; [\thoge]という6文字をデコードして5文字にする。
  "\\thoge"
  => "\\thoge"
  (decode-escape-sequence "\\thoge" nil)
  => "  hoge"
  (length "\\thoge")
  => 6
  (length (decode-escape-sequence "\\thoge" nil))
  => 5
```

関連: `[xyzzy:04201]`

## `delete-indentation`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-indentation &optional ARG`

```text
インデントを削除し直前の行と連結します。[ESC ^]
連結する行とされる行は、半角スペースで区切られます。

  ARG : 連結する行を指定します。
        t   次行のインデントを削除し、現在の行に連結します。
        nil 現在の行のインデントを削除し、直前の行に連結します。
```

関連: `just-one-space`, `newline-and-indent`

## `delete-last-ime-composition`

- Function / package: editor / 定義: kanji.l
- 呼び出し: `delete-last-ime-composition`

```text
IME 変換直後であれば、直前に変換した文字列を削除します。[C-c C-d]
```

## `downcase-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `downcase-word &optional (ARG 1)`

```text
カーソル位置から単語の末尾までを小文字に変換します。[ESC l]
```

関連: `upcase-word`, `capitalize-word`, `downcase-region`, `downcase-selection`, `string-downcase`

## `fill-paragraph`

- Function / package: editor / 定義: fill.l
- 呼び出し: `fill-paragraph`

```text
現在の段落を詰め込みます。[ESC q]
```

関連: `fill-region-as-paragraph`, `fill-prefix`

## `ime-push-composition-string`

- Function / package: editor / 定義: kanji.l
- 呼び出し: `ime-push-composition-string &optional NODELETE`

```text
セレクションの確定済仮名文字を非確定状態にします。[C-c C-p]
```

関連: `rewind-ime-composition`

## `map-backslash-to-slash`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `map-backslash-to-slash STRING`

```text
文字列のバックスラッシュをスラッシュに置換して返します。

  STRING : 変換対象の文字列

使用例：
  ;;; パスを変換する。
  (map-backslash-to-slash "C:\\xyzzy\\xyzzy.exe")
  => "C:/xyzzy/xyzzy.exe"
```

関連: `map-slash-to-backslash`

## `map-slash-to-backslash`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `map-slash-to-backslash STRING`

```text
文字列のスラッシュをバックスラッシュに置換して返します。

  STRING : 変換対象の文字列

使用例：
  ;;; パスを変換する。
  (map-slash-to-backslash "C:/xyzzy/xyzzy.exe")
  => "C:\\xyzzy\\xyzzy.exe"
```

関連: `map-backslash-to-slash`

## `namestring`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `namestring PATHNAME`

```text
PATHNAMEの内容に応じて適切なフルパスを返すような動きをする。与えたのがフ
ルパスでなければ、先頭に(default-directory)を補ってフルパスらしくします。
使用例：
  (default-directory)
  =>"C:/Applications/xyzzy/"

  (namestring "abc.txt")
  =>"C:/Applications/xyzzy/abc.txt"

  (namestring "Z:/zzz.txt")
  =>"Z:/zzz.txt"
```

関連: `file-namestring`, `merge-pathnames`

## `nstring-capitalize`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nstring-capitalize STRING &key :start :end`

```text
STRING の内部の単語の先頭を大文字に、それ以外を小文字にした文字列を返します。
引数 STRING は破壊されます。

使用例：  
  (setq foo "tHis iS a pEn.")
  => "tHis iS a pEn."
  (nstring-capitalize foo)
  => "This Is A Pen."
  foo
  => "This Is A Pen."
```

関連: `string-capitalize`

## `nstring-downcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nstring-downcase STRING &key :start :end`

```text
STRING を小文字にした文字列を返します。引数 STRING は破壊されます。

使用例：  
  (setq foo "XyZzY")
  => "XyZzY"
  (nstring-downcase foo)
  => "xyzzy"
  foo
  => "xyzzy"
```

関連: `string-downcase`

## `nstring-upcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nstring-upcase STRING &key :start :end`

```text
STRING を大文字にした文字列を返します。引数 STRING は破壊されます。

使用例：
  (setq foo "xyzzy")
  => "xyzzy"
  (nstring-upcase foo)
  => "XYZZY"
  foo
  => "XYZZY"
```

関連: `string-upcase`

## `quote-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `quote-string STRING TARGET-CHAR QUOTE-CHAR`

```text
文字列中の特定文字の前にエスケープ文字をつけます。

  STRING      : 置換する文字列
  TARGET-CHAR : エスケープされる文字
  QUOTE-CHAR  : エスケープ文字

使用例：
  ;;;   スペースの前に'をつけます。
  (quote-string  "a b  c"  #\SPC #\')
  => "a' b' ' c"
```

関連: `substitute-string`

## `rewind-ime-composition`

- Function / package: editor / 定義: kanji.l
- 呼び出し: `rewind-ime-composition &optional NODELETE POP`

```text
直前に IME で変換した文字列を非確定状態に戻します。[C-c C-c]
変換直後でなければ、直前に変換した文字列を非確定状態で挿入します。
```

関連: `ime-push-composition-string`

## `schar`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `schar SIMPLE-STRING INDEX`

```text
SIMPLE-STRINGのINDEX番目の文字を返します。
INDEXは0を基底とします。

使用例：
  ;;; simpleでないstringでscharを使ってみる。
  (setq foo (make-vector 10 :initial-element #\a :element-type 'character :fill-pointer 3))
                        => "aaa"
  (schar foo 0)         => 不正なデータ型です: "aaa": simple-string
  (setq bar "aaa")      => "aaa"
  (schar bar 0)         => #\a
```

関連: `char`, `simple-string`

## `split-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `split-string STRING SEPARATOR &optional EMPTY-OK CHAR-BAG`

```text
文字列を指定されたセパレータ文字で分割したリストにします。
セパレータ文字は含まれません。

  STRING       : 分割する文字列を指定します。
  SEPARATOR    : セパレータ文字を指定します。
  EMPTY-OK     : 長さが0の文字列も（つまり、セパレータ文字が連続するような場合）
                 を許すかどうかを指定します。non-nil で残し、nil で捨てます。
                 「無視する」ではなく「許す」方が non-nil です。
                 なお、末尾のセパレータに対しては non-nil でも空要素を
                 作りません（先頭側とは非対称です）。
  CHAR-BAG     : 分割した後の文字列の前後をトリムするための文字群を指定します。
  
使用例：
  (split-string "121,,12321" #\,)       => ("121" "12321")
  (split-string "121,,12321" #\, t)     => ("121" "" "12321")
  (split-string "121,,12321" #\, t "1") => ("2" "" "232")
  (split-string "121,,12321" #\, t "3") => ("121" "" "12321")
```

## `string`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string X`

```text
Xが文字列ならそれを返します。シンボルならその名前を返します。
文字や文字のベクタなら、それらの文字からなる文字列を返します。

使用例：
  (string "foo")
  => "foo"
  (string 'bar)
  => "bar"
  (string #\a)
  => "a"
  (string (make-vector 3 :initial-contents '(#\a #\b #\c)))
  => "abc"
```

関連: `symbol-name`, `make-sequence`, `format`, `coerce`

## `string-capitalize`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-capitalize STRING &key :start :end`

```text
STRING の内部の単語の先頭を大文字に、それ以外を小文字にした文字列を返します。
引数 STRING は保存されます。

使用例：
  (string-capitalize "xYZzY")
  => "Xyzzy"  
  (string-capitalize "tHis iS a pEn.")
  => "This Is A Pen."
```

関連: `nstring-capitalize`

## `string-downcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-downcase STRING &key :start :end`

```text
STRING を小文字にした文字列を返します。引数 STRING は保存されます。

使用例：
  (string-downcase "XyZzY")
  => "xyzzy"
  (string-downcase "XYZZY" :start 2 :end 4)
  => "XYzzY"
```

関連: `nstring-downcase`, `char-downcase`, `downcase-word`

## `string-equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-equal STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して等しければt、そうでなけ
ればnilを返します。

使用例：
  (string-equal "foo" "foo")
  => t
  (string-equal "foo" "Foo")
  => t
```

関連: `equalp`, `string=`, `string-not-equal`

## `string-greaterp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-greaterp STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して「>」の条件を満たせば
一致しない文字のインデックスを、そうでなければnilを返します。

使用例：
  (string-greaterp "ac" "ab")
  => 1
  (string-greaterp "ac" "ac")
  => nil
  (string-greaterp "AC" "ab")
  => 1
```

関連: `string<`, `string>`, `string<=`, `string>=`, `string-lessp`, `string-not-lessp`, `string-not-greaterp`

## `string-left-trim`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-left-trim CHARACTER-BAG STRING`

```text
文字列の先頭から指定した文字群を削除します。

  STRING         : 文字列
  CHARACTGER-BAG : 削除する文字群です。
  
使用例：
  ;;;  先頭の"/"や"\"を取り除きます。
  (string-left-trim "/\\" "/foo/bar/zzz.txt/")
  => "foo/bar/zzz.txt/"
```

関連: `string-trim`, `string-right-trim`

## `string-lessp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-lessp STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して「<」の条件を満たせば
一致しない文字のインデックスを、そうでなければnilを返します。

使用例：  
  (string-lessp "Aa" "ab")
  => 1
  (string-lessp "ac" "AB")
  => nil
```

関連: `string<`, `string>`, `string<=`, `string>=`, `string-not-lessp`, `string-greaterp`, `string-not-greaterp`

## `string-looking-at`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `string-looking-at REGEXP STRING &key :start :end :case-fold`

```text
STRING が、REGEXP とマッチするかを調べます。

string-match は、REGEXP が STRING のどこかにマッチすれば、その位置を返し
ますが、string-looking-at は指定された位置でマッチするかを返します。

  :start       : チェックする文字列の開始位置を指定します。
                 適正な値でないとき、戻り値は nil となります。
  :end         : チェックする文字列の終了位置を指定します。
                 適正な値でないとき、戻り値は nil となります。
  :case-fold   : ASCII 文字の大文字小文字の区別の方法を指定します。
                 REGEXP が[コンパイル済み正規表現]の場合は、:case-fold
                 指定は意味を持ちません。
        nil     - 大文字小文字を区別して検索します。
        :smart  - REGEXP に大文字が含まれていない場合、大文字小文字を区
                  別せずに検索します。
        上記以外- 大文字小文字を区別せずに検索します。

例:
  (string-looking-at "a+b" "aaab")
  => 0

  (string-looking-at "a+b" "baaab")
  => nil

  (string-looking-at "a+b" "aaab" :start 2)
  => 2

  (string-looking-at "a+b" "aaab" :start 3 :end 6)
  => nil

  (string-looking-at "a+b" "AaAAB" :case-fold :smart)
  => 0
```

関連: `string-match`, `string-matchp`, `looking-at`, `match-string`, `正規表現の表記`

## `string-match`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `string-match REGEXP STRING &optional START END`

```text
指定された文字列が正規表現に一致するかどうかを返します。

  REGEXP : 正規表現
  STRING : チェックする文字列
  START  : 文字列の開始位置
  END    : 文字列の終了位置

互換性：
  muleあり。
  Common Lispなし。
```

関連: `string-matchp`, `string-looking-at`, `looking-at`, `正規表現の表記`

## `string-matchp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `string-matchp REGEXP STRING &optional START END`

```text
| string-match と string-matchp とはどこがどう
| 違うのでしょう？

p 付きの方は大文字小文字を区別しません。
```

関連: `string-match`, `string-looking-at`

## `string-not-equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-not-equal STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して等しくなければ一致しない
文字のインデックスを、そうでなければnilを返します。
string-equalの反対の機能です。
```

関連: `string-equal`

## `string-not-greaterp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-not-greaterp STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して「<=」の条件を満たせ
ば一致しない文字のインデックスを、そうでなければnilを返します。
```

関連: `string<`, `string>`, `string<=`, `string>=`, `string-lessp`, `string-not-lessp`, `string-greaterp`

## `string-not-lessp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-not-lessp STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を大文字小文字に関係なく比較して「>=」の条件を満たせ
ば一致しない文字のインデックスを、そうでなければnilを返します。
```

関連: `string<`, `string>`, `string<=`, `string>=`, `string-lessp`, `string-greaterp`, `string-not-greaterp`

## `string-replace-match`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `string-replace-match STRING REPLACEMENT`

```text
string-matchで検索した結果を使って文字列の置換を行います。

  STRING      : string-matchで指定した文字列を指定します。
  REPLACEMENT : 置換する文字列を指定します。
                REPLACEには正規表現に部分\1-\9を含めることが可能です。

使用例：
  ;;; 文字列を置換してみる。
  (setq str "01356:00001:error message")
  => "01356:00001:error message"
  (when (string-match "\\([0-9]+\\):\\([0-9]+\\):\\(.*\\)" str)
    (setq str (string-replace-match str "\\1,\\3")))
  => "01356,error message"
```

関連: `string-match`

## `string-right-trim`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-right-trim CHARACTER-BAG STRING`

```text
文字列の末尾から指定した文字群を削除します。

  STRING         : 文字列
  CHARACTGER-BAG : 削除する文字群です。
  
使用例：
  ;;;  末尾の"/"や"\"を取り除きます。
  (string-right-trim "/\\" "/foo/bar/zzz.txt/")
  => "/foo/bar/zzz.txt"
```

関連: `string-trim`, `string-left-trim`

## `string-trim`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-trim CHARACTER-BAG STRING`

```text
文字列の前後から指定した文字群を削除します。

  STRING         : 文字列
  CHARACTGER-BAG : 削除する文字群です。
  
使用例：
  ;;;  前後の"/"や"\"を取り除きます。
  (string-trim "/\\" "/foo/bar/zzz.txt/")
  => "foo/bar/zzz.txt"
```

関連: `string-right-trim`, `string-left-trim`

## `string-upcase`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string-upcase STRING &key :start :end`

```text
STRING を大文字にした文字列を返します。引数 STRING は保存されます。

使用例：
  (string-upcase "xyzzy")
  => "XYZZY"
  (string-upcase "xyzzy" :start 2 :end 4)
  => "xyZZy"
```

関連: `nstring-upcase`, `char-upcase`, `upcase-word`

## `string/=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string/= STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して等しくなければ一致しない文字のインデックスを、
そうでなければnilを返します。
英字の大文字と小文字は区別します。string=の反対の機能です。
```

関連: `string=`

## `string<`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string< STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して「<」の条件を満たせば一致しない文字のインデ
ックスを、そうでなければnilを返します。

使用例：
  (string< "aa" "aa")
  => nil
  (string< "aa" "ab")
  => 1
```

関連: `string=`, `string>`, `string<=`, `string>=`, `string-lessp`, `string-not-lessp`, `string-greaterp`, `string-not-greaterp`

## `string<=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string<= STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して「<=」の条件を満たせば一致しない文字のイン
デックスを、そうでなければnilを返します。
```

関連: `string=`, `string<`, `string>`, `string>=`, `string-lessp`, `string-not-lessp`, `string-greaterp`, `string-not-greaterp`

## `string=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string= STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して等しければt、そうでなければnilを返します。
英字の大文字と小文字は区別します。

使用例：
  (string= "foo" "foo")
  => t
  (string= "foo" "Foo")
  => nil
  (string= "together" "frog" :start1 1 :end1 3 :start2 2)
  => t

参考：
  case-sensitive        case-insensitive
  ----                  ----
  string=               string-equal
  string/=              string-not-equal
  string<               string-lessp
  string>               string-greaterp
  string<=              string-not-greaterp
  string>=              string-not-lessp
```

関連: `equal`, `string-equal`, `string/=`, `string>`, `string<`, `string<=`

## `string>`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string> STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して「>」の条件を満たせば一致しない文字のインデ
ックスを、そうでなければnilを返します。

使用例：
  (string> "ac" "ab")
  => 1
  (string> "ac" "ac")
  => nil
  (string> "AC" "ab")
  => nil
```

関連: `string<`, `string<=`, `string>=`, `string-lessp`, `string-not-lessp`, `string-greaterp`, `string-not-greaterp`

## `string>=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `string>= STRING1 STRING2 &key :start1 :end1 :start2 :end2`

```text
STRING1とSTRING2を比較して「>=」の条件を満たせば一致しない文字のイン
デックスを、そうでなければnilを返します。
```

関連: `string<`, `string>`, `string<=`, `string-lessp`, `string-not-lessp`, `string-greaterp`, `string-not-greaterp`

## `substitute-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `substitute-string STRING PATTERN REPLACEMENT &key :case-fold :start :end :skip :count`

```text
文字列中の正規表現パターンを置換して返します。

  :case-fold  : nil なら大文字小文字を区別する。
                :smart なら、パターンに大文字が現れないときのみ区別しない。
                その他の場合なら大文字小文字を区別しない。                
  :start      : 開始位置。デフォルトは 0 で非負の整数
  :end        : 終了位置。デフォルトは nil で、 nil の場合は列の長さを
                指定した場合と等しい動作
  :skip       : 指定された回数マッチするまでは置換を行わない
  :count      : 置き換える最大の回数

使用例：
  ;;; 部分文字列を置換する。
  (substitute-string "Hogehoge" "ho" "pa")
  => "Hogepage"

  ;;; 大文字小文字を区別せず置換する。
  (substitute-string "Hogehoge" "ho" "pa" :case-fold t)
  => "pagepage"

  ; 正規表現・メタ文字の利用
  (substitute-string "abc123cdef" "[^0-9]*\\([0-9]+\\).*" "\\1 in \\&")
  =>"123 in abc123cdef"
```

関連: `replace-string`, `substitute`, `replace`, `quote-string`

## `substring`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `substring STRING START &optional END`

```text
指定された文字列の部分文字列を返します。
START, END に負の数値を指定すると文字列の最後からカウントします。

互換性：
  Common Lispにはなし(ただしsubseqがほぼ同等の機能）
  muleあり。
```

関連: `subseq`

## `transpose-words`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `transpose-words &optional (ARG 1)`

```text
カーソル位置の単語を後方の単語と入れ換えます。[ESC t]
```

関連: `transpose-region`

## `upcase-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `upcase-word &optional (ARG 1)`

```text
カーソル位置から単語の末尾までを大文字に変換します。[ESC u]
```

関連: `downcase-word`, `capitalize-word`, `upcase-region`, `upcase-selection`, `string-upcase`
