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

#include <netdb.h>

/* **worker スレッドで引く** (issue #223)。中身は
   `src/core/resolver-posix.cc`。

   以前はここで `gethostbyname` を直に呼んでいた。**引けてはいたが、遅い DNS で
   エディタが数秒固まり、C-g でも戻れなかった** -- あの呼びには
   `poll_quit_char` を挟む隙が無い。

   **結果の寿命は Win32 と同じ約束**である: `lookup_host` が返す `hostent` は
   このオブジェクトのメンバを指し、**次の lookup まで有効。**
   `sockinet::saddr::hostname ()` が `h_name` をそのまま返すので、この約束が
   要る。 */
class resolver
{
public:
  struct job;                   // resolver-posix.cc の中だけで使う

private:
  int r_timeout;                // ms。0 以下なら待ち続ける
  /* 結果。**次の lookup まで有効** (Win32 の r_buf と同じ)。 */
  hostent r_hostent;
  char r_name[NI_MAXHOST];
  char *r_addr_list[2];
  unsigned char r_addr[16];

  job *wait_for_job (job *);

public:
  resolver (int = 60000);
  ~resolver ();

  void cancel ();

  hostent *lookup_host (const char *);
  hostent *lookup_host (const void *, int, int);
  servent *lookup_serv (const char *, const char *);
};

#endif // _WIN32

#endif /* _resolver_h_ */
