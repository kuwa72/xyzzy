# その他 (misc)

reference/reference.xml から自動生成。64 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*popup-completion-list-default*`

- Variable / package: editor / 定義: complete.l

```text
補完リスト表示のデフォルトの動作を制御します。
  :always   必ずポップアップ表示します。
  :never    *Completion*バッファで表示します。
  上記以外  個々の設定(*minibuffer-popup-completion-list*等)が
            適用されます。
```

関連: `*minibuffer-popup-completion-list*`, `*lisp-popup-completion-list*`

## `*print-option-show-dialog*`

- Variable / package: editor / 定義: estartup.l

```text
nilの場合は、コマンドラインオプションで -p を指定した時、印刷ダイアログ
を表示しません。
```

## `add-file-history-to-menu`

- Function / package: editor / 定義: app-menu.l
- 呼び出し: `add-file-history-to-menu`

```text
ファイルメニューの履歴のところに履歴を記録する？
（詳細不明）
(add-file-history-to-menu)
```

関連: `*minibuffer-file-name-history*`

## `C-z でアイコン化させるには？`

- Tips

```text
(require "wip/winapi")
(c:define-dll-entry winapi:BOOL ShowWindow (winapi:HWND c:int) "user32")

(global-set-key #\C-z #'(lambda () (interactive)
                          (ShowWindow (get-window-handle) 6)))
```

## `continue-popup`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `continue-popup`

```text
popup-stringで前回表示した内容を再度表示します。
```

関連: `popup-string`

## `convert-encoding-from-internal`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `convert-encoding-from-internal ENCODING INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
与えられた文字列やストリームを内部コードからENCODINGに変換します。

　ENCODING               : 出力ストリームのエンコーディング
                           encoding.lに大量に定義してある*encoding-euc-jp*など
  INPUT-STRING-OR-STREAM : 変換する文字列またはストリーム
  OUTPUT-STREAM          : 出力するストリーム

戻り値は以下の通りです。

  文字列 OUTPUT-STREAMがnilの時(指定しないときもnilとみなされます)
  t      ストリームに出力したとき
```

関連: `convert-encoding-to-internal`, `detect-char-encoding`

## `convert-encoding-to-internal`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `convert-encoding-to-internal ENCODING INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
与えられた文字列やストリームをENCODINGから内部コードに変換します。

　ENCODING               : 入力ストリームのエンコーディング
                           encoding.lに大量に定義してある
                           *encoding-euc-jp*などやdetect-char-encodingの
                           戻り値を利用するのも良いでしょう
  INPUT-STRING-OR-STREAM : 変換する文字列またはストリーム
  OUTPUT-STREAM          : 出力するストリーム

戻り値は以下の通りです。

  文字列 OUTPUT-STREAMがnilの時(指定しないときもnilとみなされます)
  t      ストリームに出力したとき
```

関連: `convert-encoding-from-internal`, `detect-char-encoding`

## `decode-mime-header`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `decode-mime-header`

```text
現在行から下にRFC822ヘッダを探してMIMEデコードします。
```

## `ding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ding`

```text
音を鳴らします？（詳細不明）

使用例：
  ;;; 音を鳴らす。
  (ding)
  => nil
```

関連: `undefined`

## `do-events`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `do-events`

```text
長い処理の途中に、Windowsのイベントを処理してあげるおまじないらしい。

使用例：
  ;;; イベント処理をしてみる。
  (do-events)
  => nil
```

関連: `refresh-screen`, `sit-for`, `sleep-for`

## `DOSのコマンドをキックして結果を文字列にするには？`

- Tips

```text
| DOSのコマンド(コンソールアプリって言ったほうがいいのかな？）
| をキックして、結果を文字列として、取り出す事はできますか？

こんな感じでしょうか。

(defun command-substitution (command)
  (let ((outfile nil)
        (buffer nil))
    (unwind-protect
        (save-excursion
          (setq buffer (create-new-buffer "*foo*"))
          (setq outfile (make-temp-file-name))
          (call-process command :output outfile :show :hide :wait t)
          (set-buffer buffer)
          (insert-file-contents outfile)
          (goto-char (1- (point-max)))
          (when (looking-for "\n")
            (delete-char 1))
          (goto-char (point-min))
          (replace-buffer "\n+" " " :regexp t)
          (buffer-substring (point-min) (point-max)))
      (and buffer
           (delete-buffer buffer))
      (and outfile
           (delete-file outfile)))))
```

## `ed::get-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `get-register R`

```text
レジスタ R の値を返します。何も入ってない場合の戻り値は nil です。
```

関連: `ed::set-register`, `view-register`

## `ed::set-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `set-register R VALUE`

```text
レジスタ R に値 VALUE を格納します。
```

関連: `ed::get-register`, `view-register`

## `gc`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `gc &optional NO-MESSAGE`

```text
（多分）ゴミ集めをします。
```

## `get-image-size`

- Function / package: editor / 定義: imagehdr.l
- 呼び出し: `get-image-size FILENAME`

```text
指定された画像ファイルの縦・横・フォーマットを取得することが可能です。

使用例：
  ;;; imageタグを挿入してみる
  (require "imagehdr")
  (defun html-write-image-tag (file)
    (interactive "fJPEG, GIF, PNG : ")
    (multiple-value-bind (width height fmt)
      (get-image-size file)
      (insert (format nil "<IMG SRC=\"~a\" WIDTH=~d HEIGHT=~d>" file width height))))
```

## `list-server-resources`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-server-resources SERVER-NAME &optional COMMENT-P`

```text
指定されたコンピュータの共有資源の一覧を取得します。
同時に資源のコメントも取得可能です。

使用例：
  (list-server-resources "SAMURAI")
  => ("SPOOL" "E" "D" "A")
  (list-server-resources "SAMURAI" t)
  => (("SPOOL" "") ("E" "CD-ROM Drive") ("D" "Backup Storage") ("A" "FD Drive"))
```

関連: `list-servers`

## `list-servers`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-servers &optional COMMENT-P`

```text
ネットワークコンピュータの一覧が取得できます。
同時にコンピュータに設定されているコメントも取得可能です。

使用例：
  (list-servers)
  => ("SAMURAI" "ROUNIN")
  (list-servers t)
  => (("SAMURAI" "Main Machine") ("ROUNIN" "Sub Machine"))
```

関連: `list-server-resources`

## `load-keyword-file`

- Function / package: editor / 定義: kwd.l
- 呼び出し: `load-keyword-file NAME &optional ICASE TABLE CONDITION`

```text
キーワードファイルをロードします。

使用例：
  (and *xmldoc-keyword-file*
       (null *xmldoc-keyword-hash-table*)
       (setq *xmldoc-keyword-hash-table*
             (load-keyword-file *xmldoc-keyword-file* t)))
  (when *xmldoc-keyword-hash-table*
    (make-local-variable 'keyword-hash-table)
    (setq keyword-hash-table *xmldoc-keyword-hash-table*))

補足：
  xyzzy 0.2.2.236 から NAME には複数のキーワードファイルを
  リストで指定可能です。
```

関連: `キーワードファイルの書き方`, `キーワードファイルのカスタマイズ`, `*keyword-load-path*`, `make-list-from-keyword-table`

## `long-operation`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `long-operation &rest BODY`

```text
カーソルを砂時計にします。明らかに処理時間が長いことが見込まれる場合にし
ようすると良いと思います。

使用例：
  (long-operation
     (message "start")
     ;; 何か長い処理
     (message "end"))
```

関連: `begin-wait-cursor`, `end-wait-cursor`

## `lookup-dictionary`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `lookup-dictionary DIRECTORY DIC-FILE INDEX-FILE WORD`

```text
辞書引き機能
（詳細不明）

使用例：
  (lookup-dictionary *edict-dictionary-path* "xyzzydic" "xyzzye2j" s)
```

## `not`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `not X`

```text
否定を返します。
non nilならばnilを返し、nilならばtを返します。機能としてはnullと同じです。
```

関連: `null`

## `number-of-function-bar-labels`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `number-of-function-bar-labels`

```text
ファンクションバーのラベルの数を返します。非表示の場合でも数値を返します。
```

関連: `set-number-of-function-bar-labels`

## `OLEオートメーションの使用例`

- Tips

```text
; 意味もなく全部のシートに「東西南北」を書き込む
(setq application (ole-create-object "Excel.Application"))
(ole-putprop application 'visible 1)
(setq workbook (ole-method (ole-getprop application 'Workbooks) 'Add))
(setq numbers-of-worksheets
      (ole-getprop
       (ole-getprop workbook 'worksheets)
       'count))
(setq worksheet-index 1)
(while (<= worksheet-index numbers-of-worksheets)
  (setq worksheet
 (ole-getprop workbook 'Worksheets worksheet-index))
  (ole-putprop (ole-method worksheet 'Range "A1:D1")
        'value #("東" "西" "南" "北"))
  (setq worksheet-index (+ worksheet-index 1)))


こんな小細工をしてみたんですけどどうでしょう?

(defmacro $ (obj prop &rest args)
  `(ole-method ,obj ',prop ,@args))

(defsetf $ (obj prop &rest args) (x)
  `(progn
     (ole-putprop ,obj ',prop ,x ,@args)
     ,x))

(let (app workbook worksheet range)
  (setq app (ole-create-object "Excel.Application"))
  (setf ($ app Visible) t)
  (setq workbook ($ ($ app Workbooks) Add))
  (setq worksheet ($ workbook Worksheets 1))
  (setf ($ ($ worksheet Range "A1:D1") Value) '("North" "South" "East" "West"))
  (setf ($ ($ worksheet Range "A2:B2") Value) #(5.2 10))
  (setf ($ ($ worksheet Range "C2") Value) 8)
  (setf ($ ($ worksheet Range "D2") Value) 20)

  (setq range ($ worksheet Range "A1:D2"))
  ($ range Select)
  ($ ($ workbook Charts) Add)
  (sit-for 5)

  (setf ($ workbook saved) t)
  ($ ($ app ActiveWorkbook) Close 0)
  ($ app Quit))
```

## `popup-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `popup-list LIST CALLBACK &optional POINT`

```text
ポップアップリストを表示します。選択された項目を引数にコールバッ
ク関数が呼び出されます。

使用例：
  (defun func ()
    (popup-list
       '("123" "abc" "xyz")
       #'(lambda (x) (msgbox "\"~A\" selected" x))))
  => func
```

関連: `dabbrev-popup`, `popup-string`

## `popup-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `popup-string STRING POINT &optional TIMEOUT`

```text
文字列をポップアップさせます。ツールチップのポップみたいな表示です。

  STRING  : ポップアップさせる文字列を指定します。
  POINT   : 文字列を表示する位置をポイントで指定します。
  TIMEOUT : 表示を止めるまでの秒数を指定します。
```

関連: `popup-list`, `continue-popup`, `track-popup-menu`

## `refresh-screen`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `refresh-screen &optional F`

```text
画面をリフレッシュします。
キー入力の方が画面の再描画よりも優先されます。従って、外部プロセスから非
同期に入力される文字列をバッファに出力したり、処理の途中でダイアログを表
示すると、画面が追いついていない場合があります。そのような場合に実行します。
```

関連: `do-events`, `sit-for`, `sleep-for`

## `set-fill-prefix`

- Function / package: editor / 定義: fill.l
- 呼び出し: `set-fill-prefix`

```text
行頭からポイントまでをfill prefixに設定します。 [C-x .]
行頭で実行された場合には、fill prefixはクリアされます。auto-fill-mode
では、折り返しが行なわれると行頭にfill prefixが挿入されます。
```

関連: `fill-prefix`, `auto-fill-mode`

## `set-number-of-function-bar-labels`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-number-of-function-bar-labels N`

```text
ファンクションバーのラベルの数を設定します。指定できる数は、
4/5/8/10/12/15です。
[共通設定] - [表示] - [ファンクションキー] のところでも値を設定できます。
```

関連: `number-of-function-bar-labels`

## `show-html-help`

- Function / package: editor / 定義: winhelp.l
- 呼び出し: `show-html-help`

```text
カーソル位置の文字列を HTML Help から検索します。
*html-help-path* に設定されたヘルプファイルが使用されます。

*html-help-path* の値は、「共通設定」-「ディレクトリ」-「HTML ヘルプ」-
「COL/CHMファイル」から設定できるみたいです。
```

## `show-winhelp`

- Function / package: editor / 定義: winhelp.l
- 呼び出し: `show-winhelp`

```text
カーソル位置の文字列を WinHelp から検索します。[C-F1]
*winhelp-path* に設定されたヘルプファイルが使用されます。
```

## `si:*activate-toplevel`

- Function / package: system / 定義: builtin.l
- 呼び出し: `*activate-toplevel`

```text
xyzzyを他のウィンドウの最前面に表示します。
```

## `si:*app-user-model-id`

- Function / package: system / 定義: builtin.l
- 呼び出し: `*app-user-model-id`

```text
xyzzyのアプリケーションIDを返します。
Windows 7以降のタスクバーではこのアプリケーションIDを元に
ウィンドウをグループ化して管理します。

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

関連: `create-shortcut`

## `si:base64-decode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `base64-decode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM FOLD-WIDTH`

```text
Base64でデコードします。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力のストリームを指定します。
        nil     デコードの結果はbase64-decodeの戻り値となります。
        nil以外 デコードの結果はOUTPUT-STREAMに出力されます。

使用例：
  (si:base64-decode "gtmCsILZgrA=")
  => "ほげほげ"
```

関連: `si:base64-encode`

## `si:base64-encode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `base64-encode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
Base64エンコードします。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力のストリームを指定します。
        nil     エンコードの結果はbase64-encodeの戻り値となります。
        nil以外 エンコードの結果はOUTPUT-STREAMに出力されます。

使用例：  
  (si:base64-encode "ほげほげ")
  => "gtmCsILZgrA="
```

関連: `si:base64-decode`

## `si:closure-variable`

- Function / package: system / 定義: builtin.l
- 呼び出し: `si:closure-variable CLOSURE`

```text
クロージャの中身を覗くための関数です。

  CLOSURE : レキシカルクロージャもしくは関数定義に
            レキシカルクロージャを持つシンボルを指定します。

以下の関数でクロージャを参照することが可能です。

  si:closure-variable closure
  si:closure-function closure
  si:closure-frame closure
  si:closure-body closure

使用例：
  (setq foo (let ((x 3)) #'(lambda () (incf x) x)))
  => #<lexical-closure: (anonymous)>
  (funcall foo)
  => 4
  (funcall foo)
  => 5
  (si:closure-variable foo)
  => ((x . 5))
```

## `si:hmac-md5`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-md5 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
MD5 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-md5 "secret" "ほげほげ")
  => "12a092046e2629830aca05cc2c85b3af"

  (delete #\LFD (si:base64-encode (si:hmac-md5 "secret" "ほげほげ" :binary t)))
  => "EqCSBG4mKYMKygXMLIWzrw=="

補足：
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-sha-1`, `si:hmac-sha-224`, `si:hmac-sha-256`, `si:hmac-sha-384`, `si:hmac-sha-512`

## `si:hmac-sha-1`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-sha-1 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
SHA1 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-sha-1 "secret" "ほげほげ")
  => "79b224aa36871315b272fa2d62197b54566f5580"

  (delete #\LFD (si:base64-encode (si:hmac-sha-1 "secret" "ほげほげ" :binary t)))
  => "ebIkqjaHExWycvotYhl7VFZvVYA="

補足：
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-md5`, `si:hmac-sha-224`, `si:hmac-sha-256`, `si:hmac-sha-384`, `si:hmac-sha-512`

## `si:hmac-sha-224`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-sha-224 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
SHA224 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-sha-224 "secret" "ほげほげ")
  => "6ae2369b6dbad816a088f000a0239511fc0ebec228048b3e27e69b17"

  (delete #\LFD (si:base64-encode (si:hmac-sha-224 "secret" "ほげほげ" :binary t)))
  => "auI2m2262BagiPAAoCOVEfwOvsIoBIs+J+abFw=="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-md5`, `si:hmac-sha-1`, `si:hmac-sha-256`, `si:hmac-sha-384`, `si:hmac-sha-512`

## `si:hmac-sha-256`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-sha-256 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
SHA256 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-sha-256 "secret" "ほげほげ")
  => "b965ae8881656b71b29fbdab349fcfe7769d5cd26bce81cc9616205b4c7a9e6e"

  (delete #\LFD (si:base64-encode (si:hmac-sha-256 "secret" "ほげほげ" :binary t)))
  => "uWWuiIFla3Gyn72rNJ/P53adXNJrzoHMlhYgW0x6nm4="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-md5`, `si:hmac-sha-1`, `si:hmac-sha-224`, `si:hmac-sha-384`, `si:hmac-sha-512`

## `si:hmac-sha-384`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-sha-384 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
SHA384 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-sha-384 "secret" "ほげほげ")
  => "41a30b9a8e3dd864a20fb1af62b3baa58ddfaea64bc45c817e0803fd1b9ac7437049cd116a97145238cc1b6a0c06a9c5"

  (delete #\LFD (si:base64-encode (si:hmac-sha-384 "secret" "ほげほげ" :binary t)))
  => "QaMLmo492GSiD7GvYrO6pY3frqZLxFyBfggD/Ruax0NwSc0RapcUUjjMG2oMBqnF"

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-md5`, `si:hmac-sha-1`, `si:hmac-sha-224`, `si:hmac-sha-256`, `si:hmac-sha-512`

## `si:hmac-sha-512`

- Function / package: system / 定義: builtin.l
- 呼び出し: `hmac-sha-512 KEY INPUT-STRING-OR-STREAM &key :binary`

```text
SHA512 関数を利用してメッセージ認証コード値を得ます。

  KEY                    : 秘密鍵
  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:hmac-sha-512 "secret" "ほげほげ")
  => "84410143a5b046a25d9c508e1ac1cdfecff665ae580844fc13f2b22a374e0392ccdc54eb65934d93985ae2130a7e9948e4b8639c117a87f484b5033fd47871f4"

  (delete #\LFD (si:base64-encode (si:hmac-sha-512 "secret" "ほげほげ" :binary t)))
  => "hEEBQ6WwRqJdnFCOGsHN/s/2Za5YCET8E/KyKjdOA5LM3FTrZZNNk5ha4hMKfplI5LhjnBF6h/SEtQM/1Hhx9A=="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:hmac-md5`, `si:hmac-sha-1`, `si:hmac-sha-224`, `si:hmac-sha-256`, `si:hmac-sha-384`

## `si:md5`

- Function / package: system / 定義: builtin.l
- 呼び出し: `md5 INPUT-STRING-OR-STREAM &key :binary`

```text
MD5ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：  
  (si:md5 "ほげほげ")
  => "11e100e3eb6e6171d9681ba6641794e3"

  (delete #\LFD (si:base64-encode (si:md5 "ほげほげ" :binary t)))
  => "EeEA4+tuYXHZaBumZBeU4w=="

補足：
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

## `si:octet-length`

- Function / package: system / 定義: builtin.l
- 呼び出し: `octet-length STRING &key :encoding :start :end`

```text
指定したエンコーディングでエンコードした場合の文字列のバイトサイズを求めます。

  STRING    : バイトサイズを求める文字列
  :encoding : エンコーディング。デフォルトはエンコーディング変換なし
  :start    : 開始位置。デフォルトは 0 で非負の整数
  :end      : 終了位置。デフォルトは nil で、 nil の場合は文字列の長さを
              指定した場合と等しい動作

使用例：
  (si:octet-length "abc")
  => 3
  (si:octet-length "abcあいう")
  => 9
  (si:octet-length "abcアイウ" :start 1 :end 5)
  => 6
  (si:octet-length "abcアイウ" :encoding *encoding-utf8n*)
  => 12
  (si:octet-length (convert-encoding-from-internal *encoding-utf8n* "abcアイウ"))
  => 12

補足：
  xyzzy 0.2.2.238 から利用可能です。
```

## `si:quoted-printable-decode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `quoted-printable-decode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM UNDERSCORE-TO-SPACE`

```text
Quoted-Printableデコードします。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力のストリームを指定します。
        nil     デコードの結果はquoted-printable-decodeの戻り値となります。
        nil以外 デコードの結果はOUTPUT-STREAMに出力されます。
```

## `si:sha-1`

- Function / package: system / 定義: builtin.l
- 呼び出し: `sha-1 INPUT-STRING-OR-STREAM &key :binary`

```text
SHA1 ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:sha-1 "ほげほげ")
  => "ac4dfa2e4d091a8636ea740e326bb72e6e7749a0"

  (delete #\LFD (si:base64-encode (si:sha-1 "ほげほげ" :binary t)))
  => "rE36Lk0JGoY26nQOMmu3Lm53SaA="

補足：
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:md5`, `si:sha-224`, `si:sha-256`, `si:sha-384`, `si:sha-512`

## `si:sha-224`

- Function / package: system / 定義: builtin.l
- 呼び出し: `sha-224 INPUT-STRING-OR-STREAM &key :binary`

```text
SHA224 ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:sha-224 "ほげほげ")
  => "310aa231065ce5c0cd397c2de10dba942fc6580e3631b6354446664d"

  (delete #\LFD (si:base64-encode (si:sha-224 "ほげほげ" :binary t)))
  => "MQqiMQZc5cDNOXwt4Q26lC/GWA42MbY1REZmTQ=="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:md5`, `si:sha-1`, `si:sha-256`, `si:sha-384`, `si:sha-512`

## `si:sha-256`

- Function / package: system / 定義: builtin.l
- 呼び出し: `sha-256 INPUT-STRING-OR-STREAM &key :binary`

```text
SHA256 ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:sha-256 "ほげほげ")
  => "2f33a6ce8c3ebaf0f3af2f7c6e90d532dcb0e733c8ef2e4f55485302d64de910"

  (delete #\LFD (si:base64-encode (si:sha-256 "ほげほげ" :binary t)))
  => "LzOmzow+uvDzry98bpDVMtyw5zPI7y5PVUhTAtZN6RA="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:md5`, `si:sha-1`, `si:sha-224`, `si:sha-384`, `si:sha-512`

## `si:sha-384`

- Function / package: system / 定義: builtin.l
- 呼び出し: `sha-384 INPUT-STRING-OR-STREAM &key :binary`

```text
SHA384 ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:sha-384 "ほげほげ")
  => "a54809e2c52b54e5832ad827dd397a25f73c2997027f7d0da102a2090bc64d29db9f5a95c301abfc5aa62ea35ca9a612"

  (delete #\LFD (si:base64-encode (si:sha-384 "ほげほげ" :binary t)))
  => "pUgJ4sUrVOWDKtgn3Tl6Jfc8KZcCf30NoQKiCQvGTSnbn1qVwwGr/FqmLqNcqaYS"

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:md5`, `si:sha-1`, `si:sha-224`, `si:sha-256`, `si:sha-512`

## `si:sha-512`

- Function / package: system / 定義: builtin.l
- 呼び出し: `sha-512 INPUT-STRING-OR-STREAM &key :binary`

```text
SHA512 ハッシュ値を得ます。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  :binary                : nilを指定するとハッシュ値を16進文字列にエンコードします。
                           non-nilを指定するとハッシュ値を文字列でそのまま返します。

使用例：
  (si:sha-512 "ほげほげ")
  => "ae86321f351722bc915b1c5b75262e086bcf074aa8bdd496773d55f267b07d7ce8b58b29680ca821ee3e68c2b50ebe070ac7f183e2663af6b4226e0d400fd782"

  (delete #\LFD (si:base64-encode (si:sha-512 "ほげほげ" :binary t)))
  => "roYyHzUXIryRWxxbdSYuCGvPB0qovdSWdz1V8mewfXzotYspaAyoIe4+aMK1Dr4HCsfxg+JmOva0Im4NQA/Xgg=="

補足：
  xyzzy 0.2.2.236 から利用可能です。
  :binary 引数は xyzzy 0.2.2.242 から利用可能です。
```

関連: `si:md5`, `si:sha-1`, `si:sha-224`, `si:sha-256`, `si:sha-384`

## `si:uudecode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `uudecode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
uudecodeします。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力のストリームを指定します。
        nil     デコードの結果はuudecodeの戻り値となります。
        nil以外 デコードの結果はOUTPUT-STREAMに出力されます。
```

関連: `si:uuencode`

## `si:uuencode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `uuencode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
uuencodeします。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力のストリームを指定します。
        nil     エンコードの結果はuuencodeの戻り値となります。
        nil以外 エンコードの結果はOUTPUT-STREAMに出力されます。
```

関連: `si:uudecode`

## `si:uuid-create`

- Function / package: system / 定義: builtin.l
- 呼び出し: `uuid-create &key :sequential`

```text
UUIDを生成し文字列とリストの多値で返します。

  :sequential : non-nilを指定すると連番のUUIDを生成します。

リストは以下の形式になっています。

  (time-low
   time-mid
   time-high-and-version
   clock-seq-and-reserved
   clock-seq-low
   (node-octet0
    node-octet1
    ...
    node-octet5))

使用例：

  (si:uuid-create)
  => "0035e2b2-9839-48c6-a914-9c2928d0cd53"
  => (3531442 38969 18630 169 20 (156 41 40 208 205 83))

  (apply 'format nil "~8,'0X-~4,'0X-~4,'0X-~2,'0X~2,'0X-~{~2,'0X~}"
         '(3531442 38969 18630 169 20 (156 41 40 208 205 83)))
  => "0035e2b2-9839-48c6-a914-9c2928d0cd53"

  (si:uuid-create :sequential t)
  => "e05fe0ee-7561-11e1-ba61-000c29aae86e"
  => (3764379886 30049 4577 186 97 (0 12 41 170 232 110))

  (si:uuid-create :sequential t)
  => "e05fe0ef-7561-11e1-ba61-000c29aae86e"
  => (3764379887 30049 4577 186 97 (0 12 41 170 232 110))

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `si:www-url-decode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `www-url-decode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM`

```text
URL デコードを行います。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力ストリームです。
                           t を指定した場合は標準出力へ出力します。
                           省略もしくは nil を指定すると戻り値になります。

使用例:
  (si:www-url-decode "%82%D9%82%B0%82%D9%82%B0" nil)
  =>"ほげほげ"

補足:
  xyzzy 0.2.2.233 では builtin.l 中の引数の記述が間違っています。
  0.2.2.234 で修正されました。
```

関連: `si:www-url-encode`

## `si:www-url-encode`

- Function / package: system / 定義: builtin.l
- 呼び出し: `www-url-encode INPUT-STRING-OR-STREAM &optional OUTPUT-STREAM LITERAL-CHARS`

```text
RFC1738 に基づき文字列の URL エンコードを行います。

  INPUT-STRING-OR-STREAM : 入力の文字列または入力ストリームを指定します。
  OUTPUT-STREAM          : 出力ストリームです。
                           t を指定した場合は標準出力へ出力します。
                           省略もしくは nil を指定すると戻り値になります。
  LITERAL-CHARS          : エンコードしない文字群を指定します。
     t                       すべての文字をエンコードする
     nil                     "-A-Za-z0-9$_.+!*'(|),"と同値

使用例:
  ; 標準では Shift_JIS としてエンコード
  (si:www-url-encode "かめ")
  =>"%82%A9%82%DF"
  
  ; EUC-JP としてエンコード
  (si:www-url-encode (map-internal-to-euc "かめ"))
  =>"%A4%AB%A4%E1"
  
  ; 変換しない文字群を明示する
  (si:www-url-encode "www-url-encode" nil "0-9A-Za-z")
  =>"www%2Durl%2Dencode"

補足:
  RFC1738は現在RFC3986によって更新されています。
  RFC3986で定義されている unreserved な文字の種類は "0-9A-Za-z---._~" です。

  xyzzy 0.2.2.233 では builtin.l 中の引数の記述が間違っています。
  0.2.2.234 で修正されました。
```

関連: `si:www-url-decode`

## `undefined`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `undefined`

```text
ベルを鳴らします。 ding の interactive 版です。

キーにコマンドが割り当てられてないことを表すのに使われることがあるようです。
```

関連: `ding`

## `update-mode-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `update-mode-line &optional BUFFER`

```text
モード行を更新します。mode-line-formatの変更などを行った場合に、速やかに
モード行に反映したい場合に実行します。
```

関連: `mode-line-format`

## `view-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `view-register R`

```text
レジスタ R の中身をバッファ *output* に表示します。
```

## `キーワードファイルのカスタマイズ`

- Tips

```text
キーワードファイルをカスタマイズするには以下の方法を推奨します。

  1. *keyword-load-path*にカスタマイズしたキーワードファイルを
     置く場所を指定する

     ;; 例) $XYZZY/keyword に置く場合
     (pushnew (merge-pathnames "keyword" (si:system-root))
              *keyword-load-path* :test #'string=)

  2. 上記場所にカスタマイズしたいキーワードファイルと
     同名のファイルを作成
  3. 先頭に ;@include <カスタマイズしたいファイル> を追加
  4. ;*-- は ;*+ などを使ってキーワードを追加・削除・色の変更

例：
  ;;;; C# のキーワードファイルのカスタマイズ
  ;;
  :: #reigon と #endregion はキーワード番号0の色を利用
  ;; LINQ のクエリ式のキーワードを削除
  ;; http://msdn.microsoft.com/en-us/library/bb310804.aspx

  ;; etc/C# の読み込み
  ;@include <C#>

  ;; 色の変更
  ;*0
  #region
  #endregion

  ;; キーワードの削除
  ;*--
  from
  where
  select
  group
  into
  orderby
  join
  let
  in
  on
  equals
  by
  ascending
  descending

備考：
  このカスタマイズ方法が使えるのはxyzzy 0.2.2.238以降です。
```

関連: `キーワードファイルの書き方`

## `キーワードファイルの書き方`

- Tips

```text
キーワードファイルは*keyword-load-path*もしくはetc-pathから検索
をします。$XYZZY/etc配下のファイルを参照して下さい。

形式：
  属性を指定する場合には以下の二つの形式で記述します。

  ;*n[attrib]
  ;**fg[bg[attrib]]

      n       キーワード番号(0-5) 3-5は0-2と同じ色の反転
      fg      文字色 0-f (0ならば普通の色)
      bg      背景色 0-f (0ならば普通の色）
      attrib  属性みたいなもの。以下のものの組み合わせ
              b bold
              u underline
              s strike-out
              l 一行丸ごと
  ;@include <path>  etc-pathからの相対パスでキーワードファイルを読み込む
  ;@include "path"  読み込み中のファイルからの相対パスでキーワードファイルを読み込む
  ;*+               conditionに関わらず以降を有効にする
  ;*-               conditionに関わらず以降を無効にする
                    キーワードが定義済みの場合は定義されたまま
  ;*--              conditionに関わらず以降を削除する
  ;*+item           itemがconditionに一致した場合に以降を有効にする
  ;*-item           itemがconditionに一致した場合に以降を無効にする
                    キーワードが定義済みの場合は定義されたまま
  ;*--item          itemがconditionに一致した場合に以降を削除する
  ;*&               以降はHTMLのタグ以外でも有効なキーワードとする
  ;*<               以降はHTMLのタグでのみ有効なキーワードとする

備考：
  load-keyword-fileに指定したconditionはitemと比較を行います。
  $XYZZY/lisp/html-kwd.lを参照。
  xyzzy 0.2.2.238から他のキーワードファイルの読み込み (;@include) と
  キーワードの削除 (;*--) が可能になりました。
  属性の指定はファイルローカルです。;@includeによって読み込んだ他の
  ファイルには影響を与えません。
```

関連: `キーワードファイルのカスタマイズ`

## `コマンドによりヒストリを変更するには？`

- Tips

```text
コマンド別にミニバッファのヒストリを管理する方法です。

  ;;; ヒストリのリスト
  (setq foo-history '("qux" "quux" "quuux"))
  
  ;;; 管理したいコマンド
  (defun foo ()
    (interactive)
    (list
     (let ((*minibuffer-default-history* foo-history)) ; ヒストリを設定する
       (prog1
         (completing-read
          "foo: "               ; プロンプト文字列
          '("foo" "bar" "baz")  ; 補完候補
          :must-match nil       ; 必ず補完候補にマッチしなきゃ駄目？
          :case-fold t)         ; 大文字小文字を区別する？
         ; 変更されたかもしれないから戻しておく
         (setq foo-history *minibuffer-default-history*)))))
```

## `ファイル操作の例`

- Tips

```text
(defun find-modify-save-test (file)
  (interactive "f")
  (let (temp-buffer)
    (unwind-protect
        (progn
          ;; テンポラリのバッファを作って
          (setq temp-buffer (create-new-buffer "*foo*"))
          ;; カレントバッファにして
          (set-buffer temp-buffer)
          ;; ファイルを読み込む
          (insert-file-contents (merge-pathnames file *src-dir*))
          (goto-char (point-min))
          ;; ここでいろいろやる

          ;; ファイルに書く
          (write-file (merge-pathnames file *dst-dir*)))
      ;; バッファを作っていたら消す(kill-bufferはうるさいのでdelete-bufferで)
      (when temp-buffer
        (delete-buffer temp-buffer)))))
```

## `印刷時のヘッダやフッタに関する表記`

- Tips

```text
印刷時のヘッダやフッタに関する表記方法です。以下は 
  Toy's xyzzy memo - Data Library -
  http://www.carabiner-systems.com/xyzzy/data.html)
からの引用です。

--- 引用 ---
印刷時のヘッダやフッタに関する表記 
header and footer 1999/12/25　Written by Tetsuya Kamei [xyzzy:03752] 

  %f   ファイル名
  %F   ファイル名 (ディレクトリ付き)
  %b   バッファ名
  %p   ページ番号
  %P   総ページ数

  %Y   西暦 (YYYY)
  %y   西暦 (YY)
  %m   月   (1～12)
  %0m  月   (01～12)
  %*m  月   (January～December)
  %:m  月   (Jan～Dec)
  %d   日   (1～31)
  %0d  日   (01～31)
  %*w  曜日 (Sunday～Saturday)
  %:w  曜日 (Sun～Sat)
  %w   曜日 (日～土)
  %h   時   (0～23)
  %0h  時   (00～23)
  %H   時   (0～11)
  %0H  時   (00～11)
  %:H  時   (1～12)
  %0:H 時   (01～12)
  %*H       (AM/PM)
  %*:H      (am/pm)
  %M   分   (0～59)
  %0M  分   (00～59)
  %s   秒   (0～59)
  %0s  秒   (00～59)

  %-   横線

  %l   以前を左詰め
  %r   以降を右詰め
       指定されない部分は中央揃え

  それ以外の文字はそのまま
  --------------------------------------------------------------------------------
  (デフォルト)
    [ヘッダ] %F%l%r%:w, %0d %:m %Y %0h:%0M:%0s
    [フッタ] - %p -
```

## `各種ロード関係の関数の違い`

- Tips

```text
load         インタプリタでloadします。

load-library *.lcがあればそれをロードします。
             *.lcがなければ*.lをロードします。

autoload     関数1つ単位で、呼ばれたときloadするようにできます。
             関数が呼ばれるまではloadされません。

require      あるライブラリをロードします。ただし、既に
             ロード済みならロードしません。

*modules*    この変数を見ると今どのモジュールがロード済か分かります。
             既にロード済だともうロードしません。
```

関連: `load`, `load-library`, `autoload`, `require`, `*modules*`

## `行番号等のON/OFF`

- Tips

```text
こんなに簡単にポップアップメニューから実行できます。

使用例：
  ;;; C-RBtnUpで独自のポップアップメニューにします。
  (global-set-key #\C-RBtnUp 'my-apps-popup)
  (defun my-apps-popup ()
    (interactive)
    (track-popup-menu  
     (define-popup-menu
              (:item nil "行番号(&L)"
               'toggle-line-number)
              (:item nil "スクロールバー(&B)"
               'toggle-vscroll-bar)
              (:item nil "モードライン(&M)"
               'toggle-mode-line)
              (:item nil "ファンクションキー(&F)"
               'toggle-function-bar)
              (:item nil "折り返し(&T)"
               'toggle-fold-line)
              (:item nil "リードオンリー(&R)"
               'toggle-read-only))))
```
