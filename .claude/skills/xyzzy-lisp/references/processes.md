# プロセス (processes)

reference/reference.xml から自動生成。42 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `activate-xyzzy-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `activate-xyzzy-window INSTANCE`

```text
指定したxyzzyをアクティブにします。
  
  INSTANCE : 起動中のxyzzyに割り当てられた非負の整数
```

関連: `si:*instance-number`, `list-xyzzy-windows`

## `call-process`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `call-process COMMAND-LINE &key :environ :no-std-handles :input :output :error :exec-directory :show :wait`

```text
外部プログラムを実行します。完全にxyzzyの外部でプログラムを実行します。

  COMMAND-LINE    : 実行するコマンドをオプション付で指定します。
  :environ        : 設定する環境変数を連想リスト形式で渡します。
                    (("HOME" . "C:/applications/xyzzy/")
                     ("TOPDIR" . "C:/spool/"))
  :no-std-handles : t の場合， :input :output :error の指定を無視します．
  :input          : 標準入力を使用する外部プログラムであれば入力ファイル名
                    を指定します。
  :output         : 標準出力を使用する外部プログラムであれば出力ファイル名
                    を指定します。
  :error          : 標準エラー出力を使用する外部プログラムであれば出力ファ
                    イル名を指定します．指定しないときは，標準出力に出力し
                    ます．
  :exec-directory : 実行するディレクトリを指定します。
  :show           : 外部プログラムの実行時の表示を指定します。
                    :show      通常のウィンドウ
                    :no-active 非アクティブ
                    :minimize  最小化
                    :maximize  最大化
                    :hide      非表示
                    上記以外   通常のウィンドウ
  :wait           : 外部プログラムが終了するのを待ち合わせます。

実行したプロセスを取得したいときは make-process を使います．

使用例：
  ;;; notepad.exeの終了を待ち合わせてみる。
  (call-process "notepad" :wait t)
```

関連: `execute-shell-command`, `make-process`

## `command-output-alternate-send-input`

- Function / package: editor / 定義: process.l
- 呼び出し: `command-output-alternate-send-input`

```text
現在のバッファに関連付けられたプロセスに対して、マーカーと現在行の行末
の間の文字と \r をつなげて送ります。

マーカーは、プロセスが最後に出力したバッファの位置につけられています。
```

関連: `command-output-send-input`

## `command-output-mode`

- Function / package: editor / 定義: process.l
- 呼び出し: `command-output-mode`

```text
バッファを command-output-mode にします。
自動保存とundo情報を記録しなくなります。

また、以下のように設定された *command-output-mode-map* がキーマップ
として使われます。
  RET : command-output-send-input 
  C-j : command-output-alternate-send-input
```

関連: `command-output-send-input`, `command-output-alternate-send-input`

## `command-output-send-input`

- Function / package: editor / 定義: process.l
- 呼び出し: `command-output-send-input &optional EOL`

```text
現在のバッファに関連付けられたプロセスに対して、マーカーと現在行の行末
の間の文字と EOL をつなげて送ります。 EOL のデフォルトは \n です。

マーカーは、プロセスが最後に出力したバッファの位置につけられています。
```

関連: `command-output-alternate-send-input`, `marker-point`, `process-send-string`

## `count-xyzzy-instance`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `count-xyzzy-instance`

```text
現在起動中のxyzzyの数を返します。
```

## `execute-region`

- Function / package: editor / 定義: process.l
- 呼び出し: `execute-region FROM TO`

```text
リージョンの内容をバッチファイルとして実行します。
```

## `execute-shell-command`

- Function / package: editor / 定義: process.l
- 呼び出し: `execute-shell-command COMMAND &optional INFILE OUTPUT ENVIRON DIRECTORY`

```text
外部プログラムを実行します。結果だけをxyzzyに取り込みます。

  COMMAND    : 実行するコマンドをオプション付で指定します。
  INFILE     : 標準入力を使用する外部プログラムであれば入力ファイル名を
               指定します。
  OUTPUT     : 標準出力を出力するバッファを指定します。
  ENVIRON    : 設定する環境変数を連想リスト形式で渡します。
                (("HOME" . "C:/applications/xyzzy/")
                 ("TOPDIR" . "C:/spool/"))
  DIRECTORY  : 実行するディレクトリを指定します。

このコマンドは call-process を使って実装されています。
call-processとは違って標準出力をバッファに出力します。出力するバッファは完
全に破壊されますので注意してください。
外部プログラムとして実行したくない場合は， execute-subprocess を使います。

使用例：
  ;;; コマンドプロンプトのhelpを表示してみる。
  (execute-shell-command "help" nil (selected-buffer))
```

関連: `call-process`, `execute-subprocess`, `shell-execute`

## `execute-subprocess`

- Function / package: editor / 定義: process.l
- 呼び出し: `execute-subprocess CMD &optional ARG BUFNAME ENVIRON DIRECTORY`

```text
プログラムを BUFFNAME で指定したバッファ上で実行します。[C-x &]
結果は， BUFFNAME で指定されたバッファ上に表示されます。

  CMD        : 実行するコマンドをオプション付で指定します。
  ARG        : (詳細不明)
  BUFNAME    : 関連付けるバッファ名を指定します。デフォルトは "*Command Output*" です。
               指定したバッファが存在しないとき，新しくバッファを作ります。
  ENVIRON    : 設定する環境変数を連想リスト形式で渡します。
                  (("HOME" . "C:/applications/xyzzy/")
                   ("TOPDIR" . "C:/spool/"))
  DIRECTORY  : 実行するディレクトリを指定します。 

指定されたバッファは command-output-mode になります。

使用例：
  ;;; cmd.exe をバッファ上で実行します。 シンプルなシェルとして動作します。
  (execute-subprocess "cmd.exe")
  =>#<buffer: *Command Output*>
```

関連: `make-process`, `execute-shell-command`, `filter-region`, `command-output-mode`, `shell-command-line`

## `filter-buffer`

- Function / package: editor / 定義: process.l
- 呼び出し: `filter-buffer COMMAND`

```text
バッファ全体の内容を標準入力につなげて COMMAND を実行します。[C-x #]
COMMAND の終了を待ち、終了するとバッファの内容は一旦全て消去され、
COMMAND の標準出力がバッファに出力されます。
```

関連: `filter-region`

## `filter-region`

- Function / package: editor / 定義: process.l
- 呼び出し: `filter-region COMMAND &optional START END`

```text
リージョンの内容を標準入力につなげて COMMAND を実行します。[C-x |]
COMMAND の終了を待ち、終了するとリージョンの内容は一旦全て消去され、
COMMAND の標準出力がリージョンにに出力されます。

リージョンが指定されていないときは、COMMANDの結果を単にカーソル位置
に出力します。
```

関連: `filter-buffer`, `call-process`

## `kill-process`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kill-process PROCESS`

```text
プロセスを強制的に終了させます。
```

関連: `kill-subprocess`, `signal-process`, `make-process`

## `kill-subprocess`

- Function / package: editor / 定義: process.l
- 呼び出し: `kill-subprocess`

```text
バッファに結び付けられているプロセスを停止させます。[C-c C-k]
```

関連: `kill-process`, `make-process`

## `kill-xyzzy`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kill-xyzzy &optional (EXIT-CODE t)`

```text
xyzzyを終了します。

  EXIT-CODE : xyzzyの終了ステータスを指定します。
              省略時はEXIT_SUCCESSを終了ステータスとします。
       nil  : EXIT_FAILUREを終了ステータスとします。
       t    : EXIT_SUCCESSを終了ステータスとします。
       整数 : その値を終了ステータスとします。

補足：
  EXIT-CODE の指定は xyzzy 0.2.2.239 から利用可能です。
```

関連: `*kill-xyzzy-hook*`, `*query-kill-xyzzy-hook*`, `save-all-buffers-kill-xyzzy`, `save-buffers-kill-xyzzy`

## `launch-application`

- Function / package: editor / 定義: dialogs.l
- 呼び出し: `launch-application APP`

```text
プログラムを xyzzy の外部で実行します。
```

## `list-xyzzy-windows`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-xyzzy-windows`

```text
起動中のxyzzyの一覧をリスト形式で返します。
  
  (list-xyzzy-windows)
  =>((0 . "*scratch* - xyzzy 0.2.2.235@XYZZY") (1 . "*untitled* - xyzzy 0.2.2.235@XYZZY") (2 . "*untitled*<2> - xyzzy 0.2.2.235@XYZZY"))
```

関連: `next-xyzzy-window`, `previous-xyzzy-window`

## `make-process`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-process COMMAND-LINE &key :environ :output :exec-directory :incode :outcode :eol-code :show`

```text
プロセスを起動します。

  COMMAND-LINE    : 実行するコマンドをオプション付で指定します。
  :environ        : 設定する環境変数を連想リスト形式で渡します。
                    (("HOME" . "C:/applications/xyzzy/")
                     ("TOPDIR" . "C:/spool/"))
  :output         : プロセスの標準出力を出力するバッファを指定します。
  :exec-directory : 実行するディレクトリを指定します。
  :incode         : プロセスの入力の文字コードを指定します。
  :outcode        : プロセスの出力の文字コードを指定します。
  :eol-code       : 改行コードを指定します。
  :show           : 外部プログラムの実行時の表示を指定します。
                    :show      通常のウィンドウ
                    :no-active 非アクティブ
                    :minimize  最小化
                    :maximize  最大化
                    :hide      非表示
                    上記以外   通常のウィンドウ

プロセスへの入力はprocess-send-stringを使用します。
プロセスはバッファに関連付けられ、プロセスの出力がバッファにそのまま出力されます。
バッファに関連付けられたプロセスの状態は，モードライン上に :Run や :Exit と
表示されます。また、環境変数や出力先等を変更できます。

戻り値は，バッファに関連付けられたプロセスです。

参考:
  [xyzzy:02210]山本真二さん
  call-process または別の組み込み関数で、標準入力、標準出力、標準エラー
  出力を直接バッファに繋ぐようにした方が早くてかっこいいと思うのですが、
  難しいですか？

  (make-process *eshell* :output (selected-buffer))
  (process-send-string (buffer-process (selected-buffer))
                       (concatenate 'string cmd *shell-ret*))

補足：
  :show パラメータの指定は xyzzy 0.2.2.236 から利用可能です。
```

関連: `*xyzzyenv-show-flag*`, `call-process`, `execute-subprocess`, `filter-region`, `buffer-process`, `process-send-string`, `set-process-sentinel`, `set-process-filter`, `kill-subprocess`, `shell-execute`, `open-network-stream`

## `next-xyzzy-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `next-xyzzy-window`

```text
次のxyzzyに移動します。
移動順は起動した順です。
```

関連: `previous-xyzzy-window`, `list-xyzzy-windows`

## `open-network-stream`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `open-network-stream BUFFER HOSTNAME SERVICE &key :incode :outcode :eol-code`

```text
ホストのポートとのTCP接続を開きます。
成功すれば接続をBUFFERのサブプロセスとして返します。

使用例：
  ;;; http://www.yahoo.co.jp/を取得してみる。
  (progn
    (defun filter (proc in) (insert in))
    (setq proc (open-network-stream (selected-buffer) "www.yahoo.co.jp" 80))
    (process-send-string proc "GET / HTTP/1.0\n\n")
    (set-process-filter proc 'filter))
  => HTTP/1.1 200 OK
     Server: ...
```

関連: `connect`, `make-process`

## `pipe-command`

- Function / package: editor / 定義: process.l
- 呼び出し: `pipe-command CMD`

```text
CMD を実行し、プロセスの終了を待って標準出力を *Shell output* バッファ
に出力します。[C-x @]
```

関連: `execute-shell-command`

## `previous-xyzzy-window`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `previous-xyzzy-window`

```text
前のxyzzyに移動します。
移動順は起動した順の逆です。
```

関連: `next-xyzzy-window`, `list-xyzzy-windows`

## `process-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-buffer PROCESS`

```text
プロセスが結び付けられているバッファを返します。
```

関連: `buffer-process`

## `process-eol-code`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-eol-code PROCESS`

```text
PROCESSに設定された改行コードを返します。
```

関連: `set-process-eol-code`

## `process-exit-code`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-exit-code PROCESS`

```text
指定されたプロセスPROCESSの終了コードを取得します。
```

関連: `signal-process`, `process-status`

## `process-filter`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-filter PROCESS`

```text
PROCESSに設定されたFILTER用の関数を返します。
```

関連: `set-process-filter`

## `process-incode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-incode PROCESS`

```text
PROCESSに設定された入力用の文字エンコーディングを指定します。
```

関連: `set-process-incode`

## `process-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-marker PROCESS`

```text
プロセスに関連付けられたマーカーを返します。
プロセスの出力はマーカー位置に挿入され、
マーカー位置は挿入したテキスト長だけ進みます。

process-filter をセットした場合は、マーカーに対する処理は起こりません。
必要な場合は、通常 process-filter で自分で処理します。
プロセスに関連付けられたマーカーは、 delete-marker で削除することはできません。
```

関連: `make-marker`, `make-process`, `delete-marker`, `process-filter`

## `process-outcode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-outcode PROCESS`

```text
PROCESSに設定された出力用の文字エンコーディングを指定します。
```

関連: `set-process-outcode`

## `process-send-n`

- Function / package: editor / 定義: process.l
- 呼び出し: `process-send-n`

```text
バッファに結び付けられているプロセスに "n\n" を送ります。
```

関連: `process-send-y`

## `process-send-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-send-string PROCESS STRING`

```text
プロセスに文字列を送ります。

  PROCESS : 文字列を送りつけるプロセスを指定します。 
  STRING  : 送りつける文字列を指定します。

使用例：
  ;;; sort.exeを起動して、"abc" "aab" "aac"を送りつける。
  (setq proc (make-process "sort"))
  => #<process 135271372>
  (process-send-string proc "abc\n") => t
  (process-send-string proc "aab\n") => t
  (process-send-string proc "aac\n") => t
  (process-send-string proc "^Z")    => t
  aab
  aac
  abc
```

関連: `make-process`

## `process-send-y`

- Function / package: editor / 定義: process.l
- 呼び出し: `process-send-y`

```text
バッファに結び付けられているプロセスに "y\n" を送ります。
```

関連: `process-send-n`

## `process-sentinel`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-sentinel PROCESS`

```text
PROCESSに設定されたSENTINEL用の関数を返します。
```

関連: `set-process-sentinel`

## `process-status`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `process-status PROCESS`

```text
指定されたプロセスの状態を返します。

  :run  動作中
  :exit 停止
```

関連: `kill-process`, `make-process`

## `run-admin-console`

- Function / package: editor / 定義: process.l
- 呼び出し: `run-admin-console`

```text
xyzzy の外部でコンソールを管理者権限で起動します。
変数 *eshell* または *shell* の値が実行されるコマンドとして使われます。
```

関連: `run-console`

## `run-console`

- Function / package: editor / 定義: process.l
- 呼び出し: `run-console`

```text
xyzzy の外部でコンソールを起動します。
変数 *eshell* または *shell* の値が実行されるコマンドとして使われます。
```

関連: `run-admin-console`

## `set-process-eol-code`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-process-eol-code PROCESS CODE`

```text
PROCESSで処理する場合の改行コードCODEを設定します。
```

関連: `process-eol-code`

## `set-process-filter`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-process-filter PROCESS FILTER`

```text
プロセスの出力を加工するためのフィルタを指定します。
プロセスからの入力があるとset-process-filter関数でプロセスと関係づけられた
フィルタ関数が呼ばれます。
フィルタの第一引数はプロセスで第二引数は入力文字列です。
フィルタの戻り値は捨てられるようです。

使用例:
  ;;; プロセスへの出力を試すミニマルではないかも
  (let ((buf (create-new-buffer "hoge")))
    (unwind-protect ;;念の為感が強い
        (progn
           (make-process *eshell* :output buf)
           (set-process-filter (buffer-process buf)
                               (lambda (prc str)
                                 (yes-or-no-p "proc ~S str ~S" prc str)))
           (process-send-string (buffer-process buf)
                                (concat "dir&exit" *shell-ret*))
           (sleep-for 0.9))
      (delete-buffer buf)))
```

関連: `process-filter`, `set-process-outcode`, `set-process-incode`, `set-process-sentinel`, `process-send-string`

## `set-process-incode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-process-incode PROCESS CODE`

```text
プロセスからset-process-filterに入力がある場合の文字エンコーディングを指定します。
```

関連: `set-process-outcode`

## `set-process-outcode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-process-outcode PROCESS CODE`

```text
プロセスに対してsend-process-stringをする場合の文字エンコーディングを指定します。
```

関連: `set-process-incode`

## `set-process-sentinel`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-process-sentinel PROCESS SENTINEL`

```text
プロセスが終了する場合に呼ばれる関数（いわゆるSENTINEL）を指定します。
```

関連: `process-sentinel`, `set-process-filter`

## `shell-execute`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `shell-execute FILENAME &optional DIRECTORY PARAMS &key :verb`

```text
何かを行います。URLであればそれを開き、実行ファイルであれば実行したり、
拡張子に応じてアプリケーションを実行します。

  FILENAME  : 何か？URLもOK？
  DIRECTORY : どこでそれを実行するかを指定します。
        t       (cwd)の返されるディレクトリで実行されるみたいです。
        nil     特に指定がないのでFILENAMEのディレクトリで実行されます。
  :verb     : 実行するべき操作を指定します。
              利用可能な操作の種類は、ファイルまたはファイルによって異なります。
              通常は次の操作が有効です。
                :open       : FILENAME で指定したファイルを開きます。
                              文書ファイルまたは実行可能ファイルを指定できます。
                              1 つのフォルダを指定することもできます。
                :edit       : エディタを開きます。
                              文書以外のファイルを指定すると失敗します。
                :explore    : FILENAME で指定したフォルダを選択して、エクスプローラを起動します。
                :print      : FILENAME で指定したファイルを印刷します。
                              文書以外のファイルを指定すると失敗します。
                :runas      : 管理者権限で FILENAME で指定したファイルを開きます。
                              文書ファイルまたは実行可能ファイルを指定できます。
                              1 つのフォルダを指定することもできます。
              nil を指定すると :open が規定で利用されます。

質問：

  | http://java.sun.com/products/jdk/1.2/docs/api/index.html
  | とかをF3キー一発で開けたらって思ってるんです。

  こんなかんじでどうぞ。

  (defun foo ()
    (interactive)
    (shell-execute "http://java.sun.com/products/jdk/1.2/docs/api/index.html" t))
```

関連: `execute-shell-command`, `make-process`

## `signal-process`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `signal-process PROCESS`

```text
指定されたプロセスPROCESSにシグナルを送ります。
※SIGINT?
```

関連: `kill-process`, `process-exit-code`
