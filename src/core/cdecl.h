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
# include <algorithm>
# include <utility>
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
#endif

typedef uintptr_t pointer_t;

typedef uint16_t Char;
# define CHAR_LIMIT 0x110000  /* full Unicode scalar value space (U+0000..U+10FFFF + 1) */
typedef u_long lChar;
const lChar lChar_EOF = lChar (-1);

typedef uint16_t ucs2_t;
typedef uint32_t ucs4_t;

typedef long point_t;

# undef min
# undef max
# define NOMINMAX

using std::min;
using std::max;
using std::swap;

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

   The convention only has to be self-consistent: the lfunction_proc_* typedefs
   in lisp.h, the definitions of the primitives, and the declarations that
   gen-syms writes into fns-decl.h all have to agree.  Nothing outside the
   program depends on which one it is.

   Empty is what makes that true for every toolchain here.  MSVC x86 is built
   with /Gz, so unannotated functions and unannotated function pointer types
   are both __stdcall, and they agree.  Clang has no usable equivalent -- its
   -fdefault-calling-conv reaches into libc++, where unique_ptr deleters are
   handed the CRT's __cdecl free -- so there nothing is annotated and
   everything is __cdecl, and they agree as well.  On x64 and ARM64 __stdcall
   is ignored anyway.

   So LISP_CALL stays empty; what matters is that it is used everywhere the
   convention appears, rather than __stdcall being written out in some places
   and left off in others. */
# define LISP_CALL

#endif
