# システム (system)

reference/reference.xml から自動生成。62 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*command-line-args-base-directory*`

- Variable / package: editor / 定義: estartup.l

```text
xyzzy.exeまたはxyzzycli.exeの実行ディレクトリです。
*process-command-line-hook*に渡される引数が相対パスの場合は
このディレクトリを起点にパスを解決する必要があります。

例：
  (add-hook '*process-command-line-hook*
            #'(lambda (arg)
                (ed::find-file-internal
                 (merge-pathnames arg *command-line-args-base-directory*))))

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `*process-command-line-hook*`

## `*features*`

- Variable / package: lisp

```text
実装の特徴を表すキーワードをリストとして格納しています。
#+ と #- の評価に影響します。

候補：
  :xyzzy
  :ieee-floating-point
  :win32s
  :windows-95
  :windows-98
  :windows-me
  :windows-nt
  :windows-2000
  :windows-xp
  :windows-vista
  :windows-7
  :windows-8
  :x86
  :x64
  :ia64
  :wow64

使用例：
  (+ 2 #+xyzzy 3 #+foo 4)
  => 5
  (push :foo *features*)
  => (:foo :wow64 :x64 :windows-7 :windows-vista :windows-xp :windows-2000 :windows-nt :xyzzy :ieee-floating-point)
  (+ 2 #+xyzzy 3 #+foo 4)
  => 9
  (pop *features*)
  => :foo
  (+ 2 #+xyzzy 3 #+foo 4)
  => 5

備考：
  以下の値は xyzzy 0.2.2.236 から利用可能です。
  :windows-vista
  :windows-7
  :windows-8
  :x86
  :x64
  :ia64
  :wow64
```

関連: `featurep`

## `*modules*`

- Variable / package: lisp / 定義: evalmacs.l

```text
ロードされたモジュールの一覧が格納されています。
(require "foo")で実際にモジュールを読み込むか否かは*modules*に登録されて
いるかどうかで決まります。モジュールの中で(provide "foo")すると、そのモ
ジュールが*modules*に追加されます。

使用例：
  ;;; モジュールの一覧を見てみる。
  *modules*
  => ( ... )
  (provide "foo")
  => ("foo" ... )
  *modules*
  => ("foo" ... )
```

関連: `provide`, `require`, `modulep`, `各種ロード関係の関数の違い`

## `*process-command-line-hook*`

- Variable / package: editor / 定義: estartup.l

```text
xyzzy.exeに渡されたオプション引数を判定する際に呼び出されます。
*post-startup-hook*の直前で呼び出されます。

参考：
  (run-hook-with-args-until-success
   '*process-command-line-hook* arg)
```

関連: `起動時処理フロー`, `*command-line-args-base-directory*`

## `admin-user-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `admin-user-p`

```text
xyzzyが管理者として実行されているならtを返します。

補足：
  xyzzy 0.2.2.247 から利用可能です。
```

## `copy-to-clipboard`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `copy-to-clipboard STRING`

```text
指定された文字列をクリップボードにコピーします。

  STRING : クリップボードにコピーする文字列を指定します。
```

関連: `get-clipboard-data`, `copy-region-to-clipboard`, `copy-selection-to-clipboard`, `copy-rectangle-selection-to-clipboard`, `kill-region-to-clipboard`, `kill-selection-to-clipboard`, `kill-rectangle-selection-to-clipboard`, `yank-to-clipboard`, `paste-from-clipboard`, `paste-rectangle-from-clipboard`

## `dde-execute`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dde-execute CHAN DATA`

```text
DDE EXECUTE を実行します。引数 CHAN は DDE チャンネル、DATA は相手にくら
わすコマンド文字列です。コマンドの内容は、相手のマニュアルに従ってくださ
い。dde-execute は t を返します。

  CHAN : チャンネルを指定します。
  DATA : データを指定します。

なお、DDE 関数では以下の例外が発生する可能性があります。必要であれば例外
を処理してください。

  dde-timeout        タイムアウトしました。
  dde-busy           DDE サーバが BUSY です。
  dde-low-memory     サーバ先行状態です
  dde-no-conv        DDE 対話が確立できません
  dde-not-processed  トランザクションの実行に失敗しました
  dde-server-died    サーバーが終了しました
  storage-error      メモリがありません
  dde-error          よくわかんないけど、とにかくエラーです
```

関連: `dde-poke`, `dde-request`, `dde-terminate`

## `dde-initiate`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dde-initiate SERVICE TOPIC`

```text
DDE 対話を確立します。引数 SERVICE はサービス名、 TOPIC はトピックで、
それぞれ文字列型です。なにを指定するかは通信する相手のマニュアルを
参照してください。正常に終了した場合、DDE チャンネルを返します。
以降の通信ではこのDDE チャンネルを使用してください。
```

関連: `dde-execute`, `dde-poke`, `dde-terminate`

## `dde-poke`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dde-poke CHAN ITEM DATA`

```text
DDE POKE を実行します。

  CHAN : チャンネルを指定します。
  ITEM : （詳細不明）
  DATA : データを文字列で指定します。

引数 CHAN は DDE チャンネル、DATA は相手にくらわす文字列です。文字列の内
容は、相手のマニュアルに従ってください。dde-poke は t を返します。
```

関連: `dde-execute`, `dde-request`, `dde-terminate`

## `dde-request`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dde-request CHAN DATA RESULT-TYPE`

```text
DDE REQUEST を実行します。

  CHAN        : チャンネルを指定します。
  DATA        : データを指定します。
  RESULT-TYPE : 戻り値の型を指定します。

引数 CHAN は DDE チャンネル、DATA は相手にくらわす文字列です。文字列の内
容は、相手のマニュアルに従ってください。戻り値は DDE の相手が返したもの
を返しますが、RESULT-TYPE の指定によってデータの解釈を以下のようにおこな
います。

  :text   : 通常の文字列を返します。
  :binary : 漢字などを無視して返ってきたデータをそのまま文字列で返します。
  :int8
  :int16
  :int32  : データをそれぞれ 8, 16, 32 ビット整数の配列とみなして整数のリ
            ストで返します。配列の要素が 1 のときは整数値を返します。

戻り値型の指定は、もじらの DDE で遊ぼうと思って作っただけなので、通常は
指定しなくて構いません。
```

関連: `dde-execute`, `dde-poke`, `dde-terminate`

## `dde-terminate`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dde-terminate CHAN`

```text
DDE 対話を終了します。引数 CHAN は DDE チャンネルです。正常に終了した場
合は t、すでに対話が終了していた場合は nil を返します。

  CHAN : チャンネルを指定します。
```

## `dump-xyzzy`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dump-xyzzy &optional FILENAME`

```text
ダンプファイルをFILENAMEにして作成します。
既に作成されていても上書きします。
FILENAME省略時のファイル名は？（未確認）
```

関連: `xyzzy-dumped-p`, `version-up-xyzzy`

## `etc-path`

- Function / package: editor / 定義: misc.l
- 呼び出し: `etc-path`

```text
*etc-path*を返します。
```

関連: `*etc-path*`

## `featurep`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `featurep FEATURE`

```text
FEATURE が *features* の要素であればそれ以降のリストを返します。
そうでなければ nil を返します。

使用例：
 ;;; process.l より
 (let ((shell (if (featurep :windows-nt) "cmd.exe" "command.com")))
   (defvar *shell* shell)
   (defvar *eshell* shell))
```

関連: `*features*`

## `find-load-path`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `find-load-path FILENAME`

```text
*load-path*からファイルを検索しそのフルパスを返します。

使用例：
  (find-load-path "wip/ftp.l")
  => "C:/APPLICATIONS/XYZZY/lisp/wip/ftp.l"
  (find-load-path "siteinit.l")
  => "C:/APPLICATIONS/XYZZY/site-lisp/siteinit.l"
```

関連: `*load-path*`

## `get-clipboard-data`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-clipboard-data`

```text
クリップボードの内容を文字列として取り出します。
```

関連: `copy-to-clipboard`, `clipboard-empty-p`

## `get-special-folder-location`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-special-folder-location PLACE`

```text
いろいろなフォルダへのパスを返します。

  PLACE : フォルダの種類を指定します。
    :start-menu
    :send-to
    :desktop
    :personal
    :programs
    :recent
    :startup
    :templates

参考：
  WindowsAPIのGetSpecialFolderLocation
```

関連: `get-windows-directory`, `get-system-directory`

## `get-system-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-system-directory`

```text
Windowsシステムフォルダまでのパスを返す。

使用例：
  (get-system-directory)
  => "C:/WINDOWS/System32/"
```

関連: `get-windows-directory`, `get-special-folder-location`

## `get-window-handle`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-window-handle &optional WINDOW`

```text
指定されたウィンドウのハンドルを返します。

  WINDOW : ハンドルを返すウィンドウを指定します。

使用例：
  ;;; カーソルがあるウィンドウのハンドルを返します。
  (get-window-handle (selected-window))
```

## `get-windows-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-windows-directory`

```text
Windowsフォルダへのパスを返します。

使用例：
  (get-windows-directory)
  => "C:/WINDOWS/"
```

関連: `get-system-directory`, `get-special-folder-location`

## `lisp-implementation-type`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `lisp-implementation-type`

```text
Lisp 処理系の実装名を返します。

使用例：
  (lisp-implementation-type)
  => "xyzzy"

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `lisp-implementation-version`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `lisp-implementation-version`

```text
Lisp 処理系のバージョンを返します。

使用例：
  (lisp-implementation-version)
  => "0.2.2.236"

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `machine-instance`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `machine-instance`

```text
マシン名を返します。

使用例：
  (machine-instance)
  => "WS4849"

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `machine-name`, `machine-type`, `machine-version`, `*features*`

## `machine-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `machine-name`

```text
マシン名を返します。

使用例：
  ;;; マシン名を返します。
  (machine-name)
  => "WS4849"

  ;;; PCによって、den8やdiffのインストールディレクトリが違っているので、
  ;;; 切り替えたりできます。
  (defun my-directory-setup ()
    (let ((x (machine-name)))
      (setq *diff-command-name*
            (cond ((string= x "TOMOYO") "c:/Cygnus/diff")
                   (t "c:/z/tools/diff")))
      (setq *den8-directory*
            (cond ((string= x "KANA") "D:/1gou-ki/den8_321")
                   (t "c:/z/den8_321")))))
```

関連: `user-name`, `si:getenv`, `machine-type`, `machine-instance`, `machine-version`

## `machine-type`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `machine-type`

```text
マシンのアーキテクチャを返します。

使用例：
  (machine-type)
  => "x64"

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `machine-name`, `machine-instance`, `machine-version`, `*features*`

## `machine-version`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `machine-version`

```text
CPU のバージョンを返します。

使用例：
  (machine-version)
  => "Intel64 Family 6 Model 23 Stepping 10, GenuineIntel"

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `machine-name`, `machine-instance`, `machine-type`, `*features*`

## `ole-create-event-sink`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-create-event-sink OBJECT &optional INTERFACE TYPELIB-FILE`

```text
OLEオブジェクトのイベントを受け取るイベント・シンクを作成します。
イベント・シンク作成後にset-ole-event-handlerでイベントハンドラを設定します。

  OBJECT       : イベント発生元のOLEオブジェクトを指定します。
  INTERFACE    : イベント・シンクのインターフェイス名を指定します。
  TYPELIB-FILE : タイプライブラリのファイル名を指定します。
                 通常は省略可能です。

使用例 :
  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-create-event-sink ie "DWebBrowserEvents2")
    (set-ole-event-handler ie "DownloadComplete"
                           #'(lambda ()
                               (msgbox "Download complete!")))
    #{ie.Navigate["http://www.google.co.jp/"]})
```

関連: `set-ole-event-handler`, `OLEオートメーションの使用例`

## `ole-create-object`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-create-object PROGRAM-ID`

```text
OLEオートメーション・サーバを作成します。

  PROGRAM-ID : 作成するOLEオートメーション・サーバのPROGIDを指定します。

使用例 :
  (ole-create-object "InternetExplorer.Application")
  => #<oledata: IWebBrowser2 56234972>
```

関連: `oledatap`, `ole-get-object`, `OLEオートメーションの使用例`

## `ole-for-each`

- Macro / package: editor / 定義: builtin.l
- 呼び出し: `ole-for-each (VAR OBJ &optional RESULTFORM) &body BODY`

```text
OLEオブジェクトのコレクションを列挙します。

  VAR           : BODY実行中に各シンボルに束縛される変数
  OBJ           : OLEオブジェクトのコレクション
  RESULTFORM    : ole-for-eachの戻り値
  BODY          : 繰り返しの本体

使用例 :
  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (setf #{ie.Visible} t)
    #{ie.Navigate["http://www.google.co.jp/"]}
    (while (/= #{ie.ReadyState} 4)
      (sit-for 0.1))
    (ole-for-each (div #{ie.document.GetElementsByTagName["div"]})
      (princ #{div.InnerText}))
    #{ie.Quit})
```

関連: `OLEオートメーションの使用例`

## `ole-get-object`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-get-object PROGRAM-ID`

```text
起動しているOLEオートメーション・サーバに接続します。

  PROGRAM-ID : 接続対象のOLEオートメーション・サーバのPROGIDを指定します。

使用例 :
  (ole-get-object "Excel.Application")
  => #<oledata: _Application 56234956>
```

関連: `oledatap`, `ole-create-object`, `OLEオートメーションの使用例`

## `ole-getprop`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-getprop OBJECT PROPERTY &rest ARGS`

```text
OLEオブジェクトのプロパティを取得します。

  OBJECT     : OLEオブジェクトを指定します。
  PROPERTY   : プロパティ名を指定します。
  ARGS       : プロパティの引数をリストで指定します。

使用例 :
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-getprop ie :Path))
  => "C:\\Program Files\\Internet Explorer\\"

リーダーマクロを利用して以下のように記述することもできます。

  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    #{ie.Path})
  => "C:\\Program Files\\Internet Explorer\\"
```

関連: `ole-method`, `ole-method*`, `ole-putprop`, `OLEオートメーションの使用例`

## `ole-method`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-method OBJECT PROPERTY &rest ARGS`

```text
OLEオブジェクトのメソッドを起動します。
引数を名前で指定したい場合はole-method*を利用します。

  OBJECT     : OLEオブジェクトを指定します。
  PROPERTY   : メソッド名を指定します。
  ARGS       : 引数をリストで指定します。

使用例 :
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-putprop ie :Visible t)
    (ole-method ie :Navigate "http://www.google.co.jp/"))

リーダーマクロを利用して以下のように記述することもできます。

  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (setf #{ie.Visible} t)
    #{ie.Navigate["http://www.google.co.jp/"]})
```

関連: `ole-method*`, `ole-getprop`, `ole-putprop`, `OLEオートメーションの使用例`

## `ole-method*`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-method* OBJECT PROPERTY &optional ARGS NAMED-ARGS`

```text
OLEオブジェクトのメソッドを起動します。

  OBJECT     : OLEオブジェクトを指定します。
  PROPERTY   : メソッド名を指定します。
  ARGS       : 引数をリストで指定します。
  NAMED-ARGS : 名前付き引数を属性リストで指定します。

使用例 :
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-putprop ie :Visible t)
    (ole-method* ie :Navigate
                 (list "http://www.google.co.jp/")
                 (list :Headers "Referer: http://www.google.co.jp/")))

リーダーマクロを利用して以下のように記述することもできます。

  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (setf #{ie.Visible} t)
    #{ie.Navigate["http://www.google.co.jp/" {:Headers "Referer: http://www.google.co.jp/"}]})

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `ole-method`, `ole-getprop`, `ole-putprop`, `OLEオートメーションの使用例`

## `ole-putprop`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ole-putprop OBJECT PROPERTY VALUE &rest ARGS`

```text
OLEオブジェクトのプロパティを設定します。

  OBJECT     : OLEオブジェクトを指定します。
  PROPERTY   : プロパティ名を指定します。
  VALUE      : プロパティに設定する値を指定します。
  ARGS       : プロパティの引数をリストで指定します。

使用例 :
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-putprop ie :Visible t))
  => t

リーダーマクロを利用して以下のように記述することもできます。

  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (setf #{ie.Visible} t))
  => t
```

関連: `ole-method`, `ole-method*`, `ole-getprop`, `OLEオートメーションの使用例`

## `os-build-number`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `os-build-number`

```text
Windows NT 4.00.13811 + Service Pack 3 の場合

使用例：  
  (os-build-number)
  => 1381
```

## `os-csd-version`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `os-csd-version`

```text
Windows NT 4.00.1381 + Service Pack 3 の場合

使用例：
  (os-csd-version)
  => "Service Pack 3"
```

## `os-major-version`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `os-major-version`

```text
OSのメジャーバージョンを返します。

使用例：
  (os-major-version)
  => 4
```

関連: `machine-name`

## `os-minor-version`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `os-minor-version`

```text
OSのマイナーバージョンを返します。

使用例：
  (os-minor-version)
  => 0
```

関連: `machine-name`

## `os-platform`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `os-platform`

```text
OSの種類を返します。OSが95とNTで動作を変えたいときなどに使います。返され
る値は文字列ではなくシンボルです。

参考：
  OS            シンボル
  ----          ----
  Windows???    win32s
  Windows95     windows-95
  Windows98     windows-98
  WindowsMe     windows-me
  WindowsNT     windows-nt
  Windows2000   windows-2000
  WindowsXP     windows-xp
  WindowsVista  windows-vista
  Windows7      windows-7
  Windows8      windows-8

使用例：
  (os-platform)
  => windows-nt
```

関連: `machine-name`, `si:getenv`

## `read-registry`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-registry SECTION KEY &optional ROOT`

```text
レジストリから読み込みます。

  SECTION : セクションを指定します。
  KEY     : キーを指定します。
  ROOT    : ルートキーを指定します。
     nil             HKEY_CURRENT_USER\Software\Free Software\Xyzzy
     :current-user   HKEY_CURRENT_USER
     :classes-root   HKEY_CLASSES_ROOT
     :local-machine  HKEY_LOCAL_MACHINE
     :users          HKEY_USERS

使用例：
  ;;; HKEY_CURRENT_USER/software/Microsoft/devstudio/5.0/Recent File List/project1 の値を読む
  (read-registry "software\\Microsoft\\devstudio\\5.0\\Recent File List" "project1"  :current-user)
```

## `set-ole-event-handler`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-ole-event-handler OBJECT EVENT-NAME HANDLER`

```text
OLEオブジェクトのイベントハンドラを設定します。

  OBJECT     : イベント発生元のOLEオブジェクトを指定します。
  EVENT-NAME : イベント名を指定します。
  HANDLER    : イベントハンドラを指定します。

使用例 :
  (require "ole")
  (let ((ie (ole-create-object "InternetExplorer.Application")))
    (ole-create-event-sink ie "DWebBrowserEvents2")
    (set-ole-event-handler ie "DownloadComplete"
                           #'(lambda ()
                               (msgbox "Download complete!")))
    #{ie.Navigate["http://www.google.co.jp/"]})
```

関連: `ole-create-event-sink`, `OLEオートメーションの使用例`

## `si:control-pressed`

- Function / package: system / 定義: builtin.l
- 呼び出し: `control-pressed`

```text
Control キーの状態を多値で返します。

戻り値
   一つ目は左右どちらかの Control キーが押されているか、押されていないか
   二つ目はトグルになっているかどうか

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `si:get-key-state`, `si:meta-pressed`, `si:shift-pressed`

## `si:dump-image-path`

- Function / package: system / 定義: builtin.l
- 呼び出し: `dump-image-path`

```text
読み込んだダンプファイルのパスを返します。

使用例：
  (si:dump-image-path)
  => "C:/Program Files/xyzzy/xyzzy.w2k"
```

関連: `dump-xyzzy`

## `si:environ`

- Function / package: system / 定義: builtin.l
- 呼び出し: `environ`

```text
全ての環境変数の名前と値の連想リストを返します。

使用例：
  (si:environ)
  => (("ALLUSERSPROFILE" . "C:\\ProgramData")
      ("APPDATA" . "C:\\Users\\xyzzy\\AppData\\Roaming")
      ("CommonProgramFiles" . "C:\\Program Files\\Common Files")
      ...)

補足：
  xyzzy 0.2.2.243 から利用可能です。
```

関連: `si:getenv`, `si:putenv`

## `si:get-key-state`

- Function / package: system / 定義: builtin.l
- 呼び出し: `get-key-state VKEY`

```text
指定された仮想キーの状態を多値で返します。

 VKEY : 仮想キーコードを指定します。
        si:*vk- で始まる定数を指定します。

戻り値
   一つ目はキーが押されているか、押されていないか
   二つ目はトグルになっているかどうか

使用例 :
  (multiple-value-bind (press toggle)
      (si:get-key-state si:*vk-shift*)
    (when press
      (msgbox "Shift pressed"))
    (when toggle
      (msgbox "Shift toggled")))

補足：
  xyzzy 0.2.2.246 から利用可能です。

仮想キー定数一覧：
  si:*vk-lbutton*
  si:*vk-rbutton*
  si:*vk-cancel*
  si:*vk-mbutton*
  si:*vk-xbutton1*
  si:*vk-xbutton2*
  si:*vk-back*
  si:*vk-tab*
  si:*vk-clear*
  si:*vk-return*
  si:*vk-shift*
  si:*vk-control*
  si:*vk-menu*
  si:*vk-pause*
  si:*vk-capital*
  si:*vk-kana*
  si:*vk-hangul*
  si:*vk-junja*
  si:*vk-final*
  si:*vk-hanja*
  si:*vk-kanji*
  si:*vk-escape*
  si:*vk-convert*
  si:*vk-nonconvert*
  si:*vk-accept*
  si:*vk-modechange*
  si:*vk-space*
  si:*vk-prior*
  si:*vk-next*
  si:*vk-end*
  si:*vk-home*
  si:*vk-left*
  si:*vk-up*
  si:*vk-right*
  si:*vk-down*
  si:*vk-select*
  si:*vk-print*
  si:*vk-execute*
  si:*vk-snapshot*
  si:*vk-insert*
  si:*vk-delete*
  si:*vk-help*
  si:*vk-0*
  si:*vk-1*
  si:*vk-2*
  si:*vk-3*
  si:*vk-4*
  si:*vk-5*
  si:*vk-6*
  si:*vk-7*
  si:*vk-8*
  si:*vk-9*
  si:*vk-a*
  si:*vk-b*
  si:*vk-c*
  si:*vk-d*
  si:*vk-e*
  si:*vk-f*
  si:*vk-g*
  si:*vk-h*
  si:*vk-i*
  si:*vk-j*
  si:*vk-k*
  si:*vk-l*
  si:*vk-m*
  si:*vk-n*
  si:*vk-o*
  si:*vk-p*
  si:*vk-q*
  si:*vk-r*
  si:*vk-s*
  si:*vk-t*
  si:*vk-u*
  si:*vk-v*
  si:*vk-w*
  si:*vk-x*
  si:*vk-y*
  si:*vk-z*
  si:*vk-lwin*
  si:*vk-rwin*
  si:*vk-apps*
  si:*vk-sleep*
  si:*vk-numpad0*
  si:*vk-numpad1*
  si:*vk-numpad2*
  si:*vk-numpad3*
  si:*vk-numpad4*
  si:*vk-numpad5*
  si:*vk-numpad6*
  si:*vk-numpad7*
  si:*vk-numpad8*
  si:*vk-numpad9*
  si:*vk-multiply*
  si:*vk-add*
  si:*vk-separator*
  si:*vk-subtract*
  si:*vk-decimal*
  si:*vk-divide*
  si:*vk-f1*
  si:*vk-f2*
  si:*vk-f3*
  si:*vk-f4*
  si:*vk-f5*
  si:*vk-f6*
  si:*vk-f7*
  si:*vk-f8*
  si:*vk-f9*
  si:*vk-f10*
  si:*vk-f11*
  si:*vk-f12*
  si:*vk-f13*
  si:*vk-f14*
  si:*vk-f15*
  si:*vk-f16*
  si:*vk-f17*
  si:*vk-f18*
  si:*vk-f19*
  si:*vk-f20*
  si:*vk-f21*
  si:*vk-f22*
  si:*vk-f23*
  si:*vk-f24*
  si:*vk-numlock*
  si:*vk-scroll*
  si:*vk-oem-nec-equal*
  si:*vk-oem-fj-jisho*
  si:*vk-oem-fj-masshou*
  si:*vk-oem-fj-touroku*
  si:*vk-oem-fj-loya*
  si:*vk-oem-fj-roya*
  si:*vk-lshift*
  si:*vk-rshift*
  si:*vk-lcontrol*
  si:*vk-rcontrol*
  si:*vk-lmenu*
  si:*vk-rmenu*
  si:*vk-browser-back*
  si:*vk-browser-forward*
  si:*vk-browser-refresh*
  si:*vk-browser-stop*
  si:*vk-browser-search*
  si:*vk-browser-favorites*
  si:*vk-browser-home*
  si:*vk-volume-mute*
  si:*vk-volume-down*
  si:*vk-volume-up*
  si:*vk-media-next-track*
  si:*vk-media-prev-track*
  si:*vk-media-stop*
  si:*vk-media-play-pause*
  si:*vk-launch-mail*
  si:*vk-launch-media-select*
  si:*vk-launch-app1*
  si:*vk-launch-app2*
  si:*vk-oem-1*
  si:*vk-oem-plus*
  si:*vk-oem-comma*
  si:*vk-oem-minus*
  si:*vk-oem-period*
  si:*vk-oem-2*
  si:*vk-oem-3*
  si:*vk-oem-4*
  si:*vk-oem-5*
  si:*vk-oem-6*
  si:*vk-oem-7*
  si:*vk-oem-8*
  si:*vk-oem-ax*
  si:*vk-oem-102*
  si:*vk-ico-help*
  si:*vk-ico-00*
  si:*vk-processkey*
  si:*vk-ico-clear*
  si:*vk-packet*
  si:*vk-oem-reset*
  si:*vk-oem-jump*
  si:*vk-oem-pa1*
  si:*vk-oem-pa2*
  si:*vk-oem-pa3*
  si:*vk-oem-wsctrl*
  si:*vk-oem-cusel*
  si:*vk-oem-attn*
  si:*vk-oem-finish*
  si:*vk-oem-copy*
  si:*vk-oem-auto*
  si:*vk-oem-enlw*
  si:*vk-oem-backtab*
  si:*vk-attn*
  si:*vk-crsel*
  si:*vk-exsel*
  si:*vk-ereof*
  si:*vk-play*
  si:*vk-zoom*
  si:*vk-noname*
  si:*vk-pa1*
  si:*vk-oem-clear*
```

## `si:getenv`

- Function / package: system / 定義: builtin.l
- 呼び出し: `getenv VARIABLE`

```text
環境変数の値を取り出します。

  VARIABLE：環境変数名

使用例：
  ;;; 環境変数PATHを取り出して、個々のPATHに分割する。
  (split-string (si:getenv "PATH") #\;)
  => ("c:\\usr\\local\\bin" "C:\\WINNT\\system32" "C:\\WINNT" ...)

  (setf (si:getenv "FOO") "BAR")
  => "BAR"
  (si:getenv "FOO")
  => "BAR"

補足：
  xyzzy 0.2.2.243 からsetf可能です。
```

関連: `user-name`, `machine-name`, `si:environ`, `si:putenv`

## `si:getpid`

- Function / package: system / 定義: builtin.l
- 呼び出し: `getpid`

```text
xyzzyのプロセスIDを返します。

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `si:meta-pressed`

- Function / package: system / 定義: builtin.l
- 呼び出し: `meta-pressed`

```text
Alt キーの状態を多値で返します。

戻り値
   一つ目は左右どちらかの Alt キーが押されているか、押されていないか
   二つ目はトグルになっているかどうか

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `si:get-key-state`, `si:control-pressed`, `si:shift-pressed`

## `si:output-debug-string`

- Function / package: system / 定義: builtin.l
- 呼び出し: `output-debug-string FMT &rest ARGS`

```text
現在のデバッガに文字列を送信します。出力したメッセージはDebugViewや
VisualStudioの出力ウィンドウで確認可能です。

  FMT  : format同様の書式が指定できます。
  ARGS : 出力書式へのパラメタとなります。

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `*debug-output*`

## `si:putenv`

- Function / package: system / 定義: builtin.l
- 呼び出し: `putenv VARIABLE &optional VALUE`

```text
環境変数に値を設定します。

  VARIABLE：環境変数名
  VALUE   ：環境変数値

VALUE を省略した場合や nil を指定した場合は環境変数を削除します。

環境変数の設定に成功した場合は設定した値を、環境変数を削除した場合
または設定に失敗した場合は nil を返します。

使用例：
  ;;; 環境変数PATHに$XYZZY/binを追加する
  (si:putenv "PATH" (format nil "~A;~A"
                            (merge-pathnames "bin" (si:system-root))
                            (si:getenv "PATH")))

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `si:environ`, `si:getenv`

## `si:search-path`

- Function / package: system / 定義: builtin.l
- 呼び出し: `search-path FILE &optional PATH EXT`

```text
指定されたファイルを検索します。

  FILE : 検索対象のファイル名を指定します。
  PATH : ファイル検索対象のパス名を指定します。
         nil を指定すると次の順序でファイルを検索します。
           1. xyzzy.exe と同じディレクトリ
           2. カレントディレクトリ
           3. 32 ビットの Windows システムディレクトリ (SYSTEM32)
           4. 16 ビットの Windows システムディレクトリ (SYSTEM)
           5. Windows ディレクトリ
           6. 環境変数 PATH に記述されている各ディレクトリ
  EXT  : 検索対象のファイルの拡張子を指定します。
         拡張子の先頭には、ピリオドを指定してください。
         FILE パラメータで拡張子が指定されていなかった場合にのみ追加されます。
         拡張子が不要な場合、または、FILE で拡張子を指定した場合は、EXT には
         nil を指定してください。

使用例 :
  (si:search-path "cmd.exe")
  => "C:/Windows/system32/cmd.exe"

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

## `si:shift-pressed`

- Function / package: system / 定義: builtin.l
- 呼び出し: `shift-pressed`

```text
Shift キーの状態を多値で返します。

戻り値
   一つ目は左右どちらかの Shift キーが押されているか、押されていないか
   二つ目はトグルになっているかどうか

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `si:get-key-state`, `si:control-pressed`, `si:meta-pressed`

## `si:system-root`

- Function / package: system / 定義: builtin.l
- 呼び出し: `system-root`

```text
xyzzyがインストールされているパスを返します。

※userパッケージもeditorパッケージもsystemをuse-packageしていないので、
  呼び出すときはsi:を付けて、(si:system-root)としなければいけません。

使用例：
  (load (merge-pathnames "lisp/henmi/foo.l" (si:system-root)))
```

関連: `user-homedir-pathname`

## `software-type`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `software-type`

```text
ソフト名を返します。

使用例：  
  (software-type)
  => "xyzzy"
```

## `software-version`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `software-version`

```text
xyzzyのバージョンを返します。

使用例：
  (software-version)
  => "0.2.2.228"
```

## `start-xyzzy-server`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `start-xyzzy-server`

```text
stop-xyzzy-serverの逆です。複数のxyzzy-serverが立ち上がっている状態で
xyzzycli.exe が実行された場合、最後にアクティブになったほうが選択され
るようです。
```

関連: `stop-xyzzy-server`

## `stop-xyzzy-server`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `stop-xyzzy-server`

```text
xyzzycli.exeに反応しないようにします。
```

関連: `start-xyzzy-server`

## `user-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `user-name`

```text
Windowsのログオンユーザー名を返します。
```

関連: `machine-name`, `si:getenv`

## `version-up-xyzzy`

- Function / package: editor / 定義: verup.l
- 呼び出し: `version-up-xyzzy &rest ARGS`

```text
亀井さんが配布しているxyzzyのアーカイブファイルをxyzzyがインストールされている
ディレクトリに展開します。
別途、ダンプファイルの再作成をする必要があります。
```

関連: `dump-xyzzy`

## `write-registry`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `write-registry SECTION KEY VALUE`

```text
レジストリに書き込みます。

  SECTION : セクションを指定します。
  KEY     : キーを指定します。
  VALUE   : 値を指定します。

使用例：
  ;;; HKEY_CURRENT_USER\Software\Free Software\Xyzzy の下にデータを書き込む
  (write-registry "software\\chombo\\altime" "aaa" 64)

  以下のように書き込まれます。
-----
REGEDIT4

[HKEY_CURRENT_USER\Software\Free Software\Xyzzy\software\chombo\altime]
"aaa"=dword:00000040
-----
```

関連: `read-registry`

## `xyzzy-dumped-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `xyzzy-dumped-p`

```text
起動時にxyzzyがダンプ済みかどうかを返します。

  t     ダンプ済み
  nil   ダンプ済みではない

ダンプ作業をしても再起動するまでは戻り値はtになりません。
```

関連: `dump-xyzzy`

## `起動時処理フロー`

- Tips

```text
起動時の処理フローです。 $XYZZY/xyzzy.exe を起動すると、最初は init.cc
  から $XYZZY/lisp/startup.l が呼び出されます。以降の主なフローは以下
  のとおりです。
  
  init.cc: 
    1. startupをload-library 
       startup.l: 
        1. loadupをload-library 
           loadup.l: 
            1. estartup を load-library 
             （estartup.l で、e:startup を定義） 
            2. historyをload-library 
             （history.l で、 load-history-file を定義） 
            3. app-menuをload-library 
             （app-menu.l で、 init-app-menus を定義） 
            4. siteinit を load-library 
    2. ダンプが未だならダンプ 
    3. e:startup を実行 
       estartup.l の e:startup: 
        1. フレームを初期化 
        2. *pre-startup-hook* を実行 
        3. .xyzzyを実行 
        4. ヒストリを初期化 
         （history.lのload-history-fileで、 *load-history-hook* を実行） 
        5. メニューを初期化 
         （app-menu.lのinit-app-menusで、 *init-app-menus-hook* を実行） 
        6. *scratch*を作成
        7.引数解析
          (process-command-line から、 *command-line-mailto-hook* とか
           *process-command-line-hook*を実行）
        8. *post-startup-hook*を実行 
  
まとめると、起動時にユーザが変更可能な部分は、以下の順番で実行さ
れます。

  1. $XYZZY/site-lisp/siteinit.l
  2. *pre-startup-hook*
  3. ~/.xyzzy
  4. *load-history-hook*
  5. *init-app-menus-hook*
  6. *command-line-mailto-hook* （-mailtoがある場合）
  7. *process-command-line-hook* （不明なオプションがある場合）
  8. *post-startup-hook*
```

関連: `*command-line-mailto-hook*`, `*init-app-menus-hook*`, `*load-history-hook*`, `*post-startup-hook*`, `*pre-startup-hook*`, `*process-command-line-hook*`
