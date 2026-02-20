// ncurses frontend for xyzzy - terminal-based editor UI
// Links xyzzy-core (no Win32 GUI) + ncurses for display/input

#include "stdafx.h"
#include "ed.h"

#include <locale.h>
#include <signal.h>
#include <execinfo.h>
#include <ncurses.h>

#include "lex.h"
#include "environ.h"
#include "except.h"
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
lisp Fmake_syntax_table ();

static void crash_handler (int sig)
{
  endwin ();
  void *frames[64];
  int n = backtrace (frames, 64);
  fprintf (stderr, "\n=== Signal %d ===\n", sig);
  backtrace_symbols_fd (frames, n, 2);
  _exit (1);
}

static volatile int g_need_resize = 0;

static void sigwinch_handler (int)
{
  g_need_resize = 1;
}

int main (int argc, char **argv)
{
  signal (SIGSEGV, crash_handler);
  signal (SIGABRT, crash_handler);
  signal (SIGWINCH, sigwinch_handler);

  // Lisp engine init (same as cli-main.cc)
  init_ucs2_table ();

  try
    {
      init_syms ();

      // Minimal symbol values
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

      init_readtable ();
      init_condition ();
      init_char_encoding ();
      create_std_streams ();

      // Use terminal-io for standard I/O
      xsymbol_value (Vstandard_input) = xsymbol_value (Vterminal_io);
      xsymbol_value (Vstandard_output) = xsymbol_value (Vterminal_io);

      // ncurses init
      setlocale (LC_ALL, "");
      initscr ();
      raw ();
      noecho ();
      keypad (stdscr, TRUE);
      start_color ();
      use_default_colors ();

      // Show a message and wait for a key
      mvprintw (0, 0, "xyzzy-ncurses: press any key to exit");
      refresh ();
      getch ();

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
