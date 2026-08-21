# エラー (errors)

reference/reference.xml から自動生成。13 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*error-regexp-list*`

- Variable / package: editor / 定義: errors.l

```text
first-error/next-errorで使用するエラー発生位置の表記形式を変更することが可能です。
*error-regexp-list*の形式は以下のとおりです。

  ((正規表現1 ファイル名のマッチ位置1 行のマッチ位置1)
   (正規表現2 ファイル名のマッチ位置2 行のマッチ位置2)
    ...
   (正規表現N ファイル名のマッチ位置N 行のマッチ位置N))

[xyzzy:05447]で亀井さんが示しているとおり、pushを使って追加するのが無難です。
(push (list (compile-regexp "^\"\\([^\"\n]+\\)\", line \\([0-9]+\\):") 1 2)
      *error-regexp-list*)
```

関連: `next-error`, `first-error`

## `define-condition`

- Macro / package: lisp / 定義: condition.l
- 呼び出し: `define-condition NAME (PARENT-TYPE) &rest BODY`

```text
新しいコンディションを定義します。
新しく定義したコンディションは error で投げたり
handler-case で処理したりできます。

コンディションは構造体からできています。
親となるコンディションにスロットが定義されている場合、
新しいコンディションにもそれらのスロットが引き継がれます。

  NAME        : コンディションの名前
  PARENT-TYPE : 親となるコンディション
  BODY
    第一要素  コンディションに追加するスロットの名前のリスト
    それ以降  以下のどれか一つを car として持つリスト
      :documentation  コンディションの説明を設定します。
      :report         エラー報告用の関数を指定します。
      :important      important な構造体になる？（詳細不明）

使用例:
  ;; lisp/condition.l より
  (define-condition check-type-error (type-error)
    (string place)
    (:report (lambda (c s)
               (format s "`~A'の値`~S'は~:[~S~;~:*~A~]ではありません"
                       (check-type-error-place c)
                       (check-type-error-datum c)
                       (check-type-error-string c)
                       (check-type-error-expected-type c)))))

  ;; 自分で定義してみる
  (define-condition my-error (error)
    (string) ; 新しいスロット :string を追加
    (:documentation "自分で定義したコンディション")
    (:report (lambda (c s) ; c はコンディション、s は出力ストリーム
               (format s "エラーです: ~A"
                       (my-error-string c))))
    (:important t))
  => t
  (error 'my-error :string "test")
  => エラーです: test
  (documentation 'my-error 'type)
  => "自分で定義したコンディション"
```

関連: `handler-case`, `error`, `エラー処理関係`, `make-condition`

## `error`

- Function / package: lisp / 定義: handler.l
- 呼び出し: `error DATUM &rest ARGS`

```text
例外を発生します。

発生させた例外は上位の階層でハンドリングすることができます。
ハンドリングの方法はhandler-caseを参照して下さい。
```

関連: `handler-case`, `ignore-errors`, `unwind-protect`, `エラー処理関係`, `stack-trace`, `make-condition`, `si:*condition-string`, `si:*throw-error`

## `first-error`

- Function / package: editor / 定義: errors.l
- 呼び出し: `first-error &optional ARG WRAP`

```text
grep後の*compilation*バッファ上で実行すると、該当行へジャンプ可能です。[F10]
以後は、next-error([F11], [C-x `])を押すことで次々と該当行へジャンプ可能です。
各種コンパイラの出力結果に応じてジャンプすることも可能です。
また、コンパイラのエラー出力が標準に対応していなくても、
*error-regexp-list*を変更することで対応が可能な場合があります。
```

関連: `next-error`, `*error-regexp-list*`

## `handler-case`

- Macro / package: lisp / 定義: handler.l
- 呼び出し: `handler-case FORM &rest CASES`

```text
例外をキャッチします。
詳細はエラー処理関連を参照してください。キャッチした例外は
si:*condition-stringで対応する文字列を取得できるようです。

  (handler-case
    例外が発生しそうな処理
    (エラーのシンボル1 (仮引数1) エラー処理1)     
    (エラーのシンボル2 (仮引数2) エラー処理2)     
    (エラーのシンボル3 (仮引数3) エラー処理3))

例えば、例外が発生しそうな処理で(error エラーシンボル2)が起きると、途中
の処理をすっとばして、エラー処理2が実行されます。そこで対応出来れば処理
を継続しますが、対応できなければ(error 仮引数2)を実行して、より上位の
handler-caseに対応をお願いします。どこまでいっても対応できなければ、
xyzzyがエラーダイアログを出して処理を終了します。

使用例：
  ;;; 例外が出ても、個々に対応しつつ処理を継続する場合
  ;;; with-output-to-stringを使ってるのは変数が煩わしいから
  (with-output-to-string (out)
    (dolist (i '((6 3) (6 0) (6 "a")))
      (handler-case
          (/ (car i) (cadr i))
        (division-by-zero (c)
          (format out "division-by-zero: ~a~%" (si:*condition-string c)))
        (error (c)
          (format out "error:\t ~a~%" (si:*condition-string c))))))
  => "division-by-zero: 0で除算しました: /: (6 0)
      error:     不正なデータ型です: \"a\": number"
```

関連: `ignore-errors`, `trap-errors`, `unwind-protect`, `error`, `エラー処理関係`

## `ignore-errors`

- Macro / package: lisp / 定義: handler.l
- 呼び出し: `ignore-errors &body BODY`

```text
本体を評価したときに発生するエラーを全て無視します。
エラーが発生した場合には、ignore-errorsはnilとそのコンディションを多値で
返します。

C++の場合：
  try {
    return resolve_shortcut("c:\\autoexec.bat");
  } catch (...) {
    return nil;
  }

xyzzyの場合：
  (ignore-errors  (resolve-shortcut "c:/autoexec.bat"))
  =>nil
  =>#S(file-error pathname "c:/autoexec.bat" datum ショートカットではありません)
```

関連: `trap-errors`, `handler-case`, `unwind-protect`, `エラー処理関係`

## `make-condition`

- Function / package: lisp / 定義: condition.l
- 呼び出し: `make-condition TYPE &rest ARGS`

```text
TYPE 型のコンディションを作成して返します。
作成するだけで、エラーにはなりません。
エラーを発生させるには error などで投げる必要があります。

使用例:
  (make-condition 'simple-error)
  => #S(simple-error format-string nil format-arguments nil)
```

関連: `handler-case`, `error`, `エラー処理関係`, `define-condition`

## `next-error`

- Function / package: editor / 定義: errors.l
- 呼び出し: `next-error &optional ARG`

```text
次のエラーの該当行にジャンプします。[F11], [C-x `]
```

関連: `*error-regexp-list*`, `first-error`

## `plain-error`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `plain-error &rest REST`

```text
（詳細不明）
```

## `quit`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `quit`

```text
コマンドの実行などを中止します。[C-g]

実行に時間がかかりすぎる場合や無限ループに陥ったときなどに使われます。
```

関連: `error`

## `toggle-trace-on-error`

- Function / package: editor / 定義: misc.l
- 呼び出し: `toggle-trace-on-error &optional (ARG () SVAR)`

```text
エラーをトレースするかどうかをトグルします。
On にする時にトレース用のバッファ *Trace Output* が無ければ新しく作ります。

前置引数をつけた場合、toggle-mode と同じような挙動をします。
```

関連: `ed::toggle-mode`

## `trap-errors`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `trap-errors &body BODY`

```text
BODY 内でエラーが起こった場合もしくは中断（quit）された場合、
キャッチして trap-errors の外に影響がでないようにします。
handler-case の簡易版といえます。
ignore-errors と違い、エラーが発生したら表示されます。

使用例:
  ;; エラーが起きたらとりあえずキャッチして、その後の処理は続ける。
  (progn
    (trap-errors
      (/ 1 0))
    (msgbox "done."))
```

関連: `handler-case`, `ignore-errors`

## `エラー処理関係`

- Tips

```text
エラーの種類のツリー（階層）です。

condition
├simple-condition
├serious-condition
│├error
││├simple-error
│││└plain-error
││├arithmetic-error
│││├division-by-zero
│││├floating-point-overflow
│││├floating-point-underflow
│││├domain-error
│││├bignum-overflow
│││└power-number-too-large
││├cell-error
│││├unbound-variable
│││├modify-constant
│││└undefined-function
││├control-error
│││└target-missing
││├file-error
│││├file-not-found
│││├path-not-found
│││├access-denied
│││├invalid-drive
│││├current-directory
│││├not-same-device
│││├write-protected
│││├bad-unit
│││├device-not-ready
│││├sharing-violation
│││├lock-violation
│││├wrong-disk
│││├file-exists
│││├not-empty
│││├archiver-error
│││├network-error
│││└file-lost-error
││├package-error
│││└simple-package-error
││├program-error
│││├no-target
│││├bad-macro-form
│││├invalid-function
│││├invalid-variable-list
│││├invalid-lambda-list
│││└invalid-keyword-list
││├type-error
││├range-error
││├stream-error
│││└end-of-file
││├reader-error
││├too-few-arguments
││├too-many-arguments
││├bad-type-specifier
││├read-only-buffer
││└dde-error
││  ├dde-timeout
││  ├dde-busy
││  ├dde-low-memory
││  ├dde-no-conv
││  ├dde-not-processed
││  ├dde-server-died
││  └dde-terminated-transaction
│├storage-condition
│├stack-overflow
│└invalid-byte-code
├quit
│└silent-quit
└warning
  └simple-warning


| xyzzyはもちろん、Emacs Lispでなくて Common Lispに合わせているんですよね。

そうです。コンディションタイプには独自のがありますけど。Stallman先生は、
直接ではないですがCommonのコンディションシステムに影響を与えているらしい
ので、仕組み的には似てます。

| コンディションって何ですか？

Commonでは、エラーと言わずにコンディションと言うらしいです(エラー以外も
投げられるから?)。簡単に言うとC++のtry-catchと同じです(多分、C++がパクっ
たんだろうけど)。

  class condition {};
  class serious_condition: public condition {};
  class error: public serious_condition {};
  class arithmetic_error: public error {};
  class division_by_zero: public arithmetic_error {};

ってのがある場合、

  throw division_by_zero;

とすると、

  try {...} catch (division_by_zero &) {...}

でも、

  try {...} catch (error &) {...}

でも、

  try {...} catch (condition &) {...}

でも捕まえられますよね?
それと同様に

  (error 'division-by-zero)

は、

  (handler-case ... (division-by-zero (c) ...))
  (handler-case ... (error (c) ...))
  (handler-case ... (condition (c) ...))

どれででも捕まえることができます。ま、名前が違うだけでEmacsの
condition-caseと同じです(多分)。catch&throwのタグに継承関係を付けた
のとも同じかも。

また、Emacsでできるかどうかは知りませんが、↓な感じで次のキャッチャにコ
ンディションを渡すこともできます。

  (handler-case
      (any-expression)
    (error (c)
      (some-expression)
      (error c)))

C++での
  try
    {
      any-expression;
    }
  catch (error &)
    {
      some-expression;
      throw;
    }
と同じですけど。
```
