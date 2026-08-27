ビルド方法
==========

Windows 版を作るツールチェインは 2 つあります。ふだんの開発は llvm-mingw
(Clang/LLD + UCRT) で、x86 / x86-64 / ARM64 をどれも Linux や macOS から
クロスビルドできます。MSVC は上流に合わせるためと、リリース物を作るために
維持しています。MSYS2 / Cygwin は対応しません。

llvm-mingw クロスビルド (ふだんの開発用)
-----------------------------------------

Windows マシンが無くても Windows 版をビルドして動かせます。docker だけ要ります。
ビルドは llvm-mingw (Clang/LLD + UCRT)、実行は Wine です。

```bash
tools/x image                # コンテナイメージを作る (初回のみ、20分ほど)
tools/x configure x86_64     # i686 / aarch64 も指定できます
tools/x build     x86_64
tools/x bytecompile x86_64   # .lc を作る (Wine 上の起動が速くなる)
tools/x test      x86_64     # テストスイートを Wine で流す
```

ARM64 はビルドのみです。ここの Wine は x86 の機械語しか実行しないので、ARM64 の
バイナリは動かせません (テストは MSVC の windows-11-arm ジョブが見ています)。
コードジェネレータもターゲット向けにビルドされて動かせないので、先に
`src/core/gen/` を用意します。

```bash
tools/x arm-prep             # x86_64 側でジェネレータだけ動かして src/core/gen/ を作る
tools/x configure aarch64
tools/x build     aarch64
```

`tools/x` を引数なしで実行するとサブコマンドの一覧が出ます。CI の `mingw`
ワークフローは i686 / x86_64 / aarch64 を同じ `tools/x` で回しているので、CI が
落ちたときは手元で同じことを再現できます。

テストスイートには構成ごとに外しているものがあります (`tools/run-tests.sh` と
`misc/run-tests-batch.l` にそれぞれ理由を書いてあります)。Clang ビルドには
`_set_se_translator` に相当する SEH 変換が無く、さらに i686 では LLVM が 32bit
x86 の SEH を扱えないので、ハードウェア例外を Lisp のコンディションとして受け取る
テストだけは MSVC ビルドが見ています。

スイートはどの構成でも全部は通らないので、既知の失敗を名前で
`misc/known-failures/` に書き出して、**それ以外**で CI を止めています。リスト外が
落ちたら赤、リストに載っているテストが通るようになった場合も赤です。詳細は
[misc/known-failures/README.md](../../misc/known-failures/README.md) を参照してください。

リリース用のバイナリは従来どおり MSVC の `build` ワークフローが作ります。
リリースの出し方は [RELEASING.md](../../RELEASING.md) にまとめてあります。

MSVC (リリース物と上流互換)
----------------------------

```powershell
vcpkg install zlib:arm64-windows-static-md   # or x64-windows-static-md
cmake -B build -G "Visual Studio 17 2022" -A ARM64 `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=arm64-windows-static-md
cmake --build build --config Release
cmake --build build --config Release --target bytecompile
```

Linux (ncurses フロントエンド)
-------------------------------

```bash
# Debian/Ubuntu
sudo apt install build-essential cmake libncursesw5-dev zlib1g-dev
cmake -B build-curses -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build-curses --target xyzzy-ncurses -- -j$(nproc)
```

bytecompile で Lisp ファイル (.l) をバイトコンパイル (.lc) します。初回起動が大幅に速くなります。

### 端末フロントエンドの画面を見る

Linux ビルドには Lisp テストスイートが無く (#49)、`tools/linux-smoke.sh` は
「プロセスが起動する」ところまでしか見ません。**画面に何が描かれるか**
(カーソルの位置、ポップアップの見え方、そもそもキーがコマンドループに
届いているか) は見るしかないので、pty に繋いで打鍵を流し込み、画面を
テキストで吐く道具を置いてあります。

```bash
tools/x build linux
tools/x pty '(defun foo (x' '\e\e(buffer-substring (point-min) (point-max))\r'
```

引数 1 つが 1 ステップで、キーを送ってから出力が落ち着いたところで画面を
印字します。エスケープと環境変数は `tools/pty-drive.py` の docstring に
あります。`\e\e` (eval-expression) の結果はステータス行に出て、
ステータス行も画面の一部として吐かれるので、動いているエディタに
その場で質問するのが一番速い確認方法です。
