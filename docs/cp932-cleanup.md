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


入力経路: BMP 外の文字は 1 打鍵で 1 文字
----------------------------------------

実機で「コマンド行に絵文字を打つと落ちる」「本文だとカーソルが 1 個余分に
進む」「アンドゥ・リドゥが戻らない」の 3 つが出た。原因は 1 つ。

Windows は BMP 外の文字を **UTF-16 の code unit 2 個 = メッセージ 2 通**で
渡してくる (`WM_CHAR` ×2、`WM_IME_CHAR` ×2、IME の `GCS_RESULTSTR` は
2 要素の文字列)。以前はそれをそのままキューに載せていたので、1 文字に対して
`self-insert-command` が 2 回走り、サロゲートの片割れが別々の文字として
バッファに insert された。

ここでバッファの不変条件が壊れる。`b_nchars` (バッファ全体の code point 数)
は 2 増えるのに、chunk 側の `c_nchars` は `count_code_points` で数え直すので
pair を **1** と数える。両者が食い違った状態で

  * `forward_char` は `c_nchars` を基準に進むので、`b_nchars` の分だけ
    進もうとして chunk が尽きる。テキストが後続していれば 1 個余分に進んだ
    ところで止まる (= カーソルがずれる)。空バッファ (= コマンド行) では
    次の chunk が無く、`assert` が消えた release ビルドで null 参照になる
    (= 落ちる)
  * `UndoInsert` は cp 単位で範囲を持つので、削る範囲が実体とずれる
    (= アンドゥが戻らない)

直し方は「キューに載せる前に pair を 1 個の code point に畳む」。

| 直した場所 | 何をしたか |
|---|---|
| `kbd.cc` の `kbd_queue::putc` | high surrogate を 1 個保留し、次に low が来たら合成して 1 回だけキューに積む。low が続かなかったら孤立 high をそのまま流す |
| `toplev.cc` の `ime_composition` | 確定文字列を丸ごと持っているので、ループの中で pair を畳む |
| `chtype.h` の `LCHAR_MOUSE` / `LCHAR_MENU` | `0x10000` / `0x20000` は payload (bit 0-20 = code point) に食い込んでいた。U+10000 以上の文字を 1 個の code point として流すと `c & LCHAR_MOUSE` が真になり、文字がマウスイベント扱いされる。kind field (bit 21-23) 側へ移した |
| `cmdloop.cc` の `dispatch` | `Char c = Char (cc)` で 16bit に切り詰めていた。U+1F600 → `0xF600` は `CCF_META` と同値。BMP 外は code point のまま扱い、`*last-command-char*` にもそれを入れる |
| `clipboard.cc` の `make_string_from_cf_wtext` | 貼り付けた文字列でサロゲートの片割れを 2 要素として置いていた。`(length "😀")` が 2 になる。1 code point に合成する |
| `kbd.h` / `kbd.cc` のマクロ記録 | `Char saved[]` が 16bit だったので、キーボードマクロに録った BMP 外の文字が別の文字になっていた。code point で持つ |
| `move.cc` の `forward_char` | 不変条件が壊れた状態を踏んでも落ちないよう、chunk が尽きたら末尾に clamp する (`assert` は release で消える) |
| `move.cc` の `folded_point_column_1` | cu ごとに `char_columns` を足していた。surrogate half はどちらも幅 1 なので BMP 外の文字が常に 2 幅で数えられる。絵文字は実際に 2 幅なので偶然合っていたが、幅 1 の BMP 外の文字 (数学英数字など) で `point_column` / `forward_column` とずれる。pair を合成して幅を引く |
| `string.cc` の `update_column` | Lisp string (code point 列) の要素を `Char` に落としてから幅を引いていた |
| `term.cc` の `terminal_key_to_bytes` | 3 バイトまでしか組み立てていなかった。畳む前は half が 2 個来て CESU-8 になり、pty の向こうで化けていた。BMP 外は 4 バイトの UTF-8 にする |

同じ 16bit 切り詰めが、キーボードとは関係ないところにも残っていた。

| 直した場所 | 何をしたか |
|---|---|
| `bytecode.cc` の `BCcode_char` | `code-char` はバイトコード側に別実装があり、そちらだけ `Char` に切り詰めていた。バイトコンパイルされたコードから `(code-char 128512)` を呼ぶと 0xF600 の文字が返る。`Fcode_char` と同じにした (範囲外は nil) |
| `lread.cc` の `read-char` / `peek-char` / `read-char-no-hang` | `make_char (Char (c))` で切り詰めていた。`C-q` (quote-char) はここを通るので、`C-q` で絵文字を入れると本文に 0xF600 が入る。UTF-8 のファイルを `read-char` で読む場合も同じ |
| `char.cc` の `unicode-char` | BMP 外に対してサロゲート 2 要素の**文字列**を返していた。`char-unicode` は BMP 外の文字から code point を返すので非対称で、`cmds.l` の `C-q u` は結果を文字として使う。文字を返すようにした |
| `char.cc` の `char-unicode` / `unicode-char` のサロゲート判定 | `utf16_surrogate_*_p` は `ucs2_t` を取るので code point を渡すと切り詰まる。U+1D800 のように下位 16bit がサロゲートに見える BMP 外の code point が nil になっていた。BMP の判定を先に置いた |
| `filer.cc` の `*filer-last-command-char*` | `cmdloop.cc` と同じ切り詰め |

`syntax.cc` と `lread.cc` の `Char c = xchar_code (ch)` も同じ切り詰めを
していた。どちらも直後に ASCII 判定や範囲判定があるので結果は変わらないが、
「範囲外だから nil」と「切り詰めた値が偶然範囲外だから nil」は別のことなので
`ucs4_t` に広げた。同じ形は `pathname.cc` のドライブレター判定と
`fnkey.cc` の機能キー判定にも残っている。こちらは切り詰めた値も英字や
機能キーにならないので結果が変わらず、直していない。


ターミナル (M-x shell) が化けていた理由
---------------------------------------

`M-x shell` の多バイト文字が全部化けるという報告があり、最初
`*default-process-encoding*` が sjis のままだったせいだと見たが、**それは
外れだった**。Windows 10 1809 以降の `make-process` は ConPTY 経由で、
`ConPtyProcess::read_process` は pty の生バイトを `Terminal::feed()` に
直接渡す。ターミナルエミュレータが自前の UTF-8 デコーダで読むので、
`*default-process-encoding*` を通らない。

本当の原因は `Terminal::put_char` に残っていた 1 行:

```cpp
ucs2_t w = (ucs2_t)ucs;
ich = w2i (w);          // Unicode → 旧 internal encoding
```

`w2i` は「Unicode → 旧 internal encoding (charset タグ付きの CP932 系)」の
表 (`wc2internal_table`)。Phase 2 で buffer が UTF-16 になった後、**表示経路で
唯一ここだけ生き残っていた**。TermCell を読む側 (`sync_to_buffer` も
`paint_terminal` も) は `ch` を UTF-16 code unit として扱い、`i2w` で戻す箇所は
どこにも無いので、内部コードがそのまま Unicode として解釈される。実機では
日本語が `芰` のような無関係な漢字になった。**U+8290 = 0x82, 0x90 — CP932 の
2 バイトを 16bit に詰めた値そのもの**で、これが決め手になった。

`(ucs2_t)ucs` の切り詰めの方は BMP 外を潰す。`😀` → U+F600 付近の私用領域
文字 = 豆腐。`cmdloop.cc` の `dispatch` と同じ形が、ターミナル側にも別に
存在していた。

| 直した場所 | 何をしたか |
|---|---|
| `term.h` の `TermCell::ch` | `Char` (16bit) → `ucs4_t` (code point) |
| `term.cc` の `put_char` | `w2i` を撤去し code point をそのまま持つ |
| `term.cc` の幅計算 | `term_wcwidth` (term.cc 独自・BMP のみ・buffer 表示と食い違う) を捨てて `unicode_width` (eaw.cc) に統一 |
| `term.cc` の `sync_to_buffer` | buffer 本文は UTF-16 なので BMP 外を surrogate pair に展開 |
| `disp.cc` の `paint_terminal` | GDI へ渡すのも UTF-16 なので同じく展開 |
| `print.cc` の `print_engine::notice` | `LoadStringW` が既に UTF-16 を返しているのに `w2i` を通して `MsgBox` に渡していた。印刷のエラーメッセージの日本語が化けていた。`MsgBox` には `wchar_t*` を取る overload があるのでそのまま渡す |

これで表示経路の旧 `w2i` (scalar 版) は全滅した。残っているのは
`encoding.cc` の CP932 ファイルコーデックだけで、そこは本来の用途。
(`w2i (const ucs2_t *, int, ucs4_t *)` の bulk 版は UTF-16 → code point の
別関数で、こちらは正しい。)


ターミナルの色
--------------

「WSL でカラフルなテーマを使ったら色味が全然再現されない」という報告。
仕様の限界ではなく、具体的なバグが 3 つあった。

**① 24bit 色が未対応で、しかもパラメータを食い残していた** (主因)

`38;5;n` (256 色) だけを見ていて、`38;2;r;g;b` は `if` を外れて**何もせず
`i` も進めなかった**。すると続く `2, r, g, b` が SGR コードとして再解釈される。

    ESC[38;2;255;100;50m   本来: 前景をオレンジに
      → 2   = DIM を ON
      → 255 = 無視
      → 100 = 背景を明るい黒に
      → 50  = 無視

色が付かないどころか DIM と勝手な背景色が入る。`48;2;40;44;52` なら
`40` → 背景黒、`44` → 背景ネイビー。

**② 256 色パレットが 16 ずれていた**

色立方体の起点を index 0 と取っていて、xterm の 16 が抜けていた。
`ESC[38;5;208m` (オレンジ) が `RGB(255,204,204)` = 薄いピンクになる。
加えて各段を 51 の倍数にしていたが、xterm は `0,95,135,175,215,255` の
不等間隔。

**③ uint8_t に詰めていて溢れていた**

`t_fg = c + 17` なので index 239 以上が 8bit を溢れ、グレースケール上端が
別の色になっていた。

**④ handle_osc が空の stub**

パレットを差し替えるテーマ (`OSC 4`、`OSC 10/11`) を全部捨てていた。

| 直した場所 | 何をしたか |
|---|---|
| `term.h` の色表現 | `uint8_t` → tag 付き 32bit (`term_color_t`: 既定 / palette index / 24bit RGB) |
| `term.cc` の `parse_sgr_color` | 新設。`38;2;r;g;b` と `38;5;n`、`:` 形式 (`38:2::r:g:b`) に対応し、パラメータを正しく消費する |
| `term.cc` の CSI パーサ | `:` を T.416 の sub-parameter 区切りとして扱う。以前は intermediate 扱いで区切りにならず、`38:2:255:0:0` が 1 個の巨大な数値に潰れていた |
| `term.cc` の `handle_osc` | 実装 (`OSC 4/10/11/104/110/111`)。`rgb:RR/GG/BB` と `#RRGGBB` 形式を読む |
| `term.cc` の `handle_sgr` | 取りこぼしていた SGR を追加: 斜体(3)、取消線(9)、点滅(5/6/25)、リセット(21/23/29)、上線(53/55)。点滅などは属性を持たないが、食っておかないと後続が色指定に化ける |
| `disp.cc` の `term_color_to_rgb` | xterm 準拠に (16 色・色立方体の起点と段・グレースケール)。OSC で差し替えられた色を優先 |
| `disp.cc` の `paint_terminal` | REVERSE と既定色の組合せ、INVISIBLE、取消線の描画 |

`TERM_MAX_PARAMS` も 16 から 32 に増やした。`38;2;r;g;b` を前景と背景の
両方に指定すると 10 個使うので余裕を見る。


サブプロセスの生パイプ
----------------------

上とは別に、`*default-process-encoding*` も sjis のまま取り残されていたので
UTF-8 (`*encoding-utf8n*`) に変えた。`*default-fileio-encoding*` は既に
`*encoding-utf8n*` になっていたので、その揃え直し。`*eshell*` の既定は pwsh で、
pwsh はリダイレクトされた stdout に UTF-8 を書く。

効くのは生パイプの経路 (ConPTY が無い環境の `make-process`、`call-process`、
ソケットプロセス、`set-process-filter`) だけ。ConPTY 経路は上に書いたとおり
この変数を通らない。子が CP932 で出力する場合は
`(setq *default-process-encoding* *encoding-sjis*)` で戻せる。


テスト
------

`unittest/filename-nonascii-tests.l` と `unittest/non-bmp-tests.l` に 29 件。
CP932 の内 (日本語)、CP932 の外だが BMP 内 (ハングル)、BMP の外 (絵文字) の
3 段で、作成・存在確認・真名・読み出し・`directory`・補完・ワイルドカード・
ディレクトリ名自体・文字数を見る。

`pathnames-tests.l` は丸ごと除外されていたが、落ちるのは
`shell-operation-move-multi` の 1 件 (`SHFileOperationW` の `FO_MOVE` に
複数のソースと 1 つの宛先ディレクトリを渡す形) だけだと分かったので、除外を
その 1 件に絞った。同じ形を `FO_COPY` でやる `shell-operation-copy-multi` と、
`shell-operation-move-multi2` は通る。

`non-bmp-tests.l` には入力経路の契約を 6 件足した: insert 後の point が
code point 単位で 1 進むこと (バッファの先頭と途中の両方)、アンドゥ・リドゥ
が往復すること、`delete-char` 1 回で消えること、`forward-char` /
`backward-char` 1 回で越えること、そしてサロゲートの片割れを Lisp から
明示的に並べても落ちないこと。C++ 側の入力経路 (`WM_CHAR` の畳み込み) は
Lisp から叩けないので、畳んだ後に通る経路の契約を押さえている。

切り詰めが残っていた場所にも 5 件足した。`code-char` はバイトコンパイル
した関数を経由して呼び、`compiled-function-p` で本当にコンパイルされて
いることを確かめる (インタプリタのままだと `Fcode_char` を通ってしまい
テストが素通りする)。


ターミナルの VT パーサにテストを付けた
--------------------------------------

`Terminal` は `ConPtyProcess` が抱えていて process 無しには作れなかったので、
VT パーサには自動テストが一切なかった。色の解釈を書き直すのに合わせて
`si:*terminal-feed-for-test` を足し、`unittest/terminal-tests.l` に 40 件
書いた (文字出力・全角・BMP 外・16 色・256 色・24bit 色・`:` 形式・属性・
カーソル移動・消去・挿入削除・スクロール・折返し)。

今回の 256 色 16 ずれのようなバグは、これがあれば実機を待たずに捕まる。
