CP932 経由をやめる
==================

内部表現は `ucs4_t` の配列であり、Windows は UTF-16 を受け取る。その間に
CP932 のバイト列を挟む理由は無い。CP932 には Unicode の大半が入らないので、
挟めば入らない文字が `'?'` になる。ファイル名でそれが起きると、`'?'` は
ファイル名に使えない文字なので「開けない」としか見えない。

この文書は、どこに CP932 が残っていて、どれを外し、どれを残したかを記す。

症状
----

  * 日本語のファイル名は開けるのに、ハングルや簡体字を含むファイル名が開けない。
    CP932 に無い文字が `'?'` になり、ファイルシステムが不正な名前として弾く。
  * 絵文字を含むファイル名はいかなる手段でも開けない。上に加えて、文字の即値が
    16bit しか持てず BMP 外の code point を保持できなかった。
  * `find-file` の補完で絵文字が `??` に化ける。UTF-16 の 2 単位がそれぞれ
    `'?'` になっていた。
  * `(code-char 128512)` が `62976` を返す (`0x1F600` → `0xF600`)。
  * ソースやファイルに書いた絵文字が `'?'` 1 文字になる。UTF-8 のデコーダが
    4 バイト列を読み飛ばして `'?'` に置き換えていた。


外した箇所
----------

### パスとファイルシステム

`WINFS` の全メソッドが `LPCWSTR` / `WIN32_FIND_DATAW` を取るようになった。
内部では変換が要らなくなったので実装は短くなった。`pathname2wstr` は
サロゲート対を発出する (以前は `buf[i] = wchar_t (p[i])` で上位を落としていた)。

`pathname.cc` `fileio.cc` `glob.cc` `stream.cc` `mman.cc` `data.cc` `insdel.cc`
`system.cc` と、`minibuf.cc` の補完、`filer.cc`、`DnD.cc` のドロップ、
`dialogs.cc`、`init.cc` のディレクトリ初期化、`winhelp.cc` のヘルプファイル、
`dockbar.cc` のビットマップ、`usertool.cc` が追随している。

`glob.cc` にはパターン照合が 3 本あった。CP932 同士、CP932 パターン対 wide
名前、wide 同士 (ただしブラケット式が無い) の 3 本で、SJIS の先行/後続バイトを
避けるための分岐が `[a-z]` の範囲指定にまで及んでいた。両側 wide なら
「1 単位は 1 単位」なので 1 本に畳めた。

### 環境変数・設定ファイル・プロセス

  * Windows の環境変数は `_wgetenv` / `_wputenv` / `_wenviron` を通る。
  * INI の値は UTF-16 で読み書きする (`GetPrivateProfileStringW` の結果を
    そのまま使う)。節名とキー名は `conf.h` の ASCII リテラルなので `char*` のまま。
  * `CreateProcessW` に渡す環境ブロックは UTF-16 だけになった。同じ内容の
    ANSI ブロックを並べて作っていたが、`str()` を呼ぶ者はいなかった。
  * POSIX 側 (ncurses フロントエンド) の環境変数・コマンド行・パスは **UTF-8**
    である。CP932 に変換していたのは二重に誤りだった。`i2u8` / `u82i` /
    `pathname2u8` を核に置いて共有している。

### 入力と表示

  * IME: `WM_IME_REQUEST` はウィンドウクラスを `RegisterClassW` で登録して
    いるので wide の `RECONVERTSTRING` が来る。そこに CP932 のバイトを詰めて
    いたので、IME は再変換対象を UTF-16 のゴミとして読んでいた。
  * タイトルバー: ファイル名を含むので UTF-16 で組む。
  * ファイラの一覧とバッファセレクタ: `listviewex.cc` が項目テキストを
    `LVM_GETITEMTEXTW` で wide で受け取り、CP932 に落として、描画のために
    また wide に戻していた。往復をやめた。
  * 印刷: ヘッダ/フッタの書式エンジン、文書名、フォント名。

### 文字が code point を丸ごと持てるようになった

即値はタグを下位 4bit に置き、残りをペイロードにしている。ペイロードは
bit 16 から始まっていたので文字は 16bit しか持てなかった。bit 4..15 は
未使用だったので、ペイロードを bit 4 から始めて 28bit にした。

  * `Fcode_char` は切り詰めをやめた。Unicode の範囲外と、単独のサロゲートは
    文字ではないので `nil` を返す。
  * `readc_stream` の UTF-8 デコーダは 4 バイト列を 1 code point として読む。
  * `#\` の読み取りと `print_char` も code point を通す。
  * バッファの本文は以前から UTF-16 のサロゲート対で持てていた
    (`Chunk::c_text` と `Buffer.h` の cp 歩き) ので、そこは変えていない。


残した箇所
----------

| 箇所 | 理由 |
|---|---|
| ファイル内容のコーデック (`stream.cc` の `putc_encoded`、`encoding.cc`、`ucs2.cc`、`ucs2tab`) | これがまさに「ファイルの読み書き」。sjis で保存する機能そのもの |
| `archiver.cc` / `arc-if.cc` | 書庫の DLL (`UNLHA32.DLL` 等) が ANSI 専用。`WINFS` の境界だけ `WideStr` で変換している |
| `dde.cc` | DDE は ANSI のプロトコル。相手が合意しないと UTF-16 にできない |
| `edict.cc` | 辞書ファイルの形式が CP932 |
| `winhelp.cc` の索引 | 索引ファイルの中身が CP932。突き合わせる側も CP932 で揃える必要がある |
| `sockinet.cc` | ホスト名は ASCII でなければならない。非 ASCII には punycode が必要で、それは別の機能 |
| `chunk.cc` | `chunk` は byte 列の型。`w2s`/`s2w` はその型の定義どおりの変換 |
| `clipboard.cc` の `CF_TEXT` | `CF_UNICODETEXT` を先に試したうえでのフォールバック |
| `statarea.cc`、`preview.cc`、`menu.cc`、`dialogs.cc` のドライブ名 | 中身が ASCII (時刻、桁数、`U+XXXX`、ドライブレター) なので変換で失われるものが無い |
| `pathname2cstr` | 上の ANSI 専用インタフェース向けに残してある。宣言にその旨を書いた |


テスト
------

`unittest/filename-nonascii-tests.l` と `unittest/non-bmp-tests.l` に 18 件。
CP932 の内 (日本語)、CP932 の外だが BMP 内 (ハングル)、BMP の外 (絵文字) の
3 段で、作成・存在確認・真名・読み出し・`directory`・補完・ワイルドカード・
ディレクトリ名自体・文字数を見る。

`pathnames-tests.l` は丸ごと除外されていたが、落ちるのは
`shell-operation-move-multi` の 1 件 (`SHFileOperationW` の `FO_MOVE` に
複数のソースと 1 つの宛先ディレクトリを渡す形) だけだと分かったので、除外を
その 1 件に絞った。同じ形を `FO_COPY` でやる `shell-operation-copy-multi` と、
`shell-operation-move-multi2` は通る。
