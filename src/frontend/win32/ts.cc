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
  TSQuery          *query;          /* compiled query (read by bg query thread) */
  char             *query_src;      /* UTF-8 source of cached query */
  const TSLanguage *lang;
  long              revision;       /* b_modified_count of the installed tree */

  /* Background parse state ------------------------------------------------- */
  volatile LONG     parse_bg_active;  /* 1 while bg parse thread is running */
  volatile LONG     parse_bg_cancel;  /* 1 to ask bg parse thread to abort */
  HANDLE            parse_hthread;    /* bg parse thread handle */
  TSTree           *parse_result;     /* completed parse awaiting installation */
  long              parse_result_rev; /* revision parse_result corresponds to */
  long              parse_bg_rev;     /* revision currently being parsed */

  /* Background query state ------------------------------------------------- */
  volatile LONG     bg_active;     /* 1 while bg query thread is running */
  volatile LONG     bg_cancel;     /* set to 1 to ask bg thread to stop early */
  HANDLE            hthread;       /* bg query thread handle */
  ts_span_raw      *bg_spans;      /* results from last completed bg query */
  uint32_t          bg_span_count;
  long              bg_span_rev;   /* b_modified_count when bg_spans were produced */
  TSPoint           bg_sp, bg_ep;  /* point range the results cover */
  bool              bg_has_range;  /* false = full-buffer query */
};

static std::unordered_map<Buffer *, lts_buf_cache *> g_ts_cache;

/* Return the cache entry for BP, creating one if needed.
   Grammar changes flush the tree and compiled query after stopping bg threads. */
static lts_buf_cache *
get_buf_cache (Buffer *bp, const TSLanguage *lang)
{
  auto it = g_ts_cache.find (bp);
  if (it != g_ts_cache.end ())
    {
      lts_buf_cache *c = it->second;
      if (c->lang != lang)
        {
          /* Grammar changed: stop all bg threads before touching shared state. */
          if (c->hthread)
            {
              InterlockedExchange (&c->bg_cancel, 1);
              WaitForSingleObject (c->hthread, 5000);
              CloseHandle (c->hthread); c->hthread = NULL;
              InterlockedExchange (&c->bg_active, 0);
            }
          if (c->parse_hthread)
            {
              InterlockedExchange (&c->parse_bg_cancel, 1);
              WaitForSingleObject (c->parse_hthread, 5000);
              CloseHandle (c->parse_hthread); c->parse_hthread = NULL;
              InterlockedExchange (&c->parse_bg_active, 0);
            }
          if (c->parse_result) { ts_tree_delete (c->parse_result); c->parse_result = nullptr; }
          if (c->tree)      { ts_tree_delete (c->tree); c->tree = nullptr; }
          if (c->query)     { ts_query_delete (c->query); c->query = nullptr; }
          xfree (c->query_src); c->query_src = nullptr;
          ts_parser_set_language (c->parser, lang);
          c->lang              = lang;
          c->revision          = -1;
          c->parse_bg_rev      = -1;
          c->parse_result_rev  = -1;
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
  c->parse_bg_active   = 0;
  c->parse_bg_cancel   = 0;
  c->parse_hthread     = NULL;
  c->parse_result      = nullptr;
  c->parse_result_rev  = -1;
  c->parse_bg_rev      = -1;
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

/* Background parse thread --------------------------------------------------
   Reads from a flat snapshot of the buffer taken on the main thread.
   Stores the completed TSTree in c->parse_result for the main thread to
   install; never writes c->tree directly to avoid races with the query thread. */

struct ts_parse_job
{
  lts_buf_cache *cache;
  char          *snapshot;  /* malloc'd flat copy of buffer (UTF-16LE bytes) */
  uint32_t       snap_size;
  long           revision;
};

static const char *
ts_snap_read (void *payload, uint32_t byte_index, TSPoint /*pos*/,
              uint32_t *bytes_read)
{
  ts_parse_job *job = (ts_parse_job *) payload;
  if (byte_index >= job->snap_size) { *bytes_read = 0; return ""; }
  *bytes_read = job->snap_size - byte_index;
  return job->snapshot + byte_index;
}

/* Progress callback: cancel parse when flagged by the main thread. */
static bool
ts_parse_cancel_cb (TSParseState *state)
{
  ts_parse_job *job = (ts_parse_job *) state->payload;
  return job->cache->parse_bg_cancel != 0;
}

static DWORD WINAPI
ts_parse_thread (LPVOID arg)
{
  ts_parse_job *job = (ts_parse_job *) arg;
  lts_buf_cache *c = job->cache;

  TSInput input = { job, ts_snap_read, TSInputEncodingUTF16LE };
  TSParseOptions opts = { job, ts_parse_cancel_cb };

  /* Always full-parse (nullptr old tree): ts_tree_edit is not connected, so
     passing an old tree produces incorrect node positions after any edit. */
  TSTree *new_tree = ts_parser_parse_with_options (c->parser, nullptr, input, opts);

  free (job->snapshot);

  if (new_tree && !c->parse_bg_cancel)
    {
      /* Writes must be visible before parse_bg_active clears (full barrier). */
      c->parse_result     = new_tree;
      c->parse_result_rev = job->revision;
    }
  else if (new_tree)
    ts_tree_delete (new_tree);

  InterlockedExchange (&c->parse_bg_active, 0);
  delete job;
  return 0;
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
  TSQuery       *query;   /* read-only ref, valid while bg_active is set */
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
  ts_tree_delete (job->tree);

  if (!c->bg_cancel)
    {
      free (c->bg_spans);
      c->bg_spans      = spans;
      c->bg_span_count = count;
    }
  else
    free (spans);

  InterlockedExchange (&c->bg_active, 0);
  delete job;
  return 0;
}

/* (si:ts-query-buffer GRAMMAR QUERY-SOURCE &optional BUFFER START-ROW END-ROW)
   Parse BUFFER with GRAMMAR on a background thread (no main-thread blocking),
   then run QUERY-SOURCE asynchronously.  Returns cached spans when the bg
   query thread finishes; returns nil while parsing or querying is in progress.
   START-ROW / END-ROW are 0-based tree-sitter row numbers. */
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

  /* --- Install completed bg parse result (if any) ------------------------- */

  if (!c->parse_bg_active && c->parse_result)
    {
      /* parse_bg_active is 0 with a full barrier: parse_result writes are
         visible here.  The query thread already holds ts_tree_copy(), so it
         is safe to replace c->tree even while bg_active is set. */
      if (c->parse_hthread)
        { CloseHandle (c->parse_hthread); c->parse_hthread = NULL; }
      if (c->parse_result_rev == bp->b_modified_count)
        {
          if (c->tree) ts_tree_delete (c->tree);
          c->tree     = c->parse_result;
          c->revision = c->parse_result_rev;
        }
      else
        ts_tree_delete (c->parse_result);
      c->parse_result = nullptr;
    }

  /* --- Parse section (background thread) ---------------------------------- */

  if (!c->tree || c->revision != bp->b_modified_count)
    {
      /* Cancel any running bg query — can't launch a new parse while it
         holds a reference to the (stale) tree. */
      if (c->bg_active)
        { InterlockedExchange (&c->bg_cancel, 1); return Qnil; }

      /* Bg parse already running for the current revision: wait.
         SwitchToThread() yields the remaining time slice so the parse thread
         gets CPU without a full scheduler-quantum delay. */
      if (c->parse_bg_active && c->parse_bg_rev == bp->b_modified_count)
        { SwitchToThread (); return Qnil; }

      /* Bg parse running for a stale revision: signal cancel, come back. */
      if (c->parse_bg_active)
        { InterlockedExchange (&c->parse_bg_cancel, 1); return Qnil; }

      /* No threads running; take a snapshot and launch a bg parse. */
      long cur_rev = bp->b_modified_count;

      uint32_t total_bytes = 0;
      for (Chunk *ch = bp->b_chunkb; ch; ch = ch->c_next)
        total_bytes += (uint32_t) ch->c_used * sizeof (Char);

      char *snapshot = (char *) malloc (total_bytes ? total_bytes : 1);
      if (!snapshot) return Qnil;

      char *p = snapshot;
      for (Chunk *ch = bp->b_chunkb; ch; ch = ch->c_next)
        {
          uint32_t n = (uint32_t) ch->c_used * sizeof (Char);
          memcpy (p, ch->c_text, n);
          p += n;
        }

      ts_parse_job *job = new ts_parse_job;
      job->cache     = c;
      job->snapshot  = snapshot;
      job->snap_size = total_bytes;
      job->revision  = cur_rev;

      if (c->parse_hthread) { CloseHandle (c->parse_hthread); c->parse_hthread = NULL; }
      InterlockedExchange (&c->parse_bg_cancel, 0);
      InterlockedExchange (&c->parse_bg_active, 1);
      c->parse_bg_rev = cur_rev;

      c->parse_hthread = CreateThread (NULL, 0, ts_parse_thread, job, 0, NULL);
      if (!c->parse_hthread)
        {
          InterlockedExchange (&c->parse_bg_active, 0);
          free (snapshot);
          delete job;
        }
      return Qnil;
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
        /* Must not delete c->query while bg query thread is reading it. */
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

  if (c->bg_active)
    { SwitchToThread (); return Qnil; }

  /* Return cached spans if they match the current revision and range. */
  if (c->bg_spans
      && c->bg_span_rev == bp->b_modified_count
      && c->bg_has_range == has_range
      && (!has_range || (c->bg_sp.row == sp.row && c->bg_ep.row == ep.row)))
    {
      uint32_t nsp = c->bg_span_count;

      /* Convert all span byte offsets to code-point offsets in a single
         forward buffer scan.  The naive approach calls cu_to_cp() once per
         endpoint, each restarting from byte 0 — O(N×M) for N buffer chars
         and M spans.  Sorting the 2M endpoints and scanning once gives
         O(N + M log M), cutting a ~40 ms hitch to ~1 ms for large files. */
      /* pair<cu, tag>, tag = i*2+is_end */
      using cu_slot = std::pair<uint32_t, uint32_t>;
      cu_slot *slots  = (cu_slot *) malloc (nsp * 2 * sizeof (cu_slot));
      point_t *cp_out = (point_t *) malloc (nsp * 2 * sizeof (point_t));

      if (slots && cp_out)
        {
          for (uint32_t i = 0; i < nsp; i++)
            {
              slots[i*2  ] = { c->bg_spans[i].start_byte / (uint32_t)sizeof(Char), i*2   };
              slots[i*2+1] = { c->bg_spans[i].end_byte   / (uint32_t)sizeof(Char), i*2+1 };
            }
          std::sort (slots, slots + nsp * 2,
                     [](const cu_slot &a, const cu_slot &b) { return a.first < b.first; });

          /* Single forward scan. */
          point_t  cp     = 0;
          uint32_t cur_cu = 0;
          Chunk   *ch     = bp->b_chunkb;
          uint32_t ch_cu0 = 0;
          for (uint32_t e = 0; e < nsp * 2; e++)
            {
              uint32_t target = slots[e].first;
              while (cur_cu < target)
                {
                  if (!ch) break;
                  uint32_t ch_end = ch_cu0 + (uint32_t) ch->c_used;
                  const Char *p = ch->c_text + (cur_cu - ch_cu0);
                  while (cur_cu < target && cur_cu < ch_end)
                    {
                      Char cc = *p++;
                      cp++; cur_cu++;
                      if (cc >= 0xD800 && cc <= 0xDBFF
                          && cur_cu < ch_end
                          && *p >= 0xDC00 && *p <= 0xDFFF)
                        { p++; cur_cu++; } /* surrogate pair: 2 cu = 1 cp */
                    }
                  if (cur_cu >= ch_end) { ch_cu0 += ch->c_used; ch = ch->c_next; }
                }
              cp_out[slots[e].second] = cp;
            }
          free (slots); slots = nullptr;

          lisp result = Qnil;
          for (uint32_t i = 0; i < nsp; i++)
            {
              uint32_t name_len;
              const char *name = ts_query_capture_name_for_id (
                                   c->query, c->bg_spans[i].cap_index, &name_len);
              result = xcons (list (make_string (name, (int) name_len),
                                    make_fixnum (cp_out[i*2]),
                                    make_fixnum (cp_out[i*2+1])),
                              result);
            }
          free (cp_out);
          return Fnreverse (result);
        }

      /* OOM fallback: per-span conversion (O(N×M) but always correct). */
      free (slots); free (cp_out);
      lisp result = Qnil;
      for (uint32_t i = 0; i < nsp; i++)
        {
          uint32_t name_len;
          const char *name = ts_query_capture_name_for_id (
                               c->query, c->bg_spans[i].cap_index, &name_len);
          int start_cu = (int)(c->bg_spans[i].start_byte / sizeof (Char));
          int end_cu   = (int)(c->bg_spans[i].end_byte   / sizeof (Char));
          result = xcons (list (make_string (name, (int) name_len),
                                make_fixnum (cu_to_cp (bp, start_cu)),
                                make_fixnum (cu_to_cp (bp, end_cu))),
                          result);
        }
      return Fnreverse (result);
    }

  /* Launch background query thread.  ts_tree_copy() gives the bg thread its
     own reference; the main thread may update c->tree freely thereafter. */
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

  return Qnil;
}

/* --- Helpers for si:ts-apply-highlights ---------------------------------- */

/* Delete all textprops with tag == ltag from bp directly. */
static void
ts_delete_textprops_tag (Buffer *bp, lisp ltag)
{
  textprop *prev = nullptr;
  for (textprop *t = bp->b_textprop, *next; t; t = next)
    {
      next = t->t_next;
      if (t->t_tag == ltag)
        {
          if (prev) prev->t_next = next;
          else      bp->b_textprop = next;
          if (bp->b_textprop_cache == t) bp->b_textprop_cache = nullptr;
          bp->free_textprop (t);
        }
      else
        prev = t;
    }
}

/* Compare ASCII tree-sitter capture name with a Lisp string (UTF-16).
   Works correctly for names that are pure ASCII (all ts capture names are). */
static bool
ts_ascii_match (const char *name, uint32_t len, lisp lstr)
{
  if (!stringp (lstr) || (uint32_t) xstring_length (lstr) != len) return false;
  const Char *p = xstring_contents (lstr);
  for (uint32_t i = 0; i < len; i++)
    if (p[i] != (unsigned char) name[i]) return false;
  return true;
}

/* Look up the fg color for capture CAP_IDX in LCOLORS alist.
   LCOLORS: ((name-string . fg-fixnum) ...).  Returns -1 if not found. */
static int
ts_lookup_color (TSQuery *query, uint32_t cap_idx, lisp lcolors)
{
  uint32_t name_len;
  const char *name = ts_query_capture_name_for_id (query, cap_idx, &name_len);
  for (lisp a = lcolors; consp (a); a = xcdr (a))
    {
      lisp entry = xcar (a);
      if (consp (entry) && ts_ascii_match (name, name_len, xcar (entry))
          && fixnump (xcdr (entry)))
        return (int) fixnum_value (xcdr (entry));
    }
  return -1;
}

/* Batch cu→cp conversion: fills cp_out[0..2*nsp) from bg_spans.
   Returns true on success; on failure cp_out is left in an indeterminate state. */
static bool
ts_batch_cu_to_cp (Buffer *bp, const ts_span_raw *spans, uint32_t nsp,
                   std::pair<uint32_t,uint32_t> *slots, point_t *cp_out)
{
  using cu_slot = std::pair<uint32_t, uint32_t>;
  for (uint32_t i = 0; i < nsp; i++)
    {
      slots[i*2  ] = { spans[i].start_byte / (uint32_t) sizeof (Char), i*2   };
      slots[i*2+1] = { spans[i].end_byte   / (uint32_t) sizeof (Char), i*2+1 };
    }
  std::sort (slots, slots + nsp * 2,
             [](const cu_slot &a, const cu_slot &b) { return a.first < b.first; });
  point_t  cp     = 0;
  uint32_t cur_cu = 0;
  Chunk   *ch     = bp->b_chunkb;
  uint32_t ch_cu0 = 0;
  for (uint32_t e = 0; e < nsp * 2; e++)
    {
      uint32_t target = slots[e].first;
      while (cur_cu < target)
        {
          if (!ch) break;
          uint32_t ch_end = ch_cu0 + (uint32_t) ch->c_used;
          const Char *p = ch->c_text + (cur_cu - ch_cu0);
          while (cur_cu < target && cur_cu < ch_end)
            {
              Char cc = *p++; cp++; cur_cu++;
              if (cc >= 0xD800 && cc <= 0xDBFF && cur_cu < ch_end
                  && *p >= 0xDC00 && *p <= 0xDFFF)
                { p++; cur_cu++; }
            }
          if (cur_cu >= ch_end) { ch_cu0 += ch->c_used; ch = ch->c_next; }
        }
      cp_out[slots[e].second] = cp;
    }
  return true;
}

/* (si:ts-apply-highlights grammar query buffer start-row end-row tag colors)
   colors: alist of (name-string . fg-color-fixnum)
   Manages bg parse/query threads (same as si:ts-query-buffer), then when spans
   are ready applies textprops directly in C — no Lisp list allocation.
   Returns t when highlights were applied, nil while bg work is pending. */
lisp
Fsi_ts_apply_highlights (lisp lgrammar, lisp lquery, lisp lbuffer,
                         lisp lstart_row, lisp lend_row,
                         lisp ltag, lisp lcolors)
{
  check_ts_grammar (lgrammar);
  check_string (lquery);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  const TSLanguage *lang = (const TSLanguage *) xts_grammar_lang (lgrammar);
  lts_buf_cache *c = get_buf_cache (bp, lang);
  if (!c->parser) FEsimple_error (Ets_parse_failed);

  /* Install completed bg parse result. */
  if (!c->parse_bg_active && c->parse_result)
    {
      if (c->parse_hthread) { CloseHandle (c->parse_hthread); c->parse_hthread = NULL; }
      if (c->parse_result_rev == bp->b_modified_count)
        { if (c->tree) ts_tree_delete (c->tree); c->tree = c->parse_result; c->revision = c->parse_result_rev; }
      else
        ts_tree_delete (c->parse_result);
      c->parse_result = nullptr;
    }

  /* Ensure tree is up-to-date. */
  if (!c->tree || c->revision != bp->b_modified_count)
    {
      if (c->bg_active) { InterlockedExchange (&c->bg_cancel, 1); return Qnil; }
      if (c->parse_bg_active && c->parse_bg_rev == bp->b_modified_count) { SwitchToThread (); return Qnil; }
      if (c->parse_bg_active) { InterlockedExchange (&c->parse_bg_cancel, 1); return Qnil; }

      long cur_rev = bp->b_modified_count;
      uint32_t total_bytes = 0;
      for (Chunk *ch = bp->b_chunkb; ch; ch = ch->c_next)
        total_bytes += (uint32_t) ch->c_used * sizeof (Char);
      char *snapshot = (char *) malloc (total_bytes ? total_bytes : 1);
      if (!snapshot) return Qnil;
      char *p = snapshot;
      for (Chunk *ch = bp->b_chunkb; ch; ch = ch->c_next)
        { uint32_t n = (uint32_t) ch->c_used * sizeof (Char); memcpy (p, ch->c_text, n); p += n; }
      ts_parse_job *job = new ts_parse_job;
      job->cache = c; job->snapshot = snapshot; job->snap_size = total_bytes; job->revision = cur_rev;
      if (c->parse_hthread) { CloseHandle (c->parse_hthread); c->parse_hthread = NULL; }
      InterlockedExchange (&c->parse_bg_cancel, 0);
      InterlockedExchange (&c->parse_bg_active, 1);
      c->parse_bg_rev = cur_rev;
      c->parse_hthread = CreateThread (NULL, 0, ts_parse_thread, job, 0, NULL);
      if (!c->parse_hthread) { InterlockedExchange (&c->parse_bg_active, 0); free (snapshot); delete job; }
      return Qnil;
    }

  /* Compile query (cached). */
  {
    int qlen16 = xstring_length (lquery);
    int qbuf_size = qlen16 * 3 + 1;
    char *qbuf = (char *) xmalloc (qbuf_size);
    int qlen8 = WideCharToMultiByte (CP_UTF8, 0, (LPCWSTR) xstring_contents (lquery), qlen16,
                                     qbuf, qbuf_size - 1, NULL, NULL);
    qbuf[qlen8] = 0;
    if (!c->query || !c->query_src || strcmp (qbuf, c->query_src) != 0)
      {
        if (c->bg_active) { xfree (qbuf); InterlockedExchange (&c->bg_cancel, 1); return Qnil; }
        if (c->query) ts_query_delete (c->query);
        xfree (c->query_src);
        uint32_t qerr_offset = 0; TSQueryError qerr_type = TSQueryErrorNone;
        c->query = ts_query_new (lang, qbuf, (uint32_t) qlen8, &qerr_offset, &qerr_type);
        if (!c->query) { xfree (qbuf); FEsimple_error (Ets_invalid_query, make_fixnum (qerr_offset)); }
        c->query_src = qbuf;
        free (c->bg_spans); c->bg_spans = nullptr; c->bg_span_count = 0; c->bg_span_rev = -1;
      }
    else
      xfree (qbuf);
  }

  /* Resolve range args. */
  bool has_range = (lstart_row && lstart_row != Qnil && lend_row && lend_row != Qnil);
  TSPoint sp = has_range ? TSPoint{ (uint32_t) fixnum_value (lstart_row), 0 } : TSPoint{ 0, 0 };
  TSPoint ep = has_range ? TSPoint{ (uint32_t) fixnum_value (lend_row), UINT32_MAX } : TSPoint{ 0, 0 };

  if (c->bg_active) { SwitchToThread (); return Qnil; }

  /* Cache hit: bg_active is 0 here so bg_spans is stable.
     Strategy depends on whether the new range overlaps the cached range:
     - Overlapping (small scroll): apply cached spans immediately so the
       display stays highlighted during key repeat, then launch a bg query
       for the new range so fresh spans arrive soon.
     - Non-overlapping (large jump like M-< / M->): cached spans are for a
       completely different part of the file.  Touching textprops would
       delete visible highlights and replace them with invisible ones.
       Instead, just launch the bg query and return nil; the caller will
       retry once the bg query completes. */
  if (c->bg_spans && c->bg_span_rev == bp->b_modified_count)
    {
      bool range_match = c->bg_has_range == has_range
          && (!has_range || (c->bg_sp.row == sp.row && c->bg_ep.row == ep.row));
      bool range_overlaps = !has_range || !c->bg_has_range
          || (c->bg_sp.row < ep.row && sp.row < c->bg_ep.row);

      if (range_overlaps)
        {
          uint32_t nsp = c->bg_span_count;
          using cu_slot = std::pair<uint32_t, uint32_t>;
          cu_slot *slots  = nsp ? (cu_slot *) malloc (nsp * 2 * sizeof (cu_slot)) : nullptr;
          point_t *cp_out = nsp ? (point_t *) malloc (nsp * 2 * sizeof (point_t)) : nullptr;
          bool ok = (nsp == 0) || (slots && cp_out
                                   && ts_batch_cu_to_cp (bp, c->bg_spans, nsp, slots, cp_out));

          ts_delete_textprops_tag (bp, ltag);

          if (ok && nsp > 0)
            for (uint32_t i = 0; i < nsp; i++)
              {
                int fg = ts_lookup_color (c->query, c->bg_spans[i].cap_index, lcolors);
                if (fg < 0) continue;
                int attrib = (fg & (GLYPH_TEXTPROP_NCOLORS - 1)) << GLYPH_TEXTPROP_FG_SHIFT_BITS;
                textprop *p = bp->add_textprop (cp_out[i*2], cp_out[i*2+1]);
                if (p) { p->t_attrib = attrib; p->t_tag = ltag; bp->b_textprop_cache = p; }
              }

          free (slots); free (cp_out);

          if (!range_match)
            {
              /* bg_spans consumed; safe to launch new query for shifted range. */
              c->bg_sp = sp; c->bg_ep = ep; c->bg_has_range = has_range;
              ts_bg_job *job = new ts_bg_job;
              job->cache = c; job->tree = ts_tree_copy (c->tree); job->query = c->query;
              job->sp = sp; job->ep = ep; job->has_range = has_range;
              InterlockedExchange (&c->bg_cancel, 0);
              InterlockedExchange (&c->bg_active, 1);
              if (c->hthread) { CloseHandle (c->hthread); c->hthread = NULL; }
              c->hthread = CreateThread (NULL, 0, ts_query_thread, job, 0, NULL);
              if (!c->hthread) { InterlockedExchange (&c->bg_active, 0); ts_tree_delete (job->tree); delete job; }
            }

          bp->refresh_buffer ();
          return Qt;
        }

      /* Non-overlapping range: launch bg query without touching textprops. */
      c->bg_sp = sp; c->bg_ep = ep; c->bg_has_range = has_range;
      ts_bg_job *job2 = new ts_bg_job;
      job2->cache = c; job2->tree = ts_tree_copy (c->tree); job2->query = c->query;
      job2->sp = sp; job2->ep = ep; job2->has_range = has_range;
      InterlockedExchange (&c->bg_cancel, 0);
      InterlockedExchange (&c->bg_active, 1);
      if (c->hthread) { CloseHandle (c->hthread); c->hthread = NULL; }
      c->hthread = CreateThread (NULL, 0, ts_query_thread, job2, 0, NULL);
      if (!c->hthread) { InterlockedExchange (&c->bg_active, 0); ts_tree_delete (job2->tree); delete job2; }
      return Qnil;
    }

  /* Cache miss (no spans or stale revision): launch bg query thread. */
  ts_bg_job *job = new ts_bg_job;
  job->cache = c; job->tree = ts_tree_copy (c->tree); job->query = c->query;
  job->sp = sp; job->ep = ep; job->has_range = has_range;
  c->bg_span_rev = bp->b_modified_count; c->bg_sp = sp; c->bg_ep = ep; c->bg_has_range = has_range;
  InterlockedExchange (&c->bg_cancel, 0);
  InterlockedExchange (&c->bg_active, 1);
  if (c->hthread) { CloseHandle (c->hthread); c->hthread = NULL; }
  c->hthread = CreateThread (NULL, 0, ts_query_thread, job, 0, NULL);
  if (!c->hthread) { InterlockedExchange (&c->bg_active, 0); ts_tree_delete (job->tree); delete job; }
  return Qnil;
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

      if (c->hthread)
        {
          InterlockedExchange (&c->bg_cancel, 1);
          WaitForSingleObject (c->hthread, 5000);
          CloseHandle (c->hthread);
          c->hthread = NULL;
        }
      if (c->parse_hthread)
        {
          InterlockedExchange (&c->parse_bg_cancel, 1);
          WaitForSingleObject (c->parse_hthread, 5000);
          CloseHandle (c->parse_hthread);
          c->parse_hthread = NULL;
        }

      if (c->parse_result) ts_tree_delete (c->parse_result);
      if (c->tree)         ts_tree_delete (c->tree);
      if (c->query)        ts_query_delete (c->query);
      if (c->query_src)    xfree (c->query_src);
      if (c->bg_spans)     free (c->bg_spans);
      if (c->parser)       ts_parser_delete (c->parser);
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
   Return t if BUFFER has an up-to-date parse tree with no pending bg parse. */
lisp
Fsi_ts_parse_complete_p (lisp lbuffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  auto it = g_ts_cache.find (bp);
  if (it == g_ts_cache.end ())
    return Qnil;
  lts_buf_cache *c = it->second;
  return (c->tree && !c->parse_bg_active
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

/* Convert a code-point offset to byte offset for tree-sitter positioning. */
static uint32_t
cp_to_byte (Buffer *bp, point_t target_cp)
{
  uint32_t byte_off = 0;
  point_t cp = 0;
  for (Chunk *ch = bp->b_chunkb; ch && cp < target_cp; ch = ch->c_next)
    {
      const Char *p = ch->c_text;
      const Char *end = p + ch->c_used;
      while (p < end && cp < target_cp)
        {
          Char cc = *p++;
          cp++;
          byte_off += (uint32_t) sizeof (Char);
          if (cc >= 0xD800 && cc <= 0xDBFF && p < end
              && *p >= 0xDC00 && *p <= 0xDFFF)
            { p++; byte_off += (uint32_t) sizeof (Char); }
        }
    }
  return byte_off;
}

/* (si:ts-node-ancestors grammar buffer point)
   Returns a list of (type start-cp end-cp) from the named node at POINT
   up to the parse tree root (innermost first).
   Returns nil when no up-to-date tree is available yet. */
lisp
Fsi_ts_node_ancestors (lisp lgrammar, lisp lbuffer, lisp lpoint)
{
  check_ts_grammar (lgrammar);
  Buffer *bp = Buffer::coerce_to_buffer (lbuffer);
  check_integer (lpoint);
  const TSLanguage *lang = (const TSLanguage *) xts_grammar_lang (lgrammar);

  auto it = g_ts_cache.find (bp);
  if (it == g_ts_cache.end ())
    return Qnil;
  lts_buf_cache *c = it->second;
  if (!c->tree || c->revision != bp->b_modified_count)
    return Qnil;

  uint32_t byte_off = cp_to_byte (bp, (point_t) fixnum_value (lpoint));

  TSNode root = ts_tree_root_node (c->tree);
  TSNode node = ts_node_named_descendant_for_byte_range (root, byte_off, byte_off);

  lisp result = Qnil;
  while (!ts_node_is_null (node))
    {
      const char *type    = ts_node_type (node);
      point_t start_cp    = cu_to_cp (bp, (int)(ts_node_start_byte (node) / sizeof (Char)));
      point_t end_cp      = cu_to_cp (bp, (int)(ts_node_end_byte   (node) / sizeof (Char)));
      result = xcons (list (make_string (type, (int) strlen (type)),
                            make_fixnum (start_cp),
                            make_fixnum (end_cp)),
                      result);
      node = ts_node_parent (node);
    }

  return Fnreverse (result);
}
