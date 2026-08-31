#include "stdafx.h"
#include "ed.h"
#include "gdi-utils.h"
#include "resource.h"

/* `src/core/utils.cc` の 518-661 行から移した (issue #195 / #185)。
   **中身は変えていない。** 移した理由はヘッダ (`gdi-utils.h`) に書いてある。 */

void
fill_rect (HDC hdc, const RECT &r, COLORREF c)
{
  COLORREF oc = SetBkColor (hdc, c);
  ExtTextOut (hdc, 0, 0, ETO_OPAQUE, &r, 0, 0, 0);
  SetBkColor (hdc, oc);
}

void
fill_rect (HDC hdc, int x, int y, int cx, int cy, COLORREF c)
{
  RECT r;
  r.left = x;
  r.top = y;
  r.right = x + cx;
  r.bottom = y + cy;
  COLORREF oc = SetBkColor (hdc, c);
  ExtTextOut (hdc, 0, 0, ETO_OPAQUE, &r, 0, 0, 0);
  SetBkColor (hdc, oc);
}

void
draw_hline (HDC hdc, int x1, int x2, int y, COLORREF c)
{
  RECT r;
  r.left = x1;
  r.top = y;
  r.right = x2;
  r.bottom = y + 1;
  COLORREF oc = SetBkColor (hdc, c);
  ExtTextOut (hdc, 0, 0, ETO_OPAQUE, &r, 0, 0, 0);
  SetBkColor (hdc, oc);
}

void
draw_vline (HDC hdc, int y1, int y2, int x, COLORREF c)
{
  RECT r;
  r.left = x;
  r.top = y1;
  r.right = x + 1;
  r.bottom = y2;
  COLORREF oc = SetBkColor (hdc, c);
  ExtTextOut (hdc, 0, 0, ETO_OPAQUE, &r, 0, 0, 0);
  SetBkColor (hdc, oc);
}

/* **この `#if 0` は無効で、下の `#else` の方が動いている。** ペンと
   `SetPixel` で Windows 95 風の 3D の縁を描く版で、xyzzy の履歴のどこかで
   切られた。**移すときに消さなかったのは、消す判断が「見た目をどうするか」
   であって置き場所の話ではないため。** 生きている版は 2 本の線を引くだけの
   単純なもので、`#else` の側にある。 */
#if 0
void
paint_button_off (HDC hdc, const RECT &r)
{
  HGDIOBJ open = SelectObject (hdc, CreatePen (PS_SOLID, 0, sysdep.btn_highlight));
  MoveToEx (hdc, r.left, r.bottom - 1, 0);
  LineTo (hdc, r.left, r.top);
  LineTo (hdc, r.right - 1, r.top);
  DeleteObject (SelectObject (hdc, open));

  open = SelectObject (hdc, sysdep.hpen_black);
  LineTo (hdc, r.right - 1, r.bottom - 1);
  LineTo (hdc, r.left - 1, r.bottom - 1);
  SelectObject (hdc, open);

  open = SelectObject (hdc, CreatePen (PS_SOLID, 0, sysdep.btn_shadow));
  MoveToEx (hdc, r.left + 1, r.bottom - 2, 0);
  LineTo (hdc, r.right - 2, r.bottom - 2);
  LineTo (hdc, r.right - 2, r.top);
  DeleteObject (SelectObject (hdc, open));
}

void
paint_button_on (HDC hdc, const RECT &r)
{
  HGDIOBJ open = SelectObject (hdc, sysdep.hpen_black);
  MoveToEx (hdc, r.left, r.bottom - 1, 0);
  LineTo (hdc, r.left, r.top);
  LineTo (hdc, r.right - 1, r.top);
  SelectObject (hdc, open);

  open = SelectObject (hdc, CreatePen (PS_SOLID, 0, sysdep.btn_highlight));
  LineTo (hdc, r.right - 1, r.bottom - 1);
  LineTo (hdc, r.left - 1, r.bottom - 1);
  DeleteObject (SelectObject (hdc, open));

  open = SelectObject (hdc, CreatePen (PS_SOLID, 0, sysdep.btn_shadow));
  MoveToEx (hdc, r.left + 1, r.bottom - 3, 0);
  LineTo (hdc, r.left + 1, r.top + 1);
  LineTo (hdc, r.right - 2, r.top + 1);
  DeleteObject (SelectObject (hdc, open));

  SetPixel (hdc, r.left + 1, r.bottom - 2, sysdep.btn_face);
  SetPixel (hdc, r.right -2, r.top + 1, sysdep.btn_face);
}
#else
void
paint_button_off (HDC hdc, const RECT &r)
{
  draw_vline (hdc, r.top, r.bottom - 1, r.left, sysdep.btn_highlight);
  draw_hline (hdc, r.left, r.right - 1, r.top, sysdep.btn_highlight);
  draw_vline (hdc, r.top, r.bottom, r.right - 1, sysdep.btn_shadow);
  draw_hline (hdc, r.left, r.right, r.bottom - 1, sysdep.btn_shadow);
}

void
paint_button_on (HDC hdc, const RECT &r)
{
  draw_vline (hdc, r.top, r.bottom - 1, r.left, sysdep.btn_shadow);
  draw_hline (hdc, r.left, r.right - 1, r.top, sysdep.btn_shadow);
  draw_vline (hdc, r.top, r.bottom, r.right - 1, sysdep.btn_highlight);
  draw_hline (hdc, r.left, r.right, r.bottom - 1, sysdep.btn_highlight);
}
#endif

frameDC::frameDC (HWND hwnd, int flags)
     : f_hwnd (hwnd)
{
  f_hdc = GetDCEx (f_hwnd, 0,
                   flags | DCX_CACHE | (LockWindowUpdate (f_hwnd)
                                        ? DCX_LOCKWINDOWUPDATE : 0));
  HBITMAP hbm = LoadBitmap (app.hinst, MAKEINTRESOURCE (IDB_CHECK));
  f_obr = SelectObject (f_hdc, CreatePatternBrush (hbm));
  DeleteObject (hbm);
}

frameDC::~frameDC ()
{
  DeleteObject (SelectObject (f_hdc, f_obr));
  LockWindowUpdate (0);
  ReleaseDC (f_hwnd, f_hdc);
}

void
frameDC::frame_rect (const RECT &r, int w) const
{
  HRGN hrgn1 = CreateRectRgnIndirect (&r);
  HRGN hrgn2 = CreateRectRgn (r.left + w, r.top + w,
                              r.right - w, r.bottom - w);
  CombineRgn (hrgn1, hrgn1, hrgn2, RGN_XOR);
  DeleteObject (hrgn2);
  SelectClipRgn (f_hdc, hrgn1);
  DeleteObject (hrgn1);
  paint (r);
  SelectClipRgn (f_hdc, 0);
}
