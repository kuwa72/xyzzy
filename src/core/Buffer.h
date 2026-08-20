#ifndef _Buffer_h_
# define _Buffer_h_

# include "alloc.h"
# include "kanji.h"

enum wcolor_index
{
  WCOLOR_TEXT,
  WCOLOR_BACK,
  WCOLOR_CTRL,
  WCOLOR_HIGHLIGHT_TEXT,
  WCOLOR_HIGHLIGHT,
  WCOLOR_KWD1,
  WCOLOR_KWD2,
  WCOLOR_KWD3,
  WCOLOR_STRING,
  WCOLOR_COMMENT,
  WCOLOR_TAG,
  WCOLOR_CURSOR,
  WCOLOR_CARET,
  WCOLOR_IMECARET,
  WCOLOR_LINENUM,
  WCOLOR_REVERSE,
  WCOLOR_MODELINE_FG,
  WCOLOR_MODELINE_BG,

  WCOLOR_GRAY,
  WCOLOR_BTNSHADOW,
  WCOLOR_BTNTEXT,
  WCOLOR_MAX,
  USER_DEFINABLE_COLORS = WCOLOR_GRAY
};

struct wcolor_index_name
{
  const char *name;
  COLORREF rgb;
  const wchar_t *display_name;
};

extern const wcolor_index_name wcolor_index_names[];

# define MIN_FOLD_WIDTH 4
# define MAX_FOLD_WIDTH 30000

struct Buffer;

class syntax_info;

/* Phase 2 Step 5d: UTF-16 Char 列の code point 数を数える。
   high surrogate (0xD800-0xDBFF) の直後に low surrogate (0xDC00-0xDFFF)
   が続く場合は 1 code point として勘定。標準的でない並び (lone surrogate
   や順序逆転) はそれぞれ 1 として数える保守解釈。 */
static inline int
count_code_points (const Char *p, int n)
{
  int count = 0;
  for (int i = 0; i < n; i++)
    {
      count++;
      if (p[i] >= 0xD800 && p[i] <= 0xDBFF
          && i + 1 < n && p[i + 1] >= 0xDC00 && p[i + 1] <= 0xDFFF)
        i++;
    }
  return count;
}

static inline int
is_high_surrogate (Char c)
{
  return c >= 0xD800 && c <= 0xDBFF;
}

static inline int
is_low_surrogate (Char c)
{
  return c >= 0xDC00 && c <= 0xDFFF;
}

/* Phase 2-1: chunk 内の cp 歩き。cu_offset (現在位置) から
   ncp 分 code point 進めた cu_offset を返す。ncp は負不可、
   range 超過は c_used で止める。 */
static inline int
chunk_forward_cp (const Char *p, int c_used, int cu_offset, int ncp)
{
  while (ncp > 0 && cu_offset < c_used)
    {
      if (is_high_surrogate (p[cu_offset])
          && cu_offset + 1 < c_used
          && is_low_surrogate (p[cu_offset + 1]))
        cu_offset += 2;
      else
        cu_offset += 1;
      ncp--;
    }
  return cu_offset;
}

/* chunk 内で cu_offset から ncp code point 戻した cu_offset を返す。
   ncp は負不可、範囲超過は 0 で止める。 */
static inline int
chunk_backward_cp (const Char *p, int cu_offset, int ncp)
{
  while (ncp > 0 && cu_offset > 0)
    {
      cu_offset--;
      if (cu_offset > 0
          && is_low_surrogate (p[cu_offset])
          && is_high_surrogate (p[cu_offset - 1]))
        cu_offset--;
      ncp--;
    }
  return cu_offset;
}

int unicode_width (unsigned int);  /* eaw.h */

/* Phase 2-3: cp 数 → cu offset 逆引き (count_code_points の逆関数)。
   ncp 個 cp 進めた cu offset を返す。chunk 末尾まで達した場合は c_used
   で止める。 */
static inline int
cp_to_cu_in_chunk (const Char *p, int c_used, int ncp)
{
  int cu = 0;
  while (ncp > 0 && cu < c_used)
    {
      if (is_high_surrogate (p[cu])
          && cu + 1 < c_used
          && is_low_surrogate (p[cu + 1]))
        cu += 2;
      else
        cu += 1;
      ncp--;
    }
  return cu;
}

/* Phase 2-3: offset が code point boundary か判定。offset が 0 / c_used
   と等しい、あるいは text[offset] が low surrogate の直前 (= high surrogate
   が text[offset-1]) でなければ true。 */
static inline bool
is_code_point_boundary (const Char *p, int c_used, int offset)
{
  if (offset <= 0 || offset >= c_used)
    return true;
  return !(is_high_surrogate (p[offset - 1]) && is_low_surrogate (p[offset]));
}

/* Phase 2-3: offset が surrogate pair を割る位置なら直前の cp 境界まで
   戻す。分割に使う「安全な」offset を返す。 */
static inline int
safe_split_offset (const Char *p, int c_used, int offset)
{
  if (offset > 0 && offset < c_used
      && is_high_surrogate (p[offset - 1])
      && is_low_surrogate (p[offset]))
    return offset - 1;
  return offset;
}

/* Phase 2-1: surrogate pair からの display width 取得。pair 合成後の
   cp で unicode_width を引き、paint 側 (glyph_sbchar/dbchar) が emit
   する cell 数と同じ値を返す。0-width (非 BMP の tag / variation
   selector 等) は 0 のまま返して column と display を揃える。 */
static inline int
surrogate_pair_width (Char hi, Char lo)
{
  u_int32_t cp = 0x10000u
                 + ((u_int32_t (hi) - 0xD800u) << 10)
                 + (u_int32_t (lo) - 0xDC00u);
  return unicode_width (cp);
}

struct Chunk
{
  enum {TEXT_SIZE = 4096};
  enum {BREAKS_SIZE = (TEXT_SIZE + 7) / 8};
  static fixed_heap c_heap;
  static fixed_heap c_breaks_heap;
  static const u_char c_breaks_mask[];

  Chunk *c_prev;
  Chunk *c_next;
  Char *c_text;
  u_char *c_breaks;
  short c_used;
  /* c_nchars: 使用中の code point 数。surrogate pair (high+low) を
     1 code point として数える。lone surrogate (片割れ) は 1 code point。
     よって `c_nchars <= c_used` (等号は surrogate pair が無い時)。
     Phase 2-1 以降: b_nchars = sum(c_nchars)、point_t は buffer 先頭
     からの code point 数。chunk 内部の array 参照は c_used / p_offset
     の cu 単位で続ける (data store の layout は Char = u16 code unit)。 */
  short c_nchars;
  short c_nlines;
  short c_nbreaks;
  short c_first_eol;
  short c_last_eol;
  Char c_bstrch;
  Char c_estrch;
  u_char c_bstate;
  u_char c_estate;

  void update_syntax (const syntax_info &);
  void parse_syntax ();

  int count_lines () const;
  int rest () const;
  void clear ();
  void clear_breaks ()
    {
      bzero (c_breaks, (c_used + 7) / 8);
      c_nbreaks = 0;
    }
  void break_on (int n)
    {
      c_breaks[n >> 3] |= c_breaks_mask[n & 7];
      c_nbreaks++;
    }
  void break_off (int n)
    {
      assert (break_p (n));
      assert (c_nbreaks > 0);
      c_breaks[n >> 3] &= ~c_breaks_mask[n & 7];
      c_nbreaks--;
    }
  u_char break_p (int n) const {return c_breaks[n >> 3] & c_breaks_mask[n & 7];}
};

inline int
Chunk::rest () const
{
  return TEXT_SIZE - c_used;
}

struct textprop
{
  textprop *t_next;
  Region t_range;
  lisp t_tag;
  int t_attrib;

  int operator < (point_t point) const
    {return (t_range.p1 < point
             || (t_range.p1 == point && t_range.p1 == t_range.p2));}
  int operator > (point_t point) const
    {return (t_range.p2 > point
             || (t_range.p2 == point && t_range.p1 == t_range.p2));}
};

template <class T>
class allocator
{
  struct arep {arep *a_next;};
  static fixed_heap a_heap;
  arep *a_reps;
  arep *a_free;
public:
  allocator () : a_reps (0), a_free (0) {}

  ~allocator ()
    {
      free_all ();
    }

  T *alloc ()
    {
      if (!a_free)
        {
          arep *r = (arep *)a_heap.alloc ();
          if (!r)
            return 0;
          r->a_next = a_reps;
          a_reps = r;
          a_free = r + 1;
          arep *p, *pe;
          for (p = a_free, pe = (arep *)((T *)p + ((a_heap.size () - sizeof *p)
                                                   / sizeof (T) - 1));
               p < pe; p = (arep *)((T *)p + 1))
            p->a_next = (arep *)((T *)p + 1);
          p->a_next = 0;
        }
      T *p = (T *)a_free;
      a_free = a_free->a_next;
      return p;
    }

  void free (T *p)
    {
      ((arep *)p)->a_next = a_free;
      a_free = (arep *)p;
    }

  void free_all ()
    {
      for (arep *p = a_reps, *next; p; p = next)
        {
          next = p->a_next;
          a_heap.free (p);
        }
      a_reps = 0;
      a_free = 0;
    }
};

typedef allocator <Chunk> ChunkHeap;
typedef allocator <textprop> textprop_heap;

# define NO_MARK_SET (-1)

struct Point
{
  point_t p_point;
  Chunk *p_chunk;
  int p_offset;

  Char ch () const;
  Char &ch ();
  Char prevch () const;
};

inline Char
Point::ch () const
{
  assert (p_chunk);
  assert (p_offset >= 0 && p_offset < p_chunk->c_used);
  return p_chunk->c_text[p_offset];
}

inline Char &
Point::ch ()
{
  assert (p_chunk);
  assert (p_offset >= 0 && p_offset < p_chunk->c_used);
  return p_chunk->c_text[p_offset];
}

inline Char
Point::prevch () const
{
  assert (p_chunk);
  if (p_offset)
    return p_chunk->c_text[p_offset - 1];
  const Chunk *p = p_chunk->c_prev;
  assert (p);
  assert (p->c_used > 0);
  return p->c_text[p->c_used - 1];
}

struct ReadFileContext;
class xread_stream;
class xwrite_stream;
class xwrite_buffer;
class save_excursion;
class save_restriction;
enum syntax_code : int;

class FileTime: public _FILETIME
{
public:
  enum {VOID_TIME = -1};
  FileTime ();
  FileTime (lisp, int);
  int voidp ();
  void clear ();
  void file_modtime (lisp, int);
  FileTime &operator = (const _FILETIME &);
};

inline int
operator == (const _FILETIME &a, const _FILETIME &b)
{
  return a.dwLowDateTime == b.dwLowDateTime && a.dwHighDateTime == b.dwHighDateTime;
}

inline int
operator != (const _FILETIME &a, const _FILETIME &b)
{
  return a.dwLowDateTime != b.dwLowDateTime || a.dwHighDateTime != b.dwHighDateTime;
}

inline int
operator < (const _FILETIME &a, const _FILETIME &b)
{
  return CompareFileTime (&a, &b) < 0;
}

inline int
operator > (const _FILETIME &a, const _FILETIME &b)
{
  return CompareFileTime (&a, &b) > 0;
}

inline void
FileTime::clear ()
{
  dwLowDateTime = VOID_TIME;
  dwHighDateTime = VOID_TIME;
}

inline
FileTime::FileTime ()
{
  clear ();
}

inline
FileTime::FileTime (lisp path, int dir_ok)
{
  file_modtime (path, dir_ok);
}

inline int
FileTime::voidp ()
{
  return dwLowDateTime == VOID_TIME && dwHighDateTime == VOID_TIME;
}

inline FileTime &
FileTime::operator = (const _FILETIME &s)
{
  dwLowDateTime = s.dwLowDateTime;
  dwHighDateTime = s.dwHighDateTime;
  return *this;
}

struct insertChars
{
  const Char *string;
  int length;
};

enum eol_code : int
{
  eol_lf,
  eol_crlf,
  eol_cr,
  eol_guess,
  eol_noconv = eol_lf
};

static inline int
valid_eol_code_p (int code)
{
  return code >= eol_lf && code <= eol_guess;
}

static inline int
exact_valid_eol_code_p (int code)
{
  return code >= eol_lf && code < eol_guess;
}

static inline eol_code
exact_eol_code (int code, int default_code = 1)
{
  return (exact_valid_eol_code_p (code) ? eol_code (code)
          : exact_valid_eol_code_p (default_code) ? eol_code (default_code)
          : eol_crlf);
}

class UndoInfo;

struct fold_parameter
{
  int mode;
  int extend_limit;
  int shorten_limit;
};

struct write_region_param
{
  lisp encoding;
  eol_code eol;
  int error;
  int error_open;
};

struct glyph_width;

struct Buffer
{
  static Buffer *b_blist;
  static Buffer *b_dlist;

  static Buffer *b_last_selected_buffer;

  Buffer *b_prev;
  Buffer *b_next;
  Buffer *b_ldisp;

  ChunkHeap b_chunk_heap;

  Chunk *b_chunkb;
  Chunk *b_chunke;
  long b_nchars;
  long b_nlines;
  long b_nfolded;

  textprop_heap b_textprop_heap;
  textprop *b_textprop;
  textprop *b_textprop_cache;

  Region b_contents;
  point_t b_point;
  point_t b_mark;

  point_t b_disp;

  long b_version;

  static long b_total_create_count;
  long b_create_count;

  static Buffer *b_last_title_bar_buffer;
  static int b_title_bar_text_order;

  eol_code b_eol_code;

  enum selection_type
    {
      SELECTION_TYPE_MASK = 3,
      SELECTION_VOID = 0,
      SELECTION_LINEAR = 1,
      SELECTION_REGION = 2,
      SELECTION_RECTANGLE = 3,
      PRE_SELECTION = 0x100,
      CONTINUE_PRE_SELECTION = 0x200
    };
  selection_type b_selection_type;
  point_t b_selection_point;
  point_t b_selection_marker;
  long b_selection_column;

  selection_type b_reverse_temp;
  Region b_reverse_region;

  enum
    {
      BUFFER_BAR_MODIFIED = 1,
      BUFFER_BAR_CREATED = 2,
      BUFFER_BAR_DELETED = 4,
      BUFFER_BAR_LAST_MODIFIED_FLAG = 8,
      BUFFER_BAR_MARK = 16
    };
  COLORREF b_buffer_bar_fg;
  COLORREF b_buffer_bar_bg;
  static u_char b_buffer_bar_modified_any;
  u_char b_buffer_bar_modified;
  u_char b_truncated;
  u_char b_modified;
  long b_modified_count;
  Region b_modified_region;
  point_t b_last_modified;

  u_char b_need_auto_save;
  u_char b_done_auto_save;
  u_char b_make_backup;
  u_char b_buffer_name_modified;

  FileTime b_modtime;
  HANDLE b_hlock;

  int b_narrow_depth;
  int b_last_narrow_depth;

# define Buffer_gc_start lbp
  lisp lbp;
  lisp lvar;
  lisp lmap;
  lisp lminor_map;
  lisp lsyntax_table;
  lisp lbuffer_name;
  lisp ldirectory;
  lisp lfile_name;
  lisp lalternate_file_name;
  lisp lminibuffer_buffer;
  lisp ldialog_title;
  lisp lminibuffer_default;
  lisp lcomplete_type;
  lisp lcomplete_list;
  lisp lprocess;
  lisp lmenu;
  lisp lwaitobj_list;
  lisp lkinsoku_bol_chars;
  lisp lkinsoku_eol_chars;
  lisp lchar_encoding;
# define Buffer_gc_end lchar_encoding

  lisp lmarkers; // XXX

  u_char b_minibufferp;
  const ucs4_t *b_prompt;
  int b_prompt_length;
  int b_prompt_columns;
  char b_prompt_arg[16];

  UndoInfo *b_undo;
  UndoInfo *b_redo;
  int b_undo_count;

  save_excursion *b_excursion;
  save_restriction *b_restriction;

  XCOLORREF b_colors[USER_DEFINABLE_COLORS];
  int b_colors_enable;

  int b_hjump_columns;

  static int b_default_fold_mode;
  int b_fold_columns;  // 折り返しカラム(-1: しない)
  enum {FOLD_DEFAULT = -2, FOLD_NONE = -1, FOLD_WINDOW = 0};
  int b_fold_mode;

  enum {LNMODE_DEFAULT, LNMODE_DISP, LNMODE_LF};
  static int b_default_linenum_mode;
  int b_linenum_mode;
  int linenum_mode () const {return (b_linenum_mode == LNMODE_DEFAULT
                                     ? b_default_linenum_mode
                                     : b_linenum_mode);}

  lisp kinsoku_eol_chars () const {return (lkinsoku_eol_chars != Qnil
                                           ? lkinsoku_eol_chars
                                           : xsymbol_value (Vdefault_kinsoku_eol_chars));}
  lisp kinsoku_bol_chars () const {return (lkinsoku_bol_chars != Qnil
                                           ? lkinsoku_bol_chars
                                           : xsymbol_value (Vdefault_kinsoku_bol_chars));}

  enum
    {
      KINSOKU_DEFAULT = -1,
      KINSOKU_NONE = 0,
      KINSOKU_EOL = 1,
      KINSOKU_SPC = 2,
      KINSOKU_WORDWRAP = 4,
      KINSOKU_CHARS = 8,

      KINSOKU_MODE_MASK = 15
    };
  static int b_default_kinsoku_mode;
  int b_kinsoku_mode;
  int kinsoku_mode () const {return (b_kinsoku_mode == KINSOKU_DEFAULT
                                     ? b_default_kinsoku_mode
                                     : b_kinsoku_mode);}

  enum {MAX_KINSOKU_LIMIT = 16};
  static int b_default_kinsoku_extend_limit;
  static int b_default_kinsoku_shorten_limit;
  int b_kinsoku_extend_limit;
  int b_kinsoku_shorten_limit;
  int kinsoku_extend_limit () const {return (b_kinsoku_extend_limit < 0
                                             ? b_default_kinsoku_extend_limit
                                             : b_kinsoku_extend_limit);}
  int kinsoku_shorten_limit () const {return (b_kinsoku_shorten_limit < 0
                                              ? b_default_kinsoku_shorten_limit
                                              : b_kinsoku_shorten_limit);}

  int b_tab_columns;
  int b_local_tab_columns;

  int b_ime_mode;

  int b_wflags;
  int b_wflags_mask;

  Point b_stream_cache;

  int b_post_modified_hook_enabled;
  int b_in_post_modified_hook;

  Chunk *alloc_chunk ();
  void free_chunk (Chunk *);
  void free_all_chunks (Chunk *);
  void delete_chunk (Chunk *);
  void delete_contents ();
  void erase ();
  void delete_all_markers ();

  textprop *make_textprop () {return b_textprop_heap.alloc ();}
  void free_textprop (textprop *p)
    {
      if (p == b_textprop_cache)
        b_textprop_cache = 0;
      b_textprop_heap.free (p);
    }
  textprop *textprop_head (point_t point) const
    {
      return (b_textprop_cache && b_textprop_cache->t_range.p2 <= point
              ? b_textprop_cache : b_textprop);
    }
  textprop *find_textprop (point_t) const;
  textprop *add_textprop (point_t, point_t);
  void textprop_adjust_insertion (point_t, int);
  void textprop_adjust_deletion (point_t, int);

  void modify ();
  void modify_chunk (Chunk *) const;
  void set_modified_region (point_t, point_t);
  void prepare_modify_buffer ();
  void prepare_modify_region (Window *, point_t, point_t);
  point_t prepare_modify_region (Window *, lisp, lisp);
  void call_post_buffer_modified_hook (lisp, Point &, point_t, point_t);
  void post_buffer_modified (lisp ope, Point &point, point_t from, point_t to)
    {
      if (b_post_modified_hook_enabled)
        call_post_buffer_modified_hook (ope, point, from, to);
    }

  void insert_chars (Point &, const Char *, int);
  void insert_chars (Point &, const ucs4_t *, int);
  void insert_chars (Window *, const Char *, int, int);
  void insert_chars (Window *, const insertChars *, int, int);
  int insert_chars_internal (Point &, const Char *, int, int);
  int insert_chars_internal (Point &, const insertChars *, int, int);
  int pre_insert_chars (Point &, int size_cu, int size_cp);
  void post_insert_chars (Point &, int size_cu, int size_cp);
  void delete_region (Window *, point_t, point_t);
  int delete_region_internal (Point &, point_t, point_t);
  void insert_file_contents (Window *, lisp, lisp, lisp, lisp, ReadFileContext &);
  void set_point (Point &, point_t) const;
  void set_point_no_restrictions (Point &, point_t);
  int move_gap (Point &, int);
  int allocate_new_chunks (Point &, int);
  void move_after_gap (Point &, int) const;
  void move_before_gap (Point &, int) const;
  void adjust_insertion (const Point &, int);
  void adjust_deletion (const Point &, int);
  void overwrite_chars (Window *, const Char *, int);

  void file_modtime (FileTime &ft);
  void update_modtime ();
  int verify_modtime ();

  int read_only_p () const
    {return symbol_value (Vbuffer_read_only, this) != Qnil;}
  void check_read_only () const;

  int delete_surplus_undo ();
  UndoInfo *setup_save_undo ();
  UndoInfo *setup_insert_undo (point_t, int);
  void save_insert_undo (UndoInfo *, point_t, int);
  int save_delete_undo (const Point &, int);
  int save_modify_undo (const Point &, int);
  void save_modtime_undo (const FileTime &);
  void chain_undo (UndoInfo *);
  void clear_undo_info ();
  void undo_boundary ();
  int clear_undo_boundary ();
  void process_undo (UndoInfo *&);
  int undo_step (Window *, UndoInfo *&, int &);
  point_t last_modified_point () const;

  void substring (const Point &, int, Char *) const;
  void substring (point_t, int, Char *) const;
  void substring (const Point &, int, ucs4_t *) const;
  void substring (point_t, int, ucs4_t *) const;
  lisp substring (point_t, point_t) const;

  Buffer (lisp, lisp, lisp, int = 0);
  ~Buffer ();

  static Buffer *create_buffer (lisp, lisp, lisp);
  void link_list ();
  void unlink_list () const;
  static Buffer *find_buffer (const ucs4_t *, int, long);
  static Buffer *find_buffer (lisp, long, int);
  static Buffer *make_internal_buffer (const char *);
  void set_local_variable (lisp, lisp);
  void make_local_variable (lisp);

  Chunk *read_chunk (ReadFileContext &, xread_stream &);
  int read_file_contents (ReadFileContext &, xread_stream &);
  int read_file_contents (ReadFileContext &, const wchar_t *, int, int);
  int write_region (const wchar_t *, point_t, point_t, int, write_region_param &);
  int write_region (xwrite_stream &, xwrite_buffer &, int &);
  void init_write_region_param (write_region_param &, lisp, lisp) const;

  int readin_chunk (ReadFileContext &, xread_stream &);
  int readin_chunk (ReadFileContext &, const wchar_t *);

  int make_auto_save_file_name (wchar_t *);
  void delete_auto_save_file ();
  int make_backup_file_name (wchar_t *, const wchar_t *);
  lisp save_buffer (lisp encoding, lisp eol);

  void goto_char (Point &, point_t) const;
  int line_forward (Point &, long) const;
  int line_backward (Point &, long) const;
  void goto_bol (Point &) const;
  void goto_eol (Point &) const;
  int forward_line (Point &, long) const;
  int forward_char (Point &, long) const;
  /* Phase 2-1: cu 単位で walk する variant。search/regex の内部で
     atom = code unit を維持しつつ Point invariant を保つために使う。
     p_point は cp 単位、p_offset は cu 単位のまま扱う。 */
  int cu_forward_char (Point &, long) const;
  /* (chunk, cu_offset) から buffer 先頭までの cp 距離を返す。O(chunks)。 */
  point_t cp_position_of (const Chunk *, int) const;
  /* (chunk, cu_offset) から buffer 先頭までの cu 距離を返す。O(chunks)。 */
  point_t cu_position_of (const Chunk *, int) const;
  /* cp offset -> cu offset (buffer 先頭基準)。O(chunks)。 */
  point_t cu_from_cp (point_t) const;
  /* cu offset -> cp offset (buffer 先頭基準)。O(chunks)。 */
  point_t cp_from_cu (point_t) const;
  /* Point の (p_chunk, p_offset) から p_point を再計算 */
  void refresh_cp (Point &) const;
  long count_lines ();
  int bolp (const Point &) const;
  int eolp (const Point &) const;
  int bobp (const Point &) const;
  int eobp (const Point &) const;
  int forward_word (Point &, long) const;
  void valid_marker_p (lisp marker) const;

  long point_column (const Point &) const;
  long forward_column (Point &, long, long, int, int) const;
  long goto_column (Point &, long, int) const;
  long point_linenum (const Point &) const;
  long point_linenum (point_t) const;
  long linenum_point (Point &, long);
  void go_bol (Point &) const;
  void go_eol (Point &) const;
  int next_char (Point &) const;
  void narrow_to_region (point_t, point_t);
  void widen ();

  int scan_forward (Point &, const Char *, int, const int *, point_t, int) const;
  int scan_backward (Point &, const Char *, int, const int *, point_t, int) const;
  int word_bound (const Point &) const;
  int symbol_bound (const Point &) const;
  int bm_execf (Point &, const Char *, int, const int *, point_t, int) const;
  int bm_execb (Point &, const Char *, int, const int *, point_t, int) const;
  int re_scan_buffer (Point &, lisp, point_t, point_t, lChar, int) const;

  point_t coerce_to_point (lisp) const;
  point_t coerce_to_restricted_point (lisp) const;
  static Buffer *coerce_to_buffer (lisp);
  Char *buffer_name (Char *, Char *) const;
  void modify_mode_line () const;
  void modify_buffer_bar ()
    {
      b_buffer_bar_modified |= BUFFER_BAR_MODIFIED;
      b_buffer_bar_modified_any |= BUFFER_BAR_MODIFIED;
    }
  static void maybe_modify_buffer_bar ()
    {b_buffer_bar_modified_any |= BUFFER_BAR_MODIFIED;}
  void buffer_bar_created ()
    {
      b_buffer_bar_modified |= BUFFER_BAR_CREATED;
      b_buffer_bar_modified_any |= BUFFER_BAR_CREATED;
    }
  static int count_modified_buffers ();
  static int query_kill_xyzzy ();
  static int kill_xyzzy (int);

  void refresh_mode_line ();
  void refresh_buffer () const;

  void dlist_remove ();
  void dlist_add_head ();
  void dlist_add_tail ();
  void dlist_force_add_tail ();
  static Buffer *dlist_find ();
  int internal_buffer_p () const;

  int escaped_char_p (const Point &, int = 0) const;
  int skip_string (Point &, Char, int) const;
  int skip_multi_chars_comment (Point &, int, int, int) const;
  int comment_char_p (Point &, int, int) const;
  int skip_single_char_comment (Point &, int, syntax_code) const;
  int skip_maybe_comment (Point &) const;
  int skip_cplusplus_comment_forward (Point &) const;
  int skip_cplusplus_comment_backward (Point &) const;
  int goto_matched_open (Point &, Char) const;
  int goto_matched_close (Point &, Char) const;
  int skip_symbol (Point &, int) const;
  int skip_white_forward (Point &, int) const;
  int skip_white_backward (Point &, int) const;
  int skip_sexp_forward (Point &) const;
  int skip_sexp_backward (Point &) const;
  int column_comment_p (const struct syntax_table *, const Point &) const;
  int up_down_list (Point &, int, int) const;

  void invalidate_syntax () const;

  int symbol_match_p (const Point &, const char *, int, int) const;
  int symbol_match_p (const Point &, const Char *, int, int) const;
  int forward_identifier (Point &, const Char *, int, const Char *, int, int) const;
  int backward_identifier (Point &, const Char *, int, const Char *, int, int) const;
  void skip_pure_white (Point &) const;
  int c_goto_if_directive (Point &) const;
  int c_skip_white_backward (Point &, int) const;
  int c_label_line_p (const Point &) const;
  int first_char_p (const Point &) const;
  int c_goto_match_if (Point &) const;
  int calc_c_indent (Point &, Point &, int) const;
  int c_beginning_of_stmt (Point &, int, Point * = 0) const;
  int c_class_decl_p (Point &, const Point &, int) const;
  int c_in_class_p (const Point &, int) const;
  int c_argdecl_p (Point &, Point &, const Point &, const Point &, int, int) const;
  int c_check_class_decl (Point &, Point &, const Point &, int, Char) const;
  int c_check_throws (Point &, Point &, const Point &, int) const;
  int c_check_extern_p (const Point &) const;
  int java_check_annotation_p (Point &) const;
  int c_preprocessor_directive_p (const Point &opoint) const;
  int csharp_region_directive_p (const Point &point, int syntax_opt) const;
  int csharp_using_statement_p (const Point &opoint, int syntax_opt) const;

  lisp lock_file ();
  lisp lock_file (lisp, int);
  int unlock_file ();
  int file_locked_p () const;

  void refresh_title_bar () const;
  void set_frame_title (int);
  Char *store_title (lisp, Char *, Char *) const;

  void change_colors (const XCOLORREF *);

  long char_columns (Char, long) const;

  long folded_point_linenum (point_t) const;
  long folded_point_linenum (const Point &point) const
    {return folded_point_linenum (point.p_point);}
  long folded_linenum_point (Point &, long);
  long folded_count_lines ();
  long folded_point_column (const Point &) const;
  long folded_point_linenum_column (point_t, long *) const;
  long folded_point_linenum_column (const Point &point, long *columnp) const
    {return folded_point_linenum_column (point.p_point, columnp);}
  void folded_go_bol (Point &) const;
  void folded_go_eol (Point &) const;
  long folded_forward_column (Point &, long, long, int, int) const;
  void folded_goto_bol (Point &) const;
  void folded_goto_eol (Point &) const;
  int folded_forward_line (Point &, long);
  long folded_goto_column (Point &, long, int) const;

  void init_fold_width (int);
  void window_size_changed ();

  void check_range (Point &) const;

  void change_ime_mode ();
  void upcase_region_internal (Point &, point_t);
  void downcase_region_internal (Point &, point_t);
  void capitalize_region_internal (Point &, point_t);

  void cleanup_waitobj_list ();

  void fold_width_modified ();

  int parse_fold_line (Point &, long, const fold_parameter &) const;
  int parse_fold_line (Point &point, const fold_parameter &param) const
    {return parse_fold_line (point, b_fold_columns, param);}
  void parse_fold_chunk (Chunk *) const;
  int parse_fold_line (Point &, long, const glyph_width &,
                       const fold_parameter &) const;

  struct update_fold_info
    {
      point_t point;
      Chunk *cp;
      long linenum;
    };
  void update_fold_chunk (point_t, update_fold_info &) const;
  void folded_go_bol_1 (Point &) const;
  long folded_point_column_1 (point_t, const update_fold_info &) const;
  long folded_point_column_1 (point_t, Point &) const;

  int check_hook (lisp, lisp &) const;
  lisp run_hook (lisp) const;
  lisp run_hook (lisp, lisp) const;
  lisp run_hook (lisp, lisp, lisp) const;
  lisp run_hook (lisp, lisp, lisp, lisp) const;
  lisp run_hook (lisp, lisp, lisp, lisp, lisp) const;
  lisp run_hook (lisp, lisp, lisp, lisp, lisp, lisp) const;
  lisp run_hook_while_success (lisp) const;
  lisp run_hook_while_success (lisp, lisp) const;
  lisp run_hook_until_success (lisp) const;
  lisp run_hook_until_success (lisp, lisp) const;
  lisp safe_run_hook (lisp, int) const;

  Buffer *next_buffer (int);
  Buffer *prev_buffer (int);
#ifdef DEBUG
  void check_valid () const;
#endif
};

inline long
Buffer::point_linenum (const Point &point) const
{
  return point_linenum (point.p_point);
}

inline int
Buffer::bobp (const Point &p) const
{
  return p.p_point == b_contents.p1;
}

inline int
Buffer::eobp (const Point &p) const
{
  return p.p_point == b_contents.p2;
}

inline void
Buffer::update_modtime ()
{
  file_modtime (b_modtime);
}

inline int
Buffer::internal_buffer_p () const
{
  return *xstring_contents (lbuffer_name) == ' ';
}

inline lisp
Buffer::lock_file ()
{
  return lock_file (lfile_name, 0);
}

inline int
Buffer::file_locked_p () const
{
  return b_hlock != INVALID_HANDLE_VALUE;
}

static inline long
char_columns (Char c, long column, long tab)
{
  if (c == '\t')
    return tab - column % tab;
  /* combining / ZWJ / VS 等 (EAW 0) は描画上も 0 幅 (paint 側は
     glyph_sbchar で emit 自体 skip)。column 計算も 0 に合わせることで
     cursor 位置と描画位置の乖離を防ぐ。
     char_width() は最低 1 を保証するので、column 計算では unicode_width
     を直接引いて 0 を許容する。 */
  int w = unicode_width (c);
  if (c == '\n' || c == CC_DEL)
    return 1;   /* 制御文字 etc は 1 幅扱いのまま (display も ^X で占める) */
  return w;
}

inline long
Buffer::char_columns (Char c, long column) const
{
  return ::char_columns (c, column, b_tab_columns);
}


class no_restrictions
{
  Buffer *bufp;
  Region oreg;
public:
  no_restrictions (Buffer *bp) : bufp (bp), oreg (bp->b_contents)
    {
      bp->b_contents.p1 = 0;
      bp->b_contents.p2 = bp->b_nchars;
    }
  ~no_restrictions ()
    {
      bufp->b_contents = oreg;
    }
};

struct ReadFileContext
{
  enum
    {
      RFCS_NOERR,
      RFCS_OPEN,
      RFCS_MEM,
      RFCS_IOERR
    };
  int r_status;
  eol_code r_expect_eol;
  eol_code r_eol_code;
  lisp r_expect_char_encoding;
  lisp r_char_encoding;
  DWORD r_errcode;
  long r_nchars;
  long r_nlines;
  FileTime r_modtime;
  Chunk *r_chunk;
  Chunk *r_tail;
  int r_cr;
};

void create_default_buffers ();
void discard_insert_undo (UndoInfo *);

/* C-level tree-sitter edit hooks set by ts.cc at startup (main thread only).
   pre_edit:  called before delete/overwrite with the cp range being removed.
   post_edit: called after every edit with (start_cp, new_end_cp). */
typedef void (*ts_edit_fn)(Buffer *, point_t start, point_t end_pos);
extern ts_edit_fn g_ts_pre_edit;
extern ts_edit_fn g_ts_post_edit;

#endif
