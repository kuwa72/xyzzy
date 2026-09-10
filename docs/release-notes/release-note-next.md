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
