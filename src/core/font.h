#ifndef _font_h_
#define _font_h_

#define FONT_SIZE_MIN_PIXEL 8
#define FONT_SIZE_MAX_PIXEL 48

struct FontMetricsResult;  // font-metrics.h (issue #195 step5)

class FontObject
{
protected:
  HFONT fo_hfont;
  int fo_need_pad;
  POINT fo_offset;
  SIZE fo_size;
  int fo_ascent;
  LOGFONTW fo_logfont;
public:
  FontObject () : fo_hfont (0) {}
  ~FontObject () {if (fo_hfont) DeleteObject (fo_hfont);}
  int create (const LOGFONTW &);
  int create (const wchar_t *, int, int);
  operator HFONT () const {return fo_hfont;}
  const HFONT hfont () const {return fo_hfont;}
  int need_pad_p () const {return fo_need_pad;}
  void require_pad () {fo_need_pad = 1;}
  void get_metrics ();
  void get_metrics (HDC, SIZE &, SIZE &);
  void set_metrics (const FontMetricsResult &);  // issue #195 step5d
  void calc_offset (const SIZE &);
  const SIZE &size () const {return fo_size;}
  const POINT &offset () const {return fo_offset;}
  int ascent () const {return fo_ascent;}
  const LOGFONTW &logfont () const {return fo_logfont;}
  static const bool update (LOGFONTW &lf, const lisp keys, const bool recommend_size_p);
  // issue #195 step5e: defined in the frontend (font.cc), routed through the
  // FontMetrics interface, so this core header no longer embeds GDI calls
  // (GetDC / GetDeviceCaps / MulDiv).
  static int dpi ();
  static int pixel_to_point (int pixel);
  static int point_to_pixel (int point);
};

#define FONT_ASCII          0
#define FONT_JP             1
#define FONT_LATIN          2
#define FONT_CYRILLIC       3
#define FONT_GREEK          4
#define FONT_CN_SIMPLIFIED  5
#define FONT_CN_TRADITIONAL 6
#define FONT_HANGUL         7
#define FONT_GEORGIAN       8
/* 記号・アイコン用。Private Use Area に字形を置く Nerd Font 系がここに来る。
   本文用フォントに glyph が無い範囲だけを別 face で描くための枠で、
   Windows Terminal や WezTerm が持つ fallback chain の末尾に相当する。 */
#define FONT_SYMBOL         9
#define FONT_MAX            10

struct FontSetParam
{
  LOGFONTW fs_logfont[FONT_MAX];
  int fs_use_backsl;
  int fs_line_spacing;
  int fs_recommend_size;
  int fs_size_pixel;
};

class FontSet
{
protected:
  void save_params (const FontSetParam &);
  void load_params (FontSetParam &);

  static const UINT fs_lang_id[];
  static const lisp *const fs_lang_key[];
  static const char *const fs_regent[];
  struct fontface {const wchar_t *disp, *print; int charset;};
  static const fontface fs_default_face[];
public:
  enum
    {
      backsl,
      newline,
      htab,
      fullspc1,
      fullspc2,
      sep,
      blank,
      wblank1,
      wblank2,
      halfspc,
      bold_backsl,
      fold_sep0,
      fold_sep1,
      fold_mark_sep0,
      fold_mark_sep1,
      max_bitmap
    };

protected:
  FontObject fs_font[FONT_MAX];
  SIZE fs_size;
  SIZE fs_cell;
  int fs_ascent;
  int fs_need_pad;
  int fs_line_spacing;
  int fs_use_backsl;
  int fs_line_width;
  int fs_recommend_size;
  int fs_size_pixel;

public:
  FontSet () {}
  ~FontSet () {}
  int create (const FontSetParam &);
  void init ();
  lisp make_alist () const;
  const bool update (FontSetParam &param, const lisp lfontset) const;
  const FontObject &font (int n) const {return fs_font[n];}
  const SIZE &size () const {return fs_size;}
  const SIZE &cell () const {return fs_cell;}
  int need_pad_p () const {return fs_need_pad;}
  int use_backsl_p () const {return fs_use_backsl;}
  int line_width () const {return fs_line_width;}
  int line_spacing () const {return fs_line_spacing;}
  int recommend_size_p () const {return fs_recommend_size;}
  int size_pixel_p () const {return fs_size_pixel;}

  static const char *regent (int n) {return fs_regent[n];}
  static const wchar_t *default_face (int n, int print)
    {return (!print || !fs_default_face[n].print
             ? fs_default_face[n].disp : fs_default_face[n].print);}
  static int default_charset (int n) {return fs_default_face[n].charset;}
  static UINT lang_id (int n) {return fs_lang_id[n];}
  static const lisp lang_key (int n) {return *fs_lang_key[n];}
  static const int lang_key_index (lisp llang)
    {
      for (int i = 0; i < FONT_MAX; i++)
        {
          if (lang_key (i) == llang)
            return i;
        }
      return -1;
    }
};


#endif /* _font_h_ */
