xyzzy リリースノート
====================

  * バージョン: 0.4.0
  * リリース日: 2026-08-25
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

0.3.1 以降で最大の機能追加である。Leader Key・プロジェクト管理・ターミナル
連携・簡易 Git・カラーテーマ・ミニバッファのファジー絞り込みを標準導入し、
バックアップ/カーソル位置記憶/最近使ったファイルを設定ファイル無しで動く
「Sensible Defaults」にした。それに伴って踏んだ不具合 (プロジェクトルート
検出、ターミナルのキー入出力、バッチモードの終了) も合わせて直っている。

**直近でユーザー影響が大きいのはマウス操作の修正である。** 8/21 の BMP 外
文字対応以降、win32 版で編集バッファへの左/右/中クリックが一切効かなく
なっていた (カーソル移動も範囲選択も右クリックメニューも出ない)。今回の
リリースで直っている。


ドキュメントの整備
------------------

  * README とリポジトリの概要が、この木を上流そのものであるかのように見せて
    いたのを直した。バッジとダウンロードのリンクが snmsts/xyzzy を指した
    ままで、GitHub の説明文は xyzzy-022 のものが残っていた。私家版で
    あること、どこから分岐した木なのか、不具合の報告先がここであって上流
    ではないことを先頭に書いた。
  * ドキュメントを利用者向け (docs/user/)・開発者向け (docs/dev/)・リリース
    ノート (docs/release-notes/) に分けた。README がビルド手順やバージョン
    体系の詳細まで抱えていて「導入とポインタ」になっていなかったのと、
    機能一覧・キーバインド・設定 (GUI ダイアログと ini/.xyzzy.history/
    ~/.xyzzy の3層構造)・Lisp 拡張の書き方がどこにも無かったのを直した。
    あわせてリリースの ZIP/インストーラに docs/dev/ (設計メモ、上流の古い
    ChangeLog) やリリースノート本体がそのまま入ってしまっていたのもやめ、
    docs/user/ だけを配布物に入れるように CMakeLists.txt の install() を
    変えた。
  * `docs/user/keybindings.md` を大幅に拡充した。Emacs との違いに注意する
    表を追加し、`C-s`/`C-r` の説明を実態 (デフォルトでは isearch ではなく
    `RET` 確定の非インクリメンタル検索。`lisp/loadup.l` に `isearch.l` は
    起動時ロード対象として入っていない) に合わせて直した。`Home`/`End` の
    説明の誤り (`Home` は次バッファへの切り替え、`End` は undo/`S-End` は
    redo であり、行頭・行末移動ではない) も訂正した。自明として省いていた
    基本のカーソル移動・編集キー、ミニバッファ操作、画面スクロール系、
    略語展開・レジスタ・キーボードマクロ・ページ移動・外部コマンド実行・
    タグジャンプ・ブックマーク・`C-c` プレフィックス・文字コード/EOL
    切り替え・擬似フレーム/セッション・シフト選択・`C-x 4`/`C-x 6` 系・
    段落/S式移動、`C-←`/`C-→` が単語移動ではなく行頭/行末移動になっている
    点、ファイラ・バッファ一覧・補完リスト・query-replace・カレンダー・
    ターミナルなど専用キーマップを持つサブウィンドウ/ダイアログのキー、
    lisp-mode・c-mode/c++-mode・shell-mode・markdown-mode・html+-mode
    などのモード固有キーを一通り追記した。
  * 標準添付の Lisp ライブラリ・主要モードをまとめた利用者向けドキュメント
    (`docs/user/lisp-libraries.md`) を追加した。C/C++, C#, Java, JS/TS,
    Python, Perl, HTML+, CSS, XML, JSON, YAML, TOML, Markdown, Makefile,
    CMake などの言語・設定ファイルモード、ターミナル・Grep・一括置換・
    略称展開・TAGS・ファイラ・セッション・辞書・電卓・ゲームなどの各種
    ツール、Common Lisp 互換やエディタ操作を支えるコアライブラリ、
    `lisp/wip/` 内のアウトラインツリーや TreeView などの拡張群を網羅した。


Sensible Defaults
------------------

デフォルトインストール状態で現代的なエディタ体験を得られるようにした。

  * バックアップファイル (`*~`) をカレントディレクトリではなく
    `~/.xyzzy.d/backup/` にディレクトリ階層を維持して自動隔離
    (`*backup-directory*`, `*hierarchic-backup-directory*` を既定で有効化)。
  * 各ファイルのカーソル位置を自動記憶し、再オープン時に前回の編集位置へ
    復帰する `saveplace` モジュール (`lisp/saveplace.l`) を標準装備。
  * 直近に開いたファイルの一覧を管理し、`C-x C-r` でインクリメンタルに
    開ける `recentf` モジュール (`lisp/recentf.l`) を標準装備。
  * `backup`、`saveplace`、`recentf` を標準の起動ダンプ・ロード対象
    (`lisp/loadup.l`) に組み込み、設定ファイル無しの初期状態でも自動的に
    動作するようにした。


Leader Key とプロジェクト管理
------------------------------

  * Leader Key 操作体系および Which-key 的ミニバッファガイダンス
    (`lisp/leader.l`) を標準導入した。`M-m` または `C-c SPC` でミニバッファに
    利用可能な機能カテゴリ (`f:File`, `b:Buffer`, `p:Project`, `s:Search`,
    `g:Git`, `t:Toggle`, `w:Window`, `h:Help` 等) が一覧表示され、キーボード
    だけで目的のコマンドを実行できる。`leader-define-key` でユーザー独自の
    シーケンスとラベルを追加できる。
  * プロジェクト管理機能 (`lisp/project.l`) を標準導入した。Git リポジトリや
    マーカーファイル (`.git`, `CMakeLists.txt`, `package.json`, `Cargo.toml`,
    `go.mod` 等) からプロジェクトルートを自動検出し、
    `project-find-file` (`Leader p f`)・`project-grep` (`Leader p g`)・
    `project-filer` (`Leader p d`)・`project-switch-project` (`Leader p p`)
    を提供する。
  * トグル式ターミナル連携および簡易 Git 支援 (`lisp/git.l`) を標準導入した。
    `toggle-terminal-drawer` (`Leader t t`) は画面下部にターミナル
    (`*Shell*`) をワンキーでトグル表示・格納する。`git-status`
    (`Leader g s`) はプロジェクトの変更状態一覧を `*git status*` に表示し、
    差分確認 (`d`)・ログ表示 (`l`)・更新 (`g`)・ファイルオープン (`RET`) が
    キー1つで行える。`git-diff` (`Leader g d`)、`git-log` (`Leader g l`)、
    `git-blame` (`Leader g b`) も追加した。
  * ミニバッファのファジー絞り込み (`lisp/fuzzy-complete.l`) を追加した。
    `completing-read` には候補の絞り込み方をフックする手段が無いため、
    `isearch.l`/`which-key-guide` と同じ手法 (`read-char` で1文字ずつ読み、
    `minibuffer-prompt` でステータス行を都度書き換える) で独自の
    インクリメンタル絞り込みループを実装した。文字を打った順番どおりに
    含まれていれば連続でなくても候補に残り (`fuzzy-score`/`fuzzy-filter`)、
    パスの場合はファイル名部分を優先してスコアリングする。
    `project-find-file`・`project-switch-project` の絞り込みに使う。
    `C-n`/`C-p`/`TAB` で候補間を移動できる。
  * `project-find-file`/`project-grep` が、プロジェクト直下の `lisp/`・
    `docs/`・`src/` などドット無しの名前のディレクトリへ実質降りて行けず、
    ごく一部のファイルしか見つけられていなかった不具合を修正した。原因は
    `project-collect-files-recursive` が `directory` の `:wild "*.*"` で
    サブディレクトリを列挙していたこと。「ドットを含まない名前にもマッチ
    するか」が環境によって違い (Wine 上ではマッチせず走査がほぼ空振りする
    一方、実 Windows の `FindFirstFile` の古い互換仕様ではマッチしてしまう)、
    挙動が toolchain 依存で信頼できなかった。`:wild` をやめ、`directory`
    自身の `:recursive t` + `:test` に一括で任せる形に書き換えた。
  * `project-current-root`/`project-find-file` が、実際にはプロジェクト
    ルート配下にいるにもかかわらず正しく検出できず、1階層上や無関係な
    親ディレクトリを誤って返すことがあった不具合を修正した。原因は
    `project-find-root-directory` が `(truename start-dir)` の結果を
    `directory-namestring` にそのまま通していたこと。`truename` は末尾の
    `/` を落とすことがあり、その結果を渡すとディレクトリであっても最後の
    ディレクトリ名をファイル名と誤認し、1階層上から探索を始めてしまう。
    `file-directory-p` で判定し、ディレクトリなら末尾 `/` を補うだけに
    するよう修正した。**この不具合は MSVC (x86/x64/ARM64 のいずれも) の
    CI で `unittest/project-tests.l` 実行中にハング/メモリ不足/タイムアウト
    する形で発現しており、修正により解消した** (Wine 上では単に間違った —
    が偶然辻褄が合うことが多い — 結果を返すだけで済んでいたため、これまで
    発覚していなかった)。回帰テスト
    `test-project-root-detection-exact-directory` を追加した。
  * `toggle-terminal-drawer` (`Leader t t`) が初回起動時にフリーズし、
    ターミナルが一切開かなかった不具合を修正した。原因は
    `get-buffer-window` に、まだ存在しないバッファ名の文字列
    (`"*Shell*"`) をそのまま渡すとハングするという挙動で、初回トグル時
    (`*Shell*` バッファがまだ無い状態) に必ず踏んでいた。`get-buffer-create`
    で存在を保証したバッファオブジェクトを渡すよう修正した。
  * `*backup-directory*` の既定値が末尾の `/` を欠いた状態で設定されていた
    不具合を修正した。`merge-pathnames` は、第1引数がそれ自体 `/` を含む
    複数階層のパスで末尾も `/` の場合、末尾の `/` を落とすことがある。
    `lisp/backup.l` 自身のドキュメント例は末尾 `/` 付きの値を前提としており、
    単純な文字列連結に置き換えて確実に `/` を付けるようにした。


カラーテーマ
------------

  * カラーテーマ機能 (`lisp/color-theme.l`) を追加した。表示色の設定は
    色ごとの個別変更 (ツール→ローカル設定→表示色) しか無く、Solarized や
    Molokai のような公開配色を一括で当てはめる手段が無かった。
    `set-buffer-colors` (`USER_DEFINABLE_COLORS`, 18色) が受け取るベクタと
    してテーマを丸ごと持たせ、開いている全バッファと以後の新規バッファ
    (`*Shell*` を含む) へ自動適用する。表示(V) メニューに「カラーテーマ
    (&H)」を追加し、Solarized・Molokai・Gruvbox・Nord・Dracula・
    One Dark/Light・Tomorrow Night・Catppuccin (Mocha/Latte/Frappé/
    Macchiato)・Tokyo Night・Everforest・GitHub Dark・Ayu (Dark/Light/
    Mirage)・Rosé Pine (Main/Moon/Dawn)・Night Owl・Oceanic Next・
    Nightfox・Kanagawa・Cobalt2・Zenburn・VS Code Dark+ (計30種、
    明暗ペアがあるものは両方収録) を同梱した。選択したテーマは履歴
    (`*current-color-theme*`) として次回起動時にも復元される。
    `M-x set-color-theme`/`clear-color-theme` でも切り替え可能。
    `M-x select-color-theme` (表示(V)→カラーテーマ→「プレビューして
    選択」) は専用バッファ `*Color Theme*` に全30種を1行1件で並べる形に
    した。ミニバッファの絞り込みだと候補が途中で切れて一覧性が無いための
    変更で、カーソル行が変わるたびに `*post-command-hook*` でその行の
    テーマを全バッファへ即座にプレビュー適用し、`RET` で確定、`q`/`C-g`
    でプレビュー開始前の色に戻す。


ターミナルの入出力まわりの修正
------------------------------

  * ターミナルバッファで、エディタ側に取られたキーをターミナルの中の
    アプリへそのまま渡す `terminal-send-next-key` (`C-c C-q`) を足した。
    ターミナルのキーは `*terminal-map*` にあるものだけがエディタへ行き、
    残りは全部 pty へ流れる仕組みなので、素通しの経路が必要なのは `C-v`
    (貼り付け) や `S-PageUp` (スクロールバック) のようにこちらで意味を
    持たせたキーだけで、vim の `C-v` や less の `S-PageUp` がそれまで
    押せなかった。
  * `(read-char *keyboard*)` がターミナルバッファで返ってこなくなって
    いたのを直した。キーの pty への横流しは入力キューを読む `fetch` の
    中で起きていて、Lisp が明示的にキーを待っているときも横流しが優先
    されるため、キーは `read-char` に届かないまま pty へ消えていた。
    `y-or-n-p` や `query-replace` の応答待ちがターミナルバッファでは
    何を押しても進まなかったのがこれ。Lisp が `*keyboard*` を読んでいる
    間だけ横流しを止める。
  * 機能キーを `(read-char *keyboard*)` で取ると別のキーになっていたのを
    直した。`decode_keys` が積む lChar は kind field (bit 21-23) を持つ
    新しい表現 (`LCKEY_UP` = `0x200005`) だが、char object にするときに
    下位 16bit を取っていたので kind が落ち、`#\Up` が `#\C-e` になって
    いた。Lisp の char は今も旧表現 (`#\Up` = `CCF_UP` = `0xff05`) なので、
    `ccf_from_lc` で戻す。`read-key-sequence` や `describe-key` が矢印キー
    を取り違えていたのも同じ原因で、あわせて直っている。
  * `si:terminal-send-key` に char を渡すと機能キーとして扱われなかった
    のを直した。`#\Up` (`0xff05`) の `LCHAR_KIND` は CHAR に見えるため、
    `ESC[A` ではなく U+FF05 (全角パーセント) の UTF-8 が pty へ流れて
    いた。char で渡されたものは `lc_from_ccf` で昇格し、BMP 外の
    code point だけは `Char` (16bit) に落とすと `0xF600` = `CCF_META` と
    ぶつかるのでそのまま渡す。この経路は process が無いと呼べずテストが
    書けなかったので、`si:*terminal-key-for-test` も char を受けるように
    して固定した。
  * ターミナルバッファで `S-PageUp`/`S-PageDown` のスクロールバックと
    `S-Insert` の貼り付けが効いていなかったのを直した。キーを pty へ
    流すかエディタへ渡すかの判定で `*terminal-map*` を引くとき、lChar を
    下位 16bit に落としてから渡していた。kind と modifier はそこより
    上のビットにあるので、`#\S-PageUp` (`0x01200000`) は `0`、
    `#\S-Insert` は `0x0C` として引かれ、どちらも map に無い別のキー
    扱いで pty へ流れていた。`C-v` の貼り付けだけが動いていたのは、
    `LCKIND_CHAR` の制御文字が下位 16bit に収まっていて偶然一致していた
    ため。`parse_keymap` は内部で新旧どちらの encoding も正規化するので、
    lChar をそのまま渡す。


マウス・起動・終了まわりの修正
------------------------------

  * win32 版で、普通の編集バッファに対する左/右/中クリックが一切効かなく
    なっていた (カーソル移動もしない、範囲選択もできない、右クリック
    メニューも出ない) 不具合を修正した。ホイールと ConPTY ターミナルへの
    マウス転送は無事だったので、原因の特定に手間取った。BMP 外文字対応
    (`LCHAR_MOUSE` を payload 領域と衝突する `0x10000` から kind field
    側の値 `LCKIND_MOUSE` へ移した変更) 以降、`mouse.cc` が組み立てる
    「`CCF_LBTNDOWN` 等 (旧 Char encoding) に `LCHAR_MOUSE` を素の `|` で
    重ねた値」は、kind field が CHAR でも FNKEY でもない中間形態に
    なっていた。キーマップ検索の `normalize_for_keymap`/
    `full_keymap_index` (`keymap.cc`) はこの中間形態を知らず常にバインディング
    無しを返すため、`*global-keymap*` の `#\LBtnDown` → `mouse-left-press`
    等が一切引けなくなっていた。旧 Char 部分 (payload に無傷で残っている)
    を取り出して通常の `lc_from_ccf` 変換に通す `lc_from_raw_mouse` を
    追加し、キーマップ検索とプレフィックスキー入力中のマウス移動判定
    (`char_mouse_move_p`) の両方に適用した。
  * 存在しないファイルをコマンドラインから指定して起動すると
    (`xyzzy.exe unexists_file.txt` など)、起動直後に無関係な「指定された
    ファイルが見つかりません」ダイアログが出るだけでなく、その後 xyzzy を
    終了しようとしたときにも同じダイアログが再び現れ、未編集のバッファ
    であっても保存確認をすっ飛ばして終了処理自体がそのまま中断されて
    しまう不具合を修正した。原因は `lisp/saveplace.l`/`lisp/recentf.l` の
    `*find-file-hooks*` (ファイルを開いた後) と `*before-delete-buffer-hook*`
    (バッファを閉じる前) 用フックが、対象ファイルの存在確認をせずに
    `truename` を無条件で呼んでいたこと。ファイルが存在しないと
    `truename` は Win32 の raw error (`ERROR_FILE_NOT_FOUND`) をそのまま
    Lisp condition として投げ、それが `call_hooks` (`src/core/Buffer.cc`)
    の中で捕捉されて「ファイルが見つかりません」ダイアログとして表示
    される一方、フック自体は失敗したことになるので、開くときは以後の
    `*find-file-hooks*` 処理が、終了しようとしたときは
    `Buffer::query_kill_xyzzy` の以後の処理 (変更されたバッファがあるかの
    確認と保存確認ダイアログ) がまるごとスキップされていた。両フックとも
    対象ファイルが実在するときだけ `truename` を呼ぶよう修正した。
  * 上記とあわせて、独自実装のメッセージボックス (`XMessageBox`,
    `src/frontend/win32/msgbox.cc`) が標準の `MessageBox` と違って
    オーナーウィンドウを無効化していなかったのも直した。ダイアログ表示中
    もメインウィンドウが操作可能なままだと、そこへの `WM_CLOSE` が
    ダイアログ自身のモーダルメッセージループの内側から `Buffer::kill_xyzzy`
    を再入的に呼び出しうる (Lisp 評価系がエラーの unwind 途中で不安定な
    状態のまま突入することになる)。`MessageBox` と同じく、表示中は
    オーナーを `EnableWindow` で無効化し、閉じる際に戻すようにした。


ビルドとテスト基盤
------------------

  * バッチモード実行時 (`xyzzy-batch.exe`) に GUI イベントループ
    (`main_loop`) へ突入したり、バッファ保存確認ダイアログでプロセス
    終了がブロックされたりしていた不具合を修正し、コマンドライン・CI 上
    でのバッチコンパイルやスクリプト実行が確実に即座に終了するように
    した。
  * `misc/run-tests-batch.l` が `unittest/*-tests.l` の読み込みループ
    全体を1つの `handler-case` で囲んでいたため、アルファベット順で早い
    1ファイルが読み込みに失敗すると、それより後ろの全ファイル
    (`leader-tests.l`, `project-tests.l` を含む) が黙って読み込まれず
    スキップされていた。実際に `unittest/git-tests.l` が存在しない
    `"unittest"` モジュールを `require` していたため、この不具合が
    誘発され、Leader Key・プロジェクト管理のテストが CI 上で一度も
    実行されないまま「オールグリーン」を報告していた。ハンドラをファイル
    単位に分割し、`assert-true`/`assert-equal`/`assert-false` を提供する
    `unittest/test-helpers.l` を追加して `require "unittest"` を修正した。
    この経路が塞がっていたために発見されていなかった `lisp/project.l` の
    実バグ (`project-list-files` が相対パスの切り出しに失敗し、
    `project-find-file`/`project-grep` がプロジェクト直下ではなくファイル
    システムのルート付近を走査してしまう) も、これで初めて見つかって
    修正された。
  * 32bit (x86) ビルドの `xyzzy`/`xyzzy-batch`/`xyzzy-cli` に MSVC の
    `/LARGEADDRESSAWARE` リンカオプションを追加した。link.exe はこれを
    既定で付けない (mingw/lld は既定で付ける) ため、WOW64 上で使える
    アドレス空間が既定では実質 2GB に制限されている。4GB まで使えるように
    しておく (64bit ビルドでは既定で有効なので無害)。


既知の問題
----------

0.2.6.8 のリリースノートに書いたものから変わっていない。

  * 32bit の llvm-mingw ビルドでは、FFI の呼び出しでハードウェア例外が
    起きたとき Lisp のコンディションにならずプロセスが落ちる。LLVM が
    32bit x86 の SEH を扱えないためで、MSVC ビルドには影響しない。
  * ARM64 のバイナリを実際に動かす確認は MSVC のジョブ (windows-11-arm)
    だけで行っている。x86 の Wine では ARM64 の実行ファイルを起動できない。
