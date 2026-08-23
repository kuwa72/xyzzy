# xyzzy — kuwa72 私家版

[![MSVC](https://github.com/kuwa72/xyzzy/actions/workflows/build.yml/badge.svg)](https://github.com/kuwa72/xyzzy/actions/workflows/build.yml)
[![llvm-mingw](https://github.com/kuwa72/xyzzy/actions/workflows/mingw.yml/badge.svg)](https://github.com/kuwa72/xyzzy/actions/workflows/mingw.yml)

[亀井哲弥氏](http://www.jsdlab.co.jp/~kamei/)が開発した、Common Lisp 風の言語で拡張できる
Emacs 風テキストエディタ xyzzy の**私家版**です。**公式でも、有志による本流でもありません。**
自分が毎日使うために直しているものを、そのまま置いてあります。

## この私家版の立ち位置

```
亀井哲弥氏のオリジナル (0.2.2.235)
 └ xyzzy-022/xyzzy         有志による継続開発 (0.2.2.253)
    └ snmsts/xyzzy modern  ARM64/x86-64、Win32 の Unicode 化、CMake 化、
       │                   tree-sitter、ncurses フロントエンド (0.2.6.x)
       └ kuwa72/xyzzy      ← ここ (0.3.x)
```

土台の大きな作り直しは [snmsts/xyzzy](https://github.com/snmsts/xyzzy) の `modern` によるものです。
ここはその上に、常用して困ったところ (ターミナル、フォント、ビルドとリリースの足回り) を
足しているだけの木で、版番号も上流とは別に振っています。

  * **無保証です。** 自分の環境で動くことしか確かめていません。
  * **上流に持ち込まないでください。** ここ由来の不具合を xyzzy-022 や snmsts に報告されると
    向こうが困ります。報告は [Issues](https://github.com/kuwa72/xyzzy/issues) へどうぞ。
  * 素の xyzzy が欲しい場合は [xyzzy-022/xyzzy](https://github.com/xyzzy-022/xyzzy)、
    ARM64/Unicode 対応だけが欲しい場合は [snmsts/xyzzy](https://github.com/snmsts/xyzzy) を
    見てください。

## ダウンロード

[Releases](https://github.com/kuwa72/xyzzy/releases/latest) からインストーラまたは ZIP をダウンロードしてください。
インストール手順・対応アーキテクチャの一覧は [docs/user/installation.md](docs/user/installation.md) を参照してください。

## 使い方

  * [機能一覧](docs/user/features.md) — 何ができるか、どう使うか
  * [キーバインド](docs/user/keybindings.md) — 主要な操作の早見表
  * [設定](docs/user/configuration.md) — GUI の設定ダイアログと設定ファイルの関係
  * [コマンドラインオプション](docs/user/command-line.md) — 起動オプションと xyzzycli
  * [Lisp で拡張する](docs/user/lisp-extensions.md) — 初期化ファイルの書き方と関数リファレンス

バージョンは `MAJOR.MINOR.PATCH` の3桁 (私家版なので上流とは別に振っています)。
各リリースで何をなぜ変えたかは [Releases](https://github.com/kuwa72/xyzzy/releases)
のノートを参照してください。

## 開発する・ビルドする

ソースからビルドする方法、CI やリリース手順などは
[docs/dev/](docs/dev/README.md)、[CLAUDE.md](CLAUDE.md)、
[RELEASING.md](RELEASING.md) にまとめてあります。

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE)、個別のファイルの由来は [LEGAL.md](LEGAL.md)
を参照してください。本体の著作権は原作者の亀井哲弥氏、および xyzzy-022 / snmsts/xyzzy に
貢献した方々にあります。この私家版はその上に乗っているだけです。
