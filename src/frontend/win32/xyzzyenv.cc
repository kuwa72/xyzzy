#include <windows.h>
#include <malloc.h>

typedef unsigned long u_long;
typedef unsigned char u_char;

/* The command line is UTF-16 end to end: xyzzy hands us one built with
   CreateProcessW, and we hand one to CreateProcessW in turn. Reading it with
   GetCommandLineA turned every character outside the ANSI code page into '?'.
   A UTF-16 unit is never the trail byte of a two-byte character either, so
   the IsDBCSLeadByte steps that used to be here are gone. */
static wchar_t *
skip_token (wchar_t *p)
{
  if (*p == '"')
    {
      for (p++; *p && *p != '"'; p++)
        ;
      if (*p == '"')
        p++;
    }
  else
    {
      for (; *p && *p != ' ' && *p != '\t'; p++)
        ;
    }
  return p;
}

static wchar_t *
skip_white (wchar_t *p)
{
  for (; *p == ' ' || *p == '\t'; p++)
    ;
  return p;
}

static wchar_t *
split (wchar_t *&beg)
{
  wchar_t *p = skip_token (beg);
  if (*beg == '"')
    {
      beg++;
      if (p > beg && p[-1] == '"')
        p[-1] = 0;
    }
  else if (*p)
    *p++ = 0;
  return skip_white (p);
}

static wchar_t *
split (wchar_t *&beg, int &l)
{
  wchar_t *p = skip_token (beg);
  if (*beg == '"')
    {
      beg++;
      l = p - beg;
      if (p > beg && p[-1] == '"')
        l--;
    }
  else
    l = p - beg;
  return skip_white (p);
}

static u_long
parse_long (const wchar_t *p)
{
  u_long val = 0;
  for (; *p >= '0' && *p <= '9'; p++)
    val = val * 10 + *p - '0';
  return val;
}

static inline int
char_upcase (int c)
{
  return c >= 'a' && c <= 'Z' ? c - ('a' - 'A') : c;
}

static int
wcasecmp (const wchar_t *p, const wchar_t *q, int size)
{
  const wchar_t *const pe = p + size;
  int f;
  for (f = 0; p < pe && !(f = char_upcase (*p) - char_upcase (*q)); p++, q++)
    ;
  return f;
}

/* Write the diagnostic as UTF-8 bytes: the console handle may be redirected
   into a pipe that xyzzy reads, and that side expects bytes. */
static void
doprint (const wchar_t *fmt, ...)
{
  wchar_t buf[1024];
  va_list ap;
  va_start (ap, fmt);
  wvsprintfW (buf, fmt, ap);
  va_end (ap);
  char mb[1024 * 4];
  int l = WideCharToMultiByte (CP_UTF8, 0, buf, -1, mb, sizeof mb, 0, 0);
  if (l > 0)
    {
      DWORD n;
      WriteFile (GetStdHandle (STD_ERROR_HANDLE), mb, l - 1, &n, 0);
    }
}

static void
syserror (int e, wchar_t *buf, int size)
{
  if (!FormatMessageW ((FORMAT_MESSAGE_FROM_SYSTEM
                       | FORMAT_MESSAGE_IGNORE_INSERTS
                       | FORMAT_MESSAGE_MAX_WIDTH_MASK),
                      0, e, GetUserDefaultLangID (),
                      buf, size, 0))
    wsprintfW (buf, L"error %d", e);
}

static int
cmdmatch (const wchar_t *p, const wchar_t *pe, const wchar_t *s)
{
  if (pe - p >= 4 && (!wcasecmp (pe - 4, L".exe", 4)
                      || !wcasecmp (pe - 4, L".com", 4)))
    pe -= 4;
  int l = lstrlenW (s);
  return pe - p >= l && !wcasecmp (pe - l, s, l);
}

static void
set_title (wchar_t *cmd)
{
  int cmdl;
  wchar_t *opt = split (cmd, cmdl);
  if (cmdmatch (cmd, cmd + cmdl, L"cmd")
      || cmdmatch (cmd, cmd + cmdl, L"command"))
    {
      int optl;
      wchar_t *arg = split (opt, optl);
      if (optl == 2 && !wcasecmp (opt, L"/c", 2))
        {
          cmd = arg;
          split (cmd, cmdl);
        }
    }

  wchar_t *title = (wchar_t *)_alloca ((cmdl + 1) * sizeof (wchar_t));
  memcpy (title, cmd, cmdl * sizeof (wchar_t));
  title[cmdl] = 0;
  SetConsoleTitleW (title);
}

int
main (void)
{
  wchar_t buf[256];
  wchar_t *myname = skip_white (GetCommandLineW ());
  wchar_t *opt = split (myname);
  WORD show = 0;
  wchar_t *event;
  if (!wcsncmp (opt, L"-s", 2))
    {
      if (lstrlenW (opt) > 2)
        show = static_cast <WORD> (parse_long (opt + 2));
      event = split (opt);
    }
  else
    {
      event = opt;
    }
  wchar_t *cmdline = split (event);
  wchar_t *dir = 0;
  int no_events = !lstrcmpW (event, L"--");

  if (no_events)
    {
      dir = cmdline;
      cmdline = split (dir);
    }

  set_title (cmdline);

  PROCESS_INFORMATION pi;
  STARTUPINFOW si = {sizeof si};

  si.dwFlags = STARTF_USESTDHANDLES;
  if (show)
    {
      si.dwFlags |= STARTF_USESHOWWINDOW;
      si.wShowWindow = show;
    }
  si.hStdInput = GetStdHandle (STD_INPUT_HANDLE);
  si.hStdOutput = GetStdHandle (STD_OUTPUT_HANDLE);
  si.hStdError = GetStdHandle (STD_ERROR_HANDLE);

  if (!CreateProcessW (0, cmdline, 0, 0, 1, CREATE_NEW_PROCESS_GROUP,
                       0, dir, &si, &pi))
    {
      syserror (GetLastError (), buf, sizeof buf / sizeof *buf);
      doprint (L"%ls: %ls: %ls\n", myname, cmdline, buf);
      ExitProcess (2);
    }

  CloseHandle (pi.hThread);

  if (no_events)
    {
      if (WaitForSingleObject (pi.hProcess, INFINITE) == WAIT_FAILED)
        {
          syserror (GetLastError (), buf, sizeof buf / sizeof *buf);
          doprint (L"%ls: %ls\n", myname, buf);
          ExitProcess (2);
        }
    }
  else
    {
      HANDLE hevent = HANDLE (parse_long (event));

      HANDLE objects[2];
      objects[0] = hevent;
      objects[1] = pi.hProcess;
      while (1)
        {
          DWORD r = WaitForMultipleObjects (2, objects, 0, INFINITE);
          if (r == WAIT_FAILED)
            {
              syserror (GetLastError (), buf, sizeof buf / sizeof *buf);
              doprint (L"%ls: %ls\n", myname, buf);
              ExitProcess (2);
            }
          if (r == WAIT_OBJECT_0 + 1)
            break;

          GenerateConsoleCtrlEvent (CTRL_BREAK_EVENT, pi.dwProcessId);
          if (WaitForSingleObject (pi.hProcess, 3000) == WAIT_TIMEOUT)
            GenerateConsoleCtrlEvent (CTRL_C_EVENT, pi.dwProcessId);
          ResetEvent (hevent);
        }
    }

  DWORD code;
  GetExitCodeProcess (pi.hProcess, &code);
  ExitProcess (code);
}
