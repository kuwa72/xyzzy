#include "stdafx.h"
#include "ed.h"
#include "win32sysdep.h"
#include "oleconv.h"

/* Phase 2-5: take an in-place wchar_t buffer (null-terminated, with
   capacity for at least wcslen(wbuf) + 3 to prepend "...") and abbreviate
   its contents so GetTextExtentPoint32W fits within maxpxl. Returns 1 if
   wbuf was modified, 0 otherwise. UTF-16 end-to-end so non-cp932 paths /
   display names pass through untouched. */
int WINAPI
abbreviate_string (HDC hdc, wchar_t *wbuf, int maxpxl, int is_pathname)
{
  int wl = (int)wcslen (wbuf);

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
  return 1;
}

static int
abbrev_string (wchar_t *wbuf, int maxl, int pathname_p)
{
  HDC hdc (GetDC (0));
  HGDIOBJ of (SelectObject (hdc, win32_sysdep.ui_font ()));
  TEXTMETRICW tm;
  GetTextMetricsW (hdc, &tm);
  int maxpxl = tm.tmAveCharWidth * maxl;
  int r = abbreviate_string (hdc, wbuf, maxpxl, pathname_p);
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
  /* Convert ucs4 → UTF-16 (worst case 2x), reserve +4 for "..." plus
     terminator. abbreviate_string may write up to slen + 3 + null. */
  wchar_t *wbuf = (wchar_t *)alloca ((i2wl (string) + 4) * sizeof (wchar_t));
  i2w (string, (ucs2_t *)wbuf);
  if (!abbrev_string (wbuf, l, pathname_p && pathname_p != Qnil))
    return string;
  return make_string ((const Char *)wbuf, (size_t)wcslen (wbuf));
}
