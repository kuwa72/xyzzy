#include "stdafx.h"
#include "ed.h"
#include "conf.h"
#include "font-metrics.h"

const UINT FontSet::fs_lang_id[] =
{
  IDS_LANG_ASCII,
  IDS_LANG_JAPANESE,
  IDS_LANG_LATIN,
  IDS_LANG_CYRILLIC,
  IDS_LANG_GREEK,
  IDS_LANG_CN_SIMPLIFIED,
  IDS_LANG_CN_TRADITIONAL,
  IDS_LANG_KSC5601,
  IDS_LANG_GEORGIAN,
  IDS_LANG_SYMBOL,
};

const lisp *const FontSet::fs_lang_key[] =
{
  &Kascii,
  &Kjapanese,
  &Klatin,
  &Kcyrillic,
  &Kgreek,
  &Kcn_simplified,
  &Kcn_traditional,
  &Kksc5601,
  &Kgeorgian,
  &Ksymbol,
};

const char *const FontSet::fs_regent[] =
{
  "Ascii",
  "Japanese",
  "Latin",
  "Cyrillic",
  "Greek",
  "GB2312",
  "BIG5",
  "KSC5601",
  "Georgian",
  "Symbol",
};

const FontSet::fontface FontSet::fs_default_face[] =
{
  {L"FixedSys", L"MS Gothic", SHIFTJIS_CHARSET},
  {L"FixedSys", L"MS Gothic", SHIFTJIS_CHARSET},
  {L"Courier New"},
  {L"Courier New"},
  {L"Courier New"},
  {L"MS Hei", 0, GB2312_CHARSET},
  {L"MingLiu", 0, CHINESEBIG5_CHARSET},
  {L"GulimChe", 0, HANGEUL_CHARSET},
  {L"BPG Courier New U"},
  /* Nerd Font の記号だけを収めた配布物。パッチ済みの本文フォントを使って
     いる人はそちらの face 名を入れればよく、どちらも無い場合は
     load_params が ASCII の face に落とす。 */
  {L"Symbols Nerd Font Mono"},
};

int
FontObject::create (const wchar_t *face, int h, int charset)
{
  LOGFONTW lf;
  memset (&lf, 0, sizeof lf);
  wcsncpy (lf.lfFaceName, face, LF_FACESIZE - 1);
  lf.lfFaceName[LF_FACESIZE - 1] = 0;
  lf.lfHeight = h;
  lf.lfCharSet = charset;
  lf.lfPitchAndFamily = FIXED_PITCH;
  return create (lf);
}

int
FontObject::create (const LOGFONTW &lf)
{
  HFONT h = CreateFontIndirectW (&lf);
  if (!h)
    return 0;
  if (fo_hfont)
    DeleteObject (fo_hfont);
  fo_hfont = h;
  GetObjectW (h, sizeof fo_logfont, &fo_logfont);
  return 1;
}

void
FontObject::get_metrics ()
{
  SIZE ex1, ex2;

  HDC hdc = GetDC (0);
  get_metrics (hdc, ex1, ex2);
  ReleaseDC (0, hdc);
}

void
FontObject::get_metrics (HDC hdc, SIZE &ex1, SIZE &ex2)
{
  HGDIOBJ of = SelectObject (hdc, fo_hfont);
  TEXTMETRICW tm;
  GetTextMetricsW (hdc, &tm);
  fo_size.cx = tm.tmAveCharWidth;
  fo_size.cy = tm.tmAscent + tm.tmDescent;
  fo_ascent = tm.tmAscent;
  GetTextExtentPoint32W (hdc, L"A", 1, &ex1);
  GetTextExtentPoint32W (hdc, L"\x3042", 1, &ex2);  // U+3042 あ
  SelectObject (hdc, of);
}

// issue #13 step5c: Win32FontMetrics — the GDI implementation of the neutral
// FontMetrics interface. It mirrors FontObject::get_metrics(HDC,...) exactly
// (same screen DC, same GetTextMetricsW / GetTextExtentPoint32W probes) so the
// measurement is pixel-equivalent; the only difference is that it owns the
// font/DC lifetime internally and takes a LOGFONTW rather than a pre-selected
// hfont. Steps 5d/5e route FontSet::create and font.h's dpi helpers through it.
struct Win32FontMetrics : public FontMetrics
{
  FontMetricsResult measure (const LOGFONTW &lf) override
  {
    FontMetricsResult r;
    memset (&r, 0, sizeof r);
    HFONT hf = CreateFontIndirectW (&lf);
    if (!hf)
      return r;
    HDC hdc = GetDC (0);
    HGDIOBJ of = SelectObject (hdc, hf);
    TEXTMETRICW tm;
    GetTextMetricsW (hdc, &tm);
    r.ave_char_width = tm.tmAveCharWidth;
    r.ascent = tm.tmAscent;
    r.descent = tm.tmDescent;
    SIZE ex;
    GetTextExtentPoint32W (hdc, L"A", 1, &ex);
    r.ascii_width = ex.cx;
    GetTextExtentPoint32W (hdc, L"\x3042", 1, &ex);  // U+3042 あ
    r.fullwidth = ex.cx;
    SelectObject (hdc, of);
    ReleaseDC (0, hdc);
    DeleteObject (hf);
    return r;
  }

  int dpi_y () const override
  {
    HDC hdc = GetDC (0);
    int d = GetDeviceCaps (hdc, LOGPIXELSY);
    ReleaseDC (0, hdc);
    return d;
  }
};

// issue #13 step5d: store metrics measured through FontMetrics, replicating
// exactly the side effect get_metrics(HDC,...) had on the FontObject.
void
FontObject::set_metrics (const FontMetricsResult &r)
{
  fo_size.cx = r.ave_char_width;
  fo_size.cy = r.ascent + r.descent;
  fo_ascent = r.ascent;
}

// issue #13 step5e: dpi and the point<->pixel conversions live in the frontend
// now (moved out of font.h, a core header reachable via ed.h). dpi() goes
// through the neutral FontMetrics interface; MulDiv stays here in the Win32
// source rather than leaking into core.
int
FontObject::dpi ()
{
  Win32FontMetrics fm;
  return fm.dpi_y ();
}

int
FontObject::pixel_to_point (int pixel)
{
  return MulDiv (pixel, 72, dpi ());
}

int
FontObject::point_to_pixel (int point)
{
  return MulDiv (point, dpi (), 72);
}

void
FontObject::calc_offset (const SIZE &sz)
{
  fo_offset.x = (sz.cx - fo_size.cx) / 2;
  fo_offset.y = (sz.cy - fo_size.cy) / 2;
}

const bool
FontObject::update (LOGFONTW &lf, const lisp keys, const bool recommend_size_p)
{
  check_cons (keys);
  lisp lface = find_keyword (Kface, keys);
  lisp lsize = find_keyword (Ksize, keys);

  bool update = false;
  if (lsize != Qnil && !recommend_size_p)
    {
      int size = fixnum_value (lsize);
      int old_size;
      int pixel;
      if (find_keyword_bool (Ksize_pixel_p, keys))
        {
          old_size =lf.lfHeight;
          pixel = size;
        }
      else
        {
          old_size = FontObject::pixel_to_point (lf.lfHeight);
          pixel = FontObject::point_to_pixel (size);
        }
      if (pixel < FONT_SIZE_MIN_PIXEL || pixel > FONT_SIZE_MAX_PIXEL)
        FErange_error (lsize);
      if (old_size != size)
        {
          lf.lfHeight = pixel;
          lf.lfWidth = 0;
          update = true;
        }
    }

  if (lface != Qnil)
    {
      check_string (lface);
      int flen = xstring_length (lface);
      const ucs4_t *fdata = xstring_contents (lface);
      bool face_match = ((size_t)flen == wcslen (lf.lfFaceName));
      for (int i = 0; face_match && i < flen; i++)
        if (lf.lfFaceName[i] != wchar_t (fdata[i]))
          face_match = false;
      if (!face_match)
        {
          int n = min (flen, LF_FACESIZE - 1);
          for (int i = 0; i < n; i++) lf.lfFaceName[i] = wchar_t (fdata[i]);
          lf.lfFaceName[n] = 0;
          update = true;
        }
    }

  return update;
}

void
FontSet::paint_newline_bitmap (HDC hdc)
{
  int h = fs_size.cy / 2;
  int y0 = fs_size.cy - 2;
  int ox = fs_cell.cx * newline + 2;
  int y;
  for (y = 0; y < h; y++)
    SetPixel (hdc, ox, y0 - y, RGB (0, 0, 0));
  for (y = 0; y < h / 2 - 1; y++)
    SetPixel (hdc, ox + y, y0 - y, RGB (0, 0, 0));
  int w, x;
  for (w = (y + 1) / 2, x = y; x >= w; x--)
    SetPixel (hdc, ox + x, y0 - y, RGB (0, 0, 0));
  for (x++; y < h; y++)
    SetPixel (hdc, ox + x, y0 - y, RGB (0, 0, 0));
  for (y--; x >= 0; x--)
    SetPixel (hdc, ox + x, y0 - y, RGB (0, 0, 0));
}

void
FontSet::paint_backsl_bitmap (HDC hdc)
{
  HGDIOBJ of = SelectObject (hdc, fs_font[FONT_ASCII]);

  TextOutW (hdc, fs_cell.cx * backsl, 0, L"/", 1);
  StretchBlt (hdc, fs_cell.cx * backsl, 0, fs_cell.cx, fs_cell.cy,
              hdc, fs_cell.cx * (backsl + 1) - 1, 0, -fs_cell.cx, fs_cell.cy,
              SRCCOPY);

  TextOutW (hdc, fs_cell.cx * bold_backsl, 0, L"/", 1);
  int omode = SetBkMode (hdc, TRANSPARENT);
  TextOutW (hdc, fs_cell.cx * bold_backsl + 1, 0, L"/", 1);
  SetBkMode (hdc, omode);
  StretchBlt (hdc, fs_cell.cx * bold_backsl, 0, fs_cell.cx, fs_cell.cy,
              hdc, fs_cell.cx * (bold_backsl + 1) - 1, 0, -fs_cell.cx, fs_cell.cy,
              SRCCOPY);

  SelectObject (hdc, of);
}

void
FontSet::paint_sep_bitmap (HDC hdc)
{
  int x = fs_cell.cx * sep + fs_cell.cx / 4;
  MoveToEx (hdc, x, 0, 0);
  LineTo (hdc, x, fs_cell.cy);
}

void
FontSet::paint_tab_bitmap (HDC hdc)
{
  int h = fs_ascent / 4;
  int x0 = fs_cell.cx * htab + (fs_cell.cx - h) / 2;
  int y0 = fs_ascent - 1;
  MoveToEx (hdc, x0, y0, 0);
  LineTo (hdc, x0 + h, y0);
  LineTo (hdc, x0, y0 - h);
  LineTo (hdc, x0, y0);
}

void
FontSet::paint_fullspc_bitmap (HDC hdc)
{
  int h = fs_ascent / 4;
  if (!h)
    h = 2;
  else if (h & 1)
    h++;
  int w = fs_size.cx * 2 * 3 / 4;
  if (!w)
    w = 2;
  else if (w & 1)
    w++;

  int x1 = fs_cell.cx * fullspc1 + (fs_size.cx * 2 - w) / 2;
  int x2 = x1 + w;
  int y1 = fs_ascent - 1;
  int y2 = fs_ascent - h;

  for (int x = x1; x < x2; x += 2)
    {
      SetPixel (hdc, x, y1, RGB (0, 0, 0));
      SetPixel (hdc, x + 1, y2, RGB (0, 0, 0));
    }
  x2--;
  for (int y = y1 - 2; y > y2; y -= 2)
    {
      SetPixel (hdc, x1, y, RGB (0, 0, 0));
      SetPixel (hdc, x2, y + 1, RGB (0, 0, 0));
    }
}

void
FontSet::paint_halfspc_bitmap (HDC hdc)
{
  int h = fs_size.cy / 5;
  if (h < 3)
    h = 3;

  MoveToEx (hdc, fs_size.cx * halfspc + 1, fs_ascent - h, 0);
  LineTo (hdc, fs_size.cx * halfspc + 1, fs_ascent - 1);
  LineTo (hdc, fs_size.cx * (halfspc + 1) - 2, fs_ascent - 1);
  LineTo (hdc, fs_size.cx * (halfspc + 1) - 2, fs_ascent - h - 1);
}

void
FontSet::paint_blank (HDC hdc)
{
  if (fs_size.cx > 2 && fs_ascent > 2)
    {
      PatBlt (hdc, fs_cell.cx * blank + 1, 1,
              fs_size.cx - 2, fs_ascent - 2, BLACKNESS);
      PatBlt (hdc, fs_cell.cx * wblank1 + 1, 1,
              fs_size.cx * 2 - 2, fs_ascent - 2, BLACKNESS);
    }
}

void
FontSet::paint_fold_bitmap (HDC hdc)
{
  int s0 = fs_cell.cx * fold_sep0;
  int s1 = fs_cell.cx * fold_sep1;
  int m0 = fs_cell.cx * fold_mark_sep0;
  int m1 = fs_cell.cx * fold_mark_sep1;

  PatBlt (hdc, s0, 0, fs_cell.cx, fs_cell.cy, WHITENESS);
  PatBlt (hdc, s1, 0, fs_cell.cx, fs_cell.cy, WHITENESS);
  PatBlt (hdc, m0, 0, fs_cell.cx, fs_cell.cy, WHITENESS);
  PatBlt (hdc, m1, 0, fs_cell.cx, fs_cell.cy, WHITENESS);

  const FontObject &f = fs_font[FONT_ASCII];
  HGDIOBJ of = SelectObject (hdc, f);
  wchar_t wc = L'<';
  ExtTextOutW (hdc, m0 + f.offset ().x, f.offset ().y, 0, 0, &wc, 1, 0);
  ExtTextOutW (hdc, m1 + f.offset ().x, f.offset ().y, 0, 0, &wc, 1, 0);
  SelectObject (hdc, of);

  for (int y = 0; y < fs_cell.cy; y += 2)
    {
      SetPixel (hdc, s0, y, RGB (0, 0, 0));
      SetPixel (hdc, m0, y, RGB (0, 0, 0));
    }
  for (int y = fs_cell.cy & 1; y < fs_cell.cy; y += 2)
    {
      SetPixel (hdc, s1, y, RGB (0, 0, 0));
      SetPixel (hdc, m1, y, RGB (0, 0, 0));
    }
}

void
FontSet::create_bitmap ()
{
  if (fs_hbm)
    DeleteObject (fs_hbm);
  fs_hbm = CreateBitmap (fs_cell.cx * max_bitmap, fs_cell.cy, 1, 1, 0);
  HDC hdc = GetDC (0);
  HDC hdcmem = CreateCompatibleDC (hdc);
  ReleaseDC (0, hdc);
  HGDIOBJ obm = SelectObject (hdcmem, fs_hbm);
  HGDIOBJ open = SelectObject (hdcmem, CreatePen (PS_SOLID, 0, RGB (0, 0, 0)));
  PatBlt (hdcmem, 0, 0, fs_cell.cx * max_bitmap, fs_cell.cy, WHITENESS);
  paint_newline_bitmap (hdcmem);
  paint_backsl_bitmap (hdcmem);
  paint_sep_bitmap (hdcmem);
  paint_tab_bitmap (hdcmem);
  paint_fullspc_bitmap (hdcmem);
  paint_halfspc_bitmap (hdcmem);
  paint_blank (hdcmem);
  paint_fold_bitmap (hdcmem);
  DeleteObject (SelectObject (hdcmem, open));
  SelectObject (hdcmem, obm);
  DeleteDC (hdcmem);
}

// issue #13 step5d: create font `fo` from `lf` and measure it through the
// neutral FontMetrics interface, storing the result on the FontObject and
// recording the ascii/fullwidth advance widths in `ex` (cx only is read by
// create() below). Replaces the old create()+get_metrics(HDC) pair.
static void
measure_into (FontMetrics &fm, FontObject &fo, const LOGFONTW &lf, SIZE ex[2])
{
  fo.create (lf);
  FontMetricsResult r = fm.measure (lf);
  fo.set_metrics (r);
  ex[0].cx = r.ascii_width;
  ex[1].cx = r.fullwidth;
}

int
FontSet::create (const FontSetParam &param)
{
  /* ターミナルのフォント選択は「この code point のグリフを持っている
     フォント」を GetGlyphIndicesW で調べて覚えている。フォントが差し替わったら
     その答えは古いので捨てる (disp.cc)。 */
  {
    extern void invalidate_terminal_font_cache ();
    invalidate_terminal_font_cache ();
  }

  SIZE ex[FONT_MAX][2] = {};
  Win32FontMetrics fm;

  fs_line_spacing = max (0, min (param.fs_line_spacing, 30));
  fs_use_backsl = param.fs_use_backsl;
  fs_recommend_size = param.fs_recommend_size;
  fs_size_pixel = param.fs_size_pixel;

  if (!fs_recommend_size)
    {
      for (int i = 0; i < FONT_MAX; i++)
        measure_into (fm, fs_font[i], param.fs_logfont[i], ex[i]);
    }
  else
    {
      measure_into (fm, fs_font[FONT_ASCII], param.fs_logfont[FONT_ASCII], ex[FONT_ASCII]);

      for (int i = 1; i < FONT_MAX; i++)
        for (int h = fs_font[FONT_ASCII].size ().cy; h > 0; h--)
          {
            LOGFONTW lf (param.fs_logfont[i]);
            lf.lfHeight = h;
            lf.lfWidth = 0;
            measure_into (fm, fs_font[i], lf, ex[i]);
            if (fs_font[i].size ().cx <= fs_font[FONT_ASCII].size ().cx)
              break;
          }
    }

  fs_size = fs_font[FONT_ASCII].size ();

  for (int i = 0; i < FONT_MAX; i++)
    if (fs_font[i].size ().cx > fs_size.cx)
      {
        LOGFONTW lf (param.fs_logfont[i]);
        lf.lfWidth = fs_size.cx;
        measure_into (fm, fs_font[i], lf, ex[i]);
      }

  fs_cell.cx = fs_size.cx;
  fs_cell.cy = fs_size.cy + fs_line_spacing;
  fs_ascent = fs_font[FONT_JP].ascent ();
  fs_line_width = fs_size.cy / 12;
  if (!fs_line_width)
    fs_line_width = 1;

  fs_need_pad = 0;
  for (int i = 0; i < FONT_MAX; i++)
    {
      fs_font[i].calc_offset (fs_size);
      if (fs_font[i].size ().cx != fs_size.cx
          || ex[i][0].cx * 2 != ex[i][0].cx)
        {
          fs_font[i].require_pad ();
          fs_need_pad = 1;
        }
    }

  create_bitmap ();
  save_params (param);
  return 1;
}

void
FontSet::save_params (const FontSetParam &param)
{
  for (int i = 0; i < FONT_MAX; i++)
    write_conf (cfgFont, regent (i), param.fs_logfont[i]);
  write_conf (cfgFont, cfgLineSpacing, param.fs_line_spacing);
  write_conf (cfgFont, cfgBackslash, param.fs_use_backsl);
  write_conf (cfgFont, cfgRecommendSize, param.fs_recommend_size);
  write_conf (cfgFont, cfgSizePixel, param.fs_size_pixel);
  flush_conf ();
}

static int CALLBACK
fix_charset_proc (ENUMLOGFONTW *elf, NEWTEXTMETRIC *, int type, LPARAM lparam)
{
  HDC hdc = GetDC (0);
  FontSetParam &param = *(FontSetParam *)lparam;
  if (*elf->elfLogFont.lfFaceName != L'@')
    for (int i = 0; i < FONT_MAX; i++)
      {
        if (font_exist_p (hdc, param.fs_logfont[i].lfFaceName, param.fs_logfont[i].lfCharSet))
          continue;
        if (!wcscmp (elf->elfLogFont.lfFaceName, param.fs_logfont[i].lfFaceName))
          param.fs_logfont[i].lfCharSet = elf->elfLogFont.lfCharSet;
      }
  ReleaseDC (0, hdc);
  return 1;
}

void
FontSet::load_params (FontSetParam &param)
{
  /* スロットを増やすときに、この 4 つのどれかを書き忘れるのが一番ありがちな
     間違いである。実際に fs_default_face だけ 1 行落として、添字 FONT_SYMBOL が
     配列の外を指し、MSVC ビルドが起動時にそのゴミを face 名として読んで
     Access violation で落ちた。数が合わなければコンパイルを止める。 */
  static_assert (numberof (fs_lang_id) == FONT_MAX,
                 "fs_lang_id の数が FONT_MAX と合っていない");
  static_assert (numberof (fs_lang_key) == FONT_MAX,
                 "fs_lang_key の数が FONT_MAX と合っていない");
  static_assert (numberof (fs_regent) == FONT_MAX,
                 "fs_regent の数が FONT_MAX と合っていない");
  static_assert (numberof (fs_default_face) == FONT_MAX,
                 "fs_default_face の数が FONT_MAX と合っていない");

  memset (&param, 0, sizeof param);

  if (!read_conf (cfgFont, cfgLineSpacing, param.fs_line_spacing))
    param.fs_line_spacing = 0;
  if (!read_conf (cfgFont, cfgBackslash, param.fs_use_backsl))
    param.fs_use_backsl = 0;
  if (!read_conf (cfgFont, cfgRecommendSize, param.fs_recommend_size))
    param.fs_recommend_size = 0;
  if (!read_conf (cfgFont, cfgSizePixel, param.fs_size_pixel))
    param.fs_size_pixel = 0;
  for (int i = 0; i < FONT_MAX; i++)
    if (!read_conf (cfgFont, regent (i), param.fs_logfont[i]))
      *param.fs_logfont[i].lfFaceName = 0;

  for (int i = 0; i < FONT_MAX; i++)
    {
      if (!*param.fs_logfont[i].lfFaceName)
        {
          wcsncpy (param.fs_logfont[i].lfFaceName, default_face (i, 0),
                   LF_FACESIZE - 1);
          param.fs_logfont[i].lfFaceName[LF_FACESIZE - 1] = 0;
          if (!i)
            {
              LOGFONTW lfw;
              GetObjectW (GetStockObject (SYSTEM_FIXED_FONT), sizeof lfw, &lfw);
              param.fs_logfont[0].lfHeight = lfw.lfHeight;
            }
          else
            param.fs_logfont[i].lfHeight = param.fs_logfont[0].lfHeight;
        }
      param.fs_logfont[i].lfPitchAndFamily &= ~3;
      param.fs_logfont[i].lfPitchAndFamily |= FIXED_PITCH;
    }

  HDC hdc = GetDC (0);
  EnumFontFamiliesExW (hdc, (LPLOGFONTW)0, FONTENUMPROCW (fix_charset_proc), LPARAM (&param), 0);

  /* 記号スロットの既定は Nerd Font の記号だけを収めた配布物だが、入って
     いない環境も多い。その場合は本文 (ASCII) と同じ face にしておく:
     パッチ済みの Nerd Font を本文に使っているならそれで正しく出るし、
     そうでなければ従来どおり豆腐になるだけで、以前と何も変わらない。
     Symbols Nerd Font Mono を入れる、あるいはフォント設定でこの枠に
     face を選べば、そこから先は記号だけ別 face で描かれる。 */
  if (!font_exist_p (hdc, param.fs_logfont[FONT_SYMBOL].lfFaceName,
                     param.fs_logfont[FONT_SYMBOL].lfCharSet))
    {
      wcscpy (param.fs_logfont[FONT_SYMBOL].lfFaceName,
              param.fs_logfont[FONT_ASCII].lfFaceName);
      param.fs_logfont[FONT_SYMBOL].lfCharSet = param.fs_logfont[FONT_ASCII].lfCharSet;
    }

  ReleaseDC (0, hdc);
}

void
FontSet::init ()
{
  FontSetParam param;
  load_params (param);
  create (param);
}

lisp
FontSet::make_alist () const
{
  lisp r = Qnil;
  for (int i = 0; i < FONT_MAX; i++)
    {
      LOGFONTW lf = font (i).logfont ();
      int size = lf.lfHeight;
      if (!size_pixel_p ())
        size = FontObject::pixel_to_point (size);
      r = xcons (make_list (FontSet::lang_key (i),
                            Kface, make_string ((const Char *)lf.lfFaceName, wcslen (lf.lfFaceName)),
                            Ksize, make_fixnum (size),
                            Ksize_pixel_p, boole (size_pixel_p ()),
                            0),
                 r);
    }

  return Fnreverse (r);
}

const bool
FontSet::update (FontSetParam &param, const lisp lfontset) const
{
  // Initialize FontSetParam by current setting.
  param.fs_use_backsl = use_backsl_p ();
  param.fs_line_spacing = line_spacing ();
  param.fs_recommend_size = recommend_size_p ();
  param.fs_size_pixel = size_pixel_p ();
  for (int i = 0; i < FONT_MAX; i++)
    param.fs_logfont[i] = font (i).logfont ();

  // Update FontSetParam.fs_logfont by lfontset;
  bool update = false;
  for (lisp x = lfontset; consp (x); x = xcdr (x))
    {
      check_cons (xcar (x));
      lisp llang = Fcaar (x);
      lisp keys = Fcdar (x);

      int n = FontSet::lang_key_index (llang);
      if (n < 0)
        FEsimple_error (Einvalid_charset, llang);

      if (FontObject::update (param.fs_logfont[n], keys, (llang != Kascii && recommend_size_p ())))
        update = true;
    }

  return update;
}

lisp
Fget_text_fontset ()
{
  return app.text_font.make_alist ();
}

lisp
Fset_text_fontset (lisp lfontset)
{
  check_cons (lfontset);

  FontSetParam param;
  if (!app.text_font.update (param, lfontset))
    return Qnil;

  Window::change_parameters (param);
  refresh_screen (0);

  return Qt;
}

int
get_font_height (HWND hwnd)
{
  HFONT hfont = HFONT (SendMessage (hwnd, WM_GETFONT, 0, 0));
  HDC hdc = GetDC (hwnd);
  HGDIOBJ ofont = SelectObject (hdc, hfont);
  TEXTMETRICW tm;
  GetTextMetricsW (hdc, &tm);
  SelectObject (hdc, ofont);
  ReleaseDC (hwnd, hdc);
  return tm.tmHeight;
}

static int CALLBACK
check_valid_font (const ENUMLOGFONTW *, const NEWTEXTMETRIC *,
                  DWORD, LPARAM lparam)
{
  *(bool *)lparam = true;
  return 0;
}

bool
font_exist_p (const HDC hdc, const wchar_t *face, BYTE charset)
{
  bool exists = false;

  LOGFONTW font;
  memset (&font, 0, sizeof font);
  font.lfCharSet = charset;
  wcsncpy (font.lfFaceName, face, LF_FACESIZE - 1);

  EnumFontFamiliesExW (hdc, &font,
                       FONTENUMPROCW (check_valid_font),
                       LPARAM (&exists), 0);

  return exists;
}
