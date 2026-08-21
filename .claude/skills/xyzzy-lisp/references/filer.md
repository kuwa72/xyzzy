# ファイラ (filer)

reference/reference.xml から自動生成。73 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*filer-chdir-hook*`

- Variable / package: editor

```text
（ファイラでディレクトリが変更されたりすると実行されます。用途不明）
```

## `*filer-chdir-primary-p*`

- Variable / package: editor

```text
（詳細不明）
```

## `*filer-click-toggle-marks-always*`

- Variable / package: editor

```text
nilなら、ファイラで左クリックしたとき、その位置にカーソルがある場合の
みマークを反転します。
non-nil なら、カーソルの移動とマークの反転の両方を同時に行います。
デフォルトは t です。
```

## `*filer-directories*`

- Variable / package: editor / 定義: filer.l

```text
ファイラのジャンプ用のディレクトリを連想リストで設定します。

使用例：
  (setq *filer-directories*
      '((" [デスクトップ]" . "c:/windows/デスクトップ")
        (" [スプール]" . "c:/spool")))
```

関連: `filer`

## `*filer-drag-and-drop-helper`

- Function / package: editor / 定義: filer.l
- 呼び出し: `*filer-drag-and-drop-helper EFFECT FILES SRC DEST`

```text
（詳細不明）
```

## `*filer-dual-window*`

- Variable / package: editor

```text
ミニバッファなどでディレクトリを入力した時に立ち上がるファイラを選択し
ます。 nil なら一画面ファイラ、non-nil なら二画面ファイラが起動します。
デフォルトは nil です。
```

## `*filer-eat-esc*`

- Variable / package: editor

```text
nilなら、モードレスファイラでESCを押しても閉じません。
デフォルトは t です。
```

## `*filer-echo-filename*`

- Variable / package: editor

```text
（途中）
ファイラのステータスウィンドウへのファイル名の表示を制御します。
ファイル名の表示は暇なときに行なっているようです。
  non-nil  暇なときに表示する
  nil      表示しない
```

関連: `filer`

## `*filer-format-comma*`

- Variable / package: editor

```text
non-nilなら、ファイルサイズをカンマ区切りで表示します。
[共通設定] - [ファイラ] - [ファイルサイズをカンマ区切りで表示(C)] で値を
指定することができます。
```

## `*filer-guide-text*`

- Variable / package: editor

```text
ファイラ下部に表示されるガイドテキストを設定します。

使用例：
  (setq *filer-guide-text*
      '("(A)ttribute  (B)yteCompile  (C)opy  (D)elete  (E)xtract  (F)ind"
        "(G)o  (J)ump  m(K)dir  <L>Cd  (M)ove  re(N)ame"))
```

関連: `filer`

## `*filer-last-command-char*`

- Variable / package: editor

```text
ファイラにてコマンドを実行した時に最後に入力された文字を示します。
```

## `*filer-last-file-mask*`

- Variable / package: editor

```text
一画面ファイラの初期のファイルマスクをリストで設定します。
```

関連: `*filer-primary-file-mask*`, `*filer-secondary-file-mask*`

## `*filer-left-window-p*`

- Variable / package: editor

```text
二画面ファイラを閉じたとき、どちらのウィンドウがアクティブだったかが保存
されます。ファイラ未起動時の値は t です。

  nil     : 右側のウィンドウ
  non-nil : 左側のウィンドウ
```

## `*filer-mark-file-size-unit*`

- Variable / package: editor

```text
ファイラのマークファイルの合計サイズの単位を指定します。
#\B, #\K, #\M, #\G, #\Tの何れかを指定可能です。ただし、例えば#\K
が設定されたとき、サイズが1K未満ならバイト単位になります。デフォ
ルトではnilに設定されています。

使用例：
  (setq *filer-mark-file-size-unit* #\M)
```

関連: `filer`

## `*filer-modal*`

- Variable / package: editor / 定義: filer.l

```text
ファイラの動作を指定します。

モーダルの場合には、ファイラはエディタとは同期的に動作します。
ファイラ起動中はエディタでの編集は不能です。
モードレスの場合には、ファイラはエディタとは非同期に動作します。
ファイラ起動中にエディタでの編集が可能です。

  t   モーダルで動作させます
  nil モードレスで動作させます
```

関連: `filer`

## `*filer-path-masks*`

- Variable / package: editor / 定義: filer.l

```text
ファイラのファイルマスクを設定します。

使用例：
  (pushnew '("Microsoft" "*.doc" "*.xls" "*.ppt" "*.sys" "*.bat" "*.ini")
           *filer-path-masks* :test 'equal)
```

関連: `filer`

## `*filer-primary-directory*`

- Variable / package: editor

```text
二画面ファイラのアクティブな方のディレクトリを示します。
右側か左側かは *filer-left-window-p* の値によって決まります。
ファイラ未起動時は左側のディレクトリを指定できます。

使用例：
  ; [xyzzy:07218]
  ; 常にカレントディレクトリからファイラを起動する。
  (defun foo ()
    (interactive)
    (let ((*filer-primary-directory* nil)
          (*filer-secondary-directory* nil))
      (open-filer)))
```

関連: `*filer-secondary-directory*`

## `*filer-primary-file-mask*`

- Variable / package: editor

```text
ファイラ左側の初期のファイルマスクをリストで設定します。

使用例：
  (setq *filer-primary-file-mask* '("*"))
```

関連: `filer`, `*filer-secondary-file-mask*`

## `*filer-retrieve-icon*`

- Variable / package: editor / 定義: filer.l

```text
non-nil のとき、ファイラでファイルタイプに応じたアイコンを表示します。
[共通設定] - [ファイラ] - [アイコンをファイルから取ってくる(I)] で値を指
定することができます。
```

## `*filer-secondary-directory*`

- Variable / package: editor

```text
二画面ファイラのアクティブでない方のディレクトリを示します。
右側か左側かは *filer-left-window-p* の値によって決まります。
ファイラ未起動時は右側のディレクトリを指定できます。
```

関連: `*filer-primary-directory*`

## `*filer-secondary-file-mask*`

- Variable / package: editor

```text
ファイラ右側の初期のファイルマスクをリストで設定します。

使用例：
  (setq *filer-secondary-file-mask* '("*"))
```

関連: `*filer-primary-file-mask*`, `filer`

## `*filer-show-hidden-files*`

- Variable / package: editor / 定義: filer.l

```text
ファイラで隠しファイルを表示するかどうかを設定します。
  non-nil  隠しファイルを表示する
  nil      隠しファイルを表示しない

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `filer`, `*filer-show-system-files*`

## `*filer-show-system-files*`

- Variable / package: editor / 定義: filer.l

```text
ファイラで保護されたオペレーティング システム ファイルを表示するかどうかを設定します。
  non-nil  保護されたオペレーティング システム ファイルを表示する
  nil      保護されたオペレーティング システム ファイルを表示しない

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `filer`, `*filer-show-hidden-files*`

## `*filer-use-recycle-bin*`

- Variable / package: editor / 定義: filer.l

```text
ファイラでファイルの削除にゴミ箱を使用するかを設定します。
  non-nil  ファイラで削除したときはゴミ箱行き
  nil      直接削除
```

関連: `filer`

## `*filer-use-shell-file-operation*`

- Variable / package: editor / 定義: filer.l

```text
ファイラでファイルの移動・コピー・削除をエクスプローラで行うかどうかを設定します。

  non-nil  ファイルの移動・コピー・削除をエクスプローラで行う
           ファイル操作の進捗状況の確認や GUI によるキャンセルができますが、
           Ctrl-g によるキャンセルはできません
  nil      ファイルの移動・コピー・削除を xyzzy で行う
           Ctrl-g によるキャンセルができます

補足：
  xyzzy 0.2.2.251 から利用可能です。
```

関連: `filer`

## `*modal-filer-save-position*`

- Variable / package: editor

```text
モーダルでファイラを動作させているときの、ファイラ終了時の動作を設定します。

  t   位置を保存します
  nil 位置を保存しません
```

関連: `*modal-filer-save-size*`

## `*modal-filer-save-size*`

- Variable / package: editor

```text
モーダルでファイラを動作させているときの、ファイラ終了時の動作を設定します。

  t   大きさを保存します
  nil 大きさを保存しません
```

関連: `filer`

## `filer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer &optional PATH ALLOW-MULTIPLE-SELECT-P CAPTION DUAL-WINDOW-P MODELESSP`

```text
ファイラを開きます。

  PATH      : ファイラが最初に表示するディレクトリを指定します。
  ALLOW-MULTIPLE-SELECT-P
            : ファイルを複数選択可能にするかどうかを指定します。
  CAPTION   : ファイラのウィンドウのタイトルを指定します。
  DUAL-WINDOW-P
            : 二画面ファイラで開くかどうかを指定します。
  MODELESSP : モードレスダイアログでファイラを開くかどうかを指定します。
              モードレスの場合には編集しつつファイラを表示できます。

選択結果を多値で返します。

  最初の戻り値はユーザが選択したファイルのリストを返します。
  次の戻り値はOKボタンを押したらt、CANCELボタンを押したらnilを返します。

使用例：
  ;;; multiple-value-bindでファイルを受け取る。
  (multiple-value-bind (files bool)
       (filer "c:/" t "title" nil)
       (when bool
         (msgbox "~{~S~%~}" files)))
  => :ok
```

関連: `*filer-primary-directory*`, `*filer-secondary-directory*`

## `filer-calc-directory-byte-size`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-calc-directory-byte-size`

```text
ファイラにて選択したディレクトリのファイルサイズの合計を計算します。
```

## `filer-calc-directory-size`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-calc-directory-size`

```text
ファイラにて選択したディレクトリのディスク使用量を計算します。
```

## `filer-cancel`

- Function / package: editor / 定義: filer.l
- 呼び出し: `filer-cancel`

```text
ファイラを閉じます。
「閉じる」ボタンや「キャンセルボタン」を押したときと同じ効果が得られます。

(defun filer-cancel ()
 (filer-close nil))
と定義されています。
```

関連: `filer-close`

## `filer-clear-all-marks`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-clear-all-marks &optional SECONDARY-WINDOW-P`

```text
ファイラにてマークを全て解除します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-close`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-close RESULT`

```text
ファイラを閉じます。

  RESULT : モーダルファイラの場合、関数filerの戻り値に影響を与えます。
           （詳細不明）
```

関連: `filer-cancel`

## `filer-context-menu`

- Function / package: editor
- 呼び出し: `filer-context-menu`

```text
ファイラにてコンテキストメニューを表示します。
```

## `filer-count-marks`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-count-marks &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにてマークされたファイルの数を返します。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します。
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-current-file-directory-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-current-file-directory-p &optional SECONDARY-WINDOW-P`

```text
ファイラにてカーソル位置のファイルがディレクトリかどうかを判定します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-current-file-dot-dot-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-current-file-dot-dot-p &optional SECONDARY-WINDOW-P`

```text
ファイラにてカーソル位置のファイルが親ディレクトリを示す ".." 
であるかどうかを判定します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-demand-reload`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-demand-reload`

```text
（詳細不明）
```

## `filer-dual-window-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-dual-window-p`

```text
ファイラが二画面ファイラかどうかを判別します。
```

## `filer-forward-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-forward-line &optional ARG SECONDARY-WINDOW-P`

```text
ファイラにてカーソルを次の行に移動します。

  ARG                : 指定行数移動します
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-forward-page`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-forward-page &optional ARG SECONDARY-WINDOW-P`

```text
ファイラにてカーソルを次のページに移動します。

  ARG                : 指定ページ数移動します
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-current-file`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-current-file &optional SECONDARY-WINDOW-P`

```text
ファイラにてカーソル位置のファイルのパスを返します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-directory &optional SECONDARY-WINDOW-P`

```text
ファイラにて現在表示しているディレクトリのフルパスを取得します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-drive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-drive &optional SECONDARY-WINDOW-P`

```text
ファイラにて現在表示しているドライブを取得します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-mark-files`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-mark-files &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにてマークされたファイルのパスをリストの形で返します。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-sort-order`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-sort-order &optional SECONDARY-WINDOW-P`

```text
ファイラにおけるファイルの表示順を返します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-get-text`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-get-text`

```text
一画面ファイラにて上部のファイル名の欄に書いてあるテキストを返します。
```

## `filer-goto-bof`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-goto-bof &optional SECONDARY-WINDOW-P`

```text
ファイラにてカーソルをウィンドウの先頭に移動します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

関連: `filer-goto-eof`

## `filer-goto-eof`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-goto-eof &optional SECONDARY-WINDOW-P`

```text
ファイラにてカーソルをウィンドウの最後に移動します。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

関連: `filer-goto-bof`

## `filer-goto-file`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-goto-file STRING &optional START REVERSE WILD-P`

```text
ファイラにてファイル名が STRING の位置にカーソルを移動します。

  STRING  : 検索するファイル名
  START   : 検索を開始する位置
     nil      先頭から
     t        現在位置から
     それ以外 現在位置の次から
  REVERSE : 探す方向
     nil      前方向
     non-nil  後方向
  WILD-P  : ワイルドカードを有効にするか
     nil      無効
     t        有効
     それ以外 有効かつ先頭一致(末尾に"*"を補う)
```

## `filer-isearch`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-isearch &optional CHAR NO-WRAP SECONDARY-WINDOW-P`

```text
ファイラにてインクリメンタルサーチによるカーソル移動を行います。

  CHAR               : 検索する文字。nil の時は入力されたキーを検索します。
  NO-WRAP            : 最後までいったら、最初に戻るかどうか
             nil         戻らない
             non-nil     戻る
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-left-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-left-window`

```text
二画面ファイラにて左側のウィンドウをアクティブにします。
```

関連: `filer-right-window`

## `filer-left-window-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-left-window-p`

```text
二画面ファイラにて現在アクティブなウィンドウが左側のウィンドウか判別します。
```

## `filer-mark`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-mark &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにてカーソル位置のファイルをマークします。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-mark-all`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-mark-all &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにて現在表示しているディレクトリにあるファイル全てをマークします。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-mark-match-files`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-mark-match-files MASK &optional SECONDARY-WINDOW-P`

```text
MASK の示す条件を満たすファイルを全てマークします。

  MASK               : マークするファイル名の条件
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-modal-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-modal-p`

```text
ファイラがモーダルか判別します。
```

## `filer-modify-column-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-modify-column-width N D &optional SECONDARY-WINDOW-P`

```text
ファイラにおけるそれぞれのカラムの幅を変えます。

  N                  : 変更するカラム
             0           ファイル名
             1           サイズ
             2           更新日時
             3           属性
  D                  : 変更量
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-read-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-read-char`

```text
ファイラにてキーボードからの入力を読み込み、文字を返します。
```

## `filer-reload`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-reload &optional MASK SECONDARY-WINDOW-P`

```text
ファイラの画面を更新し、最新の状態にします。

  MASK               : 表示するファイルの条件を指定します
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-right-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-right-window`

```text
二画面ファイラにて右側のウィンドウをアクティブにします。
```

関連: `filer-left-window`

## `filer-scroll-left`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-scroll-left &optional SECONDARY-WINDOW-P`

```text
ファイラにて左方向にスクロールします。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

関連: `filer-scroll-right`

## `filer-scroll-right`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-scroll-right &optional SECONDARY-WINDOW-P`

```text
ファイラにて右方向にスクロールします。

  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

関連: `filer-scroll-left`

## `filer-set-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-set-directory DIRECTORY &optional SECONDARY-WINDOW-P`

```text
ファイラにて表示するディレクトリを DIRECTORY に変更します。

  DIRECTORY          : ディレクトリを指定します
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-set-file-mask`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-set-file-mask MASK &optional SECONDARY-WINDOW-P`

```text
ファイラにて表示する条件を指定します。

  MASK               : 表示する条件
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-set-text`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-set-text STRING`

```text
一画面ファイラのファイル名の欄に STRING をセットします。
```

## `filer-sort`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-sort ARG &optional SECONDARY-WINDOW-P`

```text
ファイラにおけるファイルの表示順を変更します。

  ARG                : 表示順を指定します
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-subscribe-to-reload`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-subscribe-to-reload PATH &optional SUB-DIRECTORY-P`

```text
ファイラにて PATH を表示しているウィンドウを更新し、
最新の状態にします。

  PATH            : パスを指定します
  SUB-DIRECTORY-P : PATH のサブディレクトリを更新対象にするか否か
          nil         更新しない
          non-nil     更新する
```

## `filer-swap-windows`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-swap-windows`

```text
二画面ファイラにてもう一方のウィンドウへフォーカスを移します。
```

## `filer-toggle-all-marks`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-toggle-all-marks &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにて現在のディレクトリの全てのファイルについてマークされた状態と
されていない状態を反転させます。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-toggle-mark`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-toggle-mark &optional FILE-ONLY-P SECONDARY-WINDOW-P`

```text
ファイラにてカーソル位置のファイルについてマークされた状態とされていない
状態を反転させます。

  FILE-ONLY-P        : ディレクトリも対象にするか
             nil         ディレクトリも対象にします
             non-nil     ファイルだけを対象にします
  SECONDARY-WINDOW-P : 対象とするウィンドウを指定します
             nil         現在アクティブなウィンドウ
             non-nil     現在アクティブでないウィンドウ
```

## `filer-viewer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `filer-viewer`

```text
ファイラにてカーソル位置のファイルの最初の方を見ることができます。
```

## `open-filer`

- Function / package: editor / 定義: filer.l
- 呼び出し: `open-filer`

```text
ファイラを開きます。[C-c C-f]
filerのinteractive版です。
```

関連: `filer`
