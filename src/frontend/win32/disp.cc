#include "stdafx.h"
#include "ed.h"
#include "binfo.h"
#include "syntaxinfo.h"
#define DEFINE_LUCIDA_OFFSET_TABLE
#include "lucida-width.h"
#include "jisx0212-hash.h"
#include "mainframe.h"
#include "regex.h"
#include "glyph.h"
#include "term.h"
#include "eaw.h"
#include "painter-win32.h"

extern Terminal *buffer_terminal (const Buffer *bp);

class color_caret
{
public:
  enum {RGB_MAX = 256};
private:
  HBITMAP cc_hbm;
  struct
    {
      BITMAPINFOHEADER b;
      RGBQUAD rgb[RGB_MAX];
    } cc_bi;
public:
  void load_colors ();
  color_caret ();
  ~color_caret ();
  void create (HWND, HBITMAP, int, int, COLORREF);
  void destroy ();
};

void
color_caret::load_colors ()
{
  memset (&cc_bi.b, 0, sizeof cc_bi.b);
  cc_bi.b.biSize = sizeof cc_bi.b;
  cc_bi.b.biPlanes = 1;

  PALETTEENTRY pe[RGB_MAX];
  HDC hdc = GetDC (0);
  cc_bi.b.biBitCount = GetDeviceCaps (hdc, BITSPIXEL) * GetDeviceCaps (hdc, PLANES);
  int n = GetSystemPaletteEntries (hdc, 0, RGB_MAX, pe);
  ReleaseDC (0, hdc);

  for (int i = 0; i < n; i++)
    {
      cc_bi.rgb[i].rgbRed = pe[i].peRed;
      cc_bi.rgb[i].rgbGreen = pe[i].peGreen;
      cc_bi.rgb[i].rgbBlue = pe[i].peBlue;
      cc_bi.rgb[i].rgbReserved = 0;
    }
  cc_bi.b.biClrUsed = n;
}

color_caret::color_caret ()
     : cc_hbm (0)
{
  load_colors ();
}

color_caret::~color_caret ()
{
  if (cc_hbm)
    DeleteObject (cc_hbm);
}

void
color_caret::destroy ()
{
  DestroyCaret ();
  if (cc_hbm)
    {
      DeleteObject (cc_hbm);
      cc_hbm = 0;
    }
}

void
color_caret::create (HWND hwnd, HBITMAP hbm, int w, int h, COLORREF cc)
{
  HBITMAP old_hbm = cc_hbm;
  cc_hbm = 0;
  if (!hbm)
    {
      cc_bi.b.biWidth = w;
      cc_bi.b.biHeight = h;
      HDC hdc = GetDC (0);
      HDC hdcmem = CreateCompatibleDC (hdc);
      cc_hbm = CreateDIBitmap (hdc, &cc_bi.b, 0, 0,
                               (BITMAPINFO *)&cc_bi, DIB_RGB_COLORS);
      HGDIOBJ obm = SelectObject (hdcmem, cc_hbm);
      fill_rect (hdcmem, 0, 0, w, h, cc);
      SelectObject (hdcmem, obm);
      DeleteDC (hdcmem);
      ReleaseDC (0, hdc);
      hbm = cc_hbm;
    }
  CreateCaret (hwnd, hbm, w, h);
  if (old_hbm)
    DeleteObject (old_hbm);
}

static color_caret xcaret;

void
reload_caret_colors ()
{
  xcaret.load_colors ();
}

// Buffer::next_char() moved to core/glyph.cc

#define CARET_SHAPE_BLOCK 0
#define CARET_SHAPE_THIN 1
#define CARET_SHAPE_HALF 2
#define CARET_SHAPE_UNDERLINE 3

static void
calc_caret_shape (SIZE &size, int ovwrt, int dbcp, int selection)
{
  if (selection)
    {
      size.cx = 2 * sysdep.border.cx;
      size.cy = app.text_font.size ().cy;
    }
  else
    {
      lisp sym;
      if (ovwrt)
        sym = Voverwrite_caret_shape;
      else
        sym = Vnormal_caret_shape;

      long shape;
      safe_fixnum_value (xsymbol_value (sym), &shape);
      switch (shape)
        {
        case CARET_SHAPE_THIN:
          size.cx = 2 * sysdep.border.cx;
          size.cy = app.text_font.size ().cy;
          break;

        default:
        case CARET_SHAPE_BLOCK:
          size.cy = app.text_font.size ().cy;
          goto width;

        case CARET_SHAPE_HALF:
          size.cy = app.text_font.size ().cy / 2;
          goto width;

        case CARET_SHAPE_UNDERLINE:
          size.cy = 2 * sysdep.border.cy;
          goto width;

        width:
          size.cx = app.text_font.cell ().cx;
          if (dbcp)
            size.cx *= 2;
          break;
        }
    }
}

void
Window::caret_size (SIZE &size) const
{
  /* Phase 2-1: cursor が pair 先頭 (high surrogate) に乗ってる時、
     char_width(high 単体) は 1 を返すので caret が半角になる。pair
     合成して unicode_width を引く必要がある。 */
  int wide = 0;
  if (w_point.p_offset != w_point.p_chunk->c_used && w_point.ch () >= 256)
    {
      Char c0 = w_point.ch ();
      if (is_high_surrogate (c0)
          && w_point.p_offset + 1 < w_point.p_chunk->c_used
          && is_low_surrogate (w_point.p_chunk->c_text[w_point.p_offset + 1]))
        wide = (surrogate_pair_width (c0, w_point.p_chunk->c_text[w_point.p_offset + 1]) == 2);
      else
        wide = (char_width (c0) == 2);
    }
  calc_caret_shape (size,
                    symbol_value (Voverwrite_mode, w_bufp) != Qnil,
                    wide,
                    ((w_selection_type != Buffer::SELECTION_VOID
                      && (w_selection_point == NO_MARK_SET
                          || ((w_selection_point <= w_selection_marker)
                              ? (w_point.p_point >= w_selection_point
                                 && w_point.p_point < w_selection_marker)
                              : (w_point.p_point >= w_selection_marker
                                 && w_point.p_point < w_selection_point))))
                     || app.f_in_drop));
}

void
Window::hide_caret () const
{
  if (app.active_frame.has_caret == w_hwnd && app.active_frame.caret_on)
    {
      HideCaret (w_hwnd);
      app.active_frame.caret_on = 0;
    }
}

void
Window::delete_caret ()
{
  if (app.active_frame.has_caret)
    {
      xcaret.destroy ();
      app.active_frame.caret_on = 0;
      app.active_frame.has_caret = 0;
    }
}

void
Window::update_last_caret ()
{
  if (app.active_frame.windows)
    {
      if (selected_window ())
        selected_window ()->update_caret ();
      Window *mini = Window::minibuffer_window ();
      if (mini && mini != selected_window ())
        mini->update_caret ();
    }
}

void
Window::update_caret (HWND hwnd, int x, int y, int w, int h, COLORREF cc)
{
  int gray_caret = app.f_in_drop;
  if (!app.ime_composition
      && app.last_blink_caret != (xsymbol_value (Vblink_caret) != Qnil))
    {
      app.last_blink_caret = xsymbol_value (Vblink_caret) != Qnil;
      if (app.last_blink_caret)
        restore_caret_blink_time ();
      else
        set_caret_blink_time ();
    }
  if (!app.active_frame.has_caret)
    {
      app.active_frame.has_caret = hwnd;
      xcaret.create (hwnd, gray_caret ? HBITMAP (1) : 0, w, h, cc);
      ShowCaret (hwnd);
    }
  else if (app.active_frame.has_caret != hwnd
           || w != app.active_frame.caret_size.cx
           || h != app.active_frame.caret_size.cy
           || cc != app.active_frame.last_caret_color
           || app.active_frame.gray_caret != gray_caret)
    {
      app.active_frame.has_caret = hwnd;
      xcaret.destroy ();
      xcaret.create (hwnd, gray_caret ? HBITMAP (1) : 0, w, h, cc);
      ShowCaret (hwnd);
    }
  else if (!app.active_frame.caret_on)
    ShowCaret (hwnd);
  app.active_frame.has_caret_last = hwnd;
  app.active_frame.last_caret_color = cc;
  app.active_frame.caret_on = 1;
  app.active_frame.caret_size.cx = w;
  app.active_frame.caret_size.cy = h;
  app.active_frame.caret_pos.x = x;
  app.active_frame.caret_pos.y = y;
  app.active_frame.gray_caret = gray_caret;
  SetCaretPos (app.active_frame.caret_pos.x,
               app.active_frame.caret_pos.y + app.text_font.size ().cy - h);
  set_ime_caret ();
}

void
Window::update_caret () const
{
  int show, prompt = 0;

  if (app.f_in_drop)
    show = w_bufp && app.drop_window == this;
  else if (!app.active_frame.has_focus)
    show = 0;
  else if (stringp (xsymbol_value (Vminibuffer_message))
           && xsymbol_value (Vminibuffer_prompt) != Qnil
           && app.minibuffer_prompt_column >= 0)
    {
      show = minibuffer_window_p ();
      prompt = 1;
    }
  else
    show = w_bufp && selected_window () == this;

  if (!show)
    {
      if (app.active_frame.has_caret == w_hwnd)
        delete_caret ();
    }
  else
    {
      COLORREF cc = (app.ime_open_mode == kbd_queue::IME_MODE_ON
                     ? w_colors[WCOLOR_IMECARET]
                     : w_colors[WCOLOR_CARET]);
      COLORREF bg = w_colors[WCOLOR_BACK];
      SIZE sz;
      int x, y;
      if (prompt)
        {
          calc_caret_shape (sz, 0, 0, 0);
          x = app.minibuffer_prompt_column - 1;
          y = 0;
        }
      else
        {
          caret_size (sz);
          x = caret_column ();
          y = caret_line ();

          if (w_glyphs.g_rep && y >= 0 && y < w_ch_max.cy)
            {
              int x1 = x + 1;
              const glyph_data *gd = w_glyphs.g_rep->gr_oglyph[y];
              if (x1 < gd->gd_len)
                {
                  glyph_t gc = gd->gd_cc[x1];
                  bg = glyph_backcolor (gc);
                  if (cc == bg)
                    {
                      COLORREF fg = glyph_forecolor (gc);
                      bg = RGB ((GetRValue (fg) + GetRValue (bg)) / 2,
                                (GetGValue (fg) + GetGValue (bg)) / 2,
                                (GetBValue (fg) + GetBValue (bg)) / 2);
                    }
                }
            }
        }

      cc = (bg ^ cc) & 0xffffff;

      HDC hdc = GetDC (w_hwnd);
      cc = GetNearestColor (hdc, cc);
      ReleaseDC (w_hwnd, hdc);

      update_caret (w_hwnd, caret_xpixel (x), caret_ypixel (y),
                    sz.cx, sz.cy, cc);
    }
}

/* 5b-3: glyph 列 [g, ge) から UTF-16 wchar buffer と per-wchar padding を
   組み立てる。JUNK trail (wide char 後続セル) は skip。surrogate pair は
   2 wchar に展開し、上位 wchar に全 advance を載せる (paint_chars に
   渡す lpDx の慣例)。戻り値は書き込んだ wchar 数。 */
static int
paint_build_wchars (const glyph_t *g, const glyph_t *ge,
                    wchar_t *wbuf, INT *wpad, int cellw, int cap)
{
  int n = 0;
  for (; g < ge && n + 1 < cap; g++)
    {
      glyph_t c = *g;
      if (c & GLYPH_JUNK)
        continue;
      u_int32_t cp = GLYPH_CP (c);
      int width = (int) glyph_width (c);
      if (width == 0)
        width = 1;  /* combining (将来) は base に併合; 単独なら 1 cell 想定 */
      int advance = width * cellw;
      if (cp < 0x10000u)
        {
          wbuf[n] = (wchar_t) cp;
          wpad[n] = advance;
          n++;
        }
      else if (cp < 0x110000u)
        {
          /* surrogate pair に分解。lpDx は high/low に半々 (cellw 各々) で
             振る。lpDx[high]=advance,low=0 にすると low が advance 右に
             飛んで結合されず別 glyph として描画される。逆に lpDx[high]=0,
             low=advance だと結合されるが glyph が cell 内で右寄せに見える
             ケースがある。半々は MFC 等の標準的な振り方で、結合 glyph が
             自然に 2 cell に収まる。 */
          u_int32_t v = cp - 0x10000u;
          int half = advance / 2;
          wbuf[n]   = (wchar_t) (0xD800u + (v >> 10));
          wpad[n]   = half;
          n++;
          if (n + 1 >= cap)
            break;
          wbuf[n]   = (wchar_t) (0xDC00u + (v & 0x3FFu));
          wpad[n]   = advance - half;
          n++;
        }
      /* cp >= 0x110000 は Phase 3 shape ref。Phase 2 では到達しない */
    }
  return n;
}

/* 5b-3: glyph 列 [g, ge) を 1 font slot で ExtTextOutW。font_idx は
   GLYPH_FONT_MASK から抽出した 0-15 の slot 番号 (FontSet の FONT_*)。
   呼び元は GLYPH_BITMAP_BIT を見て bitmap dispatch と分岐済み。 */
static void
paint_chars (HDC hdc, int x, int y, int flags, const RECT &r,
             int font_idx, const glyph_t *g, const glyph_t *ge,
             const INT * /*padding*/)
{
  const FontObject &f = app.text_font.font (font_idx);
  HGDIOBJ of = SelectObject (hdc, f);

  wchar_t wbuf[512];
  INT wpad[512];
  int n = paint_build_wchars (g, ge, wbuf, wpad,
                              app.text_font.cell ().cx, 512);
  /* n=0 でも ETO_OPAQUE があれば BG fill のため空文字列で呼ぶ。これを
     skip すると leading-blank strip 後 g..ge が空になった group (例:
     全部空白の selection 範囲) で BG 反転が残らず redraw が壊れる。 */
  ExtTextOutW (hdc, x + f.offset ().x, y + f.offset ().y, flags,
               &r, wbuf, n, n > 0 ? wpad : 0);

  SelectObject (hdc, of);
}

/* -------- Win32Painter (issue #13 step 2) ----------------------------
   GDI implementation of the Painter interface. Reuses paint_build_wchars
   above for UTF-16 expansion. Colors are received per-call (decoded by the
   core), so the primitives set/restore GDI state locally. */

void
Win32Painter::draw_text (int x, int y, const glyph_t *g, const glyph_t *ge,
                         COLORREF fg, COLORREF bg, int charset,
                         unsigned /*flags*/, const RECT *clip, bool opaque)
{
  /* Bold/underline/strike are realized by the core (overprint offset +
     opaque=false, and fill_rect for the lines), matching the existing
     paint_glyphs passes, so `flags` is informational here. */
  const FontObject &f = app.text_font.font (charset);
  HGDIOBJ of = SelectObject (p_hdc, f);
  COLORREF ofg = SetTextColor (p_hdc, fg);
  COLORREF obg = 0;
  int omode = 0;
  if (opaque)
    obg = SetBkColor (p_hdc, bg);
  else
    omode = SetBkMode (p_hdc, TRANSPARENT);

  wchar_t wbuf[512];
  INT wpad[512];
  int n = paint_build_wchars (g, ge, wbuf, wpad, app.text_font.cell ().cx, 512);
  /* n=0 でも opaque なら BG fill のため空文字列で呼ぶ (paint_chars と同じ)。 */
  ExtTextOutW (p_hdc, x + f.offset ().x, y + f.offset ().y,
               (opaque ? ETO_OPAQUE : 0) | ETO_CLIPPED,
               clip, wbuf, n, n > 0 ? wpad : 0);

  if (opaque)
    SetBkColor (p_hdc, obg);
  else
    SetBkMode (p_hdc, omode);
  SetTextColor (p_hdc, ofg);
  SelectObject (p_hdc, of);
}

void
Win32Painter::fill_rect (int x, int y, int w, int h, COLORREF c)
{
  ::fill_rect (p_hdc, x, y, w, h, c);
}

void
Win32Painter::draw_hline (int x1, int x2, int y, COLORREF c)
{
  ::draw_hline (p_hdc, x1, x2, y, c);
}

void
Win32Painter::draw_vline (int x, int y1, int y2, COLORREF c)
{
  ::draw_vline (p_hdc, y1, y2, x, c);
}

void
Win32Painter::blit_glyph_bitmap (int x, int y, int w, int h, int slot,
                                 int cell_yoff, COLORREF fg, COLORREF bg)
{
  COLORREF ofg = SetTextColor (p_hdc, fg);
  COLORREF obg = SetBkColor (p_hdc, bg);
  BitBlt (p_hdc, x, y, w, h, p_hdcmem,
          app.text_font.cell ().cx * slot, cell_yoff, SRCCOPY);
  SetTextColor (p_hdc, ofg);
  SetBkColor (p_hdc, obg);
}

int
Win32Painter::text_width (const glyph_t *g, const glyph_t *ge, int charset)
{
  const FontObject &f = app.text_font.font (charset);
  HGDIOBJ of = SelectObject (p_hdc, f);
  wchar_t wbuf[512];
  INT wpad[512];
  int n = paint_build_wchars (g, ge, wbuf, wpad, app.text_font.cell ().cx, 512);
  SIZE sz;
  GetTextExtentPoint32W (p_hdc, wbuf, n, &sz);
  SelectObject (p_hdc, of);
  return sz.cx;
}

/* Resolve a Painter font role to an HFONT. Non-negative = text_font charset
   slot; PFONT_MODELINE/PFONT_RULER = the app-level mode-line / ruler font. */
static HFONT
win32_role_font (int role)
{
  if (role == PFONT_MODELINE)
    return app.modeline_param.m_hfont;
  if (role == PFONT_RULER)
    return sysdep.hfont_ruler;
  return app.text_font.font (role);
}

void
Win32Painter::draw_text_chars (int x, int y, const Char *s, int len,
                               COLORREF fg, COLORREF bg, int role,
                               const RECT *clip, bool opaque)
{
  HGDIOBJ of = SelectObject (p_hdc, win32_role_font (role));
  COLORREF ofg = SetTextColor (p_hdc, fg);
  COLORREF obg = 0;
  int omode = 0;
  if (opaque)
    obg = SetBkColor (p_hdc, bg);
  else
    omode = SetBkMode (p_hdc, TRANSPARENT);
  ExtTextOutW (p_hdc, x, y, (opaque ? ETO_OPAQUE : 0) | ETO_CLIPPED,
               clip, (LPCWSTR)s, len, 0);
  if (opaque)
    SetBkColor (p_hdc, obg);
  else
    SetBkMode (p_hdc, omode);
  SetTextColor (p_hdc, ofg);
  SelectObject (p_hdc, of);
}

int
Win32Painter::text_chars_width (const Char *s, int len, int role)
{
  HGDIOBJ of = SelectObject (p_hdc, win32_role_font (role));
  SIZE sz;
  GetTextExtentPoint32W (p_hdc, (LPCWSTR)s, len, &sz);
  SelectObject (p_hdc, of);
  return sz.cx;
}

int
Win32Painter::cell_width () const
{
  return app.text_font.cell ().cx;
}

int
Win32Painter::cell_height () const
{
  return app.text_font.cell ().cy;
}

/* -------------------------------------------------------------------- */

/* issue #13 step 3: the HDC entry point is now a thin adapter that builds
   a Win32Painter and delegates to the Painter& renderer above. All glyph
   drawing flows through the Painter. (Kept so paint_line's existing
   hdc/hdcmem call sites stay unchanged; folded away once paint_line itself
   takes a Painter&.) `padding` was already dead in the glyph path. */
void
Window::paint_glyphs (HDC hdc, HDC hdcmem, const glyph_t *gstart, const glyph_t *g,
                      const glyph_t *ge, char *buf, const INT * /*padding*/,
                      int x, int y, int yoffset) const
{
  Win32Painter painter (hdc, hdcmem);
  paint_glyphs (painter, gstart, g, ge, buf, x, y, yoffset);
}

/* Painter& variant of paint_glyphs (issue #13 step 2). A faithful
   transcription of the HDC version above with GDI leaf calls routed
   through the Painter: paint_chars -> draw_text, BitBlt ->
   blit_glyph_bitmap, the underline/strike thin-rect ExtTextOut ->
   fill_rect, and per-group SetTextColor/SetBkColor folded into the
   primitive calls (colors decoded here and passed down). Bold is the
   overprint pass (x+1, opaque=false). Unused until step 3; the HDC path
   above stays live meanwhile. */
void
Window::paint_glyphs (Painter &painter, const glyph_t *gstart, const glyph_t *g,
                      const glyph_t *ge, char *buf,
                      int x, int y, int yoffset) const
{
  const int cellcx = app.text_font.cell ().cx;
  const int cellcy = app.text_font.cell ().cy;
  RECT r;
  r.top = y + yoffset;
  r.bottom = y + cellcy;
  r.right = x;
  glyph_t gsum = 0;
  const glyph_t *gfrom = g;

  const glyph_t blank_cell = glyph_ascii_cell (' ');
  while (g < ge)
    {
      const glyph_t *g0 = g;
      char *be = buf;
      glyph_t c = *g++;
      gsum |= c;
      *be++ = char (c);
      c &= GLYPH_COLOR_MASK | GLYPH_FONT_MASK | GLYPH_BITMAP_BIT;
      while (g < ge
             && (*g & (GLYPH_COLOR_MASK | GLYPH_FONT_MASK | GLYPH_BITMAP_BIT)) == c)
        {
          gsum |= *g;
          *be++ = char (*g++);
        }

      r.left = r.right;
      r.right += (be - buf) * cellcx;
      if (r.right > w_clsize.cx)
        {
          r.right = w_clsize.cx;
          if (r.left > r.right)
            break;
        }

      char *b = buf;
      if (!(c & GLYPH_BITMAP_BIT))
        {
          for (; b < be && *b == ' '; b++)
            ;
          g0 += b - buf;
        }
      const glyph_t *g1;
      for (g1 = g;
           g1 > g0
           && (g1[-1] & ~(glyph_t) GLYPH_COLOR_MASK) == blank_cell;
           g1--)
        ;
      be -= g - g1;

      if (c & GLYPH_BITMAP_BIT)
        {
          int xpx = r.left + (b - buf) * cellcx;
          for (; b < be; b++, xpx += cellcx)
            {
              int w = w_clsize.cx - xpx;
              if (w <= 0)
                break;
              if (w > cellcx)
                w = cellcx;
              painter.blit_glyph_bitmap (xpx, r.top, w, cellcy, *b & 0xff,
                                         yoffset, glyph_forecolor (c),
                                         glyph_backcolor (c));
            }
        }
      else
        painter.draw_text (r.left + (b - buf) * cellcx, y, g0, g1,
                           glyph_forecolor (c), glyph_backcolor (c),
                           int (GLYPH_FONT (c) >> GLYPH_FONT_SHIFT_BITS),
                           0, &r, true);
    }

  if (gsum & GLYPH_BOLD)
    {
      g = gfrom;
      if (g > gstart && g[-1] & GLYPH_BOLD)
        {
          g--;
          if (*g & GLYPH_JUNK)  /* wide char trail なら lead まで戻す */
            g--;
        }

      while (1)
        {
          for (; g < ge && !(*g & GLYPH_BOLD); g++)
            ;
          if (g == ge)
            break;
          char *be = buf;
          const glyph_t *g0 = g;
          glyph_t c0 = *g++;
          *be++ = char (c0);
          glyph_t c = c0 & (GLYPH_FORE_COLOR_MASK | GLYPH_BITMAP_BIT
                            | GLYPH_FONT_MASK | GLYPH_BOLD);
          for (; g < ge && (*g & (GLYPH_FORE_COLOR_MASK | GLYPH_BITMAP_BIT
                                  | GLYPH_FONT_MASK | GLYPH_BOLD)) == c; g++)
            *be++ = char (*g);

          r.left = x + (g0 - gfrom) * cellcx + 1;
          r.right = x + (g - gfrom) * cellcx + 1;
          if (r.right > w_clsize.cx)
            {
              r.right = w_clsize.cx;
              if (r.left > r.right)
                break;
            }

          if (c & GLYPH_BITMAP_BIT)
            {
              char *b = buf;
              for (int xpx = r.left; b < be; b++, xpx += cellcx)
                if ((*b & 0xff) == FontSet::backsl)
                  {
                    int w = w_clsize.cx - xpx;
                    if (w <= 0)
                      break;
                    if (w > cellcx)
                      w = cellcx;
                    painter.blit_glyph_bitmap (xpx, r.top, w, cellcy,
                                               FontSet::bold_backsl, yoffset,
                                               glyph_forecolor (c0),
                                               glyph_backcolor (c0));
                  }
            }
          else
            painter.draw_text (r.left, y, g0, g,
                               glyph_forecolor (c0), glyph_backcolor (c0),
                               int (GLYPH_FONT (c) >> GLYPH_FONT_SHIFT_BITS),
                               PAINT_BOLD, &r, false);
        }
    }

  if (gsum & (!yoffset ? GLYPH_UNDERLINE | GLYPH_STRIKEOUT : GLYPH_UNDERLINE))
    {
      g = gfrom;
      while (1)
        {
          for (; g < ge && !(*g & (GLYPH_UNDERLINE | GLYPH_STRIKEOUT)); g++)
            ;
          if (g == ge)
            break;
          const glyph_t *g0 = g;
          glyph_t c = *g++ & (GLYPH_FORE_COLOR_MASK | GLYPH_UNDERLINE | GLYPH_STRIKEOUT);
          for (; g < ge && (*g & (GLYPH_FORE_COLOR_MASK | GLYPH_UNDERLINE | GLYPH_STRIKEOUT)) == c; g++)
            ;

          r.left = x + (g0 - gfrom) * cellcx;
          r.right = x + (g - gfrom) * cellcx;
          if (r.right > w_clsize.cx)
            {
              r.right = w_clsize.cx;
              if (r.left > r.right)
                break;
            }

          if (c & GLYPH_UNDERLINE)
            {
              int ytop = y + app.text_font.size ().cy - app.text_font.line_width ();
              painter.fill_rect (r.left, ytop, r.right - r.left,
                                 app.text_font.line_width (), glyph_forecolor (c));
            }
          if (!yoffset && c & GLYPH_STRIKEOUT)
            {
              int ytop = y + app.text_font.size ().cy / 2;
              painter.fill_rect (r.left, ytop, r.right - r.left,
                                 app.text_font.line_width (), glyph_forecolor (c));
            }
        }
    }
}

void
Window::paint_line (Painter &painter, glyph_data *ogd, const glyph_data *ngd,
                    char *buf, int y) const
{
  /* issue #13 step 3f: glyph drawing / blank fills via Painter; the
     ScrollWindow/ValidateRect scroll-blit optimization stays on the
     w_hwnd member (window-content scroll, not a Painter drawing op). */
  const glyph_t *n = ngd->gd_cc, *ne = n + ngd->gd_len;
  glyph_t *o = ogd->gd_cc, *oe = o + ogd->gd_len;

  for (; n < ne && o < oe && *n == *o; n++, o++)
    ;
  if (n == ne && o == oe)
    return;
  /* 5b-3: 旧 glyph_trail_p (=GLYPH_TRAIL bit) は廃止。wide char 後続セルは
     GLYPH_JUNK で識別する。 */
  if (n < ne && (*n & GLYPH_JUNK))
    n--, o--;
  if (o > ogd->gd_cc && o[-1] & GLYPH_BOLD)
    {
      n--, o--;
      if (n < ne && (*n & GLYPH_JUNK))
        n--, o--;
    }

  const glyph_t *nfd = n;
  glyph_t *ofd = o;

  for (n = ne, o = oe; n > nfd && o > ofd && n[-1] == o[-1]; n--, o--)
    ;
  if (n < ne && (*n & GLYPH_JUNK))
    n++, o++;
  if (o > ogd->gd_cc && o[-1] & GLYPH_BOLD)
    {
      if (o < oe)
        {
          n++, o++;
          if (n < ne && (*n & GLYPH_JUNK))
            n++, o++;
        }
      else
        painter.fill_rect (((ogd->gd_len - 1) * app.text_font.cell ().cx + app.text_font.cell ().cx / 2), y,
                           app.text_font.cell ().cx, app.text_font.cell ().cy, w_colors[WCOLOR_BACK]);
    }

  const glyph_t *nls = n;
  glyph_t *ols = o;

  int dl = (nls - nfd) - (ols - ofd);

  if (!dl)
    {
      paint_glyphs (painter, ngd->gd_cc, nfd, nls, buf,
                    ((nfd - ngd->gd_cc - 1) * app.text_font.cell ().cx
                     + app.text_font.cell ().cx / 2),
                    y, 0);
      for (o = ofd, n = nfd; n < nls;)
        *o++ = *n++;
    }
  else
    {
      if (ogd->gd_len - (ols - ogd->gd_cc) <= 3)
        {
          paint_glyphs (painter, ngd->gd_cc, nfd, ne, buf,
                        ((nfd - ngd->gd_cc - 1) * app.text_font.cell ().cx
                         + app.text_font.cell ().cx / 2),
                        y, 0);
          if (dl < 0 && ogd->gd_len > ngd->gd_len)
            painter.fill_rect (((ngd->gd_len - 1) * app.text_font.cell ().cx
                                + app.text_font.cell ().cx / 2),
                               y,
                               (ogd->gd_len - ngd->gd_len) * app.text_font.cell ().cx,
                               app.text_font.cell ().cy,
                               w_colors[WCOLOR_BACK]);
        }
      else
        {
          RECT r;
          r.top = y;
          r.bottom = y + app.text_font.cell ().cy;
          r.left = ((ols - ogd->gd_cc - 1) * app.text_font.cell ().cx
                    + app.text_font.cell ().cx / 2);
          r.right = ((ogd->gd_len - 1) * app.text_font.cell ().cx
                     + app.text_font.cell ().cx / 2);
          int dx = dl * app.text_font.cell ().cx;
          if (r.right + dx > w_clsize.cx)
            {
              r.right = w_clsize.cx - dx;
              r.right = max (r.left, r.right);
            }
          ScrollWindow (w_hwnd, dx, 0, &r, 0);
          if (dl < 0)
            {
              if (r.right > w_clsize.cx)
                {
                  int x = ((w_clsize.cx + app.text_font.cell ().cx / 2)
                           / app.text_font.cell ().cx + dl);
                  if (x >= 0 && x < ngd->gd_len)
                    {
                      const glyph_t *g = ngd->gd_cc + x;
                      int l = 1;
                      /* 5b-3: lead/trail 判定は GLYPH_JUNK と width=WIDE で */
                      if (x && (*g & GLYPH_JUNK))
                        {
                          g--;
                          x--;
                          l = 2;
                        }
                      else if (glyph_width (*g) == 2)
                        l = 2;
                      paint_glyphs (painter, ngd->gd_cc, g, g + l, buf,
                                    (x - 1) * app.text_font.cell ().cx + app.text_font.cell ().cx / 2,
                                    y, 0);
                    }
                }
              r.left = ((ngd->gd_len - 1) * app.text_font.cell ().cx
                        + app.text_font.cell ().cx / 2);
              ValidateRect (w_hwnd, &r);
              painter.fill_rect (r.left, r.top,
                                 r.right - r.left, app.text_font.cell ().cy,
                                 w_colors[WCOLOR_BACK]);
            }
          else
            {
              r.right = ((nls - ngd->gd_cc - 1) * app.text_font.cell ().cx
                         + app.text_font.cell ().cx / 2);
              ValidateRect (w_hwnd, &r);
            }
          paint_glyphs (painter, ngd->gd_cc, nfd, nls, buf,
                        ((nfd - ngd->gd_cc - 1) * app.text_font.cell ().cx
                         + app.text_font.cell ().cx / 2),
                        y, 0);
        }
      for (o = ofd, n = nfd; n < ne;)
        *o++ = *n++;
      *o = 0;
      ogd->gd_len = ngd->gd_len;
    }
}

void
Window::erase_cursor_line (HDC hdc) const
{
  if (w_cursor_line.ypixel < 0 || !w_glyphs.g_rep)
    return;

  int y = w_cursor_line.ypixel / app.text_font.cell ().cy;
  if (y >= 0 && y < w_ch_max.cy)
    {
      HDC xhdc = hdc;
      if (!hdc)
        {
          hide_caret ();
          hdc = GetDC (w_hwnd);
        }

      int x1 = (w_cursor_line.x1 - app.text_font.cell ().cx / 2) / app.text_font.cell ().cx + 1;
      int x2pixel = w_cursor_line.x2;
      if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
        {
          int w = w_cursor_line.x1 + ((w_bufp->b_fold_columns - w_last_top_column)
                                      * app.text_font.cell ().cx);
          if (x2pixel < w)
            x2pixel = w;
        }
      int x2 = (x2pixel - app.text_font.cell ().cx / 2
                + app.text_font.cell ().cx - 1) / app.text_font.cell ().cx + 1;

      const glyph_data *gd = w_glyphs.g_rep->gr_oglyph[y];
      const glyph_t *g = gd->gd_cc + x1, *ge = gd->gd_cc + min (int (gd->gd_len), x2);
      int x = w_cursor_line.x1;
      HGDIOBJ of = SelectObject (hdc, app.text_font.font (FONT_ASCII));
      HDC hdcmem = CreateCompatibleDC (hdc);
      HGDIOBJ obm = SelectObject (hdcmem, app.text_font.hbm ());
      HGDIOBJ obr = SelectObject (hdc, CreateSolidBrush (w_colors[WCOLOR_BACK]));

      INT *padding;
      if (!app.text_font.need_pad_p ())
        padding = 0;
      else
        {
          padding = (INT *)alloca (sizeof *padding * w_ch_max.cx);
          for (int i = 0; i < w_ch_max.cx; i++)
            padding[i] = app.text_font.cell ().cx;
        }
      char *buf = (char *)alloca (w_ch_max.cx + 3);
      paint_glyphs (hdc, hdcmem, gd->gd_cc, g, ge, buf, padding, x,
                    (w_cursor_line.ypixel - app.text_font.cell ().cy + 1),
                    app.text_font.cell ().cy - 1);
      SelectObject (hdcmem, obm);
      DeleteDC (hdcmem);
      SelectObject (hdc, of);
      DeleteObject (SelectObject (hdc, obr));

      x += (ge - g) * app.text_font.cell ().cx;
      if (x < w_cursor_line.x2)
        draw_hline (hdc, x, w_cursor_line.x2,
                    w_cursor_line.ypixel, w_colors[WCOLOR_BACK]);
      if (hdc != xhdc)
        ReleaseDC (w_hwnd, hdc);
    }
  const_cast <Window *> (this)->w_cursor_line.ypixel = -1;
}

void
Window::paint_cursor_line (HDC hdc, int f) const
{
  int x1, x2, y;
  int paint = (w_last_flags & WF_CURSOR_LINE
               && (selected_window () == this
                   || (w_bufp && xsymbol_value (Vshow_cursor_line_always) != Qnil)));
  int erase;
  int inverse = symbol_value (Vinverse_cursor_line, w_bufp) != Qnil;

  if (paint)
    {
      x1 = ((w_last_flags & WF_LINE_NUMBER ? LINENUM_COLUMNS + 1 : 0)
            * app.text_font.cell ().cx + app.text_font.cell ().cx / 2);
      x2 = w_ch_max.cx * app.text_font.cell ().cx;
      if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
        {
          int w = x1 + ((w_bufp->b_fold_columns - w_last_top_column)
                        * app.text_font.cell ().cx);
          if (w < x2)
            x2 = w;
        }
      if (x2 > w_clsize.cx)
        x2 = w_clsize.cx;

      y = (w_linenum - w_last_top_linenum + 1) * app.text_font.cell ().cy - 1;

      if (y != w_cursor_line.ypixel
          || x1 != w_cursor_line.x1
          || x2 != w_cursor_line.x2)
        erase = 1;
      else if (!f)
        return;
      else
        erase = inverse;
    }
  else
    {
      if (w_cursor_line.ypixel < 0)
        return;
      erase = 1;
    }

  HDC xhdc = hdc;
  if (!hdc)
    {
      hide_caret ();
      hdc = GetDC (w_hwnd);
    }

  if (erase)
    erase_cursor_line (hdc);

  if (paint)
    {
      if (inverse)
        {
          HGDIOBJ open = SelectObject
            (hdc, CreatePen (PS_SOLID, 0, w_colors[WCOLOR_CURSOR] ^ w_colors[WCOLOR_BACK]));
          int omode = SetROP2 (hdc, R2_XORPEN);
          MoveToEx (hdc, x1, y, 0);
          LineTo (hdc, x2, y);
          SetROP2 (hdc, omode);
          DeleteObject (SelectObject (hdc, open));
        }
      else
        draw_hline (hdc, x1, x2, y, w_colors[WCOLOR_CURSOR]);

      const_cast <Window *> (this)->w_cursor_line.ypixel = y;
      const_cast <Window *> (this)->w_cursor_line.x1 = x1;
      const_cast <Window *> (this)->w_cursor_line.x2 = x2;
    }

  if (hdc != xhdc)
    ReleaseDC (w_hwnd, hdc);
}

#define MAX_KWDLEN 256

// kwd_val, kwdmatch, glyph_dbchar, glyph_sbchar, glyph_bmchar moved to core/glyph.cc


// regexp_kwd class moved to core/glyph.cc


// Window::redraw_line() moved to core/glyph.cc


void
Window::scroll_down_region (int y1, int y2, int dy, int offset) const
{
  glyph_data **g = w_glyphs.g_rep->gr_oglyph + y1;
  int maxl = 0;
  for (int i = y1; i <= y2; i++, g++)
    maxl = max (maxl, int ((*g)->gd_len));
  if (maxl == offset)
    return;

  erase_cursor_line (0);

  g = w_glyphs.g_rep->gr_oglyph;
  for (int yd = y2, ys = y2 - dy; ys >= y1; yd--, ys--)
    if (g[ys]->gd_len > offset)
      {
        memcpy (g[yd]->gd_cc + offset, g[ys]->gd_cc + offset,
                sizeof (glyph_t) * (g[ys]->gd_len + 1 - offset));
        for (glyph_t *p = g[yd]->gd_cc + g[yd]->gd_len,
             *pe = g[yd]->gd_cc + offset;
             p < pe; p++)
          *p = GLYPH_JUNK;
        g[yd]->gd_len = g[ys]->gd_len;
      }

  RECT r;
  r.left = (offset - 1) * app.text_font.cell ().cx + app.text_font.cell ().cx / 2;
  r.right = min (w_client.cx, LONG ((maxl - 1) * app.text_font.cell ().cx
                                    + app.text_font.cell ().cx / 2));
  r.top = y1 * app.text_font.cell ().cy;
  r.bottom = (y2 + 1) * app.text_font.cell ().cy;
  ScrollWindow (w_hwnd, 0, dy * app.text_font.cell ().cy, 0, &r);
  r.bottom = r.top + dy * app.text_font.cell ().cy;
  ValidateRect (w_hwnd, &r);
}

void
Window::scroll_up_region (int y1, int y2, int dy, int offset) const
{
  glyph_data **g = w_glyphs.g_rep->gr_oglyph + y1;
  int maxl = 0;
  for (int i = y1; i <= y2; i++, g++)
    maxl = max (maxl, int ((*g)->gd_len));
  if (maxl == offset)
    return;

  erase_cursor_line (0);

  g = w_glyphs.g_rep->gr_oglyph;
  for (int yd = y1, ys = y1 + dy; ys <= y2; yd++, ys++)
    if (g[ys]->gd_len > offset)
      {
        memcpy (g[yd]->gd_cc + offset, g[ys]->gd_cc + offset,
                sizeof (glyph_t) * (g[ys]->gd_len + 1 - offset));
        for (glyph_t *p = g[yd]->gd_cc + g[yd]->gd_len,
             *pe = g[yd]->gd_cc + offset;
             p < pe; p++)
          *p++ = GLYPH_JUNK;
        g[yd]->gd_len = g[ys]->gd_len;
      }

  RECT r;
  r.left = (offset - 1) * app.text_font.cell ().cx + app.text_font.cell ().cx / 2;
  r.right = min (w_client.cx, LONG ((maxl - 1) * app.text_font.cell ().cx
                                    + app.text_font.cell ().cx / 2));
  r.top = y1 * app.text_font.cell ().cy;
  r.bottom = (y2 + 1) * app.text_font.cell ().cy;
  ScrollWindow (w_hwnd, 0, -dy * app.text_font.cell ().cy, 0, &r);
  r.top = r.bottom - dy * app.text_font.cell ().cy;
  ValidateRect (w_hwnd, &r);
}

// compare_glyph() moved to core/glyph.cc


void
Window::find_motion () const
{
  int offset = (flags () & WF_LINE_NUMBER) ? LINENUM_COLUMNS + 1 : 0;
  glyph_data **og = w_glyphs.g_rep->gr_oglyph;
  glyph_data **ng = w_glyphs.g_rep->gr_nglyph;
  int y1, y2;
  for (y1 = 0; y1 < w_ech.cy; y1++)
    {
      int f = compare_glyph (og[y1], ng[y1], offset);
      if (f == NO_MATCH)
        break;
      ng[y1]->gd_mod = f != FULL_MATCH;
    }

  for (y2 = w_ech.cy - 1; y2 > y1; y2--)
    {
      int f = compare_glyph (og[y2], ng[y2], offset);
      if (f == NO_MATCH)
        break;
      ng[y2]->gd_mod = f != FULL_MATCH;
    }

  if (y1 == y2)
    return;

  struct {int y1, y2, dy, f, n;} down, up;
  down.n = 0;
  up.n = 0;

  for (int y = y2 - 1; y > y1; y--)
    {
      int f = compare_glyph (og[y], ng[y2], offset);
      if (!f)
        continue;
      int oy, ny;
      for (oy = y - 1, ny = y2 - 1; oy >= y1; oy--, ny--)
        {
          int f2 = compare_glyph (og[oy], ng[ny], offset);
          if (!f2)
            break;
          f |= f2;
        }
      down.y1 = oy + 1;
      down.y2 = y2;
      down.dy = y2 - y;
      down.f = f;
      down.n = y - 1 - oy;
      break;
    }

  for (int i = 0; i < 3; i++, y2--)
    {
      for (int y = y2 - 1; y >= y1; y--)
        {
          int f = compare_glyph (og[y2], ng[y], offset);
          if (!f)
            continue;
          int oy, ny;
          for (oy = y2 - 1, ny = y - 1; ny >= y1; oy--, ny--)
            {
              int f2 = compare_glyph (og[oy], ng[ny], offset);
              if (!f2)
                break;
              f |= f2;
            }
          int n = y2 - 1 - oy;
          if (n > up.n)
            {
              up.y1 = ny + 1;
              up.y2 = y2;
              up.dy = y2 - y;
              up.f = f;
              up.n = n;
            }
          break;
        }
      if (up.n > 3)
        break;
    }

  if (down.n > up.n)
    {
      if (down.n >= 2)
        scroll_down_region (down.y1, down.y2, down.dy,
                            down.f == FULL_MATCH ? 0 : offset);
    }
  else
    {
      if (up.n >= 2)
        scroll_up_region (up.y1, up.y2, up.dy,
                          up.f == FULL_MATCH ? 0 : offset);
    }
}

void
Window::paint_region (Painter &painter, int from, int to) const
{
  char *buf = (char *)alloca (w_ch_max.cx + 3);
  glyph_data **g = w_glyphs.g_rep->gr_nglyph + from;
  glyph_data **og = w_glyphs.g_rep->gr_oglyph + from;
  for (int y = from * app.text_font.cell ().cy, ye = to * app.text_font.cell ().cy;
       y < ye; y += app.text_font.cell ().cy, g++, og++)
    if ((*g)->gd_mod)
      {
        paint_line (painter, *og, *g, buf, y);
        (*g)->gd_mod = 0;
      }
}

/* issue #13 step 3f: HDC entry point builds the glyph-atlas memory DC and a
   Win32Painter, then delegates. (The FONT_ASCII select / WCOLOR_BACK brush
   / padding the old HDC version set up are gone: paint_glyphs picks its own
   per-charset font, blank fills go through painter.fill_rect, and padding
   was dead in the glyph path.) */
void
Window::paint_region (HDC hdc, int from, int to) const
{
  HDC hdcmem = CreateCompatibleDC (hdc);
  HGDIOBJ obm = SelectObject (hdcmem, app.text_font.hbm ());
  Win32Painter painter (hdc, hdcmem);
  paint_region (painter, from, to);
  SelectObject (hdcmem, obm);
  DeleteDC (hdcmem);
}

// Window::redraw_window() moved to core/glyph.cc

void
Window::scroll_lines (int dy)
{
  erase_cursor_line (0);

  glyph_data **og = w_glyphs.g_rep->gr_oglyph;
  int maxl = 0;
  for (int i = 0; i < w_ch_max.cy; i++, og++)
    maxl = max (maxl, int ((*og)->gd_len));

  RECT r;
  r.left = 0;
  r.right = min (w_client.cx, LONG ((maxl - 1) * app.text_font.cell ().cx
                                    + app.text_font.cell ().cx / 2));
  r.top = 0;
  if (dy < 0)
    r.bottom = w_ech.cy * app.text_font.cell ().cy;
  else
    r.bottom = w_client.cy;
  ScrollWindow (w_hwnd, 0, dy * app.text_font.cell ().cy, 0, &r);
  if (dy < 0)
    {
      r.bottom = w_client.cy;
      r.top = ((r.bottom + dy * app.text_font.cell ().cy)
               / app.text_font.cell ().cy * app.text_font.cell ().cy);
    }
  else
    {
      r.top = 0;
      r.bottom = dy * app.text_font.cell ().cy;
    }
  ValidateRect (w_hwnd, &r);

  if (dy < 0)
    {
      dy = -dy;
      og = w_glyphs.g_rep->gr_oglyph;
      glyph_data **ng = w_glyphs.g_rep->gr_nglyph;
      glyph_data **ogx = og;
      glyph_data **ngx = ng;
      glyph_data **osave = (glyph_data **)alloca (sizeof (glyph_data *) * dy * 2);
      glyph_data **nsave = osave + dy;
      int i;
      for (i = 0; i < dy; i++)
        {
          osave[i] = *og++;
          nsave[i] = *ng++;
        }
      for (; i < w_ech.cy; i++)
        {
          *ogx++ = *og++;
          (*ng)->gd_mod = 0;
          *ngx++ = *ng++;
        }
      og -= dy;
      for (i = 0; i < dy; i++, og++)
        {
          osave[i]->gd_len = (*og)->gd_len;
          memcpy (osave[i]->gd_cc, (*og)->gd_cc,
                  sizeof (glyph_t) * ((*og)->gd_len + 1));
          *ogx++ = osave[i];
          *ngx++ = nsave[i];
          nsave[i]->gd_mod = 1;
        }
      if (w_ech.cy < w_ch_max.cy)
        (*ngx)->gd_mod = 1;
    }
  else
    {
      og = w_glyphs.g_rep->gr_oglyph + w_ch_max.cy;
      glyph_data **ng = w_glyphs.g_rep->gr_nglyph + w_ch_max.cy;
      glyph_data **ogx = og;
      glyph_data **ngx = ng;
      glyph_data **osave = (glyph_data **)alloca (sizeof (glyph_data *) * dy * 2);
      glyph_data **nsave = osave + dy;
      int i;
      for (i = 0; i < dy; i++)
        {
          osave[i] = *--og;
          nsave[i] = *--ng;
        }
      for (; i < w_ch_max.cy; i++)
        {
          *--ogx = *--og;
          *--ngx = *--ng;
          (*ngx)->gd_mod = 0;
        }
      og += dy - 1;
      for (i = 0; i < dy; i++, og--)
        {
          osave[i]->gd_len = (*og)->gd_len;
          memcpy (osave[i]->gd_cc, (*og)->gd_cc,
                  sizeof (glyph_t) * ((*og)->gd_len + 1));
          *--ogx = osave[i];
          *--ngx = nsave[i];
          (*ngx)->gd_mod = 1;
        }
    }
}

// set_region(), bol_point(), folded_bol_point() moved to core/glyph.cc


void
Window::reframe ()
{
  assert (w_bufp);

  if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
    w_bufp->folded_count_lines ();

  Region modr = w_bufp->b_modified_region;
  if ((w_selection_type & (Buffer::CONTINUE_PRE_SELECTION
                           | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
    {
      set_region (modr, w_selection_region.p1, w_selection_region.p2);
      w_selection_type = Buffer::SELECTION_VOID;
      w_selection_point = NO_MARK_SET;
      w_selection_marker = NO_MARK_SET;
    }
  (int &)w_selection_type &= ~Buffer::CONTINUE_PRE_SELECTION;

  if (w_reverse_region.p1 != NO_MARK_SET)
    {
      set_region (modr, w_reverse_region.p1, w_reverse_region.p2);
      if ((w_reverse_temp & (Buffer::CONTINUE_PRE_SELECTION
                             | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
        {
          w_reverse_region.p1 = NO_MARK_SET;
          w_reverse_region.p2 = NO_MARK_SET;
          w_reverse_temp = Buffer::SELECTION_VOID;
        }
    }
  (int &)w_reverse_temp &= ~Buffer::CONTINUE_PRE_SELECTION;

  if (w_selection_type != Buffer::SELECTION_VOID)
    {
      point_t p1, p2;
      point_t p = (w_selection_point == NO_MARK_SET
                   ? w_point.p_point : w_selection_point);
      if (w_selection_marker < p)
        {
          p1 = w_selection_marker;
          p2 = p;
        }
      else
        {
          p1 = p;
          p2 = w_selection_marker;
        }

      switch (w_selection_type & Buffer::SELECTION_TYPE_MASK)
        {
        case Buffer::SELECTION_RECTANGLE:
          if (w_disp_flags & (WDF_GOAL_COLUMN | WDF_SET_GOAL_COLUMN))
            set_region (modr, p1, p2);
          break;

        case Buffer::SELECTION_LINEAR:
          if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
            {
              p1 = bol_point (p1);
              p2 = bol_point (p2);
            }
          else
            {
              p1 = folded_bol_point (p1);
              p2 = folded_bol_point (p2);
            }
          break;
        }
      if (p1 != w_selection_region.p1)
        set_region (modr, p1, w_selection_region.p1);
      if (p2 != w_selection_region.p2)
        set_region (modr, p2, w_selection_region.p2);
      w_selection_region.p1 = p1;
      w_selection_region.p2 = p2;
    }

  int need_repaint = ((w_disp_flags & (WDF_WINDOW | WDF_MODELINE | WDF_PENDING))
                      || modr.p1 != -1
                      || w_last_disp != w_disp
                      || w_last_top_column != w_top_column);

  long mark_linenum = ((symbol_value (Vinverse_mark_line, w_bufp) != Qnil
                        && w_mark != NO_MARK_SET)
                       ? (w_bufp->b_fold_columns == Buffer::FOLD_NONE
                          ? w_bufp->point_linenum (w_mark)
                          : w_bufp->folded_point_linenum (w_mark))
                       : -1);
  if (mark_linenum != w_last_mark_linenum)
    {
      w_last_mark_linenum = mark_linenum;
      need_repaint = 1;
    }

  if (!need_repaint && w_point.p_point == w_last_point)
    {
#ifdef DEBUG
      if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
        {
          assert (w_linenum == w_bufp->point_linenum (w_point));
          assert (w_column == w_bufp->point_column (w_point));
        }
      else
        {
          assert (w_linenum == w_bufp->folded_point_linenum (w_point));
          assert (w_column == w_bufp->folded_point_column (w_point));
        }
#endif
      if (w_disp_flags & WDF_GOAL_COLUMN)
        w_goal_column = w_column;
      paint_cursor_line (0, 0);
      return;
    }

  w_last_point = w_point.p_point;

  long linenum, column;
  if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
    {
      linenum = w_bufp->point_linenum (w_point);
      column = w_bufp->point_column (w_point);
      w_plinenum = linenum;
    }
  else
    {
      linenum = w_bufp->folded_point_linenum_column (w_point, &column);
      w_plinenum = (w_bufp->linenum_mode () == Buffer::LNMODE_LF
                    ? w_bufp->point_linenum (w_point)
                    : linenum);
    }

  long olinenum = w_linenum;
  w_linenum = linenum;
  w_column = column;
  if (w_disp_flags & WDF_GOAL_COLUMN)
    w_goal_column = column;

  int maxwidth = w_ech.cx - w_bufp->b_prompt_columns;
  if (flags () & WF_LINE_NUMBER)
    maxwidth -= LINENUM_COLUMNS + 1;

  if (w_point.p_offset != w_point.p_chunk->c_used)
    {
      Char c = w_point.ch ();
      if (c != CC_LFD && c != CC_TAB && char_width (c) == 2)
        maxwidth--;
    }

  maxwidth = max (maxwidth, 0);

  int hjump = w_bufp->b_hjump_columns;
  if (hjump <= 0)
    hjump = w_hjump_columns;

  if (column < w_top_column)
    w_top_column = column / hjump * hjump;
  else if (column >= w_top_column + maxwidth)
    w_top_column = ((column - maxwidth + hjump) / hjump * hjump);

  if (column < w_top_column || column - w_top_column >= maxwidth)
    w_top_column = column;

  if (w_top_column != w_last_top_column)
    need_repaint = 1;

  int hide = symbol_value (Vhide_restricted_region, w_bufp) != Qnil;
  if (hide && w_disp < w_bufp->b_contents.p1)
    w_disp = w_bufp->b_contents.p1;

  long last_linenum, disp_linenum;
  if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
    {
      last_linenum = w_bufp->point_linenum (w_last_disp);
      disp_linenum = (w_disp == w_last_disp
                      ? last_linenum
                      : w_bufp->point_linenum (w_disp));
    }
  else
    {
      last_linenum = w_bufp->folded_point_linenum (w_last_disp);
      disp_linenum = (w_disp == w_last_disp
                      ? last_linenum
                      : w_bufp->folded_point_linenum (w_disp));
    }

  if (flags () & WF_SCROLLING)
    w_disp_flags |= WDF_REFRAME_SCROLL;

  long scroll_margin;
  safe_fixnum_value (symbol_value (Vscroll_margin, w_bufp),
                     &scroll_margin);
  scroll_margin = max (0L, min (scroll_margin, long ((w_ech.cy - 1) / 2)));

  if (w_ignore_scroll_margin)
    {
      if (!scroll_margin
          || (linenum >= disp_linenum + scroll_margin
              && linenum < disp_linenum + w_ech.cy - scroll_margin))
        w_ignore_scroll_margin = 0;
      else
        scroll_margin = min (w_ignore_scroll_margin - 1, int (w_ech.cy - 1) / 2);
    }

  long jump_scroll;
  safe_fixnum_value (symbol_value (Vjump_scroll_threshold, w_bufp),
                     &jump_scroll);
  jump_scroll = max (0L, jump_scroll);

  if (w_disp_flags & WDF_DELETE_TOP
      && xsymbol_value (Vold_relocation_method) == Qnil)
    disp_linenum = linenum - max (0L, min (olinenum - w_last_top_linenum,
                                           long (w_ech.cy - 1)));
  else if (linenum < disp_linenum + scroll_margin)
    {
      if (linenum >= disp_linenum - jump_scroll
          || w_disp_flags & WDF_REFRAME_SCROLL
          || w_disp > w_bufp->b_contents.p2)
        disp_linenum = linenum - scroll_margin;
      else
        disp_linenum = linenum - w_ech.cy / 2;
    }
  else if (linenum >= disp_linenum + w_ech.cy - scroll_margin)
    {
      if (linenum < disp_linenum + w_ech.cy + jump_scroll
          || w_disp_flags & WDF_REFRAME_SCROLL
          || w_disp < w_bufp->b_contents.p1)
        disp_linenum = linenum - w_ech.cy + scroll_margin + 1;
      else
        disp_linenum = linenum - w_ech.cy / 2;
    }
  disp_linenum = max (1L, disp_linenum);

  Point df;
  disp_linenum = (w_bufp->b_fold_columns == Buffer::FOLD_NONE
                  ? w_bufp->linenum_point (df, disp_linenum)
                  : w_bufp->folded_linenum_point (df, disp_linenum));

  if (!need_repaint && df.p_point == w_last_disp)
    {
      w_disp = w_last_disp;
      paint_cursor_line (0, 0);
      return;
    }

  w_last_disp = w_disp = df.p_point;

  if (!w_glyphs.g_rep && !alloc_glyph_rep ())
    {
      w_last_top_column = w_top_column;
      w_last_top_linenum = disp_linenum;
      w_last_flags = flags ();
      return;
    }

  hide_caret ();

  if (!need_repaint && w_top_column == w_last_top_column)
    {
      int dy = last_linenum - disp_linenum;
      if (dy && dy >= -w_ch_max.cy * 2 / 3 && dy <= w_ch_max.cy * 2 / 3)
        {
          scroll_lines (dy);
          redraw_window (df, disp_linenum, 0, hide);
          goto paint;
        }
    }

  redraw_window (df, disp_linenum, 1, hide);
  if (xsymbol_value (Vsi_find_motion) != Qnil)
    find_motion ();

paint:
  HDC hdc = GetDC (w_hwnd);
  if (w_cursor_line.ypixel >= 0
      && w_cursor_line.x1 == app.text_font.cell ().cx / 2
      && flags () & WF_LINE_NUMBER)
    erase_cursor_line (hdc);
  paint_window (hdc);
  w_last_top_column = w_top_column;
  w_last_top_linenum = disp_linenum;
  w_last_flags = flags ();
  paint_cursor_line (hdc, 1);
  ReleaseDC (w_hwnd, hdc);
  return;
}

void
Window::paint_minibuffer_message (lisp string)
{
  if (!w_glyphs.g_rep && !alloc_glyph_rep ())
    return;

  glyph_data **gr = w_glyphs.g_rep->gr_nglyph;

  glyph_t *g = (*gr)->gd_cc;
  glyph_t *ge = g + w_ch_max.cx;
  *g++ = ' ';

  const ucs4_t *p = xstring_contents (string);
  const ucs4_t *pe = p + xstring_length (string);

  while (g < ge && p < pe)
    {
      ucs4_t cc = *p++;
      if (cc < ' ')
        {
          if (g + 1 == ge)
            break;
          *g++ = GLYPH_CTRL | '^';
          *g++ = GLYPH_CTRL | cc + '@';
        }
      else if (cc == CC_DEL)
        {
          if (g + 1 == ge)
            break;
          *g++ = GLYPH_CTRL | '^';
          *g++ = GLYPH_CTRL | '?';
        }
      else
        {
          u_int32_t cp = u_int32_t (cc);
          int w = unicode_width (cp);
          if (w == 2)
            {
              if (g + 1 == ge)
                break;
              g = glyph_dbchar (g, cp, 0, 0);
            }
          else
            g = glyph_sbchar (g, cp, 0, 0);
        }
    }

  app.minibuffer_prompt_column = g - (*gr)->gd_cc;

  for (; g > (*gr)->gd_cc && g[-1] == ' '; g--)
    ;
  *g = 0;
  (*gr)->gd_len = g - (*gr)->gd_cc;
  (*gr)->gd_mod = 1;

  gr++;
  for (int y = 1; y < w_ch_max.cy; y++, gr++)
    {
      (*gr)->gd_len = 0;
      (*gr)->gd_cc[0] = 0;
      (*gr)->gd_mod = 1;
    }

  hide_caret ();

  HDC hdc = GetDC (w_hwnd);
  paint_window (hdc);
  ReleaseDC (w_hwnd, hdc);

  update_caret ();
}

void
Window::clear_window ()
{
  if (!w_glyphs.g_rep && !alloc_glyph_rep ())
    return;

  glyph_data **g = w_glyphs.g_rep->gr_nglyph;
  for (int y = 0; y < w_ch_max.cy; y++, g++)
    {
      (*g)->gd_len = 0;
      (*g)->gd_cc[0] = 0;
      (*g)->gd_mod = 1;
    }

  HDC hdc = GetDC (w_hwnd);
  paint_window (hdc);
  paint_cursor_line (hdc, 1);
  ReleaseDC (w_hwnd, hdc);
}

static inline void
format_point (char *b, int l, int c)
{
  sprintf (b, "%10u:%-10u", l, c + 1);
}

/*
  012345678901234567890
  xxxxxxxxxx:xxxxxxxxxx
      654321 123456
 */
static void
point_from_end (const char *buf, const char *&bb, const char *&be)
{
  const char *b, *e;
  for (b = buf + 4; b > buf && b[-1] != ' '; b--)
    ;
  for (e = buf + 17; *e && *e != ' '; e++)
    ;
  bb = b;
  be = e;
}

static int
calc_point_width (int l, int c)
{
  char buf[32];
  format_point (buf, l, c);
  const char *b, *e;
  point_from_end (buf, b, e);
  return e - b;
}

static void
format_percent(char* buf, int size, int percent)
{
  sprintf_s(buf, size, "%d", percent);
}

bool
mode_line_percent_painter::need_repaint_all ()
{
	char buf[32];
	format_percent(buf, 32, m_percent);
	return m_point_pixel >= 0 && strlen(buf) != m_last_width;

}

int
mode_line_percent_painter::calc_percent (Buffer* bufp, point_t point)
{
  if(bufp->b_nchars > 0)
    return (100*point) / bufp->b_nchars;
  if(point == 0) // 0/0, treat as 0.
	return 0;
  return -1;
}


int
mode_line_percent_painter::paint_percent (HDC hdc)
{

  RECT r;
  r.top = 1;
  r.bottom = m_ml_size.cy - 1;
  r.left = m_point_pixel;

  char nb[32];
  format_percent(nb, 32, m_percent);
  m_last_width = strlen(nb);

  wchar_t wnb[32];
  for (int i = 0; i < m_last_width; i++)
    wnb[i] = (unsigned char)nb[i];

  SIZE size;
  GetTextExtentPoint32W (hdc, wnb, m_last_width, &size);

  long right = size.cx + r.left;
  r.right = min(right, m_ml_size.cx - 1);

  ExtTextOutW (hdc,
               m_point_pixel ,
               1 + m_modeline_paramp->m_exlead,
               ETO_OPAQUE | ETO_CLIPPED, &r, wnb, m_last_width, 0);
  m_last_percent = m_percent;
  

  return (int)right;
}


bool
mode_line_point_painter::need_repaint_all()
{
	return m_point_pixel >= 0 && calc_point_width (m_plinenum, m_column) != m_last_ml_point_width;
}

int
mode_line_point_painter::paint_point (HDC hdc)
{
  if (m_point_pixel < 0)
    return 0;
  if (m_column == m_last_ml_column && m_plinenum == m_last_ml_linenum)
    return 0;

  RECT r;
  r.top = 1;
  r.bottom = m_ml_size.cy - 1;

  char nb[32];
  format_point (nb, m_plinenum, m_column);
  const char *b, *e;
  point_from_end (nb, b, e);
  m_last_ml_point_width = e - b;

  int x0 = (m_point_pixel + m_modeline_paramp->m_exts[1]
            - m_modeline_paramp->m_exts[b - nb]);
  int right = (x0 + m_modeline_paramp->m_exts[e - nb]
               + m_modeline_paramp->m_exts[1]);

  if (m_last_ml_linenum < 0)
    {
      r.left = m_point_pixel;
      r.right = min (right, int (m_ml_size.cx - 1));
    }
  else
    {
      char ob[32];
      format_point (ob, m_last_ml_linenum, m_last_ml_column);
      int ib = b - nb, ie = e - nb;
      for (; ib < ie && ob[ib] == nb[ib]; ib++)
        ;
      for (; ie > ib && ob[ie - 1] == nb[ie - 1]; ie--)
        ;
      r.left = x0 + m_modeline_paramp->m_exts[ib];
      r.right = min (x0 + m_modeline_paramp->m_exts[ie], int (m_ml_size.cx - 1));
      b = nb + ib;
      e = nb + ie;
    }

  for (; b < e && *b == ' '; b++)
    ;
  for (; e > b && e[-1] == ' '; e--)
    ;

  {
    wchar_t wb[32];
    int wlen = e - b;
    for (int i = 0; i < wlen; i++)
      wb[i] = (unsigned char)b[i];
    ExtTextOutW (hdc,
                 x0 + m_modeline_paramp->m_exts[b - nb],
                 1 + m_modeline_paramp->m_exlead,
                 ETO_OPAQUE | ETO_CLIPPED, &r, wb, wlen, 0);
  }
  m_last_ml_column = m_column;
  m_last_ml_linenum = m_plinenum;
  return right;
}


void
Window::paint_mode_line (Painter &painter)
{
  /* Phase 2: mode line は Char * (UTF-16 code unit) で組み立てて直接
     描画する。旧実装は cp932 バイト列 → cp932_to_wcs で非 cp932 chars が
     '?' に落ちていた。
     issue #13 step 3e: body text/border は Painter 経由
     (draw_text_chars(PFONT_MODELINE) / draw_hline / draw_vline)。point/
     percent サブペインタ (paint_point/paint_percent) は cross-frontend な
     virtual (cli/ncurses stub あり) で hdc に modeline font/colors が
     selected 済みである前提なので、まだ HDC のまま据え置き、Win32Painter
     から取り出した hdc を渡す。 */
  Char *b0, *b;
  Char *posp = 0;
  Char *percentp = 0;

  w_ime_mode_line = 0;
  lisp fmt = symbol_value (Vmode_line_format, w_bufp);
  if (stringp (fmt))
    {
      int l = max (int (w_ch_max.cx), 512);
      b0 = (Char *)alloca ((l + 10) * sizeof (Char));
      b = b0;
      *b++ = ' ';

      buffer_info binfo (this, w_bufp, &posp, &w_ime_mode_line, &percentp);
      b = binfo.format (fmt, b, b0 + l);
    }
  else
    b0 = b = 0;

  COLORREF mlfg, mlbg;
  if (w_inverse_mode_line)
    {
      mlfg = modeline_colors[MLCI_FOREGROUND];
      mlbg = modeline_colors[MLCI_BACKGROUND];
    }
  else
    {
      mlfg = w_colors[WCOLOR_MODELINE_FG];
      mlbg = w_colors[WCOLOR_MODELINE_BG];
    }

  /* sub-painters still draw via HDC and assume the modeline font + colors
     are already selected; set them up here and feed them the raw hdc. */
  HDC hdc = static_cast <Win32Painter &> (painter).hdc ();
  COLORREF ofg = SetTextColor (hdc, mlfg);
  COLORREF obg = SetBkColor (hdc, mlbg);
  HGDIOBJ of = SelectObject (hdc, app.modeline_param.m_hfont);

  RECT r;
  r.left = 1;
  r.top = 1;
  r.right = w_ml_size.cx - 1;
  r.bottom = w_ml_size.cy - 1;

  std::list<mode_line_painter*> painters;
  w_point_painter.set_posp(posp);
  w_percent_painter.set_posp(percentp);
  if(posp) {
	  w_point_painter.setup_paint(&app.modeline_param, w_column, w_plinenum, w_ml_size);
	  painters.push_back(&w_point_painter);
  }
  else
  {
	  w_point_painter.no_format_specifier();
  }


  if(percentp) {
	  w_percent_painter.setup_paint(&app.modeline_param, mode_line_percent_painter::calc_percent(w_bufp, w_point.p_point), w_ml_size);

	  if(posp && posp > percentp) // tenuki sort.
		  painters.push_front(&w_percent_painter);
	  else
		  painters.push_back(&w_percent_painter);
  }
  else
  {
	  w_percent_painter.no_format_specifier();
  }


  if (painters.size() == 0)
    {
      painter.draw_text_chars (1, 1 + app.modeline_param.m_exlead,
                               b0, int (b - b0), mlfg, mlbg,
                               PFONT_MODELINE, &r, true);
    }
  else
    {
	  Char *b1 = b0;
	  for(std::list<mode_line_painter*>::iterator it = painters.begin(); it != painters.end(); it++)
	  {
		  mode_line_painter * mlp = *it;

		  int point_start_px;

		  if(mlp->get_posp() - b1 == 0)
		  {
			  point_start_px = r.left;
		  }
		  else
		  {
			  int wmll = int (mlp->get_posp() - b1);
			  point_start_px = r.left + painter.text_chars_width (b1, wmll, PFONT_MODELINE);

			  r.right = min (point_start_px, int (w_ml_size.cx - 1));
			  painter.draw_text_chars (r.left, 1 + app.modeline_param.m_exlead,
								   b1, wmll, mlfg, mlbg, PFONT_MODELINE, &r, true);
		  }

		  r.left = mlp->first_paint(hdc, point_start_px);
		  b1 = mlp->get_posp();
	  }

      r.right = w_ml_size.cx - 1;
      painter.draw_text_chars (r.left, 1 + app.modeline_param.m_exlead,
                               b1, int (b - b1), mlfg, mlbg,
                               PFONT_MODELINE, &r, true);
    }

  SelectObject (hdc, of);
  SetTextColor (hdc, ofg);
  SetBkColor (hdc, obg);

  /* 3D bevel border (was CreatePen/MoveToEx/LineTo): highlight top+left,
     shadow right+bottom. LineTo excludes its endpoint pixel; the hline/
     vline ranges below reproduce the same pixel coverage. */
  painter.draw_vline (0, 1, w_ml_size.cy - 1, sysdep.btn_highlight);
  painter.draw_hline (0, w_ml_size.cx - 1, 0, sysdep.btn_highlight);
  painter.draw_vline (w_ml_size.cx - 1, 0, w_ml_size.cy - 1, sysdep.btn_shadow);
  painter.draw_hline (0, w_ml_size.cx, w_ml_size.cy - 1, sysdep.btn_shadow);
}

/* issue #13 step 3e: HDC entry point wraps the Painter& version. */
void
Window::paint_mode_line (HDC hdc)
{
  Win32Painter painter (hdc, 0);
  paint_mode_line (painter);
}

void
Window::paint_mode_line ()
{
  PAINTSTRUCT ps;
  if (w_disp_flags & WDF_MODELINE)
    {
      BeginPaint (w_hwnd_ml, &ps);
      EndPaint (w_hwnd_ml, &ps);
      HDC hdc = GetDC (w_hwnd_ml);
      paint_mode_line (hdc);
      ReleaseDC (w_hwnd_ml, hdc);
    }
  else
    {
      HDC hdc = BeginPaint (w_hwnd_ml, &ps);
      paint_mode_line (hdc);
      EndPaint (w_hwnd_ml, &ps);
    }
}

inline void
Window::update_mode_line_vars (int i, lisp var)
{
  lisp val = symbol_value (var, w_bufp);
  if (w_last_vars[i] != val)
    {
      w_last_vars[i] = val;
      w_disp_flags |= WDF_MODELINE;
    }
}

inline void
Window::update_mode_line_vars ()
{
  update_mode_line_vars (LV_MODE_NAME, Vmode_name);
  update_mode_line_vars (LV_MODE_LINE_FORMAT, Vmode_line_format);
  update_mode_line_vars (LV_READ_ONLY, Vbuffer_read_only);
  update_mode_line_vars (LV_OVERWRITE, Voverwrite_mode);
  update_mode_line_vars (LV_AUTO_FILL, Vauto_fill);
}

int
Window::redraw_mode_line ()
{
  if (!w_hwnd_ml)
    return 0;
  if (xsymbol_value (Vinverse_mode_line) == Qnil)
    {
      if (w_inverse_mode_line)
        {
          w_disp_flags |= WDF_MODELINE;
          w_inverse_mode_line = 0;
        }
    }
  else if (w_inverse_mode_line != (selected_window () == this))
    {
      w_disp_flags |= WDF_MODELINE;
      w_inverse_mode_line ^= 1;
    }

  update_mode_line_vars ();

  int r;

  HDC hdc = GetDC (w_hwnd_ml);
  // a little slow. we can avoid this setup if we check validity.
  w_point_painter.setup_paint(&app.modeline_param, w_column, w_plinenum, w_ml_size);
  w_percent_painter.setup_paint(&app.modeline_param, mode_line_percent_painter::calc_percent(w_bufp, w_point.p_point), w_ml_size);

  if (w_disp_flags & WDF_MODELINE
      || w_point_painter.need_repaint_all()
	  || w_percent_painter.need_repaint_all())
    {
      paint_mode_line (hdc);
      w_disp_flags &= ~WDF_MODELINE;
      r = 1;
    }
  else
    {
      COLORREF ofg, obg;
      if (w_inverse_mode_line)
        {
          ofg = SetTextColor (hdc, modeline_colors[MLCI_FOREGROUND]);
          obg = SetBkColor (hdc, modeline_colors[MLCI_BACKGROUND]);
        }
      else
        {
          ofg = SetTextColor (hdc, w_colors[WCOLOR_MODELINE_FG]);
          obg = SetBkColor (hdc, w_colors[WCOLOR_MODELINE_BG]);
        }
      HGDIOBJ of = SelectObject (hdc, app.modeline_param.m_hfont);

	  // order is not important.
	  w_point_painter.update_paint(hdc);
	  w_percent_painter.update_paint(hdc);

      SelectObject (hdc, of);
      SetTextColor (hdc, ofg);
      SetTextColor (hdc, obg);
      r = 0;
    }
  ReleaseDC (w_hwnd_ml, hdc);
  return r;
}

int
Window::refresh (int f)
{
  assert (IsWindow (w_hwnd));

  if (!w_next && stringp (xsymbol_value (Vminibuffer_message)))
    {
      if (w_disp_flags & (WDF_WINDOW | WDF_PENDING))
        {
          paint_minibuffer_message (xsymbol_value (Vminibuffer_message));
          w_disp_flags &= ~(WDF_WINDOW | WDF_PENDING);
        }
      return 0;
    }

  if (w_bufp != w_last_bufp)
    {
      // Switching to/from terminal buffer: force full repaint
      // because terminal rendering bypasses the glyph system
      if ((w_last_bufp && buffer_terminal (w_last_bufp))
          || (w_bufp && buffer_terminal (w_bufp)))
        InvalidateRect (w_hwnd, 0, TRUE);
      w_last_bufp = w_bufp;
      w_top_column = 0;
      w_selection_region.p1 = -1;
      w_disp_flags |= WDF_WINDOW | WDF_MODELINE;
    }

  if (flags () != w_last_flags)
    w_disp_flags |= WDF_WINDOW;

  // Terminal buffer: bypass normal glyph rendering
  if (w_bufp)
    {
      int tr = refresh_terminal (f);
      if (tr >= 0)
        return tr;
    }

  int r = 0;
  if (w_bufp)
    {
      int owf = w_disp_flags;
      Buffer::selection_type ost = w_selection_type;
      Buffer::selection_type ort = w_reverse_temp;
      if (!f)
        {
          (int &)w_selection_type |= Buffer::CONTINUE_PRE_SELECTION;
          (int &)w_reverse_temp |= Buffer::CONTINUE_PRE_SELECTION;
        }

      if (w_bufp->b_last_narrow_depth != w_bufp->b_narrow_depth)
        {
          if (!w_bufp->b_last_narrow_depth || !w_bufp->b_narrow_depth)
            w_disp_flags |= WDF_WINDOW | WDF_MODELINE;
          else
            w_disp_flags |= WDF_WINDOW;
        }

      if (f)
        w_bufp->check_range (w_point);

      reframe ();
      if (flags () & Window::WF_RULER)
        update_ruler ();
      r = redraw_mode_line ();

      if (f)
        w_disp_flags = 0;
      else
        {
          w_disp_flags = owf & (WDF_GOAL_COLUMN | WDF_SET_GOAL_COLUMN);
          w_selection_type = ost;
          w_reverse_temp = ort;
        }
    }
  else if (w_disp_flags & (WDF_WINDOW | WDF_PENDING))
    clear_window ();

  update_vscroll_bar ();
  update_hscroll_bar ();
  update_caret ();
  return r;
}

void
Window::pending_refresh ()
{
  if (!w_bufp)
    return;

  if ((w_selection_type & (Buffer::CONTINUE_PRE_SELECTION
                           | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
    {
      w_disp_flags |= WDF_WINDOW;
      w_selection_type = Buffer::SELECTION_VOID;
      w_selection_point = NO_MARK_SET;
      w_selection_marker = NO_MARK_SET;
    }
  (int &)w_selection_type &= ~Buffer::CONTINUE_PRE_SELECTION;

  if (w_reverse_region.p1 != NO_MARK_SET
      && (w_reverse_temp & (Buffer::CONTINUE_PRE_SELECTION
                            | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
    {
      w_disp_flags |= WDF_WINDOW;
      w_reverse_region.p1 = NO_MARK_SET;
      w_reverse_region.p2 = NO_MARK_SET;
      w_reverse_temp = Buffer::SELECTION_VOID;
    }
  (int &)w_reverse_temp &= ~Buffer::CONTINUE_PRE_SELECTION;

  w_disp_flags |= WDF_REFRAME_SCROLL | WDF_PENDING;

  if (w_point.p_point == w_last_point)
    {
#ifdef DEBUG
      if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
        {
          assert (w_linenum == w_bufp->point_linenum (w_point));
          assert (w_column == w_bufp->point_column (w_point));
        }
      else
        {
          assert (w_linenum == w_bufp->folded_point_linenum (w_point));
          assert (w_column == w_bufp->folded_point_column (w_point));
        }
#endif
    }
  else
    {
      w_last_point = w_point.p_point;
      if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
        {
          w_linenum = w_bufp->point_linenum (w_point);
          w_column = w_bufp->point_column (w_point);
        }
      else
        w_linenum = w_bufp->folded_point_linenum_column (w_point, &w_column);
    }

  if (w_linenum < w_last_top_linenum)
    w_last_top_linenum = w_linenum;
  else if (w_linenum >= w_last_top_linenum + w_ech.cy)
    w_last_top_linenum = w_linenum - w_ech.cy + 1;

  if (w_disp_flags & WDF_GOAL_COLUMN)
    w_goal_column = w_column;
}

// ============================================================
// Terminal (ConPTY) direct GDI rendering
// ============================================================

// xterm 256-color palette → COLORREF
static COLORREF
term_color_to_rgb (const Terminal *term, term_color_t tc)
{
  /* xterm の標準 16 色。以前は VGA 相当の値だったが、xterm / Windows
     Terminal の既定に寄せる。 */
  static const COLORREF basic16[] = {
    RGB(0,0,0),       RGB(205,0,0),     RGB(0,205,0),     RGB(205,205,0),
    RGB(0,0,238),     RGB(205,0,205),   RGB(0,205,205),   RGB(229,229,229),
    RGB(127,127,127), RGB(255,0,0),     RGB(0,255,0),     RGB(255,255,0),
    RGB(92,92,255),   RGB(255,0,255),   RGB(0,255,255),   RGB(255,255,255),
  };
  /* 6x6x6 の色立方体は等間隔ではない。xterm はこの 6 段。以前は 51 の
     倍数 (0,51,102,...) にしていたので、暗い側の色がまとめて明るく出た。 */
  static const int cube[6] = {0, 95, 135, 175, 215, 255};

  if (tc == TCOLOR_DEFAULT)
    return CLR_INVALID;

  if ((tc & TCOLOR_TAG_MASK) == TCOLOR_RGB)
    {
      uint32_t v = TCOLOR_VALUE (tc);
      return RGB ((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff);
    }

  int n = int (TCOLOR_VALUE (tc));
  if (n < 0 || n > 255)
    return CLR_INVALID;

  /* OSC 4 でテーマが差し替えた色が優先。 */
  if (term)
    {
      int32_t ov = term->palette_entry (n);
      if (ov >= 0)
        return RGB ((ov >> 16) & 0xff, (ov >> 8) & 0xff, ov & 0xff);
    }

  if (n < 16)
    return basic16[n];
  if (n < 232)
    {
      /* index 16 が色立方体の先頭。以前は 17 を引いた値をそのまま立方体の
         index にしていたので、全体が 16 ずれて色相が合っていなかった。 */
      int i = n - 16;
      return RGB (cube[(i / 36) % 6], cube[(i / 6) % 6], cube[i % 6]);
    }
  /* 232-255 はグレースケール 24 段 */
  int v = (n - 232) * 10 + 8;
  return RGB (v, v, v);
}

void
Window::paint_terminal (Painter &painter, Terminal *term)
{
  /* issue #13 step 3g: terminal grid rendering via Painter. The terminal
     itself (Terminal, an escape-sequence parser / virtual screen in
     core/term.h) is platform-neutral and the PTY backend (ConPTY vs pty)
     lives in the process layer, so the only Win32 residual here is the
     cursor cell, drawn with InvertRect (no neutral Painter equivalent);
     it uses the hdc obtained from the Win32Painter (documented). */
  int cellw = app.text_font.cell ().cx;
  int cellh = app.text_font.cell ().cy;
  int trows = term->rows ();
  int tcols = term->cols ();

  const FontObject &ascii_font = app.text_font.font (FONT_ASCII);
  const FontObject &jp_font = app.text_font.font (FONT_JP);

  // Terminal defaults: white on black (like a real terminal)
  COLORREF def_fg = RGB(192, 192, 192);
  COLORREF def_bg = RGB(0, 0, 0);

  for (int r = 0; r < w_ch_max.cy; r++)
    {
      int py = r * cellh;
      for (int c = 0; c < w_ch_max.cx; )
        {
          if (r >= trows || c >= tcols)
            {
              // Beyond terminal grid — fill with background
              int x = c * cellw + cellw / 2;
              painter.fill_rect (x, py, w_client.cx - x, cellh, def_bg);
              c = w_ch_max.cx;
              continue;
            }

          const TermCell *tc = term->display_cell (r, c);
          if (tc->wide == 2)
            { c++; continue; }

          term_color_t fg_c = tc->fg;
          term_color_t bg_c = tc->bg;
          uint8_t attrs = tc->attrs;

          if (attrs & TATTR_REVERSE)
            { term_color_t tmp = fg_c; fg_c = bg_c; bg_c = tmp; }

          /* 既定色は buffer の色 (def_fg / def_bg)。REVERSE で入れ替わった
             側も既定色でありうるので、入れ替え後に判定する。 */
          COLORREF fg = (fg_c == TCOLOR_DEFAULT
                         ? ((attrs & TATTR_REVERSE) ? def_bg : def_fg)
                         : term_color_to_rgb (term, fg_c));
          COLORREF bg = (bg_c == TCOLOR_DEFAULT
                         ? ((attrs & TATTR_REVERSE) ? def_fg : def_bg)
                         : term_color_to_rgb (term, bg_c));

          if (attrs & TATTR_DIM)
            {
              fg = RGB(GetRValue(fg)/2, GetGValue(fg)/2, GetBValue(fg)/2);
            }
          if (attrs & TATTR_INVISIBLE)
            fg = bg;

          int cw = (tc->wide == 1) ? 2 : 1;  // character cell width

          /* TermCell::ch は code point。GDI に渡すのは UTF-16 なので、
             BMP 外は surrogate pair の 2 単位にする。 */
          ucs4_t ich = tc->ch;
          Char wc[2];
          int wcl = 1;
          if (ich == 0 || ich == ' ')
            wc[0] = ' ';
          else if (ich < 0x10000)
            wc[0] = Char (ich);
          else
            {
              wc[0] = utf16_ucs4_to_pair_high (ich);
              wc[1] = utf16_ucs4_to_pair_low (ich);
              wcl = 2;
            }

          int px = c * cellw + cellw / 2;
          RECT rc = { px, py, px + cw * cellw, py + cellh };

          int role = (tc->wide == 1) ? FONT_JP : FONT_ASCII;
          const FontObject &cell_font = (tc->wide == 1) ? jp_font : ascii_font;
          painter.draw_text_chars (px + cell_font.offset ().x,
                                   py + cell_font.offset ().y,
                                   wc, wcl, fg, bg, role, &rc, true);

          if (attrs & TATTR_UNDERLINE)
            painter.draw_hline (px, px + cw * cellw, py + cellh - 1, fg);

          if (attrs & TATTR_STRIKE)
            painter.draw_hline (px, px + cw * cellw, py + cellh / 2, fg);

          if (attrs & TATTR_BOLD)
            // Draw again offset by 1 pixel for bold effect (transparent)
            painter.draw_text_chars (px + cell_font.offset ().x + 1,
                                     py + cell_font.offset ().y,
                                     wc, wcl, fg, bg, role, &rc, false);

          c += cw;
        }
    }

  // Draw cursor — InvertRect has no neutral Painter equivalent; use the
  // Win32Painter's hdc directly (this is the Win32 terminal impl).
  int cr = term->cursor_row ();
  int cc = term->cursor_col ();
  if (cr >= 0 && cr < trows && cc >= 0 && cc < tcols
      && this == selected_window ())
    {
      int cpx = cc * cellw + cellw / 2;
      int cpy = cr * cellh;
      RECT crc = { cpx, cpy, cpx + cellw, cpy + cellh };
      InvertRect (static_cast <Win32Painter &> (painter).hdc (), &crc);
    }

  // Fill area below terminal rows
  if (trows < w_ch_max.cy)
    painter.fill_rect (0, trows * cellh, w_client.cx, w_client.cy - trows * cellh, def_bg);
}

/* issue #13 step 3g: HDC entry point wraps the Painter& version. */
void
Window::paint_terminal (HDC hdc, Terminal *term)
{
  Win32Painter painter (hdc, 0);
  paint_terminal (painter, term);
}

int
Window::refresh_terminal (int f)
{
  Terminal *term = buffer_terminal (w_bufp);
  if (!term)
    return -1;  // not a terminal buffer

  // Resize terminal to match window
  if (term->rows () != w_ech.cy || term->cols () != w_ech.cx)
    {
      extern void buffer_terminal_resize (const Buffer *bp, int rows, int cols);
      buffer_terminal_resize (w_bufp, w_ech.cy, w_ech.cx);
    }

  // Hide Windows caret — terminal draws its own cursor
  hide_caret ();

  int r = redraw_mode_line ();

  // Always repaint terminal (it's cheap compared to glyph diffing)
  {
    HDC hdc = GetDC (w_hwnd);
    paint_terminal (hdc, term);
    ReleaseDC (w_hwnd, hdc);
    term->clear_dirty ();
  }

  w_disp_flags = 0;

  update_vscroll_bar ();
  update_hscroll_bar ();
  return r;
}

void
refresh_screen (int f)
{
  Window::destroy_windows ();
  if (app.active_frame.windows_moved)
    Window::move_all_windows ();

  if (g_frame.modified ())
    recalc_toplevel ();

  lisp lmenu = (win32_menu_p (selected_buffer ()->lmenu)
                ? selected_buffer ()->lmenu
                : (win32_menu_p (xsymbol_value (Vdefault_menu))
                   ? xsymbol_value (Vdefault_menu)
                   : Qnil));
  if (lmenu != xsymbol_value (Vlast_active_menu))
    {
      if (SetMenu (app.toplev, lmenu == Qnil ? 0 : xwin32_menu_handle (lmenu)))
        {
          DrawMenuBar (app.toplev);
#ifndef WINDOWBLINDS_FIXED // WindowBlinds�΍�
          if (lmenu == Qnil || xsymbol_value (Vlast_active_menu) == Qnil)
            {
              RECT r;
              GetWindowRect (app.toplev, &r);
              int w = r.right - r.left;
              int h = r.bottom - r.top;
              MoveWindow (app.toplev, r.left, r.top, w - 1, h - 1, 1);
              MoveWindow (app.toplev, r.left, r.top, w, h, 1);
            }
#endif /* WINDOWBLINDS_FIXED */
          xsymbol_value (Vlast_active_menu) = lmenu;
        }
    }

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    UpdateWindow (wp->w_hwnd);

  int update_title_bar = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->refresh (f) && wp == selected_window ())
      update_title_bar = 1;

  app.stat_area.update ();

  for (Buffer *bp = Buffer::b_blist; bp; bp = bp->b_next)
    {
      bp->b_modified_region.p1 = -1;
      bp->b_last_narrow_depth = bp->b_narrow_depth;
    }

  if (f)
    {
      Buffer *bp = selected_buffer ();
      g_frame.update_ui ();
      bp->change_ime_mode ();
      bp->set_frame_title (update_title_bar);
      bp->dlist_add_head ();
      Fundo_boundary ();
    }
}

void
pending_refresh_screen ()
{
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->pending_refresh ();

  selected_buffer ()->dlist_add_head ();
}

void
Window::paint_background (Painter &painter, int x, int y, int w, int h) const
{
  painter.fill_rect (x, y, w, h, w_colors[WCOLOR_BACK]);
}

/* issue #13 step 3b: HDC entry point wraps the Painter& version. */
void
Window::paint_background (HDC hdc, int x, int y, int w, int h) const
{
  Win32Painter painter (hdc, 0);
  paint_background (painter, x, y, w, h);
}

void
Window::winsize_changed (int w, int h)
{
  int ow = w_clsize.cx;
  w_clsize.cx = w - RIGHT_PADDING;
  if (w_clsize.cx < 0)
    w_clsize.cx = 0;
  w_clsize.cy = h;
#if 0
  if (w_clsize.cx < ow)
    {
      HDC hdc = GetDC (w_hwnd);
      paint_background (hdc, w_clsize.cx, 0, RIGHT_PADDING, h);
      ReleaseDC (w_hwnd, hdc);
    }
#else
  RECT r;
  r.left = w_clsize.cx < ow ? w_clsize.cx : ow;
  r.top = 0;
  r.right = r.left + RIGHT_PADDING;
  r.bottom = h;
  InvalidateRect (w_hwnd, &r, 1);
#endif
  w_disp_flags |= WDF_WINSIZE_CHANGED;
}

void
Window::discard_invalid_region (const PAINTSTRUCT &ps, RECT &r)
{
  r.left = max (0L, ((ps.rcPaint.left - app.text_font.cell ().cx / 2)
                     / app.text_font.cell ().cx));
  r.right = min (w_ch_max.cx,
                 ((ps.rcPaint.right + app.text_font.cell ().cx
                   + app.text_font.cell ().cx / 2 - 1)
                  / app.text_font.cell ().cx));
  r.right = max (r.left, r.right);
  r.top = max (0L, ps.rcPaint.top / app.text_font.cell ().cy);
  r.bottom = min (w_ch_max.cy,
                  ((ps.rcPaint.bottom + app.text_font.cell ().cy - 1)
                   / app.text_font.cell ().cy));
  r.bottom = max (r.top, r.bottom);

  glyph_data **og = w_glyphs.g_rep->gr_oglyph;
  glyph_data **ng = w_glyphs.g_rep->gr_nglyph;
  for (int y = r.top; y < r.bottom; y++)
    if (og[y]->gd_len > r.left || ps.fErase)
      {
        ng[y]->gd_mod = 1;
        glyph_t *p = &og[y]->gd_cc[r.left];
        for (int l = r.right - r.left; l > 0; l--)
          *p++ = GLYPH_JUNK;
        if (r.right > og[y]->gd_len)
          {
            *p = 0;
            og[y]->gd_len = short (r.right);
          }
      }
}

void
Window::update_window ()
{
  // Terminal buffer: paint directly from TermCell
  if (w_bufp)
    {
      Terminal *term = buffer_terminal (w_bufp);
      if (term)
        {
          PAINTSTRUCT ps;
          HDC hdc = BeginPaint (w_hwnd, &ps);
          paint_terminal (hdc, term);
          EndPaint (w_hwnd, &ps);
          return;
        }
    }

  PAINTSTRUCT ps;
  HDC hdc = BeginPaint (w_hwnd, &ps);

  if (!w_glyphs.g_rep)
    {
      EndPaint (w_hwnd, &ps);
      w_disp_flags |= WDF_WINDOW;
      refresh (0);
      return;
    }

  RECT r;
  discard_invalid_region (ps, r);

  if (w_disp_flags & WDF_WINSIZE_CHANGED)
    {
      EndPaint (w_hwnd, &ps);
      w_disp_flags &= ~WDF_WINSIZE_CHANGED;
      w_disp_flags |= WDF_WINDOW;
      refresh (0);
    }
  else
    {
      paint_region (hdc, r.top, r.bottom);
      EndPaint (w_hwnd, &ps);
      paint_cursor_line (0, 1);
    }
  if (this == selected_window ()
      && !app.ime_composition
      && GetFocus () == app.toplev)
    update_caret ();
}

lisp
Frefresh_screen (lisp f)
{
  if (!f || f == Qnil)
    refresh_screen (0);
  else if (f != Qt)
    refresh_screen (1);
  else
    for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
      wp->w_disp_flags |= Window::WDF_WINDOW;
  return Qt;
}
