# xyzzy モダン化・デフォルト体験改善 引き継ぎ書 (Handover Document)

本ドキュメントは、PR [#15](https://github.com/kuwa72/xyzzy/pull/15) (`topic/sensible-defaults-and-leader`) における作業の全体計画、実施済み作業差分、解決済みトラブルシュート、および今後の残タスクを次の作業AIへ引き継ぐための詳細資料です。

---

## 1. 概要と目的

- **リポジトリ**: `kuwa72/xyzzy`
- **対象ブランチ**: `topic/sensible-defaults-and-leader`
- **プルリクエスト**: [#15: Add sensible defaults, leader key system, project management, and git integration](https://github.com/kuwa72/xyzzy/pull/15)
- **目的**: 
  Doom Emacs, Spacemacs, Prelude 等の優れた設計思想を取り入れ、**「設定ファイル (~/.xyzzy) を書かなくても、デフォルトインストール状態で最初から快適・モダンに作業できる状態」** を構築する。

---

## 2. 全体計画 (ロードマップ) と進捗状況

| Phase | 項目 | 概要 | 状態 |
|---|---|---|---|
| **Phase 1** | **Sensible Defaults** | バックアップ安全隔離、カーソル位置記憶、最近開いたファイル | **完了** (反映・テスト済) |
| **Phase 2** | **Leader Key & Which-key** | `M-m` / `C-c SPC` によるキー体系 + ミニバッファ候補一覧ガイダンス | **完了** (反映・テスト済) |
| **Phase 3** | **プロジェクト管理 (`project.l`)** | Git/マーカーによるルート判定、プロジェクト内ジャンプ・Grep | **完了** (反映・テスト済) |
| **Phase 4** | **トグルターミナル & Git支援** | `Leader t t` で下部ターミナル展開、`Leader g s` で簡易 Git 操作 | **完了** (反映・テスト済) |
| **Phase 5** | **ミニバッファUI・補完の高度化** | 絞り込み補完 UI の強化やインクリメンタル検索の快適化 | **未着手** (必要に応じ実施) |

---

## 3. 実施済み作業と作業差分詳細

### ① Phase 1: 賢い基本挙動 (Sensible Defaults)
1. **バックアップ安全自動隔離 (`lisp/backup.l`)**:
   - `*backup-directory*` の既定値を `~/.xyzzy.d/backup/` に設定。
   - `*hierarchic-backup-directory*` を `t` に設定。プロジェクトディレクトリを汚さず、安全に階層構造を保ってバックアップ。
2. **カーソル位置記憶 (`lisp/saveplace.l` [新規])**:
   - ファイル終了時にカーソル位置を記録し、再オープン時に自動復元。`~/.xyzzy.history` と連携してセッション間永続化。
3. **最近開いたファイル管理 (`lisp/recentf.l` [新規])**:
   - 直近開いたファイルを最大 200 件自動記録。
   - `C-x C-r`（または `M-x recentf-open`）でインクリメンタル補完から選択して即オープン。

### ② Phase 2: Leader Key & Which-key ガイダンス (`lisp/leader.l` [新規])
1. **Leader Key プレフィックス**:
   - `M-m` および `C-c SPC` を `execute-leader-key` にバインド。
2. **カテゴリ構成**:
   - `f`: File (`find-file`, `recentf-open`, `save-buffer`, `write-file`, `open-filer`)
   - `b`: Buffer (`switch-to-buffer`, `kill-selected-buffer`, `list-buffers`, `revert-buffer`, `next-buffer`, `previous-buffer`)
   - `p`: Project (`project-find-file`, `project-grep`, `project-filer`, `project-open-terminal`, `project-switch-project`)
   - `s`: Search (`isearch-forward`, `isearch-backward`, `grep`, `query-replace`)
   - `g`: Git (`git-status`, `git-diff`, `git-log`, `git-blame`)
   - `t`: Toggle (`toggle-terminal-drawer`, `toggle-line-number`, `toggle-fold-line`/`toggle-truncate-lines`, `calc`)
   - `w`: Window (`split-window`, `split-window-vertically`, `other-window`, `delete-window`, `delete-other-windows`)
   - `h`: Help (`describe-key`, `describe-function`, `describe-variable`, `describe-bindings`, `apropos`)
   - `SPC`: `execute-extended-command` (`M-x`)
   - `/`: `grep`
3. **Which-key ガイダンス (`which-key-guide`)**:
   - キー入力待ち受け時に、ミニバッファへ候補一覧（例: `[Leader] f:File+ b:Buffer+ ...`）をリアルタイム表示。
4. **ユーザー拡張 (`leader-define-key`)**:
   - `(leader-define-key "f o" 'my-command "MyOpen")` で独自キーシーケンスを追加可能。

### ③ Phase 3: プロジェクト管理 (`lisp/project.l` [新規])
1. **プロジェクトルート自動検出 (`project-current-root`)**:
   - `.git`, `CMakeLists.txt`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile` 等のマーカーファイルを親ディレクトリに向かって遡り判定。
2. **プロジェクトコマンド**:
   - `project-find-file` (`Leader p f`): プロジェクト配下の全ファイルを相対パスで補完オープン。
   - `project-grep` (`Leader p g`): プロジェクトルート配下の全ファイルを一括検索。
   - `project-filer` (`Leader p d`): プロジェクトルートでファイラ起動。
   - `project-open-terminal` (`Leader p t`): プロジェクトルートをカレントディレクトリとしてターミナル起動。
   - `project-switch-project` (`Leader p p`): 記憶されたプロジェクト一覧から切り替え。

### ④ Phase 4: トグルターミナル & 簡易 Git 支援 (`lisp/git.l` [新規], `lisp/terminal.l`)
1. **トグル式ターミナルドロワー (`toggle-terminal-drawer` / `Leader t t`)**:
   - 画面下部にターミナルバッファ（`*Shell*`）をワンキーで分割表示・格納。
2. **簡易 Git 支援 (`lisp/git.l`)**:
   - `git-status` (`Leader g s`): `*git status*` バッファに変更一覧を表示（`d`: 差分, `l`: ログ, `g`: 更新, `RET`: 開く, `q`: 閉じる）。
   - `git-diff` (`Leader g d`): `*git diff*` に差分を表示。
   - `git-log` (`Leader g l`): コミットグラフ履歴を表示。
   - `git-blame` (`Leader g b`): 行ごとのコミット履歴を表示。

### ⑤ 起動ロードへの統合 & ドキュメント更新
- `lisp/loadup.l`: `backup`, `saveplace`, `recentf`, `leader`, `project`, `git` を標準起動ロード対象に追加。
- `docs/user/keybindings.md`: Leader Key 体系の表を追加。
- `docs/user/lisp-libraries.md`: 新規ライブラリの説明を追加。
- `docs/release-notes/release-note-next.md`: リリースノートに変更内容を記載。

---

## 4. 解決済みの重要トラブルシュート (ハマりポイント)

次の作業AIが同じ問題に引っかからないよう、解決したバグと構造的要因を記録します。

### 1. バッチモード (`xyzzy-batch.exe`) でプロセスが終了せずハングする問題
- **要因 1**: `src/frontend/win32/init.cc` で `si:*startup` 完了後に `if (init_ok)` が真になり、バッチモードであっても GUI メッセージループ（`main_loop`）に入ってキー入力を待っていた。
  - **解決**: `if (init_ok && !g_batch_mode)` とし、バッチ時は `ExitProcess` へ直行するように修正。
- **要因 2**: `src/core/Buffer.cc` の `Fkill_xyzzy` で、バッファ保存確認（`Buffer::kill_xyzzy(1)`）がモーダルダイアログを待とうとしてブロックしていた。
  - **解決**: `Buffer::kill_xyzzy(!g_batch_mode)` とし、バッチ時は確認なしで即座に終了するように修正。
- **要因 3**: `tools/bytecompile.sh` で `wineserver -w`（自然終了待機）が呼ばれていたが、wineserver はキャッシュ維持のため常駐し続ける。
  - **解決**: `wineserver -k` に変更し、`trap 'wineserver -k 2>/dev/null || true' EXIT` を追加。

### 2. Emacs と xyzzy のシンボル・用語・引数の不一致
- **ウィンドウ分割**:
  - Emacs は `split-window-vertically` (上下分割), `split-window-horizontally` (左右分割)。
  - xyzzy は `split-window` (上下分割), `split-window-vertically` (左右分割)。
  - **解決**: `lisp/window.l` に `split-window-horizontally`, `split-window-below`, `split-window-right` を互換関数として追加。
- **行折り返し切り替え**:
  - Emacs は `toggle-truncate-lines`、xyzzy は `toggle-fold-line`。
  - **解決**: `lisp/window.l` に `toggle-truncate-lines` をエイリアスとして追加。
- **isearch の autoload**:
  - `isearch.l` は起動時ロードされておらず、`defs.l` にも autoload が無かった。
  - **解決**: `lisp/defs.l` に `(autoload 'isearch-forward "isearch" t)` 等を追加。
- **diff-mode のシグネチャ**:
  - xyzzy の `diff-mode` は 5 引数必要。
  - **解決**: `lisp/git.l` 内で専用の `git-diff-mode` (無引数) を定義して適用。

---

## 5. テスト・ビルドの検証コマンド

作業時は以下のコマンドでビルドとテストを検証できます：

```bash
# 1. PE バイナリのビルド
tools/x build x86_64

# 2. 全 146 ファイルのバイトコンパイル (.lc 生成)
tools/x bytecompile x86_64 --force

# 3. 単体テストの実行
tools/x wine x86_64 unittest/defaults-tests.l
tools/x wine x86_64 unittest/leader-tests.l
tools/x wine x86_64 unittest/project-tests.l
tools/x wine x86_64 unittest/git-tests.l

# 4. 全体テストスイートの実行
tools/x test x86_64
```

---

## 6. 次の AI への引き継ぎタスク (今後の作業方針)

1. **実機（Windows 環境）でのデプロイ・実動テスト**:
   - `tools/deploy-windows.sh` で Windows 側へ展開し、GUI（`xyzzy.exe`）での `M-m` / `C-c SPC` 操作、プロジェクト検索、Git、ターミナルトグルがスムーズに動作することを確認。
2. **Phase 5: ミニバッファ UI / 補完のさらなる改善（オプション）**:
   - `completing-read` のポップアップや絞り込み（インクリメンタル絞り込み）の視認性向上。
   - `M-x` や `project-find-file` でのファジーマッチング / パス絞り込みの拡張。
3. **PR のマージ・レビュー対応**:
   - CI チェック（`mingw` ワークフロー等）の通過確認と、必要に応じた微調整。
