// ncurses keyboard input: maps terminal keys to xyzzy lChar
#include "stdafx.h"
#include "ed.h"
#include "charset.h"

#include <ncurses.h>
#include <fcntl.h>
#include <unistd.h>

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

  if (!wait)
    {
      fetchlog ("fetch: no-wait → EOF\n");
      return lChar_EOF;
    }

  // Block on ncurses input
  fetchlog ("fetch: waiting on wget_wch...\n");
  keylog ("fetch: waiting (wait=%d)...\n", wait);

  // Try wget_wch first for wide char support; fall back to wgetch
  wint_t wch;
  int ret = wget_wch (stdscr, &wch);

  fetchlog ("fetch: ret=%d wch=%d (0x%x)\n", ret, (int)wch, (int)wch);
  keylog ("fetch: ret=%d wch=%d (0x%x)\n", ret, (int)wch, (int)wch);

  if (ret == ERR)
    {
      fetchlog ("fetch: wget_wch returned ERR, trying wgetch fallback\n");
      // Fallback to narrow char input
      int ch = wgetch (stdscr);
      fetchlog ("fetch: wgetch=%d (0x%x)\n", ch, ch);
      if (ch == ERR)
        return lChar_EOF;
      wch = ch;
      ret = (ch >= KEY_MIN) ? KEY_CODE_YES : OK;
    }

  if (ret == KEY_CODE_YES)
    {
      // Special key
      lChar c = map_ncurses_key (wch);
      fetchlog ("fetch: special key → lChar=0x%lx\n", (unsigned long)c);
      keylog ("fetch: special key → lChar=0x%lx\n", (unsigned long)c);
      return c;
    }

  // Regular character (wchar_t)
  // Handle C-g (quit)
  if (wch == 7) // Ctrl-G
    {
      fetchlog ("fetch: C-g (quit)\n");
      keylog ("fetch: C-g (quit)\n");
      xsymbol_value (Vquit_flag) = Qt;
      return (lChar)wch;
    }

  // ncurses raw() mode sends LF (0x0a) for Enter; xyzzy expects CR (0x0d)
  if (wch == 0x0a)
    wch = 0x0d;

  lChar result = wchar_to_lchar ((wchar_t)wch);
  fetchlog ("fetch: wchar=%d → lChar=0x%lx\n", (int)wch, (unsigned long)result);
  keylog ("fetch: wchar=%d → lChar=0x%lx\n", (int)wch, (unsigned long)result);
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

  lChar c;
  if (ret == KEY_CODE_YES)
    c = map_ncurses_key (wch);
  else
    {
      if (wch == 0x0a)
        wch = 0x0d;
      c = wchar_to_lchar ((wchar_t)wch);
    }

  return c;
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
  lChar c;
  if (ret == KEY_CODE_YES)
    c = map_ncurses_key (wch);
  else
    {
      if (wch == 0x0a)
        wch = 0x0d;
      c = wchar_to_lchar ((wchar_t)wch);
    }
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
int kbd_queue::lookup_kbd_macro (lisp) const { return 0; }
int kbd_queue::toggle_ime (int, int) { return 0; }

void key_sequence::push (Char, int) {}
void key_sequence::done (Char, int) {}
