// ncurses keyboard input: maps terminal keys to xyzzy lChar
#include "stdafx.h"
#include "ed.h"
#include "charset.h"

#include <ncurses.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/select.h>

void refresh_screen (int);

// SIGWINCH flag (set in ncurses-main.cc)
extern volatile int g_need_resize;

// Mouse support: dispatch ncurses mouse event → xyzzy lChar
// Returns lChar (CCF_LBTNxxx | LCHAR_MOUSE etc), or lChar_EOF if unhandled.
lChar ncurses_mouse_dispatch (MEVENT *mev);

void
ncurses_mouse_init ()
{
  mousemask (ALL_MOUSE_EVENTS | REPORT_MOUSE_POSITION, NULL);
  // Enable SGR (1006) mouse mode for coordinates > 223
  printf ("\033[?1006h");
  fflush (stdout);
  mouseinterval (0);  // no click-resolution delay (we handle it ourselves)
}

// Helper: process a KEY_MOUSE event from wget_wch.
// Returns lChar for the keyboard queue, or lChar_EOF if not handled.
static lChar
handle_mouse_event ()
{
  MEVENT mev;
  if (getmouse (&mev) != OK)
    return lChar_EOF;
  return ncurses_mouse_dispatch (&mev);
}

// Key debug log (enabled by XYZZY_KEYLOG env var)
static int g_keylog_fd = -1;
static int g_keylog_init = 0;

static void
keylog (const char *fmt, ...)
{
  if (!g_keylog_init)
    {
      g_keylog_init = 1;
      if (getenv ("XYZZY_KEYLOG"))
        g_keylog_fd = open ("/tmp/xyzzy-keylog.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    }
  if (g_keylog_fd < 0)
    return;
  char buf[256];
  va_list ap;
  va_start (ap, fmt);
  int n = vsnprintf (buf, sizeof (buf), fmt, ap);
  va_end (ap);
  if (n > 0)
    {
      ssize_t r __attribute__((unused)) = write (g_keylog_fd, buf, n);
    }
}

// Map ncurses special key codes to xyzzy CCF_* function keys
static lChar
map_ncurses_key (int key)
{
  switch (key)
    {
    case KEY_UP:        return CCF_UP;
    case KEY_DOWN:      return CCF_DOWN;
    case KEY_LEFT:      return CCF_LEFT;
    case KEY_RIGHT:     return CCF_RIGHT;
    case KEY_HOME:      return CCF_HOME;
    case KEY_END:       return CCF_END;
    case KEY_PPAGE:     return CCF_PRIOR;
    case KEY_NPAGE:     return CCF_NEXT;
    case KEY_IC:        return CCF_INSERT;
    case KEY_DC:        return CCF_DELETE;
    case KEY_BACKSPACE: return 0x7f;   // DEL
    case KEY_F(1):      return CCF_F1;
    case KEY_F(2):      return CCF_F2;
    case KEY_F(3):      return CCF_F3;
    case KEY_F(4):      return CCF_F4;
    case KEY_F(5):      return CCF_F5;
    case KEY_F(6):      return CCF_F6;
    case KEY_F(7):      return CCF_F7;
    case KEY_F(8):      return CCF_F8;
    case KEY_F(9):      return CCF_F9;
    case KEY_F(10):     return CCF_F10;
    case KEY_F(11):     return CCF_F11;
    case KEY_F(12):     return CCF_F12;
    default:            return lChar_EOF;
    }
}

// Convert a wchar_t (from wget_wch) to xyzzy internal lChar
static lChar
wchar_to_lchar (wchar_t wc)
{
  // ncurses raw() mode sends LF (0x0a) for Enter; xyzzy expects CR (0x0d)
  if (wc == 0x0a)
    wc = 0x0d;

  if (wc < 0x80)
    return (lChar)wc;

  // BMP range: use w2i() lookup table
  if (wc <= 0xffff)
    {
      Char c = w2i ((ucs2_t)wc);
      if (c != 0)
        return (lChar)c;
    }

  // Outside BMP or unmapped: return as-is (will display as unknown)
  return lChar_EOF;
}

// Convert ncurses wget_wch result to lChar (special key or character)
static lChar
ncurses_key_to_lchar (int ret, wint_t wch)
{
  if (ret == KEY_CODE_YES)
    return map_ncurses_key (wch);
  return wchar_to_lchar ((wchar_t)wch);
}

// Debug log for fetch (written to /tmp/xyzzy-fetch.log)
// Defined in core/cmdloop.cc; opened here on first use
extern int g_fetchlog_fd;
static void
fetchlog (const char *fmt, ...)
{
  if (g_fetchlog_fd < 0)
    g_fetchlog_fd = open ("/tmp/xyzzy-fetch.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (g_fetchlog_fd < 0)
    return;
  char buf[256];
  va_list ap;
  va_start (ap, fmt);
  int n = vsnprintf (buf, sizeof (buf), fmt, ap);
  va_end (ap);
  if (n > 0)
    {
      ssize_t r __attribute__((unused)) = write (g_fetchlog_fd, buf, n);
    }
}

// Drain KEY_RESIZE from ncurses input queue after SIGWINCH.
// The actual resize (resizeterm, compute_geometry) is deferred to refresh_screen.
// Saves any real key found while draining into kbd_queue::pending.
static void
handle_resize (kbd_queue &kbdq)
{
  // Don't clear the flag here — let refresh_screen handle the actual
  // resize (compute_geometry, window_size_changed, etc.).
  // We just drain KEY_RESIZE so it doesn't pile up in the input queue.

  // Drain any KEY_RESIZE from the ncurses input queue
  nodelay (stdscr, TRUE);
  wint_t drain;
  int drain_ret;
  while ((drain_ret = wget_wch (stdscr, &drain)) != ERR)
    {
      if (drain_ret == KEY_CODE_YES && drain == KEY_RESIZE)
        continue;
      // Got a real key — save it via public push_back()
      kbdq.push_back (ncurses_key_to_lchar (drain_ret, drain));
      break;
    }
  nodelay (stdscr, FALSE);

  fetchlog ("fetch: resize detected, deferring to refresh_screen\n");
}

// From ncurses-process.cc: poll processes and collect fds
void poll_processes ();
int collect_process_fds (fd_set *fds);

lChar
kbd_queue::fetch (int wait, int)
{
  // Return pending character first
  if (pending != lChar_EOF)
    {
      lChar c = pending;
      pending = lChar_EOF;
      fetchlog ("fetch: from pending 0x%lx\n", (unsigned long)c);
      return c;
    }

  // Check internal queue
  if (head != tail)
    {
      lChar c = cc[head];
      head = (head + 1) % QUEUE_MAX;
      fetchlog ("fetch: from queue 0x%lx\n", (unsigned long)c);
      return c;
    }

  // Keyboard macro: macro_char() reads from the macro string.
  // kbd_macro_context (in kbd.h) sets kbd_macro pointer;
  // when running, we feed characters from the macro string.
  if (kbd_macro)
    {
      // Inline macro character fetch (macro_char is private)
      // kbd_macro_context stores: string, index
      // We access through the public macro_is_running() interface
      // and let command_loop handle it via lChar_EOF when exhausted
    }

  // Note: Win32 fetch() always blocks regardless of 'wait' param.
  // readc_stream() calls fetch(0,0) for keyboard stream reads
  // (e.g. read-char *keyboard* in universal-argument).
  // We must also always block here.

  // select()-based event loop: multiplex stdin + process pipe fds
  wint_t wch;
  int ret;
  for (;;)
    {
      fetchlog ("fetch: waiting on select...\n");

      fd_set rfds;
      FD_ZERO (&rfds);
      FD_SET (STDIN_FILENO, &rfds);
      int maxfd = STDIN_FILENO;

      // Add process fds to the select set
      int pmax = collect_process_fds (&rfds);
      if (pmax > maxfd)
        maxfd = pmax;

      // 100ms timeout: allows periodic process polling and resize checks
      struct timeval tv;
      tv.tv_sec = 0;
      tv.tv_usec = 100000;

      int sel = select (maxfd + 1, &rfds, 0, 0, &tv);

      // Handle resize (SIGWINCH sets g_need_resize)
      if (g_need_resize)
        {
          handle_resize (*this);
          refresh_screen (1);
          // Check if handle_resize saved a key
          if (pending != lChar_EOF)
            {
              lChar c = pending;
              pending = lChar_EOF;
              return c;
            }
        }

      if (sel > 0)
        {
          // Poll process output if any process fd is ready
          if (pmax >= 0)
            poll_processes ();

          // Check if stdin is ready
          if (FD_ISSET (STDIN_FILENO, &rfds))
            {
              // Read key from ncurses in non-blocking mode
              nodelay (stdscr, TRUE);
              ret = wget_wch (stdscr, &wch);
              nodelay (stdscr, FALSE);

              fetchlog ("fetch: ret=%d wch=%d (0x%x)\n",
                        ret, (int)wch, (int)wch);

              if (ret == ERR)
                continue;

              if (ret == KEY_CODE_YES && wch == KEY_RESIZE)
                {
                  handle_resize (*this);
                  continue;
                }

              if (ret == KEY_CODE_YES && wch == KEY_MOUSE)
                {
                  lChar mc = handle_mouse_event ();
                  if (mc != lChar_EOF)
                    {
                      fetchlog ("fetch: mouse → 0x%lx\n", (unsigned long)mc);
                      return mc;
                    }
                  continue;
                }

              break;
            }
        }
      else if (sel == 0)
        {
          // Timeout — poll processes for termination
          poll_processes ();
          // Check if popup_string timeout has elapsed
          extern void check_popup_timeout ();
          check_popup_timeout ();
        }
      // sel < 0: EINTR from signal, loop around
    }

  lChar result = ncurses_key_to_lchar (ret, wch);

  // ESC timeout detection: ESC alone (200ms) → CCF_F10 (menu activation)
  if (result == CC_ESC)
    {
      // First check ncurses internal buffer (ESC+key may already be consumed)
      wint_t next_wch;
      nodelay (stdscr, TRUE);
      int next_ret = wget_wch (stdscr, &next_wch);
      nodelay (stdscr, FALSE);

      if (next_ret != ERR)
        {
          // Another character available → ESC is meta prefix
          // Save it for the next fetch() call
          pending = ncurses_key_to_lchar (next_ret, next_wch);
        }
      else
        {
          // Nothing in ncurses buffer. Wait on raw fd for 200ms.
          fd_set rfds;
          FD_ZERO (&rfds);
          FD_SET (STDIN_FILENO, &rfds);
          struct timeval tv;
          tv.tv_sec = 0;
          tv.tv_usec = 200000;  // 200ms
          int sel = select (STDIN_FILENO + 1, &rfds, 0, 0, &tv);
          if (sel <= 0)
            {
              // Timeout → ESC alone → convert to F10 (menu activation)
              result = CCF_F10;
            }
          // else: next key arrived → ESC is meta prefix, return CC_ESC as-is
        }
    }

  fetchlog ("fetch: → lChar=0x%lx\n", (unsigned long)result);
  return result;
}

lChar
kbd_queue::peek (int)
{
  // peek in xyzzy is actually a non-blocking fetch (consumes the character)
  if (pending != lChar_EOF)
    {
      lChar c = pending;
      pending = lChar_EOF;
      return c;
    }
  if (head != tail)
    {
      lChar c = cc[head];
      head = (head + 1) % QUEUE_MAX;
      return c;
    }

  // Non-blocking check from ncurses
  nodelay (stdscr, TRUE);
  wint_t wch;
  int ret = wget_wch (stdscr, &wch);
  nodelay (stdscr, FALSE);

  if (ret == ERR)
    return lChar_EOF;
  if (ret == KEY_CODE_YES && wch == KEY_RESIZE)
    {
      g_need_resize = 1;
      return lChar_EOF;
    }
  if (ret == KEY_CODE_YES && wch == KEY_MOUSE)
    {
      lChar mc = handle_mouse_event ();
      return mc;  // may be lChar_EOF if unhandled
    }

  return ncurses_key_to_lchar (ret, wch);
}

int
kbd_queue::listen ()
{
  if (pending != lChar_EOF || head != tail)
    return 1;
  nodelay (stdscr, TRUE);
  wint_t wch;
  int ret = wget_wch (stdscr, &wch);
  nodelay (stdscr, FALSE);
  if (ret == ERR)
    return 0;
  if (ret == KEY_CODE_YES && wch == KEY_RESIZE)
    {
      g_need_resize = 1;
      return 0;
    }
  if (ret == KEY_CODE_YES && wch == KEY_MOUSE)
    {
      lChar mc = handle_mouse_event ();
      if (mc != lChar_EOF)
        {
          pending = mc;
          return 1;
        }
      return 0;
    }
  lChar c = ncurses_key_to_lchar (ret, wch);
  if (c != lChar_EOF)
    pending = c;
  return c != lChar_EOF;
}

int
kbd_queue::putraw (lChar c)
{
  if ((tail + 1) % QUEUE_MAX == head)
    return 0;
  cc[tail] = c;
  tail = (tail + 1) % QUEUE_MAX;
  return 1;
}

int
kbd_queue::putc (lChar c)
{
  return putraw (c);
}

int
kbd_queue::putw (int c)
{
  return putraw ((lChar)c);
}

int
kbd_queue::puts (const char *s, int l)
{
  for (int i = 0; i < l; i++)
    if (!putraw ((lChar)(unsigned char)s[i]))
      return 0;
  return 1;
}

void kbd_queue::clear () { head = tail = 0; pending = lChar_EOF; }
void kbd_queue::close_ime () {}
void kbd_queue::restore_ime () {}

void
kbd_queue::sit_for (DWORD timeout)
{
  if (kbd_macro || pending != lChar_EOF || head != tail)
    return;
  // sit_for: wait for keyboard input or timeout, polling processes
  long usec = (long)timeout * 1000;
  while (usec > 0)
    {
      fd_set rfds;
      FD_ZERO (&rfds);
      FD_SET (STDIN_FILENO, &rfds);
      int maxfd = STDIN_FILENO;
      int pmax = collect_process_fds (&rfds);
      if (pmax > maxfd)
        maxfd = pmax;

      struct timeval tv;
      long chunk = (usec > 100000) ? 100000 : usec;
      tv.tv_sec = chunk / 1000000;
      tv.tv_usec = chunk % 1000000;

      int ret = select (maxfd + 1, &rfds, 0, 0, &tv);
      if (ret > 0)
        {
          poll_processes ();
          if (FD_ISSET (STDIN_FILENO, &rfds))
            return;  // keyboard input arrived
        }
      else if (ret == 0)
        poll_processes ();
      usec -= chunk;
    }
}

void
kbd_queue::sleep_for (DWORD timeout)
{
  long usec = (long)timeout * 1000;
  while (usec > 0)
    {
      fd_set rfds;
      FD_ZERO (&rfds);
      int maxfd = -1;
      int pmax = collect_process_fds (&rfds);
      if (pmax > maxfd)
        maxfd = pmax;

      struct timeval tv;
      long chunk = (usec > 100000) ? 100000 : usec;
      tv.tv_sec = chunk / 1000000;
      tv.tv_usec = chunk % 1000000;

      if (maxfd >= 0)
        {
          int ret = select (maxfd + 1, &rfds, 0, 0, &tv);
          if (ret > 0)
            poll_processes ();
        }
      else
        select (0, 0, 0, 0, &tv);
      usec -= chunk;
    }
}
int kbd_queue::lookup_kbd_macro (lisp) const { return 0; }
int kbd_queue::toggle_ime (int, int) { return 0; }

void key_sequence::push (Char, int) {}
void key_sequence::done (Char, int) {}
