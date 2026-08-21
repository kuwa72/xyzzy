# 関数 (functions)

reference/reference.xml から自動生成。14 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `autoload`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `autoload FN FILE &optional COMMANDP MACROP`

```text
関数が呼び出された時点でファイルをロードするよう宣言します。

  FN       : 関数シンボルを指定します。
  FILE     : ロードするファイルを指定します。
  COMMANDP : 実行するときに interactive に実行するかどうかを指定します。
  MACROP   : マクロかどうかを指定します。

FN が既に関数として定義されている場合はなにもしません。
定義されていない場合は新たに関数を作って FN の一時的な定義とします。この
関数は初めて FN が呼ばれたときに実行され、指定されたファイル FILE から本
来呼び出されるべき FN の定義をロードします。もし FILE 中に FN の定義が存
在しなければエラーとなります。

関数を呼び出す側からは、元々そのファイルがロードされていたかのように実行
を続けます。めったに使わない関数を autoload で宣言しておくとメモリ消費
量を節約できます。また、起動時にファイルをロードしないので起動が速くなり
ます。

使用例：
  ;;; defs.lより
  (autoload 'search-dialog "dialogs" t)
  (autoload 'replace-dialog "dialogs" t)
  (autoload 'count-matches-dialog "dialogs" t)
  (autoload 'goto-line-dialog "dialogs" t)
  (autoload 'open-file-dialog "dialogs" t)
```

関連: `mc-autoload`, `autoload-function-p`, `各種ロード関係の関数の違い`

## `autoload-function-p`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `autoload-function-p DEF`

```text
指定された関数がautoloadされたか否かを返します。
  nil 指定された関数がautoload済み
      もしくはautoloadしない関数の場合
  t   指定された関数がautoload前の場合

使用例：
  (export 'lisp-info-F1)
  (autoload 'lisp-info-F1 "info-modoki" t)
  (autoload-function-p 'lisp-info-F1)
  => t
  (lisp-info-F1)
  (autoload-function-p 'lisp-info-F1)
  => nil
```

関連: `autoload`

## `beginning-of-defun`

- Function / package: editor / 定義: sexp.l
- 呼び出し: `beginning-of-defun &optional (ARG 1)`

```text
カーソルを関数定義の先頭に移動します。[ESC C-a]
```

関連: `end-of-defun`

## `commandp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `commandp OBJECT`

```text
関数が interactive 宣言されていれば tを返し、そうでなければnilを返します。
```

関連: `interactive`, `interactive-p`

## `defun`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `defun NAME (&rest LAMBDA-LIST) &body BODY`

```text
関数を定義します。NAME がすでに関数定義を持つ場合は上書きされます。
BODY の先頭に documentation 文字列や interactive 宣言を含めることができます。
```

関連: `lambda`

## `digit-argument`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `digit-argument RAW &optional ARG`

```text
後に続くコマンドに前置引数を渡します。[ESC 0 ... ESC 9]
```

関連: `universal-argument`, `negative-argument`

## `ed::build-summary-function`

- BufferLocal / package: editor

```text
バッファ中の関数の一覧を取得します。行及び関数名を要素に持つリス
トで得られます。list-functionで使用されています。

使用例：
  ; listfn.lで評価
  (funcall ed::build-summary-function)
  => ((10 "lisp-build-summary-of-functions") (39 "lisp-maketags"))
```

関連: `list-function`

## `end-of-defun`

- Function / package: editor / 定義: sexp.l
- 呼び出し: `end-of-defun &optional (ARG 1)`

```text
カーソルを関数定義の末尾に移動します。[ESC C-e]
```

関連: `beginning-of-defun`

## `flet`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `flet ({(NAME LAMBDA-LIST {declaration}* [doc-string] {FORM}*)}*) {FORM}*`

```text
ローカルな関数を定義してフォームを評価します。フォーム内で flet で
定義された関数は、外部で定義された同じ名前の関数よりも優先されます。
関数は同時に複数定義できます。

それぞれの定義方法は defun のように、最初に関数名、
次にパラメータのリスト(&optional, &rest, &key パラメータも使えます)、
そしてoptional declaration と docstring、そして最後にフォームと続きます。

  (flet ((safesqrt (x) (sqrt (abs x)))) 
    ;; The safesqrt function is used in two places. 
    (safesqrt (apply #'+ (map 'list #'safesqrt longlist))))
```

関連: `labels`, `macrolet`

## `interactive`

- Special Form / package: editor / 定義: builtin.l
- 呼び出し: `interactive {INTERACTIVE-STRING {PARAMETER}*|LIST}`

```text
関数が対話的に実行可能であること、すなわちコマンドであることを宣言します。
このフォームを定義に含む関数は対話的に実行できます。
対話的に実行とは具体的には
・キーバインドでの実行
・M-x (execute-extended-command) での実行
・ツールバーでの実行
などです。

実行に引数が必要でない関数では必要ありませんが、引数を与えなければならな
い関数の場合は、INTERACTIVE-STRINGによって対話的に実行したときに関数に渡
す引数の値やその与え方を制御する必要があります。
INTERACTIVE-STRINGの構成は以下のようになります。
  *             任意。書込み禁止バッファでの実行を禁止します。
  0             任意。プロンプトに数引数がつきます。
  指定子        引数に与えるデータとその与え方の指定になります。
  任意の文字列  ミニバッファで引数を与えるときのプロンプトになります。
  \n            区切り文字です。続けて次の引数についての記述ができます。

PARAMETERでは指定子に対する設定を記述できます。
 :defaultN      初期表示
 :historyN      履歴情報
 :titleN        ダイアログのタイトル
Nの部分には何番目の指定子に対する設定かという数値が入ります。
例えば最初の指定子に対する初期表示の指定は:default0で行います。
:defaultNと:titleNで指定するのは文字列、
:historyNで指定するのはminibuffer-history-variableプロパティを持つシンボルです。
履歴のデータはそのプロパティ値が使用されます。minibuf.l参照。

以下、指定子とその動作です。

  {属性}
   P: Prompt       ミニバッファでユーザー入力
   M: Must Match   正しく入力されるまで繰り返す
   C: Completion   入力候補表示・補完あり
   D: Default      :defaultN使用可能
   H: History      :historyN使用可能
   T: Title        :titleN使用可能

  [最終変換値]
  {xx}    - 関数には xxx 型の値がくる
  {xx/yy} - 入力値が省略又は未定義値だと、yy型がくる
  {xx|yy} - 入力値が多重値だと、yy の型でくる
  {*****} - なんでもあり

        {PMCDHT}
  a     {PMCDH }[symbol]        関数名
  B     {P CDH }[buffer/string] バッファ名
  b     {PMCDH }[buffer]        既存のバッファ名
  c     {P     }[character]     文字
  C     {PMCDH }[symbol]        コマンド名
  d     {      }[integer]       ポイント位置
  D     {PMCDHT}[string]        ディレクトリ名
  e     {P CDH }[string]        実行ファイル
  F     {P CDHT}[string]        ファイル名
  f     {PMCDHT}[string]        既存のファイル名
  l     {P CDHT}[string|cons]   ファイル名(複数可)
  M     {      }[integer]       セレクション開始位置
  m     {      }[integer]       マーク位置
  n     {PM    }[integer]       整数
  N     {PM    }[integer]       整数(前置引数を優先)
  p     {      }[integer]       前置引数の値
  P     {      }[symbol/nil]    生の前置引数
  R     {      }[integer]       セレクション範囲(一つ目がセレクションの始点、二つ目がセレクションの終点)
  r     {      }[integer]       リージョン(一つ目がマーク位置、二つ目がポイント位置)
  s     {P  DH }[string]        文字列
  S     {PMCDH }[symbol]        シンボル
  v     {PMCDH }[symbol]        変数名
  X     {P     }[*****]         S式(引数には評価した値が渡される)
  x     {P     }[*****]         S式そのもの
  z     {PMC H }[encoding]      文字エンコーディング
  Z     {PMC H }[encoding]      文字エンコーディング(自動判定を除く)
 
新たに任意の指定子を作成することもできます。
*interactive-specifier-alist*に指定子にあたる文字と処理の関数シンボルを
登録します。keymap.lを参照。

また、LISTにて指定子に依らない任意の動作をさせることもできます。
cmds.lのrepeat-complex-commandの定義などを参照。

備考:
・0zと0Zという指定は特別に、前置引数が与えられたときのみミニバッファで入
  力待ちになるという動作になります。
・PARAMETERで:emacsにnon-nilを指定するとemacsとの互換性を考慮した動作に
  なります。
```

関連: `commandp`, `long-operation`, `*prefix-args*`, `read-buffer-name`, `read-char-encoding`, `read-command-name`, `read-directory-name`, `read-exist-buffer-name`, `read-exist-file-name`, `read-file-name-list`, `read-file-name`, `read-function-name`, `read-integer`, `read-sexp`, `read-string`, `read-symbol-name`, `read-variable-name`

## `list-function`

- Function / package: editor / 定義: listfn.l
- 呼び出し: `list-function &rest ARGS`

```text
バッファ中の関数の一覧をダイアログで表示します。選択することで定
義位置にジャンプすることが可能です。バッファ中の関数の一覧は、バ
ッファローカル変数build-summary-functionから取得しています。
```

関連: `ed::build-summary-function`

## `mark-sexp`

- Function / package: editor / 定義: sexp.l
- 呼び出し: `mark-sexp &optional (ARG 1)`

```text
前方のS式の末尾にマークを設定します。[ESC NUL]
```

関連: `set-mark-command`

## `negative-argument`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `negative-argument RAW &optional ARG`

```text
後に続くコマンドに負の前置引数を渡します。[ESC -]
```

関連: `universal-argument`, `digit-argument`

## `universal-argument`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `universal-argument RAW &optional ARG`

```text
後に続くコマンドに前置引数として 'universal-argument を渡します。[C-u]

'universal-agument を数値として処理する場合は 4 と解釈されます。
```

関連: `digit-argument`, `negative-argument`, `*prefix-args*`, `*prefix-value*`
