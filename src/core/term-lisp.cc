// Lisp API for terminal emulator (si:terminal-*)

#include "stdafx.h"
#include "ed.h"
#include "term.h"
#include "lprocess.h"

// Defined in frontend (ncurses-process.cc / win32 process.cc)
extern Terminal *buffer_terminal (const Buffer *bp);
extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
extern void buffer_terminal_resize (const Buffer *bp, int rows, int cols);

// Get Terminal* from a process lisp object.
// Returns NULL if the process has no terminal.
static Terminal *
process_terminal (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return 0;
  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return 0;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  return buffer_terminal (bp);
}

// (si:process-terminal-p process) → t/nil
lisp
Fsi_process_terminal_p (lisp process)
{
  return boole (process_terminal (process) != 0);
}

// (si:terminal-screen-line process row) → string
lisp
Fsi_terminal_screen_line (lisp process, lisp lrow)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  int row = fixnum_value (lrow);
  if (row < 0 || row >= term->rows ())
    FErange_error (lrow);

  int cols = term->cols ();
  Char buf[1024];
  int len = 0;

  // Find last non-empty cell
  int last = -1;
  for (int c = cols - 1; c >= 0; c--)
    {
      const TermCell *tc = term->cell_at (row, c);
      if (tc->ch != 0 && tc->ch != ' ')
        { last = c; break; }
      if (tc->ch == ' ' && (tc->fg || tc->bg || tc->attrs))
        { last = c; break; }
    }

  /* TermCell::ch は code point、buf は UTF-16 なので BMP 外は
     surrogate pair に展開する。1 文字で 2 単位使うので余裕を 2 見る。 */
  for (int c = 0; c <= last && len < (int)(sizeof buf / sizeof buf[0]) - 3; c++)
    {
      const TermCell *tc = term->cell_at (row, c);
      if (tc->wide == 2)
        continue;
      ucs4_t ch = tc->ch ? tc->ch : ' ';
      if (ch < 0x10000)
        buf[len++] = Char (ch);
      else
        {
          buf[len++] = utf16_ucs4_to_pair_high (ch);
          buf[len++] = utf16_ucs4_to_pair_low (ch);
        }
    }

  return make_string (buf, len);
}

// (si:terminal-screen-size process) → (values rows cols)
lisp
Fsi_terminal_screen_size (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (term->cols ());
  return make_fixnum (term->rows ());
}

// (si:terminal-cursor-position process) → (values row col)
lisp
Fsi_terminal_cursor_position (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (term->cursor_col ());
  return make_fixnum (term->cursor_row ());
}

// (si:terminal-resize process rows cols)
lisp
Fsi_terminal_resize (lisp process, lisp lrows, lisp lcols)
{
  check_process (process);
  int rows = fixnum_value (lrows);
  int cols = fixnum_value (lcols);
  if (rows < 1 || cols < 1)
    FErange_error (rows < 1 ? lrows : lcols);

  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return Qnil;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  buffer_terminal_resize (bp, rows, cols);
  return Qt;
}

// (si:terminal-app-cursor-keys-p process) → t/nil
lisp
Fsi_terminal_app_cursor_keys_p (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  return boole (term->app_cursor_keys ());
}

// (si:terminal-send-key process key)
// Convert an lChar key to VT100 escape sequence and send to process.
lisp
Fsi_terminal_send_key (lisp process, lisp lkey)
{
  check_process (process);
  lChar c;
  if (charp (lkey))
    c = xchar_code (lkey);
  else
    c = fixnum_value (lkey);

  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return Qnil;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  Terminal *term = buffer_terminal (bp);
  if (!term)
    return Qnil;

  char buf[16];
  int len = terminal_key_to_bytes (term, c, buf, sizeof buf);
  if (len > 0)
    {
      buffer_terminal_send (bp, buf, len);
      return Qt;
    }
  return Qnil;
}

// (si:terminal-scroll-back process delta)
// Scroll the terminal view back (positive) or forward (negative).
lisp
Fsi_terminal_scroll_back (lisp process, lisp ldelta)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  int delta = fixnum_value (ldelta);
  term->scrollback_scroll (delta);
  return make_fixnum (term->scrollback_offset ());
}

// (si:terminal-scrollback-line process index)
// Get a scrollback line (0=most recent). Returns string or nil.
lisp
Fsi_terminal_scrollback_line (lisp process, lisp lindex)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  int index = fixnum_value (lindex);
  const TermCell *line = term->scrollback_line (index);
  if (!line)
    return Qnil;

  int cols = term->cols ();
  Char buf[1024];
  int len = 0;
  int last = -1;
  for (int c = cols - 1; c >= 0; c--)
    {
      if (line[c].ch != 0 && line[c].ch != ' ')
        { last = c; break; }
    }
  /* 上と同じ理由で surrogate pair に展開する。 */
  for (int c = 0; c <= last && len < (int)(sizeof buf / sizeof buf[0]) - 3; c++)
    {
      if (line[c].wide == 2)
        continue;
      ucs4_t ch = line[c].ch ? line[c].ch : ' ';
      if (ch < 0x10000)
        buf[len++] = Char (ch);
      else
        {
          buf[len++] = utf16_ucs4_to_pair_high (ch);
          buf[len++] = utf16_ucs4_to_pair_low (ch);
        }
    }
  return make_string (buf, len);
}

/* (si:*terminal-feed-for-test rows cols string)
     => 各行のリスト。行は各セルの (code-point fg bg attrs) のリスト。

   VT パーサ (色・カーソル・消去・スクロール) に自動テストを付けるための
   口。Terminal は本来 ConPtyProcess が抱えていて、process 無しに作る手段が
   無かったため、パーサには自動テストが一切なかった。SGR の色解釈を書き
   直した際にここを塞いだ。

   fg / bg は term_color_t をそのまま整数で返す:
     0                = 端末の既定色
     #x1000000 + n    = xterm palette index n (0-255)
     #x2000000 + RGB  = 24bit 直接指定 (0xRRGGBB)
   attrs は TATTR_* のビット和。

   string は code point 列。UTF-8 に直してから流すので、エスケープ列も
   日本語も同じように書ける。                                             */
lisp
Fsi_terminal_feed_for_test (lisp lrows, lisp lcols, lisp string)
{
  int rows = fixnum_value (lrows);
  int cols = fixnum_value (lcols);
  if (rows < 1 || rows > 200)
    FErange_error (lrows);
  if (cols < 1 || cols > 500)
    FErange_error (lcols);
  check_string (string);

  Terminal term (rows, cols);

  int l = xstring_length (string);
  if (l > 0)
    {
      size_t n = i2u8l (xstring_contents (string), l);
      char *b = (char *)xmalloc (n + 1);
      i2u8 (xstring_contents (string), l, b);
      term.feed ((const u_char *)b, int (n));
      xfree (b);
    }

  lisp result = Qnil;
  for (int r = rows - 1; r >= 0; r--)
    {
      lisp row = Qnil;
      for (int c = cols - 1; c >= 0; c--)
        {
          const TermCell *tc = term.cell_at (r, c);
          lisp cell = xcons (make_fixnum (tc->ch),
                             xcons (make_fixnum (tc->fg),
                                    xcons (make_fixnum (tc->bg),
                                           xcons (make_fixnum (tc->attrs),
                                                  Qnil))));
          row = xcons (cell, row);
        }
      result = xcons (row, result);
    }
  return result;
}
