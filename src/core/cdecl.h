// -*-C++-*-
#ifndef _cdecl_h_
# define _cdecl_h_

#ifdef _MSC_VER
# pragma warning (disable: 4201)
#endif

# include <stdio.h>
# include <stdint.h>
# include <limits.h>
# include "platform.h"
# include <stdlib.h>
# include <stddef.h>
# include <string.h>
#ifdef _MSC_VER
# include <mbstring.h>
#endif
#ifdef _WIN32
# include <malloc.h>
#endif

#ifdef _MSC_VER
# pragma warning (default: 4201)

# pragma warning (disable: 4510)
# pragma warning (disable: 4514)
# pragma warning (disable: 4610)
#endif

#ifdef _MSC_VER
# define alloca _alloca
# define memicmp _memicmp
# define strdup _strdup
# define stricmp _stricmp
#endif

# define BITS_PER_SHORT (sizeof (short) * CHAR_BIT)
# define BITS_PER_INT (sizeof (int) * CHAR_BIT)
# define BITS_PER_LONG (sizeof (long) * CHAR_BIT)

#ifdef _WIN32
# define PATH_MAX 1024
#else
# include <limits.h>
#endif
# define BUFFER_NAME_MAX PATH_MAX

#ifdef _WIN32
typedef unsigned char u_char;
typedef unsigned short u_short;
typedef unsigned int u_int;
typedef unsigned long u_long;

typedef u_char u_int8_t;
typedef u_short u_int16_t;
typedef u_long u_int32_t;
typedef uint64_t u_int64_t;
#endif

typedef uintptr_t pointer_t;

typedef u_int16_t Char;
# define CHAR_LIMIT 0x110000  /* full Unicode scalar value space (U+0000..U+10FFFF + 1) */
typedef u_long lChar;
const lChar lChar_EOF = lChar (-1);

typedef u_int16_t ucs2_t;
typedef u_int32_t ucs4_t;

typedef long point_t;

# undef min
# undef max
# define NOMINMAX

template <class T>
inline const T &
min (const T &a, const T &b)
{
  return a < b ? a : b;
}

template <class T>
inline const T &
max (const T &a, const T &b)
{
  return a > b ? a : b;
}

inline char min (char a, char b) {return a < b ? a : b;}
inline char max (char a, char b) {return a > b ? a : b;}
inline u_char min (u_char a, u_char b) {return a < b ? a : b;}
inline u_char max (u_char a, u_char b) {return a > b ? a : b;}
inline short min (short a, short b) {return a < b ? a : b;}
inline short max (short a, short b) {return a > b ? a : b;}
inline u_short min (u_short a, u_short b) {return a < b ? a : b;}
inline u_short max (u_short a, u_short b) {return a > b ? a : b;}
inline int min (int a, int b) {return a < b ? a : b;}
inline int max (int a, int b) {return a > b ? a : b;}
inline u_int min (u_int a, u_int b) {return a < b ? a : b;}
inline u_int max (u_int a, u_int b) {return a > b ? a : b;}
inline long min (long a, long b) {return a < b ? a : b;}
inline long max (long a, long b) {return a > b ? a : b;}
inline u_long min (u_long a, u_long b) {return a < b ? a : b;}
inline u_long max (u_long a, u_long b) {return a > b ? a : b;}
inline float min (float a, float b) {return a < b ? a : b;}
inline float max (float a, float b) {return a > b ? a : b;}
inline double min (double a, double b) {return a < b ? a : b;}
inline double max (double a, double b) {return a > b ? a : b;}

template <class T>
inline void
swap (T &a, T &b)
{
  T t = a;
  a = b;
  b = t;
}

inline int
bcmp (const void *p1, const void *p2, size_t size)
{
  return memcmp (p1, p2, size);
}

#ifdef _WIN32
inline void *
bzero (void *dst, size_t size)
{
  return memset (dst, 0, size);
}
#endif

inline void
bcopy (const Char *src, Char *dst, size_t size)
{
  memcpy (dst, src, sizeof (Char) * size);
}

inline int
bcmp (const Char *p1, const Char *p2, size_t size)
{
  return memcmp (p1, p2, sizeof (Char) * size);
}

inline void
bcopy (const ucs4_t *src, ucs4_t *dst, size_t size)
{
  memcpy (dst, src, sizeof (ucs4_t) * size);
}

inline int
bcmp (const ucs4_t *p1, const ucs4_t *p2, size_t size)
{
  return memcmp (p1, p2, sizeof (ucs4_t) * size);
}

template <class T>
inline T *
bfill (T *p0, int start, int end, T x)
{
  for (T *p = p0 + start, *pe = p0 + end; p < pe; p++)
    *p = x;
  return p0;
}

template <class T>
inline T *
bfill (T *p0, int size, T x)
{
  return bfill (p0, 0, size, x);
}

# define numberof(a) (sizeof (a) / sizeof *(a))

# ifdef DEBUG
int assert_failed (const char *, int);
#  define assert(f) \
  ((void)((f) || assert_failed (__FILE__, __LINE__)))
# else
#  define assert(f) /* empty */
# endif

# ifdef DEBUG
#  define DBG_PRINT(a) (printf a, fflush (stdout))
# else
#  define DBG_PRINT(a) /* empty */
# endif

# undef __CONCAT
# define __CONCAT(X, Y) X ## Y
# define CONCAT(X, Y) __CONCAT (X, Y)

# undef __CONCAT3
# define __CONCAT3(X, Y, Z) X ## Y ## Z
# define CONCAT3(X, Y, Z) __CONCAT3 (X, Y, Z)

# define __TOSTR(X) #X
# define _TOSTR(X) __TOSTR(X)
# define __TOWSTR(X) L##X
# define _TOWSTR(X) __TOWSTR (X)

#ifdef _MSC_VER
# define THREADLOCAL __declspec(thread)
#else
# define THREADLOCAL __thread
#endif
/* LISP_CALL: calling convention annotation for Lisp primitive functions.
   The original xyzzy used MSVC's /Gz flag (global __stdcall default) instead
   of per-function annotations.  We replicate that: /Gz is added to CMakeLists
   for MSVC x86 builds, so all functions are __stdcall by default, matching the
   lfunction_proc_* typedefs which use explicit __stdcall.  On x64/ARM64,
   __stdcall is silently ignored (= __cdecl), so no annotation is needed there.
   LISP_CALL is kept as empty to avoid redundant per-function annotation. */
# define LISP_CALL

#endif
