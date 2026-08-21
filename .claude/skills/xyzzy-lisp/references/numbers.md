# 数値 (numbers)

reference/reference.xml から自動生成。87 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `* &rest NUMBERS`

```text
引数を全て乗算した数値を返します。

使用例：  
  (* 1 2 3)
  => 6
```

関連: `/`

## `*random-state*`

- Variable / package: lisp

```text
現在の乱数の状態を保持してます。
random が STATE 無しで呼ばれたとき使われます。
```

関連: `random`, `make-random-state`

## `+`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `+ &rest NUMBERS`

```text
引数を全て加算して返します。

使用例：  
  (+ 1 2 3)
  => 6
  (+ 1.2 4 -2)
  => 3.2
```

関連: `-`

## `-`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `- NUMBER &rest MORE-NUMBERS`

```text
引数が一つの場合にはその数値をマイナスにしたものを返します。
引数が二つ以上の場合には一つ目の引数からその他の引数を減算した数値を返します。

使用例：
  (- 3)
  => -3
  (- 3 2 1)
  => 0
```

関連: `+`

## `/`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `/ NUMBER &rest MORE-NUMBERS`

```text
引数が一つの場合には 1 を引数で除算した数値を返します。
引数が二つ以上の場合には一つ目の引数を二つ目の引数全てで除算した数値を返します。
  
使用例：  
  (/ 2)
  => 1/2  
  (/ 3 2 1)
  => 3/2
  (/ 4 3 2)
  => 2/3
```

関連: `denominator`, `numerator`, `*`

## `/=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `/= NUMBER &rest MORE-NUMBERS`

```text
引数がすべて異なっていればt、そうでなければnilを返します。

使用例：  
  (/= 2 3)
  => t
  (/= 3 3)
  => nil
  (/= 2 3 4 5)
  => t
  (/= 2 3 4 2)
  => nil
```

関連: `=`

## `1+`

- Function / package: lisp / 定義: number.l
- 呼び出し: `1+ NUM`

```text
NUMに1を足した数を返します。

使用例：  
  (1+ 1)
  => 2
```

関連: `1-`

## `1-`

- Function / package: lisp / 定義: number.l
- 呼び出し: `1- NUM`

```text
NUMから1を引いた数を返します。

使用例：  
  (1- 2)
  => 1
```

関連: `1+`

## `<`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `< NUMBER &rest MORE-NUMBERS`

```text
引数が小さい順に並んでいればt、そうでなければnilを返します。

使用例：  
  (< 2 3 4)
  => t
  (< 2 4 3 5)
  => nil
```

関連: `>`

## `<=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `<= NUMBER &rest MORE-NUMBERS`

```text
隣り合った引数がすべて<=の関係ならt、そうでなければnilを返します。

使用例：  
  (<= 2 3 3 4)
  => t
  (<= 2 4 3 5)
  => nil
```

関連: `>=`

## `=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `= NUMBER &rest MORE-NUMBERS`

```text
引数の数値がすべて等しければt、そうでなければnilを返します。

使用例：  
  (= 3 3)
  => t
  (= 3 4)
  => nil
  (= 3 3 3 3)
  => t
  (= 3 3 3 4)
  => nil
```

関連: `equal`, `equalp`, `/=`

## `>`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `> NUMBER &rest MORE-NUMBERS`

```text
引数が大きい順に並んでいればt、そうでなければnilを返します。

使用例：  
  (> 3 2 1)
  => t
  (> 3 2 1 4)
  => nil
```

関連: `<`

## `>=`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `>= NUMBER &rest MORE-NUMBERS`

```text
隣り合った引数がすべて>=の関係ならt、そうでなければnilを返します。
  
使用例：  
  (>= 4 3 3 2 1)
  => t
  (>= 4 2 3 1)
  => nil
```

関連: `<=`

## `abs`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `abs NUMBER`

```text
絶対値を返します。

使用例：
  ;;; 絶対値を返す。
  (abs -3.0)
  => 3.0
```

## `acos`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `acos NUMBER`

```text
逆余弦関数の値を返します。
```

関連: `acosh`

## `acosh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `acosh Z`

```text
逆双曲線余弦関数を計算します。
```

関連: `acos`

## `ash`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `ash INTEGER COUNT`

```text
整数をロジカルにシフトします。

  INTEGER : シフトする数値
  COUNT   : ビット数分だけ正ならば左に、負ならば右にシフト
  
例：
  ;;; 4を左と右に3ビットずつシフトさせてみる。
  (ash 4 3)
  => 32
  (ash 4 -3)
  => 0
```

## `asin`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `asin NUMBER`

```text
逆正弦関数の値を返します。
```

関連: `asinh`

## `asinh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `asinh Z`

```text
逆双曲線正弦関数を計算します。
```

関連: `asin`

## `atan`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `atan Y &optional X`

```text
逆正接関数の値を返します。
```

関連: `atanh`

## `atanh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `atanh Z`

```text
逆双曲線正接関数を計算します。
```

関連: `atan`

## `byte`

- Function / package: lisp / 定義: number.l
- 呼び出し: `byte SIZE POSITION`

```text
byte specifier を作ります。
「0 を基底として POSITION ビット目から始まる SIZE ビット」
を表すオブジェクトを返します。

内部的には cons と同じです。
```

関連: `dpb`, `ldb`, `byte-position`, `byte-size`

## `byte-position`

- Function / package: lisp / 定義: number.l
- 呼び出し: `byte-position BYTESPEC`

```text
byte specifier の位置を返します。

内部的には cdr と同じです。
```

関連: `byte`

## `byte-size`

- Function / package: lisp / 定義: number.l
- 呼び出し: `byte-size BYTESPEC`

```text
byte specifier のサイズを返します。

内部的には car と同じです。
```

関連: `byte`

## `ceiling`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `NUMBER &optional DIVISOR`

```text
NUMBERを正の無限大方向に丸めます。
DIVISORを省略した場合にはNUMBER以上の最小の整数になります。

使用例：  
  (ceiling 2.2)
  => 3
  (ceiling 2.8)
  => 3
  (ceiling -2.2)
  => -2  
  (multiple-value-list (ceiling 2.2))
  => (3 -0.8)
```

関連: `floor`, `truncate`, `round`, `fceiling`

## `cis`

- Function / package: lisp / 定義: number.l
- 呼び出し: `cis Z`

```text
偏角が Z で絶対値が 1 の複素数を返します。

  (cis Z) == (complex (cos Z) (sin Z))
```

## `complex`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `complex REALPART &optional IMAGPART`

```text
指定された実数部(REALPART)と虚数部(IMAGPART)で複素数を表現します。

使用例：
  (setq a (complex 0 1))
  =>#C(0 1)

  (* a a)
  =>-1
```

関連: `imagpart`, `realpart`

## `conjugate`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `conjugate NUMBER`

```text
共役複素数を返します。
```

## `cos`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `cos RADIANS`

```text
余弦関数の値を返します。
```

## `cosh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `cosh Z`

```text
双曲線余弦関数を計算します。
```

## `decf`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `decf PLACE &optional (DELTA 1)`

```text
変数をデクリメントする

使用例：
  ;;; 変数xの値をデクリメントする。
  (setq x 1)    => 1
  (decf x)      => 0
  x             => 0
```

関連: `incf`

## `denominator`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `denominator RATIONAL`

```text
分数の分母を返します。
```

関連: `numerator`, `/`

## `deposit-field`

- Function / package: lisp / 定義: number.l
- 呼び出し: `deposit-field NEWBYTE BYTESPEC INTEGER`

```text
指定されたフィールドを NEWBYTE の同じフィールドの内容で置き換えた値を返
します。

使用例：
  (format nil "~2,'0x" (deposit-field #x0f (byte 4 4) #xa7))
  =>"07"
  (format nil "~2,'0x" (deposit-field #xaa (byte 4 4) #x0f))
  =>"af"
```

関連: `ldb`, `dpb`

## `dpb`

- Function / package: lisp / 定義: number.l
- 呼び出し: `dpb NEWBYTE BYTESPEC INTEGER`

```text
指定されたフィールドを NEWBYTE で置き換えた値を返します。

使用例：
  (format nil "~2,'0x" (dpb #x0f (byte 4 4) #xa7))
  =>"f7"
  (format nil "~2,'0x" (dpb #x0a (byte 4 4) #x0f))
  =>"af"
```

関連: `ldb`, `deposit-field`

## `evenp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `evenp INTEGER`

```text
INTEGERが偶数ならばt、そうでなければnilを返します。

使用例：  
  (evenp 2)
  => t
  (evenp 0)
  => t
  (evenp 1)
  => nil
```

関連: `oddp`

## `exp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `exp NUMBER`

```text
自然対数の底 e の NUMBER 乗の数値を返します。

使用例：
  ;;; 自然対数の底 e とその二乗を表示してみる。
  (exp 1)
  => 2.718282
  (exp 2)
  => 7.389056
```

## `expt`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `expt BASE-NUMBER POWER-NUMBER`

```text
べき乗します。

使用例：  
  (expt 2 10)
  => 1024
  (expt 10 3)
  => 1000
```

## `fceiling`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fceiling NUMBER &optional DIVISOR`

```text
ceiling と同じですが浮動小数点数を返します。
```

関連: `ceiling`

## `ffloor`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `ffloor NUMBER &optional DIVISOR`

```text
floor と同じですが浮動小数点数を返します。
```

関連: `floor`

## `float`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `float NUMBER &optional OTHER`

```text
任意の型の数値を浮動小数点型に変換します。

  (float 'NUMBER) == (coerce 'NUMBER 'single-float)

使用例：
  ;;; integerをfloatに変換する。
  (setq var 0)                  => 0
  (type-of var)                 => integer
  (setq var (float var))        => 0.0
  (type-of var)                 => single-float
```

関連: `rationalize`

## `floor`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `floor NUMBER &optional DIVISOR`

```text
NUMBERを負の無限大方向に丸めます。
DIVISORを省略した場合にはNUMBERを越えない最大の整数になります。

使用例：  
  (floor 2.2)
  => 2
  (floor 2.8)
  => 2
  (floor -2.4)
  => -3  
  (multiple-value-list (floor 2.2))
  => (2 0.2)
```

関連: `ceiling`, `truncate`, `round`, `ffloor`

## `fround`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fround NUMBER &optional DIVISOR`

```text
round と同じですが浮動小数点数を返します。
```

関連: `round`

## `ftruncate`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `ftruncate NUMBER &optional DIVISOR`

```text
truncateと同じですが浮動小数点数を返します。
```

関連: `truncate`

## `gcd`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `gcd &rest INTEGERS`

```text
引数の最大公約数を返します。

使用例：
  (gcd 91 70)
  => 7
  (gcd 63 -42 35)
  => 7
  (gcd -3)
  => -3
  (gcd 35 8)
  => 1
```

関連: `lcm`

## `imagpart`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `imagpart NUMBER`

```text
複素数の虚数部を取得します。

使用例：
  (setq a (complex 1 3))
  =>#C(1 3)

  (imagpart a)
  =>3
```

関連: `realpart`, `complex`

## `incf`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `incf PLACE &optional (DELTA 1)`

```text
変数をインクリメントします。

使用例：
  ;;; 変数xの値をインクリメントする。
  (setq x 1)    => 1
  (incf x)      => 2
  x             => 2
```

関連: `decf`

## `integer-length`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `integer-length INTEGER`

```text
2進数で表した時の長さを返します。

使用例:
  (integer-length 7) => 3 ; #b00000111
  (integer-length 8) => 4 ; #b00001000
```

## `isqrt`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `isqrt INTEGER`

```text
整数の平方根を整数で返します。

 (isqrt INTEGER) == (floor (sqrt INTEGER))

使用例：
  ;;; 143と144のisqrtを計算する。
  (isqrt 143)
  => 11
  (isqrt 144)
  => 12
```

## `lcm`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `lcm INTEGER &rest MORE-INTEGERS`

```text
引数の最小公倍数を返します。

使用例：  
  (lcm 14 35)
  => 70
  (lcm 0 5)
  => 0
  (lcm 1 2 3 4 5 6)
  => 60
```

関連: `gcd`

## `ldb`

- Function / package: lisp / 定義: number.l
- 呼び出し: `ldb BYTESPEC INTEGER`

```text
指定されたフィールドの値を取り出します。
フィールドを指定する byte specifier は関数 byte で作ります。

例：
  ;;; 最下位ビットを取り出す
  (ldb (byte 1 0) #x02)  => 0
  (ldb (byte 1 0) #x0f)  => 1
  ;;; (最下位バイトの)上位 4 ビットを取り出す
  (ldb (byte 4 4) #x0f)  => 0
  (ldb (byte 4 4) #xaf)  => 10
  (ldb (byte 4 4) #xf0)  => 15
```

関連: `dpb`, `byte`

## `ldb-test`

- Function / package: lisp / 定義: number.l
- 呼び出し: `ldb-test BYTESPEC INTEGER`

```text
指定されたフィールドが non-zero かどうかを判定します。
(not (zerop (ldb BYTESPEC INTEGER))) と同じです。
```

関連: `ldb`

## `log`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `log NUMBER &optional BASE`

```text
BASE を底とする NUMBER の対数を返します。

使用例：
  (log 2.718282)
  => 1.0
  (log 7.389056)
  => 2.0
```

## `logand`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logand &rest ARGS`

```text
ビット毎のANDを取ります。C言語でいう&です。

使用例：
  ;;; 2進数で#b11110000と#b00110011のビットの積を取る。
  (format nil "~8,'0b" (logand #b11110000 #b00110011))
  => "00110000"
```

関連: `logior`, `logandc1`, `logandc2`, `lognand`, `lognot`

## `logandc1`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logandc1 X Y`

```text
Xの1の補数 と Y のビット毎の論理積を返します。

使用例:
  (format nil "~4,'0b" (logandc1 #b0011 #b0101))
  => "0100"
  (format nil "~4,'0b" (logand (lognot #b0011) #b0101))
  => "0100"
```

関連: `logand`, `logandc2`

## `logandc2`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logandc2 X Y`

```text
X と Yの1の補数 のビット毎の論理積を返します。

使用例:
  (format nil "~4,'0b" (logandc2 #b0011 #b0101))
  => "0010"
  (format nil "~4,'0b" (logand #b0011 (lognot #b0101)))
  => "0010"
```

関連: `logand`, `logandc1`

## `logeqv`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logeqv &rest ARGS`

```text
ビット毎の論理等価を返します。

使用例:
  (format nil "~4,'0b" (logeqv #b0011 #b0101))
  => "-111"
  (format nil "~4,'0b" (lognot (logxor #b0011 #b0101)))
  => "-111"
```

関連: `logxor`

## `logior`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logior &rest ARGS`

```text
ビット毎のORを取ります。C言語でいう|です。

使用例：
  ;;; 2進数で#b00110000と#b00000011のビットの和を取る。
  (format nil "~8,'0b" (logior #b00110000 #b00000011))
  => "00110011"
```

関連: `logand`, `lognor`, `logorc1`, `logorc2`

## `lognand`

- Function / package: lisp / 定義: number.l
- 呼び出し: `lognand X Y`

```text
ビット毎の否定的論理積(NAND)を返します。

使用例:
  ;;; X        0011
  ;;; Y        0101
  ;;; AND      0001
  ;;; NAND     1110
  ;;; 1の補数  0001
  ;;; 2の補数  0010
  (format nil "~4,'0b" (lognand #b0011 #b0101))
  => "0-10"
  (format nil "~4,'0b" (lognot (logand #b0011 #b0101)))
  => "0-10"
```

関連: `logand`, `lognor`

## `lognor`

- Function / package: lisp / 定義: number.l
- 呼び出し: `lognor X Y`

```text
ビット毎の否定的論理和(NOR)を返します。

使用例:
  ;;; X        0011
  ;;; Y        0101
  ;;; OR       0111
  ;;; NOR      1000
  ;;; 1の補数  0111
  ;;; 2の補数  1000
  (format nil "~4,'0b" (lognor #b0011 #b0101))
  => "-1000"
  (format nil "~4,'0b" (lognot (logior #b0011 #b0101)))
  => "-1000"
```

関連: `logior`, `lognand`

## `lognot`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `lognot INTEGER`

```text
INTEGERの1の補数(2進数表現で0と1を反転させたもの)を返します。

使用例:
  ;;; INTEGER 00000011
  ;;; 反転    11111100
  ;;; 1の補数 00000011
  ;;; 2の補数 00000100
  (lognot #b0011)
  => -4
  (format nil "~8,'0b" -4)
  => "0000-100"
  (format nil "~4,'0b" (lognot -4))
  => "0011"
```

関連: `logand`, `logor`

## `logorc1`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logorc1 X Y`

```text
Xの1の補数 と Y のビット毎の論理和を返します。

使用例:
  (format nil "~4,'0B" (logorc1 #b0011 #b0101))
  => "0-11"
  (format nil "~4,'0b" (logior (lognot #b0011) #b0101))
  => "0-11"
```

関連: `logior`, `logorc2`

## `logorc2`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logorc2 X Y`

```text
X と Yの1の補数 のビット毎の論理和を返します。

使用例:
  (format nil "~4,'0B" (logorc2 #b0011 #b0101))
  => "-101"
  (format nil "~4,'0b" (logior #b0011 (lognot #b0101)))
  => "-101"
```

関連: `logior`, `logorc1`

## `logxor`

- Function / package: lisp / 定義: number.l
- 呼び出し: `logxor &rest ARGS`

```text
ビット毎の排他的論理和を返します。

使用例:
  (format nil "~4,'0b" (logxor #b0011 #b0101))
  => "0110"
```

関連: `logeqv`

## `make-random-state`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-random-state &optional STATE`

```text
乱数の状態を初期化します

  STATE:
    nil          初期化はせずに現在の*random-state*のコピーを返します。
    t            時刻に基づいて新しい状態を作ります。
    random-state この関数(make-random-state)の戻り値を渡すとコピーが返ります。

使用例:
 ;;;乱数列の再現
 (let ((rs1 (make-random-state nil))
       (rs2 (make-random-state nil)))   ;;現状の乱数状態のコピーを二つ作る
   (dotimes (i 10)
     (format t "~A " (random 100 rs1))) ;;一つ目
   (terpri)
   (dotimes (i 10)
     (format t "~A " (random 100 rs1))) ;;一つ目やりすぎて
   (terpri)
   (dotimes (i 10)
     (format t "~A " (random 100 rs2))) ;;二つ目を少し見てみる。
   (terpri))
 =>3 41 81 70 73 66 32 72 2 55   ;ここと
   21 97 83 14 86 26 99 69 18 46 
   3 41 81 70 73 66 32 72 2 55   ;ここが同じになる
```

関連: `*random-state*`, `random-state-p`, `random`

## `mask-field`

- Function / package: lisp / 定義: number.l
- 呼び出し: `mask-field BYTESPEC INTEGER`

```text
指定されたフィールド以外を 0 とした値を返します。

  ;; ldb との比較
  (format nil "~2,'0x" (ldb (byte 4 4) #xaf))
  =>"0a"
  (format nil "~2,'0x" (mask-field (byte 4 4) #xaf))
  =>"a0"
```

関連: `ldb`

## `max`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `max NUMBER &rest MORE-NUMBERS`

```text
引数の中で最大の数値を返します。

使用例：  
  (max 3)
  => 3
  (max -3 0 2)
  => 2
  (max 2.5 1)
  => 2.5
  (max 3 2.5)
  => 3
```

関連: `min`

## `min`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `min NUMBER &rest MORE-NUMBERS`

```text
引数の中で最小の数値を返します。

使用例：
  (min 3)
  => 3
  (min -2 0 3)
  => -2
  (min 2.5 1)
  => 1
```

関連: `max`

## `minusp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `minusp NUMBER`

```text
NUMBER がゼロより小さければ t 、そうでなければ nil を返します。

使用例：
  (minusp 0)
  => nil
  (minusp -1)
  => t
  (minusp -0.00001)
  => t
```

関連: `plusp`

## `mod`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `mod NUMBER DIVISOR`

```text
(floor NUMBER DIVISOR)の戻り値の二つ目を返します。

使用例：
  (mod 13 4)
  => 1
  (mod -13 4)
  => 3
```

関連: `floor`, `rem`

## `numerator`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `numerator RATIONAL`

```text
分数の分子を返します。
```

関連: `denominator`, `/`

## `oddp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `oddp INTEGER`

```text
INTEGERが奇数ならばt、そうでなければnilを返します。

使用例：  
  (oddp 1)
  => t
  (oddp 0)
  => nil
  (oddp -35)
  => t
```

関連: `evenp`

## `phase`

- Function / package: lisp / 定義: number.l
- 呼び出し: `phase Z`

```text
複素数の偏角を求めます。
戻り値はラジアン単位です。

  (phase -1)
  =>3.141593
```

## `plusp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `plusp NUMBER`

```text
NUMBERがゼロより大きければt、そうでなければnilを返します。

使用例：
  (plusp 0)
  => nil
  (plusp 1)
  => t
  (plusp 0.00001)
  => t
```

関連: `minusp`

## `random`

- Function / 定義: builtin.l
- 呼び出し: `random NUMBER &optional STATE`

```text
0以上NUMBER未満の乱数を返します。

  STATE: 乱数の状態変数です。破壊的に処理されます。
```

関連: `*random-state*`, `make-random-state`

## `rational`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rational NUMBER`

```text
実数を有理数に変換します。もしも、 NUMBER がすでに有理数だったら、そのま
ま返します。 rational の場合は、浮動小数点数を全く誤差を含まないものとし
て扱い、その浮動小数点数を数学的に有理数化します。
  
  ;;; 0.5 は2進数でちょうど表せる
  (rational 0.5)
  =>1/2
  ;;; 0.1 は2進数では誤差を含む
  (rational 0.1)
  =>13421773/134217728
  ;;; 倍精度だとまた違う
  (rational 0.1d0)
  =>3602879701896397/36028797018963968
```

関連: `rationalize`

## `rationalize`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rationalize NUMBER`

```text
実数を有理数に変換します。もしも、 NUMBER がすでに有理数だったら、そのま
ま返します。 rationalize の場合は、浮動小数点数を表示される範囲までの精
度で扱い、近似して有理数化します。
```

関連: `rational`, `float`

## `realpart`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `realpart NUMBER`

```text
複素数の実数部を取得します。

使用例：
  (setq a (complex 1 3))
  =>#C(1 3)

  (realpart a)
  =>1
```

関連: `imagpart`, `complex`

## `rem`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rem NUMBER DIVISOR`

```text
(truncate NUMBER DIVISOR)の戻り値の二つ目を返します。

使用例：  
  (rem 13 4)
  => 1
  (rem -13 4)
  => -1
```

関連: `truncate`, `mod`

## `round`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `NUMBER &optional DIVISOR`

```text
NUMBERを近い方の整数に丸めます。
ちょうど0.5の場合には偶数方向に丸められます。

使用例： 
  (round 2.5)
  => 2
  (round 2.6)
  => 3
  (round 3.5)
  => 4
  (round -2.5)
  => -2
  (round -2.6)
  => -3
  (multiple-value-list (round 2.5))
  => (2 0.5)
```

関連: `floor`, `ceiling`, `truncate`, `fround`

## `signum`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `signum NUMBER`

```text
数値の符号を返します。
引数が複素数の場合は偏角が等しく絶対値が 1 の複素数を返します

使用例：
  (signum 12)
  => 1
  (signum 0)
  => 0
  (signum -5.0)
  =>-1.0
  (signum (complex 1 1))
  =>#C(0.7071068 0.7071068)
```

## `sin`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `sin RADIANS`

```text
正弦関数の値を返します。
```

## `sinh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `sinh Z`

```text
双曲線正弦関数を計算します。
```

## `sqrt`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `sqrt NUMBER`

```text
平方根の値を返します。
```

## `tan`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `tan RADIANS`

```text
正接関数の値を返します。
```

## `tanh`

- Function / package: lisp / 定義: number.l
- 呼び出し: `tanh Z`

```text
双曲線正接関数を計算します。
```

## `truncate`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `truncate NUMBER &optional DIVISOR`

```text
NUMBERを0の方向に丸めます。

使用例：
  (truncate 2.8)
  => 2
  (truncate -2.8)
  => -2
  (multiple-value-list (truncate 2.8))
  => (2 0.8)
```

関連: `rem`, `floor`, `ceiling`, `round`, `ftruncate`

## `zerop`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `zerop NUMBER`

```text
NUMBERがゼロならt、そうでなければnilを返します。

使用例：  
  (zerop 0)
  => t
  (zerop 1)
  => nil
  (zerop 0.0)
  => t
  (zerop -0.00)
  => t
```
