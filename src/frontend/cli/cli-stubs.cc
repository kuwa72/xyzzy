// Stub implementations for Win32 frontend functions that core references.
// These provide minimal implementations so xyzzy-cli can link without
// the Win32 GUI frontend.

#include "stdafx.h"
#include "ed.h"
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
// 表示フラグの seam (src/core/fns.h)。ヘッドレスなのでどちらも何もしない。
int window_update_scroll_bars (Window *, int) { return 0; }
int window_default_flags_changed (int) { return 0; }
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
/* `XMessageBox` の空実装はもう要らない。**あのクラスは
   src/core/msgbox.h に居たので、GUI のダイアログのメソッドを端末側でも
   埋める必要があった。** src/frontend/win32/xmessagebox.h へ移した
   (issue #185)。 */

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
// conf.cc stubs
// ============================================================
//
// **read_conf / write_conf のスタブは消した。** 実装が
// src/core/conf-io.cc へ移り、INI の読み書きは src/core/ini-posix.cc が
// 持っている (issue #143)。スタブを残すと、**静的ライブラリの側が引かれず
// リンクは通るのに実装が使われない** ので、必ず消すこと。
//
// ここに残っているのはウィンドウの位置 (モニタとタスクバーを見るもの) と
// レジストリからの移行で、どちらも本当に Win32 の話。

int conf_load_geometry (HWND, const char *, const char *, int, int) { return 0; }
void conf_save_geometry (HWND, const char *, const char *, int, int) {}
void adjust_snap_window_size (HWND, WINDOWPLACEMENT &) {}
void make_geometry_key (char *buf, size_t, const char *prefix) { if (buf) *buf = 0; }
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
// (kbd_queue, key_sequence, utimer are members of Application)
// ============================================================

/* `clipboard::clipboard ()` がここにあったが、消した (issue #195 / #185)。
   **`clipboard` が `Application` のメンバだったので、端末とヘッドレスも
   コンストラクタを埋めるしかなかった。** 中身は Win32 の
   `hwnd_next_clipboard` などを 0 にするだけで、その後 1 度も読まれない。
   クラスが core から消えたのでこれも要らなくなった。 */

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

/* `utimer` の実体は src/core/utimer.cc にある (issue #50)。**スタブを残すと
   静的ライブラリの側が引かれず、待ち行列を持たない utimer が使われて
   `start-timer` が黙って何もしない。** */

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
// ツールバーのコマンド引きと GC の mark (宣言は src/core/fns.h)
// ============================================================

/* ヘッドレスなのでツールバーは無く、Lisp オブジェクトも持たない。
   **以前は `main_frame g_frame;` と `dock_frame` / `splitter` の
   コンストラクタを `#ifdef _WIN32` で置いていた** — core が `g_frame` を
   直に触っていたためである (issue #185)。 */
lisp frontend_lookup_tool_command (int) { return Qnil; }
void frontend_gc_mark (void (*)(lisp)) {}

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
/* **Windows のファイルシステムは名前の大文字小文字を区別しない。**
   `src/frontend/win32/vfs.cc` と同じ値。ここに要るのは xyzzy-cli が
   あちらを link しないため (このファイルが WINFS を埋める)。**core から
   参照されるまで定義が無いことに気付かなかった** — `path_ncmp`
   (src/core/pathname.cc) がここを聞くようになって link error で出た
   (issue #183)。 */
const int WINFS::case_insensitive_names = 1;
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

BOOL WINAPI WINFS::CopyFileMode (LPCWSTR from, LPCWSTR to)
{
  DWORD attr = ::GetFileAttributesW (from);
  return attr == INVALID_FILE_ATTRIBUTES
    ? FALSE : ::SetFileAttributesW (to, attr);
}

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


// ============================================================
// Lisp-callable frontend functions (registered in symbol table)
// These are referenced by the generated symtable.cc
// ============================================================

/* Fsi_startup は src/core/window-lisp.cc へ移した。**3 つのフロントエンドが
   同じ 1 行を持っていた** (win32 / ncurses / ここ)。 */

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

/* Fsi_load_dll_module は POSIX では src/core/dll-posix.cc が dlopen で実装する
   ので、そちらでは何も置かない (置くと静的ライブラリの解決順で core の実装が
   引かれず、CLI だけ nil を返し続ける)。

   **Win32 では話が別。** このファイルは Windows の xyzzy-cli.exe でも使われ、
   そちらは src/frontend/win32/dll.cc をリンクしないので、スタブが無いと
   未定義参照になる (実際に踏んだ)。呼び出しの側 (make-c-function /
   make-c-callable) はどちらでもまだスタブ -- issue #133。 */
#ifdef _WIN32
lisp Fsi_load_dll_module (lisp) { return Qnil; }
#endif
/* **FFI の実装は core にある。** 型の検査と `si:make-c-function' は
   src/core/dll-call.cc、実際に呼ぶ所は非 Win32 では src/core/dll-posix.cc
   (issue #133 の段階 2〜3)。**非 Win32 ではスタブを置かない** — 置くと
   静的ライブラリの側が引かれず、リンクは通るのに実装が使われない。

   **Win32 では話が逆で、ここにスタブが要る。** 実際に呼ぶ所は
   src/frontend/win32/dll.cc にあり、xyzzy-cli.exe はそれをリンクしない
   (core だけをリンクする「境界の質のテスト」なので)。前に
   `Fsi_load_dll_module` で同じことを踏んだ。 */
#ifdef _WIN32
void init_c_callable (lisp) {}
lisp funcall_dll (lisp, lisp) { return Qnil; }
lisp funcall_c_callable (lisp, lisp) { return Qnil; }
#endif

/* `si:make-c-callable` (Lisp の関数を C から呼べるアドレスにするもの) は
   非 Win32 にはまだ無い — 実行時に機械語を作る必要がある (段階 4)。 */
lisp Fsi_make_c_callable (lisp, lisp, lisp, lisp) { return Qnil; }
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

/* **タブバーが無いので「並び順を持っていない」。** 0 は nil ではなく
   「聞く相手が居ない」で、`Fget_next_buffer` と `Fbuffer_list` はこれを見て
   内部の順 (`Buffer::b_blist`) に落ちる。宣言は src/core/fns.h。

   ここは前は `#ifdef _WIN32` で囲んだ `buffer_bar::` の空実装だった。
   **クラスが core のヘッダに居たので、POSIX でも一度は書かれ、そして
   `#ifdef` に切られて死んでいた。** */
Buffer *frontend_tab_order_top_buffer () { return 0; }
Buffer *frontend_tab_order_bottom_buffer () { return 0; }
Buffer *frontend_tab_order_next_buffer (Buffer *, int) { return 0; }
lisp frontend_tab_order_buffer_list () { return 0; }
void frontend_buffer_deleted (Buffer *) {}

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

/* `FKWin::fk_default_nbuttons` の定義はもう要らない。**ラベルの数は ini に
   保存される設定値で GUI の話ではない**ので、`g_fnkey_default_nbuttons`
   (src/core/environ.h) に出した。ここに 10 を入れていたが、**端末に
   ファンクションバーは無いので ini に 10 と書く以外の効果が無かった**
   (issue #185)。 */

// ============================================================
// GlobalIME stubs
// ============================================================

#include "gime.h"

GlobalIME::GlobalIME () { gi_app = 0; gi_pump = 0; ImmGetPropertyProc = 0; }

// ============================================================
// Filer stubs
// ============================================================

/* xyzzy を終わらせる直前の後始末 (宣言は src/core/fns.h)。ヘッドレスなので
   何もしない。**`#ifdef _WIN32` の外に置く**: core が無条件に呼ぶ。 */
void frontend_before_kill_xyzzy () {}

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

/* Fsi_uuid_create は src/core/system.cc が POSIX でも実装するように
   なったので、ここのスタブを消した。 */

lisp Fsi_search_path (lisp, lisp, lisp)
{
  return Qnil;
}

/* Fsi_file_operation は src/core/pathname.cc が POSIX でも実装するように
   なったので、ここのスタブ (Eremove_not_supported を上げるだけ) を消した。 */

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

/* `make_clipboard_text` / `make_string_from_clipboard_text` の空実装がここに
   あったが、消した (issue #195 / #185)。**`CLIPBOARDTEXT` は
   `src/core/clipboard.h` に居たので POSIX でも型が見えていたが、呼ぶ側は
   `src/frontend/win32/` の中 (clipboard.cc と DnD.cc) にしか無かった。**
   誰も参照しないシンボルを 2 つ置いていただけである。 */

#endif // !_WIN32

/* ヘッドレスにウィンドウは無いので、大きさも変えられない。宣言は core の
   Window.h にあり、src/core/window-lisp.cc の Fenlarge_window から呼ばれる
   ので、実体は要る (0 = 変えられなかった)。 */
int Window::enlarge_window (int, int) { return 0; }
