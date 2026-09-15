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
    `AUTH <token>` が必要。`accept` がブロッキングのため serve 中は xyzzy が
    応答専念になる (C-g / 切断で復帰)。ノンブロック化は今後の課題。

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
