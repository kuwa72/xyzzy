# キーマップ (keymaps)

reference/reference.xml から自動生成。39 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*full-keymap-length*`

- Variable / package: editor / 定義: keymap.l

```text
make-keymap で作られるキーマップの長さです。
```

関連: `make-keymap`

## `*global-keymap*`

- Variable / package: editor

```text
グローバルなキーマップです。モード毎のキーマップに何も割り当てられてい
ない場合に使われます。

global-set-key はこのキーマップにバインディングをセットします。
```

関連: `global-set-key`

## `*kbd-translate-table*`

- Variable / package: editor / 定義: keyboard.l

```text
多分、入力された物理的なキーを論理的なキーに変換するためのものです。
この論理的なキーは、F13～F24などのように存在しないキーに振り向けることが
出来ます。例えば、キートップのラベルに別の文字のラベルを貼り付けるような
ものだと思います。

  ・物理的なキーから論理的なキーへの変換
  ・ローカルキーマップに論理的なキーの設定があればコマンド実行
  ・グローバルキーマップに論理的なキーの設定があればコマンド実行

使用例：
  ;;; C-[ と ESC を別物にする
  (setf (svref *kbd-translate-table* (char-code #\C-[)) #\F15)
  (global-set-key #\F15 'xxxx)

  ;;; BSとCtrl-hを別物にする
  (setf (svref *kbd-translate-table* (char-code #\C-h)) #\F13)
  (global-set-key #\F13 'replace-dialog)
```

関連: `キー表現使用可能文字`

## `BS と C-h に別々の機能を割り当てるには？`

- Tips

```text
| (global-set-key #\C-h 'replace-dialog) という設定を行うと、
| BS Key を押下した場合も、ダイアログが出てきます。

伝統的な仕様ですが、

  (setf (svref *kbd-translate-table* (char-code #\C-h)) #\F13)
  (global-set-key #\F13 'replace-dialog)

このようにすれば逃げられなくもないです。
```

関連: `global-set-key`

## `command-keys`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `command-keys COMMAND GLOBAL-KEYMAP LOCAL-KEYMAP &optional MINOR-MODE-KEYMAPS`

```text
指定した関数にバインドされたキーのリストを返します。
MINOR-MODE-KEYMAPS LOCAL-KEYMAP GLOBAL-KEYMAPの順に優先されます。

使用例:
  (command-keys 'undo *global-keymap* (local-keymap) (minor-mode-map))
  => (#\C-\\ #\End)
```

関連: `lookup-keymap`

## `copy-keymap`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `copy-keymap MAP`

```text
キーマップのコピーを返します。

使用例：
  ;;; gresreg.lより
  ;;; query-replaceのキーマップをコピーして
  ;;; query-gresregのキーマップを作って、ちょっと修正する。
  (unless *query-gresreg-map*
    (setq *query-gresreg-map* (copy-keymap *query-replace-map*))
    (define-key *query-gresreg-map* #\C-g '(throw . quit)))
```

## `ctl-x-4-map`

- Variable / package: editor / 定義: keymap.l

```text
C-x 4 に続くキーシーケンスのバインディングを格納するキーマップです。
```

関連: `ctl-x-4-prefix`

## `ctl-x-4-prefix`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `ctl-x-4-prefix`

```text
C-x 4 プレフィックスです。 [C-x 4]
デフォルトでは
  C-x 4 b      switch-to-buffer-other-window
  C-x 4 f      find-file-other-window
の二つが設定されています。

ctl-x-4-prefix の関数セルは普通のコマンドではなく ctl-x-4-map というキ
ーマップを保持しています。
```

関連: `ctl-x-4-map`

## `ctl-x-6-map`

- Variable / package: editor / 定義: pframe.l

```text
C-x 6 に続くキーシーケンスのバインディングを格納するキーマップです。
```

関連: `ctl-x-6-prefix`

## `ctl-x-6-prefix`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `ctl-x-6-prefix`

```text
C-x 6 プレフィックスです。 [C-x 6]
デフォルトではフレーム関係のコマンドが登録されています。

ctl-x-6-prefix の関数セルは普通のコマンドではなく ctl-x-6-map というキ
ーマップを保持しています。
```

関連: `ctl-x-6-map`

## `ctl-x-map`

- Variable / package: editor / 定義: keymap.l

```text
C-x に続くキーシーケンスのバインディングを格納するキーマップです。
```

関連: `ctl-x-prefix`

## `ctl-x-prefix`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `ctl-x-prefix`

```text
C-x プレフィックスです。 [C-x]

ctl-x-prefix の関数セルは普通のコマンドではなく ctl-x-map というキーマ
ップを保持しています。

参考:
  ;;; keymap.l
  (defvar ctl-x-map (make-keymap))
  (setf (symbol-function 'ctl-x-prefix) ctl-x-map)
```

関連: `ctl-x-map`

## `define-key`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `define-key KEYMAP KEY COMMAND`

```text
キーマップのキーにコマンドを割り当てます。

  KEYMAP  : キーマップ
  KEY     : 登録するキー
  COMMAND : 実行するコマンド

使用例：
  ;;; Ctrl-X fのキー割り当てを変える
  (define-key ctl-x-map #\f 'my-find-file)
  => t 
  ;;; Esc-f のキー割り当てを変える
  (define-key esc-map #\f 'my-find-file)
  => t
  ;;; Ctrl-C aのキー割り当てを変える
  (define-key spec-map #\a 'my-find-file)
  => t
```

関連: `undefine-key`, `global-set-key`, `local-set-key`, `substitute-key-definition`, `make-keymap`, `キー表現使用可能文字`, `各種言語キーマップ`

## `describe-bindings`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `describe-bindings`

```text
カレントバッファのキー割り当て一覧を表示します。
```

## `describe-key`

- Function / package: editor / 定義: help.l
- 呼び出し: `describe-key KEY`

```text
指定したキーにバインドされた関数と docstring を表示します。
```

関連: `describe-key-briefly`

## `describe-key-briefly`

- Function / package: editor / 定義: help.l
- 呼び出し: `describe-key-briefly KEY &optional ARG`

```text
指定したキーにバインドされた関数を表示します。[C-x ?]

  KEY : 検索するキー
  ARG : 出力(表示)先をどこにするか
        nil     : ステータスバーに表示
        non-nil : バッファに「キー (関数名)」のフォーマットで文字列を出力
```

関連: `describe-key`

## `esc-map`

- Variable / package: editor / 定義: keymap.l

```text
ESC に続くキーシーケンスのバインディングを格納するキーマップです。
```

関連: `meta-prefix`

## `get-ime-mode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-ime-mode`

```text
IMEのON/OFF状態を返します。

戻り値は以下の通りです
  t   変換モード
  nil 直接入力モード
```

関連: `toggle-ime`

## `global-set-key`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `global-set-key KEY COMMAND`

```text
グローバルなキーマップにキーを登録します。

使用例：
 (global-set-key #\C-r          'previous-page)
 (global-set-key #\S-Left       'selection-backward-char)
 (global-set-key #\S-C-Left     'selection-backward-word)
```

関連: `global-unset-key`, `define-key`, `local-set-key`, `undefined`, `*global-keymap*`, `キー表現使用可能文字`

## `global-unset-key`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `global-unset-key KEY`

```text
グローバルなキーマップのキーの割り当てを解除します。

使用例：
  ;;; global-set-keyで割り当てたキーを解除してみる。
  (global-set-key #\C-r 'previous-page)
  => t
  (global-unset-key #\C-r)
  => t
```

関連: `global-set-key`

## `key-to-string`

- Function / package: editor / 定義: help.l
- 呼び出し: `key-to-string KEY &optional ESC-TO-META`

```text
キーを読みやすいように文字列に変換します。

  ESC-TO-META : non-nilならESCをM-に変換します

使用例:
  (key-to-string '(#\ESC #\C-a))    => "ESC C-a"
  (key-to-string '(#\ESC #\C-a) t)  => "M-C-a"
```

## `local-keymap`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `local-keymap &optional BUFFER`

```text
バッファ BUFFER のローカルキーマップ (use-keymap で設定されたキーマッ
プ) を返します。

BUFFER が省略された場合はカレントバッファが対象になります。
```

関連: `use-kaymap`, `local-set-key`

## `local-set-key`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `local-set-key KEY COMMAND`

```text
カレントバッファのローカルキーマップにキーを登録します。
引数の意味は global-set-key と同じです。
```

関連: `local-unset-key`, `local-keymap`, `global-set-key`, `define-key`

## `local-unset-key`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `local-unset-key KEY`

```text
ローカルキーマップのキー割り当てを解除します。

使用例：
  ;;; lisp-modeのTABのローカルキーマップを外す。
  (lookup-key-command #\TAB)
  => lisp-indent-line
  (local-unset-key #\TAB)
  => t
  (lookup-key-command #\TAB)
  => self-insert-command
```

関連: `local-set-key`

## `lookup-key-command`

- Function / package: editor / 定義: help.l
- 呼び出し: `lookup-key-command KEY`

```text
指定したキーに設定された関数を返します。
lookup-keymapを使って実装されています。
```

関連: `lookup-keymap`

## `lookup-keymap`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `lookup-keymap KEYMAP KEY &optional IGNORE-CASE SYMBOL-ONLY`

```text
指定したキーマップの中で指定したキーにバインドされた関数を返します。
```

関連: `command-keys`, `lookup-key-command`

## `make-keymap`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-keymap`

```text
空のキーマップを作成します。
```

関連: `make-sparse-keymap`, `keymapp`, `use-keymap`, `define-key`, `lookup-keymap`

## `make-sparse-keymap`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-sparse-keymap`

```text
空のキーマップを作成します。
キー定義の数が少ない時に使うとメモリを節約できます。

使用例：
  ;;; lispmode.lより
  (unless *lisp-mode-map*
    (setq *lisp-mode-map* (make-sparse-keymap))
    (define-key *lisp-mode-map* #\C-M-x 'eval-defun)
    ...
    (define-key *lisp-mode-map* #\) 'lisp-electric-close))
```

関連: `make-keymap`

## `meta-prefix`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `meta-prefix`

```text
ESC プレフィックスです。 [ESC]

meta-prefix の関数セルは普通のコマンドではなく esc-map というキーマッ
プを保持しています。
```

関連: `esc-map`

## `set-extended-key-translate-table`

- Function / package: editor / 定義: keyboard.l
- 呼び出し: `set-extended-key-translate-table KEY C`

```text
通常は同時押しができないキーを別のキーに振り向けるテーブルです。

| c-modeでシフトを押しながらTABを押した時に
| インデントしてもらおうと思ったんですが、
| #\TABを#\S-TABにしたらSHIFTは使えませんとのことで。

残念ながらまともな手段では Shift+Tab は使えません。が、まともでない手
段が用意されています。

  (set-extended-key-translate-table exkey-S-tab #\F20)

このようにしておくと、Shift+Tab が押されたときに F20 が押されたふりをするので

  (global-set-key #\F20 'foo)

とすればお望み通り(^^

exkey-... に指定できるのは以下の通り。

  exkey-space
  exkey-S-space
  exkey-C-space
  exkey-S-C-space
  exkey-M-space
  exkey-S-M-space
  exkey-C-M-space
  exkey-S-C-M-space
                   
  exkey-backspace
  exkey-S-backspace
  exkey-C-backspace
  exkey-S-C-backspace
  exkey-M-backspace
  exkey-S-M-backspace
  exkey-C-M-backspace
  exkey-S-C-M-backspace
  
  exkey-tab
  exkey-S-tab
  exkey-C-tab
  exkey-S-C-tab
  
  exkey-return
  exkey-S-return
  exkey-C-return
  exkey-S-C-return
  exkey-M-return
  exkey-S-M-return
  exkey-C-M-return
  exkey-S-C-M-return
  
  exkey-escape
  exkey-S-escape

  exkey-zenkaku
  exkey-S-zenkaku
  exkey-C-zenkaku
  exkey-S-C-zenkaku
  exkey-S-M-zenkaku
```

## `set-function-bar-label`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-function-bar-label CHAR LABEL`

```text
ファンクションバーのラベルを変更します。

  CHAR  : 各ファンクファンクションバーに対応したキャラクタ
  LABEL : 表示するラベル

使用例
  (global-set-key #\F3 'search-forward-again)
  => t
  (set-function-bar-label #\F3 "次検索")
  => t
```

関連: `set-number-of-function-bar-labels`

## `spec-map`

- Variable / package: editor / 定義: keymap.l

```text
C-c に続くキーシーケンスのバインディングを格納するキーマップです。
```

関連: `specific-command-prefix`

## `specific-command-prefix`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `specific-command-prefix`

```text
C-c プレフィックスです。 [C-c]

specific-command-prefix の関数セルは普通のコマンドではなく spec-map と
いうキーマップを保持しています。
```

関連: `spec-map`

## `substitute-key-definition`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `substitute-key-definition OLDDEF NEWDEF &optional (KEYMAP *global-keymap*) (OKEYMAP KEYMAP)`

```text
OKEYMAP において OLDDEF が割り当てられているすべてのキーに対して、
KEYMAP において NEWDEF を割り当てます。

例：
  ;;; text-mode での行の移動を物理行単位にする
  (substitute-key-definition 'next-virtual-line 'next-line
                             *text-mode-map* *global-keymap*)
  (substitute-key-definition 'previous-virtual-line 'previous-line
                             *text-mode-map* *global-keymap*)
```

関連: `define-key`

## `toggle-ime`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `toggle-ime &optional ON-OR-OFF`

```text
IMEのON/OFFを制御します。
  non-nil  IMEをONにする
  nil      IMEをOFFにする
  省略時   IMEをトグルする
```

関連: `*ime-mode-hook*`, `get-ime-mode`

## `undefine-key`

- Function / package: editor / 定義: keymap.l
- 呼び出し: `undefine-key KEYMAP KEY`

```text
キーマップのキーの割り当てを解除します。

  KEYMAP : キーマップ
  KEY    : 削除するキー

使用例：
  ;;; C-lをfiler-reloadに割り当てて、解除してみる
  (define-key filer-keymap #\C-l 'filer-reload)
  => t
  (undefine-key filer-keymap #\C-l)
  => t
```

関連: `define-key`

## `use-keymap`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `use-keymap KEYMAP &optional BUFFER`

```text
バッファが使用するキーマップを設定します。

  KEYMAP : 使用するキーマップを指定します。
  BUFFER : バッファを指定します。省略時はカレントバッファに適用されます。

使用例：
  ;;; lispmode.lより
  (defun lisp-mode ()
    (interactive)
    (kill-all-local-variables)
    (setq buffer-mode 'lisp-mode)
    (setq mode-name "Lisp")
    (use-keymap *lisp-mode-map*)
    ...
    (run-hooks '*lisp-mode-hook*))
```

関連: `make-keymap`, `define-key`

## `キー表現使用可能文字`

- Tips

```text
#\aや#\C-bのように文字として表現します。ただし、\"'(),;`| の9文字は、
lispの構文上の特別な意味があるので、それを抑制するために'\'を前置します。

  #\a           ; a
  #\;           ; ;
  #\C-b         ; Ctrl+b
  #\C-\;        ; Ctrl+;
  #\M-\;        ; Alt+;
  #\C-M-\;      ; Ctrl+Alt+;

Ctrl、Alt、Shiftの同時押しも表現できます。C-、M-、S-の順番は何でも良いです。

  #\C-          ; Ctrl同時押し
  #\S-          ; Shift同時押し
  #\C-S-        ; Ctrl+Shift同時押し
  #\M-          ; Alt同時押し
  #\M-C-        ; Alt+Ctrl同時押し
  #\M-S-        ; Alt+Shift同時押し
  #\M-C-S-      ; Alt+Ctrl+Shift同時押し


キーによっては同時押しできるキーに制限があります。
例えばS-TABは普通のやり方ではできません。どうしてもやりたければ、
set-extended-key-translate-table を参照して下さい。

  ┌─────────────┬─────────────┐
  │キー                      │同時押しできるキー        │
  │                          ├─┬─┬─┬─┬─┬─┬─┤
  │                          │M │C │M │S │C │M │M │
  │                          │  │  │C │  │S │S │C │
  │                          │  │  │  │  │  │  │S │
  ├─────────────┼─┼─┼─┼─┼─┼─┼─┤
  │ !"#$%&'()*+,-./          │○│○│○│Ｘ│Ｘ│Ｘ│Ｘ│
  │0123456789:;<=>?          │  │  │  │  │  │  │  │
  │@ABCDEFGHIJKLMNO          │  │  │  │  │  │  │  │
  │PQRSTUVWXYZ[\]^_          │  │  │  │  │  │  │  │
  │`abcdefghijklmno          │  │  │  │  │  │  │  │
  │pqrstuvwxyz{|}~           │  │  │  │  │  │  │  │
  ├─────────────┼─┼─┼─┼─┼─┼─┼─┤
  │SPC       スペースキー    │○│○│Ｘ│Ｘ│Ｘ│Ｘ│Ｘ│
  ├─────────────┼─┼─┼─┼─┼─┼─┼─┤
  │TAB       Tabキー         │○│Ｘ│Ｘ│Ｘ│Ｘ│Ｘ│Ｘ│
  │LFD                       │  │  │  │  │  │  │  │
  │RET       Enterキー       │  │  │  │  │  │  │  │
  │ESC       Escキー         │  │  │  │  │  │  │  │
  │DEL                       │  │  │  │  │  │  │  │
  │NUL                       │  │  │  │  │  │  │  │
  ├─────────────┼─┼─┼─┼─┼─┼─┼─┤
  │PageUp    Page Upキー     │○│○│○│○│○│○│○│
  │PageDown  Page Downキー   │  │  │  │  │  │  │  │
  │End       Endキー         │  │  │  │  │  │  │  │
  │Home      Homeキー        │  │  │  │  │  │  │  │
  │Left      ←キー          │  │  │  │  │  │  │  │
  │Up        ↑キー          │  │  │  │  │  │  │  │
  │Right     →キー          │  │  │  │  │  │  │  │
  │Down      ↓キー          │  │  │  │  │  │  │  │
  │Pause     Pauseキー       │  │  │  │  │  │  │  │
  │Scroll    ScrollLockキー  │  │  │  │  │  │  │  │
  │Apps      Applicationキー │  │  │  │  │  │  │  │
  │Insert    Insertキー      │  │  │  │  │  │  │  │
  │Delete    Deleteキー      │  │  │  │  │  │  │  │
  │Help      どのキー?       │  │  │  │  │  │  │  │
  │F1～F24   F1～F24キー     │  │  │  │  │  │  │  │
  │LBtnDown  左ボタン押し    │  │  │  │  │  │  │  │
  │LBtnUp    左ボタン離し    │  │  │  │  │  │  │  │
  │LBtnMove  左ボタンドラッグ│  │  │  │  │  │  │  │
  │RBtnDown  右ボタン押し    │  │  │  │  │  │  │  │
  │RBtnUp    右ボタン離し    │  │  │  │  │  │  │  │
  │RBtnMove  右ボタンドラッグ│  │  │  │  │  │  │  │
  │MBtnDown  中ボタン押し    │  │  │  │  │  │  │  │
  │MBtnUp    中ボタン離し    │  │  │  │  │  │  │  │
  │MBtnMove  中ボタンドラッグ│  │  │  │  │  │  │  │
  │XBtn1Down                 │  │  │  │  │  │  │  │
  │XBtn1Up                   │  │  │  │  │  │  │  │
  │XBtn1Move                 │  │  │  │  │  │  │  │
  │XBtn2Down                 │  │  │  │  │  │  │  │
  │XBtn2Up                   │  │  │  │  │  │  │  │
  │XBtn2Move                 │  │  │  │  │  │  │  │
  │MouseMove                 │  │  │  │  │  │  │  │
  └─────────────┴─┴─┴─┴─┴─┴─┴─┘

例えば、#\RETと#\C-mは内部的には同じ文字と見なされます。このような文字は以下
のとおりです。

  (eq #\TAB #\C-i) => t
  (eq #\LFD #\C-j) => t
  (eq #\RET #\C-m) => t
  (eq #\ESC #\C-[) => t
  (eq #\DEL #\C-?) => t
  (eq #\NUL #\C-@) => t

xyzzy 0.2.2.236 からCommon Lispと同様の文字も利用可能です。
このような文字は以下のとおりです。

  (eq #\Backspace #\C-h) => t
  (eq #\Tab       #\TAB) => t
  (eq #\Newline   #\LFD) => t
  (eq #\Linefeed  #\LFD) => t
  (eq #\Page      #\C-l) => t
  (eq #\Return    #\RET) => t
  (eq #\Space     #\SPC) => t
  (eq #\Rubout    #\DEL) => t
```

関連: `global-set-key`, `define-key`, `*kbd-translate-table*`, `http://www.ai.mit.edu/projects/iiip/doc/CommonLISP/HyperSpec/Body/sec_13-1-7.html`

## `各種言語キーマップ`

- Tips

```text
プログラム言語毎（というか、モード毎）にキーマップを変更することができます。

  ;;; 言語用キーマップ一覧
  *basic-mode-map*              ; BASIC用
  *csharp-mode-map*             ; C#用
  *c-mode-map*                  ; C言語用
  *c++-mode-map*                ; C++用
  *css-mode-map*                ; CSS用
  *html-mode-map*               ; HTML用
  *idl-mode-map*                ; IDL用
  *java-mode-map*               ; java用
  *LaTeX-mode-map*              ; LaTeX用
  *lisp-mode-map*               ; lisp用
  *pascal-mode-map*             ; PASCAL用
  *perl-mode-map*               ; Perl用
  *sql-mode-map*                ; SQL用

  ;;; その他キーマップ一覧
  *box-drawings-mode-map*       ; 罫線描画モード用
  *buffer-menu-mode-map*        ; buffer-menu用
  *calc-mode-map*               ; calc用
  *calendar-mode-map*           ; calendar用
  *den8-view-mode-map*          ; 電信八号のメール表示用
  *den8-summary-mode-map*       ; 電信八号のメール一覧表示用
  *den8-draft-mode-map*         ; 電信八号の下書き用
  *diff-mode-map*               ; diff用
  *async-grep-mode-map*         ; 非同期grep用
  *lisp-interaction-mode-map*   ; *scratch*というかlisp-interaction-mode用
  *fundamental-mode-map*        ; モードが無いとき用
  *log-summary-mode-map*        ; niftyのログ一覧用
  *log-article-mode-map*        ; niftyのログ用
  *command-output-mode-map*     ; 外部コマンド実行時用
  *shell-mode-map*              ; shellモード用
  *tail-f-mode-map*             ; tail-f用
  *text-mode-map*               ; テキスト用
  *view-mode-map*               ; テキスト表示用

使用例：
  ;;; c++-modeでのキー割り当てを変える
  (define-key ed::*c++-mode-map* #\C-s 'foo)

  ;;; lisp-modeでのキー割り当てを変える
  (define-key ed::*lisp-mode-map*  #\TAB 'lisp-complete-symbol)

  ;;; Lispインタラクションモードでのキー割り当てを変える
  (define-key ed::*lisp-interaction-mode-map* #\TAB 'lisp-complete-symbol)
```

関連: `define-key`
