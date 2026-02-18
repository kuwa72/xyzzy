#ifndef _wconv_h_
#define _wconv_h_

// CP932 <-> wchar_t conversion helpers for UNICODE build.
// Internal strings are CP932 (char*); Win32 W-APIs need wchar_t*.

#define XYZZY_CP932 932

// Stack-based CP932 -> wchar_t conversion (for short strings)
static inline wchar_t *
_cp932_to_wide (wchar_t *w, const char *a, int wlen)
{
  *w = 0;
  MultiByteToWideChar (XYZZY_CP932, 0, a, -1, w, wlen);
  return w;
}

// Stack-based wchar_t -> CP932 conversion
static inline char *
_wide_to_cp932 (char *a, const wchar_t *w, int alen)
{
  *a = 0;
  WideCharToMultiByte (XYZZY_CP932, 0, w, -1, a, alen, 0, 0);
  return a;
}

// Macro: CP932 char* -> wchar_t* (alloca on stack)
#define A2W(a) \
  (_convert = (int)(strlen (a) + 1),\
   _cp932_to_wide ((wchar_t *)alloca (_convert * sizeof (wchar_t)), (a), _convert))

// Macro: wchar_t* -> CP932 char* (alloca on stack)
#define W2A(w) \
  (_convert = (int)(wcslen (w) + 1) * 2,\
   _wide_to_cp932 ((char *)alloca (_convert), (w), _convert))

// RAII wide string from CP932 (heap allocated, for longer strings)
class WideStr
{
  wchar_t *m_buf;
  WideStr (const WideStr &);
  WideStr &operator= (const WideStr &);
public:
  explicit WideStr (const char *s)
  {
    int n = MultiByteToWideChar (XYZZY_CP932, 0, s, -1, 0, 0);
    m_buf = (wchar_t *)malloc (n * sizeof (wchar_t));
    if (m_buf)
      MultiByteToWideChar (XYZZY_CP932, 0, s, -1, m_buf, n);
  }
  ~WideStr () { free (m_buf); }
  operator const wchar_t * () const { return m_buf; }
  const wchar_t *c_str () const { return m_buf; }
};

// RAII CP932 string from wchar_t* (heap allocated)
class Cp932Str
{
  char *m_buf;
  Cp932Str (const Cp932Str &);
  Cp932Str &operator= (const Cp932Str &);
public:
  explicit Cp932Str (const wchar_t *w)
  {
    int n = WideCharToMultiByte (XYZZY_CP932, 0, w, -1, 0, 0, 0, 0);
    m_buf = (char *)malloc (n);
    if (m_buf)
      WideCharToMultiByte (XYZZY_CP932, 0, w, -1, m_buf, n, 0, 0);
  }
  ~Cp932Str () { free (m_buf); }
  operator const char * () const { return m_buf; }
  const char *c_str () const { return m_buf; }
};

#endif /* _wconv_h_ */
