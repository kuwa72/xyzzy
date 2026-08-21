# モード (modes)

reference/reference.xml から自動生成。28 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*auto-mode-alist*`

- Variable / package: editor / 定義: defs.l

```text
モード判定用の連想リストです。(key . datum)の組で登録します。
(string-matchp key filename)がnon-nilになった場合に、
datumをfuncallします。

datumにdecode-auto-modeのプロパティが存在する場合には、バッファを
第一引数にしてdatumをfuncallします。
cc-mode.lのdecode-c-modeを参照

使用例：
  (pushnew '("\\.asp" . basic-mode) *auto-mode-alist* :test 'equal)
```

関連: `*find-file-auto-mode-function*`, `*auto-mode-parameter-alist*`

## `*auto-mode-parameter-alist*`

- Variable / package: editor / 定義: files.l

```text
ファイルの先頭のパラメータに対し、実行する関数を指定する alist です。
書式は (文字列 . 関数) となっています。

ファイルの先頭にパラメータ -*- aaa: bbb -*- がある場合、
"aaa" に string-equal な文字列が *auto-mode-parameter-alist* に登録されていれば、
対応する関数を "bbb" を引数にして funcall します。

デフォルト値は
  '(("mode" . find-file-auto-mode)
    ("package" . find-file-buffer-package))
です。
```

関連: `*find-file-auto-mode-function*`, `*auto-mode-alist*`, `*buffer-package*`, `find-file`

## `*command-output-mode-hook*`

- Variable / package: editor / 定義: process.l

```text
execute-subprocessの中でcommand-output-mode起動時に実行されます。
```

## `*css-keyword-file*`

- Variable / package: editor / 定義: css-mode.l

```text
css-modeで利用するCSS Level 2のキーワードファイルを指定します。
*css-level*が2の場合に読み込まれます。
```

## `*css-level*`

- Variable / package: editor / 定義: css-mode.l

```text
css-modeで利用するCSS Levelを指定します。
デフォルトは 3 (CSS Level 3)です。

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `*css-mode-hook*`

- Variable / package: editor / 定義: css-mode.l

```text
css-mode起動時に実行されます。
```

## `*css3-keyword-files*`

- Variable / package: editor / 定義: css-mode.l

```text
css-modeで利用するCSS Level 3のキーワードファイルを指定します。
*css-level*が3の場合に読み込まれます。

CSS3用のキーワードファイルはCSSモジュールごとに分かれているので、
必要なモジュールのキーワードのみを読み込むことができます。

デフォルトはCSS Level 3の全モジュール、ブラウザごとの拡張、
HTML4/5 の要素をキーワードとして読み込みます。

  ;; css-modeで利用するキーワードの設定 (CSS Level 3)
  (setq *css3-keyword-files*
    '(;; CSS3 modules
      "CSS3/2d-transforms"
      "CSS3/3d-transforms"
      "CSS3/animations"
      "CSS3/backgrounds-and-borders"
      "CSS3/basic-box"
      "CSS3/basic-user-interface"
      "CSS3/behavioral-extensions"
      "CSS3/color"
      "CSS3/flexible-box-layout"
      "CSS3/fonts"
      "CSS3/generated-and-replaced-content"
      "CSS3/hyperlinks"
      "CSS3/layout"
      "CSS3/line"
      "CSS3/lists"
      "CSS3/marquee"
      "CSS3/multi-column"
      "CSS3/paged-media"
      "CSS3/presentation-levels"
      "CSS3/ruby"
      "CSS3/speech"
      "CSS3/tables"
      "CSS3/text"
      "CSS3/transitions"
      ;; vendor extensions
      "CSS3/microsoft-extensions"
      "CSS3/mozilla-extensions"
      "CSS3/webkit-extensions"
      ;; HTML elements
      "CSS3/html4-elements"
      "CSS3/html5-elements"
      ))

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `*diff-mode-hook*`

- Variable / package: editor / 定義: diff.l

```text
diff起動時に実行されます。
```

## `*find-file-auto-encoding-use-utf8n*`

- Variable / package: editor / 定義: files.l

```text
non-nilなら、ファイルの先頭のエンコーディング情報にUTF-8が記述(-*- Encoding: UTF-8 -*-)
されている場合にBOMなしのUTF-8(utf8n)としてファイルを開きます。

備考：
  xyzzy 0.2.2.241 から利用可能です。
```

関連: `*auto-encoding-alist*`, `*find-file-no-auto-encoding*`, `find-file`

## `*find-file-auto-mode-function*`

- Variable / package: editor / 定義: files.l

```text
find-file の際にモードを設定するための関数を登録します。

ファイルの先頭のパラメータ（-*- Mode: LISP -*- など）や 
*auto-mode-alist* よりも優先されます。
```

関連: `*auto-mode-parameter-alist*`, `*auto-mode-alist*`, `find-file`

## `*ime-mode-hook*`

- Variable / package: editor

```text
IMEの切替え時に呼び出されます。
```

関連: `toggle-ime`

## `*minor-mode-alist*`

- Variable / package: editor

```text
マイナモードがオンのときにモードラインに表示する文字列の連想リストです。
各要素の car はシンボル、 cdr は文字列かシンボルです。

car に指定したシンボルの値が non-nil であって、 cdr が文字列かまたは値が
文字列であるようなシンボルならば、その文字列がモードラインに表示されます。

使用例：
  (pushnew '(edict-mode . "Edict") *minor-mode-alist* :key #'car)

  (pushnew '(async-grep-mode . async-grep-status)
           *minor-mode-alist* :key #'car)
```

## `*tail-f-mode-hook*`

- Variable / package: editor / 定義: tail-f.l

```text
tail-f起動時に実行されます。
```

関連: `tail-f`

## `abbrev-mode`

- Function / package: editor / 定義: abbrev.l
- 呼び出し: `abbrev-mode &optional (ARG () SV)`

```text
abbrev-modeを開始します。

使用例：
  (abbrev-mode t)
```

関連: `quietly-read-abbrev-file`

## `add-hook`

- Function / package: editor / 定義: misc.l
- 呼び出し: `add-hook HOOK FN &optional APPEND`

```text
フック変数に関数を追加します。

  HOOK : フック変数のシンボルを指定します。
  FN   : 関数のシンボルを指定します。

フックとは特定の処理においてユーザが望む処理を追加するための仕組みです。
xyzzyには「ユーザが修正したいだろうなぁ」と思うところにフックが仕掛けら
れています。例えば「find-fileするときには何か関数を実行したい」と思った
ら、「find-fileを上書き」したり、「xxx-find-fileを作ったり」するのではな
く、その用途に使えるフック変数がないかどうかを確認しましょう。

下の例はfind-fileする時にfunc1とfunc2を呼び出して何らかの処理をする例です。

  【準備処理】
        ;;; find-fileで呼び出される*before-find-file-hook*に
        ;;; ユーザが作った関数func1とfunc2が呼び出されるように登録する。
        (add-hook '*before-find-file-hook* 'func1)
        (add-hook '*before-find-file-hook* 'func2)

  【find-file実行時】
        ;;; find-fileを実行すると、ファイルの読み込みの前で
        ;;; *before-find-file-hook*に登録されている関数が実行される。
        (find-file ...)
          └(run-hooks '*before-find-file-hook*)
              ├(func1)
              └(func2)

  【後片付け】
        ;;; find-fileで呼び出される*before-find-file-hook*から
        ;;; ユーザが作った関数func1とfunc2を取り除く
        (delete-hook '*before-find-file-hook* 'func1)
        (delete-hook '*before-find-file-hook* 'func2)

なお、フック変数は用途に応じて呼び出され方や戻す値の意味が異なります。注
意しましょう。

使用例：
  ;;; lispmode.l
  (add-hook '*query-kill-buffer-hook* 'kill-scratch-hook)
```

関連: `delete-hook`, `run-hooks`

## `delete-hook`

- Function / package: editor / 定義: misc.l
- 呼び出し: `delete-hook HOOK FN`

```text
フック変数から関数を削除します。

  HOOK : フック変数のシンボルを指定します。
  FN   : 関数のシンボルを指定します。
```

関連: `add-hook`

## `ed::toggle-mode`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `toggle-mode VAR ARG SV`

```text
マイナーモードの状態を表す変数VARを設定します。
SVがnilならば状態は反転します。
ARGが負数もしくはnilならば無効になります。
ARGが非負数値もしくはnon-nilならば有効になります。
```

## `minor-mode-map`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `minor-mode-map &optional BUFFER`

```text
set-minor-mode-mapで設定したキーマップを取得します。
```

関連: `set-minor-mode-map`

## `mode-specific-indent-command`

- BufferLocal / package: editor

```text
indent-regionを参照のこと

使用例：
  ;;; 適当なモードで以下をevalしてみると、
  ;;; "ラベル:" のような行は行頭からになり、それ以外の行は8桁目からになる。
  (progn
    (make-local-variable 'mode-specific-indent-command)
    (setq mode-specific-indent-command
        #'(lambda () (save-excursion
                       (goto-bol)
                       (delete-horizontal-spaces)
                       (or (looking-at "^\\w+:") (indent-to 8))))))
```

関連: `indent-region`

## `overwrite-mode`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `overwrite-mode &optional (ARG () SV)`

```text
上書き用マイナーモードを制御します。 toggle-over と同じです。
```

関連: `toggle-over`

## `quietly-read-abbrev-file`

- Function / package: editor / 定義: abbrev.l
- 呼び出し: `quietly-read-abbrev-file &optional FILE`

```text
Q.現在、モードを切り替えて且つ abbrev を有効にするには、
  ┌───────────────────────────────┐
  │M-x: sql-mode,                                                │
  │M-x: abbrev-mode                                              │
  │M-x: read-abbrev-file,                                        │
  │Read-abbrev-file: C:/xyzzy/.abbrev_defs                       │
  └───────────────────────────────┘
  のように４段階踏まなくてはなりません。最初の M-x: sql-mode の時か、
  ファンクションキーに割り当てて一度に行う方法はないもんでしょうか？

A.[xyzzy:02017]赤塚慶さん
  .xyzzy に
  ┌───────────────────────────────┐
  │; 起動時に abbrev file を読み込む                             │
  │(quietly-read-abbrev-file)                                    │
  └───────────────────────────────┘
  とかいておくと、  .abbrev_defs を呼んでくれます。

  [xyzzy:02020]亀井哲弥さん
  これに加えて、
  ┌───────────────────────────────┐
  │(add-hook 'ed::*sql-mode-hook* #'(lambda () (abbrev-mode t))) │
  └───────────────────────────────┘
  も書いておけば、M-x sql-mode だけでいけると思います(たぶん)。
```

関連: `abbrev-mode`

## `run-hook-with-args`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `run-hook-with-args HOOK &rest ARGS`

```text
run-hooksと同じように関数を実行します。run-hooksと異なり引数を
指定できます。
```

関連: `run-hooks`

## `run-hook-with-args-until-success`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `run-hook-with-args-until-success HOOK &rest ARGS`

```text
run-hooksと同じように関数を実行します。run-hooksと異なり戻り値
がnon-nilになるまで順番に実行します。
```

関連: `run-hook-with-args`, `run-hook-with-args-while-success`

## `run-hook-with-args-while-success`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `run-hook-with-args-while-success HOOK &rest ARGS`

```text
run-hooksと同じように関数を実行します。run-hooksと異なり戻り値
がnon-nilの間だけ順番に実行します。
```

関連: `run-hook-with-args`, `run-hook-with-args-until-success`

## `run-hooks`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `run-hooks &rest HOOKLIST`

```text
フック変数を順番に実行します。フック変数の詳細はadd-hookを参照して下さい。

  HOOKLIST : フック変数を指定します。複数個並べて書けます。
             並べて書いた順番に実行します。

フック変数の実行には引数をつけることが出来ません。
どうしてもつけたい場合には、run-hook-with-argsを使いましょう。

使用例：
  ;;; c-mode.l
  (run-hooks 'c-mode-hook)
```

関連: `run-hook-with-args`, `run-hook-with-args-until-success`, `run-hook-with-args-while-success`

## `set-minor-mode-map`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-minor-mode-map KEYMAP &optional BUFFER`

```text
マイナーモード用のキーマップを設定します。
```

関連: `unset-minor-mode-map`, `minor-mode-map`

## `toggle-over`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `toggle-over &optional (ARG () SV)`

```text
上書き用マイナーモードを制御します。 [Insert]

  nil以外  上書きモードにする
  nil      挿入モードにする
  省略時   モードをトグルする
```

関連: `overwrite-mode`

## `unset-minor-mode-map`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `unset-minor-mode-map KEYMAP &optional BUFFER`

```text
マイナーモード用のキーマップを解除します。
```

関連: `set-minor-mode-map`
