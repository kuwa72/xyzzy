#include "stdafx.h"
#include "ed.h"

int WINAPI
abbreviate_string (HDC hdc, char *buf, int maxpxl, int is_pathname)
{
  wchar_t wbuf[2048];
  int wl = cp932_to_wcs (buf, -1, wbuf, 2048) - 1;
  int orig_byte_len = strlen (buf);

  SIZE sz;
  GetTextExtentPoint32W (hdc, wbuf, wl, &sz);
  if (sz.cx <= maxpxl)
    return 0;

  GetTextExtentPoint32W (hdc, L"...", 3, &sz);
  maxpxl = (maxpxl - sz.cx);

  wchar_t *lb, *le;
  wchar_t *rb, *re;

  if (is_pathname)
    {
      lb = le = wbuf;
      re = wbuf + wl;
      rb = find_last_slash_w (wbuf);
      if (rb)
        {
          GetTextExtentPoint32W (hdc, rb, re - rb, &sz);
          if (sz.cx > maxpxl)
            {
              rb++;
              goto trim_tail;
            }

          int pxl = sz.cx;
          int dev = 0;
          if (alpha_char_p (*lb & 255) && lb[1] == L':')
            dev = (lb[2] == L'\\' || lb[2] == L'/') ? 3 : 2;
          else if ((lb[0] == L'\\' || lb[0] == L'/') && (lb[1] == L'\\' || lb[1] == L'/'))
            {
              wchar_t *sl = find_slash_w (lb + 2);
              if (sl)
                {
                  wchar_t *sl2 = find_slash_w (sl + 1);
                  if (sl2 && sl2 < rb)
                    dev = sl2 - lb + 1;
                }
            }
          if (dev)
            {
              GetTextExtentPoint32W (hdc, lb, dev, &sz);
              if (pxl + sz.cx > maxpxl)
                goto done;
              pxl += sz.cx;
              le = lb + dev;
            }

          while (rb > le)
            {
              wchar_t c = *rb;
              *rb = 0;
              wchar_t *slash = find_last_slash_w (wbuf);
              *rb = c;
              if (!slash)
                break;
              GetTextExtentPoint32W (hdc, slash, rb - slash, &sz);
              if (sz.cx + pxl > maxpxl)
                break;
              rb = slash;
              pxl += sz.cx;
            }
        }
      else
        {
          rb = wbuf;
        trim_tail:
          for (; re > rb; re--)
            {
              GetTextExtentPoint32W (hdc, rb, re - rb, &sz);
              if (sz.cx <= maxpxl)
                {
                  if ((re - rb) + 3 > wl)
                    return 0;
                  *re = 0;
                  int n = re - rb;
                  memmove (wbuf, rb, n * sizeof (wchar_t));
                  wbuf[n] = L'.';
                  wbuf[n + 1] = L'.';
                  wbuf[n + 2] = L'.';
                  wbuf[n + 3] = 0;
                  wcs_to_cp932 (wbuf, -1, buf, orig_byte_len + 1);
                  return 1;
                }
            }
        }
    }
  else
    {
      maxpxl /= 2;
      for (lb = wbuf, le = wbuf + wl / 2; le > lb; le--)
        {
          GetTextExtentPoint32W (hdc, lb, le - lb, &sz);
          if (sz.cx <= maxpxl)
            break;
        }
      for (rb = wbuf + wl / 2, re = wbuf + wl; rb < re; rb++)
        {
          GetTextExtentPoint32W (hdc, rb, re - rb, &sz);
          if (sz.cx <= maxpxl)
            break;
        }
    }
done:
  if ((le - lb) + (re - rb) + 3 > wl)
    return 0;

  for (int i = 0; i < 3; i++)
    le[i] = L'.';
  wcscpy (le + 3, rb);
  wcs_to_cp932 (wbuf, -1, buf, orig_byte_len + 1);
  return 1;
}

static int
abbrev_string (char *buf, int maxl, int pathname_p)
{
  HDC hdc (GetDC (0));
  HGDIOBJ of (SelectObject (hdc, sysdep.ui_font ()));
  TEXTMETRICW tm;
  GetTextMetricsW (hdc, &tm);
  int maxpxl = tm.tmAveCharWidth * maxl;
  int r = abbreviate_string (hdc, buf, maxpxl, pathname_p);
  SelectObject (hdc, of);
  ReleaseDC (0, hdc);
  return r;
}

lisp
Fabbreviate_display_string (lisp string, lisp maxlen, lisp pathname_p)
{
  check_string (string);
  int l = fixnum_value (maxlen);
  if (l <= 0)
    return make_string ("");
  char *buf = (char *)alloca (xstring_length (string) * 2 + 1);
  w2s (buf, string);
  if (!abbrev_string (buf, l, pathname_p && pathname_p != Qnil))
    return string;
  return make_string (buf);
}
