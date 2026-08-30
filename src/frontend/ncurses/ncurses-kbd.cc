// ncurses keyboard input: maps terminal keys to xyzzy lChar
#include "stdafx.h"
#include "ed.h"
#include "charset.h"

#include <ncurses.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/select.h>

#include "term.h"

void refresh_screen (int);
extern Terminal *buffer_terminal (const Buffer *bp);
extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
static lChar ncurses_key_to_lchar (int ret, wint_t wch);

// Send an ncurses key event to the terminal's pty.
// Returns 1 if the key was forwarded, 0 if not handled.
static int
send_key_to_terminal (const Buffer *bp, Terminal *term, int ret, wint_t wch)
{
  lChar c = ncurses_key_to_lchar (ret, wch);
  if (c == lChar_EOF)
    return 0;
  char buf[16];
  int len = terminal_key_to_bytes (term, c, buf, sizeof buf);
  if (len > 0)
    return buffer_terminal_send (bp, buf, len);
  return 0;
}

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
  // Enable button-event tracking (1002) for drag motion events
  printf ("\033[?1002h\033[?1006h");
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
    // Shift + arrow keys
    case KEY_SLEFT:     return CCF_LEFT  | CCF_SHIFT_BIT;
    case KEY_SRIGHT:    return CCF_RIGHT | CCF_SHIFT_BIT;
    case KEY_SR:        return CCF_UP    | CCF_SHIFT_BIT;  // shift-up (scroll reverse)
    case KEY_SF:        return CCF_DOWN  | CCF_SHIFT_BIT;  // shift-down (scroll forward)
    // Shift + other nav keys
    case KEY_SHOME:     return CCF_HOME  | CCF_SHIFT_BIT;
    case KEY_SEND:      return CCF_END   | CCF_SHIFT_BIT;
    case KEY_SPREVIOUS: return CCF_PRIOR | CCF_SHIFT_BIT;
    case KEY_SNEXT:     return CCF_NEXT  | CCF_SHIFT_BIT;
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

  // core is now UTF-16/UCS-4 internally: pass the Unicode code point
  // straight through as a LCKIND_CHAR lChar (LCKIND_CHAR == 0, and the
  // 21-bit payload field holds any code point up to 0x10FFFF).
  // No more w2i() folding into the old cp932 internal encoding.
  if (wc > 0)
    return (lChar)wc;

  return lChar_EOF;
}

// Convert ncurses wget_wch result to lChar (special key or character)
static lChar
ncurses_key_to_lchar (int ret, wint_t wch)
{
  if (ret == KEY_CODE_YES)
    {
      /* map_ncurses_key は旧 Char encoding (CCF_LEFT = 0xff04 等) を返す。
         そのまま lChar として扱うと kind タグが無い (=LCKIND_CHAR) ため、
         呼び出し側 (send_key_to_terminal → terminal_key_to_bytes 等、新
         encoding を前提とする経路) には「コードポイント 0xff04 の文字」
         にしか見えない。lc_from_ccf を通して kind=FNKEY 付きの正規の
         lChar に直す。 */
      lChar ccf = map_ncurses_key (wch);
      if (ccf == lChar_EOF)
        return lChar_EOF;
      return lc_from_ccf (Char (ccf));
    }
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

/* --- 直近の打鍵の記録 ----------------------------------------------------
 *
 * `get-recent-keys` (`C-h l` = `view-lossage`) が読む。**端末では
 * ncurses-stubs.cc の「nil を返す」スタブだったので、view-lossage は
 * 空の *Help* を出していた。**
 *
 * Win32 側 (src/frontend/win32/kbd.cc の `copy_queue`) は**入力キューの環状
 * バッファをそのまま履歴として使う** (head が進んだ後ろに消費済みの打鍵が
 * 残るので、head から後ろへ辿る)。端末側の `fetch` は端末から読んだ字を
 * `cc[]` を経由せずに返すので、その履歴が空になる。
 *
 * **入力キューには手を出さない。** 別に小さな環を持つ方が、待ちと取り消しの
 * 絡んだキューの不変条件に触らずに済む。fetch が返す所を通すだけにした
 * (再帰で呼び直す枝は内側が記録する)。
 */

enum {RECENT_KEYS_MAX = 128};
static Char recent_keys[RECENT_KEYS_MAX];
static long recent_keys_count;   /* 書いた総数。環の位置はこれを割った余り */

static inline lChar
record_key (lChar c)
{
  /* メニューの選択と EOF は打鍵ではない (Win32 側の copy_queue も外す)。 */
  if (c != lChar_EOF && !(c & LCHAR_MENU))
    {
      recent_keys[recent_keys_count % RECENT_KEYS_MAX] = Char (c);
      recent_keys_count++;
    }
  return c;
}

/* 古い順に詰めて返す。src/frontend/ncurses/ncurses-stubs.cc の
   `Fget_recent_keys` が呼ぶ。 */
int
ncurses_copy_recent_keys (Char *b, int size)
{
  long n = recent_keys_count;
  if (n > RECENT_KEYS_MAX)
    n = RECENT_KEYS_MAX;
  if (n > size)
    n = size;
  long first = recent_keys_count - n;
  for (long i = 0; i < n; i++)
    b[i] = recent_keys[(first + i) % RECENT_KEYS_MAX];
  return int (n);
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
      return record_key (c);
    }

  // Check internal queue
  if (head != tail)
    {
      lChar c = cc[head];
      head = (head + 1) % QUEUE_MAX;
      fetchlog ("fetch: from queue 0x%lx\n", (unsigned long)c);
      return record_key (c);
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

  /* コマンドの *途中* で待つ場合、ここまでに書いたものが端末へ出ていない。
     コマンドループは「コマンドが終わったら描く」形 (command_loop の
     refresh_screen) なので、read-char で待つコマンドは描かれないまま
     待ちに入る。isearch / query-replace / Leader メニューのプロンプトが
     画面に出ないのはこれだった (issue #66)。

     wait で見分けている: コマンドループは fetch (1, ...) を、直前に
     refresh_screen を済ませてから呼ぶ。コマンドの途中の read-char は
     stream.cc から fetch (0, 0) で来る。**打鍵ごとに 2 回描かないため**に
     この区別が要る (ncurses の refresh_screen は毎回全ウィンドウの
     glyph を作り直すので、余分な 1 回が効く)。 */
  if (!wait)
    refresh_screen (0);

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

      /* 100ms timeout: allows periodic process polling and resize checks.
         **ユーザタイマの期限が先に来るならそちらに合わせる。** POSIX には
         `SetTimer` に相当するものが無いので、**待つ側が期限を見るしかない**
         (src/core/utimer.cc)。ここを 100ms 固定にしていたため
         `start-timer` が使えず、`lisp/ts.l` の遅延ハイライトと
         `lisp/grepd.l` の非同期 grep が動かなかった。 */
      int timeout_ms = 100;
      int next = app.user_timer.next_timeout_ms ();
      if (next >= 0 && next < timeout_ms)
        timeout_ms = next;

      struct timeval tv;
      tv.tv_sec = timeout_ms / 1000;
      tv.tv_usec = (timeout_ms % 1000) * 1000;

      int sel = select (maxfd + 1, &rfds, 0, 0, &tv);

      /* **期限が来たものを呼ぶ。** select が入力で戻ったときも見る:
         打鍵が続いている間タイマが止まると、入力中こそ動いてほしい
         遅延ハイライトが動かない。

         `timer ()` は Lisp を呼ぶので、**その中で画面が変わることがある。**
         入力を読む前に呼んでおく (読んだあとだと、そのキーの処理と
         入れ替わって順序が読めなくなる)。 */
      if (app.user_timer.next_timeout_ms () == 0)
        {
          try {app.user_timer.timer ();} catch (nonlocal_jump &) {}
          refresh_screen (0);
        }

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
              return record_key (c);
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
                      return record_key (mc);
                    }
                  continue;
                }

              // Terminal key forwarding: if selected window has a terminal,
              // send key to pty instead of xyzzy command loop.
              // Keys bound in *terminal-map* go to command loop.
              // Skip terminal check when in prefix key sequence (g_map not finished).
              {
                extern int g_map_finished_p ();
                Window *sw = selected_window ();
                if (sw && sw->w_bufp && !sw->minibuffer_window_p ()
                    && g_map_finished_p () && !kbd_inhibit_terminal_forward)
                  {
                    Terminal *tw = buffer_terminal (sw->w_bufp);
                    if (tw)
                      {
                        lChar lc = ncurses_key_to_lchar (ret, wch);
                        if (lc != lChar_EOF)
                          {
                            // Check *terminal-map*: if key is bound,
                            // let command loop handle it.
                            /* lc は下位 16bit に落とさずそのまま渡す
                               (win32 側と同じ理由。parse_keymap は
                               normalize_for_keymap を通すので旧 encoding も
                               新 encoding も受けられる)。 */
                            lisp tmap = xsymbol_value (Vterminal_map);
                            if (tmap != Qnil && tmap != Qunbound)
                              {
                                lisp km = Fkeymapp (tmap);
                                if (km != Qnil && parse_keymap (lc, km) != Qnil)
                                  break;  // → command loop
                              }
                            if (send_key_to_terminal (sw->w_bufp, tw, ret, wch))
                              continue;
                          }
                      }
                  }
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
  if (result == lChar_EOF)
    {
      fetchlog ("fetch: unmapped key ret=%d wch=%d (0x%x), ignoring\n",
                ret, (int)wch, (int)wch);
      // Recurse to get next valid key (avoid returning EOF which exits the editor)
      return fetch (wait, 0);
    }

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
  return record_key (result);
}

lChar
kbd_queue::peek (int)
{
  /* peek in xyzzy is actually a non-blocking fetch (consumes the character)

     **ここも記録する。** 名前は peek だが字を消費するので、`fetch` だけを
     記録していると **ミニバッファに打った字と、まとめて届いた打鍵が
     view-lossage から抜ける** (実測: `abc` を 1 回の書き込みで送ると `a`
     しか残らなかった)。 */
  if (pending != lChar_EOF)
    {
      lChar c = pending;
      pending = lChar_EOF;
      return record_key (c);
    }
  if (head != tail)
    {
      lChar c = cc[head];
      head = (head + 1) % QUEUE_MAX;
      return record_key (c);
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
      return record_key (mc);  // may be lChar_EOF if unhandled
    }

  return record_key (ncurses_key_to_lchar (ret, wch));
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
