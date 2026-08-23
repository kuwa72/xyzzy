コマンドラインオプション
========================

xyzzy
-----

起動時の引数は以下の形式を受け付けます。

**xyzzy**
  [**-image** `dump-file`]
  [**-config** `config-directory`]
  [**-ini** `ini-file`]
  [**-q**|**-no-init-file**]
  (`other-option`|`file`)*

**-image**、**-config** または **-ini** を指定する場合は、それ以外のオプションより
前になければなりません。また、**-q** または **-no-init-file** を指定する場合は
**-image**、**-config** および **-ini** 以外のオプションの先頭になければなりません。

それぞれのオプションの詳細は以下の通りです。

  * **-image** `dump-file`

    ダンプイメージのファイル名を `dump-file` に変更します。
    指定されない場合、実行ファイルの拡張子を .wxp に変更したファイル名を使用します。

  * **-config** `config-directory`

    自動的に作成される設定ファイルを置くディレクトリを `config-directory` に変更します。
    指定されない場合、`$XYZZY/usr/`ユーザー名`/wxp/` に置かれます。
    環境変数 `XYZZYCONFIGPATH` で指定することも可能です。
    ここに何が置かれるかは [設定](configuration.md) を参照してください。

  * **-ini** `ini-file`

    自動的に作成される設定ファイルのファイル名を `ini-file` に変更します。
    指定されない場合は xyzzy.ini となります。環境変数 `XYZZYINIFILE` でも指定できます。

  * **-q**
  * **-no-init-file**

    ユーザ初期化ファイル (`~/.xyzzy`) をロードしません。

  * **-l** `file`
  * **-load** `file`

    `file` を **load** します。

  * **-I** `dir`
  * **-load-path** `dir`

    `dir` を **\*load-path\*** の先頭に追加します。

  * **-R** `module`
  * **-require** `module`

    `module` を **require** します。

  * **-work-dir** `dir`

    xyzzy の作業ディレクトリを `dir` に変更します。

  * **-f** `fn`
  * **-funcall** `fn`

    `fn` を **funcall** します。

  * **-e** `sexp`
  * **-eval** `sexp`

    `sexp` を評価します。

  * **-g** `linenum`
  * **-go** `linenum`

    直前に指定したファイルの `linenum` 行目に移動します。

  * **-c** `column`
  * **-column** `column`

    直前に指定したファイルの `column` 桁に移動します。

  * **-trace**

    **\*Trace Output\*** バッファを有効にし、エラー発生時にスタックトレースが
    出力されるようにします。

  * **-kill**

    xyzzy を終了します。これ以降の引数は無視されます。

  * **-p** `filename`

    `filename` を印刷して終了します。

  * **-s** `session-file`

    `session-file` をセッションファイルとして読み込み、セッションの自動保存を有効にします。

  * **-S** `session-file`

    `session-file` をセッションファイルとして読み込み、セッションの自動保存を無効にします。

  * **-m** `mode`
  * **-mode** `mode`

    以降に指定された `file` のモードを `mode` にします。

  * **-ro**

    以降に指定された `file` を書込み禁止モードで読み込みます。

  * **-rw**

    以降に指定された `file` を書込み可能モードで読み込みます (**-ro** を取り消します)。

  * **-mailto** `mailto`

    `mailto` を引数にして `*command-line-mailto-hook*` を呼びます。

  * `file`

    `file` を読み込みます。

xyzzycli について
-----------------

xyzzycli は、すでに動作している xyzzy にファイルを読ませたり読ませなかったりということが
できます。xyzzy が動作していない場合は勝手に起動します。起動時の引数は以下の形式を受け付けます。

**xyzzycli**
  [**-image** `dump-file`]
  [**-config** `config-directory`]
  [**-ini** `ini-file`]
  [**-q**|**-no-init-file**]
  [**-wait**]
  (`other-option`|`file`)*

**-image**、**-config**、**-ini**、**-q** および **-no-init-file** を除くコマンドラインの
先頭に **-wait** を指定すると、以降に指定したファイルのバッファが削除されるのを待ちます。

その他のコマンドラインオプションは、xyzzy のオプションと同じものを指定することができます。
xyzzy がすでに動作している場合、**-image**、**-config**、**-ini**、**-q** および
**-no-init-file** は無視されます。

なお、コマンドプロンプト上で **-wait** を指定する場合、`start /wait xyzzycli -wait ...`
のように起動する必要があります。
