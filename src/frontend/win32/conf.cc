#include "stdafx.h"
#include "ed.h"
#include "environ.h"
#include "print.h"
#include "monitor.h"

#define DECLARE_CONF(NAME, VALUE) char NAME[] = VALUE;
#include "conf.h"

// CP932 -> wchar_t helper for INI file I/O (A->W migration).
// All internal strings are CP932; WritePrivateProfileStringW needs wchar_t.
static void
write_ini (const char *section, const char *name, const char *str)
{
  wchar_t wpath[PATH_MAX + 1];
  MultiByteToWideChar (932, 0, app.ini_file_path, -1, wpath, PATH_MAX + 1);

  wchar_t wsection[256], wname[256];
  wchar_t *ws = 0, *wn = 0;
  if (section)
    { MultiByteToWideChar (932, 0, section, -1, wsection, 256); ws = wsection; }
  if (name)
    { MultiByteToWideChar (932, 0, name, -1, wname, 256); wn = wname; }

  if (str)
    {
      wchar_t wstr[1024];
      MultiByteToWideChar (932, 0, str, -1, wstr, 1024);
      WritePrivateProfileStringW (ws, wn, wstr, wpath);
    }
  else
    WritePrivateProfileStringW (ws, wn, 0, wpath);
}

static int
read_ini (const char *section, const char *name, char *buf, int size)
{
  wchar_t wsection[256], wname[256], wpath[PATH_MAX + 1];
  MultiByteToWideChar (932, 0, section, -1, wsection, 256);
  MultiByteToWideChar (932, 0, name, -1, wname, 256);
  MultiByteToWideChar (932, 0, app.ini_file_path, -1, wpath, PATH_MAX + 1);
  wchar_t wbuf[1024];
  GetPrivateProfileStringW (wsection, wname, L"", wbuf, 1024, wpath);
  WideCharToMultiByte (932, 0, wbuf, -1, buf, size, 0, 0);
  buf[size - 1] = 0;
  return (int)strlen (buf);
}

void
write_conf (const char *section, const char *name, const char *str)
{
  write_ini (section, name, str);
}

void
write_conf (const char *section, const char *name, long value, int hex)
{
  char buf[32];
  sprintf (buf, hex ? "#%lx" : "%ld", value);
  write_ini (section, name, buf);
}

void
write_conf (const char *section, const char *name, const int *value, int n, int hex)
{
  char *buf = (char *)alloca (16 * n), *b = buf;
  for (int i = 0; i < n; i++)
    b += sprintf (b, hex ? ",#%x" : ",%d", *value++);
  write_ini (section, name, buf + 1);
}

void
write_conf (const char *section, const char *name, const RECT &r)
{
  char buf[128];
  sprintf (buf, "(%d,%d)-(%d,%d)", r.left, r.top, r.right, r.bottom);
  write_ini (section, name, buf);
}

void
write_conf (const char *section, const char *name, const LOGFONTW &lf)
{
  char face[LF_FACESIZE * 3];
  WideCharToMultiByte (CP_ACP, 0, lf.lfFaceName, -1, face, sizeof face, 0, 0);
  char buf[128];
  sprintf (buf, "%d,\"%s\",%d", lf.lfHeight, face, lf.lfCharSet);
  write_ini (section, name, buf);
}

void
write_conf (const char *section, const char *name, const PRLOGFONT &lf)
{
  char buf[128];
  sprintf (buf, "%d,\"%s\",%d,%d,%d", lf.point, lf.face, lf.charset, lf.bold, lf.italic);
  write_ini (section, name, buf);
}

void
write_conf (const char *section, const char *name, const WINDOWPLACEMENT &w)
{
  char buf[128];
  sprintf (buf, "(%d,%d)-(%d,%d),%d",
           w.rcNormalPosition.left,
           w.rcNormalPosition.top,
           w.rcNormalPosition.right,
           w.rcNormalPosition.bottom,
           w.showCmd);
  write_ini (section, name, buf);
}

void
flush_conf ()
{
  write_ini (0, 0, 0);
}

int
read_conf (const char *section, const char *name, char *buf, int size)
{
  return read_ini (section, name, buf, size);
}

void
delete_conf (const char *section)
{
  write_ini (section, 0, 0);
}

static int
parse_int (const char *s, int &v)
{
  return sscanf (s, *s == '#' ? "#%x" : "%d", &v) == 1;
}

int
read_conf (const char *section, const char *name, int &value)
{
  char buf[32];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  return parse_int (buf, value);
}

#if INT_MAX != LONG_MAX
static int
parse_long (const char *s, u_long &v)
{
  return sscanf (s, *s == '#' ? "#%lx" : "%ld", &v) == 1;
}

int
read_conf (const char *section, const char *name, u_long &value)
{
  char buf[32];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  return parse_long (buf, value);
}
#endif /* INT_MAX != LONG_MAX */

int
read_conf (const char *section, const char *name, int *value, int n)
{
  int size = 16 * n;
  char *buf = (char *)alloca (size);
  int l = read_conf (section, name, buf, size);
  if (!l || l >= size - 1)
    return 0;
  for (int i = 1; i < n; i++, buf++, value++)
    {
      if (!parse_int (buf, *value))
        return 0;
      buf = strchr (buf, ',');
      if (!buf)
        return 0;
    }
  return parse_int (buf, *value);
}

int
read_conf (const char *section, const char *name, RECT &rr)
{
  char buf[128];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  int t, r, b;
  if (sscanf (buf, "(%d,%d)-(%d,%d)", &l, &t, &r, &b) != 4)
    return 0;
  rr.left = l;
  rr.top = t;
  rr.right = r;
  rr.bottom = b;
  return 1;
}

int
read_conf (const char *section, const char *name, LOGFONTW &lf)
{
  char buf[128];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  memset (&lf, 0, sizeof lf);
  int h, cs;
  char face[LF_FACESIZE];
  if (sscanf (buf, "%d,\"%31[^\"]\",%d", &h, face, &cs) != 3)
    return 0;
  MultiByteToWideChar (CP_ACP, 0, face, -1, lf.lfFaceName, LF_FACESIZE);
  lf.lfHeight = h;
  lf.lfCharSet = cs;
  return 1;
}

int
read_conf (const char *section, const char *name, PRLOGFONT &lf)
{
  char buf[128];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  int point, cs, bold, italic;
  if (sscanf (buf, "%d,\"%31[^\"]\",%d,%d,%d",
              &point, lf.face, &cs, &bold, &italic) != 5)
    return 0;
  lf.point = point;
  lf.charset = cs;
  lf.bold = bold;
  lf.italic = italic;
  return 1;
}

int
read_conf (const char *section, const char *name, WINDOWPLACEMENT &w)
{
  char buf[128];
  int l = read_conf (section, name, buf, sizeof buf);
  if (!l || l >= sizeof buf - 1)
    return 0;
  int t, r, b, s;
  if (sscanf (buf, "(%d,%d)-(%d,%d),%d", &l, &t, &r, &b, &s) != 5)
    return 0;
  w.rcNormalPosition.left = l;
  w.rcNormalPosition.top = t;
  w.rcNormalPosition.right = r;
  w.rcNormalPosition.bottom = b;
  w.showCmd = s;
  return 1;
}

void
conf_write_string (const char *section, const char *name, const char *string)
{
  int l = strlen (string);
  char *b = (char *)alloca (l + 3);
  *b = '"';
  memcpy (b + 1, string, l);
  b[l + 1] = '"';
  b[l + 2] = 0;
  write_conf (section, name, b);
}

static void
adjust_geometry (RECT &r, const RECT &or, int posp, int sizep)
{
  if (!sizep)
    {
      r.right = r.left + or.right - or.left;
      r.bottom = r.top + or.bottom - or.top;
    }
  if (!posp)
    {
      r.right += or.left - r.left;
      r.bottom += or.top - r.top;
      r.left = or.left;
      r.top = or.top;
    }
}

int
conf_load_geometry (HWND hwnd, const char *section,
                    const char *prefix, int posp, int sizep)
{
  if (!posp && !sizep)
    return 0;

  WINDOWPLACEMENT w;
  w.length = sizeof w;
  if (!GetWindowPlacement (hwnd, &w))
    return 0;

  RECT cr (w.rcNormalPosition);

  char b[64];
  make_geometry_key (b, sizeof b, prefix);
  if (!read_conf (section, b, w))
    return 0;

  adjust_geometry (w.rcNormalPosition, cr, posp, sizep);

  w.flags = 0;
  if (w.showCmd == SW_SHOWMINIMIZED)
    w.showCmd = SW_SHOW;
  return SetWindowPlacement (hwnd, &w);
}

void
conf_save_geometry (HWND hwnd, const char *section,
                    const char *prefix, int posp, int sizep)
{
  if (!posp && !sizep)
    return;

  WINDOWPLACEMENT w;
  w.length = sizeof w;
  if (!GetWindowPlacement (hwnd, &w))
    return;
  if (xsymbol_value (Vfiler_save_window_snap_size) != Qnil)
    adjust_snap_window_size (hwnd, w);

  char b[64];
  make_geometry_key (b, sizeof b, prefix);

  if (!posp || !sizep)
    {
      WINDOWPLACEMENT ow;
      if (read_conf (section, b, ow))
        adjust_geometry (w.rcNormalPosition, ow.rcNormalPosition, posp, sizep);
    }

  write_conf (section, b, w);
}

void
adjust_snap_window_size (HWND hwnd, WINDOWPLACEMENT &w)
{
  if (w.showCmd != SW_SHOWNORMAL) return;

  RECT r;
  if (!GetWindowRect (hwnd, &r)) return;

  w.rcNormalPosition.left = r.left;
  w.rcNormalPosition.top = r.top;
  w.rcNormalPosition.right = r.right;
  w.rcNormalPosition.bottom = r.bottom;

  MONITORINFO info;
  if (monitor.get_monitorinfo_from_window (hwnd, &info))
    {
      int taskbar_width = info.rcWork.left - info.rcMonitor.left;
      int taskbar_height = info.rcWork.top - info.rcMonitor.top;
      w.rcNormalPosition.left -= taskbar_width;
      w.rcNormalPosition.top -= taskbar_height;
      w.rcNormalPosition.right -= taskbar_width;
      w.rcNormalPosition.bottom -= taskbar_height;
    }
}

void
make_geometry_key (char* buf, size_t bufsize, const char *prefix)
{
  _snprintf_s (buf, bufsize, _TRUNCATE,
               "%s%dx%d", prefix ? prefix : "",
               GetSystemMetrics (SM_CXSCREEN),
               GetSystemMetrics (SM_CYSCREEN));
}

#define CONF_SZ           0x10000
#define CONF_INT          0x20000
#define CONF_HEX          0x30000
#define CONF_LOGFONT      0x40000
#define CONF_PRINT_FONT   0x50000

struct conf
{
  const char *name;
  DWORD reg_type;
  int type;
};

static const conf misc[] =
{
  {cfgSaveWindowSize, REG_DWORD, CONF_INT},
  {cfgSaveWindowSnapSize, REG_DWORD, CONF_INT},
  {cfgSaveWindowPosition, REG_DWORD, CONF_INT},
  {cfgWindowFlags, REG_DWORD, CONF_HEX},
  {cfgFnkeyLabels, REG_DWORD, CONF_INT},
  {cfgFoldMode, REG_DWORD, CONF_INT},
  {cfgFoldLineNumMode, REG_DWORD, CONF_INT},
  {cfgRestoreWindowSize, REG_DWORD, CONF_INT},
  {cfgRestoreWindowPosition, REG_DWORD, CONF_INT},
};

static const conf buffer_selector[] =
{
  {cfgColumn, REG_BINARY, CONF_INT | 4},
};

static const conf colors[] =
{
  {cfgTextColor, REG_DWORD, CONF_HEX},
  {cfgBackColor, REG_DWORD, CONF_HEX},
  {cfgCtlColor, REG_DWORD, CONF_HEX},
  {cfgKwdColor1, REG_DWORD, CONF_HEX},
  {cfgKwdColor2, REG_DWORD, CONF_HEX},
  {cfgKwdColor3, REG_DWORD, CONF_HEX},
  {cfgStringColor, REG_DWORD, CONF_HEX},
  {cfgCommentColor, REG_DWORD, CONF_HEX},
  {cfgTagColor, REG_DWORD, CONF_HEX},
  {cfgCursorColor, REG_DWORD, CONF_HEX},
  {cfgCaretColor, REG_DWORD, CONF_HEX},
  {cfgImeCaretColor, REG_DWORD, CONF_HEX},
  {cfgModeLineFg, REG_DWORD, CONF_HEX},
  {cfgModeLineBg, REG_DWORD, CONF_HEX},
};

static const conf filer[] =
{
  {cfgTextColor, REG_DWORD, CONF_HEX},
  {cfgBackColor, REG_DWORD, CONF_HEX},
  {cfgCursorColor, REG_DWORD, CONF_HEX},
  {cfgColumnLeft, REG_BINARY, CONF_INT | 4},
  {cfgColumnRight, REG_BINARY, CONF_INT | 4},
  {cfgSortRight, REG_DWORD, CONF_INT},
  {cfgSortLeft, REG_DWORD, CONF_INT},
  {cfgColumn, REG_BINARY, CONF_INT | 4},
  {cfgSort, REG_DWORD, CONF_INT},
};

static const conf font[] =
{
  {cfgJapanese, REG_BINARY, CONF_LOGFONT},
  {cfgGb2312, REG_BINARY, CONF_LOGFONT},
  {cfgKsc5601, REG_BINARY, CONF_LOGFONT},
  {cfgCyrillic, REG_BINARY, CONF_LOGFONT},
  {cfgBig5, REG_BINARY, CONF_LOGFONT},
  {cfgAscii, REG_BINARY, CONF_LOGFONT},
  {cfgGreek, REG_BINARY, CONF_LOGFONT},
  {cfgLineFeed, REG_DWORD, CONF_INT},
  {cfgBackslash, REG_DWORD, CONF_INT},
  {cfgLatin, REG_BINARY, CONF_LOGFONT},
  {cfgLineSpacing, REG_DWORD, CONF_INT},
  {cfgRecommendSize, REG_DWORD, CONF_INT},
};

static const conf print[] =
{
  {cfgMargin, REG_BINARY, CONF_INT | 4},
  {cfgHeaderMargin, REG_DWORD, CONF_INT},
  {cfgFooterMargin, REG_DWORD, CONF_INT},
  {cfgLineNumber, REG_DWORD, CONF_INT},
  {cfgHeader, REG_SZ, CONF_SZ},
  {cfgFooter, REG_SZ, CONF_SZ},
  {cfgHeaderOn, REG_DWORD, CONF_INT},
  {cfgFooterOn, REG_DWORD, CONF_INT},
  {cfgColumns, REG_DWORD, CONF_INT},
  {cfgColumnSep, REG_DWORD, CONF_INT},
  {cfgFoldColumns, REG_DWORD, CONF_INT},
  {cfgAscii, REG_BINARY, CONF_PRINT_FONT},
  {cfgJapanese, REG_BINARY, CONF_PRINT_FONT},
  {cfgLatin, REG_BINARY, CONF_PRINT_FONT},
  {cfgCyrillic, REG_BINARY, CONF_PRINT_FONT},
  {cfgGreek, REG_BINARY, CONF_PRINT_FONT},
  {cfgGb2312, REG_BINARY, CONF_PRINT_FONT},
  {cfgBig5, REG_BINARY, CONF_PRINT_FONT},
  {cfgKsc5601, REG_BINARY, CONF_PRINT_FONT},
};

static const conf preview[] =
{
  {cfgScale, REG_DWORD, CONF_INT},
};

// ASCII-only char* → Char* widening into alloca'd buffer.
// reg2ini migrates legacy xyzzy registry data whose key names are ASCII.
static Char *
ascii_widen (Char *dst, const char *src)
{
  Char *p = dst;
  while ((*p++ = (Char)(u_char)*src++))
    ;
  return dst;
}

#define ASCII_W(s) \
  ascii_widen ((Char *)alloca ((strlen (s) + 1) * sizeof (Char)), (s))

static size_t
wsz_len (const Char *s)
{
  const Char *p = s;
  while (*p) p++;
  return p - s;
}

static void
reg2ini_str (const char *key, ReadRegistry &r, const conf &cf)
{
  Char *wname = ASCII_W (cf.name);
  DWORD type;
  int l = r.query (wname, &type);
  if (l > 0 && type == REG_SZ && !(l % sizeof (Char)))
    {
      int ncu = l / sizeof (Char);
      Char *w = (Char *)alloca ((ncu + 1) * sizeof (Char));
      if (r.get (wname, w, (ncu + 1) * sizeof (Char)) == l)
        {
          while (ncu > 0 && w[ncu - 1] == 0) ncu--;
          size_t nbytes = w2sl (w, ncu);
          char *v = (char *)alloca (nbytes + 1);
          w2s (v, w, ncu);
          v[nbytes] = 0;
          conf_write_string (key, cf.name, v);
        }
    }
}

static void
reg2ini_int (const char *key, ReadRegistry &r, const conf &cf)
{
  int v;
  if (r.get (ASCII_W (cf.name), &v))
    write_conf (key, cf.name, v, cf.type == CONF_HEX);
}

static void
reg2ini_int (const char *key, ReadRegistry &r, const conf &cf, int l)
{
  int sz = sizeof (int) * l;
  int *v = (int *)alloca (sz);
  if (r.get (ASCII_W (cf.name), v, sz) == sz)
    write_conf (key, cf.name, v, l, (cf.type & ~0xffff) == CONF_HEX);
}

static void
reg2ini_logfont (const char *key, ReadRegistry &r, const conf &cf)
{
  LOGFONTA lfa;
  if (r.get (ASCII_W (cf.name), &lfa, sizeof lfa) == sizeof lfa)
    {
      LOGFONTW lfw;
      logfont_a_to_w (lfa, lfw);
      write_conf (key, cf.name, lfw);
    }
}

static void
reg2ini_print_font (const char *key, ReadRegistry &r, const conf &cf)
{
  PRLOGFONT lf;
  if (r.get (ASCII_W (cf.name), &lf, sizeof lf) == sizeof lf)
    write_conf (key, cf.name, lf);
}

static void
reg2ini (const char *rkey, const char *ikey, const conf *cf, int n)
{
  Char *key;
  if (!*rkey)
    key = (Char *)Registry::Settings;
  else
    {
      size_t sl = wsz_len (Registry::Settings);
      size_t rl = strlen (rkey);
      key = (Char *)alloca ((sl + 1 + rl + 1) * sizeof (Char));
      memcpy (key, Registry::Settings, sl * sizeof (Char));
      key[sl] = '\\';
      ascii_widen (key + sl + 1, rkey);
    }

  if (!ikey)
    ikey = rkey;

  ReadRegistry r (key);
  if (r.fail ())
    return;

  for (int i = 0; i < n; i++)
    switch (cf[i].type & ~0xffff)
      {
      case CONF_SZ:
        reg2ini_str (ikey, r, cf[i]);
        break;

      case CONF_INT:
      case CONF_HEX:
        if (!(cf[i].type & 0xffff))
          reg2ini_int (ikey, r, cf[i]);
        else
          reg2ini_int (ikey, r, cf[i], cf[i].type & 0xffff);
        break;

      case CONF_LOGFONT:
        reg2ini_logfont (ikey, r, cf[i]);
        break;

      case CONF_PRINT_FONT:
        reg2ini_print_font (ikey, r, cf[i]);
        break;
      }
}

static void
reg2ini_colors ()
{
  size_t sl = wsz_len (Registry::Settings);
  size_t cl = strlen (cfgColors);
  Char *key = (Char *)alloca ((sl + 1 + cl + 1) * sizeof (Char));
  memcpy (key, Registry::Settings, sl * sizeof (Char));
  key[sl] = '\\';
  ascii_widen (key + sl + 1, cfgColors);

  ReadRegistry r (key);
  if (r.fail ())
    return;

  conf cf;
  cf.type = CONF_HEX;
  char name[16];
  cf.name = name;
  for (int i = 1; i <= 16; i++)
    {
      sprintf (name, "%s%d", cfgFg, i);
      reg2ini_int (cfgColors, r, cf);
      sprintf (name, "%s%d", cfgBg, i);
      reg2ini_int (cfgColors, r, cf);
    }

  COLORREF c[16];
  static const Char cust_colors[] = {'C','u','s','t','C','o','l','o','r','s',0};
  if (r.get (cust_colors, c, sizeof c) == sizeof c)
    for (int i = 0; i < 16; i++)
      {
        sprintf (name, "%s%d", cfgCustColor, i);
        write_conf (cfgColors, name, long (c[i]), 1);
      }
}

static void
reg2ini_geometry (const char *rkey)
{
  size_t sl = wsz_len (Registry::Settings);
  size_t rl = strlen (rkey);
  Char *key = (Char *)alloca ((sl + 1 + rl + 1) * sizeof (Char));
  memcpy (key, Registry::Settings, sl * sizeof (Char));
  key[sl] = '\\';
  ascii_widen (key + sl + 1, rkey);
  EnumRegistry er (key);
  if (er.fail ())
    return;

  for (int i = 0;; i++)
    {
      Char name[128];
      DWORD namel = sizeof name / sizeof (Char);
      WINDOWPLACEMENT w;
      DWORD wl = sizeof w;
      DWORD type;
      int e = RegEnumValueW (er, i, (LPWSTR)name, &namel, 0, &type, (BYTE *)&w, &wl);
      if (e == ERROR_SUCCESS)
        {
          if (type == REG_BINARY && wl == sizeof w && w.length == sizeof w)
            {
              size_t nbytes = w2sl (name, namel);
              char *aname = (char *)alloca (nbytes + 1);
              w2s (aname, name, namel);
              aname[nbytes] = 0;
              write_conf (rkey, aname, w);
            }
        }
      else if (e != ERROR_MORE_DATA)
        break;
    }
}

static void
reg2ini_geometry ()
{
  const char *rkey = cfgGeometry;
  size_t sl = wsz_len (Registry::Settings);
  size_t rl = strlen (rkey);
  Char *rootkey = (Char *)alloca ((sl + 1 + rl + 1) * sizeof (Char));
  memcpy (rootkey, Registry::Settings, sl * sizeof (Char));
  rootkey[sl] = '\\';
  ascii_widen (rootkey + sl + 1, rkey);
  EnumRegistry er (rootkey);
  if (er.fail ())
    return;

  for (int i = 0;; i++)
    {
      Char name[128];
      DWORD namel = sizeof name / sizeof (Char);
      FILETIME ft;
      int e = RegEnumKeyExW (er, i, (LPWSTR)name, &namel, 0, 0, 0, &ft);
      if (e == ERROR_SUCCESS)
        {
          WINDOWPLACEMENT w;
          Char key[256];
          size_t pos = sl;
          memcpy (key, Registry::Settings, sl * sizeof (Char));
          key[pos++] = '\\';
          ascii_widen (key + pos, cfgGeometry);
          pos += strlen (cfgGeometry);
          key[pos++] = '\\';
          memcpy (key + pos, name, namel * sizeof (Char));
          key[pos + namel] = 0;
          ReadRegistry r (key);
          if (!r.fail ()
              && r.get (ASCII_W (cfgShowCmd), (int *)&w.showCmd)
              && r.get (ASCII_W (cfgLeft), &w.rcNormalPosition.left)
              && r.get (ASCII_W (cfgTop), &w.rcNormalPosition.top)
              && r.get (ASCII_W (cfgRight), &w.rcNormalPosition.right)
              && r.get (ASCII_W (cfgBottom), &w.rcNormalPosition.bottom))
            {
              size_t nbytes = w2sl (name, namel);
              char *aname = (char *)alloca (nbytes + 1);
              w2s (aname, name, namel);
              aname[nbytes] = 0;
              write_conf (cfgMisc, aname, w);
            }
        }
      else if (e != ERROR_MORE_DATA)
        break;
    }

  reg2ini_geometry (cfgFiler);
  reg2ini_geometry (cfgPrintPreview);
}

int
reg2ini ()
{
  {
    ReadRegistry r (Registry::Settings);
    if (r.fail ())
      return 0;
  }

  reg2ini ("", cfgMisc, misc, numberof (misc));
  reg2ini (cfgBufferSelector, 0, buffer_selector, numberof (buffer_selector));
  reg2ini (cfgColors, 0, colors, numberof (colors));
  reg2ini_colors ();
  reg2ini (cfgFiler, 0, filer, numberof (filer));
  reg2ini (cfgFont, 0, font, numberof (font));
  reg2ini (cfgPrint, 0, print, numberof (print));
  reg2ini (cfgPrintPreview, 0, preview, numberof (preview));
  reg2ini_geometry ();
  flush_conf ();
  return 1;
}

static int
reg_empty_tree_p (HKEY hkey)
{
  Char cls[1024];
  DWORD clsl = sizeof cls / sizeof (Char);
  DWORD nkeys, keyl, xclsl, nvals, naml, datal, desc;
  FILETIME ft;
  if (RegQueryInfoKeyW (hkey, (LPWSTR)cls, &clsl, 0, &nkeys, &keyl, &xclsl,
                       &nvals, &naml, &datal, &desc, &ft) != ERROR_SUCCESS)
    return 0;
  return !(nkeys + nvals);
}

static int
delete_sub_tree (HKEY hkey, const Char *name)
{
  {
    EnumRegistry r (hkey, name);
    if (!r.fail ())
      {
        for (int i = 0; i < 100; i++)
          {
            FILETIME ft;
            Char buf[256];
            DWORD sz = sizeof buf / sizeof (Char);
            if (RegEnumKeyExW (r, 0, (LPWSTR)buf, &sz, 0, 0, 0, &ft) != ERROR_SUCCESS
                || !delete_sub_tree (r, buf))
              break;
          }
      }
  }
  return RegDeleteKeyW (hkey, (LPCWSTR)name) == ERROR_SUCCESS;
}

void
reg_delete_tree ()
{
  static const Char sw_free[] = {'S','o','f','t','w','a','r','e','\\',
                                 'F','r','e','e',' ',
                                 'S','o','f','t','w','a','r','e',0};
  static const Char xyzzy[] = {'x','y','z','z','y',0};
  static const Char sw[] = {'S','o','f','t','w','a','r','e',0};
  static const Char free_sw[] = {'F','r','e','e',' ','S','o','f','t','w','a','r','e',0};
  {
    EnumRegistry r (HKEY_CURRENT_USER, sw_free);
    if (r.fail ())
      return;
    if (sysdep.WinNTp ())
      delete_sub_tree (r, xyzzy);
    else
      RegDeleteKeyW (r, (LPCWSTR)xyzzy);
    if (!reg_empty_tree_p (r))
      return;
  }

  EnumRegistry r (HKEY_CURRENT_USER, sw);
  if (!r.fail ())
    RegDeleteKeyW (r, (LPCWSTR)free_sw);
}
