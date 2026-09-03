#ifndef _TOPLEV_H_
# define _TOPLEV_H_

# ifdef _WIN32

LRESULT CALLBACK toplevel_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK frame_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK client_wndproc (HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK modeline_wndproc (HWND, UINT, WPARAM, LPARAM);

# endif // _WIN32

#endif // _TOPLEV_H_
