// Console subsystem entry point for batch operations (byte-compile, etc.)
// Calls WinMain with SW_HIDE so the window is created but not shown.

#include <windows.h>
#include <cstdio>

int PASCAL WinMain (HINSTANCE, HINSTANCE, LPSTR, int);
extern bool g_batch_mode;

int main ()
{
  g_batch_mode = true;
  SetErrorMode (SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX | SEM_NOGPFAULTERRORBOX);
  setvbuf (stdout, NULL, _IONBF, 0);
  setvbuf (stderr, NULL, _IONBF, 0);
  int rc = WinMain (GetModuleHandle (NULL), NULL, GetCommandLineA (), SW_HIDE);
  fflush (stdout);
  fflush (stderr);
  return rc;
}
