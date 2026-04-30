#include "stdafx.h"
#include "ed.h"
#include "ts.h"
#include <tree_sitter/api.h>

lts_grammar *
make_ts_grammar ()
{
  lts_grammar *p = ldata <lts_grammar, Tts_grammar>::lalloc ();
  p->name = Qnil;
  p->lang = 0;
  p->hmod = 0;
  p->loaded = 0;
  return p;
}

/* (si:load-ts-grammar DLL-PATH LANG-NAME)
   DLL-PATH: path to grammar DLL (.so / .dll)
   LANG-NAME: ASCII language name, e.g. "c"
   Returns a ts-grammar object, or signals an error. */
lisp
Fsi_load_ts_grammar (lisp lpath, lisp lname)
{
  check_string (lpath);
  check_string (lname);

  int plen = xstring_length (lpath);
  if (plen > PATH_MAX)
    FEsimple_error (Epath_name_too_long, lpath);

  wchar_t wpath[PATH_MAX + 1];
  memcpy (wpath, xstring_contents (lpath), plen * sizeof (wchar_t));
  wpath[plen] = 0;

  /* Build entry point name: "tree_sitter_" + lang (ASCII only) */
  int nlen = xstring_length (lname);
  char entry[64];
  if (nlen > 40)
    nlen = 40;
  strcpy (entry, "tree_sitter_");
  const Char *nc = xstring_contents (lname);
  for (int i = 0; i < nlen; i++)
    entry[12 + i] = (char)(nc[i] & 0x7f);
  entry[12 + nlen] = 0;

  HMODULE h = GetModuleHandleW (wpath);
  int loaded_by_us = 0;
  if (!h)
    {
      h = LoadLibraryW (wpath);
      if (!h)
        FEsimple_win32_error (GetLastError (), lpath);
      loaded_by_us = 1;
    }

  typedef const void *(*ts_lang_fn) ();
  ts_lang_fn fn = (ts_lang_fn) GetProcAddress (h, entry);
  if (!fn)
    {
      if (loaded_by_us)
        FreeLibrary (h);
      FEsimple_error (Ets_dll_entry_not_found, lname);
    }

  const void *lang = fn ();
  if (!lang)
    {
      if (loaded_by_us)
        FreeLibrary (h);
      FEsimple_error (Ets_dll_entry_not_found, lname);
    }

  lts_grammar *g = make_ts_grammar ();
  g->name = lname;
  g->lang = lang;
  g->hmod = h;
  g->loaded = loaded_by_us;
  return g;
}

/* Flatten buffer chunks to a contiguous UTF-16 array.
   Returns xmalloc'd buffer; caller must xfree.  *out_ncu receives code unit count. */
static Char *
flatten_buffer (Buffer *bp, int *out_ncu)
{
  int total = 0;
  for (Chunk *c = bp->b_chunkb; c; c = c->c_next)
    total += c->c_used;

  Char *buf = (Char *) xmalloc ((total + 1) * sizeof (Char));
  Char *p = buf;
  for (Chunk *c = bp->b_chunkb; c; c = c->c_next)
    {
      memcpy (p, c->c_text, c->c_used * sizeof (Char));
      p += c->c_used;
    }
  buf[total] = 0;
  *out_ncu = total;
  return buf;
}

/* Convert a code-unit offset to code-point offset by scanning chunks. */
static point_t
cu_to_cp (Buffer *bp, int cu_offset)
{
  point_t cp = 0;
  int remaining = cu_offset;
  for (Chunk *c = bp->b_chunkb; c && remaining > 0; c = c->c_next)
    {
      int take = (remaining < c->c_used) ? remaining : c->c_used;
      const Char *p = c->c_text;
      const Char *end = p + take;
      while (p < end)
        {
          Char cc = *p++;
          cp++;
          if (cc >= 0xD800 && cc <= 0xDBFF && p < end && *p >= 0xDC00 && *p <= 0xDFFF)
            p++;  /* surrogate pair: two cu = one cp */
        }
      remaining -= take;
    }
  return cp;
}

/* (si:ts-query-buffer GRAMMAR QUERY-SOURCE &optional BUFFER)
   Parse BUFFER (default: current buffer) with GRAMMAR, run QUERY-SOURCE.
   Returns a list of (CAPTURE-NAME START-CP END-CP) per capture, in order. */
lisp
Fsi_ts_query_buffer (lisp lgrammar, lisp lquery, lisp lbuffer)
{
  check_ts_grammar (lgrammar);
  check_string (lquery);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);

  const TSLanguage *lang = (const TSLanguage *) xts_grammar_lang (lgrammar);

  int ncu;
  Char *text = flatten_buffer (bp, &ncu);

  TSParser *parser = ts_parser_new ();
  if (!parser)
    {
      xfree (text);
      FEsimple_error (Ets_parse_failed);
    }

  if (!ts_parser_set_language (parser, lang))
    {
      ts_parser_delete (parser);
      xfree (text);
      FEsimple_error (Ets_language_abi_mismatch);
    }

  TSTree *tree = ts_parser_parse_string_encoding (
    parser, NULL,
    (const char *) text,
    (uint32_t)(ncu * sizeof (Char)),
    TSInputEncodingUTF16LE);

  if (!tree)
    {
      ts_parser_delete (parser);
      xfree (text);
      FEsimple_error (Ets_parse_failed);
    }

  /* Build query: convert UTF-16 query string to UTF-8 for ts_query_new */
  int qlen16 = xstring_length (lquery);
  int qbuf_size = qlen16 * 3 + 1;
  char *qbuf = (char *) xmalloc (qbuf_size);
  int qlen8 = WideCharToMultiByte (CP_UTF8, 0,
                                   (LPCWSTR) xstring_contents (lquery), qlen16,
                                   qbuf, qbuf_size - 1, NULL, NULL);
  qbuf[qlen8] = 0;

  uint32_t qerr_offset = 0;
  TSQueryError qerr_type = TSQueryErrorNone;
  TSQuery *query = ts_query_new (lang, qbuf, (uint32_t) qlen8,
                                 &qerr_offset, &qerr_type);
  xfree (qbuf);

  if (!query)
    {
      ts_tree_delete (tree);
      ts_parser_delete (parser);
      xfree (text);
      FEsimple_error (Ets_invalid_query, make_fixnum (qerr_offset));
    }

  TSQueryCursor *cursor = ts_query_cursor_new ();
  ts_query_cursor_exec (cursor, query, ts_tree_root_node (tree));

  lisp result = Qnil;
  TSQueryMatch match;
  while (ts_query_cursor_next_match (cursor, &match))
    {
      for (uint16_t i = 0; i < match.capture_count; i++)
        {
          const TSQueryCapture *cap = &match.captures[i];
          uint32_t name_len;
          const char *name = ts_query_capture_name_for_id (query, cap->index, &name_len);

          uint32_t start_byte = ts_node_start_byte (cap->node);
          uint32_t end_byte   = ts_node_end_byte   (cap->node);

          int start_cu = (int)(start_byte / sizeof (Char));
          int end_cu   = (int)(end_byte   / sizeof (Char));

          point_t start_cp = cu_to_cp (bp, start_cu);
          point_t end_cp   = cu_to_cp (bp, end_cu);

          lisp cap_name = make_string (name, (int) name_len);
          lisp span = list (cap_name, make_fixnum (start_cp), make_fixnum (end_cp));
          result = xcons (span, result);
        }
    }

  ts_query_cursor_delete (cursor);
  ts_query_delete (query);
  ts_tree_delete (tree);
  ts_parser_delete (parser);
  xfree (text);

  return Fnreverse (result);
}

lisp
Fsi_ts_grammar_p (lisp x)
{
  return ts_grammar_p (x) ? Qt : Qnil;
}
