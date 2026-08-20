#include "stdafx.h"
#include "cdecl.h"
#include "ed.h"
#include "utils.h"
#include "chtype.h"

void *
xmalloc (size_t size)
{
  if (!size)
    size = 1;
  void *p = malloc (size);
  if (!p)
    FEstorage_error ();
  return p;
}

void *
xrealloc (void *p, size_t size)
{
  if (!size)
    size = 1;
  if (!p)
    p = malloc (size);
  else
    p = realloc (p, size);
  if (!p)
    FEstorage_error ();
  return p;
}

void
xfree (void *p)
{
  if (p)
    free (p);
}

char *
xstrdup (const char *s)
{
  return strcpy ((char *)xmalloc (strlen (s) + 1), s);
}

wchar_t *
xwcsdup (const wchar_t *s)
{
  return wcscpy ((wchar_t *)xmalloc ((wcslen (s) + 1) * sizeof (wchar_t)), s);
}

void *
xmemdup (const void *p, size_t size)
{
  return memcpy (xmalloc (size), p, size);
}

char *
stpcpy (char *d, const char *s)
{
  while ((*d++ = *s++))
    ;
  return d - 1;
}

char *
stpncpy (char *d, const char *s, int n)
{
  for (; n > 0; n--)
  {
    if (!(*d++ = *s++))
      return d - 1;
  }
  *d = 0;
  return d;
}

char *
jindex (const char *p, int c)
{
  for (const u_char *s = (const u_char *)p; *s;)
    {
      if (SJISP (*s) && s[1])
        s += 2;
      else
        {
          if (*s == c)
            return (char *)s;
          s++;
        }
    }
  return 0;
}

char *
jrindex (const char *p, int c)
{
  const u_char *save, *s;
  for (save = 0, s = (const u_char *)p; *s;)
    {
      if (SJISP (*s) && s[1])
        s += 2;
      else
        {
          if (*s == c)
            save = s;
          s++;
        }
    }
  return (char *)save;
}

char *
find_slash (const char *p)
{
  for (u_char *s = (u_char *)p; *s;)
    {
      if (SJISP (*s) && s[1])
        s += 2;
      else
        {
          if (*s == '/' || *s == '\\')
            return (char *)s;
          s++;
        }
    }
  return 0;
}

char *
find_last_slash (const char *p)
{
  u_char *save, *s;
  for (save = 0, s = (u_char *)p; *s;)
    {
      if (SJISP (*s) && s[1])
        s += 2;
      else
        {
          if (*s == '/' || *s == '\\')
            save = s;
          s++;
        }
    }
  return (char *)save;
}

wchar_t *
find_slash_w (const wchar_t *p)
{
  for (const wchar_t *s = p; *s; s++)
    if (*s == L'/' || *s == L'\\')
      return (wchar_t *)s;
  return 0;
}

wchar_t *
find_last_slash_w (const wchar_t *p)
{
  wchar_t *save = 0;
  for (const wchar_t *s = p; *s; s++)
    if (*s == L'/' || *s == L'\\')
      save = (wchar_t *)s;
  return save;
}

long
log2 (u_long x)
{
  long l;
  for (l = 0; x; x >>= 1, l++)
    ;
  return l;
}

#define NF_SIGN 1
#define NF_LEADNUM 2
#define NF_DOT 4
#define NF_TRAILNUM 8
#define NF_EXPSIGN 16
#define NF_EXP (NF_EXPCHAR | NF_EXPNUM)
#define  NF_EXPCHAR 32
#define  NF_EXPNUM 64
#define NF_SLASH 128

int
default_float_format ()
{
  lisp f = xsymbol_value (Vread_default_float_format);
  if (f == Qshort_float)
    return NF_FLOAT_S;
  if (f == Qdouble_float)
    return NF_FLOAT_D;
  if (f == Qlong_float)
    return NF_FLOAT_L;
  return NF_FLOAT_F;
}

int
parse_number_format (const Char *p, const Char *pe, int base)
{
  Char expchar = 'e';
  int f = 0;
  if (p < pe && (*p == '+' || *p == '-'))
    p++;
  if (p < pe && digit_char (*p) < base)
    {
      f |= NF_LEADNUM;
      for (p++; p < pe && digit_char (*p) < base; p++)
        ;
    }
  if (p < pe && *p == '.')
    {
      f |= NF_DOT;
      p++;
    }
  if (p < pe && *p == '/')
    {
      f |= NF_SLASH;
      p++;
    }
  if (p < pe && digit_char (*p) < base)
    {
      f |= NF_TRAILNUM;
      for (p++; p < pe && digit_char (*p) < base; p++)
        ;
    }
  if (p < pe)
    {
      Char c = char_downcase (*p);
      switch (c)
        {
        case 'e':
        case 's':
        case 'f':
        case 'd':
        case 'l':
          f |= NF_EXPCHAR;
          expchar = c;
          p++;
        }
    }
  if (p < pe && (*p == '+' || *p == '-'))
    {
      f |= NF_EXPSIGN;
      p++;
    }
  if (p < pe && digit_char_p (*p))
    {
      f |= NF_EXPNUM;
      for (p++; p < pe && digit_char_p (*p); p++)
        ;
    }

  if ((f & (NF_EXP | NF_EXPSIGN)) == NF_EXPSIGN)
    return NF_BAD;
  f &= ~NF_EXPSIGN;

  if (p == pe)
    {
      switch (f)
        {
        case NF_LEADNUM:
          return NF_INTEGER;

        case NF_LEADNUM | NF_DOT:
          return NF_INTEGER_DOT;

        case NF_LEADNUM | NF_SLASH | NF_TRAILNUM:
          return NF_FRACTION;

        case NF_DOT | NF_TRAILNUM:
        case NF_DOT | NF_TRAILNUM | NF_EXP:
        case NF_LEADNUM | NF_DOT | NF_TRAILNUM:
        case NF_LEADNUM | NF_DOT | NF_TRAILNUM | NF_EXP:
        case NF_LEADNUM | NF_EXP:
        case NF_LEADNUM | NF_DOT | NF_EXP:
          return NF_FLOAT | expchar;
        }
    }
  return NF_BAD;
}

int
parse_number_format (const ucs4_t *p, const ucs4_t *pe, int base)
{
  ucs4_t expchar = 'e';
  int f = 0;
  if (p < pe && (*p == '+' || *p == '-'))
    p++;
  if (p < pe && digit_char (*p) < base)
    {
      f |= NF_LEADNUM;
      for (p++; p < pe && digit_char (*p) < base; p++)
        ;
    }
  if (p < pe && *p == '.')
    {
      f |= NF_DOT;
      p++;
    }
  if (p < pe && *p == '/')
    {
      f |= NF_SLASH;
      p++;
    }
  if (p < pe && digit_char (*p) < base)
    {
      f |= NF_TRAILNUM;
      for (p++; p < pe && digit_char (*p) < base; p++)
        ;
    }
  if (p < pe)
    {
      ucs4_t c = char_downcase (*p);
      switch (c)
        {
        case 'e':
        case 's':
        case 'f':
        case 'd':
        case 'l':
          f |= NF_EXPCHAR;
          expchar = c;
          p++;
        }
    }
  if (p < pe && (*p == '+' || *p == '-'))
    {
      f |= NF_EXPSIGN;
      p++;
    }
  if (p < pe && digit_char_p (*p))
    {
      f |= NF_EXPNUM;
      for (p++; p < pe && digit_char_p (*p); p++)
        ;
    }

  if ((f & (NF_EXP | NF_EXPSIGN)) == NF_EXPSIGN)
    return NF_BAD;
  f &= ~NF_EXPSIGN;

  if (p == pe)
    {
      switch (f)
        {
        case NF_LEADNUM:
          return NF_INTEGER;

        case NF_LEADNUM | NF_DOT:
          return NF_INTEGER_DOT;

        case NF_LEADNUM | NF_SLASH | NF_TRAILNUM:
          return NF_FRACTION;

        case NF_DOT | NF_TRAILNUM:
        case NF_DOT | NF_TRAILNUM | NF_EXP:
        case NF_LEADNUM | NF_DOT | NF_TRAILNUM:
        case NF_LEADNUM | NF_DOT | NF_TRAILNUM | NF_EXP:
        case NF_LEADNUM | NF_EXP:
        case NF_LEADNUM | NF_DOT | NF_EXP:
          return NF_FLOAT | expchar;
        }
    }
  return NF_BAD;
}

int
check_integer_format (const char *s, int *n)
{
  ucs4_t *b = (ucs4_t *)alloca (strlen (s) * sizeof (ucs4_t));
  ucs4_t *be = s2w (b, s);
  for (; b < be && (*b == ' ' || *b == '\t'); b++)
    ;
  for (; be > b && (be[-1] == ' ' || be[-1] == '\t'); be--)
    ;

  switch (parse_number_format (b, be, 10))
    {
    case NF_INTEGER:
    case NF_INTEGER_DOT:
      *n = atoi (s);
      return 1;

    default:
      return 0;
    }
}

int
streq (const Char *p, int l, const char *s)
{
  for (const Char *pe = p + l; p < pe; p++, s++)
    if (*p != *s)
      return 0;
  return 1;
}

int
streq (const ucs4_t *p, int l, const char *s)
{
  for (const ucs4_t *pe = p + l; p < pe; p++, s++)
    if (*p != (u_char)*s)
      return 0;
  return 1;
}

int
strequal (const char *cp, const ucs4_t *Cp)
{
  while (*cp)
    {
      if (*Cp++ != (u_char)*cp++)
        return 0;
    }
  return !*Cp;
}

int
strequal (const char *cp, const ucs4_t *Cp, int l)
{
  for (const ucs4_t *Ce = Cp + l; Cp < Ce; Cp++)
    {
      if (*Cp != (u_char)*cp++)
        return 0;
    }
  return 1;
}

int
strequal (const char *cp, const Char *Cp)
{
  while (*cp)
    {
      Char c = *Cp++;
      if (DBCP (c))
        {
          if (!cp[1] || c != Char ((u_char (*cp) << 8) | u_char (cp[1])))
            return 0;
          cp += 2;
        }
      else
        {
          if (char_downcase (c) != char_downcase (u_char (*cp)))
            return 0;
          cp++;
        }
    }
  return 1;
}

int
strequal (const char *cp, const Char *Cp, int l)
{
  for (const Char *Ce = Cp + l; Cp < Ce; Cp++)
    {
      Char c = *Cp;
      if (DBCP (c))
        {
          if (c != Char ((u_char (*cp) << 8) | u_char (cp[1])))
            return 0;
          cp += 2;
        }
      else
        {
          if (char_downcase (c) != char_downcase (u_char (*cp)))
            return 0;
          cp++;
        }
    }
  return 1;
}

int
sjis_strcasecmp (const char *s1, const char *s2)
{
  const u_char *p1 = (const u_char *)s1;
  const u_char *p2 = (const u_char *)s2;
  while (1)
    {
      u_char c1 = *p1++;
      u_char c2 = *p2++;
      if (SJISP (c1))
        {
          if (c1 != c2)
            return c1 - c2;
          c1 = *p1++;
          c2 = *p2++;
        }
      else
        {
          c1 = char_downcase (c1);
          c2 = char_downcase (c2);
        }
      if (c1 != c2)
        return c1 - c2;
      if (!c1)
        return 0;
    }
}

void
convert_backsl_with_sl (char *path, int f, int t)
{
  for (u_char *s = (u_char *)path; *s;)
    {
      if (SJISP (*s) && s[1])
        s += 2;
      else
        {
          if (*s == f)
            *s = t;
          s++;
        }
    }
}

#ifdef _WIN32
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
#endif // _WIN32

ucs2_t *
i2w (const ucs4_t *p, int l, ucs2_t *b)
{
  /* Phase 3: Lisp string stores ucs4_t code points. Convert to UTF-16 for
     Windows APIs. BMP chars map 1:1; non-BMP emit surrogate pairs. */
  ucs2_t *out = b;
  for (int i = 0; i < l; i++)
    {
      ucs4_t cp = p[i];
      if (cp < 0x10000)
        *out++ = ucs2_t (cp);
      else
        {
          cp -= 0x10000;
          *out++ = ucs2_t (0xD800 + (cp >> 10));
          *out++ = ucs2_t (0xDC00 + (cp & 0x3FF));
        }
    }
  *out = 0;
  return out;
}

int
i2wl (const ucs4_t *p, int l)
{
  /* Phase 3: count UTF-16 code units needed, plus terminator. */
  int n = 1;
  for (int i = 0; i < l; i++)
    n += (p[i] >= 0x10000) ? 2 : 1;
  return n;
}

/* The other direction: UTF-16 from Windows -> ucs4_t code points. A surrogate
   pair becomes one code point; an unpaired surrogate is kept as-is rather than
   dropped, so a name that came out of the filesystem can go back into it
   unchanged. Returns the position past the last code point written. */
ucs4_t *
w2i (const ucs2_t *p, int l, ucs4_t *b)
{
  ucs4_t *out = b;
  for (int i = 0; i < l; i++)
    {
      ucs2_t c = p[i];
      if (utf16_surrogate_high_p (c) && i + 1 < l
          && utf16_surrogate_low_p (p[i + 1]))
        *out++ = utf16_pair_to_ucs4 (c, p[++i]);
      else
        *out++ = c;
    }
  return out;
}

/* The wchar_t overloads are what path code should use: wchar_t is UTF-16 on
   Windows and UCS-4 on Linux, and the difference belongs here rather than at
   every call site. Both write a trailing nul. */
wchar_t *
i2w (const ucs4_t *p, int l, wchar_t *b)
{
  if (sizeof (wchar_t) == sizeof (ucs2_t))
    return (wchar_t *)i2w (p, l, (ucs2_t *)b);
  for (int i = 0; i < l; i++)
    b[i] = wchar_t (p[i]);
  b[l] = 0;
  return b + l;
}

ucs4_t *
w2i (const wchar_t *p, int l, ucs4_t *b)
{
  if (sizeof (wchar_t) == sizeof (ucs2_t))
    return w2i ((const ucs2_t *)p, l, b);
  for (int i = 0; i < l; i++)
    b[i] = ucs4_t (p[i]);
  return b + l;
}

ucs4_t *
w2i (const wchar_t *p, ucs4_t *b)
{
  return w2i (p, int (wcslen (p)), b);
}

int
w2il (const ucs2_t *p, int l)
{
  int n = 0;
  for (int i = 0; i < l; i++)
    {
      if (utf16_surrogate_high_p (p[i]) && i + 1 < l
          && utf16_surrogate_low_p (p[i + 1]))
        i++;
      n++;
    }
  return n;
}

int
w2il (const wchar_t *p, int l)
{
  return sizeof (wchar_t) == sizeof (ucs2_t) ? w2il ((const ucs2_t *)p, l) : l;
}

/* UTF-8, for the byte interfaces of a Unix system: filenames, the
   environment, argv. These are not CP932 there and never were; the byte
   string an OS hands us is UTF-8 on anything this builds for. */

size_t
i2u8l (const ucs4_t *p, int l)
{
  size_t n = 1;
  for (int i = 0; i < l; i++)
    n += (p[i] < 0x80) ? 1 : (p[i] < 0x800) ? 2 : (p[i] < 0x10000) ? 3 : 4;
  return n;
}

char *
i2u8 (const ucs4_t *p, int l, char *b)
{
  for (int i = 0; i < l; i++)
    {
      ucs4_t c = p[i];
      if (c < 0x80)
        *b++ = char (c);
      else if (c < 0x800)
        {
          *b++ = char (0xC0 | (c >> 6));
          *b++ = char (0x80 | (c & 0x3F));
        }
      else if (c < 0x10000)
        {
          *b++ = char (0xE0 | (c >> 12));
          *b++ = char (0x80 | ((c >> 6) & 0x3F));
          *b++ = char (0x80 | (c & 0x3F));
        }
      else
        {
          *b++ = char (0xF0 | (c >> 18));
          *b++ = char (0x80 | ((c >> 12) & 0x3F));
          *b++ = char (0x80 | ((c >> 6) & 0x3F));
          *b++ = char (0x80 | (c & 0x3F));
        }
    }
  *b = 0;
  return b;
}

size_t
u82il (const char *s)
{
  size_t n = 0;
  for (const u_char *p = (const u_char *)s; *p; p++)
    if ((*p & 0xC0) != 0x80)
      n++;
  return n;
}

/* A byte that is not valid UTF-8 is kept as its own code point rather than
   dropped, so a name that came from the filesystem can go back to it. */
ucs4_t *
u82i (const char *s, ucs4_t *b)
{
  for (const u_char *p = (const u_char *)s; *p;)
    {
      ucs4_t c = *p++;
      int extra = c < 0x80 ? 0 : c < 0xC0 ? 0 : c < 0xE0 ? 1 : c < 0xF0 ? 2 : 3;
      if (extra)
        {
          ucs4_t v = c & (0x3F >> extra);
          int i;
          for (i = 0; i < extra && (*p & 0xC0) == 0x80; i++)
            v = (v << 6) | (*p++ & 0x3F);
          c = i == extra ? v : c;
        }
      *b++ = c;
    }
  return b;
}

