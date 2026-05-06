// -*-C++-*-
#ifndef _StrBuf_h_
# define _StrBuf_h_

# include "cdecl.h"

class StrBuf
{
protected:
  struct strbuf_chunk
    {
      strbuf_chunk *cdr;
      ucs4_t *used;
      ucs4_t contents[1];
    };

  strbuf_chunk *sb_chunk;
  int sb_chunk_size;
  ucs4_t *sb_next;
  ucs4_t *sb_limit;
  int sb_finished;

  virtual void alloc ();

  void dump (strbuf_chunk *) const;

  void *sb_initial_buffer;

  void clear ();
  void init ();

  int linear_p () const;

public:
  StrBuf (void *, int);
  StrBuf (int = 2040);
  ~StrBuf ();

  void empty ();
  int empty_p () const;

  void add (ucs4_t);
  void add (int);
  void fill (ucs4_t, int);
  void fill (int, int);
  void add (const char *);
  void add (const ucs4_t *, int);
  void add (const Char *, int);
  void add (StrBuf &);
  void add_simple (const char *);
  void add_simple (const char *, int);

  void finish ();
  void copy (ucs4_t *);
  operator const ucs4_t * () const;
  int length () const;
  lisp make_string ();
  lisp make_substring (int, int);

  void dump () const;
};

inline
StrBuf::StrBuf (void *p, int size)
{
  assert (p);
  assert (size >= sizeof (strbuf_chunk));
  sb_initial_buffer = p;
  sb_chunk_size = (size - offsetof (strbuf_chunk, contents)) / sizeof (ucs4_t);
  init ();
}

inline
StrBuf::StrBuf (int size)
{
  assert (size > 0);
  sb_initial_buffer = 0;
  sb_chunk_size = size;
  init ();
}

inline
StrBuf::~StrBuf ()
{
  clear ();
}

inline void
StrBuf::empty ()
{
  clear ();
  init ();
}

inline void
StrBuf::add (ucs4_t c)
{
  assert (!sb_finished);
  if (sb_next == sb_limit)
    alloc ();
  *sb_next++ = c;
}

inline void
StrBuf::add (int c)
{
  add (ucs4_t (c & 0xff));
}

inline void
StrBuf::fill (int c, int n)
{
  fill (ucs4_t (c & 0xff), n);
}

inline
StrBuf::operator const ucs4_t * () const
{
  return sb_chunk->contents;
}

inline int
StrBuf::linear_p () const
{
  return sb_chunk && !sb_chunk->cdr;
}

#endif
