# ターミナルエミュレータ仕様

## 概要

xyzzy に VT100/xterm 互換ターミナルエミュレータを組み込む。
SSH やフルスクリーンアプリ (vim, htop, less 等) が実用的に動作するレベルを目標とする。
コア部分はフロントエンド非依存とし、ncurses / Win32 両方で利用可能な設計とする。

## アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│  Lisp                                            │
│                                                   │
│  (make-process ...)  ←→  process-filter           │
│  (process-send-string ...)                        │
│  (si:terminal-* ...)  ← 新規 Lisp API            │
│                                                   │
├─────────────────────────────────────────────────┤
│  C++ core                                         │
│                                                   │
│  Terminal クラス (src/core/term.cc)               │
│    - VT100 パーサー (状態マシン)                   │
│    - 仮想スクリーン (TermCell[rows × cols])       │
│    - Lisp API 実装 (si:terminal-*)               │
│    - フロントエンド非依存                          │
│                                                   │
├─────────────────────────────────────────────────┤
│  C++ frontend (フロントエンドごとに実装)           │
│                                                   │
│  ncurses:                                         │
│    render_terminal() — TermScreen → ncurses 描画  │
│    256 色 COLOR_PAIR マッピング                    │
│                                                   │
│  Win32 (将来):                                    │
│    render_terminal() — TermScreen → GDI 描画      │
│    または ConPTY に委譲                            │
│                                                   │
├─────────────────────────────────────────────────┤
│  C++ frontend (プロセス I/O)                      │
│                                                   │
│  ncurses: forkpty() → Terminal::feed()            │
│  Win32:   CreateProcess/ConPTY → Terminal::feed() │
│                                                   │
└─────────────────────────────────────────────────┘
```

## コンポーネント

### 1. Terminal クラス (C++, src/core/term.cc) — core 配置

VT100/xterm パーサー + 仮想スクリーン。フロントエンド非依存。

- **仮想スクリーン**: `TermCell[rows × cols]`、各セルに文字・前景色・背景色・属性
- **パーサー**: UTF-8 デコード + エスケープシーケンス状態マシン
- **対応シーケンス**:
  - CSI: カーソル移動、消去、行/文字挿入削除、スクロール、SGR色、スクロール領域
  - DEC private: 代替スクリーン (1049/47)、カーソル表示 (25)、アプリカーソルキー (1)
  - OSC: ウィンドウタイトル (消費のみ)
  - 色: 標準 8色 + bright 8色 + 256色 (フロントエンドが対応する範囲で表示)
- **依存**: `ed.h`, `wchar.h` のみ。ncurses / Win32 API に依存しない

### 2. フロントエンド描画

#### 共通インターフェース

`render_window()` にターミナルモード分岐を追加。

```
if (buffer がターミナルモード)
  → render_terminal() — フロントエンド固有の描画
else
  → 既存の glyph ベース描画
```

Terminal クラスが公開する描画用 API:
- `term_rows()`, `term_cols()` — スクリーンサイズ
- `term_cell(row, col)` → TermCell (文字, fg, bg, attrs, wide)
- `term_cursor_row()`, `term_cursor_col()` — カーソル位置
- `term_cursor_visible()` — カーソル表示状態

#### ncurses 実装 (ncurses-stubs.cc)

- TermCell.fg/bg → ncurses COLOR_PAIR (init_pair で動的確保)
- TermCell.attrs → A_BOLD, A_DIM, A_UNDERLINE, A_REVERSE
- TermCell.wide → setcchar + add_wch (全角文字)
- カーソル位置は Terminal.cursor_row/col から

色マッピング:
- TermCell の色インデックス: 0=default, 1-8=standard, 9-16=bright, 17-256=拡張
- ncurses が 256 色対応 (`TERM=xterm-256color`) → 256 色そのまま使用
- COLOR_PAIRS 上限 (通常 32767+) → fg×bg 組み合わせを動的に確保
- xyzzy の内部カラーシステム (16色) とは完全に独立

#### Win32 実装 (将来)

- ConPTY がある場合: ConPTY にバイトストリームを渡し描画は OS 側
- ConPTY がない場合 (XP/ReactOS): TermScreen → GDI で自前描画
  - TermCell.fg/bg → COLORREF (256 色テーブル)
  - ExtTextOutW でセル描画

### 3. プロセス統合

Process クラスに Terminal を保持。

データフロー:
```
pty read → raw bytes
  ├→ Terminal::feed()          … 仮想スクリーン更新 (常時)
  └→ process-filter (optional) … Lisp にも生データを渡す
```

- Process が pty を持つ → Terminal が自動的に付く
- Terminal は常に feed される（仮想スクリーンは常に最新）
- `process-filter` が設定されている場合: 生バイトをエンコーディング変換して Lisp にも渡す
- **描画モードの判定**: ウィンドウ → バッファ → プロセス → Terminal の有無で自動判定
  - Terminal があれば専用描画、なければ通常バッファ描画
  - 明示的なモード切替 API は不要

#### プロセス I/O はフロントエンド固有
- ncurses: `forkpty()` → master_fd → `read()` → `Terminal::feed()`
- Win32: `CreateProcess` + pipe/ConPTY → `ReadFile()` → `Terminal::feed()`

### 4. Lisp API (新規)

#### プロセス制御 (既存 API はそのまま動作)
- `(make-process ...)` — プロセス作成（ターミナルは自動で付く）
- `(process-send-string proc string)` — 入力送信（pty 経由）
- `(set-process-filter proc func)` — 出力フィルタ（生データ受信）
- `(set-process-sentinel proc func)` — 終了通知

#### ターミナル情報 (新規)
```lisp
;; ターミナル有無の判定
(si:process-terminal-p process)
  → t/nil (プロセスに Terminal が付いているか)

;; ターミナル画面読み取り
(si:terminal-screen-line process row)
  → 指定行の文字列を返す (Lisp string)

(si:terminal-screen-size process)
  → (values rows cols)

(si:terminal-cursor-position process)
  → (values row col)

;; ターミナルリサイズ
(si:terminal-resize process rows cols)
  → pty の TIOCSWINSZ も更新

;; ターミナル状態クエリ
(si:terminal-app-cursor-keys-p process)
  → t/nil (アプリケーションカーソルキーモードか)
```

#### キー入力 (Lisp 側で制御)

ターミナルバッファ用のキーマップを Lisp で定義。
C++ 側は「キーをエスケープシーケンスに変換してターミナルに送る」関数を提供するだけ。

```lisp
;; ターミナルバッファ用キーマップ
(defvar *terminal-mode-map* (make-keymap))

;; デフォルトバインド: 未定義キーは全てターミナルに送信
;; (キーマップの default binding として terminal-self-insert を設定)

;; C-c をエスケーププレフィックスとして予約
(define-key *terminal-mode-map* '(#\C-c #\C-c) 'terminal-send-ctrl-c)
(define-key *terminal-mode-map* '(#\C-c #\o)   'other-window)
(define-key *terminal-mode-map* '(#\C-c #\k)   'terminal-kill-process)
;; ユーザーが自由にカスタマイズ可能
```

C++ 側が提供する関数:
```lisp
;; キーをエスケープシーケンスに変換してプロセスに送信 (C++ 実装)
(si:terminal-send-key process key)
  ; 矢印キー → ESC [ A/B/C/D (アプリモード時は ESC O A/B/C/D)
  ; F1-F12, Home, End, PgUp, PgDn, Delete, Insert 等も変換
  ; 通常文字はそのまま UTF-8 で送信
```

キーマッピング (C++ 内部テーブル):
| キー | 通常モード | アプリカーソルモード |
|------|-----------|-------------------|
| ↑    | ESC [ A   | ESC O A           |
| ↓    | ESC [ B   | ESC O B           |
| →    | ESC [ C   | ESC O C           |
| ←    | ESC [ D   | ESC O D           |
| Home | ESC [ H   | ESC O H           |
| End  | ESC [ F   | ESC O F           |
| PgUp | ESC [ 5 ~ |                   |
| PgDn | ESC [ 6 ~ |                   |
| F1-F12 | ESC [ 11~ 〜 ESC [ 24~ |    |
| Delete | ESC [ 3 ~ |                 |
| Insert | ESC [ 2 ~ |                 |

### 5. バッファとの関係

- ターミナルバッファは**表示専用** — 通常の編集操作は無効
- バッファ内容は Terminal の仮想スクリーンから **読み取り可能** だが、描画は専用パスで行う
- スクロールバック（ターミナルからスクロールアウトした行）は将来的にバッファに蓄積
  - 現状はスクロールバックなし（仮想スクリーンのみ）
  - 代替スクリーン使用時はスクロールバックを溜めない

#### 複数ウィンドウから同一バッファを表示する場合

- ターミナルサイズは **selected window のサイズに追従**
  - 入力できるのは selected window だけなので、そこに合わせる
  - 他のウィンドウは同じ仮想スクリーンをクリップ表示（はみ出し分は非表示）
- `C-x o` でターミナルバッファの別ウィンドウに移動した場合:
  - 新しいウィンドウのサイズで `Terminal::resize` + `TIOCSWINSZ`
  - 子プロセスに SIGWINCH が自動送信される
- 仮想スクリーンは常に1つのサイズ（複数サイズの同時管理は行わない）

### 6. ウィンドウリサイズ

エディタウィンドウのサイズが変わった場合:
1. `Window::compute_geometry()` で新しいサイズを検出
2. `Terminal::resize(new_rows, new_cols)` で仮想スクリーンをリサイズ
3. `ioctl(master_fd, TIOCSWINSZ, &ws)` で pty にサイズ通知
4. 子プロセスに `SIGWINCH` が自動送信される

## 既存コマンドとの関係

### 現状の shell 関連コマンド

| コマンド | キー | 動作 |
|---------|------|------|
| `run-console` | `C-x c` / メニュー「NTプロンプト」 | Win32: 外部 cmd.exe、Unix: `execute-subprocess` |
| `shell` | `M-x shell` | `make-process` で対話シェル (`*Shell*` バッファ) |
| `execute-subprocess` | `C-x &` | `make-process` で非同期プロセス実行 |
| `pipe-command` | `C-x @` | `call-process` で同期実行、出力キャプチャ |
| `filter-buffer` / `filter-region` | `C-x #` / `C-x \|` | バッファ/領域をコマンドでフィルタ |

### ターミナルエミュレータの適用範囲

`make-process` 経由 (pty 付き) で起動されたプロセスが自動的にターミナル描画対象:
- `M-x shell` → ターミナル描画
- `execute-subprocess` → ターミナル描画
- Unix 版 `run-console` → `execute-subprocess` 経由なのでターミナル描画

同期実行の `call-process` (`pipe-command`, `filter-*`) は対象外（pty なし）。

### M-x shell の段階的置き換え

現在の `shell.l`:
- `shell-mode`: 行入力モード (`shell-send-input` で RET 押下時に行送信)
- エスケープシーケンスは生表示
- vim, less 等のフルスクリーンアプリは動作しない

ターミナル対応後:
- `shell-mode` を拡張し、プロセスに Terminal がある場合は `*terminal-mode-map*` を使用
- 行入力ではなくキーごとにターミナルに送信 (`terminal-self-insert`)
- `C-c` プレフィックスでエディタコマンドにアクセス
- 既存の `shell-send-interrupt` (`C-c C-c`) はそのまま維持

移行方針:
1. 最初は `terminal-shell` として別コマンドで提供
2. 安定したら `M-x shell` のデフォルト動作を切り替え
3. 従来の行入力モードも `*shell-line-mode*` 等で残す（パイプ接続時用）

## ファイル配置

```
src/core/term.h         Terminal クラス定義、TermCell 構造体
src/core/term.cc        Terminal 実装 (パーサー, スクリーン操作)
src/core/term-lisp.cc   Lisp API (si:terminal-*)

src/frontend/ncurses/ncurses-stubs.cc   render_terminal() 追加
src/frontend/ncurses/ncurses-process.cc Process → Terminal 統合

src/frontend/win32/win32-term.cc        (将来) Win32 描画
```

現在の `ncurses-term.cc` は `src/core/term.cc` に移動。
`sync_to_buffer()` は削除し、フロントエンド側の直接描画に置き換える。

## 実装順序

### Phase 1: core 分離 + 専用描画
- Terminal クラスを `src/core/` に移動
- `render_window()` にターミナルモード分岐追加
- TermScreen → ncurses 直接描画（256色対応）
- Process からターミナルモードを判定するフラグ

### Phase 2: Lisp API
- `si:process-terminal-p`
- `si:terminal-screen-line`
- `si:terminal-screen-size`
- `si:terminal-cursor-position`
- `si:terminal-resize`
- `si:terminal-app-cursor-keys-p`

### Phase 3: キー入力
- `si:terminal-send-key` (C++: キー→エスケープシーケンス変換)
- `*terminal-mode-map*` (Lisp: ターミナルバッファ用キーマップ)
- `terminal-self-insert` (Lisp: 未定義キーをターミナルに送る default binding)
- C-c プレフィックス (Lisp: エディタコマンドへのエスケープ)

### Phase 4: リサイズ連動
- ウィンドウサイズ変更 → Terminal::resize + TIOCSWINSZ
- 分割ウィンドウ対応

### Phase 5: スクロールバック
- スクロールアウトした行をバッファに蓄積
- 上にスクロールして過去の出力を閲覧可能
- Shift+PgUp/PgDn でスクロールバック操作
- 代替スクリーン使用時はスクロールバックを溜めない

## 制約・前提

- ターミナル描画は xyzzy の内部カラーシステム (16色) を使わない
  - ncurses: COLOR_PAIR を直接使用 → 256 色対応
  - Win32: COLORREF を直接使用 → 256 色対応
- ターミナルサイズは pty/ConPTY と同期
- true color (24bit RGB) は非対応（256色パレットにフォールバック）
- Terminal クラス自体はプラットフォーム非依存（core 配置）
- プロセス I/O とウィンドウ描画はフロントエンド固有
