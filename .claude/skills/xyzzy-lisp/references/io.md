# 入出力 (io)

reference/reference.xml から自動生成。77 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*eol-cr*`

- Variable / package: editor / 定義: encoding.l

```text
改行コードのCRを表す値です。
プロセスやバッファの入出力の改行コードを設定するのに使用します。
```

関連: `*eol-lf*`, `*eol-crlf*`, `set-buffer-eol-code`

## `*eol-crlf*`

- Variable / package: editor / 定義: encoding.l

```text
改行コードのCRLFを表す値です。
プロセスやバッファの入出力の改行コードを設定するのに使用します。
```

関連: `*eol-cr*`, `*eol-lf*`, `set-buffer-eol-code`

## `*eol-lf*`

- Variable / package: editor / 定義: encoding.l

```text
改行コードのLFを表す値です。
プロセスやバッファの入出力の改行コードを設定するのに使用します。
```

関連: `*eol-cr*`, `*eol-crlf*`, `set-buffer-eol-code`

## `*keyboard*`

- Variable / package: editor

```text
キーボードからの入力を表すストリームです。
```

関連: `*standard-input*`

## `*readtable*`

- Variable / package: lisp

```text
現在のリードテーブルを格納している変数です。
```

関連: `si:*set-readtable-case`, `readtable-case`, `readtablep`, `copy-readtable`, `*ole-readtable*`

## `*standard-input*`

- Variable / package: lisp

```text
標準入力を表すストリームです。
普段はキーボードからの入力になっています。
```

関連: `*standard-output*`, `*keyboard*`

## `*standard-output*`

- Variable / package: lisp

```text
標準出力を表すストリームです。
普段はステータスバーのウィンドウへの出力になっています。
lisp-interaction-mode の C-j(eval-print-last-sexp) では
そのバッファへの出力になっています。

使用例：
  ;;; eval-expression で評価した場合
  *standard-output*  
  => #<status window stream 48042808>

  ;;; eval-print-last-sexp で評価した場合
  *standard-output*
  => #<buffer stream 48042280>
```

関連: `*standard-input*`

## `broadcast-stream-streams`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `broadcast-stream-streams BROADCAST-STREAM`

```text
make-broadcast-streamで作られたBROADCAST-STREAMの出力先のストリームのリ
ストを返します。

使用例：
  ;;; hogeの出力先をリストで得る。
  (with-open-stream (foo (open "foo.txt" :direction :output))
    (with-open-stream (bar (open "bar.txt" :direction :output))
      (with-open-stream (hoge (make-broadcast-stream foo bar))
        (broadcast-stream-streams hoge))))
  => (#<file-output stream: C:/applications/xyzzy/foo.txt>
      #<file-output stream: C:/applications/xyzzy/bar.txt>)
```

関連: `make-broadcast-stream`

## `buffer-stream-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-stream-buffer STREAM`

```text
buffer-streamであるストリームが関連付けられているバッファを返します。

  STREAM : buffer-streamであるストリームを指定します。
```

関連: `make-buffer-stream`, `buffer-stream-point`, `xyzzyで提供されているストリームの種類`

## `buffer-stream-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-stream-p STREAM`

```text
ストリームがbuffer-streamかどうかを返します。

  STREAM : 判定するストリーム

  t   ストリームはbuffer-streamである。
  nil ストリームはbuffer-streamではない。
```

関連: `make-buffer-stream`, `xyzzyで提供されているストリームの種類`

## `buffer-stream-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-stream-point STREAM`

```text
buffer-streamであるストリームの入出力のポイントを返します。

  STREAM : buffer-streamであるストリームを指定します。
```

関連: `buffer-stream-set-point`, `buffer-stream-buffer`, `file-position`, `make-buffer-stream`, `read`, `xyzzyで提供されているストリームの種類`

## `buffer-stream-set-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-stream-set-point STREAM POINT`

```text
buffer-streamであるストリームの入出力のポイントを指定します。

  STREAM : buffer-streamであるストリームを指定します。
  POINT  : buffer-stream上の入出力のポイントを指定します。

参考：
  misc.lの with-output-to-buffer とか with-input-from-buffer
```

関連: `buffer-stream-point`, `xyzzyで提供されているストリームの種類`

## `clear-input`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `clear-input &optional INPUT-STREAM`

```text
入力ストリームにバッファリングされている入力をクリアします。
```

関連: `open`

## `clear-message`

- Function / package: editor / 定義: misc.l
- 呼び出し: `clear-message`

```text
ステータスバーのメッセージを消去します。
```

関連: `message`

## `close`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `close STREAM &key :abort`

```text
指定されたストリームをクローズします。

  STREAM : クローズするストリームを指定します。
  :abort : 異常終了時に指定します。
        t       ストリームに対する副作用を取り消そうとします。
        nil     ストリーム普通に終了します。
```

関連: `open`

## `concatenated-stream-streams`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `concatenated-stream-streams CONCATENATED-STREAM`

```text
make-concatenated-streamで作られたCONCATENATED-STREAMの入力元のストリームのリ
ストを返します。

使用例：
  ;;; hogeの入力元をリストで得る。
  (with-open-stream (foo (make-string-input-stream "foo"))
    (with-open-stream (bar (make-string-input-stream "bar"))
      (with-open-stream (hoge (make-concatenated-stream foo bar))
        (concatenated-stream-streams hoge))))
  => (#<string-input stream 48042632>
      #<string-input stream 48042544>)
```

関連: `make-concatenated-stream`

## `connect`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `connect HOSTNAME SERVICE &key :encoding :ssl (:ssl-verify-mode :peer)`

```text
ホストのポートとのTCP接続を開きます。
成功すれば接続へのストリームを返します。

  HOSTNAME         : 接続先のホスト名またはIPアドレスを指定します。
  SERVICE          : サービス名またはポート番号を指定します。
  :encoding        : エンコーディングのモードを指定します。
        :binary        バイナリモードです。
        :text          テキストモードです。（省略時は:text）
        :canonical     :text と同じ意味になります。
        :raw           改行コードの扱いが、LF のみになります。
                       それ以外は :text と同じです。
  :ssl             : SSL通信を行う場合はtを指定します。
  :ssl-verify-mode : SSL証明書の検証モードを指定します。
        :none          サーバ証明書を検証しません。
        :peer          サーバ証明書を検証します。
                       検証が失敗した場合socket-errorが通知されます。
                       デフォルトは:peerです。

参考：
  ;;; http://www.yahoo.co.jp/を取得してみる。
  (with-open-stream (stream (connect "www.yahoo.co.jp" 80))
    (format stream "GET / HTTP/1.0\n\n")
    (while (setq in (read-line stream nil))
      (insert in "\n")))

  ;;; https://www.google.co.jp/を取得してみる。
  (with-open-stream (stream (connect "www.google.co.jp" "https" :ssl t))
    (format stream "GET / HTTP/1.1\n")
    (format stream "Host: www.google.co.jp\n\n")
    (while (setq in (read-line stream nil))
      (insert in "\n")))

備考：
  SSL接続は xyzzy 0.2.2.248 から利用可能です。
```

関連: `open-network-stream`, `socket-stream-ssl-p`, `ssl-do-handshake`, `xyzzyで提供されているストリームの種類`

## `copy-readtable`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-readtable &optional FROM-READTABLE TO-READTABLE`

```text
リードテーブルをコピーします。

  FROM-READTABLE : コピー元 (デフォルトは *readtable*)
                   nil を明示的に与えるとデフォルトのリードテーブルをコピー。
  TO-READTABLE   : コピー先。省略時は新しく作成。
```

関連: `*readtable*`

## `debug-output-stream-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `debug-output-stream-p STREAM`

```text
ストリームがdebug-output-streamかどうかを返します。

  STREAM : 判定するストリーム

  t   ストリームはdebug-output-streamである。
  nil ストリームはdebug-output-streamではない。

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `*debug-output*`, `xyzzyで提供されているストリームの種類`

## `echo-stream-input-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `echo-stream-input-stream ECHO-STREAM`

```text
make-echo-streamで作られたECHO-STREAMの入力元のストリームを返します。
```

関連: `make-echo-stream`

## `echo-stream-output-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `echo-stream-output-stream ECHO-STREAM`

```text
make-echo-streamで作られたECHO-STREAMの出力先のストリームを返します。
```

関連: `make-echo-stream`

## `file-position`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-position FILE-STREAM &optional POSITION`

```text
FILE-STREAM上の現在位置を取得・変更します。
POSITIONを省略すると、FILE-STREAMの現在位置を返します。
POSITIONを指定すると、FILE-STREAMの現在位置を変更します。

  FILE-STREAM : 入出力するストリームを指定します。
  POSITION    : ストリームの先頭からの位置を指定します。
                0を基底とするインデックスです。

POSITIONには負の数値を指定することはできません。
また、ストリームの終端を越えた数値を指定すると、
その間はNUL文字が詰められます。

使用例：
  ;;; "01234567"と出力後、移動して"abc"と出力します。
  (setq foo (open "abc.txt" :direction :output))
  => #<file-output stream: C:/applications/xyzzy/abc.txt>
  (princ "0123456" foo)         => "0123456"
  (file-position foo 10)        => t
  (princ "abc" foo)             => "abc"
  (close foo)                   => t
```

関連: `buffer-stream-point`, `buffer-stream-set-point`

## `format`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `format DESTINATION CONTROL-STRING &rest ARGUMENTS`

```text
出力書式に従って出力します。

  DESTINATION : 出力先を指定します。
        t       標準出力に出力
        nil     文字列として結果を返す
        fp      指定のストリームに出力

  CONTROL-STRING : 以下の出力指定子で整形します。
        ~A      Ascii（アスキー指示）。princタイプで出力。
        ~S      S-Expression（S式指示）。prin1タイプで出力。
        ~%      改行。~n%はn個の改行
        ~&      出力ストリームが行頭でなければ改行。fresh-line参照。
        ~|      改ページ
        ~~      Tilde（チルダ指示）
        ~改行   改行とそれに続く空白文字を無視する
        ~T      Tabulate（タブ指示）
        ~*      次のargumentを無視
        ~?      Indirection（間接指示）
        ~D      10進数
        ~B      Binary（2進指示）
        ~O      Octal（8進指示）
        ~X      Hexadecimal（16進指示）
        ~R      Radix（基数指示）
        ~P      Plural（複数形指示）
        ~C      Character（文字指示）
        ~F      Fixed-format floating-point（固定小数点形式浮動小数指示）
        ~E      Exponential floating-point（指数形式浮動小数指示）
        ~G      General floating-point（一般浮動小数点指示）
        ~$      Dollars floating-point（ドル浮動小数点指示）
        ~(      Case conversion（ケース変換指示）
        ~)      ~(を閉じる
        ~[      Conditional expression（条件選択指示）
        ~]      ~[を閉じる
        ~{      Iteration（反復指示）
        ~}      ~{を閉じる
        ~^      Up and out（ゼロ終了指示）

使用例:
  ;;; 整数に0を付けて出力 ("~[最小桁数][,パディング文字][,桁区切り文字]D")
  (format nil "~5,'0D" 4)
  => "00004"

  ;;; 整数を3桁ごとにカンマで区切って出力
  (format nil "~:D" 1234567890)
  => "1,234,567,890"

  ;;; 文字列を最低桁カラムになるように空白を追加して出力
  (format nil "~10A" "foo")
  => "       foo"
  (format nil "~10@A" "foo")
  => "foo       "

  ;;; ケース変換の例
  (format nil "~(~A~)" "FOO BAR")  ;全て小文字
  => "foo bar"
  (format nil "~:(~A~)" "foo bar") ;単語の先頭の文字を大文字
  => "Foo Bar"
  (format nil "~@(~A~)" "foo bar") ;先頭の文字を大文字
  => "Foo bar"
  (format nil "~:@(~A~)" "foo bar");全て大文字
  => "FOO BAR"

  ;;; 間接指示の例
  (format nil "~? ~D" "[~A ~D]" '("foo" 2) 3)
  => "[foo 2] 3"
  (format nil "~@? ~D" "[~A ~D]" "foo" 2 3)
  => "[foo 2] 3"

  ;;; 条件選択指示の例
  (format nil "Windows ~[NT~;98~;95~]" 0)
  => "Windows NT"
  (format nil "Windows ~[NT~;98~;95~]" 1)
  => "Windows 98"
  ;デフォルト値 "~:;"
  (format nil "Windows ~[NT~;98~;95~:;3.1~]" 5)
  => "Windows 3.1"

  ;;; 反復指示の例
  ; "~{" 引数はリスト
  (format nil "~{ ~A~}" '("dog" "cat" "pig"))
  => " dog cat pig"
  ; "~:{"  引数はリストのリスト
  (format nil "~:{[~A ~D]~}" '(("a" 1) ("b" 2) ("c" 3)))
  => "[a 1][b 2][c 3]"
  ; "~@{" 残りの引数をリストとして用いる
  (format nil "~@{[~A ~D]~}" "a" 1 "b" 2 "c" 3)
  => "[a 1][b 2][c 3]"
  ; "~@:{" 引数のリストをリストとして用いる
  (format nil "~:@{[~A ~D]~}" '("a" 1) '("b" 2) '("c" 3))
  => "[a 1][b 2][c 3]"

  ;;; ゼロ終了指示の例
  ;引数がなければ終了
  (format nil "Done.~^ ~D warning~:P.~^ ~D error~:P.")
  => "Done."
  (format nil "Done.~^ ~D warning~:P.~^ ~D error~:P." 3)
  => "Done. 3 warnings."
  (format nil "Done.~^ ~D warning~:P.~^ ~D error~:P." 3 5)
  => "Done. 3 warnings. 5 errors."

  ;;; 反復指示とゼロ終了指示
  ;副リストの中の引数がもうなければ "~{" をそこで閉じる
  (format nil "~:{/~S~^ ...~}" '((hot dog) (hamburger) (ice cream) (french fries)))
  => "/hot .../hamburger/ice .../french ..."
  ;リストが終わりならそこで ":{" 全体を終了
  (format nil "~:{/~S~:^ ...~}" '((hot dog) (hamburger) (ice cream) (french fries)))
  => "/hot .../hamburger .../ice .../french"
  ;副リストの中の引数がもうなければ全体を終了
  (format nil "~:{/~S~#:^ ...~}" '((hot dog) (hamburger) (ice cream) (french fries)))
  => "/hot .../hamburger"

  ;;; 16進数のformat書式の書き方
  (format nil "~2,'0x" 10)
  => "0a"
  (format nil "~:@(~2,'0x~)" 10)
  => "0A"
```

## `fresh-line`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fresh-line &optional OUTPUT-STREAM`

```text
OUTPUT-STREAM が行の先頭ではないときだけ改行 (#\LFD) を出力します。
```

関連: `terpri`

## `get-dispatch-macro-character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-dispatch-macro-character DISP-CHAR SUB-CHAR &optional READTABLE`

```text
ディスパッチマクロを取得します。
SUB-CHAR は大文字小文字を区別しません。

DISP-CHAR がディスパッチマクロ文字でなければエラーとなります。
```

関連: `make-dispatch-macro-character`, `set-dispatch-macro-character`

## `get-macro-character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-macro-character CHAR &optional READTABLE`

```text
マクロ文字 CHAR に割り当てられている関数を返します。マクロ文字でない
場合は nil を返します。
また、マクロ文字である場合には二番目の戻り値として CHAR が 
non-terminating かどうかを返します。

使用例：
  ;;; # は non-terminating macro character
  (get-macro-character #\#)
  => system:|#-reader|
  => t
  ;;; ' は terminating macro character
  (get-macro-character #\')
  => system:|'-reader|
  => nil
  ;;; A はマクロ文字ではない
  (get-macro-character #\A)
  => nil
```

関連: `set-macro-character`

## `listen`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `listen &optional INPUT-STREAM`

```text
指定された入力ストリームに何か入力がある状態ならばt、ないならばnilを返します。
```

関連: `read-char-no-hang`

## `make-broadcast-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-broadcast-stream &rest STREAMS`

```text
ブロードキャスト用の出力ストリームを作成します。
STREAMS に指定した複数のストリームに対して同時に出力することができます。

参考：
                        OUTPUT━━┓
                    ┌→┃STREAM1 ┠→
                    │  ┗━━━━┛
        BROADCAST ┓│  OUTPUT━━┓
    ─→┃STREAM  ┠┼→┃STREAM2 ┠→
        ┗━━━━┛│  ┗━━━━┛
                    │  OUTPUT━━┓
                    └→┃STREAM3 ┠→
                        ┗━━━━┛
使用例：
  ;;; fooとbarという出力ストリームを作ってから、
  ;;; hogeというブロードキャスト用ストリームを作り一括して出力
  (with-open-stream (foo (open "foo.txt" :direction :output))
    (with-open-stream (bar (open "bar.txt" :direction :output))
      (with-open-stream (hoge (make-broadcast-stream foo bar))
        (princ "abc" hoge))))
  => "abc"
```

関連: `broadcast-stream-streams`, `broadcast-stream-p`, `make-concatenated-stream`, `make-echo-stream`, `xyzzyで提供されているストリームの種類`

## `make-buffer-stream`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-buffer-stream BUFFER &optional POINT EOB`

```text
バッファ上にbuffer-streamを作成します。

  BUFFER : buffer-streamを作成するバッファを指定します。
  POINT  : 入出力を開始するポイントを指定します。
        nil     バッファの先頭が開始位置
        nil以外 指定されたポイントが開始位置
  EOB    : 終端のポイントを指定します。
        nil     バッファの最後が終端
        nil以外 指定されたポイントが終端
```

関連: `buffer-stream-buffer`, `buffer-stream-point`, `buffer-stream-set-point`, `xyzzyで提供されているストリームの種類`

## `make-concatenated-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-concatenated-stream &rest STREAMS`

```text
STREAMS に指定した複数の入力ストリームをくっつけて、順番に読み出すための
一つの入力ストリームを作ります。

参考：
                        INPUT ━━┓    
                      ┌┨STREAM1 ┃←─
                      │┗━━━━┛    
        CONCAT━━┓  │INPUT ━━┓    
    ←─┨STREAM  ┃←┼┨STREAM2 ┃←─
        ┗━━━━┛  │┗━━━━┛    
                      │INPUT ━━┓    
                      └┨STREAM3 ┃←─
                        ┗━━━━┛    

使用例：
  ;;; 文字列の入力ストリームを二本作った後、一本に連接してみる。
  (with-open-stream (foo (make-string-input-stream "foo"))
    (with-open-stream (bar (make-string-input-stream "bar"))
      (with-open-stream (hoge (make-concatenated-stream foo bar))
        (while (setq in (read-char hoge nil))
          (write-char in)))))
```

関連: `make-broadcast-stream`, `xyzzyで提供されているストリームの種類`

## `make-dispatch-macro-character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-dispatch-macro-character CHAR &optional NON-TERMINATING-P READTABLE`

```text
ディスパッチマクロ文字を新たに作成します。
CHAR が既にディスパッチマクロ文字であれば何もしません。
```

関連: `set-dispatch-macro-character`, `get-dispatch-macro-character`

## `make-echo-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-echo-stream INPUT-STREAM OUTPUT-STREAM`

```text
INPUT-STREAM からの入力を OUTPUT-STREAM に出力するストリームを作成します。
make-two-way-stream と異なり、 INPUT-STREAM から入力された内容は、全て
OUTPUT-STREAM にエコーされます。

参考：

     ECHO STREAM━┓    INPUT ━━┓
    ←─┨←───┨←─┨STREAM  ┃←─
        ┃    ┌─┨    ┗━━━━┛
        ┃    └→┃    OUTPUT━━┓
    ─→┠───→┠─→┃STREAM  ┠─→
        ┗━━━━┛    ┗━━━━┛
```

関連: `echo-stream-input-stream`, `echo-stream-output-stream`, `echo-stream-p`, `make-two-way-stream`, `make-broadcast-stream`, `xyzzyで提供されているストリームの種類`

## `make-string-input-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-string-input-stream STRING &optional START END`

```text
文字列からの入力用ストリームを作成します。
以後、このストリームからは文字列の内容を順番に取得可能です。

  STRING : 対象の文字列を指定します。
  START  : 入力ストリームとする開始位置です。
  END    : 入力ストリームとする終了位置です。

複数の入力ストリームを使用するのでなければ、with-input-from-string を使
用する方が簡単です。

使用例：
  ;;; 文字列の入力用ストリームからひとつ読み出してみる。
  (with-open-stream (foo (make-string-input-stream "abc def"))
    (read foo))
  => abc  

  ;;; with-input-from-stringを使って同じ事をしてみる。
  (with-input-from-string (foo "abc def")
    (read foo))
  => abc
```

関連: `make-string-output-stream`, `with-input-from-string`, `xyzzyで提供されているストリームの種類`

## `make-two-way-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `make-two-way-stream INPUT-STREAM OUTPUT-STREAM`

```text
入力をINPUT-STREAM、出力をOUTPUT-STREAMにする入出力ストリームを作成します。

参考：
        TWO WAY
          STREAM━┓    INPUT ━━┓
    ←─┨←───┨←─┨STREAM  ┃←─
        ┃        ┃    ┗━━━━┛
        ┃        ┃    OUTPUT━━┓
    ─→┠───→┠─→┃STREAM  ┠─→
        ┗━━━━┛    ┗━━━━┛
```

関連: `two-way-stream-input-stream`, `two-way-stream-output-stream`, `make-echo-stream`, `xyzzyで提供されているストリームの種類`

## `message`

- Function / package: lisp / 定義: misc.l
- 呼び出し: `message FMT &rest ARGS`

```text
メッセージをステータスバーに出力します。

  FMT  : format同様の書式が指定できます。
  ARGS : 出力書式へのパラメタとなります。
```

関連: `clear-message`, `msgbox`, `message-box`, `minibuffer-message`, `with-interval-message`, `format`, `*status-window*`, `status-window-stream-p`

## `open`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `open FILENAME &key :direction :if-exists :if-does-not-exist :encoding :share`

```text
ファイルへのストリームを作成して返します。ストリームのクローズには close 
を使いますが、 with-open-stream を使えば close の手間が省ける上に安全です。

  FILENAME           : ストリームを作成するファイル名を指定します。
  :direction         : ストリームの入出力の方向を指定します。
        :input          入力（省略時）
        :output         出力
        :io             入出力
        :probe          ファイルテスト？
                        戻り値のストリームは無効になっています。
  :if-exists         : ファイルが存在する場合の動作を指定します。
        :error          エラーを出力します。（省略時）
        :skip           エラーは出力せず、nilを返します。
        :append         既存ファイルに追加します。
                        ストリームの位置はファイル終端になります。
        :overwrite      上書きします。
        :new-version    ファイルを作成します。
                        既にあれば上書きされます。
        ---- 以下詳細不明 ----
        :supersede      更新？
        :rename         リネーム用にストリームを開く？
        :rename-and-delete  リネーム用にストリームを開く？
  :if-does-not-exist : ファイルが存在しない場合の動作を指定します。
        :error          エラーを出力します。（省略時）
        :create         エラーは出力せず、入力ファイルを作成します。
  :encoding          : エンコーディングのモードを指定します。
        :binary         バイナリモードです。
        :text           テキストモードです。（省略時は:text）
        :canonical      :text と同じ意味になります。
        :raw            改行コードの扱いが、LF のみになります。
                        それ以外は :text と同じです。
  :share             : ファイルの共有モードを指定します。
        省略時　　　　　:direction が :input または :probe なら :read に、
                        それ以外は共有不可になります。
        :read           読み取りの共有が可能になります。
        :write          書き込みの共有が可能になります。
        :read-write     読み書きの共有が可能になります。

使用例：
  ;;; ストリーム経由でファイルに書き出してみる。
  (setq foo (open "abc.txt" :direction :output))
  => #<file-output stream: C:/applications/xyzzy/abc.txt>
  (princ "test" foo)
  => "test"
  (close foo)
  => t
```

関連: `close`, `clear-input`, `xyzzyで提供されているストリームの種類`, `with-open-file`, `with-open-stream`

## `open-stream-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `streamp OBJECT`

```text
OBJECTが開いたストリームか否かを返します。
  t    OBJECTは開いたストリームです。
  nil  OBJECTはストリームでないか、閉じています。
```

関連: `streamp`

## `parse-integer`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `parse-integer STRING &key :start :end :radix :junk-allowed`

```text
文字列から整数を読み取ります。
C言語のatoiに相当します。

  STRING  : 対象の文字列
  :start  : 読み取り開始位置
  :end    : 読み取り終了位置
  :radix  : 基数
  :junk-allowed
          : non-nilなら前後の空白を無視します

多値で二つの値を返します。
一つ目は読み込んだ整数値です。読み込めなかった場合はnilを返します。
二つ目は読んだ最後の文字の次の文字のインデックスです。文字列の最後まで読
んだ場合は文字列の長さになります。

例:
  (parse-integer "16")
  =>16
  =>2
  (parse-integer "016")
  =>16
  =>3
  (parse-integer " 16 ")
  =>不正な数値の形式です: " 16 "
  (parse-integer " 16 " :junk-allowed t)
  =>16
  =>3

備考:
  Common Lispの同名の関数と動作が異なります。
  Common Lispのparse-integerは:junk-allowedがnilでも前後の空白を無視し、
  non-nilのときは前後の空白のみならず数字以外の文字も無視します。
```

## `peek-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `peek-char &optional PEEK-TYPE INPUT-STREAM EOF-ERROR-P EOF-VALUE RECURSIVE-P`

```text
ストリームから文字を覗き見ます。read-charしてunread-charするようなもんです。

  PEEK_TYPE      : 覗き見る文字の種類を指定します。
        nil        全ての種類の文字を受け付けます。
        文字       指定された文字とEOFのみを受け付けます。
        上記以外   空白以外を受け付けます。
                   空白には 水平タブ 改行 垂直タブ 改ページ 行頭復帰 スペース が該当します。
                   キーでは TAB C-i LFD C-j RET C-m SPC が該当します。
  INPUT-STREAM   : 入力元のストリームを指定します。
  EOF-ERROR-P    : EOFをエラーとするかどうかを指定します。
        t          エラーとします。
        nil        エラーとせず、nilを返します。
  EOF-VALUE      : EOFのときにnilの代わりに返す文字を指定します。
  RECURSIVE-P    : 結果に影響しません。

戻り値は文字です。

使用例：
  ;;; 標準入力の文字を除き見る。
  (peek-char nil *standard-input* nil nil)
```

関連: `read-char`

## `prin1`

- Function / package: lisp / 定義: stream.l
- 呼び出し: `prin1 OBJECT &optional STREAM`

```text
オブジェクトをストリームに出力します。

  OBJECT : 出力するオブジェクトを指定します。
  STREAM : ストリームを指定します。

STREAMを省略されたときは、標準出力に出力します。princでの出力とよく似て
いますが、エスケープ文字を出力することや文字列が引用符で囲まれる点が異な
ります。

使用例：
  ;;; princとprin1の出力の違い
  (princ "abc") => abc  (prin1 "abc") => "abc"
  (princ #\a)   => a    (prin1 #\a)   => #\a
```

関連: `princ`

## `princ`

- Function / package: lisp / 定義: stream.l
- 呼び出し: `princ OBJECT &optional STREAM`

```text
オブジェクトをストリームに出力します。

  OBJECT : 出力するオブジェクトを指定します。
  STREAM : ストリームを指定します。

STREAMを省略されたときは、標準出力に出力します。prin1での出力とよく似て
いますが、エスケープ文字を出力しないことや文字列が引用符で囲まれない点が
異なります。
※CLtL2(Common Lisp the Language, 2nd edition)によると人間に読み易いよう
  に意図しているそうです。

使用例：
  ;;; princとprin1の出力の違い
  (princ "abc") => abc  (prin1 "abc") => "abc"
  (princ #\a)   => a    (prin1 #\a)   => #\a
```

関連: `prin1`

## `read`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE RECURSIVE-P`

```text
INPUT-STREAM から Lisp のオブジェクトを読み込んで返します。

  INPUT-STREAM : 入力元のストリーム
  EOF-ERROR-P  : EOFの状態でread-charしたときにどうするか？
        t               エラーとする。
        nil             エラーとせず、nilを返します。
  EOF-VALUE    : EOFの状態でreadしたときにnilの代わりに返す文字を指定します。
  RECURSIVE-P  : （詳細不明）
```

## `read-as-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-as-string STREAM &optional EOF-ERROR-P EOF-VALUE`

```text
ストリームからトークンを読み込んで文字列として返します。
マクロ文字やエスケープ文字は読み取りません。
```

関連: `read`

## `read-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read-char &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE RECURSIVE-P`

```text
指定された入力ストリームから一文字読み込んで、文字を返します。

  INPUT-STREAM : 入力ストリーム
  EOF-ERROR-P  : EOFの状態でread-charしたときにどうするか？
        t               エラーとする。
        nil             エラーとせず、nilを返します。
  EOF-VALUE    : EOFの状態でread-charしたときにnilの代わりに返す文字を指定します。
  RECURSIVE-P  : （詳細不明）

使用例：
  (read-char *keyboard*) <-- "a"を入力
  => #\a

補足：
  蛇足ですが、EOFはEnd Of Fileの略です。ファイルやストリームをすっかり読
  み終わってしまった状態を指します。
```

関連: `read-char-no-hang`, `write-char`

## `read-char-no-hang`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read-char-no-hang &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE`

```text
read-char と同じです。ただし、入力がなければ待たずに nil を返します。
```

関連: `read-char`, `listen`

## `read-delimited-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read-delimited-list CHAR &optional INPUT-STREAM RECURSIVE-P`

```text
指定した文字が現れるまで Lisp オブジェクトを読み込み、結果のリストを返します。

  CHAR         : リストの終わりを表す文字
  INPUT-STREAM : 入力元のストリーム
  RECURSIVE-P  : nil ならトップレベル、non-nil なら再帰呼び出しとして読み込む
```

関連: `read`

## `read-from-string`

- Function / package: lisp / 定義: stream.l
- 呼び出し: `read-from-string STRING &optional EOF-ERROR-P EOF-VALUE &key :start :end :preserve-whitespace`

```text
文字列を読み、多値で2つの値を返します。1つ目の戻り値は Lisp Reader が読
み込んだオブジェクトそのもの、2つ目の戻り値は文字列中において読まなかっ
た最初の文字の位置です。文字列を最後まで読んだ場合、2つ目の戻り値はその
文字列の長さと等しくなります。

  STRING               : 読む対象である文字列
  EOF-ERROR-P          : EOFの状態でread-from-stringしたときにどうするか？
                non-nil    エラーとします。(デフォルト)
                nil        エラーとせず、nilを返します。
  EOF-VALUE            : EOFの状態でread-from-stringしたときにnilの代わ
                         りに返す文字を指定します。
  :start               : 読み始める位置(デフォルトは0)
  :end                 : 読み終わる位置(デフォルトは文字列の長さ)
  :preserve-whitespace : (詳細不明)
                non-nil    
                nil
```

関連: `parse-integer`

## `read-into`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-into STRING &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE MAX-LENGTH`

```text
指定された入力ストリームから文字列を読み込み、指定された文字列に格納します。
結果の書き込みは破壊的に行われます。

  STRING       : 結果を格納する文字列。フィルポインタを持たなければならない
  INPUT-STREAM : 入力元のストリーム
  EOF-ERROR-P  : non-nil なら、入力ストリームが終端に達しているとエラー
  EOF-VALUE    : 入力ストリームが最初から終端に達していた場合の戻り値
  MAX-LENGTH   : 読み込む長さの上限。デフォルトは STRING の本来の長さ

INPUT-STREAM が終端に達していた場合を除いて戻り値は STRING です。

使用例：
  (let ((x (make-vector 2 :element-type 'character :fill-pointer 0)))
    (read-into x (make-string-input-stream "abcdef")))
  => "ab"

  (let ((x (make-vector 10 :element-type 'character :fill-pointer 0)))
    (read-into x (make-string-input-stream "abcdef")))
  => "abcdef"

  (let ((x (make-vector 10 :element-type 'character :fill-pointer 0)))
    (read-into x (make-string-input-stream "abcdef") t nil 3))
  => "abc"
```

関連: `read`

## `read-line`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read-line &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE RECURSIVE-P`

```text
指定された入力ストリームから一行読み込んで文字列として返します。

  INPUT-STREAM : 入力元のストリーム
  EOF-ERROR-P  : nil 以外の場合、入力ストリームが終端に達しているとエラー
  EOF-VALUE    : 入力ストリームが最初から終端に達していた場合の戻り値

二つ目の戻り値として、改行文字を読み込んだ場合は nil を、に達した場合
は t を返します。

RECURSIVE-P は、与えることはできますが使用されません。
```

## `read-line-into`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-line-into STRING &optional INPUT-STREAM EOF-ERROR-P EOF-VALUE`

```text
指定された入力ストリームから一行読み込んで、指定された文字列に格納します。
格納先の文字列は破壊されます。

  STRING       : 結果を埋め込む先の文字列。
                 フィルポインタを持ち、かつアジャスタブルでなければならない
  INPUT-STREAM : 入力元のストリーム
  EOF-ERROR-P  : non-nil なら、入力ストリームが終端に達しているとエラー
  EOF-VALUE    : 入力ストリームが最初から終端に達していた場合の戻り値

INPUT-STREAM が終端に達していた場合を除いて戻り値は STRING です。
また二つ目の戻り値として、改行文字を読み込んだ場合は nil を、終端に達
した場合は t を返します。

使用例：
  (let ((x (make-vector 2 :element-type 'character :fill-pointer 0 :adjustable t)))
    (read-line-into x (make-string-input-stream "abcdef")))
  => "abcdef"
  => t

  (let ((x (make-vector 2 :element-type 'character :fill-pointer 0 :adjustable t)))
    (read-line-into x (make-string-input-stream "abc\ndef")))
  => "abc"
  => nil
```

関連: `read-line`, `read-into`, `read`

## `read-preserving-whitespace`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `read-preserving-whitespace &optional IN-STREAM EOF-ERROR-P EOF-VALUE RECURSIVE-P`

```text
ストリームから Lisp のオブジェクトを読み込んで返します。
read とほぼ同じですが、読んだ最後の文字が空白文字だった場合、その文字を
ストリームへ戻します。
```

関連: `read`

## `readtable-case`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `readtable-case READTABLE`

```text
READTABLE の case sensitivity を返します。
この値はシンボルの read および print の際の挙動に影響します。

戻り値
  :upcase       read の際にアルファベットを大文字に変換
                print の際に小文字を含むシンボル名をエスケープ
  :downcase     read の際にアルファベットを小文字に変換
                print の際に大文字を含むシンボル名をエスケープ
  :preserve     大文字小文字の変換・エスケープをしない (デフォルト)
  :invert       read 時は :preserve と同じ？
                print の際にアルファベットを含むシンボル名をエスケープ

リードテーブルの case sensitivity を変更するには si:*set-readtable-case
または setf を使います。

例:
  (let ((*readtable* (copy-readtable *readtable*)))
    (dolist (rtc '(:upcase :downcase :preserve :invert))
      (setf (readtable-case *readtable*) rtc)
      (print (read-from-string "Foo"))))
  -> FOO
  -> foo
  -> Foo
  -> |Foo|
  => nil
```

関連: `si:*set-readtable-case`, `*readtable*`

## `readtablep`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `readtablep OBJECT`

```text
OBJECT がリードテーブルなら t 、それ以外なら nil を返します。
```

関連: `*readtable*`

## `set-dispatch-macro-character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-dispatch-macro-character DISP-CHAR SUB-CHAR FUNCTION &optional READTABLE`

```text
ディスパッチマクロ文字を設定します。
SUB-CHAR は大文字小文字を区別しません。

DISP-CHAR がディスパッチマクロ文字でなければエラーとなります。
また SUB-CHAR に [0-9] は指定できません。
```

関連: `make-dispatch-macro-character`, `get-dispatch-macro-character`

## `set-macro-character`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-macro-character CHAR FUNCTION &optional NON-TERMINATING-P READTABLE`

```text
マクロ文字を設定します。

  CHAR                  マクロ文字にする文字
  FUNCTION              CHAR が読まれたときに呼ばれる関数
  NON-TERMINATING-P     トークンの途中に現れた CHAR をマクロ文字とみなさない
  READTABLE             設定するリードテーブル

使用例：
  (set-macro-character #\? 'read-test)
  (defun read-test (stream ch)
    (list '*question* (read stream)))
  (read-from-string "?a")
  => (*question* a)
  => 2
```

関連: `get-macro-character`

## `si:*set-readtable-case`

- Function / package: system / 定義: builtin.l
- 呼び出し: `*set-readtable-case READTABLE CASE`

```text
READTABLE の case sensitivity を CASE に設定します。
```

関連: `readtable-case`, `*readtable*`

## `si:*stream-line-number`

- Misc / package: system / 定義: builtin.l
- 呼び出し: `*stream-line-number &optional STREAM`

```text
（詳細不明）
(si:*stream-line-number *standard-input*)
```

## `socket-stream-ssl-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `socket-stream-ssl-p STREAM`

```text
STREAMがSSLストリームならtを返します。

補足：
  xyzzy 0.2.2.248 から利用可能です。
```

## `ssl-do-handshake`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `ssl-do-handshake STREAM SERVER-NAME &key (:ssl-verify-mode :peer)`

```text
STREAMに対してSSL認証を行いSSLストリームに変換しtを返します。
STREAMがすでにSSLストリームなら何もせずnilを返します。
その後の通信はすべてSSL通信となります。

  STREAM           : ストリームを指定します。
  SERVER-NAME      : 証明書の検証に使用するサーバ名（コモンネーム）を指定します。
  :ssl-verify-mode : SSL証明書の検証モードを指定します。
        :none          サーバ証明書を検証しません。
        :peer          サーバ証明書を検証します。
                       検証が失敗した場合socket-errorが通知されます。
                       デフォルトは:peerです。

参考：
  ;;; Proxy経由でhttps://www.google.co.jp/を取得してみる。
  (defun proxy-https-get (proxy-host proxy-port host port path)
    (let (line res)
      (with-open-stream (stream (connect proxy-host proxy-port))
        (format stream "CONNECT ~A:~A HTTP/1.0~%~%" host port)
        (setq line (read-line stream))
        (unless (string-match "^HTTP/[0-9]\.[0-9] 200" line)
          (plain-error "CONNECT failed: ~S" line))
        (ssl-do-handshake stream host)
        (format stream "GET ~A HTTP/1.0~%" path)
        (format stream "Host: ~A~%~%" host)
        (while (setq line (read-line stream nil))
          (push line res))
        (nreverse res))))

  (format t "~{~A~%~}"
          (proxy-https-get "proxy.example.com" 8080
                           "www.google.co.jp" 443 "/"))

補足：
  xyzzy 0.2.2.248 から利用可能です。
```

関連: `connect`, `socket-stream-ssl-p`

## `streamp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `streamp OBJECT`

```text
OBJECTがストリームか否かを返します。
  t    OBJECTはストリームである。
  nil  OBJECTはストリームでない。
```

関連: `open-stream-p`

## `terpri`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `terpri &optional OUTPUT-STREAM`

```text
OUTPUT-STREAM に改行 (#\LFD) を出力して nil を返します。
```

関連: `fresh-line`

## `two-way-stream-input-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `two-way-stream-input-stream TWO-WAY-STREAM`

```text
make-two-way-stream で作られた TWO-WAY-STREAM の入力元のストリームを返します。
```

関連: `make-two-way-stream`

## `two-way-stream-output-stream`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `two-way-stream-output-stream TWO-WAY-STREAM`

```text
make-two-way-stream で作られた TWO-WAY-STREAM の出力先のストリームを返します。
```

関連: `make-two-way-stream`

## `unread-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `unread-char CHARACTER &optional INPUT-STREAM`

```text
入力ストリームに一文字戻します。

  CHARACTER    : 入力ストリームに戻す文字
  INPUT-STREAM : 入力ストリーム
```

## `with-input-from-buffer`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-input-from-buffer (BUFFER &optional POINT EOB) &rest BODY`

```text
バッファを入力ストリームとして扱えるようになり、
*standard-input*から読み込まれるようになります。

使用例：
  ;;; *scratch*の内容を*Output*に吐き出す。
  (with-output-to-buffer ((switch-to-buffer "*Output*"))
    (with-input-from-buffer ((switch-to-buffer "*scratch*"))
      (while (setq line (read-line *standard-input* nil))
        (princ line)
        (princ "\n"))))
```

関連: `with-output-to-buffer`

## `with-input-from-selected-buffer`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-input-from-selected-buffer &rest BODY`

```text
現在のバッファを標準入力にして読み込みます。

使用例：
  ;;; 現在のバッファから読み込んで変数に入れる。
  (with-input-from-selected-buffer
    (setq name (read) count (read) exp (read)))
```

## `with-input-from-string`

- Macro / package: lisp / 定義: stream.l
- 呼び出し: `with-input-from-string (VAR STRING &key :index :start :end) &body BODY`

```text
文字列を標準入力にして読み込みます。
```

関連: `make-string-input-stream`, `with-output-to-string`

## `with-interval-message`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-interval-message (INTERVAL) &body BODY`

```text
BODY 内で message コマンドによる表示の更新間隔を制限します。

  INTERVAL : 表示の最低更新間隔（ミリ秒）。
             前回 message を実行したときから INTERVAL ミリ秒以上経過していない場合、
             新たなメッセージを表示しません。

使用例:
  ;; 更新間隔を 100 ミリ秒にしてみる。
  (with-interval-message (100)
    (dotimes (i 100000)
      (message "~D" i)))
```

関連: `message`

## `with-open-file`

- Macro / package: lisp / 定義: stream.l
- 呼び出し: `with-open-file (STREAM FILENAME &rest OPTIONS) &body BODY`

```text
指定されたファイルからストリームを作成し、本体を評価します。

  STREAM    : ストリームに束縛される変数
  FILENAME  : ストリームを作成するファイル名
  OPTIONS   : キーワード引数。open へ渡せるものと同じ
  BODY      : 実行する本体

使用例：
  (with-open-file (fp (merge-pathnames "lisp/henmi/c++-kwd.txt" (si:system-root)))
    (let ((line nil))
      (while (setq line (read-line fp nil nil nil))
        (push line *kekka*))))
```

関連: `with-open-stream`, `open`

## `with-open-stream`

- Macro / package: lisp / 定義: stream.l
- 呼び出し: `with-open-stream (VAR STREAM) &body BODY`

```text
局所変数をストリームに束縛して本体を評価し、ストリームを閉じます。

参考：
  connect の例を参照のこと
```

関連: `with-open-file`, `connect`

## `with-output-to-buffer`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-output-to-buffer (BUFFER &optional POINT) &rest BODY`

```text
標準出力を指定されたバッファにリダイレクトします。

  BUFFER : 出力するバッファ
  POINT  : 出力をするポイントを指定します。
           指定しない場合には、バッファの先頭から出力されます。
  BODY   : 実行するフォーム

使用例：
  ;;; *scratch*に書き出してみる。
  (with-output-to-buffer ((find-buffer "*scratch*"))
     (format t "foo~%")
     (format t "bar~%"))
```

関連: `with-output-to-selected-buffer`, `with-output-to-temp-buffer`

## `with-output-to-selected-buffer`

- Function / package: editor / 定義: misc.l
- 呼び出し: `with-output-to-selected-buffer &rest BODY`

```text
標準出力をカレントバッファにリダイレクトします。
ポイントがある位置から出力されます。
  
使用例：
  ;;; カレントバッファに書き出してみる。
  (with-output-to-selected-buffer
     (format t "foo~%")
     (format t "bar~%"))
```

関連: `with-output-to-buffer`

## `with-output-to-string`

- Macro / package: lisp / 定義: stream.l
- 呼び出し: `with-output-to-string (VAR &optional STRING) &body BODY`

```text
文字列を出力するストリームを作成します。

使用例：
  ;;; ストリームを使って文字列を出力してみる。
  (setq var
        (with-output-to-string (out)
          (prin1 "test" out)))
  => "test"
```

関連: `make-string-output-stream`, `with-input-from-string`

## `with-output-to-temp-buffer`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `with-output-to-temp-buffer (BUFNAME &optional (POPUP t)) &rest BODY`

```text
指定されたバッファを作成し、標準出力をそのバッファにリダイレクトします。
同じ名前のバッファがあった場合には、そのバッファの内容は破棄されます。
単に処理結果だけを書き込むような場合に便利です。

  BUFNAME : バッファの名前を指定します。
  POPUP   : バッファを分割表示する際の行数／列数を指定します。
        t       ニ分割します。
        整数    指定行数／列数で分割します。
        nil     バッファを分割表示しません。
  VERT-P  : バッファの分割方法を指定します。
            POPUP が nil の場合は意味を持ちません。
        non-nil 左右にバッファを分割します。
        nil     上下にバッファを分割します。

使用例：
  ;;; *Help*を作ってそこに書き出してみる。
  (with-output-to-temp-buffer ("*Help*")
     (format t "foo~%")
     (format t "bar~%"))

互換性：
   muleにもCommon Lispにもありません。
```

関連: `with-output-to-buffer`

## `write`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `write OBJECT &key :stream :escape :pretty :base :radix :circle :level :length :readably`

```text
OBJECTを印字表現でストリームに出力します。

  OBJECT       : 出力するオブジェクトを指定します。

  :stream      : 出力するストリームを指定します。
                 省略すると*standard-output*に出力します。

  :escape      : エスケープするかどうか指定します。
                 デフォルトの値は*print-escape*です。
        non-nil  prin1やformat指定子の~Sと同じように出力されます。
        nil      princやformat指定子の~Aと同じように出力されます。

  :pretty      : 式の表示を見やすくするかどうかを指定します。
                 デフォルトの値は*print-pretty*です。
        non-nil  見やすくします。
        nil      見やすくしません。

  :base        : 基数を指定します。
                 2～36までを指定でき、それ以外は10進数になります。
                 デフォルトの値は*print-base*です。

  :radix       : 基数を主力するかどうかを指定します。
                 デフォルトの値は*print-radix*です。
        non-nil  #(基数)r(数)の形で出力します。
                 10進数の時はこの形ではなく、最後に . が付きます。
                 2進数,8進数,16進数の基数はそれぞれ、b,o,xと表示され、
                 それ以外の時は基数自体は10進数で表示されます。
        nil      数のみ出力します。

  :circle      : 循環リストを考慮するかどうかを指定します。
                 デフォルトの値は*print-circle*です。
        non-nil  考慮し、#1=(a . #1#) のような形で表示します。
        nil      考慮しません。無限に表示されるのでC-gで止める必要があります。

  :level       : リスト出力の深さの制限を指定します。
                 制限よりも深い位置にあるリストは、#で表示されます。
                 デフォルトの値は*print-level*です。

  :length      : リスト出力の長さの制限を指定します。
                 制限よりも長いリストは途中で打ち切られ、
                 ... で表示されます。
                 デフォルトの値は*print-length*です。

  :readably    : 読めるように出力します。
                 デフォルトの値は*print-readably*です。
        non-nil  :lengthや:levelのnon-nil指定を無効にし、
                 :escapeがnilでもnon-nilを指定したように出力します。
```

関連: `read`

## `write-char`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `write-char CHARACTER &optional OUTPUT-STREAM`

```text
OUTPUT-STREAM に CHARACTER を出力し、その CHARACTER を返します。
```

関連: `read-char`

## `xyzzyで提供されているストリームの種類`

- Tips

```text
（途中）
以下はxyzzyで提供されているストリームの種類です。

  Commonと同じ
  ---------------------------------------------
  file-input-stream       open
  file-output-stream      open
  file-io-stream          open
  string-input-stream     make-string-input-stream
  string-output-stream    make-string-output-stream
  synonym-stream          make-synonym-stream
  broadcast-stream        make-broadcast-stream
  concatenated-stream     make-concatenated-stream
  echo-stream             make-echo-stream
  two-way-stream          make-two-way-stream
  ---------------------------------------------

synonym-stream以降は使ったことないんで(^^;、動くかどうか分からないんです
が多分動くでしょう(^^)。

  独自
  ---------------------------------------------
  buffer-stream           make-buffer-stream
  status-window-stream    なし
  keyboard-stream         なし
  wstreams-stream         なし
  debug-output-stream     なし
  ---------------------------------------------

独自ストリームの概要：
  buffer-stream
    バッファをストリームとみなして入出力どっちでもできます。  
  status-window-stream
    ステータスウィンドウをストリームとみなして出力ができます。
    グローバル変数*status-window*の値です。
  keyboard-stream
    キーボードをストリームとみなして入力ができます。
    グローバル変数*keyboard*の値です。
  wstreams-stream
    formatからコールバックが呼ばれたときのstreamの実体。
  debug-output-stream
    現在のデバッガをストリームとみなして出力ができます。
    グローバル変数*debug-output*の値です。

補足：
  debug-output-stream は xyzzy 0.2.2.246 から利用可能です。
```

関連: `open`, `make-string-input-stream`, `make-string-output-stream`, `make-synonym-stream`, `make-broadcast-stream`, `make-concatenated-stream`, `make-echo-stream`, `make-two-way-stream`, `make-buffer-stream`, `connect`, `stream-encoding`, `set-stream-encoding`
