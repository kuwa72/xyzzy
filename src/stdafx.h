// stdafx.h : 標準のシステム インクルード ファイルのインクルード ファイル、または
// 参照回数が多く、かつあまり変更されない、プロジェクト専用のインクルード ファイル
// を記述します。
//

#pragma once

#include "targetver.h"

#include <windows.h>

#include <commctrl.h>
#include <ctype.h>
#include <ddeml.h>
#ifdef _MSC_VER
#include <eh.h>
#endif
#include <errno.h>
#include <fcntl.h>
#include <float.h>
#include <imm.h>
#include <io.h>
#include <limits.h>
#include <list>
#include <malloc.h>
#include <math.h>
#ifdef _MSC_VER
#include <mbctype.h>
#include <mbstring.h>
#include <new.h>
#endif
#include <objbase.h>
#include <ole2.h>
#include <ole2ver.h>
#include <olectl.h>
#include <process.h>
#include <propkey.h>
#include <rpc.h>
#include <setjmp.h>
#include <share.h>
#include <shlobj.h>
#include <ShObjIdl.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <windows.h>
#include <winioctl.h>
#include <winreg.h>
#include <winsock.h>
#include <wtypes.h>
#include <tchar.h>

#include "wconv.h"

/* 64-bit / MinGW compatibility for window/dialog APIs */
#ifndef DWL_USER
# define DWL_USER DWLP_USER
#endif
#ifndef DWL_MSGRESULT
# define DWL_MSGRESULT DWLP_MSGRESULT
#endif
#ifndef GWL_WNDPROC
# define GWL_WNDPROC GWLP_WNDPROC
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

/* MinGW compatibility */
#ifndef _MSC_VER
#include <cmath>
using std::isnan;
#define _finite std::isfinite
#define _isnan std::isnan
#define _copysign copysign
#define _chgsign(x) (-(x))
/* MinGW's windows.h only defines min/max macros for C, not C++ */
#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#endif
