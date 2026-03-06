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

  for (int c = 0; c <= last && len < (int)(sizeof buf / sizeof buf[0]) - 1; c++)
    {
      const TermCell *tc = term->cell_at (row, c);
      if (tc->wide == 2)
        continue;
      buf[len++] = tc->ch ? tc->ch : ' ';
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
