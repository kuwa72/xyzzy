# 配列 (arrays)

reference/reference.xml から自動生成。19 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `adjustable-array-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `adjustable-array-p ARRAY`

```text
ARRAY がサイズ変更可能なら t、不可能なら nil を返します。
```

関連: `vector-push-extend`, `make-array`

## `aref`

- Accessor / package: lisp / 定義: builtin.l
- 呼び出し: `aref ARRAY &rest SUBSCRIPTS`

```text
SUBSCRIPTS で特定される配列の要素にアクセスします。SUBSCRIPTS がなく配列が
ゼロ次元の場合は、配列のただひとつの要素にアクセスします。
具体的な使い方については、以下の例を参照してください。

使用例：
  ;;; 2x2の初期化された配列を作ります。値の取得・変更を行います。
  (setf foo (make-array '(2 2) :initial-contents '((1 2) (3 4))))
  =>#2A((1 2) (3 4))
  (aref foo 1 1);配列fooの要素(1,1)の値を得る
  =>4
  (setf (aref foo 1 1) 10);配列fooの要素(1,1)の値を10にする
  =>10
  foo
  =>#2A((1 2) (3 10))
```

関連: `make-array`, `setf`, `svref`

## `array-dimension`

- Function / package: lisp / 定義: array.l
- 呼び出し: `array-dimension ARRAY AXIS-NUMBER`

```text
配列 ARRAY の AXIS-NUMBER 番目の次元のサイズを返します。
AXIS-NUMBER は 0 から始まる整数値です。
なお、フィルポインタを持っているベクタに関しても、本来のサイズを返します。

使用例:
  (setf x (make-array '(2 3)))
  => #2A((nil nil nil) (nil nil nil))
  (array-dimension x 0)
  => 2
  (array-dimension x 1)
  => 3

  ;; フィルポインタつきのベクタ
  (setf x (make-array 5 :initial-contents '(a b c d e) :fill-pointer 3))
  => #(a b c)
  (array-dimension x 0)
  => 5
  (length x) ; length だとフィルポインタまでの長さになる
  => 3
```

関連: `array-dimensions`, `array-total-size`

## `array-dimensions`

- Function / package: lisp / 定義: array.l
- 呼び出し: `array-dimensions ARRAY`

```text
配列 ARRAY の各次元のサイズをリストにして返します。

使用例:
  (setf x (make-array '(2 3)))
  => #2A((nil nil nil) (nil nil nil))
  (array-dimensions x)
  => (2 3)
```

関連: `array-dimension`, `array-total-size`, `make-array`

## `array-element-type`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `array-element-type ARRAY`

```text
ARRAY の要素のタイプを判別します。
配列なら t、文字列なら character を返します。
```

関連: `make-array`

## `array-has-fill-pointer-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `array-has-fill-pointer-p ARRAY`

```text
配列 ARRAY がフィルポインタを持っているなら t、
持っていないなら nil を返します。
```

関連: `fill-pointer`

## `array-rank`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `array-rank ARRAY`

```text
配列 ARRAY の次元を返します。

使用例:
  (setf x (make-array '(2 3)))
  => #2A((nil nil nil) (nil nil nil))
  (array-rank x)
  => 2
```

関連: `make-array`

## `array-row-major-index`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `array-row-major-index ARRAY &rest SUBSCRIPTS`

```text
ARRAY の SUBSCRIPTS で表される要素が、ARRAY を一次元の配列とみなしたときに
何番目の要素にあたるかのインデックスを返します。

SUBSCRIPTS の数は ARRAY の次元と等しい必要があり、
また各引数は ARRAY の各次元のサイズ未満である必要があります。

使用例:
  (setf x (make-array '(2 3)))
  => #2A((nil nil nil) (nil nil nil))
  (array-row-major-index x 0 2)
  => 2
  (array-row-major-index x 1 1)
  => 4

  上の例はこんな感じです。

        0   1   2
     ┌─┬─┬─┐
   0 │ 0│ 1│ 2│
     ├─┼─┼─┤
   1 │ 3│ 4│ 5│
     └─┴─┴─┘
```

関連: `row-major-aref`

## `array-total-size`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `array-total-size ARRAY`

```text
配列 ARRAY の全要素数を返します。

使用例:
  (setf x (make-array '(2 3)))
  => #2A((nil nil nil) (nil nil nil))
  (array-total-size x)
  => 6
```

関連: `array-dimension`, `array-dimensions`

## `fill-pointer`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fill-pointer VECTOR`

```text
ベクタ（一次元配列） VECTOR のフィルポインタの位置を返します。
VECTOR がフィルポインタを持たない場合、エラーとなります。
  
備考:
  フィルポインタは、ベクタの見た目上の最後の位置を決めます。
  make-array では与えられた DIMENSION の配列を作りますが、
  フィルポインタを与えた場合、画面に表示されたり vector-pop などの関数が
  作用したりするのはフィルポインタの位置までとなります。

  なお、aref を使えばフィルポインタ以降の要素にもアクセスできます。
  また、フィルポインタに関係ないベクタ本来の長さを知りたい場合は
  array-dimension （または array-dimensions）を使います。
```

関連: `array-has-fill-pointer-p`, `make-array`, `vector-pop`, `vector-push`, `length`

## `make-array`

- Function / package: lisp / 定義: array.l
- 呼び出し: `make-array DIMENSIONS &rest REST &key (:element-type t) (:initial-element () ies-p) (:initial-contents () ics-p) :fill-pointer :adjustable :displaced-to (:displaced-index-offset 0)`

```text
DIMENSIONS で示される大きさ・次元の配列をつくり、それを値として返します。
もし、DIMENSIONS が nil なら、ゼロ次元配列がつくられます。
たとえば、変数 hoge をサイズ4の一次元配列(=サイズ4のベクタ)にするためには、

  (setf hoge (make-array 4))
  => #(nil nil nil nil)

変数 foo をサイズ2x4の二次元配列とするためには、

  (setf foo (make-array '(2 4)))
  => #2A((nil nil nil nil) (nil nil nil nil))

とします。
:element-type は、新しい配列の各要素の型を規定します。
:initial-element が与えられている場合、新しい配列の全要素はすべて
:initial-element に初期化されます。これに対して、:initial-contents が与えら
れている場合、新しい配列の各要素が :initial-contents で初期化されます。
たとえば、

  (make-array '(2 4) :initial-element 10); 2x4の配列をつくる。:initial-elementで初期化
  => #2A((10 10 10 10) (10 10 10 10))
  (setq a (make-array '(2 4) 
  :initial-contents '((0 1 2 3) (3 2 1 0))); 2x4の配列をつくる。:initial-contentsで初期化
  => #2A((0 1 2 3) (3 2 1 0))

なお、配列の要素にアクセスするためには、 aref が使われます。

:displaced-to, :displaced-index-offset 指定は、元の配列の一部からなる共有配列
を生成するために使われます。 copy-seq による複製とは違い、配列自体を共有しています。

  (setq b (make-array '(2 3) :displaced-to a :displaced-index-offset 2))
  => #2A((2 3 3) (2 1 0))

  (setq c (make-array 5 :displaced-to a :displaced-index-offset 1))
  => #(1 2 3 3 2)

  (setf (aref b 1 0) 10)
  a
  => #2A((0 1 2 3) (3 10 1 0))
  b
  => #2A((2 3 3) (10 1 0))
  c
  => #(1 2 3 3 10)
```

関連: `make-sequence`, `aref`, `setf`, `make-vector`, `length`, `array-dimensions`

## `make-vector`

- Function / package: lisp / 定義: array.l
- 呼び出し: `make-vector LENGTH &key (:element-type t) (:initial-element () ies-p) (:initial-contents () ics-p) :fill-pointer :adjustable :displaced-to (:displaced-index-offset 0)`

```text
指定した長さのベクタを返します。

使用例：
  ;;; 長さが10のベクタを作ります。
  (make-vector 10)
  => #(nil nil nil nil nil nil nil nil nil nil)

  ;;; :element-typeにcharacterを指定すると文字列が作成できる
  (make-vector 10 :element-type 'character)
  => "^@^@^@^@^@^@^@^@^@^@"
```

関連: `vector`, `make-array`, `copy-seq`

## `row-major-aref`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `row-major-aref ARRAY INDEX`

```text
ARRAY を一次元の配列とみなしたときに、INDEX 番目になる要素を返します。

使用例:
  (setf x (make-array '(2 3) :initial-contents '((a b c) (d e f))))
  => #2A((a b c) (d e f))
  (row-major-aref x 0)
  => a
  (row-major-aref x 2)
  => c
  (row-major-aref x 3)
  => d
```

関連: `aref`, `svref`, `array-row-major-index`

## `svref`

- Accessor / package: lisp / 定義: builtin.l
- 呼び出し: `svref SIMPLE-VECTOR INDEX`

```text
aref と同じですが、 svref はベクタ(一次元配列)のみにアクセスできます。つ
まり、ベクタ hoge があるとき、 (svref hoge 2) は (aref hoge 2) と同じ意味で
す。ただし、 foo が2x2配列の場合は、 svref でアクセスすることはできません。
```

関連: `aref`, `setf`, `vector`

## `vconcat`

- Function / package: editor / 定義: misc.l
- 呼び出し: `vconcat &rest SEQ`

```text
ベクタを連結します。

使用例:
  (vconcat #(1 3) #(2 5 7))
  => #(1 3 2 5 7)
```

関連: `concatenate`

## `vector`

- Function / package: lisp / 定義: array.l
- 呼び出し: `vector &rest LIST`

```text
要素 LIST からなるベクタをつくります。

  (setf v (vector 1 2 "oop"))
  =>#(1 2 "oop")

ベクタの各要素にアクセスするためには、svref(あるいはaref)が使われます。
```

関連: `svref`, `aref`, `setf`, `length`, `vector-pop`, `vector-push`, `vector-push-extend`, `vectorp`, `fill-pointer`, `make-vector`, `make-array`

## `vector-pop`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `vector-pop VECTOR`

```text
ベクタ（一次元配列） VECTOR のフィルポインタの位置の要素を取り除き、
その要素を返します。

VECTOR はフィルポインタを持っているベクタである必要があります。

使用例:
  ;; フィルポインタなし
  (setf x (make-array 5 :initial-contents '(a b c d e)))
  => #(a b c d e)
  (vector-pop x)
  => エラー

  ;; フィルポインタあり
  (setf x (make-array 5 :initial-contents '(a b c d e) :fill-pointer t))
  => #(a b c d e)
  (vector-pop x)
  => e
  x
  => #(a b c d)
```

関連: `fill-pointer`, `vector-push`

## `vector-push`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `vector-push NEW-ELEMENT VECTOR`

```text
ベクタ（一次元配列） VECTOR のフィルポインタの次の位置に
新しい要素 NEW-ELEMENT を追加します。

VECTOR はフィルポインタを持っているベクタである必要があります。
フィルポインタが VECTOR の最後に達している場合には何もせず nil を返します。

使用例:
  ;; フィルポインタがベクタの長さに一致
  (setf x (make-vector 5 :initial-contents '(a b c d e) :fill-pointer t))
  => #(a b c d e)
  (fill-pointer x)
  => 5
  (vector-push 'xyz x)
  => nil
  x
  =>#(a b c d e)

  ;; フィルポインタがベクタの長さより小さい
  (setf x (make-vector 5 :initial-contents '(a b c d e) :fill-pointer 3))
  => #(a b c)
  (fill-pointer x)
  => 3
  (vector-push 'xyz x)
  => 3
  x
  => #(a b c xyz)
```

関連: `fill-pointer`, `vector-pop`, `vector-push-extend`

## `vector-push-extend`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `vector-push-extend NEW-ELEMENT VECTOR &optional EXTENSION`

```text
ベクタ VECTOR に新しい要素を追加します。長さが足りなければ拡張します。
VECTOR はフィルポインタを持ち、かつアジャスタブルなベクタである必要があります。

  NEW-ELEMENT：新しい要素 
  VECTOR     ：追加するベクタ
  EXTENSION  ：拡張する時のサイズ増加量。
               デフォルトでは 64 増えます。

使用例：
  ;;; 文字を要素とする長さ10のベクタを作成し文字を詰める。
  (setq vec (make-vector 10 :element-type 'character
                            :fill-pointer 0 :adjustable t))
  => ""
  (vector-push-extend #\a vec)  => 0
  vec                           => "a"
  (vector-push-extend #\b vec)  => 1
  vec                           => "ab"

  ;;; 文字を要素とする長さ10のベクタを作成し文字を詰める。
  (setq s (make-vector 10 :element-type 'character
                          :fill-pointer 0 :adjustable t))
  => ""
  (dotimes (i 20 s)
    (vector-push-extend (code-char (+ 64 i)) s)
    (vector-push-extend (code-char (+ 64 i)) s)
    (vector-push-extend (code-char (+ 64 i)) s))
  => "@@@AAABBBCCCDDDEEEFFFGGGHHHIIIJJJKKKLLLMMMNNNOOOPPPQQQRRRSSS"
```

関連: `vector-push`, `adjustable-array-p`, `fill-pointer`, `vector`
