// -*-C++-*-
#ifndef _utils_h_
# define _utils_h_

# include <stddef.h>

void *xmalloc (size_t);
void *xrealloc (void *, size_t);
void xfree (void *);
char *xstrdup (const char *);
wchar_t *xwcsdup (const wchar_t *);
void *xmemdup (const void *, size_t);
#ifdef _WIN32
char *stpcpy (char *, const char *);
char *stpncpy (char *, const char *, int);
#endif
long log2 (u_long);

# define NF_BAD 0
# define NF_INTEGER 1
# define NF_INTEGER_DOT 2
# define NF_FRACTION 3
# define NF_FLOAT 0x100
# define  NF_FLOAT_E (NF_FLOAT | 'e')
# define  NF_FLOAT_S (NF_FLOAT | 's')
# define  NF_FLOAT_F (NF_FLOAT | 'f')
# define  NF_FLOAT_D (NF_FLOAT | 'd')
# define  NF_FLOAT_L (NF_FLOAT | 'l')

int parse_number_format (const Char *, const Char *, int);
int parse_number_format (const ucs4_t *, const ucs4_t *, int);
int check_integer_format (const char *, int *);
int default_float_format ();

int streq (const Char *, int, const char *);
int streq (const ucs4_t *, int, const char *);
int strequal (const char *, const Char *);
int strequal (const char *, const Char *, int);
int strequal (const char *, const ucs4_t *);
int strequal (const char *, const ucs4_t *, int);
int sjis_strcasecmp (const char *, const char *);
static inline int
strcaseeq (const char *s1, const char *s2)
{
  return !sjis_strcasecmp (s1, s2);
}

char *jindex (const char *, int);
char *jrindex (const char *, int);
char *find_last_slash (const char *);
wchar_t *find_last_slash_w (const wchar_t *);
char *find_slash (const char *);
wchar_t *find_slash_w (const wchar_t *);
void convert_backsl_with_sl (char *, int, int);

inline void
map_backsl_to_sl (char *s)
{
  convert_backsl_with_sl (s, '\\', '/');
}

inline void
map_sl_to_backsl (char *s)
{
  convert_backsl_with_sl (s, '/', '\\');
}

/* Wide paths need the same handful of helpers. They are simpler than the
   char* versions: a UTF-16 unit is never mistaken for the trail byte of a
   two-byte character, so there is nothing to skip over. */
inline void
map_backsl_to_sl (wchar_t *s)
{
  for (; *s; s++)
    if (*s == L'\\')
      *s = L'/';
}

inline void
map_sl_to_backsl (wchar_t *s)
{
  for (; *s; s++)
    if (*s == L'/')
      *s = L'\\';
}

/* Bounded wide printf. The two-argument swprintf that MSVC and mingw provide
   does not exist on POSIX, where swprintf always takes a size; this spells the
   size out so both agree, and always nul-terminates. Returns the number of
   units written, not counting the terminator. */
inline int
xsnwprintf (wchar_t *b, size_t n, const wchar_t *fmt, ...)
{
  if (!n)
    return 0;
  va_list ap;
  va_start (ap, fmt);
  int r = vswprintf (b, n, fmt, ap);
  va_end (ap);
  if (r < 0 || size_t (r) >= n)
    {
      b[n - 1] = 0;
      return int (wcslen (b));
    }
  return r;
}

inline wchar_t *
wstpcpy (wchar_t *d, const wchar_t *s)
{
  while ((*d = *s++))
    d++;
  return d;
}

inline wchar_t *
wstpncpy (wchar_t *d, const wchar_t *s, int n)
{
  for (; n > 0; n--)
    if (!(*d++ = *s++))
      return d - 1;
  *d = 0;
  return d;
}

inline char *
strappend (char *d, const char *s)
{
  return stpcpy (d + strlen (d), s);
}

inline wchar_t *
wcsappend (wchar_t *d, const wchar_t *s)
{
  return wstpcpy (d + wcslen (d), s);
}

static inline int
dir_separator_p (Char c)
{
  return c == '/' || c == '\\';
}

static inline int
dir_separator_p (int c)
{
  return c == '/' || c == '\\';
}

/* GDI で線と矩形を描く 6 つ (`fill_rect` / `draw_hline` / `draw_vline` /
   `paint_button_*`) と `frameDC` は `src/frontend/win32/gdi-utils.h` へ移した
   (issue #195 / #185)。**`src/core/` の中から呼んでいるコードが 1 つも
   無かった。**

   下の `find_handle` / `wnet_enum_handle` はここに残る。**`HANDLE` は
   `HDC` と違ってデバイスの話ではなく**、`pathname.cc` / `glob.cc` /
   `completion.cc` が実際に使っている。 */

class find_handle
{
  HANDLE h;
public:
  find_handle (HANDLE h_) : h (h_) {}
  ~find_handle () {FindClose (h);}
};

class wnet_enum_handle
{
  HANDLE h;
public:
  wnet_enum_handle (HANDLE h_) : h (h_) {}
  ~wnet_enum_handle () {WNetCloseEnum (h);}
};


#endif
