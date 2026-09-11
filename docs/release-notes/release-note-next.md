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

  * バッファの行が短くなった後にスクロールすると、変更前の文字が行末に
    残って表示されることがある問題を修正しました。
  * **共通設定・ローカル設定ダイアログの整理とフォント設定ダイアログ幅の拡大 (issue #358)**:
    - **フォント設定幅の拡大**: フォント設定ダイアログ (`IDD_FONT`) の幅を他のタブに合わせて 239 から 263 に拡大し、フォント名リストの幅を 79 から 105 に拡張することで、フォント名が表示しきれない問題を解消しました。
    - **レガシー設定の削除・デフォルト有効化**:
      - 「ちゃんと反転する」(`*window-flag-just-inverse*`) を常時有効化し、ダイアログから削除しました。
      - 「ホイールマウスに反応する」(`*support-mouse-wheel*`) を常時有効化しました。
      - 現代環境で不要となったレガシー設定（Global IME, MS-IME 2000向け設定, Mule-UCS向けUTF-8設定, MSVC2.x/MSDN Info Viewer設定）を削除しました。
      - クリップボード同期を常時同期に一本化し、「中途半端に同期」等の複雑な選択肢を整理しました。
    - **文言・タブ名の見直し**:
      - 「表示する?」→「表示項目」
      - 「てきとーに」→「自動判別」、「改行とEOFの解釈」→「改行コードの判定」
      - 「なんでALTでメニューが開かない?」→「Altキー単体でメニューを開く」
      - 「いろいろ」タブ→「全般」タブ、「さまざま」タブ→「操作・編集」タブ
      - ローカル設定の「もろもろ」タブ→「バッファ設定」タブ、「保存してなくても文句を言わない」→「変更があっても保存確認しない」
      - 禁則処理の「表示」「Fill」→「折り返し表示時」「段落整形(M-q)実行時」
      - 「古いバージョンをいくつ残す?」→「保持する古い世代数」、「番号が最後までいったら勝手に詰める」→「番号が最大値に達したら自動で詰める」
  * **WSL連携 (パス相互変換・ターミナル起動・クリップボード統合) (issue #342)**:
    Windows 上の xyzzy から WSL（Windows Subsystem for Linux）をシームレスに操作できるようにする `lisp/wsl.l` を追加しました。
    - **パス相互変換 API**:
      - `wsl-path-to-windows`: Linux 側のパス (`/mnt/c/...` や `/home/...`) を Windows 側のパス (`C:/...` や `\\wsl.localhost\<distro>\...`) へ変換。
      - `windows-path-to-wsl`: Windows 側のパス (`C:/...` や `\\wsl.localhost\...`) を Linux 側のパス (`/mnt/c/...` や `/home/...`) へ変換。
    - **ディストリビューション管理**:
      - `wsl-list-distributions` / `wsl-parse-distributions`: `wsl.exe -l -q` の出力を整形し、利用可能なディストリビューション名リストを取得。UTF-16LE や改行コード差異に対応。
      - `wsl-read-distribution`: ミニバッファ補完によるディストリビューション選択。
    - **ターミナル連携 (`M-x wsl` / `M-x wsl-shell`)**:
      - カレントバッファのディレクトリに対応する WSL 側のパスを自動検出し、そのディレクトリで `wsl.exe` によるターミナルエミュレータバッファ (`:terminal t`) を起動。
      - プレフィックス引数によるディストリビューションの対話的指定に対応。メジャーモード `wsl-mode` を提供。
    - **クリップボード・OSC 52 支援**:
      - `wsl-osc-52-sequence`: ターミナル用 OSC 52 エスケープシーケンスの生成ユーティリティ。
      - `wsl-copy-string`, `wsl-paste-string`, `wsl-copy-region`, `wsl-paste`: xyzzy のクリップボード／kill-ring との連携ユーティリティ。
  * **WSLプロジェクト管理と外部ツール自動ディスパッチ (issue #343)**:
    WSL 上のプロジェクトに対するディレクトリオープン、ビルド・Git実行の自動委譲、およびコンパイルエラー解析の連携を実装しました。
    - **WSL プロジェクトオープン (`M-x wsl-open-directory`)**:
      ディストリビューションと WSL パスを指定して Windows 側 UNC パス (`\\wsl.localhost\<distro>\...`) を開き、プロジェクトルートおよび WSL コンテキストを設定。
    - **compilation-mode の WSL 連携 (`M-x wsl-compile`)**:
      WSL 上でのビルドコマンド実行（`wsl.exe -d <distro> --cd <wsl_dir> -- sh -c "..."`）を行い、コンパイルログ内の Linux パスを Windows パスに自動変換することで `next-error` (`C-x \``) による該当ファイル・行へのジャンプを実現。
    - **WSL Git 連携 (`M-x wsl-git`)**:
      WSL 側での Git コマンド実行支援。
    - **WSL 側 CLI スクリプト (`tools/xyzzy-wsl`)**:
      WSL 側シェルからカレントディレクトリやファイルを Windows 側 xyzzy で開くためのランチャースクリプトを提供。
  * **LSP クライアント基本機能の実装 (JSON-RPC・ドキュメント同期・診断・定義ジャンプ) (issue #344)**:
    Language Server Protocol (LSP) と連携するための軽量クライアント基盤 `lisp/lsp.l` を追加しました。
    - **JSON エンコーダー / デコーダー**:
      - 外部ライブラリ依存のない組み込み Lisp による高速・軽量な JSON パーサーおよびシリアライザー (`json-encode`, `json-decode`)。
    - **JSON-RPC / Content-Length プロトコル処理**:
      - LSP 仕様に準拠した Content-Length ヘッダ付きメッセージの送受信・バッファリングおよびリクエスト/レスポンス処理 (`lsp-make-message`, `lsp-parse-messages`, `lsp-send-request`, `lsp-send-notification`)。
    - **ライフサイクル & ドキュメント同期**:
      - 言語サーバープロセスとの初期化ハンドシェイク (`initialize`, `initialized`)、シャットダウン処理 (`shutdown`, `exit`)。
      - ファイルオープン (`textDocument/didOpen`)、バッファ変更 (`textDocument/didChange` full sync)、保存 (`textDocument/didSave`)、クローズ (`textDocument/didClose`) の同期。
    - **診断と定義ジャンプ**:
      - `textDocument/publishDiagnostics` によるエラー・警告の解析と抽出 (`lsp-extract-diagnostics`)。
      - `textDocument/definition` によるシンボル定義位置（ファイルURI、行・文字オフセット）のパースと定義元バッファ・カーソル位置へのジャンプ (`lsp-find-definition`)。
    - **マイナーモード `lsp-mode`**:
      - バッファごとのフック（`after-change-functions`, `after-save-hook`, `kill-buffer-hook`）とキーマップ (`M-.` で `lsp-find-definition`) を提供。
  * **LSP の WSL 透過接続（URIトランスレータとWSL内言語サーバー起動） (issue #345)**:
    Windows 上の xyzzy から WSL 内にインストールされた言語サーバー（rust-analyzer, pyright, gopls 等）をシームレスに利用するための透過連携機能を実装しました。
    - **URI / パス相互変換トランスレータ (`lsp-path-to-uri` / `lsp-uri-to-path`)**:
      - Windows UNC パス（`\\wsl.localhost\<distro>\home\...` 等）を WSL 側 URI（`file:///home/...`）へ透過変換。
      - WSL 側 URI（`file:///home/...`）を Windows UNC パスへ逆変換。また `/mnt/<drive>/...` 形式の URI をローカル Windows ドライブパスへ解決。
    - **WSL 言語サーバーの起動と自動ディスパッチ**:
      - `lsp-wsl-server-command`: `wsl.exe -d <distro> -- <command>` 形式でのコマンドライン構築。
      - バッファが WSL プロジェクト内にある場合、`lsp-start-server` が自動的に WSL 側言語サーバーを起動し、ディストリビューションコンテキストを保持。
    - **透過的な診断と定義ジャンプ**:
      - WSL 側言語サーバーからの診断通知 (`publishDiagnostics`) や定義ジャンプ (`textDocument/definition`) で返される URI を UNC パスに透過マッピングし、xyzzy バッファで直接開いて該当位置へジャンプ。
  * **`wsl-list-distributions` で未定義関数 `generate-new-buffer` が呼ばれる不具合の修正 (issue #351)**:
    `wsl-open-directory` 等のディストリビューション一覧取得処理で、Emacs Lisp の関数名である `generate-new-buffer` が使われていたのを xyzzy の組み込み関数 `create-new-buffer` に修正しました。
  * **WSL ディレクトリオープン時のバッファ表示と初期ディレクトリ設定 (issue #353)**:
    `wsl-open-directory` で WSL ディレクトリを開いた際、専用バッファ `*WSL: <distro>:<path>*` を作成・表示し、当該バッファおよびグローバルのカレントディレクトリを WSL 側の UNC パスに設定することで、直後の `C-x C-f` (`find-file`) やファイラ等で当該ディレクトリが初期位置として提示されるように改善しました。また、WSL パスを直接指定して開く対話的コマンド `wsl-find-file` を追加しました。
  * **`wsl-open-directory` でのディレクトリ補完サポート (issue #355)**:
    `wsl-open-directory` の対話的ディレクトリ入力において、Windows UNC パスを基にしたミニバッファディレクトリ補完機能 (`wsl-read-directory`, `wsl-resolve-directory-path`) を導入し、WSL 内のディレクトリを TAB 補完等で選択・入力できるようにしました。
