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
| **Phase 5** | **ミニバッファUI・補完の高度化** | 絞り込み補完 UI の強化やインクリメンタル検索の快適化 | **一部完了** (`project-find-file`/`project-switch-project` のファジー絞り込み。`M-x` は未着手、下記参照) |

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

### ⑤ Phase 5 (一部): ミニバッファのファジー絞り込み (`lisp/fuzzy-complete.l` [新規])
1. **経緯**: `completing-read`/`read-command-name` は候補の絞り込み方をフックする
   手段が無い、完全にブラックボックスなネイティブ実装 (predicate も無ければ
   スコアリングも差し込めない)。そのため `project-find-file` にファジー
   マッチングを入れるには、`isearch.l`/`which-key-guide` と同じ手法
   (`read-char` で1文字ずつ読み、`minibuffer-prompt` でステータス行を都度
   書き換える、実バッファ・実ウィンドウは一切開かない) で自前の
   インクリメンタル絞り込みループを書くしかなかった。
2. **`fuzzy-score`/`fuzzy-filter`**: CANDIDATE が QUERY の (大小無視の) 部分列
   であればスコアを返す、貪欲な左から右への1回走査。連続一致・単語区切り
   直後の一致にボーナス。パス文字列は、ディレクトリ名側に QUERY の先頭文字と
   たまたま一致する文字があると貪欲走査がそちらに食いつき、ファイル名側の
   綺麗な一致を見逃すことがあるため、ファイル名部分 (最後の `/` より後ろ)
   だけの再走査も行い、良い方のスコアを採用している（`unittest/fuzzy-complete-tests.l`
   のテストで実際にこの問題を検出して直した）。
3. **`fuzzy-completing-read`**: `C-n`/`C-p`/`TAB`/`↑`/`↓` で絞り込み結果内を
   移動、`RET` で確定、`C-g` でキャンセル。`project-find-file` と
   `project-switch-project` の `completing-read` 呼び出しをこれに置き換えた。
4. **意図的にやらなかったこと**: `M-x` (`execute-extended-command`) のファジー
   化。`interactive "C"` の `C` コードが呼ぶ `read-command-name` は
   `completing-read` 同様フックできず、置き換えるには `execute-extended-command`
   自体を書き換えて `do-symbols` + `commandp` でコマンド一覧を自前で集め、
   `command-execute` を直接呼ぶ形にする必要がある。エディタ全体で最も
   使用頻度の高いコマンドの核を書き換えることになり、影響範囲・リスクが
   `project-find-file` とは桁違いに大きいため、今回は見送った。次に着手する
   なら別 PR で切り出すことを推奨する。
5. **テストの限界**: `fuzzy-score`/`fuzzy-filter` は純粋関数なので
   `unittest/fuzzy-complete-tests.l` で自動テスト済み。一方 `fuzzy-completing-read`
   の `read-char` ループ自体は自動テストできない。`unread-char` で複数文字を
   スタックしてキー入力を模擬できないか試したが、2文字目以降が消費されず
   本物のキーボード入力待ちにハングすることを確認済み (`isearch.l`/
   `which-key-guide` の対話ループも同じ理由で無テスト)。手動での動作確認
   (または実機での操作) に頼るしかない。

### ⑥ 起動ロードへの統合 & ドキュメント更新
- `lisp/loadup.l`: `backup`, `saveplace`, `recentf`, `leader`, `fuzzy-complete`, `project`, `git` を標準起動ロード対象に追加。
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
- **`autoloadp` は存在しない**:
  - `help.l` 内の `(let ((autoloadp (autoload-function-p def))) ...)` というローカル変数名を、グローバル関数だと誤認して `leader-tests.l`/`symbol-check.l` から呼んでいた。
  - **解決**: 実際の関数 `autoload-function-p`（シンボルを直接渡す）に置き換え。

### 3. テストスイートが「オールグリーン」を報告しつつ実は半分以上走っていなかった問題
- **要因**: `unittest/git-tests.l`（および `leader-tests.l`, `project-tests.l`, `symbol-check.l`）が存在しない `"unittest"` モジュールを `require` していた。さらに `misc/run-tests-batch.l` が `unittest/*-tests.l` を読み込む `dolist` ループ全体を1つの `handler-case` で囲んでいたため、アルファベット順で早い `git-tests.l` の読み込み失敗が、それより後ろの全ファイル（`leader-tests.l`, `project-tests.l` を含む）を黙ってスキップさせていた。CI/ローカルとも「682件成功」を報告していたが、実際には221件しか実行されていなかった。
- **解決**: `assert-true`/`assert-equal`/`assert-false` を提供する `unittest/test-helpers.l` を新設し、各テストファイルの誤った `require` を修正。`run-tests-batch.l` はファイル単位で `handler-case` するよう変更し、1本の破損が後続ファイルを道連れにしないようにした。
- **教訓**: `misc/run-tests-batch.l` のようなテストローダー自体が壊れていると、テスト対象のバグより先にテストが「走ったふりをする」。テストの件数が想定より少ない/多い変化に気づいたら、まずローダーのエラーハンドリング粒度を疑う。

### 4. `project.l` のパス正規化バグ（上記の隠蔽により発見が遅れていた）
- **要因**: `project-current-root` などが `(namestring (directory-namestring root))` という書き方をしていたが、`directory-namestring` の戻り値（末尾 `/` 付き）を再度 `namestring` に通すと末尾の `/` が消える。結果、`project-current-root` が `"Z:/work"` のような不正な値を返し、`project-list-files` の相対パス切り出しがずれて、`project-find-file`/`project-grep` がプロジェクト直下ではなくファイルシステムのルート付近を誤って走査していた。
- **解決**: `directory-namestring` の戻り値をそのまま使うよう、冗長な外側の `namestring` 呼び出しを `project.l` 内の7箇所すべてから削除。
- **教訓**: `directory-namestring` の結果を他のパス関数に再度通す前に、末尾スラッシュが保たれるか実機で確認すること。

### 5. `symbol-check.l` の `kill-xyzzy` 呼び出し位置
- **要因**: `with-open-file` の**内側**で `kill-xyzzy` を呼んでいたため、ストリームの close/flush（`with-open-file` の unwind-protect 由来）が走る前にプロセスが終了し、ログファイルが一度も実際に書き出されていなかった。
- **解決**: `kill-xyzzy` を `with-open-file` フォームの外に出した。
- **教訓**: バッチスクリプトで `kill-xyzzy` を呼ぶ際は、ファイル書き込み・バッファ flush が確実に完了した後であることを確認する。

### 6. `toggle-terminal-drawer` が初回起動時にフリーズしてターミナルが一切開かない
- **症状**: `Leader t t` を押しても何も起きない（エラーも出ない、ただ固まる）。
- **要因**: `get-buffer-window` に、**まだ存在しないバッファ名の文字列**（`"*Shell*"` のように、その名前のバッファが一つも無い状態）をそのまま渡すとハングする、という `get-buffer-window` 自体の挙動を踏んでいた。`toggle-terminal-drawer` の1行目 `(get-buffer-window "*Shell*")` は初回トグル時（`*Shell*` がまだ存在しない）に必ずこの条件に当たる。バッファオブジェクトを渡す、または既存バッファ名を渡す場合はハングしない（`(get-buffer-window (get-buffer-create "*Shell*"))` や `(get-buffer-window "*scratch*")` は問題なく `nil`/ウィンドウを返す）。
- **解決**: `get-buffer-create` で存在を保証したバッファオブジェクトを渡すよう `lisp/terminal.l` を修正。`unittest/git-tests.l` に、実際に `toggle-terminal-drawer` を呼んでシェルプロセスが `:run` になることを確認する回帰テストを追加した。
- **教訓**: `get-buffer-window` に生の文字列を渡すときは、そのバッファが存在するとは限らない場面で使わない。存在確認・存在保証 (`find-buffer`/`get-buffer-create`) を先に行うか、バッファオブジェクトを渡す。
- **副産物の発見（実害なし）**: デバッグ中に `get-buffer`（`get-buffer-create` ではなく無印）という関数を試しに呼んだところ、これも同様にハングした。**`get-buffer` は xyzzy に存在しない関数**（Emacs Lisp にはあるが xyzzy には無い）。今回のコードベースでは実際には使われていなかったが、Emacs の記憶で書くと踏みやすい地雷なので、存在確認せずに使わないこと（`find-buffer`/`get-buffer-create` を使う）。

### 7. `project-find-file`/`project-grep` が、環境によって「ほぼ何も見つからない」か「メモリ不足でクラッシュ」かのどちらかになっていた
- **経緯**: CI (PR #15) の MSVC x86 ジョブが `unittest/project-tests.l` の `test-project-list-files` 実行中に `xyzzy-batch: メモリ不足です` でクラッシュし、テストスイートが要約行を出せずに落ちた。llvm-mingw (Wine) の3ジョブは pass していた。
- **要因**: `project-collect-files-recursive` (旧実装) がサブディレクトリ列挙に `(directory dir :wild "*.*" :directory-only t)` を使っていた。**`"*.*"` がドットを含まない名前 (`lisp`, `docs`, `src`, `unittest` 等) にマッチするかどうかは環境依存**だと判明:
  - Wine 上で実測すると `"*.*"` はドット無しの名前にマッチせず、`lisp/` 等の通常ディレクトリへ一切降りて行けない。結果、リポジトリ全体で走査できたのはたった **11 ファイル** (トップレベルと `.claude`/`.github` の中身のみ)。`project-find-file`/`project-grep` は動くには動くが、対象のごく一部しか見えていなかった。
  - 実 Windows の Win32 `FindFirstFile` は MS-DOS 8.3 互換の古い仕様で `"*.*"` がドット無しの名前にも**マッチしてしまう**。結果、`.git` を除く全ディレクトリを本当に再帰的に総なめし (実測 **2708〜2709 ファイル**)、それを素朴な再帰 Lisp 関数 + `nconc` で積み上げるため、32bit プロセスの限られたヒープを食い潰してクラッシュしていた。
  - つまり**同じコードが Wine では「ほぼ何も見つからない」、実 Windows では「メモリ不足で落ちる」という、両方の環境で別々の壊れ方をしていた**。このセッションの動作確認は一貫して Wine 上だったため、前者の壊れ方しか見えず、CI で MSVC x86 が実際に走るまで気づけなかった。
- **解決**: `directory` 自身が持つ `:recursive t` + `:test` (ディレクトリに対して `:test` が nil を返すとその配下ごと無視される、公式ドキュメントにも `.git` 除外の例として載っている) に丸ごと任せる形に書き換え、`:wild` と手書きの再帰・`nconc` を廃止した (`project-list-files`、ヘルパーは `project-ignored-directory-p` のみに整理)。Wine 上で 2709 ファイル (`.git`/`_build` を正しく除外、`lisp/project.l` も検出) を確認済み。
- **教訓**: `directory` に `:wild` でワイルドカードを渡すときは、「ドットを含まない名前にマッチするか」を対象プラットフォームで必ず確認する。**再帰的に「配下を全部」欲しいときは `:wild` を使わず `:recursive t` + `:test` に任せる方が、動作の一貫性と実装の単純さの両方で勝る。** また、Wine 上の動作確認は MSVC 実 Windows ビルドの代わりにはならない — ファイルシステム API の細部 (この `"*.*"` の件のような) はエミュレーションで再現されないことがある。

---

## 5. テスト・ビルドの検証コマンド

作業時は以下のコマンドでビルドとテストを検証できます：

```bash
# 1. PE バイナリのビルド
tools/x build x86_64

# 2. 全 146 ファイルのバイトコンパイル (.lc 生成)
tools/x bytecompile x86_64 --force

# 3. 個別テストファイルの実行 (exe名を省略すると xyzzy-batch.exe に
#    そのままファイル名が渡ってしまい -l 相当のロードにならないので注意)
tools/x wine x86_64 xyzzy-batch.exe -q -l unittest/leader-tests.l
tools/x wine x86_64 xyzzy-batch.exe -q -l unittest/project-tests.l
tools/x wine x86_64 xyzzy-batch.exe -q -l unittest/git-tests.l

# 4. 全体テストスイートの実行 (misc/run-tests-batch.l 経由、
#    unittest/*-tests.l を一括ロードして known-failures と突き合わせる)
tools/x test x86_64
```

---

## 6. 次の AI への引き継ぎタスク (今後の作業方針)

1. ~~実機（Windows 環境）でのデプロイ・実動テスト~~ **完了**（作業者本人が実機で確認済み。その過程で「ターミナルドロワーが初回起動時にフリーズする」不具合が見つかり、上記トラブルシュート6として修正済み）。
2. **Phase 5: ミニバッファ UI / 補完のさらなる改善（一部完了、残りはオプション）**:
   - ~~`project-find-file`/`project-switch-project` でのファジーマッチング~~ **完了**。`lisp/fuzzy-complete.l` を参照 (上記③⑤)。
   - **未着手・見送り**: `M-x` (`execute-extended-command`) のファジー化。理由は上記③⑤の「意図的にやらなかったこと」を参照 — `read-command-name` はフックできず、エディタ最頻用コマンドの書き換えになるため別 PR での着手を推奨。
   - **未着手**: `completing-read` が引き続き使われている箇所 (`recentf-open` など) への同様の展開。今回は `project.l` の2箇所のみに留めた。
   - **手動確認が必要**: `fuzzy-completing-read` の対話ループ自体は自動テストできない (上記③⑤5.)。実機で `Leader p f`/`Leader p p` を実際に打鍵して、絞り込み・`C-n`/`C-p`/`TAB` 移動・`RET`/`C-g` の挙動を確認してほしい。
3. **PR のマージ・レビュー対応（CI チェック通過確認）**: `mingw` (Wine) ワークフローは commit `546b158` 時点で green を確認済みだが、**この時点では `Build` (MSVC) ワークフローは実行されていなかった/キャンセルされていた**。その後の commit (`78dcda7`) で `Build` ワークフローが初めて実際に走り、MSVC x86 が上記トラブルシュート7のメモリ不足でクラッシュすることが判明・修正した。**「mingw が green だから CI 通過」と早合点しないこと** — この PR には `mingw`・`Build` (MSVC x86/x64/ARM64) の両方が required check として設定されている。修正後の commit で両方の green を確認してから完了とすること。
4. **`uuid-create-4-seq`**: 解決済み扱いでよい。上記 CI run のログで `uuid-create-4-seq...OK`（x86_64/i686 両方）を確認済み。ローカル (Docker+Wine) 環境固有のタイミング差であり、known-failures への追加は不要と結論。
