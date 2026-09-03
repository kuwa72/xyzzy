#ifndef _win32sysdep_h_
# define _win32sysdep_h_

# include "../../core/sysdep.h"

struct Win32Sysdep : public Sysdep
{
  Win32Sysdep ();
  ~Win32Sysdep ();

  COLORREF btn_text;
  COLORREF btn_highlight;
  COLORREF btn_shadow;
  COLORREF btn_face;
  COLORREF window_text;
  COLORREF gray_text;
  COLORREF highlight_text;
  COLORREF highlight;
  COLORREF window;

  HFONT hfont_ruler;
  SIZE ruler_ext;

private:
  HFONT hfont_ui;
  HFONT hfont_ui90;
  HFONT hfont_ui270;
  static HFONT create_ui_font (int);

public:
  HFONT ui_font ();
  HFONT ui_font90 ();
  HFONT ui_font270 ();

  void load_colors ();
};

extern Win32Sysdep win32_sysdep;
extern Sysdep &sysdep;

#endif // _win32sysdep_h_
