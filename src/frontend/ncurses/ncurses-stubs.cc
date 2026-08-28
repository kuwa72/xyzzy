// Stub implementations for Win32 frontend functions that core references.
// ncurses frontend: starts as cli-stubs.cc copy, functions will be
// replaced with real implementations as phases progress.

#include <string>
#include <vector>
#include "stdafx.h"
#include "ed.h"
#include "mainframe.h"
#include "conf.h"
#include "colors.h"
#include "version.h"
#include "term.h"
#include "minibuffer-message.h"

// ============================================================
// Global objects (normally defined in init.cc and sysdep.cc)
// ============================================================

Application app;
char enable_quit::q_enable;
Frontend *g_frontend;

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
  windows_name = "ncurses";
  windows_short_name = L"ncurses";
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
StatusWindow::puts (const ucs4_t *b, int size)
{
  for (const ucs4_t *be = b + size; b < be; b++)
    putc (*b);
}

int
StatusWindow::putc (ucs4_t c)
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
        *sw_b++ = ucs2_t (c);
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

int MsgBox (HWND, const Char *msg, const Char *title, UINT style, int)
{
  if (g_frontend)
    return g_frontend->message_box (style, msg, title);
  // Fallback before frontend is initialized
  if ((style & 0x0f) == MB_YESNO)
    return IDYES;
  return IDOK;
}
int MsgBoxEx (HWND hw, const Char *msg, const Char *title, int type, int def, int icon, int beep,
              const Char **, int, int, int)
{
  // Reconstruct MB_* style from decomposed parameters
  UINT style = (UINT)(type & 0x0f);
  return MsgBox (hw, msg, title, style, beep);
}
void XMessageBox::add_button (UINT, const Char *) {}
void XMessageBox::set_button (int, UINT, const Char *) {}
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
  ucs4_t w[32];
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
count_prompt_columns (const ucs4_t *s, int l)
{
  int n = 0;
  for (const ucs4_t *se = s + l; s < se; s++)
    n += char_width (*s);
  return n;
}

void command_loop ();
lisp Fsi_throw_error (lisp);

lisp
read_minibuffer (const ucs4_t *prompt, long prompt_length, lisp def,
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
  Buffer *prev_mini_bufp = mini->w_bufp;
  mini->set_buffer_params (bp);
  mini->set_window ();
  mini->w_flags = 0;
  minibuffer_recursive_level++;

  // Insert default value if provided
  // noselect: insert text, cursor stays at end (user types filename after directory)
  // !noselect: insert text, select it (cursor at start, selection to end)
  if (stringp (def))
    {
      // insert_chars_internal takes UTF-16 Char*; expand the ucs4 default
      // (surrogate pairs for non-BMP), mirroring win32 minibuf insert_default.
      int deflen = xstring_length (def);
      const ucs4_t *defuc = xstring_contents (def);
      Char *defc = (Char *)alloca (deflen * 2 * sizeof (Char));
      Char *dp = defc;
      for (int i = 0; i < deflen; i++)
        {
          ucs4_t cp = defuc[i];
          if (cp < 0x10000)
            *dp++ = Char (cp);
          else
            {
              cp -= 0x10000;
              *dp++ = Char (0xD800 + (cp >> 10));
              *dp++ = Char (0xDC00 + (cp & 0x3FF));
            }
        }
      bp->insert_chars_internal (mini->w_point, defc, dp - defc, 1);
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

  // Restore previous window and minibuffer state
  // Win32 uses WindowConfiguration destructor which restores w_bufp;
  // here we restore it manually so next-window skips the minibuffer.
  wp->set_window ();
  mini->w_bufp = prev_mini_bufp;

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
complete_read (const ucs4_t *prompt, long prompt_length, lisp def,
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
read_filename (const ucs4_t *prompt, long prompt_length, lisp type,
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
minibuffer_read_integer (const ucs4_t *prompt, long prompt_length)
{
  lisp string = read_minibuffer (prompt, prompt_length, Qnil, Kinteger, Qnil, Kinteger,
                                 0, 0, 0, Qnil, -1);
  int l = xstring_length (string);
  return parse_integer (string, 0, l, 10, 1);
}

// process.cc: implemented in ncurses-process.cc

// ============================================================
// menu.cc — ncurses TUI menu implementation
// ============================================================

#define xwin32_menu_items xwin32_menu_command

#ifndef MF_GRAYED
#define MF_GRAYED    0x0001
#define MF_ENABLED   0x0000
#define MF_CHECKED   0x0008
#define MF_UNCHECKED 0x0000
#endif

static u_long used_id[(MENU_ID_RANGE_MAX - MENU_ID_RANGE_MIN) / (sizeof (u_long) * 8)];

static lwin32_menu *
make_win32_menu ()
{
  lwin32_menu *p = ldata <lwin32_menu, Twin32_menu>::lalloc ();
  p->handle = 0;
  p->id = 0;
  p->init = Qnil;
  p->command = Qnil;
  p->tag = Qnil;
  p->name = Qnil;
  return p;
}

void
check_popup_menu (lisp lmenu)
{
  check_win32_menu (lmenu);
  if (!xwin32_menu_handle (lmenu))
    {
      if (!xwin32_menu_id (lmenu))
        FEprogram_error (Euninitialized_menu_item);
      FEprogram_error (Eis_not_popup_menu);
    }
}

static lisp
create_new_item (int &id, lisp tag, lisp command, lisp init)
{
  bitset (used_id, 0);
  id = find_zero_bit (used_id, numberof (used_id));
  if (id < 0)
    {
      gc (1);
      id = find_zero_bit (used_id, numberof (used_id));
      if (id < 0)
        FEprogram_error (Etoo_many_menu_items);
    }
  id += MENU_ID_RANGE_MIN;

  lisp litem = make_win32_menu ();
  xwin32_menu_id (litem) = id;
  xwin32_menu_tag (litem) = tag;
  xwin32_menu_command (litem) = command ? command : Qnil;
  xwin32_menu_init (litem) = init ? init : Qnil;
  return litem;
}

int
init_menu_flags (lisp item)
{
  Window *wp = selected_window ();
  Buffer *bp = wp->w_bufp;
  if (!bp)
    return MF_GRAYED | MF_UNCHECKED;
  if (symbolp (item))
    {
#define MF(X) ((X) ? MF_UNCHECKED | MF_ENABLED : MF_UNCHECKED | MF_GRAYED)
      if (item == Kmodified)
        return MF (bp->b_modified);
      if (item == Kundo)
        return MF (bp->b_undo && !bp->read_only_p ());
      if (item == Kredo)
        return MF (bp->b_redo && !bp->read_only_p ());
#define SELECTIONP(X) \
  ((wp->w_selection_type & Buffer::SELECTION_TYPE_MASK) == Buffer::X)
      if (item == Kany_selection)
        return MF (wp->w_selection_type != Buffer::SELECTION_VOID);
      if (item == Kmodify_any_selection)
        return MF (wp->w_selection_type != Buffer::SELECTION_VOID
                   && !bp->read_only_p ());
      if (item == Kselection)
        return MF (wp->w_selection_type != Buffer::SELECTION_VOID
                   && !SELECTIONP (SELECTION_RECTANGLE));
      if (item == Kmodify_selection)
        return MF (wp->w_selection_type != Buffer::SELECTION_VOID
                   && !SELECTIONP (SELECTION_RECTANGLE)
                   && !bp->read_only_p ());
      if (item == Krectangle)
        return MF (SELECTIONP (SELECTION_RECTANGLE));
      if (item == Kmodify_rectangle)
        return MF (SELECTIONP (SELECTION_RECTANGLE)
                   && !bp->read_only_p ());
      if (item == Kclipboard)
        return MF (!bp->read_only_p ()
                   && Fclipboard_empty_p () == Qnil);
#undef MF
#undef SELECTIONP
    }

  if (item != Qnil)
    {
      lisp result = Qnil;
      try
        {
          result = Ffuncall (item, Qnil);
        }
      catch (nonlocal_jump &)
        {
        }

      int check = 0, gray = 0;
      multiple_value::value (0) = result;
      for (int i = 0; i < multiple_value::count (); i++)
        {
          if (multiple_value::value (i) == Kcheck)
            check = 1;
          if (multiple_value::value (i) == Kdisable)
            gray = 1;
        }

      return ((check ? MF_CHECKED : MF_UNCHECKED)
              | (gray ? MF_GRAYED : MF_ENABLED));
    }

  return MF_ENABLED | MF_UNCHECKED;
}

static int
init_menu_popup_recursive (lisp lmenu, int enablep)
{
  int f = 0;
  for (lisp p = xwin32_menu_items (lmenu); consp (p); p = xcdr (p))
    {
      int flags;
      lisp item = xcar (p);
      if (!xwin32_menu_id (item))
        {
          if (!xwin32_menu_handle (item))
            continue;
          if (init_menu_popup_recursive (item, enablep))
            flags = MF_ENABLED | MF_UNCHECKED;
          else
            flags = MF_GRAYED | MF_UNCHECKED;
        }
      else
        {
          if (xwin32_menu_init (item) == Kend_macro)
            flags = (app.kbdq.save_p ()
                     ? MF_ENABLED | MF_UNCHECKED
                     : MF_GRAYED | MF_UNCHECKED);
          else if (enablep)
            {
              if (xwin32_menu_init (item) != Qnil)
                flags = init_menu_flags (xwin32_menu_init (item));
              else if (xwin32_menu_command (item) == Qnil)
                flags = MF_GRAYED | MF_UNCHECKED;
              else
                flags = MF_ENABLED | MF_UNCHECKED;
            }
          else
            flags = MF_GRAYED | MF_UNCHECKED;
        }
      // Store flags temporarily in id's high bits for rendering
      // Actually, we just store in the init_menu_flags result — the TUI
      // renderer will call init_menu_flags() directly per item.
      if ((flags & (MF_ENABLED | MF_GRAYED)) == MF_ENABLED)
        f = 1;
    }
  return f;
}

void init_menu_popup (WPARAM, LPARAM) {}

static lisp
lookup_menu_command_recursive (lisp lmenu, int id)
{
  for (lisp p = xwin32_menu_items (lmenu); consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (xwin32_menu_id (x) == id)
        return xwin32_menu_command (x);
      if (xwin32_menu_handle (x))
        {
          x = lookup_menu_command_recursive (x, id);
          if (x)
            return x;
        }
    }
  return 0;
}

lisp
lookup_menu_command (int id)
{
  if (id)
    {
      if (win32_menu_p (xsymbol_value (Vtracking_menu)))
        {
          lisp x = lookup_menu_command_recursive (xsymbol_value (Vtracking_menu), id);
          if (x)
            return x;
        }
      if (win32_menu_p (xsymbol_value (Vlast_active_menu)))
        {
          lisp x = lookup_menu_command_recursive (xsymbol_value (Vlast_active_menu), id);
          if (x)
            return x;
        }
    }
  return Qnil;
}

static int
find_tag_position (lisp &lmenu, lisp tag)
{
  for (lisp p = xwin32_menu_items (lmenu); consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (xwin32_menu_tag (x) == tag)
        return xlist_length (xcdr (p));
      if (xwin32_menu_handle (x))
        {
          int pos = find_tag_position (x, tag);
          if (pos >= 0)
            {
              lmenu = x;
              return pos;
            }
        }
    }
  return -1;
}

static lisp
get_menu (lisp lmenu, lisp tag, lisp positionp, int &pos)
{
  check_popup_menu (lmenu);
  if (positionp && positionp != Qnil)
    {
      pos = fixnum_value (tag);
      if (pos < 0)
        FErange_error (tag);
    }
  else
    {
      pos = find_tag_position (lmenu, tag);
      if (pos < 0)
        return Qnil;
    }

  int l = xlist_length (xwin32_menu_items (lmenu));
  if (pos >= l)
    return Qnil;

  l -= pos + 1;
  return Fnth (make_fixnum (l), xwin32_menu_items (lmenu));
}

lisp
track_popup_menu (lisp, lisp, const POINT *) { return Qnil; }

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
// popup.cc — ncurses popup (erase_popup, Fpopup_string etc. defined
// below, after #include <ncurses.h>)
// ============================================================

// Forward declarations — defined after ncurses.h is included
void erase_popup (int, int);
void check_popup_timeout ();

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
  if (id > MENU_ID_RANGE_MIN && id < MENU_ID_RANGE_MAX)
    bitclr (used_id, id - MENU_ID_RANGE_MIN);
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
// vfs.cc (WINFS static methods used by core)
// The POSIX implementation moved to src/core/vfs-posix.cc: it is not
// specific to this frontend, and leaving it here left xyzzy-cli with a
// filesystem that could not open a file.
// ============================================================

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

/* **空実装だった。** そのため端末では `minibuffer-message' もプロンプトも
   何も出さず、`message' の出力先をエコー領域へ回した時点で (issue #97)
   メッセージが 1 つも見えなくなった。Win32 の Fsi_minibuffer_message
   (src/frontend/win32/toplev.cc) と同じことをする。 */
lisp
Fsi_minibuffer_message (lisp message, lisp prompt)
{
  app.minibuffer_prompt_column = -1;
  app.minibuffer_prompt_row = 0;
  if (message == Qnil)
    xsymbol_value (Vminibuffer_message) = Qnil;
  else
    {
      check_string (message);
      xsymbol_value (Vminibuffer_message) = message;
      xsymbol_value (Vminibuffer_prompt) = boole (prompt && prompt != Qnil);
    }
  Window *mini = Window::minibuffer_window ();
  if (mini)
    mini->w_disp_flags |= Window::WDF_WINDOW;
  if (!app.kbdq.macro_is_running ())
    refresh_screen (0);
  return Qt;
}

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

/* **plist に入っている分は返す。** 常に nil を返していたので、
   `(documentation 'foo 'function)` が nil になっていた -- docstring は
   `lisp::function-documentation` に文字列で入っているのに、それを見る唯一の
   経路がここだった (issue #105)。`M-x describe-function` も同じ。

   Win32 側 (src/frontend/win32/doc.cc) はこの後にもう 1 段あり、property が
   文字列でなく整数なら etc/DOC の中のオフセットとして mmap で読む。**ここに
   その段は無くてよい:** DOC を書くのは Fsi_snarf_documentation で、それが
   POSIX では空実装なので、property が整数になることがない。同じ理由で
   src/frontend/cli/cli-stubs.cc にも同じものが入っている。 */
lisp
Fsi_get_documentation_string (lisp symbol, lisp indicator, lisp apropos, lisp)
{
  lisp doc = Fget (symbol, indicator, Qnil);
  if (!stringp (doc))
    return Qnil;
  if (apropos == Qnil)
    return doc;
  /* apropos は 1 行目だけ。 */
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
// Window.cc — ncurses implementations
// ============================================================

#include "Window.h"
#include "charset.h"
#include "painter.h"        // issue #13 step4: NcursesPainter
#include "font-metrics.h"   // issue #13 step5: NcursesFontMetrics
#include <ncurses.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

// BUTTON5_PRESSED (mouse wheel down) is only defined when ncurses is built
// with NCURSES_MOUSE_VERSION >= 2; the wheel-down case is a no-op without it.
#ifndef BUTTON5_PRESSED
# define BUTTON5_PRESSED 0
#endif

// ---- popup_string state ----
static WINDOW *g_popup_win;          // ncurses overlay window (null = hidden)
static int g_popup_timeout_ms;       // timeout in ms, -1 = infinite
static struct timeval g_popup_start; // display start time
static int g_popup_continue;         // set by Fcontinue_popup

void refresh_screen (int);

static void
do_erase_popup ()
{
  if (g_popup_win)
    {
      delwin (g_popup_win);
      g_popup_win = 0;
      touchwin (stdscr);
      refresh_screen (1);
    }
}

void
erase_popup (int force, int)
{
  if ((force || !g_popup_continue) && g_popup_win)
    do_erase_popup ();
  g_popup_continue = 0;
}

void
check_popup_timeout ()
{
  if (!g_popup_win || g_popup_timeout_ms <= 0)
    return;
  struct timeval now;
  gettimeofday (&now, 0);
  long elapsed = (now.tv_sec - g_popup_start.tv_sec) * 1000
                 + (now.tv_usec - g_popup_start.tv_usec) / 1000;
  if (elapsed >= g_popup_timeout_ms)
    do_erase_popup ();
}

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

  memset (&w_point, 0, sizeof w_point);
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
  memset (&w_rect, 0, sizeof w_rect);
  memset (&w_order, 0, sizeof w_order);
  memset (w_last_vars, 0, sizeof w_last_vars);
  memset (&w_clsize, 0, sizeof w_clsize);
  memset (&w_ech, 0, sizeof w_ech);
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
  memset (&w_vsinfo, 0, sizeof w_vsinfo);
  memset (&w_hsinfo, 0, sizeof w_hsinfo);
  memset (&w_ch_max, 0, sizeof w_ch_max);
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
  memset (&w_rect, 0, sizeof w_rect);
  memset (&w_order, 0, sizeof w_order);
  memset (w_last_vars, 0, sizeof w_last_vars);
  memset (&w_clsize, 0, sizeof w_clsize);
  memset (&w_ech, 0, sizeof w_ech);
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
  memset (&w_vsinfo, 0, sizeof w_vsinfo);
  memset (&w_hsinfo, 0, sizeof w_hsinfo);
  memset (&w_ch_max, 0, sizeof w_ch_max);
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
  /* フォーカス報告 (DECSET 1004)。tmux 等のマルチプレクサが別ペインに
     切り替えたときと同じで、選択ウィンドウから外れる側/入る側の
     ターミナルバッファへ ESC[O / ESC[I を送る。要求していないアプリには
     terminal_focus_to_bytes が 0 を返すので何もしない。 */
  extern Terminal *buffer_terminal (const Buffer *bp);
  extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
  Window *prev = app.active_frame.selected;
  if (prev != this)
    {
      if (prev && prev->w_bufp)
        {
          Terminal *pt = buffer_terminal (prev->w_bufp);
          char b[8];
          int l = terminal_focus_to_bytes (pt, 0, b, sizeof b);
          if (l > 0)
            buffer_terminal_send (prev->w_bufp, b, l);
        }
      if (w_bufp)
        {
          Terminal *nt = buffer_terminal (w_bufp);
          char b[8];
          int l = terminal_focus_to_bytes (nt, 1, b, sizeof b);
          if (l > 0)
            buffer_terminal_send (w_bufp, b, l);
        }
    }

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

/* WindowConfiguration とその lisp 入口は src/core/window-config.cc に移した
   (issue #82)。ここに空の実装を置いていたため、端末では
   save-window-excursion が何も戻さず、current-window-configuration は nil を
   返していた。 */

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

/* Phase 2 (issue #13 / UTF-16): mode line は Char * (UTF-16 code unit 列) で
   組み立てる。core の binfo.h が char* → Char* に切り替わったため、win32 の
   src/frontend/win32/binfo.cc と同じ Char* 実装に揃える。ime_mode のみ
   ncurses 固有 (端末任せで常に "--")。 */

/* Char は uint16_t なので、L"..." を (const Char *) にキャストしてはいけない。
   Windows の wchar_t は 2 バイトなので偶然一致するが、Linux では 4 バイトで、
   'l' が 6C 00 00 00 と並ぶ。これを 16 bit で読むと 006C 0000 になり、2 文字目が
   NUL になって "lf" が "l" に化ける (モード行の %l が実際にそうなっていた)。
   要素を明示した Char 配列で持つ。 */
static const Char eol_name_lf[] = {'l', 'f', 0};
static const Char eol_name_crlf[] = {'c', 'r', 'l', 'f', 0};
static const Char eol_name_cr[] = {'c', 'r', 0};

const Char *const buffer_info::b_eol_name[] =
  {eol_name_lf, eol_name_crlf, eol_name_cr};

static Char *
stwncpy (Char *b, Char *be, const char *s, size_t max)
{
  size_t i;
  for (i = 0; i < max && s[i] && b < be; i++)
    *b++ = (Char)(u_char)s[i];
  return b;
}

static Char *
stwncpy (Char *b, Char *be, const wchar_t *s, size_t max)
{
  size_t i;
  for (i = 0; i < max && s[i] && b < be; i++)
    *b++ = (Char)s[i];
  return b;
}

static Char *
copy_lisp_string (Char *b, Char *be, lisp str)
{
  /* ucs4 → UTF-16 で Char buffer に詰める (surrogate pair も発出)。 */
  int nstr = xstring_length (str);
  const ucs4_t *p = xstring_contents (str);
  ucs2_t *out = (ucs2_t *)b;
  ucs2_t *out_end = (ucs2_t *)be;
  for (int i = 0; i < nstr && out < out_end; i++)
    {
      ucs4_t cp = p[i];
      if (cp < 0x10000)
        *out++ = ucs2_t (cp);
      else if (out + 1 < out_end)
        {
          cp -= 0x10000;
          *out++ = ucs2_t (0xD800 + (cp >> 10));
          *out++ = ucs2_t (0xDC00 + (cp & 0x3FF));
        }
      else
        break;
    }
  return (Char *)out;
}

Char *
buffer_info::modified (Char *b, int pound) const
{
  if (!pound)
    {
      Char c1 = '-', c2 = '-';
      if (b_bufp->b_modified)
        c1 = c2 = '*';
      if (b_bufp->read_only_p ())
        {
          c1 = '%';
          if (c2 == '-')
            c2 = c1;
        }
      if (b_bufp->b_truncated)
        c2 = '#';
      *b++ = c1;
      *b++ = c2;
    }
  else
    *b++ = b_bufp->b_modified ? '*' : ' ';
  return b;
}

Char *
buffer_info::read_only (Char *b, int pound) const
{
  if (b_bufp->read_only_p ())
    *b++ = '%';
  else if (!pound && b_bufp->b_truncated)
    *b++ = '#';
  else
    *b++ = ' ';
  return b;
}

Char *
buffer_info::buffer_name (Char *b, Char *be) const
{
  b = b_bufp->buffer_name (b, be);
  if (b == be - 1)
    *b++ = ' ';
  return b;
}

Char *
buffer_info::file_name (Char *b, Char *be, int pound) const
{
  lisp name;
  if (stringp (name = b_bufp->lfile_name)
      || stringp (name = b_bufp->lalternate_file_name))
    {
      if (!pound)
        b = stwncpy (b, be, "File: ", 6);
      b = copy_lisp_string (b, be, name);
      if (b == be - 1)
        *b++ = ' ';
    }
  return b;
}

Char *
buffer_info::file_or_buffer_name (Char *b, Char *be, int pound) const
{
  Char *bb = b;
  b = file_name (b, be, pound);
  if (b == bb)
    b = buffer_name (b, be);
  return b;
}

static Char *
docopy (Char *d, Char *de, const char *s, int &f)
{
  if (d < de) *d++ = f ? ' ' : ':';
  f = 1;
  return stwncpy (d, de, s, strlen (s));
}

Char *
buffer_info::minor_mode (lisp x, Char *b, Char *be, int &f) const
{
  for (int i = 0; i < 10; i++)
    if (consp (x) && symbolp (xcar (x))
        && symbol_value (xcar (x), b_bufp) != Qnil)
      {
        x = xcdr (x);
        if (symbolp (x))
          {
            x = symbol_value (x, b_bufp);
            if (!stringp (x))
              break;
          }
        if (stringp (x))
          {
            if (b < be) *b++ = f ? ' ' : ':';
            f = 1;
            return copy_lisp_string (b, be, x);
          }
      }
    else
      break;
  return b;
}

Char *
buffer_info::mode_name (Char *b, Char *be, int c) const
{
  int f = 0;
  lisp mode = symbol_value (Vmode_name, b_bufp);
  if (stringp (mode))
    b = copy_lisp_string (b, be, mode);

  if (c == 'M')
    {
      if (b_bufp->b_narrow_depth)
        b = docopy (b, be, "Narrow", f);
      if (Fkbd_macro_saving_p () != Qnil)
        b = docopy (b, be, "Def", f);
      for (lisp al = xsymbol_value (Vminor_mode_alist);
           consp (al); al = xcdr (al))
        b = minor_mode (xcar (al), b, be, f);
    }

  if (processp (b_bufp->lprocess))
    switch (xprocess_status (b_bufp->lprocess))
      {
      case PS_RUN:
        b = stwncpy (b, be, ":Run", 4);
        break;

      case PS_EXIT:
        b = stwncpy (b, be, ":Exit", 5);
        break;
      }
  return b;
}

Char *
buffer_info::progname (Char *b, Char *be) const
{
  return stwncpy (b, be, ProgramName, strlen (ProgramName));
}

Char *
buffer_info::encoding (Char *b, Char *be) const
{
  return copy_lisp_string (b, be, xchar_encoding_name (b_bufp->lchar_encoding));
}

Char *
buffer_info::eol_code (Char *b, Char *be) const
{
  const Char *s = b_eol_name[b_bufp->b_eol_code];
  while (*s && b < be)
    *b++ = *s++;
  return b;
}

Char *
buffer_info::ime_mode (Char *b, Char *be) const
{
  // ncurses: IME is handled by the terminal, always show "--"
  if (!b_ime)
    return b;
  *b_ime = 1;
  if (b < be) *b++ = '-';
  if (b < be) *b++ = '-';
  return b;
}

Char *
buffer_info::position (Char *b, Char *be) const
{
  if (b_posp)
    *b_posp = b;
  else if (b_wp)
    {
      char tem[64];
      int tl = snprintf (tem, sizeof tem, "%d:%d", b_wp->w_plinenum, b_wp->w_column);
      b = stwncpy (b, be, tem, tl);
    }
  return b;
}

Char *
buffer_info::version (Char *b, Char *be, int pound) const
{
  const char *s = pound ? DisplayVersionString : VersionString;
  return stwncpy (b, be, s, strlen (s));
}

Char *
buffer_info::host_name (Char *b, Char *be, int pound) const
{
  if (*sysdep.host_name)
    {
      if (pound && b < be)
        *b++ = '@';
      b = stwncpy (b, be, sysdep.host_name, wcslen (sysdep.host_name));
    }
  return b;
}

Char *
buffer_info::process_id (Char *b, Char *be) const
{
  char tem[64];
  int tl = snprintf (tem, sizeof tem, "%d", sysdep.process_id);
  return stwncpy (b, be, tem, tl);
}

Char *
buffer_info::admin_user (Char *b, Char *be) const
{
  if (Fadmin_user_p () == Qt)
    b = stwncpy (b, be, "root: ", 6);
  return b;
}

Char *
buffer_info::percent (Char *b, Char *be) const
{
  if (b_percentp)
    *b_percentp = b;
  else if (b_bufp && b_wp)
    {
      char tem[64];
      int tl;
      if (b_bufp->b_nchars > 0)
        tl = snprintf (tem, sizeof tem, "%d",
                       (int)((100 * (long long)b_wp->w_point.p_point) / b_bufp->b_nchars));
      else
        tl = snprintf (tem, sizeof tem, "100");
      b = stwncpy (b, be, tem, tl);
    }
  return b;
}

Char *
buffer_info::format (lisp fmt, Char *b, Char *be) const
{
  if (b_posp)
    *b_posp = 0;
  if (b_ime)
    *b_ime = 0;
  if (b_percentp)
    *b_percentp = 0;

  const ucs4_t *p = xstring_contents (fmt);
  const ucs4_t *const pe = p + xstring_length (fmt);

  while (p < pe && b < be)
    {
      ucs4_t c = *p++;
      if (c != '%')
        {
        normal_char:
          if (b < be) *b++ = Char (c);
        }
      else
        {
          if (p == pe)
            break;

          c = *p++;
          int pound = 0;
          if (c == '#')
            {
              pound = 1;
              if (p == pe)
                break;
              c = *p++;
            }

          switch (c)
            {
            default:
              goto normal_char;

            case '*':
              b = modified (b, pound);
              break;

            case 'r':
              b = read_only (b, pound);
              break;

            case 'p':
              b = progname (b, be);
              break;

            case 'v':
              b = version (b, be, pound);
              break;

            case 'h':
              b = host_name (b, be, pound);
              break;

            case 'b':
              b = buffer_name (b, be);
              break;

            case 'f':
              b = file_name (b, be, pound);
              break;

            case 'F':
              b = file_or_buffer_name (b, be, pound);
              break;

            case 'M':
            case 'm':
              b = mode_name (b, be, c);
              break;

            case 'k':
              b = encoding (b, be);
              break;

            case 'l':
              b = eol_code (b, be);
              break;

            case 'i':
              b = ime_mode (b, be);
              break;

            case 'P':
              b = position (b, be);
              break;

            case '/':
              b = percent (b, be);
              break;

            case '$':
              b = process_id (b, be);
              break;

            case '!':
              b = admin_user (b, be);
              break;
            }
        }
    }

  return b;
}

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

// Whether xyzzy color index is a "bright" variant (0-7)
static int
xyzzy_color_bright (int idx)
{
  return idx < 8;
}

// Color pair layout:
//   1-8:   syntax highlighting
//   9:     selection (white on blue)
//   16+:   textprop colors, indexed as 16 + fg*16 + bg
#define SELECTION_PAIR 9
#define MENU_PAIR 10       // menu bar & dropdown normal
#define MENU_SEL_PAIR 11   // menu selected item
#define TEXTPROP_PAIR_BASE 16
#define TEXTPROP_PAIR(fg, bg) (TEXTPROP_PAIR_BASE + (fg) * 16 + (bg))

// Substitute character for a bitmap-glyph FontSet slot (issue #13 step4e).
// A terminal has no glyph atlas, so xyzzy's bitmap markers (newline, tab,
// fold separators) map to stand-in characters; padding/blank slots stay blank.
// Shared by output_glyph and NcursesPainter::blit_glyph_bitmap.
static chtype
bitmap_slot_char (int slot)
{
  switch (slot)
    {
    case FontSet::newline:        return ACS_LRCORNER;  // end-of-line mark
    case FontSet::htab:           return ACS_RARROW;    // tab mark
    case FontSet::backsl:
    case FontSet::bold_backsl:    return '\\';
    case FontSet::sep:
    case FontSet::fold_sep0:
    case FontSet::fold_sep1:      return ACS_HLINE;
    case FontSet::fold_mark_sep0:
    case FontSet::fold_mark_sep1: return ACS_PLUS;
    default:                      return ' ';           // blanks / spaces
    }
}

// Output a single glyph_t to ncurses at position (row, col).
// Returns the number of columns consumed (0 for combining/JUNK trail,
// 1 for narrow, 2 for wide).
//
// 5b-4: glyph layout は code_point (high 32bit, GLYPH_CP) + metadata
// (low 32bit, GLYPH_FONT/WIDTH/etc)。旧 GLYPH_LEAD/TRAIL/CATEGORY は廃止、
// wide char 後続 cell は GLYPH_JUNK で識別。
static int
output_glyph (int row, int col, glyph_t g)
{
  // JUNK trail (wide char の 2 cell 目): caller 側で skip 想定。念のため 0。
  if (g & GLYPH_JUNK)
    return 0;

  attr_t attrs = 0;
  if (g & GLYPH_BOLD)      attrs |= A_BOLD;
  if (g & GLYPH_UNDERLINE) attrs |= A_UNDERLINE;
  if (g & GLYPH_REVERSED)  attrs |= A_REVERSE;

  int selected = (g & GLYPH_SELECTED) != 0;

  if (g & GLYPH_BITMAP_BIT)
    {
      // Bitmap markers (newline / tab / fold separators): no glyph atlas on a
      // terminal, so substitute a per-slot stand-in character (issue #13
      // step4e). slot = the FontSet enum in the low byte (below GLYPH_BITMAP_BIT).
      attr_t a = attrs | (selected ? COLOR_PAIR (SELECTION_PAIR) : 0);
      mvaddch (row, col, bitmap_slot_char ((int)(g & 0xff)) | a);
      return 1;
    }

  int color_pair = selected ? SELECTION_PAIR : 0;
  if (g & GLYPH_TEXTPROP_FG_BIT)
    {
      int fg = (g >> GLYPH_TEXTPROP_FG_SHIFT_BITS) & (GLYPH_TEXTPROP_NCOLORS - 1);
      int bg = (g >> GLYPH_TEXTPROP_BG_SHIFT_BITS) & (GLYPH_TEXTPROP_NCOLORS - 1);
      color_pair = TEXTPROP_PAIR (fg, bg);
      if (color_pair >= COLOR_PAIRS)
        color_pair = 0;
      if (fg > 0 && xyzzy_color_bright (fg))
        attrs |= A_BOLD;
    }
  else
    {
      glyph_t text_type = g & GLYPH_TEXT_MASK;
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

  uint32_t cp = GLYPH_CP (g);
  int width = (int) glyph_width (g);
  if (width == 0)
    width = 1;

  // Phase 3 reserved (shape ref): 当面 ? で出す
  if (cp >= 0x110000u)
    {
      mvaddch (row, col, '?' | attrs);
      return width;
    }

  // ASCII control char (cp < 0x20) は ^ で代替表示 (元来 GLYPH_CTRL +
  // bitmap / 2-cell ^X 形式は visual marker。ncurses は単純化)
  if (cp < 0x20)
    {
      mvaddch (row, col, '^' | attrs);
      return width;
    }

  if (cp < 0x80)
    {
      mvaddch (row, col, cp | attrs);
      return width;
    }

  // BMP / 非 BMP の Unicode glyph
  cchar_t cch;
  wchar_t ws[3];
  if (cp < 0x10000u)
    {
      ws[0] = (wchar_t) cp;
      ws[1] = 0;
    }
  else
    {
      uint32_t v = cp - 0x10000u;
      ws[0] = (wchar_t) (0xD800u + (v >> 10));
      ws[1] = (wchar_t) (0xDC00u + (v & 0x3FFu));
      ws[2] = 0;
    }
  setcchar (&cch, ws, attrs, (short) color_pair, NULL);
  mvadd_wch (row, col, &cch);
  return width;
}

// COLORREF sentinel meaning "use the terminal default" (no explicit color).
// Core uses CLR_INVALID for "unset"; mirror that here. Defined before the
// first user (NcursesPainter::draw_text call sites).
#ifndef CLR_INVALID
# define CLR_INVALID ((COLORREF)0xffffffff)
#endif

// ============================================================
// NcursesPainter — issue #13 step4 (skeleton: step4a; wired in step4c)
//
// A Painter (src/core/painter.h) backed by ncurses. The long-term goal is to
// retire the bypass path (render_window/output_glyph drawing directly) and let
// core's paint_*(Painter&) run on ncurses too. Its primitives route to the
// existing ncurses drawing helpers.
//
// Units: ncurses is a cell terminal, so x,y are character cells and
// cell_width()/cell_height() are 1. Colors arrive as COLORREF (packed RGB);
// COLORREF -> color pair is get_colorref_pair (step4b). For now draw_text
// reuses output_glyph, whose glyph-derived color governs text color, so the
// step4c call-path switch is pixel-identical; the COLORREF args are honored
// in a later step.
struct NcursesPainter : public Painter
{
  // Text output: draw the glyph run [g, ge) starting at cell (x, y).
  // Mirrors render_glyph_row's loop: skip JUNK trails, advance by glyph width.
  void draw_text (int x, int y, const glyph_t *g, const glyph_t *ge,
                  COLORREF /*fg*/, COLORREF /*bg*/, int /*charset*/,
                  unsigned /*flags*/, const RECT * /*clip*/,
                  bool /*opaque*/) override
  {
    int col = x;
    for (const glyph_t *p = g; p < ge; p++)
      {
        if (*p & GLYPH_JUNK)
          continue;            // wide trail — consumed by its lead
        int w = output_glyph (y, col, *p);
        col += (w > 0) ? w : 1;
      }
  }

  // Rectangle fill: blank cells (the only "fill" a terminal has).
  void fill_rect (int x, int y, int w, int h, COLORREF /*c*/) override
  {
    for (int row = y; row < y + h; row++)
      {
        move (row, x);
        for (int i = 0; i < w; i++)
          addch (' ');
      }
  }

  // Lines: ncurses has line-drawing chars but no shading, so the mode line's
  // 3D border collapses to a single rule (or a no-op when zero-length).
  void draw_hline (int x1, int x2, int y, COLORREF /*c*/) override
  {
    if (x2 > x1)
      mvhline (y, x1, ACS_HLINE, x2 - x1);
  }
  void draw_vline (int x, int y1, int y2, COLORREF /*c*/) override
  {
    if (y2 > y1)
      mvvline (y1, x, ACS_VLINE, y2 - y1);
  }

  // Symbol-glyph blit: no atlas on a terminal, so substitute a character per
  // FontSet slot (issue #13 step4e), via the shared bitmap_slot_char table.
  // Markers (newline, tab, fold separators) become visible stand-ins; padding
  // slots stay blank.
  void blit_glyph_bitmap (int x, int y, int w, int /*h*/, int slot,
                          int /*cell_yoff*/, COLORREF /*fg*/,
                          COLORREF /*bg*/) override
  {
    mvaddch (y, x, bitmap_slot_char (slot));
    for (int i = 1; i < w; i++)
      mvaddch (y, x + i, ' ');
  }

  // Measurement: cell columns the run occupies (wcwidth-equivalent via
  // glyph_width). Used for mode-line truncation.
  int text_width (const glyph_t *g, const glyph_t *ge, int /*charset*/) override
  {
    int w = 0;
    for (const glyph_t *p = g; p < ge; p++)
      {
        if (*p & GLYPH_JUNK)
          continue;
        int gw = (int) glyph_width (*p);
        w += (gw > 0) ? gw : 1;
      }
    return w;
  }

  // UTF-16 Char run in a non-glyph-buffer font (mode line / ruler / terminal).
  // On a terminal the mode line is drawn reversed (the GUI uses MODELINE_FG/BG
  // colors); honor that via A_REVERSE when font_role is PFONT_MODELINE.
  void draw_text_chars (int x, int y, const Char *s, int len,
                        COLORREF /*fg*/, COLORREF /*bg*/, int font_role,
                        const RECT * /*clip*/, bool /*opaque*/) override
  {
    wchar_t wbuf[1025];
    int wi = 0;
    for (int i = 0; i < len && wi < 1024; i++)
      wbuf[wi++] = (wchar_t) s[i];
    wbuf[wi] = 0;
    attr_t attr = (font_role == PFONT_MODELINE) ? A_REVERSE : 0;
    if (attr)
      attron (attr);
    mvaddnwstr (y, x, wbuf, wi);
    if (attr)
      attroff (attr);
  }
  int text_chars_width (const Char *s, int len, int /*font_role*/) override
  {
    int w = 0;
    for (int i = 0; i < len; i++)
      {
        int cw = wcwidth ((wchar_t) s[i]);
        w += (cw > 0) ? cw : 1;
      }
    return w;
  }

  // Cell metrics: a terminal cell is the unit, so 1.
  int cell_width () const override { return 1; }
  int cell_height () const override { return 1; }
};

// NcursesFontMetrics — issue #13 step5b (dummy).
//
// A terminal has no scalable fonts: every cell is 1x1, ASCII is one column,
// fullwidth is two. ncurses never actually measures a font (FontSet::create
// is Win32-only and not compiled here), so this exists to satisfy the
// FontMetrics interface and document the cell=1 model; it is not yet wired in.
struct NcursesFontMetrics : public FontMetrics
{
  FontMetricsResult measure (const LOGFONTW & /*lf*/) override
  {
    FontMetricsResult r;
    r.ave_char_width = 1;
    r.ascent = 1;
    r.descent = 0;
    r.ascii_width = 1;
    r.fullwidth = 2;
    return r;
  }
  int dpi_y () const override { return 96; }  // nominal; unused on a terminal
};

// Render one glyph_data row to ncurses screen row.
// col_offset: starting column on screen (0 for full-width windows).
// cols: number of columns available for this window's text.
//
// 5b-4: 1 glyph_t = 1 code point。wide char は連続 2 cell (lead に
// width=WIDE+CP、trail に GLYPH_JUNK) で格納されている。trail は skip し、
// lead で 2 column 分前進する。
static void
render_glyph_row (int row, int col_offset, int cols, const glyph_data *gd)
{
  // issue #13 step4d: clear the row background through the Painter.
  NcursesPainter painter;
  painter.fill_rect (col_offset, row, cols, 1, CLR_INVALID);

  if (!gd || gd->gd_len <= 0)
    return;

  const glyph_t *g = gd->gd_cc;
  int len = gd->gd_len;

  // issue #13 step4c: route the glyph row through NcursesPainter::draw_text
  // instead of calling output_glyph directly. draw_text walks [g, gend) the
  // same way (skip JUNK, advance by glyph width) and reuses output_glyph
  // internally, so the rendering is identical — only the call path changes.
  // Clip [g, gend) to the cells that fit in `cols` here, since draw_text has
  // no column limit of its own.
  int x = 0, gend = 0;
  while (gend < len && x < cols)
    {
      glyph_t gt = g[gend++];
      if (gt & GLYPH_JUNK)
        continue;
      int w = (int) glyph_width (gt);
      x += (w > 0) ? w : 1;
    }

  painter.draw_text (col_offset, row, g, g + gend,
                     CLR_INVALID, CLR_INVALID, 0, 0, NULL, false);
}

// Draw modeline for a given window on a given screen row.
// col_offset: starting column on screen. cols: modeline width.
static void
draw_modeline (Window *wp, int row, int col_offset, int cols)
{
  if (cols <= 0)
    return;

  Buffer *bp = wp->w_bufp;
  if (!bp)
    return;

  // Phase 2: buffer_info::format writes Char * (UTF-16 code units).
  int l = cols + 10;
  Char *b0 = (Char *)alloca (l * sizeof (Char));
  Char *b = b0;
  *b++ = ' ';

  lisp fmt = symbol_value (Vmode_line_format, bp);
  if (stringp (fmt))
    {
      buffer_info binfo (wp, bp, NULL, NULL, NULL);
      b = binfo.format (fmt, b, b0 + l);
    }

  int maxw = (cols < 1024) ? cols : 1024;

  // Build the padded mode-line content as a Char run, then draw it through
  // the Painter (issue #13 step4f). draw_text_chars applies A_REVERSE for the
  // PFONT_MODELINE role, matching the previous direct mvaddnwstr+A_REVERSE.
  Char line[1025];
  int n = 0;
  for (Char *p = b0; p < b && n < maxw; p++)
    line[n++] = *p;
  while (n < maxw)
    line[n++] = (Char)'-';

  NcursesPainter painter;
  painter.draw_text_chars (col_offset, row, line, n,
                           CLR_INVALID, CLR_INVALID, PFONT_MODELINE,
                           NULL, true);
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
// Put one character of a status-line row, advancing x.
static void
status_line_putc (int row, int &x, ucs4_t c)
{
  if (c < 0x20)
    return;                     // skip control chars
  if (c < 0x80)
    {
      mvaddch (row, x, c);
      x++;
      return;
    }
  wchar_t wc = (wchar_t)c;
  if (wc == 0)
    {
      mvaddch (row, x, '?');
      x++;
      return;
    }
  cchar_t cc;
  wchar_t ws[2] = {wc, 0};
  setcchar (&cc, ws, 0, 0, NULL);
  mvadd_wch (row, x, &cc);
  int w = wcwidth ((wchar_t)wc);
  x += (w > 0) ? w : 1;
}

// Draw the status line (echo area) over NROWS rows starting at TOP.
//
// **メッセージは複数行になれる** (issue #97)。行の割り方は高さを決める側と
// 同じもの (src/core/minibuffer-message.cc) を使う。別々に数えると
// 「4 行分の高さを取ったのに 3 行しか描かない」という食い違いになる。
static void
draw_status_line (int top, int nrows, int cols)
{
  for (int i = 0; i < nrows; i++)
    {
      move (top + i, 0);
      clrtoeol ();
    }

  // Check for Vminibuffer_message first (set by (message ...) Lisp function)
  lisp msg = xsymbol_value (Vminibuffer_message);
  if (stringp (msg))
    {
      minibuffer_row *rows
        = (minibuffer_row *)alloca (sizeof (minibuffer_row) * max (1, nrows));
      int n = minibuffer_message_layout (msg, cols, nrows, rows);
      const ucs4_t *s = xstring_contents (msg);
      for (int i = 0; i < n; i++)
        {
          int x = 0;
          for (int j = rows[i].p1; j < rows[i].p2 && x < cols; j++)
            status_line_putc (top + i, x, s[j]);
        }
      return;
    }
  int row = top;

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
  wp->w_plinenum = (bp->b_fold_columns == Buffer::FOLD_NONE)
    ? linenum
    : (bp->linenum_mode () == Buffer::LNMODE_LF
       ? bp->point_linenum (wp->w_point.p_point)
       : linenum);
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

  wp->w_last_top_linenum = disp_linenum;
  wp->w_last_top_column = wp->w_top_column;
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
          && x >= bp->b_fold_columns)
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

// Initialize ncurses color pairs for syntax highlighting and text properties
static void init_textprop_color_pairs ();
static short colorref_to_ncurses_color (COLORREF);
static int g_colors_initialized = 0;

static void
init_ncurses_colors ()
{
  if (g_colors_initialized)
    return;
  g_colors_initialized = 1;

  // Color pairs for syntax highlighting (1-8)
  init_pair (1, COLOR_GREEN, -1);     // comment
  init_pair (2, COLOR_YELLOW, -1);    // string
  init_pair (3, COLOR_CYAN, -1);      // keyword1
  init_pair (4, COLOR_MAGENTA, -1);   // keyword2
  init_pair (5, COLOR_RED, -1);       // keyword3
  init_pair (6, COLOR_BLUE, -1);      // tag
  init_pair (7, COLOR_RED, -1);       // ctrl (bright via A_BOLD)
  init_pair (8, COLOR_WHITE, -1);     // linenum (dim via A_DIM)
  init_pair (SELECTION_PAIR, COLOR_WHITE, COLOR_BLUE);  // selection
  init_pair (MENU_PAIR, COLOR_BLACK, COLOR_WHITE);      // menu normal
  init_pair (MENU_SEL_PAIR, COLOR_WHITE, COLOR_BLACK);  // menu selected

  init_textprop_color_pairs ();
}

// Color pairs for text properties (16-271) -- the "文字1〜15" palette.
//
// 色は添字から直に決めず、Window::w_textprop_forecolor の COLORREF を端末色へ
// 量子化する。この表はカラーテーマから差し替えられる (issue #98,
// src/core/textprop-colors.cc) ので、添字を見ていると差し替えが効かない。
// 既定値のままなら結果は以前と同じ色になる (#ff0000 -> 赤 など)。
//
// 明るい版と暗い版 (1-7 と 9-15) の区別は output_glyph 側の A_BOLD が付ける。
// どちらも同じ端末色へ量子化されるので、その役割はここでは持てない。
static void
init_textprop_color_pairs ()
{
  int max_pairs = COLOR_PAIRS;
  for (int fg = 0; fg < 16; fg++)
    for (int bg = 0; bg < 16; bg++)
      {
        int pair = TEXTPROP_PAIR (fg, bg);
        if (pair >= max_pairs)
          break;
        short ncfg = (fg == 0) ? -1
                     : colorref_to_ncurses_color (Window::w_textprop_forecolor[fg]);
        short ncbg = (bg == 0) ? -1
                     : colorref_to_ncurses_color (Window::w_textprop_backcolor[bg]);
        init_pair ((short)pair, ncfg, ncbg);
      }
}

/* 「文字1〜15」の表が Lisp から差し替えられたときの後始末
   (src/core/textprop-colors.cc)。端末では色そのものを cell に持てないので、
   色ペアを作り直して全ウィンドウに再描画の印を付ける。 */
void
Window::textprop_colors_changed ()
{
  init_textprop_color_pairs ();
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    wp->w_disp_flags |= WDF_WINDOW;
}

// SIGWINCH flag (set in ncurses-main.cc)
extern volatile int g_need_resize;

// Terminal helpers (defined in ncurses-process.cc)
extern Terminal *buffer_terminal (const Buffer *bp);
extern void buffer_terminal_resize (const Buffer *bp, int rows, int cols);

// Terminal color pair allocation for 256-color support.
// Pairs 272+ are used for terminal fg/bg combinations.
#define TERM_PAIR_BASE 272

// Map terminal color index to ncurses color number.
// 0=default(-1), 1-8=standard(0-7), 9-16=bright(8-15), 17+=extended(idx-17)
static short
term_color_to_ncurses (uint8_t tc)
{
  if (tc == 0) return -1;
  if (tc <= 8) return (short)(tc - 1);
  if (tc <= 16) return (short)(tc - 9 + 8);
  return (short)(tc - 17);  // 256-color index directly
}

// Cache for terminal color pairs (lazily allocated)
struct TermColorPairCache {
  struct Entry { uint8_t fg, bg; short pair; };
  Entry entries[256];
  int count;
  short next_pair;
};
static TermColorPairCache g_term_colors = {{}, 0, TERM_PAIR_BASE};

static short
get_term_color_pair (uint8_t fg, uint8_t bg)
{
  if (fg == 0 && bg == 0)
    return 0;  // default colors

  // Search cache
  for (int i = 0; i < g_term_colors.count; i++)
    if (g_term_colors.entries[i].fg == fg && g_term_colors.entries[i].bg == bg)
      return g_term_colors.entries[i].pair;

  // Allocate new pair
  if (g_term_colors.next_pair >= COLOR_PAIRS || g_term_colors.count >= 256)
    return 0;  // fallback to default

  short pair = g_term_colors.next_pair++;
  short ncfg = term_color_to_ncurses (fg);
  short ncbg = term_color_to_ncurses (bg);
  init_pair (pair, ncfg, ncbg);

  TermColorPairCache::Entry &e = g_term_colors.entries[g_term_colors.count++];
  e.fg = fg; e.bg = bg; e.pair = pair;
  return pair;
}

// ============================================================
// COLORREF -> ncurses color pair  (issue #13 step4b)
//
// Core's paint_*(Painter&) resolves each glyph to a COLORREF (packed RGB)
// before calling Painter::draw_text — the syntax/textprop category is already
// gone by then. So NcursesPainter must quantize an arbitrary RGB down to a
// terminal color and allocate a pair on demand, the same shape as
// get_term_color_pair but keyed by (fg_colorref, bg_colorref).
//
// Pair-number layout (see init_ncurses_colors / get_term_color_pair):
//   1-8 syntax, 9 selection, 10-11 menu, 16-271 textprop,
//   272.. terminal (<=256 entries, so up to 527).
// COLORREF pairs therefore start at 528 to avoid clobbering any of those.
#define COLORREF_PAIR_BASE 528

// (CLR_INVALID is defined earlier, near NcursesPainter.)

// Quantize a packed-RGB COLORREF to an ncurses color number (0-7, or 8-15 when
// the terminal advertises >=16 colors). Returns -1 for the default color.
// Each channel is thresholded into a bit of the 3-bit ncurses color cube; a
// high overall luminance promotes to the bright (8-15) variant.
static short
colorref_to_ncurses_color (COLORREF c)
{
  if (c == CLR_INVALID)
    return -1;

  int r = GetRValue (c), g = GetGValue (c), b = GetBValue (c);

  // ncurses COLOR_* bit order is 1=red, 2=green, 4=blue.
  int idx = (r >= 0x80 ? COLOR_RED : 0)
          | (g >= 0x80 ? COLOR_GREEN : 0)
          | (b >= 0x80 ? COLOR_BLUE : 0);

  // Promote to a bright variant when the color is clearly light and the
  // terminal has the extra 8 colors to offer.
  if (COLORS >= 16)
    {
      int maxch = r > g ? (r > b ? r : b) : (g > b ? g : b);
      if (maxch >= 0xc0)
        idx += 8;
    }
  return (short)idx;
}

// Cache for COLORREF (fg,bg) -> pair, mirroring TermColorPairCache.
struct ColorrefPairCache {
  struct Entry { COLORREF fg, bg; short pair; };
  Entry entries[256];
  int count;
  short next_pair;
};
static ColorrefPairCache g_colorref_colors = {{}, 0, COLORREF_PAIR_BASE};

// Allocate (or look up) an ncurses color pair for a COLORREF fg/bg combo.
// Returns 0 (the terminal default pair) when both are default or when the
// pair budget is exhausted.
static short
get_colorref_pair (COLORREF fg, COLORREF bg)
{
  if (fg == CLR_INVALID && bg == CLR_INVALID)
    return 0;

  for (int i = 0; i < g_colorref_colors.count; i++)
    if (g_colorref_colors.entries[i].fg == fg
        && g_colorref_colors.entries[i].bg == bg)
      return g_colorref_colors.entries[i].pair;

  if (g_colorref_colors.next_pair >= COLOR_PAIRS
      || g_colorref_colors.count >= 256)
    return 0;  // fall back to default colors

  short pair = g_colorref_colors.next_pair++;
  init_pair (pair, colorref_to_ncurses_color (fg),
             colorref_to_ncurses_color (bg));

  ColorrefPairCache::Entry &e = g_colorref_colors.entries[g_colorref_colors.count++];
  e.fg = fg; e.bg = bg; e.pair = pair;
  return pair;
}

// Render a terminal window directly from TermCell grid
static void
render_terminal_window (Window *wp, Terminal *term, int total_cols)
{
  int col_offset = wp->w_rect.left;
  int win_cols = wp->w_rect.right - wp->w_rect.left;
  int has_separator = (wp->w_rect.right < total_cols) ? 1 : 0;
  int text_cols = win_cols - has_separator;
  if (text_cols < 1) text_cols = 1;

  int win_top = wp->w_rect.top;
  int text_rows = wp->w_rect.bottom - wp->w_rect.top - 1;

  // Resize terminal to match window if needed
  if (term->rows () != text_rows || term->cols () != text_cols)
    buffer_terminal_resize (wp->w_bufp, text_rows, text_cols);

  int trows = term->rows ();
  int tcols = term->cols ();

  for (int r = 0; r < text_rows; r++)
    {
      move (win_top + r, col_offset);
      for (int c = 0; c < text_cols; c++)
        {
          if (r < trows && c < tcols)
            {
              const TermCell *tc = term->display_cell (r, c);
              if (tc->wide == 2)
                continue;  // skip continuation cells

              attr_t attrs = 0;
              if (tc->attrs & TATTR_BOLD)      attrs |= A_BOLD;
              if (tc->attrs & TATTR_DIM)       attrs |= A_DIM;
              if (tc->attrs & TATTR_UNDERLINE) attrs |= A_UNDERLINE;
              if (tc->attrs & TATTR_REVERSE)   attrs |= A_REVERSE;

              short pair = get_term_color_pair (tc->fg, tc->bg);

              Char ch = tc->ch;
              if (ch == 0) ch = ' ';

              // Use mvadd_wch for all terminal cells to avoid chtype's
              // 8-bit color pair limit (pairs >= 256 wrap around).
              wchar_t wc;
              if (ch > 0x80)
                {
                  ucs2_t w = i2w (ch);
                  wc = (wchar_t)(w ? w : '?');
                }
              else
                wc = (wchar_t)ch;

              cchar_t cc;
              wchar_t wstr[2] = { wc, 0 };
              setcchar (&cc, wstr, attrs, pair, NULL);
              mvadd_wch (win_top + r, col_offset + c, &cc);
            }
          else
            {
              mvaddch (win_top + r, col_offset + c, ' ');
            }
        }
    }

  term->clear_dirty ();

  // Draw modeline
  draw_modeline (wp, wp->w_rect.bottom - 1, col_offset, win_cols);

  // Draw vertical separator if needed
  if (has_separator)
    {
      int sep_col = wp->w_rect.right - 1;
      for (int y = wp->w_rect.top; y < wp->w_rect.bottom; y++)
        mvaddch (y, sep_col, ACS_VLINE);
    }
}

// Render one editing window: fill glyphs, render to screen, draw modeline.
// total_cols: terminal width (for separator detection).
static void
render_window (Window *wp, int total_cols)
{
  Buffer *bp = wp->w_bufp;
  if (!bp)
    return;

  // If this buffer has a terminal-backed process, render directly from terminal
  Terminal *term = buffer_terminal (bp);
  if (term)
    {
      render_terminal_window (wp, term, total_cols);
      return;
    }

  int col_offset = wp->w_rect.left;
  int win_cols = wp->w_rect.right - wp->w_rect.left;
  int has_separator = (wp->w_rect.right < total_cols) ? 1 : 0;
  int text_cols = win_cols - has_separator;
  if (text_cols < 1) text_cols = 1;

  int win_top = wp->w_rect.top;
  int text_rows = wp->w_rect.bottom - wp->w_rect.top - 1;  // -1 for modeline
  if (text_rows < 1)
    text_rows = 1;

  ncurses_calc_client_size (wp, text_cols, text_rows);
  bp->window_size_changed ();
  ncurses_reframe (wp);

  // Update selection region from point/marker (same as win32/disp.cc)
  if ((wp->w_selection_type & (Buffer::CONTINUE_PRE_SELECTION
                               | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
    {
      // Use (int &) cast to match the (int &) &= ~CONTINUE_PRE_SELECTION below;
      // without this, strict aliasing lets the compiler cache the enum value
      // across the (int &) write, so the VOID assignment silently disappears.
      (int &)wp->w_selection_type = (int)Buffer::SELECTION_VOID;
      wp->w_selection_point = NO_MARK_SET;
      wp->w_selection_marker = NO_MARK_SET;
      wp->w_selection_region.p1 = -1;
    }
  (int &)wp->w_selection_type &= ~Buffer::CONTINUE_PRE_SELECTION;

  if (wp->w_reverse_region.p1 != NO_MARK_SET)
    {
      if ((wp->w_reverse_temp & (Buffer::CONTINUE_PRE_SELECTION
                                 | Buffer::PRE_SELECTION)) == Buffer::PRE_SELECTION)
        {
          wp->w_reverse_region.p1 = NO_MARK_SET;
          wp->w_reverse_region.p2 = NO_MARK_SET;
          (int &)wp->w_reverse_temp = (int)Buffer::SELECTION_VOID;
        }
    }
  (int &)wp->w_reverse_temp &= ~Buffer::CONTINUE_PRE_SELECTION;

  if (wp->w_selection_type != Buffer::SELECTION_VOID)
    {
      point_t p = (wp->w_selection_point == NO_MARK_SET
                   ? wp->w_point.p_point : wp->w_selection_point);
      point_t p1, p2;
      if (wp->w_selection_marker < p)
        { p1 = wp->w_selection_marker; p2 = p; }
      else
        { p1 = p; p2 = wp->w_selection_marker; }
      wp->w_selection_region.p1 = p1;
      wp->w_selection_region.p2 = p2;
    }
  else
    {
      wp->w_selection_region.p1 = -1;
    }

  if (wp->w_glyphs.g_rep)
    {
      Point df;
      df.p_point = 0;
      df.p_chunk = bp->b_chunkb;
      df.p_offset = 0;
      if (wp->w_disp > 0)
        bp->goto_char (df, wp->w_disp);

      long vlinenum;
      if (bp->b_fold_columns == Buffer::FOLD_NONE)
        vlinenum = bp->point_linenum (wp->w_disp);
      else
        vlinenum = bp->folded_point_linenum (wp->w_disp);

      int hide = symbol_value (Vhide_restricted_region, bp) != Qnil;
      wp->redraw_window (df, vlinenum, 1, hide);

      glyph_data **ng = wp->w_glyphs.g_rep->gr_nglyph;
      for (int y = 0; y < text_rows && y < wp->w_ch_max.cy; y++)
        render_glyph_row (win_top + y, col_offset, text_cols, ng[y]);

      // issue #13 step4d: clear empty rows past the buffer end through the
      // Painter, then mark each with the '~' beyond-EOF indicator.
      NcursesPainter painter;
      for (int y = wp->w_ch_max.cy; y < text_rows; y++)
        {
          painter.fill_rect (col_offset, win_top + y, text_cols, 1, CLR_INVALID);
          mvaddch (win_top + y, col_offset, '~');
        }

      glyph_data **tmp = wp->w_glyphs.g_rep->gr_oglyph;
      wp->w_glyphs.g_rep->gr_oglyph = wp->w_glyphs.g_rep->gr_nglyph;
      wp->w_glyphs.g_rep->gr_nglyph = tmp;
    }

  // Draw modeline at bottom of this window's area
  draw_modeline (wp, wp->w_rect.bottom - 1, col_offset, win_cols);

  // Draw vertical separator if this window is not at right edge.
  // issue #13 step4e: route through NcursesPainter::draw_vline.
  if (has_separator)
    {
      int sep_col = wp->w_rect.right - 1;
      NcursesPainter painter;
      painter.draw_vline (sep_col, wp->w_rect.top, wp->w_rect.bottom,
                          CLR_INVALID);
    }
}

static void draw_persistent_menu_bar ();

void
refresh_screen (int f)
{
  init_ncurses_colors ();

  // refresh_screen(1) is supposed to force a full repaint (Win32 does).
  // ncurses otherwise relies on its own diff, which can miss updates in
  // terminal-backed windows after an idle period, leaving the shell buffer
  // frozen until the app is resized or alt-tabbed.
  if (f)
    touchwin (stdscr);

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

      Window::compute_geometry ();
      for (Buffer *bp = Buffer::b_blist; bp; bp = bp->b_next)
        bp->window_size_changed ();
      clear ();
      displog ("refresh: resized to %dx%d\n", cols, rows);
    }

  int rows, cols;
  getmaxyx (stdscr, rows, cols);

  if (rows < 3 || cols < 4)
    return;

  /* ステータス行の高さをメッセージの量に合わせる (issue #97)。**描く前に。**
     高さが変わると他のウィンドウの高さも変わる。 */
  if (Window::adjust_minibuffer_lines ())
    {
      for (Buffer *bp = Buffer::b_blist; bp; bp = bp->b_next)
        bp->window_size_changed ();
      clear ();
    }

  Window *sel = selected_window ();
  if (!sel)
    return;
  int in_minibuffer = sel->minibuffer_window_p ()
                      && sel->w_bufp
                      && sel->w_bufp->b_minibufferp;

  Window *mini = Window::minibuffer_window ();
  if (!mini)
    return;

  // Render each non-minibuffer window
  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      if (!wp->w_bufp)
        continue;
      render_window (wp, cols);
    }

  // Draw echo area (last row)
  if (in_minibuffer)
    {
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
      draw_status_line (rows - Window::w_minibuffer_lines,
                        Window::w_minibuffer_lines, cols);

      // Position cursor in active window
      if (!sel->minibuffer_window_p ())
        {
          Terminal *sel_term = sel->w_bufp ? buffer_terminal (sel->w_bufp) : 0;
          if (sel_term)
            {
              /* Terminal window: cursor from terminal emulator.
                 スクロールバックを遡っている間と、アプリが DECTCEM
                 (CSI ?25l) でカーソルを消している間は出さない。 */
              if (sel_term->scrollback_offset () > 0
                  || !sel_term->cursor_visible ())
                curs_set (0);
              else
                {
                  int win_top = sel->w_rect.top;
                  int col_offset = sel->w_rect.left;
                  int cr = sel_term->cursor_row ();
                  int cc = sel_term->cursor_col ();
                  move (win_top + cr, col_offset + cc);
                  curs_set (1);
                }
            }
          else
            {
              int cy, cx;
              glyph_point_to_screen (sel, &cy, &cx);
              int win_top = sel->w_rect.top;
              int col_offset = sel->w_rect.left;
              int text_rows = sel->w_rect.bottom - sel->w_rect.top - 1;
              if (cy < text_rows)
                move (win_top + cy, col_offset + cx);
              curs_set (1);
            }
        }
    }

  // Draw persistent menu bar at row 0 (after all windows, so nothing overwrites it)
  int save_y, save_x;
  getyx (stdscr, save_y, save_x);
  draw_persistent_menu_bar ();
  move (save_y, save_x);

  // Flush to terminal
  ::refresh ();

  // Re-display popup_string overlay if visible
  if (g_popup_win)
    {
      touchwin (g_popup_win);
      wrefresh (g_popup_win);
    }
}

void
pending_refresh_screen ()
{
  // No-op for ncurses (we refresh synchronously)
}

Window *
Window::minibuffer_window ()
{
  // Return the last window in the chain (the minibuffer window)
  Window *wp = app.active_frame.windows;
  if (!wp)
    return 0;
  while (wp->w_next)
    wp = wp->w_next;
  return wp;
}

// ============================================================
// Window management (ncurses implementation)
// ============================================================

Window *
Window::coerce_to_window (lisp object)
{
  if (!object || object == Qnil)
    return selected_window ();
  check_window (object);
  if (!xwindow_wp (object))
    FEprogram_error (Edeleted_window);
  return xwindow_wp (object);
}

int
Window::count_windows ()
{
  int n = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next, n++)
    ;
  return n;
}

void
Window::close ()
{
  xwindow_wp (lwp) = 0;

  for (WindowConfiguration *wc = WindowConfiguration::wc_chain; wc; wc = wc->wc_prev)
    for (WindowConfiguration::Data *d = wc->wc_data, *de = d + wc->wc_nwindows; d < de; d++)
      if (d->wp == this)
        {
          w_next = app.active_frame.reserved;
          app.active_frame.reserved = this;
          return;
        }

  w_next = app.active_frame.deleted;
  app.active_frame.deleted = this;
}

// Proportionally redistribute sizes when the total changes.
// o[] has n+1 entries (boundary positions), old_size -> new_size.
static void
ncurses_compute_size (int *o, int n, int old_size, int new_size)
{
  if (old_size < 0) old_size = 0;
  if (new_size < 0) new_size = 0;
  int *const w = (int *)alloca (sizeof *w * n);
  int i;
  for (i = 0; i < n; i++)
    w[i] = o[i + 1] - o[i];
  int diff_size = new_size - old_size;
  if (!old_size)
    {
      int d = diff_size / n;
      for (i = 0; i < n; i++)
        w[i] += d;
    }
  else
    for (i = 0; i < n; i++)
      w[i] += w[i] * diff_size / old_size;

  int sum = 0;
  for (i = 0; i < n; i++)
    {
      if (w[i] < 0) w[i] = 0;
      sum += w[i];
    }

  int d = new_size - sum;
  if (d > 0)
    for (; d > 0; d--)
      w[(new_size + d) % n]++;
  else
    for (d = -d; d > 0; d--)
      w[(new_size + d) % n]--;

  for (o[0] = 0, i = 1; i <= n; i++)
    {
      o[i] = o[i - 1] + w[i - 1];
      if (o[i] < o[i - 1])
        o[i] = o[i - 1];
    }
  for (o[n] = new_size, i = n - 1; i > 0; i--)
    if (o[i] > o[i + 1])
      o[i] = o[i + 1];
}

// Recompute w_rect for all windows based on terminal size.
// ncurses version: 2D grid layout using w_order, character cell coordinates.
// Parameters are ignored (Win32 compat signature with defaults in Window.h).
void
Window::compute_geometry (const SIZE &, int)
{
  if (!app.active_frame.windows)
    return;

  int rows, cols;
  getmaxyx (stdscr, rows, cols);
  app.active_frame.size.cx = cols;
  app.active_frame.size.cy = rows;

  // Find minibuffer window (last in chain)
  Window *mini = minibuffer_window ();
  if (!mini)
    return;

  /* ステータス行 (エコー領域) は最後の w_minibuffer_lines 行。
     **メッセージの量で高さが変わる** (issue #97)。編集中のウィンドウに
     本文 1 行 + モード行は残す。行 0 はメニューバーが使う。 */
  int mini_lines = max (1, min (Window::w_minibuffer_lines, rows - 3));
  Window::w_minibuffer_lines = mini_lines;
  mini->w_rect.left = 0;
  mini->w_rect.right = cols;
  mini->w_rect.top = rows - mini_lines;
  mini->w_rect.bottom = rows;
  ncurses_calc_client_size (mini, cols, mini_lines);

  // Collect max grid dimensions from w_order
  long nx = 0, ny = 0;
  long ow = 0, oh = 0;
  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      nx = max (nx, (long)wp->w_order.right);
      ny = max (ny, (long)wp->w_order.bottom);
      ow = max (ow, (long)wp->w_rect.right);
      oh = max (oh, (long)wp->w_rect.bottom);
    }

  if (nx == 0 || ny == 0)
    return;

  // Build boundary arrays from current w_rect positions.
  //
  // **埋まらない添字が無いことを当てにしない。** w_order に穴があると
  // (compact_window_orders の説明) alloca のごみをそのまま座標として使い、
  // ゼロ高のウィンドウや画面外のウィンドウができる。番号を詰めてあれば
  // 穴は無いが、ここでも -1 で始めて埋め残しを直前の境界で塞ぐ。
  int *const ox = (int *)alloca (sizeof *ox * (nx + 1));
  int *const oy = (int *)alloca (sizeof *oy * (ny + 1));
  for (int i = 0; i <= nx; i++)
    ox[i] = -1;
  for (int i = 0; i <= ny; i++)
    oy[i] = -1;
  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      ox[wp->w_order.left] = wp->w_rect.left;
      oy[wp->w_order.top] = wp->w_rect.top;
      ox[wp->w_order.right] = wp->w_rect.right;
      oy[wp->w_order.bottom] = wp->w_rect.bottom;
    }
  if (ox[0] < 0)
    ox[0] = 0;
  if (oy[0] < 0)
    oy[0] = 0;
  for (int i = 1; i <= nx; i++)
    if (ox[i] < 0)
      ox[i] = ox[i - 1];
  for (int i = 1; i <= ny; i++)
    if (oy[i] < 0)
      oy[i] = oy[i - 1];

  // Proportionally redistribute to new terminal size
  // reserve row 0 (menu bar) + the minibuffer rows
  int avail_rows = max (1, rows - 1 - mini_lines);
  ncurses_compute_size (ox, nx, ow, cols);
  ncurses_compute_size (oy, ny, oh, avail_rows);

  // Shift all y positions down by 1 to make room for menu bar at row 0
  for (int i = 0; i <= ny; i++)
    oy[i] += 1;

  // Apply new positions from grid
  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      wp->w_rect.left = ox[wp->w_order.left];
      wp->w_rect.top = oy[wp->w_order.top];
      wp->w_rect.right = ox[wp->w_order.right];
      wp->w_rect.bottom = oy[wp->w_order.bottom];

      // Compute text area: subtract 1 row for modeline,
      // subtract 1 col for vertical separator if not at right edge
      int win_cols = wp->w_rect.right - wp->w_rect.left;
      if (wp->w_rect.right < cols)
        win_cols--;  // vertical separator
      int text_rows = wp->w_rect.bottom - wp->w_rect.top - 1;
      if (text_rows < 1) text_rows = 1;
      if (win_cols < 1) win_cols = 1;
      ncurses_calc_client_size (wp, win_cols, text_rows);
    }
}

void
Window::split (int nlines, int verticalp)
{
  if (minibuffer_window_p ())
    FEsimple_error (Ecannot_split_minibuffer_window);

  int h0, h1;
  int current;

  if (!verticalp)
    {
      // Horizontal split (C-x 2): split rows
      int cur_height = w_rect.bottom - w_rect.top;
      if (cur_height < 4)
        FEsimple_error (Ecannot_split);

      if (!nlines)
        {
          h0 = w_ech.cy / 2;
          h1 = w_ech.cy - h0 - 1;
          current = w_linenum - w_last_top_linenum < h0 ? 0 : 1;
        }
      else if (nlines > 0)
        {
          h0 = nlines;
          h1 = w_ech.cy - h0 - 1;
          current = 0;
        }
      else
        {
          h1 = -nlines;
          h0 = w_ech.cy - h1 - 1;
          current = 1;
        }

      if (h0 < 1 || h1 < 1)
        FEsimple_error (Ecannot_split);
    }
  else
    {
      // Vertical split (C-x 3): split columns
      // Need at least 10+10 columns (WINDOW_WIDTH_MIN from Win32)
#define WINDOW_WIDTH_MIN 10
      if (!nlines)
        {
          h0 = w_ech.cx / 2;
          h1 = w_ech.cx - h0 - 1;
          current = w_column - w_top_column < h0 ? 0 : 1;
        }
      else if (nlines > 0)
        {
          h0 = nlines;
          h1 = w_ech.cx - h0 - 1;
          current = 0;
        }
      else
        {
          h1 = -nlines;
          h0 = w_ech.cx - h1 - 1;
          current = 1;
        }

      if (h0 < WINDOW_WIDTH_MIN || h1 < WINDOW_WIDTH_MIN)
        FEsimple_error (Ecannot_split);
#undef WINDOW_WIDTH_MIN
    }

  // Create new window as copy
  Window *wp = new Window (*this);

  // Link into chain: this -> wp -> (old this->w_next)
  if (w_next)
    w_next->w_prev = wp;
  wp->w_next = w_next;
  wp->w_prev = this;
  w_next = wp;

  Window *mini = minibuffer_window ();

  if (!verticalp)
    {
      // Horizontal split: divide rows
      wp->w_rect = w_rect;
      wp->w_order = w_order;

      int split_row = w_rect.top + (w_rect.bottom - w_rect.top) / 2;
      w_rect.bottom = split_row;
      wp->w_rect.top = split_row;

      // Update w_order: insert a new row boundary
      Window *w;
      for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
        if (w != wp && w->w_rect.top == wp->w_rect.top)
          {
            w_order.bottom = w->w_order.top;
            wp->w_order.top = w->w_order.top;
            break;
          }

      if (!w || w == mini)
        {
          int y = 0, o = 0;
          for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
            if (w->w_rect.top < wp->w_rect.top && w->w_rect.top > y)
              {
                y = w->w_rect.top;
                o = w->w_order.top;
              }
          w_order.bottom = o + 1;
          wp->w_order.top = o + 1;
          for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
            {
              if (w != wp && w->w_order.top > o)
                w->w_order.top++;
              if (w != this && w->w_order.bottom > o)
                w->w_order.bottom++;
            }
        }
    }
  else
    {
      // Vertical split: divide columns
      wp->w_rect = w_rect;
      wp->w_order = w_order;

      int split_col = w_rect.left + (w_rect.right - w_rect.left) / 2;
      w_rect.right = split_col;
      wp->w_rect.left = split_col;

      // Update w_order: insert a new column boundary
      Window *w;
      for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
        if (w != wp && w->w_rect.left == wp->w_rect.left)
          {
            w_order.right = w->w_order.left;
            wp->w_order.left = w->w_order.left;
            break;
          }

      if (!w || w == mini)
        {
          int x = 0, o = 0;
          for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
            if (w->w_rect.left < wp->w_rect.left && w->w_rect.left > x)
              {
                x = w->w_rect.left;
                o = w->w_order.left;
              }
          w_order.right = o + 1;
          wp->w_order.left = o + 1;
          for (w = app.active_frame.windows; w && w != mini; w = w->w_next)
            {
              if (w != wp && w->w_order.left > o)
                w->w_order.left++;
              if (w != this && w->w_order.right > o)
                w->w_order.right++;
            }
        }
    }

  if (current)
    wp->set_window ();

  // Recompute geometry for all windows
  compute_geometry ();
}

void
Window::delete_other_windows ()
{
  if (minibuffer_window_p ())
    return;

  Window *mini = minibuffer_window ();

  int f = 0;
  for (Window *wp = app.active_frame.windows, *next; wp; wp = next)
    {
      next = wp->w_next;
      if (wp != this && wp != mini)
        {
          wp->save_buffer_params ();
          wp->close ();
          f = 1;
        }
    }
  if (!f)
    return;

  app.active_frame.windows = this;
  set_window ();
  w_prev = 0;
  w_next = mini;
  mini->w_prev = this;
  mini->w_next = 0;

  // Reset to single-window grid
  w_order.left = 0;
  w_order.top = 0;
  w_order.right = 1;
  w_order.bottom = 1;

  compute_geometry ();
}

int
Window::delete_window ()
{
  if (minibuffer_window_p ())
    return 0;

  // Check if this is the only non-minibuffer window
  Window *mini = minibuffer_window ();
  if (!w_prev && w_next == mini)
    FEsimple_error (Eonly_one_window);

  // Find a neighbor to absorb this window's space.
  // Try to find a window that shares an edge and can expand.
  Window *can = 0;

  // Prefer the previous window (above or left)
  if (w_prev && w_prev != mini)
    can = w_prev;
  else if (w_next && w_next != mini)
    can = w_next;

  if (can)
    {
      // Expand the candidate's w_order to cover this window's grid cells
      if (can->w_order.top == w_order.top && can->w_order.bottom == w_order.bottom)
        {
          // Same row span — horizontal neighbor, absorb columns
          if (can->w_order.right == w_order.left)
            can->w_order.right = w_order.right;
          else if (can->w_order.left == w_order.right)
            can->w_order.left = w_order.left;
        }
      else if (can->w_order.left == w_order.left && can->w_order.right == w_order.right)
        {
          // Same column span — vertical neighbor, absorb rows
          if (can->w_order.bottom == w_order.top)
            can->w_order.bottom = w_order.bottom;
          else if (can->w_order.top == w_order.bottom)
            can->w_order.top = w_order.top;
        }
    }

  // Unlink from chain
  if (!w_prev)
    {
      // First window: next becomes head
      Window *next = w_next;
      next->w_prev = 0;
      app.active_frame.windows = next;
      save_buffer_params ();
      close ();
      if (can) can->set_window ();
      else next->set_window ();
    }
  else
    {
      w_prev->w_next = w_next;
      if (w_next)
        w_next->w_prev = w_prev;
      save_buffer_params ();
      close ();
      if (can) can->set_window ();
    }

  // 消した側の境界番号が宙に浮くので詰める (src/core/window-config.cc)。
  compact_orders ();
  compute_geometry ();
  return 1;
}

// ============================================================
// Wait cursor / Process / Buffer stubs
// ============================================================

lisp Fbegin_wait_cursor () { return Qnil; }
lisp Fend_wait_cursor () { return Qnil; }

lisp
Fget_buffer_window (lisp buffer, lisp curwin)
{
  Buffer *bp = Buffer::coerce_to_buffer (buffer);
  Window *cwp = ((curwin && curwin != Qnil)
                 ? Window::coerce_to_window (curwin) : 0);
  int f = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_bufp == bp)
      {
        if (wp != cwp)
          return wp->lwp;
        if (f)
          return wp->lwp;
        f = 1;
      }
  return f ? cwp->lwp : Qnil;
}

// Fprocess_marker: implemented in ncurses-process.cc
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

// ============================================================
// Clipboard via OSC 52 escape sequence
// ============================================================

// Internal clipboard buffer (fallback when OSC 52 read is unsupported)
static std::string g_clipboard_buf;

static const char b64_table[] =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string
base64_encode (const std::string &in)
{
  std::string out;
  int i = 0, len = (int)in.size ();
  while (i < len)
    {
      int b0 = (u_char)in[i++];
      int b1 = (i < len) ? (u_char)in[i++] : 0;
      int b2 = (i < len) ? (u_char)in[i++] : 0;
      int n = (b0 << 16) | (b1 << 8) | b2;
      out += b64_table[(n >> 18) & 0x3f];
      out += b64_table[(n >> 12) & 0x3f];
      out += (i - 1 > len) ? '=' : b64_table[(n >> 6) & 0x3f];
      out += (i > len) ? '=' : b64_table[n & 0x3f];
    }
  return out;
}

static int
b64_decode_char (int c)
{
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

static std::string
base64_decode (const std::string &in)
{
  std::string out;
  int i = 0, len = (int)in.size ();
  while (i < len)
    {
      int a = 0, b = 0, c = 0, d = 0;
      while (i < len && (a = b64_decode_char (in[i])) < 0) i++;
      if (i >= len) break; i++;
      while (i < len && (b = b64_decode_char (in[i])) < 0) i++;
      if (i >= len) break; i++;
      out += (char)((a << 2) | (b >> 4));
      if (i >= len || in[i] == '=') break;
      c = b64_decode_char (in[i++]);
      if (c < 0) break;
      out += (char)(((b & 0xf) << 4) | (c >> 2));
      if (i >= len || in[i] == '=') break;
      d = b64_decode_char (in[i++]);
      if (d < 0) break;
      out += (char)(((c & 0x3) << 6) | d);
    }
  return out;
}

// Convert a ucs4 code-point string to UTF-8.
static std::string
utf16_to_utf8 (const ucs4_t *s, int len)
{
  std::string out;
  for (int i = 0; i < len; i++)
    {
      ucs4_t wc = s[i];
      if (wc < 0x80)
        out += (char)wc;
      else if (wc < 0x800)
        {
          out += (char)(0xc0 | (wc >> 6));
          out += (char)(0x80 | (wc & 0x3f));
        }
      else if (wc < 0x10000)
        {
          out += (char)(0xe0 | (wc >> 12));
          out += (char)(0x80 | ((wc >> 6) & 0x3f));
          out += (char)(0x80 | (wc & 0x3f));
        }
      else
        {
          out += (char)(0xf0 | (wc >> 18));
          out += (char)(0x80 | ((wc >> 12) & 0x3f));
          out += (char)(0x80 | ((wc >> 6) & 0x3f));
          out += (char)(0x80 | (wc & 0x3f));
        }
    }
  return out;
}

// Convert UTF-8 to internal Char string
static lisp
utf8_to_internal_string (const std::string &utf8)
{
  std::vector<Char> chars;
  int i = 0, len = (int)utf8.size ();
  while (i < len)
    {
      ucs2_t wc;
      u_char c = utf8[i++];
      if (c < 0x80)
        wc = c;
      else if ((c & 0xe0) == 0xc0)
        {
          wc = (c & 0x1f) << 6;
          if (i < len) wc |= (utf8[i++] & 0x3f);
        }
      else if ((c & 0xf0) == 0xe0)
        {
          wc = (c & 0x0f) << 12;
          if (i < len) wc |= (utf8[i++] & 0x3f) << 6;
          if (i < len) wc |= (utf8[i++] & 0x3f);
        }
      else
        {
          // Skip 4-byte+ sequences (outside BMP)
          while (i < len && (utf8[i] & 0xc0) == 0x80) i++;
          wc = '?';
        }
      // wc is a Unicode (BMP) code point decoded from UTF-8; make_string
      // takes UTF-16 Char units, so store it directly — no cp932 w2i fold.
      chars.push_back ((Char)wc);
    }
  if (chars.empty ())
    return make_simple_string ();
  return make_string (chars.data (), (int)chars.size ());
}

// Write OSC 52 to set clipboard
static void
osc52_copy (const std::string &utf8)
{
  std::string b64 = base64_encode (utf8);
  // Use BEL (\a) terminator — more compatible than ST (\e\\)
  std::string seq = "\033]52;c;" + b64 + "\a";
  // Write directly to terminal, bypassing ncurses
  ssize_t r = write (STDOUT_FILENO, seq.data (), seq.size ());
  (void)r;
}

// Read clipboard via OSC 52 (with timeout)
static std::string
osc52_paste (int timeout_ms = 500)
{
  // Request clipboard: ESC ] 52 ; c ; ? BEL
  const char *req = "\033]52;c;?\a";
  ssize_t r = write (STDOUT_FILENO, req, strlen (req));
  (void)r;

  // Read response: ESC ] 52 ; c ; BASE64 BEL (or ST)
  // We need raw mode — ncurses is already in raw mode
  std::string resp;
  struct timeval tv;
  fd_set fds;
  int start_ms = timeout_ms;

  while (timeout_ms > 0)
    {
      FD_ZERO (&fds);
      FD_SET (STDIN_FILENO, &fds);
      tv.tv_sec = timeout_ms / 1000;
      tv.tv_usec = (timeout_ms % 1000) * 1000;
      int ret = select (STDIN_FILENO + 1, &fds, 0, 0, &tv);
      if (ret <= 0)
        break;
      char buf[256];
      int n = read (STDIN_FILENO, buf, sizeof buf);
      if (n <= 0)
        break;
      resp.append (buf, n);
      // Check for terminator: BEL (\a=0x07) or ST (ESC \)
      if (resp.find ('\a') != std::string::npos)
        break;
      if (resp.find ("\033\\") != std::string::npos)
        break;
      // Reduce timeout for subsequent reads
      timeout_ms = start_ms / 5;
    }

  // Parse: look for ESC ] 52 ; c ; then base64 until BEL or ST
  size_t pos = resp.find ("\033]52;c;");
  if (pos == std::string::npos)
    pos = resp.find ("\033]52;p;");  // primary selection
  if (pos == std::string::npos)
    return "";  // No valid response
  pos += 7;  // skip past "ESC]52;c;"
  size_t end = resp.find ('\a', pos);
  if (end == std::string::npos)
    {
      end = resp.find ("\033\\", pos);
      if (end == std::string::npos)
        end = resp.size ();
    }
  std::string b64 = resp.substr (pos, end - pos);
  return base64_decode (b64);
}

lisp Fcopy_to_clipboard (lisp string)
{
  check_string (string);
  if (!xstring_length (string))
    return Qnil;

  std::string utf8 = utf16_to_utf8 (xstring_contents (string),
                                        xstring_length (string));
  g_clipboard_buf = utf8;
  osc52_copy (utf8);
  return Qt;
}

lisp Fget_clipboard_data ()
{
  // Try OSC 52 read first — but only if terminal likely supports it.
  // For now, skip OSC 52 read and use internal buffer to avoid 500ms delay.
  // TODO: detect OSC 52 read support and enable conditionally.
  std::string utf8 = g_clipboard_buf;
  if (utf8.empty ())
    return Qnil;
  return utf8_to_internal_string (utf8);
}

lisp Fclipboard_empty_p ()
{
  return boole (g_clipboard_buf.empty ());
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

// Window management
lisp Fselected_window () { return selected_window () ? selected_window ()->lwp : Qnil; }

lisp
Fwindow_buffer (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  return wp->w_bufp ? wp->w_bufp->lbp : Qnil;
}

lisp
Fwindow_height (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  int h = wp->w_rect.bottom - wp->w_rect.top - 1;
  return make_fixnum (max (h, 1));
}

lisp
Fwindow_width (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  return make_fixnum (max ((int)wp->w_ech.cx, 1));
}

lisp
Fwindow_lines (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  int h = wp->w_rect.bottom - wp->w_rect.top - 1;
  return make_fixnum (max (h, 1));
}

lisp
Fwindow_columns (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  int w = wp->w_ech.cx;
  if (wp->flags () & Window::WF_LINE_NUMBER)
    w -= Window::LINENUM_COLUMNS + 1;
  return make_fixnum (max (w, 1));
}

lisp
Fwindow_coordinate (lisp lwindow)
{
  Window *wp = Window::coerce_to_window (lwindow);
  return make_list (make_fixnum (wp->w_rect.left),
                    make_fixnum (wp->w_rect.top),
                    make_fixnum (wp->w_rect.right),
                    make_fixnum (wp->w_rect.bottom),
                    0);
}

lisp
Fget_window_line (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  return make_fixnum (wp->w_bufp->b_fold_columns == Buffer::FOLD_NONE
                      ? (wp->w_bufp->point_linenum (wp->w_point)
                         - wp->w_bufp->point_linenum (wp->w_disp))
                      : (wp->w_bufp->folded_point_linenum (wp->w_point)
                         - wp->w_bufp->folded_point_linenum (wp->w_disp)));
}

lisp
Fget_window_start_line (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  return make_fixnum (wp->w_bufp->b_fold_columns == Buffer::FOLD_NONE
                      ? wp->w_bufp->point_linenum (wp->w_disp)
                      : wp->w_bufp->folded_point_linenum (wp->w_disp));
}

lisp Fget_window_handle (lisp) { return Qnil; }
lisp Fget_window_flags () { return make_fixnum (0); }
lisp Fset_window_flags (lisp) { return Qnil; }
lisp Fget_local_window_flags (lisp) { return make_fixnum (0); }
lisp Fset_local_window_flags (lisp, lisp, lisp) { return Qnil; }

lisp
Fset_window (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  wp->set_window ();
  return Qt;
}

lisp
Fsplit_window (lisp arg, lisp verticalp)
{
  selected_window ()->split (!arg || arg == Qnil || arg == Qt ? 0 : fixnum_value (arg),
                             verticalp && verticalp != Qnil);
  return Qt;
}

lisp
Fdelete_window ()
{
  return boole (selected_window ()->delete_window ());
}

lisp
Fdelete_other_windows ()
{
  selected_window ()->delete_other_windows ();
  return Qt;
}

lisp
Fenlarge_window (lisp nlines, lisp side)
{
  int n = (!nlines || nlines == Qnil) ? 1 : fixnum_value (nlines);
  int vert = side && side != Qnil;
  Window *wp = selected_window ();
  Window *mini = Window::minibuffer_window ();

  if (!n)
    return Qt;

  if (!vert)
    {
      // Horizontal resize: change height
      // Find neighbor above or below
      Window *neighbor = 0;
      for (Window *w = app.active_frame.windows; w && w != mini; w = w->w_next)
        if (w != wp && w->w_rect.top == wp->w_rect.bottom
            && w->w_rect.left < wp->w_rect.right
            && w->w_rect.right > wp->w_rect.left)
          { neighbor = w; break; }
      if (!neighbor)
        for (Window *w = app.active_frame.windows; w && w != mini; w = w->w_next)
          if (w != wp && w->w_rect.bottom == wp->w_rect.top
              && w->w_rect.left < wp->w_rect.right
              && w->w_rect.right > wp->w_rect.left)
            { neighbor = w; break; }
      if (!neighbor)
        FEsimple_error (Ecannot_change_window_size);

      int nh = neighbor->w_rect.bottom - neighbor->w_rect.top - 1 - n;
      if (nh < 2)
        FEsimple_error (Ecannot_change_window_size);

      if (neighbor->w_rect.top == wp->w_rect.bottom)
        {
          wp->w_rect.bottom += n;
          neighbor->w_rect.top += n;
        }
      else
        {
          wp->w_rect.top -= n;
          neighbor->w_rect.bottom -= n;
        }
    }
  else
    {
      // Vertical resize: change width
      Window *neighbor = 0;
      for (Window *w = app.active_frame.windows; w && w != mini; w = w->w_next)
        if (w != wp && w->w_rect.left == wp->w_rect.right
            && w->w_rect.top < wp->w_rect.bottom
            && w->w_rect.bottom > wp->w_rect.top)
          { neighbor = w; break; }
      if (!neighbor)
        for (Window *w = app.active_frame.windows; w && w != mini; w = w->w_next)
          if (w != wp && w->w_rect.right == wp->w_rect.left
              && w->w_rect.top < wp->w_rect.bottom
              && w->w_rect.bottom > wp->w_rect.top)
            { neighbor = w; break; }
      if (!neighbor)
        FEsimple_error (Ecannot_change_window_size);

      int nw = neighbor->w_rect.right - neighbor->w_rect.left - n;
      if (nw < 5)
        FEsimple_error (Ecannot_change_window_size);

      if (neighbor->w_rect.left == wp->w_rect.right)
        {
          wp->w_rect.right += n;
          neighbor->w_rect.left += n;
        }
      else
        {
          wp->w_rect.left -= n;
          neighbor->w_rect.right -= n;
        }
    }

  Window::compute_geometry ();
  return Qt;
}

lisp
Fnext_window (lisp window, lisp minibufp)
{
  Window *wp = Window::coerce_to_window (window);
  if (!minibufp)
    minibufp = Qnil;
  Window *next = wp->w_next;
  if (!next
      || (!next->w_bufp && minibufp != Qt)
      || (next->minibuffer_window_p ()
          && minibufp != Qnil && minibufp != Qt))
    next = app.active_frame.windows;
  return next->lwp;
}

lisp
Fprevious_window (lisp window, lisp minibufp)
{
  Window *wp = Window::coerce_to_window (window);
  if (!minibufp)
    minibufp = Qnil;
  Window *prev = wp->w_prev;
  if (!prev)
    prev = Window::minibuffer_window ();
  if ((!prev->w_bufp && minibufp != Qt)
      || (prev->minibuffer_window_p ()
          && minibufp != Qnil && minibufp != Qt))
    prev = prev->w_prev;
  return prev->lwp;
}

lisp
Fdeleted_window_p (lisp window)
{
  check_window (window);
  return boole (!xwindow_wp (window));
}

lisp Fpos_not_visible_in_window_p (lisp, lisp) { return Qnil; }

// Screen
lisp
Fscreen_height ()
{
  int rows, cols;
  getmaxyx (stdscr, rows, cols);
  return make_fixnum (rows);
}

lisp
Fscreen_width ()
{
  int rows, cols;
  getmaxyx (stdscr, rows, cols);
  return make_fixnum (cols);
}

lisp Frefresh_screen (lisp) { refresh_screen (1); return Qnil; }

// Minibuffer
lisp
Fminibuffer_window ()
{
  Window *mini = Window::minibuffer_window ();
  return mini ? mini->lwp : Qnil;
}

lisp
Fminibuffer_window_p (lisp window)
{
  check_window (window);
  return boole (xwindow_wp (window) && xwindow_wp (window)->minibuffer_window_p ());
}

lisp
Fminibuffer_buffer (lisp window)
{
  Window *mini = Window::minibuffer_window ();
  return (mini && mini->w_bufp) ? mini->w_bufp->lbp : Qnil;
}
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
  int complete_filename_scan (const wchar_t *, lisp, lisp);
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
      memcpy (xstring_contents (d), xstring_contents (s),
              xstring_length (s) * sizeof (*(xstring_contents (s))));
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

  const ucs4_t *p = xstring_contents (c_item) + c_target_len;
  const ucs4_t *pe = xstring_contents (c_item) + c_match_len;

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
  /* **バッファは ucs4_t で取る。** ここは `Char *b = alloca (sizeof (Char) * l)`
     と書いてあり、`Char` は 2 バイト (src/core/cdecl.h) なのに、そこへ
     `sizeof (*(xstring_contents (...)))` = ucs4_t の 4 バイト単位で
     memcpy していた。**必要な半分しか確保していないスタックへ書いていた**
     ことになる。添字も Char 単位で進むので位置も合わない。

     Win32 側 (src/frontend/win32/minibuf.cc) は ucs4_t へ移してあり、こちらは
     移す前のコードが残っていた。ファイル名の補完で落ちる (Linux ネイティブ
     ビルドで Lisp テストスイートが signal 11 で死ぬ 2 番目の原因、issue #49)。
     短い名前だと alloca の余りに収まって表に出ないので、**長いパスと
     マルチバイトの名前で初めて落ちる。** */
  int l = xstring_length (prefix) + c_match_len;
  ucs4_t *b = (ucs4_t *)alloca (sizeof (ucs4_t) * l);
  memcpy (b, xstring_contents (prefix),
          xstring_length (prefix) * sizeof (ucs4_t));
  if (stringp (c_item))
    memcpy (b + xstring_length (prefix), xstring_contents (c_item),
            c_match_len * sizeof (ucs4_t));
  if (l == xstring_length (c_string)
      && !memcmp (b, xstring_contents (c_string), l * sizeof (ucs4_t)))
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

  ucs4_t *b = xstring_contents (c_target);
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
completion::complete_filename_scan (const wchar_t *path, lisp show_dots, lisp ignores)
{
  int ignored = 0;

  /* Room for the '/' that gets appended to directory names. */
  WIN32_FIND_DATAW *fd = (WIN32_FIND_DATAW *)alloca (sizeof *fd + 2 * sizeof (wchar_t));
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
        wcscat (fd->cFileName, L"/");
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
  const ucs4_t *p0 = xstring_contents (c_target);
  const ucs4_t *pe = p0 + xstring_length (c_target);
  const ucs4_t *p;
  for (p = pe; p > p0 && p[-1] != '/'; p--)
    ;
  set_target (make_string (p, pe - p));

  if (!c_target_len)
    {
      lisp x = Fnamestring (make_string (p0, p - p0));
      if (xstring_length (x)
          && xstring_contents (x)[xstring_length (x) - 1] != '/')
        {
          ucs4_t *b = (ucs4_t *)xmalloc ((xstring_length (x) + 1) * sizeof (ucs4_t));
          memcpy (b, xstring_contents (x),
                  xstring_length (x) * sizeof (*(xstring_contents (x))));
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

  wchar_t *path = (wchar_t *)alloca ((i2wl (xstring_contents (directory),
                                            xstring_length (directory)) + 2)
                                     * sizeof (wchar_t));
  i2w (xstring_contents (directory), xstring_length (directory), path);
  wcscat (path, L"*");

  {
    char tb[128];
    if (stringp (c_target))
      w2s (tb, tb + sizeof tb - 1, c_target);
    else
      tb[0] = 0;
    displog ("complete_filename: dir=\"%ls\" target=\"%s\" tlen=%d\n",
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

// Popup — non-modal tooltip-like text display
lisp
Fpopup_string (lisp lstring, lisp lpoint, lisp ltimeout)
{
  g_popup_continue = 0;

  // Parse timeout (seconds → ms, -1 = infinite)
  int timeout = -1;
  if (ltimeout && ltimeout != Qnil)
    timeout = fixnum_value (ltimeout);

  check_string (lstring);
  const ucs4_t *str = xstring_contents (lstring);
  int slen = xstring_length (lstring);

  // Erase any existing popup
  do_erase_popup ();

  if (slen == 0)
    return Qnil;

  // Split into lines at '\n' and compute display widths
  struct line_info {
    int start;
    int len;
    int display_width;
  };
  // Count lines
  int nlines = 1;
  for (int i = 0; i < slen; i++)
    if (str[i] == '\n')
      nlines++;

  line_info *lines = (line_info *)alloca (nlines * sizeof (line_info));
  int li = 0;
  int line_start = 0;
  int max_width = 0;

  for (int i = 0; i <= slen; i++)
    {
      if (i == slen || str[i] == '\n')
        {
          lines[li].start = line_start;
          lines[li].len = i - line_start;

          // Compute display width via i2w + wcwidth
          int w = 0;
          for (int j = line_start; j < i; j++)
            {
              ucs4_t c = str[j];
              if (c < 0x20)
                continue;
              else if (c < 0x80)
                w++;
              else
                {
                  int cw = wcwidth ((wchar_t)c);
                  w += (cw > 0) ? cw : 1;
                }
            }
          lines[li].display_width = w;
          if (w > max_width)
            max_width = w;

          line_start = i + 1;
          li++;
        }
    }

  // Compute popup dimensions (content + box border)
  int term_rows, term_cols;
  getmaxyx (stdscr, term_rows, term_cols);

  int inner_width = max_width + 2;  // 1 padding each side
  if (inner_width > term_cols - 2)
    inner_width = term_cols - 2;
  if (inner_width < 1)
    inner_width = 1;
  int win_width = inner_width + 2;  // +2 for box borders

  int visible_lines = nlines;
  if (visible_lines > term_rows - 2)
    visible_lines = term_rows - 2;
  if (visible_lines < 1)
    visible_lines = 1;
  int win_height = visible_lines + 2;  // +2 for box borders

  // Position: near cursor at lpoint
  int win_row = 0, win_col = 0;
  Window *wp = selected_window ();
  if (wp)
    {
      int cy, cx;
      glyph_point_to_screen (wp, &cy, &cx);
      int abs_y = wp->w_rect.top + cy + 1;  // below cursor
      int abs_x = wp->w_rect.left + cx;

      if (abs_y + win_height <= term_rows - 1)
        win_row = abs_y;
      else
        {
          // Place above cursor
          win_row = wp->w_rect.top + cy - win_height;
          if (win_row < 0)
            win_row = 0;
        }
      win_col = abs_x;
    }

  // Clamp to screen
  if (win_col + win_width > term_cols)
    win_col = term_cols - win_width;
  if (win_col < 0)
    win_col = 0;
  if (win_row + win_height > term_rows)
    win_row = term_rows - win_height;
  if (win_row < 0)
    win_row = 0;

  // Create ncurses window
  WINDOW *win = newwin (win_height, win_width, win_row, win_col);
  if (!win)
    return Qnil;

  wattron (win, A_REVERSE);
  box (win, 0, 0);

  // Draw text lines
  for (int i = 0; i < visible_lines; i++)
    {
      wmove (win, i + 1, 1);
      // Clear inner area
      for (int j = 0; j < inner_width; j++)
        waddch (win, ' ');
      wmove (win, i + 1, 2);  // 1 border + 1 padding

      int col = 0;
      for (int j = 0; j < lines[i].len && col < inner_width - 1; j++)
        {
          Char c = str[lines[i].start + j];
          if (c < 0x20)
            continue;
          else if (c < 0x80)
            {
              waddch (win, (chtype)c);
              col++;
            }
          else
            {
              ucs2_t wc = i2w (c);
              int cw = wcwidth ((wchar_t)wc);
              if (cw <= 0) cw = 1;
              if (col + cw > inner_width - 1) break;
              wchar_t ws[2] = {(wchar_t)wc, 0};
              waddnwstr (win, ws, 1);
              col += cw;
            }
        }
    }

  wattroff (win, A_REVERSE);
  wrefresh (win);

  // Store state
  g_popup_win = win;
  g_popup_timeout_ms = (timeout > 0) ? timeout * 1000 : -1;
  gettimeofday (&g_popup_start, 0);
  g_popup_continue = 1;

  return Qt;
}

lisp
Fcontinue_popup ()
{
  g_popup_continue = 1;
  return Qt;
}

extern volatile int g_need_resize;
void refresh_screen (int);

lisp
Fpopup_list (lisp list, lisp callback, lisp lpoint)
{
  if (!consp (list))
    return Qnil;

  // Validate strings and count items
  int nitems = 0;
  for (lisp p = list; consp (p); p = xcdr (p))
    {
      check_string (xcar (p));
      nitems++;
    }
  if (nitems == 0)
    return Qnil;

  // Collect strings and compute max display width
  struct popup_item {
    const ucs4_t *str;
    int len;
    int display_width;
    lisp lstr;
  };
  popup_item *items = (popup_item *)alloca (nitems * sizeof (popup_item));

  int max_width = 0;
  int idx = 0;
  for (lisp p = list; consp (p); p = xcdr (p), idx++)
    {
      lisp s = xcar (p);
      items[idx].str = xstring_contents (s);
      items[idx].len = xstring_length (s);
      items[idx].lstr = s;

      // Compute display width via i2w + wcwidth
      int w = 0;
      for (int i = 0; i < items[idx].len; i++)
        {
          ucs4_t c = items[idx].str[i];
          if (c < 0x20)
            continue;
          else if (c < 0x80)
            w++;
          else
            {
              int cw = wcwidth ((wchar_t)c);
              w += (cw > 0) ? cw : 1;
            }
        }
      items[idx].display_width = w;
      if (w > max_width)
        max_width = w;
    }

  // Compute popup dimensions
  int term_rows, term_cols;
  getmaxyx (stdscr, term_rows, term_cols);

  int inner_width = max_width + 2;  // padding
  if (inner_width < 13)
    inner_width = 13;
  if (inner_width > term_cols - 2)
    inner_width = term_cols - 2;
  int win_width = inner_width + 2;  // +2 for box borders

  int max_visible = 10;
  int visible = nitems < max_visible ? nitems : max_visible;
  int win_height = visible + 2;  // +2 for box borders

  // Compute position: bottom-aligned above last row (minibuffer area)
  int win_row = term_rows - 1 - win_height;
  if (win_row < 0)
    win_row = 0;
  int win_col = 0;

  // Try to position near cursor in minibuffer
  Window *sel = selected_window ();
  if (sel && sel->minibuffer_window_p ())
    {
      // Place at left edge of screen, above minibuffer
      win_col = 0;
    }
  else if (sel)
    {
      // Position near cursor in editing window
      int cy, cx;
      glyph_point_to_screen (sel, &cy, &cx);
      int abs_y = sel->w_rect.top + cy + 1;  // +1 below cursor
      int abs_x = sel->w_rect.left + cx;

      // Check if there's room below cursor
      if (abs_y + win_height <= term_rows - 1)
        win_row = abs_y;
      else
        {
          // Place above cursor
          win_row = sel->w_rect.top + cy - win_height;
          if (win_row < 0)
            win_row = 0;
        }
      win_col = abs_x;
    }

  // Clamp to screen
  if (win_col + win_width > term_cols)
    win_col = term_cols - win_width;
  if (win_col < 0)
    win_col = 0;
  if (win_row + win_height > term_rows)
    win_row = term_rows - win_height;
  if (win_row < 0)
    win_row = 0;

  // Create ncurses window
  WINDOW *win = newwin (win_height, win_width, win_row, win_col);
  if (!win)
    return Qnil;

  keypad (win, TRUE);
  box (win, 0, 0);

  int sel_idx = 0;
  int scroll_offset = 0;

  // Draw helper
  auto draw_items = [&]() {
    for (int i = 0; i < visible; i++)
      {
        int item_idx = scroll_offset + i;
        wmove (win, i + 1, 1);

        if (item_idx == sel_idx)
          wattron (win, A_REVERSE);

        // Clear line
        for (int j = 0; j < inner_width; j++)
          waddch (win, ' ');

        wmove (win, i + 1, 1);

        // Render string via i2w
        int col = 0;
        if (item_idx < nitems)
          {
            for (int j = 0; j < items[item_idx].len && col < inner_width; j++)
              {
                Char c = items[item_idx].str[j];
                if (c < 0x20)
                  continue;
                else if (c < 0x80)
                  {
                    waddch (win, (chtype)c);
                    col++;
                  }
                else
                  {
                    ucs2_t wc = i2w (c);
                    int cw = wcwidth ((wchar_t)wc);
                    if (cw <= 0) cw = 1;
                    if (col + cw > inner_width) break;
                    wchar_t ws[2] = {(wchar_t)wc, 0};
                    waddnwstr (win, ws, 1);
                    col += cw;
                  }
              }
          }

        if (item_idx == sel_idx)
          wattroff (win, A_REVERSE);
      }

    // Scroll indicators
    if (scroll_offset > 0)
      mvwaddch (win, 0, win_width / 2, ACS_UARROW);
    else
      mvwaddch (win, 0, win_width / 2, ACS_HLINE);

    if (scroll_offset + visible < nitems)
      mvwaddch (win, win_height - 1, win_width / 2, ACS_DARROW);
    else
      mvwaddch (win, win_height - 1, win_width / 2, ACS_HLINE);

    wrefresh (win);
  };

  draw_items ();

  // Modal key loop
  lisp result = Qnil;
  bool done = false;
  while (!done)
    {
      wint_t wch;
      int ret = wget_wch (win, &wch);

      if (ret == KEY_CODE_YES)
        {
          switch (wch)
            {
            case KEY_UP:
              if (sel_idx > 0)
                {
                  sel_idx--;
                  if (sel_idx < scroll_offset)
                    scroll_offset = sel_idx;
                }
              break;
            case KEY_DOWN:
              if (sel_idx < nitems - 1)
                {
                  sel_idx++;
                  if (sel_idx >= scroll_offset + visible)
                    scroll_offset = sel_idx - visible + 1;
                }
              break;
            case KEY_PPAGE:
              sel_idx -= visible;
              if (sel_idx < 0) sel_idx = 0;
              scroll_offset = sel_idx;
              break;
            case KEY_NPAGE:
              sel_idx += visible;
              if (sel_idx >= nitems) sel_idx = nitems - 1;
              scroll_offset = sel_idx - visible + 1;
              if (scroll_offset < 0) scroll_offset = 0;
              break;
            case KEY_RESIZE:
              g_need_resize = 1;
              done = true;
              continue;
            default:
              done = true;
              continue;
            }
          draw_items ();
        }
      else if (ret == OK)
        {
          // Regular character
          switch (wch)
            {
            case '\r':   // Enter
            case '\n':
            case '\t':   // Tab
              // Confirm selection
              {
                delwin (win);
                win = NULL;
                touchwin (stdscr);
                refresh_screen (1);

                xsymbol_value (Vpopup_list_callback) = callback;
                try
                  {
                    funcall_1 (callback, items[sel_idx].lstr);
                  }
                catch (nonlocal_jump &)
                  {
                    print_condition (nonlocal_jump::data ());
                  }
                result = Qt;
                done = true;
              }
              continue;
            case 0x1b:   // Escape
              done = true;
              continue;
            case 0x07:   // C-g
              done = true;
              continue;
            case 0x10:   // C-p
              if (sel_idx > 0)
                {
                  sel_idx--;
                  if (sel_idx < scroll_offset)
                    scroll_offset = sel_idx;
                }
              break;
            case 0x0e:   // C-n
              if (sel_idx < nitems - 1)
                {
                  sel_idx++;
                  if (sel_idx >= scroll_offset + visible)
                    scroll_offset = sel_idx - visible + 1;
                }
              break;
            case ' ':    // Space — confirm
              {
                delwin (win);
                win = NULL;
                touchwin (stdscr);
                refresh_screen (1);

                xsymbol_value (Vpopup_list_callback) = callback;
                try
                  {
                    funcall_1 (callback, items[sel_idx].lstr);
                  }
                catch (nonlocal_jump &)
                  {
                    print_condition (nonlocal_jump::data ());
                  }
                result = Qt;
                done = true;
              }
              continue;
            default:
              // Unknown key — cancel and push key back
              unget_wch (wch);
              done = true;
              continue;
            }
          draw_items ();
        }
      else
        {
          // ERR — probably signal or timeout
          done = true;
        }
    }

  // Cleanup (for cancel/escape/error paths)
  if (win)
    {
      delwin (win);
      touchwin (stdscr);
      refresh_screen (1);
    }

  return result;
}

// ============================================================
// Menu — ncurses TUI Lisp functions
// ============================================================

lisp
Fcreate_menu (lisp tag)
{
  lisp lmenu = make_win32_menu ();
  xwin32_menu_handle (lmenu) = (HMENU)1;
  xwin32_menu_tag (lmenu) = tag ? tag : Qnil;
  return lmenu;
}

lisp
Fcreate_popup_menu (lisp tag)
{
  lisp lmenu = make_win32_menu ();
  xwin32_menu_handle (lmenu) = (HMENU)1;
  xwin32_menu_tag (lmenu) = tag ? tag : Qnil;
  return lmenu;
}

lisp
Fadd_menu_item (lisp lmenu, lisp tag, lisp item, lisp command, lisp init)
{
  check_popup_menu (lmenu);
  if (item != Kclose_box)
    check_string (item);
  int id;
  lisp litem = create_new_item (id, tag, command, init);
  protect_gc gcpro (litem);
  if (item != Kclose_box)
    xwin32_menu_name (litem) = item;
  xwin32_menu_items (lmenu) = xcons (litem, xwin32_menu_items (lmenu));
  bitset (used_id, id - MENU_ID_RANGE_MIN);
  return litem;
}

lisp
Fadd_menu_separator (lisp lmenu, lisp tag)
{
  check_popup_menu (lmenu);
  lisp litem = make_win32_menu ();
  xwin32_menu_tag (litem) = tag ? tag : Qnil;
  xwin32_menu_items (lmenu) = xcons (litem, xwin32_menu_items (lmenu));
  return litem;
}

lisp
Fadd_popup_menu (lisp lmenu, lisp lpopup, lisp name)
{
  check_popup_menu (lmenu);
  check_string (name);
  check_popup_menu (lpopup);
  xwin32_menu_name (lpopup) = name;
  xwin32_menu_items (lmenu) = xcons (lpopup, xwin32_menu_items (lmenu));
  return lpopup;
}

lisp
Finsert_menu_item (lisp lmenu, lisp position, lisp tag, lisp item,
                   lisp command, lisp init)
{
  check_popup_menu (lmenu);
  if (item != Kclose_box)
    check_string (item);
  int pos = fixnum_value (position);
  if (pos < 0)
    FErange_error (position);
  int id;
  lisp litem = create_new_item (id, tag, command, init);
  protect_gc gcpro (litem);
  if (item != Kclose_box)
    xwin32_menu_name (litem) = item;

  int l = xlist_length (xwin32_menu_items (lmenu));
  if (pos >= l)
    xwin32_menu_items (lmenu) = xcons (litem, xwin32_menu_items (lmenu));
  else
    {
      lisp tem = xcons (litem, Qnil);
      l -= pos;
      lisp p;
      for (p = xwin32_menu_items (lmenu); --l > 0; p = xcdr (p))
        assert (consp (p));
      assert (consp (p));
      xcdr (tem) = xcdr (p);
      xcdr (p) = tem;
    }
  bitset (used_id, id - MENU_ID_RANGE_MIN);
  return litem;
}

lisp
Finsert_menu_separator (lisp lmenu, lisp position, lisp tag)
{
  check_popup_menu (lmenu);
  int pos = fixnum_value (position);
  if (pos < 0)
    FErange_error (position);
  lisp litem = make_win32_menu ();
  xwin32_menu_tag (litem) = tag ? tag : Qnil;

  int l = xlist_length (xwin32_menu_items (lmenu));
  if (pos >= l)
    xwin32_menu_items (lmenu) = xcons (litem, xwin32_menu_items (lmenu));
  else
    {
      lisp tem = xcons (litem, Qnil);
      l -= pos;
      lisp p;
      for (p = xwin32_menu_items (lmenu); --l > 0; p = xcdr (p))
        assert (consp (p));
      assert (consp (p));
      xcdr (tem) = xcdr (p);
      xcdr (p) = tem;
    }
  return litem;
}

lisp
Finsert_popup_menu (lisp lmenu, lisp position, lisp lpopup, lisp name)
{
  check_popup_menu (lmenu);
  check_string (name);
  check_popup_menu (lpopup);
  int pos = fixnum_value (position);
  if (pos < 0)
    FErange_error (position);
  xwin32_menu_name (lpopup) = name;

  int l = xlist_length (xwin32_menu_items (lmenu));
  if (pos >= l)
    xwin32_menu_items (lmenu) = xcons (lpopup, xwin32_menu_items (lmenu));
  else
    {
      lisp tem = xcons (lpopup, Qnil);
      l -= pos;
      lisp p;
      for (p = xwin32_menu_items (lmenu); --l > 0; p = xcdr (p))
        assert (consp (p));
      assert (consp (p));
      xcdr (tem) = xcdr (p);
      xcdr (p) = tem;
    }
  return lpopup;
}

lisp
Fdelete_menu (lisp lmenu, lisp tag, lisp positionp)
{
  int pos;
  lisp item = get_menu (lmenu, tag, positionp, pos);
  if (item != Qnil)
    delq (item, &xwin32_menu_items (lmenu));
  return item;
}

lisp
Fcopy_menu_items (lisp old_menu, lisp new_menu)
{
  check_popup_menu (old_menu);
  check_popup_menu (new_menu);
  if (old_menu == new_menu)
    return new_menu;
  xwin32_menu_items (new_menu) = Fcopy_list (xwin32_menu_items (old_menu));
  return new_menu;
}

lisp
Fset_menu (lisp lmenu)
{
  if (lmenu != Qnil)
    check_popup_menu (lmenu);
  xsymbol_value (Vdefault_menu) = lmenu;
  return lmenu;
}

lisp
Fcurrent_menu (lisp buffer)
{
  if (!buffer)
    return (win32_menu_p (selected_buffer ()->lmenu)
            ? selected_buffer ()->lmenu
            : xsymbol_value (Vdefault_menu));
  else if (buffer == Qnil)
    return xsymbol_value (Vdefault_menu);
  else
    return Buffer::coerce_to_buffer (buffer)->lmenu;
}

lisp
Fget_menu (lisp lmenu, lisp tag, lisp positionp)
{
  int pos;
  return get_menu (lmenu, tag, positionp, pos);
}

lisp
Fget_menu_position (lisp lmenu, lisp tag)
{
  check_popup_menu (lmenu);
  int pos = find_tag_position (lmenu, tag);
  if (pos < 0)
    return Qnil;
  multiple_value::count () = 2;
  multiple_value::value (1) = lmenu;
  return make_fixnum (pos);
}

lisp
Fuse_local_menu (lisp lmenu)
{
  if (lmenu != Qnil)
    check_popup_menu (lmenu);
  selected_buffer ()->lmenu = lmenu;
  return lmenu;
}

// ---- TUI menu rendering helpers ----

struct menu_entry
{
  lisp item;         // lwin32_menu object
  wchar_t label[256];
  int label_len;     // character count
  int display_width; // column width (wcwidth-aware)
  int accel;         // accelerator char (lowercase), 0 if none
  int flags;         // MF_GRAYED / MF_CHECKED etc.
  int is_separator;
  int is_submenu;
  char keybind[64];  // Emacs-style key binding string (e.g. "C-x C-c")
  int keybind_width; // display width of keybind string
};

// Format a single Char as Emacs-style key name. Returns pointer past the written chars.
static char *
keyname_emacs (char *p, Char c)
{
  int meta = 0;

  if (meta_char_p (c))
    {
      meta = 1;
      c = meta_char_to_char (c);
    }
  else if (meta_function_char_p (c))
    {
      meta = 1;
      c = meta_function_to_function (c);
    }

  if (function_char_p (c))
    {
      if (pseudo_ctlchar_p (c))
        {
          p = stpcpy (p, "C-");
          if (meta)
            p = stpcpy (p, "M-");
          *p++ = pseudo_ctl2char_table[c & 0xff];
          *p = 0;
        }
      else
        {
          if (c & CCF_SHIFT_BIT)
            p = stpcpy (p, "S-");
          if (c & CCF_CTRL_BIT)
            p = stpcpy (p, "C-");
          if (meta)
            p = stpcpy (p, "M-");
          const char *x = function_Char2name (c & ~(CCF_SHIFT_BIT | CCF_CTRL_BIT));
          if (x)
            p = stpcpy (p, x);
        }
    }
  else
    {
      const char *x = standard_Char2name (c);
      if (x)
        {
          if (meta)
            p = stpcpy (p, "M-");
          p = stpcpy (p, x);
        }
      else
        {
          if (c < ' ')
            {
              p = stpcpy (p, "C-");
              if (meta)
                p = stpcpy (p, "M-");
              *p++ = _char_downcase (c + '@');
              *p = 0;
            }
          else if (c == CC_DEL)
            {
              p = stpcpy (p, "C-");
              if (meta)
                p = stpcpy (p, "M-");
              *p++ = '?';
              *p = 0;
            }
          else
            {
              if (meta)
                p = stpcpy (p, "M-");
              *p++ = (char)c;
              *p = 0;
            }
        }
    }
  return p;
}

// Look up keybindings for menu items (like Win32 modify_menu_string)
static void
fill_menu_keybinds (menu_entry *entries, int count)
{
  // keybind fields are already zeroed by collect_menu_items.
  // Wrap in try-catch to avoid crashing the menu if keymap lookup fails.
  try
    {
      Buffer *bp = selected_buffer ();
      if (!bp)
        return;

      lisp *map;
      int nmaps = 0;
      long n;

      if (safe_fixnum_value (Flist_length (bp->lminor_map), &n) && n > 0)
        {
          map = (lisp *)alloca (sizeof *map * (n + 3));
          map[nmaps++] = Fcurrent_selection_keymap ();
          for (lisp p = bp->lminor_map; consp (p) && nmaps <= n; nmaps++, p = xcdr (p))
            map[nmaps] = xcar (p);
        }
      else
        {
          map = (lisp *)alloca (sizeof *map * 3);
          map[nmaps++] = Fcurrent_selection_keymap ();
        }
      map[nmaps++] = bp->lmap;
      map[nmaps++] = xsymbol_value (Vglobal_keymap);

      for (int idx = 0; idx < count; idx++)
        {
          menu_entry &e = entries[idx];

          if (e.is_separator || e.is_submenu)
            continue;
          if (!xwin32_menu_id (e.item)
              || xwin32_menu_command (e.item) == Qnil
              || !symbolp (xwin32_menu_command (e.item)))
            continue;

          for (int i = 0; i < nmaps; i++)
            {
              Char b[5];
              Char *be = lookup_command_keyseq (xwin32_menu_command (e.item),
                                                map[i], map, i,
                                                b, b, b + numberof (b));
              if (be)
                {
                  char *p = e.keybind;
                  char *pe = e.keybind + sizeof (e.keybind) - 1;
                  for (const Char *k = b; k < be && p < pe - 16; k++)
                    {
                      if (k != b)
                        *p++ = ' ';
                      p = keyname_emacs (p, *k);
                    }
                  *p = 0;
                  e.keybind_width = (int)strlen (e.keybind);
                  break;
                }
            }
        }
    }
  catch (nonlocal_jump &)
    {
    }
}

#define MAX_SUBMENU_DEPTH 8

struct submenu_level
{
  WINDOW *win;
  menu_entry items[256];
  int count;
  int sel;
  int x, y;   // window position (col, row)
  int width;  // box width
};

static int
collect_menu_items (lisp lmenu, menu_entry *entries, int max_entries, int enablep)
{
  // Items list is stored in reverse order (prepend). Walk it to count, then
  // fill entries in display order (reversed).
  int count = 0;
  for (lisp p = xwin32_menu_items (lmenu); consp (p); p = xcdr (p))
    count++;
  if (count > max_entries)
    count = max_entries;

  // Fill from the end
  int idx = count - 1;
  for (lisp p = xwin32_menu_items (lmenu); consp (p) && idx >= 0; p = xcdr (p), idx--)
    {
      lisp x = xcar (p);
      menu_entry &e = entries[idx];
      e.item = x;
      e.label[0] = 0;
      e.label_len = 0;
      e.display_width = 0;
      e.accel = 0;
      e.flags = MF_ENABLED | MF_UNCHECKED;
      e.is_separator = 0;
      e.is_submenu = 0;
      e.keybind[0] = 0;
      e.keybind_width = 0;

      if (!xwin32_menu_id (x) && !xwin32_menu_handle (x))
        {
          // Separator
          e.is_separator = 1;
          continue;
        }

      if (xwin32_menu_handle (x))
        e.is_submenu = 1;

      // Get label from name field
      lisp name = xwin32_menu_name (x);
      if (stringp (name))
        {
          const ucs4_t *src = xstring_contents (name);
          int slen = xstring_length (name);
          int di = 0;
          for (int si = 0; si < slen && di < 254; si++)
            {
              if (src[si] == '&')
                {
                  // Next char is accelerator
                  if (si + 1 < slen && src[si + 1] != '&')
                    {
                      wchar_t wc = (wchar_t)src[si + 1];
                      e.accel = (wc < 128) ? tolower (wc) : wc;
                    }
                  continue; // Skip '&' marker
                }
              e.label[di++] = (wchar_t)src[si];
            }
          e.label[di] = 0;
          e.label_len = di;
          int dw = 0;
          for (int j = 0; j < di; j++)
            {
              int cw = wcwidth (e.label[j]);
              dw += (cw > 0) ? cw : 1;
            }
          e.display_width = dw;
        }

      // Compute flags
      if (xwin32_menu_id (x))
        {
          if (xwin32_menu_init (x) == Kend_macro)
            e.flags = (app.kbdq.save_p ()
                       ? MF_ENABLED | MF_UNCHECKED
                       : MF_GRAYED | MF_UNCHECKED);
          else if (enablep)
            {
              if (xwin32_menu_init (x) != Qnil)
                e.flags = init_menu_flags (xwin32_menu_init (x));
              else if (xwin32_menu_command (x) == Qnil)
                e.flags = MF_GRAYED | MF_UNCHECKED;
              else
                e.flags = MF_ENABLED | MF_UNCHECKED;
            }
          else
            e.flags = MF_GRAYED | MF_UNCHECKED;
        }
      else if (e.is_submenu)
        {
          // Submenu: enabled if any child is enabled
          suppress_gc sgc;
          if (init_menu_popup_recursive (x, enablep))
            e.flags = MF_ENABLED | MF_UNCHECKED;
          else
            e.flags = MF_GRAYED | MF_UNCHECKED;
        }
    }
  return count;
}

static void
draw_menu_bar_item (int col, const wchar_t *label, int len, int display_width, int selected)
{
  attr_t attr = selected
    ? (A_BOLD | COLOR_PAIR (MENU_SEL_PAIR))
    : COLOR_PAIR (MENU_PAIR);
  attron (attr);
  mvaddch (0, col, ' ');
  move (0, col + 1);
  for (int i = 0; i < len; i++)
    {
      cchar_t cc;
      wchar_t ws[2] = {label[i], 0};
      setcchar (&cc, ws, attr, 0, NULL);
      add_wch (&cc);
    }
  addch (' ');
  attroff (attr);
}

static void
draw_persistent_menu_bar ()
{
  int rows, cols;
  getmaxyx (stdscr, rows, cols);

  // Clear row 0 with menu color background
  attron (COLOR_PAIR (MENU_PAIR));
  move (0, 0);
  for (int i = 0; i < cols; i++)
    addch (' ');
  attroff (COLOR_PAIR (MENU_PAIR));

  lisp lmenu = xsymbol_value (Vdefault_menu);
  if (win32_menu_p (selected_buffer ()->lmenu))
    lmenu = selected_buffer ()->lmenu;
  if (!win32_menu_p (lmenu))
    return;

  menu_entry bar_items[64];
  int bar_count = collect_menu_items (lmenu, bar_items, 64, 1);

  int col = 0;
  for (int i = 0; i < bar_count; i++)
    {
      draw_menu_bar_item (col, bar_items[i].label, bar_items[i].label_len,
                          bar_items[i].display_width, 0);
      col += bar_items[i].display_width + 2;
    }
}

static WINDOW *
draw_dropdown (int bar_x, int top_row, menu_entry *entries, int count, int sel, int *widthp)
{
  // Compute width using display_width (wcwidth-aware)
  int max_label_w = 4;
  int max_keybind_w = 0;
  for (int i = 0; i < count; i++)
    {
      int w = entries[i].display_width;
      if (entries[i].is_submenu)
        w += 2; // space for " >"
      if (w > max_label_w)
        max_label_w = w;
      if (entries[i].keybind_width > max_keybind_w)
        max_keybind_w = entries[i].keybind_width;
    }
  int max_w = max_label_w + (max_keybind_w ? max_keybind_w + 2 : 0);
  int box_w = max_w + 4; // 1 border + 1 pad + content + 1 pad + 1 border
  int box_h = count + 2; // 1 border + items + 1 border

  int rows, cols;
  getmaxyx (stdscr, rows, cols);

  // Clamp horizontal position
  if (bar_x + box_w > cols)
    bar_x = cols - box_w;
  if (bar_x < 0)
    bar_x = 0;

  // Clamp vertical position
  if (top_row + box_h > rows)
    {
      top_row = rows - box_h;
      if (top_row < 0)
        top_row = 0;
    }
  if (top_row + box_h > rows)
    box_h = rows - top_row;

  WINDOW *win = newwin (box_h, box_w, top_row, bar_x);
  if (!win)
    return NULL;

  wbkgd (win, COLOR_PAIR (MENU_PAIR));
  box (win, 0, 0);

  for (int i = 0; i < count && i + 1 < box_h - 1; i++)
    {
      if (entries[i].is_separator)
        {
          mvwhline (win, i + 1, 1, ACS_HLINE, box_w - 2);
          continue;
        }

      attr_t attr = COLOR_PAIR (MENU_PAIR);
      if (i == sel)
        attr = A_BOLD | COLOR_PAIR (MENU_SEL_PAIR);
      if (entries[i].flags & MF_GRAYED)
        attr |= A_DIM;

      wattron (win, attr);
      // Clear the line
      wmove (win, i + 1, 1);
      for (int j = 1; j < box_w - 1; j++)
        waddch (win, ' ');

      // Draw check mark
      if (entries[i].flags & MF_CHECKED)
        mvwaddch (win, i + 1, 1, '*');
      else
        mvwaddch (win, i + 1, 1, ' ');

      // Draw label
      wmove (win, i + 1, 2);
      for (int j = 0; j < entries[i].label_len && j < box_w - 4; j++)
        {
          wchar_t wc = entries[i].label[j];
          cchar_t cc;
          wchar_t ws[2] = {wc, 0};
          setcchar (&cc, ws, attr, 0, NULL);
          wadd_wch (win, &cc);
        }

      // Submenu indicator
      if (entries[i].is_submenu)
        mvwaddch (win, i + 1, box_w - 2, '>');

      // Keybind (right-aligned)
      if (entries[i].keybind_width > 0)
        {
          int kb_col = box_w - 2 - entries[i].keybind_width;
          mvwaddstr (win, i + 1, kb_col, entries[i].keybind);
        }

      wattroff (win, attr);
    }

  wrefresh (win);
  if (widthp)
    *widthp = box_w;
  return win;
}

// Find first selectable item in a submenu level
static int
find_first_selectable (menu_entry *items, int count)
{
  for (int i = 0; i < count; i++)
    if (!items[i].is_separator && !(items[i].flags & MF_GRAYED))
      return i;
  for (int i = 0; i < count; i++)
    if (!items[i].is_separator)
      return i;
  return -1;
}

// Open a submenu from parent level's selected item
static int
open_submenu (submenu_level *stack, int depth)
{
  if (depth >= MAX_SUBMENU_DEPTH - 1)
    return 0;
  submenu_level &parent = stack[depth];
  if (parent.sel < 0 || parent.sel >= parent.count)
    return 0;
  menu_entry &pe = parent.items[parent.sel];
  if (!pe.is_submenu)
    return 0;

  submenu_level &child = stack[depth + 1];
  child.count = collect_menu_items (pe.item, child.items, 256, 1);
  if (child.count == 0)
    return 0;
  fill_menu_keybinds (child.items, child.count);
  child.sel = find_first_selectable (child.items, child.count);

  // Position: right of parent, aligned to parent's selected row
  child.x = parent.x + parent.width;
  child.y = parent.y + parent.sel; // align with parent item row

  child.win = draw_dropdown (child.x, child.y, child.items, child.count,
                             child.sel, &child.width);
  return 1;
}

// Close submenu at given depth
static void
close_submenu (submenu_level *stack, int depth)
{
  submenu_level &lvl = stack[depth];
  if (lvl.win)
    {
      delwin (lvl.win);
      lvl.win = NULL;
    }
  lvl.count = 0;
  lvl.sel = -1;
}

// Redraw a single submenu level
static void
redraw_level (submenu_level &lvl)
{
  if (lvl.win)
    {
      delwin (lvl.win);
      lvl.win = NULL;
    }
  lvl.win = draw_dropdown (lvl.x, lvl.y, lvl.items, lvl.count,
                           lvl.sel, &lvl.width);
}

// Close all submenus from depth down to (but not including) keep_depth,
// then refresh screen and redraw remaining levels
static void
close_submenus_above (submenu_level *stack, int &depth, int keep_depth)
{
  for (int d = depth; d > keep_depth; d--)
    close_submenu (stack, d);
  depth = keep_depth;
  touchwin (stdscr);
  refresh ();
  for (int d = 0; d <= depth; d++)
    if (stack[d].win)
      {
        // Redraw without deleting first — just recreate
        delwin (stack[d].win);
        stack[d].win = draw_dropdown (stack[d].x, stack[d].y, stack[d].items,
                                      stack[d].count, stack[d].sel,
                                      &stack[d].width);
      }
}

// Determine which menu item index was clicked at screen (row, col)
// for a submenu_level. Returns -1 if outside, -2 if on border/separator.
static int
menu_item_at (submenu_level &lvl, int row, int col)
{
  if (!lvl.win || lvl.count == 0)
    return -1;
  // Box: top-left at (lvl.y, lvl.x), width=lvl.width, height=lvl.count+2
  if (col < lvl.x || col >= lvl.x + lvl.width)
    return -1;
  if (row <= lvl.y || row >= lvl.y + lvl.count + 1)
    return -1;
  int idx = row - lvl.y - 1;  // item index (0-based)
  if (idx < 0 || idx >= lvl.count)
    return -1;
  if (lvl.items[idx].is_separator)
    return -2;
  return idx;
}

// Determine which bar item index was clicked at screen row 0
static int
bar_item_at (menu_entry *bar_items, int bar_count, int col)
{
  int x = 0;
  for (int i = 0; i < bar_count; i++)
    {
      int w = bar_items[i].display_width + 2;
      if (col >= x && col < x + w)
        return i;
      x += w;
    }
  return -1;
}

static lisp
run_menu_modal (lisp menu_root, int initial_bar_sel = -1)
{
  // Collect top-level bar items
  menu_entry bar_items[64];
  int bar_count = collect_menu_items (menu_root, bar_items, 64, 1);
  if (bar_count == 0)
    return Qnil;

  int bar_sel = (initial_bar_sel >= 0 && initial_bar_sel < bar_count)
                ? initial_bar_sel : 0;
  lisp result = Qnil;
  int drop_open = (initial_bar_sel >= 0) ? 1 : 0;
  int need_redraw_bar = 1;
  int need_redraw_drop = drop_open ? 1 : 0;
  int running = 1;

  // Submenu stack: heap-allocated to avoid ~1.2MB stack usage
  submenu_level *stack = new submenu_level[MAX_SUBMENU_DEPTH];
  memset (stack, 0, sizeof (submenu_level) * MAX_SUBMENU_DEPTH);
  for (int i = 0; i < MAX_SUBMENU_DEPTH; i++)
    stack[i].sel = -1;
  int depth = 0; // current deepest open level (0 = first dropdown)

  while (running)
    {
      if (need_redraw_bar)
        {
          int rows2, cols2;
          getmaxyx (stdscr, rows2, cols2);
          attron (COLOR_PAIR (MENU_PAIR));
          move (0, 0);
          for (int i = 0; i < cols2; i++)
            addch (' ');
          attroff (COLOR_PAIR (MENU_PAIR));
          int col = 0;
          for (int i = 0; i < bar_count; i++)
            {
              draw_menu_bar_item (col, bar_items[i].label, bar_items[i].label_len,
                                  bar_items[i].display_width, i == bar_sel);
              col += bar_items[i].display_width + 2;
            }
          refresh ();
          need_redraw_bar = 0;
        }

      if (need_redraw_drop)
        {
          // Close all existing submenus
          for (int d = depth; d >= 0; d--)
            close_submenu (stack, d);
          depth = 0;

          touchwin (stdscr);
          refresh ();

          if (drop_open && bar_items[bar_sel].is_submenu)
            {
              submenu_level &lvl = stack[0];
              lvl.count = collect_menu_items (bar_items[bar_sel].item, lvl.items, 256, 1);
              fill_menu_keybinds (lvl.items, lvl.count);
              lvl.sel = find_first_selectable (lvl.items, lvl.count);

              int bar_x = 0;
              for (int i = 0; i < bar_sel; i++)
                bar_x += bar_items[i].display_width + 2;

              lvl.x = bar_x;
              lvl.y = 1; // just below menu bar
              lvl.win = draw_dropdown (lvl.x, lvl.y, lvl.items, lvl.count,
                                       lvl.sel, &lvl.width);
            }
          else if (!drop_open)
            {
              stack[0].count = 0;
              stack[0].sel = -1;
            }
          need_redraw_drop = 0;
        }

      int ch = getch ();
      displog ("menu_modal: ch=%d (0x%x)\n", ch, ch);
      submenu_level &cur = stack[depth];

      switch (ch)
        {
        case KEY_LEFT:
        case 2: // C-b
          if (drop_open && depth > 0)
            {
              // Go back to parent submenu
              close_submenu (stack, depth);
              depth--;
              touchwin (stdscr);
              refresh ();
              for (int d = 0; d <= depth; d++)
                redraw_level (stack[d]);
            }
          else
            {
              // Move to previous bar item
              bar_sel = (bar_sel + bar_count - 1) % bar_count;
              need_redraw_bar = 1;
              if (drop_open)
                need_redraw_drop = 1;
            }
          break;

        case KEY_RIGHT:
        case 6: // C-f
          if (drop_open && cur.sel >= 0 && cur.sel < cur.count
              && cur.items[cur.sel].is_submenu
              && !(cur.items[cur.sel].flags & MF_GRAYED))
            {
              // Open submenu
              if (open_submenu (stack, depth))
                depth++;
            }
          else
            {
              // Move to next bar item
              bar_sel = (bar_sel + 1) % bar_count;
              need_redraw_bar = 1;
              if (drop_open)
                need_redraw_drop = 1;
            }
          break;

        case KEY_UP:
        case 16: // C-p
          if (drop_open && cur.count > 0)
            {
              int start = cur.sel;
              do
                cur.sel = (cur.sel + cur.count - 1) % cur.count;
              while (cur.items[cur.sel].is_separator && cur.sel != start);
              redraw_level (cur);
            }
          break;

        case KEY_DOWN:
        case 14: // C-n
          if (!drop_open)
            {
              drop_open = 1;
              need_redraw_drop = 1;
            }
          else if (cur.count > 0)
            {
              int start = cur.sel;
              do
                cur.sel = (cur.sel + 1) % cur.count;
              while (cur.items[cur.sel].is_separator && cur.sel != start);
              redraw_level (cur);
            }
          break;

        case '\r':
        case '\n':
        case KEY_ENTER:
          if (!drop_open)
            {
              drop_open = 1;
              need_redraw_drop = 1;
            }
          else if (cur.sel >= 0 && cur.sel < cur.count
                   && !cur.items[cur.sel].is_separator
                   && !(cur.items[cur.sel].flags & MF_GRAYED))
            {
              if (cur.items[cur.sel].is_submenu)
                {
                  if (open_submenu (stack, depth))
                    depth++;
                }
              else
                {
                  result = cur.items[cur.sel].item;
                  running = 0;
                }
            }
          else
            running = 0;
          break;

        case 27: // ESC
        case 7:  // C-g
          running = 0;
          break;

        case KEY_MOUSE:
          {
            MEVENT mev;
            if (getmouse (&mev) == OK)
              {
                int mrow = mev.y, mcol = mev.x;
                displog ("menu_mouse: row=%d col=%d bstate=0x%lx\n",
                         mrow, mcol, (unsigned long)mev.bstate);
                int clicked = (mev.bstate & (BUTTON1_PRESSED | BUTTON1_CLICKED));
                if (!clicked)
                  {
                    // Ignore release events silently
                    if (mev.bstate & (BUTTON1_RELEASED | BUTTON2_RELEASED
                                      | BUTTON3_RELEASED | REPORT_MOUSE_POSITION))
                      {
                        displog ("menu_mouse: ignored release/motion\n");
                        break;
                      }
                    // Non-left-button click → close menu
                    displog ("menu_mouse: non-left → close\n");
                    running = 0;
                    break;
                  }

                // Check bar items (row 0)
                if (mrow == 0)
                  {
                    int bi = bar_item_at (bar_items, bar_count, mcol);
                    if (bi >= 0)
                      {
                        bar_sel = bi;
                        drop_open = 1;
                        need_redraw_bar = 1;
                        need_redraw_drop = 1;
                      }
                    break;
                  }

                // Check dropdown items from deepest to shallowest
                int handled = 0;
                for (int d = depth; d >= 0; d--)
                  {
                    int idx = menu_item_at (stack[d], mrow, mcol);
                    if (idx >= 0)
                      {
                        // Close deeper levels
                        if (d < depth)
                          close_submenus_above (stack, depth, d);

                        stack[d].sel = idx;
                        redraw_level (stack[d]);

                        if (stack[d].items[idx].is_submenu
                            && !(stack[d].items[idx].flags & MF_GRAYED))
                          {
                            if (open_submenu (stack, d))
                              depth = d + 1;
                          }
                        else if (!(stack[d].items[idx].flags & MF_GRAYED))
                          {
                            result = stack[d].items[idx].item;
                            running = 0;
                          }
                        handled = 1;
                        break;
                      }
                    else if (idx == -2)
                      {
                        displog ("menu_mouse: separator click\n");
                        handled = 1; // clicked separator, ignore
                        break;
                      }
                  }
                if (!handled)
                  {
                    displog ("menu_mouse: outside → close\n");
                    running = 0;  // clicked outside all menus → close
                  }
              }
          }
          break;

        default:
          if (ch > 0 && ch < 256)
            {
              int lch = tolower (ch);
              int matched = 0;

              // Check deepest open level first
              if (drop_open && cur.count > 0)
                {
                  for (int i = 0; i < cur.count; i++)
                    if (cur.items[i].accel == lch
                        && !cur.items[i].is_separator
                        && !(cur.items[i].flags & MF_GRAYED))
                      {
                        matched = 1;
                        if (cur.items[i].is_submenu)
                          {
                            cur.sel = i;
                            redraw_level (cur);
                            if (open_submenu (stack, depth))
                              depth++;
                          }
                        else
                          {
                            result = cur.items[i].item;
                            running = 0;
                          }
                        break;
                      }
                }

              if (!matched && running)
                {
                  for (int i = 0; i < bar_count; i++)
                    if (bar_items[i].accel == lch)
                      {
                        bar_sel = i;
                        drop_open = 1;
                        need_redraw_bar = 1;
                        need_redraw_drop = 1;
                        matched = 1;
                        break;
                      }
                }
            }
          break;
        }
    }

  // Cleanup all open submenus
  for (int d = depth; d >= 0; d--)
    close_submenu (stack, d);
  delete[] stack;

  // Post menu command to keyboard queue (like Win32 WM_COMMAND handler).
  // This lets dispatch() handle it via LCHAR_MENU path, which doesn't
  // process interactive specs — avoiding issues with (interactive "p").
  if (result != Qnil)
    {
      int id = xwin32_menu_id (result);
      if (id >= MENU_ID_RANGE_MIN && id < MENU_ID_RANGE_MAX)
        {
          // Preserve selection state: set CONTINUE_PRE_SELECTION *before*
          // refresh_screen, so render_window doesn't clear the selection.
          // dispatch() will clear it after the command runs.
          Window *wp = selected_window ();
          if (wp && (wp->w_selection_type & Buffer::PRE_SELECTION))
            (int &)wp->w_selection_type |= Buffer::CONTINUE_PRE_SELECTION;
          app.kbdq.putc (LCHAR_MENU | id);
        }
    }

  // Drain stale mouse events left over from menu interaction.
  // Without this, the menu click's release/motion events leak into
  // the editor and corrupt selection state (e.g. moving point to the
  // menu area coordinates).
  {
    MEVENT mev;
    nodelay (stdscr, TRUE);
    wint_t wch;
    while (wget_wch (stdscr, &wch) != ERR)
      {
        if (wch == KEY_MOUSE)
          getmouse (&mev);  // consume and discard
        else
          {
            // Non-mouse key: put it back
            unget_wch (wch);
            break;
          }
      }
    nodelay (stdscr, FALSE);
  }

  touchwin (stdscr);
  refresh_screen (1);
  return Qnil;
}

lisp
Fcall_menu (lisp)
{
  lisp lmenu = xsymbol_value (Vdefault_menu);
  if (!win32_menu_p (lmenu))
    return Qnil;

  // Check buffer-local menu
  if (win32_menu_p (selected_buffer ()->lmenu))
    lmenu = selected_buffer ()->lmenu;

  // Set last_active_menu persistently (not dynamic_bind) so that
  // lookup_menu_command can find the command when dispatch() processes
  // the LCHAR_MENU posted to kbdq after we return.
  xsymbol_value (Vlast_active_menu) = lmenu;
  return run_menu_modal (lmenu);
}

static lisp
run_popup_modal (lisp lmenu)
{
  submenu_level *stack = new submenu_level[MAX_SUBMENU_DEPTH];
  memset (stack, 0, sizeof (submenu_level) * MAX_SUBMENU_DEPTH);
  for (int i = 0; i < MAX_SUBMENU_DEPTH; i++)
    stack[i].sel = -1;
  int depth = 0;

  // Collect root popup items
  submenu_level &root = stack[0];
  root.count = collect_menu_items (lmenu, root.items, 256, 1);
  if (root.count == 0)
    {
      delete[] stack;
      return Qnil;
    }
  fill_menu_keybinds (root.items, root.count);

  int rows, cols;
  getmaxyx (stdscr, rows, cols);

  int cur_y, cur_x;
  getyx (stdscr, cur_y, cur_x);

  root.sel = find_first_selectable (root.items, root.count);
  root.x = cur_x;
  root.y = cur_y;
  root.win = draw_dropdown (root.x, root.y, root.items, root.count,
                            root.sel, &root.width);
  if (!root.win)
    return Qnil;

  lisp result = Qnil;
  int running = 1;

  while (running)
    {
      int ch = getch ();
      submenu_level &cur = stack[depth];

      switch (ch)
        {
        case KEY_UP:
        case 16: // C-p
          if (cur.count > 0)
            {
              int start = cur.sel;
              do
                cur.sel = (cur.sel + cur.count - 1) % cur.count;
              while (cur.items[cur.sel].is_separator && cur.sel != start);
              redraw_level (cur);
            }
          break;

        case KEY_DOWN:
        case 14: // C-n
          if (cur.count > 0)
            {
              int start = cur.sel;
              do
                cur.sel = (cur.sel + 1) % cur.count;
              while (cur.items[cur.sel].is_separator && cur.sel != start);
              redraw_level (cur);
            }
          break;

        case KEY_RIGHT:
        case 6: // C-f
          // Open submenu if selected item is a submenu
          if (cur.sel >= 0 && cur.sel < cur.count
              && cur.items[cur.sel].is_submenu
              && !(cur.items[cur.sel].flags & MF_GRAYED))
            {
              if (open_submenu (stack, depth))
                depth++;
            }
          break;

        case KEY_LEFT:
        case 2: // C-b
          // Go back to parent if in a submenu
          if (depth > 0)
            {
              close_submenu (stack, depth);
              depth--;
              touchwin (stdscr);
              refresh ();
              for (int d = 0; d <= depth; d++)
                redraw_level (stack[d]);
            }
          break;

        case '\r':
        case '\n':
        case KEY_ENTER:
          if (cur.sel >= 0 && cur.sel < cur.count
              && !cur.items[cur.sel].is_separator
              && !(cur.items[cur.sel].flags & MF_GRAYED))
            {
              if (cur.items[cur.sel].is_submenu)
                {
                  if (open_submenu (stack, depth))
                    depth++;
                }
              else
                {
                  result = cur.items[cur.sel].item;
                  running = 0;
                }
            }
          else
            running = 0;
          break;

        case 27: // ESC
        case 7:  // C-g
          running = 0;
          break;

        case KEY_MOUSE:
          {
            MEVENT mev;
            if (getmouse (&mev) == OK
                && (mev.bstate & (BUTTON1_PRESSED | BUTTON1_CLICKED)))
              {
                int handled = 0;
                for (int d = depth; d >= 0; d--)
                  {
                    int idx = menu_item_at (stack[d], mev.y, mev.x);
                    if (idx >= 0)
                      {
                        if (d < depth)
                          close_submenus_above (stack, depth, d);

                        stack[d].sel = idx;
                        redraw_level (stack[d]);

                        if (stack[d].items[idx].is_submenu
                            && !(stack[d].items[idx].flags & MF_GRAYED))
                          {
                            if (open_submenu (stack, d))
                              depth = d + 1;
                          }
                        else if (!(stack[d].items[idx].flags & MF_GRAYED))
                          {
                            result = stack[d].items[idx].item;
                            running = 0;
                          }
                        handled = 1;
                        break;
                      }
                    else if (idx == -2)
                      {
                        handled = 1;
                        break;
                      }
                  }
                if (!handled)
                  running = 0;
              }
            else if (!(mev.bstate & (BUTTON1_RELEASED | BUTTON2_RELEASED
                                     | BUTTON3_RELEASED | REPORT_MOUSE_POSITION)))
              running = 0;  // non-left click → close (but ignore releases)
          }
          break;

        default:
          // Accelerator key handling
          if (ch > 0 && ch < 256)
            {
              int lch = tolower (ch);
              for (int i = 0; i < cur.count; i++)
                if (cur.items[i].accel == lch
                    && !cur.items[i].is_separator
                    && !(cur.items[i].flags & MF_GRAYED))
                  {
                    if (cur.items[i].is_submenu)
                      {
                        cur.sel = i;
                        redraw_level (cur);
                        if (open_submenu (stack, depth))
                          depth++;
                      }
                    else
                      {
                        result = cur.items[i].item;
                        running = 0;
                      }
                    break;
                  }
            }
          break;
        }
    }

  // Cleanup all levels
  for (int d = depth; d >= 0; d--)
    close_submenu (stack, d);
  delete[] stack;

  if (result != Qnil)
    {
      int id = xwin32_menu_id (result);
      if (id >= MENU_ID_RANGE_MIN && id < MENU_ID_RANGE_MAX)
        {
          Window *wp = selected_window ();
          if (wp && (wp->w_selection_type & Buffer::PRE_SELECTION))
            (int &)wp->w_selection_type |= Buffer::CONTINUE_PRE_SELECTION;
          app.kbdq.putc (LCHAR_MENU | id);
        }
    }

  // Drain stale mouse events from menu interaction
  {
    MEVENT mev;
    nodelay (stdscr, TRUE);
    wint_t wch;
    while (wget_wch (stdscr, &wch) != ERR)
      {
        if (wch == KEY_MOUSE)
          getmouse (&mev);
        else
          { unget_wch (wch); break; }
      }
    nodelay (stdscr, FALSE);
  }

  touchwin (stdscr);
  refresh_screen (1);
  return Qnil;
}

lisp
Ftrack_popup_menu (lisp lmenu, lisp)
{
  check_popup_menu (lmenu);
  xsymbol_value (Vtracking_menu) = lmenu;
  return run_popup_modal (lmenu);
}

// ============================================================
// Mouse support
// ============================================================

// Find which xyzzy Window contains screen coordinate (row, col).
// Returns NULL if no editing window matches (e.g. menu bar row).
static Window *
ncurses_find_window_at (int row, int col)
{
  Window *mini = Window::minibuffer_window ();
  // Check minibuffer first
  if (mini && mini->w_bufp
      && row >= mini->w_rect.top && row < mini->w_rect.bottom
      && col >= mini->w_rect.left && col < mini->w_rect.right)
    return mini;
  // Iterate editing windows
  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      if (!wp->w_bufp)
        continue;
      if (row >= wp->w_rect.top && row < wp->w_rect.bottom
          && col >= wp->w_rect.left && col < wp->w_rect.right)
        return wp;
    }
  return NULL;
}

// Convert screen (row, col) to text (line, column) within a window.
// Sets *line to virtual line number, *column to column offset.
// Returns 0 if inside text area, non-zero if out of bounds.
static int
ncurses_screen_to_text (Window *wp, int row, int col, int *line, int *column)
{
  int text_top = wp->w_rect.top;
  int text_left = wp->w_rect.left;
  int text_rows = wp->w_rect.bottom - wp->w_rect.top - 1;  // -1 for modeline
  int has_separator = (wp->w_rect.right < (int)app.active_frame.size.cx) ? 1 : 0;
  int text_cols = (wp->w_rect.right - wp->w_rect.left) - has_separator;

  int linenum_offset = 0;
  if (wp->flags () & Window::WF_LINE_NUMBER)
    linenum_offset = Window::LINENUM_COLUMNS + 1;

  int y = row - text_top;
  int x = col - text_left - linenum_offset;

  int oob = 0;
  if (y < 0) { oob = 1; y = 0; }
  else if (y >= text_rows) { oob = 1; y = text_rows - 1; }
  if (x < 0) { oob = 1; x = 0; }
  else if (x >= text_cols - linenum_offset) { oob = 1; x = text_cols - linenum_offset - 1; }

  *line = wp->w_last_top_linenum + y;
  *column = wp->w_top_column + x;
  return oob;
}

// Win32 mouse.cc compatibility: rowcol_from_point
// In ncurses, coordinates are already cell-based, so this is straightforward.
int
rowcol_from_point (Window *wp, int *xx, int *yy)
{
  return ncurses_screen_to_text (wp, *yy, *xx, yy, xx);
}

// Click tracking for double/triple click detection
static struct {
  int row, col;
  int click_count;
  struct timespec last_time;
  int button_down;  // 0=none, 1=left, 2=middle, 3=right
} g_click_state = {-1, -1, 0, {0, 0}, 0};

static int
detect_click_count (int row, int col)
{
  struct timespec now;
  clock_gettime (CLOCK_MONOTONIC, &now);
  long elapsed_ms = (now.tv_sec - g_click_state.last_time.tv_sec) * 1000
                  + (now.tv_nsec - g_click_state.last_time.tv_nsec) / 1000000;
  if (row == g_click_state.row && col == g_click_state.col && elapsed_ms < 500)
    g_click_state.click_count++;
  else
    g_click_state.click_count = 1;
  g_click_state.row = row;
  g_click_state.col = col;
  g_click_state.last_time = now;
  return g_click_state.click_count;
}

// Open menu bar directly at the clicked column position.
// Called from mouse dispatch when row 0 is clicked.
static void
ncurses_menu_bar_click (int col)
{
  lisp lmenu = xsymbol_value (Vdefault_menu);
  if (!win32_menu_p (lmenu))
    return;
  if (win32_menu_p (selected_buffer ()->lmenu))
    lmenu = selected_buffer ()->lmenu;

  // Find which bar item was clicked by computing positions
  menu_entry bar_items[64];
  int bar_count = collect_menu_items (lmenu, bar_items, 64, 1);
  int bi = bar_item_at (bar_items, bar_count, col);
  if (bi < 0)
    bi = 0;

  xsymbol_value (Vlast_active_menu) = lmenu;
  run_menu_modal (lmenu, bi);
}

// ---- Separator drag (window resize by mouse) ----

// Check if screen (row, col) is on a window separator.
// Returns: 0=not on separator, 1=horizontal (modeline), 2=vertical separator.
// Sets *wp1 to the window above/left of the boundary, *wp2 to the one below/right.
static int
separator_hit_test (int row, int col, Window **wp1, Window **wp2)
{
  Window *mini = Window::minibuffer_window ();
  int cols = (int)app.active_frame.size.cx;

  for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
    {
      if (!wp->w_bufp)
        continue;

      // Check modeline (horizontal separator): bottom row of this window
      int modeline_row = wp->w_rect.bottom - 1;
      if (row == modeline_row
          && col >= wp->w_rect.left && col < wp->w_rect.right)
        {
          // Find neighbor below
          for (Window *w2 = app.active_frame.windows; w2 && w2 != mini; w2 = w2->w_next)
            if (w2 != wp && w2->w_rect.top == wp->w_rect.bottom
                && w2->w_rect.left < wp->w_rect.right
                && w2->w_rect.right > wp->w_rect.left)
              {
                *wp1 = wp;
                *wp2 = w2;
                return 1;
              }
        }

      // Check vertical separator: rightmost column when not at terminal edge
      if (wp->w_rect.right < cols)
        {
          int sep_col = wp->w_rect.right;  // the boundary column
          if (col == sep_col - 1  // on the separator character itself
              && row >= wp->w_rect.top && row < wp->w_rect.bottom)
            {
              // Find neighbor to the right
              for (Window *w2 = app.active_frame.windows; w2 && w2 != mini; w2 = w2->w_next)
                if (w2 != wp && w2->w_rect.left == wp->w_rect.right
                    && w2->w_rect.top < wp->w_rect.bottom
                    && w2->w_rect.bottom > wp->w_rect.top)
                  {
                    *wp1 = wp;
                    *wp2 = w2;
                    return 2;
                  }
            }
        }
    }
  return 0;
}

// Modal drag loop for resizing windows by dragging a separator.
// drag_type: 1=horizontal (modeline), 2=vertical separator.
static void
separator_drag (int drag_type, Window *wp1, Window *wp2, int start_row, int start_col)
{
  int min_size = (drag_type == 1) ? 3 : 6;  // min rows / min cols per window

  while (1)
    {
      int ch = getch ();
      if (ch != KEY_MOUSE)
        {
          // Any non-mouse key ends the drag
          if (ch != ERR)
            ungetch (ch);
          break;
        }

      MEVENT mev;
      if (getmouse (&mev) != OK)
        continue;

      // Button release ends drag
      if (mev.bstate & (BUTTON1_RELEASED | BUTTON2_RELEASED | BUTTON3_RELEASED))
        break;

      // Only handle motion / pressed events
      if (!(mev.bstate & (REPORT_MOUSE_POSITION | BUTTON1_PRESSED)))
        continue;

      int new_pos = (drag_type == 1) ? mev.y : mev.x;
      int cur_boundary = (drag_type == 1) ? wp1->w_rect.bottom : wp1->w_rect.right;

      int delta = new_pos - cur_boundary;
      if (drag_type == 1)
        delta = new_pos - (wp1->w_rect.bottom - 1);  // modeline row
      else
        delta = new_pos - (wp1->w_rect.right - 1);   // separator col

      if (delta == 0)
        continue;

      // Check minimum size constraints
      Window *mini = Window::minibuffer_window ();
      if (drag_type == 1)
        {
          int new_h1 = (wp1->w_rect.bottom - wp1->w_rect.top) + delta;
          int new_h2 = (wp2->w_rect.bottom - wp2->w_rect.top) - delta;
          if (new_h1 < min_size || new_h2 < min_size)
            continue;
          // Move the horizontal boundary for all windows sharing it
          int boundary = wp1->w_rect.bottom;
          for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
            {
              if (wp->w_rect.bottom == boundary)
                wp->w_rect.bottom += delta;
              else if (wp->w_rect.top == boundary)
                wp->w_rect.top += delta;
            }
        }
      else
        {
          int new_w1 = (wp1->w_rect.right - wp1->w_rect.left) + delta;
          int new_w2 = (wp2->w_rect.right - wp2->w_rect.left) - delta;
          if (new_w1 < min_size || new_w2 < min_size)
            continue;
          // Move the vertical boundary for all windows sharing it
          int boundary = wp1->w_rect.right;
          for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
            {
              if (wp->w_rect.right == boundary)
                wp->w_rect.right += delta;
              else if (wp->w_rect.left == boundary)
                wp->w_rect.left += delta;
            }
        }

      // Recompute text area sizes for all windows
      int cols = (int)app.active_frame.size.cx;
      for (Window *wp = app.active_frame.windows; wp && wp != mini; wp = wp->w_next)
        {
          int win_cols = wp->w_rect.right - wp->w_rect.left;
          if (wp->w_rect.right < cols)
            win_cols--;
          int text_rows = wp->w_rect.bottom - wp->w_rect.top - 1;
          if (text_rows < 1) text_rows = 1;
          if (win_cols < 1) win_cols = 1;
          ncurses_calc_client_size (wp, win_cols, text_rows);
        }

      clear ();
      refresh_screen (1);
    }

  g_click_state.button_down = 0;
}

// Dispatch ncurses MEVENT to xyzzy mouse event.
// Called from ncurses-kbd.cc when KEY_MOUSE is received.
// Returns lChar to enqueue, or lChar_EOF if unhandled.
lChar
ncurses_mouse_dispatch (MEVENT *mev)
{
  int row = mev->y;
  int col = mev->x;
  mmask_t state = mev->bstate;

  // Determine button and operation
  Char ccf;
  if (state & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED))
    ccf = CCF_LBTNDOWN;
  else if (state & BUTTON1_RELEASED)
    ccf = CCF_LBTNUP;
  else if (state & (BUTTON3_PRESSED | BUTTON3_CLICKED | BUTTON3_DOUBLE_CLICKED))
    ccf = CCF_RBTNDOWN;
  else if (state & BUTTON3_RELEASED)
    ccf = CCF_RBTNUP;
  else if (state & (BUTTON2_PRESSED | BUTTON2_CLICKED | BUTTON2_DOUBLE_CLICKED))
    ccf = CCF_MBTNDOWN;
  else if (state & BUTTON2_RELEASED)
    ccf = CCF_MBTNUP;
  else if (state & (BUTTON4_PRESSED | BUTTON5_PRESSED))
    {
      // Mouse wheel: scroll window under cursor, 3 lines
      Window *wp = ncurses_find_window_at (row, col);
      if (wp && wp->w_bufp)
        {
          int delta = (state & BUTTON4_PRESSED) ? -3 : 3;
          wp->scroll_window (delta);
          refresh_screen (1);
        }
      return lChar_EOF;
    }
  else if (state & REPORT_MOUSE_POSITION)
    {
      // Motion: convert to button-specific move based on tracked state
      switch (g_click_state.button_down)
        {
        case 1: ccf = CCF_LBTNMOVE; break;
        case 2: ccf = CCF_MBTNMOVE; break;
        case 3: ccf = CCF_RBTNMOVE; break;
        default: ccf = CCF_MOUSEMOVE; break;
        }
    }
  else
    return lChar_EOF;

  // Track button state for motion events
  if (state & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED))
    g_click_state.button_down = 1;
  else if (state & (BUTTON2_PRESSED | BUTTON2_CLICKED | BUTTON2_DOUBLE_CLICKED))
    g_click_state.button_down = 2;
  else if (state & (BUTTON3_PRESSED | BUTTON3_CLICKED | BUTTON3_DOUBLE_CLICKED))
    g_click_state.button_down = 3;
  else if (state & (BUTTON1_RELEASED | BUTTON2_RELEASED | BUTTON3_RELEASED))
    g_click_state.button_down = 0;

  // Add modifier keys
  if (state & BUTTON_SHIFT)
    ccf |= CCF_SHIFT_BIT;
  if (state & BUTTON_CTRL)
    ccf |= CCF_CTRL_BIT;
  if (state & BUTTON_ALT)
    ccf = function_to_meta_function (ccf);

  // Click on menu bar row → open menu at clicked item directly
  if (row == 0 && (ccf == CCF_LBTNDOWN || (ccf & ~(CCF_SHIFT_BIT | CCF_CTRL_BIT)) == CCF_LBTNDOWN))
    {
      ncurses_menu_bar_click (col);
      return lChar_EOF;
    }

  // Left-click on window separator → start drag resize
  if (ccf == CCF_LBTNDOWN)
    {
      Window *wp1 = 0, *wp2 = 0;
      int sep = separator_hit_test (row, col, &wp1, &wp2);
      if (sep)
        {
          separator_drag (sep, wp1, wp2, row, col);
          return lChar_EOF;
        }
    }

  // Find which window was clicked
  Window *wp = ncurses_find_window_at (row, col);
  if (!wp)
    return lChar_EOF;

  // Convert to text coordinates
  int line, column;
  ncurses_screen_to_text (wp, row, col, &line, &column);

  // Detect click count for double/triple click (on button down only)
  int click_count = 1;
  if (ccf == CCF_LBTNDOWN || ccf == CCF_RBTNDOWN || ccf == CCF_MBTNDOWN)
    click_count = detect_click_count (row, col);

  // Set xyzzy mouse variables (same as win32/mouse.cc dispatch)
  xsymbol_value (Vlast_mouse_window) = wp->lwp;
  xsymbol_value (Vlast_mouse_line) = make_fixnum (line);
  xsymbol_value (Vlast_mouse_column) = make_fixnum (column);
  xsymbol_value (Vlast_mouse_click_count) = make_fixnum (click_count);

  return (lChar)ccf | LCHAR_MOUSE;
}

// Dialog (Fdialog_box and Fproperty_sheet are in ncurses-dialog.cc)
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

// Process: implemented in ncurses-process.cc

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
// Fshell_execute: implemented in ncurses-process.cc
lisp Fcreate_shortcut (lisp, lisp, lisp) { return Qnil; }
lisp Fresolve_shortcut (lisp) { return Qnil; }
lisp Feject_media (lisp) { return Qnil; }
lisp Fget_special_folder_location (lisp) { return Qnil; }
lisp Fget_file_info (lisp) { return Qnil; }

// Misc
lisp Fmain_loop () { command_loop (); return Qnil; }
// Fsit_for/Fsleep_for: implemented in ncurses-process.cc
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
