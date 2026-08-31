// -*-C++-*-
#ifndef _string_h_
# define _string_h_

/* string */

# include "array.h"

# define MAX_STRING_LENGTH (INT_MAX / sizeof (ucs4_t))

class lsimple_string: public lbase_vector
{
};

class lcomplex_string: public lbase_complex_vector
{
};

# define stringp(X) \
  object_type_mask_p ((X), TAvector | TAstring, TAvector | TAstring)
# define simple_string_p(X) typep ((X), Tsimple_string)
# define complex_string_p(X) typep ((X), Tcomplex_string)

inline void
check_string (lisp x)
{
  if (!stringp (x))
    FEtype_error (x, Qstring);
}

inline void
check_simple_string (lisp x)
{
  check_type (x, Tsimple_string, Qsimple_string);
}

# define xstring_length xvector_length
# define xstring_dimension xvector_dimension

inline ucs4_t *&
xstring_contents (lisp x)
{
  assert (stringp (x));
  return (ucs4_t *&)xbase_vector_contents (x);
}

inline lsimple_string *
make_simple_string ()
{
  lsimple_string *p = ldata <lsimple_string, Tsimple_string>::lalloc ();
  p->common_init ();
  return p;
}

inline lcomplex_string *
make_complex_string ()
{
  lcomplex_string *p = ldata <lcomplex_string, Tcomplex_string>::lalloc ();
  p->common_init ();
  return p;
}

inline int
string_equal (lisp x, lisp y)
{
  assert (stringp (x));
  assert (stringp (y));
  return (xstring_length (x) == xstring_length (y)
          && !memcmp (xstring_contents (x), xstring_contents (y), (xstring_length (x)) * sizeof (*(xstring_contents (x)))));
}

int string_equalp (const ucs4_t *, int, const char *, int);
int string_equalp (const ucs4_t *, int, const ucs4_t *, int);
int string_equalp (const Char *, int, const Char *, int);

inline int
string_equalp (lisp x, lisp y)
{
  return string_equalp (xstring_contents (x), xstring_length (x),
                        xstring_contents (y), xstring_length (y));
}

int string_equalp (lisp, int, lisp, int, int);

lisp parse_integer (lisp, int, int &, int, int);

int update_column (int, Char);
int update_column (int, const ucs4_t *, int);
int update_column (int, Char, int);
inline int update_column (int col, ucs4_t c) { return update_column (col, Char (c)); }
inline int update_column (int col, ucs4_t c, int n) { return update_column (col, Char (c), n); }
size_t s2wl (const char *);
ucs4_t *s2w (ucs4_t *, size_t, const char **);
ucs4_t *s2w (ucs4_t *, const char *);
ucs4_t *s2w (const char *, size_t);
ucs4_t *a2w (ucs4_t *, size_t, const char **);
void a2w (ucs4_t *, const char *, size_t);
ucs4_t *a2w (ucs4_t *, const char *);
ucs4_t *a2w (const char *, size_t);
size_t w2sl (const ucs4_t *, size_t);
size_t w2sl (const Char *, size_t);
char *w2s (char *, const ucs4_t *, size_t);
char *w2s (char *, const Char *, size_t);
char *w2s (const ucs4_t *, size_t);
char *w2s (char *, char *, const ucs4_t *, size_t);

size_t s2wl (const char *string, const char *se, int zero_term);
ucs4_t *s2w (ucs4_t *b, const char *string, const char *se, int zero_term);
void w2s_chunk (char *, char *, const ucs4_t *, size_t);

ucs2_t *i2w (const ucs4_t *, int, ucs2_t *);
int i2wl (const ucs4_t *, int);        /* UTF-16 units + 1; an upper bound for wchar_t too */
ucs4_t *w2i (const ucs2_t *, int, ucs4_t *);
int w2il (const ucs2_t *, int);
/* wchar_t is UTF-16 on Windows and UCS-4 elsewhere; these hide that. */
wchar_t *i2w (const ucs4_t *, int, wchar_t *);
ucs4_t *w2i (const wchar_t *, int, ucs4_t *);
ucs4_t *w2i (const wchar_t *, ucs4_t *);
int w2il (const wchar_t *, int);
/* UTF-8, for the byte interfaces of a Unix system. */
size_t i2u8l (const ucs4_t *, int);
char *i2u8 (const ucs4_t *, int, char *);
size_t u82il (const char *);
ucs4_t *u82i (const char *, ucs4_t *);
size_t u82il (const char *, const char *, int);
ucs4_t *u82i (ucs4_t *, const char *, const char *, int);
char *i2u8 (char *, char *, const ucs4_t *, size_t);

/* **コードポイント単位の大文字小文字を無視した比較。** 畳むのは ASCII の
   `A`-`Z` だけ。

   **バイト列の関数 (`memicmp` / `_memicmp`) で `ucs4_t` の配列を比べては
   いけない** (issue #184)。あちらはバイトごとに畳むので、
   `あ` (U+3042) と `ぢ` (U+3062) が**同じ文字列になる** — 下位バイトの
   0x42 (`B`) が 0x62 (`b`) に畳まれるため。Win32 では
   `src/frontend/win32/filer.cc` と `dialogs.cc` が実際にそうなっていた。

   ASCII だけ畳むのは、`_memicmp` が実際に畳んでいた範囲に合わせたため
   (locale に依る畳み方を入れると、上の誤りと同じ形で「どの文字が同じか」が
   環境で変わる)。 */
int ucs4_ncasecmp (const ucs4_t *, const ucs4_t *, size_t);
lisp make_string_from_utf8 (const char *);
inline int w2il (const wchar_t *p) { return w2il (p, int (wcslen (p))); }
Char *s2w_u16 (Char *, const char *);  /* SJIS → UTF-16 for Win32 API use */

lisp coerce_to_string (lisp, int);

lisp make_string (const char *);
lisp make_string (const u_char *);
lisp make_string (const char *, size_t);
lisp make_string_simple (const char *, size_t);
lisp make_string (const ucs4_t *, size_t);
lisp make_string (const Char *, size_t);   // UTF-16 (Win32 wchar_t) → ucs4_t Lisp string
lisp make_string (const wchar_t *, size_t);
lisp make_string (const wchar_t *);
lisp make_string (ucs4_t, size_t);
lisp make_complex_string (ucs4_t, int, int, int);
lisp make_string_from_list (lisp);
lisp make_string_from_vector (lisp);
lisp make_string (size_t);
lisp copy_string (lisp);

void string_start_end (lisp, int &, int &, lisp, lisp);
lisp subseq_string (lisp, lisp, lisp);

u_int hashpjw (const ucs4_t *, int);
u_int ihashpjw (const ucs4_t *, int);

inline u_int
hashpjw (lisp string)
{
  assert (stringp (string));
  return hashpjw (xstring_contents (string), xstring_length (string));
}

inline u_int
ihashpjw (lisp string)
{
  assert (stringp (string));
  return ihashpjw (xstring_contents (string), xstring_length (string));
}

inline u_int
hashpjw (lisp string, u_int prime)
{
  return hashpjw (string) % prime;
}

inline u_int
ihashpjw (lisp string, u_int prime)
{
  return ihashpjw (string) % prime;
}

inline size_t
w2sl (lisp l)
{
  return w2sl (xstring_contents (l), xstring_length (l));
}

inline char *
w2s (char *b, lisp l)
{
  return w2s (b, xstring_contents (l), xstring_length (l));
}

inline char *
w2s (lisp l)
{
  return w2s (xstring_contents (l), xstring_length (l));
}

inline char *
w2s (char *b, char *be, lisp l)
{
  return w2s (b, be, xstring_contents (l), xstring_length (l));
}

inline ucs2_t *
i2w (lisp x, ucs2_t *b)
{
  return i2w (xstring_contents (x), xstring_length (x), b);
}

inline int
i2wl (lisp x)
{
  return i2wl (xstring_contents (x), xstring_length (x));
}

#endif
