# xyzzy

xyzzy は[亀井哲弥氏](http://www.jsdlab.co.jp/~kamei/)が開発した、
Common Lisp 風の言語で拡張可能な Emacs 風テキストエディタです。

このフォークは [xyzzy-022](https://github.com/xyzzy-022/xyzzy) (0.2.2.253) をベースに、
ビルドシステムの近代化とマルチアーキテクチャ対応を進めています。

## 現在の状態

- バージョン: 0.2.6.2
- ビルドシステム: CMake (旧 Visual Studio ソリューションから移行)
- Win32 API: UNICODE (W-suffix) に移行済み — システムロケール非依存
- デフォルトファイルエンコーディング: UTF-8N
- 動作確認: Windows 11 on ARM64 (MSYS2/clangarm64 でビルド)

## 互換性について

0.2.2.235 との互換性は考慮しますが、バグ修正や近代化のための変更は積極的に行います。

主な変更点:

- ANSI API → Unicode API への移行 (`CP_ACP` 依存の排除)
- デフォルトエンコーディングの UTF-8N 化
- ARM64 / x86-64 対応

## ビルド方法

### 必要なもの

- [MSYS2](https://www.msys2.org/)
- clangarm64 (ARM64) / clang64 (x86-64) / mingw32 (x86) のいずれかの環境

```bash
# ARM64 の場合
pacman -S mingw-w64-clang-aarch64-clang mingw-w64-clang-aarch64-cmake mingw-w64-clang-aarch64-zlib
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

ビルド済みの xyzzy.exe を使って Lisp ファイルをバイトコンパイルし、
ダンプイメージを生成します。

### テスト

```bash
ctest
```

### パッケージ作成

```bash
cpack
```

ZIP アーカイブが生成されます。

## バージョン体系

`0.2.{y}.{r}` — `y` は西暦下1桁、`r` はリリース番号。

- 0.2.6.2 → 2026年、2回目のリリース

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照。
