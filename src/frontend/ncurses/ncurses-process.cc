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
#include <errno.h>

void refresh_screen (int);

// ============================================================
// Process class — POSIX implementation
// ============================================================

class Process
{
  Buffer *p_bufp;
  lisp p_proc;
  lisp p_filter;
  lisp p_sentinel;
  lisp p_last_incode;
  lisp p_marker;
  pid_t p_pid;
  int p_read_fd;   // pipe: child stdout/stderr → parent read
  int p_write_fd;  // pipe: parent write → child stdin

  void insert_output (const Char *data, int size);

public:
  Process (Buffer *bp, lisp pl, lisp marker);
  ~Process ();

  void create (lisp command, lisp execdir);
  void poll_output ();
  void terminated ();
  void send (const char *s, int l) const;
  void signal_proc () const;
  void kill_proc () const;

  lisp process_buffer () const { return p_bufp->lbp; }
  lisp &filter () { return p_filter; }
  lisp &sentinel () { return p_sentinel; }
  lisp &marker () { return p_marker; }
  int read_fd () const { return p_read_fd; }
  pid_t pid () const { return p_pid; }

  int incode_modified_p () const
    { return xprocess_incode (p_proc) != p_last_incode; }
  eol_code eolcode () const { return xprocess_eol_code (p_proc); }

  static lisp make_process_marker (Buffer *bp)
    {
      lisp marker = Fmake_marker (bp->lbp);
      xmarker_point (marker) = bp->b_contents.p2;
      return marker;
    }
};

Process::Process (Buffer *bp, lisp pl, lisp marker)
     : p_bufp (bp), p_proc (pl), p_filter (Qnil), p_sentinel (Qnil),
       p_last_incode (Qnil), p_marker (marker),
       p_pid (-1), p_read_fd (-1), p_write_fd (-1)
{
}

Process::~Process ()
{
  if (p_read_fd >= 0)
    close (p_read_fd);
  if (p_write_fd >= 0)
    close (p_write_fd);
  if (p_pid > 0)
    {
      int status;
      waitpid (p_pid, &status, WNOHANG);
    }
}

void
Process::create (lisp command, lisp execdir)
{
  char *cmdline = (char *)alloca (xstring_length (command) * 2 + 1);
  w2s (cmdline, command);

  char dir[PATH_MAX + 1];
  pathname2cstr (execdir, dir);

  // Create pipes: parent reads from out_pipe[0], child writes to out_pipe[1]
  //               child reads from in_pipe[0], parent writes to in_pipe[1]
  int out_pipe[2], in_pipe[2];
  if (pipe (out_pipe) < 0)
    FEsimple_error (Ecreate_thread_failed);
  if (pipe (in_pipe) < 0)
    {
      close (out_pipe[0]);
      close (out_pipe[1]);
      FEsimple_error (Ecreate_thread_failed);
    }

  pid_t pid = fork ();
  if (pid < 0)
    {
      close (out_pipe[0]);
      close (out_pipe[1]);
      close (in_pipe[0]);
      close (in_pipe[1]);
      FEsimple_error (Ecreate_thread_failed);
    }

  if (pid == 0)
    {
      // Child process
      close (out_pipe[0]);
      close (in_pipe[1]);
      dup2 (in_pipe[0], STDIN_FILENO);
      dup2 (out_pipe[1], STDOUT_FILENO);
      dup2 (out_pipe[1], STDERR_FILENO);
      close (in_pipe[0]);
      close (out_pipe[1]);

      if (*dir && chdir (dir) < 0)
        ;  // ignore chdir failure in child

      // Reset signal handlers
      signal (SIGINT, SIG_DFL);
      signal (SIGQUIT, SIG_DFL);
      signal (SIGPIPE, SIG_DFL);

      execl ("/bin/sh", "sh", "-c", cmdline, (char *)0);
      _exit (127);
    }

  // Parent process
  close (out_pipe[1]);
  close (in_pipe[0]);
  p_read_fd = out_pipe[0];
  p_write_fd = in_pipe[1];
  p_pid = pid;

  // Set read fd to non-blocking
  int flags = fcntl (p_read_fd, F_GETFL, 0);
  fcntl (p_read_fd, F_SETFL, flags | O_NONBLOCK);
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

// Read available output from child process, decode, and insert into buffer
void
Process::poll_output ()
{
  u_char rawbuf[4096];
  ssize_t n = read (p_read_fd, rawbuf, sizeof rawbuf);
  if (n <= 0)
    return;

  // EOL conversion
  u_char *src = rawbuf;
  int srclen = (int)n;
  switch (eolcode ())
    {
    case eol_crlf:
      {
        u_char *d = rawbuf, *s = rawbuf, *se = s + srclen;
        for (; s < se; s++)
          if (*s != '\r')
            *d++ = *s;
        srclen = d - rawbuf;
        break;
      }
    case eol_cr:
      {
        for (u_char *s = rawbuf, *se = s + srclen; s < se; s++)
          if (*s == '\r')
            *s = '\n';
        break;
      }
    default:
      break;
    }

  // Encoding conversion: bytes → Char via encoding_input_stream_helper
  // For simplicity, use the process incode to decode
  p_last_incode = xprocess_incode (p_proc);

  // Build a simple byte input source and decode through encoding stream
  Char outbuf[4096];
  int outlen = 0;

  lisp encoding = p_last_incode;
  if (encoding != Qnil && xchar_encoding_type (encoding) != encoding_auto_detect)
    {
      // Use encoding to convert
      class simple_byte_input : public byte_input_stream
        {
          u_char *p_buf;
          u_char *p_end;
          virtual int refill ()
            {
              if (p_buf >= p_end)
                return eof;
              int c = setbuf (p_buf, p_end);
              p_buf = p_end; // consumed
              return c;
            }
        public:
          simple_byte_input (u_char *buf, int len) : p_buf (buf), p_end (buf + len) {}
        } bis (src, srclen);

      encoding_input_stream_helper eis (encoding, bis);
      int c;
      while ((c = eis->get ()) != xstream::eof && outlen < (int)numberof (outbuf))
        outbuf[outlen++] = (Char)c;
    }
  else
    {
      // No encoding or auto-detect: treat as raw bytes → Char
      for (int i = 0; i < srclen && outlen < (int)numberof (outbuf); i++)
        outbuf[outlen++] = (Char)src[i];
    }

  insert_output (outbuf, outlen);
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
Process::signal_proc () const
{
  if (p_pid > 0)
    ::kill (p_pid, SIGINT);
}

void
Process::kill_proc () const
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
      Process *pr = xprocess_data (xcar (p));
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
      Process *pr = xprocess_data (xcar (p));
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

static lisp
process_char_encoding (lisp encoding)
{
  if (encoding == Qnil)
    encoding = xsymbol_value (Vdefault_process_encoding);
  check_char_encoding (encoding);
  if (xchar_encoding_type (encoding) == encoding_auto_detect)
    FEtype_error (encoding, Qchar_encoding);
  return encoding;
}

static void
process_io_encoding (lisp &incode, lisp &outcode, lisp keys)
{
  incode = process_char_encoding (find_keyword (Kincode, keys));
  outcode = process_char_encoding (find_keyword (Koutcode, keys));
}

static eol_code
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

  char *cmdline = (char *)alloca (xstring_length (cmd) * 2 + 1);
  w2s (cmdline, cmd);

  int no_std_handles = find_keyword_bool (Kno_std_handles, keys);

  lisp lstdin = find_keyword (Kinput, keys);
  lisp lstdout = find_keyword (Koutput, keys);
  lisp lstderr = find_keyword (Kerror, keys, 0);
  if (!lstderr)
    lstderr = lstdout;

  char infile[PATH_MAX + 1] = "", outfile[PATH_MAX + 1] = "", errfile[PATH_MAX + 1] = "";
  if (!no_std_handles)
    {
      if (stringp (lstdin))
        pathname2cstr (lstdin, infile);
      else if (lstdin == Qnil)
        strcpy (infile, "/dev/null");

      if (stringp (lstdout))
        pathname2cstr (lstdout, outfile);
      else if (lstdout == Qnil)
        strcpy (outfile, "/dev/null");

      if (lstdout != lstderr)
        {
          if (stringp (lstderr))
            pathname2cstr (lstderr, errfile);
          else if (lstderr == Qnil)
            strcpy (errfile, "/dev/null");
        }
    }

  lisp exec_dir = find_keyword (Kexec_directory, keys);
  if (exec_dir == Qnil)
    exec_dir = selected_buffer ()->ldirectory;
  char dir[PATH_MAX + 1];
  pathname2cstr (exec_dir, dir);

  lisp wait = find_keyword (Kwait, keys);
  if (wait != Qnil && !realp (wait))
    wait = Qt;

  pid_t pid = fork ();
  if (pid < 0)
    FEsimple_error (Ecreate_thread_failed);

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

      execl ("/bin/sh", "sh", "-c", cmdline, (char *)0);
      _exit (127);
    }

  // Parent
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
      pr->create (command, execdir);
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
      Process *pr = xprocess_data (xcar (p));
      if (pr)
        {
          (*fn)(pr->filter ());
          (*fn)(pr->sentinel ());
          (*fn)(pr->marker ());
        }
    }
}

lisp
Fbuffer_process (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lprocess;
}

lisp
Fprocess_buffer (lisp process)
{
  check_process (process);
  return xprocess_buffer (process);
}

lisp
Fprocess_command (lisp process)
{
  check_process (process);
  return xprocess_command (process);
}

lisp
Fprocess_status (lisp process)
{
  check_process (process);
  switch (xprocess_status (process))
    {
    case PS_RUN:
      return Krun;
    case PS_EXIT:
      return Kexit;
    default:
      return Qnil;
    }
}

lisp
Fprocess_exit_code (lisp process)
{
  check_process (process);
  return (xprocess_status (process) == PS_EXIT
          ? make_fixnum (xprocess_exit_code (process)) : Qnil);
}

lisp
Fprocess_incode (lisp process)
{
  check_process (process);
  return xprocess_incode (process);
}

lisp
Fprocess_outcode (lisp process)
{
  check_process (process);
  return xprocess_outcode (process);
}

lisp
Fset_process_incode (lisp process, lisp encoding)
{
  check_process (process);
  xprocess_incode (process) = process_char_encoding (encoding);
  return Qt;
}

lisp
Fset_process_outcode (lisp process, lisp encoding)
{
  check_process (process);
  xprocess_outcode (process) = process_char_encoding (encoding);
  return Qt;
}

lisp
Fprocess_eol_code (lisp process)
{
  check_process (process);
  return make_fixnum (xprocess_eol_code (process));
}

lisp
Fset_process_eol_code (lisp process, lisp code)
{
  check_process (process);
  xprocess_eol_code (process) = process_eol_code (code);
  return Qt;
}

lisp
Fsignal_process (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (pr)
    pr->signal_proc ();
  return Qt;
}

lisp
Fkill_process (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (pr)
    pr->kill_proc ();
  return Qt;
}

lisp
Fprocess_send_string (lisp process, lisp string)
{
  check_process (process);
  check_string (string);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  Char_input_string_stream is (string);
  process_output_byte_stream os (*pr);
  encoding_output_stream_helper s (xprocess_outcode (process), is, eol_noconv);
  copy_xstream (s, os);
  return Qt;
}

lisp
Fset_process_filter (lisp process, lisp filter)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  pr->filter () = filter;
  return Qt;
}

lisp
Fprocess_filter (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->filter ();
}

lisp
Fset_process_sentinel (lisp process, lisp sentinel)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  pr->sentinel () = sentinel;
  return Qt;
}

lisp
Fprocess_sentinel (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->sentinel ();
}

lisp
Fprocess_marker (lisp process)
{
  check_process (process);
  Process *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->marker ();
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

lisp
Fsit_for (lisp timeout, lisp nodisp)
{
  double sec = coerce_to_double_float (timeout);
  if (sec <= 0)
    return Qt;

  long usec = (long)(sec * 1000000);
  struct timeval tv;
  tv.tv_sec = usec / 1000000;
  tv.tv_usec = usec % 1000000;

  fd_set rfds;
  FD_ZERO (&rfds);
  FD_SET (STDIN_FILENO, &rfds);
  int maxfd = STDIN_FILENO;

  // Also monitor process fds
  int pmax = collect_process_fds (&rfds);
  if (pmax > maxfd)
    maxfd = pmax;

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
  return Qt;
}

lisp
Fsleep_for (lisp timeout)
{
  double sec = coerce_to_double_float (timeout);
  if (sec <= 0)
    return Qt;

  long usec = (long)(sec * 1000000);
  struct timeval tv;
  tv.tv_sec = usec / 1000000;
  tv.tv_usec = usec % 1000000;

  // Sleep but still poll processes
  fd_set rfds;
  FD_ZERO (&rfds);
  int maxfd = -1;
  int pmax = collect_process_fds (&rfds);
  if (pmax > maxfd)
    maxfd = pmax;

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
  return Qt;
}
