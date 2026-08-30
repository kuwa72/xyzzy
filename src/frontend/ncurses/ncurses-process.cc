// POSIX subprocess implementation for ncurses frontend
// Replaces Win32 CreateProcess + threads with fork/exec + select()

#include "stdafx.h"
#include "ed.h"
#include "byte-stream.h"
#include "mainframe.h"

#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#ifdef __APPLE__
#include <util.h>
#else
#include <pty.h>
#endif
#include <termios.h>
#include <errno.h>

void refresh_screen (int);

#include "term.h"

/* `:environ' で渡された (("NAME" . "VALUE") ...) を execve に渡す配列に
   する。値が nil の項は**その名前を消す**。

   **fork の前に作る。** 子の中で `setenv' を呼ぶ方が短いが、`setenv' は
   malloc するので、**fork した瞬間に別のスレッドが malloc のロックを
   持っていると子が固まる。** xyzzy はスレッドを使う。子の中で呼んで良いのは
   `open' / `dup2' / `chdir' / `signal' / `exec*' のような async-signal-safe な
   ものだけなので、配列は親で組んで `execve' に渡す。

   **1 塊の xmalloc で確保して、その先頭を BLOCK で返す。** 配列は塊の途中を
   指すので、`xfree (envp)' では解放できない (呼ぶ側は BLOCK を xfree する)。
   lenv が nil なら 0 を返す — その場合は呼ぶ側が `environ' をそのまま使う。 */
static char **
build_environ (lisp lenv, void *&block)
{
  block = 0;
  if (!consp (lenv))
    return 0;

  /* まず要る大きさを測る。既存の environ の数 + 指定の数 + 終端。 */
  size_t nenv = 0;
  for (char **e = environ; e && *e; e++, nenv++)
    ;
  size_t nspec = 0, lspec = 0;
  for (lisp le = lenv; consp (le); le = xcdr (le))
    {
      lisp x = xcar (le);
      if (!consp (x) || !stringp (xcar (x)))
        continue;
      nspec++;
      lspec += i2u8l (xstring_contents (xcar (x)), xstring_length (xcar (x))) + 2;
      if (stringp (xcdr (x)))
        lspec += i2u8l (xstring_contents (xcdr (x)), xstring_length (xcdr (x)));
    }

  size_t nptr = nenv + nspec + 1;
  size_t lb = (lspec + sizeof (char *) - 1) / sizeof (char *) * sizeof (char *);
  char *buf = (char *)xmalloc (lb + sizeof (char *) * nptr);
  block = buf;
  char **envp = (char **)(buf + lb);

  size_t n = 0;
  for (char **e = environ; e && *e; e++)
    envp[n++] = *e;

  /* 指定を上書きする。**名前が同じものを差し替える** — 後ろに足すだけだと
     execve に同じ名前が 2 つ並び、どちらが効くかは処理系任せになる。 */
  char *b = buf;
  for (lisp le = lenv; consp (le); le = xcdr (le))
    {
      lisp x = xcar (le);
      if (!consp (x) || !stringp (xcar (x)))
        continue;

      char *entry = b;
      b = i2u8 (xstring_contents (xcar (x)), xstring_length (xcar (x)), b);
      size_t namelen = b - entry;
      *b++ = '=';
      if (stringp (xcdr (x)))
        b = i2u8 (xstring_contents (xcdr (x)), xstring_length (xcdr (x)), b);
      *b++ = 0;

      int found = 0;
      for (size_t i = 0; i < n; i++)
        if (!strncmp (envp[i], entry, namelen) && envp[i][namelen] == '=')
          {
            if (xcdr (x) == Qnil)
              {
                /* 消す: 後ろを詰める。 */
                for (size_t j = i; j + 1 < n; j++)
                  envp[j] = envp[j + 1];
                n--;
              }
            else
              envp[i] = entry;
            found = 1;
            break;
          }
      if (!found && xcdr (x) != Qnil)
        envp[n++] = entry;
    }
  envp[n] = 0;
  return envp;
}

// ============================================================
// Process class — POSIX implementation
// ============================================================

/* 共通部分は core の `ProcessBase' (src/core/process-base.h) にある。
   ここに残るのは POSIX の実体だけ: pid、パイプ 2 本、端末エミュレータ。 */
class Process : public ProcessBase
{
  pid_t p_pid;
  int p_read_fd;   // pipe: child stdout/stderr → parent read
  int p_write_fd;  // pipe: parent write → child stdin
  Terminal *p_term; // VT100 terminal emulator

  void insert_output (const Char *data, int size);

public:
  Process (Buffer *bp, lisp pl, lisp marker);
  ~Process ();

  void create (lisp command, lisp execdir, lisp lenv);
  void poll_output ();
  void terminated ();
  void send (const char *s, int l) const;
  void signal_proc ();
  void kill_proc ();

  /* **この 3 つは基底に上げない。** fd も `Terminal' も Win32 には対応する
     概念が無く、置くと基底がプラットフォームを知ることになる。呼ぶ側は
     下の `posix_process ()' で降ろす。 */
  int read_fd () const { return p_read_fd; }
  pid_t pid () const { return p_pid; }
  Terminal *term () const { return p_term; }
};

/* `xprocess_data' は core の基底を返すので、上の POSIX 固有のメソッドを
   呼ぶ所だけここで降ろす。 */
static inline Process *
posix_process (lisp p)
{
  return static_cast <Process *> (xprocess_data (p));
}

Process::Process (Buffer *bp, lisp pl, lisp marker)
     : ProcessBase (bp, pl, marker),
       p_pid (-1), p_read_fd (-1), p_write_fd (-1), p_term (0)
{
}

Process::~Process ()
{
  if (p_read_fd >= 0)
    close (p_read_fd);
  // p_write_fd == p_read_fd when using pty; only close once
  if (p_write_fd >= 0 && p_write_fd != p_read_fd)
    close (p_write_fd);
  if (p_pid > 0)
    {
      int status;
      waitpid (p_pid, &status, WNOHANG);
    }
  delete p_term;
}

void
Process::create (lisp command, lisp execdir, lisp lenv)
{
  /* A Unix command line and a Unix pathname are UTF-8 bytes, not CP932. */
  char *cmdline = (char *)alloca (i2u8l (xstring_contents (command),
                                         xstring_length (command)));
  i2u8 (xstring_contents (command), xstring_length (command), cmdline);

  char dir[PATH_MAX * 2 + 1];
  pathname2u8 (execdir, dir);

  /* **fork の前に組む** (build_environ の注を参照)。 */
  void *envblock;
  char **envp = build_environ (lenv, envblock);

  // Use forkpty() to give the child a pseudo-terminal.
  // This enables shell prompts, line editing, and terminal-aware
  // programs (less, vi, etc.) to work correctly.
  int master_fd;
  struct winsize ws;
  ws.ws_row = 24;
  ws.ws_col = 80;
  ws.ws_xpixel = 0;
  ws.ws_ypixel = 0;

  pid_t pid = forkpty (&master_fd, NULL, NULL, &ws);
  if (pid < 0)
    {
      xfree (envblock);         /* FEsimple_error は longjmp する */
      FEsimple_error (Ecreate_thread_failed);
    }

  if (pid == 0)
    {
      // Child process — already has pty as stdin/stdout/stderr
      if (*dir && chdir (dir) < 0)
        ;  // ignore chdir failure in child

      // Reset signal handlers
      signal (SIGINT, SIG_DFL);
      signal (SIGQUIT, SIG_DFL);
      signal (SIGPIPE, SIG_DFL);

      if (envp)
        {
          char *argv[] = {(char *)"sh", (char *)"-c", cmdline, 0};
          execve ("/bin/sh", argv, envp);
        }
      else
        execl ("/bin/sh", "sh", "-c", cmdline, (char *)0);
      _exit (127);
    }

  xfree (envblock);

  // Parent process — single master fd for both read and write
  p_read_fd = master_fd;
  p_write_fd = master_fd;
  p_pid = pid;

  // Keep ONLCR enabled — the pty line discipline converts \n to \r\n,
  // and the terminal emulator handles \r and \n separately.

  // Set master fd to non-blocking
  int flags = fcntl (master_fd, F_GETFL, 0);
  fcntl (master_fd, F_SETFL, flags | O_NONBLOCK);

  // Create terminal emulator matching pty size
  p_term = new Terminal (ws.ws_row, ws.ws_col);
}

void
Process::insert_output (const Char *data, int size)
{
  if (!size)
    return;

  try
    {
      if (p_filter != Qnil)
        {
          dynamic_bind d (Vinhibit_quit, Qt);
          lisp s = make_string (data, size);
          funcall_2 (p_filter, p_proc, s);
        }
      else
        {
          Window *wp = selected_window ();
          if (xmarker_point (p_marker) == NO_MARK_SET)
            xmarker_point (p_marker) = p_bufp->b_contents.p2;
          int goto_tail = (wp->w_bufp == p_bufp
                           && wp->w_point.p_point == xmarker_point (p_marker));
          Point point;
          p_bufp->set_point (point, xmarker_point (p_marker));
          p_bufp->check_read_only ();
          p_bufp->insert_chars (point, data, size);
          xmarker_point (p_marker) += size;
          if (goto_tail)
            p_bufp->goto_char (wp->w_point, xmarker_point (p_marker));
          int f = 0;
          for (wp = app.active_frame.windows; wp; wp = wp->w_next)
            if (wp->w_bufp == p_bufp)
              {
                wp->w_disp_flags |= Window::WDF_REFRAME_SCROLL;
                f = 1;
              }
          if (f)
            refresh_screen (0);
        }
    }
  catch (nonlocal_jump &)
    {
    }
}

// Read available output from child process and feed to terminal emulator
void
Process::poll_output ()
{
  u_char rawbuf[4096];
  int fed = 0;

  // Drain all immediately available output in one go.  Some pty drivers
  // (WSL2 in particular) do not always wake select() for small chunks that
  // arrive right after an idle period; reading until EAGAIN makes sure we do
  // not leave echoed bytes sitting in the pty buffer.
  for (;;)
    {
      ssize_t n = read (p_read_fd, rawbuf, sizeof rawbuf);
      if (n < 0)
        {
          if (errno == EAGAIN)
            break;
          // Real read error: process what we have already read, if any.
          if (!fed)
            return;
          break;
        }
      if (n == 0)
        {
          // EOF: caller (poll_processes) will reap the process.  Process any
          // bytes already read below.
          break;
        }

      fed = 1;

      if (p_term)
        p_term->feed (rawbuf, (int)n);
      else
        {
          // Fallback: no terminal emulator, insert raw output
          // (This path is used when terminal is not available)
          Char outbuf[4096];
          int outlen = 0;
          for (int i = 0; i < (int)n && outlen < (int)numberof (outbuf); i++)
            outbuf[outlen++] = (Char)rawbuf[i];
          insert_output (outbuf, outlen);
        }
    }

  if (!fed || !p_term)
    return;

  // feed() の中で DSR / DA の応答が積まれていたら pty へ返す。win32 の
  // ConPtyProcess::read_process は元からこれをやっているが、ncurses 側は
  // 抜けていた。返さないと、起動時にカーソル位置や端末種別を問い合わせて
  // から描画するタイプの TUI が、応答を待ってスタートアップで止まったり
  // 既定値で誤ったレイアウトを組んだりする。
  if (p_term->reply_len ())
    {
      send (p_term->reply_data (), p_term->reply_len ());
      p_term->reply_clear ();
    }

  // OSC 52 (クリップボード書き込み)。ncurses には自前のクリップボード
  // API が無いので、自分を包んでいる本物の端末 (Windows Terminal /
  // X11 / Wayland 端末) へそのまま中継する — tmux の
  // allow-passthrough と同じ発想。読み出し (?) は Terminal 側で
  // すでに弾いてあるので、ここに来るのは書き込みだけ。
  if (p_term->clipboard_pending ())
    {
      printf ("\033]%s\a", p_term->clipboard_raw ());
      fflush (stdout);
      p_term->clipboard_clear ();
    }

  // Trigger screen refresh — render_terminal_window will read
  // directly from the TermCell grid, no buffer sync needed.
  if (p_term->dirty ())
    {
      for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
        if (wp->w_bufp == p_bufp)
          {
            refresh_screen (0);
            break;
          }
    }
}

void
Process::terminated ()
{
  int status;
  int exit_code = 0;
  if (p_pid > 0)
    {
      if (waitpid (p_pid, &status, WNOHANG) > 0)
        {
          if (WIFEXITED (status))
            exit_code = WEXITSTATUS (status);
          else if (WIFSIGNALED (status))
            exit_code = 128 + WTERMSIG (status);
        }
      p_pid = -1;
    }

  if (p_read_fd >= 0)
    {
      close (p_read_fd);
      // p_write_fd == p_read_fd when using pty; don't close twice
      if (p_write_fd == p_read_fd)
        p_write_fd = -1;
      p_read_fd = -1;
    }
  if (p_write_fd >= 0)
    {
      close (p_write_fd);
      p_write_fd = -1;
    }

  xprocess_data (p_proc) = 0;
  xprocess_status (p_proc) = PS_EXIT;
  xprocess_exit_code (p_proc) = exit_code;

  delq (p_proc, &xsymbol_value (Vprocess_list));

  if (p_sentinel != Qnil)
    {
      try
        {
          dynamic_bind d (Vinhibit_quit, Qt);
          funcall_1 (p_sentinel, p_proc);
        }
      catch (nonlocal_jump &)
        {
        }
    }

  p_bufp->modify_mode_line ();
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_bufp == p_bufp)
      {
        refresh_screen (0);
        break;
      }
}

void
Process::send (const char *s, int l) const
{
  while (l > 0)
    {
      ssize_t n = write (p_write_fd, s, l);
      if (n < 0)
        {
          if (errno == EINTR)
            continue;
          file_error (errno);
        }
      s += n;
      l -= n;
    }
}

void
Process::signal_proc ()
{
  if (p_pid > 0)
    ::kill (p_pid, SIGINT);
}

void
Process::kill_proc ()
{
  if (p_pid > 0)
    ::kill (p_pid, SIGKILL);
}

// ============================================================
// Helper: check if process is still alive, reap if dead
// ============================================================

static int
check_process_alive (Process *pr)
{
  if (!pr || pr->pid () <= 0)
    return 0;
  int status;
  pid_t ret = waitpid (pr->pid (), &status, WNOHANG);
  if (ret == 0)
    return 1;  // still running
  return 0;    // exited or error
}

// ============================================================
// Poll all running processes; reap terminated ones
// Called from fetch() select loop
// ============================================================

void
poll_processes ()
{
  int any_terminated = 0;
restart:
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (!pr)
        continue;

      // Try to read output
      pr->poll_output ();

      // Check if child has exited (read() would have returned 0/error above)
      if (!check_process_alive (pr))
        {
          // Drain any remaining output
          for (;;)
            {
              u_char tmp[1024];
              ssize_t n = read (pr->read_fd (), tmp, sizeof tmp);
              if (n <= 0)
                break;
              // Process the last bits (simplified: just poll_output again)
            }
          pr->terminated ();
          Process *old_pr = pr;
          delete old_pr;
          any_terminated = 1;
          // Restart iteration since list was modified
          goto restart;
        }
    }
}

// Collect all process read fds into fd_set, return max fd
int
collect_process_fds (fd_set *fds)
{
  int maxfd = -1;
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (pr && pr->read_fd () >= 0)
        {
          FD_SET (pr->read_fd (), fds);
          if (pr->read_fd () > maxfd)
            maxfd = pr->read_fd ();
        }
    }
  return maxfd;
}

// ============================================================
// Encoding helpers (shared with Win32 process.cc)
// ============================================================

/* process_char_encoding と process_io_encoding は src/core/process-lisp.cc へ
   移した (win32 側と 1 文字も違わなかった)。

   process_eol_code は**中身が違う**ので残る。**この関数がプラットフォームの
   違いそのもの**で、既定の改行コードが POSIX は LF、Win32 は CRLF になる。
   core から呼ばれるので static を外した (宣言は src/core/fns.h)。 */
eol_code
process_eol_code (lisp code)
{
  if (code == Qnil)
    return eol_lf;  // POSIX default: LF (not CRLF like Win32)
  int n = fixnum_value (code);
  if (!valid_eol_code_p (n) || n == eol_guess)
    n = eol_lf;
  return eol_code (n);
}

// ============================================================
// process_output_byte_stream — for Fprocess_send_string encoding
// ============================================================

class process_output_byte_stream: public byte_output_stream
{
  Process &p_proc;
  u_char p_buf[1024];
protected:
  virtual u_char *sflush (u_char *b, u_char *be, int)
    {
      p_proc.send ((char *)b, be - b);
      return b;
    }
public:
  process_output_byte_stream (Process &proc)
       : byte_output_stream (p_buf, p_buf + sizeof p_buf), p_proc (proc) {}
};

// ============================================================
// Lisp functions: synchronous process
// ============================================================

lisp
Fcall_process (lisp cmd, lisp keys)
{
  check_string (cmd);

  char *cmdline = (char *)alloca (i2u8l (xstring_contents (cmd),
                                         xstring_length (cmd)));
  i2u8 (xstring_contents (cmd), xstring_length (cmd), cmdline);

  int no_std_handles = find_keyword_bool (Kno_std_handles, keys);

  lisp lstdin = find_keyword (Kinput, keys);
  lisp lstdout = find_keyword (Koutput, keys);
  lisp lstderr = find_keyword (Kerror, keys, 0);
  if (!lstderr)
    lstderr = lstdout;

  char infile[PATH_MAX * 2 + 1] = "", outfile[PATH_MAX * 2 + 1] = "",
       errfile[PATH_MAX * 2 + 1] = "";
  if (!no_std_handles)
    {
      if (stringp (lstdin))
        pathname2u8 (lstdin, infile);
      else if (lstdin == Qnil)
        strcpy (infile, "/dev/null");

      if (stringp (lstdout))
        pathname2u8 (lstdout, outfile);
      else if (lstdout == Qnil)
        strcpy (outfile, "/dev/null");

      if (lstdout != lstderr)
        {
          if (stringp (lstderr))
            pathname2u8 (lstderr, errfile);
          else if (lstderr == Qnil)
            strcpy (errfile, "/dev/null");
        }
    }

  lisp exec_dir = find_keyword (Kexec_directory, keys);
  if (exec_dir == Qnil)
    exec_dir = selected_buffer ()->ldirectory;
  char dir[PATH_MAX * 2 + 1];
  pathname2u8 (exec_dir, dir);

  lisp wait = find_keyword (Kwait, keys);
  if (wait != Qnil && !realp (wait))
    wait = Qt;

  /* **fork の前に組む** (build_environ の注を参照)。 */
  void *envblock;
  char **envp = build_environ (find_keyword (Kenviron, keys), envblock);

  pid_t pid = fork ();
  if (pid < 0)
    {
      xfree (envblock);         /* FEsimple_error は longjmp する */
      FEsimple_error (Ecreate_thread_failed);
    }

  if (pid == 0)
    {
      // Child
      if (!no_std_handles)
        {
          if (*infile)
            {
              int fd = open (infile, O_RDONLY);
              if (fd >= 0) { dup2 (fd, STDIN_FILENO); close (fd); }
            }
          if (*outfile)
            {
              int fd = open (outfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
              if (fd >= 0) { dup2 (fd, STDOUT_FILENO); close (fd); }
            }
          if (lstdout != lstderr && *errfile)
            {
              int fd = open (errfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
              if (fd >= 0) { dup2 (fd, STDERR_FILENO); close (fd); }
            }
          else if (lstdout == lstderr && *outfile)
            {
              // stderr → same as stdout
              dup2 (STDOUT_FILENO, STDERR_FILENO);
            }
        }

      if (*dir && chdir (dir) < 0)
        ;  // ignore chdir failure in child

      signal (SIGINT, SIG_DFL);
      signal (SIGQUIT, SIG_DFL);
      signal (SIGPIPE, SIG_DFL);

      if (envp)
        {
          char *argv[] = {(char *)"sh", (char *)"-c", cmdline, 0};
          execve ("/bin/sh", argv, envp);
        }
      else
        execl ("/bin/sh", "sh", "-c", cmdline, (char *)0);
      _exit (127);
    }

  // Parent
  xfree (envblock);
  DWORD exit_code = 0;
  if (wait == Qt)
    {
      int status;
      while (waitpid (pid, &status, 0) < 0 && errno == EINTR)
        ;
      if (WIFEXITED (status))
        exit_code = WEXITSTATUS (status);
      else if (WIFSIGNALED (status))
        exit_code = 128 + WTERMSIG (status);
    }
  else if (wait != Qnil)
    {
      // Wait for a specified time (not very useful on POSIX, but honor the API)
      double w = coerce_to_double_float (wait);
      if (w > 0)
        usleep ((useconds_t)(w * 1000000));
    }

  return wait == Qt ? make_fixnum (exit_code) : Qt;
}

// ============================================================
// Lisp functions: asynchronous process
// ============================================================

lisp
Fmake_process (lisp command, lisp keys)
{
  check_string (command);

  lisp execdir = find_keyword (Kexec_directory, keys);
  if (execdir == Qnil)
    execdir = selected_buffer ()->ldirectory;

  Buffer *bp = Buffer::coerce_to_buffer (find_keyword (Koutput, keys));
  if (buffer_has_process (bp))
    FEsimple_error (Esubprocess_is_already_running);

  lisp incode, outcode;
  process_io_encoding (incode, outcode, keys);
  lisp x = find_keyword (Keol_code, keys, 0);
  if (!x)
    x = find_keyword (Knewline_code, keys);
  eol_code eol = process_eol_code (x);

  lisp process = make_process ();
  lisp pl = xcons (process, xsymbol_value (Vprocess_list));

  xprocess_buffer (process) = bp->lbp;
  xprocess_command (process) = command;
  xprocess_incode (process) = incode;
  xprocess_outcode (process) = outcode;
  xprocess_eol_code (process) = eol;

  Process *pr = new Process (bp, process, Process::make_process_marker (bp));
  try
    {
      pr->create (command, execdir, find_keyword (Kenviron, keys));
    }
  catch (nonlocal_jump &)
    {
      delete pr;
      throw;
    }

  xsymbol_value (Vprocess_list) = pl;
  xprocess_data (process) = pr;
  xprocess_status (process) = PS_RUN;

  bp->lprocess = process;
  bp->modify_mode_line ();

  return process;
}

// ============================================================
// Lisp accessor functions
// ============================================================

int
buffer_has_process (const Buffer *bp)
{
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    if (xprocess_data (xcar (p))
        && xprocess_data (xcar (p))->process_buffer () == bp->lbp)
      return 1;
  return 0;
}

Terminal *
buffer_terminal (const Buffer *bp)
{
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (pr && pr->process_buffer () == bp->lbp && pr->term ())
        return pr->term ();
    }
  return 0;
}

void
buffer_terminal_resize (const Buffer *bp, int rows, int cols)
{
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (pr && pr->process_buffer () == bp->lbp && pr->term ())
        {
          Terminal *t = pr->term ();
          if (t->rows () != rows || t->cols () != cols)
            {
              t->resize (rows, cols);
              // Notify the pty of the new size
              if (pr->read_fd () >= 0)
                {
                  struct winsize ws;
                  ws.ws_row = rows;
                  ws.ws_col = cols;
                  ws.ws_xpixel = 0;
                  ws.ws_ypixel = 0;
                  ioctl (pr->read_fd (), TIOCSWINSZ, &ws);
                }
            }
          return;
        }
    }
}

// Send raw bytes to the pty of a buffer's terminal process.
// Returns 1 if sent, 0 if no terminal process found.
int
buffer_terminal_send (const Buffer *bp, const char *data, int len)
{
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (pr && pr->process_buffer () == bp->lbp && pr->term ()
          && pr->read_fd () >= 0)
        {
          // write_fd == read_fd for pty
          while (len > 0)
            {
              ssize_t n = write (pr->read_fd (), data, len);
              if (n < 0)
                {
                  if (errno == EINTR) continue;
                  break;
                }
              data += n;
              len -= n;
            }
          return 1;
        }
    }
  return 0;
}

int
query_kill_subprocesses ()
{
  if (!consp (xsymbol_value (Vprocess_list)))
    return 1;
  if (!yes_or_no_p (Msubprocesses_are_running))
    return 0;
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    if (xprocess_data (xcar (p)))
      xprocess_data (xcar (p))->signal_proc ();
  return 1;
}

void
process_gc_mark (void (*fn)(lisp))
{
  for (lisp p = xsymbol_value (Vprocess_list); consp (p); p = xcdr (p))
    {
      Process *pr = posix_process (xcar (p));
      if (pr)
        {
          (*fn)(pr->filter ());
          (*fn)(pr->sentinel ());
          (*fn)(pr->marker ());
        }
    }
}




















// ============================================================
// Stubs for Win32-only functions
// ============================================================

void read_process_output (WPARAM, LPARAM) {}
void wait_process_terminate (WPARAM, LPARAM) {}

lisp
Fopen_network_stream (lisp, lisp, lisp, lisp)
{
  FEsimple_error (Ecreate_thread_failed);
  return Qnil;
}

lisp
Fshell_execute (lisp, lisp, lisp, lisp)
{
  FEsimple_error (Ecreate_thread_failed);
  return Qnil;
}

// ============================================================
// sit-for / sleep-for
// ============================================================

/* **待っている間もユーザタイマを動かす。** Win32 の `sleep-for` は
   メッセージループを回すのでその間もタイマが動く。POSIX で 1 回の `select` で
   寝てしまうと、`(start-timer 0.5 f)` のあと `(sleep-for 0.2)` で待つコードが
   永遠に進まない (unittest の `fix-start-timer` がまさにその形)。

   期限が来ているものを呼ぶ。`timer ()` は Lisp を呼ぶので、投げてきたものは
   ここで捨てる (待っている側は待ち続けるのが筋)。 */
static void
run_due_timers ()
{
  if (app.user_timer.next_timeout_ms () == 0)
    {
      try {app.user_timer.timer ();} catch (nonlocal_jump &) {}
    }
}

/* 次に `select` で待つ長さ (ミリ秒)。残り時間とタイマの期限の小さい方。
   **0 は返さない** — 0 で回すと、期限が過ぎたまま進まないタイマがあったとき
   busy loop になる。 */
static int
wait_slice_ms (double remaining_sec)
{
  int slice = int (remaining_sec * 1000);
  if (slice > 100)
    slice = 100;                /* プロセスの監視と同じ刻み */
  int next = app.user_timer.next_timeout_ms ();
  if (next >= 0 && next < slice)
    slice = next;
  return slice > 0 ? slice : 1;
}

static void
fill_timeval (struct timeval &tv, int ms)
{
  tv.tv_sec = ms / 1000;
  tv.tv_usec = (ms % 1000) * 1000;
}

lisp
Fsit_for (lisp timeout, lisp nodisp)
{
  double sec = coerce_to_double_float (timeout);
  if (sec <= 0)
    return Qt;

  double remaining = sec;
  while (remaining > 0)
    {
      run_due_timers ();

      fd_set rfds;
      FD_ZERO (&rfds);
      FD_SET (STDIN_FILENO, &rfds);
      int maxfd = STDIN_FILENO;

      // Also monitor process fds
      int pmax = collect_process_fds (&rfds);
      if (pmax > maxfd)
        maxfd = pmax;

      int ms = wait_slice_ms (remaining);
      struct timeval tv;
      fill_timeval (tv, ms);

      int ret = select (maxfd + 1, &rfds, 0, 0, &tv);
      if (ret > 0)
        {
          // Check process fds first
          poll_processes ();
          if (FD_ISSET (STDIN_FILENO, &rfds))
            return Qnil;  // keyboard input available
        }
      else if (ret == 0)
        {
          // Timeout: poll processes in case any terminated
          poll_processes ();
        }
      remaining -= ms / 1000.0;
    }
  run_due_timers ();
  return Qt;
}

lisp
Fsleep_for (lisp timeout)
{
  double sec = coerce_to_double_float (timeout);
  if (sec <= 0)
    return Qt;

  double remaining = sec;
  while (remaining > 0)
    {
      run_due_timers ();

      // Sleep but still poll processes
      fd_set rfds;
      FD_ZERO (&rfds);
      int maxfd = -1;
      int pmax = collect_process_fds (&rfds);
      if (pmax > maxfd)
        maxfd = pmax;

      int ms = wait_slice_ms (remaining);
      struct timeval tv;
      fill_timeval (tv, ms);

      if (maxfd >= 0)
        {
          // Monitor process fds during sleep
          int ret = select (maxfd + 1, &rfds, 0, 0, &tv);
          if (ret > 0)
            poll_processes ();
        }
      else
        {
          // No processes, just sleep
          select (0, 0, 0, 0, &tv);
        }
      remaining -= ms / 1000.0;
    }
  run_due_timers ();
  return Qt;
}
