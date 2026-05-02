#include "stdafx.h"
#include "ed.h"
#include "ts.h"
#include <tree_sitter/api.h>
#include <unordered_map>

/* Raw capture span: byte offsets + capture index.  Produced by the background
   query thread; converted to code-point offsets on the main thread. */
struct ts_span_raw
{
  uint32_t start_byte;
  uint32_t end_byte;
  uint32_t cap_index;
};

/* Per-buffer parse + query cache -------------------------------------------*/

struct lts_buf_cache
{
  TSParser         *parser;
  TSTree           *tree;
  TSQuery          *query;          /* compiled query (read by bg thread too) */
  char             *query_src;      /* UTF-8 source of cached query */
  const TSLanguage *lang;
  long              revision;       /* b_modified_count of fully-parsed tree */
  long              parse_revision; /* b_modified_count when in-progress parse started */
  int               parse_in_progress;

  /* Async query state ------------------------------------------------------- */
  volatile LONG     bg_active;     /* 1 while bg thread is running */
  volatile LONG     bg_cancel;     /* set to 1 to ask bg thread to stop early */
  HANDLE            hthread;       /* bg thread handle (NULL if none started yet) */
  ts_span_raw      *bg_spans;      /* results from last completed bg query */
  uint32_t          bg_span_count;
  long              bg_span_rev;   /* b_modified_count when bg_spans were produced */
  TSPoint           bg_sp, bg_ep;  /* point range the results cover */
  bool              bg_has_range;  /* false = full-buffer query */
};

static std::unordered_map<Buffer *, lts_buf_cache *> g_ts_cache;

/* Return the cache entry for BP, creating one if needed.
   Grammar changes flush the tree and compiled query; bg state is also reset. */
static lts_buf_cache *
get_buf_cache (Buffer *bp, const TSLanguage *lang)
{
  auto it = g_ts_cache.find (bp);
  if (it != g_ts_cache.end ())
    {
      lts_buf_cache *c = it->second;
      if (c->lang != lang)
        {
          /* Grammar changed: discard tree and query.  bg thread should not be
             running here in practice, but guard anyway. */
          if (c->tree)      { ts_tree_delete (c->tree); c->tree = nullptr; }
          if (c->query)     { ts_query_delete (c->query); c->query = nullptr; }
          xfree (c->query_src); c->query_src = nullptr;
          ts_parser_set_language (c->parser, lang);
          c->lang              = lang;
          c->revision          = -1;
          c->parse_in_progress = 0;
        }
      return c;
    }

  lts_buf_cache *c = new lts_buf_cache;
  c->parser            = ts_parser_new ();
  c->tree              = nullptr;
  c->query             = nullptr;
  c->query_src         = nullptr;
  c->lang              = lang;
  c->revision          = -1;
  c->parse_revision    = -1;
  c->parse_in_progress = 0;
  c->bg_active         = 0;
  c->bg_cancel         = 0;
  c->hthread           = NULL;
  c->bg_spans          = nullptr;
  c->bg_span_count     = 0;
  c->bg_span_rev       = -1;
  c->bg_sp             = {0, 0};
  c->bg_ep             = {0, 0};
  c->bg_has_range      = false;
  if (c->parser)
    ts_parser_set_language (c->parser, lang);
  g_ts_cache[bp] = c;
  return c;
}

/*---------------------------------------------------------------------------*/

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

/* (si:load-ts-grammar DLL-PATH LANG-NAME) */
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
      if (loaded_by_us) FreeLibrary (h);
      FEsimple_error (Ets_dll_entry_not_found, lname);
    }

  const void *lang = fn ();
  if (!lang)
    {
      if (loaded_by_us) FreeLibrary (h);
      FEsimple_error (Ets_dll_entry_not_found, lname);
    }

  lts_grammar *g = make_ts_grammar ();
  g->name   = lname;
  g->lang   = lang;
  g->hmod   = h;
  g->loaded = loaded_by_us;
  return g;
}

/* TSInput callback: read directly from buffer chunks (no full-buffer copy).
   Resumes correctly across parse interruptions because tree-sitter requests
   bytes from the exact offset where it left off. */
struct ts_parse_ctx
{
  Buffer        *bp;
  Chunk         *chunk;
  uint32_t       chunk_start_byte;
  LARGE_INTEGER  t_start;
  LARGE_INTEGER  t_freq;
};

static const char *
ts_buf_read (void *payload, uint32_t byte_index, TSPoint /*pos*/,
             uint32_t *bytes_read)
{
  ts_parse_ctx *ctx = (ts_parse_ctx *) payload;

  if (!ctx->chunk || byte_index < ctx->chunk_start_byte)
    {
      ctx->chunk            = ctx->bp->b_chunkb;
      ctx->chunk_start_byte = 0;
    }
  while (ctx->chunk)
    {
      uint32_t end = ctx->chunk_start_byte
                     + (uint32_t) ctx->chunk->c_used * sizeof (Char);
      if (byte_index < end)
        break;
      ctx->chunk_start_byte = end;
      ctx->chunk            = ctx->chunk->c_next;
    }
  if (!ctx->chunk) { *bytes_read = 0; return ""; }

  uint32_t off = byte_index - ctx->chunk_start_byte;
  *bytes_read  = (uint32_t) ctx->chunk->c_used * sizeof (Char) - off;
  return (const char *) ctx->chunk->c_text + off;
}

/* TSParseOptions progress callback: cancel after 50 ms. */
static bool
ts_progress_cb (TSParseState *state)
{
  ts_parse_ctx *ctx = (ts_parse_ctx *) state->payload;
  LARGE_INTEGER now;
  QueryPerformanceCounter (&now);
  double ms = (double)(now.QuadPart - ctx->t_start.QuadPart)
              * 1000.0 / ctx->t_freq.QuadPart;
  return ms >= 50.0;
}

/* Convert a code-unit offset to code-point offset.
   Called on the main thread only (reads buffer chunks). */
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
            p++;
        }
      remaining -= take;
    }
  return cp;
}

/* Background query thread -------------------------------------------------- */

struct ts_bg_job
{
  lts_buf_cache *cache;
  TSTree        *tree;    /* ts_tree_copy() — bg thread owns, must delete */
  TSQuery       *query;   /* read-only ref, protected by bg_active on main thread */
  TSPoint        sp, ep;
  bool           has_range;
};

static DWORD WINAPI
ts_query_thread (LPVOID arg)
{
  ts_bg_job *job = (ts_bg_job *) arg;
  lts_buf_cache *c = job->cache;

  TSQueryCursor *cursor = ts_query_cursor_new ();

  {
    TSNode root = ts_tree_root_node (job->tree);
    ts_query_cursor_exec (cursor, job->query, root);
    if (job->has_range)
      ts_query_cursor_set_point_range (cursor, job->sp, job->ep);
  }

  uint32_t alloc = 64, count = 0;
  ts_span_raw *spans = (ts_span_raw *) malloc (alloc * sizeof (ts_span_raw));
  if (!spans) { ts_query_cursor_delete (cursor); ts_tree_delete (job->tree);
                InterlockedExchange (&c->bg_active, 0); delete job; return 0; }

  TSQueryMatch match;
  uint32_t tick = 0;
  bool oom = false;
  while (!oom && ts_query_cursor_next_match (cursor, &match))
    {
      /* Check cancellation every 64 matches to stay responsive. */
      if (!(++tick & 63) && c->bg_cancel)
        break;

      for (uint16_t i = 0; i < match.capture_count; i++)
        {
          if (count >= alloc)
            {
              uint32_t new_alloc = alloc * 2;
              ts_span_raw *p = (ts_span_raw *) realloc (spans,
                                                        new_alloc * sizeof (ts_span_raw));
              if (!p) { oom = true; break; }
              spans = p;
              alloc = new_alloc;
            }
          const TSQueryCapture *cap = &match.captures[i];
          spans[count].start_byte = ts_node_start_byte (cap->node);
          spans[count].end_byte   = ts_node_end_byte   (cap->node);
          spans[count].cap_index  = cap->index;
          count++;
        }
    }

  ts_query_cursor_delete (cursor);
  ts_tree_delete (job->tree);  /* release our ts_tree_copy() ref */

  if (!c->bg_cancel)
    {
      free (c->bg_spans);
      c->bg_spans      = spans;
      c->bg_span_count = count;
    }
  else
    {
      free (spans);
      /* Leave bg_spans as-is (stale but harmless; cleared on next launch). */
    }

  /* Full memory barrier: span writes must be visible before bg_active → 0. */
  InterlockedExchange (&c->bg_active, 0);
  delete job;
  return 0;
}

/* (si:ts-query-buffer GRAMMAR QUERY-SOURCE &optional BUFFER START-ROW END-ROW)
   Parse BUFFER with GRAMMAR (with 50 ms timeout + resume), then run
   QUERY-SOURCE asynchronously.  Returns cached spans on the tick after the
   bg query thread finishes; returns nil while parsing or querying is in
   progress.  START-ROW / END-ROW are 0-based tree-sitter row numbers. */
lisp
Fsi_ts_query_buffer (lisp lgrammar, lisp lquery, lisp lbuffer,
                     lisp lstart_row, lisp lend_row)
{
  check_ts_grammar (lgrammar);
  check_string (lquery);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);

  const TSLanguage *lang = (const TSLanguage *) xts_grammar_lang (lgrammar);

  lts_buf_cache *c = get_buf_cache (bp, lang);
  if (!c->parser)
    FEsimple_error (Ets_parse_failed);

  /* --- Parse section (main thread, 50 ms slices) -------------------------- */

  if (!c->tree || c->parse_in_progress || c->revision != bp->b_modified_count)
    {
      /* Buffer changed while a bg query was running: cancel it.
         We must not touch c->query while bg_active is set. */
      if (c->bg_active)
        {
          InterlockedExchange (&c->bg_cancel, 1);
          return Qnil;
        }

      if (c->parse_in_progress && c->parse_revision != bp->b_modified_count)
        {
          ts_parser_reset (c->parser);
          c->parse_in_progress = 0;
        }

      long cur_rev = bp->b_modified_count;

      ts_parse_ctx pctx;
      pctx.bp               = bp;
      pctx.chunk            = nullptr;
      pctx.chunk_start_byte = 0;
      QueryPerformanceFrequency (&pctx.t_freq);
      QueryPerformanceCounter   (&pctx.t_start);

      TSInput      input = { &pctx, ts_buf_read, TSInputEncodingUTF16LE };
      TSParseOptions opts = { &pctx, ts_progress_cb };

      /* Always do a full re-parse: we never call ts_tree_edit to inform
         tree-sitter of edits, so passing the old tree causes incorrect
         incremental results (wrong node positions after any edit). */
      TSTree *new_tree = ts_parser_parse_with_options (c->parser, nullptr,
                                                       input, opts);
      if (new_tree)
        {
          if (c->tree)
            ts_tree_delete (c->tree);
          c->tree              = new_tree;
          c->revision          = cur_rev;
          c->parse_in_progress = 0;
        }
      else
        {
          c->parse_revision    = cur_rev;
          c->parse_in_progress = 1;
          if (!c->tree)
            return Qnil;
          /* Fall through: query the stale tree while parsing continues. */
        }
    }

  /* --- Query compilation (main thread, cached) ---------------------------- */

  {
    int qlen16 = xstring_length (lquery);
    int qbuf_size = qlen16 * 3 + 1;
    char *qbuf = (char *) xmalloc (qbuf_size);
    int qlen8 = WideCharToMultiByte (CP_UTF8, 0,
                                     (LPCWSTR) xstring_contents (lquery), qlen16,
                                     qbuf, qbuf_size - 1, NULL, NULL);
    qbuf[qlen8] = 0;

    if (!c->query || !c->query_src || strcmp (qbuf, c->query_src) != 0)
      {
        /* Must not delete c->query while bg thread is reading it. */
        if (c->bg_active)
          { xfree (qbuf); InterlockedExchange (&c->bg_cancel, 1); return Qnil; }

        if (c->query) ts_query_delete (c->query);
        xfree (c->query_src);

        uint32_t qerr_offset = 0;
        TSQueryError qerr_type = TSQueryErrorNone;
        c->query = ts_query_new (lang, qbuf, (uint32_t) qlen8,
                                 &qerr_offset, &qerr_type);
        if (!c->query)
          { xfree (qbuf); FEsimple_error (Ets_invalid_query, make_fixnum (qerr_offset)); }
        c->query_src = qbuf;
        free (c->bg_spans); c->bg_spans = nullptr; c->bg_span_count = 0;
        c->bg_span_rev = -1;
      }
    else
      xfree (qbuf);
  }

  /* --- Async query -------------------------------------------------------- */

  /* Missing optional args arrive as null (0), not Qnil; guard both. */
  bool has_range = (lstart_row && lstart_row != Qnil
                    && lend_row   && lend_row   != Qnil);
  TSPoint sp = has_range ? TSPoint{ (uint32_t) fixnum_value (lstart_row), 0 }
                         : TSPoint{ 0, 0 };
  TSPoint ep = has_range ? TSPoint{ (uint32_t) fixnum_value (lend_row), UINT32_MAX }
                         : TSPoint{ 0, 0 };

  /* If bg thread is still running, wait for it. */
  if (c->bg_active)
    return Qnil;

  /* If results from the last bg run are still fresh for this range+revision,
     convert byte offsets to code-point offsets and return them. */
  if (c->bg_spans
      && c->bg_span_rev == bp->b_modified_count
      && c->bg_has_range == has_range
      && (!has_range || (c->bg_sp.row == sp.row && c->bg_ep.row == ep.row)))
    {
      lisp result = Qnil;
      for (uint32_t i = 0; i < c->bg_span_count; i++)
        {
          uint32_t name_len;
          const char *name = ts_query_capture_name_for_id (
                               c->query, c->bg_spans[i].cap_index, &name_len);
          int start_cu = (int)(c->bg_spans[i].start_byte / sizeof (Char));
          int end_cu   = (int)(c->bg_spans[i].end_byte   / sizeof (Char));
          point_t start_cp = cu_to_cp (bp, start_cu);
          point_t end_cp   = cu_to_cp (bp, end_cu);
          lisp cap_name = make_string (name, (int) name_len);
          result = xcons (list (cap_name,
                                make_fixnum (start_cp),
                                make_fixnum (end_cp)),
                          result);
        }
      return Fnreverse (result);
    }

  /* Launch background query thread.  Pass a ts_tree_copy() so the bg thread
     has an independent reference; the main thread may replace c->tree freely
     once bg_active is set. */
  ts_bg_job *job = new ts_bg_job;
  job->cache     = c;
  job->tree      = ts_tree_copy (c->tree);
  job->query     = c->query;
  job->sp        = sp;
  job->ep        = ep;
  job->has_range = has_range;

  c->bg_span_rev  = bp->b_modified_count;
  c->bg_sp        = sp;
  c->bg_ep        = ep;
  c->bg_has_range = has_range;
  InterlockedExchange (&c->bg_cancel, 0);
  InterlockedExchange (&c->bg_active, 1);

  if (c->hthread)
    { CloseHandle (c->hthread); c->hthread = NULL; }

  c->hthread = CreateThread (NULL, 0, ts_query_thread, job, 0, NULL);
  if (!c->hthread)
    {
      InterlockedExchange (&c->bg_active, 0);
      ts_tree_delete (job->tree);
      delete job;
    }

  return Qnil;  /* results available on next tick */
}

/* (si:ts-free-buffer-cache &optional BUFFER) */
lisp
Fsi_ts_free_buffer_cache (lisp lbuffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  auto it = g_ts_cache.find (bp);
  if (it != g_ts_cache.end ())
    {
      lts_buf_cache *c = it->second;

      /* Signal bg thread to stop and wait for it to finish. */
      if (c->hthread)
        {
          InterlockedExchange (&c->bg_cancel, 1);
          WaitForSingleObject (c->hthread, 5000);
          CloseHandle (c->hthread);
          c->hthread = NULL;
        }

      if (c->tree)      ts_tree_delete (c->tree);
      if (c->query)     ts_query_delete (c->query);
      if (c->query_src) xfree (c->query_src);
      if (c->bg_spans)  free (c->bg_spans);
      if (c->parser)    ts_parser_delete (c->parser);
      delete c;
      g_ts_cache.erase (it);
    }
  return Qt;
}

/* (si:ts-buffer-cached-p &optional BUFFER) */
lisp
Fsi_ts_buffer_cached_p (lisp lbuffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  auto it = g_ts_cache.find (bp);
  if (it == g_ts_cache.end ())
    return Qnil;
  return it->second->tree ? Qt : Qnil;
}

/* (si:ts-parse-complete-p &optional BUFFER)
   Return t if BUFFER has an up-to-date parse tree with no pending parse. */
lisp
Fsi_ts_parse_complete_p (lisp lbuffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  auto it = g_ts_cache.find (bp);
  if (it == g_ts_cache.end ())
    return Qnil;
  lts_buf_cache *c = it->second;
  return (c->tree && !c->parse_in_progress
          && c->revision == bp->b_modified_count) ? Qt : Qnil;
}

/* (si:ts-query-pending-p &optional BUFFER)
   Return t while the async query thread is running for BUFFER. */
lisp
Fsi_ts_query_pending_p (lisp lbuffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  auto it = g_ts_cache.find (bp);
  if (it == g_ts_cache.end ())
    return Qnil;
  return it->second->bg_active ? Qt : Qnil;
}

lisp
Fsi_ts_grammar_p (lisp x)
{
  return ts_grammar_p (x) ? Qt : Qnil;
}
