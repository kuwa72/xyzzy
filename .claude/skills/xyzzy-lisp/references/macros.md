# マクロ (macros)

reference/reference.xml から自動生成。9 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*executing-macro*`

- Variable / package: editor / 定義: cmds.l

```text
マクロを実行中か否かを返します。
  t    マクロを実行中
  nil  マクロを実行中ではない
```

## ```'(backquote)`

- Misc / package: ???
- 呼び出し: `form`

```text
注：タイプはリードマクロなんですが・・・
　　info-modokiでどうしようか悩んでしまいます。

``'(逆引用符(backquote))はリストをquoteします。ただし、特別な標識 `,' 
及び `,@' を用いることで、リストの要素を選択的に評価することができます。

使用例：
  ;;; 逆引用符を使用してリストを作成
  (setq f0 '(0 1 2 3))         =>  (0 1 2 3)  
  (setq f1 `(0 1 2 3))         =>  (0 1 2 3)
  (setq f2 `(4 5 ,(car f1)))   =>  (4 5 0)
  (setq f3 `(6 7 ,(cdr f1)))   =>  (6 7 (1 2 3))
  (setq f4 `(8 9 ,@(cdr f1)))  =>  (8 9 1 2 3)
```

## `call-last-kbd-macro`

- Function / package: editor / 定義: kbdmacro.l
- 呼び出し: `call-last-kbd-macro &optional (ARG 1)`

```text
start-kbd-macro/end-kbd-macroで登録したキーボードマクロを実行します。
[C-x e]
[ツール(T)]-[キーボードマクロおまけ(O)]-[保存]したキーボードマクロは、
[ツール(T)]-[キーボードマクロおまけ(O)]-[読み込み]で後から選択することが可能です。
```

関連: `command-execute`

## `defmacro`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `defmacro NAME (&rest LAMBDA-LIST) &body BODY`

```text
マクロを定義します。

使用例：
  ;;; cadrをマクロで定義し直した場合
  (defmacro cadr (x)
    (list 'car (list 'cdr x)))
  => cadr
  (macroexpand '(cadr y))
  => (car (cdr y))

参考：
  --- 亀井さんの説明 [xyzzy:03975] ---
  
  マクロは 2 回評価される関数みたいなものと思っていれば
  間違いないでしょう(ただし 1 回目の評価のときには引数の
  評価はされない)。ごく簡単な例をあげると、
  
    (defmacro foo ()
      '(+ 1 2))
  
  このように定義して (foo) を評価すると、1 回目の評価で
  (+ 1 2) が返り、それをさらに評価して 3 が返る、となり
  ます。引数がある場合も同様に、
  
    (defmacro bar (n)
      (list '+ 1 n))
  
    (bar 3)
    -> (+ 1 3)
    => 4
  
  となります。
  
  | (M (any1) (any2) (any3)) と呼び出すと、
  |     (progn
  |       (m-setup)
  |       (any1)
  |       (any2)
  |       (any3)
  |       (m-cleanup))
  | と呼ばれるのと同じよう動作するものはどうしたら良いですか？
  
  この場合、引数が 3 つなので、こうなります。
  
    (defmacro M (a b c)
      (list 'progn '(m-setup) a b c '(m-cleanup)))
  
    (M (any1) (any2) (any3))
    -> (progn (m-setup) (any1) (any2) (any3) (m-cleanup))
    => ?
  
  ふつ～、引数は何個でもありだろうってなときは、通常の関
  数と同様に &rest で受けてやればいいわけですね。
  
    (defmacro M2 (&rest args)
      (append '(progn) '((m-setup)) args '((m-cleanup))))
  
    (M2 (any1) (any2) (any3))
    -> (progn (m-setup) (any1) (any2) (any3) (m-cleanup))
    => ?
  
  ちなみに、1 回目がどのように評価されているか(マクロの
  展開)を見るには macroexpand を使います。
  
    (macroexpand '(M2 (any1) (any2) (any3)))
    => (progn (m-setup) (any1) (any2) (any3) (m-cleanup))
  
  複雑なマクロ定義だと、list やら append やら cons やら 
  quote やらをごちゃごちゃ書くのがめんどくせ～、というわ
  けでテンプレートを使うことができます。詳しい説明は面倒
  なのでしませんが(^^; 上の例をテンプレートを使って書く
  とこのようになります。
  
    (defmacro M (a b c)
      `(progn
         (m-setup)
         ,a ,b ,c
         (m-cleanup)))
  
    (defmacro M2 (&rest args)
      `(progn
         (m-setup)
         ,@args
         (m-cleanup)))
```

関連: `macroexpand`, ```'(backquote)`

## `macro-function`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `macro-function SYMBOL &optional ENV`

```text
SYMBOLがマクロか否かを返します。マクロの場合にはその内容を返します。
ENVを指定した場合は指定した環境からマクロを探します。

使用例：
  (macro-function 'car)
  => nil

  (macro-function 'when)
  => (macro (lisp::test &body lisp::body)
          (block when (list 'if lisp::test (cons 'progn lisp::body))))

  (macrolet ((foo (a b)
               `(+ ,a ,b))
             (env (&environment env)
               env))
    (setf env (env)))
  => #<environment-object 134287448>

  (macro-function 'foo)
  => nil

  (macro-function 'foo env)
  => (macro (a b) (block foo (list '+ a b)))

補足：
  xyzzy 0.2.2.241 からENVを指定可能です。
```

関連: `fboundp`, `boundp`

## `macroexpand`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `macroexpand FORM &optional ENV`

```text
フォームがどのようにマクロ展開されるかを返します。
マクロの展開され方を確認するのに役立ちます。

使用例：
  ;;; マクロM2を定義してどのように展開
  (defmacro M2 (&rest args)
      `(progn
         (m-setup) ,@args (m-cleanup)))
  (macroexpand '(M2 (insert "Begin") (insert "End")))
  => (progn (m-setup) (insert "Begin") (insert "End") (m-cleanup))
```

関連: `defmacro`, `macroexpand-1`

## `macroexpand-1`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `macroexpand-1 FORM &optional ENV`

```text
macroexpandに似ていますが、展開されるレベルが1レベルで終わるところが違います。
自作のマクロなどがどう展開されるのか調べるときに便利です。

使用例:
  (defmacro my-macro ()
    `(dotimes (x 10)))
  というマクロがあるとき
  
  (macroexpand '(my-macro))
  => (block nil (let* ((x 0) (#1=#:count 10)) (lisp::*loop (if (>= x #1#) (return (progn 'nil))) (tagbody) (setq x (+ x 1)))))
  とmy-macro展開後のdotimesまで(実際はdotimesを展開後さらにdo*を展開)が
  再帰的に展開されますが、

  (macroexpand-1 '(my-macro))
  => (dotimes (x 10))
  と、my-macroだけが展開されます。
```

関連: `macroexpand`

## `macrolet`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `macrolet ({(NAME LAMBDA-LIST {declaration}* [doc-string] {FORM}*)}*) {FORM}*`

```text
defmacroの局所版です。
```

関連: `defmacro`, `flet`

## `set-syntax-from-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-syntax-from-char TO-CHAR FROM-CHAR &optional TO-READTABLE FROM-READTABLE`

```text
文字のシンタックスを変更します。
lisp のリーダの挙動が変わります。

  TO-CHAR        : シンタックスを変更する文字
  FROM-CHAR      : 設定するシンタックスを持つ文字
  TO-READTABLE   : 変更するリードテーブル (指定しなければ *readtable*)
  FROM-READTABLE : 変更元のリードテーブル (指定しなければデフォルトのリードテーブル)

使用例：
  ;;; カンマを whitespace として扱うようにしてみる
  (let ((readtab (copy-readtable)))
    (set-syntax-from-char #\, #\SPC readtab *readtable*)
    (let ((*readtable* readtab))
      (read-from-string "(a,b,c)")))
  => (a b c)
  => 7
```
