#include "stdafx.h"
#include "ed.h"
#include "ChooseFont.h"

ChooseFontP::ChooseFontP ()
{
  cf_hil = ImageList_LoadBitmap (app.hinst,
                                MAKEINTRESOURCE (IDB_TT),
                                18, 1, RGB (0, 0, 255));
}

ChooseFontP::~ChooseFontP ()
{
  if (cf_hil)
    ImageList_Destroy (cf_hil);
}

void
ChooseFontP::add_lang (HWND hwnd)
{
  for (int i = 0; i < FONT_MAX; i++)
    {
      wchar_t buf[128];
      *buf = 0;
      LoadStringW (app.hinst, FontSet::lang_id (i), buf, numberof (buf));
      int idx = SendDlgItemMessageW (hwnd, IDC_LANG, CB_ADDSTRING, 0, LPARAM (buf));
      SendDlgItemMessageW (hwnd, IDC_LANG, CB_SETITEMDATA, idx, i);
    }
}

/* face 名に needle が含まれるか (大小無視)。needle は空なら常に真。 */
static int
face_matches (const wchar_t *face, const wchar_t *needle)
{
  if (!needle || !*needle)
    return 1;
  for (const wchar_t *p = face; *p; p++)
    {
      const wchar_t *a = p, *b = needle;
      while (*b && towlower (*a) == towlower (*b))
        { a++; b++; }
      if (!*b)
        return 1;
    }
  return 0;
}

int CALLBACK
ChooseFontP::enum_font_name_proc (ENUMLOGFONTW *elf, NEWTEXTMETRIC *, int type, LPARAM lparam)
{
  if (*elf->elfLogFont.lfFaceName != L'@'
      && (elf->elfLogFont.lfPitchAndFamily & 3) == FIXED_PITCH)
    {
      const name_filter *nf = (const name_filter *)lparam;
      if (!face_matches (elf->elfLogFont.lfFaceName, nf->needle))
        return 1;
      HWND hwnd = nf->hwnd;
      if (SendMessageW (hwnd, LB_FINDSTRINGEXACT, WPARAM (-1), LPARAM (elf->elfLogFont.lfFaceName)) == LB_ERR)
        {
          int i = SendMessageW (hwnd, LB_ADDSTRING, 0, LPARAM (elf->elfLogFont.lfFaceName));
          SendMessageW (hwnd, LB_SETITEMDATA, i, (elf->elfLogFont.lfCharSet << 8) | type);
        }
    }
  return 1;
}

void
ChooseFontP::add_font_name (HWND hwnd, HDC hdc)
{
  wchar_t needle[128];
  if (!GetDlgItemTextW (hwnd, IDC_FONT_FILTER, needle, numberof (needle)))
    *needle = 0;
  name_filter nf;
  nf.hwnd = GetDlgItem (hwnd, IDC_NAMELIST);
  nf.needle = needle;
  EnumFontFamiliesExW (hdc, (LPLOGFONTW)0, FONTENUMPROCW (enum_font_name_proc),
                       LPARAM (&nf), 0);
}

/* 絞り込みを変えたら一覧を作り直す。選んでいた face が残っていれば選択を
   維持し、消えたら先頭にする (選択が消えたままだとサンプルが固まる)。 */
void
ChooseFontP::refill_font_name (HWND hwnd)
{
  wchar_t cur[LF_FACESIZE];
  *cur = 0;
  int i = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETCURSEL, 0, 0);
  if (i != LB_ERR)
    SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETTEXT, i, LPARAM (cur));

  SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_RESETCONTENT, 0, 0);
  HDC hdc = GetDC (hwnd);
  add_font_name (hwnd, hdc);
  ReleaseDC (hwnd, hdc);

  int j = LB_ERR;
  if (*cur)
    j = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_FINDSTRINGEXACT,
                            WPARAM (-1), LPARAM (cur));
  if (j == LB_ERR)
    j = 0;
  SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_SETCURSEL, j, 0);
  notify_font_name (hwnd, LBN_SELCHANGE);
}

void
ChooseFontP::notify_font_filter (HWND hwnd, int code)
{
  if (code == EN_CHANGE)
    refill_font_name (hwnd);
}

int CALLBACK
ChooseFontP::enum_font_size_proc (ENUMLOGFONTW *elf, NEWTEXTMETRIC *, int type, LPARAM lparam)
{
  HWND hwnd = ((xdpi *)lparam)->hwnd;
  int dpi = ((xdpi *)lparam)->dpi;
  int pixel = ((xdpi *)lparam)->pixel;
  wchar_t b[16];
  if (type & TRUETYPE_FONTTYPE)
    {
      if (!pixel)
        {
          static const int tt[] =
            {6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 26, 28, 36,};
          if (SendMessageW (hwnd, LB_FINDSTRINGEXACT, WPARAM (-1), LPARAM (L"  6")) == LB_ERR)
            for (int i = 0; i < numberof (tt); i++)
              {
                wsprintfW (b, L"%3d", tt[i]);
                SendMessageW (hwnd, LB_ADDSTRING, 0, LPARAM (b));
              }
        }
      else
        {
          if (SendMessageW (hwnd, LB_FINDSTRINGEXACT, WPARAM (-1), LPARAM (L"  8")) == LB_ERR)
            for (int i = FONT_SIZE_MIN_PIXEL; i <= FONT_SIZE_MAX_PIXEL; i++)
              {
                wsprintfW (b, L"%3d", i);
                SendMessageW (hwnd, LB_ADDSTRING, 0, LPARAM (b));
              }
        }
    }
  else
    {
      wsprintfW (b, L"%3d", (pixel ? elf->elfLogFont.lfHeight
                          : MulDiv (elf->elfLogFont.lfHeight, 72, dpi)));
      if (SendMessageW (hwnd, LB_FINDSTRINGEXACT,
                        WPARAM (-1), LPARAM (b)) == LB_ERR)
        SendMessageW (hwnd, LB_ADDSTRING, 0, LPARAM (b));
    }
  return 1;
}

void
ChooseFontP::add_font_size (HWND hwnd, int i)
{
  wchar_t face[LF_FACESIZE];
  if (SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETTEXT, i, LPARAM (face)) == LB_ERR)
    return;
  SendDlgItemMessageW (hwnd, IDC_SIZELIST, WM_SETREDRAW, 0, 0);
  SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_RESETCONTENT, 0, 0);

  xdpi x;
  x.hwnd = GetDlgItem (hwnd, IDC_SIZELIST);
  x.dpi = cf_dpi;
  x.pixel = cf_param.fs_size_pixel;

  HDC hdc = GetDC (hwnd);
  EnumFontFamiliesW (hdc, face, FONTENUMPROCW (enum_font_size_proc), LPARAM (&x));
  ReleaseDC (hwnd, hdc);

  SendDlgItemMessageW (hwnd, IDC_SIZELIST, WM_SETREDRAW, 1, 0);
  InvalidateRect (GetDlgItem (hwnd, IDC_SIZELIST), 0, 0);
}

void
ChooseFontP::change_font_size (HWND hwnd, int size)
{
  int i = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETCURSEL, 0, 0);
  if (i == LB_ERR)
    return;

  add_font_size (hwnd, i);

  struct {int index, point;} min, max;
  min.index = max.index = -1;

  wchar_t b[16];
  int n = SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETCOUNT, 0, 0);
  for (i = 0; i < n; i++)
    if (SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETTEXT, i, LPARAM (b)) != LB_ERR)
      {
        int x = _wtoi (b);
        if (x <= size && (min.index == -1 || x > min.point))
          {
            min.index = i;
            min.point = x;
          }
        if (x >= size && (max.index == -1 || x < max.point))
          {
            max.index = i;
            max.point = x;
          }
      }

  SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_SETCURSEL,
                      ((min.index == -1 && max.index == -1)
                       ? 0
                       : (min.index == -1
                          ? max.index
                          : (max.index == -1
                             ? min.index
                             : (size - min.point <= max.point - size
                                ? min.index : max.index)))),
                      0);

  notify_font_size (hwnd, LBN_SELCHANGE);
}

void
ChooseFontP::notify_lang (HWND hwnd, int code)
{
  if (code != CBN_SELCHANGE)
    return;
  int i = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETCURSEL, 0, 0);
  if (i == LB_ERR)
    return;
  i = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETITEMDATA, i, 0);
  if (i < 0 || i >= FONT_MAX)
    return;

  int j = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_FINDSTRINGEXACT,
                              WPARAM (-1), LPARAM (cf_param.fs_logfont[i].lfFaceName));
  if (j == LB_ERR)
    j = 0;
  SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_SETCURSEL, j, 0);

  change_font_size (hwnd,
                    (cf_param.fs_size_pixel
                     ? cf_param.fs_logfont[i].lfHeight
                     : MulDiv (cf_param.fs_logfont[i].lfHeight, 72, cf_dpi)));
}

void
ChooseFontP::notify_font_name (HWND hwnd, int code)
{
  if (code != LBN_SELCHANGE)
    return;
  int i = SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETCURSEL, 0, 0);
  if (i == LB_ERR)
    return;
  wchar_t b[16];
  if (SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETTEXT, i, LPARAM (b)) == LB_ERR)
    return;
  change_font_size (hwnd, _wtoi (b));
}

void
ChooseFontP::notify_font_size (HWND hwnd, int code)
{
  if (code != LBN_SELCHANGE)
    return;

  int lang = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETCURSEL, 0, 0);
  if (lang == LB_ERR)
    return;
  lang = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETITEMDATA, lang, 0);
  if (lang < 0 || lang >= FONT_MAX)
    return;

  int i = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETCURSEL, 0, 0);
  if (i == LB_ERR)
    return;
  wchar_t wname[LF_FACESIZE];
  if (SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETTEXT, i, LPARAM (wname)) == LB_ERR)
    return;

  int j = SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETCURSEL, 0, 0);
  if (j == LB_ERR)
    return;
  wchar_t b[16];
  if (SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETTEXT, j, LPARAM (b)) == LB_ERR)
    return;

  BYTE charset = BYTE (SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETITEMDATA, i, 0) >> 8);
  LOGFONTW lfw;
  bzero (&lfw, sizeof lfw);
  lfw.lfHeight = cf_param.fs_size_pixel ? _wtoi (b) : MulDiv (_wtoi (b), cf_dpi, 72);
  lfw.lfCharSet = charset;
  wcscpy (lfw.lfFaceName, wname);

  cf_param.fs_logfont[lang] = lfw;

  HFONT hfont = CreateFontIndirectW (&lfw);
  HFONT hfdlg = HFONT (SendMessage (hwnd, WM_GETFONT, 0, 0));
  HFONT hfctl = HFONT (SendDlgItemMessage (hwnd, IDC_SAMPLE, WM_GETFONT, 0, 0));
  SendDlgItemMessage (hwnd, IDC_SAMPLE, WM_SETFONT, WPARAM (hfont), MAKELPARAM (0, 0));
  if (hfctl != hfdlg)
    DeleteObject (hfctl);
  InvalidateRect (GetDlgItem (hwnd, IDC_SAMPLE), 0, 0);
}

void
ChooseFontP::notify_size_pixel (HWND hwnd, int code)
{
  if (code != BN_CLICKED)
    return;
  int i = SendDlgItemMessage (hwnd, IDC_SIZE_PIXEL, BM_GETCHECK, 0, 0);
  if (i != cf_param.fs_size_pixel)
    {
      cf_param.fs_size_pixel = i;

      int i = SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETCURSEL, 0, 0);
      if (i == LB_ERR)
        return;
      wchar_t b[16];
      if (SendDlgItemMessageW (hwnd, IDC_SIZELIST, LB_GETTEXT, i, LPARAM (b)) == LB_ERR)
        return;
      int sz = _wtoi (b);
      if (cf_param.fs_size_pixel)
        sz = MulDiv (sz, cf_dpi, 72);
      else
        sz = MulDiv (sz, 72, cf_dpi);
      change_font_size (hwnd, sz);
    }
}

void
ChooseFontP::draw_font_list (HWND, DRAWITEMSTRUCT *dis)
{
  COLORREF ofg, obg;

  if (dis->itemState & ODS_SELECTED)
    {
      ofg = SetTextColor (dis->hDC, sysdep.highlight_text);
      obg = SetBkColor (dis->hDC, sysdep.highlight);
    }
  else
    {
      ofg = SetTextColor (dis->hDC, sysdep.window_text);
      obg = SetBkColor (dis->hDC, sysdep.window);
    }

  const RECT &r = dis->rcItem;
  if (dis->itemID != UINT (-1))
    {
      wchar_t wb[LF_FACESIZE];
      *wb = 0;
      SendMessageW (dis->hwndItem, LB_GETTEXT, dis->itemID, LPARAM (wb));

      SIZE size;
      GetTextExtentPoint32W (dis->hDC, L"0", 1, &size);

      int wl = wcslen (wb);
      ExtTextOutW (dis->hDC, r.left + 18, (r.top + r.bottom - size.cy) / 2,
                   ETO_OPAQUE, &r, wb, wl, 0);

      if (dis->itemData & TRUETYPE_FONTTYPE)
        ImageList_Draw (cf_hil, 0, dis->hDC,
                        r.left, (r.top + r.bottom - 12) / 2, ILD_TRANSPARENT);
    }

  if (dis->itemState & ODS_FOCUS)
    DrawFocusRect (dis->hDC, &r);
  SetTextColor (dis->hDC, ofg);
  SetBkColor (dis->hDC, obg);
}

static const struct {BYTE charset; const char *string;} samples[] =
{
  {0, "AaBbCcXxYyZz"},
  {SHIFTJIS_CHARSET, "Aa\x82\xa0\x82\x9f\x83\x41\x83\x40\x88\x9f\x89\x46"},
  {CHINESEBIG5_CHARSET, "Aa\xa4\x40\xa4\x41\xc9\x40\xc9\x41"},
  {GB2312_CHARSET, "AaBb\xb0\xa1\xb0\xa2"},
  {HANGEUL_CHARSET, "Aa\xb0\xa1\xb0\xa2\xca\xa1\xca\xa2"},
  {HEBREW_CHARSET, "AaBb\xe0\xe1\xf9\xfa"},
  {ARABIC_CHARSET, "AaBb\xc7\xc8\xe7\xe8"},
  {GREEK_CHARSET, "AaBb\xc1\xe1\xc2\xe2"},
  {TURKISH_CHARSET, "AaBb\xc0\xe0\xde\xfe\xdf"},
  {RUSSIAN_CHARSET, "AaBb\xc0\xe0\xdf\xff"},
  {BALTIC_CHARSET, "AaBb\xc0\xe0\xdd\xfd"},
};

/* 記号スロットの見本。Nerd Font の各出自から 1 つずつ拾ってある。
   左から powerline の三角、git のブランチ、フォルダ (Seti-UI)、git
   (Devicons)、アカウント (Codicons)、家 (Font Awesome)、Tux (Font Logos)。 */
static const wchar_t nerd_sample[] =
  L"\ue0b0\ue0a0\ue5ff\ue702\uea60\uf015\uf17c";

/* face に glyph がいくつ入っているか数える。GGI_MARK_NONEXISTING_GLYPHS を
   付けると、無い文字は 0xffff で返る。豆腐を見れば分かることではあるが、
   数で言われた方が早い。 */
static int
count_glyphs (HDC hdc, const wchar_t *str, int len)
{
  WORD gi[32];
  if (len > int (numberof (gi)))
    len = numberof (gi);
  if (GetGlyphIndicesW (hdc, str, len, gi, GGI_MARK_NONEXISTING_GLYPHS) == GDI_ERROR)
    return -1;
  int n = 0;
  for (int i = 0; i < len; i++)
    if (gi[i] != 0xffff)
      n++;
  return n;
}

/* IDC_LANG が今どのスロットを指しているか。分からなければ -1。 */
static int
current_lang (HWND hwnd)
{
  int i = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETCURSEL, 0, 0);
  if (i == CB_ERR)
    return -1;
  i = SendDlgItemMessageW (hwnd, IDC_LANG, CB_GETITEMDATA, i, 0);
  return i >= 0 && i < FONT_MAX ? i : -1;
}

void
ChooseFontP::draw_sample (HWND hwnd, DRAWITEMSTRUCT *dis)
{
  const char *sample = samples[0].string;
  BYTE charset = 0;
  int i = SendDlgItemMessageW (hwnd, IDC_NAMELIST, LB_GETCURSEL, 0, 0);
  if (i != LB_ERR)
    {
      charset = BYTE (SendDlgItemMessageW (hwnd, IDC_NAMELIST,
                                               LB_GETITEMDATA, i, 0) >> 8);
      for (int i = 0; i < numberof (samples); i++)
        if (charset == samples[i].charset)
          {
            sample = samples[i].string;
            break;
          }
    }

  // Determine code page from charset for proper conversion
  CHARSETINFO ci;
  UINT cp = 1252;
  if (TranslateCharsetInfo ((DWORD *)(DWORD_PTR)charset, &ci, TCI_SRCCHARSET))
    cp = ci.ciACP;

  HFONT hf = HFONT (SendMessage (dis->hwndItem, WM_GETFONT, 0, 0));
  HGDIOBJ of = SelectObject (dis->hDC, hf);
  COLORREF ofg = SetTextColor (dis->hDC, cf_fg);
  COLORREF obg = SetBkColor (dis->hDC, cf_bg);
  wchar_t wsample[64];
  int wl;
  if (current_lang (hwnd) == FONT_SYMBOL)
    {
      /* 記号スロットは code page を通せない (PUA に対応する多バイト表現が
         無い) ので、見本を wide のまま置く。 */
      int n = numberof (nerd_sample) - 1;
      wcscpy (wsample, nerd_sample);
      wl = n;
      int have = count_glyphs (dis->hDC, nerd_sample, n);
      if (have >= 0 && have < n)
        wl += swprintf (wsample + n, numberof (wsample) - n, L"   %d/%d", have, n);
    }
  else
    wl = MultiByteToWideChar (cp, 0, sample, -1, wsample, 64) - 1;
  SIZE size = {0};
  GetTextExtentPoint32W (dis->hDC, wsample, wl, &size);
  const RECT &r = dis->rcItem;
  ExtTextOutW (dis->hDC, (r.left + r.right - size.cx) / 2,
               (r.top + r.bottom - size.cy) / 2,
               ETO_CLIPPED | ETO_OPAQUE, &r, wsample, wl, 0);

  SetTextColor (dis->hDC, ofg);
  SetBkColor (dis->hDC, obg);
  SelectObject (dis->hDC, of);

  paint_button_on (dis->hDC, r);
}

int
ChooseFontP::draw_item (HWND hwnd, int id, DRAWITEMSTRUCT *dis)
{
  switch (id)
    {
    case IDC_NAMELIST:
      draw_font_list (hwnd, dis);
      return 1;

    case IDC_SAMPLE:
      draw_sample (hwnd, dis);
      return 1;

    default:
      return 0;
    }
}

void
ChooseFontP::init_dialog (HWND hwnd)
{
  add_lang (hwnd);
  SendDlgItemMessageW (hwnd, IDC_LANG, CB_SETCURSEL, 0, 0);

  HDC hdc = GetDC (hwnd);
  cf_dpi = GetDeviceCaps (hdc, LOGPIXELSY);
  add_font_name (hwnd, hdc);
  ReleaseDC (hwnd, hdc);

  SendDlgItemMessage (hwnd, IDC_SIZE_PIXEL, BM_SETCHECK,
                      cf_param.fs_size_pixel ? 1 : 0, 0);

  notify_lang (hwnd, LBN_SELCHANGE);
}

int
ChooseFontP::do_command (HWND hwnd, int id, int code)
{
  switch (id)
    {
    case IDC_LANG:
      notify_lang (hwnd, code);
      return 1;

    case IDC_NAMELIST:
      notify_font_name (hwnd, code);
      return 1;

    case IDC_SIZELIST:
      notify_font_size (hwnd, code);
      return 1;

    case IDC_SIZE_PIXEL:
      notify_size_pixel (hwnd, code);
      return 1;

    case IDC_FONT_FILTER:
      notify_font_filter (hwnd, code);
      return 1;

    default:
      return 0;
    }
}

void
ChooseFontP::do_destroy (HWND hwnd)
{
  HFONT hfdlg = HFONT (SendMessage (hwnd, WM_GETFONT, 0, 0));
  HFONT hfctl = HFONT (SendDlgItemMessage (hwnd, IDC_SAMPLE, WM_GETFONT, 0, 0));
  if (hfctl != hfdlg)
    DeleteObject (hfctl);
}

void
ChooseFontP::set_color (HWND hwnd, COLORREF fg, COLORREF bg)
{
  cf_fg = fg;
  cf_bg = bg;
  InvalidateRect (GetDlgItem (hwnd, IDC_SAMPLE), 0, 0);
}
