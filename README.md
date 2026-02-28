# xyzzy

[![Build](https://github.com/snmsts/xyzzy/actions/workflows/build.yml/badge.svg)](https://github.com/snmsts/xyzzy/actions/workflows/build.yml)

[亀井哲弥氏](http://www.jsdlab.co.jp/~kamei/)が開発した Common Lisp 風の言語で拡張可能な Emacs 風テキストエディタです。

このフォークは [xyzzy-022](https://github.com/xyzzy-022/xyzzy) (0.2.2.253) をベースに、
ARM64 で動くようにしたり、Win32 API を Unicode 化したりしています。たぶん動きます。

## ダウンロード

[Releases](https://github.com/snmsts/xyzzy/releases/latest) から ZIP をダウンロードしてください。

| アーカイブ | 対象 |
|---|---|
| xyzzy-...-arm64.zip | ARM64 (Snapdragon など) |
| xyzzy-...-amd64.zip | x86-64 (普通の PC) |
| xyzzy-...-x86-msvc.zip | x86 (32-bit、互換用) |

## インストール

アーカイブを**ディレクトリつきで**展開すればできあがりです。インストーラなどという気の利いたものはないので、ショートカットとかファイルの関連付けなどをしたい場合は自分でやってください。

## アンインストール

当然のことながらアンインストーラはないので、展開したディレクトリを丸ごと削除してください。

## 主な変更点

- ARM64 / x86-64 / x86 で動作
- Win32 API: ANSI (A-suffix) から Unicode (W-suffix) に移行 — システムロケールに依存しない
- デフォルトファイルエンコーディング: UTF-8N
- ビルドシステム: Visual Studio ソリューションから CMake に移行

## ビルド方法

CI では MSVC (Visual Studio 17 2022) でビルドしています。
MSYS2 + Clang でもビルドできます。詳しくは [CMakeLists.txt](CMakeLists.txt) を参照してください。

## バージョン体系

`0.{Y1}.{Y2}.{M}` — `Y1.Y2` が西暦下2桁、`M` が月。

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照。
