#ifndef _win32_Window_h_
# define _win32_Window_h_

# ifdef _WIN32

class Window;

void update_caret (HWND, int, int, int, int, COLORREF);
int frame_window_setcursor (HWND, WPARAM, LPARAM);
int frame_window_resize (HWND, LPARAM, const POINT * = 0);
int frame_window_resize (Window *wp, HWND hwnd, const POINT &point, int vert);
void ForceSetForegroundWindow (HWND);

# endif // _WIN32

#endif // _win32_Window_h_
