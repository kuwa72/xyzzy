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

### MSVC (CI と同じ)

```powershell
vcpkg install zlib:arm64-windows-static-md   # or x64-windows-static-md
cmake -B build -G "Visual Studio 17 2022" -A ARM64 `
  -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=arm64-windows-static-md
cmake --build build --config Release
cmake --build build --config Release --target bytecompile
```

### MSYS2 + Clang (ARM64)

```bash
pacman -S mingw-w64-clang-aarch64-{clang,cmake,make,zlib}
export PATH=/clangarm64/bin:$PATH
cmake -B build-clangarm64 -G "MinGW Makefiles" \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_RC_COMPILER=llvm-windres -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build-clangarm64 -- -j$(nproc)
cmake --build build-clangarm64 --target bytecompile
```

### Linux (ncurses フロントエンド)

```bash
# Debian/Ubuntu
sudo apt install build-essential cmake libncursesw5-dev zlib1g-dev
cmake -B build-curses -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build build-curses --target xyzzy-ncurses -- -j$(nproc)
```

### mingw-w64 クロスビルド (Linux/macOS から Windows 版を作る)

Windows マシンが無くても Windows 版をビルドして動かせます。docker だけ要ります。
ビルドは mingw-w64、実行は Wine です。

```bash
tools/x image                # コンテナイメージを作る (初回のみ、20分ほど)
tools/x configure x86_64     # i686 も指定できます
tools/x build     x86_64
tools/x bytecompile x86_64   # .lc を作る (Wine 上の起動が速くなる)
tools/x test      x86_64     # テストスイートを Wine で流す
```

`tools/x` を引数なしで実行するとサブコマンドの一覧が出ます。CI の
`mingw` ワークフローも同じ `tools/x` を呼んでいるので、CI が落ちたときは
手元で同じことを再現できます。

リリース用のバイナリは従来どおり MSVC の `build` ワークフローが作ります。

bytecompile で Lisp ファイル (.l) をバイトコンパイル (.lc) します。初回起動が大幅に速くなります。

## バージョン体系

`0.{Y1}.{Y2}.{M}` — `Y1.Y2` が西暦下2桁、`M` が月。

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照。
