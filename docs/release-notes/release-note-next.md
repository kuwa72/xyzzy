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
  * `project-find-file`/`project-grep` が、プロジェクト直下の `lisp/`・`docs/`・
    `src/` などドット無しの名前のディレクトリへ実質降りて行けず、ごく一部の
    ファイルしか見つけられていなかった不具合を修正した。原因は
    `project-collect-files-recursive` が `directory` の `:wild "*.*"` で
    サブディレクトリを列挙していたこと。「ドットを含まない名前にもマッチ
    するか」が環境によって違い (Wine 上ではマッチせず走査がほぼ空振りする
    一方、実 Windows の `FindFirstFile` の古い互換仕様ではマッチしてしまう)、
    挙動が toolchain 依存で信頼できなかった。`:wild` をやめ、`directory`
    自身の `:recursive t` + `:test` (ディレクトリに対して nil を返すとその
    配下ごと無視される) に一括で任せる形に書き換えた。
  * `project-current-root`/`project-find-file` が、実際にはプロジェクト
    ルート配下にいるにもかかわらず正しく検出できず、1階層上や無関係な
    親ディレクトリを誤って返すことがあった不具合を修正した。原因は
    `project-find-root-directory` が `(truename start-dir)` の結果を
    `directory-namestring` にそのまま通していたこと。`truename` は末尾の
    `/` を落とすことがあり (実測済み)、その結果を渡すとディレクトリで
    あっても最後のディレクトリ名をファイル名と誤認し、1階層上から探索を
    始めてしまう。`file-directory-p` で判定し、ディレクトリなら末尾 `/`
    を補うだけにするよう修正した。**この不具合は MSVC (x86/x64/ARM64 の
    いずれも) の CI で `unittest/project-tests.l` 実行中にハング/メモリ
    不足/タイムアウトする形で発現しており、修正により解消した** (Wine 上
    では単に間違った — が偶然辻褄が合うことが多い — 結果を返すだけで
    済んでいたため、これまで発覚していなかった)。回帰テスト
    `test-project-root-detection-exact-directory` を追加した。
  * `*backup-directory*` の既定値が末尾の `/` を欠いた状態で設定されていた
    不具合を修正した。`merge-pathnames` は、第1引数がそれ自体 `/` を含む
    複数階層のパスで末尾も `/` の場合、末尾の `/` を落とすことがある (実測
    済み)。`lisp/backup.l` 自身のドキュメント例は末尾 `/` 付きの値を前提と
    しており、単純な文字列連結に置き換えて確実に `/` を付けるようにした。
    `unittest/defaults-tests.l` にも回帰テストを追加した。
  * 32bit (x86) ビルドの `xyzzy`/`xyzzy-batch`/`xyzzy-cli` に MSVC の
    `/LARGEADDRESSAWARE` リンカオプションを追加した。link.exe はこれを
    既定で付けない (mingw/lld は既定で付ける) ため、WOW64 上で使える
    アドレス空間が既定では実質 2GB に制限されている。4GB まで使えるように
    しておく (64bit ビルドでは既定で有効なので無害)。
  * ターミナルバッファで、エディタ側に取られたキーをターミナルの中のアプリへ
    そのまま渡す `terminal-send-next-key` (`C-c C-q`) を足した。ターミナルの
    キーは `*terminal-map*` にあるものだけがエディタへ行き、残りは全部 pty へ
    流れる仕組みなので、素通しの経路が必要なのは `C-v` (貼り付け) や
    `S-PageUp` (スクロールバック) のようにこちらで意味を持たせたキーだけで、
    vim の `C-v` や less の `S-PageUp` がそれまで押せなかった。
  * `(read-char *keyboard*)` がターミナルバッファで返ってこなくなっていたのを
    直した。キーの pty への横流しは入力キューを読む `fetch` の中で起きていて、
    Lisp が明示的にキーを待っているときも横流しが優先されるため、キーは
    `read-char` に届かないまま pty へ消えていた。`y-or-n-p` や `query-replace`
    の応答待ちがターミナルバッファでは何を押しても進まなかったのがこれ。
    Lisp が `*keyboard*` を読んでいる間だけ横流しを止める。
  * 機能キーを `(read-char *keyboard*)` で取ると別のキーになっていたのを直した。
    `decode_keys` が積む lChar は kind field (bit 21-23) を持つ新しい表現
    (`LCKEY_UP` = `0x200005`) だが、char object にするときに下位 16bit を
    取っていたので kind が落ち、`#\Up` が `#\C-e` になっていた。Lisp の char は
    今も旧表現 (`#\Up` = `CCF_UP` = `0xff05`) なので、`ccf_from_lc` で戻す。
    `read-key-sequence` や `describe-key` が矢印キーを取り違えていたのも同じ
    原因で、あわせて直っている。
  * `si:terminal-send-key` に char を渡すと機能キーとして扱われなかったのを
    直した。`#\Up` (`0xff05`) の `LCHAR_KIND` は CHAR に見えるため、`ESC[A` では
    なく U+FF05 (全角パーセント) の UTF-8 が pty へ流れていた。char で渡された
    ものは `lc_from_ccf` で昇格し、BMP 外の code point だけは `Char` (16bit) に
    落とすと `0xF600` = `CCF_META` とぶつかるのでそのまま渡す。この経路は
    process が無いと呼べずテストが書けなかったので、`si:*terminal-key-for-test`
    も char を受けるようにして `unittest/terminal-tests.l` に固定した。
  * カラーテーマ機能 (`lisp/color-theme.l`) を追加した。表示色の設定は
    色ごとの個別変更 (ツール→ローカル設定→表示色) しか無く、Solarized や
    Molokai のような公開配色を一括で当てはめる手段が無かった。
    `set-buffer-colors` (`USER_DEFINABLE_COLORS`, 文字色・背景色・
    キーワード1〜3・文字列・コメント・タグ・モード行など18色) が受け取る
    ベクタとしてテーマを丸ごと持たせ、開いている全バッファと以後の新規
    バッファ (`*Shell*` を含む) へ自動適用する。表示(V) メニューに
    「カラーテーマ(&H)」を追加し、Solarized・Molokai・Gruvbox・Nord・
    Dracula・One Dark/Light・Tomorrow Night・Catppuccin (Mocha/Latte/
    Frappé/Macchiato)・Tokyo Night・Everforest・GitHub Dark・Ayu (Dark/
    Light/Mirage)・Rosé Pine (Main/Moon/Dawn)・Night Owl・Oceanic Next・
    Nightfox・Kanagawa・Cobalt2・Zenburn・VS Code Dark+ (いずれも MIT/BSD
    ライセンスで配色値が公開されているもの、計30種、明暗ペアがあるものは
    両方収録) を同梱した。選択したテーマは履歴 (`*current-color-theme*`)
    として次回起動時にも復元される。`M-x set-color-theme`/`clear-color-theme`
    でも切り替え可能。色の値は Windows の `COLORREF` が Web でよく見る
    `#RRGGBB` と逆順 (`#BBGGRR`) であることに注意し、配色表の値をそのまま
    書けるよう変換関数を1つ挟んである。`M-x select-color-theme` (表示(V)→
    カラーテーマ→「プレビューして選択」) は専用バッファ `*Color Theme*` に
    全30種を1行1件で並べる形にした。ミニバッファの絞り込みだと候補が
    途中で切れて一覧性が無いための変更で、通常のカーソル移動・検索が
    そのまま使える。カーソル行が変わるたびに `*post-command-hook*`
    (`ts.l` のシンタックスハイライト再計算と同じ仕組み) でその行のテーマを
    全バッファへ即座にプレビュー適用し、`RET` で確定、`q`/`C-g` でプレビュー
    開始前の色に戻す。戻す際はテーマ名の再適用ではなくプレビュー直前に
    控えた各バッファの生の色を復元するので、ディレクトリ単位の個別設定
    (ローカル設定→表示色) が乗ったバッファもプレビューキャンセルで正しく
    元に戻る。
  * ターミナルバッファで `S-PageUp`/`S-PageDown` のスクロールバックと
    `S-Insert` の貼り付けが効いていなかったのを直した。キーを pty へ流すか
    エディタへ渡すかの判定で `*terminal-map*` を引くとき、lChar を下位 16bit に
    落としてから渡していた。kind と modifier はそこより上のビットにあるので、
    `#\S-PageUp` (`0x01200000`) は `0`、`#\S-Insert` は `0x0C` として引かれ、
    どちらも map に無い別のキー扱いで pty へ流れていた。`C-v` の貼り付けだけが
    動いていたのは、`LCKIND_CHAR` の制御文字が下位 16bit に収まっていて
    偶然一致していたため。`parse_keymap` は内部で新旧どちらの encoding も
    正規化するので、lChar をそのまま渡す。
  * 存在しないファイルをコマンドラインから指定して起動すると
    (`xyzzy.exe unexists_file.txt` など)、起動直後に無関係な
    「指定されたファイルが見つかりません」ダイアログが出るだけでなく、
    その後 xyzzy を終了しようとしたときにも同じダイアログが再び現れ、
    未編集のバッファであっても保存確認をすっ飛ばして終了処理自体が
    そのまま中断されてしまう不具合を修正した。原因は
    `lisp/saveplace.l`/`lisp/recentf.l` の `*find-file-hooks*`
    (ファイルを開いた後) と `*before-delete-buffer-hook*`
    (バッファを閉じる前) 用フックが、対象ファイルの存在確認をせずに
    `truename` を無条件で呼んでいたこと。ファイルが存在しないと
    `truename` は Win32 の raw error (`ERROR_FILE_NOT_FOUND`) をそのまま
    Lisp condition として投げ、それが `call_hooks` (`src/core/Buffer.cc`)
    の中で捕捉されて「ファイルが見つかりません」ダイアログとして表示される一方、
    フック自体は失敗したことになるので、開くときは以後の `*find-file-hooks*`
    処理が、終了しようとしたときは `Buffer::query_kill_xyzzy` の以後の処理
    (変更されたバッファがあるかどうかの確認と保存確認ダイアログ) が
    まるごとスキップされていた。両フックとも対象ファイルが実在するときだけ
    `truename` を呼ぶよう修正し、回帰テスト
    (`test-sensible-defaults-saveplace-nonexistent-file`) を追加した。
  * 上記とあわせて、独自実装のメッセージボックス (`XMessageBox`,
    `src/frontend/win32/msgbox.cc`) が標準の `MessageBox` と違って
    オーナーウィンドウを無効化していなかったのも直した。ダイアログ表示中も
    メインウィンドウが操作可能なままだと、そこへの `WM_CLOSE` がダイアログ
    自身のモーダルメッセージループの内側から `Buffer::kill_xyzzy` を
    再入的に呼び出しうる (Lisp 評価系がエラーの unwind 途中で不安定な
    状態のまま突入することになる)。`MessageBox` と同じく、表示中は
    オーナーを `EnableWindow` で無効化し、閉じる際に戻すようにした。
