#include "stdafx.h"
#include "ed.h"
#include "binfo.h"

/* Phase 2: mode line は Char * (UTF-16) で組み立てる。旧実装は cp932
   バイト列で組み立ててから最後に cp932_to_wcs していた。 */

const Char *const buffer_info::b_eol_name[] =
  {(const Char *)L"lf", (const Char *)L"crlf", (const Char *)L"cr"};

static Char *
stwncpy (Char *b, Char *be, const char *s, size_t max)
{
  size_t i;
  for (i = 0; i < max && s[i] && b < be; i++)
    *b++ = (Char)(u_char)s[i];
  return b;
}

static Char *
stwncpy (Char *b, Char *be, const Char *s, size_t max)
{
  size_t i;
  for (i = 0; i < max && s[i] && b < be; i++)
    *b++ = s[i];
  return b;
}

static Char *
copy_lisp_string (Char *b, Char *be, lisp str)
{
  /* Phase 3: ucs4 → UTF-16 で Char buffer に詰める (surrogate pair も発出)。 */
  int nstr = xstring_length (str);
  const ucs4_t *p = xstring_contents (str);
  ucs2_t *out = (ucs2_t *)b;
  ucs2_t *out_end = (ucs2_t *)be;
  for (int i = 0; i < nstr && out < out_end; i++)
    {
      ucs4_t cp = p[i];
      if (cp < 0x10000)
        *out++ = ucs2_t (cp);
      else if (out + 1 < out_end)
        {
          cp -= 0x10000;
          *out++ = ucs2_t (0xD800 + (cp >> 10));
          *out++ = ucs2_t (0xDC00 + (cp & 0x3FF));
        }
      else
        break;
    }
  return (Char *)out;
}

Char *
buffer_info::modified (Char *b, int pound) const
{
  if (!pound)
    {
      Char c1 = '-', c2 = '-';
      if (b_bufp->b_modified)
        c1 = c2 = '*';
      if (b_bufp->read_only_p ())
        {
          c1 = '%';
          if (c2 == '-')
            c2 = c1;
        }
      if (b_bufp->b_truncated)
        c2 = '#';
      *b++ = c1;
      *b++ = c2;
    }
  else
    *b++ = b_bufp->b_modified ? '*' : ' ';
  return b;
}

Char *
buffer_info::read_only (Char *b, int pound) const
{
  if (b_bufp->read_only_p ())
    *b++ = '%';
  else if (!pound && b_bufp->b_truncated)
    *b++ = '#';
  else
    *b++ = ' ';
  return b;
}

Char *
buffer_info::buffer_name (Char *b, Char *be) const
{
  b = b_bufp->buffer_name (b, be);
  if (b == be - 1)
    *b++ = ' ';
  return b;
}

Char *
buffer_info::file_name (Char *b, Char *be, int pound) const
{
  lisp name;
  if (stringp (name = b_bufp->lfile_name)
      || stringp (name = b_bufp->lalternate_file_name))
    {
      if (!pound)
        b = stwncpy (b, be, "File: ", 6);
      b = copy_lisp_string (b, be, name);
      if (b == be - 1)
        *b++ = ' ';
    }
  return b;
}

Char *
buffer_info::file_or_buffer_name (Char *b, Char *be, int pound) const
{
  Char *bb = b;
  b = file_name (b, be, pound);
  if (b == bb)
    b = buffer_name (b, be);
  return b;
}

static Char *
docopy (Char *d, Char *de, const char *s, int &f)
{
  if (d < de) *d++ = f ? ' ' : ':';
  f = 1;
  return stwncpy (d, de, s, strlen (s));
}

Char *
buffer_info::minor_mode (lisp x, Char *b, Char *be, int &f) const
{
  for (int i = 0; i < 10; i++)
    if (consp (x) && symbolp (xcar (x))
        && symbol_value (xcar (x), b_bufp) != Qnil)
      {
        x = xcdr (x);
        if (symbolp (x))
          {
            x = symbol_value (x, b_bufp);
            if (!stringp (x))
              break;
          }
        if (stringp (x))
          {
            if (b < be) *b++ = f ? ' ' : ':';
            f = 1;
            return copy_lisp_string (b, be, x);
          }
      }
    else
      break;
  return b;
}

Char *
buffer_info::mode_name (Char *b, Char *be, int c) const
{
  int f = 0;
  lisp mode = symbol_value (Vmode_name, b_bufp);
  if (stringp (mode))
    b = copy_lisp_string (b, be, mode);

  if (c == 'M')
    {
      if (b_bufp->b_narrow_depth)
        b = docopy (b, be, "Narrow", f);
      if (Fkbd_macro_saving_p () != Qnil)
        b = docopy (b, be, "Def", f);
      for (lisp al = xsymbol_value (Vminor_mode_alist);
           consp (al); al = xcdr (al))
        b = minor_mode (xcar (al), b, be, f);
    }

  if (processp (b_bufp->lprocess))
    switch (xprocess_status (b_bufp->lprocess))
      {
      case PS_RUN:
        b = stwncpy (b, be, ":Run", 4);
        break;

      case PS_EXIT:
        b = stwncpy (b, be, ":Exit", 5);
        break;
      }
  return b;
}

Char *
buffer_info::progname (Char *b, Char *be) const
{
  return stwncpy (b, be, ProgramName, strlen (ProgramName));
}

Char *
buffer_info::encoding (Char *b, Char *be) const
{
  return copy_lisp_string (b, be, xchar_encoding_name (b_bufp->lchar_encoding));
}

Char *
buffer_info::eol_code (Char *b, Char *be) const
{
  const Char *s = b_eol_name[b_bufp->b_eol_code];
  while (*s && b < be)
    *b++ = *s++;
  return b;
}

Char *
buffer_info::ime_mode (Char *b, Char *be) const
{
  if (!b_ime)
    return b;
  *b_ime = 1;
  if (app.ime_open_mode == kbd_queue::IME_MODE_ON)
    {
      if (b < be) *b++ = (Char)0x3042;  /* あ */
    }
  else
    {
      if (b < be) *b++ = '-';
      if (b < be) *b++ = '-';
    }
  return b;
}

Char *
buffer_info::position (Char *b, Char *be) const
{
  if (b_posp)
    *b_posp = b;
  else if (b_wp)
    {
      char tem[64];
      int tl = sprintf (tem, "%d:%d", b_wp->w_plinenum, b_wp->w_column);
      b = stwncpy (b, be, tem, tl);
    }
  return b;
}

Char *
buffer_info::version (Char *b, Char *be, int pound) const
{
  const char *s = pound ? DisplayVersionString : VersionString;
  return stwncpy (b, be, s, strlen (s));
}

Char *
buffer_info::host_name (Char *b, Char *be, int pound) const
{
  if (*sysdep.host_name)
    {
      if (pound && b < be)
        *b++ = '@';
      b = stwncpy (b, be, sysdep.host_name, strlen (sysdep.host_name));
    }
  return b;
}

Char *
buffer_info::process_id (Char *b, Char *be) const
{
  char tem[64];
  int tl = sprintf_s (tem, sizeof tem, "%d", sysdep.process_id);
  return stwncpy (b, be, tem, tl);
}

Char *
buffer_info::admin_user (Char *b, Char *be) const
{
  if (Fadmin_user_p () == Qt)
    {
      /* 管理者:  = U+7BA1 U+7406 U+8005 U+003A U+0020 */
      static const Char label[] = { 0x7BA1, 0x7406, 0x8005, 0x003A, 0x0020, 0 };
      for (const Char *p = label; *p && b < be; p++)
        *b++ = *p;
    }
  return b;
}

Char *
buffer_info::percent (Char *b, Char *be) const
{
  if (b_percentp)
    *b_percentp = b;
  else if (b_bufp && b_wp)
    {
      char tem[64];
      int tl;
      if (b_bufp->b_nchars > 0)
        tl = sprintf_s (tem, 64, "%d", (100 * b_wp->w_point.p_point) / b_bufp->b_nchars);
      else
        tl = sprintf_s (tem, 64, "100");
      b = stwncpy (b, be, tem, tl);
    }
  return b;
}


Char *
buffer_info::format (lisp fmt, Char *b, Char *be) const
{
  if (b_posp)
    *b_posp = 0;
  if (b_ime)
    *b_ime = 0;
  if (b_percentp)
    *b_percentp = 0;

  const ucs4_t *p = xstring_contents (fmt);
  const ucs4_t *const pe = p + xstring_length (fmt);

  while (p < pe && b < be)
    {
      ucs4_t c = *p++;
      if (c != '%')
        {
        normal_char:
          if (b < be) *b++ = Char (c);
        }
      else
        {
          if (p == pe)
            break;

          c = *p++;
          int pound = 0;
          if (c == '#')
            {
              pound = 1;
              if (p == pe)
                break;
              c = *p++;
            }

          switch (c)
            {
            default:
              goto normal_char;

            case '*':
              b = modified (b, pound);
              break;

            case 'r':
              b = read_only (b, pound);
              break;

            case 'p':
              b = progname (b, be);
              break;

            case 'v':
              b = version (b, be, pound);
              break;

            case 'h':
              b = host_name (b, be, pound);
              break;

            case 'b':
              b = buffer_name (b, be);
              break;

            case 'f':
              b = file_name (b, be, pound);
              break;

            case 'F':
              b = file_or_buffer_name (b, be, pound);
              break;

            case 'M':
            case 'm':
              b = mode_name (b, be, c);
              break;

            case 'k':
              b = encoding (b, be);
              break;

            case 'l':
              b = eol_code (b, be);
              break;

            case 'i':
              b = ime_mode (b, be);
              break;

            case 'P':
              b = position (b, be);
              break;

            case '/':
              b = percent (b, be);
              break;

            case '$':
              b = process_id (b, be);
              break;

            case '!':
              b = admin_user (b, be);
              break;
            }
        }
    }

  return b;
}
