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
