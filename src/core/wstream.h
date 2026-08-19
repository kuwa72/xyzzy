#ifndef _wstream_h_
# define _wstream_h_

# include "StrBuf.h"

class wStream: public StrBuf
{
  char buf[2040];
  int col;
  void update_column (ucs4_t);
  void update_column (ucs4_t, int);
  void update_column (const ucs4_t *, int);
public:
  wStream (int = 0);
  void add (int);
  void add (ucs4_t);
  void add (Char);
  void fill (int, int);
  void fill (ucs4_t, int);
  void add (const char *);
  void add (const ucs4_t *, int);
  void add (wStream &);
  int columns () const;
  void case_conversion (wStream &, int, int);
};

class wStreamsStream: public wStream
{
  lisp dest;
protected:
  virtual void alloc ();
public:
  wStreamsStream (lisp);
  ~wStreamsStream ();
};

inline
wStream::wStream (int l)
     : StrBuf (buf, sizeof buf), col (l)
{
}

inline void
wStream::update_column (ucs4_t c)
{
  col = ::update_column (col, c);
}

inline void
wStream::update_column (const ucs4_t *s, int size)
{
  col = ::update_column (col, s, size);
}

inline void
wStream::update_column (ucs4_t c, int size)
{
  col = ::update_column (col, c, size);
}

inline void
wStream::add (ucs4_t c)
{
  StrBuf::add (c);
  update_column (c);
}

inline void
wStream::add (int c)
{
  add (ucs4_t (c & 0xff));
}

/* wStream が add を宣言し直しているので StrBuf::add(Char) は名前隠蔽で
   見えない。ここにも置かないと Char (u_int16_t) は整数拡張で add(int) に
   落ちて上位バイトを失う。詳細は StrBuf::add(Char) のコメント。 */
inline void
wStream::add (Char c)
{
  add (ucs4_t (c));
}

inline void
wStream::fill (ucs4_t c, int size)
{
  if (size <= 0)
    return;
  StrBuf::fill (c, size);
  update_column (c, size);
}

inline void
wStream::fill (int c, int size)
{
  fill (ucs4_t (c & 0xff), size);
}

inline void
wStream::add (const ucs4_t *s, int size)
{
  if (size <= 0)
    return;
  StrBuf::add (s, size);
  update_column (s, size);
}

inline void
wStream::add (wStream &sb)
{
  StrBuf::add (sb);
  for (const strbuf_chunk *cp = sb.sb_chunk; cp; cp = cp->cdr)
    update_column (cp->contents, cp->used - cp->contents);
}

inline int
wStream::columns () const
{
  return col;
}

inline
wStreamsStream::wStreamsStream (lisp s)
     : wStream (get_stream_column (s)), dest (s)
{
}

inline
wStreamsStream::~wStreamsStream ()
{
  if (sb_next - sb_chunk->contents)
    write_stream (dest, sb_chunk->contents, sb_next - sb_chunk->contents);
}

#endif
