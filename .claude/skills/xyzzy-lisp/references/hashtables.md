# ハッシュ (hashtables)

reference/reference.xml から自動生成。13 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `clrhash`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `clrhash HASH-TABLE`

```text
ハッシュテーブルの全要素を削除します。

  HASH-TABLE : ハッシュテーブルを指定します。
```

関連: `make-hash-table`

## `gethash`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `gethash KEY HASH-TABLE &optional DEFAULT`

```text
ハッシュテーブルの中からキーが一致するものを返します。

  KEY        : 検索するキーを指定します。
  HASH-TABLE : ハッシュテーブルを指定します。

使用例：
  (setq hash-table (make-hash-table))
  => #<hashtable :test eql :size 0/17 9900500>
  (gethash 'a hash-table)
  => nil
  (setf (gethash 'a hash-table) 1)
  => 1
  (gethash 'a hash-table)
  => 1

  (setq h (make-hash-table :test #'equalp))
  (setf (gethash "body" h) '(a b c))
  (gethash "BODY" h)
```

関連: `gethash-region`, `maphash`, `make-hash-table`

## `gethash-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `gethash-region FROM TO HASHTABLE &optional DEFAULT`

```text
リージョンの文字列をハッシュテーブルから取得します。
(buffer-substring FROM TO)してから(gethash ... HASHTABLE)するようなものです。
```

関連: `gethash`

## `hash-table-count`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-count HASH-TABLE`

```text
ハッシュテーブルの要素数を返します。

  HASH-TABLE : ハッシュテーブルを指定します。
```

関連: `hash-table-size`, `make-hash-table`

## `hash-table-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-p OBJECT`

```text
オブジェクトがハッシュテーブルかどうかを返します。

  OBJECT : 判定するオブジェクトを指定します。

  (hash-table-p x) == (typep x 'hash-table)
```

関連: `make-hash-table`

## `hash-table-rehash-size`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-rehash-size HASH-TABLE`

```text
ハッシュテーブルの現在のrehash-sizeを返します。

  HASH-TABLE : ハッシュテーブルを指定します。
```

関連: `make-hash-table`

## `hash-table-rehash-threshold`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-rehash-threshold HASH-TABLE`

```text
ハッシュテーブルの現在のrehash-thresholdを返します。

  HASH-TABLE : ハッシュテーブルを指定します。

補足：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `make-hash-table`

## `hash-table-size`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-size HASH-TABLE`

```text
ハッシュテーブルの現在の大きさを返します。

  HASH-TABLE : ハッシュテーブルを指定します。
```

関連: `hash-table-count`, `make-hash-table`

## `hash-table-test`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `hash-table-test HASH-TABLE`

```text
ハッシュテーブルのキーを比較する関数を返します。

  HASH-TABLE : ハッシュテーブルを指定します。

使用例：
  (hash-table-test hash-table)
  => eql
```

関連: `make-hash-table`

## `make-hash-table`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-hash-table &key :test :size :rehash-size :rehash-threshold`

```text
ハッシュテーブルを作成して返します。

  :test        : ハッシュテーブルのキーの等価関係。デフォルトは eql です。
                 指定可能な関数は、eq, eql, equal, equalp に限られます。
  :size        : ハッシュテーブルの初期サイズの目安。
                 この値よりも大きい素数、または 2, 3, 5, 7 で割れない値
                 に設定されます。
  :rehash-size : ハッシュテーブルのテーブルサイズを増加させる量の目安。
                 デフォルトは 1.5。
                 整数値を指定すると指定した数を増加量の目安とします。
                 小数値を指定すると現在のサイズ * rehash-size で増加量の
                 目安を計算します。現在のサイズと :rehash-size を参考に、
                 より大きい素数、または 2, 3, 5, 7 で割れないサイズに設定されます。
  :rehash-threshold
               : ハッシュテーブルのテーブルサイズを増加させる使用率の目安。
                 デフォルトでは使用率が 80% を超えるとテーブルを伸長します。

とりうる素数は以下の通りです。
      17, 47, 101, 149, 199, 307, 401, 499, 599, 701, 797, 907, 997,
      1103, 1499, 1999, 2999, 4001, 4999, 6007, 7001, 8009, 8999,
      10007, 19997, 29989, 39989, 49999, 59999, 70001, 79999, 90001, 99991

使用例:
  (setq hash (make-hash-table :size 20))
  => #<hashtable :test eql :size 0/47 9900416>

  (progn
    (setf (gethash #\C-0 hash) 0)
    (setf (gethash #\C-1 hash) 1)
    (setf (gethash #\C-2 hash) 2))
  => 2
  
  (gethash #\C-1 hash)
  => 1
      t

  (hash-table-size hash)
  => 17

  (hash-table-rehash-size hash)
  => 1

  (hash-table-rehash-threshold hash)
  => 0.8

  (hash-table-test hash)
  => eql

備考：
  :rehash-size パラメータの小数指定は xyzzy 0.2.2.238 から利用可能です。
  :rehash-threshold パラメータの指定は xyzzy 0.2.2.238 から利用可能です。
```

関連: `gethash`, `hash-table-count`, `hash-table-p`, `hash-table-rehash-size`, `hash-table-rehash-threshold`, `hash-table-size`, `hash-table-test`, `remhash`, `clrhash`, `maphash`, `eql`

## `maphash`

- Function / package: lisp / 定義: hash.l
- 呼び出し: `maphash FUNCTION HASH-TABLE`

```text
ハッシュテーブルの各要素を関数に渡します。

  FUNCTION   : キーと値を受け取る関数
  HASH-TABLE : ハッシュテーブルを指定します。

使用例：
  (setf hsh (make-hash-table))
  (setf (gethash #\a hsh) "Apple")  => "Apple"
  (setf (gethash #\b hsh) "Banana") => "Banana"
  (setf (gethash #\c hsh) "Cake")   => "Cake"
  (let ((alist nil))
    (maphash #'(lambda (x y) (pushnew (cons x y) alist)) hsh)
    alist)
  =>((#\c . "Cake") (#\b . "Banana") (#\a . "Apple"))
```

関連: `with-hash-table-iterator`, `gethash`, `make-hash-table`

## `remhash`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `remhash KEY HASH-TABLE`

```text
ハッシュテーブルの中からキーが一致するものを削除します。

  KEY        : 削除するキーを指定します。
  HASH-TABLE : ハッシュテーブルを指定します。

一致するキーが存在すれば削除してtを返します。
なければnilを返します。

使用例：
  (setq hash-table (make-hash-table))
  => #<hashtable :test eql :size 0/17 9900444>
  (setf (gethash 'a hash-table) 1)
  => 1
  (remhash 'b hash-table)
  => nil
  (remhash 'a hash-table)
  => t
```

関連: `make-hash-table`

## `with-hash-table-iterator`

- Macro / package: lisp / 定義: hash.l
- 呼び出し: `with-hash-table-iterator (MNAME HASH-TABLE) &body BODY`

```text
ハッシュテーブルの要素を順番に返す関数を返してもらいます。

  MNAME      : 要素を順番に返す関数名を指定します。
               この関数は要素を列挙し終わるとnilを返します。
  HASH-TABLE : ハッシュテーブルを指定します。
  BODY       : フォームを記述します。

関数が順番に要素を返すので、loopを使ってnilが返るまで繰り返します。

使用例：
(with-hash-table-iterator (foo hsh)
  (loop
    (multiple-value-bind (f x y)
        (foo)
      (unless f (return))
      (format t "~S ~S~%" x y))))
```

関連: `maphash`
