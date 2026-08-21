# ダイアログ (dialogs)

reference/reference.xml から自動生成。18 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*std-control-default-char*`

- Variable / package: editor / 定義: defs.l

```text
select-bufferやダイアログのリストボックスで、デフォルト選択用の
キャラクタを設定します。

使用例：
  (setq *std-control-default-char* #\RET)
```

## `*std-control-down-char*`

- Variable / package: editor / 定義: defs.l

```text
select-bufferやダイアログのリストボックスで、下方向に移動するキ
ャラクタを設定します。

使用例：
  (setq *std-control-down-char* #\C-n)
```

関連: `*std-control-up-char*`

## `*std-control-next-char*`

- Variable / package: editor

```text
select-bufferやダイアログのリストボックスで、
ページダウンするキャラクタを設定します。

使用例：
  (setq *std-control-next-char* #\C-v)
```

関連: `*std-control-prior-char*`

## `*std-control-prior-char*`

- Variable / package: editor

```text
select-bufferやダイアログのリストボックスで、
ページアップするキャラクタを設定します。

使用例：
  (setq *std-control-prior-char* #\C-u)
```

関連: `*std-control-next-char*`

## `*std-control-up-char*`

- Variable / package: editor / 定義: defs.l

```text
select-bufferやダイアログのリストボックスで、上方向に移動するキ
ャラクタを設定します。

使用例：
  (setq *std-control-up-char* #\C-p)
```

関連: `*std-control-down-char*`

## `dialog`

- Function / package: lisp
- 呼び出し: `dialog X Y W H &rest CONTROLS`

```text
ダイアログを定義します。

  X Y      : ダイアログの表示位置を指定します。
  W H      : ダイアログの大きさを指定します。
  CONTROLS : コントロールを指定します。

コントロールをxyzzyで作成するのは面倒なので、VisualC++のリソース作成画面
で、部品を配置して変換する方法が用意されています。新しくバッファを作って 
*.rcファイルから必要な部分を持ってきた後で、

  M-x convert-dialog-template-buffer

バッファ名を選択するとlisp形式に変換されます。
```

関連: `dialog-box`

## `dialog-box`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `dialog-box TEMPLATE INITIAL-VALUE CHECK-OR-DISABLE`

```text
ダイアログボックスを表示します。ダイアログはdialogで定義されたものを使います。

  TEMPLATE :
      lispの形式で記述されたダイアログテンプレートを指定します。
      詳細は、関数dialogを参照してください。

  INITIAL-VALUE :
      エディトボックス等に入れる、文字列などを指定します。
      特に指定しない場合はnilでもかまいません。

  CHECK-OR-DISABLE :
      チェックボックス等の初期選択状態を指定します。
      特に指定しない場合はnilでもかまいません。

戻り値は多値なので、 multiple-value-bind 等で受け取る必要があります。1番
目の戻り値は、cancelボタンが押されたらnil、okボタンが押されたらtが返ります。
  
使用例：
  ;;; テスト用のダイアログを定義します。
  (setq *test-dialog-template*
    `(dialog 0 0 300 100 
             (:caption "について")
             (:font 9 "ＭＳ Ｐゴシック")
             (:control
              (:static nil nil #x50020003 7 7 18 21)
              (:static nil ,(concat "XYZZY version "
                                    (software-version))
               #x50020000 34 7 92 8)
              (:static nil "Copyright (C) 1996, 97 T.Kamei"
               #x50020000 34 17 92 8)
              (:button IDOK "OK" #x50010001 52 35 36 14))))

  ;;; テスト用のダイアログを表示します。
  (defun test-dialog ()
    (interactive)
    (dialog-box *test-dialog-template* nil nil)
    t)
```

関連: `dialog`, `file-name-dialog`, `directory-name-dialog`, `drive-dialog`

## `directory-name-dialog`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `directory-name-dialog &key :title :default`

```text
ディレクトリを指定するダイアログを表示します。
ユーザーが指定したディレクトリを返します。
  
  :title   : ダイアログのタイトル
  :default : 初期表示するディレクトリ

使用例：
  ;;; ミニバッファからディレクトリ名を読み取る。
  (directory-name-dialog)
  => "C:/applications/xyzzy/site-lisp"
```

関連: `file-name-dialog`, `read-directory-name`

## `drive-dialog`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `drive-dialog &optional DRIVE`

```text
ドライブ選択のダイアログを表示します。DRIVEで初期表示するドライブを選択
できます。選択したドライブのドライブ文字がキャラクタで返されます。

使用例：
  (drive-dialog)
  => #\R
```

関連: `file-name-dialog`, `directory-name-dialog`

## `file-name-dialog`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `file-name-dialog &key :char-encoding :eol-code :filter :filter-index :title :default :extension :save :multiple :must-exist :explorer :hide-read-only :initial-directory`

```text
ファイルを指定するダイアログを表示します。
ユーザーが指定したファイルを返します。多値で返します。
（詳細不明）

  :char-encoding        文字コード指定プルダウンメニューを表示
  :eol-code             改行コード指定プルダウンメニューを表示
  :filter               ファイルの種類リスト
  :filter-index         （詳細不明）
  :title                ダイアログのタイトル
  :default              デフォルトのファイル名
  :initial-directory    初期表示するディレクトリ
  :extension            （詳細不明）
  :save                 non nilならファイル名を付けて保存？
  :multiple             non nilなら複数ファイル指定可
  :must-exist           non nilなら存在しないファイルを指定できない
  :explorer             （詳細不明）
  :hide-read-only       Read Onlyなファイルを表示しない？

使用例：
  ;;; タイトルをFooにして、複数選択可能なダイアログを表示する。
  (file-name-dialog :title "Foo"
                    :multiple t
                    :filter '(("すべてのファイル(*.*)" . "*.*")))
  => ("C:/applications/xyzzy/xyzzycli.exe")
```

関連: `directory-name-dialog`, `open-file-dialog`, `read-directory-name`

## `ime-register-word-dialog`

- Function / package: editor / 定義: kanji.l
- 呼び出し: `ime-register-word-dialog`

```text
単語/用例登録ダイアログを表示します。[C-c C-r]
セレクションがあれば、セレクションの文字列を語句とします。
```

## `mark-dialog-box`

- Function / package: editor / 定義: gmark.l
- 呼び出し: `mark-dialog-box`

```text
マークダイアログを表示します。[C-F2]

マークダイアログからは、グローバルマークを設定することができ、複数のポイ
ント間を移動することができます。

  移動   : 選択したマークに移動します。
  追加   : マークを追加します。
  削除   : 選択したマークを削除します。
  全削除 : 全てのマークを削除します。
```

## `message-box`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `message-box MESSAGE &optional TITLE STYLES &key :button1 :button2 :button3 :button4 :button5 :no-wrap`

```text
yes-or-no-p 系よりも柔軟なダイアログを表示します。

  MESSAGE  : ダイアログに表示するメッセージを指定します。
  TITLE    : ダイアログのタイトルを指定します。
  STYLES   : ダイアログのスタイルをリストで指定します。
        :ok                     [OK] を表示します。
        :ok-cancel              [OK][キャンセル] を表示します。
        :yes-no                 [はい][いいえ] を表示します。
        :yes-no-cancel          [はい][いいえ][キャンセル] を表示します。
        :abort-retry-ignore     [中止][再試行][無視] を表示します。
        :information            (i) インフォメーションマークを表示します。
        :exclamation            (!) 感嘆符を表示します。
        :question               (?) 疑問符を表示します。
        :button1                ボタン 1 をデフォルト選択にします。
        :button2                ボタン 2 をデフォルト選択にします。
        :button3                ボタン 3 をデフォルト選択にします。
        :button4                ボタン 4 をデフォルト選択にします。
        :button5                ボタン 5 をデフォルト選択にします。
  :BUTTON1 : ボタン 1 のテキストを変更します。
  :BUTTON2 : ボタン 2 のテキストを変更します。
  :BUTTON3 : ボタン 3 のテキストを変更します。
  :BUTTON4 : ボタン 4 のテキストを変更します。
  :BUTTON5 : ボタン 5 のテキストを変更します。
  :NO-WRAP : MESSAGE が長すぎるときに折り返すかを制御します。
        t       長くとも折り返さない。
        nil     長ければ折り返す。

ボタンを押したときの戻り値は、それぞれ以下のとおりです。

  :ok     [OK] を選択
  :cancel [キャンセル] を選択
  :yes    [はい] を選択
  :no     [いいえ] を選択
  :abort  [中止] を選択
  :retry  [再試行] を選択
  :ignore [無視] を選択

使用例：
  ;;; [はい][いいえ][キャンセル] を表示し選択させます。
  (message-box "メールを送信しますか?" nil
    '(:yes-no-cancel :question :button1))
  => :yes

  ;;; ダイアログの結果を case で場合わけしてみる
  (case (message-box "メールを送信しますか?" nil
                     '(:yes-no-cancel :question :button1))
    (:yes (den8-draft-send t))
    (:no t)
    (t nil))
```

関連: `yes-or-no-p`, `msgbox`

## `msgbox`

- Function / package: editor / 定義: misc.l
- 呼び出し: `msgbox FMT &rest ARGS`

```text
メッセージボックスを表示します。
[OK] ボタンとインフォメーションアイコンが表示されます。

  FMT  : format の出力書式と同じものを指定できます。
  ARGS : 出力書式へのパラメタとなります。

戻り値は :ok となります。

使用例：
  ;;; 出力書式で整形してみる。
  (msgbox "このバッファは ~A です。" buffer-mode)
  => :ok
```

関連: `message-box`, `format`

## `no-or-yes-p`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `no-or-yes-p FMT &rest ARGS`

```text
「はい」「いいえ」のボタン付メッセージボックスを表示します。
デフォルトは「いいえ」です。

  t     「はい」を選択
  nil   「いいえ」を選択

使用例：
  ;;; ダイアログを表示して選択させる。
  (no-or-yes-p "foo")
  => t          ; 「はい」を選択
```

関連: `yes-or-no-p`, `y-or-n-p`, `yes-no-or-cancel-p`

## `print-dialog`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `print-dialog &optional BUFFER`

```text
指定されたバッファBUFFERの印刷用のダイアログを表示します。
```

関連: `print-buffer`

## `yes-no-or-cancel-p`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `yes-no-or-cancel-p FMT &rest ARGS`

```text
「はい」「いいえ」「キャンセル」のボタン付メッセージボックスを表示します。
デフォルトは「はい」です。「キャンセル」を選択した場合には、quitが実行されます。

  t     「はい」を選択
  nil   「いいえ」を選択

使用例：
  ;;; ダイアログを表示して選択させる。
  (yes-no-or-cancel-p "foo")
  => t          ; 「はい」を選択
  (yes-no-or-cancel-p "foo")
  => nil        ; 「いいえ」を選択
```

関連: `yes-or-no-p`, `no-or-yes-p`, `y-or-n-p`

## `yes-or-no-p`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `yes-or-no-p FMT &rest ARGS`

```text
「はい」「いいえ」のボタン付メッセージボックスを表示します。デフォルトは
「はい」です。

  FMT  : format同様の書式が指定できます。
  ARGS : 出力書式へのパラメタとなります。

戻り値は以下のとおりです。

  t     「はい」を選択
  nil   「いいえ」を選択

使用例：
  ;;; ダイアログを表示して選択させる。
  (yes-or-no-p "foo")
  => t          ; 「はい」を選択
  (yes-or-no-p "~A" "hogehoge")  
  => nil        ; 「いいえ」を選択
```

関連: `no-or-yes-p`, `y-or-n-p`, `yes-no-or-cancel-p`, `message-box`
