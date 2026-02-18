#pragma once

#ifdef _WIN32
# ifndef _WIN32_WINNT
#  define _WIN32_WINNT 0x0502
# endif
# ifdef _MSC_VER
#  include <WinSDKVer.h>
#  include <SDKDDKVer.h>
# endif
#endif
