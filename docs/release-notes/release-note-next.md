xyzzy リリースノート
====================

  * バージョン: (未リリース)
  * リリース日: (未リリース)
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

(次のリリースで何が変わるのかを、1〜2 段落で。)


変更
----

  * README とリポジトリの概要が、この木を上流そのもののように見せていたのを直した。
    バッジとダウンロードのリンクが snmsts/xyzzy を指したままで、GitHub の説明文は
    xyzzy-022 のものが残っていた。私家版であること、どこから分岐した木なのか、
    不具合の報告先がここであって上流ではないことを先頭に書いてある。
  * ドキュメントを利用者向け (docs/user/)・開発者向け (docs/dev/)・リリースノート
    (docs/release-notes/) に分けた。README がビルド手順やバージョン体系の詳細まで
    抱えていて「導入とポインタ」になっていなかったのと、機能一覧・キーバインド・
    設定 (GUIダイアログと ini/.xyzzy.history/~/.xyzzy の3層構造)・Lisp拡張の
    書き方がどこにも無かったのを直した。あわせてリリースの ZIP/インストーラに
    docs/dev/ (設計メモ、上流の古い ChangeLog) やリリースノート本体がそのまま
    入ってしまっていたのもやめ、docs/user/ だけを配布物に入れるように
    CMakeLists.txt の install() を変えた。リリースノート自体も docs/ 直下から
    docs/release-notes/ へ移し、それに合わせて `.githooks/pre-push`、
    `.github/workflows/release.yml`、`tools/release-prep.sh`、`RELEASING.md`、
    `CLAUDE.md` が参照するパスを一括で更新した (ファイル名は変えていないので
    `release-note-<版>.md` という命名はそのまま)。
  * `docs/user/keybindings.md` に Emacs との違いに注意する表を追加し、`C-s`/`C-r`
    の説明を実態 (デフォルトでは isearch ではなく `RET` 確定の非インクリメンタル
    検索) に合わせて直した。`lisp/loadup.l` を確認すると `isearch.l` は起動時の
    ロード対象に入っておらず、ドキュメントが「デフォルトでインクリメンタル
    サーチ」と書いていたのは実際の挙動と食い違っていたため。
  * `docs/user/keybindings.md` に、自明すぎて省いていた基本のカーソル移動・編集
    キー (`C-f`/`C-b`/`C-n`/`C-p`/`C-k`/`C-y` など) と、`M-x` 実行時などに使う
    ミニバッファでのキー (履歴呼び出しの `C-p`/`C-n`/`M-p`/`M-n`、補完の `TAB`、
    中断の `C-g` など) の一覧を追加した。
  * `docs/user/keybindings.md` に画面スクロール系のキー (`C-l`/`C-Down`/`C-Up`/
    `S-C-Down`/`S-C-Up`/`C-x <`/`C-x >`/`ESC C-v`) が抜けていたので追加した。
  * `docs/user/keybindings.md` の `Home`/`End` の説明が誤っていたのを直した。
    `C-a`/`Home`、`C-e`/`End` と同じ行にまとめて書いていたが、`lisp/buffer.l`と
    `lisp/cmds.l` を確認すると `Home` は次のバッファへの切り替え、`End` は undo
    (`S-End` は redo) で、行頭・行末移動ではない。Emacs との違いに注意する表にも
    追記した。
  * `docs/user/keybindings.md` を大幅に拡充した。抜けていたグローバルキー
    (略語展開・レジスタ・キーボードマクロ・ページ (フォームフィード) 移動・
    外部コマンド実行・タグジャンプ・ブックマーク・`C-c` プレフィックス・
    文字コード/EOL 切り替え・擬似フレーム/セッション・シフト選択・`C-x 4`/
    `C-x 6` 系・段落/S式移動など) を `lisp/loadup.l` の全ロード対象から洗い出し
    て追加し、`C-←`/`C-→` が単語移動ではなく行頭/行末移動になっている点も
    Emacs との違いの表に加えた。あわせてファイラ・バッファ一覧・補完リスト・
    query-replace・カレンダー・ターミナルなど、専用キーマップを持つ組み込みの
    サブウィンドウ/ダイアログの中で効くキーと、lisp-mode・c-mode/c++-mode・
    shell-mode・markdown-mode・html+-mode など既定で組み込まれているモードの
    モード固有キーも追記した。
  * Windows 向けデプロイのバイトコンパイルが、`.l` の変更が無くても
    `tools/deploy-windows.sh` を叩くたびに x86_64 で `wine: Unhandled stack
    overflow`、i686 で `xyzzy-batch: メモリ不足です` を吐くようになっていたのを
    直した。原因は `misc/makelc.l` の `reload-files` が `"startup"` モジュールも
    無条件にリロードしていたこと。`lisp/startup.l` は末尾の `(si:*startup)` で
    `ed::startup` 経由の起動処理全体を再実行し、その中で `*post-startup-hook*`
    が走る。ところがバッチ版バイトコンパイル (`misc/bytecompile-batch.l`) は
    まさにこのフックから `makelc` を起動しているため、`reload-files` が
    `startup` を読み直すたびに `makelc` が再突入し、ネストするごとに
    141 本のライブラリ全体をもう一度コンパイルし続ける無限再帰になっていた。
    アーキごとに落ち方が違っていたのはスタックとヒープのどちらが先に
    尽きるかの違いでしかなく、両方とも同じ再帰が原因だった。`reload-files`
    から `startup` を除外し (`*modules*` には provide 済みとして残す)、
    バッチ側でも `*post-startup-hook*` を使い捨てにして二重に塞いだ。
    実害は無かった (`compile-files` は再帰が起きる前に 141 本すべてを
    書き終えている) が、デプロイのたびに数分と一見不穏なクラッシュログを
    生んでいた。
  * 標準添付の Lisp ライブラリ・主要モードをまとめた利用者向けドキュメント
    (`docs/user/lisp-libraries.md`) を追加した。C/C++, C#, Java, JS/TS, Python,
    Perl, HTML+, CSS, XML, JSON, YAML, TOML, Markdown, Makefile, CMake などの言語・
    設定ファイルモードの拡張子や機能、ターミナル・Grep・一括置換・略称展開・TAGS・
    ファイラ・セッション・辞書・電卓・ゲームなどの各種ツール、Common Lisp 互換や
    エディタ操作を支えるコアライブラリ、`lisp/wip/` 内のアウトラインツリーや
    TreeView などの拡張群を網羅して一覧化した。
  * デフォルトインストール状態で現代的なエディタ体験を得られるよう「Sensible Defaults」
    を導入した。
    - バックアップファイル (`*~`) をカレントディレクトリではなく `~/.xyzzy.d/backup/`
      にディレクトリ階層を維持して安全に自動隔離 (`*backup-directory*`,
      `*hierarchic-backup-directory*` を既定で有効化)。
    - 各ファイルのカーソル位置を自動記憶し、再オープン時に前回の編集位置へ復帰する
      `saveplace` モジュール (`lisp/saveplace.l`) を標準装備。
    - 直近に開いたファイルの一覧を管理し、`C-x C-r` でインクリメンタルに開ける
      `recentf` モジュール (`lisp/recentf.l`) を標準装備。
    - `backup`、`saveplace`、`recentf` を標準の起動ダンプ・ロード対象 (`lisp/loadup.l`)
      に組み込み、設定ファイルなしの初期状態でも自動的に動作するようにした。
  * Leader Key 操作体系および Which-key 的ミニバッファガイダンス (`lisp/leader.l`) を標準導入した。
    - `M-m` または `C-c SPC` を押すことで、ミニバッファに利用可能な機能カテゴリ (`f:File`, `b:Buffer`, `p:Project`, `s:Search`, `g:Git`, `t:Toggle`, `w:Window`, `h:Help` 等) が一覧表示され、キーボードだけで迷わず目的のコマンドを実行できるようになった。
    - `leader-define-key` 関数により、ユーザーが独自の Leader キーシーケンスとラベルを簡単に追加可能。
  * プロジェクト管理機能 (`lisp/project.l`) を標準導入した。
    - Git リポジトリやマーカーファイル (`.git`, `CMakeLists.txt`, `package.json`, `Cargo.toml`, `go.mod` 等) からプロジェクトルートを自動検出。
    - `project-find-file` (`Leader p f`): プロジェクト配下の全ファイルをインクリメンタル補完で選択してオープン。
    - `project-grep` (`Leader p g`): プロジェクトルート配下の全ファイルを対象とした一括検索。
    - `project-filer` (`Leader p d`): プロジェクトルートを起点にファイラを起動。
    - `project-switch-project` (`Leader p p`): 過去に訪れたプロジェクト一覧から素早く切り替え。
  * トグル式ターミナル連携および簡易 Git 支援 (`lisp/git.l`) を標準導入した。
    - `toggle-terminal-drawer` (`Leader t t`): 画面下部にターミナル (`*Shell*`) をワンキーでトグル表示・格納。
    - `git-status` (`Leader g s`): プロジェクトの変更状態一覧を `*git status*` に表示し、キー1つで差分確認 (`d`)・ログ表示 (`l`)・更新 (`g`)・ファイルオープン (`RET`) が可能。
    - `git-diff` (`Leader g d`): プロジェクトまたはファイルの差分を `*git diff*` に表示。
    - `git-log` (`Leader g l`): コミット履歴をグラフィカルに表示。
    - `git-blame` (`Leader g b`): 現在のファイルの行ごとの変更者を一覧表示。
  * バッチモード実行時 (`xyzzy-batch.exe`) に GUI イベントループ (`main_loop`) へ突入したり、バッファ保存確認ダイアログでプロセス終了がブロックされたりしていた不具合を修正し、コマンドライン・CI 上でのバッチコンパイルやスクリプト実行が確実に即座に終了するようにした。
  * `misc/run-tests-batch.l` が `unittest/*-tests.l` の読み込みループ全体を1つの
    `handler-case` で囲んでいたため、アルファベット順で早い1ファイルが読み込みに
    失敗すると、それより後ろの全ファイル (`leader-tests.l`, `project-tests.l` を
    含む) が黙って読み込まれずスキップされていた。実際に `unittest/git-tests.l`
    が存在しない `"unittest"` モジュールを `require` していたため、この不具合が
    誘発され、Leader Key・プロジェクト管理のテストが CI 上で一度も実行されない
    まま「オールグリーン」を報告していた。ハンドラをファイル単位に分割し、
    `assert-true`/`assert-equal`/`assert-false` を提供する
    `unittest/test-helpers.l` を追加して `require "unittest"` を修正した。
    あわせて、この経路が塞がっていたために発見されていなかった `lisp/project.l`
    の実バグ (`(namestring (directory-namestring root))` が末尾の `/` を
    落とし、`project-list-files` が相対パスの切り出しに失敗して
    `project-find-file`/`project-grep` がプロジェクト直下ではなくファイル
    システムのルート付近を走査してしまう) も修正した。
  * `toggle-terminal-drawer` (`Leader t t`) が初回起動時にフリーズし、ターミナルが
    一切開かなかった不具合を修正した。原因は `get-buffer-window` に、まだ存在しない
    バッファ名の文字列 (`"*Shell*"`) をそのまま渡すとハングするという `get-buffer-window`
    自体の挙動で、初回トグル時 (`*Shell*` バッファがまだ無い状態) に必ず踏んでいた。
    `get-buffer-create` で存在を保証したバッファオブジェクトを渡すよう修正し、
    `unittest/git-tests.l` に回帰テストを追加した。
  * ミニバッファのファジー絞り込み (`lisp/fuzzy-complete.l`) を追加した。
    `completing-read` には候補の絞り込み方をフックする手段が無いため、
    `isearch.l`/`which-key-guide` と同じ手法 (`read-char` で1文字ずつ読み、
    `minibuffer-prompt` でステータス行を都度書き換える) で独自のインクリメンタル
    絞り込みループを実装した。文字を打った順番どおりに含まれていれば連続で
    なくても候補に残り (`fuzzy-score`/`fuzzy-filter`)、パスの場合はファイル名
    部分を優先してスコアリングする。`project-find-file`・`project-switch-project`
    (`Leader p f` / `Leader p p`) の絞り込みに使用。`C-n`/`C-p`/`TAB` で候補間を
    移動できる。
