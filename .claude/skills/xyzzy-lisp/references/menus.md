# メニュー (menus)

reference/reference.xml から自動生成。45 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*buffer-menu-mode-hook*`

- Variable / package: editor / 定義: buf-menu.l

```text
buffer-menuの起動時に実行されます。

参考：
  (run-hooks '*buffer-menu-mode-hook*)
```

## `*init-app-menus-hook*`

- Variable / package: editor / 定義: app-menu.l

```text
xyzzy実行後に実行されます。*app-menu*を直接変更する用途で用いら
れます。

使用例：
  (add-hook '*init-app-menus-hook*
            #'(lambda ()
                (add-menu-item *app-menu* 'close-box :close-box
                               #'kill-selected-buffer)))
```

関連: `起動時処理フロー`

## `add-menu-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `add-menu-item MENU TAG NAME &optional COMMAND INIT`

```text
新たに作成したメニュー項目をメニューの末尾に追加します。

  MENU    : 追加先のメニューを指定します。
  TAG     : 識別用のタグを指定します。
  NAME    : メニューに表示される名前を指定します。
  COMMAND : メニューの項目が選択されたときに実行するコマンドを指定します。
  INIT    : メニューが開く直前に評価し返される値によってメニューの状態を
            設定します。任意のS式が指定できますが、あまり無茶なことはしな
            いでください。式の値として意味のある値には以下のものがあります。

        :modified     カレントバッファが変更されていなければ灰色表示。
        :undo         undo不可能であれば灰色表示。
        :redo         redo不可能であれば灰色表示。
        :selection    カレントバッファのテキストが未選択であるか矩形選択
                      であれば灰色表示。
        :rectangle    カレントバッファのテキストが未選択であるか矩形以外
                      の選択であれば灰色表示。
        :clipboard    クリップボードが空であれば灰色表示。
        :check        チェック。
        :disable      灰色表示。
        その他        使用可能。
```

関連: `insert-menu-item`, `get-menu`, `create-menu`, `define-menu`

## `add-menu-separator`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `add-menu-separator MENU &optional TAG`

```text
セパレータをメニューの末尾に追加します。

  MENU : 追加先のメニューを指定します。
  TAG  : 識別用のタグを指定します。
```

関連: `insert-menu-separator`, `define-menu`, `define-popup-menu`, `get-menu`, `get-menu-position`

## `add-popup-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `add-popup-menu MENU POPUP-MENU NAME`

```text
ポップアップメニューをメニューの末尾に追加します。

  MENU       : 追加先のメニューを指定します。
  POPUP-MENU : 追加するポップアップメニューを指定します。
  NAME       : メニューに表示される名前を指定します。

使用例：
  ;;; 右クリックメニューを標準のメニューに追加してみる。
  (add-popup-menu *app-menu* *app-popup-menu* "編集2(&E)")
  => #<menu 48701736>
```

関連: `insert-popup-menu`, `define-popup-menu`

## `apps-popup`

- Function / package: editor / 定義: mouse.l
- 呼び出し: `apps-popup`

```text
ポップアップメニューを表示します。[Apps]

メニューは、*app-popup-menu* に定義されたものが使用されます。
```

関連: `mouse-menu-popup`

## `call-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `call-menu N`

```text
「ファイル(F)」「編集(E)」といったメニューの N 番目の項目を開きます。
N には 0 オリジンで位置を指定します。
すなわち 0 を指定したときは通常「ファイル(F)」のメニューを開きます。
```

## `copy-menu-items`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `copy-menu-items OLD-MENU NEW-MENU`

```text
old-menuの構造をnew-menuにトップレベルでコピーします。

亀井さん談：
  ちなみにバグってます。old-menuとnew-menuが同じ場合のことを何も考えていません。
```

## `create-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-menu &optional TAG`

```text
新たに作成した空のメニューを返します。

  TAG : 識別用のタグを指定します。

メニューの中身は空なので、以下の関数で登録必要があります。
中身を動的に作る必要が無ければ、 define-menu を使用した方が良いです。

  add-menu-item         : 項目を追加します。
  add-menu-separator    : セパレータを追加します。
  add-popup-menu        : ポップアップメニューを追加します。
  insert-menu-item      : 項目を挿入します。
  insert-menu-separator : セパレータを挿入します。
  insert-popup-menu     : ポップアップメニューを挿入します。

作成したメニューは以下の関数で使います。

  set-menu       : 標準のメニューとして設定します。
  use-local-menu : バッファにローカルなメニューとして設定します。
```

関連: `create-popup-menu`, `define-menu`, `set-menu`, `use-local-menu`

## `create-popup-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-popup-menu &optional TAG`

```text
新たに作成したポップアップメニューを返します。ポップアップメニューとして
使えることを除けば、create-menuで作成されたメニューを同じです。

  TAG : 識別用のタグを指定します。

メニューの中身は空なので、create-menuと同じように登録する必要があります。
中身を動的に作る必要が無ければ、define-popup-menuを使用した方が良いです。

作成したポップアップメニューは以下の関数で使います。

  insert-popup-menu  : 既存のメニューにポップアップメニューを追加します。
  track-popup-menu   : ポップアップメニューをその場で表示します。
```

関連: `define-popup-menu`, `track-popup-menu`, `create-menu`

## `create-tab-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-tab-bar BAR CALLBACK`

```text
タブバーの識別子BARと、タブが選択されたとき実行するコールバック関数
CALLBACKを指定して、タブバーを作成します。CALLBACKは、各タブの作成時に設
定したシンボルが渡されます。

使用例：
  (progn
    (defun a-func (a) (msgbox "~A ~A" a (type-of a)))
    (define-command-bar 'a-bar "a bar")
    (create-tab-bar 'a-bar 'a-func)
    (show-command-bar 'a-bar)
    (tab-bar-add-item 'a-bar '1st "- 1st -" "1st item")
    (tab-bar-add-item 'a-bar '2nd "- 2nd -" "2nd item"))
  => t  
  (progn
    (tab-bar-delete-item 'a-bar '1st)
    (tab-bar-delete-item 'a-bar '2nd)
    (delete-tool-bar 'a-bar)
    (delete-command-bar 'a-bar))
  => t
```

関連: `tab-bar-add-item`, `tab-bar-list-items`, `tab-bar-modify-item`, `tab-bar-select-item`

## `create-tool-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-tool-bar NAME BITMAP ITEMS`

```text
ツールバーNAMEを作成します。ツールバーに表示するビットマップファイルのフ
ルパスBITMAPと、ツールバーの項目ITEMSを指定します。ITEMSは以下の形式で記
述します。項目の替わりに:sepを指定するとセパレータを表示できます。

形式：
  ((ツールチップ1 アイコンの番号1 実行する関数1 状態制御用1)
   (ツールチップ2 アイコンの番号2 実行する関数2 状態制御用2)
    ...
   (ツールチップN アイコンの番号N 実行する関数N 状態制御用N))

補足：
  アイコンの番号：
        16x16の領域をひとつのアイコンとみなして、ビットマップファイルの
        左から0ベースの番号で指定します。
  状態制御用：
        ボタンの状態が何に依存して変更するかを指定します。
        :modified              編集されていたら 
        :selection             行モード選択、文字モード選択をしていたら
        :modify-selection      編集可能なバッファで行モード選択
                               文字モード選択をしていたら
        :rectangle             矩形選択していたら
        :modify-rectangle      編集可能なバッファで矩形選択をしていたら
        :any-selection         選択していたら
        :modify-any-selection  編集可能なバッファで選択していたら
        :clipboard             編集可能なバッファでクリップボードに値が入っていたら
        :undo                  UNDOできる状態なら
        :redo                  リドゥできる状態なら
        関数 (function)        関数が返す値による
            :disable           ボタンを押せない状態 
            :check             ボタンを押してへこんだ状態 
            上記以外           普通の押せる状態 
        上記以外               指定しないとの同じで無条件に押せる状態 
        ※OHKUBO Hiroshiさんのサイトより
          http://ohkubo.s53.xrea.com/xyzzy/memo.html

使用例：
(create-tool-bar 'abc-tool-bar
 (merge-pathnames "toolbar.bmp" (etc-path))
 '(("line-number" 0 toggle-line-number)
   ("vscroll-bar" 1 toggle-vscroll-bar)
   ("mode-line" 2 toggle-mode-line)
   :sep
   ("function-bar" 3 toggle-function-bar)
   ("fold-line" 4 toggle-fold-line)
   ("read-only" 5 toggle-read-only)))
```

関連: `define-command-bar`, `create-tab-bar`, `lisp/cmdbar.l`

## `current-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-menu &optional BUFFER`

```text
現在表示されているメニューを返します。use-local-menuを使用してい
るバッファは*app-menu*とは違うものが取得されます。
```

## `define-command-bar`

- Function / package: editor / 定義: cmdbar.l
- 呼び出し: `define-command-bar SYM NAME &optional EDGE X Y W`

```text
※以下は私見です。

ツールバーやタブバーを総称してツールバーと呼ぶようです。作成するときやツ
ールバーのリストを操作するときは全てtool-bar系の関数を使います。単に表示
するだけならば、show-tool-barを使えば可能です。

ただし、メニューの[表示]-[ツールバー]の一覧に追加する場合には、
command-bar系の関数を使います。define-command-barで登録したツールバーは、
[表示]-[ツールバー]から表示を制御することが可能です。予め、
define-command-barで定義したSYMに対応する、ツールバー・タブバーを作って
おく必要があります。

以下はタブバーを操作する場合の例です。

  (progn
    (defun a-func (a) (msgbox "~A ~A" a (type-of a)))
    (define-command-bar 'a-bar "a bar")
    (create-tab-bar 'a-bar 'a-func)
    (show-command-bar 'a-bar)
    (tab-bar-add-item 'a-bar '1st "- 1st -" "1st item")
    (tab-bar-add-item 'a-bar '2nd "- 2nd -" "2nd item"))

  (progn
    (tab-bar-delete-item 'a-bar '1st)
    (tab-bar-delete-item 'a-bar '2nd)
    (delete-tool-bar 'a-bar)
    (delete-command-bar 'a-bar))

また、ユーザのツールバーなどを作成する場合には、delete-command-barで削除
する手順を考慮することをおすすめします。コマンドバーは（シンボル名だけ）
ヒストリ変数に格納されます。その実体（ツールバーやタブバー）がなくとも、
ずっと[表示]-[ツールバー]に残ってしまいます。そのようなときは、手動で削
除する必要があります。

似たような話で、コマンドバーには関数名だけを指定しておいて、後から本体を
読み込みたい場合には、autoloadで出来ます。本体の初期化に時間が掛かる場合
には、このように分離するほうが良いと思います。

使用例：
  ------------------------------------------------
  ;;; .xyzzy
  (progn
    (define-command-bar 'a-bar "a bar")
    (autoload 'a-bar "a-bar.l"))
  ------------------------------------------------

  ------------------------------------------------
  ;;; a-bar.l
  (progn
    (create-tab-bar 'a-bar 'a-func)
    (show-command-bar 'a-bar)
    (tab-bar-add-item 'a-bar '1st "- 1st -" "1st item")
    (tab-bar-add-item 'a-bar '2nd "- 2nd -" "2nd item"))
  ------------------------------------------------
```

関連: `delete-command-bar`

## `define-menu`

- Macro / package: editor / 定義: menu.l
- 呼び出し: `define-menu &body BODY`

```text
固定的なメニューを定義します。
定義方法は define-popup-menu を参照して下さい。動的にメニューを生成した場
合には create-menu を参照して下さい。 define-menu で生成したメニューも
add-menu-item や insert-menu-item などで項目を追加することも可能です。
```

関連: `create-menu`, `add-menu-item`, `insert-menu-item`, `add-menu-separator`, `insert-menu-separator`, `copy-menu-items`, `delete-menu`, `get-menu`, `set-menu`, `use-local-menu`, `define-popup-menu`

## `define-popup-menu`

- Macro / package: editor / 定義: menu.l
- 呼び出し: `define-popup-menu &body BODY`

```text
固定的なポップアップメニューを定義します。

  BODY : メニューの定義を記述します。

BODYをインチキなBNFで書くと以下の様になります。

  POPUP-DEF : {MENU-ITEM}*

  MENU-ITEM : :sep
            : (:sep [TAG])
            | (:separator [TAG])
            | (:popup tag name {POPUP-DEF}*)
            | (:item tag name [COMMAND [INIT]])

  TAG       : メニュー項目を識別する任意のオブジェクトです。
              タグ同士はeqで比較されます

  COMMAND   : メニュー項目が選択されたときに実行されるコマンドです。

  INIT      : メニューが開く直前に評価され、返される値によってメニューの
              状態が設定されます。任意のS式が指定できますが、あまり無茶
              なことはしないでください。式の値として意味のある値には以下
              のものがあります。

        :modified     カレントバッファが変更されていなければ灰色表示
        :undo         undo不可能であれば灰色表示
        :redo         redo不可能であれば灰色表示
        :selection    カレントバッファのテキストが未選択であるか矩形選択
                      であれば灰色表示
        :rectangle    カレントバッファのテキストが未選択であるか矩形以外
                      の選択であれば灰色表示
        :clipboard    クリップボードが空であれば灰色表示
        :check        チェック
        :disable      灰色表示
        その他        使用可能

使用例：
  ;;; niftylog.l
  (define-popup-menu
    (:item nil "メッセージを読んだことにする(&R)"
     'log-read-article)
    (:item nil "メッセージを読んでないことにする(&N)"
     'log-unread-article)
    (:item nil "スレッドを読んだことにする(&T)"
     'log-read-thread)
    (:item nil "スレッドを読んでないことにする(&H)"
     'log-unread-thread)
    (:item nil "ニュースグループを読んだことにする(&G)")
    (:item nil "ニュースグループを読んでないことにする(&P)"))
  => #<menu 48698340>
```

関連: `create-popup-menu`, `track-popup-menu`, `add-popup-menu`, `insert-popup-menu`, `define-menu`

## `delete-command-bar`

- Function / package: editor / 定義: cmdbar.l
- 呼び出し: `delete-command-bar SYM`

```text
ツールバーを削除します。
```

関連: `define-command-bar`

## `delete-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-menu MENU TAG-OR-POSITION &optional TAG-OR-POSITION-P`

```text
メニューから項目等を削除します。

  MENU              : 削除するメニューを指定します。
  TAG-OR-POSITION   : タグもしくは位置を指定します。
  TAG-OR-POSITION-P : TAG-OR-POSITIONの引数をタグとして解釈するか位置と
                      して解釈するかを決めます。
           nil     TAG-OR-POSITIONはタグを表すシンボル
           non-nil TAG-OR-POSITIONは位置を表す整数値
  
タグを指定した場合にはメニューを再帰的に検索し最初に見つかった項目を削除
します。 タグが存在しない場合やメニュー項目数以上の位置を指定した場合に
は、削除に失敗します。

戻り値は以下のとおりです。

  t   削除に成功した。
  nil 削除に失敗した。
```

## `delete-tool-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-tool-bar NAME`

```text
ツールバーNAMEを削除します。
コマンドバーとして登録していた場合には、[表示]-[ツールバー]に残骸が残っ
てしまいますので、delete-command-barで削除する必要があります。
```

関連: `create-tool-bar`

## `focus-tool-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `focus-tool-bar`

```text
タブバーにフォーカスを移します。タブバーからはTABを押すことで元のバッフ
ァに戻ることが出来ます。タブバーが存在しないときは、フォーカスは元のバッ
ファのままです。
```

## `get-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-menu MENU TAG-OR-POSITION &optional TAG-OR-POSITION-P`

```text
指定されたメニューから、タグ名または位置で検索したメニューを取得します。

  TAG-OR-POSITION   : タグもしくは位置を指定します。
  TAG-OR-POSITION-P : TAG-OR-POSITIONの引数をタグとして解釈するか位置と
                      して解釈するかを決めます。
           nil     TAG-OR-POSITIONはタグを表すシンボル
           non-nil TAG-OR-POSITIONは位置を表す整数値
使用例：
  (get-menu *app-menu* 3 t)
```

関連: `current-menu`, `get-menu-position`, `define-menu`

## `get-menu-position`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-menu-position MENU TAG`

```text
メニューの中からタグの位置を検索して返します。

  MENU : 検索するメニューを指定します。
  TAG  : 検索するタグを指定します。

見つからなかった場合にはnilが返されます。
見つかった場合にはその位置とそれを含むメニューを返します。
```

関連: `get-menu`, `define-menu`

## `hide-command-bar`

- Function / package: editor / 定義: cmdbar.l
- 呼び出し: `hide-command-bar SYM`

```text
define-command-barで定義したコマンドバーを非表示にします。
```

関連: `show-command-bar`

## `hide-tool-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `hide-tool-bar NAME`

```text
ツールバーNAMEを非表示にします。
```

関連: `show-tool-bar`

## `insert-menu-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `insert-menu-item MENU POSITION TAG ITEM &optional COMMAND INIT`

```text
メニュー項目を作成しメニューの所定の位置に挿入します。

  MENU     : 追加先のメニューを指定します。
  POSITION : 挿入する位置を指定します。
  TAG      : 識別するタグを指定します。必要なければnilを指定します。
  ITEM     : メニューに表示される名前を指定します。
  COMMAND  : メニューの項目が選択されたときに実行するコマンドを指定します。
  INIT     : メニューが開く直前に評価し返される値によってメニューの状態
             を設定します。詳細はadd-menu-itemを参照して下さい。
```

関連: `add-menu-item`, `get-menu`, `define-menu`

## `insert-menu-separator`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `insert-menu-separator MENU POSITION &optional TAG`

```text
セパレータをメニューの所定の位置に挿入します。

  MENU     : 追加先のメニューを指定します。
  POSITION : 挿入する位置を指定します。
  TAG      : 識別するタグを指定します。
```

関連: `add-menu-separator`, `define-menu`, `define-popup-menu`, `get-menu`, `get-menu-position`

## `insert-popup-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `insert-popup-menu MENU POSITION POPUP-MENU MENU-NAME`

```text
ポップアップメニューをメニューの所定の位置に挿入します。

  MENU       : 追加先のメニューを指定します。
  POSITION   : 挿入する位置を指定します。
  POPUP-MENU : 追加するポップアップメニューを指定します。
  NAME       : メニューに表示される名前を指定します。

使用例：
  ;;; 右クリックメニューを標準のメニューに追加してみる。
  (insert-popup-menu *app-menu* 2 *app-popup-menu* "編集2(&E)")
  => #<menu 48701736>
```

関連: `add-popup-menu`, `define-popup-menu`

## `list-tool-bars`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-tool-bars`

```text
ツールバーの状態を取得します。状態は以下の形式で返されます。

形式：
  (((左側のツールバー1 横位置1 縦位置1 横幅1)
    (左側のツールバー2 横位置2 縦位置2 横幅2)
    (左側のツールバー3 横位置3 縦位置3 横幅3) ... )
   ((上側のツールバー1 横位置1 縦位置1 横幅1) ... )
   ((右側のツールバー1 横位置1 縦位置1 横幅1) ... )
   ((下側のツールバー1 横位置1 縦位置1 横幅1) ... )
   (非表示のツールバー1 非表示のツールバー2 ... ))

タブバーの場合だけ横幅に数字が返されます。ツールバーの場合には、必ずnil
が返されます。
```

## `menup`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `menup OBJECT`

```text
オブジェクトがメニューかどうかを返します。

  OBJECT : 判定するオブジェクト

  t   オブジェクトはメニュー
  nil オブジェクトはメニューではない
```

## `mouse-menu-popup`

- Function / package: editor / 定義: mouse.l
- 呼び出し: `mouse-menu-popup &optional APPS`

```text
ポップアップメニューを表示します。[RBtnUp]

  APPS  : メニューの表示位置を指定します。
     nil      マウスカーソル位置
     non-nil  カーソル位置
```

## `refresh-tool-bars`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `refresh-tool-bars`

```text
ツールバーをリフレッシュします。
lisp/optprop.lの中から共通設定の変更内容を、ツールバーに反映するために用
いられています。
```

## `set-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-menu MENU`

```text
指定されたメニューをデフォルトのメニューにします。xyzzy上部に常時表示さ
れるようになります。

  MENU : 設定するメニューを指定します。
         メニューが不要ならばnilを指定します。
```

関連: `use-local-menu`, `define-menu`

## `show-command-bar`

- Function / package: editor / 定義: cmdbar.l
- 呼び出し: `show-command-bar SYM`

```text
define-command-barで定義したコマンドバーを表示します。
```

関連: `hide-command-bar`

## `show-tool-bar`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `show-tool-bar NAME &optional EDGE X Y W`

```text
ツールバーNAMEを表示します。EDGE X Y Wを指定することで任意の位置に表示さ
せることが可能です。

  EDGE  :top    上側に表示
        :left   左側に表示
        :right  右側に表示
        :bottom 下側に表示
        nil     非表示
  X     横の位置
  Y     縦の位置
  W     タブバーの場合に左右に表示した場合の横幅を与える。
        ツールバーの場合はnilを与える。

[表示]-[ツールバー]に登録したいのならば、show-tool-barではなく、
define-command-bar/show-command-barを使います。
```

関連: `hide-tool-bar`

## `tab-bar-add-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-add-item BAR ITEM STRING &optional TOOLTIP MENU &key :first :last :before :after`

```text
create-tab-barで作成したタブバーBARにタブを追加します。タブを識別するた
めのITEMとタブの文字列STRINGを指定します。個別のツールチップTOOLTIPと、
メニューMENUを指定可能です。
```

関連: `tab-bar-delete-item`, `tab-bar-find-item`, `tab-bar-current-item`, `create-tab-bar`

## `tab-bar-current-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-current-item BAR`

```text
選択中のタブの情報が返されます。タブがひとつも無い場合には、nilが返され
ます。必ず、タブを識別するためのシンボル、タブの文字列、ツールチップのリ
ストで返されます。ツールチップが設定されていない場合には、nilが返されま
す。

使用例：
  (progn
    (defun a-func (a) (msgbox "~A ~A" a (type-of a)))
    (define-command-bar 'a-bar "a bar")
    (create-tab-bar 'a-bar 'a-func)
    (show-command-bar 'a-bar)
    (tab-bar-add-item 'a-bar '1st "- 1st -" "1st item")
    (tab-bar-add-item 'a-bar '2nd "- 2nd -" "2nd item"))
  => t
  (tab-bar-current-item 'a-bar)
  => (1st "- 1st -" "1st item")
  (progn
    (tab-bar-delete-item 'a-bar '1st)
    (tab-bar-delete-item 'a-bar '2nd)
    (delete-tool-bar 'a-bar)
    (delete-command-bar 'a-bar))
  => t
```

関連: `tab-bar-delete-item`, `tab-bar-add-item`

## `tab-bar-delete-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-delete-item BAR ITEM`

```text
create-tab-barで作成したタブバーBARからタブITEMを削除します。削除するタ
ブが選択状態であれば、次のタブが選択されて同時にCALLBACKが実行されます。
```

関連: `tab-bar-add-item`, `create-tab-bar`

## `tab-bar-find-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-find-item BAR ITEM`

```text
指定されたタブバーBARからタブITEMが存在するか否かを返します。

  t    存在する。
  nil  存在しない。

使用例：
  (tab-bar-find-item 'a-bar '1st)
  => t
  (tab-bar-find-item 'a-bar '3rd)
  => nil
```

関連: `create-tab-bar`, `tab-bar-list-items`

## `tab-bar-list-items`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-list-items BAR`

```text
指定されたタブバーBARのタブのシンボルのリストを返します。

使用例：
  (tab-bar-list-items 'a-bar)
  => (1st 2nd)
```

関連: `tab-bar-find-item`, `create-tab-bar`

## `tab-bar-modify-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-modify-item BAR ITEM &optional STRING TOOLTIP MENU`

```text
指定されたタブバーBARのタブITEMの設定を変更します。

使用例：
  (tab-bar-modify-item 'a-bar '1st "- first -")
  => t
```

関連: `tab-bar-add-item`

## `tab-bar-select-item`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-bar-select-item BAR ITEM`

```text
指定されたタブバーBARのタブITEMを選択状態にします。同時にタブバーに設定
されたCALLBACKが実行されます。
```

関連: `tab-bar-current-item`

## `tool-bar-exist-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tool-bar-exist-p NAME`

```text
指定されたツールバーNAMEが存在するか否かを返します。

  t    ツールバーが存在する。
  nil  ツールバー存在しない。
```

## `tool-bar-info`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tool-bar-info NAME`

```text
指定したツールバーNAMEの情報を多値で返します。

形式：
  表示位置  :top        上側に表示
            :left       左側に表示
            :right      右側に表示
            :bottom     下側に表示
            nil         非表示
  横位置    横の位置を返す。
  縦位置    縦の位置を返す。
  横幅      タブバーの場合に左右に表示した場合の横幅を返す。
            ツールバーの場合はnilを返す。
```

関連: `list-tool-bars`

## `track-popup-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `track-popup-menu MENU &optional ANY`

```text
フローティングポップアップメニューを表示します。選択されたコマン
ドを実行します。マウスボタンが押されていない場合はnilを返します。

  MENU : create-popup-menuもしくはdefine-popup-menuで作成された
         メニューを指定します。
  ANY  : どのようにポップアップするかを指定できます。
        :button1        マウスの位置にポップアップ
        :button2        マウスの位置にポップアップ
        上記以外        カーソルの位置にポップアップ
```

関連: `create-popup-menu`, `define-popup-menu`, `popup-string`

## `use-local-menu`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `use-local-menu MENU`

```text
カレントバッファにローカルなメニューを設定します。

  MENU : バッファにローカルなメニューを指定します。nilを設定するとローカ
         ルなメニューは解除され、デフォルトのメニューが使用されます。
```

関連: `set-menu`, `current-menu`, `define-menu`
