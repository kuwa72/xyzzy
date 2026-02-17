// Console subsystem entry point for batch operations (byte-compile, etc.)
// Calls WinMain with SW_HIDE so the window is created but not shown.

#include <windows.h>

int PASCAL WinMain (HINSTANCE, HINSTANCE, LPSTR, int);

int main ()
{
  return WinMain (GetModuleHandle (NULL), NULL, GetCommandLineA (), SW_HIDE);
}
