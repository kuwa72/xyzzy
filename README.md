# xyzzy

[![Build](https://github.com/snmsts/xyzzy/actions/workflows/build.yml/badge.svg)](https://github.com/snmsts/xyzzy/actions/workflows/build.yml)

[亀井哲弥氏](http://www.jsdlab.co.jp/~kamei/)が開発した Common Lisp 風の言語で拡張可能な Emacs 風テキストエディタです。

このフォークは [xyzzy-022](https://github.com/xyzzy-022/xyzzy) (0.2.2.253) をベースに、
ARM64 で動くようにしたり、Win32 API を Unicode 化したりしています。たぶん動きます。

## ダウンロード

[Releases](https://github.com/snmsts/xyzzy/releases/latest) からインストーラまたは ZIP をダウンロードしてください。

| ファイル | 対象 |
|---|---|
| xyzzy-...-arm64-setup.exe | ARM64 インストーラ (Snapdragon など) |
| xyzzy-...-amd64-setup.exe | x86-64 インストーラ (普通の PC) |
| xyzzy-...-x86-setup.exe | x86 インストーラ (32-bit、互換用) |
| xyzzy-...-arm64.zip | ARM64 ZIP |
| xyzzy-...-amd64.zip | x86-64 ZIP |
| xyzzy-...-x86.zip | x86 ZIP |

## インストール

### インストーラ版

セットアップ exe を実行してください。スタートメニュー、PATH 追加、右クリック「Open with xyzzy」などを設定できます。
署名していないので、SmartScreen にブロックされる場合があります。そのときは ZIP 版をどうぞ。

### ZIP 版

アーカイブを**ディレクトリつきで**展開すればできあがりです。ショートカットやファイルの関連付けは自分でやってください。

## アンインストール

インストーラ版は「プログラムの追加と削除」から。ZIP 版は展開したディレクトリを丸ごと削除してください。

## 主な変更点

- ARM64 / x86-64 / x86 で動作
- Win32 API: ANSI (A-suffix) から Unicode (W-suffix) に移行 — システムロケールに依存しない
- デフォルトファイルエンコーディング: UTF-8N
- ビルドシステム: Visual Studio ソリューションから CMake に移行
- 各種言語モード追加 (json, yaml, python, javascript, typescript, markdown 等)
- ncurses フロントエンド (Linux/macOS)
- VT100 ターミナルエミュレータ (Win32 ConPTY / ncurses)

## ビルド方法

Windows 版を作るツールチェインは 2 つあります。ふだんの開発は llvm-mingw
(Clang/LLD + UCRT) で、x86 / x86-64 / ARM64 をどれも Linux や macOS から
クロスビルドできます。MSVC は上流に合わせるためと、リリース物を作るために
維持しています。MSYS2 / Cygwin は対応しません。

### llvm-mingw クロスビルド (ふだんの開発用)

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
[misc/known-failures/README.md](misc/known-failures/README.md) を参照してください。

リリース用のバイナリは従来どおり MSVC の `build` ワークフローが作ります。
リリースの出し方は [RELEASING.md](RELEASING.md) にまとめてあります。

### MSVC (リリース物と上流互換)

```powershell
vcpkg install zlib:arm64-windows-static-md   # or x64-windows-static-md
cmake -B build -G "Visual Studio 17 2022" -A ARM64 `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=arm64-windows-static-md
cmake --build build --config Release
cmake --build build --config Release --target bytecompile
```

### Linux (ncurses フロントエンド)

```bash
# Debian/Ubuntu
sudo apt install build-essential cmake libncursesw5-dev zlib1g-dev
cmake -B build-curses -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build-curses --target xyzzy-ncurses -- -j$(nproc)
```

bytecompile で Lisp ファイル (.l) をバイトコンパイル (.lc) します。初回起動が大幅に速くなります。

## バージョン体系

`MAJOR.MINOR.PATCH` の 3 桁。私家版なので上流とは別に振る。

  * PATCH — バグ修正だけ (0.3.1, 0.3.2 …)
  * MINOR — 機能追加や作り直しが入ったとき (0.4.0)
  * MAJOR — 常用に耐えると判断したら 1.0.0

0.2.6.8 までは `0.{Y1}.{Y2}.{M}` (西暦下2桁と月) だったが、同じ月に2回出せない
体系だったのでやめた。過去のタグはそのまま残してある。

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照。
