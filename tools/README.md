tools/ について
================

このディレクトリはリリースの ZIP / インストーラには入りません。
開発者と、WSL 側から Windows 版 xyzzy を触る利用者のための道具です。

WSL 関係のスクリプトは 3 つあり、**対象者が違います**:

| スクリプト | 対象者 | 役割 |
|---|---|---|
| `xyzzy-wsl` | WSL を使う**利用者** | WSL のシェルから `xyzzy .` のように Windows 側 GUI の xyzzy を開く入口。使い方は [docs/user/wsl.md](../docs/user/wsl.md) |
| `wsl-debug.py` | **WSL 上のエージェント** | `M-x wsl-debug-serve` で待受けた TCP サーバへ 1 行 1 S 式を送り、評価結果を受け取るクライアント (PoC)。使い方は [docs/user/wsl.md](../docs/user/wsl.md) |
| `win-xyzzy.sh` | **開発者** | 作業ツリーの `lisp/` 等を Windows 側へ差分コピーし、実機の Windows 版 xyzzy でテストやスクリプトを走らせる。Wine では再現しない差 (ConPTY・コンソール API・共有モード等) を潰すためのもの。ヘッダコメントに詳細あり |

その他のスクリプト
------------------

| スクリプト | 役割 |
|---|---|
| `x` | 開発の入口。Docker コンテナ内で configure / build / bytecompile / package / test / wine / smoke / pty を実行する |
| `run-tests.sh` | Lisp テストスイートを回す (コンテナ内、`tools/x test` から呼ばれる) |
| `bytecompile.sh` | `lisp/` をバイトコンパイルする (コンテナ内) |
| `lc-stale.sh` | `.l` が `.lc` より新しいものを列挙する共通関数 (`bytecompile.sh` / `run-tests.sh` が source する) |
| `package.sh` | ビルド済みツリーを `_dist/<arch>` にインストールする (コンテナ内) |
| `deploy-windows.sh` | ビルド → パッケージ → `/mnt/c` 側へ配置まで一括で行う (WSL ホスト上で実行) |
| `arm-prep.sh` | ARM64 のようにホストでコードジェネレータを動かせないターゲット向けに `src/core/gen/` を生成する |
| `ci-wait.sh` | PR の全チェックが終わるまで待ち、結果とテスト集計を 1 画面に出す |
| `wine-run.sh` | クロスビルドした exe をテスト環境の変数付きで Wine 実行する (コンテナ内) |
| `linux-smoke.sh` | POSIX (ncurses) ビルドを一度起動して smoke 確認する |
| `pty-drive.py` | ncurses 版を pty 越しにキー入力で駆動し画面を表示する |
| `setup-hooks.sh` | `core.hooksPath` を `.githooks` に設定する (`.claude/settings.json` の SessionStart から実行) |
| `release-prep.sh` | バージョン bump とリリースノート改名を行う ([RELEASING.md](../RELEASING.md) 参照) |
| `release-body.py` | リリースノートから GitHub Release の本文を作る |
| `resolve-note-conflict.py` | リリースノートの競合解消を補助する |
| `check-lisp-undefined.py` | `lisp/`・`unittest/`・`misc/` の未定義関数・変数参照を静的に検査する (`run-tests.sh` の末尾で実行) |
| `test-check-lisp-undefined.py` | `check-lisp-undefined.py` の自己テスト |
| `check-win32-separation.py` | core が Win32 に依存しない分離を静的に検査する |
| `fake-lsp-server.py` | Python だけで動く最小 LSP サーバ。`unittest/lsp-e2e-tests.l` の相手役 |
| `lisp-undefined-allowlist.txt` / `lisp-undefined-vars-allowlist.txt` | `check-lisp-undefined.py` の許容リスト (理由付き) |
| `devenv/` | `tools/x` が使うコンテナイメージの Dockerfile |
