# 評価 (evaluation)

reference/reference.xml から自動生成。19 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `apply`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `apply FUNCTION ARG &rest MORE-ARGS`

```text
引数を格納したリストを指定して関数を表すシンボルから関数を呼び出します。
FNには関数を表すシンボルでも関数でも構いません。引数の個数が必ず定まって
いる場合には、applyを使う必要は無くfuncallの方が良いと思います。

使用例：
  ;;; carをいろいろな呼び出し方でする。
  (car '(a b c))                => a
  (apply 'car '((a b c)))       => a
  (apply #'car '((a b c)))      => a
```

関連: `funcall`, `multiple-value-call`

## `call-interactively`

- Function / package: editor / 定義: misc.l
- 呼び出し: `call-interactively COMMAND &optional HOOK`

```text
指定された関数をinteractiveに呼び出したかのごとく実行します。

  COMMAND : interactiveに呼び出す関数を指定します。
            (interactive ...)として宣言された関数でなければなりません。

使用例：
  ;;; find-fileを無引数で呼び出してもエラーになる。
  (find-file)
  => 引数が少なすぎます: (find-file)

  ;;; interactiveに呼び出すと大丈夫
  (call-interactively 'find-file)
  => Find file: C:/applications/xyzzy/
```

関連: `command-execute`

## `command-execute`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `command-execute COMMAND &optional HOOK`

```text
エディタのコマンドを実行します。
 
  COMMAND  : 文字列の場合，COMMAND をキーボードマクロとして実行します。
             シンボルの場合，COMMAND を interactive に実行します。
  HOOK     : COMMANDがシンボルの場合のみ使われます。
             HOOK には，2引数関数を指定し，第1引数はシンボル名，
             第2引数にはプレフィックスアーギュメントがある場合は 
             (list *prefix-value*) が，ない時は nil が入ります。
             コマンドを実行後，HOOKが実行されます。
             これ以上の詳細は不明です。

使用例：
  ;;; (command-execute "^X^F")と書いてfind-fileを実行してみます。
  (command-execute "^X^F")
 
  ;;; interactiveなコマンドを実行してみます。
  (command-execute 'next-line)

  ;;; interactiveでないコマンドを実行してみます。
  (command-execute 'goto-bol)
  =>不正なコマンドです: goto-bol

  ;;; HOOKを使ってみます。 
  (command-execute 'next-line #'(lambda (x y) (msgbox "~w\n~w" x y)))

  ;;; 各自，C-j や C-u C-j で上記のコマンドを実行してみください。
```

関連: `call-interactively`, `interactive`, `execute-extended-command`, `call-last-kbd-macro`, `*prefix-args*`

## `eval`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `eval FORM`

```text
FORM を評価します。
```

## `eval-buffer`

- Function / package: editor / 定義: lispmode.l
- 呼び出し: `eval-buffer BUFFER`

```text
バッファ全体を評価します。
eval-region を使って実装されています。
```

関連: `eval-region`

## `eval-expression`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `eval-expression X`

```text
lisp 式 X を評価します。[ESC ESC]
対話的に呼び出された場合はミニバッファで入力された式を評価します。
```

関連: `interactive`

## `eval-region`

- Function / package: editor / 定義: lispmode.l
- 呼び出し: `eval-region FROM TO &optional STREAM`

```text
リージョン内に書かれたLispコードを評価します。

使用例：
  (eval-region from to (selected-buffer))
```

関連: `eval-buffer`

## `eval-when`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `eval-when ({SITUATION}*) {FORM}*`

```text
ひとことで言うと、フォームをいつ評価するかってことです。

今回の例だと、define-dll-entry などのマクロはコンパイル時に展開
されなければならないのですが、define-dll-entry は foreign で定
義されているので、foreign がロードされていないとマクロであるこ
とが認識できません。(eval-when ...) がなく、単に (require 
"foreign") だけだと、コンパイル時には単なる関数コールだとみなさ
れてしまうため、マクロが展開されなくなってしまいます。そのため
に、eval-when でコンパイルするときも foreign をロードしろと指定
しているわけです。


          ソース                       ソース（左と同一）
            ↓  (eval)                   ↓  (compile)
      Lispインタープリタ           Lispコンパイラ
                                         ↓
                                        *.lc
                                         ↓   (load)
                                   Lispインタープリタ

C言語だと maxというのがマクロですよね。

#define max(a,b)   ((a>b)?a:b)

こんなん。

int foo(int x, int y)
{
   return max(x, y);
}
と書いたら、
int foo(int x, int y)
{
   return ((x> y) ? x : y);
}

こう書いたのと等価ですよね。
Ｃの入門書だとプリプロセッサがいったん展開してから、コンパイル
すると書かれていると思います。

lispだとこんなんになるんですが

----    test.l ---------

(defmacro macro-max (a b)
  `(if (> ,a ,b) ,a ,b))

(defun foo (x y)
  (macro-max x y))

------------------------

M-x byte-compile-fileってやったときに、
(defmacro macro-maxっていう文は、コンパイルするんでなくって
eval(インタープリタが評価する）しとかないといけない。

でないとfooのところで、コンパイル前にソースを展開できない。

だから eval-when (compile)なんです。
よくわからなかったら、３つ全部つけておけば大丈夫という説もある^^;

(eval-when (:compile-toplevel :load-toplevel :execute)

Common Lispの仕様書では、たしか eval, load, compile
だけ,だったと思います。

eval        --- インタープリタにロードするときeval
compile     --- compile時にeval
load        --- compileした*.lc をロードするときeval

(eval-when (:compile-toplevel :load-toplevel :execute)
って、今まで、xyzzyオリジナルかと思ってました。

でもallegloのhelpをみていたら、
(eval-when (:compile-toplevel :load-toplevel :execute)
ってありますね。^^;
知りませんでした。

| Common Lispの仕様書では、たしか eval, load, compile
| だけ,だったと思います。

CLtL1 ではそうだったんですが、CLtL2 で変わりました。
```

## `execute-extended-command`

- Function / package: editor / 定義: misc.l
- 呼び出し: `execute-extended-command COMMAND &optional RAW ARG`

```text
ミニバッファからコマンドを対話的に入力して実行します。[ESC x]
```

関連: `command-execute`, `repeat-complex-command`

## `funcall`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `funcall FN &rest ARGUMENTS`

```text
引数を指定して関数を表すシンボルから関数を呼び出します。
FNには関数を表すシンボルでも関数でも構いません。引数の個数が静的に定まら
ない場合にはfuncallは向いていないので、その場合にはapplyを使います。

使用例：
  ;;; carをいろいろな呼び出し方でする。
  (car '(a b c))                => a
  (funcall 'car '(a b c))       => a
  (funcall #'car '(a b c))      => a

注意：
  funcallやapply等の様に関数を引数とする標準の関数は、carがlambdaの式や
  シンボルを内部的に関数に変換します。従って、関数を表すシンボルでも関数
  そのものでも構いません。
```

関連: `apply`

## `interactive-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `interactive-p`

```text
実行中の関数が interactive に呼ばれていればt、そうでなければnilを返します。

使用例：
  ;;; fooとbarという関数を定義して、fooをinteractiveに呼び出してみる。
  ;;; fooはinteractive扱いされているが、barはそうでない。
  (defun foo () (interactive) (msgbox "foo: ~A" (interactive-p)) (bar))
  => foo
  (defun bar () (interactive) (msgbox "bar: ~A" (interactive-p)))
  => bar
  M-x: foo
  => [foo: t]
     [bar: nil]
```

関連: `commandp`, `interactive`

## `load-file`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `load-file FILENAME`

```text
ファイルを対話的に読み込みます。
load-library と異なり、*load-path* にないファイルも読み込めます。
```

関連: `load-library`, `load`, `mc-load-file`

## `load-library`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `load-library FILENAME &rest REST`

```text
ライブラリを対話的に読み込みます。
requireと異なり、一度読んでいてももう一度読み込みます。

内部的には、si:*load-libraryをinteractiveで宣言したものです。

| また、si:*load-library中で失敗したら、メッセージ等を出力して、処理を続けると
| いうのは可能でしょうか？

  (handler-case
      (si:*load-library "foo")
    (error (c) (si:*print-condition c)))
      (si:*load-library "bar")
```

関連: `si:*load-library`, `load-file`, `*load-path*`, `mc-load-library`, `各種ロード関係の関数の違い`

## `mc-autoload`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `mc-autoload FN FILE &optional COMMANDP MACROP ENCODING`

```text
Shift_JIS 以外のエンコーディングのファイルに定義された関数を autoload するよう設定します。

  FN       : 関数シンボル
  FILE     : 関数が定義されたファイル名
  COMMANDP : interactive 関数かどうか
  MACROP   : マクロかどうか
  ENCODING : FILE を読み込む際のエンコーディング
```

関連: `autoload`, `mc-load-library`, `mc-load-file`

## `mc-load-file`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `mc-load-file FILENAME &optional ENCODING`

```text
Shift_JIS 以外のエンコーディングのファイルを読み込みます。
mc-load-library と違い、*load-path* にないファイルも読み込めます。
  
  FILENAME : ファイル名（フルパス）
  ENCODING : 読み込むファイルのエンコーディング
```

関連: `load-file`, `mc-autoload`, `mc-load-library`

## `mc-load-library`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `mc-load-library FILENAME &key :encoding :no-suffix (:if-does-not-exist :error)`

```text
Shift_JIS 以外のエンコーディングのファイルを読み込みます。

  FILENAME           : ファイル名
  :encoding          : 読み込むファイルのエンコーディング
  :no-suffix         : ファイルを *load-path* から探すかどうか指定します。
        t                ファイルを find-load-path で探します。
        nil              FILENAME をそのまま使います。
  :if-does-not-exist : ファイルが見つからなかった場合の挙動を指定します。
        :error           エラーを返します。デフォルトの挙動です。
        それ以外         nil を返します。
```

関連: `load-library`, `mc-autoload`, `mc-load-file`

## `provide`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `provide MODULE-NAME`

```text
ある機能を持ったモジュールがロードされた事を示すためにファイルの先頭に書
いておく「おまじない」です。ここに書いたモジュール名が変数*modules*に登
録されます。

requireがモジュールのロードをする際にこの変数がチェックされてロード済だ
ったらもうロードしません。汎用的なモジュールを書く場合には使うようにしま
しょう。

互換性：
  Common Lispにはあり。
  muleにはなさそう。

使用例：
  ;;; lispmode.lより
  (provide "lispmode")
```

関連: `require`, `*modules*`

## `require`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `require MODULE-NAME &optional PATHNAME`

```text
指定したモジュールを読み込みます。既に読込済みであれば何もしません。

互換性：
  Common Lispにはあり。
  muleにはなさそう。

使用例：
  (require "foreign")
```

関連: `load-library`, `provide`, `*modules*`, `各種ロード関係の関数の違い`

## `si:*load-library`

- Function / package: system / 定義: builtin.l
- 呼び出し: `*load-library FILENAME &key :no-suffix :if-does-not-exist :no-message`

```text
ライブラリをロードします。普通は load-library でいいと思いますが、
どんなときにsi:*load-libraryを使うのでしょうか？

  :no-suffix         : non-nil なら指定されたファイル名をそのままロードする。
                       nil なら *load-path* を考慮する。
  :if-does-not-exist : :no-suffix が nil でファイルが存在しない場合、
                       :error ならエラー、それ以外なら nil を返す。
  :no-message        : non-nil ならロード中のメッセージを出さない。
```

関連: `*load-path*`, `load-library`
