#include "stdafx.h"
#include "ed.h"
#include "ed-hwnd.h"
#include "win32sysdep.h"
#include "Window.h"
#include "gdi-utils.h"
#include "conf.h"
#include "font-win32.h"
#include "ipc.h"
#include "wheel.h"
#include "painter-win32.h"
#include "term.h"
#include "modeline-painter.h"

#define RULER_HEIGHT 13
#define FRAME_WIDTH 2

int Window::w_hjump_columns = 8;
int Window::w_default_flags = (WF_LINE_NUMBER | WF_RULER | WF_NEWLINE | WF_MODE_LINE
                               | WF_VSCROLL_BAR | WF_EOF | WF_FOLD_MARK
                               | WF_INDENT_GUIDE);

#define TXF WCOLOR_TEXT
#define TXB WCOLOR_BACK
#define CXF WCOLOR_CTRL
#define K1F WCOLOR_KWD1
#define K2F WCOLOR_KWD2
#define K3F WCOLOR_KWD3
#define STF WCOLOR_STRING
#define CMF WCOLOR_COMMENT
#define TGF WCOLOR_TAG
#define GRF WCOLOR_GRAY
#define HIF WCOLOR_HIGHLIGHT_TEXT
#define HIB WCOLOR_HIGHLIGHT
#define BTF WCOLOR_BTNTEXT
#define BTB WCOLOR_BTNSHADOW
#define RVB WCOLOR_REVERSE
#define LNF WCOLOR_LINENUM

wcolor_index Window::forecolor_indexes[] =
{
//nrm ctl kw1 kw2 kw3 k1r k2r k3r -   -   -    -  lnm  str tag com   // 反転 選択 無効
  TXF,CXF,K1F,K2F,K3F,TXB,TXB,TXB,TXF,TXF,TXF,TXF,LNF,STF,TGF,CMF,  //   -    -    -
  GRF,GRF,GRF,GRF,GRF,TXB,TXB,TXB,GRF,GRF,GRF,GRF,LNF,GRF,GRF,GRF,  //   -    -    o
  HIF,CXF,HIF,HIF,HIF,HIF,HIF,HIF,HIF,HIF,HIF,HIF,LNF,HIF,HIF,HIF,  //   -    o    -
  TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   -    o    o
  TXB,CXF,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   o    -    -
  TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   o    -    o
  BTF,CXF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,BTF,  //   o    o    -
  TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   o    o    o
};

wcolor_index Window::backcolor_indexes[] =
{
//nrm ctl kw1 kw2 kw3 k1r k2r k3r -   -   -    -  lnm str tag com   // 反転 選択 無効
  TXB,TXB,TXB,TXB,TXB,K1F,K2F,K3F,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   -    -    -
  TXB,TXB,TXB,TXB,TXB,GRF,GRF,GRF,TXB,TXB,TXB,TXB,TXB,TXB,TXB,TXB,  //   -    -    o
  HIB,HIB,HIB,HIB,HIB,GRF,GRF,GRF,HIB,HIB,HIB,HIB,HIB,HIB,HIB,HIB,  //   -    o    -
  GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,  //   -    o    o
  RVB,RVB,RVB,RVB,RVB,RVB,RVB,RVB,RVB,RVB,RVB,RVB,LNF,RVB,RVB,RVB,  //   o    -    -
  GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,  //   o    -    o
  BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,BTB,  //   o    o    -
  GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,GRF,  //   o    o    o
};

COLORREF Window::default_colors[WCOLOR_MAX];
XCOLORREF Window::default_xcolors[USER_DEFINABLE_COLORS];
COLORREF Window::modeline_colors[2];
XCOLORREF Window::modeline_xcolors[2];

/* 「文字1〜15」の表 (w_textprop_forecolor / backcolor とその x 付き) の
   定義は src/core/textprop-colors.cc へ移した。端末フロントエンドにも
   同じ表が要るため (issue #98)。 */

const wcolor_index_name wcolor_index_names[] =
{
  {cfgTextColor, RGB (0, 0, 0), L"文字色"},
  {cfgBackColor, RGB (0xff, 0xff, 0xff), L"背景色"},
  {cfgCtlColor, RGB (0x80, 0x80, 0), L"制御文字"},
  {cfgSelectionTextColor, RGB (0xff, 0xff, 0xff), L"選択文字色"},
  {cfgSelectionBackColor, RGB (0, 0, 0), L"選択背景色"},
  {cfgKwdColor1, RGB (0, 0, 0xff), L"キーワード１"},
  {cfgKwdColor2, RGB (0, 0x40, 0), L"キーワード２"},
  {cfgKwdColor3, RGB (0x80, 0, 0x80), L"キーワード３"},
  {cfgStringColor, RGB (0, 0x40, 0), L"文字列"},
  {cfgCommentColor, RGB (0, 0x80, 0), L"コメント"},
  {cfgTagColor, RGB (0x40, 0x40, 0), L"タグ"},
  {cfgCursorColor, RGB (0x80, 0, 0x80), L"行カーソル"},
  {cfgCaretColor, RGB (0, 0, 0), L"キャレット"},
  {cfgImeCaretColor, RGB (0x80, 0, 0), L"IMEキャレット"},
  {cfgLinenum, RGB (0, 0, 0), L"行番号"},
  {cfgReverse, RGB (0, 0, 0), L"ニセ反転色"},
  {cfgUnselectedModeLineFg, RGB (0, 0, 0), L"モード行文字色"},
  {cfgUnselectedModeLineBg, RGB (0, 0, 0), L"モード行背景色"},

  {0, RGB (0, 0, 0), L"選択モード行文字色"},
  {0, RGB (0, 0, 0), L"選択モード行背景色"},
};

ModelineParam::ModelineParam ()
     : m_hfont (0)
{
}

ModelineParam::~ModelineParam ()
{
  if (m_hfont && m_hfont != HFONT (GetStockObject (SYSTEM_FONT)))
    DeleteObject (m_hfont);
}

void
ModelineParam::init (HFONT hf)
{
  if (!hf)
    m_hfont = HFONT (GetStockObject (SYSTEM_FONT));
  else
    {
      LOGFONT lf;
      GetObject (hf, sizeof lf, &lf);
      m_hfont = CreateFontIndirect (&lf);
    }
  TEXTMETRIC tm;
  HDC hdc = GetDC (0);
  HGDIOBJ of = SelectObject (hdc, m_hfont);
  GetTextMetrics (hdc, &tm);
  m_height = tm.tmExternalLeading + tm.tmHeight;
  m_exlead = tm.tmExternalLeading + 1;

  for (int i = 0; i < 22; i++)
    {
      SIZE size;
      GetTextExtentPoint32W (hdc, L"0000000000:0000000000", i, &size);
      m_exts[i] = size.cx;
    }
  SelectObject (hdc, of);
  ReleaseDC (0, hdc);
}

HWND g_status_window_hwnd;

StatusWindow::StatusWindow ()
     : sw_b (sw_buf)
{
  sw_last.l = 0;
  sw_last.textf = 0;
}

void
StatusWindow::restore ()
{
  SendMessage (g_status_window_hwnd, SB_SETTEXT, SBT_OWNERDRAW | 0, LPARAM (&sw_last));
  UpdateWindow (g_status_window_hwnd);
}

int
StatusWindow::text (const char *s)
{
  {
    WideStr ws (s);
    SendMessageW (g_status_window_hwnd, SB_SETTEXT, 0, LPARAM ((const wchar_t *)ws));
  }
  UpdateWindow (g_status_window_hwnd);
  sw_last.textf = 1;
  return sw_last.l;
}

int
StatusWindow::text (const wchar_t *s)
{
  SendMessageW (g_status_window_hwnd, SB_SETTEXT, 0, LPARAM (s));
  UpdateWindow (g_status_window_hwnd);
  sw_last.textf = 1;
  return sw_last.l;
}

void
StatusWindow::puts (const ucs4_t *b, int size)
{
  for (const ucs4_t *be = b + size; b < be; b++)
    putc (*b);
}

int
StatusWindow::putc (ucs4_t c)
{
  if (c == '\n')
    newline ();
  else
    {
      if (sw_b == sw_buf + TEXT_MAX)
        return 0;
      if (c == '\t')
        for (ucs2_t *const be = min (sw_b + 4, sw_buf + TEXT_MAX);
             sw_b < be; sw_b++)
          *sw_b = ' ';
      else if (c < ' ' || c == CC_DEL)
        {
          *sw_b++ = '^';
          if (sw_b == sw_buf + TEXT_MAX)
            return 0;
          *sw_b++ = c == CC_DEL ? '?' : ucs2_t (c) + '@';
        }
      else if (c < 0x10000)
        *sw_b++ = ucs2_t (c);
      else if (sw_b + 1 < sw_buf + TEXT_MAX)
        {
          ucs4_t v = c - 0x10000;
          *sw_b++ = ucs2_t (0xD800 + (v >> 10));
          *sw_b++ = ucs2_t (0xDC00 + (v & 0x3FF));
        }
    }
  return 1;
}

void
StatusWindow::newline ()
{
  flush ();
  sw_b = sw_buf;
}

void
StatusWindow::flush ()
{
  int l = sw_b - sw_buf;
  if (l && (sw_last.textf || l != sw_last.l
            || memcmp (sw_last.buf, sw_buf, sizeof *sw_buf * l)))
    {
      memcpy (sw_last.buf, sw_buf, sizeof *sw_buf * l);
      sw_last.l = l;
      sw_last.textf = 0;
      SendMessage (g_status_window_hwnd, SB_SETTEXT, SBT_OWNERDRAW | 0, LPARAM (&sw_last));
      UpdateWindow (g_status_window_hwnd);
    }
}

void
StatusWindow::puts (const char *s, int fl)
{
  /* Phase 2: byte-string (get_message_string 等で src/core/gen/msgdef.cc が
     SJIS コンパイル済の error 文字列) は依然 SJIS 2-byte packed を
     内部 Char として putc に渡していた。putc が identity になった以上、
     SJIS→UCS-2 変換はここで済ませる必要がある。 */
  for (const u_char *p = (const u_char *)s; *p;)
    if (SJISP (*p) && p[1])
      {
        Char sjis_packed = (*p << 8) | p[1];
        putc (i2w (sjis_packed));
        p += 2;
      }
    else
      putc (*p++);

  if (fl)
    newline ();
}

void
StatusWindow::puts (int code, int fl)
{
  puts (get_message_string (code), fl);
}

void
StatusWindow::clear (int no_update)
{
  if (sw_last.l || sw_last.textf)
    {
      sw_last.l = 0;
      sw_last.textf = 0;
      if (!no_update)
        {
          SendMessageW (g_status_window_hwnd, SB_SETTEXT, 0, LPARAM (L""));
          UpdateWindow (g_status_window_hwnd);
        }
    }
  sw_b = sw_buf;
}



int
StatusWindow::paint (const DRAWITEMSTRUCT *dis)
{
  if (dis->itemData != (ULONG_PTR)&sw_last)
    return 0;

  TEXTMETRIC tm;
  GetTextMetrics (dis->hDC, &tm);

  COLORREF ofg = SetTextColor (dis->hDC, win32_sysdep.btn_text);
  COLORREF obg = SetBkColor (dis->hDC, win32_sysdep.btn_face);

  int x = dis->rcItem.left + 1;
  int y = (dis->rcItem.top + dis->rcItem.bottom - tm.tmHeight) / 2;

#if 1
  RECT r = dis->rcItem;
  r.right = x;
  for (const ucs2_t *b = sw_last.buf, *const be = b + sw_last.l;
       b < be; )
    {
      /* Phase 2: surrogate pair は 2 cu 一括で ExtTextOutW に渡す。
         1 cu ずつ描画すると Windows 側が pair 合成できず lone surrogate
         として豆腐化する。 */
      int n = 1;
      if (b + 1 < be
          && b[0] >= 0xD800 && b[0] <= 0xDBFF
          && b[1] >= 0xDC00 && b[1] <= 0xDFFF)
        n = 2;
      SIZE sz;
      GetTextExtentPoint32W (dis->hDC, (LPCWSTR)b, n, &sz);
      r.right += sz.cx;
      ExtTextOutW (dis->hDC, x, y, ETO_CLIPPED | ETO_OPAQUE,
                   &r, (LPCWSTR)b, n, 0);
      r.left = r.right;
      x += sz.cx;
      b += n;
    }
#else
  ExtTextOutW (dis->hDC, x, y,
               ETO_CLIPPED | ETO_OPAQUE, &dis->rcItem,
               sw_last.buf, sw_last.l, 0);
#endif
  SetTextColor (dis->hDC, ofg);
  SetBkColor (dis->hDC, obg);

  return 1;
}


// glyph_rep::glyph_rep, glyph_rep::copy moved to core/glyph.cc


void
Window::init (int minibufp, int temporary)
{
  w_last_bufp = 0;
  w_disp_flags = WDF_WINDOW | WDF_MODELINE;
  w_last_mark_linenum = -1;
  memset (&w_rect, 0, sizeof w_rect);
  memset (&w_order, 0, sizeof w_order);
  memset (w_last_vars, 0, sizeof w_last_vars);
  memset (&w_clsize, 0, sizeof w_clsize);
  memset (&w_ech, 0, sizeof w_ech);
  w_colors = default_colors;
  w_term_shadow = 0;
  w_term_shadow_rows = 0;
  w_term_shadow_cols = 0;
  w_term_shadow_cursor_row = -1;
  w_term_shadow_cursor_col = -1;
  w_term_sel_p = 0;
  w_term_sel_r0 = w_term_sel_c0 = 0;
  w_term_sel_r1 = w_term_sel_c1 = 0;
  w_inverse_mode_line = 0;
  w_ime_mode_line = 0;


  w_cursor_line.ypixel = -1;

  w_ruler_top_column = -1;
  w_ruler_column = -1;
  w_ruler_fold_column = Buffer::FOLD_NONE;

  w_ignore_scroll_margin = 0;
  w_mode_line_state = 0;

  if (temporary)
    return;

  lwp = make_window ();

  if (!CreateWindowEx (sysdep.Win4p () ? WS_EX_CLIENTEDGE : 0,
                       Application::ClientClassName, L"",
                       (WS_CHILD | WS_CLIPSIBLINGS | WS_VISIBLE
                        | WS_VSCROLL | WS_HSCROLL),
                       0, 0, 0, 0, g_active_frame_hwnd, 0, app.hinst, this))
    FEstorage_error ();

  if (minibufp)
    w_hwnd_ml = 0;
  else if (!CreateWindow (Application::ModelineClassName, L"",
                          WS_CHILD | WS_CLIPSIBLINGS | WS_VISIBLE,
                          0, 0, 0, 0,
                          g_active_frame_hwnd, 0, app.hinst, this))
    {
      DestroyWindow (hwnd());
      FEstorage_error ();
    }

  xwindow_wp (lwp) = this;

  w_vsinfo.nMin = 1;
  w_vsinfo.nMax = -1;
  w_vsinfo.nPage = UINT (-1);
  w_vsinfo.nPos = -1;
  update_vscroll_bar ();

  w_hsinfo.nMin = 0;
  w_hsinfo.nMax = -1;
  w_hsinfo.nPage = UINT (-1);
  w_hsinfo.nPos = -1;
  update_hscroll_bar ();
}

Window::Window (const Window &src)
{
  lwp = Qnil;
  w_next = w_prev = 0;
#define CP(x) (x = src.x)
  CP (w_bufp);
  CP (w_flags_mask);
  CP (w_flags);
  CP (w_last_flags);
  CP (w_point);
  CP (w_mark);
  CP (w_last_point);
  CP (w_disp);
  CP (w_last_disp);
  CP (w_last_top_linenum);
  CP (w_last_top_column);
  CP (w_linenum);
  CP (w_plinenum);
  CP (w_column);
  CP (w_goal_column);
  CP (w_top_column);
  CP (w_selection_type);
  CP (w_selection_point);
  CP (w_selection_marker);
  CP (w_reverse_temp);
  CP (w_reverse_region);
  CP (w_selection_column);
  CP (w_selection_region);
#undef CP
  init (0, 0);
}

#if defined(_MSC_VER) && (_MSC_VER < 1600)
/* なんか知らんがinternal compiler error が出るようになってしまったので
   てきとーに対処。*/
#pragma optimize("g", off)
#endif

Window::Window (int minibufp, int temporary)
{
  lwp = Qnil;
  w_bufp = 0;
  w_next = w_prev = 0;

  w_flags_mask = minibufp ? WF_NEWLINE : -1;
  w_flags = 0;
  w_last_flags = flags ();

  memset (&w_point, 0, sizeof w_point);
  w_mark = NO_MARK_SET;
  w_last_point = 0;
  w_disp = 0;
  w_last_disp = 0;
  w_last_top_linenum = 1;
  w_last_top_column = 0;
  w_linenum = 1;
  w_plinenum = 1;
  w_column = 0;
  w_goal_column = 0;
  w_top_column = 0;
  w_selection_type = Buffer::SELECTION_VOID;
  w_selection_point = NO_MARK_SET;
  w_selection_marker = NO_MARK_SET;
  w_selection_column = 0;
  w_selection_region.p1 = -1;
  w_reverse_temp = Buffer::SELECTION_VOID;
  w_reverse_region.p1 = NO_MARK_SET;
  w_reverse_region.p2 = NO_MARK_SET;

  init (minibufp, temporary);
}
#if defined(_MSC_VER) && (_MSC_VER < 1600)
#pragma optimize("", on)
#endif

Window::~Window ()
{
  delete static_cast <mode_line_state *> (w_mode_line_state);
  w_mode_line_state = 0;
  free (w_term_shadow);
  w_term_shadow = 0;
  if (windowp (lwp))
    xwindow_wp (lwp) = 0;
  if (IsWindow (hwnd()))
    DestroyWindow (hwnd());
  if (IsWindow (hwnd_ml()))
    DestroyWindow (hwnd_ml());
}

void
Window::save_buffer_params ()
{
  if (!w_bufp)
    return;
  w_bufp->b_point = w_point.p_point;
  w_bufp->b_mark = w_mark;
  w_bufp->b_selection_point = w_selection_point;
  w_bufp->b_selection_marker = w_selection_marker;
  w_bufp->b_selection_type = w_selection_type;
  w_bufp->b_selection_column = w_selection_column;
  w_bufp->b_reverse_temp = w_reverse_temp;
  w_bufp->b_reverse_region = w_reverse_region;
  w_bufp->b_disp = w_disp;
}

void
Window::change_color ()
{
  COLORREF cbuf[USER_DEFINABLE_COLORS];
  COLORREF *cc;
  if (w_bufp && w_bufp->b_colors_enable)
    {
      for (int i = 0; i < USER_DEFINABLE_COLORS; i++)
        cbuf[i] = w_bufp->b_colors[i];
      cc = cbuf;
    }
  else
    cc = default_colors;

  int i;
  for (i = 0; i < USER_DEFINABLE_COLORS; i++)
    if (cc[i] != w_colors[i])
      break;
  if (i == USER_DEFINABLE_COLORS)
    return;
  if (cc == cbuf)
    {
      memcpy (w_colors_buf, default_colors, sizeof w_colors_buf);
      memcpy (w_colors_buf, cbuf, sizeof cbuf);
      w_colors = w_colors_buf;
    }
  else
    w_colors = default_colors;
  invalidate_glyphs ();
}

void
Window::set_buffer_params (Buffer *bp)
{
  w_bufp = bp;
  w_point.p_point = 0;
  w_point.p_chunk = bp->b_chunkb;
  w_point.p_offset = 0;
  bp->goto_char (w_point, bp->b_point);
  w_mark = bp->b_mark;
  w_selection_point = bp->b_selection_point;
  w_selection_marker = bp->b_selection_marker;
  w_selection_type = bp->b_selection_type;
  w_selection_column = bp->b_selection_column;
  w_reverse_temp = bp->b_reverse_temp;
  w_reverse_region = bp->b_reverse_region;
  w_disp = bp->b_disp;
  w_last_disp = w_disp;
  w_goal_column = 0;
  w_disp_flags |= WDF_WINDOW | WDF_MODELINE | WDF_GOAL_COLUMN;
  change_color ();
}

void
Window::set_buffer (Buffer *bp)
{
  if (bp != w_bufp)
    {
      Buffer *obp = w_bufp;
      save_buffer_params ();
      set_buffer_params (bp);
      bp->window_size_changed ();
      if (obp)
        obp->window_size_changed ();
      Buffer::maybe_modify_buffer_bar ();
      w_ignore_scroll_margin = 1;
    }
}

void
Window::set_window ()
{
  assert (this);
  assert (xwindow_wp (lwp) == this);

  /* フォーカス報告 (DECSET 1004)。tmux 等のマルチプレクサが別ペインに
     切り替えたときと同じで、選択ウィンドウから外れる側/入る側の
     ターミナルバッファへ ESC[O / ESC[I を送る。要求していないアプリには
     terminal_focus_to_bytes が 0 を返すので何もしない。 */
  extern Terminal *buffer_terminal (const Buffer *bp);
  extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
  Window *prev = app.active_frame.selected;
  if (prev != this)
    {
      if (prev && prev->w_bufp)
        {
          Terminal *pt = buffer_terminal (prev->w_bufp);
          char b[8];
          int l = terminal_focus_to_bytes (pt, 0, b, sizeof b);
          if (l > 0)
            buffer_terminal_send (prev->w_bufp, b, l);
        }
      if (w_bufp)
        {
          Terminal *nt = buffer_terminal (w_bufp);
          char b[8];
          int l = terminal_focus_to_bytes (nt, 1, b, sizeof b);
          if (l > 0)
            buffer_terminal_send (w_bufp, b, l);
        }
    }

  app.active_frame.selected = this;
  w_bufp->check_range (w_point);
}

void
Window::init_colors (const XCOLORREF *colors, const XCOLORREF *mlcolors,
                     const XCOLORREF *fg_colors, const XCOLORREF *bg_colors)
{
  int i;
  if (colors)
    for (i = 0; i < USER_DEFINABLE_COLORS; i++)
      default_xcolors[i] = colors[i];
  if (mlcolors)
    for (i = 0; i < numberof (modeline_xcolors); i++)
      modeline_xcolors[i] = mlcolors[i];
  if (fg_colors)
    for (i = 1; i < numberof (w_textprop_xforecolor); i++)
      w_textprop_xforecolor[i] = fg_colors[i];
  if (bg_colors)
    for (i = 1; i < numberof (w_textprop_xbackcolor); i++)
      w_textprop_xbackcolor[i] = bg_colors[i];

  for (i = 0; i < USER_DEFINABLE_COLORS; i++)
    default_colors[i] = default_xcolors[i];
  for (i = 0; i < numberof (modeline_xcolors); i++)
    modeline_colors[i] = modeline_xcolors[i];
  for (i = 1; i < numberof (w_textprop_xforecolor); i++)
    w_textprop_forecolor[i] = w_textprop_xforecolor[i];
  for (i = 1; i < numberof (w_textprop_xbackcolor); i++)
    w_textprop_backcolor[i] = w_textprop_xbackcolor[i];

  default_colors[WCOLOR_GRAY] = win32_sysdep.gray_text;
  default_colors[WCOLOR_BTNSHADOW] = win32_sysdep.btn_shadow;
  default_colors[WCOLOR_BTNTEXT] = win32_sysdep.btn_text;

  HDC hdc = GetDC (0);
  for (i = 0; i < WCOLOR_MAX; i++)
    default_colors[i] = GetNearestColor (hdc, default_colors[i]);
  for (i = 0; i < numberof (modeline_xcolors); i++)
    modeline_colors[i] = GetNearestColor (hdc, modeline_colors[i]);
  for (i = 1; i < numberof (w_textprop_forecolor); i++)
    w_textprop_forecolor[i] = GetNearestColor (hdc, w_textprop_forecolor[i]);
  for (i = 1; i < numberof (w_textprop_backcolor); i++)
    w_textprop_backcolor[i] = GetNearestColor (hdc, w_textprop_backcolor[i]);
  ReleaseDC (0, hdc);

  for (i = 0; i < USER_DEFINABLE_COLORS; i++)
    write_conf (cfgColors, wcolor_index_names[i].name, default_xcolors[i].rgb, 1);
  write_conf (cfgColors, cfgModeLineFg, modeline_xcolors[MLCI_FOREGROUND].rgb, 1);
  write_conf (cfgColors, cfgModeLineBg, modeline_xcolors[MLCI_BACKGROUND].rgb, 1);
  for (i = 1; i < numberof (w_textprop_forecolor); i++)
    {
      char b[32];
      sprintf (b, "%s%d", cfgFg, i);
      write_conf (cfgColors, b, w_textprop_xforecolor[i].rgb, 1);
      sprintf (b, "%s%d", cfgBg, i);
      write_conf (cfgColors, b, w_textprop_xbackcolor[i].rgb, 1);
    }
  flush_conf ();
}

void
Window::textprop_colors_changed ()
{
  /* init_colors と同じ後始末のうち、ini への書き込みを**しない**もの。
     テーマによる上書きは表示色の設定ではないので保存してはいけない
     (src/core/textprop-colors.cc)。 */
  HDC hdc = GetDC (0);
  int i;
  for (i = 1; i < numberof (w_textprop_forecolor); i++)
    w_textprop_forecolor[i] = GetNearestColor (hdc, w_textprop_forecolor[i]);
  for (i = 1; i < numberof (w_textprop_backcolor); i++)
    w_textprop_backcolor[i] = GetNearestColor (hdc, w_textprop_backcolor[i]);
  ReleaseDC (0, hdc);

  /* 色は描画のときに glyph から引かれるので、glyph 自体は作り直さなくてよい。
     ただし「前回描いた内容と同じ cell は描かない」ので、控えを捨てないと
     色だけが変わった行が塗り直されない。 */
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->invalidate_glyphs ();
}

void
Window::change_parameters (const FontSetParam &param)
{
  change_parameters (param, 0, 0, 0, 0, false);
}

void
Window::change_parameters (const FontSetParam &param,
                           const XCOLORREF *colors, const XCOLORREF *mlcolors,
                           const XCOLORREF *fg, const XCOLORREF *bg,
                           bool change_color_p)
{
  /* 以前はここでフォントを変える前のセル高 (ocell) を compute_geometry へ
     渡していた。ステータス行の行数をその高さから割り戻していたからで、
     行数は w_minibuffer_lines が持つようになったので要らない (issue #97)。 */
  app.text_font.create (param);
  create_fontset_bitmap (app.text_font);
  if (change_color_p)
    init_colors (colors, mlcolors, fg, bg);

  compute_geometry (app.active_frame.size);

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->invalidate_glyphs ();
}

static void
set_bgmode ()
{
  wcolor_index c = (Window::w_default_flags & Window::WF_BGCOLOR_MODE
                    ? WCOLOR_TEXT : WCOLOR_REVERSE);
  for (int i = GLYPH_REVERSED >> GLYPH_COLOR_SHIFT_BITS;
       i < (GLYPH_REVERSED >> GLYPH_COLOR_SHIFT_BITS) + 16;
       i++)
    if (i != ((GLYPH_REVERSED | GLYPH_LINENUM) >> GLYPH_COLOR_SHIFT_BITS))
      Window::backcolor_indexes[i] = c;
}

void
Window::create_default_windows ()
{
  app.text_font.init ();

  XCOLORREF cc[USER_DEFINABLE_COLORS];
  for (int i = 0; i < USER_DEFINABLE_COLORS; i++)
    cc[i] = wcolor_index_names[i].rgb;
  cc[WCOLOR_TEXT] = XCOLORREF (win32_sysdep.window_text, COLOR_WINDOWTEXT);
  cc[WCOLOR_BACK] = XCOLORREF (win32_sysdep.window, COLOR_WINDOW);
  cc[WCOLOR_HIGHLIGHT_TEXT] = XCOLORREF (win32_sysdep.highlight_text,
                                         COLOR_HIGHLIGHTTEXT);
  cc[WCOLOR_HIGHLIGHT] = XCOLORREF (win32_sysdep.highlight, COLOR_HIGHLIGHT);
  cc[WCOLOR_REVERSE] = XCOLORREF (GetSysColor (COLOR_BACKGROUND),
                                  COLOR_BACKGROUND);
  cc[WCOLOR_LINENUM] = cc[WCOLOR_TEXT];
  cc[WCOLOR_MODELINE_FG] = XCOLORREF (win32_sysdep.btn_text, COLOR_BTNTEXT);
  cc[WCOLOR_MODELINE_BG] = XCOLORREF (win32_sysdep.btn_face, COLOR_BTNFACE);

  XCOLORREF mlcc[2];
  mlcc[0] = XCOLORREF (win32_sysdep.btn_highlight, COLOR_BTNHIGHLIGHT);
  mlcc[1] = XCOLORREF (win32_sysdep.btn_text, COLOR_BTNTEXT);

  XCOLORREF fg[GLYPH_TEXTPROP_NCOLORS], bg[GLYPH_TEXTPROP_NCOLORS];
  for (int i = 0; i < GLYPH_TEXTPROP_NCOLORS; i++)
    {
      fg[i] = w_textprop_forecolor[i];
      bg[i] = w_textprop_backcolor[i];
    }

  int c;
  for (int i = 0; i < USER_DEFINABLE_COLORS; i++)
    {
      if (read_conf (cfgColors, wcolor_index_names[i].name, c))
        cc[i] = c;
      else if (i == WCOLOR_LINENUM)
        cc[i] = cc[WCOLOR_TEXT];
    }
  if (read_conf (cfgColors, cfgModeLineFg, c))
    mlcc[0] = c;
  if (read_conf (cfgColors, cfgModeLineBg, c))
    mlcc[1] = c;
  for (int i = 1; i < GLYPH_TEXTPROP_NCOLORS; i++)
    {
      char b[32];
      sprintf (b, "%s%d", cfgFg, i);
      if (read_conf (cfgColors, b, c))
        fg[i] = c;
      sprintf (b, "%s%d", cfgBg, i);
      if (read_conf (cfgColors, b, c))
        bg[i] = c;
    }

  init_colors (cc, mlcc, fg, bg);
  set_bgmode ();

  Window *wp = new Window ();
  Window *mwp = new Window (1);

  wp->w_order.left = 0;
  wp->w_order.top = 0;
  wp->w_order.right = 1;
  wp->w_order.bottom = 1;

  mwp->w_rect.top = 0;
  mwp->w_rect.bottom = app.text_font.size ().cy + sysdep.edge.cy;

  wp->w_prev = 0;
  wp->w_next = mwp;
  mwp->w_prev = wp;
  mwp->w_next = 0;

  app.active_frame.windows = wp;
  app.active_frame.selected = wp;

  SIZE osize = {0, 0};
  if (!IsIconic (get_toplevel_window ()))
    {
      RECT r;
      GetClientRect (g_active_frame_hwnd, &r);
      app.active_frame.size.cx = r.right;
      app.active_frame.size.cy = r.bottom;
    }
  else
    {
      app.active_frame.size.cx = 10;
      app.active_frame.size.cy = 10;
    }
  Window::compute_geometry (osize);
  Window::move_all_windows (0);
}

// Window::alloc_glyph_rep moved to core/glyph.cc

void
Window::calc_client_size (int width, int height)
{
  w_client.cx = max (0, width);
  w_client.cy = max (0, height);
  w_ech.cx = max (0L, ((w_client.cx - app.text_font.cell ().cx / 2)
                       / app.text_font.cell ().cx));
  w_ech.cy = w_client.cy / app.text_font.cell ().cy;
  w_ch_max.cx = (w_client.cx + app.text_font.cell ().cx
                 + app.text_font.cell ().cx / 2 - 1) / app.text_font.cell ().cx;
  w_ch_max.cy = (w_client.cy + app.text_font.cell ().cy - 1) / app.text_font.cell ().cy;
  if (!w_ech.cx && w_ch_max.cx)
    w_ech.cx = 1;
  if (!w_ech.cy && w_ch_max.cy)
    w_ech.cy = 1;
  if (!w_glyphs.g_rep
      || w_glyphs.g_rep->gr_size.cx != w_ch_max.cx
      || w_glyphs.g_rep->gr_size.cy != w_ch_max.cy)
    {
      if (!alloc_glyph_rep ())
        w_glyphs = Glyphs (0);
      w_disp_flags |= WDF_WINDOW | WDF_MODELINE | WDF_WINSIZE_CHANGED;
    }
}

static void
compute_size (int *o, int n, int old_size, int new_size)
{
  if (old_size < 0)
    old_size = 0;
  if (new_size < 0)
    new_size = 0;
  int *const w = (int *)alloca (sizeof *w * n);
  int i;
  for (i = 0; i < n; i++)
    w[i] = o[i + 1] - o[i];
  int diff_size = new_size - old_size;
  if (!old_size)
    {
      int d = diff_size / n;
      for (i = 0; i < n; i++)
        w[i] += d;
    }
  else
    for (i = 0; i < n; i++)
      w[i] += w[i] * diff_size / old_size;

  int sum = 0;
  for (i = 0; i < n; i++)
    {
      if (w[i] < 0)
        w[i] = 0;
      sum += w[i];
    }

  int d = new_size - sum;

  if (d > 0)
    for (; d > 0; d--)
      w[(new_size + d) % n]++;
  else
    for (d = -d; d > 0; d--)
      w[(new_size + d) % n]--;

  for (o[0] = 0, i = 1; i <= n; i++)
    {
      o[i] = o[i - 1] + w[i - 1];
      if (o[i] < o[i - 1])
        o[i] = o[i - 1];
    }

  for (o[n] = new_size, i = n - 1; i > 0; i--)
    if (o[i] > o[i + 1])
      o[i] = o[i + 1];
}

void
Window::compute_geometry (const SIZE &old_size, int)
{
  if (!app.active_frame.windows)
    return;

  const SIZE &new_size = app.active_frame.size;

  // compute minibuffer window geometry
  Window *wp;
  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    ;
  wp->w_rect.left = 0;
  wp->w_rect.right = new_size.cx;
  /* 高さは w_minibuffer_lines 行分。**以前は今の高さから行数を割り戻して
     いた** (`old_h / lcell`) ので、フォントを変えても行数は保たれる代わりに
     行数を変える手段が無かった (issue #97)。 */
  int old_h = wp->w_rect.bottom - wp->w_rect.top;
  int new_h = w_minibuffer_lines * app.text_font.cell ().cy + 4;
  int min_h = app.text_font.cell ().cy + 4;
  int max_h = new_size.cy - (sysdep.edge.cy + FRAME_WIDTH + min_h + app.modeline_param.m_height + 4);
  new_h = max (new_h, min_h);
  if (new_h > max_h)
    /* 入り切らないぶんは詰める。**元の高さへ戻してはいけない**: 伸ばせ
       ないのではなく「伸ばせるところまで伸ばす」のが期待する挙動である。
       画面が min_h さえ置けないほど狭いときだけ、今の高さを保つ。 */
    new_h = max_h >= min_h ? max_h : old_h;

  wp->w_rect.bottom = new_size.cy;
  wp->w_rect.top = new_size.cy - new_h;
  wp->calc_client_size (wp->w_rect.right - sysdep.edge.cx,
                        wp->w_rect.bottom - wp->w_rect.top - sysdep.edge.cy);

  long nx = 0, ny = 0;
  long ow = 0, oh = 0;
  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    {
      nx = max (nx, wp->w_order.right);
      ny = max (ny, wp->w_order.bottom);
      ow = max (ow, wp->w_rect.right);
      oh = max (oh, wp->w_rect.bottom);
    }

  // compute normal windows geometry
  //
  // **埋まらない添字が無いことを当てにしない。** w_order に穴があると
  // (Window::compact_orders の説明、src/core/window-config.cc) alloca の
  // ごみをそのまま座標として使う。`(split-window) (delete-window)
  // (split-window)` と続けるとウィンドウが 2 枚とも 1 行になっていた
  // (issue #83)。番号を詰めてあれば穴は無いが、ここでも -1 で始めて
  // 埋め残しを直前の境界で塞ぐ。
  int *const ox = (int *)alloca (sizeof *ox * (nx + 1));
  int *const oy = (int *)alloca (sizeof *oy * (ny + 1));
  {
    int i;
    for (i = 0; i <= nx; i++)
      ox[i] = -1;
    for (i = 0; i <= ny; i++)
      oy[i] = -1;
  }
  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    {
      ox[wp->w_order.left] = wp->w_rect.left;
      oy[wp->w_order.top] = wp->w_rect.top;
      ox[wp->w_order.right] = wp->w_rect.right;
      oy[wp->w_order.bottom] = wp->w_rect.bottom;
    }
  {
    int i;
    if (ox[0] < 0)
      ox[0] = 0;
    if (oy[0] < 0)
      oy[0] = 0;
    for (i = 1; i <= nx; i++)
      if (ox[i] < 0)
        ox[i] = ox[i - 1];
    for (i = 1; i <= ny; i++)
      if (oy[i] < 0)
        oy[i] = oy[i - 1];
  }

  compute_size (ox, nx, ow, new_size.cx);
  compute_size (oy, ny, oh, new_size.cy - new_h);

  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    {
      wp->w_rect.left = ox[wp->w_order.left];
      wp->w_rect.top = oy[wp->w_order.top];
      wp->w_rect.right = ox[wp->w_order.right];
      wp->w_rect.bottom = oy[wp->w_order.bottom];

      int cx = wp->w_rect.right - wp->w_rect.left - sysdep.edge.cx;
      int cy = wp->w_rect.bottom - wp->w_rect.top - sysdep.edge.cy;
      if (wp->flags () & WF_VSCROLL_BAR)
        cx -= sysdep.vscroll;
      if (wp->flags () & WF_HSCROLL_BAR)
        cy -= sysdep.hscroll;
      if (wp->w_rect.right != app.active_frame.size.cx)
        cx -= FRAME_WIDTH;
      cx -= RIGHT_PADDING;
      if (wp->hwnd_ml())
        cy -= app.modeline_param.m_height + 4 + FRAME_WIDTH;
      if (!wp->minibuffer_window_p () && wp->flags () & WF_RULER)
        cy -= RULER_HEIGHT;

      wp->calc_client_size (cx, cy);
    }

  app.active_frame.windows_moved = 1;
}

void
Window::move_all_windows (int update)
{
  int mod = 0;
  app.active_frame.windows_moved = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    {
      int cx, cy;
      int mlh;
      if (wp->hwnd_ml())
        {
          mlh = wp->flags () & WF_MODE_LINE ? app.modeline_param.m_height + 4 : 0;
          cx = wp->w_rect.right == app.active_frame.size.cx ? 0 : FRAME_WIDTH;
          cy = FRAME_WIDTH;
        }
      else
        {
          mlh = 0;
          cx = cy = 0;
        }

      RECT or, nr;
      if (!mod)
        GetWindowRect (wp->hwnd(), &or);

      SIZE size;
      size.cx = max (0, int (wp->w_rect.right - wp->w_rect.left - cx));
      int ruler = (!wp->minibuffer_window_p () && wp->flags () & WF_RULER
                   ? RULER_HEIGHT : 0);
      size.cy = max (0, int (wp->w_rect.bottom - wp->w_rect.top - mlh - cy - ruler));
      MoveWindow (wp->hwnd(), wp->w_rect.left, wp->w_rect.top + ruler,
                  size.cx, size.cy, 1);

      if (!mod)
        {
          GetWindowRect (wp->hwnd(), &nr);
          mod = memcmp (&or, &nr, sizeof or);
        }

      RECT r;
      GetClientRect (wp->hwnd(), &r);
      wp->calc_client_size (r.right - RIGHT_PADDING, r.bottom);
      if (wp->hwnd_ml())
        {
          if (!mod)
            GetWindowRect (wp->hwnd_ml(), &or);
          wp->w_ml_size.cx = size.cx;
          wp->w_ml_size.cy = mlh;
          InvalidateRect (wp->hwnd_ml(), 0, 1);
          MoveWindow (wp->hwnd_ml(),
                      wp->w_rect.left, wp->w_rect.bottom - mlh - cy, size.cx, mlh, 1);
          if (!mod)
            {
              GetWindowRect (wp->hwnd_ml(), &nr);
              mod = memcmp (&or, &nr, sizeof or);
            }
        }
    }

  for (Window *wp = app.active_frame.reserved; wp; wp = wp->w_next)
    {
      MoveWindow (wp->hwnd(), 0, 0, 0, 0, 1);
      if (wp->hwnd_ml())
        MoveWindow (wp->hwnd_ml(), 0, 0, 0, 0, 1);
    }

  if (mod)
    {
      for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
        if (wp->w_bufp)
          wp->w_bufp->window_size_changed ();

      InvalidateRect (g_active_frame_hwnd, 0, 1);
      InvalidateRect (get_toplevel_window (), 0, 1);
      if (update)
        {
          UpdateWindow (g_active_frame_hwnd);
          UpdateWindow (get_toplevel_window ());
        }
    }
}

void
Window::repaint_all_windows ()
{
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!GetUpdateRect (wp->hwnd(), 0, 0))
      wp->update_window ();
}

void
Window::destroy_windows ()
{
  Window *wp, *next;
  for (wp = app.active_frame.deleted; wp; wp = next)
    {
      next = wp->w_next;
      delete wp;
    }
  app.active_frame.deleted = 0;
}

/* ターミナルのマウス選択。ターミナルバッファは buffer 本文を持たない
   (表示は TermCell を直接描いている) ので、xyzzy 本来の選択機構は端から
   何も掴めない。格子の座標で範囲を持ち、描画側で反転して見せ、離した
   時点でクリップボードへ入れる (PuTTY や xterm と同じ copy-on-select)。 */

/* アンカーと現在位置を並べ直す。テキストの選択と同じで、開始行は c0 から
   行末まで、途中の行は丸ごと、終了行は行頭から c1 まで。 */
void
Window::terminal_selection_range (int *r0, int *c0, int *r1, int *c1) const
{
  if (w_term_sel_r0 < w_term_sel_r1
      || (w_term_sel_r0 == w_term_sel_r1 && w_term_sel_c0 <= w_term_sel_c1))
    {
      *r0 = w_term_sel_r0; *c0 = w_term_sel_c0;
      *r1 = w_term_sel_r1; *c1 = w_term_sel_c1;
    }
  else
    {
      *r0 = w_term_sel_r1; *c0 = w_term_sel_c1;
      *r1 = w_term_sel_r0; *c1 = w_term_sel_c0;
    }
}

int
Window::terminal_selected_cell_p (int row, int col) const
{
  if (!w_term_sel_p)
    return 0;
  int r0, c0, r1, c1;
  terminal_selection_range (&r0, &c0, &r1, &c1);
  if (row < r0 || row > r1)
    return 0;
  if (row == r0 && col < c0)
    return 0;
  if (row == r1 && col > c1)
    return 0;
  return 1;
}

void
Window::terminal_clear_selection ()
{
  if (!w_term_sel_p)
    return;
  w_term_sel_p = 0;
  w_disp_flags |= WDF_WINDOW;
}

void
Window::terminal_copy_selection (Terminal *term) const
{
  if (!w_term_sel_p || !term)
    return;

  extern void terminal_lock ();
  extern void terminal_unlock ();

  int r0, c0, r1, c1;
  terminal_selection_range (&r0, &c0, &r1, &c1);

  /* 行末の空白は落とす。端末の格子は右端まで空白で埋まっているので、
     そのまま取ると 1 行ごとに何十桁もの空白が付いてくる。

     格子 (display_cell) を読んでいる間は terminal_lock () で ConPTY の
     reader スレッドの feed () と排他する (issue #264)。reader が同じ
     セルへ書き込み中に読むと、行が半分だけ新しい内容になった文字列を
     クリップボードへコピーしてしまう。GlobalAlloc 以降はクリップボード
     API だけで格子を触らないので、ロックの外に出す。 */
  terminal_lock ();
  int nrows = term->rows ();
  int ncols = term->cols ();
  wchar_t *buf = 0;
  int len = 0, cap = 0;
  for (int r = r0; r <= r1 && r < nrows; r++)
    {
      int from = (r == r0) ? c0 : 0;
      int to = (r == r1) ? c1 : ncols - 1;
      if (to >= ncols)
        to = ncols - 1;
      int last = from - 1;
      for (int c = to; c >= from; c--)
        {
          const TermCell *tc = term->display_cell (r, c);
          if (tc->ch && tc->ch != ' ')
            { last = c; break; }
        }
      for (int c = from; c <= last; c++)
        {
          const TermCell *tc = term->display_cell (r, c);
          if (tc->wide == 2)
            continue;
          ucs4_t ch = tc->ch ? tc->ch : ' ';
          if (len + 4 > cap)
            {
              cap = cap ? cap * 2 : 256;
              wchar_t *nb = (wchar_t *)realloc (buf, cap * sizeof (wchar_t));
              if (!nb)
                { terminal_unlock (); free (buf); return; }
              buf = nb;
            }
          if (ch < 0x10000)
            buf[len++] = wchar_t (ch);
          else
            {
              buf[len++] = wchar_t (utf16_ucs4_to_pair_high (ch));
              buf[len++] = wchar_t (utf16_ucs4_to_pair_low (ch));
            }
        }
      if (r < r1)
        {
          if (len + 4 > cap)
            {
              cap = cap ? cap * 2 : 256;
              wchar_t *nb = (wchar_t *)realloc (buf, cap * sizeof (wchar_t));
              if (!nb)
                { terminal_unlock (); free (buf); return; }
              buf = nb;
            }
          buf[len++] = L'\r';
          buf[len++] = L'\n';
        }
    }
  terminal_unlock ();

  if (!len)
    { free (buf); return; }

  HGLOBAL hmem = GlobalAlloc (GMEM_MOVEABLE, (len + 1) * sizeof (wchar_t));
  if (!hmem)
    { free (buf); return; }
  wchar_t *p = (wchar_t *)GlobalLock (hmem);
  memcpy (p, buf, len * sizeof (wchar_t));
  p[len] = L'\0';
  GlobalUnlock (hmem);
  free (buf);

  if (OpenClipboard (get_toplevel_window ()))
    {
      EmptyClipboard ();
      SetClipboardData (CF_UNICODETEXT, hmem);
      CloseClipboard ();
    }
  else
    GlobalFree (hmem);
}

void
Window::update_vscroll_bar ()
{
  w_vsinfo.fMask = 0;
  if (flags () & WF_VSCROLL_BAR)
    {
      if (w_vsinfo.sb_seen != ScrollInfo::yes)
        {
          w_vsinfo.sb_seen = ScrollInfo::yes;
          ShowScrollBar (hwnd(), SB_VERT, 1);
        }
      /* ターミナルバッファは buffer 本文を持たない (表示は TermCell を
         直接描いている) ので、count_lines () は常に 0 行を返す。範囲が
         1 ページに収まっている扱いになり、スクロールバックが溜まっていても
         バーが立たなかった。行数は端末側から取る。

         nPos は上端の行番号 (nMin = 1 起点)。offset = 0 (ライブ) が一番下、
         offset = count が一番上なので、1 + count - offset。 */
      extern Terminal *buffer_terminal (const Buffer *bp);
      Terminal *term = w_bufp ? buffer_terminal (w_bufp) : 0;
      int nlines, npage, npos;
      if (term)
        {
          npage = term->rows ();
          nlines = term->scrollback_count () + npage;
          npos = 1 + term->scrollback_count () - term->scrollback_offset ();
        }
      else
        {
          nlines = (w_bufp
                    ? (w_bufp->b_fold_columns == Buffer::FOLD_NONE
                       ? w_bufp->count_lines ()
                       : w_bufp->folded_count_lines ())
                    : 1);
          if (!(flags () & WF_ALT_VSCROLL_BAR))
            nlines += w_ech.cy - 1;
          else
            nlines = max (nlines, int (w_last_top_linenum + w_ech.cy - 1));
          npage = w_ech.cy;
          npos = w_last_top_linenum;
        }
      if (w_vsinfo.nMax != nlines || w_vsinfo.nPage != UINT (npage))
        {
          w_vsinfo.nMax = nlines;
          w_vsinfo.nPage = npage;
          w_vsinfo.fMask |= SIF_RANGE | SIF_PAGE;
        }
      if (w_vsinfo.nPos != npos)
        {
          w_vsinfo.nPos = npos;
          w_vsinfo.fMask |= SIF_POS;
        }
      if (w_vsinfo.fMask)
        w_vsinfo.fMask |= SIF_DISABLENOSCROLL;
    }
  else
    {
      if (w_vsinfo.sb_seen != ScrollInfo::no)
        {
          ShowScrollBar (hwnd(), SB_VERT, 0);
          w_vsinfo.sb_seen = ScrollInfo::no;
          w_vsinfo.nMax = w_vsinfo.nMin;
          w_vsinfo.nPage = UINT (-1);
          w_vsinfo.nPos = -1;
          w_vsinfo.fMask = SIF_RANGE;
        }
    }
  if (w_vsinfo.fMask)
    SetScrollInfo (hwnd(), SB_VERT, &w_vsinfo, 1);
}

int
Window::vscroll_lines () const
{
  int h = w_ech.cy;
  if (xsymbol_value (Vpage_scroll_half_window) != Qunbound
      && xsymbol_value (Vpage_scroll_half_window) != Qnil)
    h /= 2;
  else
    h -= symbol_value_as_integer (Vnext_screen_context_lines, w_bufp);
  return max (h, 1);
}

void
Window::process_vscroll (int code)
{
  if (!w_bufp)
    return;

  /* ターミナルバッファはバーの操作を端末のスクロールバックに向ける。
     scroll_window () が動かすのは buffer の point で、表示は TermCell を
     直接描いているので効かない (ホイールと同じ理由)。
     scrollback の offset は「遡り」が正なので、下へ = 減らす。 */
  {
    extern Terminal *buffer_terminal (const Buffer *bp);
    Terminal *term = buffer_terminal (w_bufp);
    if (term)
      {
        int step = max (symbol_value_as_integer (Vscroll_bar_step, w_bufp), 1);
        int delta;
        switch (code)
          {
          case SB_LINEDOWN: delta = -step; break;
          case SB_LINEUP:   delta = step; break;
          case SB_PAGEDOWN: delta = -vscroll_lines (); break;
          case SB_PAGEUP:   delta = vscroll_lines (); break;
          case SB_THUMBTRACK:
            {
              ScrollInfo i;
              i.fMask = SIF_TRACKPOS;
              GetScrollInfo (hwnd(), SB_VERT, &i);
              /* update_vscroll_bar の nPos = 1 + count - offset の逆。 */
              int off = 1 + term->scrollback_count () - i.nTrackPos;
              delta = off - term->scrollback_offset ();
              break;
            }
          default:
            return;
          }
        /* scrollback_scroll () は格子の中身ではなく offset だけを書く
           カウンタ操作だが、reader スレッドの feed () が同時に格子へ
           書き込みつつ offset を動かす経路と地続きなので、
           terminal_copy_selection と同じ理由でロックする (issue #264)。 */
        extern void terminal_lock ();
        extern void terminal_unlock ();
        terminal_lock ();
        int before = term->scrollback_offset ();
        term->scrollback_scroll (delta);
        int after = term->scrollback_offset ();
        terminal_unlock ();
        if (after == before)
          return;
        terminal_clear_selection ();  /* 座標がずれるので解除 */
        w_disp_flags |= WDF_WINDOW;
        refresh_screen (0);
        return;
      }
  }

  switch (code)
    {
    case SB_LINEDOWN:
      if (!scroll_window (max (symbol_value_as_integer (Vscroll_bar_step, w_bufp), 1)))
        return;
      break;

    case SB_LINEUP:
      if (!scroll_window (-max (symbol_value_as_integer (Vscroll_bar_step, w_bufp), 1)))
        return;
      break;

    case SB_PAGEDOWN:
      if (!scroll_window (vscroll_lines ()))
        return;
      break;

    case SB_PAGEUP:
      if (!scroll_window (-vscroll_lines ()))
        return;
      break;

    case SB_THUMBTRACK:
      {
        ScrollInfo i;
        i.fMask = SIF_TRACKPOS;
        GetScrollInfo (hwnd(), SB_VERT, &i);
        if (!scroll_window (i.nTrackPos, 1))
          return;
        break;
      }

    default:
      return;
    }

  refresh_screen (1);
}

void
Window::wheel_scroll (const wheel_info &wi)
{
  if (!w_bufp || !wi.wi_value)
    return;

  /* ターミナル (ConPTY) で、アプリがマウス報告を要求している間はホイールも
     pty へ流す。要求していなければ端末自身のスクロールバックを動かす。
     xterm 互換のホイールはボタン 64 = 上、65 = 下 の press として送る。

     ターミナルバッファを Lisp の mouse-wheel-handler に渡してはいけない。
     あちらは buffer の point を動かすが、ターミナルの表示は TermCell を
     直接描いていて buffer 本文を見ていないので、ホイールを回しても何も
     起きなかった (「シェルのスクロールバックができない」)。 */
  {
    extern Terminal *buffer_terminal (const Buffer *bp);
    extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
    Terminal *term = buffer_terminal (w_bufp);
    if (term && term->mouse_mode ())
      {
        POINT pt = wi.wi_pt;
        ScreenToClient (hwnd(), &pt);
        int cellw = app.text_font.cell ().cx;
        int cellh = app.text_font.cell ().cy;
        if (cellw > 0 && cellh > 0)
          {
            int x = pt.x - cellw / 2;
            int col = x < 0 ? 0 : x / cellw;
            int row = pt.y < 0 ? 0 : pt.y / cellh;
            if (col >= term->cols ())
              col = term->cols () - 1;
            if (row >= term->rows ())
              row = term->rows () - 1;
            /* 1 ノッチ 1 イベント。実端末と同じで、スクロール量は
               アプリ側が決める。暴走を避けて上限を付ける。 */
            int n = wi.wi_value < 0 ? -wi.wi_value : wi.wi_value;
            if (n > 8)
              n = 8;
            int button = wi.wi_value > 0 ? 64 : 65;
            for (int i = 0; i < n; i++)
              {
                char b[32];
                int l = terminal_mouse_to_bytes (term, 0, button, row, col, 0,
                                                 b, sizeof b);
                if (l <= 0)
                  break;
                buffer_terminal_send (w_bufp, b, l);
              }
            return;
          }
      }
    if (term)
      {
        /* 1 ノッチで wi_nlines 行 (システム設定)。WHEEL_PAGESCROLL は
           1 画面。wi_value は上が正、scrollback_scroll も遡りが正。 */
        int nlines = (wi.wi_nlines == WHEEL_PAGESCROLL
                      ? term->rows () : wi.wi_nlines);
        if (nlines < 1)
          nlines = 1;
        int before = term->scrollback_offset ();
        term->scrollback_scroll (wi.wi_value * nlines);
        if (term->scrollback_offset () != before)
          {
            terminal_clear_selection ();  /* 座標がずれるので解除 */
            w_disp_flags |= WDF_WINDOW;
            refresh_screen (0);
          }
        return;
      }
  }

  lisp hook = symbol_value (Vmouse_wheel_handler, w_bufp);
  if (hook != Qunbound && hook != Qnil)
    {
      try
        {
          funcall_3 (hook, lwp, make_fixnum (-wi.wi_value),
                     (wi.wi_nlines == WHEEL_PAGESCROLL
                      ? Qnil : make_fixnum (wi.wi_nlines)));
        }
      catch (nonlocal_jump &)
        {
          print_condition (nonlocal_jump::data ());
        }
      refresh_screen (1);
    }
}

void
Window::update_hscroll_bar ()
{
  w_hsinfo.fMask = 0;
  if (flags () & WF_HSCROLL_BAR)
    {
      if (w_hsinfo.sb_seen != ScrollInfo::yes)
        {
          w_hsinfo.sb_seen = ScrollInfo::yes;
          ShowScrollBar (hwnd(), SB_HORZ, 1);
        }
      int pos;
      int w;
      if (!w_bufp || w_bufp->b_fold_columns == Buffer::FOLD_NONE)
        {
#define PAGES_PER_WIDTH 20
          w = w_ech.cx * PAGES_PER_WIDTH;
          pos = min (w_last_top_column, long (w_ech.cx * (PAGES_PER_WIDTH - 2)));
#undef PAGES_PER_WIDTH
        }
      else
        {
          w = w_bufp->b_fold_columns;
          if (flags () & WF_LINE_NUMBER)
            w += LINENUM_COLUMNS;
          pos = min (w_last_top_column, long (w - w_ech.cx));
        }
      if (w_hsinfo.nMax != w || w_hsinfo.nPage != UINT (w_ech.cx))
        {
          w_hsinfo.nMax = w;
          w_hsinfo.nPage = w_ech.cx;
          w_hsinfo.fMask |= SIF_RANGE | SIF_PAGE;
        }
      if (w_hsinfo.nPos != pos)
        {
          w_hsinfo.nPos = pos;
          w_hsinfo.fMask |= SIF_POS;
        }
      if (w_hsinfo.fMask)
        w_hsinfo.fMask |= SIF_DISABLENOSCROLL;
    }
  else
    {
      if (w_hsinfo.sb_seen != ScrollInfo::no)
        {
          w_hsinfo.sb_seen = ScrollInfo::no;
          ShowScrollBar (hwnd(), SB_HORZ, 0);
          w_hsinfo.nMax = w_hsinfo.nMin;
          w_hsinfo.nPage = UINT (-1);
          w_hsinfo.nPos = -1;
          w_hsinfo.fMask = SIF_RANGE;
        }
    }
  if (w_hsinfo.fMask)
    SetScrollInfo (hwnd(), SB_HORZ, &w_hsinfo, 1);
}

void
Window::process_hscroll (int code)
{
  if (!w_bufp)
    return;

  switch (code)
    {
    case SB_LINELEFT:
      if (!scroll_window_horizontally (-2))
        return;
      break;

    case SB_LINERIGHT:
      if (!scroll_window_horizontally (2))
        return;
      break;

    case SB_PAGELEFT:
      if (!scroll_window_horizontally (-w_ech.cx))
        return;
      break;

    case SB_PAGERIGHT:
      if (!scroll_window_horizontally (w_ech.cx))
        return;
      break;

    case SB_THUMBTRACK:
      {
        ScrollInfo i;
        i.fMask = SIF_TRACKPOS;
        GetScrollInfo (hwnd(), SB_HORZ, &i);
        if (!scroll_window_horizontally (i.nTrackPos - w_hsinfo.nPos))
          return;
        break;
      }

    default:
      return;
    }

  refresh_screen (1);
}


Window *
Window::minibuffer_window ()
{
  Window *wp;
  for (wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
    ;
  return wp;
}

int
Window::count_windows ()
{
  int n = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next, n++)
    ;
  return n;
}

void
Window::modify_all_mode_line ()
{
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->w_disp_flags |= WDF_MODELINE;
}

void
Window::split (int nlines, int verticalp)
{
  if (minibuffer_window_p ())
    FEsimple_error (Ecannot_split_minibuffer_window);

  int h0, h1;
  int pxl;
  int current;

  if (!verticalp)
    {
      if (!nlines)
        {
          h0 = w_ech.cy / 2;
          h1 = w_ech.cy - h0 - 1;
          current = w_linenum - w_last_top_linenum < h0 ? 0 : 1;
          pxl = (w_rect.bottom - w_rect.top) / 2;
        }
      else
        {
          int ml = app.modeline_param.m_height + 4;
          if (nlines > 0)
            {
              h0 = nlines;
              h1 = w_ech.cy - h0 - 1;
              current = 0;
            }
          else
            {
              h1 = -nlines;
              h0 = w_ech.cy - h1 - 1;
              current = 1;
            }
          pxl = (h0 * app.text_font.cell ().cy + ml
                 + (w_rect.bottom - w_rect.top - ml
                    - (h0 + h1) * app.text_font.cell ().cy) / 2);
        }

      if (h0 < 1 || h1 < 1)
        FEsimple_error (Ecannot_split);
    }
  else
    {
      if (!nlines)
        {
          h0 = w_ech.cx / 2;
          h1 = w_ech.cx - h0 - 1;
          current = w_column - w_last_top_column < h0 ? 0 : 1;
          pxl = (w_rect.right - w_rect.left) / 2;
        }
      else
        {
          if (nlines > 0)
            {
              h0 = nlines;
              h1 = w_ech.cx - h0 - 1;
              current = 0;
            }
          else
            {
              h1 = -nlines;
              h0 = w_ech.cx - h1 - 1;
              current = 1;
            }
          pxl = (h0 * app.text_font.cell ().cx
                 + (w_rect.right - w_rect.left
                    - (h0 + h1) * app.text_font.cell ().cx) / 2);
        }
#define WINDOW_WIDTH_MIN 10
      if (h0 < WINDOW_WIDTH_MIN || h1 < WINDOW_WIDTH_MIN)
        FEsimple_error (Ecannot_split);
    }

  Window *wp = new Window (*this);
  if (w_next)
    w_next->w_prev = wp;
  wp->w_next = w_next;
  wp->w_prev = this;
  w_next = wp;

  if (!verticalp)
    {
      wp->w_rect = w_rect;
      wp->w_order = w_order;

      w_rect.bottom = w_rect.top + pxl;
      wp->w_rect.top = w_rect.bottom;

      Window *w;
      for (w = app.active_frame.windows; w->w_next; w = w->w_next)
        if (w != wp && w->w_rect.top == wp->w_rect.top)
          {
            w_order.bottom = w->w_order.top;
            wp->w_order.top = w->w_order.top;
            break;
          }

      if (!w->w_next)
        {
          int y, o;
          for (w = app.active_frame.windows, y = o = 0; w->w_next; w = w->w_next)
            if (w->w_rect.top < wp->w_rect.top && w->w_rect.top > y)
              {
                y = w->w_rect.top;
                o = w->w_order.top;
              }
          w_order.bottom = o + 1;
          wp->w_order.top = o + 1;
          for (w = app.active_frame.windows; w->w_next; w = w->w_next)
            {
              if (w != wp && w->w_order.top > o)
                w->w_order.top++;
              if (w != this && w->w_order.bottom > o)
                w->w_order.bottom++;
            }
        }
    }
  else
    {
      wp->w_rect = w_rect;
      wp->w_order = w_order;

      w_rect.right = w_rect.left + pxl;
      wp->w_rect.left = w_rect.right;

      Window *w;
      for (w = app.active_frame.windows; w->w_next; w = w->w_next)
        if (w != wp && w->w_rect.left == wp->w_rect.left)
          {
            w_order.right = w->w_order.left;
            wp->w_order.left = w->w_order.left;
            break;
          }

      if (!w->w_next)
        {
          int x, o;
          for (w = app.active_frame.windows, x = o = 0; w->w_next; w = w->w_next)
            if (w->w_rect.left < wp->w_rect.left && w->w_rect.left > x)
              {
                x = w->w_rect.left;
                o = w->w_order.left;
              }
          w_order.right = o + 1;
          wp->w_order.left = o + 1;
          for (w = app.active_frame.windows; w->w_next; w = w->w_next)
            {
              if (w != wp && w->w_order.left > o)
                w->w_order.left++;
              if (w != this && w->w_order.right > o)
                w->w_order.right++;
            }
        }
    }

  if (current)
    wp->set_window ();

  compute_geometry ();
  wp->change_color ();
  Buffer::maybe_modify_buffer_bar ();
}


void
Window::close ()
{
  xwindow_wp (lwp) = 0;

  for (WindowConfiguration *wc = WindowConfiguration::wc_chain; wc; wc = wc->wc_prev)
    for (WindowConfiguration::Data *d = wc->wc_data, *de = d + wc->wc_nwindows; d < de; d++)
      if (d->wp == this)
        {
          w_next = app.active_frame.reserved;
          app.active_frame.reserved = this;
          return;
        }

  w_next = app.active_frame.deleted;
  app.active_frame.deleted = this;
}

void
Window::delete_other_windows ()
{
  if (minibuffer_window_p ())
    return;

  Window *mini = minibuffer_window ();

  int f = 0;
  for (Window *wp = app.active_frame.windows, *next; wp; wp = next)
    {
      next = wp->w_next;
      if (wp != this && wp != mini)
        {
          wp->save_buffer_params ();
          wp->close ();
          f = 1;
        }
    }
  if (!f)
    return;

  app.active_frame.windows = this;
  set_window ();
  w_prev = 0;
  w_next = mini;
  mini->w_prev = this;
  mini->w_next = 0;

  w_order.left = 0;
  w_order.right = 1;
  w_order.top = 0;
  w_order.bottom = 1;

  compute_geometry ();
  Buffer::maybe_modify_buffer_bar ();
}


int
Window::find_resizeable_edge (LONG RECT::*edge1, LONG RECT::*edge2,
                              LONG RECT::*match1, LONG RECT::*match2) const
{
  int n = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!wp->minibuffer_window_p () && wp->w_order.*edge1 == w_order.*edge2)
      {
        if (wp->w_order.*match1 == w_order.*match1)
          n++;
        if (wp->w_order.*match2 == w_order.*match2)
          n++;
      }
  return n == 2;
}

int
Window::find_resizeable_edges () const
{
  int f = 0;
  if (find_resizeable_edge (&RECT::right, &RECT::left, &RECT::top, &RECT::bottom))
    f |= RE_LEFT;
  if (find_resizeable_edge (&RECT::left, &RECT::right, &RECT::top, &RECT::bottom))
    f |= RE_RIGHT;
  if (find_resizeable_edge (&RECT::bottom, &RECT::top, &RECT::left, &RECT::right))
    f |= RE_TOP;
  if (find_resizeable_edge (&RECT::top, &RECT::bottom, &RECT::left, &RECT::right))
    f |= RE_BOTTOM;
  return f;
}

void
Window::resize_edge (LONG RECT::*edge1, LONG RECT::*edge2,
                     LONG RECT::*match1, LONG RECT::*match2) const
{
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!wp->minibuffer_window_p ()
        && wp->w_order.*edge1 == w_order.*edge2
        && wp->w_order.*match1 >= w_order.*match1
        && wp->w_order.*match2 <= w_order.*match2)
      {
        wp->w_order.*edge1 = w_order.*edge1;
        wp->w_rect.*edge1 = w_rect.*edge1;
      }

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!wp->minibuffer_window_p () && wp->w_order.*edge2 == w_order.*edge2)
      return;

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (!wp->minibuffer_window_p ())
      {
        if (wp->w_order.*edge2 > w_order.*edge2)
          (wp->w_order.*edge2)--;
        if (wp->w_order.*edge1 > w_order.*edge2)
          (wp->w_order.*edge1)--;
      }
}

void
Window::resize_edge (int f) const
{
  if (f & RE_LEFT)
    resize_edge (&RECT::right, &RECT::left, &RECT::top, &RECT::bottom);
  else if (f & RE_RIGHT)
    resize_edge (&RECT::left, &RECT::right, &RECT::top, &RECT::bottom);
  else if (f & RE_TOP)
    resize_edge (&RECT::bottom, &RECT::top, &RECT::left, &RECT::right);
  else if (f & RE_BOTTOM)
    resize_edge (&RECT::top, &RECT::bottom, &RECT::left, &RECT::right);
}

Window *
Window::find_point_window (POINT &p)
{
  Window *wp;
  for (wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (PtInRect (&wp->w_rect, p))
      break;
  return wp;
}

Window *
Window::find_scr_point_window (const POINT &pt, int ml, int *in_ml)
{
  Window *wp;
  for (wp = app.active_frame.windows; wp; wp = wp->w_next)
    {
      RECT r;
      GetWindowRect (wp->hwnd(), &r);
      if (PtInRect (&r, pt))
        {
          if (in_ml)
            *in_ml = 0;
          break;
        }
      if (ml && wp->hwnd_ml())
        {
          GetWindowRect (wp->hwnd_ml(), &r);
          if (PtInRect (&r, pt))
            {
              if (in_ml)
                *in_ml = 1;
              break;
            }
        }
    }
  return wp;
}

int
Window::delete_window ()
{
  if (minibuffer_window_p ())
    return 0;

  Window *can;
  int f;

  if (!w_prev)
    {
      can = w_next;
      if (can->minibuffer_window_p ())
        FEsimple_error (Eonly_one_window);
      f = find_resizeable_edges ();
      if (!f)
        return 0;
      can->w_prev = 0;
      app.active_frame.windows = can;
    }
  else
    {
      f = find_resizeable_edges ();
      if (!f)
        return 0;
      can = w_prev;
      can->w_next = w_next;
      if (w_next)
        w_next->w_prev = can;
    }

  POINT op;
  op.x = w_rect.left + caret_x ();
  op.y = w_rect.top + caret_y ();

  resize_edge (f);
  save_buffer_params ();
  close ();
  Window *wp = find_point_window (op);
  if (!wp || !wp->w_bufp)
    wp = can;
  wp->set_window ();
  // 消した側の境界番号が宙に浮くので詰める (src/core/window-config.cc)。
  compact_orders ();
  compute_geometry ();
  Buffer::maybe_modify_buffer_bar ();
  return 1;
}




lisp
Fminibuffer_window ()
{
  return Window::minibuffer_window ()->lwp;
}







lisp
Fscreen_width ()
{
  return make_fixnum (app.active_frame.size.cx / app.text_font.cell ().cx);
}

lisp
Fscreen_height ()
{
  return make_fixnum (app.active_frame.size.cy / app.text_font.cell ().cy);
}

lisp
Fwindow_height (lisp window)
{
  int h = (Window::coerce_to_window (window)->w_clsize.cy
           / app.text_font.cell ().cy);
  return make_fixnum (max (h, 1));
}

lisp
Fwindow_width (lisp window)
{
  int w = ((Window::coerce_to_window (window)->w_clsize.cx
            - app.text_font.cell ().cx / 2)
           / app.text_font.cell ().cx);
  return make_fixnum (max (w, 1));
}

lisp
Fwindow_lines (lisp window)
{
  int h = (Window::coerce_to_window (window)->w_clsize.cy
           / app.text_font.cell ().cy);
  return make_fixnum (max (h, 1));
}

lisp
Fwindow_columns (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  int w = ((wp->w_clsize.cx - app.text_font.cell ().cx / 2)
           / app.text_font.cell ().cx);
  if (wp->flags () & Window::WF_LINE_NUMBER)
    w -= Window::LINENUM_COLUMNS + 1;
  if (wp->flags () & Window::WF_FOLD_MARK
      && wp->w_bufp
      && wp->w_bufp->b_fold_mode == Buffer::FOLD_WINDOW)
    w--;
  return make_fixnum (max (w, 1));
}



lisp
Fget_window_handle (lisp window)
{
#ifdef _WIN64
  if (!window || window == Qnil)
    return make_integer ((int64_t)(intptr_t)get_toplevel_window ());
  return make_integer ((int64_t)(intptr_t)Window::coerce_to_window (window)->hwnd());
#else
  if (!window || window == Qnil)
    return make_fixnum (long (get_toplevel_window ()));
  return make_fixnum (long (Window::coerce_to_window (window)->hwnd()));
#endif
}

int
Window::find_horiz_order (int y)
{
  int y0 = y;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    {
      if (wp->w_rect.top > y && (y0 == y || wp->w_rect.top < y0))
        y0 = wp->w_rect.top;
      if (wp->w_rect.bottom > y && (y0 == y || wp->w_rect.bottom < y0))
        y0 = wp->w_rect.bottom;
    }
  return y == y0 ? -1 : y0;
}

void
Window::change_horiz_size (int bottom, int xmin, int xmax)
{
  int obottom = w_rect.bottom;
  if (obottom == bottom)
    return;

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.left < xmax && wp->w_rect.right > xmin)
      {
        if (wp->w_rect.top == obottom)
          wp->w_rect.top = bottom;
        if (wp->w_rect.bottom == obottom)
          wp->w_rect.bottom = bottom;
      }

  for (int y = find_horiz_order (-1), order = 0;
       y >= 0; y = find_horiz_order (y), order++)
    for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
      {
        if (wp->w_rect.top == y)
          wp->w_order.top = order;
        if (wp->w_rect.bottom == y)
          wp->w_order.bottom = order;
      }

  compute_geometry ();
}

int
Window::find_vert_order (int x)
{
  int x0 = x;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    {
      if (wp->w_rect.left > x && (x0 == x || wp->w_rect.left < x0))
        x0 = wp->w_rect.left;
      if (wp->w_rect.right > x && (x0 == x || wp->w_rect.right < x0))
        x0 = wp->w_rect.right;
    }
  return x == x0 ? -1 : x0;
}

void
Window::change_vert_size (int right, int ymin, int ymax)
{
  int oright = w_rect.right;
  if (oright == right)
    return;

  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.top < ymax && wp->w_rect.bottom > ymin)
      {
        if (wp->w_rect.left == oright)
          wp->w_rect.left = right;
        if (wp->w_rect.right == oright)
          wp->w_rect.right = right;
      }

  for (int x = find_vert_order (-1), order = 0;
       x >= 0; x = find_vert_order (x), order++)
    for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
      {
        if (wp->w_rect.left == x)
          wp->w_order.left = order;
        if (wp->w_rect.right == x)
          wp->w_order.right = order;
      }

  compute_geometry ();
}

int
Window::enlarge_window_horiz (int n)
{
  Window *wp1 = find_horiz_window (&RECT::left);
  Window *wp2 = find_horiz_window (&RECT::right);
  if (!wp1 || !wp2)
    return 0;
  int goal = w_rect.bottom + n * app.text_font.cell ().cy;
  if (goal < get_horiz_min (wp1->w_rect.left, wp2->w_rect.right)
      || goal > get_horiz_max (wp1->w_rect.left, wp2->w_rect.right))
    return 0;
  change_horiz_size (goal, wp1->w_rect.left, wp2->w_rect.right);
  return 1;
}

int
Window::enlarge_window_vert (int n)
{
  Window *wp1 = find_vert_window (&RECT::top);
  Window *wp2 = find_vert_window (&RECT::bottom);
  if (!wp1 || !wp2)
    return 0;
  int goal = w_rect.right + n * app.text_font.cell ().cx;
  if (goal < get_vert_min (wp1->w_rect.top, wp2->w_rect.bottom)
      || goal > get_vert_max (wp1->w_rect.top, wp2->w_rect.bottom))
    return 0;
  change_vert_size (goal, wp1->w_rect.top, wp2->w_rect.bottom);
  return 1;
}

int
Window::enlarge_window (int n, int side)
{
  if (!n)
    return 1;
  if (!side)
    {
      Window *wp1, *wp2;
      for (wp1 = app.active_frame.windows; wp1; wp1 = wp1->w_next)
        if (wp1->w_rect.bottom == w_rect.top
            && wp1->w_rect.left < w_rect.right
            && wp1->w_rect.right > w_rect.left)
          break;
      for (wp2 = app.active_frame.windows; wp2; wp2 = wp2->w_next)
        if (wp2->w_rect.top == w_rect.bottom
            && wp2->w_rect.left < w_rect.right
            && wp2->w_rect.right > w_rect.left)
          break;
      return ((n < 0 && wp1 && wp2 && !wp2->w_next
               && wp1->enlarge_window_horiz (-n))
              || enlarge_window_horiz (n)
              || (wp1 && wp1->enlarge_window_horiz (-n)));
    }
  else
    {
      if (enlarge_window_vert (n))
        return 1;
      Window *wp;
      for (wp = app.active_frame.windows; wp; wp = wp->w_next)
        if (wp->w_rect.right == w_rect.left
            && wp->w_rect.top < w_rect.bottom
            && wp->w_rect.bottom > w_rect.top)
          break;
      return wp && wp->enlarge_window_vert (-n);
    }
}


Window *
Window::find_point_window (const POINT &point, int &vert)
{
  if (app.active_frame.windows)
    for (Window *wp = app.active_frame.windows; wp->w_next; wp = wp->w_next)
      if (PtInRect (&wp->w_rect, point))
        {
          if (point.x >= wp->w_rect.right - (FRAME_WIDTH + 1))
            vert = 1;
          else if (point.y >= wp->w_rect.bottom - (FRAME_WIDTH + 1))
            vert = 0;
          else
            continue;
          return wp;
        }
  return 0;
}

int
frame_window_setcursor (HWND hwnd, WPARAM, LPARAM lparam)
{
  if (LOWORD (lparam) == HTCLIENT)
    {
      POINT point;
      GetCursorPos (&point);
      ScreenToClient (hwnd, &point);
      int vert;
      if (Window::find_point_window (point, vert))
        {
          SetCursor (vert ? sysdep.hcur_sizewe : sysdep.hcur_sizens);
          return 1;
        }
    }
  return 0;
}

Window *
Window::find_resizeable_window (LONG RECT::*target,
                                LONG RECT::*emin, LONG RECT::*emax,
                                LONG RECT::*edge1, LONG RECT::*edge2) const
{
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp != this && wp->w_rect.*edge1 == w_rect.*edge2)
      {
        if (wp->w_rect.*target == w_rect.*target)
          return wp;
        if (wp->w_rect.*emin < w_rect.*target && wp->w_rect.*emax > w_rect.*target)
          return wp->find_resizeable_window (target, emin, emax, edge2, edge1);
      }
  return 0;
}

inline Window *
Window::find_horiz_window (LONG RECT::*target) const
{
  return find_resizeable_window (target, &RECT::left, &RECT::right,
                                 &RECT::top, &RECT::bottom);
}

inline Window *
Window::find_vert_window (LONG RECT::*target) const
{
  return find_resizeable_window (target, &RECT::top, &RECT::bottom,
                                 &RECT::left, &RECT::right);
}

int
Window::get_horiz_min (int xmin, int xmax) const
{
  int y = w_rect.top;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.bottom == w_rect.bottom
        && wp->w_rect.left < xmax && wp->w_rect.right > xmin)
      y = max (y, int (wp->w_rect.top));
  y += (app.modeline_param.m_height + 4 + app.text_font.cell ().cy
        + sysdep.edge.cy + FRAME_WIDTH);
  if (!minibuffer_window_p () && flags () & WF_RULER)
    y += RULER_HEIGHT;
  return min (y, int (w_rect.bottom));
}

int
Window::get_horiz_max (int xmin, int xmax) const
{
  Window *mini = minibuffer_window ();
  int y = mini->w_rect.bottom;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.top == w_rect.bottom
        && wp->w_rect.left < xmax && wp->w_rect.right > xmin)
      y = min (y, int (wp->w_rect.bottom));
  if (y == mini->w_rect.bottom)
    y -= app.text_font.cell ().cy + sysdep.edge.cy;
  else
    {
      y -= (app.modeline_param.m_height + 4 + app.text_font.cell ().cy
            + sysdep.edge.cy + FRAME_WIDTH);
      if (flags () & WF_RULER)
        y -= RULER_HEIGHT;
    }
  return y;
}

int
Window::get_vert_min (int ymin, int ymax) const
{
  int x = w_rect.left;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.right == w_rect.right
        && wp->w_rect.top < ymax && wp->w_rect.bottom > ymin)
      x = max (x, int (wp->w_rect.left));
  x += app.text_font.cell ().cx * WINDOW_WIDTH_MIN;
  return min (x, int (w_rect.right));
}

int
Window::get_vert_max (int ymin, int ymax) const
{
  int x = app.active_frame.size.cx;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_rect.left == w_rect.right
        && wp->w_rect.top < ymax && wp->w_rect.bottom > ymin)
      x = min (x, int (wp->w_rect.right));
  x -= app.text_font.cell ().cx * WINDOW_WIDTH_MIN;
  return x;
}

static void
paint_resize_line (HWND hwnd, const RECT &cr, int vert)
{
  RECT r = cr;
  if (vert)
    r.left -= FRAME_WIDTH;
  else
    r.top -= FRAME_WIDTH;
  MapWindowPoints (hwnd, get_toplevel_window (), (POINT *)&r, 2);
  HDC hdc = GetDC (get_toplevel_window ());
  HBITMAP hbm = LoadBitmap (app.hinst, MAKEINTRESOURCE (IDB_CHECK));
  HBRUSH hbr = CreatePatternBrush (hbm);
  DeleteObject (hbm);
  HGDIOBJ obr = SelectObject (hdc, hbr);
  PatBlt (hdc, r.left, r.top, r.right - r.left, r.bottom - r.top, PATINVERT);
  SelectObject (hdc, obr);
  DeleteObject (hbr);
  ReleaseDC (get_toplevel_window (), hdc);
}

int
frame_window_resize (Window *wp, HWND hwnd, const POINT &point, int vert)
{
  int nmin, nmax;
  int d;
  RECT r;
  if (vert)
    {
      Window *top = wp->find_vert_window (&RECT::top);
      if (!top)
        return 0;
      Window *bottom = wp->find_vert_window (&RECT::bottom);
      if (!bottom)
        return 0;
      nmin = wp->get_vert_min (top->w_rect.top, bottom->w_rect.bottom);
      nmax = wp->get_vert_max (top->w_rect.top, bottom->w_rect.bottom);
      r.top = top->w_rect.top;
      r.bottom = bottom->w_rect.bottom;
      r.left = r.right = wp->w_rect.right;
      d = wp->w_rect.right - point.x;
    }
  else
    {
      Window *left = wp->find_horiz_window (&RECT::left);
      if (!left)
        return 0;
      Window *right = wp->find_horiz_window (&RECT::right);
      if (!right)
        return 0;
      nmin = wp->get_horiz_min (left->w_rect.left, right->w_rect.right);
      nmax = wp->get_horiz_max (left->w_rect.left, right->w_rect.right);
      r.left = left->w_rect.left;
      r.right = right->w_rect.right;
      r.top = r.bottom = wp->w_rect.bottom;
      d = wp->w_rect.bottom - point.y;
    }
  paint_resize_line (hwnd, r, vert);
  SetCapture (hwnd);

  MSG msg;
  while (1)
    {
      if (!GetMessage (&msg, 0, 0, 0))
        {
          PostQuitMessage (0);
          break;
        }
      if (GetCapture () != hwnd)
        break;
      switch (msg.message)
        {
        case WM_MOUSEMOVE:
          paint_resize_line (hwnd, r, vert);
          if (vert)
            r.left = r.right = min (max (nmin,
                                         short (LOWORD (msg.lParam)) + d),
                                    nmax);
          else
            r.top = r.bottom = min (max (nmin,
                                         short (HIWORD (msg.lParam)) + d),
                                    nmax);
          paint_resize_line (hwnd, r, vert);
          break;

        case WM_LBUTTONUP:
          ReleaseCapture ();
          paint_resize_line (hwnd, r, vert);
          if (vert)
            wp->change_vert_size (min (max (nmin, short (LOWORD (msg.lParam)) + d), nmax),
                              r.top, r.bottom);
          else
            wp->change_horiz_size (min (max (nmin, short (HIWORD (msg.lParam)) + d), nmax),
                               r.left, r.right);
          refresh_screen (0);
          return 1;

        case WM_CANCELMODE:
          ReleaseCapture ();
          goto done;

        case WM_KEYDOWN:
          break;

        default:
          DispatchMessage (&msg);
          break;
        }
    }
done:
  paint_resize_line (hwnd, r, vert);
  return 1;
}

int
frame_window_resize (HWND hwnd, LPARAM lparam, const POINT *real)
{
  POINT point;
  point.x = short (LOWORD (lparam));
  point.y = short (HIWORD (lparam));
  int vert;
  Window *wp = Window::find_point_window (point, vert);
  if (!wp)
    return 0;
  return frame_window_resize (wp, hwnd, real ? *real : point, vert);
}


/* 表示フラグ (`set-window-flags` / `set-local-window-flags`) の Win32 側。
   **Lisp から見える 4 つの入口は src/core/window-config.cc へ移した**
   (フラグの意味は `Window::flags ()` の性質で、フロントエンドの性質では
   ない)。ここに残るのは、フラグが変わったときに**画面の作りを変える**部分
   だけである。宣言は src/core/fns.h。 */

int
window_update_scroll_bars (Window *wp, int df)
{
  int recompute = 0;
  if (df & Window::WF_VSCROLL_BAR)
    {
      wp->update_vscroll_bar ();
      recompute = 1;
    }
  if (df & Window::WF_HSCROLL_BAR)
    {
      wp->update_hscroll_bar ();
      recompute = 1;
    }
  return recompute;
}

int
window_default_flags_changed (int df)
{
  set_bgmode ();
  if (df & Window::WF_FUNCTION_BAR)
    {
      /* **ファンクションバーはウィンドウの外にある。** 作り直すのは
         トップレベル全体で、`compute_geometry` では足りない。 */
      recalc_toplevel ();
      return 1;
    }
  return 0;
}

lisp
Fsi_instance_number ()
{
  int i = xyzzy_instance::instnum ();
  return i >= 0 ? make_fixnum (i) : Qnil;
}

static void
activate_xyzzy_window (HWND hwnd)
{
  Fbegin_wait_cursor ();
  DWORD_PTR r;
  int ok = SendMessageTimeout (hwnd, WM_NULL, 0, 0, SMTO_ABORTIFHUNG, 1000, &r);
  Fend_wait_cursor ();
  if (!ok)
    FEsimple_error (Etarget_xyzzy_is_busy);
  ForceSetForegroundWindow (hwnd);
  PostMessage (hwnd, WM_PRIVATE_FOREGROUND, 0, 0);
}

static lisp
next_xyzzy_window (int next)
{
  int i = xyzzy_instance::instnum ();
  if (i < 0)
    i = -1;
  xyzzy_hwnd xh (get_toplevel_window ());
  HWND hwnd = next ? xh.next (i) : xh.prev (i);
  if (!hwnd)
    return Qnil;
  activate_xyzzy_window (hwnd);
  return Qt;
}

lisp
Fnext_xyzzy_window ()
{
  return next_xyzzy_window (1);
}

lisp
Fprevious_xyzzy_window ()
{
  return next_xyzzy_window (0);
}

lisp
Fcount_xyzzy_instance ()
{
  xyzzy_hwnd xh (get_toplevel_window ());
  return make_fixnum (xh.count ());
}

lisp
Flist_xyzzy_windows ()
{
  xyzzy_hwnd xh (get_toplevel_window ());
  int i = -1;
  lisp p = Qnil;
  while (1)
    {
      int o = i;
      HWND hwnd = xh.next (i);
      if (!hwnd || i <= o)
        break;
      wchar_t wbuf[256];
      int got = GetWindowTextW (hwnd, wbuf, 256);
      if (got)
        /* Phase 2-5: hand the wide title straight to make_string. */
        p = xcons (xcons (make_fixnum (i),
                          make_string ((const Char *)wbuf, got)),
                   p);
    }
  return Fnreverse (p);
}

lisp
Factivate_xyzzy_window (lisp x)
{
  int i = fixnum_value (x);
  int o = i--;
  xyzzy_hwnd xh (get_toplevel_window ());
  HWND hwnd = xh.next (i);
  if (!hwnd || i != o)
    return Qnil;
  activate_xyzzy_window (hwnd);
  return Qt;
}




#ifndef SPI_GETFOREGROUNDLOCKTIMEOUT
#define SPI_GETFOREGROUNDLOCKTIMEOUT 0x2000
#define SPI_SETFOREGROUNDLOCKTIMEOUT 0x2001
#endif

void
ForceSetForegroundWindow (HWND hwnd)
{
  DWORD timeout;
  if (sysdep.version () >= Sysdep::WIN98_VERSION
      && SystemParametersInfo (SPI_GETFOREGROUNDLOCKTIMEOUT, 0, &timeout, 0))
    {
      SystemParametersInfo (SPI_SETFOREGROUNDLOCKTIMEOUT, 0, 0, 0);
      int ok = SetForegroundWindow (hwnd);
      SystemParametersInfo (SPI_SETFOREGROUNDLOCKTIMEOUT, 0, (void *)timeout, 0);
      if (!ok)
        {
          HWND hwnd_fg = GetForegroundWindow ();
          DWORD_PTR r;
          if (hwnd_fg && SendMessageTimeout (hwnd_fg, WM_NULL, 0, 0,
                                             SMTO_ABORTIFHUNG | SMTO_BLOCK, 100, &r))
            {
              DWORD id = GetWindowThreadProcessId (hwnd_fg, 0);
              AttachThreadInput (GetCurrentThreadId (), id, 1);
              SetForegroundWindow (hwnd);
              AttachThreadInput (GetCurrentThreadId (), id, 0);
            }
        }
    }
  else
    SetForegroundWindow (hwnd);
}

static void CALLBACK
auto_scroll (int n, void *arg)
{
  Window *wp = (Window *)arg;
  if (wp->scroll_window (n))
    refresh_screen (1);
}

lisp
Fbegin_auto_scroll ()
{
  POINT p;
  GetCursorPos (&p);
  Window *wp = Window::find_scr_point_window (p, 0, 0);
  if (!wp)
    return Qnil;
  Buffer *bp = wp->w_bufp;
  if (!bp
      || (bp->b_fold_columns == Buffer::FOLD_NONE
          ? bp->count_lines ()
          : bp->folded_count_lines ()) <= 1
      || !begin_auto_scroll (wp->hwnd(), p, auto_scroll, wp))
    return Qnil;
  return Qt;
}

void
Window::calc_ruler_rect (RECT &r) const
{
  POINT p = {0, 0};
  MapWindowPoints (hwnd(), g_active_frame_hwnd, &p, 1);
  r.left = p.x + app.text_font.cell ().cx / 2;
  if (flags () & WF_LINE_NUMBER)
    r.left += (LINENUM_COLUMNS + 1) * app.text_font.cell ().cx;
  r.top = p.y - RULER_HEIGHT;
  r.right = p.x + w_clsize.cx + RIGHT_PADDING - 1;
  r.bottom = p.y - 3;
}

inline void
Window::calc_ruler_box (const RECT &r, RECT &br) const
{
  br.left = r.left + (w_ruler_column - w_ruler_top_column) * app.text_font.cell ().cx;
  br.right = br.left + app.text_font.cell ().cx;
  br.top = r.top;
  br.bottom = r.bottom;
}

void
Window::paint_ruler_box (Painter &painter, const RECT &r) const
{
  RECT br;
  calc_ruler_box (r, br);

  br.right--;
  painter.draw_hline (br.left, br.right, br.top, win32_sysdep.window_text);
  painter.draw_vline (br.left, br.top, br.bottom, win32_sysdep.window_text);
  painter.draw_vline (br.right, br.top, br.bottom, win32_sysdep.window_text);
  br.bottom--;
  painter.draw_hline (br.left, br.right, br.bottom, win32_sysdep.window_text);
  br.left++;
  br.top++;
  painter.draw_hline (br.left, br.right, br.top, win32_sysdep.btn_highlight);
  painter.draw_vline (br.left, br.top, br.bottom, win32_sysdep.btn_highlight);
  br.left++;
  br.top++;
  br.right--;
  painter.draw_vline (br.right, br.top, br.bottom, win32_sysdep.btn_shadow);
  br.bottom--;
  painter.draw_hline (br.left, br.right, br.bottom, win32_sysdep.btn_shadow);
  painter.fill_rect (br.left, br.top, br.right - br.left, br.bottom - br.top, win32_sysdep.btn_face);
}

inline void
Window::paint_ruler (Painter &painter, const RECT &r, int x, int y, int column) const
{
  if (!(column % 10))
    {
      wchar_t wbuf[32];
      int l = swprintf (wbuf, 32, L"%d", column);
      painter.draw_text_chars (x - l * win32_sysdep.ruler_ext.cx / 2, r.top,
                               (const Char *)wbuf, l, win32_sysdep.window_text, 0,
                               PFONT_RULER, &r, false);
    }
  else if (!(column % 5))
    painter.draw_vline (x, y - 2, y + 2, win32_sysdep.window_text);
  else
    painter.draw_vline (x, y - 1, y + 1, win32_sysdep.window_text);
}

void
Window::paint_ruler (Painter &painter) const
{
  if (w_ruler_top_column < 0)
    return;

  RECT r;

  GetWindowRect (hwnd(), &r);
  MapWindowPoints (HWND_DESKTOP, g_active_frame_hwnd, (POINT *)&r, 2);
  r.bottom = r.top;
  r.top -= RULER_HEIGHT;
  painter.draw_hline (r.left, r.right - 1, r.top, win32_sysdep.btn_highlight);
  painter.draw_vline (r.left, r.top, r.bottom, win32_sysdep.btn_highlight);
//  painter.draw_hline (r.left, r.right, r.bottom, win32_sysdep.btn_shadow);
  painter.draw_vline (r.right - 1, r.top, r.bottom, win32_sysdep.btn_shadow);

  calc_ruler_rect (r);

  if (w_ruler_fold_column == Buffer::FOLD_NONE)
    painter.fill_rect (r.left, r.top, r.right - r.left, r.bottom - r.top, win32_sysdep.window);
  else if (w_ruler_fold_column <= w_ruler_top_column)
    painter.fill_rect (r.left, r.top, r.right - r.left, r.bottom - r.top, win32_sysdep.btn_shadow);
  else
    {
      int x = r.left + ((w_ruler_fold_column - w_ruler_top_column)
                        * app.text_font.cell ().cx);
      if (x < r.right)
        {
          painter.fill_rect (r.left, r.top, x - r.left, r.bottom - r.top, win32_sysdep.window);
          painter.fill_rect (x, r.top, r.right - x, r.bottom - r.top, win32_sysdep.btn_shadow);
        }
      else
        painter.fill_rect (r.left, r.top, r.right - r.left, r.bottom - r.top, win32_sysdep.window);
    }

  int y = (r.top + r.bottom) / 2;
  for (int x = r.left + app.text_font.cell ().cx / 2, column = w_ruler_top_column + 1;
       x < r.right; x += app.text_font.cell ().cx, column++)
    paint_ruler (painter, r, x, y, column);

  if (w_ruler_column >= 0)
    paint_ruler_box (painter, r);
}

void
Window::erase_ruler (Painter &painter, const RECT &r) const
{
  RECT br;
  calc_ruler_box (r, br);

  if (w_ruler_fold_column == Buffer::FOLD_NONE
      || w_ruler_column < w_ruler_fold_column)
    painter.fill_rect (br.left, br.top, br.right - br.left, br.bottom - br.top, win32_sysdep.window);
  else
    painter.fill_rect (br.left, br.top, br.right - br.left, br.bottom - br.top, win32_sysdep.btn_shadow);

  int y = (r.top + r.bottom) / 2;
  int x = (r.left + app.text_font.cell ().cx / 2
           + (w_ruler_column - w_ruler_top_column) * app.text_font.cell ().cx);
  int column = w_ruler_column + 1;
  paint_ruler (painter, br, x, y, column);

  int rem = column % 10;
  if (rem)
    {
      column -= rem;
      x -= rem * app.text_font.cell ().cx;
      if (column && x >= r.left)
        paint_ruler (painter, br, x, y, column);
      column += 10;
      x += 10 * app.text_font.cell ().cx;
      if (x < r.right)
        paint_ruler (painter, br, x, y, column);
    }
}

void
Window::update_ruler ()
{
  if (w_disp_flags & WDF_WINDOW
      || w_ruler_top_column != w_top_column
      || w_ruler_fold_column != w_bufp->b_fold_columns)
    {
      w_ruler_top_column = w_top_column;
      w_ruler_column = w_column;
      w_ruler_fold_column = w_bufp->b_fold_columns;
      HDC hdc = GetDC (g_active_frame_hwnd);
      Win32Painter painter (hdc, 0);
      paint_ruler (painter);
      ReleaseDC (g_active_frame_hwnd, hdc);
    }
  else if (w_ruler_column != w_column)
    {
      HDC hdc = GetDC (g_active_frame_hwnd);
      RECT r;
      calc_ruler_rect (r);
      Win32Painter painter (hdc, 0);
      if (w_ruler_column >= 0)
        erase_ruler (painter, r);
      w_ruler_column = w_column;
      paint_ruler_box (painter, r);
      ReleaseDC (g_active_frame_hwnd, hdc);
    }
}

void
Window::point2window_pos (point_t point, POINT &p) const
{
  long linenum, column;

  point = max (min (point, w_bufp->b_contents.p2),
               w_bufp->b_contents.p1);
  if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
    {
      Point p;
      w_bufp->set_point (p, point);
      linenum = w_bufp->point_linenum (p);
      column = w_bufp->point_column (p);
    }
  else
    linenum = w_bufp->folded_point_linenum_column (point, &column);

  p.x = column - w_last_top_column + w_bufp->b_prompt_columns;
  if (w_last_flags & Window::WF_LINE_NUMBER)
    p.x += Window::LINENUM_COLUMNS + 1;
  p.x = min (max (0L, p.x), w_ch_max.cx);
  p.x *= app.text_font.cell ().cx;
  p.x += app.text_font.cell ().cx / 2;

  p.y = linenum - w_last_top_linenum;
  p.y = min (max (0L, p.y), w_ch_max.cy);
  p.y *= app.text_font.cell ().cy;
}
