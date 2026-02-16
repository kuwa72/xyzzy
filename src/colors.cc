#include "stdafx.h"
#include "ed.h"
#include "colors.h"
#include "conf.h"
#include "Filer.h"
#include "mainframe.h"

static XCOLORREF xcolors[MC_NCOLORS];
static struct {const char *name, *disp;} xnames[] =
{
  {cfgTextColor, "\x83\x74\x83\x40\x83\x43\x83\x89\x95\xb6\x8e\x9a\x90\x46"},
  {cfgBackColor, "\x83\x74\x83\x40\x83\x43\x83\x89\x94\x77\x8c\x69\x90\x46"},
  {"highlightTextColor", "\x83\x74\x83\x40\x83\x43\x83\x89\x91\x49\x91\xf0\x95\xb6\x8e\x9a\x90\x46"},
  {"highlightBackColor", "\x83\x74\x83\x40\x83\x43\x83\x89\x91\x49\x91\xf0\x94\x77\x8c\x69\x90\x46"},
  {cfgCursorColor, "\x83\x74\x83\x40\x83\x43\x83\x89\x83\x4a\x81\x5b\x83\x5c\x83\x8b\x90\x46"},
  {"buftabSelFg", "\x91\x49\x91\xf0\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x95\xb6\x8e\x9a\x90\x46"},
  {"buftabSelBg", "\x91\x49\x91\xf0\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x94\x77\x8c\x69\x90\x46"},
  {"buftabDispFg", "\x95\x5c\x8e\xa6\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x95\xb6\x8e\x9a\x90\x46"},
  {"buftabDispBg", "\x95\x5c\x8e\xa6\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x94\x77\x8c\x69\x90\x46"},
  {"buftabFg", "\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x95\xb6\x8e\x9a\x90\x46"},
  {"buftabBg", "\x83\x6f\x83\x62\x83\x74\x83\x40\x83\x5e\x83\x75\x94\x77\x8c\x69\x90\x46"},
  {"tabSelFg", "\x91\x49\x91\xf0\x83\x5e\x83\x75\x95\xb6\x8e\x9a\x90\x46"},
  {"tabSelBg", "\x91\x49\x91\xf0\x83\x5e\x83\x75\x94\x77\x8c\x69\x90\x46"},
  {"tabFg", "\x83\x5e\x83\x75\x95\xb6\x8e\x9a\x90\x46"},
  {"tabBg", "\x83\x5e\x83\x75\x94\x77\x8c\x69\x90\x46"},
};

const char *
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
