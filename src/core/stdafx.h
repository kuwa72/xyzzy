// stdafx.h : precompiled header / common system includes

#pragma once

#include "targetver.h"
#include "platform.h"

#ifdef _WIN32
// Windows-specific system headers
#include <commctrl.h>
#include <ddeml.h>
#include <imm.h>
#include <io.h>
#include <malloc.h>
#include <objbase.h>
#include <ole2.h>
#include <ole2ver.h>
#include <olectl.h>
#include <process.h>
#include <propkey.h>
#include <rpc.h>
#include <share.h>
#include <shlobj.h>
#include <ShObjIdl.h>
#include <winioctl.h>
#include <winsock.h>
#include <wtypes.h>
#include <tchar.h>
#ifdef _MSC_VER
#include <eh.h>
#include <mbctype.h>
#include <mbstring.h>
#include <new.h>
#endif
#endif // _WIN32

// Cross-platform headers
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <float.h>
#include <limits.h>
#include <list>
#include <math.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>

#include "wconv.h"

/* 64-bit / MinGW compatibility for window/dialog APIs */
#ifndef DWL_USER
# ifdef DWLP_USER
#  define DWL_USER DWLP_USER
# endif
#endif
#ifndef DWL_MSGRESULT
# ifdef DWLP_MSGRESULT
#  define DWL_MSGRESULT DWLP_MSGRESULT
# endif
#endif
#ifndef GWL_WNDPROC
# ifdef GWLP_WNDPROC
#  define GWL_WNDPROC GWLP_WNDPROC
# endif
#endif
#ifndef GWL_STYLE
# define GWL_STYLE (-16)
#endif
#ifndef GWL_EXSTYLE
# define GWL_EXSTYLE (-20)
#endif
#ifndef GWL_ID
# define GWL_ID (-12)
#endif

/* Non-MSVC compatibility */
#ifndef _MSC_VER
#include <cmath>
#ifndef _WIN32
// Already defined in platform.h for non-Windows
#else
using std::isnan;
#define _finite std::isfinite
#define _isnan std::isnan
#define _copysign copysign
#define _chgsign(x) (-(x))
#endif // _WIN32
/* min/max macros (MinGW's windows.h only defines for C, not C++) */
#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#endif // _MSC_VER
