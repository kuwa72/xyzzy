# 制御構造 (control-flow)

reference/reference.xml から自動生成。39 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `and`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `and &rest FORMS`

```text
フォームがnon-nilの間だけ順番に評価します。
フォームが一つでもnilならば、そこで評価を中断してnilを返して終了します。
全てのフォームがnon-nilならば、最後に実行したフォームの値を返します。

  ;;; exp1 がnon-nilなら exp2を実行し、
  ;;; exp2 がnon-nilなら exp3を実行し、
  ;;; exp3 がnon-nilなら.......
  (and exp1 exp2 exp3 ...)

例えば、以下の様にチェックを順番に記述するような場合に向いていると思います。
チェックに失敗すれば、以降の処理は実行しません。

  (and (file-exist-p ...) ; 特定のファイルの存在チェック
       (find-file ...)    ; そのファイルを読み込みチェック
       (scan-buffer ...)  ; 正規表現で検索
       (match-string 2)   ; 検索結果のチェック
       ...)
```

関連: `or`

## `block`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `block NAME {FORM}*`

```text
フォームを順番に評価して最後のフォームの結果を返します。 
ほとんどprognですがreturn-fromやreturnで戻り値が指定できるところが違います。
returnやreturn-fromにぶつかったときには残りの式は評価しません。
```

関連: `return-from`

## `case`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `case KEYFORM &rest FORMS`

```text
C言語のswitch文みたいなのです。

(case <キー>
  (<リスト1> <式>～<式>)
  (<リスト2> <式>～<式>)
       ...
  (<リストn> <式>～<式>))

まず<キー>を評価し，それが<リスト>のどれかの要素と一致すれば，
その<リスト>に続く式を順に評価して，最後の式の値をcaseの値として返
す。どの<リスト>のどの要素にも一致しなければcaseの値はnilである。
ただし例外として，最後のリスト(<リストn>)がtであれば，「どれにも一
致しなければ」を意味する。

<リスト1>～<リストn>までは，それぞれデータのリストで，これら
は評価されない。すなわち値がリストになる式ではなく，リストそのものがここ
に入る。要素が一つだけの場合は，リストの代わりに要素がここにきてもいい。

使用例：
  ;;; 4を入力して場合分けさせる
  (setq x 4)
  => 4
  (case x
    (1 'one)
    (2 'two)
    (3 'three)
    ((4 5) 'four_or_five)
    (t 'large))
  => four_or_five
```

## `catch`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `catch TAG {FORM}*`

```text
throwを投げるためのラベルを設定します。
C++のtryに相当します。

  C++  : try    throw
  Lisp : catch  throw

参考：
  エラー処理関連
```

関連: `throw`

## `cond`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `cond &rest FORMS`

```text
C 言語などの if ... else if ... のようなものです。

構文は以下のようになっています。

(cond (<テスト1> <式>～<式>)
      (<テスト2> <式>～<式>)
        ...
      (<テストn> <式>～<式>))

テストが真になる最初の節の式を評価します。
上の式は次と等価です。

(if <テスト1>
     (progn <式>～<式>)
   (if <テスト2>
        (progn <式>～<式>)
      ...
      (if <テストn>
           (progn <式>～<式>)
         nil)))

テストに t を指定するとデフォルトで実行される節を指定できます。

また特別な場合として、テストの後ろの式がない場合にはテストの結果が戻り値
となります。
```

関連: `if`

## `do`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `do (&rest VARLIST) (&optional END-TEST &rest RESULT) &body BODY`

```text
(do ((var1 init1 step1)
     (var2 init2 step2)
            ...
     (varm initm stepm))
    (end-test result1 result2 ... resultm) 
   declaration1
       ...
   declarationN)

(do ((<変数1> <初期値1> <ステップ1>)
     (<変数2> <初期値2> <ステップ2>)
              ...
     (<変数m> <初期値m> <ステップm>))
    (<<終了条件> <後式1> ... <後式p>) 
   <式1>
   ...
   <式n>)


<変数1>～<変数m>までを局所変数とし，<終了条件>が真
になるまでdo式本体の<式1>～<式n>を繰り返し実行する。<
変数1>～<変数m>までは変数を表す記号で，do式の中で局所的に使
われる変数を指定する。do式が評価されるときは，まず<初期値1>～
<初期値m>までが評価され，その値が各局所変数にバインドされる。そ
の後で，<終了条件>が評価され，もし値がnilであれば本体を実行する。
次に<ステップ1>～<ステップm>までを評価してその値を各局所
変数に代入してから<終了条件>を評価する。これを<終了条件>
の値がnil以外になるまで繰り返す。<終了条件>の値がnil以外になっ
たら，<終了条件>に続く<後式1>～<後式p>を評価し，そ
の最後の式の値をdo式の値とする。

do式の一般形は，

(block nil
  (let ((<変数1> <初期値1> <ステップ1>)
        (<変数2> <初期値2> <ステップ2>)
                 ...
        (<変数m> <初期値m> <ステップm>))
    (tagbody
      loop
      (when <終了条件>
        (return (progn <後式1> ... <後式p>)))
      <式1>
      ...
      <式n>
     (psetq <変数1> <ステップ1>
              ...
            <変数m> <ステップm>)
      (go loop))))

と同値である。(loop というタグは他では使われていないものとする)
```

## `do*`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `do* (&rest VARLIST) (&optional END-TEST &rest RESULT) &body BODY`

```text
doと同じようにループ処理を行う。
doとだいたい同じだけど、letとlet*の違いのように、局所変数の初期化と更
新の方法にある。doはletを使って局所変数を初期化しているため、全ての初
期値を計算してから局所変数をバインドするが，do*ではletの代わりにlet*
が使われている。またpsetqのかわりにsetqを使う。

do*式の一般形は、

(block nil
  (let* ((<変数1> <初期値1> <ステップ1>)
         (<変数2> <初期値2> <ステップ2>)
                  ...
         (<変数m> <初期値m> <ステップm>))
    (tagbody
      loop
      (when <終了条件>
        (return (progn <後式1> ... <後式p>)))
      <式1>
      ...
      <式n>
     (setq <変数1> <ステップ1>
              ...
           <変数m> <ステップm>)
      (go loop))))

と同値である。(loop というタグは他では使われていないものとする)
```

関連: `do`, `let`, `let*`

## `do-external-symbols`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `do-external-symbols (VAR &optional (PACKAGE () SV) RESULT-FORM) &body BODY`

```text
do-symbols と似ていますが、外部シンボルのみに対して繰り返しを行います。
```

関連: `do-all-symbols`, `do-symbols`

## `do-symbols`

- Macro / package: lisp / 定義: package.l
- 呼び出し: `do-symbols (VAR &optional (PACKAGE () SV) RESULT-FORM) &body BODY`

```text
シンボルすべてについて繰り返しを行います。
動作としては dolist に似ています。

do-all-symbols と違って特定のパッケージだけを探します。正確にはパッケ
ージの外部シンボル・内部シンボルおよび、そのパッケージが use している
他パッケージの外部シンボルが対象になります。

  VAR           : BODY 実行中に各シンボルに束縛される変数
  PACKAGE       : シンボルを探すパッケージ (デフォルトは *package*)
  RESULT-FORM   : do-symbols の戻り値
  BODY          : 繰り返しの本体
```

関連: `do-external-symbols`, `do-all-symbols`, `dolist`

## `dolist`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `dolist (VAR LISTFORM &optional (RESULTFORM ''())) &body BODY`

```text
リストの長さ分だけ繰り返しを行います。

  (dolist (<変数> <リスト式> <値>)
    <式1> ... <式n>)

まず<リスト式>を評価する。その後リストの要素ごとに変数をその要素に
バインドして，本体の<式1>～<式n>までを評価する。本体式の評価
が全ての要素に対して終わると，<値>を評価し，dolistの値として返す。
また<値>は省略でき，その場合はdolistの値はnilである。

dolist式の一般形は，
  
  (do* ((temp <リスト式> (cdr temp))
        (<変数> (car temp) (car temp)))
      ((endp temp) <値>)
    <式1>
    ...
    <式n>)
  
と同値である。

使用例：
  (let ((result nil))
    (dolist (item '("Lois" "Charley" "David") (nreverse result))
      (push (length item) result)))
  => (4 7 5)
```

## `dotimes`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `dotimes (VAR COUNTFORM &optional (RESULTFORM ''())) &body BODY`

```text
(dotimes (<変数> <整数式> <値>)
  <式1> ... <式n>)

指定された回数だけ繰り返しを行います。

まず<整数式>を評価します。その値をnとすると、0～n-1までのそれぞれの
整数値に対して、<変数>をその整数値にバインドして、本体の<式1>～<式n>
までを評価します。すなわち本体式はn回繰り返されます。本体式の評
価がn回繰り返されると、<値>を評価し、dotimesの値として返します。
また<値>は省略でき、その場合dotimesの戻り値はnilです。

dotimes式の一般形は、

(do* ((temp <整数式>)
      (<変数> 0 (1+ <変数>)))
    ((>= <変数> temp) <値>)
  <式1>
  ...
  <式n>)

と同値です。
```

## `go`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `go TAG`

```text
tagbody や prog の中で指定されたタグへジャンプします。

使用例:
  ;;; dotimes 相当のループを tagbody と go で書いてみる
  (let ((x 0) (sum 0))
    (tagbody
      start
      (setq sum (+ sum x)
            x (1+ x))
      (if (<= x 10) (go start)))
    sum)
  => 55
```

関連: `tagbody`, `prog`

## `if`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `if TEST THEN [ELSE]`

```text
いわゆるIF文を実行します。
TESTがnon nilならTHENを実行。nilならELSEを実行します。

構文：
  (if TEST THEN [ELSE])
```

## `lambda`

- Misc / package: lisp / 定義: evalmacs.l
- 呼び出し: `lambda LAMBDA-LIST [[{DECLARATION}* | DOCUMENTATION]] {FORM}*`

```text
関数に名前を付ける必要がなく、手続きだけを記述したい場合にラムダ式
を用います。ラムダ式の二番目の引数はラムダリストと呼ばれ、関数の
パラメータの名前を与えます。lambda式のより完全な構文は以下です。

(lambda ({var}*
         [&optional {var | (var [initform [svar]])}*]
         [&rest var]
         [&key {var | ({var | (keyword var)} [initform [svar]])}*]
         [&aux {var | (var [initform])}*])
   [[{declaration}* | documentation-string]]
   {form}*)

引数がラムダ式によって表される関数に適用されると、form が評価
されて最後の form の結果が返されます。form は順に評価されます。

((lambda (x y) (+ x y)) 10 20)        => 30

ラムダリストの各要素は、パラメータ指定子や、記号&（アンパサンド）
で始まるラムダリストキーワードからなる。ラムダリストは５つの部分で
構成されます。

・必須パラメータの記述
    ラムダリストキーワードよりも前に現れる var を必須パラメータという。

・オプショナルパラメータの記述
    &optionalから次のラムダリストキーワードまでか、ラムダリストの
    終わりまで。関数呼び出し時に、オプショナルパラメータに対応する
    引数はあっても無くてもよい。引数が省略された場合、initform が
    あれば initform に初期化され、無ければ nil で初期化される。
    svar は引数が与えられたかどうかを示す。

  ((lambda (x &optional (y 0 given))
       (if given (+ x y) x))
    10 20)
  => 30

・レストパラメータの記述
    &restとそれに続く一つのパラメータ指定子。関数への引数のうち、
    必須パラメータとオプショナルパラメータに対応するもの以外
    からなるリストに束縛される。

  ((lambda (x &optional (y 1) (z 2) &rest args)
       (list x y z args))
    'a 'b 'c 'd 'e 'f)
  => (a b c (d e f))

・キーワードパラメタの記述
    &keyから次のラムダリストキーワードまでか、ラムダリストの
    終わりまで。関数が呼ばれたときに対応する keyword に対応する
    パラメータ指定子 var が値に束縛される。

  ((lambda (x &key ((:test f) #'eq))
       (if (funcall f x "word") 'True 'False))
   "word" :test #'equal)
  => True

  ((lambda (x &key (test #'eq))
       (if (funcall test x "word") 'True 'False))
    "word" :test #'eql)
  => False

・補助変数の記述
    ラムダリストに &aux が含まれるなら、この後の全ての指定は
    補助変数の指定子である。次に示す二つの例は同じ結果を与える。
    これらの使用については純粋にスタイルの問題である。
  
  ((lambda (x &aux (l (length x)))
       (list x l))
    '(a b c))
  => ((a b c) 3)
  
  ((lambda (x)
       (let ((l (length x))) (list x l)))
    '(a b c))
  => ((a b c) 3)
```

関連: `defun`, `si:closure-variable`

## `locally`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `locally {declaration}* {FORM}*`

```text
名前をローカルにスペシャル宣言し、フォームを順番に評価して
最後のフォームの結果を返します。

使用例：
  (defun sample-function (y)
    (declare (special y))       ; スペシャル変数
    (let ((y t))
      (list y                   ; レキシカル変数
            (locally
              (declare (special y))
              y)                ; スペシャル変数
            y                   ; レキシカル変数
            (symbol-value 'y)   ; スペシャル変数
            )))
  => sample-function

  (sample-function nil)
  => (t nil t nil)

補足：
  xyzzy 0.2.2.241 から利用可能です。
```

## `loop`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `loop &body BODY`

```text
無限ループします。
脱出するには以下の様にreturnを使います。

 (loop
   処理
   (if 条件 (return 値))
   処理)

使用例：
  ;;; 「はい」と答えるまで繰り返し
  (loop (if (yes-or-no-p "quit?") (return 123)))
  => 123
```

## `mapc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `mapc FUNCTION LIST &rest MORE-LISTS`

```text
引数の渡し方はmapcarとよく似ていますが、戻り値には与えられたリストをその
まま返します。
```

関連: `mapcar`

## `mapcan`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `mapcan FN LISTS &rest MORE-LISTS`

```text
引数の渡し方は mapcar によく似ていますが、関数 FN の呼び出し結果をくっつ
けたリストを返します。

  (mapcan f x1 ... xn) == (apply #'nconc (mapcar f x1 ... xn))

使用例：
  ;;; mapcanとmapcarとの違い
  (mapcan #'(lambda (x) (and (characterp x) (list (char-name x))))
          '(456 #\A 789 #\b #\c 123))
  => ("latin_capital_letter_a" "latin_small_letter_b" "latin_small_letter_c")
  (mapcar #'(lambda (x) (and (characterp x) (list (char-name x))))
          '(456 #\A 789 #\b #\c 123))
  => (nil ("latin_capital_letter_a") nil ("latin_small_letter_b") ("latin_small_letter_c") nil)
```

関連: `mapcar`, `mapcon`, `nconc`

## `mapcar`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `mapcar FUNCTION LIST &rest MORE-LISTS`

```text
引数のリストから関数の戻り値のリストを作成して返します。
初回は各リストのcarを、二回目はcadrを、三回目はcaddrを関数に渡します。
リストが複数の場合が分かりにくいので図示します。

  ;;; リストが一つ      ┌──┐┌──┐┌──┐
  (mapcar #'char-name '(│ #\a││ #\b││ #\c│))
                        └─┬┘└─┬┘└─┬┘
                    ┌───┘      │      └───┐
                    ↓              ↓              ↓
  == (list (char-name #\a) (char-name #\b) (char-name #\c))
  == (list "latin_small_letter_a" "latin_small_letter_b" "latin_small_letter_c")
  => ("latin_small_letter_a" "latin_small_letter_b" "latin_small_letter_c")

  ;;; リストが複数   ┌─┐┌─┐┌─┐
  (mapcar #'+      '(│ 1││ 2││ 3│ 4)
                   '(│ 1││ 3││ 5│  )
                   '(│ 1││ 4││ 9│16)
                   '(│ 1││ 8││27│  )) 
                     └┬┘└┬┘└┬┘
             ┌────┘┌─┘    │   
             ↓          ↓        ↓         
  == (list (+ 1 1 1 1) (+ 2 3 4 8) (+ 3 5 9 27))
  == (list 4 17 44)
  => (4 17 44)

使用例：
  (mapcar #'+ '(1 2 3 4) 
              '(1 3 5) 
              '(1 4 9 16) 
              '(1 8 27)) 
  => (4 17 44)
```

関連: `mapcan`, `mapcon`, `maplist`, `mapc`, `mapl`, `map`

## `mapcon`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `mapcon FN LISTS &rest MORE-LISTS`

```text
引数の渡し方は maplist によく似ていますが、関数 FN の呼び出し結果をくっ
つけたリストを返します。

  (mapcon f x1 ... xn) == (apply #'nconc (maplist f x1 ... xn))

使用例：
  (mapcon #'(lambda (x) (if (find 2 x) (list x))) '(1 a 2 b 3))
  => ((1 a 2 b 3) (a 2 b 3) (2 b 3))
  
  (mapcon #'(lambda (x) (if (find 2 x) x)) '(1 a 2 b 3)) ; 無限ループ?
  
  (mapcon #'(lambda (x) (if (find 2 x) (copy-list x))) '(1 a 2 b 3))
  => (1 a 2 b 3 a 2 b 3 2 b 3)
```

関連: `maplist`, `mapcan`, `nconc`

## `mapl`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `mapl FUNCTION LIST &rest MORE-LISTS`

```text
引数の渡し方はmaplistとよく似ていますが、戻り値には与えられたリストをそ
のまま返します。
```

関連: `maplist`

## `maplist`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `maplist FUNCTION LIST &rest MORE-LISTS`

```text
引数のリストから関数の戻り値のリストを作成して返します。
初回は各リストを、二回目はcdrを、三回目はcddrを関数に渡します。

使用例：
  (maplist #'(lambda (x) (cons 'foo x)) '(a b c d))
  => ((foo a . #1=(b . #2=(c . #3=(d)))) (foo . #1#) (foo . #2#) (foo . #3#))
```

関連: `mapcar`, `mapcon`

## `multiple-value-call`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `multiple-value-call FUNCTION {FORM}*`

```text
FORM の戻り値を引数として FUNCTION を呼びます。
apply と違って多値で返された二番目以降の戻り値も渡します。

使用例：
  (multiple-value-call #'+ (values 1 2 3) (values 4 5))
  => 15
```

関連: `multiple-value-bind`, `apply`, `values`

## `multiple-value-prog1`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `multiple-value-prog1 FORM {FORM}*`

```text
フォームを順番に評価して最初のフォームの結果を多値で返します。

prog1 に似ていますが、最初のフォームが多値を返した場合でも prog1 の戻
り値は多値になりません。
```

関連: `prog1`, `values`, `multiple-value-bind`

## `or`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `or &rest FORMS`

```text
フォームがnilの間だけ順番に評価します。
フォームが一つでもnon-nilならば、そこで評価を中断してフォームの値を返し
て終了します。全てのフォームがnilならば、nilを返します。

  ;;; exp1 がnilならexp2を実行し、
  ;;; exp2 がnilならexp3を実行し、
  ;;; exp3 がnilなら......
  ;;; 最後に実行したexpの値を返す。
  (or exp1 exp2 exp3 ...)

ルールに従って一つだけ値を定める場合に向いていると思います。

  (or (get-buffer-file-name) ; バッファにファイル名があればそれを使う。
      *foo*                  ; ファイル名がなければ、変数*foo*の値を使う。
      (read-string "foo: ")) ; *foo*にも値が無ければ入力してもらう。
```

関連: `and`

## `prog`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `prog VARLIST &body BODY`

```text
let と block と tagbody を合わせた制御構造です。

VARLIST によって局所変数を作り BODY を評価する点は let と同じですが、
BODY の中で return が使える点、ラベルを作ってジャンプできる点が異なります。

例：
  (let ((x 1)) (return x))
  => `return-from'のキャッチャを参照できません: nil

  (prog ((x 1)) (return x))
  => 1

  (prog ((x 0))
    tag
    (princ x)
    (incf x)
    (if (= x 10)
        (return x)
      (go tag)))
  -> 0123456789
  => 10
```

関連: `prog*`, `let`, `tagbody`

## `prog*`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `prog* VARLIST &body BODY`

```text
prog とよく似ていますが、 VARLIST の中で先に定義した他の変数を参照でき
る点が異なります。
```

関連: `tagbody`, `prog`, `let*`

## `prog1`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `prog1 FIRST &body BODY`

```text
フォームを順番に評価して最初のフォームの結果を返します。

使用例：
  (prog1 (print "The first form")
         (print "The second form")
         (print "The third form"))
  -> "The first form"
  -> "The second form"
  -> "The third form"
  => "The first form"
```

## `prog2`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `prog2 FIRST SECOND &body BODY`

```text
フォームを順番に評価して二番目のフォームの結果を返します。

使用例：
  (prog2 (print "The first form")
         (print "The second form")
         (print "The third form"))
  -> "The first form"
  -> "The second form"
  -> "The third form"
  => "The second form"
```

関連: `progn`, `prog1`

## `progn`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `progn {FORM}*`

```text
フォームを順番に評価して最後のフォームの結果を返します。

使用例：
  (progn (print "The first form")
         (print "The second form")
         (print "The third form"))
  -> "The first form"
  -> "The second form"
  -> "The third form"
  => "The third form"
```

## `return`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `return &optional RESULT`

```text
指定された値でブロックから脱出します。
catchしてくれるブロックがないと例外が発生します。

  (return RESULT) = (return-from nil RESULT)

使用例：
  ;;; ループからの脱出の場合
  (loop (if (yes-or-no-p "quit?") (return 123)))
  => 123

  ;;; ブロックが無いのでcatchできない場合
  (if (yes-or-no-p "quit?") (return 123))
  => `return-from'のキャッチャを参照できません: nil
```

関連: `return-from`

## `return-from`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `return-from NAME [RESULT]`

```text
ブロックから脱出します。
```

## `step`

- Macro / package: lisp / 定義: misc.l
- 呼び出し: `step FORM`

```text
ステップ実行を行います。
```

## `tagbody`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `tagbody {TAG|STATEMENT}*`

```text
labelジャンプです。
tagbody内は任意の数のtag(シンボルもしくは数字)とstatement(S式)からなり
実行時にはtagは無視されstatementが実行されます。(go tag)が評価されたときに
実行はtagの場所に移ります。tagbodyは終了時にnilを返します。
```

関連: `go`

## `throw`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `throw TAG RESULT`

```text
catchで指定されたラベルまで、非局所脱出します。
名前はC++と同じです。

  C++  : try    throw
  Lisp : catch  throw

使用例：
  ;;; test2で例外を出してtest1でキャッチする。
  (defun test1 (x)
    (catch 'label1
      (test2 x)))
  => test1
  (defun test2 (x)
    (if (zerop x)
        (throw 'label1 'division-by-zero)
        (/ 1 x)))
  => test2
  (test1 0)
  => division-by-zero

参考：
  エラー処理関連
```

関連: `catch`

## `unless`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `unless TEST &body BODY`

```text
条件が成立しない場合に実行します。whenの逆です。

  (unless 条件式  本体 ....)
```

関連: `when`

## `unwind-protect`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `unwind-protect PROTECTED-FORM {CLEANUP-FORM}*`

```text
PROTECTED-FORM 中に終了もしくは例外が発生しても（正常、異常を問わず）
CLEANUP-FORM を実行します。

使用例：
  ;;; ゼロ除算が起きても CLEANUP-FORM が実行される。
  (progn
    (msgbox "計算前")
    (unwind-protect (/ 1 0)
      (msgbox "計算後")))
  => 0で除算しました: /: (1 0)
```

関連: `handler-case`, `ignore-errors`

## `when`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `when TEST &body BODY`

```text
条件がnilでなければフォームを連続して実行します。

  TEST : 条件部
  BODY : nilでない場合に実行するフォーム

whenはマクロです。以下の様に展開されます。

 (when exp1 exp2 exp3 ...)
 = (if exp1
      (progn exp2
             exp3
             ...))
```

## `while`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `while TEST &body BODY`

```text
条件節が成立する間、BODYを繰り返して実行します。
BODYの実行の途中でwhileを抜けるには、returnを使います。

  (while 条件 本体)

使用例：
  ;;; 確認しつつ処理を実行する場合
  (while (yes-or-no-p "次行に移動しますか？")
    (forward-line)
    (reverse-region (progn (goto-bol) (point))
                    (progn (goto-eol) (point)) t)
    (refresh-screen))
  => nil
```
