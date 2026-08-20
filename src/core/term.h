// VT100/xterm terminal emulator — platform-independent core
// Parses escape sequences from pty output and maintains a virtual screen.

#ifndef TERM_H
#define TERM_H

#include <stdint.h>

// SGR attributes
enum {
  TATTR_BOLD      = 0x01,
  TATTR_DIM       = 0x02,
  TATTR_UNDERLINE = 0x04,
  TATTR_REVERSE   = 0x08,
  TATTR_INVISIBLE = 0x10,
};

struct TermCell
{
  ucs4_t ch;       // Unicode code point (0 = empty)
  uint8_t fg;      // foreground color (0=default, 1-8=standard, 9-16=bright, 17+=extended)
  uint8_t bg;      // background color (same encoding)
  uint8_t attrs;   // TATTR_*
  uint8_t wide;    // 1 = wide char first cell, 2 = wide char continuation
};

class Terminal
{
  // Screen
  int t_rows, t_cols;
  TermCell *t_screen;
  TermCell *t_alt_screen;
  int t_cur_row, t_cur_col;
  int t_scroll_top, t_scroll_bottom;

  // Saved cursor
  int t_saved_row, t_saved_col;
  uint8_t t_saved_fg, t_saved_bg, t_saved_attrs;

  // Current SGR
  uint8_t t_fg, t_bg, t_attrs;

  // Parser
  enum { TS_NORMAL, TS_ESC, TS_CSI, TS_CSI_PRIV, TS_OSC, TS_OSC_ESC,
         TS_ESC_HASH, TS_CHARSET, TS_UTF8_2, TS_UTF8_3, TS_UTF8_4 };
  int t_state;
  enum { TERM_MAX_PARAMS = 16 };
  int t_params[TERM_MAX_PARAMS];
  int t_nparam;
  int t_intermediate;
  uint32_t t_utf8_acc;
  int t_utf8_remain;

  // Modes
  int t_alt_active;
  int t_cursor_visible;
  int t_app_cursor_keys;
  int t_origin_mode;
  int t_wraparound;
  int t_insert_mode;
  int t_pending_wrap;

  // Tab stops
  uint8_t *t_tabs;

  // Scrollback buffer (ring buffer of rows)
  enum { SCROLLBACK_MAX = 1000 };
  TermCell *t_scrollback;       // SCROLLBACK_MAX * t_cols cells
  int t_scrollback_cols;        // cols at allocation time
  int t_scrollback_count;       // number of saved lines (0..SCROLLBACK_MAX)
  int t_scrollback_head;        // ring buffer write position
  int t_scrollback_offset;      // view offset (0=live, >0=scrolled back)

  void scrollback_push (const TermCell *row);
  void scrollback_realloc ();

  // Dirty tracking
  int t_dirty;

  // Internal
  TermCell *cell (int row, int col) { return &t_screen[row * t_cols + col]; }
  void clear_cell (TermCell *c);
  void clear_cell_default (TermCell *c);
  void clear_region (int r1, int c1, int r2, int c2);
  void scroll_up (int top, int bottom, int n);
  void scroll_down (int top, int bottom, int n);
  void put_char (uint32_t ucs);
  void new_line ();
  void carriage_return ();
  void backspace ();
  void tab ();
  void reverse_index ();
  void handle_csi (int final_ch);
  void handle_esc (int ch);
  void handle_sgr ();
  void handle_dec_private (int final_ch);
  void handle_osc ();
  void ensure_cursor_bounds ();
  void init_tabs ();

public:
  Terminal (int rows, int cols);
  ~Terminal ();

  void resize (int new_rows, int new_cols);
  void feed (const u_char *data, int len);
  void sync_to_buffer (Buffer *bp, Window *wp);

  // Accessors for frontend rendering
  int rows () const { return t_rows; }
  int cols () const { return t_cols; }
  int cursor_row () const { return t_cur_row; }
  int cursor_col () const { return t_cur_col; }
  int cursor_visible () const { return t_cursor_visible; }
  int app_cursor_keys () const { return t_app_cursor_keys; }
  int dirty () const { return t_dirty; }
  void clear_dirty () { t_dirty = 0; }
  const TermCell *screen () const { return t_screen; }
  const TermCell *cell_at (int row, int col) const
    { return &t_screen[row * t_cols + col]; }

  // Scrollback
  int scrollback_offset () const { return t_scrollback_offset; }
  int scrollback_count () const { return t_scrollback_count; }
  void scrollback_scroll (int delta);  // positive=back, negative=forward
  const TermCell *scrollback_line (int index) const; // 0=most recent
  // Get cell for rendering: handles scrollback offset
  const TermCell *display_cell (int row, int col) const;
  int alt_active () const { return t_alt_active; }
};

// Convert an lChar key to VT100 escape sequence bytes.
// Returns number of bytes written (0 if key not handled).
int terminal_key_to_bytes (const Terminal *term, lChar key, char *buf, int bufsize);

#endif // TERM_H
