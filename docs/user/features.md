機能一覧
========

基本的なエディタ機能
--------------------

xyzzy は Emacs 風のキー操作を持つテキストエディタです。ファイルの読み書き、
回数制限のある Undo/Redo、正規表現検索・置換、矩形選択、ウィンドウ分割といった
一通りの編集機能に加えて、拡張言語 (xyzzy Lisp) でエディタ自体を書き換えられます。
主要な操作のキーは [キーバインド](keybindings.md) を、拡張の書き方は
[Lisp で拡張する](lisp-extensions.md) を参照してください。

ファイラ
--------

`Ctl-x Ctl-f`(ディレクトリを開く) などから使えるファイル一覧・操作画面です。
一覧上でファイルの削除・コピー・移動・名前変更ができます。詳細は
[キーバインド](keybindings.md) のファイラの項を参照してください。

言語モード
----------

`etc/` 以下にシンタックス定義があるものだけでも C, C++, C#, Java, JavaScript,
TypeScript, Python, Perl, HTML/HTML5, CSS/CSS3, SQL, TeX, Pascal, Fortran,
Basic, IDL, Lisp などのモードが入っています。JSON, YAML, TOML, Makefile, CMake,
Dockerfile なども含め、ファイルを開くと拡張子や shebang から自動的にモードが選ばれます。
tree-sitter によるハイライトが使えるモードもあります (C, C++, Perl, Markdown)。
各モードの詳細や設定方法は [標準添付 Lisp ライブラリ・モード](lisp-libraries.md) を参照してください。

このフォーク独自の機能
-----------------------

### ターミナルエミュレータ

`M-x shell` でシェルを起動したターミナルバッファを開けます。VT100 互換で、
24bit/256 色、OSC (タイトル変更・クリップボード)、East Asian Ambiguous 幅の
文字、矢印キーや機能キー、IME の入力位置、マウス報告 (vim・htop・claude code
のような TUI が自分でマウスを使うもの)、synchronized output に対応しています。
Windows では ConPTY、Linux/macOS では ncurses フロントエンド経由で動きます。

Windows 版ではスクロールバック (ホイール・スクロールバー・`S-PageUp`) と、
マウスによるテキスト選択 (離した時点でクリップボードへ入る) が使えます。
ターミナル内のキー・マウス操作は [キーバインド](keybindings.md#ターミナル) を
参照してください。

### Nerd Font アイコン用フォント枠

フォント設定 (共通設定の「表示」ページ、[設定](configuration.md) を参照) に
`:symbol` という枠があり、ここに Nerd Font 系のフォントを指定すると、ファイラの
アイコンなどに使うシンボル文字を通常のフォントと別に描画できます。フォント名の
入力欄は入力した文字列で絞り込みができます。

### ARM64 / x86-64 / x86 対応と Unicode 化

Win32 API は Unicode (W サフィックス) 版を使っているため、システムロケールに
かかわらず動作します。既定のファイルエンコーディングは UTF-8N です。ARM64 (Snapdragon
搭載機など) を含む3アーキテクチャに、ネイティブのインストーラ・ZIP が用意されています。
[インストール](installation.md) を参照してください。

### Linux / macOS (ncurses フロントエンド)

ターミナル上で動く ncurses ベースのフロントエンドがあり、Windows 専用だった
GUI 版と機能をなるべく共有しています。ソースからビルドする方法はリポジトリの
`docs/dev/building.md` にあります。

各リリースで何をなぜ変えたかは、リポジトリの `docs/release-notes/release-note-<版>.md` や
GitHub の [Releases](https://github.com/kuwa72/xyzzy/releases) に書いてあります。
