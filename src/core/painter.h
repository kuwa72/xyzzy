// -*-C++-*-
#ifndef _painter_h_
# define _painter_h_

/*
 Painter — platform-neutral drawing interface (issue #195).

 The core's drawing code used to be written against the Win32 `HDC` (device
 context). `Painter` projects the operations the Win32 paint path
 (`paint_glyphs`/`paint_chars` in src/frontend/win32/disp.cc) and
 `src/core/utils.cc` (`fill_rect`/`draw_hline`) actually use onto a set of
 neutral primitives. Win32, ncurses, and a future GUI frontend each implement
 this interface.

 (This paragraph used to name a line range in disp.cc. Don't put line
 numbers in a comment in another file — the file has been edited many times
 since and the range no longer pointed at either function.)

 Current state: steps 1-5 are done.  Core's paint_* entry points all have a
 `Painter&` version and the `HDC` ones are thin wrappers around them (see
 src/core/Window.h); `paint_region`/`paint_glyphs` take no HDC at all.
 The remaining step is the wxWidgets GUI frontend — the checklist lives in
 issue #195, the plan in docs/dev/plans/2026-06-12-wx-frontend-step6.md.

 **Do not restate that checklist here.** This comment used to list
 "Step 1 (this file) / Step 2 / Step 3" and was never updated; it still said
 step 1 was current after step 5 had landed, and it was read as the truth
 (the mistake is recorded in issue #185).  A step list has to be either
 kept current or kept in one place — and one place is easier.

 Coordinates: x,y are pixels on a GUI/Win32 backend, character cells on
 ncurses. Callers stay in the same unit the backend reports via
 cell_width()/cell_height().

 Color: COLORREF (DWORD packed RGB) is reused for now; a struct RGBColor
 may replace it later (issue #195 open question).
*/

# include "cdecl.h"       // uint64_t, fixed-width int types
# include "platform.h"    // COLORREF, INT, DWORD, RECT

// Painter text primitives operate on glyph_t runs, not Char: a glyph
// carries a full 21-bit code point (GLYPH_CP, up to 0x110000) plus its
// display width, which Char (uint16_t) cannot represent. Each backend
// extracts the code point and does its own encoding (Win32: UTF-16
// surrogate pairs; ncurses: wchar_t). Mirrors Window.h.
typedef uint64_t glyph_t;

// draw_text flags (subset of the GLYPH_* attributes the Win32 path renders).
enum
{
  PAINT_BOLD      = 0x0001,
  PAINT_UNDERLINE = 0x0002,
  PAINT_STRIKEOUT = 0x0004,
};

// Font roles for draw_text_chars / text_chars_width (Char* runs drawn in a
// font other than the text-buffer glyph font: the mode line, the ruler,
// the terminal grid). Non-negative values are text_font charset slots
// (FONT_ASCII = 0, FONT_JP = 1, ...); negatives are app-level fonts.
enum
{
  PFONT_MODELINE = -1,
  PFONT_RULER    = -2,
};

struct Painter
{
  virtual ~Painter () {}

  // Text output (ExtTextOutW equivalent). `g`/`ge` is the glyph run to draw
  // in a single font slot; the backend extracts code points and widths and
  // does its own encoding (surrogate expansion, JUNK-trail skipping).
  // `charset` selects the font slot (FontSet FONT_* index, 0-15 on Win32).
  // `flags` carries PAINT_BOLD/UNDERLINE/STRIKEOUT. `clip` bounds the drawn
  // region; `opaque` fills the background with `bg` (false = transparent,
  // used for the bold overprint pass).
  virtual void draw_text (int x, int y, const glyph_t *g, const glyph_t *ge,
                          COLORREF fg, COLORREF bg, int charset,
                          unsigned flags, const RECT *clip, bool opaque) = 0;

  // Rectangle fill (PatBlt / ExtTextOut ETO_OPAQUE equivalent).
  virtual void fill_rect (int x, int y, int w, int h, COLORREF c) = 0;

  // Lines (3D border of the mode line; LineTo / 1px ExtTextOut equivalent).
  virtual void draw_hline (int x1, int x2, int y, COLORREF c) = 0;
  virtual void draw_vline (int x, int y1, int y2, COLORREF c) = 0;

  // Symbol-glyph bitmap blit (BitBlt from the glyph atlas equivalent).
  // `slot` selects the source glyph in the backend's atlas; the backend
  // knows the atlas geometry (cell width per slot). `cell_yoff` is the
  // vertical offset into the glyph cell to start from (non-zero for the
  // half-height cursor-line redraw). fg/bg colorize the 1bpp source.
  // GUI: blit from the atlas; ncurses: substitute character.
  virtual void blit_glyph_bitmap (int x, int y, int w, int h, int slot,
                                  int cell_yoff, COLORREF fg, COLORREF bg) = 0;

  // Font measurement (GetTextExtentPoint32 equivalent; e.g. mode-line
  // truncation).
  virtual int text_width (const glyph_t *g, const glyph_t *ge, int charset) = 0;

  // Draw a UTF-16 Char run in a non-glyph-buffer font (mode line / ruler /
  // terminal), selected by `font_role` (a text_font charset slot, or
  // PFONT_MODELINE / PFONT_RULER). x,y are the exact pixel origin including
  // any baseline offset (the caller adds it; this primitive stays uniform).
  // `opaque` fills the background; otherwise transparent. glyph_t buffer
  // text uses draw_text instead.
  virtual void draw_text_chars (int x, int y, const Char *s, int len,
                                COLORREF fg, COLORREF bg, int font_role,
                                const RECT *clip, bool opaque) = 0;
  virtual int text_chars_width (const Char *s, int len, int font_role) = 0;

  // Cell metrics (GUI: font cell in px; ncurses: 1).
  virtual int cell_width () const = 0;
  virtual int cell_height () const = 0;
};

#endif /* _painter_h_ */
