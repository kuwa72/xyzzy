# リスト (lists)

reference/reference.xml から自動生成。124 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `acons`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `acons KEY DATUM A-LIST`

```text
(KEY . DATUM) を A-LIST に加えた連想リストを返します。

  (acons x y a) == (cons (cons x y) a)

使用例：
  (setq foo '((b . 2))) => ((b . 2))
  (acons 'a 1 foo)      => ((a . 1) (b . 2))
  foo                   => ((b . 2))
```

## `adjoin`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `adjoin ITEM LIST &key :test :test-not :key`

```text
ITEM が LIST の member でなければ先頭に追加した LIST を返す。 member なら LIST を
そのまま返します。

  (adjoin item list) == (if (member item list) list (cons item list))

  :key : :keyに fn が指定された場合，xyzzyでは
          (adjoin item list) == (if (member item list :key fn) list (cons item list))
         となりますが，CLTL2では次のように動作し，非互換です．
          (adjoin item list) == (if (member (funcall fn item) list :key fn) list (cons item list))

使用例：
  (adjoin 'a '(b c d))
  => (a b c d)
  (adjoin 'b '(a b c d))
  => (a b c d)
  (adjoin '(a) '((b) (c) (d)) :key #'car)
  => ((a) (b) (c) (d))
```

関連: `pushnew`

## `append`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `append &rest LISTS`

```text
複数のリストを引数にとってそれらを結合したリストを返します。
引数は保存されます。

使用例：
  ;;; リストをくっつけてみる。
  (setq x '(a b c))
  (setq y '(d e f))
  (append x y)
  =>(a b c d e f)
  x
  =>(a b c)
  y
  =>(d e f)
```

関連: `nconc`, `concatenate`

## `assoc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `assoc ITEM A-LIST &key :test :test-not :key`

```text
連想リスト A-LIST の中で car 部が ITEM との :test を満たす最初のペアを返します。

使用例：
  (assoc 'r '((a . b) (c . d) (r . x) (s . y) (r . z))) 
  =>  (r . x) 
  (assoc 'goo '((foo . bar) (zoo . goo)))
  => nil 
  (assoc '2 '((1 a b c) (2 b c d) (-7 x y z)))
  => (2 b c d)
```

関連: `assoc-if`, `assoc-if-not`, `rassoc`

## `assoc-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `assoc-if PREDICATE A-LIST &key :key`

```text
連想リスト A-LIST の中で car 部が PREDICATE を満たす最初のペアを返します。

使用例：
  (assoc-if #'numberp '((a . b) (1 . c) (2 . d)))
  => (1 . c)
```

関連: `assoc`, `assoc-if-not`

## `assoc-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `assoc-if-not PREDICATE A-LIST &key :key`

```text
連想リスト A-LIST の中で car 部が PREDICATE を満たさない最初のペアを返します。

使用例：
  (assoc-if-not #'numberp '((a . b) (1 . c) (2 . d)))
  => (a . b)
```

関連: `assoc`, `assoc-if`

## `butlast`

- Function / package: lisp / 定義: list.l
- 呼び出し: `butlast LIST &optional (N 1)`

```text
リストの最後のN要素分を除いたリストを返します。
引数 LIST は保存されます。

使用例：
  ;;; 最後の要素を取り除く。
  (butlast '(1 2 3))
  => (1 2) 
  ;;; 最後の2要素を取り除く。
  (butlast '(1 2 3) 2)
  => (1)
```

関連: `nbutlast`, `last`, `subseq`

## `caaaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caaaar X`

```text
caaaar を返します。

  (caaaar X) = (car (car (car (car X))))
```

関連: `car`

## `caaadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caaadr X`

```text
caaadr を返します。

  (caaadr X) = (car (car (car (cdr X))))
```

関連: `car`, `cdr`

## `caaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caaar X`

```text
caaar を返します。

  (caaar X) = (car (car (car X)))
```

関連: `car`

## `caadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caadar X`

```text
caadar を返します。

  (caadar X) = (car (car (cdr (car X))))
```

関連: `car`, `cdr`

## `caaddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caaddr X`

```text
caaddr を返します。

  (caaddr X) = (car (car (cdr (cdr X))))
```

関連: `car`, `cdr`

## `caadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caadr X`

```text
caadr を返します。

  (caadr X) = (car (car (cdr X)))
```

関連: `car`, `cdr`

## `caar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caar X`

```text
caar を返します。

  (caar X) = (car (car X))
```

関連: `car`

## `cadaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cadaar X`

```text
cadaar を返します。

  (cadaar X) = (car (cdr (car (car X))))
```

関連: `car`, `cdr`

## `cadadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cadadr X`

```text
cadadr を返します。

  (cadadr X) = (car (cdr (car (cdr X))))
```

関連: `car`, `cdr`

## `cadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cadar X`

```text
cadar を返します。

  (cadar X) = (car (cdr (car X)))
```

関連: `car`, `cdr`

## `caddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caddar X`

```text
caddar を返します。

  (caddar X) = (car (cdr (cdr (car X))))
```

関連: `car`, `cdr`

## `cadddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cadddr X`

```text
cadddr を返します。

  (cadddr X) = (car (cdr (cdr (cdr X))))
```

関連: `car`, `cdr`, `fourth`

## `caddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `caddr X`

```text
caddr を返します。

  (caddr X) = (car (cdr (cdr X)))
```

関連: `car`, `cdr`, `third`

## `cadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cadr X`

```text
cadr を返します。

  (cadr X) = (car (cdr X))
```

関連: `car`, `cdr`, `second`

## `car`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `car LIST`

```text
リストの最初の要素を返します。

コンスセル LIST の最初のポインタを返します。 LIST が nil の場合 car は 
nil を返すよう、定義されています。引数がリストでない場合、エラーになります
引数がリスト以外でもエラーになって欲しくない場合には、safe-car を使用します。

使用例：
  (car '(a b c))
  => a
  (car '())
  => nil
  (car "string")
  => 不正なデータ型です: "string": cons
```

関連: `first`, `safe-car`

## `cdaaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdaaar X`

```text
cdaaar を返します。

  (cdaaar X) = (cdr (car (car (car X))))
```

関連: `car`, `cdr`

## `cdaadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdaadr X`

```text
cdaadr を返します。

  (cdaadr X) = (cdr (car (car (cdr X))))
```

関連: `car`, `cdr`

## `cdaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdaar X`

```text
cdaar を返します。

  (cdaar X) = (cdr (car (car X)))
```

関連: `car`, `cdr`

## `cdadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdadar X`

```text
cdadar を返します。

  (cdadar X) = (cdr (car (cdr (car X))))
```

関連: `car`, `cdr`

## `cdaddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdaddr X`

```text
cdaddr を返します。

  (cdaddr X) = (cdr (car (cdr (cdr X))))
```

関連: `car`, `cdr`

## `cdadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdadr X`

```text
cdadr を返します。

  (cdadr X) = (cdr (car (cdr X)))
```

関連: `car`, `cdr`

## `cdar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdar X`

```text
cdar を返します。

  (cdar X) = (cdr (car X))
```

関連: `car`, `cdr`

## `cddaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cddaar X`

```text
cddaar を返します。

  (cddaar X) = (cdr (cdr (car (car X))))
```

関連: `car`, `cdr`

## `cddadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cddadr X`

```text
cddadr を返します。

  (cddadr X) = (cdr (cdr (car (cdr X))))
```

関連: `car`, `cdr`

## `cddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cddar X`

```text
cddar を返します。

  (cddar X) = (cdr (cdr (car X)))
```

関連: `car`, `cdr`

## `cdddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdddar X`

```text
cdddar を返します。

  (cdddar X) = (cdr (cdr (cdr (car X))))
```

関連: `car`, `cdr`

## `cddddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cddddr X`

```text
cddddr を返します。

  (cddddr X) = (cdr (cdr (cdr (cdr X))))
```

関連: `cdr`

## `cdddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cdddr X`

```text
cdddr を返します。

  (cdddr X) = (cdr (cdr (cdr X)))
```

関連: `cdr`

## `cddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `cddr X`

```text
cddr を返します。

  (cddr X) = (cdr (cdr X))
```

関連: `cdr`

## `cdr`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `cdr LIST`

```text
リストの二番目以降をリストで返します。

コンスセル LIST の 2 番目のポインタを返します。 LIST が nil の場合 cdr 
は nil を返すよう、定義されています。引数がリストでない場合、エラーにな
ります。引数がリスト以外でもエラーになって欲しくない場合には、safe-cdrを
使用します。

使用例：
  (cdr '(a b c))
  => (b c)
  (cdr '())
  => nil
  (cdr "string")
  => 不正なデータ型です: "string": cons
```

## `cons`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `cons X Y`

```text
新しいリストを返します。

主に、新しくリストを作る際に用いる関数です。これは X を car、 
Y を cdr として、コンスセルを新しく作り、この新しいコンスセルへの
ポインタを返します。 (通常はリストですが) Y が特定のあるタイプでな
くてはならないという制限はありません。

使用例：
  (cons 1 '(2))
  => (1 2)
  (cons 1 '())
  => (1)
  (cons 1 2)
  => (1 . 2)
```

## `copy-alist`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-alist LIST`

```text
連想リストのコピーを返します。例えばこんな連想リストをコピーした場合に、
オリジナルと同じものを指している部分に下線を引いています。copy-listでは
最上位の要素そのものがオリジナルと共有しているのに対し、copy-alistは第二
階層の要素を共有しています。

オリジナル：
  '(((1 2) . #\a) ((3 4) . #\b))

copy-list ：
  '(((1 2) . #\a) ((3 4) . #\b))
    ~~~~~~~~~~~~~ ~~~~~~~~~~~~~
copy-alist：
  '(((1 2) . #\a) ((3 4) . #\b))
     ~~~~~   ~~~   ~~~~~   ~~~

GNU Emacs Lisp Reference Manualによると、コピー元の連想リストとは独立し
て連想リストの修正を行えるようにするためとか。下の例でも示しているとおり、
copy-listでは元のリストまで変わってしまいます。

使用例：
  ;;; copy-listとcopy-alistの違いを見てみる。
  (setq a '((1 . #\a) (2 . #\b)))       => ((1 . #\a) (2 . #\b))
  (setq b (copy-list a))                => ((1 . #\a) (2 . #\b))
  (setq c (copy-alist a))               => ((1 . #\a) (2 . #\b))
  (rplacd (assoc 2 a) #\c)              => (2 . #\c)
  a                                     => ((1 . #\a) (2 . #\c))
  b                                     => ((1 . #\a) (2 . #\c))
  c                                     => ((1 . #\a) (2 . #\b))
```

## `copy-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-list LIST`

```text
リストのコピーを返します。
コピーとオリジナルはequalですが、eqではありません。コピーとオリジナルは
同じ構造を持っており、一番上位のリストの要素は同じものを共有しています。
一方を変えると他方も変わります。オリジナルと同じものを指している部分に下
線を引いています。

オリジナル：
  '(((1 2) . #\a) ((3 4) . #\b))

copy-list ：
  '(((1 2) . #\a) ((3 4) . #\b))
    ~~~~~~~~~~~~~ ~~~~~~~~~~~~~
使用例：
  ;;; [A] eqではないことを示してみます。
  (setq a '((1 2 3) (4 5 6)))   => ((1 2 3) (4 5 6))
  (setq b (copy-list a))        => ((1 2 3) (4 5 6))
  (eq a b)                      => nil
  (equal a b)                   => t
  ;;; [B] car同士はeqです。
  (eq (car a) (car b))          => t
  ;;; [C] caarを変えると変わるけど、carを変えても変わらない。
  (progn (setf (caar a) 7) a)   => ((7 2 3) (4 5 6))
  b                             => ((7 2 3) (4 5 6))
  (progn (setf (car a) 8) a)    => (8 (4 5 6))
  b                             => ((7 2 3) (4 5 6))
```

関連: `copy-tree`, `copy-seq`

## `eighth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `eighth X`

```text
list の 8 番目の要素を返します。

  (eighth X) = (nth 7 X)

使用例：
  (eighth '(1 2 3 4 5 6 7 8 9 0))
  => 8
```

関連: `nth`

## `endp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `endp OBJECT`

```text
OBJECT が空かどうかを返します。
リストの終わりを判定するのに使用されます。 null と異なり、
例えば文字列を指定するとエラーを発生します。

  空リストもしくはnil   t
  空でないリスト        nil
  それ以外              エラー

使用例：
  ;;; nullとの違いを見てみる。
  (endp "foo")  => 不正なデータ型です: t: list
  (endp nil)    => t
  (null "foo")  =>nil
  (null nil)    => t
```

関連: `null`

## `fifth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `fifth X`

```text
list の 5 番目の要素を返します。

  (fifth X) = (nth 4 X)

使用例：
  (fifth '(1 2 3 4 5 6 7 8 9 0))
  => 5
```

関連: `nth`

## `first`

- Function / package: lisp / 定義: list.l
- 呼び出し: `first LIST`

```text
carの別名です。
全く同じ動きをします。

使用例：
  ;;; carと同じ動きをする。
  (car '(1 2 3))
  => 1
  (first '(1 2 3))
  => 1
  (symbol-function 'car)
  => #<function: car>
  (symbol-function 'first)
  => #<function: car>
 
参考：
  ;;; list.lの定義
  (si:*fset 'first #'car)
```

関連: `car`, `nth`

## `fourth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `fourth X`

```text
cadddr の別名です。全く同じ動きをします。
```

関連: `cadddr`, `nth`

## `intersection`

- Function / package: lisp / 定義: list.l
- 呼び出し: `intersection LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 の両方に含まれる要素のリストを作って返します。
nintersection と違い引数 LIST1 は保存されます。

使用例:
  (intersection '(1 3 5 7 9) '(2 3 5 7 11))
  => (7 5 3)
```

関連: `nintersection`, `union`, `set-difference`, `set-exclusive-or`, `ldiff`, `subsetp`

## `last`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `last LIST &optional (N 1)`

```text
リストの末尾からN個分のリストを返します。

使用例：
  ;;; 末尾を取得してみる。
  (last '(a b c d))     => (d)
  (last '(a b c d) 2)   => (c d)
  (last '(a b c d) 5)   => (a b c d)
```

関連: `butlast`, `subseq`

## `ldiff`

- Function / package: lisp / 定義: list.l
- 呼び出し: `ldiff LIST OBJECT`

```text
OBJECT が LIST の一部であるなら、LIST から OBJECT の部分を除いたリストを返します。

LIST の一部分であるかどうかの判定は eq で行います。
OBJECT が LIST の tailp であれば LIST の一部であるとみなされるとも言えます。

使用例:
  (setq x '(a b c d e))
  => (a b c d e)
  (setq y (cddr x))
  => (c d e)
  (ldiff x y)
  => (a b)
  ;; 見た目は同じでも x の一部分でないならダメ
  (ldiff x '(c d e))
  => (a b c d e)
```

関連: `tailp`, `intersection`, `set-difference`, `set-exclusive-or`

## `list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `list &rest ARGS`

```text
この関数は、 ARGS を要素とするリストを作ります。結果として返されるリ
ストは(常に) nil でターミネート(訳注：終端)されています。 ARGS が与え
られない場合、 empty リストを返します。 

  (list 1 2 3 4 5)
  => (1 2 3 4 5)
  (list)
  => nil
```

関連: `list*`, `make-list`

## `list*`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `list* &rest ARGS`

```text
list とよく似て ARGS を要素とするリストを作りますが、 最後の要素だけは
コンスセルの cdr部に直接つなげます。

使用例:
  (setq a (list 1 2 3))
  => (1 2 3)            ; (1 . (2 . (3 . nil)))

  (setq b (list* 1 2 3))
  => (1 2 . 3)          ; (1 . (2 . 3))

  (setq c (list* 4 5 6 a))
  => (4 5 6 1 2 3)
```

関連: `list`

## `list-length`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `list-length LIST`

```text
リストの長さを返します。
リストが循環している場合、length は結果を返さないかもしれませんが、
list-length は nil を返します。

使用例：
  ;;; リストの長さを比べてみる。
  (list-length '())             => 0 
  (list-length '(a b c d))      => 4 
  (list-length '(a (b c) d))    => 3 
  (let ((a '(x)))
    (setf (cdr a) a)
    (list-length a))            => nil
```

関連: `length`

## `make-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-list SIZE &key :initial-element`

```text
指定された長さのリストを作成して返します。

  SIZE             : リストの長さ
  :initial-element : リストの要素

使用例：
  (make-list 3)
  => (nil nil nil)
  (make-list 0)
  => nil
  (make-list 2 :initial-element 'x)
  => (x x)
```

関連: `list`, `make-sequence`

## `member`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `member ITEM LIST &key :test :test-not :key`

```text
LIST の中で ITEM との :test を満たすものがあれば一致したところからのリストを返します。
なければ nil を返します。

使用例：
  (member 'e '(a b c d))
  => nil
  (member 'b '(a b c d))
  => (b c d)
```

関連: `member-if`, `member-if-not`, `find`, `position`, `getf`

## `member-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `member-if PREDICATE LIST &key :key`

```text
LIST の中で条件 PREDICATE を満たすものがあれば、そこからのリストを返します。
なければ nil を返します。

使用例：
  (member-if #'numberp '(a b c))
  => nil
  (member-if #'numberp '(a b 3 c))
  => (3 c)
```

関連: `member`, `member-if-not`

## `member-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `member-if-not PREDICATE LIST &key :key`

```text
LIST の中で条件 PREDICATE を満たさないものがあれば、そこからのリストを返します。
なければ nil を返します。

使用例：
  (member-if-not #'numberp '(1 2 3))
  => nil
  (member-if-not #'numberp '(1 2 a 3))
  => (a 3)
```

関連: `member`, `member-if`

## `nbutlast`

- Function / package: lisp / 定義: list.l
- 呼び出し: `nbutlast LIST &optional (N 1)`

```text
リストの最後のN要素分を除いたリストを返します。
引数 LIST は破壊されます。

使用例：
  ;;; 最後の要素を取り除きます。
  (setq foo '(1 2 3))
  => (1 2 3)
  (nbutlast foo)
  => (1 2)
  foo
  => (1 2)
```

関連: `butlast`

## `nconc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nconc &rest LISTS`

```text
複数のリストを引数にとってそれらを結合したリストを返します。
引数は破壊されます。

使用例：
  ;;; リストをくっつけてみる。
  (setq x '(a b c))
  (setq y '(d e f))
  (nconc x y)
  => (a b c d e f) 
  x
  => (a b c d e f)
  y
  => (d e f)
```

関連: `append`

## `nintersection`

- Function / package: lisp / 定義: list.l
- 呼び出し: `nintersection LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 の両方に含まれる要素のリストを作って返します。
intersection と違い引数 LIST1 は破壊されます。

使用例:
  (setq x '(1 3 5 7 9))
  => (1 3 5 7 9)
  (setq y '(2 3 5 7 11))
  => (2 3 5 7 11)
  (nintersection x y)
  => (3 5 7)
  x
  => (1 3 5 7)
  y
  => (2 3 5 7 11)
```

関連: `intersection`

## `ninth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `ninth X`

```text
list の 9 番目の要素を返します。

  (ninth X) = (nth 8 X)

使用例：
  (ninth '(1 2 3 4 5 6 7 8 9 0))
  => 9
```

関連: `nth`

## `nreconc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nreconc X Y`

```text
X を反転させて Y を結合したリストを返します。
引数 X は破壊されます。

  (nreconc x y) == (nconc (nreverse x) y)

nreconcの方が効率が良いようです。
```

関連: `revappend`

## `nset-difference`

- Function / package: lisp / 定義: list.l
- 呼び出し: `nset-difference LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 から LIST2 にも含まれる要素を除き、そのリストを返します。
set-difference と違い引数 LIST1 は破壊されます。

使用例:
  (setq x '(1 3 5 7 9))
  => (1 3 5 7 9)
  (setq y '(2 3 7))
  => (2 3 7)
  (nset-difference x y)
  => (1 5 9)
  x
  => (1 5 9)
```

関連: `set-difference`

## `nset-exclusive-or`

- Function / package: lisp / 定義: list.l
- 呼び出し: `nset-exclusive-or LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 のいずれか一方にのみ含まれる要素のリストを作って返します。
set-exclusive-or と違い引数 LIST2 は破壊されます。

使用例:
  (setq x '(1 3 5 7 9))
  => (1 3 5 7 9)
  (setq y '(2 3 5 7 11))
  => (2 3 5 7 11)
  (nset-exclusive-or x y)
  => (9 1 2 11)
  x
  => (1 3 5 7 9)
  y
  => (2 11)
```

関連: `set-exclusive-or`

## `nsublis`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nsublis ALIST TREE &key :test :test-not :key`

```text
TREE の中で ALIST の :key との :test を満たすものを VALUE に置き換えたリストを返します。
引数 TREE は破壊されます。

使用例：
  ;;; fooの変換テーブルの内容に基づいてbarを変換します。
  (setq foo '((1 . #\a) (2 . #\b) (3 . #\c)))
  => ((1 . #\a) (2 . #\b) (3 . #\c))
  (setq bar '(1 (2 3) ((4 5 6) (7 8 9))))
  => (1 (2 3) ((4 5 6) (7 8 9)))
  (nsublis foo bar)
  => (#\a (#\b #\c) ((4 5 6) (7 8 9)))
  bar
  => (#\a (#\b #\c) ((4 5 6) (7 8 9)))
```

関連: `sublis`, `nsubst`

## `nsubst`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nsubst NEW OLD TREE &key :test :test-not :key`

```text
TREE の中で OLD を NEW に置き換えたTREEを返します。
引数 TREE は破壊されます。

使用例：
  ;;; 階層のあるツリーをnsubstしてみる。aは破壊される。
  (setq a '((1 2) ((1 3) (1 4))))       => ((1 2) ((1 3) (1 4)))
  (nsubst 5 1 a)                        => ((5 2) ((5 3) (5 4)))
  a                                     => ((5 2) ((5 3) (5 4)))
```

関連: `subst`, `nsublis`, `nsubst-if`, `nsubst-if-not`, `nsubstitute`

## `nsubst-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nsubst-if NEW TEST TREE &key :key`

```text
TREEの中でTESTを満たすものがあればNEWに置き換えたものを返します。
TREEが破壊される点を除いてsubst-ifと同じです。

  NEW  : 置き換える要素
  TEST : 置き換えるかどうかを判定するテスト
         non-nilを返したら置き換えます。
  TREE : 対象のツリー

TESTの引数についてはsubst-ifを参照して下さい。

使用例：
  ;;; 適当なツリーを用意して、その要素が奇数ならば0に置き換える。
  (setq a '((1 2) ((1 3) (1 (1 3)))))
  => ((1 2) ((1 3) (1 (1 3))))
  (nsubst-if 0 #'(lambda (x) (and (integerp x) (oddp x))) a)
  => ((0 2) ((0 0) (0 (0 0))))
  a
  => ((0 2) ((0 0) (0 (0 0))))
```

関連: `subst-if`, `nsubst-if-not`, `nsubst`, `nsubstitute-if`

## `nsubst-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nsubst-if-not NEW TEST TREE &key :key`

```text
TREEの中でTESTを満たさないものがあればNEWに置き換えたものを返します。
TREEが破壊される点を除いてsubst-if-notと同じです。

  NEW  : 置き換える要素
  TEST : 置き換えるかどうかを判定するテスト
         nilを返したら置き換えます。
  TREE : 対象のツリー

TESTの引数についてはsubst-ifを参照して下さい。

使用例：
  ;;; 適当なツリーを用意して、数字以外のものがあれば0に変換する。
  (setq a '((123 "abc") '(456 "123") (789 #\a)))
  => ((123 "abc") '(456 "123") (789 #\a))
  (nsubst-if-not 0 #'(lambda (x) (or (listp x) (integerp x))) a)
  => ((123 0) (0 (456 0)) (789 0))
  a
  => ((123 0) (0 (456 0)) (789 0))
```

関連: `subst-if`, `nsubst-if`, `nsubst`, `nsubstitute-if-not`

## `nth`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nth N LIST`

```text
リストの N 番目の要素を返します。

  N    : リストのインデックスを指定します。0を基底とします。
  LIST : 要素を返すリストです。

N がリストの長さを越えていれば nil を返します。 N が負数であればエラーを
返します。

  (nth n x) == (car (nthcdr n x))

使用例：
  (nth 2 '(1 2 3 4))
  => 3
  (nth 10 '(1 2 3 4))
  => nil
  (nth -3 '(1 2 3 4))
  => 範囲外の値です: -3
```

関連: `nthcdr`, `nth-value`, `elt`, `first`, `second`, `third`, `fourth`, `fifth`, `sixth`, `seventh`, `eighth`, `ninth`, `tenth`

## `nthcdr`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `nthcdr N LIST`

```text
リストの N 番目の cdr を返します。

  N    : リストのインデックスを指定します。0を基底とします。
  LIST : 要素を返すリストです。

N がリストの長さを越えていれば nil を返します。 N が負数であればエラーを
返します。

使用例：
  (nthcdr 1 '(1 2 3 4))
  => (2 3 4)
  (nthcdr 10 '(1 2 3 4))
  => nil
  (nthcdr -3 '(1 2 3 4))
  => 範囲外の値です: -3
```

関連: `nth`, `nth-value`

## `nunion`

- Function / package: lisp / 定義: list.l
- 呼び出し: `nunion LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 を併せたリストを作って返します。
union と違い LIST1 は破壊されます。

使用例:
  (setq x '(1 3 5 7 9))
  => (1 3 5 7 9)
  (setq y '(2 3 5 7 11))
  => (2 3 5 7 11)
  (nunion x y)
  => (1 9 2 3 5 7 11)
  x
  => (1 9 2 3 5 7 11)
  y
  => (2 3 5 7 11)
```

関連: `union`

## `pairlis`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pairlis KEYS DATA &optional A-LIST`

```text
二つのリスト KEYS と DATA から要素を一つずつ組み合わせた連想リストを作って返します。
A-LIST が与えられればそれに加えて返します。

  '(1 2 3 4 5) ─┬→ '((5 . e) (4 . d) (3 . c) (2 . b) (1 . a))
  '(a b c d e) ─┘

使用例：
  (pairlis '(one two) '(1 2) '((three . 3)))
  => ((two . 2) (one . 1) (three . 3))
```

## `pop`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `pop PLACE`

```text
リストの先頭要素を取り除きます。取り除いた要素を返します。

  PLACE : setfに適用できるものでなければなりません。

使用例：
  (setq x '(a (b c d) e f))     => (a (b c d) e f)
  (pop (cdr (second x)))        => c
  x                             => (a (b d) e f)

互換性：
  Common Lispとxyzzyにあり。
  muleはなさそう。
```

## `push`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `push ITEM PLACE`

```text
リストの先頭に要素を追加します。

  ITEM  : リストに追加する要素です。
  PLACE : pushする場所はsetfに適用できるものでなければなりません。

使用例：
  ;;; リストの途中にpushしてみる。
  (setq x '(a (b c d) e f))     => (a (b c d) e f)
  (push 99 (cdr (second x)))    => (99 c d)
  x                             => (a (b 99 c d) e f)

互換性：
  Common Lispとxyzzyにあり。
  muleは無さそう。
```

関連: `pushnew`

## `pushnew`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `pushnew ITEM PLACE &KEY :test :test-not :key`

```text
push とほぼ同じですが、リストの最上位に現れている要素でなければリストの
先頭に追加されます。追加するかどうかは、 :test もしくは :test-not で指定
される比較テストを使ってリストの全要素についてチェックして決められます。

  ITEM      : 登録する内容です。
  PLACE     : 登録する場所です。
  :test     : 比較関数です。標準では#'eql？
  :test-not : 比較関数です。
  :key      : キー判定用の関数です。標準では#'identity？

使用例：
  (setq *a* nil)                ;; この時 *a* の値は nil
  (pushnew 'a *a*)  => (a)      ;; この時 *a* の値は (a)
  (pushnew 'b *a*)  => (b a)    ;; この時 *a* の値は (b a)
  (pushnew 'a *a*)  => (b a)    ;; この時 *a* の値は (b a)

互換性：
  Common Lispとxyzzyにあり。
  muleは無さそう。
```

関連: `push`, `adjoin`

## `rassoc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rassoc ITEM A-LIST &key :test :test-not :key`

```text
連想リスト A-LIST の中で cdr 部が ITEM との :test を満たす最初のペアを返します。

使用例：
  (rassoc 'a '((a . b) (b . c) (c . a) (z . a)))
  => (c . a)
```

関連: `rassoc-if`, `rassoc-if-not`, `assoc`

## `rassoc-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rassoc-if PREDICATE A-LIST &key :key`

```text
連想リスト A-LIST の中で cdr 部が PREDICATE を満たす最初のペアを返します。

使用例：
  (rassoc-if #'numberp '((a . b) (1 . c) (2 . 4)))
  => (2 . 4)
```

関連: `rassoc`, `rassoc-if-not`

## `rassoc-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rassoc-if-not PREDICATE A-LIST &key :key`

```text
連想リスト A-LIST の中で cdr 部が PREDICATE を満たさない最初のペアを返します。

使用例：
  (rassoc-if-not #'numberp '((a . b) (1 . c) (2 . d)))
  => (a . b)
```

関連: `rassoc`, `rassoc-if`

## `rest`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `rest LIST`

```text
cdrの別名です。 
全く同じ動きをします。 

使用例： 
  ;;; cdrと同じ動きをする。 
  (cdr '(1 2 3))
  => (2 3)
  (rest '(1 2 3))
  => (2 3)
  (symbol-function 'cdr)
  => #<function: cdr>
  (symbol-function 'rest)
  => #<function: cdr>
 
参考： 
  ;;; evalmacs.lの定義
  (si:*fset 'rest #'cdr)
```

関連: `cdr`

## `revappend`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `revappend X Y`

```text
X を反転させて Y を結合したリストを返します。
引数 X は保存されます。

  (revappend x y) == (append (reverse x) y)
  
revappendの方が効率が良いようです。
```

関連: `nreconc`

## `rplaca`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rplaca X Y`

```text
リスト X の car を Y に置き換えて、置き換えた X を返します。
(progn (setf (car X) Y) X)と同じでしょうか。

使用例：
  ;;; 置き換えてみる。
  (setq g '(a b c)) 
  => (a b c)
  (rplaca (cdr g) 'd)
  => (d c) 
  g
  => (a d c)
```

## `rplacd`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rplacd X Y`

```text
リスト X の cdr を Y に置き換えて、置き換えた X を返します。
(progn (setf (cdr X) Y) X)と同じでしょうか。

使用例：
  ;;; 置き換えてみる。
  (setq x '(a b c)) 
  (rplacd x 'd)
  => (a . d) 
  x
  => (a . d)
```

## `safe-caaaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caaaar X`

```text
safe-caaaar を返します。

  (safe-caaaar X) = (safe-car (safe-car (safe-car (safe-car X))))
```

関連: `safe-car`

## `safe-caaadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caaadr X`

```text
safe-caaadr を返します。

  (safe-caaadr X) = (safe-car (safe-car (safe-car (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-caaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caaar X`

```text
safe-caaar を返します。

  (safe-caaar X) = (safe-car (safe-car (safe-car X)))
```

関連: `safe-car`

## `safe-caadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caadar X`

```text
safe-caadar を返します。

  (safe-caadar X) = (safe-car (safe-car (safe-cdr (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-caaddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caaddr X`

```text
safe-caaddr を返します。

  (safe-caaddr X) = (safe-car (safe-car (safe-cdr (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-caadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caadr X`

```text
safe-caadr を返します。

  (safe-caadr X) = (safe-car (safe-car (safe-cdr X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-caar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caar X`

```text
safe-caar を返します。

  (safe-caar X) = (safe-car (safe-car X))
```

関連: `safe-car`

## `safe-cadaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cadaar X`

```text
safe-cadaar を返します。

  (safe-cadaar X) = (safe-car (safe-cdr (safe-car (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cadadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cadadr X`

```text
safe-cadadr を返します。

  (safe-cadadr X) = (safe-car (safe-cdr (safe-car (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cadar X`

```text
safe-cadar を返します。

  (safe-cadar X) = (safe-car (safe-cdr (safe-car X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-caddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caddar X`

```text
safe-caddar を返します。

  (safe-caddar X) = (safe-car (safe-cdr (safe-cdr (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cadddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cadddr X`

```text
safe-cadddr を返します。

  (safe-cadddr X) = (safe-car (safe-cdr (safe-cdr (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-caddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-caddr X`

```text
safe-caddr を返します。

  (safe-caddr X) = (safe-car (safe-cdr (safe-cdr X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-cadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cadr X`

```text
safe-cadr を返します。

  (safe-cadr X) = (safe-car (safe-cdr X))
```

関連: `safe-car`, `safe-cdr`

## `safe-car`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-car X`

```text
(car X) は X が nil か cons でなければエラーになります
しかし safe-car はエラーを発生せずに nil を返します。

使用例：
  ;;; carとsafe-carの違い
  (car "abc")
  => 不正なデータ型です: "abc": cons
  (safe-car "abc")
  => nil
```

関連: `car`

## `safe-cdaaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdaaar X`

```text
safe-cdaaar を返します。

  (safe-cdaaar X) = (safe-cdr (safe-car (safe-car (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdaadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdaadr X`

```text
safe-cdaadr を返します。

  (safe-cdaadr X) = (safe-cdr (safe-car (safe-car (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdaar X`

```text
safe-cdaar を返します。

  (safe-cdaar X) = (safe-cdr (safe-car (safe-car X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdadar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdadar X`

```text
safe-cdadar を返します。

  (safe-cdadar X) = (safe-cdr (safe-car (safe-cdr (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdaddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdaddr X`

```text
safe-cdaddr を返します。

  (safe-cdaddr X) = (safe-cdr (safe-car (safe-cdr (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdadr X`

```text
safe-cdadr を返します。

  (safe-cdadr X) = (safe-cdr (safe-car (safe-cdr X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdar X`

```text
safe-cdar を返します。

  (safe-cdar X) = (safe-cdr (safe-car X))
```

関連: `safe-car`, `safe-cdr`

## `safe-cddaar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cddaar X`

```text
safe-cddaar を返します。

  (safe-cddaar X) = (safe-cdr (safe-cdr (safe-car (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cddadr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cddadr X`

```text
safe-cddadr を返します。

  (safe-cddadr X) = (safe-cdr (safe-cdr (safe-car (safe-cdr X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cddar X`

```text
safe-cddar を返します。

  (safe-cddar X) = (safe-cdr (safe-cdr (safe-car X)))
```

関連: `safe-car`, `safe-cdr`

## `safe-cdddar`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdddar X`

```text
safe-cdddar を返します。

  (safe-cdddar X) = (safe-cdr (safe-cdr (safe-cdr (safe-car X))))
```

関連: `safe-car`, `safe-cdr`

## `safe-cddddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cddddr X`

```text
safe-cddddr を返します。

  (safe-cddddr X) = (safe-cdr (safe-cdr (safe-cdr (safe-cdr X))))
```

関連: `safe-cdr`

## `safe-cdddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdddr X`

```text
safe-cdddr を返します。

  (safe-cdddr X) = (safe-cdr (safe-cdr (safe-cdr X)))
```

関連: `safe-cdr`

## `safe-cddr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cddr X`

```text
safe-cddr を返します。

  (safe-cddr X) = (safe-cdr (safe-cdr X))
```

関連: `safe-cdr`

## `safe-cdr`

- Function / package: lisp / 定義: list.l
- 呼び出し: `safe-cdr X`

```text
(cdr X) は X が nil か cons でなければエラーになります
しかし safe-cdr はエラーを発生せずに nil を返します。
```

関連: `cdr`

## `second`

- Function / package: lisp / 定義: list.l
- 呼び出し: `second X`

```text
cadrの別名です。
全く同じ動きをします。

使用例：
  ;;; cadrと同じ動きをする。
  (cadr '(1 2 3))
  => 2
  (second '(1 2 3))
  => 2
  (symbol-function 'cadr)
  => #<lexical-closure: cadr>
  (symbol-function 'second)
  => #<lexical-closure: cadr>
 
参考：
  ;;; list.lの定義
  (si:*fset 'second #'cadr)
```

関連: `first`, `cadr`, `nth`

## `set-difference`

- Function / package: lisp / 定義: list.l
- 呼び出し: `set-difference LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
二つのリストの差を返します。
nset-difference と違い引数 LIST1 は保存されます。

使用例：
  (set-difference  '(3 6 9) '(2 4 6 8 10))
  => (9 3)
```

関連: `nset-difference`, `union`, `intersection`, `set-exclusive-or`, `ldiff`, `subsetp`

## `set-exclusive-or`

- Function / package: lisp / 定義: list.l
- 呼び出し: `set-exclusive-or LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 のいずれか一方にのみ含まれる要素のリストを作って返します。
nset-exclusive-or と違い引数 LIST2 は保存されます。

使用例:
  (set-exclusive-or '(1 3 5 7 9) '(2 3 5 7 11))
  => (9 1 11 2)
```

関連: `nset-exclusive-or`, `intersection`, `union`, `set-difference`, `ldiff`, `subsetp`

## `seventh`

- Function / package: lisp / 定義: list.l
- 呼び出し: `seventh X`

```text
list の 7 番目の要素を返します。

  (seventh X) = (nth 6 X)

使用例：
  (seventh '(1 2 3 4 5 6 7 8 9 0))
  => 7
```

関連: `nth`

## `sixth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `sixth X`

```text
list の 6 番目の要素を返します。

  (sixth X) = (nth 5 X)

使用例：
  (sixth '(1 2 3 4 5 6 7 8 9 0))
  => 6
```

関連: `nth`

## `sublis`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `sublis ALIST TREE &key :test :test-not :key`

```text
TREE の中で ALIST の :key との :test を満たすものを VALUE に置き換えたリストを返します。
引数 TREE は保存されます。

使用例：
  ;;; a->1、b->2に変更
  (sublis '((a . 1) (b . 2)) '(a b c))
  => (1 2 c)
```

関連: `subst`, `nsublis`, `nsubstitute`

## `subsetp`

- Function / package: lisp / 定義: list.l
- 呼び出し: `subsetp LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 が LIST2 のサブセットなら t、そうでないなら nil を返します。

使用例:
  (subsetp '(1 5 7) '(1 3 5 7 9))
  => t
  (subsetp '(1 5 8) '(1 3 5 7 9))
  => nil
```

関連: `set-difference`, `intersection`

## `subst`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `subst NEW OLD TREE &key :test :test-not :key`

```text
TREE の中で OLD を NEW に置き換えた TREE のコピーを返します。
引数 TREE は保存されます。

使用例：
  ;;; 階層のあるツリーをsubstしてみる。aはそのまま
  (setq a '((1 2) ((1 3) (1 4))))       => ((1 2) ((1 3) (1 4)))
  (subst 5 1 a)                         => ((5 2) ((5 3) (5 4)))
  a                                     => ((1 2) ((1 3) (1 4)))
```

関連: `sublis`, `nsubst`, `subst-if`, `subst-if-not`, `substitute`

## `subst-if`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `subst-if NEW TEST TREE &key :key`

```text
TREE の中で TEST を満たすものがあれば NEW に置き換えたものを返します。
引数 TREE は保存されます。

  NEW  : 置き換える要素
  TEST : 置き換えるかどうかを判定するテスト
         non-nilを返したら置き換えます。
  TREE : 対象のツリー

TESTにはTREEの部分リストと要素を順番に引数として与えるので、必ずしも末端
の要素だけが置き換えの対象とはなりません。例えば、こんな感じで呼び出され
ます。

  ;;; funcで判定する場合
  (subst-if 0 #'func '(1 2 3))

  ;;; funcに引数として与えられる値(1 2 3だけじゃない)
  (1 2 3) 1 (2 3) 2 (3) 3 nil

下の使用例の様に事前の型チェックをして回避します。

使用例：
  ;;; 適当なツリーを用意して、その要素が奇数ならば0に置き換える。
  (setq a '((1 2) ((1 3) (1 (1 3)))))
  => ((1 2) ((1 3) (1 (1 3))))
  (subst-if 0 #'(lambda (x) (and (integerp x) (oddp x))) a)
  => ((0 2) ((0 0) (0 (0 0))))
  a
  => ((1 2) ((1 3) (1 (1 3))))
```

関連: `subst-if-not`, `subst`, `substitute-if`

## `subst-if-not`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `subst-if-not NEW TEST TREE &key :key`

```text
TREEの中でTESTを満たさないものがあればNEWに置き換えたものを返します。
TREEは保存されます。

  NEW  : 置き換える要素
  TEST : 置き換えるかどうかを判定するテスト
         nilを返したら置き換えます。
  TREE : 対象のツリー

TESTの引数についてはsubst-ifを参照して下さい。

使用例：
  ;;; 適当なツリーを用意して、数字以外のものがあれば0に変換する。
  (setq a '((123 "abc") '(456 "123") (789 #\a)))
  => ((123 "abc") '(456 "123") (789 #\a))
  (subst-if-not 0 #'(lambda (x) (or (listp x) (integerp x))) a)
  => ((123 0) (0 (456 0)) (789 0))
  a
  => ((123 "abc") '(456 "123") (789 #\a))
```

関連: `subst-if`, `subst`, `substitute-if-not`

## `tailp`

- Function / package: lisp / 定義: list.l
- 呼び出し: `tailp SUBLIST LIST`

```text
SUBLISTがLISTを構成しているconsであるかを返す。

具体的にはLISTを順にcdrしていった結果とSUBLISTが
eqならtそうでないならnilを返す。
```

関連: `ldiff`

## `tenth`

- Function / package: lisp / 定義: list.l
- 呼び出し: `tenth X`

```text
list の 10 番目の要素を返します。

  (tenth X) = (nth 9 X)

使用例：
  (tenth '(1 2 3 4 5 6 7 8 9 0))
  => 0
```

関連: `nth`

## `third`

- Function / package: lisp / 定義: list.l
- 呼び出し: `third X`

```text
caddr の別名です。全く同じ動きをします。
```

関連: `caddr`, `nth`

## `union`

- Function / package: lisp / 定義: list.l
- 呼び出し: `union LIST1 LIST2 &rest REST &key :test :test-not :key`

```text
LIST1 と LIST2 を併せたリストを作って返します。
nunion と違い引数 LIST1 は保存されます。

使用例:
  (union '(1 3 5 7 9) '(2 3 5 7 11))
  => (1 9 2 3 5 7 11)
```

関連: `merge`, `nunion`, `intersection`, `set-difference`, `set-exclusive-or`, `ldiff`, `subsetp`
