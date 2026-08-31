#ifndef _statarea_h_
#define _statarea_h_

/* Win32 のステータスバーの右側 (時刻 / 位置 / 文字コード / Unicode) 。
   **src/core/statarea.h に居た**が、`src/core/` の中から触っているコードが
   1 つも無かったので出した (issue #195 / #185)。

   **`status_area` は `Application` (ed.h) のメンバだった。** 実体は
   `g_stat_area` で、`src/frontend/win32/statarea.cc` が持つ。

   **`app.status_window` (ed.h の `StatusWindow`) とは別物である。**
   あちらは下のバーに出るメッセージ (`message`) で、core が使う。 */

class status_area
{
  enum {ST_TIME, ST_POS, ST_CODE, ST_UNICODE, ST_MAX};

  HWND s_hwnd;
  HFONT s_hfont;
  int s_flags;
  int s_clwidth;
  int s_borders[3];
  int s_min_ext[ST_MAX];
  int s_extent[ST_MAX];
  int s_order[ST_MAX];
  int s_nitems;
  int s_dow;
  char *s_lbuf[ST_MAX];
  char s_timeb[16];             // " XX/XX XX:XX "
  char s_posb[32];              // " XXXXXXXXXX:XXXXXXXXXX "
  char s_codeb[8];              // " XXXX "
  char s_unicodeb[12];          // " U+XXXX "

  static const char s_nil[];
  static const char s_eof[];

  void clear_cache ();
  int get_extent (const char *) const;
  int calc_extent (int, const char *);
  void set_parts () const;
  void update (int) const;
  void update_all ();
  int position ();
  int char_code ();
  int char_unicode ();
  int time ();
  void parse_format (const ucs4_t *, int);
  static lisp format_modified_p ();
  static int char_ext (HDC hdc, char c)
    {
      SIZE sz;
      wchar_t wc;
      cp932_to_wcs (&c, 1, &wc, 1);
      GetTextExtentPoint32W (hdc, &wc, 1, &sz);
      return sz.cx;
    }
  static int char_max_ext (HDC, char, char);
public:
  void init (HWND);
  void resize ();
  void update ();
  void timer ();
  void reload_settings ();
};

/* 実体は src/frontend/win32/statarea.cc。**`Application` のメンバから
   ここへ移した。** */
extern status_area g_stat_area;

#endif /* _statarea_h_ */
