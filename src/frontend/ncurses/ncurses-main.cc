// ncurses frontend for xyzzy - terminal-based editor UI
// Links xyzzy-core (no Win32 GUI) + ncurses for display/input

#include "stdafx.h"
#include "ed.h"
#include "Window.h"

#include <locale.h>
#include <signal.h>
#include <ncurses.h>
#include <float.h>
#include <unistd.h>
#include <fcntl.h>

#ifndef M_PI
# define M_PI 3.141592653589793
#endif

// Flag set by PostQuitMessage (kill-xyzzy) to distinguish from Quit
volatile int g_quit_message_posted = 0;

#include "lex.h"
#include "environ.h"
#include "except.h"
#include "fnkey.h"
#include "kanji.h"
#include "version.h"

// Forward declarations from core
void init_syms ();
void combine_syms ();
void rehash_all_hash_tables ();
void init_condition ();
void init_syntax_spec ();
void create_std_streams ();
int rdump_xyzzy ();
void init_ucs2_table ();
void init_char_encoding ();
void init_readtable ();
void init_environ ();
void cleanup_lisp_objects ();
lisp Fmake_keymap ();
lisp Fmake_sparse_keymap ();
lisp Fmake_syntax_table ();
lisp Fdefine_key (lisp keymap, lisp key, lisp fn);
lisp Fsi_fset (lisp name, lisp body);
lisp Fintern (lisp string, lisp package);
void command_loop ();
void create_default_buffers ();
lisp Fcommand_execute (lisp command, lisp hook);
lisp Fkeymapp (lisp);

static void crash_handler (int sig)
{
  endwin ();
  fprintf (stderr, "\n=== Signal %d ===\n", sig);
  _exit (1);
}

volatile int g_need_resize = 0;

static void sigwinch_handler (int)
{
  g_need_resize = 1;
}

// POSIX version of init_module_dir
static void
init_module_dir ()
{
  char *xyzzyhome = getenv ("XYZZYHOME");
  if (xyzzyhome && *xyzzyhome)
    {
      char path[PATH_MAX];
      int l = strlen (xyzzyhome);
      if (l > 0 && l < PATH_MAX - 2)
        {
          strcpy (path, xyzzyhome);
          if (path[l - 1] != '/')
            {
              path[l] = '/';
              path[l + 1] = 0;
            }
          xsymbol_value (Qmodule_dir) = make_path (path);
          return;
        }
    }

  // Fallback: use /proc/self/exe directory
  char path[PATH_MAX];
  ssize_t len = readlink ("/proc/self/exe", path, sizeof (path) - 1);
  if (len > 0)
    {
      path[len] = 0;
      char *slash = strrchr (path, '/');
      if (slash)
        {
          slash[1] = 0;
          xsymbol_value (Qmodule_dir) = make_path (path);
          return;
        }
    }

  // Last resort: current directory
  if (getcwd (path, sizeof (path)))
    {
      int l = strlen (path);
      if (l > 0 && path[l - 1] != '/')
        {
          path[l] = '/';
          path[l + 1] = 0;
        }
      xsymbol_value (Qmodule_dir) = make_path (path);
    }
}

static void
init_current_dir ()
{
  char path[PATH_MAX];
  if (getcwd (path, sizeof (path)))
    {
      int l = strlen (path);
      if (l > 0 && path[l - 1] != '/')
        {
          path[l] = '/';
          path[l + 1] = 0;
        }
      xsymbol_value (Qdefault_dir) = make_path (path);
    }
}

static void
init_home_dir ()
{
  char *home = getenv ("HOME");
  if (home && *home)
    {
      char path[PATH_MAX];
      int l = strlen (home);
      if (l > 0 && l < PATH_MAX - 2)
        {
          strcpy (path, home);
          if (path[l - 1] != '/')
            {
              path[l] = '/';
              path[l + 1] = 0;
            }
          xsymbol_value (Qhome_dir) = make_path (path);
          return;
        }
    }
  xsymbol_value (Qhome_dir) = xsymbol_value (Qdefault_dir);
}

static void
init_load_path ()
{
  // Load path: module_dir + module_dir/lisp + module_dir/site-lisp
  lisp p = Qnil;
  lisp mod = xsymbol_value (Qmodule_dir);
  if (mod != Qnil && stringp (mod))
    {
      const Char *s = xstring_contents (mod);
      int l = xstring_length (mod);

      // module_dir/site-lisp/
      Char buf[PATH_MAX];
      const char *site = "site-lisp/";
      bcopy (s, buf, l);
      for (int i = 0; site[i]; i++)
        buf[l + i] = site[i];
      p = xcons (make_string (buf, l + 10), p);

      // module_dir/lisp/
      const char *lisp_dir = "lisp/";
      bcopy (s, buf, l);
      for (int i = 0; lisp_dir[i]; i++)
        buf[l + i] = lisp_dir[i];
      p = xcons (make_string (buf, l + 5), p);

      // module_dir itself
      p = xcons (mod, p);
    }
  xsymbol_value (Vload_path) = p;
}

static void
init_math_symbols ()
{
#define CP(T, F) (xsymbol_value (T) = xsymbol_value (F))

  xsymbol_value (Qmost_positive_single_float) = make_single_float (FLT_MAX);
  xsymbol_value (Qmost_negative_single_float) = make_single_float (-FLT_MAX);
  float fl, fe;
  for (fl = 1.0F, fe = 1.1F; fl && fe > fl; fe = fl, fl /= 2.0F)
    ;
  xsymbol_value (Qleast_positive_single_float) = make_single_float (fe);
  xsymbol_value (Qleast_negative_single_float) = make_single_float (-fe);
  xsymbol_value (Qleast_positive_normalized_single_float) =
    make_single_float (FLT_MIN);
  xsymbol_value (Qleast_negative_normalized_single_float) =
    make_single_float (-FLT_MIN);
  for (fl = 1.0F, fe = 1.1F; (float)(1.0F + fl) != 1.0F && fe > fl; fe = fl, fl /= 2.0F)
    ;
  xsymbol_value (Qsingle_float_epsilon) = make_single_float (fe);
  for (fl = 1.0F, fe = 1.1F; (float)(1.0F - fl) != 1.0F && fe > fl; fe = fl, fl /= 2.0F)
    ;
  xsymbol_value (Qsingle_float_negative_epsilon) = make_single_float (fe);

  CP (Qmost_positive_short_float, Qmost_positive_single_float);
  CP (Qmost_negative_short_float, Qmost_negative_single_float);
  CP (Qleast_positive_short_float, Qleast_positive_single_float);
  CP (Qleast_negative_short_float, Qleast_negative_single_float);
  CP (Qleast_positive_normalized_short_float,
      Qleast_positive_normalized_single_float);
  CP (Qleast_negative_normalized_short_float,
      Qleast_negative_normalized_single_float);
  CP (Qshort_float_epsilon, Qsingle_float_epsilon);
  CP (Qshort_float_negative_epsilon, Qsingle_float_negative_epsilon);

  xsymbol_value (Qmost_positive_double_float) = make_double_float (DBL_MAX);
  xsymbol_value (Qmost_negative_double_float) = make_double_float (-DBL_MAX);
  double dl, de;
  for (dl = 1.0, de = 1.1; dl && de > dl; de = dl, dl /= 2.0)
    ;
  xsymbol_value (Qleast_positive_double_float) = make_double_float (de);
  xsymbol_value (Qleast_negative_double_float) = make_double_float (-de);
  xsymbol_value (Qleast_positive_normalized_double_float) =
    make_double_float (DBL_MIN);
  xsymbol_value (Qleast_negative_normalized_double_float) =
    make_double_float (-DBL_MIN);
  for (dl = 1.0, de = 1.1; 1.0 + dl != 1.0 && de > dl; de = dl, dl /= 2.0)
    ;
  xsymbol_value (Qdouble_float_epsilon) = make_double_float (de);
  for (dl = 1.0, de = 1.1; 1.0 - dl != 1.0 && de > dl; de = dl, dl /= 2.0)
    ;
  xsymbol_value (Qdouble_float_negative_epsilon) = make_double_float (de);

  CP (Qmost_positive_long_float, Qmost_positive_double_float);
  CP (Qleast_positive_long_float, Qleast_positive_double_float);
  CP (Qleast_negative_long_float, Qleast_negative_double_float);
  CP (Qmost_negative_long_float, Qmost_negative_double_float);
  CP (Qleast_positive_normalized_long_float,
      Qleast_positive_normalized_double_float);
  CP (Qleast_negative_normalized_long_float,
      Qleast_negative_normalized_double_float);
  CP (Qlong_float_epsilon, Qdouble_float_epsilon);
  CP (Qlong_float_negative_epsilon, Qdouble_float_negative_epsilon);

  xsymbol_value (Qmost_positive_fixnum) = make_fixnum (LONG_MAX);
  xsymbol_value (Qmost_negative_fixnum) = make_fixnum (LONG_MIN);

  xsymbol_value (Qpi) = make_double_float (M_PI);
  xsymbol_value (Qimag_two) = make_complex (make_fixnum (0), make_fixnum (2));

#undef CP
}

// Equivalent of init.cc init_symbol_value_once()
static void
init_symbol_value_once ()
{
  xsymbol_value (Qt) = Qt;

  xsymbol_value (Vprint_readably) = Qnil;
  xsymbol_value (Vprint_escape) = Qt;
  xsymbol_value (Vprint_pretty) = Qt;
  xsymbol_value (Vprint_base) = make_fixnum (10);
  xsymbol_value (Vprint_radix) = Qnil;
  xsymbol_value (Vprint_circle) = Qnil;
  xsymbol_value (Vprint_length) = Qnil;
  xsymbol_value (Vprint_level) = Qnil;

  xsymbol_value (Vload_verbose) = Qt;
  xsymbol_value (Vload_print) = Qnil;

  xsymbol_value (Vrandom_state) = Fmake_random_state (Qt);
  xsymbol_value (Vdefault_random_state) = xsymbol_value (Vrandom_state);

  xsymbol_value (Qcall_arguments_limit) = make_fixnum (MAX_VECTOR_LENGTH);
  xsymbol_value (Qlambda_parameters_limit) = make_fixnum (MAX_VECTOR_LENGTH);
  xsymbol_value (Qmultiple_values_limit) = make_fixnum (MULTIPLE_VALUES_LIMIT);

  init_math_symbols ();
  init_readtable ();

  xsymbol_value (Qchar_code_limit) = make_fixnum (CHAR_LIMIT);

  xsymbol_value (Qarray_rank_limit) = make_fixnum (ARRAY_RANK_LIMIT);
  xsymbol_value (Qarray_dimension_limit) = make_fixnum (MAX_VECTOR_LENGTH);
  xsymbol_value (Qarray_total_size_limit) = make_fixnum (MAX_VECTOR_LENGTH);

  xsymbol_value (Qinternal_time_units_per_second) = make_fixnum (1000);

  xsymbol_value (Vcreate_buffer_hook) = Qnil;
  xsymbol_value (Vdefault_fileio_encoding) = xsymbol_value (Qencoding_sjis);
  xsymbol_value (Vexpected_fileio_encoding) = xsymbol_value (Qencoding_auto);
  xsymbol_value (Vdetect_char_encoding_mode) = Klibguess;
  xsymbol_value (Vdetect_char_encoding_buffer_size) = make_fixnum (DEFAULT_DETECT_BUFFER_SIZE);
  xsymbol_value (Vdefault_eol_code) = make_fixnum (eol_lf);  // LF for POSIX
  xsymbol_value (Vexpected_eol_code) = make_fixnum (eol_guess);

  xsymbol_value (Qor_string_integer) =
    xcons (Qor, xcons (Qstring, xcons (Qinteger, Qnil)));
  xsymbol_value (Qor_symbol_integer) =
    xcons (Qor, xcons (Qsymbol, xcons (Qinteger, Qnil)));
  xsymbol_value (Qor_string_character) =
    xcons (Qor, xcons (Qstring, xcons (Qcharacter, Qnil)));
  xsymbol_value (Qor_integer_marker) =
    xcons (Qor, xcons (Qinteger, xcons (Qmarker, Qnil)));
  xsymbol_value (Qor_character_cons) =
    xcons (Qor, xcons (Qcharacter, xcons (Qcons, Qnil)));
  xsymbol_value (Qor_symbol_string) =
    xcons (Qor, xcons (Qsymbol, xcons (Qstring, Qnil)));
  xsymbol_value (Qor_string_stream) =
    xcons (Qor, xcons (Qstring, xcons (Qstream, Qnil)));
  xsymbol_value (Qreal_between_0_and_1) =
    make_list (Qreal, make_fixnum (0), make_fixnum (1), 0);
  xsymbol_value (Qor_real_integer_1_star) =
    make_list (Qor,
               make_list (Qinteger, make_fixnum (1), Smultiply, 0),
               make_list (Qfloat, make_single_float (1.0), Smultiply, 0),
               0);

  xsymbol_value (Vread_default_float_format) = Qsingle_float;

  xsymbol_value (Vscroll_bar_step) = make_fixnum (2);

  xsymbol_value (Vglobal_keymap) = Fmake_keymap ();
  xsymbol_value (Vselection_keymap) = Qnil;
  xsymbol_value (Vkept_undo_information) = make_fixnum (1000);
  xsymbol_value (Vbuffer_read_only) = Qnil;
  xsymbol_value (Venable_meta_key) = Qt;
  xsymbol_value (Vlast_command_char) = Qnil;
  xsymbol_value (Vneed_not_save) = Qnil;
  xsymbol_value (Vauto_save) = Qt;
  xsymbol_value (Vbeep_on_error) = Qt;
  xsymbol_value (Vbeep_on_warn) = Qt;
  xsymbol_value (Vbeep_on_never) = Qnil;
  xsymbol_value (Vprefix_value) = Qnil;
  xsymbol_value (Vprefix_args) = Qnil;
  xsymbol_value (Vnext_prefix_value) = Qnil;
  xsymbol_value (Vnext_prefix_args) = Qnil;
  xsymbol_value (Vdefault_syntax_table) = Fmake_syntax_table ();
  xsymbol_value (Vauto_fill) = Qnil;
  xsymbol_value (Vthis_command) = Qnil;
  xsymbol_value (Vlast_command) = Qnil;

  xsymbol_value (Qapp_user_model_id) = Qnil;
  xsymbol_value (Qsoftware_type) = make_string (ProgramName);
  xsymbol_value (Qsoftware_version) = make_string (VersionString);
  xsymbol_value (Qsoftware_version_display_string) =
    make_string (DisplayVersionString);

  xsymbol_value (Qtemporary_string) = make_string_simple ("", 0);

  xsymbol_value (Vversion_control) = Qt;
  xsymbol_value (Vkept_old_versions) = make_fixnum (2);
  xsymbol_value (Vkept_new_versions) = make_fixnum (2);
  xsymbol_value (Vmake_backup_files) = Qt;
  xsymbol_value (Vmake_backup_file_always) = Qnil;
  xsymbol_value (Vpack_backup_file_name) = Qt;
  xsymbol_value (Vauto_save_interval) = make_fixnum (256);
  xsymbol_value (Vauto_save_interval_timer) = make_fixnum (30);
  xsymbol_value (Vbackup_by_copying) = Qnil;
  xsymbol_value (Vfile_precious_flag) = Qt;

  xsymbol_value (Vinverse_mode_line) = Qt;
  xsymbol_value (Vbuffer_list_sort_ignore_case) = Qt;
  xsymbol_value (Veat_mouse_activate) = Qt;
  xsymbol_value (Vindent_tabs_mode) = Qt;

  xsymbol_value (Slock_file) = Qnil;
  xsymbol_value (Vexclusive_lock_file) = Qnil;

  xsymbol_value (Vcursor_shape) = Karrow;
  xsymbol_value (Vhide_restricted_region) = Qnil;

  xsymbol_value (Vfiler_last_command_char) = Qnil;
  xsymbol_value (Vfiler_dual_window) = Qnil;
  xsymbol_value (Vfiler_left_window_p) = Qt;
  xsymbol_value (Vfiler_secondary_directory) = Qnil;
  xsymbol_value (Vfiler_click_toggle_marks_always) = Qt;
  xsymbol_value (Vfiler_show_hidden_files) = Qt;
  xsymbol_value (Vfiler_show_system_files) = Qt;

  xsymbol_value (Vdll_module_list) = Qnil;
  xsymbol_value (Vlast_win32_error) = make_fixnum (0);

  xsymbol_value (Vfunction_bar_labels) =
    make_vector (MAX_FUNCTION_BAR_LABEL, Qnil);

  xsymbol_value (Vkeyword_hash_table) = Qnil;
  xsymbol_value (Vhighlight_keyword) = Qt;
  xsymbol_value (Vhtml_highlight_mode) = Qnil;

  xsymbol_value (Vblink_caret) = Qt;

  xsymbol_value (Vparentheses_hash_table) = Qnil;

  xsymbol_value (Vdefault_kinsoku_bol_chars) = Qnil;
  xsymbol_value (Vdefault_kinsoku_eol_chars) = Qnil;

  xsymbol_value (Vdde_timeout) = make_fixnum (30000);
  xsymbol_value (Vbrackets_is_wildcard_character) = Qt;

  init_char_encoding ();

  xsymbol_value (Vbypass_evalhook) = Qnil;
  xsymbol_value (Vbypass_applyhook) = Qnil;

  xsymbol_value (Vtitle_bar_format) = Qnil;
  xsymbol_value (Vstatus_bar_format) = Qnil;
  xsymbol_value (Vlast_status_bar_format) = Qnil;
  xsymbol_value (Vscroll_margin) = make_fixnum (0);
  xsymbol_value (Vjump_scroll_threshold) = make_fixnum (3);
  xsymbol_value (Vauto_update_per_device_directory) = Qt;
  xsymbol_value (Vmodal_filer_save_position) = Qt;
  xsymbol_value (Vmodal_filer_save_size) = Qt;
  xsymbol_value (Vfiler_echo_filename) = Qt;
  xsymbol_value (Vfiler_eat_esc) = Qt;
  xsymbol_value (Vsupport_mouse_wheel) = Qt;
  xsymbol_value (Vminibuffer_save_ime_status) = Qt;
  xsymbol_value (Vuse_shell_execute_ex) = Qt;
  xsymbol_value (Vshell_execute_disregards_shift_key) = Qt;
  xsymbol_value (Vregexp_keyword_list) = Qnil;
  xsymbol_value (Vunicode_to_half_width) = Qt;
  xsymbol_value (Vcolor_page_enable_dir_p) = Qnil;
  xsymbol_value (Vcolor_page_enable_subdir_p) = Qnil;
  xsymbol_value (Vchange_clipboard_hook) = Qnil;
}

// Equivalent of init.cc init_symbol_value()
static void
init_symbol_value ()
{
  xsymbol_value (Vquit_flag) = Qnil;
  xsymbol_value (Vinhibit_quit) = Qnil;
  xsymbol_value (Voverwrite_mode) = Qnil;
  xsymbol_value (Vprocess_list) = Qnil;
  xsymbol_value (Vminibuffer_message) = Qnil;
  xsymbol_value (Vsi_find_motion) = Qt;
  xsymbol_value (Vdefault_menu) = Qnil;
  xsymbol_value (Vlast_active_menu) = Qnil;

  xsymbol_value (Vreader_in_backquote) = Qnil;
  xsymbol_value (Vreader_preserve_white) = Qnil;
  xsymbol_value (Vread_suppress) = Qnil;
  xsymbol_value (Vread_eval) = Qt;
  xsymbol_value (Vreader_label_alist) = Qnil;
  xsymbol_value (Vload_pathname) = Qnil;

  xsymbol_value (Vclipboard_newer_than_kill_ring_p) = Qnil;
  xsymbol_value (Vkill_ring_newer_than_clipboard_p) = Qnil;

  xsymbol_value (Vkbd_encoding) = xsymbol_value (Qencoding_sjis);
  xsymbol_value (Qperformance_counter_frequency) = make_fixnum (1000);

  xsymbol_value (Vsi_accept_kill_xyzzy) = Qt;
  xsymbol_value (Vlast_match_string) = Qnil;
}

static void
init_env_symbols (const char *argv0)
{
  // Add :ncurses to *features* for #-ncurses / #+ncurses reader conditionals
  lisp Kncurses = Fintern (make_string ("ncurses"),
                            xsymbol_value (Vkeyword_package));
  xsymbol_value (Vfeatures) = xcons (Kncurses,
                                xcons (Kxyzzy,
                                  xcons (Kieee_floating_point, Qnil)));
  xsymbol_value (Qdump_image_path) = Qnil;
  xsymbol_value (Qsystem_path) = make_string (argv0);
  init_module_dir ();
  init_current_dir ();
  init_environ ();
  init_home_dir ();
  init_load_path ();
  // Add :tty to *features* if stdout is connected to a real terminal
  if (isatty (STDOUT_FILENO))
    {
      lisp Ktty_kwd = Fintern (make_string ("tty"),
                               xsymbol_value (Vkeyword_package));
      xsymbol_value (Vfeatures) = xcons (Ktty_kwd, xsymbol_value (Vfeatures));
    }
}

// Create ncurses-compatible windows (no Win32 HWND)
static void
create_ncurses_windows ()
{
  // Create main editing window (temporary=1 to skip HWND creation)
  Window *wp = new Window (0, 1);
  // Create lisp window object and link
  wp->lwp = make_window ();
  xwindow_wp (wp->lwp) = wp;
  wp->w_disp_flags = Window::WDF_WINDOW | Window::WDF_MODELINE;
  // Initialize w_order for 2D grid layout
  wp->w_order.left = 0;
  wp->w_order.top = 0;
  wp->w_order.right = 1;
  wp->w_order.bottom = 1;

  // Create minibuffer window
  Window *mwp = new Window (1, 1);
  mwp->lwp = make_window ();
  xwindow_wp (mwp->lwp) = mwp;
  mwp->w_disp_flags = Window::WDF_WINDOW;

  // Link windows
  wp->w_prev = 0;
  wp->w_next = mwp;
  mwp->w_prev = wp;
  mwp->w_next = 0;

  // Set as active frame
  app.active_frame.windows = wp;
  app.active_frame.selected = wp;

  // Set frame size from terminal
  int rows, cols;
  getmaxyx (stdscr, rows, cols);
  app.active_frame.size.cx = cols;
  app.active_frame.size.cy = rows;

  // Compute initial window geometry (w_rect)
  Window::compute_geometry ();
}

// Set up minimal key bindings in C++ so the editor is usable
// without loading startup.l / cmds.l
static void
setup_minimal_keybindings ()
{
  lisp km = xsymbol_value (Vglobal_keymap);

  // === self-insert-command ===
  // (lambda () (interactive) (insert *last-command-char*) t)
  lisp sic_sym = Fintern (make_string ("self-insert-command"), 0);
  {
    lisp body = xcons (list (Qinteractive),
                  xcons (list (Sinsert, Vlast_command_char),
                    list (Qt)));
    Fsi_fset (sic_sym, xcons (Qlambda, xcons (Qnil, body)));
  }

  // Bind printable ASCII (0x20-0x7e)
  for (int c = 0x20; c <= 0x7e; c++)
    Fdefine_key (km, make_char ((Char)c), sic_sym);

  // Set default-input-function for non-ASCII chars
  xsymbol_value (Vdefault_input_function) = sic_sym;

  // === newline (RET) ===
  // (lambda () (interactive) (insert #\LFD) t)
  lisp nl_sym = Fintern (make_string ("newline"), 0);
  {
    lisp body = xcons (list (Qinteractive),
                  xcons (list (Sinsert, make_char ('\n')),
                    list (Qt)));
    Fsi_fset (nl_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x0d), nl_sym);

  // === Movement ===
  // C-f: forward-char
  Fdefine_key (km, make_char (0x06), Sforward_char);

  // C-b: backward-char — (lambda () (interactive) (forward-char -1))
  lisp bc_sym = Fintern (make_string ("backward-char"), 0);
  {
    lisp body = xcons (list (Qinteractive),
                  list (list (Sforward_char, make_fixnum (-1))));
    Fsi_fset (bc_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x02), bc_sym);

  // C-n: forward-line (next line)
  Fdefine_key (km, make_char (0x0e), Sforward_line);

  // C-p: previous-line — (lambda () (interactive) (forward-line -1))
  lisp pl_sym = Fintern (make_string ("previous-line"), 0);
  {
    lisp body = xcons (list (Qinteractive),
                  list (list (Sforward_line, make_fixnum (-1))));
    Fsi_fset (pl_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x10), pl_sym);

  // C-a: beginning-of-line
  Fdefine_key (km, make_char (0x01), Sgoto_bol);

  // C-e: end-of-line
  Fdefine_key (km, make_char (0x05), Sgoto_eol);

  // === Delete ===
  // C-d: delete-char
  // (lambda () (interactive) (if (< (point) (point-max)) (delete-region (point) (+ (point) 1))))
  lisp dc_sym = Fintern (make_string ("delete-char"), 0);
  {
    lisp point_call = list (Spoint);
    lisp cond = list (Snumber_less, point_call, list (Spoint_max));
    lisp del = list (Sdelete_region, point_call, list (Sadd, point_call, make_fixnum (1)));
    lisp body = xcons (list (Qinteractive),
                  list (list (Sif, cond, del)));
    Fsi_fset (dc_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x04), dc_sym);
  Fdefine_key (km, make_char (CCF_DELETE), dc_sym);

  // DEL (0x7f): delete-backward-char
  // (lambda () (interactive) (if (> (point) (point-min)) (delete-region (- (point) 1) (point))))
  lisp dbc_sym = Fintern (make_string ("delete-backward-char"), 0);
  {
    lisp point_call = list (Spoint);
    lisp cond = list (Snumber_greater, point_call, list (Spoint_min));
    lisp del = list (Sdelete_region, list (Ssubtract, point_call, make_fixnum (1)), point_call);
    lisp body = xcons (list (Qinteractive),
                  list (list (Sif, cond, del)));
    Fsi_fset (dbc_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x7f), dbc_sym);
  Fdefine_key (km, make_char (0x08), dbc_sym);

  // === Scroll ===
  // C-v: scroll down (scroll-window lines)
  Fdefine_key (km, make_char (0x16), Sscroll_window);

  // === Undo ===
  // C-/ or C-_: undo
  Fdefine_key (km, make_char (0x1f), Sundo);

  // === C-g: keyboard quit ===
  // Ding and clear the key sequence (like Emacs keyboard-quit)
  lisp kq_sym = Fintern (make_string ("keyboard-quit"), 0);
  {
    lisp body = xcons (list (Qinteractive),
                  list (list (Sding)));
    Fsi_fset (kq_sym, xcons (Qlambda, xcons (Qnil, body)));
  }
  Fdefine_key (km, make_char (0x07), kq_sym);

  // === C-x prefix map ===
  lisp cx_map = Fmake_sparse_keymap ();
  Fdefine_key (km, make_char (0x18), cx_map);
  // C-x C-c: kill-xyzzy
  Fdefine_key (cx_map, make_char (0x03), Skill_xyzzy);
  // C-x C-s: save-buffer
  Fdefine_key (cx_map, make_char (0x13), Ssave_buffer);

  // C-x C-f: find-file (minimal version)
  // (lambda (filename) (interactive "FFind file: ")
  //   (set-buffer (create-new-buffer filename))
  //   (insert-file-contents filename t))
  lisp ff_sym = Fintern (make_string ("find-file"), 0);
  {
    lisp arg = Fintern (make_string ("filename"), 0);
    lisp spec = make_string_simple ("FFind file: ", 12);
    lisp body = xcons (list (Qinteractive, spec),
                  xcons (list (Sset_buffer, list (Screate_new_buffer, arg)),
                    list (list (Sinsert_file_contents, arg, Qt))));
    Fsi_fset (ff_sym, xcons (Qlambda, xcons (list (arg), body)));
  }
  Fdefine_key (cx_map, make_char (0x06), ff_sym);

  // === Minibuffer keymap ===
  // RET exits the minibuffer; C-g quits (via quit_flag mechanism)
  lisp mini_map = Fmake_sparse_keymap ();
  xsymbol_value (Vminibuffer_local_map) = mini_map;
  // RET (0x0d) → exit-recursive-edit
  Fdefine_key (mini_map, make_char (0x0d), Sexit_recursive_edit);
  // C-g (0x07) → quit-recursive-edit
  Fdefine_key (mini_map, make_char (0x07), Squit_recursive_edit);
}

// ncurses-specific keybindings (when Lisp startup succeeded)
// minibuf.l already defines minibuffer keymaps with proper RET/C-g bindings,
// so we only need to ensure default-input-function is set.
static void
setup_ncurses_keybindings ()
{
  // Ensure default-input-function is set for non-ASCII self-insert
  lisp sic = Fintern (make_string ("self-insert-command"), 0);
  if (xsymbol_value (Vdefault_input_function) == Qnil
      || xsymbol_value (Vdefault_input_function) == Qunbound)
    xsymbol_value (Vdefault_input_function) = sic;

  // F10/ESC menu activation is set up in startup.l (ed::activate-menu)
}

// Write to log fd (survives SIGTERM since write() is unbuffered)
static int g_log_fd = -1;
static void
log_msg (const char *msg)
{
  if (g_log_fd >= 0)
    {
      ssize_t r __attribute__((unused)) = write (g_log_fd, msg, strlen (msg));
    }
}

// Self-test: exercise minibuffer + find-file from C++ by pre-loading keystrokes
static void
self_test_minibuffer ()
{
  g_log_fd = open ("/tmp/ncurses-selftest.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
  log_msg ("self-test starting\n");

  // Test 1: basic read_minibuffer
  {
    const char *input = "hello";
    for (int i = 0; input[i]; i++)
      app.kbdq.putc ((lChar)(unsigned char)input[i]);
    app.kbdq.putc (0x0d);

    const char *prompt = "Test: ";
    Char wprompt[16];
    for (int i = 0; prompt[i]; i++)
      wprompt[i] = prompt[i];

    lisp result = Qnil;
    try
      {
        result = read_minibuffer (wprompt, strlen (prompt), Qnil, Qnil, Qnil, Qnil,
                                  0, 0, 0, Qnil, -1);
      }
    catch (nonlocal_jump &)
      {
        log_msg ("FAIL: minibuffer threw\n");
        if (g_log_fd >= 0) close (g_log_fd);
        return;
      }
    if (stringp (result) && xstring_length (result) == 5)
      log_msg ("OK: read_minibuffer returned \"hello\"\n");
    else
      log_msg ("FAIL: unexpected result\n");
  }

  // Test 2: C-x C-f /etc/hostname (find-file via keystrokes)
  {
    log_msg ("Test 2: find-file starting\n");
    app.kbdq.putc (0x18);  // C-x
    app.kbdq.putc (0x06);  // C-f
    const char *path = "/etc/hostname";
    for (int i = 0; path[i]; i++)
      app.kbdq.putc ((lChar)(unsigned char)path[i]);
    app.kbdq.putc (0x0d);  // RET
    app.kbdq.putc (0x18);  // C-x
    app.kbdq.putc (0x03);  // C-c

    log_msg ("Test 2: entering command_loop\n");
    try
      {
        command_loop ();
      }
    catch (nonlocal_jump &)
      {
        log_msg ("Test 2: command_loop exited via throw\n");
      }

    Buffer *bp = selected_buffer ();
    if (bp && bp->b_nchars > 0)
      {
        char buf[128];
        snprintf (buf, sizeof (buf), "OK: find-file loaded %ld chars\n",
                  (long)bp->b_nchars);
        log_msg (buf);
      }
    else
      {
        char buf[128];
        snprintf (buf, sizeof (buf), "INFO: find-file buffer nchars=%ld\n",
                  bp ? (long)bp->b_nchars : -1L);
        log_msg (buf);
      }
  }

  log_msg ("self-test complete\n");
  if (g_log_fd >= 0)
    close (g_log_fd);
}

lisp read_minibuffer (const Char *, long, lisp, lisp, lisp, lisp, int, int, int, lisp, int);

int main (int argc, char **argv)
{
  signal (SIGSEGV, crash_handler);
  signal (SIGABRT, crash_handler);

  // SIGWINCH: use sigaction WITHOUT SA_RESTART so that
  // wget_wch() returns ERR immediately when the terminal is resized.
  {
    struct sigaction sa;
    sa.sa_handler = sigwinch_handler;
    sigemptyset (&sa.sa_mask);
    sa.sa_flags = 0;  // no SA_RESTART
    sigaction (SIGWINCH, &sa, NULL);
  }

  // ncurses needs locale set before initscr
  setlocale (LC_ALL, "");

  // Lisp engine init
  init_ucs2_table ();

  try
    {
      init_syms ();
      init_symbol_value_once ();
      init_condition ();
      init_syntax_spec ();
      init_env_symbols (argv[0]);
      create_std_streams ();
      init_symbol_value ();

      xsymbol_value (Vstandard_input) = xsymbol_value (Vterminal_io);
      xsymbol_value (Vstandard_output) = xsymbol_value (Vterminal_io);

      // ncurses init
      initscr ();
      raw ();
      noecho ();
      keypad (stdscr, TRUE);
      start_color ();
      use_default_colors ();

      // Create editor windows and buffers
      create_ncurses_windows ();
      create_default_buffers ();

      // Check for self-test mode early (before slow startup.l loading)
      int self_test = 0;
      for (int i = 1; i < argc; i++)
        if (strcmp (argv[i], "--self-test") == 0)
          self_test = 1;

      // Progress log to /tmp/xyzzy-startup.log
      int sfd = open ("/tmp/xyzzy-startup.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      auto slog = [&](const char *msg) {
        if (sfd >= 0) {
          struct timespec ts;
          clock_gettime (CLOCK_MONOTONIC, &ts);
          char buf[256];
          int n = snprintf (buf, sizeof (buf), "[%ld.%03ld] %s\n",
                            (long)ts.tv_sec, ts.tv_nsec / 1000000, msg);
          ssize_t r __attribute__((unused)) = write (sfd, buf, n);
        }
      };

      slog ("startup begin");

      // Suppress verbose loading messages — they write to stdout
      // which corrupts the ncurses screen.
      xsymbol_value (Vload_verbose) = Qnil;

      // Load startup.l — use .l (not .lc) since .lc was compiled
      // without #-ncurses conditionals.
      int lisp_loaded = 0;
      try
        {
          lisp startup_path = Qnil;
          lisp mod = xsymbol_value (Qmodule_dir);
          if (mod != Qnil && stringp (mod))
            {
              char mpath[PATH_MAX];
              const Char *ms = xstring_contents (mod);
              int ml = xstring_length (mod);
              int i;
              for (i = 0; i < ml && i < PATH_MAX - 20; i++)
                mpath[i] = (ms[i] < 0x80) ? (char)ms[i] : '?';
              mpath[i] = 0;
              char spath[PATH_MAX];
              snprintf (spath, sizeof (spath), "%slisp/startup.l", mpath);
              struct stat st;
              if (stat (spath, &st) == 0)
                startup_path = make_string (spath);
              else
                {
                  snprintf (spath, sizeof (spath), "%sstartup.l", mpath);
                  if (stat (spath, &st) == 0)
                    startup_path = make_string (spath);
                }
              slog (spath);
            }
          slog ("loading startup.l...");
          Fload (startup_path, xcons (Kverbose, xcons (Qnil, Qnil)));
          lisp_loaded = 1;
          slog ("startup.l loaded OK");
        }
      catch (nonlocal_jump &)
        {
          slog ("startup.l FAILED");
          nonlocal_data *nld = nonlocal_jump::data ();
          if (nld->type && symbolp (nld->type))
            {
              lisp name = xsymbol_name (nld->type);
              if (stringp (name))
                {
                  const Char *s = xstring_contents (name);
                  int l = xstring_length (name);
                  char mb[256];
                  int mi = 0;
                  for (int j = 0; j < l && mi < (int)sizeof (mb) - 2; j++)
                    mb[mi++] = (s[j] < 0x80) ? (char)s[j] : '?';
                  mb[mi] = 0;
                  slog (mb);
                }
            }
        }

      // Re-establish ncurses terminal settings after Lisp loading
      // (file I/O during loading may have disrupted terminal state)
      raw ();
      noecho ();
      keypad (stdscr, TRUE);
      slog ("ncurses terminal re-initialized");

      if (!lisp_loaded)
        {
          setup_minimal_keybindings ();
          slog ("using minimal keybindings");
        }
      else
        {
          setup_ncurses_keybindings ();
          slog ("using Lisp keybindings");
        }

      if (self_test)
        {
          slog ("self-test mode");
          self_test_minibuffer ();
          if (sfd >= 0) close (sfd);
          endwin ();
          return 0;
        }

      slog ("entering command_loop");

      // Enter command loop (fetch -> dispatch -> refresh)
      // Quit (C-g outside recursive edit) throws nonlocal_jump with
      // type=toplevel, which exits command_loop. We restart unless
      // kill-xyzzy (C-x C-c) was invoked (sets g_quit_message_posted).
      while (1)
        {
          try
            {
              command_loop ();
              break;  // normal exit (lChar_EOF)
            }
          catch (nonlocal_jump &)
            {
              if (g_quit_message_posted)
                break;  // kill-xyzzy requested exit
              // Quit or other error: show message, restart loop
              nonlocal_data *nld = nonlocal_jump::data ();
              print_condition (nld);
              slog ("command_loop restarted after throw");
            }
        }

      slog ("command_loop exited");
      if (sfd >= 0) close (sfd);

      endwin ();
    }
  catch (nonlocal_jump &)
    {
      endwin ();
      fprintf (stderr, "Fatal error during initialization\n");
      return 1;
    }

  return 0;
}
