# Phase 2 Step 5b: glyph_t 再設計 + Phase 3 shape 拡張の前提

**親計画:** `docs/plans/2026-04-19-unicode-migration.md` (Phase 2 section 2-4)
**Branch:** `unicode`
**Date:** 2026-04-19
**Status:** 設計合意、実装未着手

## 背景

Phase 2 Step 5a (commit `25c0662`) で buffer 内部表現を UTF-16 code unit に切り替えた。
display pipeline (`src/core/glyph.cc`, `src/frontend/win32/disp.cc`,
`src/frontend/win32/print.cc`) は依然として旧「internal encoding」
前提で動いており、Japanese 表示がこの時点で壊れている。本文書は
この cutover を完成させるための glyph_t 再設計を規定する。

## 旧 glyph_t の巧妙さと破綻

旧 `glyph_t` (32bit u_long) は SBCS 前提で巧妙に詰めてある:

```
 31..30  29...25   24 23 22 21   20..17  16  15 14 13  12..9  8  7..0
 ------ --------- --- -- -- --  ------- --- -- -- -- ------ -- ----
 cat    charset   SO UL IT BD   tp-bg   tfg  R  S  H  text   bm char
```

- `char` (bit 0-7): 8bit だけ。SBCS なら完結、DBCS は 2 glyph に
  lead/trail byte を分割格納する
- `charset` (bit 25-29): 5bit = 最大 32 charset。実際 GLYPH_CHARSET_*
  は 22 種類まで膨張
- `category` (bit 30-31): `SBCS / JUNK / DBCS_LEAD / DBCS_TRAIL`
  の 4 状態。paint_line は lead/trail で wide char 先頭を判定

この設計は「charset → offset が決まれば 8bit だけで code を復元可能」
という **SBCS 寄りの前提** で全域を 32bit に圧縮している。UTF-16 化で
narrow-non-ASCII (U+0100 以降) は 8bit に収まらず、charset に
block-offset を暗黙紐付けする拡張 (旧 GLYPH_CHARSET_ULATIN1/2 流) も
font slot が 4bit=16 個では BMP 全域カバーに届かない。

## Phase 2 新 glyph_t

**8 byte struct** に踏み切る:

```c
struct glyph_t
{
  u_int32_t code_point;    // bit 0-20  : Unicode code point 0x000000-0x10FFFF
                           //             (21bit 使用、bit 21-31 = 11bit 予約)
  u_int32_t metadata;      // 従来の属性 bitfield
};
```

### code_point 欄

- `0x000000-0x10FFFF` : 直接 code point
- **`0x110000-0x1FFFFF` は Phase 3 で shape_pool への ref に予約**
  (bit 20 = 1 が ref の目印)
- 11bit は将来拡張領域として残す (Phase 4 以降、例えば cluster 内
  continuation marker や SVG emoji ref 等)

surrogate pair は buffer 上は 2 code unit だが glyph としては 1 個に
まとめて code_point に non-BMP 値 (0x10000-0x10FFFF) で入れる。
cursor は code point 単位で動く (`point_t` セマンティクスは親計画 2-1 済)。

### metadata 欄 (u_int32_t)

旧 glyph_t から charset+category を外し、font_idx+width+JUNK を置く。
残りは旧配置を保存:

```
 31       30..29  28..25     24 23 22 21   20..17 16 15 14 13  12..9   8    7..0
 -------  ------  ---------  -- -- -- --   ------ -- -- -- --  ------  ---  ----
 JUNK     width   font_idx   SO UL IT BD   tp-bg  tfg R  S  H  text    bm   rsv
```

- `font_idx` (4bit, 0-15): `FONT_*` slot に直接対応。`get_font_idx(cp)`
  で算出。charset による間接 dispatch を廃止
- `width` (2bit): 0=combining/zero-width, 1=narrow, 2=wide, 3=reserved。
  `unicode_width(cp)` で算出
- `JUNK` (bit 31): 旧 GLYPH_JUNK の意味を維持 (未描画の padding)
- `SO/UL/IT/BD/tp-bg/tfg/R/S/H/text/bm`: 旧配置保存
- `bit 7..0`: 旧 `char` bits は code_point に移ったので **予約** (別用途で
  使えるが Phase 2 では 0)

旧 `GLYPH_LEAD` / `GLYPH_TRAIL` / `GLYPH_CATEGORY_MASK` は廃止。
paint_line は lead/trail を見ずに width + code_point から描画する。

### column vs glyph index

**1 glyph = 1 code point = 1 以上の column cell**。現行 `gd_len` は
column 数だったが、新設計では glyph 数。wide (width=2) は後続 column に
対応する実 cell を占有するが、`gd_cc[]` 配列上は 1 entry しか持たない。

paint_line / paint_glyphs は `g - gd_cc` ではなく「実 column 位置」を
累積計算して描画 x 座標を出す。具体的には paint_glyphs に
`column_of[]` or 内部的に advance 累積する形を追加。

cursor カラム計算・`w_top_column` 折り返し判定等 glyph 配列を
インデックスしていた箇所は、column 積算ヘルパに置換。

## Phase 3 拡張の前提 (ここで決めておくこと)

Phase 3 は shaping (ligature, 色絵文字, Arabic 文脈形, IVS 正字) を
導入する。GDI ExtTextOut を超える領域で、DirectWrite または HarfBuzz
がバックエンド候補。本 Phase 2 設計はこの先を殺さないことが要件。

### 拡張案: shape_pool への ref

```c
#define GLYPH_SHAPE_REF_MIN 0x110000u

struct shape_record
{
  u_int8_t  n_code_points;   // cluster 内 code point 数
  u_int8_t  n_glyphs;        // 出力 font glyph 数
  u_int8_t  cluster_cells;   // display 上の cell 数 (width 累積)
  u_int8_t  flags;           // color emoji 有無、RTL 等
  u_int32_t code_points[];   // 逆引き (選択 text 取得)
  u_int16_t glyph_ids[];     // HarfBuzz/DirectWrite 出力
  i_int16_t advances[];      // cell 単位でなく pixel
  i_int8_t  x_offsets[];
  i_int8_t  y_offsets[];
};
```

- glyph_t.code_point 欄に `GLYPH_SHAPE_REF_MIN + index` を格納
- cluster 占有 cell 数 = `shape_record.cluster_cells` を見て paint_line
  が進行。Phase 2 の width フィールドは 1 cluster=1 glyph の前提なので
  そのまま用いる (width = cluster_cells ≦ 3 の範囲に限定するか、
  width が 3 未満でも shape_record 側の cluster_cells を優先させるか
  は Phase 3 で決める)

### intern 設計

shape_record は線形 pool に追加、key でハッシュ dedup:

```
key_bytes = concat(code_points[], u8(font_idx), u16(features))
hash      = FNV-1a 32bit or xxhash32
```

- **pool 寿命**: Buffer 所有 (`Buffer::b_shape_pool`)。フォント変更時
  `flush`、バッファ kill 時解放。line 間で共有することで同じ
  合字・絵文字列の re-shape を回避
- **ref 安定性**: intern 済み entry は pool 寿命中 index 不変。
  `compare_glyph` は memcmp で成立 (ref も含めて単純比較)
- **GC 戦略**: 当面追加のみ、flush はフォント変更 / kill 時のみ。
  メモリ肥大が観測されたら LRU or mark-sweep を追加

### Phase 2 コードへの影響 (= 今決めておくこと)

- `code_point` 欄の値域を確認するヘルパを置く
  ```c
  static inline bool glyph_is_shape_ref(u32 cp) { return cp >= 0x110000u; }
  static inline u32  glyph_shape_ref_index(u32 cp) { return cp - 0x110000u; }
  ```
  Phase 2 時点で `glyph_is_shape_ref` は常に false。if で分岐する形を
  先に書いておけば Phase 3 で else 側を埋めるだけで済む
- paint_glyphs は fast path (code_point 直値) と slow path (shape ref)
  を分けられる構造にしておく。Phase 2 は slow path 未実装 = assert
- `compare_glyph` は変更不要 (memcmp のまま)
- `Buffer` に `b_shape_pool` を Phase 2 では追加しない (定義の雛形は
  作らない)。Phase 3 で clean に足せる

## 移行作業の順序 (Step 5b サブステップ)

- **5b-0** (本文書): 設計合意 ← 今ここ
- **5b-1**: `src/core/Window.h` で glyph_t 再定義、旧マクロ (GLYPH_CHARSET_*,
  GLYPH_LEAD/TRAIL, GLYPH_CATEGORY_MASK) 削除。`glyph_is_shape_ref`
  helper 追加。ビルドが通る状態に (paint 側は壊れる)
- **5b-2**: `src/core/glyph.cc` `glyph_dbchar` / `glyph_sbchar` を
  code point 引数に変更、`unicode_width` / `get_font_idx` 採用。
  `redraw_line` の Char\* 走査を UTF-16 code unit aware に (surrogate
  pair 合成、combining mark は後続 glyph として width=0 で並置)
- **5b-3**: `src/frontend/win32/disp.cc` `paint_glyphs` を font_idx 単位
  grouping に、`paint_chars` を charset 分岐から font_idx dispatch に、
  `paint_line` の lead/trail 検査廃止
- **5b-4**: `src/frontend/win32/print.cc` も同様に (print path)
- **5b-5**: ビルド + 起動 + 日本語ファイル表示で手動確認

5b-1 から 5b-4 は論理的に一続きなので **単一 commit** で入れる。
5b-0 は本 plan 追加の commit で先行させる (以下の5a直後)。

## 非機能事項

- メモリ: window 1 画面 glyph 数 200×100 = 20000 cells. 8byte glyph
  で 160KB (旧: 80KB, 2倍)。許容範囲
- 速度: code_point 直値 = paint_glyphs の fast path。ref 分岐は Phase 3
  でも cluster 先頭のみで分岐予測に優しい。旧 charset dispatch よりも
  switch-case が小さくなり速度面は中立〜わずかに改善を期待

## Phase 2 で諦めること (親計画 2-4 と同じ)

- ligature / kerning (DirectWrite 化で対応)
- 結合文字の正確な shaping (base+combining の位置合わせ)
- color emoji レンダリング
- RTL bidi (invisible reorder 文字可視化のみ軽量実装 = 別枝)
- IVS の正字選択

これらは Phase 3 の shape_pool 機構が揃ってから。

## 未解決の決定事項 (実装時に確定)

- **width=0 glyph の column 占有**: combining mark を base の隣に
  置く場合、gd_cc 配列上 2 entry だが column は 1。paint_line が
  column 累積で 0 足すだけで自然に処理できるはず。要実装時検証
- **`gd_len` の意味**: 今まで column 数 = glyph 数だったが、新設計では
  glyph 数。column 数が欲しい箇所は各 glyph の width を累積する
  helper を用意。call site の整理対象
- **compare_glyph の粒度**: 現行は memcmp 完全一致で、1 cell 差異でも
  NO_MATCH → 行全体 redraw。新 layout でも同じ方針。最適化は後日
- **fallback glyph の形**: code_point に対して font が持たない場合、
  Phase 2 は GDI 任せで豆腐 □ 表示。Phase 3 で font fallback
  (Segoe UI Emoji 等) を shape_pool で差し替える

## 参考

- 親計画: `docs/plans/2026-04-19-unicode-migration.md`
- EAW lookup: `src/core/eaw.{h,cc}`
- Font idx lookup: `src/core/fontmap.{h,cc}`
- 既存 glyph_t: `src/core/Window.h:4-158`
- 既存 paint dispatch: `src/frontend/win32/disp.cc:448-560`
