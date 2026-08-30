// -*-C++-*-
//
// 設定 (xyzzy.ini) の読み書き。**Win32 に触っているのは
// Get/WritePrivateProfileStringW の 2 つだけ**で、残りは書式の処理なので
// core に置く。非 Win32 ではその 2 つを src/core/ini-posix.cc が実装する。
//
// もとは src/frontend/win32/conf.cc にあり、非 Win32 では
// ncurses-stubs.cc / cli-stubs.cc の「0 を返す」スタブ 17 個が使われていた。
// **Linux ビルドは終了すると設定を全部忘れていた** (issue #143)。
// あちらに残したのはウィンドウの位置 (モニタとタスクバーを見るもの) と
// レジストリからの移行で、どちらも本当に Win32 の話。
//
// **非 Win32 で書く ini は UTF-8。** Win32 側は CP932 で書くので、同じ
// xyzzy.ini を両方で共有すると非 ASCII の値が化ける。共有する使い方は
// 想定していない (設定の場所自体がプラットフォームで違う)。

#include "stdafx.h"
#include "ed.h"
#include "environ.h"

#define DECLARE_CONF(NAME, VALUE) char NAME[] = VALUE;
#include "conf.h"

/* INI I/O. Section and key names are ASCII literals from conf.h, so they
   stay char*; values are wchar_t, because some of them are pathnames or font
   face names and CP932 cannot hold every one of those. */
static void
write_ini (const char *section, const char *name, const wchar_t *str)
{
  wchar_t wsection[256], wname[256];
  wchar_t *ws = 0, *wn = 0;
  if (section)
    { MultiByteToWideChar (XYZZY_CP932, 0, section, -1, wsection, 256); ws = wsection; }
  if (name)
    { MultiByteToWideChar (XYZZY_CP932, 0, name, -1, wname, 256); wn = wname; }

  WritePrivateProfileStringW (ws, wn, str, app.ini_file_path);
}

static void
write_ini (const char *section, const char *name, const char *str)
{
  if (!str)
    {
      write_ini (section, name, (const wchar_t *)0);
      return;
    }
  wchar_t wstr[1024];
  MultiByteToWideChar (XYZZY_CP932, 0, str, -1, wstr, numberof (wstr));
  write_ini (section, name, wstr);
}

static int
read_ini (const char *section, const char *name, wchar_t *buf, int size)
{
  wchar_t wsection[256], wname[256];
  MultiByteToWideChar (XYZZY_CP932, 0, section, -1, wsection, 256);
  MultiByteToWideChar (XYZZY_CP932, 0, name, -1, wname, 256);
  GetPrivateProfileStringW (wsection, wname, L"", buf, size, app.ini_file_path);
  buf[size - 1] = 0;
  return (int)wcslen (buf);
}

static int
read_ini (const char *section, const char *name, char *buf, int size)
{
  wchar_t wbuf[1024];
  read_ini (section, name, wbuf, numberof (wbuf));
  WideCharToMultiByte (XYZZY_CP932, 0, wbuf, -1, buf, size, 0, 0);
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
  wchar_t buf[128];
  xsnwprintf (buf, numberof (buf), L"%d,\"%ls\",%d",
              lf.lfHeight, lf.lfFaceName, lf.lfCharSet);
  write_ini (section, name, buf);
}

void
write_conf (const char *section, const char *name, const PRLOGFONT &lf)
{
  wchar_t buf[128];
  xsnwprintf (buf, numberof (buf), L"%d,\"%ls\",%d,%d,%d",
              lf.point, lf.face, lf.charset, lf.bold, lf.italic);
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
  write_ini (0, 0, (const wchar_t *)0);
}

int
read_conf (const char *section, const char *name, char *buf, int size)
{
  return read_ini (section, name, buf, size);
}

void
write_conf (const char *section, const char *name, const wchar_t *str)
{
  write_ini (section, name, str);
}

int
read_conf (const char *section, const char *name, wchar_t *buf, int size)
{
  return read_ini (section, name, buf, size);
}

void
delete_conf (const char *section)
{
  write_ini (section, 0, (const wchar_t *)0);
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
  /* The face name is read wide: font names are not all inside CP932, and
     write_conf stores it wide. */
  wchar_t buf[128];
  int l = read_conf (section, name, buf, numberof (buf));
  if (!l || l >= int (numberof (buf)) - 1)
    return 0;
  memset (&lf, 0, sizeof lf);
  int h, cs;
  if (swscanf (buf, L"%d,\"%31[^\"]\",%d", &h, lf.lfFaceName, &cs) != 3)
    return 0;
  lf.lfHeight = h;
  lf.lfCharSet = cs;
  return 1;
}

int
read_conf (const char *section, const char *name, PRLOGFONT &lf)
{
  wchar_t buf[128];
  int l = read_conf (section, name, buf, numberof (buf));
  if (!l || l >= int (numberof (buf)) - 1)
    return 0;
  int point, cs, bold, italic;
  if (swscanf (buf, L"%d,\"%31[^\"]\",%d,%d,%d",
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

void
conf_write_string (const char *section, const char *name, const wchar_t *string)
{
  int l = int (wcslen (string));
  wchar_t *b = (wchar_t *)alloca ((l + 3) * sizeof (wchar_t));
  *b = '"';
  wmemcpy (b + 1, string, l);
  b[l + 1] = '"';
  b[l + 2] = 0;
  write_conf (section, name, b);
}
