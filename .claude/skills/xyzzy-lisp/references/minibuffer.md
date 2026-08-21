# ミニバッファ (minibuffer)

reference/reference.xml から自動生成。28 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*enter-minibuffer-hook*`

- Variable / package: editor

```text
ミニバッファに入ったときに実行されます。(interactive...)で指定さ
れた引数が渡されます。
```

## `*exit-minibuffer-hook*`

- Variable / package: editor

```text
ミニバッファから出たときに実行されます。
```

## `*minibuffer-popup-completion-list*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファで補完リストをポップアップ表示するかを設定します。

使用例：
  (setq *popup-completion-list-default* :always)
  (setq *minibuffer-popup-completion-list* :never)

動作：
  *minibuffer-popup-completion-list*
    :always   ポップアップ表示
    :never    *Completion*バッファで表示
  
    *popup-completion-list-default*
      :always ポップアップ表示
      :never  *Completion*バッファで表示
  
    non-nil   ポップアップ表示
    nil       *Completion*バッファで表示
```

関連: `*popup-completion-list-default*`

## `*minibuffer-save-ime-status*`

- Variable / package: editor

```text
ミニバッファのIMEの状態を制御します。
  nil  ミニバッファのIMEの状態を保存しません。
  t    ミニバッファのIMEの状態を保存します。
```

## `clear-minibuffer-message`

- Function / package: editor / 定義: misc.l
- 呼び出し: `clear-minibuffer-message`

```text
ミニバッファに表示された文字列を消去します。
```

関連: `minibuffer-message`, `minibuffer-prompt`

## `completing-read`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `completing-read PROMPT COMPLETIONS &key :case-fold :default :history :must-match`

```text
ミニバッファにプロンプトを表示してユーザーの入力を読み取ります。

  PROMPT      : 表示するプロンプト
  COMPLETIONS : 補完入力のためのリスト
  :case-fold  : non nilなら大文字小文字を区別しない
  :default    : 初期値の指定
  :history    : 履歴情報
                minibuffer-history-variableプロパティを持つシンボルを指定します
  :must-match : non nilならCOMPLETIONS以外受け付けない
```

関連: `read-string`, `interactive`

## `ignored-extensions`

- Variable / package: editor / 定義: defs.l

```text
ミニバッファでの入力補完において、ignored-extensionsの拡張子がついたファ
イルは補完の対象になりません。

使用例：
  ; exeとdllは入力補完しない
  (setq ignored-extensions '("exe" "dll"))
```

## `minibuffer-message`

- Function / package: editor / 定義: misc.l
- 呼び出し: `minibuffer-message FMT &rest ARGS`

```text
書式に従ってミニバッファにメッセージを表示します。 
ミニバッファにカーソルが表示されない以外は minibuffer-prompt と同じ？

  FMT  : format 同様の書式
  ARGS : 出力書式へのパラメタ
```

関連: `clear-minibuffer-message`, `minibuffer-prompt`, `format`

## `minibuffer-prompt`

- Function / package: editor / 定義: misc.l
- 呼び出し: `minibuffer-prompt FMT &rest ARGS`

```text
書式に従ってミニバッファにメッセージを表示します。
その後read-charを使ってキーボードから文字を読み込めば、
凝ったミニバッファからの入力が可能になります。

  FMT  : format同様の書式が指定できます。
  ARGS : 出力書式へのパラメタとなります。

使用例：
  ;;; 以下のようにすると、パスワード入力のようにエコーバックしない。
  minibuffer入力が可能
  (defun test1 ()
    (interactive)
    (let ((ans ""))
      (loop
        (minibuffer-prompt "From ~d: " 12)
        (let ((c (read-char *keyboard*)))
          (case c
            (#\RET (return ans))
            (#\C-g (quit))
            (t (setq ans (format nil "~a~c" ans c))))))))  

参考：
  wip/ftp.lのgetpass
```

## `minibuffer-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `minibuffer-window`

```text
ミニバッファのウインドウを取得します。

使用例：
  ;;; ミニバッファに移動する。
  (set-window (minibuffer-window))
```

## `minibuffer-window-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `minibuffer-window-p WINDOW`

```text
ウィンドウがミニバッファかどうかを返します。

  WINDOW：ミニバッファかどうかを調べるウィンドウ 

  t     ミニバッファである
  nil   ミニバッファではない

使用例：
  ;;; ミニバッファでは別のバッファに変更できないので別のウィンドウに移動する。
  (if (minibuffer-window-p (selected-window))
      (other-window))
  => t
```

## `read-buffer-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-buffer-name PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーがバッファ名を入力するのを待ち
ます。ユーザーの入力したバッファを返します。入力したバッファが存在しない
場合は、文字列をそのまま返します。
(interactive "B") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します

使用例:
  ;;; ミニバッファからバッファ名を読み込む
  (read-buffer-name "Buffer: ")   ; ←*scratch* と入力
  =>#<buffer: *scratch*>
```

関連: `interactive`

## `read-char-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-char-encoding PROMPT &key :history`

```text
ミニバッファにプロンプトを表示してユーザーが文字エンコーディングを入力す
るのを待ちます。ユーザーの入力した文字エンコーディングを返します。補完の
リストは *char-encoding-list* を参照しているようです。
(interactive "z") に相当します。

  PROMPT     : プロンプト
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します

使用例:
  ;;; ミニバッファから文字エンコーディングを読み込む
  (read-char-encoding "Encoding: ") ; ←utf8n と入力
  =>#.(make-utf8-encoding "utf8n" "Unicode (UTF-8N)" :signature nil :windows t :byte-order nil :cjk :jp)
```

関連: `read-exact-char-encoding`, `*char-encoding-list*`, `interactive`

## `read-command-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-command-name PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーがコマンドを入力するのを待ちま
す。ユーザーの入力したコマンドのシンボルを返します。
(「コマンド」は「interactive宣言された関数」の意味で使ってます)
(interactive "C") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `interactive`

## `read-directory-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-directory-name PROMPT &key :default :title :history`

```text
ミニバッファにプロンプトを表示してユーザーがディレクトリ名を入力するのを
待ちます。入力中は TAB キーでディレクトリ名を補完できます。 "~" はユーザ
ーのホームディレクトリに、 ".." は親ディレクトリに変換されます。ユーザー
の入力したディレクトリ名を返します。
(interactive "D") に相当します。

  PROMPT     : プロンプト
  :default   : 初期表示するディレクトリ名
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します

使用例：
  ;;; ミニバッファからディレクトリ名を読み取る。
  (read-directory-name "directory: ")
  => "C:/applications/xyzzy/etc"
```

関連: `interactive`

## `read-exact-char-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-exact-char-encoding PROMPT &key :history`

```text
read-char-encodingとほぼ同じですが、自動判定が候補から除外されます。
(interactive "Z") に相当します。
```

関連: `read-char-encoding`

## `read-exist-buffer-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-exist-buffer-name PROMPT &key :default :history`

```text
read-buffer-name とほとんど同じですが、 read-exist-buffer-name はすでに
存在するバッファ名しか指定できません。
(interactive "b") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `read-buffer-name`, `interactive`

## `read-exist-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-exist-file-name PROMPT &key :default :title :history`

```text
read-file-name とほとんど同じですが、 read-exist-file-name はすでに存在
しているファイルしか指定できません。
(interactive "f") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :title     : 一画面ファイラのタイトル
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `read-file-name`, `interactive`

## `read-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-file-name PROMPT &key :default :title :history`

```text
ミニバッファにプロンプトを表示してユーザーがファイル名を入力するのを待ち
ます。入力中は TAB キーでファイル名を補完できます。 "~" はユーザーのホー
ムディレクトリに、 ".." は親ディレクトリに変換されます。ユーザーの入力し
たファイル名を返します。
(interactive "F") に相当します。

  PROMPT     : プロンプト
  :default   : 初期表示するファイル名
  :title     : 一画面ファイラのタイトル
  :history   : 履歴情報
               minibuffer-history-variable プロパティを持つシンボルを指定します

使用例：
  ;;; ミニバッファからファイル名を読み取る。
  (read-file-name "filename: ")
  => "C:/applications/xyzzy/xyzzy.exe"
```

関連: `read-exist-file-name`, `read-file-name-list`, `interactive`

## `read-file-name-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-file-name-list PROMPT &key :default :title :history`

```text
read-file-name とほとんど同じですが、 read-file-name-list は複数のファイ
ルを指定できます。複数のファイルを指定した場合は、そのリストを返します。
(interactive "l") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :title     : 一画面ファイラのタイトル
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `read-file-name`, `interactive`

## `read-function-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-function-name PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーが関数名を入力するのを待ちます。
ユーザーの入力した関数のシンボルを返します。
(interactive "a") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `interactive`

## `read-integer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-integer PROMPT`

```text
ミニバッファにプロンプトを表示してユーザーが整数を入力するを待ちます。
ユーザーの入力した整数を返します。
(interactive "n") に相当します。

  PROMPT     : プロンプト

使用例：
  ;;; ミニバッファから数値を読み取る。
  (read-integer "num: ")
  => 123
```

関連: `interactive`

## `read-sexp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-sexp PROMPT`

```text
ミニバッファにプロンプトを表示してユーザーがS式を入力するのを待ちます。
ユーザーの入力したS式と文字数を多値で返します。
(interactive "x") に相当します。

  PROMPT     : プロンプト

使用例：
  ;;; ミニバッファからS式を入力する。
  (read-sexp "sexp: ")
  => (+ 3 3)
  => 7
```

関連: `interactive`

## `read-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-string PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーが文字列を入力するのを待ちます。
ユーザーの入力した文字列を返します。
(interactive "s") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します

使用例：
  ;;; ミニバッファからURLを入力する。
  (read-string "URL: ")
  => "http://www.yahoo.co.jp"
```

関連: `completing-read`, `interactive`

## `read-symbol-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-symbol-name PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーがシンボルを入力するのを待ちます。
ユーザーの入力したシンボルを返します。
(interactive "S") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `interactive`

## `read-variable-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-variable-name PROMPT &key :default :history`

```text
ミニバッファにプロンプトを表示してユーザーが変数を入力するのを待ちます。
ユーザーの入力した変数のシンボルを返します。
(interactive "v") に相当します。

  PROMPT     : プロンプト
  :default   : 初期値とする文字列
  :history   : 履歴情報
               minibuffer-history-variableプロパティを持つシンボルを指定します
```

関連: `interactive`

## `repeat-complex-command`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `repeat-complex-command SEXP`

```text
execute-extended-command（いわゆるM-x）でのコマンド実行をそのままの引数
で再度実行します。[ESC p]
```

関連: `execute-extended-command`

## `y-or-n-p`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `y-or-n-p FMT &rest ARGS`

```text
ミニバッファにメッセージを表示してユーザーが'y'か'n'を入力するのを待ちます。

  t     'y'を押下した
  nil   'n'を押下した

使用例：
  ;;; "Foo: (y or n) "と表示して選択させる。
  (y-or-n-p "Foo: ")
  => t          ; 'y'を押下
```

関連: `yes-or-no-p`, `no-or-yes-p`, `yes-no-or-cancel-p`
