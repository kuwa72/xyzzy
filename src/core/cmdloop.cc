// Core command loop: keymap dispatch + main editing loop
// Extracted from src/frontend/win32/toplev.cc
// Platform-independent: calls refresh_screen() and pending_refresh_screen()
// which are provided by each frontend.

#include "stdafx.h"
#include "ed.h"
#include "Window.h"
#include "vfs.h"
#ifdef _WIN32
#include "mainframe.h"
#endif

class keyvec
{
  lisp v_buf[64];
  long v_length;
  long v_size;
  lisp *v_vec;
  int v_finished;
public:
  keyvec () : v_length (0), v_size (numberof (v_buf)), v_vec (v_buf), v_finished (1) {}
  ~keyvec () {if (v_vec != v_buf) free (v_vec);}
  void init ();
  void finish () {v_finished = 1;}
  int finished_p () const {return v_finished;}
  lisp lookup (Char c) {return lookup_keymap (c, v_vec, v_length);}
  void translate (lisp, lisp);
  void gc_mark_object (void (*)(lisp));
};

void
keyvec::init ()
{
  Buffer *bp = selected_buffer ();
  long l, n;

  if (safe_fixnum_value (Flist_length (bp->lminor_map), &l))
    {
      n = l + 3;
      if (n > v_size)
        {
          long size = (n + 63) & ~63;
          lisp *x = (lisp *)malloc (sizeof *x * size);
          if (x)
            {
              if (v_vec != v_buf)
                free (v_vec);
              v_vec = x;
              v_size = size;
            }
        }
      n = min (n, v_size) - 2;
      l = 0;
      v_vec[l++] = Fcurrent_selection_keymap ();
      for (lisp p = bp->lminor_map; consp (p) && l < n; l++, p = xcdr (p))
        v_vec[l] = xcar (p);
    }
  else
    {
      l = 0;
      v_vec[l++] = Fcurrent_selection_keymap ();
    }

  v_vec[l++] = bp->lmap;
  v_vec[l++] = xsymbol_value (Vglobal_keymap);
  v_length = l;
  v_finished = 0;
}

void
keyvec::translate (lisp old_command, lisp new_command)
{
  for (long i = 0; i < v_length; i++)
    if (v_vec[i] == old_command)
      v_vec[i] = new_command;
}

void
keyvec::gc_mark_object (void (*fn)(lisp))
{
  for (long i = 0; i < v_length; i++)
    (*fn)(v_vec[i]);
}

static keyvec g_map;

void
toplev_gc_mark (void (*fn)(lisp))
{
  g_map.gc_mark_object (fn);
}

int
toplev_accept_mouse_move_p ()
{
  return g_map.finished_p ();
}

int
char_mouse_move_p (Char cc)
{
  if (function_char_p (cc))
    cc = meta_function_to_function (cc & ~(CCF_SHIFT_BIT | CCF_CTRL_BIT));
  return cc == CCF_MOUSEMOVE;
}

static lisp
dispatch (lChar cc)
{
  lisp command;
  Char c = Char (cc);

  app.gc_itimer.reset ();
  app.as_itimer.reset ();
  app.last_cmd_tick = GetTickCount ();

  if (cc & LCHAR_MENU)
    {
      if (c >= MENU_ID_RANGE_MIN && c < MENU_ID_RANGE_MAX)
        command = lookup_menu_command (c);
#ifdef _WIN32
      else if (c >= TOOL_ID_RANGE_MIN && c < TOOL_ID_RANGE_MAX)
        command = g_frame.lookup_command (c);
#endif
      else
        return Qt;
      if (command == Qnil)
        return Qt;
    }
  else
    {
      if (g_map.finished_p ())
        {
          xsymbol_value (Vprefix_args) = xsymbol_value (Vnext_prefix_args);
          xsymbol_value (Vnext_prefix_args) = Qnil;
          xsymbol_value (Vprefix_value) = xsymbol_value (Vnext_prefix_value);
          xsymbol_value (Vnext_prefix_value) = Qnil;

          if (!meta_char_p (c) && !meta_function_char_p (c)
              && !function_char_p (c)
              && (DBCP (c) || (SBCP (c) && !ascii_char_p (c))))
            {
              command = symbol_value (Vdefault_input_function, selected_buffer ());
              if (command == Qnil || command == Qunbound)
                return Qt;
              goto run_command;
            }
          g_map.init ();
        }
      else if (char_mouse_move_p (c))
        return Qt;

      command = g_map.lookup (c);
      if (!command)
        {
          app.keyseq.push (c, !app.kbdq.macro_is_running ());
          Fcontinue_pre_selection ();
          app.kbdq.close_ime ();
          return Qt;
        }
    }

run_command:
  xsymbol_value (Vlast_command) = xsymbol_value (Vthis_command);
  xsymbol_value (Vthis_command) = command;
  xsymbol_value (Vlast_command_char) = make_char (Char (c));
  if (command != Qnil)
    {
      selected_buffer ()->safe_run_hook (Vpre_command_hook, 1);
      if (xsymbol_value (Vthis_command) != command)
        {
          lisp new_command = xsymbol_value (Vthis_command);
          if (Fkeymapp (new_command) != Qnil)
            {
              xsymbol_value (Vthis_command) = xsymbol_value (Vlast_command);
              g_map.translate (command, new_command);
              app.keyseq.push (c, !app.kbdq.macro_is_running ());
              Fcontinue_pre_selection ();
              app.kbdq.close_ime ();
              return Qt;
            }
          command = new_command;
        }
    }

  g_map.finish ();

  if (!app.kbdq.macro_is_running ())
    app.status_window.clear ();
  app.keyseq.done (c, !app.kbdq.macro_is_running ());
  app.kbdq.restore_ime ();
  app.kbdq.set_next_command_key ();

  selected_buffer ()->b_ime_mode = app.ime_open_mode;

  if (command == Qnil)
    {
      if (!char_mouse_move_p (CCF_MOUSEMOVE))
        {
          app.status_window.puts (Ekey_not_bound, 1);
          if (xsymbol_value (Vbeep_on_warn) != Qnil)
            Fding ();
        }
      app.kbdq.clear ();
      app.kbdq.end_last_command_key ();
      return Qnil;
    }

  lisp result = Qnil;
  try
    {
      stack_trace trace (stack_trace::apply, Scommand_execute, command, 0);
      result = Fcommand_execute (command, 0);
    }
  catch (nonlocal_jump &)
    {
      nonlocal_data *nld = nonlocal_jump::data ();
      if (nld->type == Qexit_this_level)
        throw;
      print_condition (nonlocal_jump::data ());
      app.kbdq.clear ();
    }
  protect_gc gcpro (result);
  selected_buffer ()->safe_run_hook (Vpost_command_hook, 1);
  app.kbdq.end_last_command_key ();
  erase_popup (0, 0);
  end_wait_cursor (1);
  WINFS::clear_share_cache ();
  return result;
}

void
command_loop ()
{
  dynamic_bind dynb0 (Vsi_condition_handlers, Qnil);
  dynamic_bind dynb1 (Vprefix_value, Qnil);
  dynamic_bind dynb2 (Vprefix_args, Qnil);
  dynamic_bind dynb3 (Vnext_prefix_value, Qnil);
  dynamic_bind dynb4 (Vnext_prefix_args, Qnil);
  dynamic_bind dynb5 (Vthis_command, Qnil);
  dynamic_bind dynb6 (Vlast_command, Qnil);

  save_command_key_index sck (app.kbdq);
  while (1)
    {
      if (app.kbdq.macro_is_running ())
        pending_refresh_screen ();
      else
        {
          if (stringp (xsymbol_value (Vminibuffer_message)))
            {
              xsymbol_value (Vminibuffer_message) = Qnil;
              Window *mw = Window::minibuffer_window ();
              if (mw)
                mw->w_disp_flags |= Window::WDF_WINDOW;
            }
          refresh_screen (1);
        }
      xsymbol_value (Vquit_flag) = Qnil;
      xsymbol_value (Vinhibit_quit) = Qnil;
      xsymbol_value (Vsi_find_motion) = Qt;
      xsymbol_value (Vevalhook) = Qnil;
      xsymbol_value (Vapplyhook) = Qnil;
      app.mouse.clear_move ();
      lChar c = app.kbdq.fetch (1, toplev_accept_mouse_move_p ());
      if (c == lChar_EOF)
        break;

      while (1)
        {
          dispatch (c);
          c = app.kbdq.peek (toplev_accept_mouse_move_p ());
          if (c == lChar_EOF)
            break;
          pending_refresh_screen ();
          if (!app.kbdq.macro_is_running ())
            Fundo_boundary ();
        }

      if (!app.f_auto_save_pending
          && !app.kbdq.macro_is_running ())
        {
          app.auto_save_count++;
          long interval;
          if (safe_fixnum_value (xsymbol_value (Vauto_save_interval),
                                 &interval)
              && interval > 0 && app.auto_save_count >= interval)
            app.f_auto_save_pending = 1;
        }
    }
}

lisp
execute_string (lisp string)
{
  check_stack_overflow ();
  save_command_key_index sck (app.kbdq);
  check_string (string);
  if (app.kbdq.lookup_kbd_macro (string))
    FEsimple_error (Ekbd_macro_called_recursively);
  lisp val = xsymbol_value (Vprefix_value);
  int n = val == Qnil ? 1 : fixnum_value (val);
  lisp result = Qt;
  if (xstring_length (string))
    for (int i = 0; !n || i < n; i++)
      {
        kbd_macro_context macro (app.kbdq, string);
        while (macro.running ())
          {
            xsymbol_value (Vquit_flag) = Qnil;
            xsymbol_value (Vinhibit_quit) = Qnil;
            lChar c = app.kbdq.fetch (0, 0);
            if (c == lChar_EOF)
              return result;
            result = dispatch (c);
            if (result == Qnil)
              return result;
            pending_refresh_screen ();
            QUIT;
          }
        QUIT;
      }
  return result;
}
