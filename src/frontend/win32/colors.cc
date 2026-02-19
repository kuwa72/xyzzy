#include "stdafx.h"
#include "ed.h"
#include "colors.h"
#include "conf.h"
#include "Filer.h"
#include "mainframe.h"

static XCOLORREF xcolors[MC_NCOLORS];
static struct {const char *name; const wchar_t *disp;} xnames[] =
{
  {cfgTextColor, L"ファイラ文字色"},
  {cfgBackColor, L"ファイラ背景色"},
  {"highlightTextColor", L"ファイラ選択文字色"},
  {"highlightBackColor", L"ファイラ選択背景色"},
  {cfgCursorColor, L"ファイラカーソル色"},
  {"buftabSelFg", L"選択バッファタブ文字色"},
  {"buftabSelBg", L"選択バッファタブ背景色"},
  {"buftabDispFg", L"表示バッファタブ文字色"},
  {"buftabDispBg", L"表示バッファタブ背景色"},
  {"buftabFg", L"バッファタブ文字色"},
  {"buftabBg", L"バッファタブ背景色"},
  {"tabSelFg", L"選択タブ文字色"},
  {"tabSelBg", L"選択タブ背景色"},
  {"tabFg", L"タブ文字色"},
  {"tabBg", L"タブ背景色"},
};

const wchar_t *
misc_color_name (int i)
{
  return xnames[i].disp;
}

XCOLORREF
get_misc_color (int i)
{
  return xcolors[i];
}

static void
load_default ()
{
  xcolors[MC_FILER_FG] = XCOLORREF (sysdep.window_text, COLOR_WINDOWTEXT);
  xcolors[MC_FILER_BG] = XCOLORREF (sysdep.window, COLOR_WINDOW);
  xcolors[MC_FILER_HIGHLIGHT_FG] = XCOLORREF (sysdep.highlight_text, COLOR_HIGHLIGHTTEXT);
  xcolors[MC_FILER_HIGHLIGHT_BG] = XCOLORREF (sysdep.highlight, COLOR_HIGHLIGHT);
  xcolors[MC_FILER_CURSOR] = RGB (192, 0, 192);

  for (int i = MC_BUFTAB_SEL_FG; i <= MC_TAB_FG; i += 2)
    {
      xcolors[i] = XCOLORREF (sysdep.btn_text, COLOR_BTNTEXT);
      xcolors[i + 1] = XCOLORREF (sysdep.btn_face, COLOR_BTNFACE);
    }
}

void
load_misc_colors ()
{
  load_default ();

  int i, c;
  for (i = MC_FILER_FG; i <= MC_FILER_CURSOR; i++)
    if (read_conf (cfgFiler, xnames[i].name, c))
      xcolors[i] = c;

  for (; i < MC_NCOLORS; i++)
    if (read_conf (cfgColors, xnames[i].name, c))
      xcolors[i] = c;
}

void
modify_misc_colors (const XCOLORREF *colors, int save)
{
  memcpy (xcolors, colors, sizeof xcolors);
  if (save)
    {
      int i;
      for (i = MC_FILER_FG; i <= MC_FILER_CURSOR; i++)
        write_conf (cfgFiler, xnames[i].name, xcolors[i].rgb, 1);
      for (; i < MC_NCOLORS; i++)
        write_conf (cfgColors, xnames[i].name, xcolors[i].rgb, 1);
    }

  Filer::modify_colors ();
  g_frame.color_changed ();
}
