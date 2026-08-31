// -*-C++-*-
#ifndef _gdi_utils_h_
# define _gdi_utils_h_

/* GDI で線と矩形を描く小さな道具。**src/core/utils.h に居た**が、
   `src/core/` の中から呼んでいるコードが 1 つも無かったので出した
   (issue #195 / #185)。

   **#185 は「`Painter` に同じ primitive があるので寄せられる」と書いていた
   が、測ると寄せる先が要らなかった。** ここを呼ぶのは
   `disp.cc` / `Window.cc` / `dockbar.cc` / `toplev.cc` / `fnkey.cc` /
   `ColorDialog.cc` / `ChooseFont.cc` / `print.cc` / `pane.cc` の 9 つで、
   **全部 `src/frontend/win32/` の中**である。core が `HDC` を 15 個抱えて
   いた理由は「core が使っているから」ではなく、**置き場所だけ**だった。

   端末側の描画は `Painter` を通っていて (`NcursesPainter::fill_rect` /
   `draw_hline` / `draw_vline`)、こちらとは別物である。**名前が同じなので
   混ざりやすいが、引数が `HDC` かどうかで見分けられる。** */

extern void paint_button_off (HDC, const RECT &);
extern void paint_button_on (HDC, const RECT &);
extern void fill_rect (HDC, int, int, int, int, COLORREF);
extern void fill_rect (HDC, const RECT &, COLORREF);
extern void draw_hline (HDC, int, int, int, COLORREF);
extern void draw_vline (HDC, int, int, int, COLORREF);

/* ドラッグ中の枠を XOR で描くための DC。`LockWindowUpdate` を握るので、
   **生きている間は他のウィンドウが描けない。** スタックに置いて短く使う。 */
class frameDC
{
  HWND f_hwnd;
  HDC f_hdc;
  HGDIOBJ f_obr;
  enum {WIDTH = 2};
public:
  frameDC (HWND, int = 0);
  ~frameDC ();
  void frame_rect (const RECT &, int = WIDTH) const;
  void paint (const RECT &r) const
    {PatBlt (f_hdc, r.left, r.top,
             r.right - r.left, r.bottom - r.top, PATINVERT);}
};

#endif /* _gdi_utils_h_ */
