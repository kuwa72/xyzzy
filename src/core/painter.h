// -*-C++-*-
#ifndef _painter_h_
# define _painter_h_

/*
 Painter — platform-neutral drawing interface (issue #13).

 The core's drawing code is being decoupled from the Win32 `HDC` (device
 context). `Painter` projects the operations the Win32 paint path
 (src/frontend/win32/disp.cc `paint_glyphs`/`paint_chars`, around 403-748)
 and `src/core/utils.cc` (`fill_rect`/`draw_hline`) actually use onto a set
 of neutral primitives. Win32, ncurses, and a future GUI frontend each
 implement this interface.

 Phase (issue #13):
   Step 1 (this file) — interface only, unused, zero build impact.
   Step 2 — Win32Painter implementation, added alongside the existing
            HDC path and verified for pixel equivalence.
   Step 3 — core `paint_*(HDC)` switched to `paint_*(Painter&)`.

 Coordinates: x,y are pixels on a GUI/Win32 backend, character cells on
 ncurses. Callers stay in the same unit the backend reports via
 cell_width()/cell_height().

 Color: COLORREF (DWORD packed RGB) is reused for now; a struct RGBColor
 may replace it later (issue #13 open question).
*/

# include "cdecl.h"       // Char
# include "platform.h"    // COLORREF, INT, DWORD, RECT

typedef u_int64_t glyph_t; // mirror of Window.h; painter primitives take Char

// draw_text flags (subset of the GLYPH_* attributes the Win32 path renders).
enum
{
  PAINT_BOLD      = 0x0001,
  PAINT_UNDERLINE = 0x0002,
  PAINT_STRIKEOUT = 0x0004,
};

struct Painter
{
  virtual ~Painter () {}

  // Text output (ExtTextOutW equivalent). `s`/`len` is the run to draw in
  // a single font slot. `padding` is the per-character advance array used
  // for variable-width / fullwidth layout (may be 0 for fixed advance).
  // `charset` selects the font slot (FontSet FONT_* index, 0-15 on Win32).
  // `clip` bounds the drawn region (background fill included when opaque).
  virtual void draw_text (int x, int y, const Char *s, int len,
                          COLORREF fg, COLORREF bg, int charset,
                          unsigned flags, const INT *padding,
                          const RECT *clip, bool opaque) = 0;

  // Rectangle fill (PatBlt / ExtTextOut ETO_OPAQUE equivalent).
  virtual void fill_rect (int x, int y, int w, int h, COLORREF c) = 0;

  // Lines (3D border of the mode line; LineTo / 1px ExtTextOut equivalent).
  virtual void draw_hline (int x1, int x2, int y, COLORREF c) = 0;
  virtual void draw_vline (int x, int y1, int y2, COLORREF c) = 0;

  // Symbol-glyph bitmap blit (BitBlt from the glyph atlas equivalent).
  // `slot` selects the source glyph in the backend's atlas; the backend
  // knows the atlas geometry. GUI: blit from the atlas; ncurses: substitute
  // character.
  virtual void blit_glyph_bitmap (int x, int y, int w, int h,
                                  int slot, COLORREF fg, COLORREF bg) = 0;

  // Font measurement (GetTextExtentPoint32 equivalent; e.g. mode-line
  // truncation).
  virtual int text_width (const Char *s, int len, int charset) = 0;

  // Cell metrics (GUI: font cell in px; ncurses: 1).
  virtual int cell_width () const = 0;
  virtual int cell_height () const = 0;
};

#endif /* _painter_h_ */
