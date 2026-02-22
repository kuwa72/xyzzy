# xyzzy

[![Build](https://github.com/snmsts/xyzzy/actions/workflows/build.yml/badge.svg)](https://github.com/snmsts/xyzzy/actions/workflows/build.yml)

[亀井哲弥氏](http://www.jsdlab.co.jp/~kamei/)が開発した Common Lisp 風の言語で拡張可能な Emacs 風テキストエディタです。

このフォークは [xyzzy-022](https://github.com/xyzzy-022/xyzzy) (0.2.2.253) をベースに、
ビルドシステムを CMake に置き換えたり、Win32 API を Unicode 化したり、
ARM64 で動くようにしたりしています。たぶん動きます。

## 主な変更点

- ビルドシステム: Visual Studio ソリューションから CMake に移行
- Win32 API: ANSI (A-suffix) から Unicode (W-suffix) に移行 — システムロケールに依存しない
- デフォルトファイルエンコーディング: UTF-8N
- ARM64 / x86-64 対応 (MSYS2 でビルド)

## ビルド方法

### 必要なもの

- [MSYS2](https://www.msys2.org/)
- clangarm64 (ARM64) または mingw64 (x86-64) のいずれかの環境

```bash
# ARM64 の場合
pacman -S mingw-w64-clang-aarch64-clang mingw-w64-clang-aarch64-cmake mingw-w64-clang-aarch64-zlib

# x86-64 の場合
pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-cmake mingw-w64-x86_64-zlib
```

### ビルド手順

```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles"
cmake --build . -- -j4
```

### バイトコンパイル

```bash
cmake --build . --target bytecompile
```

Lisp ファイルをバイトコンパイルします。これをやっておかないと起動がとても遅いです。

### パッケージ作成

```bash
cpack
```

ZIP アーカイブが生成されます。

## バージョン体系

`0.{Y1}.{Y2}.{M}` — `Y1.Y2` が西暦下2桁、`M` が月。
12月は `0` 扱いで年が繰り上がります。

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照。
