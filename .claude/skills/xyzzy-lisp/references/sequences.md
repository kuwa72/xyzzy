# シーケンス (sequences)

reference/reference.xml から自動生成。45 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `complement`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `complement FN`

```text
FN と逆の結果（not）を返す関数を作り、その関数を返します。

使用例:
  (funcall (complement 'oddp) 4)
  => t
```

関連: `not`

## `concatenate`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `concatenate RESULT-TYPE &rest SEQUENCES`

```text
SEQUENCES を結合して RESULT-TYPE のシーケンスを新しく作り、返します。

RESULT-TYPE には make-sequence と同様のものが使用できます。
RESULT-TYPE の値によって、大まかには以下の関数と同じ挙動をします。
  'list   <--> append
  'string <--> concat
  'vector <--> vconcat

なお SEQUENCES と RESULT-TYPE の型は必ずしも一致しなくてもかまいません。
```

関連: `make-sequence`, `append`, `concat`, `vconcat`

## `copy-seq`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-seq SEQUENCE`

```text
SEQUENCEのコピーを作成して返します。元のSEQUENCEとはequalpだがeqではありません。

  (copy-seq x) == (subseq x 0)
```

関連: `copy-list`, `copy-string`, `make-vector`

## `count`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `count ITEM SEQUENCE &key :from-end :test :test-not :start :end :key`

```text
ITEMとのテストを満足するSEQUENCE中の要素数を返します。結果は非負の整数です。

  :from-end : 他の関数との互換性のために用意されたもので、結果に影響しません。
  :test     : テストを行う2項演算子
  :start    : テストする開始位置
  :end      : テストの終了位置
```

関連: `count-if`, `count-if-not`, `si:*tree-count`

## `count-if`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `count-if TEST SEQUENCE &key :from-end :start :end :key`

```text
TESTを満足するSEQUENCE中の要素数を返します。結果は非負の整数です。

  :from-end : 他の関数との互換性のために用意されたもので、結果に影響しません。
  :test     : テストを行う2項演算子
  :start    : テストする開始位置
  :end      : テストの終了位置
```

関連: `count`, `count-if-not`

## `count-if-not`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `count-if-not TEST SEQUENCE &key :from-end :start :end :key`

```text
TESTを満足しないSEQUENCE中の要素数を返します。結果は非負の整数です。

  :from-end : 他の関数との互換性のために用意されたもので、結果に影響しません。
  :test     : テストを行う2項演算子
  :start    : テストする開始位置
  :end      : テストの終了位置
```

関連: `count`, `count-if`

## `delete`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete ITEM SEQUENCE &key :from-end :test :test-not :start :end :count :key`

```text
SEQUENCEの中でITEMと一致するものを削除したシーケンスを返します。
引数 SEQUENCE は破壊されます。

  :count    : 削除する文字数を制限します。
  :from-end : :countが指定された場合にのみ意味を持ちます。
         nil    SEQUENCEの先頭から削除します。
         t      SEQUENCEの後尾から削除します。

使用例：
  ;;; removeとdeleteを使ってみる。
  (setq foo "abcabcdef")        => "abcabcdef"
  (remove #\b foo)              => "acacdef"
  foo                           => "abcabcdef"
  (delete #\b foo)              => "acacdef"
  foo                           => "acacdef"
```

関連: `remove`, `delete-if`, `delete-if-not`, `delete-duplicates`

## `delete-duplicates`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `delete-duplicates SEQUENCE &key :from-end :test :test-not (:start 0) (:end (length SEQUENCE)) (:key #'identity)`

```text
SEQUENCE の中から重複する要素を削除したシーケンスを返します。
delete 同様、引数 SEQUENCE は破壊されます。

 :from-end  non-nil ならシーケンスの終わりから重複する要素を削除していきます。
```

関連: `delete`, `remove-duplicates`

## `delete-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete-if PREDICATE SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEの中でPREDICATEを満たすものを削除したシーケンスを返します。
引数 SEQUENCE は破壊されます。
```

関連: `remove-if`, `delete`, `delete-if-not`

## `delete-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete-if-not PREDICATE SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEの中でPREDICATEを満たさないものを削除したシーケンスを返します。
引数 SEQUENCE は破壊されます。
```

関連: `remove-if-not`, `delete`, `delete-if`

## `elt`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `elt SEQUENCE INDEX`

```text
SEQUENCEのINDEX番目の要素を返します。
INDEXは0を基底とします。なければnilを返します。
```

関連: `nth`

## `every`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `every PREDICATE SEQUENCE &rest MORE-SEQUENCES`

```text
SEQUENCEの先頭の要素から順番にPREDICATEを適用していき、PREDICATEが
nil を返すと、nilをすぐに返します。
全ての要素がPREDICATEを満たす場合、 t を返します。

MORE-SEQUNCESが与えられた時、SEQUENCEの中で最も短いものの終わりまで実行されます。
```

関連: `some`, `notevery`

## `fill`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fill SEQUENCE ITEM &key :start :end`

```text
SEQUENCEのそれぞれをITEMに置換えます。元のSEQUENCEは置き換えられます。

使用例：
  ;;; シーケンスを作って、変更してみる。
  (setq foo (make-sequence 'string 8 :initial-element #\a))
  => "aaaaaaaa"
  (fill foo #\b :start 3 :end 4)
  => "aaabaaaa"
  foo
  => "aaabaaaa"
```

## `find`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find ITEM SEQUENCE &key :from-end :test :test-not :start :end :key`

```text
SEQUENCE の中で ITEM との :test を満たすものがあればそれを返します。なければ
nilを返します。

使用例：
  ;;; リストから'aを探してみる。
  (find 'a '(e c a b))
  => a
```

関連: `find-if`, `find-if-not`, `position`, `member`, `getf`

## `find-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find-if PREDICATE SEQUENCE &key :from-end :start :end :key`

```text
SEQUENCEの中でPREDICATEを満たすものがあればそれを返します。なければnilを返します。
```

関連: `find`, `find-if-not`

## `find-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find-if-not PREDICATE SEQUENCE &key :from-end :start :end :key`

```text
SEQUENCEの中でPREDICATEを満たさないものがあればそれを返します。なければ
nilを返します。
```

関連: `find`, `find-if`

## `length`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `length SEQUENCE`

```text
sequence(文字列や、リスト、配列)の長さを求めます。
配列にfill-pointerがある場合は、そこまでの長さになります。

使用例：
  (length "abcd")               => 4
  (length (list 1 2 3))         => 3
  (length (make-array 7))       => 7
  (length (make-array 7 :fill-pointer 4))
                                => 4
```

関連: `list-length`, `fill-pointer`

## `make-sequence`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `make-sequence TYPE SIZE &key :initial-element`

```text
要素のタイプが TYPE でサイズが SIZE なシーケンスを作成して返します。
:initial-element が与えられた場合はそれぞれの項目はそれで初期化されます。
  
TYPE の値と返されるシーケンスは以下の通りです。
  'list          ──→ リスト
  'vector        ─┬→ ベクタ
  'simple-vector ─┘
  'string        ─┬→ 文字列
  'simple-string ─┘

TYPE にはリストを与えることもでき、その場合は最初の要素でシーケンスが決まります。
  '(list ...)         ──→ リスト
  '(array ...)        ─┬→ 配列
  '(simple-array ...) ─┘
最初の要素が list の場合、二番目以降の引数は無視されます。
最初の要素が array または simple-array の場合は三番目の要素まで意味を持ちます。
二番目の要素は値によって以下のように変化します。リストの場合はその最初の要素で判断されます。
  t                  ─┬→ 配列
  nil                ─┘
  character          ─┬→ 文字列
  base-character     ─┤
  standard-char      ─┤
  extended-character ─┘
三番目の要素は 1 または (*) または (SIZE に等しい数値) でなければなりませんが、
どれを選んでも動作に違いはないようです。
  
使用例：
  ;;; #\a が 8 文字の文字列を作ってみる
  (make-sequence 'string 8 :initial-element #\a)
  => "aaaaaaaa"
  (make-sequence 'list 4 :initial-element "abc")
  => (#1="abc" #1# #1# #1#)
  (make-sequence 'vector 4 :initial-element 'a)
  => #(a a a a)
  ;;; あえて TYPE に array を与えてみる
  (make-sequence '(array t (*)) 4 :initial-element 'a)
  => #(a a a a)
  (make-sequence '(array character 1) 8 :initial-element #\a)
  => "aaaaaaaa"
```

関連: `make-vector`, `make-array`, `make-list`

## `map`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `map RESULT-TYPE FUNCTION SEQUENCE &rest MORE-SEQUENCES`

```text
SEQUENCE に FUNCTION を適用して、RESULT-TYPE に応じたシーケンスを返します。
mapcar との違いは、リストだけでなく文字列や配列等のシーケンスにも適用できる
ことと、RESULT-TYPE の指定が必要なことです。

  RESULT-TYPE : nil、又は make-sequence の TYPE と同じものが使えます。
                nil の場合 戻り値は常に nil で、通常 副作用を目的として
                使用されます。
  FUNCTION    : mapcar と同様、SEQUENCE の各要素をひとつずつ取り出したも
                のとなります。 MORE-SEQUENCES がある場合もやはり mapcar 
                と同じように適用されます。

使用例:
  ;;; 文字列の場合は一つ一つの要素が string ではなく char になることに注意
  (map 'list #'char-code "abc")
  => (97 98 99)
```

関連: `map-into`, `make-sequence`, `mapcar`

## `map-into`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `map-into RESULT-SEQUENCE FUNCTION &rest SEQUENCES`

```text
SEQUENCES に map と同じように FUNCTION を適用し、その結果を 
RESULT-SEQUENCE に埋め込みます。RESULT-SEQUENCE が一番短い SEQUENCE より
も長い場合には RESULT-SEQUENCE の後部の余った要素は変化しません。
  
使用例:
  (map-into "abcde" #'char-upcase "fgh")
  => "FGHde"
  (map-into '(1 2 3) #'- '(4 5 6 7 8))
  => (-4 -5 -6)
```

関連: `map`

## `merge`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `merge RESULT-TYPE SEQUENCE1 SEQUENCE2 PREDICATE &key :key`

```text
SEQUENCE1とSEQUENCE2を併合します。SEQUENCE1とSEQUENCE2は破壊されません。
PREDICATEによりSEQUENCE1とSEQUENCE2の値を比較し、非nilならば SEQUENCE1の値を 
nil ならば SEQUENCE2の値を順にマージしていきます。

  RESULT-TYPE : 結果となるシーケンスの型を指定します。
  PREDICATE   : シーケンス同士を比較する関数を指定します。
  :key        : 比較対照を取得する関数を指定します。

例
  (merge 'list '(1 2 3 5 8) '(2 4 6) #'<) => (1 2 2 3 4 5 6 8)
  (merge 'string "AbCF" "aBcd" #'char-lessp) => "AabBCcdF"
```

関連: `union`, `concatenate`, `stable-sort`

## `mismatch`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `mismatch SEQUENCE1 SEQUENCE2 &key :from-end :test :test-not (:key #'identity) (:start1 0) (:start2 0) :end1 :end2`

```text
SEQUENCE1 と SEQUENCE2 を比較し、一致しない要素のインデックスを返します。

  :start1  SEQUENCE1 の比較開始位置
  :start2  SEQUENCE2 の比較開始位置
  :end1    SEQUENCE1 の比較終了位置
  :end2    SEQUENCE2 の比較終了位置

:start1 と :start2 の値が異なる場合、SEQUENCE1 内でのインデックスを返します。

使用例:
  (mismatch "abcd" "abxd")
  => 2

備考:
  :from-end は実装されていないようです。
```

## `notany`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `notany PREDICATE SEQUENCE &rest MORE-SEQUENCES`

```text
SEQUENCEの先頭の要素から順番にPREDICATEを適用していき、PREDICATEが
非nilな値を返すと、 nil をすぐに返します。
PREDICATEを満たす要素が見つからない時は t を返します。

MORE-SEQUNCESが与えられた時、SEQUENCEの中で最も短いものの終わりまで実行されます。
```

関連: `notevery`, `some`

## `notevery`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `notevery PREDICATE SEQUENCE &rest MORE-SEQUENCES`

```text
SEQUENCEの先頭の要素から順番にPREDICATEを適用していき、PREDICATEが
nil を返すと、t をすぐに返します。
全ての要素がPREDICATEを満たす場合、 nil を返します。

MORE-SEQUNCESが与えられた時、SEQUENCEの中で最も短いものの終わりまで実行されます。
```

関連: `notany`, `every`

## `nreverse`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nreverse SEQUENCE`

```text
SEQUENCE を逆順にした新しいシーケンスを作成して返します。
引数 SEQUENCE は破壊されます。

使用例：
  (setq lst '(a b c))
  => (a b c)
  (nreverse lst)
  => (c b a)
  lst
  => (a)
```

関連: `reverse`

## `nsubstitute`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `nsubstitute NEWITEM OLDITEM SEQUENCE &key :from-end :test :test-not :start :end :count :key`

```text
SEQUENCE に対して OLDITEM との :test を満足する要素を NEWITEM に置き換えたシーケンスを返します。
引数 SEQUENCE は破壊されます。

  :test     : テストを行う2項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `nsubst`, `nsubstitute`, `nsubstitute-if`, `nsubstitute-if-not`, `substitute`, `nsbulis`

## `nsubstitute-if`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `nsubstitute-if NEWITEM TEST SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEに対してTESTを満足する要素をNEWITEMに置き換えたシーケンスを返します。
引数 SEQUENCE は破壊されます。

  TEST      : テストを行う単項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、 non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `nsubst-if`, `nsubstitute`, `nsubstitute-if-not`, `substitute-if`

## `nsubstitute-if-not`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `nsubstitute-if-not NEWITEM TEST SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEに対してTESTを満足しない要素をNEWITEMに置き換えたシーケンスを返します。
引数 SEQUENCE は破壊されます。

  TEST      : テストを行う単項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、 non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `nsubst-if-not`, `nsubstitute`, `nsubstitute-if`, `substitute-if-not`

## `position`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `position ITEM SEQUENCE &key :from-end :test :test-not :start :end :key`

```text
SEQUENCE の中で ITEM との :test を満たすものがあればそのインデックスを返します。
なければ nil を返します。

使用例：
  ;;; リストの中から'aのインデックスを調べる
  (position 'a '(e c a b))
  => 2
```

関連: `position-if`, `position-if-not`, `find`, `member`

## `position-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `position-if PREDICATE SEQUENCE &key :from-end :start :end :key`

```text
SEQUENCEの中でPREDICATEを満たすものがあればそのインデックスを返します。
なければnilを返します。
```

関連: `position`, `position-if-not`

## `position-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `position-if-not PREDICATE SEQUENCE &key :from-end :start :end :key`

```text
SEQUENCEの中でPREDICATEを満たさないものがあればそのインデックスを返します。
なければnilを返します。
```

関連: `position`, `position-if`

## `reduce`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `reduce FUNCTION SEQUENCE &key :from-end :start :end :initial-value (:key #'identity)`

```text
2項演算子であるFUNCTIONで、SEQUENCEに対して畳み込みを行います。
  
  FUNCTION  : 2項演算子。
  :from-end : nil なら先頭から、non-nil なら最後の要素から畳み込みを行います。
  :start    : 畳み込みを行う SEQUENCE の開始インデックスです。デフォルトは 0 です。 
              :from-end が non-nil なら終了インデックスになります。
  :end      : 畳み込みを行う SEQUENCE の終了インデックスです。デフォルトは nil です。
              :from-end が non-nil なら開始インデックスになります。
  :initial-value : non-nil ならばこの値を初期値として使用します。
  :key      : FUNCTION に渡す前に要素に適用する関数。デフォルトは #'identity です。

 (reduce #'- '(1 2 3)) = (- (- 1 2) 3)
 (reduce #'- '(1 2 3) :initial-value 10) = (- (- (- 10 1) 2) 3)
 (reduce #'- '(1 2 3) :from-end t :initial-value 10) = (- 1 (- 2 (- 3 10)))
 (reduce #'- '((1) (2) (3)) :key #'car) = (- (- (car '(1)) (car '(2))) (car '(3)))

補足：
  xyzzy 0.2.2.241 から:keyパラメータを指定可能です。
```

## `remove`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `remove ITEM SEQUENCE &key :from-end :test :test-not :start :end :count :key`

```text
SEQUENCE の中で ITEM と一致するものを削除したシーケンスを返します。
引数 SEQUENCE は保存されます。

  :count    : 削除する文字数を制限します。
  :from-end : :countが指定された場合にのみ意味を持ちます。
         nil    SEQUENCEの先頭から削除します。
         t      SEQUENCEの後尾から削除します。

使用例：
  ;;; removeとdeleteを使ってみる。
  (setq foo "abcabcdef")        => "abcabcdef"
  (remove #\b foo)              => "acacdef"
  foo                           => "abcabcdef"
  (delete #\b foo)              => "acacdef"
  foo                           => "acacdef"
```

関連: `delete`, `remove-if`, `remove-if-not`, `remove-duplicates`

## `remove-duplicates`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `remove-duplicates SEQUENCE &key :from-end :test :test-not (:start 0) :end (:key #'identity)`

```text
SEQUENCE の中から重複する要素を削除したシーケンスを返します。
remove 同様、引数 SEQUENCE は保存されます。

  :from-end  non-nil ならシーケンスの終わりから重複する要素を削除していきます。
```

関連: `remove`, `delete-duplicates`

## `remove-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `remove-if PREDICATE SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCE の中で PREDICATE を満たすものを削除したシーケンスを返します。
引数 SEQUENCE は保存されます。
```

関連: `remove`, `remove-if-not`, `delete-if`

## `remove-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `remove-if-not PREDICATE SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEの中でPREDICATEを満たさないものを削除したシーケンスを返します。
元のSEQUENCEは保存されます。
```

関連: `remove`, `remove-if`, `delete-if-not`

## `replace`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `replace SEQUENCE1 SEQUENCE2 &key :start1 :end1 :start2 :end2`

```text
SEQUENCE1 を SEQUENCE2 で置換します。元の SEQUENCE は置き換えられます。
SEQUENCE1 の :start1-:end1 の位置に、 SEQUENCE2 の :start2-:end2 を挿入
します。

使用例：
  (setq foo (make-sequence 'string 8 :initial-element #\a))
  => "aaaaaaaa"
  (setq bar (make-sequence 'string 3 :initial-element #\b))
  => "bbb"
  (replace foo bar)
  => "bbbaaaaa"
  (replace foo bar :start1 4 :end1 5)
  => "bbbabaaa"
```

関連: `substitute-string`

## `reverse`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `reverse SEQUENCE`

```text
SEQUENCE を逆順にした新しいシーケンスを作成して返します。
引数 SEQUENCE は保存されます。
```

関連: `nreverse`

## `some`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `some PREDICATE SEQUENCE &rest MORE-SEQUENCES`

```text
SEQUENCEの先頭の要素から順番にPREDICATEを適用していき、PREDICATEが
非nilな値を返すと、その値をSOMEの戻り値としてすぐに終了します。
PREDICATEを満たす要素が見つからない時は nil を返します。

MORE-SEQUNCESが与えられた時、SEQUENCEの中で最も短いものの終わりまで実行されます。
```

関連: `every`, `notany`

## `sort`

- Function / package: lisp
- 呼び出し: `sort SEQUENCE PREDICATE &key :key`

```text
SEQUENCE を PREDICATE に従った順番に並び替えたものを返します。元の SEQUENCE
は変更されます。 sort は安定であることは保証されません。安定なソートが必要
なときは stable-sort を使いましょう。

  SEQUENCE  : ソートするシーケンスを指定します。
  PREDICATE : 比較関数を指定します。
  :key      : 比較対象を取得する関数を指定します。

使用例：
  (setq *test-seq* '(("foo") ("bar") ("hoge")))
  => (("foo") ("bar") ("hoge"))
  (setq *test-seq* (sort *test-seq* #'string-lessp :key #'car))
  => (("bar") ("foo") ("hoge"))
  *test-seq*
  => (("bar") ("foo") ("hoge"))
 
  (setq *test-seq* '(("foo") ("bar") ("hoge")))
  => (("foo") ("bar") ("hoge"))
  (sort *test-seq* #'string-lessp :key #'car)
  => (("bar") ("foo") ("hoge"))
  *test-seq*
  => (("foo") ("hoge"))

参考：
  [xyzzy:06221] (こっそり)バージョンアップのお知らせ
  ・sort のアルゴリズムを quick から merge に変更
  (比較回数が少ない分、merge の方が速いっぽい)。
  結果、stable-sort と同じになった(が、依存しないように)。
  従来は *たまたま* (eq list (sort list)) だったが、
  そうではなくなったので注意すること。
```

関連: `stable-sort`, `[xyzzy:06221]`

## `stable-sort`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `stable-sort SEQUENCE PREDICATE &key :key`

```text
SEQUENCE を PREDICATE に従った順番に並び替えたものを返します。元の SEQUENCE
は変更されます。 stable-sort は安定なソートを行います。つまり PREDICATE によっ
て同順と見なされる要素間の順序は、ソート前と同じであることが保証されます。

  SEQUENCE  : ソートするシーケンスを指定します。
  PREDICATE : 比較関数を指定します。
  :key      : 比較対象を取得する関数を指定します。

使用例：
  (setq *test-seq* '(("foo") ("bar") ("hoge")))
  => (("foo") ("bar") ("hoge"))
  (setq *test-seq* (stable-sort *test-seq* #'string-lessp :key #'car))
  => (("bar") ("foo") ("hoge"))
  *test-seq*
  => (("bar") ("foo") ("hoge"))
 
  (setq *test-seq* '(("foo") ("bar") ("hoge")))
  => (("foo") ("bar") ("hoge"))
  (stable-sort *test-seq* #'string-lessp :key #'car)
  => (("bar") ("foo") ("hoge"))
  *test-seq*
  => (("foo") ("hoge"))
```

関連: `sort`, `[xyzzy:06221]`

## `subseq`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `subseq SEQUENCE START &optional END`

```text
SEQUENCEのSTART番目からENDもしくは最後までの新しいsequenceを返します。
```

関連: `last`, `butlast`, `substring`

## `substitute`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `substitute NEWITEM OLDITEM SEQUENCE &key :from-end :test :test-not :start :end :count :key`

```text
SEQUENCE に対して OLDITEM との :test を満足する要素を NEWITEM に置き換え
たシーケンスを返します。引数 SEQUENCE は保存されますが、戻り値と一部を共有する
かもしれません。

  :test     : テストを行う2項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `substitute-if`, `substitute-if-not`, `nsubstitute`, `subst`, `substitute-string`, `sublis`

## `substitute-if`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `substitute-if NEWITEM TEST SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEに対してTESTを満足する要素をNEWITEMに置き換えたシーケンスを返します。
引数 SEQUENCE は保存されますが、戻り値と一部を共有するかもしれません。

  TEST      : テストを行う単項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `subst-if`, `substitute`, `substitute-if-not`, `nsubstitute-if`

## `substitute-if-not`

- Function / package: lisp / 定義: sequence.l
- 呼び出し: `substitute-if-not NEWITEM TEST SEQUENCE &key :from-end :start :end :count :key`

```text
SEQUENCEに対してTESTを満足しない要素をNEWITEMに置き換えたシーケンスを返します。
引数 SEQUENCE は保存されますが、戻り値と一部を共有するかもしれません。

  TEST      : テストを行う単項演算子
  :start    : 開始位置。デフォルトは0で非負の整数
  :end      : 終了位置。デフォルトはnilで、nilの場合はSEQUENCEの長さを指定した
              場合と等しい動作。
  :count    : 置き換える最大の回数。
  :from-end : nil ならば先頭から、non-nil で末尾から置換を行う。 :count
              が与えられた時のみ意味を持つ。
```

関連: `subst-if-not`, `substitute`, `substitute-if`, `nsubstitute-if-not`
