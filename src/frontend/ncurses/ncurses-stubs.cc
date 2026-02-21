// Stub implementations for Win32 frontend functions that core references.
// ncurses frontend: starts as cli-stubs.cc copy, functions will be
// replaced with real implementations as phases progress.

#include "stdafx.h"
#include "ed.h"
#include "mainframe.h"
#include "conf.h"
#include "colors.h"
#include "version.h"

// ============================================================
// Global objects (normally defined in init.cc and sysdep.cc)
// ============================================================

Application app;
char enable_quit::q_enable;

Application::Application ()
     : mouse (kbdq)
{
  default_tab_columns = 8;
  auto_save_count = 0;
  toplevel_is_active = 0;
  ime_composition = 0;
  ime_open_mode = kbd_queue::IME_MODE_OFF;
  sleep_timer_exhausted = 0;
  last_vkeycode = -1;
  kbd_repeat_count = 0;
  wait_cursor_depth = 0;
  f_in_drop = 0;
  drop_window = 0;
  drag_window = 0;
  drag_buffer = 0;
  f_protect_quit = 0;
  last_cmd_tick = GetTickCount ();
  f_auto_save_pending = 0;
  default_caret_blink_time = 0;
  last_blink_caret = 0;
  lquit_char = Qnil;
  quit_vkey = 'G';
  quit_mod = MOD_CONTROL;
  ini_file_path = 0;
  minibuffer_prompt_column = -1;

  int tem;
  initial_stack = &tem;
  in_gc = 0;
  exit_code = 0;
  toplev = 0;
  hwnd_sw = 0;
  hinst = 0;
}

Application::~Application ()
{
  xfree (ini_file_path);
}

Sysdep sysdep;

Sysdep::Sysdep ()
{
  os_ver.dwOSVersionInfoSize = sizeof os_ver;
  GetVersionExA (&os_ver);

  {
    wchar_t wcurdir[PATH_MAX];
    GetCurrentDirectoryW (numberof (wcurdir), wcurdir);
    WideCharToMultiByte (932, 0, wcurdir, -1, curdir, sizeof curdir, 0, 0);
  }

  DWORD len = sizeof host_name;
  if (!GetComputerNameA (host_name, &len))
    *host_name = 0;

  process_id = GetCurrentProcessId ();

  perf_counter_present_p = QueryPerformanceFrequency ((LARGE_INTEGER *)&perf_freq);

  // Minimal init - no GUI resources
  wintype = WINTYPE_WINDOWS_NT5;
  windows_name = "ncurses";
  windows_short_name = "ncurses";

  memset (&border, 0, sizeof border);
  memset (&dblclk, 0, sizeof dblclk);
  memset (&edge, 0, sizeof edge);
  vscroll = 0;
  hscroll = 0;

  btn_text = 0;
  btn_highlight = 0;
  btn_shadow = 0;
  btn_face = 0;
  window_text = 0;
  gray_text = 0;
  highlight_text = 0;
  highlight = 0;
  window = 0;

  hbr_white = 0;
  hbr_black = 0;
  hpen_white = 0;
  hpen_black = 0;

  hcur_arrow = 0;
  hcur_revarrow = 0;
  hcur_ibeam = 0;
  hcur_wait = 0;
  hcur_sizewe = 0;
  hcur_sizens = 0;
  hcur_current = 0;

  hfont_ruler = 0;
  memset (&ruler_ext, 0, sizeof ruler_ext);

  machine_type = MACHINETYPE_UNKNOWN;
  process_type = PROCESSTYPE_NATIVE;

  comctl32_version = 0;
  shell32_version = 0;
}

Sysdep::~Sysdep ()
{
}

HFONT Sysdep::ui_font () { return 0; }
HFONT Sysdep::ui_font90 () { return 0; }
HFONT Sysdep::ui_font270 () { return 0; }
DWORD Sysdep::get_dll_version (const char *) { return 0; }

// ============================================================
// StatusWindow (used by core for status display)
// ============================================================

// StatusWindow ncurses display buffer — mirror of sw_last for non-member access
static ucs2_t g_status_buf[StatusWindow::TEXT_MAX];
static int g_status_len = 0;


StatusWindow::StatusWindow ()
{
  sw_hwnd = 0;
  sw_b = sw_buf;
  sw_tail = sw_buf + TEXT_MAX;
  sw_last.l = 0;
  sw_last.textf = 0;
}

void StatusWindow::restore () {}

int StatusWindow::text (const char *s)
{
  // Convert ASCII/SJIS string to ucs2 buffer and display
  sw_b = sw_buf;
  for (const u_char *p = (const u_char *)s; *p && sw_b < sw_tail;)
    {
      if (SJISP (*p) && p[1])
        {
          Char ic = (*p << 8) | p[1];
          *sw_b++ = i2w (ic);
          p += 2;
        }
      else
        *sw_b++ = *p++;
    }
  int l = sw_b - sw_buf;
  memcpy (g_status_buf, sw_buf, sizeof (*sw_buf) * l);
  g_status_len = l;
  sw_last.l = l;
  sw_last.textf = 1;
  sw_b = sw_buf;
  return l;
}

void
StatusWindow::puts (const Char *b, int size)
{
  for (const Char *be = b + size; b < be; b++)
    putc (*b);
}

int
StatusWindow::putc (Char c)
{
  if (c == '\n')
    newline ();
  else
    {
      if (sw_b >= sw_tail)
        return 0;
      if (c == '\t')
        {
          for (int i = 0; i < 8 && sw_b < sw_tail; i++)
            *sw_b++ = ' ';
        }
      else
        *sw_b++ = i2w (c);
    }
  return 1;
}

void
StatusWindow::newline ()
{
  flush ();
  sw_b = sw_buf;
}

void
StatusWindow::puts (const char *s, int fl)
{
  for (const u_char *p = (const u_char *)s; *p;)
    {
      if (SJISP (*p) && p[1])
        {
          putc ((*p << 8) | p[1]);
          p += 2;
        }
      else
        putc (*p++);
    }
  if (fl)
    newline ();
}

void
StatusWindow::puts (int code, int fl)
{
  puts (get_message_string (code), fl);
}

void
StatusWindow::flush ()
{
  int l = sw_b - sw_buf;
  if (l && (sw_last.textf || l != sw_last.l
            || memcmp (sw_last.buf, sw_buf, sizeof (*sw_buf) * l)))
    {
      memcpy (sw_last.buf, sw_buf, sizeof (*sw_buf) * l);
      memcpy (g_status_buf, sw_buf, sizeof (*sw_buf) * l);
      sw_last.l = l;
      g_status_len = l;
      sw_last.textf = 0;

    }
}

void
StatusWindow::clear (int)
{
  if (sw_last.l || sw_last.textf)
    {
      sw_last.l = 0;
      sw_last.textf = 0;
      g_status_len = 0;

    }
  sw_b = sw_buf;
}

void StatusWindow::set (HWND) {}
int StatusWindow::paint (const DRAWITEMSTRUCT *) { return 0; }

// ============================================================
// ModelineParam
// ============================================================

ModelineParam::ModelineParam ()
{
  m_hfont = 0;
  m_height = 0;
  m_exlead = 0;
  memset (m_exts, 0, sizeof m_exts);
}
ModelineParam::~ModelineParam () {}
void ModelineParam::init (HFONT) {}

// ============================================================
// toplev.cc stubs
// ============================================================

LRESULT CALLBACK toplevel_wndproc (HWND, UINT, WPARAM, LPARAM) { return 0; }
LRESULT CALLBACK frame_wndproc (HWND, UINT, WPARAM, LPARAM) { return 0; }
LRESULT CALLBACK client_wndproc (HWND, UINT, WPARAM, LPARAM) { return 0; }
LRESULT CALLBACK modeline_wndproc (HWND, UINT, WPARAM, LPARAM) { return 0; }

// main_loop delegates to core command_loop
void main_loop () { command_loop (); }
int start_quit_thread () { return 1; }
int wait_process_terminate (HANDLE) { return 0; }
int end_wait_cursor (int) { return 0; }
void set_ime_caret () {}
void recalc_toplevel () {}
void set_caret_blink_time () {}
void restore_caret_blink_time () {}

// toplev_gc_mark, toplev_accept_mouse_move_p, execute_string
// are now in core/cmdloop.cc

int get_glyph_width (Char, const glyph_width &) { return 8; }

// ============================================================
// msgbox.cc stubs
// ============================================================

int MsgBox (HWND, const char *, const char *, UINT style, int)
{
  // For yes/no dialogs, default to "yes" (e.g., kill-xyzzy with modified buffers)
  if ((style & 0x0f) == MB_YESNO)
    return IDYES;
  return IDOK;
}
int MsgBoxEx (HWND, const char *, const char *, int, int, int, int,
              const char **, int, int, int) { return IDOK; }
void XMessageBox::add_button (UINT, const char *) {}
void XMessageBox::set_button (int, UINT, const char *) {}
int XMessageBox::doit (HWND) { return IDOK; }

// ============================================================
// init.cc stubs
// ============================================================

void report_out_of_memory ()
{
  fprintf (stderr, "xyzzy-ncurses: out of memory\n");
}

// ============================================================
// minibuf.cc — ncurses minibuffer (recursive edit)
// ============================================================

static int minibuffer_recursive_level;

static lisp
load_default_impl (const char *fmt, lisp keys, int number)
{
  if (keys == Qnil)
    return Qnil;

  char b[32];
  sprintf (b, fmt, number);
  int l = strlen (b);
  Char w[32];
  a2w (w, b, l);
  temporary_string t (w, l);
  lisp var = Ffind_symbol (t.string (), xsymbol_value (Vkeyword_package));
  return var != Qnil ? find_keyword (var, keys) : Qnil;
}

lisp
load_default (lisp keys, int number)
{
  return load_default_impl ("default%d", keys, number);
}

lisp
load_history (lisp keys, int number)
{
  return load_default_impl ("history%d", keys, number);
}

lisp
load_history (lisp keys, int number, lisp def)
{
  lisp x = load_history (keys, number);
  return x != Qnil ? x : def;
}

lisp
load_title (lisp keys, int number)
{
  return load_default_impl ("title%d", keys, number);
}

static Buffer *
create_minibuffer ()
{
  char b[32];
  sprintf (b, " *Minibuf%d*", minibuffer_recursive_level);
  return Buffer::make_internal_buffer (b);
}

static int
count_prompt_columns (const Char *s, int l)
{
  int n = 0;
  for (const Char *se = s + l; s < se; s++)
    n += char_width (*s);
  return n;
}

void command_loop ();
lisp Fsi_throw_error (lisp);

lisp
read_minibuffer (const Char *prompt, long prompt_length, lisp def,
                 lisp type, lisp compl, lisp history,
                 int noselect, int completion, int must_match,
                 lisp title, int opt_arg)
{
  check_kbd_enable ();
  Window *wp = selected_window ();
  Buffer *curbp = selected_buffer ();
  if (wp->minibuffer_window_p ()
      && symbol_value (Venable_recursive_minibuffers, curbp) == Qnil)
    FEsimple_error (Eattempt_to_use_minibuffer_recursively);

  Buffer *bp = create_minibuffer ();
  bp->ldirectory = curbp->ldirectory;
  bp->lsyntax_table = curbp->lsyntax_table;
  bp->lminibuffer_buffer = curbp->lbp;
  bp->ldialog_title = title;
  bp->lminibuffer_default = stringp (def) ? def : Qnil;
  bp->lmap = xsymbol_value (type == Kcommand_line
                            ? Vminibuffer_local_command_line_map
                            : (completion
                               ? (must_match
                                  ? Vminibuffer_local_must_match_map
                                  : Vminibuffer_local_completion_map)
                               : Vminibuffer_local_map));
  if (bp->lmap == Qunbound || bp->lmap == Qnil)
    bp->lmap = Qnil;

  bp->b_prompt = prompt;
  bp->b_prompt_length = prompt_length;
  bp->b_prompt_columns = count_prompt_columns (prompt, prompt_length);
  *bp->b_prompt_arg = 0;
  if (!opt_arg)
    {
      long n;
      if (xsymbol_value (Vprefix_args) == Vuniversal_argument
          && safe_fixnum_value (xsymbol_value (Vprefix_value), &n)
          && n == 4)
        strcpy (bp->b_prompt_arg, "C-u ");
      else if (safe_fixnum_value (xsymbol_value (Vprefix_value), &n))
        sprintf (bp->b_prompt_arg, "%d ", n);
    }
  bp->b_prompt_columns += strlen (bp->b_prompt_arg);

  bp->b_minibufferp = 1;
  bp->b_fold_mode = bp->b_fold_columns = Buffer::FOLD_NONE;
  bp->fold_width_modified ();
  bp->lcomplete_type = type;
  bp->lcomplete_list = compl;

  protect_gc gcpro4 (type);
  protect_gc gcpro5 (compl);

  Window *mini = Window::minibuffer_window ();
  mini->set_buffer_params (bp);
  mini->set_window ();
  mini->w_flags = 0;
  minibuffer_recursive_level++;

  // Insert default value if provided
  // noselect: insert text, cursor stays at end (user types filename after directory)
  // !noselect: insert text, select it (cursor at start, selection to end)
  if (stringp (def))
    {
      bp->insert_chars_internal (mini->w_point,
                                 xstring_contents (def),
                                 xstring_length (def), 1);
      // noselect=1: cursor already at end, nothing to do
      // noselect=0: would need selection — skip for now (rare case)
    }

  lisp result = Qnil;
  lisp nld_type = 0, nld_id = 0;
  int abnormal_exit = 0;
  try
    {
      command_loop ();
      abnormal_exit = 1;
    }
  catch (nonlocal_jump &)
    {
      nonlocal_data *nld = nonlocal_jump::data ();
      result = nld->value;
      nld_type = nld->type;
      nld_id = nld->id;
    }

  protect_gc gcpro (result);
  protect_gc gcpro2 (nld_id);

  bp->lcomplete_type = Qnil;
  bp->lcomplete_list = Qnil;

  bp->b_prompt = 0;
  bp->b_prompt_length = 0;
  bp->b_prompt_columns = 0;
  *bp->b_prompt_arg = 0;

  if (--minibuffer_recursive_level)
    bp->b_minibufferp = 0;

  lisp contents = Qnil;
  protect_gc gcpro3 (contents);

  if (!abnormal_exit)
    {
      if (nld_type == Qexit_this_level && nld_id == Qnil)
        {
          try
            {
              contents = bp->substring (0, bp->b_nchars);
            }
          catch (nonlocal_jump &)
            {
            }
        }
    }

  bp->lminibuffer_buffer = Qnil;
  bp->lvar = Qnil;
  bp->ldialog_title = Qnil;
  bp->lminibuffer_default = Qnil;

  // Restore previous window
  wp->set_window ();

  if (minibuffer_recursive_level)
    Fdelete_buffer (bp->lbp);
  else
    Ferase_buffer (bp->lbp);

  if (abnormal_exit)
    Fexit_recursive_edit (Qnil);

  if (contents == Qnil)
    {
      if (nld_type == Qexit_this_level)
        Fsi_throw_error (nld_id);
      throw nonlocal_jump ();
    }

  return result != Qnil ? result : contents;
}

lisp
complete_read (const Char *prompt, long prompt_length, lisp def,
               lisp type, lisp compl, lisp history,
               int must_match, int opt_arg)
{
  lisp string = read_minibuffer (prompt, prompt_length, def, type, compl,
                                 history, 0, 1, must_match, Qnil, opt_arg);

  if (!symbolp (type))
    return string;

  if (type == Kexist_buffer_name)
    return Ffind_buffer (string);

  if (type == Kbuffer_name)
    {
      if (stringp (string) && !xstring_length (string))
        return def;
      lisp x = Ffind_buffer (string);
      return x == Qnil ? string : x;
    }

  if (type == Ksymbol_name || type == Kfunction_name
      || type == Kcommand_name || type == Kvariable_name
      || type == Knon_trivial_symbol_name)
    return Fintern (string, 0);

  if (type == Kchar_encoding || type == Kexact_char_encoding)
    return find_char_encoding (string);

  return string;
}

lisp
read_filename (const Char *prompt, long prompt_length, lisp type,
               lisp title, lisp defalt, lisp history)
{
  Buffer *bp = selected_buffer ();
  return read_minibuffer (prompt, prompt_length,
                          (defalt != Qnil
                           ? defalt
                           : (symbol_value (Vinsert_default_directory, bp) != Qnil
                              ? bp->ldirectory : Qnil)),
                          type, Qnil,
                          (history != Qnil
                           ? history
                           : type == Kdirectory_name ? Kdirectory_name : Kfile_name),
                          1, 1,
                          type == Kexist_file_name || type == Kdirectory_name,
                          title, -1);
}

lisp
minibuffer_read_integer (const Char *prompt, long prompt_length)
{
  lisp string = read_minibuffer (prompt, prompt_length, Qnil, Kinteger, Qnil, Kinteger,
                                 0, 0, 0, Qnil, -1);
  int l = xstring_length (string);
  return parse_integer (string, 0, l, 10, 1);
}

// ============================================================
// process.cc stubs
// ============================================================

void read_process_output (WPARAM, LPARAM) {}
void wait_process_terminate (WPARAM, LPARAM) {}
int buffer_has_process (const Buffer *) { return 0; }
int query_kill_subprocesses () { return 1; }
void process_gc_mark (void (*)(lisp)) {}

// ============================================================
// menu.cc stubs
// ============================================================

int init_menu_flags (lisp) { return 0; }
void init_menu_popup (WPARAM, LPARAM) {}
lisp lookup_menu_command (int) { return Qnil; }
lisp track_popup_menu (lisp, lisp, const POINT *) { return Qnil; }

// ============================================================
// dialogs.cc stubs
// ============================================================

void center_window (HWND) {}
void set_window_icon (HWND) {}
void init_list_column (HWND, int, const int *, const int *, int, const char *, const char *) {}
void save_list_column_width (HWND, int, const char *, const char *) {}
int lv_find_selected_item (HWND) { return -1; }
int lv_find_focused_item (HWND) { return -1; }

// Buffer.cc: change_local_colors is in core. Only stub update_buffer_bar.
void update_buffer_bar () {}

// ============================================================
// popup.cc stubs
// ============================================================

void erase_popup (int, int) {}

// ============================================================
// disp.cc stubs
// ============================================================

void reload_caret_colors () {}

// ============================================================
// listen.cc stubs
// ============================================================

UINT wm_private_xyzzysrv = 0;
void start_listen_server () {}
void init_listen_server () {}
void end_listen_server () {}
int read_listen_server (WPARAM, LPARAM) { return 0; }

// ============================================================
// Window.cc stubs
// ============================================================

void ForceSetForegroundWindow (HWND) {}

// ============================================================
// usertool.cc stubs
// ============================================================

lisp get_tooltip_text (lisp) { return Qnil; }

// ============================================================
// stdctl.cc stubs
// ============================================================

void stdctl_hook_init (HINSTANCE) {}
int stdctl_operation (int) { return 0; }

// ============================================================
// conf.cc stubs (all overloads)
// ============================================================

void write_conf (const char *, const char *, const char *) {}
void write_conf (const char *, const char *, long, int) {}
void write_conf (const char *, const char *, const int *, int, int) {}
void write_conf (const char *, const char *, const RECT &) {}
void write_conf (const char *, const char *, const LOGFONTA &) {}
void write_conf (const char *, const char *, const PRLOGFONT &) {}
void write_conf (const char *, const char *, const WINDOWPLACEMENT &) {}
int read_conf (const char *, const char *, char *, int) { return 0; }
int read_conf (const char *, const char *, int &) { return 0; }
#if INT_MAX != LONG_MAX
int read_conf (const char *, const char *, u_long &) { return 0; }
#endif
int read_conf (const char *, const char *, int *, int) { return 0; }
int read_conf (const char *, const char *, RECT &) { return 0; }
int read_conf (const char *, const char *, LOGFONTA &) { return 0; }
int read_conf (const char *, const char *, PRLOGFONT &) { return 0; }
int read_conf (const char *, const char *, WINDOWPLACEMENT &) { return 0; }
void flush_conf () {}
int conf_load_geometry (HWND, const char *, const char *, int, int) { return 0; }
void conf_save_geometry (HWND, const char *, const char *, int, int) {}
void adjust_snap_window_size (HWND, WINDOWPLACEMENT &) {}
void make_geometry_key (char *buf, size_t, const char *prefix) { if (buf) *buf = 0; }
void conf_write_string (const char *, const char *, const char *) {}
void delete_conf (const char *) {}
int reg2ini () { return 0; }
void reg_delete_tree () {}

// ============================================================
// colors.cc stubs
// ============================================================

void load_misc_colors () {}

// ============================================================
// Application member class constructors/destructors
// (kbd_queue, key_sequence, utimer, clipboard are members of Application)
// ============================================================

clipboard::clipboard ()
{
  hwnd_next_clipboard = 0;
  last_clipboard_seqno = 0;
  use_newapi_p = false;
  AddClipboardFormatListenerProc = 0;
  RemoveClipboardFormatListenerProc = 0;
}

kbd_queue::kbd_queue ()
{
  head = tail = 0;
  pending = lChar_EOF;
  nsaved = 0;
  kbd_macro = 0;
  last_ime_status = 0;
  delayed_activate = 0;
  in_hook = 0;
  putc_pending = 0;
  GetKeyboardLayout = 0;
}

kbd_queue::~kbd_queue () {}

key_sequence::key_sequence ()
{
  k_used = 0;
  k_last_used = 0;
}

utimer::utimer ()
{
  t_hwnd = 0;
  t_timer_on = 0;
}

utimer::~utimer () {}

void utimer::gc_mark (void (*)(lisp)) {}

// ============================================================
// Lisp object destructors (GC needs these)
// ============================================================

lwin32_menu::~lwin32_menu ()
{
  if (handle)
    DestroyMenu (handle);
}

void lwait_object::cleanup ()
{
  if (hevent)
    {
      CloseHandle (hevent);
      hevent = 0;
    }
}

// ============================================================
// dock_frame / g_frame (used by GC in data.cc)
// ============================================================

#ifdef _WIN32
dock_frame::dock_frame () : f_hwnd (0), f_arrange (0) {}
dock_frame::~dock_frame () {}
void dock_frame::gc_mark (void (*)(lisp)) {}
void dock_frame::cleanup () {}

splitter::splitter ()
{
  s_head = s_tail = 0;
  s_in_resize = 0;
  s_terminating = 0;
  s_hwnd = 0;
  s_hwnd_frame = 0;
  memset (&s_rect, 0, sizeof s_rect);
}

main_frame g_frame;
#endif

// ============================================================
// vfs.cc stubs (WINFS static methods used by core)
// Simple passthrough to Win32 API (no UNC share handling).
// ============================================================

char WINFS::wfs_share_cache[MAX_PATH * 2];
const WINFS::GETDISKFREESPACEEX WINFS::GetDiskFreeSpaceEx = 0;

// POSIX implementations of WINFS methods for ncurses frontend

#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

static DWORD posix_get_file_attrs (const char *p)
{
  struct stat st;
  if (stat (p, &st) != 0)
    return INVALID_FILE_ATTRIBUTES;
  DWORD attrs = 0;
  if (S_ISDIR (st.st_mode))
    attrs |= FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR))
    attrs |= FILE_ATTRIBUTE_READONLY;
  return attrs;
}

BOOL WINAPI WINFS::CreateDirectory (LPCSTR p, LPSECURITY_ATTRIBUTES)
{
  return mkdir (p, 0755) == 0;
}

HANDLE WINAPI WINFS::CreateFile (LPCSTR p, DWORD access, DWORD,
  LPSECURITY_ATTRIBUTES, DWORD cd, DWORD, HANDLE)
{
  int flags = 0;
  if ((access & GENERIC_READ) && (access & GENERIC_WRITE))
    flags = O_RDWR;
  else if (access & GENERIC_WRITE)
    flags = O_WRONLY;
  else
    flags = O_RDONLY;

  switch (cd)
    {
    case CREATE_NEW:
      flags |= O_CREAT | O_EXCL;
      break;
    case CREATE_ALWAYS:
      flags |= O_CREAT | O_TRUNC;
      break;
    case OPEN_EXISTING:
      break;
    case OPEN_ALWAYS:
      flags |= O_CREAT;
      break;
    case TRUNCATE_EXISTING:
      flags |= O_TRUNC;
      break;
    }

  int fd = open (p, flags, 0644);
  if (fd < 0)
    return INVALID_HANDLE_VALUE;
  return (HANDLE)(intptr_t)fd;
}

BOOL WINAPI WINFS::DeleteFile (LPCSTR p)
{
  return unlink (p) == 0;
}

// Directory enumeration state for FindFirstFile/FindNextFile
struct posix_find_handle
{
  DIR *dir;
  char basedir[PATH_MAX];
};

HANDLE WINAPI WINFS::FindFirstFile (LPCSTR p, LPWIN32_FIND_DATAA d)
{
  // p might be a glob pattern like "/path/to/dir/*"
  // Extract the directory part
  char dirpath[PATH_MAX];
  strncpy (dirpath, p, PATH_MAX - 1);
  dirpath[PATH_MAX - 1] = 0;

  // Remove trailing wildcard (e.g., "/*" or "/*.*")
  char *slash = strrchr (dirpath, '/');
  if (slash)
    *slash = 0;
  else
    strcpy (dirpath, ".");

  DIR *dir = opendir (dirpath);
  if (!dir)
    return INVALID_HANDLE_VALUE;

  struct dirent *ent = readdir (dir);
  while (ent && (strcmp (ent->d_name, ".") == 0 || strcmp (ent->d_name, "..") == 0))
    ent = readdir (dir);
  if (!ent)
    {
      closedir (dir);
      return INVALID_HANDLE_VALUE;
    }

  // Fill in find data
  memset (d, 0, sizeof (*d));
  strncpy (d->cFileName, ent->d_name, MAX_PATH - 1);

  char fullpath[PATH_MAX * 2];
  snprintf (fullpath, sizeof (fullpath), "%s/%s", dirpath, ent->d_name);
  struct stat st;
  if (stat (fullpath, &st) == 0)
    {
      if (S_ISDIR (st.st_mode))
        d->dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
      d->nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
      d->nFileSizeHigh = (DWORD)(st.st_size >> 32);
    }

  posix_find_handle *fh = new posix_find_handle;
  fh->dir = dir;
  strncpy (fh->basedir, dirpath, PATH_MAX - 1);
  fh->basedir[PATH_MAX - 1] = 0;
  return (HANDLE)fh;
}

BOOL WINAPI WINFS::FindNextFile (HANDLE h, LPWIN32_FIND_DATAA d)
{
  posix_find_handle *fh = (posix_find_handle *)h;
  if (!fh || !fh->dir)
    return FALSE;

  struct dirent *ent = readdir (fh->dir);
  while (ent && (strcmp (ent->d_name, ".") == 0 || strcmp (ent->d_name, "..") == 0))
    ent = readdir (fh->dir);
  if (!ent)
    return FALSE;

  memset (d, 0, sizeof (*d));
  strncpy (d->cFileName, ent->d_name, MAX_PATH - 1);

  char fullpath[PATH_MAX * 2];
  snprintf (fullpath, sizeof (fullpath), "%s/%s", fh->basedir, ent->d_name);
  struct stat st;
  if (stat (fullpath, &st) == 0)
    {
      if (S_ISDIR (st.st_mode))
        d->dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
      d->nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
      d->nFileSizeHigh = (DWORD)(st.st_size >> 32);
    }
  return TRUE;
}

BOOL FindClose (HANDLE h)
{
  if (h && h != INVALID_HANDLE_VALUE)
    {
      posix_find_handle *fh = (posix_find_handle *)h;
      if (fh->dir)
        closedir (fh->dir);
      delete fh;
    }
  return TRUE;
}

BOOL WINAPI WINFS::GetDiskFreeSpace (LPCSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD)
{
  return FALSE;
}

DWORD WINAPI WINFS::internal_GetFileAttributes (LPCSTR p)
{
  return posix_get_file_attrs (p);
}

DWORD WINAPI WINFS::GetFileAttributes (LPCSTR p)
{
  return posix_get_file_attrs (p);
}

UINT WINAPI WINFS::GetTempFileName (LPCSTR dir, LPCSTR prefix, UINT, LPSTR buf)
{
  snprintf (buf, MAX_PATH, "%s/%sXXXXXX", dir, prefix ? prefix : "tmp");
  int fd = mkstemp (buf);
  if (fd < 0)
    return 0;
  close (fd);
  return 1;
}

BOOL WINAPI WINFS::GetVolumeInformation (LPCSTR, LPSTR vn, DWORD vs, LPDWORD sn,
  LPDWORD mcl, LPDWORD fsf, LPSTR fsn, DWORD fss)
{
  if (vn && vs > 0) vn[0] = 0;
  if (sn) *sn = 0;
  if (mcl) *mcl = 255;
  if (fsf) *fsf = 0;
  if (fsn && fss > 0) fsn[0] = 0;
  return TRUE;
}

HMODULE WINAPI WINFS::LoadLibrary (LPCSTR)
{
  return 0;
}

BOOL WINAPI WINFS::MoveFile (LPCSTR a, LPCSTR b)
{
  return rename (a, b) == 0;
}

BOOL WINAPI WINFS::RemoveDirectory (LPCSTR p)
{
  return rmdir (p) == 0;
}

BOOL WINAPI WINFS::SetFileAttributes (LPCSTR, DWORD)
{
  return TRUE;
}

DWORD WINAPI WINFS::internal_GetFullPathName (LPCSTR p, DWORD n, LPSTR b, LPSTR *f)
{
  char resolved[PATH_MAX];
  if (realpath (p, resolved))
    {
      DWORD len = strlen (resolved);
      if (len < n)
        {
          strcpy (b, resolved);
          if (f)
            {
              *f = b;
              for (char *s = b; *s; s++)
                if (*s == '/')
                  *f = s + 1;
            }
          return len;
        }
    }
  // realpath failed (file might not exist), try to construct a path
  if (p[0] == '/')
    {
      DWORD len = strlen (p);
      if (len < n)
        {
          strcpy (b, p);
          if (f)
            {
              *f = b;
              for (char *s = b; *s; s++)
                if (*s == '/')
                  *f = s + 1;
            }
          return len;
        }
    }
  else
    {
      char cwd[PATH_MAX];
      if (getcwd (cwd, sizeof (cwd)))
        {
          int len = snprintf (b, n, "%s/%s", cwd, p);
          if (len > 0 && (DWORD)len < n)
            {
              if (f)
                {
                  *f = b;
                  for (char *s = b; *s; s++)
                    if (*s == '/')
                      *f = s + 1;
                }
              return len;
            }
        }
    }
  return 0;
}

BOOL WINAPI WINFS::SetCurrentDirectory (LPCSTR p)
{
  return chdir (p) == 0;
}

DWORD WINAPI WINFS::GetFullPathName (LPCSTR p, DWORD n, LPSTR b, LPSTR *f)
{
  return internal_GetFullPathName (p, n, b, f);
}

DWORD WINAPI WINFS::WNetOpenEnum (DWORD, DWORD, DWORD, LPNETRESOURCEA, LPHANDLE)
{ return (DWORD)-1; }

int WINAPI WINFS::get_file_data (const char *path, WIN32_FIND_DATAA &fd)
{
  struct stat st;
  if (stat (path, &st) != 0)
    return 0;
  memset (&fd, 0, sizeof (fd));
  if (S_ISDIR (st.st_mode))
    fd.dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR))
    fd.dwFileAttributes |= FILE_ATTRIBUTE_READONLY;
  fd.nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
  fd.nFileSizeHigh = (DWORD)(st.st_size >> 32);
  // Extract filename from path
  const char *name = strrchr (path, '/');
  strncpy (fd.cFileName, name ? name + 1 : path, MAX_PATH - 1);
  return 1;
}

// ============================================================
// dll.cc stubs
// ============================================================

void init_c_callable (lisp) {}

// ============================================================
// Lisp-callable frontend functions (registered in symbol table)
// These are referenced by the generated symtable.cc
// ============================================================

lisp Fsi_startup ()
{
  return Fsi_load_library (make_string ("startup"), Qnil);
}

lisp Fsi_minibuffer_message (lisp, lisp) { return Qnil; }
lisp Fsi_show_window_foreground () { return Qnil; }
lisp Fsi_activate_toplevel () { return Qnil; }
lisp Fsi_app_user_model_id () { return Qnil; }
lisp Fsi_create_wait_object () { return Qnil; }
lisp Fsi_add_wait_object (lisp, lisp) { return Qnil; }
lisp Fsi_remove_wait_object (lisp, lisp) { return Qnil; }

// ============================================================
// dll.cc stubs (sys_fns[] references)
// ============================================================

lisp Fsi_load_dll_module (lisp) { return Qnil; }
lisp Fsi_make_c_function (lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fsi_make_c_callable (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fsi_last_win32_error () { return Qnil; }
lisp Fsi_set_last_win32_error (lisp) { return Qnil; }

// ============================================================
// Window.cc / pane.cc / doc.cc stubs (sys_fns[] references)
// ============================================================

lisp Fsi_instance_number () { return make_fixnum (0); }
lisp Fsi_plugin_arg () { return Qnil; }
lisp Fsi_snarf_documentation (lisp, lisp) { return Qnil; }
lisp Fsi_get_documentation_string (lisp, lisp, lisp, lisp) { return Qnil; }

// ============================================================
// assert.cc stubs
// ============================================================

#ifdef DEBUG
int assert_failed (const char *file, int line)
{
  fprintf (stderr, "Assertion failed: %s:%d\n", file, line);
  abort ();
  return 0;
}
#endif

// ============================================================
// Window.cc — ncurses implementations
// ============================================================

#include "Window.h"
#include "charset.h"
#include <ncurses.h>
#include <sys/ioctl.h>
#include <unistd.h>

XCOLORREF Window::default_xcolors[USER_DEFINABLE_COLORS];
COLORREF Window::default_colors[WCOLOR_MAX];
int Window::w_default_flags = 0;
int Window::w_hjump_columns = 4;

Window::Window (int minibufp, int temporary)
{
  lwp = Qnil;
  w_bufp = 0;
  w_next = w_prev = 0;

  w_flags_mask = minibufp ? WF_NEWLINE : -1;
  w_flags = 0;
  w_last_flags = flags ();

  bzero (&w_point, sizeof w_point);
  w_mark = NO_MARK_SET;
  w_last_point = 0;
  w_disp = 0;
  w_last_disp = 0;
  w_last_top_linenum = 1;
  w_last_top_column = 0;
  w_linenum = 1;
  w_plinenum = 1;
  w_column = 0;
  w_goal_column = 0;
  w_top_column = 0;
  w_selection_type = Buffer::SELECTION_VOID;
  w_selection_point = NO_MARK_SET;
  w_selection_marker = NO_MARK_SET;
  w_selection_column = 0;
  w_selection_region.p1 = -1;
  w_reverse_temp = Buffer::SELECTION_VOID;
  w_reverse_region.p1 = NO_MARK_SET;
  w_reverse_region.p2 = NO_MARK_SET;

  // ncurses init (no HWND)
  w_last_bufp = 0;
  w_disp_flags = WDF_WINDOW | WDF_MODELINE;
  w_last_mark_linenum = -1;
  bzero (&w_rect, sizeof w_rect);
  bzero (&w_order, sizeof w_order);
  bzero (w_last_vars, sizeof w_last_vars);
  bzero (&w_clsize, sizeof w_clsize);
  bzero (&w_ech, sizeof w_ech);
  w_colors = default_colors;
  w_inverse_mode_line = 0;
  w_ime_mode_line = 0;
  w_cursor_line.ypixel = -1;
  w_ruler_top_column = -1;
  w_ruler_column = -1;
  w_ruler_fold_column = Buffer::FOLD_NONE;
  w_ignore_scroll_margin = 0;
  w_hwnd = 0;
  w_hwnd_ml = 0;
  bzero (&w_vsinfo, sizeof w_vsinfo);
  bzero (&w_hsinfo, sizeof w_hsinfo);
  bzero (&w_ch_max, sizeof w_ch_max);
  w_glyphs = 0;
}

Window::Window (const Window &src)
{
  lwp = Qnil;
  w_next = w_prev = 0;
#define CP(x) (x = src.x)
  CP (w_bufp);
  CP (w_flags_mask);
  CP (w_flags);
  CP (w_last_flags);
  CP (w_point);
  CP (w_mark);
  CP (w_last_point);
  CP (w_disp);
  CP (w_last_disp);
  CP (w_last_top_linenum);
  CP (w_last_top_column);
  CP (w_linenum);
  CP (w_plinenum);
  CP (w_column);
  CP (w_goal_column);
  CP (w_top_column);
  CP (w_selection_type);
  CP (w_selection_point);
  CP (w_selection_marker);
  CP (w_reverse_temp);
  CP (w_reverse_region);
  CP (w_selection_column);
  CP (w_selection_region);
#undef CP
  // ncurses: no HWND init
  w_last_bufp = 0;
  w_disp_flags = WDF_WINDOW | WDF_MODELINE;
  w_last_mark_linenum = -1;
  bzero (&w_rect, sizeof w_rect);
  bzero (&w_order, sizeof w_order);
  bzero (w_last_vars, sizeof w_last_vars);
  bzero (&w_clsize, sizeof w_clsize);
  bzero (&w_ech, sizeof w_ech);
  w_colors = default_colors;
  w_inverse_mode_line = 0;
  w_ime_mode_line = 0;
  w_cursor_line.ypixel = -1;
  w_ruler_top_column = -1;
  w_ruler_column = -1;
  w_ruler_fold_column = Buffer::FOLD_NONE;
  w_ignore_scroll_margin = 0;
  w_hwnd = 0;
  w_hwnd_ml = 0;
  bzero (&w_vsinfo, sizeof w_vsinfo);
  bzero (&w_hsinfo, sizeof w_hsinfo);
  bzero (&w_ch_max, sizeof w_ch_max);
  w_glyphs = 0;
  lwp = make_window ();
  xwindow_wp (lwp) = this;
}

Window::~Window ()
{
  if (windowp (lwp))
    xwindow_wp (lwp) = 0;
}

void
Window::save_buffer_params ()
{
  if (!w_bufp)
    return;
  w_bufp->b_point = w_point.p_point;
  w_bufp->b_mark = w_mark;
  w_bufp->b_selection_point = w_selection_point;
  w_bufp->b_selection_marker = w_selection_marker;
  w_bufp->b_selection_type = w_selection_type;
  w_bufp->b_selection_column = w_selection_column;
  w_bufp->b_reverse_temp = w_reverse_temp;
  w_bufp->b_reverse_region = w_reverse_region;
  w_bufp->b_disp = w_disp;
}

void
Window::set_buffer_params (Buffer *bp)
{
  w_bufp = bp;
  w_point.p_point = 0;
  w_point.p_chunk = bp->b_chunkb;
  w_point.p_offset = 0;
  bp->goto_char (w_point, bp->b_point);
  w_mark = bp->b_mark;
  w_selection_point = bp->b_selection_point;
  w_selection_marker = bp->b_selection_marker;
  w_selection_type = bp->b_selection_type;
  w_selection_column = bp->b_selection_column;
  w_reverse_temp = bp->b_reverse_temp;
  w_reverse_region = bp->b_reverse_region;
  w_disp = bp->b_disp;
  w_last_disp = w_disp;
}

void
Window::set_buffer (Buffer *bp)
{
  if (bp != w_bufp)
    {
      save_buffer_params ();
      set_buffer_params (bp);
      w_goal_column = 0;
      w_disp_flags |= WDF_WINDOW | WDF_MODELINE | WDF_GOAL_COLUMN;
    }
}

void
Window::set_window ()
{
  app.active_frame.selected = this;
  if (w_bufp)
    w_bufp->check_range (w_point);
}

void Window::change_color () {}
void Window::modify_all_mode_line () {}
void Window::init_colors (const XCOLORREF *, const XCOLORREF *,
                          const XCOLORREF *, const XCOLORREF *) {}
void Window::init (int, int) {}

// mode_line_painter vtable anchor functions
bool mode_line_percent_painter::need_repaint_all () { return false; }
int mode_line_percent_painter::paint_percent (HDC) { return 0; }
int mode_line_percent_painter::calc_percent (Buffer *, point_t) { return 0; }
bool mode_line_point_painter::need_repaint_all () { return false; }
int mode_line_point_painter::paint_point (HDC) { return 0; }

WindowConfiguration *WindowConfiguration::wc_chain = 0;
WindowConfiguration::WindowConfiguration () : wc_selected (0), wc_nwindows (0), wc_data (0) {}
WindowConfiguration::~WindowConfiguration () {}

// ============================================================
// buffer-bar.cc stubs
// ============================================================

#ifdef _WIN32
#include "buffer-bar.h"

buffer_bar *buffer_bar::b_bar = 0;
void buffer_bar::delete_buffer (Buffer *) {}
Buffer *buffer_bar::next_buffer (Buffer *, int) const { return 0; }
Buffer *buffer_bar::top_buffer () const { return 0; }
Buffer *buffer_bar::bottom_buffer () const { return 0; }
lisp buffer_bar::buffer_list () const { return Qnil; }
#endif

// ============================================================
// abbrev.cc stubs (abbreviate_string uses GDI)
// ============================================================

lisp Fabbreviate_display_string (lisp string, lisp, lisp) { return string; }

// ============================================================
// binfo.cc stubs
// ============================================================

#include "binfo.h"

const char *const buffer_info::b_eol_name[] = {"lf", "crlf", "cr"};

char *buffer_info::format (lisp, char *b, char *) const { *b = 0; return b; }
char *buffer_info::modified (char *b, int) const { *b = 0; return b; }
char *buffer_info::read_only (char *b, int) const { *b = 0; return b; }
char *buffer_info::version (char *b, char *, int) const { *b = 0; return b; }
char *buffer_info::buffer_name (char *b, char *) const { *b = 0; return b; }
char *buffer_info::file_name (char *b, char *, int) const { *b = 0; return b; }
char *buffer_info::file_or_buffer_name (char *b, char *, int) const { *b = 0; return b; }
char *buffer_info::mode_name (char *b, char *, int) const { *b = 0; return b; }
char *buffer_info::ime_mode (char *b, char *) const { *b = 0; return b; }
char *buffer_info::position (char *b, char *) const { *b = 0; return b; }
char *buffer_info::host_name (char *b, char *, int) const { *b = 0; return b; }
char *buffer_info::process_id (char *b, char *) const { *b = 0; return b; }
char *buffer_info::admin_user (char *b, char *) const { *b = 0; return b; }
char *buffer_info::percent (char *b, char *) const { *b = 0; return b; }

// ============================================================
// Keyboard/Input — real implementations in ncurses-kbd.cc
// Only stubs that ncurses-kbd.cc doesn't provide:
// ============================================================

void check_kbd_enable () {}

// ============================================================
// Display (ncurses glyph-based rendering)
// ============================================================

#include "glyph.h"

// Shared log fd (opened by fetch in ncurses-kbd.cc)
extern int g_fetchlog_fd;
static void
displog (const char *fmt, ...)
{
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

// Initialize or resize glyph buffers for a window.
// For ncurses, cell size is 1x1 (character cells, not pixels).
static void
ncurses_calc_client_size (Window *wp, int width, int height)
{
  wp->w_client.cx = max (0, width);
  wp->w_client.cy = max (0, height);
  // For ncurses: 1 char = 1 cell, no pixel math
  wp->w_ech.cx = max (0, width);
  wp->w_ech.cy = max (0, height);
  wp->w_ch_max.cx = max (0, width);
  wp->w_ch_max.cy = max (0, height);
  if (!wp->w_ech.cx && wp->w_ch_max.cx)
    wp->w_ech.cx = 1;
  if (!wp->w_ech.cy && wp->w_ch_max.cy)
    wp->w_ech.cy = 1;
  if (!wp->w_glyphs.g_rep
      || wp->w_glyphs.g_rep->gr_size.cx != wp->w_ch_max.cx
      || wp->w_glyphs.g_rep->gr_size.cy != wp->w_ch_max.cy)
    {
      if (!wp->alloc_glyph_rep ())
        wp->w_glyphs = Glyphs (0);
      wp->w_disp_flags |= Window::WDF_WINDOW | Window::WDF_MODELINE | Window::WDF_WINSIZE_CHANGED;
    }
}

// Output a single glyph_t to ncurses at position (row, col).
// Returns the number of columns consumed (1 for half-width, 2 for full-width).
static int
output_glyph (int row, int col, glyph_t g)
{
  // Extract character (low 8 bits)
  Char cc = g & 0xff;

  // Determine attributes from glyph bits
  attr_t attrs = 0;
  if (g & GLYPH_BOLD)
    attrs |= A_BOLD;
  if (g & GLYPH_UNDERLINE)
    attrs |= A_UNDERLINE;
  if (g & GLYPH_REVERSED)
    attrs |= A_REVERSE;
  if (g & GLYPH_SELECTED)
    attrs |= A_REVERSE;

  // Check for bitmap glyphs (special display chars)
  if (g & GLYPH_BITMAP_BIT)
    {
      // Bitmap markers: newline mark, tab mark, etc.
      // For ncurses, show as space (these are visual markers only)
      mvaddch (row, col, ' ' | attrs);
      return 1;
    }

  // Determine color pair from syntax highlighting
  int color_pair = 0;
  if (!(g & GLYPH_TEXTPROP_FG_BIT))
    {
      glyph_t text_type = g & GLYPH_TEXT_MASK;
      // Map glyph text types to color pairs
      // 0 = normal, 1-7 = syntax colors
      switch (text_type)
        {
        case GLYPH_COMMENT:  color_pair = 1; break;  // green
        case GLYPH_STRING:   color_pair = 2; break;  // yellow
        case GLYPH_KEYWORD1: color_pair = 3; break;  // cyan
        case GLYPH_KEYWORD2: color_pair = 4; break;  // magenta
        case GLYPH_KEYWORD3: color_pair = 5; break;  // red
        case GLYPH_TAG:      color_pair = 6; break;  // blue
        case GLYPH_CTRL:     color_pair = 7; break;  // bright red
        case GLYPH_LINENUM:  color_pair = 8; break;  // dim
        default: break;
        }
    }

  if (color_pair)
    attrs |= COLOR_PAIR (color_pair);

  // Check glyph category (DBCS lead/trail)
  glyph_t cat = g & GLYPH_CATEGORY_MASK;

  if (cat == GLYPH_LEAD)
    {
      // DBCS lead byte — will be combined with trail in caller
      // Just return, the caller handles lead+trail pair
      return 0;
    }

  if (cat == GLYPH_JUNK)
    {
      mvaddch (row, col, ' ' | attrs);
      return 1;
    }

  // Single-byte or DBCS trail (where cc has the full character)
  if (cc < 0x20)
    {
      // Control character
      mvaddch (row, col, ('^') | attrs);
      return 1;
    }
  else if (cc < 0x80)
    {
      mvaddch (row, col, cc | attrs);
      return 1;
    }
  else
    {
      // Non-ASCII: convert internal Char to UCS-2
      ucs2_t wc = i2w (cc);
      if (wc != 0)
        {
          cchar_t cch;
          wchar_t ws[2] = {(wchar_t)wc, 0};
          setcchar (&cch, ws, attrs, (short)color_pair, NULL);
          mvadd_wch (row, col, &cch);
          int w = wcwidth ((wchar_t)wc);
          return (w > 0) ? w : 1;
        }
      else
        {
          mvaddch (row, col, '?' | attrs);
          return 1;
        }
    }
}

// Render one glyph_data row to ncurses screen row.
static void
render_glyph_row (int row, int cols, const glyph_data *gd)
{
  move (row, 0);
  clrtoeol ();

  if (!gd || gd->gd_len <= 0)
    return;

  const glyph_t *g = gd->gd_cc;
  int len = gd->gd_len;
  int x = 0;

  for (int i = 0; i < len && x < cols; i++)
    {
      glyph_t gt = g[i];
      glyph_t cat = gt & GLYPH_CATEGORY_MASK;

      if (cat == GLYPH_LEAD && i + 1 < len)
        {
          // DBCS pair: lead byte has high byte, trail has low byte
          // The actual Char is stored across lead+trail
          glyph_t trail = g[i + 1];
          Char lead_cc = gt & 0xff;
          Char trail_cc = trail & 0xff;
          Char full_cc = (lead_cc << 8) | trail_cc;

          // Get attributes from lead glyph
          attr_t attrs = 0;
          if (gt & GLYPH_BOLD) attrs |= A_BOLD;
          if (gt & GLYPH_UNDERLINE) attrs |= A_UNDERLINE;
          if (gt & GLYPH_REVERSED) attrs |= A_REVERSE;
          if (gt & GLYPH_SELECTED) attrs |= A_REVERSE;

          int color_pair = 0;
          if (!(gt & GLYPH_TEXTPROP_FG_BIT))
            {
              glyph_t text_type = gt & GLYPH_TEXT_MASK;
              switch (text_type)
                {
                case GLYPH_COMMENT:  color_pair = 1; break;
                case GLYPH_STRING:   color_pair = 2; break;
                case GLYPH_KEYWORD1: color_pair = 3; break;
                case GLYPH_KEYWORD2: color_pair = 4; break;
                case GLYPH_KEYWORD3: color_pair = 5; break;
                case GLYPH_TAG:      color_pair = 6; break;
                case GLYPH_CTRL:     color_pair = 7; break;
                case GLYPH_LINENUM:  color_pair = 8; break;
                default: break;
                }
            }
          if (color_pair)
            attrs |= COLOR_PAIR (color_pair);

          ucs2_t wc = i2w (full_cc);
          if (wc != 0)
            {
              cchar_t cch;
              wchar_t ws[2] = {(wchar_t)wc, 0};
              setcchar (&cch, ws, attrs, (short)color_pair, NULL);
              mvadd_wch (row, x, &cch);
              int w = wcwidth ((wchar_t)wc);
              x += (w > 0) ? w : 1;
            }
          else
            {
              mvaddch (row, x, '?' | attrs);
              x++;
            }
          i++;  // skip trail
        }
      else if (cat == GLYPH_TRAIL)
        {
          // Orphan trail — skip
          continue;
        }
      else if (cat == GLYPH_JUNK)
        {
          // Unused cell
          x++;
        }
      else
        {
          // Normal single-byte glyph
          int w = output_glyph (row, x, gt);
          x += (w > 0) ? w : 1;
        }
    }
}

// Draw modeline for a given window on a given screen row
static void
draw_modeline (Window *wp, int row, int cols)
{
  if (cols <= 0)
    return;

  Buffer *bp = wp->w_bufp;
  if (!bp)
    return;

  int maxw = (cols < 255) ? cols : 255;

  attron (A_REVERSE);
  move (row, 0);
  clrtoeol ();
  if (stringp (bp->lbuffer_name))
    {
      const Char *name = xstring_contents (bp->lbuffer_name);
      int len = xstring_length (bp->lbuffer_name);
      wchar_t wbuf[256];
      int wi = 0;
      if (wi < maxw) wbuf[wi++] = L'-';
      if (wi < maxw) wbuf[wi++] = L'-';
      if (wi < maxw) wbuf[wi++] = bp->b_modified ? L'*' : L'-';
      if (wi < maxw) wbuf[wi++] = L' ';
      for (int i = 0; i < len && wi < maxw; i++)
        {
          ucs2_t wc = i2w (name[i]);
          wbuf[wi++] = wc ? (wchar_t)wc : L'?';
        }
      if (wi < maxw) wbuf[wi++] = L' ';

      // Show line:col position
      char pos[32];
      snprintf (pos, sizeof (pos), "(%ld,%ld)",
                wp->w_linenum, wp->w_column);
      for (int i = 0; pos[i] && wi < maxw; i++)
        wbuf[wi++] = pos[i];
      if (wi < maxw) wbuf[wi++] = L' ';

      while (wi < maxw)
        wbuf[wi++] = L'-';
      wbuf[wi] = 0;
      mvaddnwstr (row, 0, wbuf, wi);
    }
  else
    {
      for (int i = 0; i < maxw; i++)
        mvaddch (row, i, '-');
    }
  attroff (A_REVERSE);
}

// Render minibuffer prompt and content on a given screen row
static void
draw_minibuffer (Window *mini, int row, int cols)
{
  move (row, 0);
  clrtoeol ();

  Buffer *bp = mini->w_bufp;
  if (!bp)
    return;

  int x = 0;

  // Draw prompt arg (e.g. "C-u " or "4 ")
  if (bp->b_prompt_arg[0])
    {
      mvprintw (row, x, "%s", bp->b_prompt_arg);
      x += strlen (bp->b_prompt_arg);
    }

  // Draw prompt text
  if (bp->b_prompt && bp->b_prompt_length > 0)
    {
      for (long i = 0; i < bp->b_prompt_length && x < cols; i++)
        {
          Char c = bp->b_prompt[i];
          if (c < 0x80)
            {
              mvaddch (row, x, (char)c);
              x++;
            }
          else
            {
              ucs2_t wc = i2w (c);
              if (wc != 0)
                {
                  cchar_t cc;
                  wchar_t ws[2] = {(wchar_t)wc, 0};
                  setcchar (&cc, ws, 0, 0, NULL);
                  mvadd_wch (row, x, &cc);
                  int w = wcwidth ((wchar_t)wc);
                  x += (w > 0) ? w : 1;
                }
              else
                {
                  mvaddch (row, x, '?');
                  x++;
                }
            }
        }
    }

  // Draw minibuffer content (the text user is typing)
  if (bp->b_nchars > 0)
    {
      Point pt;
      pt.p_point = 0;
      pt.p_chunk = bp->b_chunkb;
      pt.p_offset = 0;

      while (pt.p_point < bp->b_nchars && x < cols)
        {
          Char c = pt.p_chunk->c_text[pt.p_offset];
          if (c < 0x20)
            {
              // skip control chars
            }
          else if (c < 0x80)
            {
              mvaddch (row, x, c);
              x++;
            }
          else
            {
              ucs2_t wc = i2w (c);
              if (wc != 0)
                {
                  cchar_t cc;
                  wchar_t ws[2] = {(wchar_t)wc, 0};
                  setcchar (&cc, ws, 0, 0, NULL);
                  mvadd_wch (row, x, &cc);
                  int w = wcwidth ((wchar_t)wc);
                  x += (w > 0) ? w : 1;
                }
              else
                {
                  mvaddch (row, x, '?');
                  x++;
                }
            }

          pt.p_point++;
          pt.p_offset++;
          if (pt.p_offset >= pt.p_chunk->c_used && pt.p_chunk->c_next)
            {
              pt.p_chunk = pt.p_chunk->c_next;
              pt.p_offset = 0;
            }
        }
    }
}

// Draw status line (echo area) showing StatusWindow content
static void
draw_status_line (int row, int cols)
{
  move (row, 0);
  clrtoeol ();

  // Check for Vminibuffer_message first (set by (message ...) Lisp function)
  lisp msg = xsymbol_value (Vminibuffer_message);
  if (stringp (msg))
    {
      const Char *s = xstring_contents (msg);
      int len = xstring_length (msg);
      int x = 0;
      for (int i = 0; i < len && x < cols; i++)
        {
          Char c = s[i];
          if (c < 0x20)
            ; // skip control chars
          else if (c < 0x80)
            {
              mvaddch (row, x, c);
              x++;
            }
          else
            {
              ucs2_t wc = i2w (c);
              if (wc != 0)
                {
                  cchar_t cc;
                  wchar_t ws[2] = {(wchar_t)wc, 0};
                  setcchar (&cc, ws, 0, 0, NULL);
                  mvadd_wch (row, x, &cc);
                  int w = wcwidth ((wchar_t)wc);
                  x += (w > 0) ? w : 1;
                }
              else
                {
                  mvaddch (row, x, '?');
                  x++;
                }
            }
        }
      return;
    }

  // Otherwise show StatusWindow content
  int l = g_status_len;
  if (l > 0)
    {
      const ucs2_t *buf = g_status_buf;
      int x = 0;
      for (int i = 0; i < l && x < cols; i++)
        {
          ucs2_t wc = buf[i];
          if (wc < 0x20)
            ; // skip
          else if (wc < 0x80)
            {
              mvaddch (row, x, (char)wc);
              x++;
            }
          else
            {
              cchar_t cc;
              wchar_t ws[2] = {(wchar_t)wc, 0};
              setcchar (&cc, ws, 0, 0, NULL);
              mvadd_wch (row, x, &cc);
              int w = wcwidth ((wchar_t)wc);
              x += (w > 0) ? w : 1;
            }
        }
    }
}

// Reframe: ensure w_point is visible in the window.
// Handles both vertical scrolling (w_disp) and horizontal scrolling (w_top_column).
static void
ncurses_reframe (Window *wp)
{
  Buffer *bp = wp->w_bufp;
  if (!bp)
    return;

  if (bp->b_fold_columns != Buffer::FOLD_NONE)
    bp->folded_count_lines ();

  long linenum, column;
  if (bp->b_fold_columns == Buffer::FOLD_NONE)
    {
      linenum = bp->point_linenum (wp->w_point.p_point);
      column = bp->point_column (wp->w_point);
    }
  else
    {
      linenum = bp->folded_point_linenum (wp->w_point.p_point);
      column = bp->folded_point_column (wp->w_point);
    }
  wp->w_linenum = linenum;
  wp->w_column = column;
  if (wp->w_disp_flags & Window::WDF_GOAL_COLUMN)
    wp->w_goal_column = column;

  // --- Horizontal scrolling (w_top_column) ---
  if (bp->b_fold_columns == Buffer::FOLD_NONE)
    {
      // maxwidth = visible text columns (excluding margin + linenum)
      int maxwidth = wp->w_ech.cx - 1;  // -1 for leading space
      if (wp->w_flags & Window::WF_LINE_NUMBER)
        maxwidth -= Window::LINENUM_COLUMNS + 1;
      maxwidth -= bp->b_prompt_columns;

      // If point is on a double-width char, need one more column
      if (wp->w_point.p_offset != wp->w_point.p_chunk->c_used)
        {
          Char c = wp->w_point.ch ();
          if (c != CC_LFD && c != CC_TAB && char_width (c) == 2)
            maxwidth--;
        }

      if (maxwidth < 1)
        maxwidth = 1;

      int hjump = bp->b_hjump_columns;
      if (hjump <= 0)
        hjump = Window::w_hjump_columns;
      if (hjump <= 0)
        hjump = 4;

      if (column < wp->w_top_column)
        wp->w_top_column = column / hjump * hjump;
      else if (column >= wp->w_top_column + maxwidth)
        wp->w_top_column = ((column - maxwidth + hjump) / hjump * hjump);

      if (column < wp->w_top_column || column - wp->w_top_column >= maxwidth)
        wp->w_top_column = column;
    }

  // --- Vertical scrolling (w_disp) ---
  long disp_linenum;
  if (bp->b_fold_columns == Buffer::FOLD_NONE)
    disp_linenum = bp->point_linenum (wp->w_disp);
  else
    disp_linenum = bp->folded_point_linenum (wp->w_disp);

  int visible_rows = wp->w_ech.cy;
  if (visible_rows <= 0)
    visible_rows = 1;

  if (linenum < disp_linenum || linenum >= disp_linenum + visible_rows)
    {
      disp_linenum = linenum - visible_rows / 2;
      if (disp_linenum < 1)
        disp_linenum = 1;

      Point df;
      if (bp->b_fold_columns == Buffer::FOLD_NONE)
        bp->linenum_point (df, disp_linenum);
      else
        bp->folded_linenum_point (df, disp_linenum);
      wp->w_disp = df.p_point;
    }
}

// Compute cursor position from glyph data.
// Walk glyph rows to find where w_point falls.
static void
glyph_point_to_screen (Window *wp, int *out_y, int *out_x)
{
  *out_y = 0;
  *out_x = 0;

  if (!wp->w_glyphs.g_rep)
    return;

  Buffer *bp = wp->w_bufp;
  if (!bp)
    return;

  // Walk buffer from w_disp to w_point, tracking screen position
  // using the same logic as the glyph system
  point_t target = wp->w_point.p_point;
  point_t disp = wp->w_disp;

  if (target < disp)
    return;

  Point pt;
  pt.p_point = 0;
  pt.p_chunk = bp->b_chunkb;
  pt.p_offset = 0;
  if (disp > 0)
    bp->goto_char (pt, disp);

  int y = 0, x = 0;
  int cols = wp->w_ech.cx;
  int rows = wp->w_ech.cy;
  point_t nchars = bp->b_nchars;

  // redraw_line() adds a leading space (left margin) at glyph column 0,
  // plus optional line number columns. x tracks the text column;
  // the leading space offset is added at the end.
  int linenum_offset = 0;
  if (wp->w_flags & Window::WF_LINE_NUMBER)
    linenum_offset = Window::LINENUM_COLUMNS + 1;

  while (pt.p_point < target && pt.p_point < nchars && y < rows)
    {
      Char c = pt.p_chunk->c_text[pt.p_offset];
      if (c == '\n')
        {
          y++;
          x = 0;
        }
      else if (c == '\t')
        {
          int tab = bp->b_tab_columns;
          if (tab <= 0) tab = 8;
          x = x + tab - (x % tab);
        }
      else if (c < 0x20)
        x += 2;  // ^X
      else if (char_width (c) == 2)
        x += 2;
      else
        x++;

      // Handle line wrap (for fold mode)
      if (bp->b_fold_columns != Buffer::FOLD_NONE
          && x + 1 + linenum_offset >= cols)
        {
          y++;
          x = 0;
        }

      pt.p_point++;
      pt.p_offset++;
      if (pt.p_offset >= pt.p_chunk->c_used && pt.p_chunk->c_next)
        {
          pt.p_chunk = pt.p_chunk->c_next;
          pt.p_offset = 0;
        }
    }

  *out_y = y;
  // Adjust for horizontal scroll (w_top_column) then add glyph offsets:
  // +1 for leading space margin, + linenum columns
  *out_x = (x - wp->w_top_column) + 1 + linenum_offset;
}

// Initialize ncurses color pairs for syntax highlighting
static int g_colors_initialized = 0;
static void
init_ncurses_colors ()
{
  if (g_colors_initialized)
    return;
  g_colors_initialized = 1;

  // Color pairs for syntax highlighting
  init_pair (1, COLOR_GREEN, -1);     // comment
  init_pair (2, COLOR_YELLOW, -1);    // string
  init_pair (3, COLOR_CYAN, -1);      // keyword1
  init_pair (4, COLOR_MAGENTA, -1);   // keyword2
  init_pair (5, COLOR_RED, -1);       // keyword3
  init_pair (6, COLOR_BLUE, -1);      // tag
  init_pair (7, COLOR_RED, -1);       // ctrl (bright via A_BOLD)
  init_pair (8, COLOR_WHITE, -1);     // linenum (dim via A_DIM)
}

// SIGWINCH flag (set in ncurses-main.cc)
extern volatile int g_need_resize;

void
refresh_screen (int)
{
  init_ncurses_colors ();

  // Handle terminal resize (SIGWINCH / KEY_RESIZE)
  if (g_need_resize)
    {
      g_need_resize = 0;

      struct winsize ws;
      if (ioctl (STDOUT_FILENO, TIOCGWINSZ, &ws) == 0
          && ws.ws_row > 0 && ws.ws_col > 0)
        resizeterm (ws.ws_row, ws.ws_col);

      int rows, cols;
      getmaxyx (stdscr, rows, cols);
      app.active_frame.size.cx = cols;
      app.active_frame.size.cy = rows;

      clear ();
      displog ("refresh: resized to %dx%d\n", cols, rows);
    }

  int rows, cols;
  getmaxyx (stdscr, rows, cols);

  if (rows < 3 || cols < 4)
    return;

  Window *sel = selected_window ();
  if (!sel)
    return;
  int in_minibuffer = sel->minibuffer_window_p ()
                      && sel->w_bufp
                      && sel->w_bufp->b_minibufferp;

  // Find the main editing window
  Window *main_wp = app.active_frame.windows;
  if (!main_wp || !main_wp->w_bufp)
    return;

  Buffer *bp = main_wp->w_bufp;

  // Layout:
  //   text:      rows 0 .. rows-3
  //   modeline:  row rows-2
  //   echo area: row rows-1
  int ml_row = rows - 2;
  int text_rows = ml_row;

  displog ("refresh: nchars=%ld point=%ld mini=%d rows=%d cols=%d\n",
           (long)bp->b_nchars,
           (long)main_wp->w_point.p_point,
           in_minibuffer, rows, cols);

  // Initialize/resize glyph buffers
  ncurses_calc_client_size (main_wp, cols, text_rows);

  // Reframe: ensure point is visible
  ncurses_reframe (main_wp);

  // Fill glyph buffers via core redraw_window
  if (main_wp->w_glyphs.g_rep)
    {
      Point df;
      df.p_point = 0;
      df.p_chunk = bp->b_chunkb;
      df.p_offset = 0;
      if (main_wp->w_disp > 0)
        bp->goto_char (df, main_wp->w_disp);

      long vlinenum;
      if (bp->b_fold_columns == Buffer::FOLD_NONE)
        vlinenum = bp->point_linenum (main_wp->w_disp);
      else
        vlinenum = bp->folded_point_linenum (main_wp->w_disp);

      int hide = symbol_value (Vhide_restricted_region, bp) != Qnil;
      main_wp->redraw_window (df, vlinenum, 1, hide);

      // Render glyph data to ncurses
      glyph_data **ng = main_wp->w_glyphs.g_rep->gr_nglyph;
      for (int y = 0; y < text_rows && y < main_wp->w_ch_max.cy; y++)
        render_glyph_row (y, cols, ng[y]);

      // Fill remaining rows with ~
      for (int y = main_wp->w_ch_max.cy; y < text_rows; y++)
        {
          move (y, 0);
          clrtoeol ();
          mvaddch (y, 0, '~');
        }

      // Swap old/new glyph buffers for next frame's diff
      glyph_data **tmp = main_wp->w_glyphs.g_rep->gr_oglyph;
      main_wp->w_glyphs.g_rep->gr_oglyph = main_wp->w_glyphs.g_rep->gr_nglyph;
      main_wp->w_glyphs.g_rep->gr_nglyph = tmp;
    }

  // Draw modeline
  draw_modeline (main_wp, ml_row, cols);

  // Draw echo area (last row)
  if (in_minibuffer)
    {
      Window *mini = Window::minibuffer_window ();
      draw_minibuffer (mini, rows - 1, cols);

      // Position cursor in minibuffer
      Buffer *mbp = mini->w_bufp;
      int cx = mbp->b_prompt_columns + strlen (mbp->b_prompt_arg);
      if (mbp->b_nchars > 0 && mini->w_point.p_point > 0)
        {
          Point pt;
          pt.p_point = 0;
          pt.p_chunk = mbp->b_chunkb;
          pt.p_offset = 0;
          int point_x = 0;
          while (pt.p_point < mini->w_point.p_point && pt.p_point < mbp->b_nchars)
            {
              Char c = pt.p_chunk->c_text[pt.p_offset];
              if (c < 0x20)
                ;
              else if (c < 0x80)
                point_x++;
              else
                {
                  ucs2_t wc = i2w (c);
                  int w = (wc != 0) ? wcwidth ((wchar_t)wc) : 1;
                  point_x += (w > 0) ? w : 1;
                }
              pt.p_point++;
              pt.p_offset++;
              if (pt.p_offset >= pt.p_chunk->c_used && pt.p_chunk->c_next)
                {
                  pt.p_chunk = pt.p_chunk->c_next;
                  pt.p_offset = 0;
                }
            }
          cx += point_x;
        }
      move (rows - 1, cx);
    }
  else
    {
      draw_status_line (rows - 1, cols);

      // Position cursor in main buffer
      int cy, cx;
      glyph_point_to_screen (main_wp, &cy, &cx);
      if (cy < text_rows)
        move (cy, cx);
    }

  // Flush to terminal
  ::refresh ();
}

void
pending_refresh_screen ()
{
  // No-op for ncurses (we refresh synchronously)
}

Window *
Window::minibuffer_window ()
{
  // Return the minibuffer window (second in the list)
  Window *wp = app.active_frame.windows;
  if (wp && wp->w_next)
    return wp->w_next;
  return 0;
}

// ============================================================
// Wait cursor / Process / Buffer stubs
// ============================================================

lisp Fbegin_wait_cursor () { return Qnil; }
lisp Fend_wait_cursor () { return Qnil; }
lisp Fget_buffer_window (lisp, lisp) { return Qnil; }
lisp Fprocess_marker (lisp) { return Qnil; }
void Buffer::cleanup_waitobj_list () {}

// ============================================================
// DLL/FFI stubs
// ============================================================

#include "dll.h"

lisp funcall_dll (lisp, lisp) { return Qnil; }
lisp funcall_c_callable (lisp, lisp) { return Qnil; }

// ============================================================
// Monitor stubs
// ============================================================

#ifdef _WIN32
#include "monitor.h"

Monitor monitor;
HMONITOR Monitor::get_monitor_from_rect (const RECT *) { return 0; }
#endif

// ============================================================
// Worker thread stubs
// ============================================================

#include "thread.h"

worker_thread::worker_thread () { w_hthread = 0; w_hlock_event = 0; w_hterm_event = 0; w_intr = 0; }
worker_thread::~worker_thread () {}
int worker_thread::start () { return 0; }
int worker_thread::wait () { return 0; }
void worker_thread::destroy () {}

// ============================================================
// OLE stubs
// ============================================================

void set_oledata_name (lisp) {}

// ============================================================
// FKWin stubs
// ============================================================

#include "fnkey.h"

int FKWin::fk_default_nbuttons = 10;

// ============================================================
// GlobalIME stubs
// ============================================================

#include "gime.h"

GlobalIME::GlobalIME () { gi_app = 0; gi_pump = 0; ImmGetPropertyProc = 0; }

// ============================================================
// Splitter dtor stub
// ============================================================

#ifdef _WIN32
splitter::~splitter () {}
#endif

// ============================================================
// Filer stubs
// ============================================================

#ifdef _WIN32
#include "Filer.h"

void Filer::close_mlfiler () {}
#endif

// ============================================================
// sock.cc blocking_hook needs Fdo_events
// ============================================================

lisp Fdo_events () { return Qnil; }

// ============================================================
// Lisp-facing functions that are Win32-only but registered in symtable
// ============================================================

#ifndef _WIN32
#include <unistd.h>

lisp Fadmin_user_p ()
{
  return getuid () == 0 ? Qt : Qnil;
}

lisp Fsi_get_key_state (lisp)
{
  return Qnil;
}

lisp Fsi_uuid_create (lisp)
{
  FEsimple_error (Eremove_not_supported);
  return Qnil;
}

lisp Fsi_search_path (lisp, lisp, lisp)
{
  return Qnil;
}

lisp Fsi_file_operation (lisp, lisp, lisp, lisp)
{
  FEsimple_error (Eremove_not_supported);
  return Qnil;
}

lisp Fset_per_device_directory (lisp)
{
  return Qt;
}

lisp Fget_short_path_name (lisp lpath)
{
  return lpath;
}

lisp Fcopy_to_clipboard (lisp)
{
  return Qnil;
}

lisp Fget_clipboard_data ()
{
  return Qnil;
}

lisp Fclipboard_empty_p ()
{
  return Qt;
}

int make_clipboard_text (CLIPBOARDTEXT &, lisp, int)
{
  return 0;
}

int make_string_from_clipboard_text (lisp, const void *, UINT, int)
{
  return 0;
}

#endif // !_WIN32

// ============================================================
// Lisp-callable functions from symtable-ed.cc that are
// Win32-frontend-only. Stubbed for ncurses.
// ============================================================

// Window management (minimal implementations)
lisp Fselected_window () { return selected_window () ? selected_window ()->lwp : Qnil; }
lisp Fwindow_buffer (lisp) { return selected_buffer () ? selected_buffer ()->lbp : Qnil; }
lisp Fwindow_height (lisp) { return make_fixnum (24); }
lisp Fwindow_width (lisp) { return make_fixnum (80); }
lisp Fwindow_lines (lisp) { return make_fixnum (23); }
lisp Fwindow_columns (lisp) { return make_fixnum (80); }
lisp Fwindow_coordinate (lisp) { return Qnil; }
lisp Fget_window_line (lisp) { return make_fixnum (0); }
lisp Fget_window_start_line (lisp) { return make_fixnum (0); }
lisp Fget_window_handle (lisp) { return Qnil; }
lisp Fget_window_flags () { return make_fixnum (0); }
lisp Fset_window_flags (lisp) { return Qnil; }
lisp Fget_local_window_flags (lisp) { return make_fixnum (0); }
lisp Fset_local_window_flags (lisp, lisp, lisp) { return Qnil; }
lisp Fset_window (lisp) { return Qnil; }
lisp Fsplit_window (lisp, lisp) { return Qnil; }
lisp Fdelete_window () { return Qnil; }
lisp Fdelete_other_windows () { return Qnil; }
lisp Fenlarge_window (lisp, lisp) { return Qnil; }
lisp Fnext_window (lisp, lisp) { return Qnil; }
lisp Fprevious_window (lisp, lisp) { return Qnil; }
lisp Fdeleted_window_p (lisp) { return Qnil; }
lisp Fpos_not_visible_in_window_p (lisp, lisp) { return Qnil; }
lisp Fcurrent_window_configuration () { return Qnil; }
lisp Fset_window_configuration (lisp) { return Qnil; }

// Screen
lisp Fscreen_height () { return make_fixnum (24); }
lisp Fscreen_width () { return make_fixnum (80); }
lisp Frefresh_screen (lisp) { refresh_screen (1); return Qnil; }

// Minibuffer
lisp Fminibuffer_window () { return Qnil; }
lisp Fminibuffer_window_p (lisp) { return Qnil; }
lisp Fminibuffer_buffer (lisp) { return Qnil; }
lisp Fminibuffer_default (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lminibuffer_default;
}
lisp Fminibuffer_completion_list (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lcomplete_list;
}
lisp Fminibuffer_completion_type (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lcomplete_type;
}
lisp Fminibuffer_dialog_title (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->ldialog_title;
}

// Read functions (minibuffer input)
lisp Fread_string (lisp, lisp) { return Qnil; }
lisp Fread_integer (lisp, lisp) { return Qnil; }
lisp Fread_sexp (lisp, lisp) { return Qnil; }
lisp Fread_command_name (lisp, lisp) { return Qnil; }
lisp Fread_function_name (lisp, lisp) { return Qnil; }
lisp Fread_variable_name (lisp, lisp) { return Qnil; }
lisp Fread_symbol_name (lisp, lisp) { return Qnil; }
lisp Fread_buffer_name (lisp, lisp) { return Qnil; }
lisp Fread_exist_buffer_name (lisp, lisp) { return Qnil; }
lisp Fread_file_name (lisp, lisp) { return Qnil; }
lisp Fread_exist_file_name (lisp, lisp) { return Qnil; }
lisp Fread_file_name_list (lisp, lisp) { return Qnil; }
lisp Fread_directory_name (lisp, lisp) { return Qnil; }
lisp Fread_char_encoding (lisp, lisp) { return Qnil; }
lisp Fread_exact_char_encoding (lisp, lisp) { return Qnil; }
lisp Fcompleting_read (lisp, lisp, lisp) { return Qnil; }
// Completion engine — POSIX port of win32/minibuf.cc completion class
namespace {

class completion
{
  lisp c_type;
  lisp c_string;
  lisp c_target;
  int c_target_len;
  int c_match_len;
  lisp c_result;
  lisp c_item;
  lisp c_matches_list;
  int c_strict_match;
  int c_nmatches;
  int c_no_completions;
  int c_word;
  lisp c_prefix;
  int c_force_no_match;

  int do_completion (lisp, int);
  void complete_with_slash (lisp, int);
  void fix_match_len ();
  void complete_symbol (lisp);
  void set_target (lisp);
  void set_prefix (lisp);
  void adjust_prefix (lisp);
  int complete_filename_scan (const char *, lisp, lisp);
  lisp split_pathname ();
public:
  completion (lisp, lisp, int);
  void complete_symbol ();
  void complete_buffer_name ();
  void complete_filename ();
  void complete_char_encoding ();
  void complete_list (lisp, int);
  lisp result () const;
};

void
completion::set_target (lisp string)
{
  assert (stringp (string));
  c_target = string;
  c_target_len = xstring_length (string);
}

void
completion::set_prefix (lisp prefix)
{
  assert (stringp (prefix));
  c_prefix = prefix;
}

completion::completion (lisp type, lisp string, int word)
{
  c_type = type;
  c_string = string;
  set_target (string);
  c_match_len = 0;
  c_result = 0;
  c_item = Qnil;
  c_matches_list = Qnil;
  c_strict_match = 0;
  c_nmatches = 0;
  c_no_completions = 1;
  c_word = word;
  c_prefix = Qnil;
  c_force_no_match = 0;
}

int
completion::do_completion (lisp candidate, int igcase)
{
  c_no_completions = 0;

  lisp item = c_item == Qnil ? c_target : c_item;
  lisp eq = (igcase
             ? Fstring_not_equalp (item, candidate, Qnil)
             : Fstring_not_equal (item, candidate, Qnil));
  int l = eq == Qnil ? xstring_length (item) : fixnum_value (eq);

  if (l < c_target_len)
    return 0;

  if (memq (candidate, c_matches_list))
    return 1;
  c_matches_list = Fcons (candidate, c_matches_list);
  c_nmatches++;

  if (l == c_target_len && l == xstring_length (candidate))
    c_strict_match = 1;
  if (c_item == Qnil)
    {
      c_item = candidate;
      c_match_len = xstring_length (candidate);
    }
  else
    c_match_len = min (c_match_len, l);

  return 1;
}

void
completion::complete_with_slash (lisp s, int igcase)
{
  if (stringp (s))
    {
      lisp d = make_string (xstring_length (s) + 1);
      bcopy (xstring_contents (s), xstring_contents (d),
             xstring_length (s));
      xstring_contents (d)[xstring_length (s)] = '/';
      if (!do_completion (d, igcase))
        destruct_string (d);
    }
}

void
completion::fix_match_len ()
{
  if (c_item == Qnil || !c_word || c_match_len <= c_target_len)
    return;

  const Char *p = xstring_contents (c_item) + c_target_len;
  const Char *pe = xstring_contents (c_item) + c_match_len;

  if (p < pe)
    {
      word_state ws (xsyntax_table (selected_buffer ()->lsyntax_table), *p);
      for (; p < pe && ws.forward (*p) != word_state::not_inword; p++)
        ;
    }

  c_match_len = min (c_match_len, (int)(p - xstring_contents (c_item)));
}

void
completion::adjust_prefix (lisp prefix)
{
  int l = xstring_length (prefix) + c_match_len;
  Char *b = (Char *)alloca (sizeof (Char) * l);
  bcopy (xstring_contents (prefix), b, xstring_length (prefix));
  if (stringp (c_item))
    bcopy (xstring_contents (c_item), b + xstring_length (prefix), c_match_len);
  if (l == xstring_length (c_string) && !bcmp (b, xstring_contents (c_string), l))
    c_result = c_string;
  else
    c_result = make_string (b, l);
}

void
completion::complete_symbol (lisp vec)
{
  for (lisp *v = xvector_contents (vec), *ve = v + xvector_length (vec); v < ve; v++)
    for (lisp p = *v; consp (p); p = xcdr (p))
      {
        lisp symbol = xcar (p);
        if (c_type == Kfunction_name)
          {
            if (void_function_p (symbol))
              continue;
          }
        else if (c_type == Kcommand_name)
          {
            if (Fcommandp (symbol) == Qnil)
              continue;
          }
        else if (c_type == Kvariable_name)
          {
            if (xsymbol_value (symbol) == Qunbound)
              continue;
          }
        else if (c_type == Knon_trivial_symbol_name)
          {
            if (void_function_p (symbol)
                && xsymbol_value (symbol) == Qunbound
                && xsymbol_plist (symbol) == Qnil)
              continue;
          }
        do_completion (xsymbol_name (symbol), 0);
      }
}

void
completion::complete_symbol ()
{
  lisp package = coerce_to_package (0);

  lisp lpkg = symbol_value (Vbuffer_package, selected_buffer ());
  if (stringp (lpkg))
    {
      lpkg = Ffind_package (lpkg);
      if (lpkg != Qnil)
        package = lpkg;
    }

  Char *b = xstring_contents (c_target);
  int l = xstring_length (c_target);

  maybe_symbol_string mss (package);
  mss.parse (b, l);
  package = mss.current_package ();

  if (mss.pkg_end ())
    {
      set_prefix (make_string (xstring_contents (c_target),
                               b - xstring_contents (c_target)));
      set_target (make_string (b, (xstring_contents (c_target)
                                   + xstring_length (c_target) - b)));
    }

  if (!mss.pkg_end () || b - mss.pkg_end () == 2)
    complete_symbol (xpackage_internal (package));
  complete_symbol (xpackage_external (package));

  if (!mss.pkg_end ())
    for (lisp p = xpackage_use_list (package); consp (p); p = xcdr (p))
      {
        package = xcar (p);
        if (packagep (package))
          complete_symbol (xpackage_external (package));
      }

  // Package name completion
  if (!mss.pkg_end ())
    for (lisp p = xsymbol_value (Vpackage_list); consp (p); p = xcdr (p))
      {
        lisp x = xcar (p);
        if (count_symbols (xpackage_external (x)) <= 0)
          continue;
        do_completion (xpackage_name (x), 0);
        for (lisp q = xpackage_nicknames (x); consp (q); q = xcdr (q))
          do_completion (xcar (q), 0);
      }

  fix_match_len ();
  if (mss.pkg_end ())
    adjust_prefix (c_prefix);
}

void
completion::complete_buffer_name ()
{
  int int_ok = c_target_len >= 1 && *xstring_contents (c_target) == ' ';
  for (Buffer *bp = Buffer::b_blist; bp; bp = bp->b_next)
    if (int_ok || !bp->internal_buffer_p ())
      {
        lisp name = Fbuffer_name (bp->lbp);
        if (!do_completion (name, 0) && name != bp->lbuffer_name)
          destruct_string (name);
      }
  fix_match_len ();
  c_force_no_match = int_ok;
}

// File completion via WINFS abstraction layer
int
completion::complete_filename_scan (const char *path, lisp show_dots, lisp ignores)
{
  int ignored = 0;

  WIN32_FIND_DATAA *fd = (WIN32_FIND_DATAA *)alloca (sizeof *fd + 2);
  HANDLE h = WINFS::FindFirstFile (path, fd);
  if (h == INVALID_HANDLE_VALUE)
    return 0;

  find_handle fh (h);
  int scan_count = 0;
  do
    {
      if (show_dots == Qnil && *fd->cFileName == '.')
        continue;
      if (fd->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        strcat (fd->cFileName, "/");
      else if (c_type == Kdirectory_name)
        continue;

      scan_count++;
      lisp name = make_string (fd->cFileName);
      for (lisp p = ignores; consp (p); p = xcdr (p))
        {
          lisp ext = xcar (p);
          if (stringp (ext)
              && xstring_length (name) > xstring_length (ext)
              && string_equalp (name, xstring_length (name) - xstring_length (ext),
                                ext, 0, xstring_length (ext)))
            {
              destruct_string (name);
              ignored = 1;
              goto ignore;
            }
        }
      if (!do_completion (name, 1))
        destruct_string (name);
    ignore:
      ;
    }
  while (WINFS::FindNextFile (h, fd));
  displog ("complete_filename_scan: scanned %d entries\n", scan_count);
  return ignored;
}

lisp
completion::split_pathname ()
{
  const Char *p0 = xstring_contents (c_target);
  const Char *pe = p0 + xstring_length (c_target);
  const Char *p;
  for (p = pe; p > p0 && p[-1] != '/'; p--)
    ;
  set_target (make_string (p, pe - p));

  if (!c_target_len)
    {
      lisp x = Fnamestring (make_string (p0, p - p0));
      if (xstring_length (x)
          && xstring_contents (x)[xstring_length (x) - 1] != '/')
        {
          Char *b = (Char *)xmalloc ((xstring_length (x) + 1) * sizeof (Char));
          bcopy (xstring_contents (x), b, xstring_length (x));
          b[xstring_length (x)++] = '/';
          xfree (xstring_contents (x));
          xstring_contents (x) = b;
        }
      return x;
    }

  return Fdirectory_namestring (make_string (p0, p - p0));
}

void
completion::complete_filename ()
{
  Buffer *bp = selected_buffer ();

  lisp show_dots = symbol_value (Vshow_dots, bp);
  if (show_dots == Qunbound)
    show_dots = Qnil;

  lisp ignores = symbol_value (Vignored_extensions, bp);
  if (ignores == Qunbound)
    ignores = Qnil;

  lisp directory = split_pathname ();
  if (!xstring_length (directory))
    directory = bp->ldirectory;
  set_prefix (directory);
  if (xstring_length (c_target))
    show_dots = Qt;

  char *path = (char *)alloca (2 * xstring_length (directory) + 10);
  w2s (path, directory);
  strcat (path, "*");

  {
    char tb[128];
    if (stringp (c_target))
      w2s (tb, tb + sizeof tb - 1, c_target);
    else
      tb[0] = 0;
    displog ("complete_filename: dir=\"%s\" target=\"%s\" tlen=%d\n",
             path, tb, c_target_len);
  }

  if (complete_filename_scan (path, show_dots, ignores) && c_item == Qnil)
    complete_filename_scan (path, show_dots, Qnil);

  displog ("complete_filename: nmatches=%d match_len=%d strict=%d\n",
           c_nmatches, c_match_len, c_strict_match);
  if (c_item != Qnil && stringp (c_item))
    {
      char ib[128];
      w2s (ib, ib + sizeof ib - 1, c_item);
      displog ("complete_filename: best_item=\"%s\"\n", ib);
    }
  else
    displog ("complete_filename: no item matched\n");

  fix_match_len ();
  adjust_prefix (directory);
}

void
completion::complete_char_encoding ()
{
  for (lisp p = xsymbol_value (Vchar_encoding_list); consp (p); p = xcdr (p))
    {
      lisp encoding = xcar (p);
      if (char_encoding_p (encoding)
          && (c_type == Kchar_encoding
              || xchar_encoding_type (encoding) != encoding_auto_detect))
        do_completion (xchar_encoding_name (encoding), 0);
    }
  fix_match_len ();
}

void
completion::complete_list (lisp list, int igcase)
{
  for (; consp (list); list = xcdr (list))
    {
      lisp x = xcar (list);
      if (consp (x))
        x = xcar (x);
      if (stringp (x))
        do_completion (x, igcase);
      else if (symbolp (x))
        do_completion (xsymbol_name (x), igcase);
    }
  fix_match_len ();
}

lisp
completion::result () const
{
  multiple_value::count () = 2;
  multiple_value::value (1) = Qnil;

  if (c_no_completions)
    return Kno_completions;

  if (c_item == Qnil)
    return Kno_match;

  multiple_value::count () = 3;
  multiple_value::value (1) = c_matches_list;
  multiple_value::value (2) = c_prefix;
  if (c_target_len && c_match_len == c_target_len && c_strict_match)
    {
      if (xlist_length (c_matches_list) == 1)
        return Ksolo_match;
      return Knot_unique;
    }

  if (c_force_no_match)
    return Kno_match;

  if (c_result)
    return c_result;

  if (c_match_len == c_target_len)
    return c_string;

  return make_string (xstring_contents (c_item), c_match_len);
}

} // anonymous namespace

lisp
Fdo_completion (lisp string, lisp type, lisp word, lisp list)
{
  check_string (string);

  // Debug: log input
  {
    char sb[128];
    w2s (sb, sb + sizeof sb - 1, string);
    const char *tname = "?";
    if (type == Kexist_file_name) tname = ":exist-file-name";
    else if (type == Kfile_name) tname = ":file-name";
    else if (type == Kfile_name_list) tname = ":file-name-list";
    else if (type == Kdirectory_name) tname = ":directory-name";
    else if (type == Ksymbol_name) tname = ":symbol-name";
    else if (type == Kcommand_name) tname = ":command-name";
    else if (type == Kbuffer_name) tname = ":buffer-name";
    else if (type == Kfunction_name) tname = ":function-name";
    displog ("do_completion: string=\"%s\" type=%s len=%d type_ptr=%p Kfnl=%p\n",
             sb, tname, (int)xstring_length (string),
             (void *)type, (void *)Kfile_name_list);
  }

  completion cmplt (type, string, word && word != Qnil);

  if (type == Ksymbol_name || type == Kfunction_name
      || type == Kcommand_name || type == Kvariable_name
      || type == Knon_trivial_symbol_name)
    cmplt.complete_symbol ();
  else if (type == Kexist_file_name || type == Kfile_name
           || type == Kfile_name_list || type == Kdirectory_name)
    {
      displog ("do_completion: ENTERING complete_filename()\n");
      cmplt.complete_filename ();
      displog ("do_completion: RETURNED from complete_filename()\n");
    }
  else if (type == Kbuffer_name || type == Kexist_buffer_name)
    cmplt.complete_buffer_name ();
  else if (type == Kchar_encoding || type == Kexact_char_encoding)
    cmplt.complete_char_encoding ();
  else if (consp (list))
    cmplt.complete_list (list, type == Klist_ignore_case);
  else
    displog ("do_completion: NO MATCH for type=%p\n", (void *)type);

  lisp res = cmplt.result ();

  // Debug: log result
  {
    if (stringp (res))
      {
        char rb[128];
        w2s (rb, rb + sizeof rb - 1, res);
        displog ("do_completion: result=\"%s\" len=%d same=%d\n",
                 rb, (int)xstring_length (res), res == string);
      }
    else if (res == Kno_completions)
      displog ("do_completion: result=:no-completions\n");
    else if (res == Kno_match)
      displog ("do_completion: result=:no-match\n");
    else if (res == Ksolo_match)
      displog ("do_completion: result=:solo-match\n");
    else if (res == Knot_unique)
      displog ("do_completion: result=:not-unique\n");
    else
      displog ("do_completion: result=%p\n", (void *)res);
  }

  return res;
}

// Prefix args
lisp
Freset_prefix_args (lisp arg, lisp value)
{
  xsymbol_value (Vnext_prefix_args) = arg;
  xsymbol_value (Vnext_prefix_value) = value;
  // Win32 does: keyseq.again(), close_ime(), keep_next_command_key(), continue_pre_selection()
  // ncurses: skip IME/selection, just set the prefix values
  return Qt;
}

lisp
Fset_next_prefix_args (lisp arg, lisp value, lisp c)
{
  xsymbol_value (Vnext_prefix_args) = arg;
  xsymbol_value (Vnext_prefix_value) = value;
  if (c && c != Qnil)
    {
      check_char (c);
      // Win32 pushes to keyseq for display; ncurses skips
    }
  return Qt;
}

// Popup
lisp Fpopup_string (lisp, lisp, lisp) { return Qnil; }
lisp Fpopup_list (lisp, lisp, lisp) { return Qnil; }
lisp Fcontinue_popup () { return Qnil; }

// Menu
lisp Fcreate_menu (lisp) { return Qnil; }
lisp Fcreate_popup_menu (lisp) { return Qnil; }
lisp Fadd_menu_item (lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fadd_menu_separator (lisp, lisp) { return Qnil; }
lisp Fadd_popup_menu (lisp, lisp, lisp) { return Qnil; }
lisp Finsert_menu_item (lisp, lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Finsert_menu_separator (lisp, lisp, lisp) { return Qnil; }
lisp Finsert_popup_menu (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fdelete_menu (lisp, lisp, lisp) { return Qnil; }
lisp Fcopy_menu_items (lisp, lisp) { return Qnil; }
lisp Fset_menu (lisp) { return Qnil; }
lisp Fcurrent_menu (lisp) { return Qnil; }
lisp Fget_menu (lisp, lisp, lisp) { return Qnil; }
lisp Fget_menu_position (lisp, lisp) { return Qnil; }
lisp Fcall_menu (lisp) { return Qnil; }
lisp Ftrack_popup_menu (lisp, lisp) { return Qnil; }
lisp Fuse_local_menu (lisp) { return Qnil; }

// Dialog
lisp Fdialog_box (lisp, lisp, lisp) { return Qnil; }
lisp Fproperty_sheet (lisp, lisp, lisp) { return Qnil; }
lisp Ffile_name_dialog (lisp) { return Qnil; }
lisp Fdirectory_name_dialog (lisp) { return Qnil; }
lisp Fdrive_dialog (lisp) { return Qnil; }
lisp Fbuffer_selector () { return Qnil; }
lisp Fprint_dialog (lisp) { return Qnil; }
lisp Fprint_buffer (lisp) { return Qnil; }

// Font
lisp Fget_text_fontset () { return Qnil; }
lisp Fset_text_fontset (lisp) { return Qnil; }
lisp Fget_filer_font () { return Qnil; }
lisp Fset_filer_font (lisp) { return Qnil; }

// IME
lisp Fget_ime_mode () { return Qnil; }
lisp Ftoggle_ime (lisp) { return Qnil; }
lisp Fset_ime_read_string (lisp) { return Qnil; }
lisp Fget_ime_composition_string () { return Qnil; }
lisp Fpop_ime_composition_string () { return Qnil; }
lisp Fime_register_word_dialog (lisp, lisp) { return Qnil; }
lisp Fenable_global_ime (lisp) { return Qnil; }

// Process
lisp Fmake_process (lisp, lisp) { return Qnil; }
lisp Fcall_process (lisp, lisp) { return Qnil; }
lisp Fbuffer_process (lisp) { return Qnil; }
lisp Fprocess_buffer (lisp) { return Qnil; }
lisp Fprocess_status (lisp) { return Qnil; }
lisp Fprocess_exit_code (lisp) { return Qnil; }
lisp Fprocess_command (lisp) { return Qnil; }
lisp Fprocess_send_string (lisp, lisp) { return Qnil; }
lisp Fprocess_filter (lisp) { return Qnil; }
lisp Fset_process_filter (lisp, lisp) { return Qnil; }
lisp Fprocess_sentinel (lisp) { return Qnil; }
lisp Fset_process_sentinel (lisp, lisp) { return Qnil; }
lisp Fprocess_incode (lisp) { return Qnil; }
lisp Fset_process_incode (lisp, lisp) { return Qnil; }
lisp Fprocess_outcode (lisp) { return Qnil; }
lisp Fset_process_outcode (lisp, lisp) { return Qnil; }
lisp Fprocess_eol_code (lisp) { return Qnil; }
lisp Fset_process_eol_code (lisp, lisp) { return Qnil; }
lisp Fkill_process (lisp) { return Qnil; }
lisp Fsignal_process (lisp) { return Qnil; }
lisp Fopen_network_stream (lisp, lisp, lisp, lisp) { return Qnil; }

// OLE
lisp Fole_create_object (lisp) { return Qnil; }
lisp Fole_get_object (lisp) { return Qnil; }
lisp Fole_putprop (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fole_getprop (lisp, lisp, lisp) { return Qnil; }
lisp Fole_method (lisp, lisp, lisp) { return Qnil; }
lisp Fole_method_star (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fole_create_event_sink (lisp, lisp, lisp) { return Qnil; }
lisp Fset_ole_event_handler (lisp, lisp, lisp) { return Qnil; }
lisp Fole_enumerator_create (lisp) { return Qnil; }
lisp Fole_enumerator_next (lisp) { return Qnil; }
lisp Fole_enumerator_reset (lisp) { return Qnil; }
lisp Fole_enumerator_skip (lisp, lisp) { return Qnil; }
lisp Fole_drop_files (lisp, lisp, lisp, lisp) { return Qnil; }

// DDE
lisp Fdde_initiate (lisp, lisp) { return Qnil; }
lisp Fdde_terminate (lisp) { return Qnil; }
lisp Fdde_execute (lisp, lisp) { return Qnil; }
lisp Fdde_poke (lisp, lisp, lisp) { return Qnil; }
lisp Fdde_request (lisp, lisp, lisp) { return Qnil; }

// Tool bar
lisp Fcreate_tool_bar (lisp, lisp, lisp) { return Qnil; }
lisp Fshow_tool_bar (lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fhide_tool_bar (lisp) { return Qnil; }
lisp Fdelete_tool_bar (lisp) { return Qnil; }
lisp Ftool_bar_exist_p (lisp) { return Qnil; }
lisp Ftool_bar_info (lisp) { return Qnil; }
lisp Flist_tool_bars () { return Qnil; }
lisp Ffocus_tool_bar () { return Qnil; }
lisp Frefresh_tool_bars () { return Qnil; }

// Tab bar
lisp Fcreate_tab_bar (lisp, lisp) { return Qnil; }
lisp Ftab_bar_add_item (lisp, lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Ftab_bar_delete_item (lisp, lisp) { return Qnil; }
lisp Ftab_bar_select_item (lisp, lisp) { return Qnil; }
lisp Ftab_bar_current_item (lisp) { return Qnil; }
lisp Ftab_bar_find_item (lisp, lisp) { return Qnil; }
lisp Ftab_bar_list_items (lisp) { return Qnil; }
lisp Ftab_bar_modify_item (lisp, lisp, lisp, lisp, lisp) { return Qnil; }

// Timer
lisp Fstart_timer (lisp, lisp, lisp) { return Qnil; }
lisp Fstop_timer (lisp) { return Qnil; }

// Listen server
lisp Fstart_xyzzy_server () { return Qnil; }
lisp Fstop_xyzzy_server () { return Qnil; }

// Function bar
lisp Fset_function_bar_label (lisp, lisp) { return Qnil; }
lisp Fnumber_of_function_bar_labels () { return make_fixnum (0); }
lisp Fset_number_of_function_bar_labels (lisp) { return Qnil; }

// Filer (all stubs)
lisp Ffiler (lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Ffiler_forward_line (lisp, lisp) { return Qnil; }
lisp Ffiler_forward_page (lisp, lisp) { return Qnil; }
lisp Ffiler_goto_bof (lisp) { return Qnil; }
lisp Ffiler_goto_eof (lisp) { return Qnil; }
lisp Ffiler_goto_file (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Ffiler_mark (lisp, lisp) { return Qnil; }
lisp Ffiler_mark_all (lisp, lisp) { return Qnil; }
lisp Ffiler_mark_match_files (lisp, lisp) { return Qnil; }
lisp Ffiler_toggle_mark (lisp, lisp) { return Qnil; }
lisp Ffiler_toggle_all_marks (lisp, lisp) { return Qnil; }
lisp Ffiler_clear_all_marks (lisp) { return Qnil; }
lisp Ffiler_count_marks (lisp, lisp) { return Qnil; }
lisp Ffiler_get_mark_files (lisp, lisp) { return Qnil; }
lisp Ffiler_get_current_file (lisp) { return Qnil; }
lisp Ffiler_current_file_directory_p (lisp) { return Qnil; }
lisp Ffiler_current_file_dot_dot_p (lisp) { return Qnil; }
lisp Ffiler_get_directory (lisp) { return Qnil; }
lisp Ffiler_set_directory (lisp, lisp) { return Qnil; }
lisp Ffiler_set_file_mask (lisp, lisp) { return Qnil; }
lisp Ffiler_get_drive (lisp) { return Qnil; }
lisp Ffiler_sort (lisp, lisp) { return Qnil; }
lisp Ffiler_get_sort_order (lisp) { return Qnil; }
lisp Ffiler_demand_reload () { return Qnil; }
lisp Ffiler_reload (lisp, lisp) { return Qnil; }
lisp Ffiler_close (lisp) { return Qnil; }
lisp Ffiler_dual_window_p () { return Qnil; }
lisp Ffiler_left_window () { return Qnil; }
lisp Ffiler_right_window () { return Qnil; }
lisp Ffiler_left_window_p () { return Qnil; }
lisp Ffiler_swap_windows () { return Qnil; }
lisp Ffiler_modal_p () { return Qnil; }
lisp Ffiler_isearch (lisp, lisp, lisp) { return Qnil; }
lisp Ffiler_viewer () { return Qnil; }
lisp Ffiler_read_char () { return Qnil; }
lisp Ffiler_get_text () { return Qnil; }
lisp Ffiler_set_text (lisp) { return Qnil; }
lisp Ffiler_calc_directory_size (lisp) { return Qnil; }
lisp Ffiler_calc_directory_byte_size (lisp) { return Qnil; }
lisp Ffiler_context_menu () { return Qnil; }
lisp Ffiler_subscribe_to_reload (lisp, lisp) { return Qnil; }
lisp Ffiler_scroll_left (lisp) { return Qnil; }
lisp Ffiler_scroll_right (lisp) { return Qnil; }
lisp Ffiler_modify_column_width (lisp, lisp, lisp) { return Qnil; }

// Archive
lisp Flist_archive (lisp, lisp) { return Qnil; }
lisp Fcreate_archive (lisp, lisp, lisp) { return Qnil; }
lisp Fextract_archive (lisp, lisp, lisp) { return Qnil; }
lisp Fdelete_file_in_archive (lisp, lisp) { return Qnil; }
lisp Fconvert_to_SFX (lisp, lisp) { return Qnil; }
lisp Farchiver_dll_version (lisp) { return Qnil; }
lisp Farchiver_dll_config_dialog (lisp, lisp) { return Qnil; }

// Shell / Shortcut
lisp Fshell_execute (lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fcreate_shortcut (lisp, lisp, lisp) { return Qnil; }
lisp Fresolve_shortcut (lisp) { return Qnil; }
lisp Feject_media (lisp) { return Qnil; }
lisp Fget_special_folder_location (lisp) { return Qnil; }
lisp Fget_file_info (lisp) { return Qnil; }

// Misc
lisp Fmain_loop () { command_loop (); return Qnil; }
lisp Fsit_for (lisp, lisp) { return Qnil; }
lisp Fsleep_for (lisp) { return Qnil; }
lisp Factivate_xyzzy_window (lisp) { return Qnil; }
lisp Fcount_xyzzy_instance () { return make_fixnum (1); }
lisp Flist_xyzzy_windows () { return Qnil; }
lisp Fnext_xyzzy_window () { return Qnil; }
lisp Fprevious_xyzzy_window () { return Qnil; }
lisp Fget_recent_keys () { return Qnil; }
lisp Fexit_recursive_edit (lisp value)
{
  nonlocal_data *nld = nonlocal_jump::data ();
  nld->type = Qexit_this_level;
  nld->value = value ? value : Qnil;
  nld->tag = Qnil;
  nld->id = Qnil;
  throw nonlocal_jump ();
  /*NOTREACHED*/
  return Qnil;
}

lisp Fquit_recursive_edit (lisp silent)
{
  nonlocal_data *nld = nonlocal_jump::data ();
  nld->type = Qexit_this_level;
  nld->value = Qnil;
  nld->tag = Qnil;
  nld->id = xsymbol_value (silent && silent != Qnil
                           ? Vierror_silent_quit
                           : Vierror_quit);
  throw nonlocal_jump ();
  /*NOTREACHED*/
  return Qnil;
}
lisp Fquit_char () { return make_char ('G' - '@'); }
lisp Fset_quit_char (lisp) { return Qnil; }
lisp Fset_cursor (lisp) { return Qnil; }
lisp Fdrag_region (lisp, lisp) { return Qnil; }
lisp Fcancel_mouse_event () { return Qnil; }
lisp Fbegin_auto_scroll () { return Qnil; }
lisp Fcreate_buffer_bar () { return Qnil; }
lisp Fstart_save_kbd_macro () { return Qnil; }
lisp Fstop_save_kbd_macro () { return Qnil; }
lisp Fkbd_macro_saving_p () { return Qnil; }
lisp Fcurrent_kbd_layout () { return Qnil; }
lisp Fselect_kbd_layout (lisp) { return Qnil; }
lisp Flist_kbd_layout () { return Qnil; }

// Network/Server resources
lisp Flist_servers (lisp) { return Qnil; }
lisp Flist_server_resources (lisp, lisp) { return Qnil; }

// WinHelp / HTML Help / Dictionary
lisp Frun_winhelp (lisp, lisp) { return Qnil; }
lisp Fkill_winhelp (lisp) { return Qnil; }
lisp Ffind_winhelp_path (lisp, lisp) { return Qnil; }
lisp Fhtml_help (lisp, lisp) { return Qnil; }
lisp Flookup_dictionary (lisp, lisp, lisp, lisp) { return Qnil; }
