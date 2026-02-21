#ifndef _glyph_h_
#define _glyph_h_

// Glyph calculation functions (core/glyph.cc)
// Buffer content → glyph_data conversion, platform-independent.

glyph_t *glyph_dbchar (glyph_t *g, Char cc, int f, int flags);
glyph_t *glyph_sbchar (glyph_t *g, Char cc, int f, int flags);
glyph_t *glyph_bmchar (glyph_t *g, Char bm, lisp ch, int f, int n);

#define NO_MATCH 0
#define FULL_MATCH 1
#define HALF_MATCH 2
int compare_glyph (const glyph_data *g1, const glyph_data *g2, int offset);

void set_region (Region &r, point_t p1, point_t p2);

#endif
