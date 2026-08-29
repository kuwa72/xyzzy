#include "stdafx.h"
#include "ed.h"

static int minibuffer_recursive_level;

static Buffer *
create_minibuffer ()
{
  char b[32];
  sprintf (b, " *Minibuf%d*", minibuffer_recursive_level);
  return Buffer::make_internal_buffer (b);
}

static lisp
load_default (const char *fmt, lisp keys, int number)
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
  return load_default ("default%d", keys, number);
}

lisp
load_history (lisp keys, int number)
{
  return load_default ("history%d", keys, number);
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
  return load_default ("title%d", keys, number);
}

static int
insert_default (Window *wp, lisp def, int noselect)
{
  point_t opoint = wp->w_point.p_point;
  if (stringp (def))
    {
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
      if (!wp->w_bufp->insert_chars_internal (wp->w_point,
                                              defc, dp - defc, 1))
        return 0;
      if (noselect)
        return 1;
      if (wp->w_point.p_point != opoint)
        Fstart_selection (make_fixnum (Buffer::SELECTION_REGION), Qt, 0);
    }
  wp->w_bufp->goto_char (wp->w_point, opoint);
  return 1;
}

static int
count_prompt_columns (const ucs4_t *s, int l)
{
  int n = 0;
  for (const ucs4_t *se = s + l; s < se; s++)
    n += char_width (*s);
  return n;
}

lisp
read_minibuffer (const ucs4_t *prompt, long prompt_length, lisp def,
                 lisp type, lisp compl, lisp history,
                 int noselect, int completion, int must_match,
                 lisp title, int opt_arg)
{
  static int last_ime_mode = kbd_queue::IME_MODE_OFF;

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
  if (bp->lmap == Qunbound)
    bp->lmap = Qnil;

  WindowConfiguration wc;

  protect_gc gcpro4 (type);
  protect_gc gcpro5 (compl);

  bp->run_hook (Venter_minibuffer_hook, bp->lbp, history);

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
  bp->b_ime_mode = last_ime_mode;
  last_ime_mode = kbd_queue::IME_MODE_OFF;

  Window *mini = Window::minibuffer_window ();
  mini->set_buffer_params (bp);

  mini->set_window ();
  mini->w_flags = 0;
  minibuffer_recursive_level++;

  lisp result = Qnil;
  lisp nld_type = 0, nld_id = 0;
  int abnormal_exit = 0;
  try
    {
      if (insert_default (mini, def, noselect))
        main_loop ();
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
  protect_gc gcpro2 (nld_id);  // nld_type is a symbol.

  bp->lcomplete_type = Qnil;
  bp->lcomplete_list = Qnil;

  bp->b_prompt = 0;
  bp->b_prompt_length = 0;
  bp->b_prompt_columns = 0;
  *bp->b_prompt_arg = 0;
  if (xsymbol_value (Vminibuffer_save_ime_status) != Qnil)
    last_ime_mode = bp->b_ime_mode;

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
      bp->run_hook (Vexit_minibuffer_hook, bp->lbp, contents);
    }

  bp->lminibuffer_buffer = Qnil;
  bp->lvar = Qnil;
  bp->ldialog_title = Qnil;
  bp->lminibuffer_default = Qnil;

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
    {
      lisp package = coerce_to_package (0);
      lisp lpkg = symbol_value (Vbuffer_package, selected_buffer ());
      if (stringp (lpkg))
        {
          lpkg = Ffind_package (lpkg);
          if (lpkg != Qnil)
            package = lpkg;
        }

      ucs4_t *b = xstring_contents (string);
      int l = xstring_length (string);

      maybe_symbol_string mss (package);
      mss.parse (b, l);
      package = mss.current_package ();

      if (!mss.pkg_end ())
        return Fintern (string, 0);

      return Fintern (make_string (b, (xstring_contents (string)
                                       + xstring_length (string) - b)),
                      package);
    }

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
  assert (stringp (string));
  int l = xstring_length (string);
  return parse_integer (string, 0, l, 10, 1);
}

lisp
Fquit_recursive_edit (lisp silent)
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
  return Qnil; /* avoid warning */
}

lisp
Fexit_recursive_edit (lisp value)
{
  nonlocal_data *nld = nonlocal_jump::data ();
  nld->type = Qexit_this_level;
  nld->value = value ? value : Qnil;
  nld->tag = Qnil;
  nld->id = Qnil;
  throw nonlocal_jump ();
  /*NOTREACHED*/
  return Qnil; /* avoid warning */
}

/* 補完エンジン (class completion と Fdo_completion) は src/core/completion.cc
   へ移した。**ここと src/frontend/ncurses/ncurses-stubs.cc に同じものが 2 つ
   あり、片方だけが直っている状態が実際に何度も起きていた** (issue #49 の
   スタック破壊、issue #111 の大文字小文字)。プラットフォームに固有なのは
   UNC の列挙だけで、それは core 側で `#ifdef _WIN32' に入っている。 */

lisp
Fminibuffer_completion_type (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lcomplete_type;
}

lisp
Fminibuffer_completion_list (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lcomplete_list;
}

lisp
Fminibuffer_buffer (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lminibuffer_buffer;
}

lisp
Fminibuffer_dialog_title (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->ldialog_title;
}

lisp
Fminibuffer_default (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lminibuffer_default;
}

static lisp
complete_read (lisp prompt, lisp def, lisp type, lisp compl,
               lisp history, int must_match, lisp keys)
{
  check_string (prompt);
  lisp x = find_keyword (Khistory, keys);
  if (x != Qnil)
    history = x;
  return complete_read (xstring_contents (prompt), xstring_length (prompt),
                        def, type, compl, history, must_match, -1);
}

lisp
Fread_string (lisp prompt, lisp keys)
{
  check_string (prompt);
  return read_minibuffer (xstring_contents (prompt), xstring_length (prompt),
                          find_keyword (Kdefault, keys), Qnil, Qnil,
                          find_keyword (Khistory, keys), 0, 0, 0, Qnil, -1);
}

lisp
Fread_function_name (lisp prompt, lisp keys)
{
  return complete_read (prompt, find_keyword (Kdefault, keys),
                        Kfunction_name, Qnil, Ksymbol_name, 1, keys);
}

lisp
Fread_command_name (lisp prompt, lisp keys)
{
  return complete_read (prompt, find_keyword (Kdefault, keys),
                        Kcommand_name, Qnil, Ksymbol_name, 1, keys);
}

lisp
Fread_symbol_name (lisp prompt, lisp keys)
{
  return complete_read (prompt, find_keyword (Kdefault, keys),
                        Ksymbol_name, Qnil, Ksymbol_name, 1, keys);
}

lisp
Fread_variable_name (lisp prompt, lisp keys)
{
  return complete_read (prompt, find_keyword (Kdefault, keys),
                        Kvariable_name, Qnil, Ksymbol_name, 1, keys);
}

static lisp
read_filename (lisp prompt, lisp keys, lisp type)
{
  check_string (prompt);
  return read_filename (xstring_contents (prompt), xstring_length (prompt),
                        type, find_keyword (Ktitle, keys),
                        find_keyword (Kdefault, keys),
                        find_keyword (Khistory, keys));
}

lisp
Fread_file_name (lisp prompt, lisp keys)
{
  return read_filename (prompt, keys, Kfile_name);
}

lisp
Fread_file_name_list (lisp prompt, lisp keys)
{
  return read_filename (prompt, keys, Kfile_name_list);
}

lisp
Fread_exist_file_name (lisp prompt, lisp keys)
{
  return read_filename (prompt, keys, Kexist_file_name);
}

lisp
Fread_directory_name (lisp prompt, lisp keys)
{
  return read_filename (prompt, keys, Kdirectory_name);
}

lisp
Fread_buffer_name (lisp prompt, lisp keys)
{
  lisp def = find_keyword (Kdefault, keys);
  if (def == Qnil)
    def = Fother_buffer (0);
  if (bufferp (def))
    def = Fbuffer_name (def);
  return complete_read (prompt, def, Kbuffer_name, Qnil, Kbuffer_name, 0, keys);
}

lisp
Fread_exist_buffer_name (lisp prompt, lisp keys)
{
  lisp def = find_keyword (Kdefault, keys);
  if (def == Qnil)
    def = Fselected_buffer ();
  if (bufferp (def))
    def = Fbuffer_name (def);
  return complete_read (prompt, def, Kexist_buffer_name, Qnil, Kbuffer_name, 1, keys);
}

lisp
Fread_integer (lisp prompt, lisp)
{
  check_string (prompt);
  return minibuffer_read_integer (xstring_contents (prompt), xstring_length (prompt));
}

lisp
Fread_sexp (lisp prompt, lisp)
{
  check_string (prompt);
  return funcall_1 (Vread_from_string,
                    read_minibuffer (xstring_contents (prompt), xstring_length (prompt),
                                     Qnil, Klisp_sexp, Qnil, Klisp_sexp, 0, 0, 0, Qnil, -1));
}

lisp
Fread_char_encoding (lisp prompt, lisp keys)
{
  check_string (prompt);
  return complete_read (prompt, Qnil, Kchar_encoding,
                        Qnil, Kchar_encoding, 1, keys);
}

lisp
Fread_exact_char_encoding (lisp prompt, lisp keys)
{
  check_string (prompt);
  return complete_read (prompt, Qnil, Kexact_char_encoding,
                        Qnil, Kchar_encoding, 1, keys);
}

lisp
Fcompleting_read (lisp prompt, lisp compl, lisp keys)
{
  return complete_read (prompt,
                        find_keyword (Kdefault, keys),
                        find_keyword_bool (Kcase_fold, keys) ? Klist_ignore_case : Klist,
                        compl, Qnil,
                        find_keyword_bool (Kmust_match, keys),
                        keys);
}
