#ifndef _ed_hwnd_h_
# define _ed_hwnd_h_

# ifdef _WIN32

/* src/core/ed.h から追い出した HWND 群 (issue #297)。
   core 側から触られていない Win32 ハンドルは frontend グローバルに居る。 */

extern HWND g_status_window_hwnd;
extern HWND g_active_frame_hwnd;
extern HWND g_active_frame_has_caret;
extern HWND g_active_frame_has_caret_last;
extern HWND g_app_hwnd_sw;

# endif // _WIN32

#endif // _ed_hwnd_h_
