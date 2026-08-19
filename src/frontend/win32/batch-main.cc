// Console subsystem entry point for batch operations (byte-compile, etc.)
// Calls WinMain with SW_HIDE so the window is created but not shown.

#include <windows.h>
#include <cstdio>
#ifdef _MSC_VER
# include <crtdbg.h>
#endif

int PASCAL WinMain (HINSTANCE, HINSTANCE, LPSTR, int);
extern bool g_batch_mode;

int main ()
{
  g_batch_mode = true;
  SetErrorMode (SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX | SEM_NOGPFAULTERRORBOX);
#ifdef _MSC_VER
  // SetErrorMode does not cover the CRT's own reporting: a failing assert puts
  // up an Abort/Retry/Ignore box of its own and waits for a click, which with
  // nobody at the console means the run never ends.  Send it to stderr, where
  // it belongs in batch.  Only matters when asserts are compiled in.
  static const int reports[] = {_CRT_ASSERT, _CRT_ERROR, _CRT_WARN};
  for (int i = 0; i < int (sizeof reports / sizeof *reports); i++)
    {
      _CrtSetReportMode (reports[i], _CRTDBG_MODE_FILE);
      _CrtSetReportFile (reports[i], _CRTDBG_FILE_STDERR);
    }
#endif
  setvbuf (stdout, NULL, _IONBF, 0);
  setvbuf (stderr, NULL, _IONBF, 0);
  int rc = WinMain (GetModuleHandle (NULL), NULL, GetCommandLineA (), SW_HIDE);
  fflush (stdout);
  fflush (stderr);
  return rc;
}
