# xyzzy UTF-16LE 内部化 + tree-sitter 組込み 設計書

**Branch:** `unicode` (parent: `modern`)
**Date:** 2026-04-19
**Status:** 設計合意、実装未着手

## 背景と動機

xyzzy の内部バッファエンコーディングは現在 SJIS を 16bit `Char` 型に引き伸ばして格納している (`typedef u_int16_t Char` @ `src/core/cdecl.h:62`、SBCP/DBCP 判定 @ `src/core/chtype.h`)。これを**UTF-16LE code unit** に切り替える。

**UTF-16LE 化の動機:**
- 絵文字・CJK拡張領域・ハングル・各種スクリプトのネイティブ対応
- Windows API (W系) との ABI 一致 — `Char*` を `(LPCWSTR)` キャストで直渡し可能
- tree-sitter 組込みで byte offset 変換が O(1) になる (`Char数 × 2`)
- .NET/dotcl との文字列やり取りが変換なし
- LSP プロトコル (UTF-16 code unit 基準) との親和

## ブランチ戦略

```
develop ─── modern ──────────────────(SJIS のまま維持)
                   ╲
                    unicode ─ Phase 1 ─ Phase 2 ─ Phase 3 ─ tree-sitter MVP ─▶ 判定点
```

`modern` は SJIS 継続ラインとしてフォールバック用に温存。`unicode` で実験を進め、2段階のゲートで merge 可否を判定。

### 判定ゲート

**Gate 1: unicode 単体の成立**
- 絵文字・non-BMP 文字が正しく表示される
- 速度が許容範囲
- 通過 → tree-sitter 抜きでも `unicode` を merge 候補に
- 不通過 → `unicode` を葬り `modern` (SJIS) を継続

**Gate 2: tree-sitter の実用性**
- Gate 1 通過後に tree-sitter 統合 MVP
- 通過 → tree-sitter 同梱で確定
- 不通過 → tree-sitter を棚上げ、unicode は単体で採用

## 互換性ポリシー

外部ユーザ向け互換シム・warning・移行ガイドは作らない。xyzzy 用に Lisp を書く外部ユーザを想定しない方針 (詳細: `project_compat_policy.md`)。
内部の `lisp/*.l`, `contrib/**/*.l` の整合だけ grep で追う。

ただし**永続化データ** (`.xyzzy.history`, `.xyzzy.resume.*` 等) は既存ユーザデータが壊れないよう codec 層で透過デコードする。

---

# Phase 順序

1. **Phase 1**: modifier → `lChar` 昇格 (キー処理・Lisp 文字オブジェクト)
2. **Phase 2**: バッファ UTF-16LE 化 + codec 層整理 + Windows W系 API 完全移行 (ここで tree-sitter 着手可能)
3. **Phase 3**: Lisp 文字列 UTF-32 化 (共有切り離し、境界変換層追加)
4. **Phase 4**: クリーンアップ (A系 API パス削除、死にコード除去、regexp/search 再検証)
5. **tree-sitter MVP** → Gate 2

---

# Phase 1: modifier → `lChar` 昇格

## 目的

現行 `Char` (16bit) に混在している「キーバインド modifier」「関数キー」「マウスイベント」を分離し、32bit `lChar` 型に正式に移す。Phase 2 以降で `Char` が純テキスト (UTF-16 code unit) として解放される前提。

## 現状の混在

`src/core/chtype.h:25-34`:
- `CCF_SHIFT_BIT = 0x0040`
- `CCF_CTRL_BIT = 0x0080`
- `CC_META = 0xf800` (Unicode 私用領域占有)
- function keys: `0xff00-0xff3e` (同じく私用領域)
- マウスイベント: 0x10000+ (既に `lChar` に退避済)

## `lChar` bit layout

```
 31..28    27  26  25  24   23..21    20..0
┌────────┬───┬───┬───┬───┬─────────┬──────────────────────┐
│ 予約   │Met│Alt│Ctl│Shf│  kind   │  payload (21 bit)    │
│ (4bit) │   │   │   │   │ (3 bit) │                      │
└────────┴───┴───┴───┴───┴─────────┴──────────────────────┘
```

- **予約 4bit (28-31)**: Win / Super / Hyper / keyup 等の将来拡張
- **modifier 4bit (24-27)**: Shift / Ctrl / Alt / Meta 別持ち (Alt=Meta 統合せず)
- **kind 3bit (21-23)**: 0=Unicode char, 1=function key, 2=mouse, 3=IME, 4..7=予約
- **payload 21bit (0-20)**: Unicode full range 0x0000-0x10FFFF または kind 別の ID 空間

```c
#define LCHAR_PAYLOAD(lc)  ((lc) & 0x1FFFFF)
#define LCHAR_KIND(lc)     (((lc) >> 21) & 0x7)
#define LCHAR_MODS(lc)     (((lc) >> 24) & 0xFF)

#define LCMOD_SHIFT  0x01000000
#define LCMOD_CTRL   0x02000000
#define LCMOD_ALT    0x04000000
#define LCMOD_META   0x08000000

#define LCKIND_CHAR   (0 << 21)
#define LCKIND_FNKEY  (1 << 21)
#define LCKIND_MOUSE  (2 << 21)
#define LCKIND_IME    (3 << 21)
```

## 関数キー採番

**案Y: 0 起算で再採番** (現行 `0xff00-0xff3e` 値は捨てる)

```c
#define LCKEY_F1      (LCKIND_FNKEY | 0x01)
#define LCKEY_F2      (LCKIND_FNKEY | 0x02)
// ...
#define LCKEY_LEFT    (LCKIND_FNKEY | 0x40)
```

互換シム不要方針のため、数値直書きがある場所は grep で潰す。

## マウス座標の扱い

**Phase 1 では最小対応、本格設計は後日**。

構想: シングルスレッド前提を活かし、1 クリックあたり X上位/X下位/Y上位/Y下位 の 4 連続 `lChar` をキューに積んで座標 16+16bit を伝達する方式。`kind` 空間に `MOUSE_BUTTON`, `MOUSE_COORD_X_HI`, `MOUSE_COORD_X_LO`, `MOUSE_COORD_Y_HI`, `MOUSE_COORD_Y_LO` 等を割り当て可能。

## 影響ファイル

- `src/core/chtype.h` — modifier/kind constant の再定義
- `src/core/kbd.cc` — WM_CHAR/WM_KEYDOWN 受理、Queue 積み
- `src/core/fnkey.cc` — 関数キー ID テーブル
- `src/core/event.cc` — イベントディスパッチ
- `src/core/cmds.*` / keymap 関連 — キーマップデータ構造
- Lisp 側: `(kbd ...)` reader、`char-code`, `code-char` 等

---

# Phase 2: バッファ UTF-16LE 化 + codec + W系 API 完全移行

## 目的

`Char` (u_int16_t) を **UTF-16LE native-endian code unit** として再定義。バッファ Chunk の `c_text` を UTF-16 code unit 列として扱う。Windows W系 API 直渡しを可能にする。

## (2-1) `point_t` セマンティクス

**`point_t` = code point 数** (code unit 数ではない)。

- `(point)`, `(buffer-size)` は文字数 (code point 数) を返す
- サロゲート中間位置は表現不能 — 常に code point 境界で進む
- traversal は chunk の summary (後述 `c_nchars`) を引きながら chunk 単位で、最後の chunk で先頭から文字数を数える既存スタイルを踏襲

### `Chunk` 構造体の拡張

```c
struct Chunk {
  Char c_text[4096];     // UTF-16 code unit
  u_char *c_breaks;      // 既存 (per code unit の折返しビットマップ)
  short c_used;          // 既存 (使用 code unit 数)
  short c_nchars;        // 新規 (使用 code point 数)
  short c_nlines;        // 既存
  short c_nbreaks;       // 既存
  short c_first_eol;     // 既存
  short c_last_eol;      // 既存
  Char c_bstrch;         // 既存
  Char c_estrch;         // 既存
  u_char c_bstate;       // 既存
  u_char c_estate;       // 既存
  Chunk *c_prev, *c_next;
};
```

### 外部連携コスト

point_t → code unit index 変換が tree-sitter edit 通知・Windows API cursor 位置・LSP 連携で必要。chunk traversal で O(chunks)。必要に応じて `b_point_to_code_unit(point_t)` helper をキャッシュ付きで用意。

## (2-2) codec 層の再構築

### 命名リネーム: `internal` → `utf16`

現行の `xxx_to_internal_stream` / `internal_to_xxx_stream` を `xxx_to_utf16_stream` / `utf16_to_xxx_stream` に改名。内部は native-endian UTF-16 なので単に `utf16`、外部ファイル系は `utf16le` / `utf16be` を維持。

### 各 codec の動作

| codec | 動作 |
|---|---|
| `sjis_to_utf16_stream` | SJIS byte → CP932 map → Unicode code point → UTF-16 code unit |
| `utf8_to_utf16_stream` | UTF-8 → code point → UTF-16 code unit (non-BMP はサロゲートペア) |
| `utf16le_to_utf16_stream` | pass-through (native=LE なので memcpy) |
| `utf16be_to_utf16_stream` | byte swap |
| `iso2022_*`, `euc*`, `big5_*`, `iso8859_*`, `windows_codepage_*` | 各コードページ → Unicode → UTF-16 |

### 共通 helper

`xbuffered_read_stream` / `xwrite_stream` に `emit_code_point()` / `consume_code_point()` を仕込み、各 codec の責務を「byte ⇔ code point」に限定。サロゲート encode/decode は helper 内で完結。

```c
void emit_code_point(u_int32_t cp) {
  if (cp <= 0xFFFF) {
    emit(cp);
  } else {
    cp -= 0x10000;
    emit(0xD800 | (cp >> 10));
    emit(0xDC00 | (cp & 0x3FF));
  }
}
```

### その他

- `fast_sjis_to_internal_stream` は `sjis_to_utf16_stream` に統合 (UTF-16 化で速度優位が消滅)
- Chunk 末尾でサロゲート分断の恐れがある場合、emit 前に `flush` して次 chunk に押し込む
- エラー処理ポリシー (無効 byte, non-representable code point) は**現挙動維持**、実装時に確認

## (2-3) Chunk 境界とサロゲート不変条件

### 不変条件

1. Chunk 境界は常に code point 境界。High surrogate + low surrogate が chunk を跨がない
2. Chunk 内の任意位置 (c_breaks ビット等) も code point 境界
3. 挿入・削除は pair を壊さない (入力側で pair 保証されている前提)

### 追加 helper

```c
int cp_to_cu_in_chunk(const Chunk *c, int cp);    // O(cu)
int count_code_points(const Char *p, int ncu);
bool is_code_point_boundary(const Chunk *c, int cu);
int safe_split_offset(const Chunk *c, int target_cu);
```

いずれも `src/core/insdel.cc` / `src/core/Buffer.h` で完結。

## (2-4) Display / Font 選択 — 案 P (最小対応)

### 方針

GDI + ExtTextOutW 継続。charset (SBCP/DBCP) ベースのフォント切替を **Unicode 範囲ベース**に置換。

### `glyph_t` 拡張

```c
struct glyph_t {
  u_int32_t code_point;    // 0x0000-0x10FFFF (surrogate pair 結合済)
  u_int16_t color_idx : 4;
  u_int16_t width     : 2; // 0 (combining) / 1 (narrow) / 2 (wide)
  u_int16_t font_idx  : 4;
  u_int16_t flags     : 6;
};
```

1 glyph = 1 code point (surrogate pair は 1 glyph にまとめる)。

### East Asian Width テーブル

UCD `EastAsianWidth.txt` から:
- `W`/`F` → 幅 2
- `N`/`Na`/`H` → 幅 1
- `A` (ambiguous) → 設定で 1 or 2 (デフォルト 2、xyzzy 流儀)
- 結合文字 (`General_Category=Mn/Me/Mc`) → 幅 0

xyzzy に組込む形式: Run-length 圧縮で 1〜2 KB。

### フォント範囲設定

```lisp
(setq unicode-font-ranges
  '((#x0000 #x007F "Consolas")
    (#x3040 #x30FF "MS Gothic")
    (#x4E00 #x9FFF "MS Gothic")
    (#x1F600 #x1F64F "Segoe UI Emoji")))
```

### Phase 2 で諦めるもの

- ligature / kerning
- 結合文字の正確な配置 (基底+combining の shaping)
- emoji color rendering
- RTL bidi 本格対応 (Trojan Source 対策の**invisible reorder 文字可視化**のみ軽量実装)

本格的な shaping・bidi・DirectWrite 化は **Phase 2 の Gate 通過後の別プロジェクト**として切り出す。

## (2-5) Windows API W系完全移行

### 原則

xyzzy の `Char` (u_int16_t) と Windows の `WCHAR` (u_int16_t UTF-16LE) は layout 完全一致 → **`(LPCWSTR)(const Char*)` キャスト直渡し**。これが UTF-16LE native-endian 採用の最大の実利。

### 層別扱い

| 領域 | ファイル | 扱い |
|---|---|---|
| ファイル I/O | `vfs.cc`, `pathname.cc` | 全面 W系化 |
| ダイアログ | `ldialog.cc`, `printdlg.cc`, `dialogs.cc` | W系化 |
| 設定 | `conf.cc` | W系化 |
| CLI stubs | `cli-stubs.cc` | Phase 2 範囲外の可能性 (console I/O が byte 系)、要確認 |
| clipboard | `clipboard.cc` | CF_UNICODETEXT 優先 |
| IME | `gime.cc`, `kbd.cc` | `xImmGetCompositionStringW` パス固定 |
| print | `print.cc` | 既に W系、周辺 A系を削除 |
| subprocess | `process.cc`, `DnD.cc` | byte level 維持 (外部プロセスのエンコーディング不定) |
| window/menu | `wndproc.cc` 他 | W系 |

### `wconv.h` の縮退

`XYZZY_CP932` ラッパーは A系→W系変換用の過渡的装置。大半が identity macro に退化し、順次削除。subprocess 引き渡し / 特定 codepage 出力用のみ残す。

### 作業量

単純置換が 100+ 箇所。真に設計判断が要るのは subprocess / plugin 境界のみ。

## (2-6) 永続化データ互換

xyzzy の session / history / resume は **Lisp source (.l ファイル) として保存**される (`lisp/history.l`, `lisp/session.l`)。`Encoding:` ヘッダで codec 自動判定。

**結論**: (2-6) は (2-2) codec 層が動けば透過的に移行される。Phase 2 固有の追加設計判断なし。

実装時の確認事項:
- `Encoding:` 宣言のない古い history ファイルのフォールバック encoding
- resume 系一時ファイルが Lisp source か否か

## (2-7) Regexp / Search 再検討

### 現状

- `regex.cc` の `charclass` は 256×256 hi/lo bitmap (8KB) — 偶然 BMP 全域に流用可能
- `search.cc` の BM テーブルは 256 entry、hash は `DBCP(c) ? c >> 8 : c` (8 箇所)

### Phase 2 の対応

- **atom = UTF-16 code unit**: `.` は 1 code unit にマッチ、non-BMP はサロゲートペア扱い (JavaScript/Java と同じ制約)
- `regex.cc`: 大半そのまま。atom 意味論のコメント更新と小修正
- `search.cc`: BM ハッシュを `c & 0xFF` に置換 (256 entry 維持、メモリ不変)

### Phase 2 で諦めるもの

- Unicode property (`\p{Letter}` 等)
- Unicode case folding
- grapheme 単位マッチ
- CJK 対応 word boundary

本格 Unicode 正規表現は将来 PCRE2/RE2 入替検討で対応。

---

# Phase 3: Lisp 文字列 UTF-32 化

## 目的

Lisp の `string` 要素型を **UTF-32 code point** に切替。`(length s)` が code point 数を返す、`(schar s i)` が code point を返す、サロゲートが API に漏れない、の正常化。

## 実装

```c
// 新型
typedef u_int32_t Char32;

// xstring_contents のシグネチャ変更
Char32 *xstring_contents(lisp s);   // u_int32_t* を返す (旧: Char*)
```

`xstring_contents` の signature 変更で compiler error が全 callsite に出る → 機械的に移行 (grep より確実)。

## バッファ↔文字列 変換 API (eager decode/encode)

```c
lisp make_string_from_range(Buffer *bp, point_t from, point_t to);
lisp make_string_utf32(const Char32 *cps, size_t ncps);
lisp make_string_utf16(const Char *units, size_t nunits);  // 自動 decode

void insert_code_points(Buffer *bp, point_t at, const Char32 *cps, size_t n);
```

BMP のみの `buffer-substring` 1MB で 1〜2ms の decode コスト増。体感圏外。

## base-string 最適化なし

SBCL 型の ASCII-only 8bit 表現は**やらない**。string header に tag byte の予約もしない。必要になってから再設計。

## `char-code` 意味変化

`(char-code #\あ)` が `0x82A0`(SJIS) → `0x3042`(U+3042) に変わる。**外部ユーザ互換不要方針**のため compat 関数は作らない。

### 確認対象

xyzzy 同梱の `lisp/*.l`, `contrib/**/*.l` 内で以下を grep:
- `#x[89a-f][0-9a-f]{3}` 等、SJIS 数値直書き
- `char-code-limit` 依存 (`65536` → `1114112`)
- ビット演算による文字コードマスク

---

# Phase 4: クリーンアップ

- A系 Windows API 呼び出し経路の死にコード削除
- `wconv.h` 最小化
- SBCP/DBCP マクロ (`chtype.h:193-194`) 完全除去
- charset 関連 glyph フラグ除去
- regexp/search エッジケース再検証 (non-BMP 含む)
- テストスイートの Unicode 対応 (絵文字・non-BMP の入出力)

---

# tree-sitter MVP (Gate 2)

Phase 2 完了時点で着手可能。外部調査済み (`tmp/ts-api.h` にヘッダキャッシュ)。

## 組込み戦略

- **ランタイム**: `lib/src/lib.c` 1 ファイル統合ビルド (C99, MIT, 外部依存なし)
- **grammar**: 動的ロード方式 (Emacs 29+ の `libtree-sitter-<lang>.dll` 規約踏襲、`tree_sitter_<lang>()` を `GetProcAddress`)
- **初期同梱**: JSON (27KB), elisp (216KB), scheme (301KB), toml (130KB) あたり。C++ (25MB) / TypeScript (8MB) は除外
- **ABI version**: tree-sitter CLI バージョン固定で `parser.c` を自前再生成、本体 bump と同期

## xyzzy ↔ tree-sitter ブリッジ

- `TSInput` コールバックで Chunk の `c_text` をチャンク単位で供給
- UTF-16LE 直渡し (`TSInputEncodingUTF16LE`)
- `TSPoint` の column は UTF-16 code unit 数 (xyzzy の内部 code unit と一致)
- `ts_tree_edit` の `start_byte` / `old_end_byte` / `new_end_byte` は `code_unit_index * 2` で算出
- 並列: `ts_tree_copy` (refcount、安い) で別スレッドに渡す

## 実行モデル

- **メインスレッド同期 + 10ms 程度のタイムアウト刻み**を最初の採用
- `ts_parser_set_timeout_micros()` or `TSParseOptions.progress_callback` で協調キャンセル
- 未完了時は再描画で段階的に色が更新される方式
- 大きいファイル (10MB+) で辛くなれば非同期化 (ワーカースレッド化) 検討

## ハイライト

- grammar 同梱の `queries/highlights.scm` を読み、`ts_query_new` でコンパイル
- `ts_query_cursor_exec` で可視範囲の capture を取得
- 色決定は Lisp 層の face マップに委ねる
- 既存 `syntax-table` / state machine 着色 (`syntaxinfo.h`) との共存: **tree-sitter をオプトイン** で、モードごとに採用可否を切替

## Gate 2 判定材料

- 大きいファイルでの parse + query 応答時間
- メインスレッド占有時間の実測
- encoding 変換のボトルネック化の有無 (事前予想: parse 自体がボトルネック、encoding は誤差)
- grammar ABI drift 時の運用コスト

---

# 関連メモリ

- `project_modern_branch.md` — modern / unicode のブランチ戦略とゲート
- `project_compat_policy.md` — 外部ユーザ互換シム不要方針
- `project_cl_rpc.md`, `project_dotcl.md`, `project_goals.md` — 関連プロジェクト
- `tmp/ts-api.h` — tree-sitter v0.26 ヘッダキャッシュ

---

# 未解決・将来課題

- grapheme cluster (UAX #29) ベースのカーソル移動・削除
- Normalization Form (NFC/NFD) のハンドリング
- 本格 RTL bidi (Uniscribe or DirectWrite)
- Unicode case folding (Turkish dotless i, ß 等)
- Line breaking (UAX #14) 和文禁則
- IVS (Ideographic Variation Selector) の正しい表示
- ligature (DirectWrite 化案件)
- Unicode property 付き正規表現 (PCRE2 / RE2 入替)
- プリンタ出力 (`print.cc:810-920`) の UTF-16 動作検証
