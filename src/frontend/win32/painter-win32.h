// -*-C++-*-
#ifndef _painter_win32_h_
#define _painter_win32_h_

# include "painter.h"

/*
 Win32Painter — the Win32 (GDI) implementation of the Painter interface
 (issue #195 step 2).

 Wraps the target device context `p_hdc` and the glyph-atlas memory DC
 `p_hdcmem` (a CompatibleDC with FontSet::hbm() selected). Font metrics
 and per-charset HFONTs come from the global `app.text_font`, so the
 primitives stay self-contained — callers no longer thread HDCs through
 the core paint path.

 During step 2 this runs alongside the existing `paint_glyphs(HDC, HDC)`
 path; step 3 removes the HDC path once the Painter& variant is verified
 pixel-equivalent on Win32.
*/
class Win32Painter : public Painter
{
  HDC p_hdc;
  HDC p_hdcmem;   // glyph atlas (FontSet::hbm selected), may be 0 if unused
public:
  Win32Painter (HDC hdc, HDC hdcmem) : p_hdc (hdc), p_hdcmem (hdcmem) {}

  HDC hdc () const {return p_hdc;}

  void draw_text (int x, int y, const glyph_t *g, const glyph_t *ge,
                  COLORREF fg, COLORREF bg, int charset,
                  unsigned flags, const RECT *clip, bool opaque);
  void fill_rect (int x, int y, int w, int h, COLORREF c);
  void draw_hline (int x1, int x2, int y, COLORREF c);
  void draw_vline (int x, int y1, int y2, COLORREF c);
  void blit_glyph_bitmap (int x, int y, int w, int h, int slot,
                          int cell_yoff, COLORREF fg, COLORREF bg);
  int  text_width (const glyph_t *g, const glyph_t *ge, int charset);
  void draw_text_chars (int x, int y, const Char *s, int len,
                        COLORREF fg, COLORREF bg, int font_role,
                        const RECT *clip, bool opaque);
  int  text_chars_width (const Char *s, int len, int font_role);
  int  cell_width () const;
  int  cell_height () const;
};

#endif /* _painter_win32_h_ */
