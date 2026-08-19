# Windows 以外のホストでのビルドとテスト、および 64bit 対応

canonical なビルドは今も `xyzzy.sln` (MSVC) である。この文書は、それと並行して
追加された **mingw-w64 クロスビルド + Wine 実行** の仕組みと、そこで進めた
64bit 対応の状況をまとめる。

macOS / Linux のワークステーションから、Windows を用意せずにビルドとテストが
回せるようにするのが目的で、CI (`.github/workflows/ci.yml`) も同じ経路を使う。


## 使い方

すべて `tools/x` から実行する。Docker が必要。

```
tools/x image                  コンテナイメージを作る (最初に一度)
tools/x configure [ARCH]       cmake configure   (ARCH: i686 | x86_64)
tools/x build     [ARCH]       ビルド
tools/x smoke     [ARCH] [秒]  起動して lisp を評価できるか確認 + スクリーンショット
tools/x prepare   [ARCH] [秒]  一度だけ通常起動してダンプイメージを書く
tools/x test      [ARCH]       unittest/ のテストを Wine 上で実行
tools/x wine      [ARCH] ...   xyzzy.exe に任意の引数を渡して起動
tools/x shell                  コンテナ内のシェル
```

ARCH 省略時は `x86_64` (環境変数 `XYZZY_ARCH` で変更可)。

`tools/x test` は、テストが進まなくなったら自分で諦める。

| 環境変数 | 既定 | 意味 |
|---|---|---|
| `XYZZY_TEST_TIMEOUT` | 1800 | 全体の制限時間 (秒) |
| `XYZZY_TEST_STALL` | 300 | 進捗が止まってから諦めるまで (秒) |

進捗は `_build/<ARCH>/run/test-progress.txt` に 1 テスト 1 行で追記される
(実行中も `tail -f` で流れる)。止まったときは最後の行が止まったテストの名前で、
`_build/<ARCH>/test-stuck.png` にそのときの画面が残る。モーダルダイアログで
止まっている場合はこれで分かる。レポートは最後にしか書かれないので、止まった
場合は残らない。

ソースは Shift_JIS (CP932) なので、閲覧・検索・編集も `tools/x` を経由する。

```
tools/x show PATH [FIRST[,LAST]]   UTF-8 にして行番号付きで表示
tools/x grep PATTERN [PATH...]     検索 (パターンに日本語も使える)
tools/x utf8 PATH...               UTF-8 に変換 (エディタで編集するため)
tools/x sjis PATH...               CP932 に戻す (編集後に必ず実行)
tools/x check-encoding             全ソースが CP932 として妥当か検証
```

### 実行環境について

  * コンテナは **amd64 固定**である。Wine は x86 の機械語をそのまま実行するため。
  * Apple Silicon では、`x86_64` の Windows バイナリは Rosetta 経由で動くので
    実用的な速度が出る。一方 **`i686` は qemu-i386 に落ちるため 10 倍以上遅い**。
    32bit の検証は CI (amd64 の Linux ランナー) に任せるのが現実的。
  * xyzzy は GUI アプリなので、コンテナ内で Xvfb を起動している。ディスプレイが
    無いと Wine は null ドライバに落ち、`CreateWindow` がすべて失敗する。
  * `lisp/*.lc` もダンプイメージも無い状態の起動は、ライブラリをソースから読む
    ためエミュレーション下では非常に遅い (数十分)。`tools/x prepare` を一度
    走らせるとダンプイメージ (`xyzzy.wxp`) ができ、以降の起動は速くなる。
    ダンプイメージはバイナリの絶対アドレスを含むので、リビルドしたら作り直す
    (各スクリプトが古いものを自動的に捨てる)。


## ビルドの構成

  * `CMakeLists.txt` … vcxproj と同じソース構成・同じ定義を再現したもの。
    コード生成 (`gen-src1` / `gen-src2` / `dpp`) も同じ順序で実行する。生成物は
    ソースツリーではなくビルドディレクトリの `gen/` に出る。
  * `cmake/mingw-i686.cmake`, `cmake/mingw-x86_64.cmake` … クロスツールチェイン。
    生成ツールはターゲット向けにビルドされるので、`CMAKE_CROSSCOMPILING_EMULATOR`
    経由で Wine 上で走らせる。
  * `compat/mingw/xyzzy-compat.h` … Windows SDK と mingw-w64 の差を埋めるための
    強制インクルードヘッダ。MSVC ビルドでは使わない。
  * ソースが CP932 なので `-finput-charset=CP932 -fexec-charset=CP932` を渡す。
    実行文字セットも CP932 のままにしてある (内部処理が CP932 前提)。
  * `src/` は `-I` ではなく `-iquote` で渡す。`src/string.h` などが CRT の
    ヘッダを隠してしまうため。vcxproj も同じ理由で `src` をインクルードパスに
    入れていない。


## MSVC との差異 (mingw ビルドのみ)

  * `_set_se_translator` が無いので、ハードウェア例外を C++ 例外に変換できない。
    代わりに `SetUnhandledExceptionFilter` でクラッシュログ (`xyzzy.BUG`) を
    出す (`install_exception_reporter`)。つまり **`catch (Win32Exception &)` は
    mingw ビルドでは発火しない**。この差は移植の未完了項目である。
  * FFI (`src/dll.cc`) は MSVC/x86 のときだけ従来の手書きスタック整列と x86 機械語
    トランポリンを使い、それ以外は **libffi** を使う。
  * 呼び出し規約は `LISPCALL` に集約した。MSVC は `/Gz` (stdcall 既定) で
    ビルドされるが mingw は cdecl 既定なので、lisp 組み込み関数へのポインタ型を
    コンパイラ既定に合わせている。
  * `funcall_builtin` は、MSVC/x86 では従来どおり alloca でスタックを組んで
    引数 0 個の `__stdcall` として呼ぶ小技を使い、それ以外では引数の数に応じた
    関数ポインタ経由で呼ぶ移植版を使う。


## 64bit (x86_64) 対応の状況

`tools/x build x86_64` は通り、`PE32+ x86-64` の `xyzzy.exe` ができる。
起動時に踏んだ 64bit 由来の不具合と対処は以下のとおり。すべて 32bit ビルドでも
正しい変更なので、MSVC/x86 の挙動は変えていない。

  * **可変長引数の番兵**: `make_list (a, b, 0)` の `0` は `int` である。
    ポインタが 4 バイトを超えるターゲットでは可変長引数スロットの上位半分が
    書かれないため、リストに不正な余分要素が付いていた。全呼び出し箇所で
    `(lisp)0` に変更 (36 箇所)。
  * **GC のスタック走査**: 保守的スキャンの両端が `int` サイズのアンカーだった
    ため 4 バイト境界から始まり、8 バイトずつ読むと無関係な 2 語を 1 つの
    ポインタとして解釈していた。両端を lisp 幅に丸めるようにした。
  * **アロケータの最小オブジェクトサイズ**: 解放済みスロットにはフリーリストの
    リンク (ポインタ) を書き込むため、オブジェクトはポインタより小さくできない。
    `llong_int` と `lsingle_float` が 4 バイトだったので 64bit ビルドでのみ
    パディングを入れ、条件を `static_assert` で常時検査するようにした。
  * **ページ内のオブジェクト整列**: `ldata_rep` のヘッダが 4 バイト境界で終わって
    いたため、ページ内の全オブジェクトが 8 バイト境界から 4 バイトずれていた。
    64bit ビルドでのみヘッダを整列させた。
  * **fixnum のタグ付け** (`number.h`) をポインタ幅の型で行うようにした。
    fixnum の値域は `BITS_PER_LONG` 由来のまま (32bit と同じ) にしている。
  * **ポインタを切り捨てていた箇所** … `pointer_t` を `uintptr_t` に変更し、
    ウィンドウの追加領域は `Get/SetWindowLongPtr` + `GWLP_*`/`DWLP_*` に変更
    (59 箇所)、`lCustData`/`WinHelp`/`HtmlHelp`/`_open_osfhandle`/
    `_beginthreadex`/リストボックスのアイテムデータなど、ポインタが 32bit に
    収まらない箇所を順に修正した。
  * **ダイアログプロシージャ**の戻り値を `INT_PTR` にした (x64 の `DLGPROC`)。
  * **DDE コールバック**の `dwData1`/`dwData2` を `ULONG_PTR` にした
    (`CONVCONTEXT *` を運ぶため 32bit では足りない)。
  * `alloc_page` がポインタの下位 32bit からアドレスを再構成していたのを修正。
  * **クラッシュログ**に x86-64 のレジスタダンプを追加した。ポインタの表示幅も
    64bit にした。

到達点:

  * `tools/x build x86_64` … **エラー 0、ポインタ切り捨て警告 0**。
    `PE32+ x86-64` の `xyzzy.exe` ができる。
  * `tools/x prepare x86_64` … 起動シーケンスを完走し、`(dump-xyzzy)` で
    ダンプイメージを書いて正常終了する。つまり **エディタとして起動する**。

### 残っている作業

  * `tools/x test x86_64` (unittest 一式) の完走確認。
  * `catch (Win32Exception &)` に相当する保護の再実装。
  * Win9x 専用の `VWIN32` 経路 (`src/vfs.cc`, `src/pathname.cc`) は 64bit では
    実行されないが、ポインタを 32bit レジスタ像に渡す部分がそのまま残っている。
  * lisp 側 FFI の `:int32` でポインタを扱っている既存資産は、64bit では
    そのままでは動かない。宣言を `:int64` に直す必要がある。
  * MSVC 側の x64 構成 (`xyzzy.sln`) は未追加。CMake 側で通ったので、同じ変更で
    通るはずだが未検証。
