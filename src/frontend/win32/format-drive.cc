#include "stdafx.h"
#include "ed.h"

lisp
Fformat_drive (lisp ldrive, lisp lquick)
{
  int drive;
  if (!ldrive || ldrive == Qnil)
    drive = 0;
  else if (charp (ldrive))
    {
      Char c = xchar_code (ldrive);
      if (lower_char_p (c))
        drive = c - 'a';
      else if (upper_char_p (c))
        drive = c - 'A';
      else
        FErange_error (ldrive);
    }
  else
    {
      drive = fixnum_value (ldrive);
      if (drive < 0 || drive >= 26)
        FErange_error (ldrive);
    }

  HMODULE shell = GetModuleHandleW (L"shell32.dll");
  if (!shell)
    FEsimple_win32_error (GetLastError ());

  int (WINAPI *fmt)(HWND, int, int, int) =
    (int (WINAPI *)(HWND, int, int, int))GetProcAddress (shell, "SHFormatDrive");
  if (!fmt)
    FEsimple_win32_error (GetLastError ());

  HWND hwnd = get_active_window ();
  HWND focus = GetFocus ();
  int f = (*fmt)(hwnd, drive, 0, lquick && lquick != Qnil);
  EnableWindow (hwnd, 1);
  SetFocus (focus);
  return boole (!f);
}
