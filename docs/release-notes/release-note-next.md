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

  * `open-filer` に `&optional path` を追加し、指定したディレクトリを
    最初に表示できるようにした (issue #426)。0 引数だったために
    `project-filer` / `project-open-terminal` のフォールバック /
    `open-memo-directory` が「引数が多すぎます」で失敗していたのを
    修正した。
  * pseudo-frame をプロジェクトに紐付けられるようにした (issue #424)。
    `project-switch-project` は従来「選んだプロジェクトのファイルを
    1 つ開く」だけだったが、プロジェクトに紐付いた pseudo-frame が
    あればそれを選択し、無ければプロジェクト名で新規作成して紐付ける
    ようになった。frame 切り替えがそのままプロジェクト切り替えになる。
    紐付いた frame では `project-current-root` がバッファ由来より
    frame のルートを優先して返すので、`project-find-file` /
    `project-grep` 等のコマンドはそのプロジェクトを対象に動く
    (バッファの隔離はしない。frame は「プロジェクトの既定 root を
    持つ workspace」)。紐付け API は `project-bind-frame` (leader キー
    `p b`) / `project-unbind-frame` / `project-frame-root` /
    `project-switch-to-project`。紐付けは (frame 名 . root) として
    `*project-frame-history*` に永続化され、
    `project-restore-project-frames` で frame を再生成できる
    (自動復元したければ siteinit で呼ぶ)。
  * ファイルツリーのサイドペインを追加した (issue #420)。
    `M-x file-tree` でフレーム左端にプロジェクトルート
    (`project-current-root`、無ければ起動元バッファの
    `default-directory`) を根とするツリーが開く。TAB / RET / 左クリックで
    ディレクトリを展開・折りたたみ、ファイルは RET で他ウィンドウに開く。
    `g` で再読み込み、`-` でルートを親へ、`H` でドットファイル表示の
    切り替え、`q` でペインを閉じる。実装は `lisp/pane.l`
    (左端の細いウィンドウを確保する共通部品) と `lisp/file-tree.l`
    (ツリー本体) の 2 つで、XPI/TreeView.dll を使わない純 Lisp 実装なので
    ncurses / POSIX 版でも動く。xyzzy には Emacs の dedicated window
    相当がないため、`C-x 1` (`delete-other-windows`) でペインは畳まれる
    (再度 `M-x file-tree` で開き直せる)。
  * ファイルツリーペインにフォーカスがあるとき、エディタ側の
    ウィンドウをクリックしてもフォーカスが移らない問題を修正
    (issue #422)。`#\\LBtnDown` はクリック先ではなくカレント
    バッファのキーマップで解決されるため、ツリー外のクリックは
    `mouse-left-press` に委譲するようにした。
  * `M-x build` / `wsl-compile` の既定値がプロジェクトルートの
    `<project>/.xyzzy.d/build.l` を読むようになった (issue #418)。
    `(setq-local *compile-command* "...")` 等の安全な代入だけを
    読み、グローバルな `*compile-command*` > "make" の順で解決する。
    eval はしないため clone したプロジェクトを開くだけで任意
    コードが走ることはない。読める変数は
    `*project-build-allowed-variables*` でホワイトリスト制。
  * エラー行解析 (`next-error` 系) が python traceback
    (`  File "x.py", line N`)、rustc (`  --> file.rs:line:col`)、
    tsc (`file.ts(line,col):`) に対応していなかった問題を修正
    (issue #414)。tsc については従来の `file(line)` 正規表現を
    `[,)]` までに広げ、python/rustc 用の形式を
    `*error-regexp-list*` に追加した。gcc/clang と go
    (`file:line:col:`) は従来どおり。回帰テストを
    `unittest/errors-tests.l` にツールチェーン別の回帰テストを追加。
    Lisp/Scheme 系では emacs lisp バイトコンパイル
    (`foo.el:l:c:`)、racket (`foo.rkt:l:c:`)、chicken
    (`prog.scm:N` in Call history) は従来形式に乗ることを確認し、
    clojure の `(foo.clj:l:c)` 括弧形式と chez の
    `at line N, char C of file.ss` 語尾形式は正規表現を追加した。
    SBCL は `; file: x' と `Line: N, Column: C' が別行のため
    1 行正規表現では拾えず、未対応のまま (要複数行解析)。
  * `next-error` (`C-x \`` / F11) が「最初のエラー」にジャンプしない
    問題を修正 (issue #410)。`goto-error` がエントリを visit する前に
    `*rerror-list*` へ移していたため、構築済みリストでは先頭が常に
    スキップされ、エラーが 1 件だけなら「これ以上エラーはありません」
    と言われてどこにも飛べなかった。加えて `grep` のように
    `build-error-list` を呼ばない経路ではリスト自体が構築されず最初の
    `C-x \`` が必ず失敗していた。表示済みのエントリだけを履歴へ移す
    ようにし、リストが空なら `first-error` がその場で構築するようにした。
    あわせて `compile-run` が `*compilation*` バッファの
    `default-directory` を設定するようにした (旧来は `-*-` ヘッダ行を
    書くだけでバッファには反映されず、`file:line:` の相対パス解決が
    プロセスの cwd 依存だった)。この修正で、末尾超過時に巻き戻って
    「バカチン」と言われるのは本当に巻き戻したときだけになった。
  * Rust ソース編集用の `rust-mode` を追加 (issue #404)。`.rs` が
    `*auto-mode-alist*` に未登録で `fundamental-mode` で開かれて
    いた。`javascript-mode`/`toml-mode` と同型で、`//`・`/* */`
    コメントと `"` 文字列をシンタクステーブルで扱い、ライフタイム
    (`'a`) と文字リテラル (`'x'`) を混同しないよう `'` は文字列
    扱いせず regexp キーワード側で「閉じクォートがあるものだけ」に
    色づけする。インデントは cc-mode 系 (4 空白)。
  * `wsl-find-file` を WSL プロジェクト外でも使えるようにした
    (issue #406)。これまでは `default-directory` が WSL プロジェクト
    (`\\wsl.localhost\...`) でないと、何も聞かずに Windows 側の
    `find-file` に落ち、GUI ファイラが xyzzy の起動ディレクトリを
    開くだけで WSL 内のフォルダを選ぶ経路がなかった。プロジェクト外
    では `wsl-open-directory` と同じくディストロと WSL 内の
    ディレクトリを補完入力させ、選んだフォルダを
    `*wsl-project-list*` に登録してから `project-find-file` で配下の
    ファイルを補完選択する。あわせて、選んだディレクトリを UNC 形に
    正規化する `wsl-directory-to-unc` を公開関数にした。
  * WSL 上でのコマンド実行 (`wsl-compile` / `wsl-git` /
    `wsl-list-distributions` / `git-status` 等の WSL ディスパッチ) の
    出力が実機 Windows で正しくバッファに取り込まれず、wsl.exe の
    UTF-16LE 出力が文字化けしていた問題を修正 (issue #402)。
    `call-process` の `:output` はファイル名しか受け付けず、バッファを
    渡すと子プロセスが xyzzy の標準出力を継承して出力が失われていた
    ので、一時ファイル経由で取り込む `wsl-call-process` に置き換えた。
    あわせて `WSL_UTF8=1` を環境変数に足して wsl.exe の出力を UTF-8 に
    切り替え、非対応の古い WSL では UTF-16LE を検出してデコードする。
    また `wsl-translate-log-paths` がヘッダ行を含むバッファ全体を翻訳
    していたため `default-directory` や `Command:` の表示が実コマンドと
    乖離していた問題を、翻訳対象をプロセス出力のみに限定することで
    修正し、`/` のマッチにトークン境界のチェックを加えてログ中の
    `C:/x` や `src/foo.c` が壊れないようにした。
  * Lisp の未定義関数呼び出しをテスト前に検出する静的検査
    `tools/check-lisp-undefined.py` を追加。バイトコンパイラは未定義関数
    を警告しないため、`lsp-mode` の `prefix-numeric-value` のように実行時
    まで気づけない不具合があった。`tools/run-tests.sh` の最後に組み込み、
    `lisp/`・`unittest/`・`misc/` を走査する。機械的に見えない定義
    (マクロ生成・C 定義コンディションのアクセサ等) は
    `tools/lisp-undefined-allowlist.txt` に理由付きで列挙する。
    自己テストは `python3 tools/test-check-lisp-undefined.py`。
  * `json-escape-string` が存在しない `write-string` を呼んでいた不具合を
    修正。引用符・バックスラッシュを含む文字列の JSON エンコードで
    「関数が定義されていません」になった。xyzzy にある `write-char` の
    組み合わせに置き換え、上記静的検査で検出・回帰テスト
    (`json-escape-string-special-chars`) を追加。
  * 未定義変数参照・未宣言 `setq` の静的検査 (issues #365, #366) を
    `tools/check-lisp-undefined.py` に追加。字句束縛 (`let`・ラムダリスト・
    `loop` 等) を追跡し、宣言も定義もない変数の参照・代入を報告する。
    `boundp` ガード・`make-local-variable`・`(declare (special ...))` の
    慣用句や `selection-start-end`・`with-temp-files` 等の束縛マクロ、
    `#{...}` (OLE)・`>>` (テスト出力期待値) といった読み物構文は誤検出に
    ならないよう扱う。他 Lisp 専用の `ccl::*warn-if-redefine-kernel*` は
    `tools/lisp-undefined-vars-allowlist.txt` に理由付きで列挙する。
    自己テストは `python3 tools/test-check-lisp-undefined.py`。
  * 上記検査で見つかった未宣言変数の実バグを修正。`display-buffer` の `w`、
    `life-grim-reaper` の `living-neighbors`、`scan-c-function-1` の `argb`、
    `edict-analogize-conjugation` の `r` は束縛漏れだったので `let` に追加。
    `*edict-dictionary-path*` と `hanoi-top-of-line-number` は `defvar` を
    追加 (`paths.l` の `setq` は `defvar` に変更)。
    `javascript-continued-statement-offset` は `boundp` ガードを追加。

  * `lsp-install-server` コマンドを追加。Windows / WSL 両方のコンテキストで
    言語サーバーを自動インストールする。権限エラー時はインストールコマンドを
    ミニバッファに提示し kill-ring にも保存する。
    インストール失敗時は `*lsp-install*` バッファに実行コマンド・終了コード・
    全出力を残して表示するほか、同じ内容をログファイルにも保存する。
    インストール後にコマンドがPATH上で見つからない場合はその旨を警告する。
  * `lsp-mode` が `(lsp-mode t)` で「関数が定義されていません:
    `prefix-numeric-value`」と失敗する不具合を修正。存在しない Emacs 流
    `prefix-numeric-value` の代わりに xyzzy 標準の `(interactive "p")` +
    `toggle-mode` を使うようにした。
  * WSL から Windows 上の xyzzy を操作する TCP デバッグサーバ (PoC) を追加。
    `lisp/wsl-debug.l` の `M-x wsl-debug-serve` で `127.0.0.1:11722` に待受け、
    WSL 側 `tools/wsl-debug.py` から 1 行 1 S 式を送って評価結果 (`+OK` /
    `-ERR`) を受け取れる。トークン未設定時は認証なし、設定時は先頭行
    `AUTH <token>` が必要。トークンは `wsl-debug-generate-token` が
    `si:uuid-create` (UUID v4) から作る。`accept` がブロッキングのため
    serve 中は xyzzy が応答専念になる (C-g / 切断で復帰)。ノンブロック化は
    今後の課題。使い方と制約は `docs/user/wsl.md` の
    「WSL 側から xyzzy を操作するデバッグサーバ (PoC)」を参照。
  * `tools/` 内の WSL 関係スクリプトの役割を整理した (issue #393)。
    `tools/README.md` に対象者別の役割表 (利用者向け `xyzzy-wsl` /
    WSL 上のエージェント向け `wsl-debug.py` / 開発者向け `win-xyzzy.sh`) を
    追加し、`docs/user/wsl.md` に `xyzzy-wsl` の使い方の節、
    `docs/dev/README.md` に `win-xyzzy.sh` が開発用である旨の案内を追加。
  * WSL 統合の使い方をまとめた `docs/user/wsl.md` を追加 (issue #389)。
    概要 (できること・できないこと)、入口コマンド (`wsl-open-directory` /
    `wsl` / `wsl-compile` / `wsl-git`)、パス変換とディストロ名の決まり方、
    設定変数 (`*wsl-distribution*`・`*wsl-unc-prefix*` 等)、Windows 10 での
    `\wsl$` 設定を書いた。`docs/user/index.md`・`docs/user/features.md` ・
    `docs/user/lisp-libraries.md` から辿れる。
  * WSL プロジェクトのコンテキストをプロジェクト単位で覚え、
    git・ビルドを透過的に WSL 側へディスパッチするようにした。
      - `wsl-open-directory` が `(ROOT . DISTRO)` を `*wsl-project-list*`
        (ヒストリファイルに保存される `define-history-variable`) に
        登録するようになった。再起動後も、開いたプロジェクトの下の
        ディレクトリでは同じディストロが使われる。
      - `wsl-open-directory` が `setq-default` で `*wsl-project-distro*`
        の既定値を書き換えていたのを止めた。以前は WSL プロジェクトを
        1 つ開くと、そのディストロが**全バッファ**の既定になっていた。
        バッファローカルに留め、プロジェクトをまたぐ記憶は
        レジストリが担う。
      - `wsl-current-distro` の解決順位を
        バッファローカル → レジストリ → UNC パス → `*wsl-distribution*`
        に変更し、どれも決まらなければ nil を返すようにした。
        対話コマンド (`wsl-compile`・`wsl-git`・`wsl-open-directory` 等)
        は決まらないとき選択を促す (勝手に `Ubuntu` を仮定しない)。
      - `git-status` / `git-diff` / `git-log` / `git-blame` が
        WSL プロジェクトでは `wsl.exe` 経由で WSL 側の git を実行し、
        出力中の Linux パスを Windows パスに変換する
        (`git-run-command-to-buffer` が `wsl-git-command-for` で判定)。
      - `M-x build` を追加。プロジェクトの側に応じて WSL 側
        (`wsl-compile` と同じ経路) / カレント側でビルドコマンドを実行し、
        結果を compilation バッファに出して `next-error` でジャンプできる。
        Windows プロジェクトにもビルドの入口ができた。`wsl-compile` は
        常に WSL 側で実行する明示的な入口として残す。
      - `compile-run` としてビルド実行・出力・パス変換・エラー解析の
        共通部分を `wsl-compile` / `build` で共有するように整理した。
    回帰テストは `unittest/wsl-tests.l` の「7. プロジェクトコンテキスト」
    (レジストリの登録・最長一致・バックスラッシュ正規化、解決順位、
    不明時の nil、`setq-default` 事故の回帰、git ディスパッチ判定、
    `build` の定義)。
  * `M-x wsl-shell` を削除した (issue #390)。本体が `M-x wsl` と同じで、入口が
    2 語ある価値がなかった。WSL シェルを起動するには `M-x wsl` を使う。
  * `wsl-open-directory` が開くバッファを、説明文を書いた read-only の画面か
    ら作業ディレクトリのエントリ一覧に変えた (issue #391)。既定ディレクトリ
    は実在チェック後にそのディレクトリへ移るので、開いた直後の `C-x C-f` が
    同じ場所から始まり、並んだ項目はそのまま `find-file` に渡せる。
    「Commands in this directory」の固定テキストは載せない。

  * LSP クライアントが Windows で全く動かなかった不具合を修正。
    `make-process` の `:outcode` に BOM 付きの `*encoding-utf8*` を渡していた
    ため、送るメッセージの先頭に毎回 BOM (EF BB BF) が付き、言語サーバーは
    ヘッダの 1 文字目が化けて**どのリクエストも解釈しなかった**。
    `*encoding-utf8n*` に変更した。あわせて `:eol-code` に `*eol-lf*` を指定。
    Windows の既定は CRLF 変換で、受信した `\r` を全部落とすため
    Content-Length ヘッダの区切りが `\n\n` に化けて応答を読めなかった。
    `lsp-parse-messages` は CRLF / LF どちらの区切りも受けるようにした。
  * `json-encode` が「オブジェクト 1 個だけの配列」をオブジェクトと取り違えて
    型エラーになる不具合を修正。`textDocument/didChange` の `contentChanges`
    がまさにこの形で、ドキュメント同期が送れなかった。キーが文字列か
    シンボルかで見分ける。
  * POSIX (ncurses) のサブプロセスが子の端末を行規則の既定のまま使っていた
    ため、改行を含まない `process-send-string` が子に届かず、LSP の
    メッセージが送れなかった。子の端末を `ICANON`・`ECHO` なし、
    `VMIN=1` / `VTIME=0` に設定する。
  * LSP の端から端までのテストを追加。`tools/fake-lsp-server.py` (Python
    だけで動く最小の LSP サーバー) を相手に、起動・initialize・ドキュメント
    同期・診断・定義ジャンプ・停止を `unittest/lsp-e2e-tests.l` で確認する。
    実サーバーに依存しないので CI でも走る。
  * WSL から Windows 上の xyzzy を走らせて動作確認するための
    `tools/win-xyzzy.sh` を追加。作業ツリーの `lisp/`・`misc/`・`unittest/`・
    `tools/` を Windows 側のコピーへ差分コピーして `xyzzy-batch.exe` を実行する
    (UNC パスは `XYZZYHOME` に使えず、xyzzy 内で `//wsl.localhost/...` の形に
    なって「Permission denied」で死ぬため、実体をコピーする)。Wine では
    再現しない差 (ConPTY・コンソール API・ドライブレター・`:eol-code`・
    ファイルの共有モード) をここで潰す。なお Windows の `open` は既定が
    共有なしなので、他のプロセスが書くファイルをテストが読むときは
    `:share :read-write` を明示する (読み手がいる間、書き手の append が
    `PermissionError` で落ちる)。
  * LSP クライアントの使い方をまとめた `docs/user/lsp.md` を追加 (issue #383)。
    概要 (できること・できないこと)、対応モードと既定サーバーの表、`M-x
    lsp-install-server` と手動インストール、Windows と WSL の違い、`M-x
    lsp-mode` と `M-.` の使い方、`*lsp-default-servers*` などの設定変数、
    サーバーの止め方、うまくつながらないときの確認手順を書いた。変数名・
    コマンド名は `lisp/lsp.l` に合わせ、`M-x` から呼べない
    `lsp-stop-server` のような関数はその旨を明記した。`docs/user/index.md` ・
    `docs/user/features.md` ・ `docs/user/lisp-libraries.md` から辿れる。
  * `lsp-install-server` が WSL 側へ入れた直後に Windows 側の PATH を確認して
    いた不具合を修正 (issue #385)。WSL プロジェクトでは `wsl.exe` 越しに WSL 側
    へ入れるのに、入れた後の確認だけ `where` (Windows 側) を見ていた。WSL 側に
    しかコマンドが無いと「入ったのに PATH に無い」と誤って報告し、
    `*lsp-install*` バッファを開いていた。入れた側と同じコンテキストで確認する
    (`lsp--installed-p`)。回帰テストは
    `lsp-install-server-wsl-verifies-on-wsl-side` と
    `lsp-install-server-local-verifies-with-local-probe`。
  * 64bit ビルドで、tree-sitter の文法 DLL が外れて
    `ts_query_cursor__advance` の中で `0xc0000005` で落ちる不具合を修正
    (issue #382)。`ts-register-mode` が同じモードを二度登録すると、先に
    読んだ文法オブジェクトは誰からも指されなくなる。二度目は
    `GetModuleHandleW` で読み込み済みのモジュールを拾うだけで参照数を
    増やさないため、一度目が GC されたときのデストラクタが
    `FreeLibrary` を呼ぶと DLL が外れる。外れると `g_ts_cache` の
    `TSTree` / `TSQuery` と解析用の裏スレッドが持つ `TSLanguage` が
    宙に浮く。文法 DLL はプロセスが終わるまで読み込んだままにした
    (`src/core/ts.h`)。あわせて `ts-register-mode` が同じ DLL を読み直さ
    ないようにし (`lisp/ts.l` の `*ts-grammar-objects*`)、孤児になる owner
    を作らないようにした。回帰テストは
    `ts-register-mode-keeps-one-grammar-object`。
  * `tools/deploy-windows.sh` が配置段階で中断する不具合を修正。
    `/mnt/c` (9p) への展開で `unzip` がタイムスタンプ・属性の設定に必ず
    警告を出し ("Operation not permitted")、警告時の終了コード 1 を
    `set -e` が失敗とみなしてデプロイ全体を黙って中断していた。ファイル
    自体は展開できているので終了コード 1 は成功扱いにし、2 以上だけを
    エラーにした。あわせて各段階 (unpacking / clearing / copying /
    saving) の開始を表示し、9p 越しの低速コピー (約 30MB×2 arch) が
    ハングに見えないようにした。
  * CLI エージェント作業フローを統合する `lisp/agent.l` を追加
    (issue #408)。これまでは `M-x wsl` で端末を開いてからエージェント
    コマンドを手で打ち、ファイルやエラーの受け渡し・変更後の
    バッファ反映・差分確認も個別の手作業だった。`M-x agent` で
    プロジェクトルートに紐づく `*Agent:<root>*` pty 端末を起動する
    (WSL プロジェクトでは `wsl.exe -d <distro> --cd <dir>` 経由の
    login shell から、POSIX では `sh -lc` から、Windows ネイティブでは
    `cmd.exe /c` から)。起動コマンドは `*agent-command*` /
    `*agent-command-list*` で設定でき、`C-u M-x agent` で一覧から
    選択する。コードバッファ側からは `agent-send-file` (ルート相対の
    `@path` 参照をプロンプトへ挿入、WSL 側には WSL パスへ変換)、
    `agent-send-region` (bracketed-paste で一塊送信)、
    `agent-send-error` (カーソル行を送信) でコンテキストを渡せる。
    `agent-diff` がプロジェクトの `git diff` を `*Agent-Diff*` に
    表示し (C-u で HEAD 差分)、`agent-revert-changed` がディスク上で
    変更された未編集バッファをまとめて revert する。あわせて
    `toggle-terminal-drawer` を `toggle-buffer-drawer` に一般化し、
    `toggle-agent-drawer` で agent バッファを画面下部に出せるように
    した。leader は `M-m a` に agent カテゴリを追加。
    回帰テストは `unittest/agent-tests.l`。
  * リポジトリ直下に `.xyzzy` (開発者用初期化ファイル) を追加し、ビルドエラーと
    grep のジャンプ (T02/T03) を修正。gcc/clang の `file:line:col:` 形式に
    対応する error regexp を `*error-regexp-list*` の先頭に追加 (既定の
    パターン 2 の贪欲 `(.+)` が `hello.c:7:5:` を filename=`hello.c:7`,
    line=`5` と誤解析していた)。`*grep-hook*` に `build-error-list` を
    登録し、grep 後に `C-x \`` でジャンプできるようにした。`next-error`
    をオーバーライドし、エラーリスト未構築時に `build-error-list` を呼び出し、
    初回呼び出しでは `goto-error t` (ポップ後に次へ) ではなく
    `goto-error nil` (先頭エラーを直接訪問) により、単一エラー時の
    「No more errors」と複数エラー時の先頭スキップを回避する。
  * `M-x agent` が起動中の agent バッファに再接続するだけで、
    `*agent-command*` を変えても新しいコマンドが起動しない不具合を
    修正 (issue #412)。起動時コマンドを `*agent-launched-command*` に
    記録し、実行中プロセスがあるとき要求コマンドと異なれば
    「~A を実行中です。~A で起動しなおしますか?」と確認して
    `kill-process` 後に作り直す (No なら従来どおり接続)。同じ
    コマンドでも `M-x agent-restart` で起動しなおせる (leader は
    `M-m a A`)。
