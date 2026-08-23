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

### 土台 (snmsts/xyzzy modern) から引き継いでいるもの

- ARM64 / x86-64 / x86 で動作
- Win32 API: ANSI (A-suffix) から Unicode (W-suffix) に移行 — システムロケールに依存しない
- デフォルトファイルエンコーディング: UTF-8N
- ビルドシステム: Visual Studio ソリューションから CMake に移行
- 各種言語モード追加 (json, yaml, python, javascript, typescript, markdown 等)
- ncurses フロントエンド (Linux/macOS)
- VT100 ターミナルエミュレータ (Win32 ConPTY / ncurses)

### この私家版で入れたもの

- ターミナルバッファを実用に耐えるところまで修正 — 24bit/256 色と OSC、Ambiguous 幅の
  桁ずれ、豆腐になる記号、矢印キー・IME 位置・貼り付け、ホイール、描画のまとめ、
  リサイズ追従
- Nerd Font のアイコン用フォント枠 (`:symbol`) と、フォント設定の絞り込み入力欄
- 32bit の DLL 呼び出しと、バイトコンパイルの取り残し (81 ファイル) の修正
- llvm-mingw + Wine のクロスビルド環境 (`tools/x`) — Windows マシン無しで
  ビルドからテストまで回せる
- テストを既知失敗リストで gate し、リリースの版番号・ノート・成果物を検証する CI
- 3 桁のバージョン体系 (`MAJOR.MINOR.PATCH`)

各リリースで何をなぜ変えたかは [docs/](docs/) のリリースノートに書いてあります。

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

MIT ライセンスです。詳細は [LICENSE](LICENSE)、個別のファイルの由来は [LEGAL.md](LEGAL.md)
を参照してください。本体の著作権は原作者の亀井哲弥氏、および xyzzy-022 / snmsts/xyzzy に
貢献した方々にあります。この私家版はその上に乗っているだけです。
