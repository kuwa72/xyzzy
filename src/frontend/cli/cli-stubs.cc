// Stub implementations for Win32 frontend functions that core references.
// These provide minimal implementations so xyzzy-cli can link without
// the Win32 GUI frontend.

#include "stdafx.h"
#include "ed.h"
#include "mainframe.h"
#include "conf.h"
#include "colors.h"
#include "version.h"
#include "term.h"

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
  minibuffer_prompt_row = 0;

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
  memset (this, 0, sizeof (*this));
  os_ver.dwOSVersionInfoSize = sizeof os_ver;
  GetVersionExW (&os_ver);
  {
    GetCurrentDirectoryW (numberof (curdir), curdir);
  }
  DWORD len = numberof (host_name);
  if (!GetComputerNameW (host_name, &len))
    *host_name = 0;
  process_id = GetCurrentProcessId ();
  perf_counter_present_p = QueryPerformanceFrequency ((LARGE_INTEGER *)&perf_freq);
  windows_name = "CLI";
  windows_short_name = L"wxp";
  process_type = PROCESSTYPE_NATIVE;
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
  if (s && *s)
    fprintf (stderr, "[status] %s\n", s);
  return 1;
}
void StatusWindow::puts (const ucs4_t *, int) {}
int StatusWindow::putc (ucs4_t) { return 0; }
void StatusWindow::newline () {}
void StatusWindow::puts (const char *, int) {}
void StatusWindow::puts (int, int) {}
void StatusWindow::flush () {}
void StatusWindow::clear (int) {}
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

void main_loop () {}
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

int MsgBox (HWND, const Char *, const Char *, UINT, int) { return IDOK; }
int MsgBoxEx (HWND, const Char *, const Char *, int, int, int, int,
              const Char **, int, int, int) { return IDOK; }
void XMessageBox::add_button (UINT, const Char *) {}
void XMessageBox::set_button (int, UINT, const Char *) {}
int XMessageBox::doit (HWND) { return IDOK; }

// ============================================================
// init.cc stubs
// ============================================================

void report_out_of_memory ()
{
  fprintf (stderr, "xyzzy-cli: out of memory\n");
}

// ============================================================
// minibuf.cc stubs
// ============================================================

lisp load_default (lisp, int) { return Qnil; }
lisp load_history (lisp, int) { return Qnil; }
lisp load_history (lisp, int, lisp) { return Qnil; }
lisp load_title (lisp, int) { return Qnil; }
lisp read_minibuffer (const ucs4_t *, long, lisp, lisp, lisp, lisp, int, int, int, lisp, int) { return Qnil; }
lisp complete_read (const ucs4_t *, long, lisp, lisp, lisp, lisp, int, int) { return Qnil; }
lisp read_filename (const ucs4_t *, long, lisp, lisp, lisp, lisp) { return Qnil; }
lisp minibuffer_read_integer (const ucs4_t *, long) { return Qnil; }

// ============================================================
// process.cc stubs
// ============================================================

void read_process_output (WPARAM, LPARAM) {}
void wait_process_terminate (WPARAM, LPARAM) {}
int buffer_has_process (const Buffer *) { return 0; }
Terminal *buffer_terminal (const Buffer *) { return 0; }
int buffer_terminal_send (const Buffer *, const char *, int) { return 0; }
void buffer_terminal_resize (const Buffer *, int, int) {}
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
// assert.cc stubs
// ============================================================

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
lisp dock_frame::lookup_command (int) const { return Qnil; }

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
// Straight passthrough to the Win32 W APIs; no UNC share handling. Paths are
// already UTF-16 by the time they get here, so there is nothing to convert.
//
// Windows only.  Off Windows those ::-qualified names are the always-fail
// stubs in src/core/platform.h, so this passthrough gave the CLI frontend a
// filesystem that could not open, list, copy or delete anything -- and said
// nothing about it, since every call simply returned "failed".  The POSIX
// implementation is src/core/vfs-posix.cc, which core links instead.
// ============================================================
#ifdef _WIN32

wchar_t WINFS::wfs_share_cache[MAX_PATH * 2];
const WINFS::GETDISKFREESPACEEX WINFS::GetDiskFreeSpaceEx =
  (WINFS::GETDISKFREESPACEEX)GetProcAddress (GetModuleHandleW (L"kernel32"), "GetDiskFreeSpaceExW");

BOOL WINAPI WINFS::CreateDirectory (LPCWSTR p, LPSECURITY_ATTRIBUTES a)
{ return ::CreateDirectoryW (p, a); }

HANDLE WINAPI WINFS::CreateFile (LPCWSTR p, DWORD a, DWORD s,
  LPSECURITY_ATTRIBUTES sa, DWORD cd, DWORD f, HANDLE t)
{ return ::CreateFileW (p, a, s, sa, cd, f, t); }

BOOL WINAPI WINFS::DeleteFile (LPCWSTR p)
{ return ::DeleteFileW (p); }

HANDLE WINAPI WINFS::FindFirstFile (LPCWSTR p, LPWIN32_FIND_DATAW d)
{ return ::FindFirstFileW (p, d); }

BOOL WINAPI WINFS::FindNextFile (HANDLE h, LPWIN32_FIND_DATAW d)
{ return ::FindNextFileW (h, d); }

BOOL WINAPI WINFS::GetDiskFreeSpace (LPCWSTR p, LPDWORD a, LPDWORD b, LPDWORD c, LPDWORD d)
{ return ::GetDiskFreeSpaceW (p, a, b, c, d); }

DWORD WINAPI WINFS::internal_GetFileAttributes (LPCWSTR p)
{ return ::GetFileAttributesW (p); }

DWORD WINAPI WINFS::GetFileAttributes (LPCWSTR p)
{ return ::GetFileAttributesW (p); }

UINT WINAPI WINFS::GetTempFileName (LPCWSTR p, LPCWSTR x, UINT u, LPWSTR b)
{ return ::GetTempFileNameW (p, x, u, b); }

BOOL WINAPI WINFS::GetVolumeInformation (LPCWSTR p, LPWSTR vn, DWORD vs, LPDWORD sn,
  LPDWORD mcl, LPDWORD fsf, LPWSTR fsn, DWORD fss)
{ return ::GetVolumeInformationW (p, vn, vs, sn, mcl, fsf, fsn, fss); }

HMODULE WINAPI WINFS::LoadLibrary (LPCWSTR p)
{ return ::LoadLibraryW (p); }

BOOL WINAPI WINFS::MoveFile (LPCWSTR a, LPCWSTR b)
{ return ::MoveFileW (a, b); }

BOOL WINAPI WINFS::RemoveDirectory (LPCWSTR p)
{ return ::RemoveDirectoryW (p); }

BOOL WINAPI WINFS::SetFileAttributes (LPCWSTR p, DWORD a)
{ return ::SetFileAttributesW (p, a); }

DWORD WINAPI WINFS::internal_GetFullPathName (LPCWSTR p, DWORD n, LPWSTR b, LPWSTR *f)
{ return ::GetFullPathNameW (p, n, b, f); }

BOOL WINAPI WINFS::SetCurrentDirectory (LPCWSTR p)
{ return ::SetCurrentDirectoryW (p); }

DWORD WINAPI WINFS::GetFullPathName (LPCWSTR p, DWORD n, LPWSTR b, LPWSTR *f)
{ return internal_GetFullPathName (p, n, b, f); }

DWORD WINAPI WINFS::WNetOpenEnum (DWORD s, DWORD t, DWORD u, LPNETRESOURCEW r, LPHANDLE h)
{ return ::WNetOpenEnumW (s, t, u, r, h); }

int WINAPI WINFS::get_file_data (const wchar_t *path, WIN32_FIND_DATAW &fd)
{
  HANDLE h = FindFirstFile (path, &fd);
  if (h == INVALID_HANDLE_VALUE)
    return 0;
  ::FindClose (h);
  return 1;
}

#endif // _WIN32

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
lisp Fsi_load_ts_grammar (lisp, lisp) { return Qnil; }
lisp Fsi_ts_query_buffer (lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fsi_ts_grammar_p (lisp) { return Qnil; }
lisp Fsi_ts_free_buffer_cache (lisp) { return Qnil; }
lisp Fsi_ts_buffer_cached_p (lisp) { return Qnil; }
lisp Fsi_ts_parse_complete_p (lisp) { return Qt; }
lisp Fsi_ts_query_pending_p (lisp) { return Qnil; }
lisp Fsi_ts_apply_highlights (lisp, lisp, lisp, lisp, lisp, lisp, lisp) { return Qnil; }
lisp Fsi_ts_node_ancestors (lisp, lisp, lisp) { return Qnil; }
lisp Fsi_ts_query_buffer_sync (lisp, lisp, lisp) { return Qnil; }

// ============================================================
// Window.cc / pane.cc / doc.cc stubs (sys_fns[] references)
// ============================================================

lisp Fsi_instance_number () { return make_fixnum (0); }
lisp Fsi_plugin_arg () { return Qnil; }
lisp Fsi_snarf_documentation (lisp, lisp) { return Qnil; }

/* plist に入っている分は返す。理由は
   src/frontend/ncurses/ncurses-stubs.cc の同じ関数の説明を参照 (issue #105)。 */
lisp
Fsi_get_documentation_string (lisp symbol, lisp indicator, lisp apropos, lisp)
{
  lisp doc = Fget (symbol, indicator, Qnil);
  if (!stringp (doc))
    return Qnil;
  if (apropos == Qnil)
    return doc;
  const ucs4_t *p = xstring_contents (doc);
  const ucs4_t *p0 = p;
  for (const ucs4_t *pe = p + xstring_length (doc); p < pe && *p != '\n'; p++)
    ;
  return make_string (p0, p - p0);
}

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
// Window.cc stubs (Window statics + WindowConfiguration)
// ============================================================

#include "Window.h"

XCOLORREF Window::default_xcolors[USER_DEFINABLE_COLORS];
int Window::w_default_flags = 0;
int Window::w_hjump_columns = 4;
void Window::change_color () {}
void Window::modify_all_mode_line () {}
void Window::set_buffer (Buffer *) {}

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

const Char *const buffer_info::b_eol_name[] = {nullptr, nullptr, nullptr};

Char *buffer_info::format (lisp, Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::modified (Char *b, int) const { *b = 0; return b; }
Char *buffer_info::read_only (Char *b, int) const { *b = 0; return b; }
Char *buffer_info::progname (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::version (Char *b, Char *, int) const { *b = 0; return b; }
Char *buffer_info::buffer_name (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::file_name (Char *b, Char *, int) const { *b = 0; return b; }
Char *buffer_info::file_or_buffer_name (Char *b, Char *, int) const { *b = 0; return b; }
Char *buffer_info::mode_name (Char *b, Char *, int) const { *b = 0; return b; }
Char *buffer_info::encoding (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::eol_code (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::ime_mode (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::position (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::host_name (Char *b, Char *, int) const { *b = 0; return b; }
Char *buffer_info::process_id (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::admin_user (Char *b, Char *) const { *b = 0; return b; }
Char *buffer_info::percent (Char *b, Char *) const { *b = 0; return b; }

// ============================================================
// Keyboard/Input stubs
// ============================================================

void check_kbd_enable () {}
lChar kbd_queue::fetch (int, int) { return lChar_EOF; }
lChar kbd_queue::peek (int) { return lChar_EOF; }
int kbd_queue::listen () { return 0; }
void kbd_queue::clear () {}
void kbd_queue::close_ime () {}
void kbd_queue::restore_ime () {}
int kbd_queue::lookup_kbd_macro (lisp) const { return 0; }
int kbd_queue::toggle_ime (int, int) { return 0; }

void key_sequence::push (Char, int) {}
void key_sequence::done (Char, int) {}

// ============================================================
// Display stubs (called by core/cmdloop.cc)
// ============================================================

void refresh_screen (int) {}
void pending_refresh_screen () {}
Window *Window::minibuffer_window () { return 0; }

/* **ヘッドレスにはウィンドウが無いが、メソッドは在る必要がある。**
   ウィンドウを触る Lisp 関数は src/core/window-lisp.cc に移った。そこから
   `Window' のメソッドを呼ぶので、CLI もこれらを持っていないとリンクできない
   (それまでは `Fget_buffer_window' のスタブ 1 個で足りていた)。

   **スタブを置く代わりにあちらへスタブを置き直してはいけない。** 静的
   ライブラリの解決順で core の実装が引かれなくなり、**CLI だけが nil を
   返し続けるのにリンクは通る**ので気付けない。境界は「画面を持っているのは
   フロントエンド」に保ったまま、無いものは無いと答える。 */
void Window::split (int, int) {}
int Window::delete_window () { return 0; }
void Window::delete_other_windows () {}
void Window::set_window () {}

// ============================================================
// Wait cursor / Process / Buffer stubs
// ============================================================

lisp Fbegin_wait_cursor () { return Qnil; }
lisp Fend_wait_cursor () { return Qnil; }
/* Fget_buffer_window は src/core/window-lisp.cc が持つようになったので、
   ここのスタブを消した。**残しておくと静的ライブラリの解決順で
   core の実装が引かれず、CLI だけ nil を返し続ける** (リンクは通るので
   気付けない)。 */
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

// FindClose now comes from src/core/vfs-posix.cc, together with the
// FindFirstFile that hands out the handle it has to release.  It was a
// "return TRUE" here for as long as those handles were always invalid.

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
