// VT100/xterm terminal emulator — platform-independent core
// Parses escape sequences from pty output and maintains a virtual screen.

#include "stdafx.h"
#include "ed.h"
#include "term.h"

#include <wchar.h>
#include <string.h>

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
  c->ch = 0; c->fg = 0; c->bg = 0; c->attrs = 0; c->wide = 0;
}

Terminal::Terminal (int rows, int cols)
    : t_rows (rows), t_cols (cols),
      t_cur_row (0), t_cur_col (0),
      t_scroll_top (0), t_scroll_bottom (rows - 1),
      t_saved_row (0), t_saved_col (0),
      t_saved_fg (0), t_saved_bg (0), t_saved_attrs (0),
      t_fg (0), t_bg (0), t_attrs (0),
      t_state (TS_NORMAL), t_nparam (0), t_intermediate (0),
      t_utf8_acc (0), t_utf8_remain (0),
      t_alt_active (0), t_cursor_visible (1),
      t_app_cursor_keys (0), t_origin_mode (0),
      t_wraparound (1), t_insert_mode (0), t_pending_wrap (0),
      t_dirty (1)
{
  int total = rows * cols;
  t_screen = new TermCell[total];
  t_alt_screen = new TermCell[total];
  t_tabs = new uint8_t[cols];
  for (int i = 0; i < total; i++)
    clear_cell_default (&t_screen[i]);
  for (int i = 0; i < total; i++)
    clear_cell_default (&t_alt_screen[i]);
  init_tabs ();
}

Terminal::~Terminal ()
{
  delete[] t_screen;
  delete[] t_alt_screen;
  delete[] t_tabs;
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
Terminal::scroll_up (int top, int bottom, int n)
{
  if (n <= 0 || top > bottom)
    return;
  if (n > bottom - top + 1)
    n = bottom - top + 1;
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

  Char ich = 0;
  if (ucs < 0x80)
    ich = (Char)ucs;
  else
    {
      ucs2_t w = (ucs2_t)ucs;
      ich = w2i (w);
      if (ich == 0)
        ich = '?';
    }

  int width = 1;
  if (ucs >= 0x80)
    {
      int w = wcwidth ((wchar_t)ucs);
      if (w > 1) width = w;
    }

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
      t_fg = 0; t_bg = 0; t_attrs = 0;
      return;
    }

  for (int i = 0; i < t_nparam; i++)
    {
      int p = t_params[i];
      switch (p)
        {
        case 0:  t_fg = 0; t_bg = 0; t_attrs = 0; break;
        case 1:  t_attrs |= TATTR_BOLD; break;
        case 2:  t_attrs |= TATTR_DIM; break;
        case 4:  t_attrs |= TATTR_UNDERLINE; break;
        case 7:  t_attrs |= TATTR_REVERSE; break;
        case 8:  t_attrs |= TATTR_INVISIBLE; break;
        case 22: t_attrs &= ~(TATTR_BOLD | TATTR_DIM); break;
        case 24: t_attrs &= ~TATTR_UNDERLINE; break;
        case 27: t_attrs &= ~TATTR_REVERSE; break;
        case 28: t_attrs &= ~TATTR_INVISIBLE; break;

        case 30: case 31: case 32: case 33:
        case 34: case 35: case 36: case 37:
          t_fg = p - 30 + 1; break;
        case 39: t_fg = 0; break;

        case 40: case 41: case 42: case 43:
        case 44: case 45: case 46: case 47:
          t_bg = p - 40 + 1; break;
        case 49: t_bg = 0; break;

        case 90: case 91: case 92: case 93:
        case 94: case 95: case 96: case 97:
          t_fg = p - 90 + 9; break;

        case 100: case 101: case 102: case 103:
        case 104: case 105: case 106: case 107:
          t_bg = p - 100 + 9; break;

        case 38: // 256-color fg
          if (i + 2 < t_nparam && t_params[i + 1] == 5)
            {
              int c = t_params[i + 2];
              // Store as 17+ for extended colors (0-255 → 17-272)
              if (c < 8) t_fg = c + 1;
              else if (c < 16) t_fg = c - 8 + 9;
              else t_fg = c + 17;
              i += 2;
            }
          break;
        case 48: // 256-color bg
          if (i + 2 < t_nparam && t_params[i + 1] == 5)
            {
              int c = t_params[i + 2];
              if (c < 8) t_bg = c + 1;
              else if (c < 16) t_bg = c - 8 + 9;
              else t_bg = c + 17;
              i += 2;
            }
          break;
        }
    }
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
      t_fg = 0; t_bg = 0; t_attrs = 0;
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

void Terminal::handle_osc () {}

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
      for (int c = 0; c <= last && len < (int)numberof (linebuf) - 1; c++)
        {
          TermCell *tc = cell (r, c);
          if (tc->wide == 2)
            continue;
          Char ch = tc->ch ? tc->ch : ' ';
          linebuf[len++] = ch;
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
              break;
            case ']': t_state = TS_OSC; t_nparam = 0; break;
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
          else if (ch == ';')
            { if (t_nparam < TERM_MAX_PARAMS) t_nparam++; }
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
          else if (ch == ';')
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
