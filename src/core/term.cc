// VT100/xterm terminal emulator — platform-independent core
// Parses escape sequences from pty output and maintains a virtual screen.

#include "stdafx.h"
#include "ed.h"
#include "term.h"

#include <string.h>
#include <ctype.h>

/* 文字幅は eaw.cc の unicode_width() を使う。以前ここに term_wcwidth という
   同じ用途の表が別にあったが、BMP しか見ておらず buffer 表示側とも食い違って
   いたので消した。 */
#include "eaw.h"

// ============================================================
// Construction / destruction
// ============================================================

void
Terminal::clear_cell (TermCell *c)
{
  c->ch = 0; c->fg = t_fg; c->bg = t_bg; c->attrs = 0; c->wide = 0;
}

void
Terminal::clear_cell_default (TermCell *c)
{
  c->ch = 0; c->fg = TCOLOR_DEFAULT; c->bg = TCOLOR_DEFAULT;
  c->attrs = 0; c->wide = 0;
}

Terminal::Terminal (int rows, int cols)
    : t_rows (rows), t_cols (cols),
      t_cur_row (0), t_cur_col (0),
      t_scroll_top (0), t_scroll_bottom (rows - 1),
      t_saved_row (0), t_saved_col (0),
      t_saved_fg (TCOLOR_DEFAULT), t_saved_bg (TCOLOR_DEFAULT),
      t_saved_attrs (0),
      t_fg (TCOLOR_DEFAULT), t_bg (TCOLOR_DEFAULT), t_attrs (0),
      t_state (TS_NORMAL), t_nparam (0), t_intermediate (0),
      t_utf8_acc (0), t_utf8_remain (0),
      t_alt_active (0), t_cursor_visible (1),
      t_app_cursor_keys (0), t_origin_mode (0),
      t_wraparound (1), t_insert_mode (0), t_pending_wrap (0),
      t_scrollback (0), t_scrollback_cols (cols),
      t_scrollback_count (0), t_scrollback_head (0),
      t_scrollback_offset (0),
      t_dirty (1), t_palette (0), t_osc_len (0)
{
  memset (t_param_colon, 0, sizeof t_param_colon);
  int total = rows * cols;
  t_screen = new TermCell[total];
  t_alt_screen = new TermCell[total];
  t_tabs = new uint8_t[cols];
  for (int i = 0; i < total; i++)
    clear_cell_default (&t_screen[i]);
  for (int i = 0; i < total; i++)
    clear_cell_default (&t_alt_screen[i]);
  init_tabs ();
  t_scrollback = new TermCell[SCROLLBACK_MAX * cols];
  for (int i = 0; i < SCROLLBACK_MAX * cols; i++)
    clear_cell_default (&t_scrollback[i]);
}

Terminal::~Terminal ()
{
  delete[] t_screen;
  delete[] t_alt_screen;
  delete[] t_tabs;
  delete[] t_scrollback;
  delete[] t_palette;
}

void
Terminal::init_tabs ()
{
  for (int i = 0; i < t_cols; i++)
    t_tabs[i] = (i % 8 == 0) ? 1 : 0;
}

void
Terminal::resize (int new_rows, int new_cols)
{
  int total = new_rows * new_cols;
  TermCell *ns = new TermCell[total];
  TermCell *na = new TermCell[total];

  for (int i = 0; i < total; i++)
    {
      clear_cell_default (&ns[i]);
      clear_cell_default (&na[i]);
    }

  int copy_rows = min (t_rows, new_rows);
  int copy_cols = min (t_cols, new_cols);
  for (int r = 0; r < copy_rows; r++)
    for (int c = 0; c < copy_cols; c++)
      {
        ns[r * new_cols + c] = t_screen[r * t_cols + c];
        na[r * new_cols + c] = t_alt_screen[r * t_cols + c];
      }

  delete[] t_screen;
  delete[] t_alt_screen;
  delete[] t_tabs;
  t_screen = ns;
  t_alt_screen = na;
  t_rows = new_rows;
  t_cols = new_cols;
  t_tabs = new uint8_t[new_cols];
  init_tabs ();

  t_scroll_top = 0;
  t_scroll_bottom = new_rows - 1;
  if (t_cur_row >= new_rows) t_cur_row = new_rows - 1;
  if (t_cur_col >= new_cols) t_cur_col = new_cols - 1;
  // Scrollback is invalidated on column change
  if (t_scrollback_cols != new_cols)
    scrollback_realloc ();
  t_scrollback_offset = 0;
  t_dirty = 1;
}

// ============================================================
// Screen operations
// ============================================================

void
Terminal::clear_region (int r1, int c1, int r2, int c2)
{
  for (int r = r1; r <= r2 && r < t_rows; r++)
    for (int c = (r == r1 ? c1 : 0); c <= (r == r2 ? c2 : t_cols - 1) && c < t_cols; c++)
      clear_cell (cell (r, c));
  t_dirty = 1;
}

void
Terminal::scrollback_realloc ()
{
  if (t_scrollback_cols == t_cols)
    return;
  delete[] t_scrollback;
  t_scrollback = new TermCell[SCROLLBACK_MAX * t_cols];
  for (int i = 0; i < SCROLLBACK_MAX * t_cols; i++)
    clear_cell_default (&t_scrollback[i]);
  t_scrollback_cols = t_cols;
  t_scrollback_count = 0;
  t_scrollback_head = 0;
}

void
Terminal::scrollback_push (const TermCell *row)
{
  if (!t_scrollback || t_alt_active)
    return;
  if (t_scrollback_cols != t_cols)
    scrollback_realloc ();
  memcpy (&t_scrollback[t_scrollback_head * t_cols], row, t_cols * sizeof (TermCell));
  t_scrollback_head = (t_scrollback_head + 1) % SCROLLBACK_MAX;
  if (t_scrollback_count < SCROLLBACK_MAX)
    t_scrollback_count++;
}

const TermCell *
Terminal::scrollback_line (int index) const
{
  if (index < 0 || index >= t_scrollback_count || !t_scrollback
      || t_scrollback_cols != t_cols)
    return 0;
  int pos = (t_scrollback_head - 1 - index + SCROLLBACK_MAX) % SCROLLBACK_MAX;
  return &t_scrollback[pos * t_cols];
}

void
Terminal::scrollback_scroll (int delta)
{
  t_scrollback_offset += delta;
  if (t_scrollback_offset < 0)
    t_scrollback_offset = 0;
  if (t_scrollback_offset > t_scrollback_count)
    t_scrollback_offset = t_scrollback_count;
  t_dirty = 1;
}

const TermCell *
Terminal::display_cell (int row, int col) const
{
  if (t_scrollback_offset <= 0)
    return cell_at (row, col);
  // row 0..t_rows-1 maps to scrollback or screen
  int sb_row = t_scrollback_offset - 1 - row;  // scrollback index for this display row
  if (sb_row >= 0)
    {
      const TermCell *line = scrollback_line (sb_row);
      if (line && col < t_cols)
        return &line[col];
      // fallback: empty cell
      static TermCell empty = {0, 0, 0, 0, 0};
      return &empty;
    }
  // Screen row: offset into live screen
  int screen_row = row - t_scrollback_offset;
  if (screen_row >= 0 && screen_row < t_rows)
    return cell_at (screen_row, col);
  static TermCell empty = {0, 0, 0, 0, 0};
  return &empty;
}

void
Terminal::scroll_up (int top, int bottom, int n)
{
  if (n <= 0 || top > bottom)
    return;
  if (n > bottom - top + 1)
    n = bottom - top + 1;
  // Save scrolled-out lines to scrollback (main screen, full-screen scroll region only)
  if (top == t_scroll_top && !t_alt_active)
    for (int r = top; r < top + n; r++)
      scrollback_push (cell (r, 0));
  for (int r = top; r <= bottom - n; r++)
    memcpy (cell (r, 0), cell (r + n, 0), t_cols * sizeof (TermCell));
  for (int r = bottom - n + 1; r <= bottom; r++)
    for (int c = 0; c < t_cols; c++)
      clear_cell (cell (r, c));
  t_dirty = 1;
}

void
Terminal::scroll_down (int top, int bottom, int n)
{
  if (n <= 0 || top > bottom)
    return;
  if (n > bottom - top + 1)
    n = bottom - top + 1;
  for (int r = bottom; r >= top + n; r--)
    memcpy (cell (r, 0), cell (r - n, 0), t_cols * sizeof (TermCell));
  for (int r = top; r < top + n; r++)
    for (int c = 0; c < t_cols; c++)
      clear_cell (cell (r, c));
  t_dirty = 1;
}

void
Terminal::ensure_cursor_bounds ()
{
  if (t_cur_row < 0) t_cur_row = 0;
  if (t_cur_row >= t_rows) t_cur_row = t_rows - 1;
  if (t_cur_col < 0) t_cur_col = 0;
  if (t_cur_col >= t_cols) t_cur_col = t_cols - 1;
}

// ============================================================
// Character output
// ============================================================

void
Terminal::put_char (uint32_t ucs)
{
  if (ucs == 0)
    return;

  /* TermCell は code point を持つ。以前はここで w2i() を通していた。
     w2i は Unicode → 旧 internal encoding (charset タグ付きの CP932 系)
     の表で、Phase 2 で buffer が UTF-16 になった後もターミナルだけに
     残っていた。表示側は TermCell::ch を UTF-16 code unit として描くので、
     内部コードがそのまま Unicode として解釈され、`日本語` が `芰芰芰` の
     ような無関係な漢字になっていた (0x8290 = CP932 の 2 バイトを 16bit に
     詰めた値)。さらに (ucs2_t)ucs で BMP 外が切り詰まり、絵文字は
     U+F600 付近の私用領域文字 = 豆腐になっていた。
     code point をそのまま持つ。 */
  if (ucs >= CHAR_LIMIT)
    return;
  ucs4_t ich = ucs;

  /* 幅も buffer 表示と同じ表 (eaw.cc) から引く。term.cc 独自の
     term_wcwidth は BMP しか見ていなかった。 */
  int width = unicode_width (ich);
  if (width < 1)
    width = 1;

  if (t_pending_wrap && t_wraparound)
    {
      t_cur_col = 0;
      new_line ();
      t_pending_wrap = 0;
    }

  if (t_insert_mode)
    {
      int shift = width;
      for (int c = t_cols - 1; c >= t_cur_col + shift; c--)
        *cell (t_cur_row, c) = *cell (t_cur_row, c - shift);
    }

  if (t_cur_col + width > t_cols)
    {
      if (t_wraparound)
        {
          for (int c = t_cur_col; c < t_cols; c++)
            clear_cell (cell (t_cur_row, c));
          t_cur_col = 0;
          new_line ();
        }
      else
        return;
    }

  TermCell *c = cell (t_cur_row, t_cur_col);
  c->ch = ich;
  c->fg = t_fg;
  c->bg = t_bg;
  c->attrs = t_attrs;
  c->wide = (width > 1) ? 1 : 0;

  if (width > 1 && t_cur_col + 1 < t_cols)
    {
      TermCell *c2 = cell (t_cur_row, t_cur_col + 1);
      c2->ch = 0;
      c2->fg = t_fg;
      c2->bg = t_bg;
      c2->attrs = t_attrs;
      c2->wide = 2;
    }

  t_cur_col += width;
  if (t_cur_col >= t_cols)
    {
      t_cur_col = t_cols - 1;
      t_pending_wrap = 1;
    }

  t_dirty = 1;
}

void Terminal::new_line ()
{
  if (t_cur_row == t_scroll_bottom)
    scroll_up (t_scroll_top, t_scroll_bottom, 1);
  else if (t_cur_row < t_rows - 1)
    t_cur_row++;
}

void Terminal::carriage_return () { t_cur_col = 0; t_pending_wrap = 0; }
void Terminal::backspace () { if (t_cur_col > 0) t_cur_col--; t_pending_wrap = 0; }

void
Terminal::tab ()
{
  int next = t_cur_col + 1;
  while (next < t_cols && !t_tabs[next])
    next++;
  if (next >= t_cols)
    next = t_cols - 1;
  t_cur_col = next;
  t_pending_wrap = 0;
}

void
Terminal::reverse_index ()
{
  if (t_cur_row == t_scroll_top)
    scroll_down (t_scroll_top, t_scroll_bottom, 1);
  else if (t_cur_row > 0)
    t_cur_row--;
}

// ============================================================
// SGR (Select Graphic Rendition)
// ============================================================

void
Terminal::handle_sgr ()
{
  if (t_nparam == 0)
    {
      t_fg = TCOLOR_DEFAULT; t_bg = TCOLOR_DEFAULT; t_attrs = 0;
      return;
    }

  for (int i = 0; i < t_nparam; i++)
    {
      int p = t_params[i];
      switch (p)
        {
        case 0:  t_fg = TCOLOR_DEFAULT; t_bg = TCOLOR_DEFAULT; t_attrs = 0; break;
        case 1:  t_attrs |= TATTR_BOLD; break;
        case 2:  t_attrs |= TATTR_DIM; break;
        case 3:  t_attrs |= TATTR_ITALIC; break;
        case 4:  t_attrs |= TATTR_UNDERLINE; break;
        case 7:  t_attrs |= TATTR_REVERSE; break;
        case 8:  t_attrs |= TATTR_INVISIBLE; break;
        case 9:  t_attrs |= TATTR_STRIKE; break;
        case 21: t_attrs &= ~TATTR_BOLD; break;   /* 二重下線は未対応 */
        case 22: t_attrs &= ~(TATTR_BOLD | TATTR_DIM); break;
        case 23: t_attrs &= ~TATTR_ITALIC; break;
        case 24: t_attrs &= ~TATTR_UNDERLINE; break;
        case 27: t_attrs &= ~TATTR_REVERSE; break;
        case 28: t_attrs &= ~TATTR_INVISIBLE; break;
        case 29: t_attrs &= ~TATTR_STRIKE; break;

        case 30: case 31: case 32: case 33:
        case 34: case 35: case 36: case 37:
          t_fg = TCOLOR_INDEXED | (p - 30); break;
        case 39: t_fg = TCOLOR_DEFAULT; break;

        case 40: case 41: case 42: case 43:
        case 44: case 45: case 46: case 47:
          t_bg = TCOLOR_INDEXED | (p - 40); break;
        case 49: t_bg = TCOLOR_DEFAULT; break;

        case 90: case 91: case 92: case 93:
        case 94: case 95: case 96: case 97:
          t_fg = TCOLOR_INDEXED | (p - 90 + 8); break;

        case 100: case 101: case 102: case 103:
        case 104: case 105: case 106: case 107:
          t_bg = TCOLOR_INDEXED | (p - 100 + 8); break;

        case 38: i = parse_sgr_color (i, &t_fg); break;
        case 48: i = parse_sgr_color (i, &t_bg); break;

        /* 5 (blink) / 6 (rapid blink) / 25 (blink off) / 53 (overline) /
           55 (overline off) は受け取って捨てる。属性を持たないので描画に
           影響しないが、param として食っておかないと後続が色指定に化ける。 */
        case 5: case 6: case 25: case 53: case 55: break;
        }
    }
}

/* SGR 38 / 48 の色指定を読む。i は 38/48 自身の位置。消費した最後の
   param の index を返す (呼び元の for が ++ する)。

   形式は 2 種類あり、区切りが ';' か ':' かで意味が変わる。

     38;5;n            256 色 palette
     38;2;r;g;b        24bit
     38:5:n            上と同じ (T.416 の sub-parameter 形式)
     38:2::r:g:b       T.416 の正式形。3 番目は colorspace id で空になる

   以前は `38;5;n` だけを見て、`38;2;r;g;b` は if を外れて**何もせず i も
   進めなかった**。すると続く 2, r, g, b が SGR コードとして再解釈され、
   例えば 38;2;255;100;50 は「2 → DIM、100 → 背景を明るい黒」になっていた。
   カラフルなテーマで色が全く合わないのはこれが主因。                      */
int
Terminal::parse_sgr_color (int i, term_color_t *out)
{
  if (i + 1 >= t_nparam)
    return i;
  int kind = t_params[i + 1];
  /* ':' 形式かどうかは、続く param が ':' 区切りで来たかで判る。 */
  int colon = t_param_colon[i + 1];

  if (kind == 5)
    {
      if (i + 2 >= t_nparam)
        return i + 1;
      int n = t_params[i + 2];
      if (n >= 0 && n <= 255)
        *out = TCOLOR_INDEXED | uint32_t (n);
      return i + 2;
    }

  if (kind == 2)
    {
      int base = i + 2;
      /* T.416 形式 (':') では colorspace id が 1 つ入る。r/g/b と合わせて
         4 つ続くならその先頭を colorspace として読み飛ばす。 */
      if (colon && base + 3 < t_nparam && t_param_colon[base + 3])
        base++;
      if (base + 2 >= t_nparam)
        return t_nparam - 1;
      int r = t_params[base], g = t_params[base + 1], b = t_params[base + 2];
      if (r < 0) r = 0; if (r > 255) r = 255;
      if (g < 0) g = 0; if (g > 255) g = 255;
      if (b < 0) b = 0; if (b > 255) b = 255;
      *out = TCOLOR_RGB | (uint32_t (r) << 16) | (uint32_t (g) << 8)
             | uint32_t (b);
      return base + 2;
    }

  return i + 1;
}

// ============================================================
// CSI sequence handler
// ============================================================

void
Terminal::handle_csi (int final_ch)
{
  int p0 = t_nparam > 0 ? t_params[0] : 0;
  int p1 = t_nparam > 1 ? t_params[1] : 0;

  switch (final_ch)
    {
    case 'A': // CUU
      if (p0 < 1) p0 = 1;
      t_cur_row -= p0;
      if (t_cur_row < t_scroll_top) t_cur_row = t_scroll_top;
      t_pending_wrap = 0;
      break;

    case 'B': // CUD
      if (p0 < 1) p0 = 1;
      t_cur_row += p0;
      if (t_cur_row > t_scroll_bottom) t_cur_row = t_scroll_bottom;
      t_pending_wrap = 0;
      break;

    case 'C': // CUF
      if (p0 < 1) p0 = 1;
      t_cur_col += p0;
      if (t_cur_col >= t_cols) t_cur_col = t_cols - 1;
      t_pending_wrap = 0;
      break;

    case 'D': // CUB
      if (p0 < 1) p0 = 1;
      t_cur_col -= p0;
      if (t_cur_col < 0) t_cur_col = 0;
      t_pending_wrap = 0;
      break;

    case 'E': // CNL
      if (p0 < 1) p0 = 1;
      t_cur_row += p0;
      if (t_cur_row > t_scroll_bottom) t_cur_row = t_scroll_bottom;
      t_cur_col = 0; t_pending_wrap = 0;
      break;

    case 'F': // CPL
      if (p0 < 1) p0 = 1;
      t_cur_row -= p0;
      if (t_cur_row < t_scroll_top) t_cur_row = t_scroll_top;
      t_cur_col = 0; t_pending_wrap = 0;
      break;

    case 'G': // CHA
      if (p0 < 1) p0 = 1;
      t_cur_col = p0 - 1;
      if (t_cur_col >= t_cols) t_cur_col = t_cols - 1;
      t_pending_wrap = 0;
      break;

    case 'H': case 'f': // CUP / HVP
      {
        int row = (p0 < 1 ? 1 : p0) - 1;
        int col = (p1 < 1 ? 1 : p1) - 1;
        if (t_origin_mode) row += t_scroll_top;
        if (row >= t_rows) row = t_rows - 1;
        if (col >= t_cols) col = t_cols - 1;
        t_cur_row = row; t_cur_col = col;
        t_pending_wrap = 0;
      }
      break;

    case 'J': // ED
      switch (p0)
        {
        case 0: clear_region (t_cur_row, t_cur_col, t_rows - 1, t_cols - 1); break;
        case 1: clear_region (0, 0, t_cur_row, t_cur_col); break;
        case 2: case 3: clear_region (0, 0, t_rows - 1, t_cols - 1); break;
        }
      break;

    case 'K': // EL
      switch (p0)
        {
        case 0: clear_region (t_cur_row, t_cur_col, t_cur_row, t_cols - 1); break;
        case 1: clear_region (t_cur_row, 0, t_cur_row, t_cur_col); break;
        case 2: clear_region (t_cur_row, 0, t_cur_row, t_cols - 1); break;
        }
      break;

    case 'L': // IL
      if (p0 < 1) p0 = 1;
      if (t_cur_row >= t_scroll_top && t_cur_row <= t_scroll_bottom)
        scroll_down (t_cur_row, t_scroll_bottom, p0);
      break;

    case 'M': // DL
      if (p0 < 1) p0 = 1;
      if (t_cur_row >= t_scroll_top && t_cur_row <= t_scroll_bottom)
        scroll_up (t_cur_row, t_scroll_bottom, p0);
      break;

    case 'P': // DCH
      {
        if (p0 < 1) p0 = 1;
        int avail = t_cols - t_cur_col;
        if (p0 > avail) p0 = avail;
        for (int c = t_cur_col; c < t_cols - p0; c++)
          *cell (t_cur_row, c) = *cell (t_cur_row, c + p0);
        for (int c = t_cols - p0; c < t_cols; c++)
          clear_cell (cell (t_cur_row, c));
        t_dirty = 1;
      }
      break;

    case '@': // ICH
      {
        if (p0 < 1) p0 = 1;
        int avail = t_cols - t_cur_col;
        if (p0 > avail) p0 = avail;
        for (int c = t_cols - 1; c >= t_cur_col + p0; c--)
          *cell (t_cur_row, c) = *cell (t_cur_row, c - p0);
        for (int c = t_cur_col; c < t_cur_col + p0; c++)
          clear_cell (cell (t_cur_row, c));
        t_dirty = 1;
      }
      break;

    case 'X': // ECH
      {
        if (p0 < 1) p0 = 1;
        for (int c = t_cur_col; c < t_cur_col + p0 && c < t_cols; c++)
          clear_cell (cell (t_cur_row, c));
        t_dirty = 1;
      }
      break;

    case 'S': // SU
      if (p0 < 1) p0 = 1;
      scroll_up (t_scroll_top, t_scroll_bottom, p0);
      break;

    case 'T': // SD
      if (p0 < 1) p0 = 1;
      scroll_down (t_scroll_top, t_scroll_bottom, p0);
      break;

    case 'd': // VPA
      if (p0 < 1) p0 = 1;
      t_cur_row = p0 - 1;
      if (t_cur_row >= t_rows) t_cur_row = t_rows - 1;
      t_pending_wrap = 0;
      break;

    case 'm': handle_sgr (); break;

    case 'r': // DECSTBM
      {
        int top = (p0 < 1 ? 1 : p0) - 1;
        int bot = (p1 < 1 ? t_rows : p1) - 1;
        if (bot >= t_rows) bot = t_rows - 1;
        if (top < bot)
          { t_scroll_top = top; t_scroll_bottom = bot; }
        t_cur_row = t_origin_mode ? t_scroll_top : 0;
        t_cur_col = 0; t_pending_wrap = 0;
      }
      break;

    case 's': // SCP
      t_saved_row = t_cur_row; t_saved_col = t_cur_col;
      break;

    case 'u': // RCP
      t_cur_row = t_saved_row; t_cur_col = t_saved_col;
      ensure_cursor_bounds (); t_pending_wrap = 0;
      break;

    case 'n': case 'c': break; // DSR, DA — ignore

    case 'h': // SM
      for (int i = 0; i < t_nparam; i++)
        if (t_params[i] == 4) t_insert_mode = 1;
      break;

    case 'l': // RM
      for (int i = 0; i < t_nparam; i++)
        if (t_params[i] == 4) t_insert_mode = 0;
      break;

    case 'g': // TBC
      if (p0 == 0) t_tabs[t_cur_col] = 0;
      else if (p0 == 3) memset (t_tabs, 0, t_cols);
      break;
    }
}

// ============================================================
// DEC private mode handler (CSI ? ... h/l)
// ============================================================

void
Terminal::handle_dec_private (int final_ch)
{
  int set = (final_ch == 'h') ? 1 : 0;

  for (int i = 0; i < t_nparam; i++)
    {
      switch (t_params[i])
        {
        case 1: t_app_cursor_keys = set; break;

        case 6: // DECOM
          t_origin_mode = set;
          t_cur_row = t_origin_mode ? t_scroll_top : 0;
          t_cur_col = 0; t_pending_wrap = 0;
          break;

        case 7: t_wraparound = set; break;
        case 25: t_cursor_visible = set; break;

        case 1049: case 47: case 1047:
          if (set && !t_alt_active)
            {
              if (t_params[i] == 1049)
                {
                  t_saved_row = t_cur_row; t_saved_col = t_cur_col;
                  t_saved_fg = t_fg; t_saved_bg = t_bg;
                  t_saved_attrs = t_attrs;
                }
              TermCell *tmp = t_screen;
              t_screen = t_alt_screen; t_alt_screen = tmp;
              t_alt_active = 1;
              for (int j = 0; j < t_rows * t_cols; j++)
                clear_cell_default (&t_screen[j]);
              t_dirty = 1;
            }
          else if (!set && t_alt_active)
            {
              TermCell *tmp = t_screen;
              t_screen = t_alt_screen; t_alt_screen = tmp;
              t_alt_active = 0;
              if (t_params[i] == 1049)
                {
                  t_cur_row = t_saved_row; t_cur_col = t_saved_col;
                  t_fg = t_saved_fg; t_bg = t_saved_bg;
                  t_attrs = t_saved_attrs;
                  ensure_cursor_bounds ();
                }
              t_dirty = 1;
            }
          break;

        case 2004: break; // bracketed paste — acknowledge only
        }
    }
}

// ============================================================
// ESC sequence handler
// ============================================================

void
Terminal::handle_esc (int ch)
{
  switch (ch)
    {
    case '7': // DECSC
      t_saved_row = t_cur_row; t_saved_col = t_cur_col;
      t_saved_fg = t_fg; t_saved_bg = t_bg; t_saved_attrs = t_attrs;
      break;

    case '8': // DECRC
      t_cur_row = t_saved_row; t_cur_col = t_saved_col;
      t_fg = t_saved_fg; t_bg = t_saved_bg; t_attrs = t_saved_attrs;
      ensure_cursor_bounds (); t_pending_wrap = 0;
      break;

    case 'D': new_line (); break;
    case 'M': reverse_index (); break;
    case 'E': t_cur_col = 0; new_line (); break;

    case 'H': // HTS
      if (t_cur_col < t_cols) t_tabs[t_cur_col] = 1;
      break;

    case 'c': // RIS — full reset
      t_fg = TCOLOR_DEFAULT; t_bg = TCOLOR_DEFAULT; t_attrs = 0;
      t_cur_row = 0; t_cur_col = 0;
      t_scroll_top = 0; t_scroll_bottom = t_rows - 1;
      t_origin_mode = 0; t_wraparound = 1; t_insert_mode = 0;
      t_cursor_visible = 1; t_app_cursor_keys = 0;
      t_pending_wrap = 0;
      init_tabs ();
      for (int i = 0; i < t_rows * t_cols; i++)
        clear_cell_default (&t_screen[i]);
      t_dirty = 1;
      break;

    case '=': case '>': break; // keypad modes — ignore
    }
}

/* OSC の色指定を読む。xterm が受ける形は

     rgb:RR/GG/BB      (1-4 桁 hex ずつ。実際は 2 桁か 4 桁が大半)
     #RGB #RRGGBB #RRRGGGBBB #RRRRGGGGBBBB
     rgbi:... や色名は未対応 (-1 を返す)

   戻り値は 0xRRGGBB、読めなければ -1。                                    */
static int
parse_osc_color (const char *s)
{
  int comp[3];
  if (!strncmp (s, "rgb:", 4))
    {
      s += 4;
      for (int i = 0; i < 3; i++)
        {
          int v = 0, n = 0;
          while (isxdigit ((u_char)*s) && n < 4)
            {
              int d = (*s <= '9' ? *s - '0'
                       : (*s | 0x20) - 'a' + 10);
              v = v * 16 + d;
              s++; n++;
            }
          if (!n)
            return -1;
          /* 桁数に応じて 8bit に正規化する (RRRR なら上位 8bit)。 */
          while (n < 4) { v = v * 16 + (v & 0xf); n++; }
          comp[i] = v >> 8;
          if (i < 2)
            {
              if (*s != '/')
                return -1;
              s++;
            }
        }
      return (comp[0] << 16) | (comp[1] << 8) | comp[2];
    }

  if (*s == '#')
    {
      s++;
      int l = 0;
      while (isxdigit ((u_char)s[l]))
        l++;
      if (l % 3)
        return -1;
      int per = l / 3;
      if (per < 1 || per > 4)
        return -1;
      for (int i = 0; i < 3; i++)
        {
          int v = 0;
          for (int j = 0; j < per; j++)
            {
              char c = *s++;
              int d = (c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
              v = v * 16 + d;
            }
          int n = per;
          while (n < 4) { v = v * 16 + (v & 0xf); n++; }
          comp[i] = v >> 8;
        }
      return (comp[0] << 16) | (comp[1] << 8) | comp[2];
    }

  return -1;
}

/* OSC (Operating System Command)。以前は空の stub だったので、テーマが
   palette を上書きしてきても全部捨てていた。実装するのは色だけ:

     OSC 4 ; index ; spec   palette の 1 色を差し替える (複数組を ';' で継ぎ足せる)
     OSC 10 ; spec          既定の前景色
     OSC 11 ; spec          既定の背景色
     OSC 104               palette を組み込みに戻す (引数付きはその index だけ)
     OSC 110 / 111         前景 / 背景を既定に戻す

   ウィンドウタイトル (OSC 0 / 2) は置き場所が無いので今は捨てる。      */
void
Terminal::handle_osc ()
{
  if (!t_osc_len)
    return;
  t_osc[t_osc_len] = 0;

  char *p = t_osc;
  int code = 0;
  if (!isdigit ((u_char)*p))
    return;
  while (isdigit ((u_char)*p))
    code = code * 10 + (*p++ - '0');
  if (*p == ';')
    p++;

  int reset_all = 0;
  int slot = -1;   /* 単一の slot を差し替える形のときの index */

  switch (code)
    {
    case 4:
      break;
    case 10: slot = 256; break;
    case 11: slot = 257; break;
    case 104:
      if (!*p)
        { reset_all = 1; break; }
      break;
    case 110: slot = 256; reset_all = 2; break;
    case 111: slot = 257; reset_all = 2; break;
    default:
      return;
    }

  if (reset_all == 1)
    {
      if (t_palette)
        for (int i = 0; i < 256; i++)
          t_palette[i] = -1;
      t_dirty = 1;
      return;
    }

  if (!t_palette)
    {
      t_palette = new int32_t[TPALETTE_SIZE];
      for (int i = 0; i < TPALETTE_SIZE; i++)
        t_palette[i] = -1;
    }

  if (reset_all == 2)
    {
      t_palette[slot] = -1;
      t_dirty = 1;
      return;
    }

  if (code == 104)
    {
      /* OSC 104 ; i ; j ... — 指定 index だけ戻す */
      while (*p)
        {
          int idx = 0;
          if (!isdigit ((u_char)*p))
            break;
          while (isdigit ((u_char)*p))
            idx = idx * 10 + (*p++ - '0');
          if (idx >= 0 && idx < 256)
            t_palette[idx] = -1;
          if (*p == ';')
            p++;
        }
      t_dirty = 1;
      return;
    }

  if (slot >= 0)
    {
      int rgb = parse_osc_color (p);
      if (rgb >= 0)
        { t_palette[slot] = rgb; t_dirty = 1; }
      return;
    }

  /* OSC 4 ; index ; spec [; index ; spec ...] */
  while (*p)
    {
      int idx = 0;
      if (!isdigit ((u_char)*p))
        break;
      while (isdigit ((u_char)*p))
        idx = idx * 10 + (*p++ - '0');
      if (*p != ';')
        break;
      p++;
      char *e = strchr (p, ';');
      if (e)
        *e = 0;
      int rgb = parse_osc_color (p);
      if (rgb >= 0 && idx >= 0 && idx < 256)
        { t_palette[idx] = rgb; t_dirty = 1; }
      if (!e)
        break;
      p = e + 1;
    }
}

// ============================================================
// Key-to-escape-sequence conversion (platform-independent)
// ============================================================

int
terminal_key_to_bytes (const Terminal *term, lChar c, char *buf, int bufsize)
{
  int len = 0;

  // Mouse/menu events — not forwarded
  if (c & (LCHAR_MOUSE | LCHAR_MENU))
    return 0;

  // Function keys → VT100 escape sequences
  {
    int app = term->app_cursor_keys ();
    int base = c & ~(CCF_CTRL_BIT | CCF_SHIFT_BIT);
    char code = 0;
    switch (base)
      {
      case CCF_UP:    code = 'A'; break;
      case CCF_DOWN:  code = 'B'; break;
      case CCF_RIGHT: code = 'C'; break;
      case CCF_LEFT:  code = 'D'; break;
      case CCF_HOME:  code = 'H'; break;
      case CCF_END:   code = 'F'; break;
      default: break;
      }
    if (code && bufsize >= 3)
      {
        buf[0] = '\033';
        buf[1] = app ? 'O' : '[';
        buf[2] = code;
        len = 3;
      }
    else if (!code)
      {
        const char *seq = 0;
        switch (base)
          {
          case CCF_INSERT: seq = "\033[2~"; break;
          case CCF_DELETE: seq = "\033[3~"; break;
          case CCF_PRIOR:  seq = "\033[5~"; break;
          case CCF_NEXT:   seq = "\033[6~"; break;
          case CCF_F1:  seq = "\033OP"; break;
          case CCF_F2:  seq = "\033OQ"; break;
          case CCF_F3:  seq = "\033OR"; break;
          case CCF_F4:  seq = "\033OS"; break;
          case CCF_F5:  seq = "\033[15~"; break;
          case CCF_F6:  seq = "\033[17~"; break;
          case CCF_F7:  seq = "\033[18~"; break;
          case CCF_F8:  seq = "\033[19~"; break;
          case CCF_F9:  seq = "\033[20~"; break;
          case CCF_F10: seq = "\033[21~"; break;
          case CCF_F11: seq = "\033[23~"; break;
          case CCF_F12: seq = "\033[24~"; break;
          default: break;
          }
        if (seq)
          {
            int slen = (int)strlen (seq);
            if (slen <= bufsize)
              { memcpy (buf, seq, slen); len = slen; }
          }
      }
  }

  if (len == 0 && c < 0x80)
    {
      // ASCII character (including control chars)
      buf[0] = (char)c;
      len = 1;
    }
  else if (len == 0 && c < 0x10000)
    {
      // Phase 2: Char/lChar は UTF-16 code unit なので UCS-2 identity
      ucs2_t ucs = (ucs2_t) c;
      if (ucs < 0x80 && bufsize >= 1)
        { buf[0] = (char)ucs; len = 1; }
      else if (ucs < 0x800 && bufsize >= 2)
        { buf[0] = 0xc0 | (ucs >> 6); buf[1] = 0x80 | (ucs & 0x3f); len = 2; }
      else if (bufsize >= 3)
        { buf[0] = 0xe0 | (ucs >> 12); buf[1] = 0x80 | ((ucs >> 6) & 0x3f);
          buf[2] = 0x80 | (ucs & 0x3f); len = 3; }
    }
  else if (len == 0 && c < CHAR_LIMIT && bufsize >= 4)
    {
      // BMP 外。入力経路が surrogate pair を 1 個の code point に畳んで
      // 渡してくるので、ここで 4 バイトの UTF-8 にする。畳む前は half が
      // 2 個来て 3 バイト列 2 つ (= CESU-8) になり、pty の向こうでは
      // 化けていた。
      u_int32_t cp = (u_int32_t) c;
      buf[0] = 0xf0 | (cp >> 18);
      buf[1] = 0x80 | ((cp >> 12) & 0x3f);
      buf[2] = 0x80 | ((cp >> 6) & 0x3f);
      buf[3] = 0x80 | (cp & 0x3f);
      len = 4;
    }

  return len;
}

// ============================================================
// Main feed — VT100 parser state machine
// ============================================================

// ============================================================
// Sync terminal screen to xyzzy Buffer
// ============================================================

void
Terminal::sync_to_buffer (Buffer *bp, Window *wp)
{
  if (!t_dirty)
    return;

  bp->erase ();

  Char linebuf[1024];
  for (int r = 0; r < t_rows; r++)
    {
      int last = -1;
      for (int c = t_cols - 1; c >= 0; c--)
        {
          TermCell *tc = cell (r, c);
          if (tc->ch != 0 && tc->ch != ' ')
            { last = c; break; }
          if (tc->ch == ' ' && (tc->fg || tc->bg || tc->attrs))
            { last = c; break; }
        }

      int len = 0;
      /* buffer 本文は UTF-16 code unit 列なので、BMP 外の code point は
         surrogate pair に展開する。1 文字で 2 単位使うので余裕を 2 見る。 */
      for (int c = 0; c <= last && len < (int)numberof (linebuf) - 3; c++)
        {
          TermCell *tc = cell (r, c);
          if (tc->wide == 2)
            continue;
          ucs4_t ch = tc->ch ? tc->ch : ' ';
          if (ch < 0x10000)
            linebuf[len++] = Char (ch);
          else
            {
              linebuf[len++] = utf16_ucs4_to_pair_high (ch);
              linebuf[len++] = utf16_ucs4_to_pair_low (ch);
            }
        }

      if (r < t_rows - 1)
        linebuf[len++] = '\n';

      if (len > 0)
        {
          Point pt;
          bp->set_point (pt, bp->b_nchars);
          bp->insert_chars (pt, linebuf, len);
        }
    }

  if (wp)
    {
      point_t pos = 0;
      for (int r = 0; r < t_cur_row && r < t_rows; r++)
        {
          int last = -1;
          for (int c = t_cols - 1; c >= 0; c--)
            {
              TermCell *tc = cell (r, c);
              if (tc->ch != 0 && tc->ch != ' ')
                { last = c; break; }
              if (tc->ch == ' ' && (tc->fg || tc->bg || tc->attrs))
                { last = c; break; }
            }
          int line_len = 0;
          for (int c = 0; c <= last; c++)
            {
              if (cell (r, c)->wide != 2)
                line_len++;
            }
          pos += line_len + 1;
        }
      int col_pos = 0;
      for (int c = 0; c < t_cur_col && c < t_cols; c++)
        {
          if (cell (t_cur_row, c)->wide != 2)
            col_pos++;
        }
      pos += col_pos;

      if (pos > bp->b_nchars)
        pos = bp->b_nchars;
      bp->goto_char (wp->w_point, pos);
    }

  t_dirty = 0;
}

// ============================================================
// Main feed — VT100 parser state machine
// ============================================================

void
Terminal::feed (const u_char *data, int len)
{
  // New output arrives: snap back to live view
  if (t_scrollback_offset > 0)
    {
      t_scrollback_offset = 0;
      t_dirty = 1;
    }
  for (int i = 0; i < len; i++)
    {
      u_char ch = data[i];

      // UTF-8 continuation
      if (t_state == TS_UTF8_2 || t_state == TS_UTF8_3 || t_state == TS_UTF8_4)
        {
          if ((ch & 0xc0) != 0x80)
            { t_state = TS_NORMAL; i--; continue; }
          t_utf8_acc = (t_utf8_acc << 6) | (ch & 0x3f);
          t_utf8_remain--;
          if (t_utf8_remain == 0)
            { t_state = TS_NORMAL; put_char (t_utf8_acc); }
          else if (t_state == TS_UTF8_4)
            t_state = TS_UTF8_3;
          else if (t_state == TS_UTF8_3)
            t_state = TS_UTF8_2;
          continue;
        }

      switch (t_state)
        {
        case TS_NORMAL:
          if (ch < 0x20)
            {
              switch (ch)
                {
                case '\033': t_state = TS_ESC; break;
                case '\n': new_line (); break;
                case '\r': carriage_return (); break;
                case '\b': backspace (); break;
                case '\t': tab (); break;
                case '\a': break;
                case 0x0e: case 0x0f: break;
                }
            }
          else if (ch < 0x80)
            put_char (ch);
          else if ((ch & 0xe0) == 0xc0)
            { t_utf8_acc = ch & 0x1f; t_utf8_remain = 1; t_state = TS_UTF8_2; }
          else if ((ch & 0xf0) == 0xe0)
            { t_utf8_acc = ch & 0x0f; t_utf8_remain = 2; t_state = TS_UTF8_3; }
          else if ((ch & 0xf8) == 0xf0)
            { t_utf8_acc = ch & 0x07; t_utf8_remain = 3; t_state = TS_UTF8_4; }
          break;

        case TS_ESC:
          switch (ch)
            {
            case '[':
              t_state = TS_CSI; t_nparam = 0; t_intermediate = 0;
              memset (t_params, 0, sizeof t_params);
              memset (t_param_colon, 0, sizeof t_param_colon);
              break;
            case ']': t_state = TS_OSC; t_nparam = 0; t_osc_len = 0; break;
            case '#': t_state = TS_ESC_HASH; break;
            case '(': case ')': t_state = TS_CHARSET; break;
            default: handle_esc (ch); t_state = TS_NORMAL; break;
            }
          break;

        case TS_CSI:
          if (ch == '?')
            { t_state = TS_CSI_PRIV; break; }
          if (ch >= '0' && ch <= '9')
            {
              if (t_nparam == 0) t_nparam = 1;
              t_params[t_nparam - 1] = t_params[t_nparam - 1] * 10 + (ch - '0');
            }
          else if (ch == ';' || ch == ':')
            {
              /* ':' は T.416 の sub-parameter 区切り。以前は 0x20-0x3f の
                 intermediate 扱いで、区切りとして働かなかったので
                 `38:2:255:0:0` が 1 個の巨大な数値に潰れていた。
                 区切ったことを覚えておいて SGR 38/48 の解釈に使う。 */
              if (t_nparam < TERM_MAX_PARAMS)
                {
                  t_nparam++;
                  t_param_colon[t_nparam - 1] = (ch == ':');
                }
            }
          else if (ch >= 0x20 && ch < 0x40)
            t_intermediate = ch;
          else if (ch >= 0x40 && ch <= 0x7e)
            { handle_csi (ch); t_state = TS_NORMAL; }
          else
            t_state = TS_NORMAL;
          break;

        case TS_CSI_PRIV:
          if (ch >= '0' && ch <= '9')
            {
              if (t_nparam == 0) t_nparam = 1;
              t_params[t_nparam - 1] = t_params[t_nparam - 1] * 10 + (ch - '0');
            }
          else if (ch == ';' || ch == ':')
            { if (t_nparam < TERM_MAX_PARAMS) t_nparam++; }
          else if (ch == 'h' || ch == 'l')
            { handle_dec_private (ch); t_state = TS_NORMAL; }
          else if (ch >= 0x40 && ch <= 0x7e)
            t_state = TS_NORMAL;
          else
            t_state = TS_NORMAL;
          break;

        case TS_OSC:
          if (ch == '\a')
            { handle_osc (); t_state = TS_NORMAL; }
          else if (ch == '\033')
            t_state = TS_OSC_ESC;
          else if (t_osc_len < OSC_MAX - 1)
            t_osc[t_osc_len++] = char (ch);
          break;

        case TS_OSC_ESC:
          if (ch == '\\')
            { handle_osc (); t_state = TS_NORMAL; }
          else
            t_state = TS_NORMAL;
          break;

        case TS_ESC_HASH:
          if (ch == '8')
            {
              for (int r = 0; r < t_rows; r++)
                for (int c = 0; c < t_cols; c++)
                  {
                    TermCell *tc = cell (r, c);
                    tc->ch = 'E'; tc->fg = 0; tc->bg = 0;
                    tc->attrs = 0; tc->wide = 0;
                  }
              t_dirty = 1;
            }
          t_state = TS_NORMAL;
          break;

        case TS_CHARSET:
          t_state = TS_NORMAL;
          break;

        default:
          t_state = TS_NORMAL;
          break;
        }
    }
}
