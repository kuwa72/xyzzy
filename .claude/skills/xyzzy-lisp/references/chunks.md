# チャンク (chunks)

reference/reference.xml から自動生成。4 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `si:make-chunk`

- Function / package: system / 定義: builtin.l
- 呼び出し: `make-chunk TYPE SIZE &optional SOURCE OFFSET`

```text
チャンクを作成します。チャンクとは外部とのやりとりをするための領域で、
外部DLLの呼び出しをする場合等に使用します。C言語的にはchar[]に相当するよ
うに思います。

  TYPE      : チャンクの型です。現状では使用していないようです。
  SIZE      : チャンクの長さです。
  SRC-CHUNK : 作成するチャンクの元ネタとなるチャンクです。
  OFFSET    : 作成するチャンクの元ネタとなるチャンクの開始位置です。

SRC-CHUNKとOFFSETの組み合わせでチャンクに関連付けされるメモリの取り方が
変わるようです。他のチャンクの内容を使用したい場合等にはを付けましょう。

  ┏━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━┓  
  ┃                  ┃OFFSET                                            ┃  
  ┃                  ┠────────────┬────────────┨  
  ┃                  ┃指定有                  │nil                     ┃  
  ┣━━━━━┯━━━╋━━━━━━━━━━━━┿━━━━━━━━━━━━┫  
  ┃SRC-CHUNK │指定有┃SRC-CHUNK + OFFSETを参照│SRC-CHUNKを共有         ┃  
  ┃          ├───╂────────────┼────────────┨  
  ┃          │nil   ┃OFFSETのアドレスを参照  │新しいメモリを確保      ┃  
  ┗━━━━━┷━━━┻━━━━━━━━━━━━┷━━━━━━━━━━━━┛  

SRC-CHUNK が nil で OFFSET が指定されていた場合には、 OFFSET をアドレス
と見なすのが特殊です。

補足説明：
  si:make-chunkはDLLを呼び出すとき、C言語に渡せるメモリ割り当てを行いま
  す。例えば以下のC言語のコードは
  ┌───────────────────────────────────┐
  │char buf[300];                                                        │
  │DWORD rc = GetCurrentDirectory(300, buf);                             │
  └───────────────────────────────────┘
  xyzzy lispで書くと、以下のようになります。
  ┌───────────────────────────────────┐
  │(let ((s (si:make-chunk nil 300))) ; C言語互換メモリの割り当て        │
  │   (GetCurrentDirectory 300 s)     ; define-dll-entryで定義しておく事 │
  │   (si:unpack-string s 0))         ; lispの文字列に変換               │
  └───────────────────────────────────┘
```

関連: `チャンクの概要`, `si:make-string-chunk`, `si:unpack-string`

## `si:make-string-chunk`

- Function / package: system / 定義: builtin.l
- 呼び出し: `make-string-chunk STRING`

```text
引数に指定された文字列の内容がコピーされたチャンクを作成します。

使用例：
  ;;; WIN32APIのMessageBoxを使ってみる。
  (let ((s (si:make-string-chunk "hello"))
        (r (si:make-string-chunk "title")))
    (MessageBox 0 s r MB_OK))     ; define-dll-entryで定義する事
```

関連: `si:make-chunk`

## `si:unpack-string`

- Function / package: system / 定義: builtin.l
- 呼び出し: `unpack-string CHUNK OFFSET &optional SIZE ZERO-TERMINATING-P`

```text
チャンクをlispの文字列に変換します。

  CHUNK              : make-chunkで作られたチャンクまたはnilを指定します。
  OFFSET             : 文字列化する位置を指定します。
                       CHUNKがnon-nilの場合はCHUNK + OFFSETのアドレスを参照します。
                       CHUNKがnilの場合はOFFSETをアドレスとみなして参照します。
  SIZE               : OFFSETの位置から文字列化する長さを指定します。
  ZERO-TERMINATING-P : 文字列がNULL文字('\0')で終端しているかどうかを指定します。
                       non-nilを指定した場合は、NULL文字までを文字列化します。
                       SIZEで指定した長さより短い文字列を返却する可能性があります。
                       nilを指定した場合は、SIZEまたはCHUNKのサイズで指定した長さを
                       すべて文字列化します。

CHUNKにnilを指定する場合、SIZEまたはZERO-TERMINATING-Pのどちらかを
必ず指定する必要があります。

補足：
  xyzzy 0.2.2.241 からCHUNKにnilを指定可能です。
```

関連: `si:make-chunk`, `チャンクの概要`

## `チャンクの概要`

- Tips

```text
xyzzyの外部と入出力するためのデータを格納するオブジェクトです。
チャンク自身は以下の要素から構成されます。

        ┌──────── 16byte ───────┐
        ┏━━━━┳━━━━┳━━━━┳━━━━┓
        ┃データ長┃データ型┃格納先  ┃－      ┃
        ┗━━━━┻━━━━┻━━━━┻━━━━┛
  データ長 : チャンクが管理するデータの長さです。
             make-chunkで指定します。
  データ型 : チャンクが管理するデータの型です。
  格納先   : チャンク自体には管理するデータを内包しません。
             格納先のアドレスだけを管理します。

以下は管理イメージです。

  ;;; 使用例
  (setq chunk (si:make-chunk 'string 8)) => #<chunk 0x00081010>
  (si:chunk-data chunk)                  => 0x00A73DC8
  (si:pack-string chunk 0 "HELLO")       => "HELLO"

      ┌アドレス┐  ┌データ─────────────┐
      ┏━━━━━┳━━━━━┯━━━━━┯━━━━━┓
      ┃0x00081010┃0x00000008│string    │0x00A73DC8┃
      ┠─────╂─────┴─────┴─────┨
      ┃0x00081018┃...                               ┃
      ┠─────╂─────────────────┨
      ┃↓        ┃                                  ┃
      ┠─────╂─┬─┬─┬─┬─┬─┬─┬─┬─┨
      ┃0x00A73DC8┃H │E │L │L │O │\0│  │  │  ┃
      ┠─────╂─┴─┴─┴─┴─┴─┴─┴─┴─┨
      ┃0x00A73DD0┃...                               ┃
      ┠─────╂─────────────────┨
      ┃↓        ┃                                  ┃
      ┗━━━━━┻━━━━━━━━━━━━━━━━━┛

チャンクから情報を取得する関数は以下のとおりです。

  si:address-of  : チャンク自身のアドレスを返します。
  si:chunk-size  : チャンクが管理するデータの長さを返します。
  si:chunk-type  : チャンクが管理するデータの型を返します。
  si:chunk-data  : チャンクが管理するデータの格納先のアドレスを返します。
  si:chunk-owner : データの格納先がチャンク自身が確保したものかどうかを返します。

チャンクを操作する関数は以下のとおりです。

  si:fill-chunk  : チャンクをfill？
  si:clear-chunk : チャンクをクリア？
  si:copy-chunk  : チャンクが管理するデータをコピーします。

チャンクの入出力をする関数は以下のとおりです。

  si:pack-int8          si:unpack-int8   :  8ビット符号付き整数用
  si:pack-uint8         si:unpack-uint8  :  8ビット符号無し整数用
  si:pack-int16         si:unpack-int16  : 16ビット符号付き整数用
  si:pack-uint16        si:unpack-uint16 : 16ビット符号無し整数用
  si:pack-int32         si:unpack-int32  : 32ビット符号付き整数用
  si:pack-uint32        si:unpack-uint32 : 32ビット符号無し整数用
  si:pack-int64         si:unpack-int64  : 64ビット符号付き整数用
  si:pack-uint64        si:unpack-uint64 : 64ビット符号無し整数用
  si:pack-float         si:unpack-float  : float用
  si:pack-double        si:unpack-double : double用
  si:pack-string        si:unpack-string : 文字列用
```

関連: `si:make-chunk`
