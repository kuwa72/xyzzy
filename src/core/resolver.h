#ifndef _resolver_h_
#define _resolver_h_

#ifdef _WIN32
#include <winsock.h>

class resolver
{
protected:
  struct params
    {
      int done;
      WPARAM wparam;
      LPARAM lparam;
    };

  HWND r_hwnd;
  HANDLE r_hsock;
  DWORD r_thread_id;
  int r_timeout;
  params r_params;
  char r_buf[MAXGETHOSTSTRUCT];

  static int r_initialized;

  LRESULT wndproc (UINT, WPARAM, LPARAM);
  static LRESULT CALLBACK wndproc (HWND, UINT, WPARAM, LPARAM);

  int wait (HANDLE);
  void post_result (WPARAM, LPARAM);
  void post_bad_result (int e)
    {post_result (0, WSAMAKEASYNCREPLY (0, e));}

  enum
    {
      wm_asyncsock = WM_USER + 5,
      wm_asyncsockreq,
      wm_cancel_asyncsock,
      wm_result_asyncsock
    };

public:
  resolver (int = 60000);
  ~resolver ();

  void cancel () {post_bad_result (WSAEINTR);}
  static int initialize (HINSTANCE);
  int create (HINSTANCE);

  hostent *lookup_host (const char *);
  hostent *lookup_host (const void *, int, int);
  servent *lookup_serv (const char *, const char *);
};

#else // !_WIN32

// Linux stub - uses synchronous resolution
class resolver
{
public:
  resolver (int = 60000) {}
  ~resolver () {}

  void cancel () {}

  hostent *lookup_host (const char *name) { return gethostbyname(name); }
  hostent *lookup_host (const void *addr, int len, int type) { return gethostbyaddr((const char*)addr, len, type); }
  servent *lookup_serv (const char *name, const char *proto) { return getservbyname(name, proto); }
};

#endif // _WIN32

#endif /* _resolver_h_ */
