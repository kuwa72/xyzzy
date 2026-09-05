#ifndef _font_win32_h_
#define _font_win32_h_

int get_font_height (HWND hwnd);
bool font_exist_p (const HDC hdc, const wchar_t *face, BYTE charset);

void create_fontset_bitmap (const FontSet &);
HBITMAP fontset_bitmap ();

#endif /* _font_win32_h_ */
