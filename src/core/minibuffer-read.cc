// minibuffer-read.cc -- `read-string' / `read-file-name' / `completing-read' など、
// ミニバッファで読む Lisp 関数の入口。
//
// **ここは元々 src/frontend/win32/minibuf.cc にあり、端末フロントエンドでは
// 全部が `return Qnil' のスタブだった** (issue #114):
//
//   lisp Fread_string (lisp, lisp) { return Qnil; }
//   ... 15 個
//
// **未実装だったのではない。** ミニバッファを読む土台は端末側にも実装済みで、
// しかも win32 側とシグネチャが一致していた。繋いでいなかっただけである。
// `C-x C-f' や `M-x' のプロンプトが端末でもちゃんと出ていたのはそのためで
// (interactive の指定は src/core/eval.cc が土台を直接呼ぶ)、**Lisp から
// `read-string' を呼んだときだけ、何も聞かずに nil が返っていた。**
//
// エラーではなく nil なので、呼んだ側は「空文字列を入力された」あるいは
// 「取り消された」と解釈して静かに違うことをする。`M-x set-variable' の
// 「Value: 」、略称の展開 (lisp/abbrev.l)、ispell の「Replace with: 」などが
// これを踏んでいた。
//
// フロントエンドに残る seam は 4 つだけで、src/core/fns.h で宣言している:
//
//   read_minibuffer         ミニバッファを 1 回読む (これが土台)
//   complete_read           補完付きで読む
//   read_filename           ファイル名として読む
//   minibuffer_read_integer 整数として読む
//
// ここに置いてあるのは「キーワード引数をほどいて土台を呼ぶ」だけの薄い包みで、
// プラットフォームに固有なものは無い。
//
// `Fminibuffer_buffer' も一緒に移した。**写しの側は別のものを返していた**:
// core が返すべきなのは「そのミニバッファに入った時点で選ばれていたバッファ」
// (read_minibuffer が `lminibuffer_buffer' に控える) で、端末側は
// 「ミニバッファウィンドウに表示されているバッファ」= ミニバッファ自身を
// 返していた。引数も見ていない。`lisp/dabbrev.l' がミニバッファでの補完に
// これを使うので、**端末ではミニバッファ自身の文字しか候補にならなかった。**

#include "stdafx.h"
#include "ed.h"

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
