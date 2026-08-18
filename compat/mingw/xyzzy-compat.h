/* Differences between the Microsoft Windows SDK and mingw-w64 that the sources
   rely on.  Force-included (-include) by the CMake build; nothing includes it
   explicitly, and the MSVC build does not use it at all.  */
#ifndef _xyzzy_mingw_compat_h_
#define _xyzzy_mingw_compat_h_

/* The C++ standard headers the sources use are pulled in first, before the
   min/max macros below exist: libstdc++ declares three argument std::min and
   std::max overloads that a function like macro of the same name would mangle.
   A source file that starts using another C++ header has to be added here.  */
#include <algorithm>
#include <fstream>
#include <list>
#include <new>
#include <typeinfo>     /* <eh.h> uses std::type_info without declaring it */

/* src/environ.h declares "class environ" while src/process.cc and
   src/environ.cc read the CRT variable of the same name.  That works with the
   Microsoft CRT because there environ expands to a plain identifier, so the
   class name is merely hidden by the variable; mingw-w64 expands it to
   (*__p__environ()), which cannot follow the "class" keyword.  Give it the
   shape the sources expect.  */
#include <stdlib.h>
/* Bind the reference while environ is still the CRT's own macro, whose
   spelling differs between the 32 and 64 bit headers. */
static char **&xyzzy_environ __attribute__ ((unused)) = environ;
#undef environ
#define environ xyzzy_environ

/* MSVC-only; the same value as FLT_RADIX for IEEE doubles.  */
#include <float.h>
#ifndef _DBL_RADIX
# define _DBL_RADIX FLT_RADIX
#endif

/* The Windows SDK defines min/max as macros in C and in C++ alike; mingw-w64
   defines them for C only.  The sources expect the SDK behaviour and call
   unqualified min/max with mixed argument types.  NOMINMAX is not honoured
   here on purpose: cdecl.h defines it, but only after <windows.h> has already
   been included, so the MSVC build gets the macros regardless.  */
#ifndef max
# define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef min
# define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#endif /* _xyzzy_mingw_compat_h_ */
