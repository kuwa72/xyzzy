# 標準添付 Lisp ライブラリ・モード一覧

xyzzy には、テキスト編集、各種プログラミング言語・マークアップ言語の構文ハイライトやインデントを行うモード、検索・置換・Grep などの編集支援ツール、Common Lisp 互換の基礎ライブラリなど、多数の Lisp ライブラリが標準で同梱されています。

このドキュメントでは、標準添付されている Lisp ライブラリおよびモードの全容、提供機能、自動読み込み条件、主要なコマンドや設定変数をまとめて解説します。

---

## 目次

1. [ライブラリの読み込み構成](#ライブラリの読み込み構成)
2. [主要な言語・編集モード](#主要な言語編集モード)
   - [プログラミング言語モード](#プログラミング言語モード)
   - [マークアップ・データ記述・設定モード](#マークアップデータ記述設定モード)
   - [ビルド・運用設定モード](#ビルド運用設定モード)
   - [テキスト・閲覧・比較モード](#テキスト閲覧比較モード)
3. [エディタ拡張機能 & 対話ツール](#エディタ拡張機能--対話ツール)
   - [端末・外部プロセス連携](#端末外部プロセス連携)
   - [検索・置換・Grep](#検索置換grep)
   - [入力支援・略語展開・整形](#入力支援略語展開整形)
   - [コードナビゲーション & タグ](#コードナビゲーション--タグ)
   - [ファイラ・バッファ・セッション管理](#ファイラバッファセッション管理)
   - [ユーティリティ・変換・辞書](#ユーティリティ変換辞書)
   - [アミューズメント & ゲーム](#アミューズメント--ゲーム)
4. [コアシステム・内部ライブラリ](#コアシステム内部ライブラリ)
5. [実験的・拡張ライブラリ (lisp/wip/)](#実験的拡張ライブラリ-lispwip)
   - [Outline Tree (アウトラインツリー)](#outline-tree-アウトラインツリー)
   - [TreeView (ツリービュー)](#treeview-ツリービュー)
   - [その他のサンプル・拡張](#その他のサンプル拡張)
6. [カスタマイズ例 (Tips)](#カスタマイズ例-tips)

---

## ライブラリの読み込み構成

xyzzy の Lisp ライブラリは、用途や読み込みタイミングに応じて以下の4つに大別されます。

| 種別 | 配置・読み込み方法 | 概要 |
|---|---|---|
| **ダンプイメージ内包 (Core)** | `lisp/loadup.l` により起動イメージに事前ロード | xyzzy の基本動作、エディタ操作、Lisp 実行環境に必要なコア機能。起動時から常に利用可能。 |
| **自動ロード (Autoload)** | `lisp/defs.l` / `lisp/ldefs.l` で定義 | ファイルを開いたとき (拡張子・shebang 判定) や、対応する `M-x` コマンドを実行した際にオンデマンドで自動読み込みされる。 |
| **明示的ロード (Require/Load)** | `~/.xyzzy` 等で `(require "...")` | 必要に応じて手動で読み込むライブラリ (Emmet、Windows風キーバインドサンプルなど)。 |
| **実験的拡張 (WIP)** | `lisp/wip/` 配下 | 高機能なアウトラインツリー (`outline-tree`) や Win32 API サンプルなど、高度な拡張群。 |

---

## 主要な言語・編集モード

ファイルを開くと、拡張子 (`*auto-mode-alist*`) またはファイル先頭の shebang 行 (`*interpreter-mode-alist*`) に基づいて自動的に適切なモードが選択されます。

### プログラミング言語モード

| モード名 | コマンド (`M-x`) | ファイル | 対象拡張子 / 判定 | 主な機能・特徴 |
|---|---|---|---|---|
| **C** | `c-mode` | `lisp/c-mode.l` | `.c` (および `.h` の自動判定) | 構文ハイライト、スマートインデント、プリプロセッサディレクティブ整形。Tree-sitter モード (`ts-c-mode`) 対応。 |
| **C++** | `c++-mode` | `lisp/cc-mode.l` | `.cc`, `.cxx`, `.cpp`, `.hxx`, `.hpp`, `.inl` | C++ 構文ハイライト、クラス・アクセス修飾子インデント。Tree-sitter モード (`ts-c++-mode`) 対応。 |
| **C#** | `csharp-mode` | `lisp/c#-mode.l` | `.cs` | C# キーワードハイライト、プロパティ・名前空間インデント。 |
| **Java** | `java-mode` | `lisp/java.l`, `lisp/javafns.l` | `.java` | Java キーワードハイライト、インデント、TAGS 作成 (`java-maketags`)。 |
| **JavaScript** | `javascript-mode` | `lisp/javascript-mode.l` | `.js`, `.jsx`, `.mjs`, `.cjs` / `node` | JS/JSX 構文ハイライト、インデント、電気的閉じ括弧。 |
| **TypeScript** | `typescript-mode` | `lisp/javascript-mode.l` | `.ts`, `.tsx` | TypeScript/TSX 構文ハイライト、型アノテーション対応。 |
| **Python** | `python-mode` | `lisp/python-mode.l` | `.py`, `.pyw` / `python`, `python3` | インデントベース構文支援、コロン入力時の自動インデント (`python-electric-colon`)、ブロック移動。 |
| **Perl** | `perl-mode` | `lisp/perl.l` | `.pl`, `.pm`, `.cgi` / `perl`, `perl5` | Perl 構文ハイライト、ヒアドキュメント、TAGS 作成 (`perl-maketags`)。Tree-sitter モード (`ts-perl-mode`) 対応。 |
| **Lisp** | `lisp-mode`<br>`lisp-interaction-mode` | `lisp/lispmode.l` | `.l`, `.lisp` | Lisp 式評価 (`eval-region`, `eval-current-buffer`, `eval-last-sexp`), インデント (`lisp-indent-line`), S式操作。`*scratch*` バッファは既定で `lisp-interaction-mode`。 |
| **Shell Script** | `shell-script-mode` | `lisp/shell-mode.l` | `.sh`, `.bash`, `.zsh` / `sh`, `bash`, `zsh` | シェルスクリプト用ハイライト、インデント支援。 |
| **Basic** | `basic-mode` | `lisp/basic-mode.l` | `.bas`, `.mb`, `.frm`, `.cls` | Visual Basic / QuickBASIC 構文ハイライト、インデント、TAGS 作成 (`basic-maketags`)。 |
| **Pascal** | `pascal-mode` | `lisp/pascal.l` | `.pas` | Pascal/Delphi 構文ハイライト、対応括弧ジャンプ (`pascal-goto-matched-parenthesis`)。 |
| **IDL** | `idl-mode` | `lisp/idl-mode.l` | `.idl` | CORBA / COM IDL (インターフェース定義言語) のキーワードハイライトとインデント。 |

- **主なフック・キーマップ**:
  - 各モードごとに `*<mode>-hook*` (例: `*c-mode-hook*`, `*python-mode-hook*`) と `*<mode>-map*` (例: `*c-mode-map*`, `*python-mode-map*`) が用意されています。
- **Tree-sitter 連携**:
  - `lisp/ts.l` により、C, C++, Perl, Markdown などで Tree-sitter による高精度な構文解析・ハイライトが利用可能です。

---

### マークアップ・データ記述・設定モード

| モード名 | コマンド (`M-x`) | ファイル | 対象拡張子 | 主な機能・特徴 |
|---|---|---|---|---|
| **HTML+** | `html+-mode` | `lisp/html+-mode.l`<br>`lisp/html-kwd.l` | `.html`, `.htm`, `.shtml` | タグハイライト、タグ対応チェック (`html+-check-match-tag`)、終了タグ自動補完 (`html+-close-match-tag` / `C-c /`), キーワード補完。 |
| **CSS** | `css-mode`<br>`css2-mode`<br>`css3-mode` | `lisp/css-mode.l` | `.css` | CSS プロパティ・値のハイライト、CSS 補完 (`css-completion` / `M-TAB`), インデント。 |
| **XML** | `xml-mode` | `lisp/xml-mode.l` | `.xml`, `.xsl`, `.xslt`, `.svg`, `.xsd`, `.rss` | XML タグ・属性ハイライト、終了タグ自動補完 (`xml-electric-close-tag` / `</`), インデント (`*xml-indent-level*`)。 |
| **JSON** | `json-mode` | `lisp/json-mode.l` | `.json`, `.jsonc` | JSON 構文ハイライト、インデント (`*json-indent-level*`), 電気的閉じ括弧。 |
| **YAML** | `yaml-mode` | `lisp/yaml-mode.l` | `.yaml`, `.yml` | YAML 構文ハイライト、インデント支援、セクション移動 (`yaml-next-section`, `yaml-previous-section`)。 |
| **TOML** | `toml-mode` | `lisp/toml-mode.l` | `.toml` | TOML テーブル・キー・バリューハイライト、インデント。 |
| **Markdown** | `markdown-mode` | `lisp/markdown.l` | `.md`, `.markdown` | 見出し・コードブロックハイライト、見出し間ナビゲーション (`markdown-heading-next`, `markdown-heading-previous`, `markdown-heading-up`)。Tree-sitter 対応。 |
| **LaTeX** | `LaTeX-mode` | `lisp/LaTeX.l` | `.tex` | LaTeX コマンド・数式ハイライト、キーワード補完 (`LaTeX-complete-keyword` / `M-TAB`), クォート自動変換 (`LaTeX-self-insert`)。 |
| **SQL** | `sql-mode` | `lisp/sql-mode.l` | `.sql` | SQL キーワードハイライト、キーワード補完 (`sql-completion` / `M-TAB`)。 |
| **Emmet** | (マクロ展開) | `lisp/emmet.l` | (HTML/CSS バッファ等) | `div.container>ul#nav>li*3>a` のような Emmet 略称を展開 (`emmet-expand-at-point`)。 |

---

### ビルド・運用設定モード

| モード名 | コマンド (`M-x`) | ファイル | 対象ファイル / 拡張子 | 主な機能・特徴 |
|---|---|---|---|---|
| **Makefile** | `makefile-mode` | `lisp/makefile-mode.l` | `Makefile`, `makefile`, `.mk` | ターゲット・変数・ディレクティブのハイライト。TAB 文字の維持支援。 |
| **CMake** | `cmake-mode` | `lisp/cmake-mode.l` | `CMakeLists.txt`, `.cmake` | CMake コマンド・変数ハイライト、インデント (`*cmake-indent-level*`)。 |
| **Dockerfile** | `dockerfile-mode` | `lisp/dockerfile-mode.l` | `Dockerfile`, `.dockerfile` | Docker 命令語 (FROM, RUN, CMD 等) のハイライト。 |

---

### テキスト・閲覧・比較モード

| モード名 | コマンド (`M-x`) | ファイル | 対象拡張子 | 主な機能・特徴 |
|---|---|---|---|---|
| **Fundamental** | `fundamental-mode` | `lisp/misc.l` | (拡張子未設定時) | エディタの最基本モード。特定の文法処理を行わないプレーンな状態。 |
| **Text** | `text-mode` | `lisp/textmode.l` | `.txt`, `.log` | 一般テキスト編集モード。センタリング (`center-line`, `center-paragraph`, `center-region`)、タブストップ移動。 |
| **View** | `view-mode` | `lisp/viewmode.l` | (閲覧用バッファ) | 読み取り専用バッファの簡易閲覧モード。`SPC` で次ページ、`DEL`/`b` で前ページ、`q` で終了。 |
| **Diff** | `diff-mode` | `lisp/diff.l` | (diff 出力) | 2つのファイルまたはバッファの差分を表示・マージ (`diff`, `diff-forward`, `diff-backward`, `diff-merge`)。 |
| **Tail -f** | `tail-f-mode` | `lisp/tail-f.l` | (ログ追従) | ファイルの末尾への追記を監視・自動スクロール表示 (`M-x tail-f`)。`q` で終了。 |

---

## エディタ拡張機能 & 対話ツール

### 端末・外部プロセス連携

- **ターミナルエミュレータ (`lisp/terminal.l`)**:
  - `M-x shell` でターミナルバッファを起動。Windows では ConPTY、Linux/macOS では擬似端末 (PTY) を使用し、VT100 / 24bit カラー対応の本格的な端末環境を提供。
  - `C-c` プレフィックスでエディタ側のコマンド (スクロールやバッファ切り替え) を実行可能。
- **外部プロセス実行 (`lisp/process.l`)**:
  - `launch-application` (`C-x c`): 外部アプリケーションをダイアログから起動。
  - `run-console` / `run-admin-console`: コマンドプロンプトを通常/管理者権限で起動。
  - `pipe-command` (`C-x |`): リージョンを指定コマンドの標準入力へ送り、出力を別バッファに受ける。
  - `filter-buffer` (`C-x #`): バッファ全体を指定コマンドでフィルタリングして置き換える。

---

### 検索・置換・Grep

- **Grep (`lisp/grep.l`, `lisp/grepd.l`)**:
  - `M-x grep` / `M-x fgrep`: 外部 grep または内蔵検索で複数ファイルを横断検索。
  - `M-x grep-dialog`: GUI ダイアログから検索ディレクトリ・マスク・オプションを指定して非同期 Grep を実行 (`async-grep-mode`)。
- **一括置換 (Gresreg) (`lisp/gresreg.l`, `lisp/gresregd.l`)**:
  - `M-x gresreg` / `M-x re-gresreg`: 複数ファイルにまたがる一括文字列/正規表現置換。
  - `M-x query-gresreg` / `M-x query-gresreg-regexp`: 確認しながら置換を進める対話型一括置換。
  - `M-x gresreg-dialog`: 置換対象ファイルや正規表現を GUI ダイアログで設定・実行。
- **インクリメンタルサーチ & 連続検索 (`lisp/isearch.l`, `lisp/csearch.l`)**:
  - `isearch-forward` / `isearch-backward`: 1文字入力するごとに前方/後方検索。
  - `search-forward-continuously` / `re-search-forward-continuously`: ダイアログを出さずに同一キーワードで連続検索。

---

### 入力支援・略語展開・整形

- **動的略称展開 (Dynamic Abbrev) (`lisp/dabbrev.l`)**:
  - `dabbrev-expand` (`C-x /`): バッファ内の単語から前方一致する候補を自動補完・順次切り替え。
  - `dabbrev-popup` (`C-x \\`): 候補一覧をポップアップメニューで表示して選択。
- **略称展開 (Abbrev) (`lisp/abbrev.l`)**:
  - `abbrev-mode`: 定義した略語 (abbreviation) をスペースや記号入力時に自動展開。略語テーブルの保存・編集 (`edit-abbrevs-mode`)。
- **Emmet 展開 (`lisp/emmet.l`)**:
  - `emmet-expand-at-point`: HTML/CSS の省略記法 (セレクタ形式) をカーソル位置で展開。
- **罫線描画モード (`lisp/boxdraw.l`)**:
  - `M-x box-drawings-mode`: 矢印キー移動に合わせて罫線文字 (`┌`, `─`, `│`, `┼` など) を自動作図。
- **自動折り返し & 段落整形 (`lisp/fill.l`)**:
  - `auto-fill-mode`: 右端マージン到達時に自動で改行を挿入。
  - `fill-paragraph` (`M-q`) / `fill-region` (`M-g`): 段落やリージョンを指定幅で綺麗に詰め込み整形。

---

### コードナビゲーション & タグ

- **TAGS (タグジャンプ) (`lisp/tags.l`, `lisp/maketags.l`)**:
  - `make-tags-file` / `make-tags-file-dialog`: ソースコードから TAGS ファイルを生成。
  - `jump-tag` (`M-.`): カーソル位置の関数・変数の定義場所へジャンプ。
  - `back-tag-jump` (`M-*`): ジャンプ元に戻る。
- **関数一覧 (`lisp/listfn.l`)**:
  - `M-x list-function`: バッファ内の関数・メソッド定義を抽出してリスト表示し、選択行へジャンプ。
- **C プリプロセッサ条件の非表示 (`lisp/hideif.l`)**:
  - `M-x hide-ifdef` / `M-x show-ifdef`: `#ifdef` / `#ifndef` ブロックを判定し、無効なコード領域を折りたたんで非表示化。
- **ウィンドウ比較 (`lisp/comparew.l`)**:
  - `M-x compare-windows`: 分割した2つのウィンドウの内容を先頭から比較し、差異がある位置までスクロール移動。

---

- **Leader Key & Which-key ガイダンス (`lisp/leader.l`)**:
  - `execute-leader-key` (`M-m` または `C-c SPC`): 画面を分割した `*Which Key*` ウィンドウに機能カテゴリ (`f:File`, `b:Buffer`, `p:Project`, `s:Search`, `g:Git`, `t:Toggle`, `w:Window`, `c:Code`, `h:Help` 等) を段組みで一覧表示し、キーボードのみで直感的に操作。
  - `leader-define-key`: 独自の Leader ショートカットとラベルを動的に登録。
- **定型コードの挿入 (スニペット) (`lisp/snippet.l`)**:
  - `snippet-expand` (`Leader c e`): 点の直前の略語をテンプレートに展開 (`defun`, `for`, `class` 等)。登録が無ければ一覧から選ぶ方へ回る。
  - `snippet-insert-by-name` (`Leader c i`): このモードのテンプレートをファジー絞り込みで選んで挿入。
  - `snippet-next-field` (`M-i`): 展開中のテンプレートの次の入力位置へ。既定値は選択された状態で入るので、そのまま打てば置き換わり、`M-i` で次へ行けば残る。
  - テンプレートの書き方は yasnippet と同じ (`$1`, `${1:既定値}`, `$0`, `$$`)。同じ番号を 2 度書くとミラーになる (`for (int ${1:i} = 0; $1 < ${2:n}; $1++)`)。`define-snippet` で追加。
- **外部フォーマッタ連携 (`lisp/formatter.l`)**:
  - `format-buffer` (`M-x`): モードに応じた外部フォーマッタ (`clang-format`, `prettier`, `black`, `shfmt` 等。表は `*formatter-alist*`) にバッファを流し込み、結果に差し替える。**起動できない・終了コードが 0 でない・出力が空、のいずれでもバッファに触らない。**
  - `*format-on-save*` / `*on-save-trim-trailing-whitespace*` / `*on-save-ensure-final-newline*`: 保存時に整形・行末空白の削除・末尾改行の付加を行う。**いずれも既定で無効** (保存のたびにファイルを黙って書き換える設定を勝手に入れないため)。`toggle-format-on-save` で切り替え。
- **ファジー絞り込み M-x (`lisp/fuzzy-mx.l`)**:
  - `fuzzy-execute-extended-command` (`M-x` / `Leader SPC`): コマンド名を打つそばからファジー絞り込みして選ぶ。空白区切りで複数キーワードを順不同指定できる (`buf list` → `list-buffers`)。直前に実行したコマンドが先に並ぶ (`*fuzzy-mx-history*`)。`*fuzzy-mx-mode*` を nil にすると従来の `read-command-name` (TAB 補完) に戻る。
  - 候補は `do-all-symbols` + `commandp` で集めるので、まだ読み込んでいないライブラリの autoload コマンドも出る (素の `M-x` と同じ範囲)。
  - 候補の右端にそのコマンドの割り当てキーが出る (Marginalia 相当)。複数あるときは一番短いものを選ぶ (一覧の目的は近道を知ることなので、`C-x C-b` と `F2` があるなら `F2`)。`*fuzzy-mx-annotate*` を nil にすると出さない。
- **シンボル一覧へのジャンプ (`lisp/imenu.l`)**:
  - `imenu` (`Leader c s`): バッファ内の関数・クラス・見出しの一覧をファジー絞り込みで選んでジャンプ。飛ぶ前にマークを置くので `C-x C-x` で元の位置へ戻れる。
  - 索引は `*imenu-generic-expression-alist*` の正規表現で作る (Lisp, Python, JavaScript, TypeScript, Perl, シェル, Markdown, Makefile, CMake, YAML, TOML, CSS)。登録が無いモードでは既存の `build-summary-function` (C 系は `lisp/cfns.l`、Java, Basic) にそのまま任せる。
  - `*imenu-create-index-function*` をバッファローカルに設定すると、そのバッファだけ独自の索引作成に差し替えられる。
- **ファジー絞り込みの縦型候補表示 (`lisp/fuzzy-complete.l`)**:
  - 候補を分割ウィンドウ (`*Candidates*`) に 1 行 1 件で並べる (Vertico 相当)。1 行目にプロンプトと打ちかけのクエリと件数、選択行に `>`。`*fuzzy-vertical*` を nil にするとステータス行 1 行の表示に戻る。行数は `*fuzzy-vertical-lines*`。
- **ウィンドウ分割の履歴 (`lisp/winner.l`)**:
  - `winner-undo` (`Leader w u`) / `winner-redo` (`Leader w r`): ウィンドウ分割の状態を戻す / やり直す。`*post-command-hook*` で構成の変化を見張り、変わる直前の構成を溜めておく。選択中のウィンドウを移すだけ (`C-x o`) は変化とみなさない。`toggle-winner-mode` で記録の有効/無効。
- **行・選択範囲の上下移動 (`lisp/move-text.l`)**:
  - `move-text-up` (`M-↑`) / `move-text-down` (`M-↓`): 現在行、または選択範囲に含まれる行をまとめて 1 行上/下へ移動。kill-ring を経由しないので貼り付け待ちの内容を潰さず、移動後も同じテキストが選択されたまま残る。
- **括弧・引用符の自動ペア挿入 (`lisp/autopair.l`)**:
  - `(`, `[`, `{`, `"` の入力で閉じ側も自動挿入。閉じ側を自分で打つと重ねずに乗り越え、空の対の中で `BS` を押すと 2 文字まとめて削除。選択範囲があれば置き換えではなく囲む。
  - `toggle-autopair` (`Leader t p`): オン/オフ。対の一覧は `*autopair-pairs*`。
  - キーマップではなく `lisp/cmds.l` の `*self-insert-hook*` / `*delete-backward-hook*` に掛けているので、`(` や `{` をローカルキーマップで奪っているモード (c-mode, lisp-mode, json-mode 等の electric コマンド) でも同じように効く。
- **キー入力中に一覧を見せる一時ウィンドウ (`lisp/popup-window.l`)**:
  - `with-popup-window` / `popup-window-draw` / `popup-window-columns`: 「キーを 1 文字ずつ読みながら候補を見せる」ための共通の仕組み。ステータス行 (`message`) を使わないのが要点で、`message` を書いた直後に `read-char` で待つとステータス行が描かれないフロントエンドがある (issue #66)。Leader メニューがこれを使う。
- **選択範囲の段階的拡大 (`lisp/expand-region.l`)**:
  - `expand-region` (`C-=` / `Leader v`) / `contract-region` (`M-=` / `Leader V`): 単語 → シンボル → 引用符の中 → 引用符ごと → 括弧の中 → 括弧ごと → 行 → 関数定義 → バッファ全体 の順に選択範囲を広げる / 戻す。段階を手続きで並べるのではなく候補を全部作って「今の範囲を真に含む最小のもの」を選ぶので、モードによって成立しない段階は自動的に飛ばされる。
- **プロジェクト管理 (Project) (`lisp/project.l`)**:
  - `project-find-file` (`Leader p f`): プロジェクト配下の全ファイルをインクリメンタル補完で選択してオープン。
  - `project-grep` (`Leader p g`): プロジェクトルート配下の全ファイルを対象とした一括検索。
  - `project-filer` (`Leader p d`): プロジェクトルートを起点にファイラを起動。
  - `project-open-terminal` (`Leader p t`): プロジェクトルートを作業ディレクトリとしてターミナルを起動。
  - `project-switch-project` (`Leader p p`): 過去に訪れたプロジェクト一覧から素早く切り替え。
- **簡易 Git 支援 (Git) (`lisp/git.l`)**:
  - `git-status` (`Leader g s`): プロジェクトの変更状態一覧を `*git status*` に表示し、差分確認 (`d`)・ログ表示 (`l`)・更新 (`g`)・ファイルオープン (`RET`) が可能。
  - `git-diff` (`Leader g d`): プロジェクトまたはファイルの差分を `*git diff*` に表示。
  - `git-log` (`Leader g l`): コミット履歴をグラフィカルに表示。
  - `git-blame` (`Leader g b`): 現在のファイルの行ごとの変更者を一覧表示。
- **トグル式ターミナルドロワー (`lisp/terminal.l`)**:
  - `toggle-terminal-drawer` (`Leader t t`): 画面下部にターミナルバッファ (`*Shell*`) をワンキーでトグル表示・格納。
- **最近開いたファイル (Recentf) (`lisp/recentf.l`)**:
  - `recentf-open` (`C-x C-r` / `Leader f r`): 直近に開いたファイルの一覧を補完候補として表示し、選択して素早くオープン。
- **カーソル位置の記憶・復元 (Save Place) (`lisp/saveplace.l`)**:
  - ファイルを閉じたときのカーソル位置を自動記録し、再度開いた際に前回の編集位置へ自動ジャンプ (`*save-place*`, `*save-place-limit*`)。
- **ファイラ (`lisp/filer.l`)**:
  - `open-filer` (`C-x C-f` でディレクトリを指定時や `C-x d`): 2画面対応の強力な内蔵ファイラ。ファイルのコピー、移動、削除、属性変更、圧縮解凍などをキーボードで高速操作。
- **バッファメニュー (`lisp/buf-menu.l`)**:
  - `list-buffers` (`C-x C-b`) / `buffer-menu`: 開いているバッファの一覧を表示。保存マーク (`s`) や削除マーク (`d`) を付けて一括処理 (`x`)。
- **セッション管理 (`lisp/session.l`)**:
  - `save-session` / `load-session` / `open-session-dialog`: 開いているバッファ、ウィンドウ分割状態、カーソル位置をセッションファイルに保存・復元。
- **擬似フレーム (`lisp/pframe.l`)**:
  - `new-pseudo-frame` (`C-c C-n`), `switch-pseudo-frame` (`C-c C-s`): 単一のウィンドウ内で仮想的な複数の画面レイアウト (フレーム) を切り替えて作業。

---

### ユーティリティ・変換・辞書

- **電卓 (`lisp/calc.l`)**:
  - `M-x calc`: ミニ電卓バッファを起動。四則演算、関数計算、Lisp 式評価が可能。
- **カレンダー (`lisp/calendar.l`)**:
  - `M-x calendar`: 月間カレンダーバッファを表示。前後の月・年の移動、日付選択。
- **英和・和英辞書 (EDICT) (`lisp/edict.l`)**:
  - `lookup-e2j-dictionary-word`: カーソル位置の英単語を英和辞書で検索。
  - `lookup-j2e-dictionary-word`: 日本語単語から和英辞書を検索。
- **スペルチェッカー (`lisp/ispell.l`)**:
  - `ispell-buffer` / `ispell-region`: 外部 ispell / aspell を呼び出してスペルチェックと候補修正。
- **エンコード / デコード (`lisp/encdec.l`)**:
  - `base64-decode-region`, `base64-decode-region-to-file`: Base64 のエンコード・デコード。
  - `uudecode-region`, `quoted-printable-decode-region`: Uudecode / Quoted-Printable 形式のデコード。
- **文字コード・エンコーディング (`lisp/kanji.l`, `lisp/encoding.l`)**:
  - `map-utf-8-region`, `map-sjis-region`, `map-euc-region`: リージョン内の文字コードを相互変換。
  - `insert-unicode-char-table`: Unicode 文字一覧テーブルを挿入。
- **タイムスタンプ (`lisp/timestmp.l`)**:
  - `insert-date-string`: 設定したフォーマットの日時文字列をバッファに挿入。
- **バックアップ設定 (`lisp/backup.l`)**:
  - `*backup-directory*`: バックアップファイル (`*~`) の保存先ディレクトリを一括指定。
  - `*hierarchic-backup-directory*`: ディレクトリ階層を維持してバックアップを隔離保存。
- **ヘルプ・ドキュメント閲覧 (`lisp/help.l`, `lisp/winhelp.l`, `lisp/dexplorer.l`)**:
  - `apropos` (`C-h a`), `describe-key` (`C-h k`), `describe-bindings` (`C-h b`): キー割り当て・関数説明の検索。
  - `show-winhelp` / `show-html-help`: Windows ヘルプファイル (`.hlp`, `.chm`) を表示。
  - `show-dexplorer`: MSDN / Document Explorer を起動してキーワード検索。

---

### アミューズメント & ゲーム

| コマンド (`M-x`) | ファイル | 概要 |
|---|---|---|
| `gomoku` | `lisp/gomoku.l` | 五目並べ (レンジュ)。カーソルキーと `SPC` で着手し、xyzzy 思考ルーチンと対戦 (`gomoku-mode`)。 |
| `life` | `lisp/life.l` | コンウェイのライフゲームシミュレータ (`life-mode`)。 |
| `hanoi` | `lisp/hanoi.l` | ハノイの塔の自動解法アニメーション表示。 |
| `c-curve`<br>`dragon-curve` | `lisp/ccurve.l` | フラクタル図形 (C 曲線 / ドラゴン曲線) をバッファ上にリアルタイム作図。 |

---

## コアシステム・内部ライブラリ

xyzzy 本体の起動や Lisp 処理系の基盤となるモジュール群です。多くは `loadup.l` によりダンプイメージに最初から組み込まれています。

### 1. 起動・環境基盤
- **`loadup.l`**: ダンプイメージ作成時に読み込む全ライブラリのロードスクリプト。
- **`startup.l` / `estartup.l`**: 起動時の初期化、コマンドライン引数処理 (`-q`, `-load` など)、`*post-startup-hook*` の実行。
- **`defs.l` / `ldefs.l`**: 共通変数定義、`*auto-mode-alist*`、各モジュールの autoload 登録。
- **`misc.l`**: `cd`, `etc-path`, `execute-extended-command` (`M-x`) など汎用ユーティリティ。

### 2. Common Lisp サブセット & データ構造
- **`common-lisp.l` / `evalmacs.l`**: `defun`, `defmacro`, `lambda`, `mapcar`, `mapcan` 等のマクロおよび基本関数。
- **`package.l`**: パッケージシステム (`in-package`, `export`, `find-package` 等)。
- **`list.l` / `sequence.l` / `array.l` / `hash.l` / `number.l` / `charname.l`**: 各種データ型の基本操作関数群。
- **`setf.l` / `struct.l` / `typespec.l`**: `setf` 展開定義、`defstruct`、型指定マクロ (`check-type`, `typep` 等)。
- **`condition.l` / `handler.l`**: 条件システム (`define-condition`, `handler-case`, `restart-case` 等)。
- **`cmu_loop.l`**: CMU Common Lisp 由来の強力な `loop` マクロ。
- **`stream.l`**: 入出力ストリーム操作。

### 3. エディタ操作・UI コア
- **`buffer.l` / `window.l` / `files.l`**: バッファ生成・切り替え、ウィンドウ分割・移動、ファイル読み書き。
- **`region.l` / `rectangl.l` / `paragrph.l` / `page.l` / `sexp.l` / `fill.l`**: テキスト選択、矩形編集、段落・S式・ページ単位の編集操作。
- **`minibuf.l` / `history.l` / `complete.l`**: ミニバッファ入力、補完処理、入力履歴管理。
- **`menu.l` / `app-menu.l` / `mouse.l` / `cmdbar.l`**: メニューバー、ポップアップメニュー、マウスイベント処理、ツールバー/コマンドバー制御。
- **`keyboard.l` / `keymap.l` / `winkey.l`**: キーボード入力解釈、キーマップ定義 (`global-set-key`, `define-key`)。
- **`font.l` / `optprop.l` / `loptprop.l`**: フォント設定、共通設定/ローカル設定プロパティシート。
- **`kwd.l` / `re-kwd.l` / `ts.l`**: 構文ハイライト用キーワードファイル解釈、正規表現キーワード、Tree-sitter 基盤。
- **`compile.l`**: バイトコンパイラ (`byte-compile-file`, `byte-recompile-directory`)。
- **`foreign.l` / `ole.l`**: C言語型定義 / FFI 外部関数インターフェース、OLE / COM オートメーション連携。

---

## 実験的・拡張ライブラリ (lisp/wip/)

`lisp/wip/` には、高度な機能や実験的なモジュール、各種サンプルコードが格納されています。

### Outline Tree (アウトラインツリー)
- **配置**: `lisp/wip/outline-tree/` (50以上のファイル群)
- **概要**: 編集中のファイルから見出しや関数・クラス定義を解析し、TreeView ウィンドウに階層型のアウトラインツリーとして一覧表示する強力な拡張。
- **対応フォーマット (ルールファイル群)**:
  - プログラミング言語: C/C++ (`cr-ctags.l`, `cr-global.l`), Lisp (`cr-lisp.l`), Perl (`cr-perl.l`), VB/ASP (`cr-VB-like.l`, `cr-ASP.l`), CSS (`cr-css.l`)
  - ドキュメント・マークアップ: Markdown (`cr-Markdown.l`), LaTeX (`cr-LaTeX.l`), HTML (`cr-html-heading.l`), TeXinfo (`cr-texinfo.l`), RD (`cr-rd.l`), Hiki (`cr-hiki.l`), FreeMind (`cr-FreeMind.l`), RFC (`cr-RFC.l`), eMemoPad (`cr-eMemoPad.l`), 2ch ログ (`cr-2ch.l`), INI (`cr-ini.l`), CSV/TSV (`cr-xsv.l`)
  - 外部ツール連携: ctags (`cr-ctags.l`), GNU GLOBAL (`cr-global.l`), xdoc2txt による PDF/Excel 抽出 (`cr-xdoc2txt-pdf.l`, `cr-xdoc2txt-excel.l`), Grep 結果ツリー (`cr-grep.l`)
- **使用方法**:
  `~/.xyzzy` 等で以下のように読み込みます。
  ```lisp
  (require "outline-tree/outline-tree")
  ```

---

### TreeView (ツリービュー)
- **配置**: `lisp/wip/treeview/`
- **概要**: Win32 コモンコントロールの TreeView を xyzzy Lisp から制御するためのフレームワーク。階層ノードの追加、アイコン設定、インクリメンタルサーチ (`treeview-isearch.l`) などを提供。

---

### その他のサンプル・拡張
- **`lisp/wip/browserex.l`**: Internet Explorer / WebBrowser コントロールをバッファ内に埋め込んでブラウジングする拡張サンプル。
- **`lisp/wip/ftp.l`**: 簡易 FTP クライアントのプロトタイプ。
- **`lisp/wip/color.l`**: Win32 カラー選択ダイアログを呼び出してカラーコードを取得するサンプル (`color-code-dialog-box`)。
- **`lisp/wip/oletest.l`**: OLE オートメーションで Excel や IE を遠隔操作するテストサンプル。
- **`lisp/wip/hellowin.l`, `turtle.l`, `win-window.l`, `winapi.l`**: Win32 API の構造体定義やウィンドウ操作、タートルグラフィックスを行う FFI サンプルコード。
- **`lisp/Gates.l`**: Windows 標準 (メモ帳風) のショートカットキー (`Ctrl+C` でコピー、`Ctrl+V` で貼り付け、`Ctrl+Z` で元に戻す等) に置き換える設定サンプル。

---

## カスタマイズ例 (Tips)

### 1. 拡張子とモードの関連付けを追加する
独自の拡張子を開いたときに特定のモードを自動適用するには、`~/.xyzzy` で `*auto-mode-alist*` に追加します。

```lisp
; 例: .vue や .svelte を html+-mode で開く
(push '("\\.vue$" . html+-mode) *auto-mode-alist*)
(push '("\\.svelte$" . html+-mode) *auto-mode-alist*)

; 例: .json5 を json-mode で開く
(push '("\\.json5$" . json-mode) *auto-mode-alist*)
```

### 2. モードフックで設定・キーバインドを変更する
各モード起動時にインデント幅や固有キーバインドを設定します。

```lisp
; Python モードでインデント幅を 4 にし、タブをスペース展開
(add-hook '*python-mode-hook*
          #'(lambda ()
              (setq-local c-basic-offset 4)
              (setq-local indent-tabs-mode nil)))

; Markdown モードで自動折り返し (auto-fill) を有効化
(add-hook '*markdown-mode-hook*
          #'(lambda ()
              (auto-fill-mode t)))

; HTML+ モードで Emmet 展開を C-Return に割り当て
(add-hook '*html+-mode-hook*
          #'(lambda ()
              (require "emmet")
              (define-key *html+-mode-map* #\C-RET 'emmet-expand-at-point)))
```

### 3. バックアップファイルの保存先を一括隔離する
編集中に生成される `*~` バックアップファイルを専用ディレクトリにまとめます。

```lisp
(require "backup")
(setq *backup-directory* "C:/Users/ユーザー名/.xyzzy.backup")
(setq *hierarchic-backup-directory* t) ; ディレクトリ階層を維持
```
