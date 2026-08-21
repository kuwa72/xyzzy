# ウィンドウ (windows)

reference/reference.xml から自動生成。70 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*next-pseudo-frame-in-tab-order*`

- Variable / package: editor / 定義: pframe.l

```text
next-pseudo-frameで次に移動するフレームを、タブでの順番どおりにするか否かを設
定します。もちろんprevious-pseudo-frameにも影響します。
  t    フレームバーでの次のフレームに移動する。
  nil  フレームの作成順に次のフレームに移動する。

補足：
  xyzzy 0.2.2.249 から利用可能です。
```

関連: `next-pseudo-frame`, `other-pseudo-frame`, `previous-pseudo-frame`

## `*next-screen-context-lines*`

- Variable / package: editor / 定義: page.l

```text
previous-page と next-page で重なって表示される行数を指定します。
*page-scroll-half-window* が non-nilのときは効果はありません。
```

関連: `next-page`, `previous-page`, `*page-scroll-half-window*`

## `*page-scroll-half-window*`

- Variable / package: editor / 定義: page.l

```text
next-page/previous-pageのスクロールの単位を半画面ずつにするか制御します。

  t     半画面ずつスクロール
  nil   一画面ずつスクロール
```

関連: `next-page`, `previous-page`, `*next-screen-context-lines*`

## `*scroll-bar-step*`

- Variable / package: editor
- 呼び出し: `*scroll-bar-step*`

```text
スクロールバーについている▲・▼ボタンを押したときのスクロール量です。
デフォルトは 2 です。
```

## `*select-pseudo-frame-hook*`

- Variable / package: editor / 定義: pframe.l

```text
フレームを選択、移動、および新規作成したときに実行されます。
すべてのフレームに対して適用されます。

フレームごとに違う動作をさせたい場合は、
フレーム構造体のスロット selected-fn に関数を設定します。
```

関連: `new-pseudo-frame`, `select-pseudo-frame`, `ed::pseudo-frame`

## `*status-bar-format*`

- Variable / package: editor / 定義: page.l

```text
ステータスバーに表示する情報を指定する文字列です。文字の並び順に表示されます。

  t     時計
  p     カーソル位置
  c     カーソル位置の文字コード(内部コード)
  u     カーソル位置の文字コード(ユニコード)
  T     時計（曜日入り）

使用例：
  (setq *status-bar-format* "cupT")
```

## `count-windows`

- Function / package: editor / 定義: window.l
- 呼び出し: `count-windows &optional MINIBUF`

```text
ウィンドウの数を返します。

  MINIBUF : フラグはミニバッファウィンドウを数えるかどうかです。
        t       ミニバッファを数える。
        nil     ミニバッファを数えない。
```

## `current-window-configuration`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-window-configuration`

```text
現在のウィンドウの状態を返します。
ここでいうウィンドウの状態とは、画面の分割状態、表示されているバッファを
指します。ウィンドウの状態はset-window-configurationで設定することが出来
ます。

使用例：
  ;;; 画面の状態を元に戻す。
  (split-window)
  => t
  (setq winconf (current-window-configuration))
  => (window-configuration #<window> ......  
  (delete-other-windows)
  => t
  (set-window-configuration winconf)
```

関連: `set-window-configuration`

## `delete-all-pseudo-frames`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `delete-all-pseudo-frames &optional (CREATE-NEW t)`

```text
フレームをすべて削除します。

  CREATE-NEW : すべて削除した後に、新しいフレームを作るかどうか
        t        作る
        nil      作らない

各フレームごとにスロット deleted-fn に登録された関数が実行されます。
```

関連: `delete-pseudo-frame`

## `delete-other-windows`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-other-windows`

```text
現在カーソルがあるウィンドウ以外のウィンドウを削除します。 [C-x 1]
ただし、現在カーソルがあるウィンドウがミニバッファウィンドウの場合は他の
ウィンドウを削除しません。

戻り値：
  t     ウィンドウの削除に関わらず t 固定
```

関連: `delete-window`

## `delete-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `delete-pseudo-frame &optional (FRAME ed::*current-pseudo-frame*)`

```text
フレームを削除します。[C-x 6 0]
最後のひとつを削除した場合、即座に新しいフレームが作られます。

  FRAME : 削除するフレーム

FRAME のスロット deleted-fn に関数が設定されている場合、FRAME が削除される前に funcall されます。
```

関連: `new-pseudo-frame`, `delete-all-pseudo-frames`

## `delete-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-window`

```text
現在カーソルがあるウィンドウを削除します。 [C-x 0]
ミニバッファウィンドウは削除できません。
また、ミニバッファウィンドウ以外のウィンドウが現在のウィンドウのみの場合
は simple-error を発生します。

ウィンドウ削除後は、以下の条件のうち、最も優先度の高い条件を満たすミニ
バッファウィンドウ以外のウィンドウの領域を広げ、そのウィンドウを
set-window します。
  1. 削除ウィンドウの左辺と、右辺が一致したウィンドウ
  2. 削除ウィンドウの右辺と、左辺が一致したウィンドウ
  3. 削除ウィンドウの上辺と、底辺が一致したウィンドウ
  4. 削除ウィンドウの底辺と、上辺が一致したウィンドウ

戻り値：
  t     ウィンドウ削除成功
  nil   ウィンドウ削除失敗

補足：
  xyzzy 0.2.2.233 では (delete-buffer X) に対して (deleted-buffer-p X)
  が存在しますが、(delete-window X) に対して (deleted-window-p X) は存在
  しません。
  ;;; deleted-buffer-p を模した deleted-window-p の定義
  (in-package "editor")
  (export '(deleted-window-p))
  (defun deleted-window-p (window)
    (unless (windowp window)
      (error 'lisp::type-error :datum window :expected-type 'window))
    (handler-case
        (progn
          (window-buffer window)
          t)
      (program-error (c)
        nil)))
補足2：
  xyzzy 0.2.2.236 で deleted-window-p が追加されました。
```

関連: `set-window`, `delete-other-windows`, `minibuffer-window-p`, `delete-buffer`, `deleted-buffer-p`

## `deleted-window-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `deleted-window-p WINDOW`

```text
ウィンドウが削除されているかどうかを調べます。
WINDOWにはウィンドウ型のものしか指定できません。

  t   指定されたウィンドウは既に削除されています。
  nil 指定されたウィンドウは未だ削除されていません。

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `delete-window`

## `ed::pseudo-frame`

- Struct / package: editor / 定義: pframe.l

```text
フレームは pseudo-frame という構造体として、pframe.l 内で定義されています。
この構造体は以下のようなスロットを持っています。
  name        : フレームの名前
  winconf     : このフレームにおけるウィンドウの状態
  save-p      : セッション保存時にこのフレームを保存するかどうか
  selected-fn : このフレームを選択したときに実行される関数
  deleted-fn  : このフレームを削除するときに実行される関数

フレームを新しく作成するには new-pseudo-frame を使えばよく、
winconf 以外のスロットは new-pseudo-frame の引数として指定できます。
winconf はフレーム作成時や移動時に自動的に設定されます。

selected-fn および delete-fn に設定された関数は funcall によって呼び出されます。
*select-pseudo-frame-hook* と異なり、フレームごとに異なる関数を割り当てることができます。
また、selected-fn の関数は *select-pseudo-frame-hook* より先に実行されます。
```

関連: `new-pseudo-frame`, `select-pseudo-frame`, `delete-pseudo-frame`, `*select-pseudo-frame-hook*`, `http://xyzzy.s53.xrea.com/qanda/wiki.cgi?p=e1d59f7af8a5ebd071340560b6ed41a2`, `http://xyzzy.s53.xrea.com/wiki/index.php?QuickTour%2Fframe`

## `enlarge-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `enlarge-window &optional EXTEND VERTICAL`

```text
ウィンドウの行数・桁数を変更します。[C-x z], [C-x ^]
VERTICALを指定しない場合には行数を変更します。

  EXTEND   : 大きくする行数・桁数を指定します。負数を指定すると小さくなります。
  VERTICAL : 桁・行のどちらを設定するか指定します。
        t       桁数を変更する。
        nil     行数を変更する。

使用例：
  ;;; ウィンドウを変更してみる。
  (enlarge-window 2 t)  => t
  (enlarge-window 100)  => 変更できません
```

関連: `shrink-window`, `enlarge-window-horizontally`

## `enlarge-window-horizontally`

- Function / package: editor / 定義: window.l
- 呼び出し: `enlarge-window-horizontally &optional (ARG 1)`

```text
カーソルのあるウィンドウの幅を大きくします。[C-x }]

使用例：
  ;;; listerのマージンからウィンドウの幅を引く場合
  (enlarge-window-horizontally (- *lister-margin* (window-width)))
```

関連: `shrink-window-horizontally`, `enlarge-window`

## `find-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `find-pseudo-frame NAME`

```text
現在のフレームの中から名前が NAME であるものを探して返します。
```

関連: `select-pseudo-frame`, `selected-pseudo-frame`

## `get-buffer-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-buffer-window BUFFER &optional START-WINDOW`

```text
バッファを表示しているウィンドウを返します。同じバッファが複数のウィンド
ウに表示されていますので、START-WINDOWから順番に探し始めます。
現在表示されてないバッファはnilが返ります。

  BUFFER       : 検索するバッファ
  START-WINDOW : 検索をし始めるウィンドウ

使用例：
  ;;; window-bufferも使ってみる。
  (selected-buffer)
  => #<buffer: *scratch*>
  (window-buffer (get-buffer-window (selected-buffer)))
  => #<buffer: *scratch*>
```

関連: `window-buffer`

## `get-local-window-flags`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-local-window-flags WINDOW-OR-BUFFER`

```text
ローカルに設定されたウィンドウフラグの状態を多値で返します。

　 WINDOW-OR-BUFFER : バッファかウィンドウのいずれかを指定します。

戻り値
   一つ目はローカルに t に設定されたフラグ
   二つ目はローカルに nil に設定されたフラグ

使用例 :
  (progn
    (set-local-window-flags (selected-window) *window-flag-line-number* t)
    (set-local-window-flags (selected-window) *window-flag-ruler* t)
    (set-local-window-flags (selected-window) *window-flag-vscroll-bar* nil)
    (get-local-window-flags (selected-window)))
  =>
  3
  32
```

関連: `set-local-window-flags`

## `get-window-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-window-line &optional WINDOW`

```text
ウィンドウでのカーソルの表示行を返します。
ウィンドウ内の一番上の表示行にカーソルがある場合 0 を返します。
現在のカーソル位置を正確に得るため、行数を取得する前に画面表示
を更新します。

  WINDOW : ウィンドウを指定します。
           指定しなければ (selected-window) が使われます。
```

関連: `window-lines`, `refresh-screen`

## `get-window-start-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-window-start-line &optional WINDOW`

```text
ウィンドウの先頭行が表示行で何行目かを返します。

補足：
  どういった場合に起こりえるのか不明ですが、ウィンドウにバッファが関連付
  いていない場合は nil を返します。
```

関連: `current-virtual-line-number`, `current-line-number`

## `mode-line-format`

- BufferLocal / package: editor

```text
モードラインのフォーマットを設定します。

使用例：
  (setq mode-line-format "--%*- %b (%M) [%k:%l] %P %f")

パラメタ：
  %*    変更あり          : **
        書込禁止          : %-
        変更あり・書込禁止: %*
        それ以外          : --
  %#*   変更あり: *
        変更なし: (空白)
  %r    書込可  : (空白)
        書込禁止: %
  %#r   書込可        : (空白)
        書込禁止      : %
        不完全バッファ: #
  %p    プログラム名
  %v    バージョン
  %$    プロセスID
  %h    ホスト名
  %#h   @ホスト名
  %b    バッファ名
  %f    File: ファイル名
  %#f   ファイル名
  %F    File: ファイル名。ファイル名がなければバッファ名
  %#F   ファイル名。ファイル名がなければバッファ名
  %M    モード(マイナーモード含む)
  %m    モード
  %k    エンコーディング
  %l    改行コード
  %i    IMEの状態
  %P    カーソル位置
  %/    カーソル位置がバッファ全体の何%の位置にあるか
  %!    xyzzyが管理者として実行されている場合は "管理者: "

備考：
  タイトルバーのフォーマットとほぼ同様ですが、
  %i, %P, %/ はモードラインのフォーマットでしか設定できません。

  %/, %$ は xyzzy 0.2.2.236 から利用可能です。
  %! は xyzzy 0.2.2.247 から利用可能です。
```

関連: `update-mode-line`, `title-bar-format`

## `new-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `new-pseudo-frame NAME &optional SAVE-P SELECTED-FN DELETED-FN`

```text
新しいフレームを作って返します。[C-x 6 2]

  NAME        : フレームの名前
  SAVE-P      : セッション保存時にこのフレームを保存するかどうか
  SELECTED-FN : このフレームを選択した時に実行される関数
  DELETED-FN  : このフレームを削除した時に実行される関数

フレームは構造体として定義されており、これらの引数はそれぞれ
同名のスロットに設定されます。

インタラクティブに呼んだ場合 NAME は自動的に割り振られ、SAVE-P は t に設定されます。
前置引数をつけて呼べば NAME を対話的に入力できます。
```

関連: `select-pseudo-frame`, `delete-pseudo-frame`, `*select-pseudo-frame-hook*`

## `next-page`

- Function / package: editor / 定義: page.l
- 呼び出し: `next-page &optional (ARG 1)`

```text
指定ページ分画面を下スクロールします。[C-v], [PageDown]
*page-scroll-half-window* が non nil なら半画面ずつスクロールします。
```

関連: `previous-page`, `*page-scroll-half-window*`, `*page-scroll-keep-window-position*`, `*next-screen-context-lines*`

## `next-pseudo-frame`

- Function / package: editor
- 呼び出し: `next-pseudo-frame`

```text
次のフレームに移動します。[C-x 6 o]
other-pseudo-frame の別名です。
```

関連: `previous-pseudo-frame`, `other-pseudo-frame`, `switch-pseudo-frame`, `*next-pseudo-frame-in-tab-order*`

## `next-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `next-window WINDOW &optional MINIBUF`

```text
WINDOW の次のウィンドウを返します。

  MINIBUF : ミニバッファウィンドウを候補に入れるか
       nil    無視する
   non-nil    候補に入れる
```

関連: `previous-window`, `set-window`

## `other-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `other-pseudo-frame`

```text
次のフレームに移動します。[C-x 6 o]
```

関連: `previous-pseudo-frame`, `next-pseudo-frame`, `switch-pseudo-frame`, `*next-pseudo-frame-in-tab-order*`

## `other-window`

- Function / package: editor / 定義: window.l
- 呼び出し: `other-window &optional (ARG 1 F) NO-ERROR`

```text
分割されたウィンドウの中を移動します。[C-x o]

  ARG      : ARG番目のウィンドウに移動します。
             負数であれば、ARG番前のウィンドウに移動します。
  NO-ERROR : (count-windows)以上の数値を指定した場合の動作を制御します。
        nil     (count-windows)以上の数値を指定するとエラーを発生します。
        t       (count-windows)以上の数値を指定してもtを返す。
```

関連: `move-previous-window`, `selected-window`, `count-windows`

## `pop-to-buffer`

- Function / package: editor / 定義: window.l
- 呼び出し: `pop-to-buffer BUFFER &optional POPUP-WINDOWS VERT-P`

```text
指定されたバッファを表示します。POPUP-WINDOWS が指定された場合画面を分割
してバッファを表示します。ウィンドウが既に分割されていたら、新たに分割せ
ずにそのウィンドウに移動し表示します。

表示幅が指定された場合には、縦分割が指定されていない場合、モード行を表示
している状態で、およそ指定された数値分の行数が表示できる大きさのウィンド
ウができます。
縦分割が指定された場合には、上下ではなく左右に分割し、行番号を表示してい
ない状態で、およそ指定された数値分の列数が表示できる大きさのウインドウが
できます。

  BUFFER        : バッファ、または、バッファの名前を指定します。
  POPUP-WINDOWS : 分割する行数／列数を指定します。
        t             ニ分割します。
        整数          指定行数／列数で分割します。
        nil           ウィンドウが分割されていない場合でも新たに
                      分割しません。
  VERT-P        : 縦方向に分割します。
        non-nil       左右にニ分割します。
        nil           上下にニ分割します。

使用例：
  ;;; den8の場合
  (defvar *den8-summary-window-ratio* 1/4)

  (defun den8-viewer ()
    (let ((view (switch-to-buffer "*Den8 View*")))     ; Viewを作る
      (let ((sum (switch-to-buffer "*Den8 Summary*"))) ; Summaryを作る
           <初期化・省略> ))
    (delete-other-windows)        ; 自分以外の全部のウインドウを消す
    (den8-popup-summary-buffer))  ; ２分割して、上下にサマリと内容を表示

  (defun den8-popup-summary-buffer ()
    (pop-to-buffer den8-summary-buffer
       (truncate (* (screen-height) *den8-summary-window-ratio*))))
```

関連: `split-window`, `split-window-vertically`

## `pos-not-visible-in-window-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `pos-not-visible-in-window-p POINT &optional WINDOW`

```text
指定されたポイントPOINTがウィンドウの表示範囲内にないかを返します。

  t     表示範囲内にない。
  nil   表示範囲内にある。
```

関連: `pos-visible-in-window-p`

## `pos-visible-in-window-p`

- Function / package: editor / 定義: window.l
- 呼び出し: `pos-visible-in-window-p POINT &optional WINDOW`

```text
ポイントがウィンドウの表示範囲内にあるかを返します。

  t     表示範囲内にある。
  nil   表示範囲内にない。
```

関連: `pos-not-visible-in-window-p`

## `previous-page`

- Function / package: editor / 定義: page.l
- 呼び出し: `previous-page`

```text
1ページ分画面を上スクロールします。[ESC v], [PageUp], [C-z]
*page-scroll-half-window* が non nil なら半画面ずつスクロールします。
```

関連: `next-page`

## `previous-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `previous-pseudo-frame`

```text
前のフレームに移動します。[C-x 6 p]
```

関連: `next-pseudo-frame`, `other-pseudo-frame`, `switch-pseudo-frame`, `*next-pseudo-frame-in-tab-order*`

## `previous-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `previous-window WINDOW &optional MINIBUF`

```text
WINDOW の前のウィンドウを返します。
  
  MINIBUF : ミニバッファウィンドウを候補に入れるか
       nil    無視する
   non-nil    候補に入れる
```

関連: `next-window`, `set-window`

## `pseudo-frame-selector`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `pseudo-frame-selector`

```text
ダイアログからフレームを選択します。
```

関連: `switch-pseudo-frame`, `select-pseudo-frame`

## `recenter`

- Function / package: editor / 定義: window.l
- 呼び出し: `recenter &optional ARG`

```text
バッファをスクロールして画面上の表示位置を調整します。[C-l]
引数を指定しなければ現在行が画面の中央に位置します。
(recenter 0) で現在行がウインドウの一番上に来ます。

  ARG : 調整後のカーソル位置
   nil          画面中央の行に移動。
   数字の場合   正の数なら、ウィンドウの上からの行数。
                負の数なら、ウィンドウの下からの行数。

戻り値
  カーソルが移動した時はt
            移動しなかった時はnil
```

## `rename-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `rename-pseudo-frame NAME`

```text
現在選択しているフレームの名前を NAME に変更します。
```

## `restore-window-configuration-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `restore-window-configuration-register R`

```text
レジスタ R に保存したウィンドウ状態に戻します。[C-x r c]
R に window-configuration が入っていないとエラーになります。
```

関連: `save-window-configuration-to-register`

## `save-window-configuration-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `save-window-configuration-to-register R`

```text
レジスタ R に現在のウィンドウの状態を保存します。[C-x r w]
中身は current-window-configuration で得られるものと同じです。
保存した状態に戻すには restore-window-configuration-register を使います。
```

関連: `restore-window-configuration-register`, `current-window-configuration`

## `save-window-excursion`

- Special Form / package: editor / 定義: builtin.l
- 呼び出し: `save-window-excursion {FORM}*`

```text
処理の前後でカレントウィンドウとウィンドウのレイアウトの状態を保存します。
```

関連: `save-excursion`, `with-selected-window`

## `screen-height`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `screen-height`

```text
xyzzyのウィンドウ全体の高さが何行になるのかを返します。
```

関連: `screen-width`, `window-height`

## `screen-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `screen-width`

```text
xyzzyのウィンドウ全体の幅が何桁になるのかを返します。
```

関連: `screen-height`, `window-width`

## `scroll-down-both-window`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-down-both-window`

```text
現在のウィンドウと、次のウィンドウを同時に下スクロールします。[S-C-Up]
```

関連: `scroll-up-both-window`, `scroll-down-other-window`

## `scroll-down-other-window`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-down-other-window &optional (ARG 1)`

```text
次のウィンドウを指定行数分上スクロールします。
```

関連: `scroll-window`, `scroll-down-both-window`

## `scroll-left`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-left &optional ARG`

```text
ウィンドウを指定桁数分、左にスクロールします。[C-x <]
負の数値を指定すると逆方向にスクロールします。
```

関連: `scroll-right`, `scroll-window-horizontally`, `scroll-window`

## `scroll-other-window`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-other-window &optional ARG`

```text
次のウィンドウをスクロールします。[ESC C-v]
ARG が nil なら下スクロールし、 non-nil であれば上スクロールします。
```

関連: `scroll-window`, `scroll-up-other-window`, `scroll-down-other-window`

## `scroll-right`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-right &optional ARG`

```text
ウィンドウを指定桁数分、右にスクロールします。[C-x >]
負の数値を指定すると逆方向にスクロールします。
```

関連: `scroll-left`, `scroll-window-horizontally`, `scroll-window`

## `scroll-up-both-window`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-up-both-window`

```text
現在のウィンドウと、次のウィンドウを同時に上スクロールします。[S-C-Down]
```

関連: `scroll-down-both-window`, `scroll-up-other-window`

## `scroll-up-other-window`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `scroll-up-other-window &optional (ARG 1)`

```text
次のウィンドウを指定行数分スクロールします。
```

関連: `scroll-window`, `scroll-up-both-window`, `scroll-other-window`

## `scroll-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `scroll-window ARG`

```text
ウィンドウを指定行数分スクロールします。
負の数値を指定すると逆方向にスクロールします。

使用例：
  ;;; 0.3秒おきに1行ずつスクロールさせる。
  (dotimes (i 4) (scroll-window 1) (sit-for .3))
  => nil
```

関連: `scroll-other-window`, `scroll-window-horizontally`

## `scroll-window-horizontally`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `scroll-window-horizontally ARG`

```text
ウィンドウを指定桁数分、右にスクロールします。
負の数値を指定すると逆方向にスクロールします。
```

関連: `scroll-window`

## `select-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `select-pseudo-frame FRAME`

```text
フレーム FRAME を選択します。

FRAME のスロット selected-fn に関数が設定されている場合、それを funcall します。
最後に *select-pseudo-frame-hook* を実行します。
```

関連: `switch-pseudo-frame`, `pseudo-frame-selector`, `find-pseudo-frame`, `new-pseudo-frame`, `*select-pseudo-frame-hook*`

## `selected-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `selected-pseudo-frame`

```text
現在選択しているフレームを返します。
```

関連: `find-pseudo-frame`

## `selected-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `selected-window`

```text
現在アクティブなウィンドウを返します。

使用例：
  ;;; 現在のウィンドウを返してみる。
  (selected-window)
  => #<window 54137832>
```

関連: `set-window`

## `set-default-fold-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-default-fold-width WIDTH`

```text
テキストの折り返し方法を制御します。[ツール]-[共通設定]-[表示]の"テキス
トの折り返し"と同じで、全体に影響します。

  WIDTH : 折り返しの方法を指定します。
        nil     折り返しません。
        t       ウィンドウの幅で折り返します。
        数値    折り返し位置を指定します。
```

## `set-local-window-flags`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-local-window-flags WINDOW-OR-BUFFER FLAGS ON-OR-OFF`

```text
ウィンドウもしくはバッファの各種表示を制御します。
ほぼ全ての項目で、ウィンドウでもバッファでも設定可能です。
バッファの設定 > ウィンドウの設定 > 全体の設定
の順番で指定が優先されます。

 BUFFER-OR-WINDOW : バッファかウィンドウのいずれかを指定します。
 FLAGS            : 下のフラグのどれかを指定します。
        *window-flag-alternate-vscroll-bar* バッファ全体表示できている
                                            場合の垂直スクロールバー
        *window-flag-cursor-line*           行カーソル
        *window-flag-eof*                   EOF
        *window-flag-fold-line*             折り返しライン
        *window-flag-fold-mark*             折り返し
        *window-flag-full-width-space*      全角スペース
        *window-flag-half-width-space*      半角スペース
        *window-flag-hscroll-bar*           水平スクロールバー
        *window-flag-just-inverse*          （詳細不明）
        *window-flag-line-number*           行番号
        *window-flag-mode-line*             モード行
        *window-flag-newline*               改行
        *window-flag-ruler*                 ルーラ
        *window-flag-scrolling*             描画位置の計算でジャンプスクロール
        *window-flag-tab*                   タブ
        *window-flag-vscroll-bar*           垂直スクロールバー
        *window-flag-zenkaku-space*         全角スペース
                                            (*window-flag-full-width-space*と同じ)
 ON-OR-OFF       : 変更後の値を設定します。
        t        フラグをonにします。
        nil      フラグをoffにします。
        それ以外 デフォルトに戻します。

使用例：
  ;;; カレントバッファの行番号を表示しないようにする。
  (set-local-window-flags (selected-buffer)
                          *window-flag-line-number* nil)
  => t
```

関連: `set-window-flags`, `get-local-window-flags`

## `set-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-window WINDOW`

```text
ウィンドウを変更します。
selected-window や get-buffer-window で取得したウィンドウに移動します。

  WINDOW：移動先のウィンドウ

使用例：
  ;;; *scratch*が表示されていれば移動する。
  (setq win (get-buffer-window (find-buffer "*scratch*")))
  => #<window 48436204>
  (if win (set-window win))
  => t
  (selected-buffer)
  => #<buffer: *scratch*>
```

関連: `selected-window`, `get-buffer-window`, `next-window`, `previous-window`

## `set-window-configuration`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-window-configuration CONF`

```text
取得しておいたウィンドウの状態に戻します。

  CONF：current-window-configurationで取得したウィンドウの状態
```

関連: `current-window-configuration`

## `set-window-flags`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-window-flags FLAGS`

```text
ウィンドウ全体もしくはバッファ全体の各種表示を制御します。

 FLAGS : 下記のフラグのビット和を指定します。
        *window-flag-alternate-vscroll-bar* バッファ全体表示できている
                                            場合の垂直スクロールバー
        *window-flag-cursor-line*           行カーソル
        *window-flag-eof*                   EOF
        *window-flag-fold-line*             折り返しライン
        *window-flag-fold-mark*             折り返し
        *window-flag-full-width-space*      全角スペース
        *window-flag-half-width-space*      半角スペース
        *window-flag-hscroll-bar*           水平スクロールバー
        *window-flag-just-inverse*          （詳細不明）
        *window-flag-line-number*           行番号
        *window-flag-mode-line*             モード行
        *window-flag-newline*               改行
        *window-flag-ruler*                 ルーラ
        *window-flag-scrolling*             描画位置の計算でジャンプスクロール
        *window-flag-tab*                   タブ
        *window-flag-vscroll-bar*           垂直スクロールバー
        *window-flag-zenkaku-space*         全角スペース
                                            (*window-flag-full-width-space*と同じ)
```

関連: `get-window-flags`, `set-local-window-flags`

## `shrink-window`

- Function / package: editor / 定義: window.l
- 呼び出し: `shrink-window &optional (ARG 1)`

```text
カーソルのあるウィンドウの高さを小さくします。  [C-x C-z]
```

関連: `shrink-window-horizontally`, `enlarge-window`

## `shrink-window-horizontally`

- Function / package: editor
- 呼び出し: `shrink-window-horizontally &optional (ARG 1)`

```text
カーソルのあるウィンドウの幅を小さくします。[C-x {]

使用例：
  ;;; listerのマージンからウィンドウの幅を引く場合
  (shrink-window-horizontally (- (window-width) *lister-margin*))
```

関連: `enlarge-window-horizontally`, `shrink-window`

## `split-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `split-window &optional ARG VERTICAL`

```text
ウィンドウを分割します。分割サイズと分割方向が指定可能です。[C-x 2]

  ARG      : 分割サイズを指定します。
  VERTICAL : 分割方向を指定します。
        t       左右に分割します。
        nil     上下に分割します。

分割後にカレントになるウィンドウには注意が必要です。

  (split-window 20 t)
  => +20-+---------+    
     |   |         |
     +↑-+---------+
      こちらにカーソルがくる
 
  (split-window -20 t)
  => +---------+20-+
     |         |   |
     +---------+↑-+
                こちらにカーソルがくる

  (split-window 20 nil)
  => +-------------+    
     |             ←こちらにカーソルがくる
     +-------------+    
     +-------------+    
      
  (split-window -20 nil)
  => +-------------+    
     +-------------+    
     |             ←こちらにカーソルがくる
     +-------------+
```

関連: `split-window-vertically`, `pop-to-buffer`

## `split-window-vertically`

- Function / package: editor / 定義: window.l
- 呼び出し: `split-window-vertically &optional ARG`

```text
ウィンドウを左右に分割します。[C-x 5]
```

関連: `split-window`

## `switch-pseudo-frame`

- Function / package: editor / 定義: pframe.l
- 呼び出し: `switch-pseudo-frame NAME`

```text
対話的にフレームを選択します。
```

関連: `select-pseudo-frame`, `pseudo-frame-selector`

## `window-columns`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-columns &optional WINDOW`

```text
ウィンドウの文字を表示可能な領域の幅をキャラクタ単位で返します。
window-width が対象とする幅から、必要に応じて「行番号」表示領域、「折り
返し」マーク表示領域を除いた幅を計算対象とします。
キャラクタ幅に満たない幅については切り捨てますが、返す最小値は 1 です。

補足：
  具体的には、window-width の返す値から、「行番号」表示時は、行番号表示
  桁数 (xyzzy 0.2.2.233 では 6) ＋境界線分 (1) が引かれます。
  さらに、「折り返し」表示かつ、テキストの折り返しが「ウィンドウ幅」の場
  合には、「折り返し」マーク分 (1) が引かれます。
```

関連: `window-width`, `window-lines`, `window-height`

## `window-coordinate`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-coordinate &optional WINDOW`

```text
指定されたウィンドウの座標をリストで返します。
(左端のx座標 左端のy座標 右端のx座標 右端のy座標)

座標軸は左上が (0 0) で右下にいくほど値が大きくなり、
単位はピクセルです。

使用例:
  (window-coordinate)
  => (0 0 693 636)
```

関連: `window-width`, `window-height`

## `window-height`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-height &optional WINDOW`

```text
ウィンドウの高さを行単位で返します。
部分的でなく完全に表示可能な行の数を返しますが、返す最小値は 1 です。
xyzzy 0.2.2.232 では内部的には window-lines と完全に同一定義です。

使用例：
  ;;; 現在のウィンドウを縦に半分にする。
  (split-window (- (floor (window-height) 2) 2))
  => t

補足：
  xyzzy 0.2.2.232 では内部的には window-lines と完全に同一定義ですが、
  window-height と window-lines は同一オブジェクトではありません。
  (eq #'window-height #'window-lines) => nil
```

関連: `window-lines`, `window-width`, `window-columns`, `screen-height`

## `window-lines`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-lines &optional WINDOW`

```text
ウィンドウの表示可能行数を返します。
部分的でなく完全に表示可能な行の数を返しますが、返す最小値は 1 です。
xyzzy 0.2.2.232 では内部的には window-height と完全に同一定義です。

使用例：
  (window-lines)
  => 18

補足：
  xyzzy 0.2.2.232 では内部的には window-height と完全に同一定義ですが、
  window-lines と window-height は同一オブジェクトではありません。
  (eq #'window-lines #'window-height) => nil
```

関連: `window-height`, `window-width`, `window-columns`, `get-window-line`

## `window-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `window-width &optional WINDOW`

```text
ウィンドウの幅をキャラクタ単位で返します。
文字を表示可能な領域の幅ではなく、「行番号」表示領域、「折り返しマーク」
表示領域を含んだ領域についての幅を返します。
キャラクタ幅に満たない幅については切り捨てますが、返す最小値は 1 です。
```

関連: `window-columns`, `window-height`, `window-lines`, `screen-width`

## `with-selected-window`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-selected-window &body BODY`

```text
BODY の前後でカレントウィンドウを保存します。
すなわち、BODY 実行中にウィンドウを移動しても、実行後に元のウィンドウに戻ります。
```

関連: `set-window`, `save-window-excursion`
