xyzzy リリースノート
====================

  * バージョン: 0.9.0
  * リリース日: 2026-09-11
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

**WSL 連携と LSP（言語サーバプロトコル）を本格導入し、外部ツールとの連携基盤を
一気に広げた回である。**

WSL 上のディストリビューションをxyzzy から操作し、compilation-mode や git を
WSL 側で実行できるようになった。さらに LSP クライアントを実装し、WSL 内の
言語サーバー（rust-analyzer, pyright, gopls 等）を透過的に利用できる。
ダイアログの整理やバグ修正も合わせて、日常使いの快適さを広げた。


変更
----


### WSL 連携

  * **WSL 連携機能を新設した** (issue #342)。
    `lisp/wsl.l` で WSL との橋渡しとなる API を一式実装した。ディストリビューションの
    列挙・選択、パスの Windows ⇄ WSL 変換、シェル起動、クリップボード連携
    （OSC 52 シーケンス経由）、compilation-mode / git との統合、および CLI ツール
    `tools/xyzzy-wsl` を提供する。`M-x wsl-shell` で WSL シェルを起動し、
    `wsl-mode` が自動的に有効になる。

  * **WSL プロジェクト管理と外部ツールの自動ディスパッチを実装した** (issue #343)。
    WSL プロジェクトを管理し、compilation-mode や git コマンドを自動的に
    WSL 側へディスパッチする。`M-x wsl-compile` で WSL 上でのビルド実行と
    `next-error` によるエラーへのジャンプが可能になった。`M-x wsl-git` で
    WSL 側の git を呼び出せる。

  * **LSP の WSL 透過接続を実装した** (issue #345)。
    Windows 上の xyzzy から WSL 内にインストールされた言語サーバーを
    シームレスに利用するための透過連携機能を実装した。URI / パス相互変換
    トランスレータ（`lsp-path-to-uri` / `lsp-uri-to-path`）により、Windows UNC
    パスを WSL 側 URI へ透過変換する。`lsp-wsl-server-command` により、
    WSL プロジェクト内で `lsp-start-server` を呼ぶと自動的に WSL 側で
    言語サーバーが起動する。定義ジャンプ時も URI 変換が透過程される。

  * **`wsl-list-distributions` と `generate-new-buffer` を連携させた** (issue #351)。
    `wsl-open-directory` と `generate-new-buffer` / `create-new-buffer` を連携させ、
    WSL ディレクトリからバッファを生成できるようにした。

  * **`wsl-open-directory` を改善した** (issue #353)。
    WSL ディレクトリを開いたとき、WSL UNC パスが `*WSL:` バッファに設定され、
    `C-x C-f`（`find-file`）やファイラ等で当該ディレクトリが初期位置として
    提示されるように改善した。また `wsl-find-file` も整備した。

  * **`wsl-open-directory` の UNC パス解決を改善した** (issue #355)。
    `wsl-open-directory` で UNC パスを正しく解決するため `wsl-read-directory` と
    `wsl-resolve-directory-path` を導入した。WSL TAB 補完も改善した。


### LSP（言語サーバプロトコル）

  * **LSP クライアントを新設した** (issue #344)。
    `lisp/lsp.l` で言語サーバプロトコルのクライアントを実装した。JSON-RPC
    ベースのメッセージング（`lsp-make-message`, `lsp-parse-messages`,
    `lsp-send-request`, `lsp-send-notification`）、プロセスとの初期化
    ハンドシェイク（`initialize`, `initialized`）、シャットダウン処理
    （`shutdown`, `exit`）、ドキュメント同期（`didOpen`, `didChange`,
    `didSave`, `didClose`）、`textDocument/publishDiagnostics` による
    エラー・警告の抽出、`textDocument/definition` による定義ジャンプを
    支持する。マイナーモード `lsp-mode` でバッファごとのフックと
    キーマップ（`M-.` で定義ジャンプ）を提供する。


### ダイアログと設定

  * **共通設定・ローカル設定ダイアログを整理し、フォント設定ダイアログの幅を
    拡大した** (issue #358)。
    フォント設定ダイアログ（`IDD_FONT`）の幅を 239 から 263 に拡大し、
    フォント名リストの幅を 79 から 105 に拡張することで、フォント名が
    表示しきれない問題を解消した。「ちゃんと反転する」
    （`*window-flag-just-inverse*`）を常時有効化しダイアログから削除し、
    「ホイールマウスに反応する」（`*support-mouse-wheel*`）も常時有効化した。
    現代環境で不要となったレガシー設定（Global IME, MS-IME 2000 向け設定,
    Mule-UCS 向け UTF-8 設定, MSVC2.x/MSDN 向け設定）を削除し、
    ダイアログの表示テキストも整理した（「てきとーに」→「自動判別」、
    「改行と EOF の解釈」→「改行コードの判定」、
    「なんで ALT でメニューが開かない?」→「Alt キー単体でメニューを開く」、
    禁則処理の「表示」「Fill」→「折り返し表示時」「段落整形 (M-q) 実行時」）。


### バグ修正

  * **バッファの行が短くなった後のスクロール表示を修正した。**
    行が短くなった後にスクロールすると、変更前の文字が行末に残って
    表示されることがある問題を修正した。


### ビルドと配布

  * **半角スペース検証スクリプトを追加した。**
    `tools/verify-half-width-space.ps1` でソース内の半角スペースの
    使用状況を検証できるようにした。
