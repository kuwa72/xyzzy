#ifndef _glyph_h_
#define _glyph_h_

#include "font.h"

// Glyph calculation functions (core/glyph.cc)
// Buffer content → glyph_data conversion, platform-independent.

// 5b-2: Phase 2 で cp は UTF-16 由来の Unicode code point (uint32_t、
// surrogate pair は呼び元で 0x10000-0x10FFFF に合成済)。glyph_dbchar は
// 表示幅 2 (wide)、glyph_sbchar は幅 1/0 (narrow / combining) を期待する。
glyph_t *glyph_dbchar (glyph_t *g, uint32_t cp, int f, int flags);
glyph_t *glyph_sbchar (glyph_t *g, uint32_t cp, int f, int flags);
glyph_t *glyph_bmchar (glyph_t *g, Char bm, lisp ch, int f, int n);

// 5b-2/5b-3: ASCII narrow 1 cell の glyph_t 値。code point + FONT_ASCII +
// width=NARROW を一括して付与。低 8 bit の char byte は 5b-3 で paint が
// GLYPH_CP に切り替えるまでの後方互換のため残してある。
static inline glyph_t
glyph_ascii_cell (uint32_t cp)
{
  return ((glyph_t) cp
          | MAKE_GLYPH_CP (cp)
          | MAKE_GLYPH_FONT (FONT_ASCII)
          | GLYPH_WIDTH_NARROW);
}

#define NO_MATCH 0
#define FULL_MATCH 1
#define HALF_MATCH 2
int compare_glyph (const glyph_data *g1, const glyph_data *g2, int offset);

void set_region (Region &r, point_t p1, point_t p2);

#endif
