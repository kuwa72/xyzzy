#ifndef _appid_h_
# define _appid_h_

#include <shobjidl.h>

typedef HRESULT (WINAPI *SETAPPID)(PCWSTR AppID);

class appid
{
public:
  static void set ();
};

#endif
