// CLI frontend for xyzzy - links only xyzzy-core (no Win32 GUI)
// This serves as the core separation quality test.

#include "stdafx.h"
#include "ed.h"

#ifndef _WIN32
#include <execinfo.h>
#include <signal.h>
static void crash_handler(int sig) {
  void *frames[64];
  int n = backtrace(frames, 64);
  fprintf(stderr, "\n=== Signal %d ===\n", sig);
  backtrace_symbols_fd(frames, n, 2);
  _exit(1);
}
#endif
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

int main (int argc, char **argv)
{
#ifndef _WIN32
  signal(SIGSEGV, crash_handler);
  signal(SIGABRT, crash_handler);
#endif
  fprintf (stderr, "xyzzy-cli: core separation test\n");
  fprintf (stderr, "Lisp engine init...\n");

  init_ucs2_table ();

  try
    {
      init_syms ();
      fprintf (stderr, "  init_syms done\n");

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

      fprintf (stderr, "  basic init done\n");

      create_std_streams ();

      // CLI: use terminal-io (stdin/stdout file stream) for standard I/O
      // instead of keyboard/status streams which are Win32 GUI specific
      xsymbol_value (Vstandard_input) = xsymbol_value (Vterminal_io);
      xsymbol_value (Vstandard_output) = xsymbol_value (Vterminal_io);

      fprintf (stderr, "  streams ready\n");
      fprintf (stderr, "xyzzy-cli ready. Type Lisp expressions:\n");

      // Simple REPL
      lisp sin = xsymbol_value (Vstandard_input);
      lisp sout = xsymbol_value (Vstandard_output);
      lisp eof_marker = xcons (Qt, Qt);  // unique object as EOF sentinel

      while (1)
        {
          fprintf (stdout, "> ");
          fflush (stdout);

          try
            {
              lisp form = Fread (sin, Qnil, eof_marker, Qnil);
              if (form == eof_marker)
                break;

              lex_env lex;
              lisp result = eval (form, lex);

              Fwrite (result, sout);
              Fterpri (sout);
            }
          catch (nonlocal_jump &)
            {
              print_condition (nonlocal_jump::data ());
              fprintf (stderr, "\n");
            }
        }

      fprintf (stderr, "\nxyzzy-cli: bye\n");
    }
  catch (nonlocal_jump &)
    {
      fprintf (stderr, "Fatal error during initialization\n");
      return 1;
    }

  return 0;
}
