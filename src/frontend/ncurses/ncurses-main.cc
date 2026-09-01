// ncurses frontend for xyzzy - terminal-based editor UI
// Links xyzzy-core (no Win32 GUI) + ncurses for display/input

#include "stdafx.h"
#include "ed.h"
#include "conf.h"   // init_posix_config_paths (issue #143)
#include "Window.h"
#include "syntaxinfo.h"

#include <locale.h>
#include <signal.h>
#include <execinfo.h>
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

static void
ncurses_cleanup ()
{
  /* マウスの追跡を止め、**タイトルを元へ戻す** (`CSI 23;0t`)。起動直後に
     `CSI 22;0t` で積んだものを降ろす。解釈しない端末は CSI をそのまま
     無視するので、付けても壊れない。 */
  printf ("\033[?1002l\033[?1006l\033[23;0t");
  fflush (stdout);
  endwin ();
}

static void crash_handler (int sig, siginfo_t *info, void *)
{
  ncurses_cleanup ();
  fprintf (stderr, "\nFatal signal %d", sig);
#ifndef _WIN32
  if (info && info->si_addr)
    fprintf (stderr, " (fault address: %p)", info->si_addr);
  fprintf (stderr, "\n");
  void *frames[32];
  int n = backtrace (frames, 32);
  if (n > 0)
    backtrace_symbols_fd (frames, n, 2);
#else
  fprintf (stderr, "\n");
#endif
  signal (sig, SIG_DFL);
  raise (sig);
}

volatile int g_need_resize = 0;

static void sigwinch_handler (int)
{
  g_need_resize = 1;
}

// Helper: set module_dir if path/lisp/ exists
static int
try_module_dir (const char *dir)
{
  char path[PATH_MAX];
  snprintf (path, sizeof (path), "%slisp/", dir);
  struct stat st;
  if (stat (path, &st) == 0 && S_ISDIR (st.st_mode))
    {
      xsymbol_value (Qmodule_dir) = make_path (dir);
      return 1;
    }
  return 0;
}

// POSIX version of init_module_dir
// Search order:
//   1. XYZZYHOME env var (development override)
//   2. Compiled-in XYZZY_DATA_DIR (cmake install prefix, unix layout)
//   3. ../share/xyzzy/ relative to exe (FHS relative fallback)
//   4. exe directory (flat layout / dev build)
//   5. current directory (last resort)
static void
init_module_dir ()
{
  char path[PATH_MAX];

  // 1. XYZZYHOME environment variable
  char *xyzzyhome = getenv ("XYZZYHOME");
  if (xyzzyhome && *xyzzyhome)
    {
      int l = strlen (xyzzyhome);
      if (l > 0 && l < PATH_MAX - 2)
        {
          strcpy (path, xyzzyhome);
          if (path[l - 1] != '/')
            {
              path[l] = '/';
              path[l + 1] = 0;
            }
          if (try_module_dir (path))
            return;
        }
    }

#ifdef XYZZY_DATA_DIR
  // 2. Compiled-in install prefix data directory
  {
    snprintf (path, sizeof (path), "%s/", XYZZY_DATA_DIR);
    if (try_module_dir (path))
      return;
  }
#endif

  // 3-4. Relative to /proc/self/exe
  ssize_t len = readlink ("/proc/self/exe", path, sizeof (path) - 1);
  if (len > 0)
    {
      path[len] = 0;
      char *slash = strrchr (path, '/');
      if (slash)
        {
          // 3. ../share/xyzzy/ (FHS: exe in bin/, data in share/xyzzy/)
          char rel[PATH_MAX];
          *slash = 0;  // remove exe name
          snprintf (rel, sizeof (rel), "%s/../share/xyzzy/", path);
          char resolved[PATH_MAX];
          if (realpath (rel, resolved))
            {
              int rl = strlen (resolved);
              if (rl > 0 && resolved[rl - 1] != '/')
                {
                  resolved[rl] = '/';
                  resolved[rl + 1] = 0;
                }
              if (try_module_dir (resolved))
                return;
            }

          // 4. Exe directory (flat layout)
          slash[1] = 0;
          if (try_module_dir (path))
            return;
        }
    }

  // 5. Last resort: current directory
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

// `-config' と `-ini' の値。init () が argv から拾って、
// init_user_config_path が使う。**Win32 は init.cc がダンプ読み込みより前に
// 同じことをしている**ので、順序を合わせてある (設定の場所は Lisp が動き
// 始める前に決まっていなければならない)。
static const char *startup_config_path;
static const char *startup_ini_file;
// `-image' の値。init_lisp_engine が app.dump_image に入れる (issue #219)。
static const char *startup_dump_image;
/* `-no-image' が来たか。**既定でイメージを使うようにしたので、切る手段が
   要る** (issue #219)。3.7 MB のファイルを置きたくない、あるいは
   `lisp/` を触りながら試している場合。 */
static int startup_no_image;
// Lisp に渡す引数はここから。`-config' / `-ini' は Lisp が知らない
// (estartup.l の process-command-line-1 に case が無く、ファイル名として
// find-file されてしまう) ので、**取り除いて渡す。**
static int startup_args_from = 1;

/* **`-config' と `-ini' は Lisp が動き出す前に読み、引数から取り除く。**
   設定の場所は startup.l が (user-config-path) を使うより前に決まって
   いなければならない。

   **先頭に並んでいる分だけを見る。** Win32 の init.cc も
   `for (ac = 1; ac < wargc - 1; ac += 2) ... else break;` と同じ形で、
   途中に現れたものは触らない (`-e "(...)"` の引数に `-ini` という文字列が
   来ることもある)。 */
static void
scan_config_options (int argc, char **argv)
{
  int i = 1;
  while (i < argc)
    {
      /* `--batch' はフロントエンドの選択で、Lisp には渡らない。
         **先頭に来るので、跨がないと後ろの `-ini' が見えない**
         (unittest/simple-test.l の test-self-command が
         `<xyzzy> --batch -ini "path" -q -e "..."' の形で組む)。 */
      if (!strcmp (argv[i], "--batch"))
        {
          i++;
          continue;
        }
      /* **値を取らないので、ペアの走査を止めずに跨ぐ。** `--batch` と同じ扱い。
         Lisp 側に case が無いので、渡すとファイル名として `find-file` される。 */
      if (!strcmp (argv[i], "-no-image"))
        {
          startup_no_image = 1;
          i++;
          continue;
        }
      if (i + 1 >= argc)
        break;
      if (!strcmp (argv[i], "-config"))
        startup_config_path = argv[i + 1];
      else if (!strcmp (argv[i], "-ini"))
        startup_ini_file = argv[i + 1];
      else if (!strcmp (argv[i], "-image"))
        startup_dump_image = argv[i + 1];
      else
        break;
      i += 2;
    }
  startup_args_from = i;
}

/* **`si:*command-line-args*` を積む。** これが nil のままだと
   `estartup.l` の `process-command-line` は何もせず、`xyzzy foo.txt` が
   ファイルを開かない。**対話版はこれを積んでいなかった** ので、端末では
   引数が全部黙って捨てられていた (issue #217)。batch は積んでいたので
   `--batch -e "..."` だけが動いていて、テストは全部その形なので
   誰も気付かなかった。

   `-config` / `-ini` は `scan_config_options` が食べた分
   (`startup_args_from`) を飛ばす。Lisp 側にこの 2 つの case は無いので、
   渡すとファイル名として `find-file` される。

   `--batch` / `--self-test` はフロントエンドの選択で、Lisp には渡さない。 */
static void
init_command_line_args (int argc, char **argv)
{
  lisp p = Qnil;
  /* 後ろから前へ積む。前から `xcons` で足すと逆順になる。 */
  for (int i = argc - 1; i >= startup_args_from; i--)
    {
      if (!strcmp (argv[i], "--batch") || !strcmp (argv[i], "--self-test"))
        continue;
      p = xcons (make_string (argv[i]), p);
    }
  xsymbol_value (Vsi_command_line_args) = p;
}

// 既定は Qhome_dir。**未設定のままだと値は #:unbound で、lisp/backup.l の
// 起動時の (concat (user-config-path) ".xyzzy.d/backup/") がそれを掴んで
// 「不正なデータ型です」で startup.l ごと落ちる。**
//
// そのあと init_posix_config_paths (src/core/ini-posix.cc) が
// `-config' / `XYZZYCONFIGPATH' / `-ini' / `XYZZYINIFILE' を見て上書きし、
// app.ini_file_path を決める。Win32 の init_user_config_path /
// init_user_inifile_path に相当する (issue #143)。
static void
init_user_config_path ()
{
  xsymbol_value (Quser_config_path) = xsymbol_value (Qhome_dir);
  init_posix_config_paths (startup_config_path, startup_ini_file);
}

static void
init_load_path ()
{
  // Load path: module_dir + module_dir/lisp + module_dir/site-lisp
  lisp p = Qnil;
  lisp mod = xsymbol_value (Qmodule_dir);
  if (mod != Qnil && stringp (mod))
    {
      const ucs4_t *s = xstring_contents (mod);
      int l = xstring_length (mod);

      // module_dir/site-lisp/
      ucs4_t buf[PATH_MAX];
      const char *site = "site-lisp/";
      for (int i = 0; i < l; i++)
        buf[i] = s[i];
      for (int i = 0; site[i]; i++)
        buf[l + i] = (ucs4_t)(u_char)site[i];
      p = xcons (make_string (buf, l + 10), p);

      // module_dir/lisp/
      const char *lisp_dir = "lisp/";
      for (int i = 0; i < l; i++)
        buf[i] = s[i];
      for (int i = 0; lisp_dir[i]; i++)
        buf[l + i] = (ucs4_t)(u_char)lisp_dir[i];
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
  /* `-image' が無ければ nil のまま。**Win32 は exe 名から必ず導くので
     いつも非 nil** だが、端末版でそれを真似すると起動のたびに 4 MB の
     イメージを書こうとすることになるので、指定されたときだけ使う
     (issue #219)。 */
  xsymbol_value (Qdump_image_path) =
    *app.dump_image ? make_path (app.dump_image, 0) : Qnil;
  xsymbol_value (Qsystem_path) = make_string (argv0);
  init_module_dir ();
  init_current_dir ();
  init_environ ();
  init_home_dir ();
  init_user_config_path ();
  /* **設定を xyzzy.ini から読む。** 位置以外の設定 (行番号の表示、折り返しの
     既定など) は端末でも意味がある。init_user_config_path が
     app.ini_file_path を決めた後でなければ読む先が無いので、この順序
     (issue #143)。 */
  environ::load_settings ();
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
    ucs4_t wprompt[16];
    for (int i = 0; prompt[i]; i++)
      wprompt[i] = (ucs4_t)(unsigned char)prompt[i];

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

lisp read_minibuffer (const ucs4_t *, long, lisp, lisp, lisp, lisp, int, int, int, lisp, int);

// Common Lisp engine initialization (shared by all frontends)
/* ダンプイメージから起きたか。`load_startup` がこれを見て、Lisp の
   `si:*startup` を直に呼ぶか startup.l を読むかを決める。 */
static int startup_from_dump;

/* **`app.exe_path` を埋める。** ダンプイメージが「このバイナリのもの」かを
   判定するのに使う (src/core/data.cc の `dump_get_exe_ident`)。

   `/proc/self/exe` を先に見る。**`argv[0]` は当てにならない**: 相対パスで
   来ることがあり (`./_build/linux/xyzzy`)、`exec` した側が何を渡すかは
   自由で、`PATH` から起こされた場合は名前だけのこともある。取れなければ
   `argv[0]` に落ちる -- 判定が緩くなるだけで、壊れはしない。 */
static void
init_exe_path (const char *argv0)
{
  *app.exe_path = 0;
  char path[PATH_MAX + 1];
  ssize_t n = readlink ("/proc/self/exe", path, sizeof path - 1);
  if (n > 0)
    path[n] = 0;
  else if (argv0 && *argv0)
    {
      strncpy (path, argv0, sizeof path - 1);
      path[sizeof path - 1] = 0;
    }
  else
    return;

  /* **UTF-8 -> wchar_t をきちんと通す。** バイトをそのまま widen すると
     0x80 以上を含むパス (日本語のホームディレクトリなど) で別の名前になり、
     stat が失敗して**判定が常に不一致になる** = イメージが一度も使われない。
     `WINFS::get_file_data` は受けた wchar_t を `os_path` で UTF-8 に戻すので、
     入れる側も同じ経路で作る。 */
  size_t len = u82il (path);
  if (len > PATH_MAX)
    len = PATH_MAX;
  ucs4_t *cp = (ucs4_t *)alloca ((len + 1) * sizeof (ucs4_t));
  ucs4_t *e = u82i (path, cp);
  int l = int (e - cp);
  if (l > PATH_MAX)
    l = PATH_MAX;
  *i2w (cp, l, app.exe_path) = 0;
}

/* `want_default_image`: `-image` が無いときに設定ディレクトリの下の
   `xyzzy.wxp` を既定として使うか。

   **対話版だけ真にする。** `--batch` を既定オンにすると、テストスイートと
   `tools/bytecompile.sh` がイメージ越しに走ることになる。**イメージは Lisp
   ライブラリ全体を含むので、`.lc` を作り直してもバイナリが同じなら
   同一性判定 (`dump_exe_ident`、issue #219) では弾けない** = 古い
   ライブラリのまま測ってしまう。

   速さが要るのは人が待つ対話起動 (762ms -> 206ms) で、`--batch` は
   スイート 1 回につき 1 プロセスしか起きないので効きが小さい。**危ない側を
   既定にしない。** `--batch` でも `-image` を明示すれば使える。 */
static void
init_lisp_engine (const char *argv0, int want_default_image)
{
  init_ucs2_table ();
  init_exe_path (argv0);

  /* **`-image` が指すイメージがあれば、シンボルを作る代わりに読む。**
     Win32 の `init_lisp_objects` (src/frontend/win32/init.cc) と同じ形で、
     読めたら `combine_syms` が builtin の関数ポインタを名前で貼り直す
     (イメージに関数ポインタは入っていない、src/core/data.cc の
     `rdump_object (FILE *, lfunction *, ...)` 参照)。

     **読めなくても黙って続ける。** 初回は必ず無いし、バイナリを作り直した
     あとの古いイメージも読めない。そこで止めると `-image` を渡した端末が
     起動しなくなる。 */
  init_posix_dump_image (startup_no_image ? 0 : startup_dump_image,
                         startup_config_path,
                         startup_no_image ? 0 : want_default_image);
  startup_from_dump = *app.dump_image && rdump_xyzzy ();
  if (startup_from_dump)
    {
      combine_syms ();
      rehash_all_hash_tables ();
    }
  else
    {
      init_syms ();
      init_symbol_value_once ();
      init_condition ();
    }
  init_syntax_spec ();
  syntax_state::init_color_table ();
  init_env_symbols (argv0);
  create_std_streams ();
  init_symbol_value ();

  xsymbol_value (Vstandard_input) = xsymbol_value (Vterminal_io);
  xsymbol_value (Vstandard_output) = xsymbol_value (Vterminal_io);
}

// Find and load startup.l, returns 1 on success
static int
load_startup (void (*slog)(const char *))
{
  try
    {
      /* **イメージから起きたときは startup.l を読まない。** イメージには
         startup.l が定義した Lisp の `si:*startup` (= `(ed::startup)`) が
         入っているので、それを呼べば済む。ここで startup.l を読み直すと
         ライブラリを全部読み直すことになり、イメージを使う意味が無くなる。
         Win32 が `Ffuncall (Ssi_startup, Qnil)` 一本で済ませているのはこの
         ためで、非ダンプ時の `si:*startup` は「startup ライブラリを読む」
         builtin (`src/core/window-lisp.cc` の `Fsi_startup`) である。

         端末版はここで自前に探している (`lisp/startup.l` を**ソースで**
         読む必要がある -- `.lc` は `:ncurses` 無しで作られている) ので、
         ダンプ経路だけを分ける。 */
      if (startup_from_dump)
        {
          if (slog) slog ("starting from the dump image");
          Ffuncall (Ssi_startup, Qnil);
          if (slog) slog ("dump image startup OK");
          return 1;
        }

      lisp startup_path = Qnil;
      lisp mod = xsymbol_value (Qmodule_dir);
      if (mod != Qnil && stringp (mod))
        {
          char mpath[PATH_MAX];
          const ucs4_t *ms = xstring_contents (mod);
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
          if (slog) slog (spath);
        }
      if (slog) slog ("loading startup.l...");
      Fload (startup_path, xcons (Kverbose, xcons (Qnil, Qnil)));
      if (slog) slog ("startup.l loaded OK");
      return 1;
    }
  catch (nonlocal_jump &)
    {
      if (slog) slog ("startup.l FAILED");
      nonlocal_data *nld = nonlocal_jump::data ();
      // Convert lisp string (ucs4 code points) to UTF-8 for the log.
      auto lisp2mb = [](lisp s, char *buf, int bufsz) {
        if (!stringp (s)) return;
        const ucs4_t *p = xstring_contents (s);
        int l = xstring_length (s);
        int mi = 0;
        for (int j = 0; j < l && mi < bufsz - 5; j++)
          {
            ucs4_t wc = p[j];
            if (wc < 0x80)
              buf[mi++] = (char)wc;
            else if (wc < 0x800)
              {
                buf[mi++] = (char)(0xC0 | (wc >> 6));
                buf[mi++] = (char)(0x80 | (wc & 0x3F));
              }
            else if (wc < 0x10000)
              {
                buf[mi++] = (char)(0xE0 | (wc >> 12));
                buf[mi++] = (char)(0x80 | ((wc >> 6) & 0x3F));
                buf[mi++] = (char)(0x80 | (wc & 0x3F));
              }
            else
              {
                buf[mi++] = (char)(0xF0 | (wc >> 18));
                buf[mi++] = (char)(0x80 | ((wc >> 12) & 0x3F));
                buf[mi++] = (char)(0x80 | ((wc >> 6) & 0x3F));
                buf[mi++] = (char)(0x80 | (wc & 0x3F));
              }
          }
        buf[mi] = 0;
      };
      if (nld->type && symbolp (nld->type))
        {
          char mb[256] = {};
          lisp2mb (xsymbol_name (nld->type), mb, sizeof mb);
          if (slog) slog (mb);
        }
      if (nld->id && nld->id != Qnil)
        {
          try {
            lisp cs = Fsi_condition_string (nld->id);
            if (stringp (cs))
              {
                char mb[1024] = {};
                lisp2mb (cs, mb, sizeof mb);
                if (slog) slog (mb);
              }
          } catch (...) {}
        }
      return 0;
    }
}

// ============================================================
// NcursesFrontend
// ============================================================

class NcursesFrontend : public Frontend
{
  int m_argc;
  char **m_argv;
  int m_self_test;
  int m_log_fd;

  static void slog_cb (const char *msg)
  {
    // Uses /tmp/xyzzy-startup.log
    static int sfd = -1;
    if (sfd == -2) return;
    if (sfd < 0)
      {
        sfd = open ("/tmp/xyzzy-startup.log", O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (sfd < 0) { sfd = -2; return; }
      }
    struct timespec ts;
    clock_gettime (CLOCK_MONOTONIC, &ts);
    char buf[256];
    int n = snprintf (buf, sizeof (buf), "[%ld.%03ld] %s\n",
                      (long)ts.tv_sec, ts.tv_nsec / 1000000, msg);
    ssize_t r __attribute__((unused)) = write (sfd, buf, n);
  }

public:
  int init (int argc, char **argv) override
  {
    m_argc = argc;
    m_argv = argv;
    m_self_test = 0;
    m_log_fd = -1;

    for (int i = 1; i < argc; i++)
      if (strcmp (argv[i], "--self-test") == 0)
        m_self_test = 1;


    // SIGWINCH
    struct sigaction sa;
    sa.sa_handler = sigwinch_handler;
    sigemptyset (&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction (SIGWINCH, &sa, NULL);

    /* 既定でイメージを使う (対話起動の速さが効くのはここ)。 */
    init_lisp_engine (argv[0], 1);
    init_TitleBarStringC ();

    // ncurses init
    initscr ();
    /* **タイトルを積んでおく** (`CSI 22;0t`)。これが無いと、xyzzy が
       終わった後もシェルのタブに開いていたファイル名が残る。降ろすのは
       `ncurses_cleanup`。 */
    printf ("\033[22;0t");
    fflush (stdout);
    raw ();
    noecho ();
    keypad (stdscr, TRUE);
    start_color ();
    use_default_colors ();

    extern void ncurses_mouse_init ();
    ncurses_mouse_init ();

    /* **走っている Lisp を C-g で止められるようにする。** `QUIT` から
       間引いて端末を覗く手を入れる (src/core/quit-poll.cc、issue #162)。
       ここより前に入れても意味が無い: `initscr` の前は覗く相手が無い。 */
    extern void ncurses_install_quit_poll ();
    ncurses_install_quit_poll ();

    create_ncurses_windows ();
    create_default_buffers ();

    init_command_line_args (argc, argv);

    slog_cb ("startup begin");

    // Suppress verbose loading — corrupts ncurses screen
    xsymbol_value (Vload_verbose) = Qnil;

    int lisp_loaded = load_startup (slog_cb);

    // Re-establish terminal settings after Lisp loading
    raw ();
    noecho ();
    keypad (stdscr, TRUE);
    slog_cb ("ncurses terminal re-initialized");

    if (!lisp_loaded)
      {
        setup_minimal_keybindings ();
        slog_cb ("using minimal keybindings");
      }
    else
      {
        setup_ncurses_keybindings ();
        slog_cb ("using Lisp keybindings");
      }

    return 0;
  }

  void cleanup () override
  {
    /* **設定を書き戻す。** ここでしか書かないので、落ちたときは前回の内容が
       残る (設定は失うより古い方がまし)。**endwin より前に書く**必要は無いが、
       画面を戻した後にファイル入出力で固まると端末が壊れて見えるので前に置く。

       Win32 は toplev.cc が終了時に environ::save_geometry を呼んでいて、
       その後半と同じもの。 */
    if (app.ini_file_path)
      environ::save_settings ();
    ncurses_cleanup ();
  }

  int main_loop () override
  {
    if (m_self_test)
      {
        slog_cb ("self-test mode");
        self_test_minibuffer ();
        return 0;
      }

    slog_cb ("entering command_loop");

    while (1)
      {
        try
          {
            command_loop ();
            break;
          }
        catch (nonlocal_jump &)
          {
            if (g_quit_message_posted)
              break;
            nonlocal_data *nld = nonlocal_jump::data ();
            print_condition (nld);
            slog_cb ("command_loop restarted after throw");
          }
      }

    slog_cb ("command_loop exited");
    return 0;
  }

  // refresh_screen: uses base class default (no-op) for now;
  // the actual ncurses refresh is called directly from command_loop via
  // the C-linkage refresh_screen() function in ncurses-stubs.cc.

  int message_box (int flags, const Char *msg, const Char *title) override
  {
    int type = flags & 0x0f;
    int rows, cols;
    getmaxyx (stdscr, rows, cols);
    int row = rows - 1;

    // Show message on the last row
    move (row, 0);
    clrtoeol ();

    const char *prompt;
    if (type == 0x04 /*MB_YESNO*/)
      prompt = " (y or n) ";
    else if (type == 0x03 /*MB_YESNOCANCEL*/)
      prompt = " (y, n, or ESC) ";
    else
      prompt = " [OK] ";

    /* **`msg` は UTF-16 である。** 組んでいるのは
       `src/core/lprint.cc` の `Fmessage_box` で、surrogate pair まで作って
       いる。以前ここは `i2w (*p)` = 旧内部エンコーディングの表引きを通して
       いたので、**日本語のメッセージが全部化けていた** (issue #179)。 */
    int prompt_len = (int)strlen (prompt);
    int max_chars = cols - prompt_len - 1;
    if (max_chars < 0) max_chars = 0;

    move (row, 0);
    int col = 0;
    for (const Char *p = msg; *p && col < max_chars; p++)
      {
        if (*p == '\r' || *p == '\n')
          continue;
        cchar_t cc;
        wchar_t wc[2] = {char_to_wchar (*p), 0};
        setcchar (&cc, wc, 0, 0, NULL);
        add_wch (&cc);
        col += wcwidth (wc[0]) > 0 ? wcwidth (wc[0]) : 1;
      }
    addstr (prompt);
    curs_set (1);
    ::refresh ();

    // Wait for input
    int result;
    if (type == 0x04 /*MB_YESNO*/ || type == 0x03 /*MB_YESNOCANCEL*/)
      {
        while (1)
          {
            int ch = getch ();
            if (ch == 'y' || ch == 'Y')
              { result = 6 /*IDYES*/; break; }
            if (ch == 'n' || ch == 'N')
              { result = 7 /*IDNO*/; break; }
            if (type == 0x03 && (ch == 27 /*ESC*/ || ch == 'q' || ch == 'Q'))
              { result = 2 /*IDCANCEL*/; break; }
            if (type == 0x04 && ch == 27 /*ESC*/)
              { result = 7 /*IDNO*/; break; }
          }
      }
    else
      {
        getch ();
        result = 1 /*IDOK*/;
      }

    // Clear the prompt
    move (row, 0);
    clrtoeol ();
    ::refresh ();

    return result;
  }
};

// ============================================================
// BatchFrontend — headless mode for bytecompile etc.
// ============================================================

class BatchFrontend : public Frontend
{
public:
  int init (int argc, char **argv) override
  {
    /* **batch は `-image` を明示したときだけ。** 上の init_lisp_engine の
       コメントを参照 (古いライブラリのイメージで測ってしまう)。 */
    init_lisp_engine (argv[0], 0);
    init_TitleBarStringC ();

    // Create minimal window/buffer infrastructure
    // (many Lisp functions assume selected_window() is valid)
    create_batch_windows ();
    create_default_buffers ();

    // Set si:*command-line-args* so estartup.l's process-command-line
    // handles -q, -load, -eval, etc. (same mechanism as Win32 xyzzy-batch)
    init_command_line_args (argc, argv);

    xsymbol_value (Vload_verbose) = Qt;

    return 0;
  }

  int main_loop () override
  {
    // Load startup.l which calls si:*startup → ed::startup →
    // process-command-line (handles -q, -load, etc.) →
    // *post-startup-hook* (where bytecompile-batch.l runs)
    auto blog = [](const char *msg) {
      fprintf (stderr, "[batch] %s\n", msg);
    };

    int lisp_loaded = load_startup (blog);
    if (!lisp_loaded)
      {
        // kill-xyzzy throws exit-this-level, which is normal for batch
        if (g_quit_message_posted)
          {
            blog ("batch: exiting via kill-xyzzy");
            return app.exit_code;
          }
        fprintf (stderr, "batch: startup.l failed to load\n");
        return 1;
      }

    return app.exit_code;
  }

private:
  // Create minimal window infrastructure without ncurses
  void create_batch_windows ()
  {
    Window *wp = new Window (0, 1);
    wp->lwp = make_window ();
    xwindow_wp (wp->lwp) = wp;
    wp->w_disp_flags = Window::WDF_WINDOW | Window::WDF_MODELINE;
    wp->w_order.left = 0;
    wp->w_order.top = 0;
    wp->w_order.right = 1;
    wp->w_order.bottom = 1;

    Window *mwp = new Window (1, 1);
    mwp->lwp = make_window ();
    xwindow_wp (mwp->lwp) = mwp;
    mwp->w_disp_flags = Window::WDF_WINDOW;

    wp->w_prev = 0;
    wp->w_next = mwp;
    mwp->w_prev = wp;
    mwp->w_next = 0;

    app.active_frame.windows = wp;
    app.active_frame.selected = wp;

    // Fake terminal size for window geometry
    app.active_frame.size.cx = 80;
    app.active_frame.size.cy = 24;

    Window::compute_geometry ();
  }
};

// ============================================================
// main — select frontend based on command-line arguments
// ============================================================

int main (int argc, char **argv)
{
  /* Set up an alternate signal stack so crash_handler works even on stack overflow */
  {
    static char altstack[65536];
    stack_t ss;
    ss.ss_sp = altstack;
    ss.ss_size = sizeof(altstack);
    ss.ss_flags = 0;
    sigaltstack(&ss, NULL);
    struct sigaction sa;
    sa.sa_sigaction = crash_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_ONSTACK | SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
  }
  setlocale (LC_ALL, "");
  scan_config_options (argc, argv);

  // Determine frontend mode
  int batch_mode = 0;
  for (int i = 1; i < argc; i++)
    if (strcmp (argv[i], "--batch") == 0)
      batch_mode = 1;

  if (batch_mode)
    g_frontend = new BatchFrontend ();
  else
    g_frontend = new NcursesFrontend ();

  int rc = 0;
  try
    {
      rc = g_frontend->init (argc, argv);
      if (rc == 0)
        rc = g_frontend->main_loop ();
      g_frontend->cleanup ();
    }
  catch (nonlocal_jump &)
    {
      g_frontend->cleanup ();
      if (g_quit_message_posted)
        rc = app.exit_code;  // kill-xyzzy is normal exit for batch
      else
        {
          fprintf (stderr, "Fatal error during initialization\n");
          rc = 1;
        }
    }

  delete g_frontend;
  g_frontend = 0;
  return rc;
}
