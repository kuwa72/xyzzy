#ifndef _oleconv_h_
#define _oleconv_h_

#include "wconv.h"

static inline wchar_t *
_a2w_helper (wchar_t *w, const char *a, int l)
{
  *w = 0;
  MultiByteToWideChar (XYZZY_CP932, 0, a, -1, w, l);
  return w;
}

static inline char *
_w2a_helper (char *a, const wchar_t *w, int l)
{
  *a = 0;
  WideCharToMultiByte (XYZZY_CP932, 0, w, -1, a, l, 0, 0);
  return a;
}

static inline wchar_t *
_i2w_helper (wchar_t *w, const Char *p, int l)
{
  i2w (p, l, (ucs2_t *)w);
  return w;
}

#define USES_CONVERSION int _convert; _convert

#define I2W(x) \
  (_i2w_helper ((wchar_t *)alloca ((xstring_length (x) + 1) * sizeof (wchar_t)), \
                xstring_contents (x), xstring_length (x)))

#endif /* _oleconv_h_ */
