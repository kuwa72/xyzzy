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

