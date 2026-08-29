// completion.cc -- ミニバッファの補完エンジン (`*do-completion')。
//
// **ここは元々 src/frontend/win32/minibuf.cc にあり、POSIX フロントエンドは
// src/frontend/ncurses/ncurses-stubs.cc に写しを持っていた。** 写しの側だけが
// 直っていない、あるいは片方だけが直っている状態が実際に起きている:
//
//   * `adjust_prefix' が `Char' (2 バイト) 分しか alloca していないのに
//     ucs4_t (4 バイト) 単位で memcpy していた。Win32 側は移行済みで、
//     写しに移行前のコードが残っていた。**長いパスとマルチバイトの名前で
//     スタックを壊す**バグで、Linux ビルドで Lisp スイートを走らせられる
//     ようにするまで誰も踏めなかった (issue #49)。
//   * 補完の突き合わせを「大文字小文字を区別しない」で決め打ちしていた
//     (issue #111)。片方を直せば済む話ではなく、両方に同じ変更が要った。
//   * ポート作業中の `displog' が写しの側に 13 箇所残っていた。
//
// **どちらが正しいか分からない差分が積もるのが一番高い代償だった**ので、
// 1 本にする。補完はプラットフォームに依らない: ファイルシステムを触る所は
// すべて WINFS (src/core/vfs.h) 越しで、シンボルとバッファは core のもの。
// 唯一プラットフォームに固有なのは UNC (`//server/share') の列挙で、そこだけ
// `#ifdef _WIN32' で囲んである。
//
// 一本化にあたって採った側と理由:
//
//   * ディレクトリを開けなかったときは `file_error' を上げる (Win32 側)。
//     写しは黙って 0 を返していた。**「候補が無い」と「そこを読めない」は
//     別のこと**で、後者を黙って捨てると理由が出ない。これが効くように
//     WINFS の POSIX 実装が errno を必ず立てるようにした (vfs-posix.cc)。
//   * パスの区切りは `map_sl_to_backsl' で `\' に揃えてから WINFS へ渡す
//     (Win32 側)。写しはこれを外していた。**#110 で WINFS の入口が `\' を
//     区切りとして受けるようになったので、POSIX でもこの形で通る。**
//   * `split_pathname' は `:' と `\' も区切りとして見る (Win32 側)。
//     core の `Fdirectory_namestring' がどのプラットフォームでも両方を
//     区切りとして扱うので、**補完だけが違う解釈をしているとずれる。**
//   * 知らない type には多値で `nil nil' を返す (Win32 側)。写しは補完を
//     一度も走らせないまま `result ()' を返していて、戻り値の約束が違って
//     いた。

#include "stdafx.h"
#include "ed.h"

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
  int complete_filename (const wchar_t *, lisp, lisp);
  lisp split_pathname ();
#ifdef _WIN32
  int complete_UNC (lisp &);
#endif
public:
  completion (lisp, lisp, int);
  void complete_symbol ();
  void complete_buffer_name ();
  void complete_filename ();
  void complete_char_encoding ();
  void complete_list (lisp, int);
  lisp result () const;
};

inline void
completion::set_target (lisp string)
{
  assert (stringp (string));
  c_target = string;
  c_target_len = xstring_length (string);
}

inline void
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
      word_state ws (xsyntax_table (selected_buffer ()->lsyntax_table), Char (*p));
      for (; p < pe && ws.forward (Char (*p)) != word_state::not_inword; p++)
        ;
    }

  c_match_len = min (c_match_len, int (p - xstring_contents (c_item)));
}

void
completion::adjust_prefix (lisp prefix)
{
  int l = xstring_length (prefix) + c_match_len;
  ucs4_t *b = (ucs4_t *)alloca (sizeof (ucs4_t) * l);
  memcpy (b, xstring_contents (prefix), xstring_length (prefix) * sizeof (ucs4_t));
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

  // パッケージ名の補完
  if (!mss.pkg_end ())
    for (lisp p = xsymbol_value (Vpackage_list); consp (p); p = xcdr (p))
      {
        lisp x = xcar (p);
        // なにも export していないパッケージは補完候補に出さない
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

int
completion::complete_filename (const wchar_t *path, lisp show_dots, lisp ignores)
{
  int ignored = 0;

  /* Room for the '/' that gets appended to directory names. */
  WIN32_FIND_DATAW *fd = (WIN32_FIND_DATAW *)alloca (sizeof *fd + 2 * sizeof (wchar_t));
  HANDLE h = WINFS::FindFirstFile (path, fd);
  if (h == INVALID_HANDLE_VALUE)
    {
      int e = GetLastError ();
      if (e != ERROR_FILE_NOT_FOUND)
        file_error (e, c_string);
      return 0;
    }

  find_handle fh (h);
  do
    {
#ifndef PATHNAME_ESCAPE_TILDE
      if (*fd->cFileName == '~' && !fd->cFileName[1])
        continue;
#endif
      if (show_dots == Qnil && *fd->cFileName == '.')
        continue;
      if (fd->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        wcscat (fd->cFileName, L"/");
      else if (c_type == Kdirectory_name)
        continue;

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
      /* **突き合わせの大文字小文字はファイルシステムに合わせる**
         (src/core/vfs.h の WINFS::case_insensitive_names)。ここは長く 1 の
         決め打ちで、Win32 では正しいが POSIX では打った字を書き換えて
         存在しないパスを作っていた (issue #111)。 */
      if (!do_completion (name, WINFS::case_insensitive_names))
        destruct_string (name);
    ignore:
      ;
    }
  while (WINFS::FindNextFile (h, fd));
  return ignored;
}

lisp
completion::split_pathname ()
{
  const ucs4_t *p0 = xstring_contents (c_target);
  const ucs4_t *pe = p0 + xstring_length (c_target);
  const ucs4_t *p;
  for (p = pe;
       p > p0 && p[-1] != ':' && p[-1] != '/' && p[-1] != '\\';
       p--)
    ;
  set_target (make_string (p, pe - p));

  pe = p;
  if (pe - p0 >= 2)
    {
      p = p0;
      if ((*p == '/' || *p == '\\')
          && (p[1] == '/' || p[1] == '\\'))
        {
          int n = 0;
          for (p += 2; p < pe; p++)
            if ((*p == '/' || *p == '\\') && ++n == 2)
              break;
          if (n < 2)
            return make_string (p0, pe - p0);
        }
    }

  if (!c_target_len)
    {
      lisp x = Fnamestring (make_string (p0, pe - p0));
      if (xstring_length (x)
          && xstring_contents (x)[xstring_length (x) - 1] != '/')
        {
          ucs4_t *b = (ucs4_t *)xmalloc ((xstring_length (x) + 1) * sizeof (ucs4_t));
          memcpy (b, xstring_contents (x), xstring_length (x) * sizeof (ucs4_t));
          b[xstring_length (x)++] = '/';
          xfree (xstring_contents (x));
          xstring_contents (x) = b;
        }
      return x;
    }

  return Fdirectory_namestring (make_string (p0, pe - p0));
}

#ifdef _WIN32
/* **UNC (`//server/share') の列挙だけがプラットフォームに固有。**
   `Flist_servers' / `Flist_server_resources' は Win32 のネットワーク列挙
   (WNetOpenEnum) で、POSIX には対応するものが無い。

   POSIX で無条件に通してはいけない理由は「候補が出ない」ことではなく、
   **`//usr/' のような普通のパスを UNC と誤判定して補完を止めてしまう**
   ことである (POSIX では先頭の `//' は `/' と同じ意味で、`//usr/' は
   `/usr/' として実在する)。 */
int
completion::complete_UNC (lisp &directory)
{
  const ucs4_t *p0 = xstring_contents (directory);
  const ucs4_t *pe = p0 + xstring_length (directory);
  int l = pe - p0;
  if (l < 2 || *p0 != '/' || p0[1] != '/')
    return 0;
  const ucs4_t *p;
  for (p = p0 + 2; p < pe && *p != '/'; p++)
    ;
  for (; pe > p && pe[-1] == '/'; pe--)
    ;
  if (p != pe)
    return 0;
  suppress_gc sgc;
  if (p == p0 + 2)
    {
      directory = make_string (p0, 2);
      for (lisp r = Flist_servers (Qnil); consp (r); r = xcdr (r))
        complete_with_slash (xcar (r), 1);
    }
  else
    {
      directory = make_string (p0, pe - p0 + 1);
      p0 += 2;
      for (lisp r = Flist_server_resources (make_string (p0, pe - p0), Qnil);
           consp (r); r = xcdr (r))
        complete_with_slash (xcar (r), 1);
    }
  return 1;
}
#endif /* _WIN32 */

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

#ifdef _WIN32
  if (!complete_UNC (directory))
#endif
    {
      wchar_t *path = (wchar_t *)alloca ((i2wl (xstring_contents (directory),
                                               xstring_length (directory)) + 2)
                                         * sizeof (wchar_t));
      i2w (xstring_contents (directory), xstring_length (directory), path);
      /* **区切りを `\' に揃えてから WINFS へ渡す。** POSIX でもこの形で
         通る: WINFS の入口 (os_path) が `\' を区切りとして受ける (#110)。
         core のパス層自体がどのプラットフォームでも両方を区切りとして
         扱うので、ここで方言を分けると補完だけが違う解釈になる。 */
      map_sl_to_backsl (path);
      wcscat (path, L"*");

      if (complete_filename (path, show_dots, ignores) && c_item == Qnil)
        complete_filename (path, show_dots, Qnil);
    }

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

  completion cmplt (type, string, word && word != Qnil);

  if (type == Ksymbol_name || type == Kfunction_name
      || type == Kcommand_name || type == Kvariable_name
      || type == Knon_trivial_symbol_name)
    cmplt.complete_symbol ();
  else if (type == Kexist_file_name || type == Kfile_name
           || type == Kfile_name_list || type == Kdirectory_name)
    cmplt.complete_filename ();
  else if (type == Kbuffer_name || type == Kexist_buffer_name)
    cmplt.complete_buffer_name ();
  else if (type == Kchar_encoding || type == Kexact_char_encoding)
    cmplt.complete_char_encoding ();
  else if (type == Klist)
    cmplt.complete_list (list ? list : Qnil, 0);
  else if (type == Klist_ignore_case)
    cmplt.complete_list (list ? list : Qnil, 1);
  else
    {
      multiple_value::count () = 2;
      multiple_value::value (1) = Qnil;
      return Qnil;
    }

  return cmplt.result ();
}

