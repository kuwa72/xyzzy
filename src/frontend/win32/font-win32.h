#ifndef _font_win32_h_
#define _font_win32_h_

int get_font_height (HWND hwnd);
bool font_exist_p (const HDC hdc, const wchar_t *face, BYTE charset);

#endif /* _font_win32_h_ */
