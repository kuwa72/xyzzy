#include "gen-stdafx.h"
#include "ucs2tab.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <locale.h>
#include <wchar.h>
#endif

#define SZ 0x500

static void
print (const u_char *width)
{
  printf ("static const u_char jisx0212_width_table[] =\n{\n");
  for (int i = 0; i < SZ / 8; i += 8)
    {
      putchar (' ');
      for (int j = 0; j < 8; j++)
        printf (" 0x%02x,", width[i + j]);
      putchar ('\n');
    }
  printf ("};\n");
}

#ifdef _WIN32
void
gen_jisx0212_width (int argc, char **argv)
{
  HDC hdc = GetDC (0);
  LOGFONT lf;
  memset (&lf, 0, sizeof lf);
  lf.lfHeight = 16;
  lf.lfCharSet = SHIFTJIS_CHARSET;
  strcpy (lf.lfFaceName, "ＭＳ 明朝");
  HGDIOBJ of = SelectObject (hdc, CreateFontIndirect (&lf));

  SIZE sz0;
  GetTextExtentPoint32 (hdc, "あ", 2, &sz0);

  u_char width[SZ / 8];
  memset (width, 255, sizeof width);
  for (int i = CCS_JISX0212_MIN; i < CCS_JISX0212_MIN + SZ; i++)
    {
      SIZE sz;
      ucs2_t wc = internal2wc_table[i];
      if (wc != ucs2_t (-1))
        {
          GetTextExtentPoint32W (hdc, (LPCWSTR)&wc, 1, &sz);
          if (sz.cx != sz0.cx)
            width[(i - CCS_JISX0212_MIN) >> 3] &= ~(1 << (i & 7));
        }
    }
  print (width);

  DeleteObject (SelectObject (hdc, of));
  ReleaseDC (0, hdc);

  exit (0);
}
#else /* !_WIN32 */
/* Non-Windows fallback: use wcwidth() to determine character display width.
   JIS X 0212 characters are almost all full-width (CJK), but a small number
   of Latin/symbol entries may be half-width.  wcwidth()==2 means full-width. */
void
gen_jisx0212_width (int argc, char **argv)
{
  setlocale (LC_CTYPE, "C.UTF-8");

  u_char width[SZ / 8];
  memset (width, 255, sizeof width);
  for (int i = CCS_JISX0212_MIN; i < CCS_JISX0212_MIN + SZ; i++)
    {
      ucs2_t wc = internal2wc_table[i];
      if (wc != ucs2_t (-1) && wcwidth ((wchar_t)wc) != 2)
        width[(i - CCS_JISX0212_MIN) >> 3] &= ~(1 << (i & 7));
    }
  print (width);

  exit (0);
}
#endif /* _WIN32 */
