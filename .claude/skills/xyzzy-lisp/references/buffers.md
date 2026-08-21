# バッファ (buffers)

reference/reference.xml から自動生成。115 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*buffer-bar-context-menu*`

- Variable / package: editor / 定義: buffer.l

```text
バッファ・バー上で右クリックしたときに出てくるコンテキストメニューです。
define-popup-menu で作成されています。（作成は app-menu.l）
```

## `*buffer-bar-context-menu-buffer*`

- Variable / package: editor / 定義: buffer.l

```text
バッファバー上で選択されているバッファです。ただし、バッファバー上の
コンテキストメニューで取得専用くらいしか使用できません。
```

## `*buffer-bar-context-menu-handler*`

- Variable / package: editor / 定義: buffer.l

```text
デフォルトのバッファバー用コンテキストメニューハンドラです。
setq-default によって定義されている標準の動作は、 
*buffer-bar-context-menu-buffer* を定義し、*buffer-bar-context-menu* を
返します。
```

関連: `*buffer-bar-context-menu*`

## `*buffer-bar-selected-buffer-to-first*`

- Variable / package: editor

```text
non-nil なら、選択されたバッファがバッファバー上で一番先頭になります。
キーでタブを移動した場合は移動されません。デフォルトは nil です。
(setq *buffer-bar-selected-buffer-to-first* t) とやって、バッファバーを
クリックすれば分かると思います。
```

## `*buffer-info-variable-list*`

- Variable / package: editor / 定義: session.l

```text
セッションファイルに保存しておくバッファローカル変数のリストです。

このリストに含まれる変数のバッファごとの値はセッションファイルに保存さ
れ、ロードした際に復元されます。(正確には、バッファローカルになってい
る場合だけそのバッファの情報として保存されます)
```

関連: `save-session`

## `*buffer-package*`

- BufferLocal / package: editor / 定義: lispmode.l

```text
ファイルの先頭のパラメータリストの Package で指定したパッケージ名が保
存されます。
```

関連: `*auto-mode-parameter-alist*`

## `*dabbrevs-no-undo*`

- Variable / package: editor / 定義: defs.l

```text
dabbrev-expand時のundoの方法を設定します。
dabbrev-expandを行なった際に候補が順次挿入されますが...
  non-nil  dabbrev-expandの直前まで一気に取り消す
  nil      途中の挿入過程を順番に取り消す
```

関連: `undo`, `dabbrev-expand`

## `*default-buffer-mode*`

- Variable / package: editor / 定義: defs.l

```text
新しくバッファを作成した場合のモードを指定します。
例えば、lisp-modeを指定しておけば、新しく作成したバッファは全てlisp-mode
になります。

使用例：  
  (setq *default-buffer-mode* 'lisp-mode)
  => lisp-mode
  (switch-to-buffer "*new*")
  => #<buffer: *new*>
  buffer-mode
  => lisp-mode
```

## `*default-eol-code*`

- Variable / package: editor

```text
新規に作ったバッファの改行コードのデフォルト値です。
```

関連: `buffer-eol-code`, `*default-fileio-encoding*`

## `*default-fileio-encoding*`

- Variable / package: editor

```text
新規に作ったバッファの文字エンコーディングのデフォルト値です。
```

関連: `buffer-fileio-encoding`, `*default-eol-code*`

## `*default-session-directory*`

- Variable / package: editor / 定義: session.l

```text
セッションファイルの保存・ロードの際にファイル名を読むときにデフォルト
で表示されるディレクトリです。
```

関連: `load-session`, `save-session`, `ed::session-directory`

## `*move-forward-after-undo-deletion*`

- Variable / package: editor

```text
削除をundoした場合のカーソルの位置を制御します。
  non-nil  削除範囲の最後尾
  nil      削除範囲の先頭
```

関連: `undo`

## `*next-buffer-in-tab-order*`

- Variable / package: editor / 定義: buffer.l

```text
next-bufferで次に移動するバッファを、タブでの順番どおりにするか否かを設
定します。もちろんprevious-bufferにも影響します。
  t    バッファバーでの次のバッファに移動する。
  nil  どうなるでしょうか？
```

## `*show-cursor-line-always*`

- Variable / package: editor

```text
カレントでないウィンドウでもカーソルラインを表示します。

使用例：
  (setq *show-cursor-line-always* t)
```

関連: `toggle-cursor-line`, `inverse-cursor-line`

## `*show-matched-parenthesis*`

- Variable / package: editor / 定義: cmds.l

```text
対応する括弧の表示を制御します。括弧に使用する文字は
set-syntax-match で指定します。
  non-nil  対応する括弧を表示する
  nil      対応する括弧を表示しない
```

関連: `set-syntax-match`

## `backup-by-copying`

- BufferLocal / package: editor

```text
ファイル保存時のバックアップファイルの作成方法を指定する変数です。

  nil     : 元のファイルをリネームしてバックアップファイルを作成してから、
            バッファを新しいファイルとして保存します。
            元のファイルのハードリンクはバックアップファイルを指すため
            ハードリンクは切れます。
            デフォルトは nil です。
  t       : 元のファイルをコピーしてバックアップファイルを作成してから、
            バッファをファイルに保存します。元のファイルのハードリンクは
            切れません。
  :remote : ファイルがリモートにある場合のみ元のファイルをコピーして
            バックアップファイルを作成します。

使用例：
  ;;; ファイル保存時にハードリンクが切れないように
  ;;; 常にコピーしてバックアップファイルを作成
  (setq backup-by-copying t)
  => t
```

関連: `file-precious-flag`, `[xyzzy:05968]`

## `backward-sexp`

- Function / package: editor / 定義: sexp.l
- 呼び出し: `backward-sexp &optional (ARG 1) NOERROR`

```text
lisp-modeでS式を1つ戻します。[ESC C-b]

使用例：
  (backward-sexp)
```

関連: `forward-sexp`, `down-list`

## `buffer-can-redo-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-can-redo-p BUFFER`

```text
バッファがredo可能な状態ならt、そうでなければnilを返します。
```

関連: `redo`

## `buffer-can-undo-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-can-undo-p BUFFER`

```text
bufferがundo可能ならt、そうでなければnilを返します。
```

関連: `undo`

## `buffer-eol-code`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-eol-code &optional BUFFER`

```text
バッファの改行コードを返します。変更する場合はset-buffer-eol-codeを使用
します。

 BUFFER: 改行コードを返すバッファ
         指定が無ければ現在のバッファ

戻り値:
  0  *eol-lf*   LF
  1  *eol-cr*   CR
  2  *eol-crlf* CRLF
```

関連: `set-buffer-eol-code`, `*default-eol-code*`

## `buffer-fileio-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-fileio-encoding &optional BUFFER`

```text
バッファの文字エンコーディングを返します。変更する場合には、
set-buffer-fileio-encodingを使用します。

使用例：
  (buffer-fileio-encoding)
  => #.(make-iso2022-encoding "jis" ... )

参照：
  kanji.l
```

関連: `set-buffer-fileio-encoding`, `*default-fileio-encoding*`

## `buffer-lines`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-lines &optional BUFFER`

```text
バッファの物理行数を返します。

使用例：  
  (buffer-lines)
  => 5014
```

## `buffer-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-list &key :buffer-bar-order`

```text
全バッファをリストで返します。

使用例:
  (buffer-list)
  =>(#<buffer:  *Minibuf0*> #<buffer: *grep*> #<buffer: *scratch*> #<buffer: *untitled*> #<buffer: addref.xml> #<buffer: reference.xml>)
  
  (buffer-list :buffer-bar-order t)
  =>(#<buffer: *scratch*> #<buffer: reference.xml> #<buffer: *untitled*> #<buffer: addref.xml> #<buffer: *grep*> #<buffer:  *Minibuf0*>)
  
  ;;ミニバッファの名前はスペースで始まる点に注意
  (mapcar #'buffer-name (buffer-list))
  =>(" *Minibuf0*" "*grep*" "*scratch*" "*untitled*" "addref.xml" "reference.xml")
```

関連: `enum-buffers`

## `buffer-local-value`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-local-value BUFFER SYMBOL`

```text
指定されたバッファのローカル変数の値を返します。

  BUFFER : ローカルな値を取得したいバッファ
  SYMBOL : ローカル変数

使用例：
  (buffer-local-value (selected-buffer) 'mode-name)
  => "xmldoc"
```

関連: `symbol-value`, `make-local-variable`, `defvar-local`

## `buffer-menu`

- Function / package: editor / 定義: buf-menu.l
- 呼び出し: `buffer-menu`

```text
バッファ一覧を表示します。
一覧の中ではバッファの選択、削除などができます。
```

## `buffer-mode`

- BufferLocal / package: editor

```text
カレントバッファのモードを格納しています。

使用例：
  ;;; list-interaction-modeの場合
  buffer-mode
  => lisp-interaction-mode
```

関連: `mode-name`

## `buffer-modified-count`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-modified-count &optional BUFFER`

```text
（バッファが修正されたカウント数？）
```

関連: `buffer-modified-p`

## `buffer-modified-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-modified-p &optional BUFFER`

```text
バッファ BUFFER が変更を加えられているかどうかを返します。
バッファが変更されていない時は nil を、変更されている時はバッファの編集
回数(buffer-modified-count の値)を返します。
BUFFER が指定されない、もしくは nil が指定された時はカレントバッファの結
果を返します。
```

関連: `set-buffer-modified-p`, `buffer-modified-count`

## `buffer-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-name BUFFER`

```text
バッファの名前を返します。

  BUFFER : 名前を返すバッファを指定します。

使用例：
  ;;; カレントバッファの名前を返します。
  (buffer-name (selected-buffer))
  => "reference.xml"
```

関連: `create-new-buffer`, `get-buffer-create`, `rename-buffer`, `find-name-buffer`

## `buffer-process`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-process BUFFER`

```text
バッファに結び付けられているプロセスを返します。
プロセスはmake-processで作成します。
```

関連: `make-process`

## `buffer-selector`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-selector`

```text
バッファ選択ウィンドウを表示します。
バッファ選択されればそのバッファを、そうでなければnilを返します。
```

関連: `select-buffer`

## `buffer-size`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-size &optional BUFFER`

```text
バッファのサイズを返します。2バイト文字があるので buffer-size の返す値と
ファイルサイズは一致しません。

使用例：
  (buffer-size)
  => 200170
```

## `bufferp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `bufferp OBJECT`

```text
OBJECTがバッファならばt、そうでないならnilを返します。
```

## `bury-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `bury-buffer &optional BUFFER`

```text
other-bufferの候補の最後にします。
```

関連: `other-buffer`

## `clear-undo-boundary`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `clear-undo-boundary &optional BUFFER`

```text
UNDO情報から直近の境界を削除します。

使用例：
  (defun self-insert-space (&optional (arg 1))
    (interactive "*")
    (when (eq *last-command* 'self-insert-space)
      (clear-undo-boundary))
    (self-insert-command arg))
  (define-key ed::*lisp-mode-map* #\SPC 'self-insert-space)
```

関連: `undo`, `undo-boundary`, `kept-undo-information`

## `close-session`

- Function / package: editor / 定義: session.l
- 呼び出し: `close-session &optional NOASK (CREATE-NEW t) (FN #'write-file)`

```text
すべてのフレームと *scratch* を除くすべてのバッファを削除します。
保存していないバッファがあれば保存します。 [C-x 6 k]

ed::*auto-save-session-file* が non-nil であり、現在セッションを開いて
いるならば同時にセッションファイルを上書きします。

  NOASK      : nil の場合ファイルごとに保存するかどうか確認
  CREATE-NEW : non-nil であれば最後に新しいフレームをひとつ作る
  FN         : ファイルの保存に使われる関数
```

関連: `ed::auto-save-session-file`

## `close-session-dialog`

- Function / package: editor / 定義: session.l
- 呼び出し: `close-session-dialog &optional NOASK`

```text
close-session とほぼ同じですが、変更されたバッファを保存する際に
ダイアログを表示して保存先を指定します。 [C-x 6 K]

  NOASK      : nil の場合ファイルごとに保存するかどうか確認
```

関連: `close-session`

## `count-buffers`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `count-buffers &optional ALL`

```text
全バッファの数を返します。

  ALL : " *Completion*"や" *Minibuf0*"等の先頭が空白のバッファも数えるか？
        t       先頭が空白のバッファも数える。
        nil     先頭が空白のバッファは数えない。

使用例：
  ;;; バッファの数を数えてみる。
  (count-buffers)
  => 20
  (count-buffers t)
  => 23
```

関連: `count-modified-buffers`

## `create-file-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-file-buffer FILENAME`

```text
ファイルを参照するバッファを作成して返します。
```

関連: `get-file-buffer`, `create-new-buffer`

## `create-new-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-new-buffer NAME`

```text
名前がNAMEのバッファを作成して返します。もしその名前のバッファが存在すれ
ば、name<1>, name<2>...と番号を付けた名前になります。

使用例：
  (create-new-buffer "test")
  => #<buffer: test>
  (create-new-buffer "test")
  => #<buffer: test<2>>
```

関連: `create-file-buffer`, `get-buffer-create`, `*create-buffer-hook*`, `find-buffer`, `バッファの内部構造`

## `delete-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-buffer BUFFER`

```text
バッファを削除しますが、kill-bufferと違い対話的に削除するかどうかは聞き
ません。kill-bufferも内部的にはdelete-bufferを使っています。

delete-bufferでは以下の二つのフックが順番に実行されます。

  *before-delete-buffer-hook*
        delete-bufferを継続するかどうかを制御します。登録された関数が一
        つでもnilを返すとdelete-bufferを中止します。

  *delete-buffer-hook*
        delete-bufferされるバッファで何か処理を行う場合に使用します。
```

関連: `*before-delete-buffer-hook*`, `*delete-buffer-hook*`, `kill-buffer`, `deleted-buffer-p`

## `deleted-buffer-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `deleted-buffer-p BUFFER`

```text
バッファが削除されているかどうかを調べます。
BUFFERにはバッファ型のものしか指定できません。

  t   指定されたバッファは既に削除されています。
  nil 指定されたバッファは未だ削除されていません。
```

関連: `delete-buffer`

## `ed::*auto-save-session-file*`

- Variable / package: editor / 定義: session.l

```text
セッションの自動保存フラグです。

  nil     : 自動保存しない
  non-nil : 自動保存する
```

関連: `toggle-session-auto-save`, `close-session`

## `enum-buffers`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `enum-buffers FN`

```text
関数がnil以外を返すまでバッファを列挙し続けます。

使用例：
  ;;; バッファを列挙し続ける。
  (enum-buffers #'(lambda (x) (and (yes-or-no-p "~S" x) x)))
  => #<buffer:  *Completion*>
```

関連: `buffer-list`

## `erase-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `erase-buffer BUFFER`

```text
バッファの内容を削除します。
以下の内容がクリアされます。
  ・バッファ上のテキスト
  ・変更フラグ
  ・修正日付
  ・restriction
  ・UNDO情報
```

## `fast-scroll-down`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `fast-scroll-down`

```text
高速に下スクロールします。[C-Up]
```

関連: `fast-scroll-up`, `scroll-window`

## `fast-scroll-up`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `fast-scroll-up`

```text
高速に上スクロールします。[C-Down]
```

関連: `fast-scroll-down`, `scroll-window`

## `file-precious-flag`

- BufferLocal / package: editor

```text
ファイル保存時にバックアップファイルを作成するかどうかを指定する変数です。

  nil : ファイル保存時にバックアップファイルを作成しません。
  t   : ファイルを保存するときにバックアップファイルを作成してから
        バッファをファイルに保存します。ディスク容量の不足等でファイルの
        保存に失敗した場合でも元のファイルを壊すことはありません。
        デフォルトは t です。

使用例：
  ;;; ファイル保存時にバックアップファイルを作成しない
  (setq file-precious-flag nil)
  => nil

補足：
  xyzzy 0.2.2.244 から利用可能です。
```

関連: `backup-by-copying`

## `file-visited-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `file-visited-p &optional BUFFER`

```text
BUFFER がファイル名を持つとき t となります。
デフォルトでは BUFFER は 現在のバッファです。
```

## `find-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-buffer BUFFER-NAME`

```text
名前がBUFFER-NAMEなバッファが存在すればそのバッファを返します。
存在しなければnilを返します。

使用例：
  (find-buffer "*scratch*")
  => #<buffer: *scratch*>
  (find-buffer "*hoge hoge*")
  => nil
```

関連: `find-name-buffer`, `get-file-buffer`, `get-buffer-create`

## `find-name-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-buffer BUFFER-NAME`

```text
名前がBUFFER-NAMEもしくはBUFFER-NAME<数字>なバッファのリストを返します。
存在しなければnilを返します。

使用例：
  (find-name-buffer " *TAGS*")
  => (#<buffer:  *TAGS*<2>> #<buffer:  *TAGS*>)
  (find-name-buffer "*hoge hoge*")
  => nil
```

関連: `find-buffer`, `get-file-buffer`, `create-new-buffer`

## `forward-sexp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-sexp &optional ARG NO-ERRORS`

```text
lisp-modeでS式を1つ進めます。[ESC C-f]

使用例：
  (forward-sexp)
```

関連: `backward-sexp`, `up-list`

## `get-alternate-file-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `get-alternate-file-buffer FILENAME &key (:test #'equalp)`

```text
ファイル名の別名が FILENAME であるようなバッファを返します。
```

関連: `get-buffer-alternate-file-name`, `set-buffer-alternate-file-name`

## `get-buffer-alternate-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-buffer-alternate-file-name &optional BUFFER`

```text
バッファBUFFERに設定されたファイル名の別名を取得します。
```

関連: `set-buffer-alternate-file-name`

## `get-buffer-colors`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-buffer-colors &optional BUFFER`

```text
バッファの色をBGRを表す数値をベクタで返します。

使用例：
  (ed:get-buffer-colors)
  => #(0 16777215 12639424 16777215 16750899 16711680 8421376 8388736 32768 128 255 8388736 0 128 0 0 0 15790320)

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `set-buffer-colors`

## `get-buffer-create`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `get-buffer-create NAME`

```text
指定した名前のバッファを返します。名前を指定しますが、同じ名前のバッファ
が既にあればそれを返します。無ければcreate-new-bufferで新しく作ります。

switch-to-bufferも良く似た動きをしますが、switch-to-bufferは
get-buffer-createを用いて実装されています。

  NAME : バッファの名前

使用例：
  ;;; *calc*がなければ作成する。
  (get-buffer-create "*calc*")
  => #<buffer: *calc*>
```

関連: `create-new-buffer`, `find-buffer`, `new-file`, `switch-to-buffer`, `バッファの内部構造`

## `get-buffer-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-buffer-file-name &optional BUFFER`

```text
バッファが参照しているファイルのフルパスを返します。
ファイルを参照していなければnilを返します。

  BUFFER : ファイルのフルパスを返すバッファを指定します。

使用例：
  ;;; カレントバッファのファイルのフルパスを返します。
  (get-buffer-file-name)
  => "C:/xyzzy/site-lisp/xmldoc/reference.xml"
```

関連: `set-buffer-file-name`, `get-file-buffer`

## `get-file-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-file-buffer FILENAME`

```text
ファイルを表示しているバッファを返します。
なければnilを返します。

使用例：  
  (get-file-buffer "not-documented.xml")
  => #<buffer: not-documented.xml>
```

関連: `get-buffer-file-name`

## `get-next-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-next-buffer &optional BUFFER REVERSE TAB-ORDER INTERNAL`

```text
次のバッファを返します。

  BUFFER    : 
       :top     先頭のバッファを返します。
       :bottom  最後尾のバッファを返します。
       バッファ 指定したバッファの次のバッファを返します。
  REVERSE   : non-nil なら一つ前のバッファを返します。
  TAB-ORDER : nil ならバッファの生成順で、non-nil ならバッファタブ順で
              次のバッファを返します。
  INTERNAL  : non-nil なら非表示バッファも含めて次のバッファを返します。
```

関連: `next-buffer`, `buffer-list`

## `get-selection-type`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-selection-type`

```text
バッファの選択状態を返します。

  nil   選択なし、
  1     行モード選択状態
  2     文字モード選択状態
  3     矩形選択状態
```

関連: `set-selection-type`, `start-selection`

## `goto-last-modified-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `goto-last-modified-line`

```text
現在のバッファで最近変更された行の先頭に移動します。
```

関連: `last-modified-point`, `exchange-point-and-mark`

## `insert-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `insert-buffer BUFFER`

```text
指定されたバッファの内容を現在のバッファに挿入します。
```

関連: `insert-buffer-substring`, `insert-file`, `insert-file-contents`, `insert`

## `insert-buffer-substring`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `insert-buffer-substring BUFFER &optional FROM TO`

```text
指定されたバッファの内容を現在のバッファに挿入します。
リージョンが指定されていればその領域を挿入します。
```

関連: `insert-buffer`, `insert`

## `insert-file-contents`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `insert-file-contents FILENAME &optional VISIT-P OFFSET SIZE`

```text
ファイルの内容をカーソル位置に挿入します。

  FILENAME : 挿入するファイル名
  VISIT-P  : ファイルを挿入後の動作を指定します。
        t       変更フラグ・UNDO情報のクリア、ファイルの日付の変更等を行います。
        nil     特に何もしません。
  OFFSET   : 挿入するオフセット
  SIZE     : 挿入する長さ

使用例：
  ;;; 簡単なテンプレートの挿入例
  ;;; site-lisp/template.lを用意しておくこと
  (defun insert-template ()
    (and (get-buffer-file-name)
         (not (file-exist-p (get-buffer-file-name)))
         (insert-file-contents (merge-pathnames "site-lisp/template.l" (si:system-root)) t)
         (message "template inserted")))
  => insert-template
  (add-hook '*lisp-mode-hook* 'insert-template)
  => (insert-template lisp-load-keyword-file)
```

関連: `insert-file`

## `kept-undo-information`

- BufferLocal / package: editor

```text
undo 可能回数を指定する変数です。

  <integer> : 指定回数分の undo 情報を保持します。
  上記以外  : undo 情報を保持しません。(undo できません。)

使用例：
  ;;; 現在開いているファイルではundoできないようにします。
  (make-local-variable 'kept-undo-information)
  => t
  (setq kept-undo-information nil)
  => nil
```

関連: `undo`, `undo-boundary`, `clear-undo-boundary`, `setup-temp-buffer`

## `kill-all-buffers`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `kill-all-buffers &optional NOT-VERBOSE`

```text
全バッファをkill-bufferします。
NOT-VERBOSEで保存するか否かを指定できます。

  NOT-VERBOSE :
        t       何も確認せずに保存しようとします。
        nil     変更があるバッファは確認のダイアログ表示されます。
```

## `kill-all-local-variables`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kill-all-local-variables`

```text
全てのローカル変数が現在のバッファで独自の値を持てないようにします。
setq-defaultされていなかったローカル変数は参照できなくなります。

使用例：
  ;;; defvar-localした変数の値を設定してからkillしてみる。
  (defvar-local abc 123)        => abc
  (setq abc 456)                => 456
  abc                           => 456
  (kill-all-local-variables)    => t
  abc                           => 123
```

## `kill-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `kill-buffer BUFFER`

```text
バッファを削除します。[C-x k]
ただし、kill-bufferはバッファが変更されていると削除していいかどうか聞
いてきます。マクロ中で使う際には、delete-bufferを使ったほうがいいでし
ょう。(ユーザに聞かずにいきなり削除します）

また、*query-kill-buffer-hook*にフック関数を設定すると、独自の用件でバ
ッファの破棄を確認できます。

使用例：
  ;;; 現在のバッファを削除する。
  (kill-buffer (selected-buffer))
  => t
```

関連: `delete-buffer`, `deleted-buffer-p`, `kill-selected-buffer`, `*query-kill-buffer-hook*`, `*kill-buffer-kills-scratch*`

## `kill-local-variable`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kill-local-variable SYMBOL`

```text
SYMBOLが現在のバッファで独自の値を持てない様にします。
kill-local-variableを実行した後では、SYMBOLの値はグローバルなSYMBOLの値
になります。setq-defaultされていなかったローカル変数は参照できなくなります。

使用例：
  ;;; defvar-localした変数の値を設定してからkillしてみる。
  (defvar-local abc 123)        => abc
  (setq abc 456)                => 456
  abc                           => 456
  (kill-local-variable 'abc)    => t
  abc                           => 123
```

関連: `kill-all-local-variables`, `make-local-variable`, `make-variable-buffer-local`

## `kill-selected-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `kill-selected-buffer`

```text
名前のとおりselected-bufferをkill-bufferします。

参考：
  ;;; buffer.l
  (defun kill-selected-buffer ()
    (interactive)
    (kill-buffer (selected-buffer)))
```

関連: `kill-buffer`

## `load-session`

- Function / package: editor / 定義: session.l
- 呼び出し: `load-session FILENAME &optional NOT-CLOSE`

```text
セッションファイルに保存されている状態を復元します。 [C-x 6 f]

  NOT-CLOSE : ロード前に開いているバッファを削除するかどうか
        nil       *scratch* を除いてすべて削除してからロード
        non-nil   残したままロード
```

関連: `save-session`, `*default-session-directory*`

## `lock-file`

- BufferLocal / package: editor

```text
ロックファイルを作るかどうかを指定する変数です。

  t   : ロックファイルを作る。
  nil : ロックファイルを作らない。

使用例：
  ;;; 現在開いているファイルではロックファイルを作らないようにする。
  (make-local-variable 'lock-file)
  => t
  (setq lock-file nil)
  => nil
```

関連: `unlock-file`, `file-locked-p`

## `make-backup-files`

- BufferLocal / package: editor

```text
バックアップファイルを作るかどうかを指定する変数です。

  t   : バックアップファイルを作る
  nil : バックアップファイルを作らない

使用例：
  ;;; 現在開いているファイルをバックアップとらないようにする。
  (make-local-variable 'make-backup-files)
  => t
  (setq make-backup-files nil)
  => nil
```

## `make-local-variable`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-local-variable SYMBOL`

```text
SYMBOLを現在のバッファで独自の値を持てるようにローカル変数にします。
make-variable-buffer-localとは異なり、現在のバッファだけです。

使用例：
  ;;; 現在のバッファは自動保存しないようにする。
  (make-local-variable 'auto-save)
  => t  
  (setq auto-save nil)
  => nil
```

関連: `make-variable-buffer-local`, `defvar-local`, `local-variable-p`, `kill-local-variable`, `kill-all-local-variables`, `buffer-local-value`

## `make-variable-buffer-local`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-variable-buffer-local SYMBOL`

```text
SYMBOLを個々のバッファで独自の値を持てるようにローカル変数にします。
make-local-variableとは異なり、全てのバッファが対象です。
余程のことが無い限りdefvar-localを使えば良いと思います。
```

関連: `make-local-variable`

## `need-buffer-save-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `need-buffer-save-p BUFFER`

```text
バッファが保存が必要かを返します。
need-not-saveと関連しています。

  t     バッファの保存が必要
  nil   バッファの保存が必要ではない
```

関連: `need-not-save`

## `next-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `next-buffer`

```text
次のバッファに切替えます。 [Home]
エディタ上で現在選択されているウィンドウの中のバッファが変わるだけです。

バッファタブの順番にそってnext-bufferしたいのならば、
*next-buffer-in-tab-order*を参照して下さい。
```

関連: `previous-buffer`, `*next-buffer-in-tab-order*`, `other-buffer`

## `not-modified`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `not-modified`

```text
バッファの変更フラグをクリアします。[ESC ~]
つまり変更されてないことになります。
(set-buffer-modified-p nil)のinteractive版です。
```

関連: `set-buffer-modified-p`

## `open-session-dialog`

- Function / package: editor / 定義: session.l
- 呼び出し: `open-session-dialog`

```text
ダイアログからセッションファイル名を指定してセッションを開きます。
[C-x 6 F]
```

関連: `load-session`

## `other-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `other-buffer &optional BUFFER`

```text
最近、表示されていたバッファを返します。
```

関連: `bury-buffer`, `next-buffer`

## `previous-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `previous-buffer`

```text
一つ前のバッファに切替えます。next-bufferの反対です。[S-Home]
```

関連: `next-buffer`

## `print-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `print-buffer &optional BUFFER`

```text
バッファを印刷します。
```

関連: `print-dialog`

## `redo`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `redo`

```text
元に戻した処理を再度実行します。[C-_],[S-End],[F12]

buffer-can-redo-p が t の時のみ実行可能です。
```

関連: `undo`, `buffer-can-redo-p`

## `rename`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `rename FILENAME &optional NOWARN`

```text
バッファに関連づけられたファイル名を変更します。バッファ名も同時に変更されます。
変更に成功したらnil以外の値を、失敗したらnilを返します。[C-x C-n]

使用例：
  ;;; カレントバッファのファイル名が"c:/foo.baz"に変更されます。
  ;;; 同時に、バッファ名も"foo.baz"になります。
  (rename "c:/foo.baz")
```

関連: `rename-buffer`, `set-buffer-file-name`, `rename-file`

## `rename-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `rename-buffer BUFFER-NAME &optional BUFFER`

```text
ファイル名は変えずにバッファ名だけを変更します。
```

関連: `rename`, `buffer-name`

## `save-session`

- Function / package: editor / 定義: session.l
- 呼び出し: `save-session FILENAME &optional NOWARN`

```text
現在のバッファと各フレームのウィンドウの状態をセッションファイルに保存
します。ただし file-visited でないバッファと save-p が nil なフレーム
は保存されません。 [C-x 6 s]

保存した状態は load-session で復元することができます。

  NOWARN : 指定されたファイルがすでに存在するときの動作
        non-nil   黙って上書きする
        nil       メッセージボックスを表示して確認する
```

関連: `load-session`

## `save-session-dialog`

- Function / package: editor / 定義: session.l
- 呼び出し: `save-session-dialog`

```text
ダイアログからセッションファイル名を指定してセッションを保存します。
[C-x 6 S]
```

関連: `save-session`

## `select-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `select-buffer`

```text
バッファを選択するダイアログを表示します。 [F2]
デフォルトではC-p/C-nで上下し、C-mで選択します。
buffer-menuのようなバッファの削除などはできません。
※正確には*std-control-xxx-char*の設定に依ります。
```

関連: `buffer-menu`

## `selected-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `selected-buffer`

```text
現在操作中のバッファ（カレントバッファ）を返します。

使用例：
  (selected-buffer)
  => #<buffer: reference.xml>

互換性：
  この関数はmuleにはありません。
  muleでのcurrent-bufferに相当します。
```

## `set-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer BUFFER`

```text
バッファを選択します。
```

関連: `switch-to-buffer`, `with-set-buffer`

## `set-buffer-alternate-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-alternate-file-name NAME &optional BUFFER`

```text
バッファBUFFERにファイル名の別名NAMEをつけます。set-buffer-file-nameでは、
ありえないパスを指定するとエラーになります。
set-buffer-alternate-file-nameではどのような文字列でも指定可能です。

使用例：
  ; c:/abc/は存在しないパス
  (set-buffer-file-name "c:/abc/def.txt")
  => c:/abc/def.txt
     指定されたパスが見つかりません。 

  ; URLでもなんでも任意の文字列を設定可
  (set-buffer-alternate-file-name "http://www.asahi.com")
  => t

指定した文字列は、バッファのファイル名がnilの場合（つまり、
get-buffer-file-nameの戻り値がnilの場合）に限り、
以下の個所で使用されます

  1)select-bufferで表示されるダイアログのファイル名
  2)mode-line-format/title-bar-formatのファイル名
```

関連: `get-buffer-alternate-file-name`, `set-buffer-file-name`

## `set-buffer-colors`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-colors COLORS &optional BUFFER`

```text
バッファの色を設定します。設定した色は現状のバッファにだけ適用されます。

  COLORS : BGRを表す数値をベクタで指定します。
```

関連: `get-buffer-colors`

## `set-buffer-eol-code`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-eol-code CODE &optional BUFFER`

```text
バッファの改行コードを設定します。
引数として改行コードの種類を表す定数が用意されています。
昔は、set-buffer-newline-codeという名称でしたが、xyzzy 0.2.0.121 からこ
の名前に変更されました。

  CODE：バッファの改行コードの種類を指定します。
        LFの場合        *eol-lf*        0
        CRLFの場合      *eol-crlf*      1
        CRの場合        *eol-cr*        2

使用例：
  ;;; バッファの改行コードをLFに変更する。
  (set-buffer-eol-code *eol-lf*)
  => t

参考：
  Changelogのxyzzy 0.2.0.121を参照のこと
```

関連: `*eol-lf*`, `*eol-crlf*`, `*eol-cr*`, `set-buffer-fileio-encoding`

## `set-buffer-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-file-name FILE-NAME &optional BUFFER`

```text
バッファと結び付けられているファイルをFILE-NAMEにします。
```

関連: `get-buffer-file-name`, `rename`, `set-buffer-alternate-file-name`

## `set-buffer-fileio-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-fileio-encoding CODE &optional BUFFER`

```text
バッファの文字エンコーディングをCODEにします。設定した文字エンコーディングは
buffer-fileio-encodingで参照することができます。

  CODE   : 文字エンコーディングを指定します。
  BUFFER : 変更するバッファを指定します。

使用例：
  (set-buffer-fileio-encoding *encoding-sjis*)
  (set-buffer-fileio-encoding *encoding-euc-jp*)
  (set-buffer-fileio-encoding *encoding-jis*)
  (set-buffer-fileio-encoding *encoding-utf8*)

参照：
  kanji.l
```

関連: `buffer-fileio-encoding`, `*char-encoding-list*`, `set-buffer-eol-code`

## `set-buffer-fold-type-column`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-column`

```text
カレントバッファを指定位置で折り返しします。
```

関連: `set-buffer-fold-type-window`, `set-buffer-fold-type-none`

## `set-buffer-fold-type-column-update`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-column-update`

```text
カレントバッファが指定位置で折り返しになっているかどうかを返します。

戻り値は以下のとおりです。
  :check  なっている
  nil     なっていない
```

関連: `set-buffer-fold-type-column`

## `set-buffer-fold-type-none`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-none`

```text
カレントバッファを折り返しなしにします。
```

関連: `set-buffer-fold-type-window`, `set-buffer-fold-type-column`

## `set-buffer-fold-type-none-update`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-none-update`

```text
カレントバッファが折り返し無しになっているかどうかを返します。

戻り値は以下のとおりです。
  :check  なっている
  nil     なっていない
```

関連: `set-buffer-fold-type-none`

## `set-buffer-fold-type-window`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-window`

```text
カレントバッファをウィンドウ幅で折り返します。
```

関連: `set-buffer-fold-type-none`, `set-buffer-fold-type-column`

## `set-buffer-fold-type-window-update`

- Function / package: editor / 定義: window.l
- 呼び出し: `set-buffer-fold-type-window-update`

```text
カレントバッファがウィンドウ幅で折り返しになっているかどうかを返します。

戻り値は以下のとおりです。
  :check  なっている
  nil     なっていない
```

関連: `set-buffer-fold-type-window`

## `set-buffer-modified-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-modified-p FLAG &optional BUFFER`

```text
バッファが変更されたかどうかのフラグを設定します。

  FLAG   : フラグを指定します。
        t       変更されている状態にします。
        nil     変更が存在しない状態にします。
  BUFFER : 対象のバッファ

使用例： 
  ;;; 変更フラグの設定・クリア
  (set-buffer-modified-p t)
  (set-buffer-modified-p nil)
```

関連: `buffer-modified-p`, `not-modified`

## `set-buffer-package`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `set-buffer-package PACKAGE-NAME`

```text
*buffer-package*を設定するコマンドです。

補足：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `eval-region`, `*buffer-package*`

## `setup-temp-buffer`

- Function / package: editor / 定義: misc.l
- 呼び出し: `setup-temp-buffer BUFFER`

```text
BUFFER を一時バッファ用に初期化します。
具体的には以下のようにバッファローカル変数を設定します。

  buffer-read-only      -> nil
  need-not-save         -> t
  kept-undo-information -> nil
  auto-save             -> nil
```

関連: `buffer-read-only`, `need-not-save`, `kept-undo-information`, `auto-save`

## `switch-to-buffer`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `switch-to-buffer BUFFER &optional NOWARN`

```text
指定されたバッファに移動し、ウィンドウに移動します。 [C-x b]
バッファが存在しなければバッファを作成します。そのバッファを操作中のウ
ィンドウに表示するところ以外は、get-buffer-createのinteractive版と言え
ます。

使用例：
  ;;; *calc*があろうとなかろうと*calc*に移動する。
  (switch-to-buffer "*calc*")
  => #<buffer: *calc*>
```

関連: `get-buffer-create`, `set-buffer`, `verify-visited-file-modtime`, `switch-to-buffer-other-window`

## `switch-to-buffer-other-window`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `switch-to-buffer-other-window BUFFER &optional NOWARN`

```text
他のウィンドウに移ってからバッファを切り替えます。[C-x 4 b]
ウィンドウ数が1の時は、ウィンドウを分割します。

  BUFFER : このバッファにカレントウィンドウを切り替えます。
  NOWARN : non-nilならば、指定したバッファが他のアプリケーションにより更
           新されているかのチェックを行いません。
```

関連: `switch-to-buffer`

## `toggle-read-only`

- Function / package: editor / 定義: buffer.l
- 呼び出し: `toggle-read-only &optional (ARG () SV)`

```text
バッファの書き込み禁止をトグルします。 [C-x C-q]
```

関連: `buffer-read-only`

## `toggle-session-auto-save`

- Function / package: editor / 定義: session.l
- 呼び出し: `toggle-session-auto-save &optional (ARG () SV)`

```text
セッションの自動保存フラグ (ed::*auto-save-session-file*) を切り替え
ます。 non-nil のときは、セッションを終了する際に自動でセッションファ
イルを上書きします。

ARG が与えられたとき (SV が non-nil のとき) は
  nil または負の整数 : nil にする
  それ以外           : t にする
```

関連: `close-session`, `ed::*auto-save-session-file*`

## `undo`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `undo`

```text
直前の操作を取り消します。[End], [C-\] 
UNDO情報の直近の境界まで戻ります。
```

関連: `buffer-can-undo-p`, `undo-boundary`, `clear-undo-boundary`, `kept-undo-information`, `redo`, `last-modified-point`, `*move-forward-after-undo-deletion*`

## `undo-boundary`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `undo-boundary`

```text
UNDO情報に境界を設定します。
以後undoを実行すると、この境界まで戻ります。
```

関連: `clear-undo-boundary`, `undo`

## `verify-visited-file-modtime`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `verify-visited-file-modtime &optional BUFFER`

```text
バッファがファイルに関連付けられていない、もしくはバッファとそれに関連付
けられたファイルとの更新時間が一致していると t を返します。バッファとそ
れに関連付けられたファイルとの更新時間が一致していない時、つまり他のプロ
セスによってファイルが変更された時などに nil を返します。
```

関連: `verify-buffers-file-modtime`, `switch-to-buffer`, `find-file-verify`, `clear-visited-file-modtime`, `update-visited-file-modtime`

## `verify-visited-file-modtime`

- BufferLocal / package: editor / 定義: buffer.l

```text
activate 時のバッファの最終更新日チェックを制御します。
  :auto    更新されていれば自動的に読み直す
  non-nil  チェックする
  nil      チェックしない
```

関連: `verify-buffers-file-modtime`, `switch-to-buffer`

## `window-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-buffer WINDOW`

```text
ウィンドウが表示しているバッファを返します。
  
使用例：
  (window-buffer (selected-window))
```

関連: `get-buffer-window`

## `with-set-buffer`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-set-buffer &body BODY`

```text
BODY を実行する際に、ポイントがミニバッファ以外にあることを保証します。
ポイントがミニバッファにあった場合、BODY を実行した後ポイントはミニバッファに戻ります。

ミニバッファで set-buffer するとエラーが起きるので、それを回避するためにあるようです。

使用例:
  ;; lisp/misc.l より
  (defun setup-temp-buffer (buffer)
    (with-set-buffer
      (save-excursion
        (set-buffer buffer)
        (setq buffer-read-only nil)
        (setq need-not-save t)
        (setq kept-undo-information nil)
        (setq auto-save nil))))
```

関連: `set-buffer`

## `バッファの内部構造`

- Tips
