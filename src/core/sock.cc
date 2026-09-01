#include "stdafx.h"
#ifdef __XYZZY__
#include "ed.h"
#undef CONCAT
#undef _CONCAT
#undef __CONCAT
#undef TOSTR
#undef _TOSTR
#endif
#include "sock.h"
#include "resolver.h"
#include "sockimpl.h"

resolver sock::s_resolver;

#define __CONCAT(X, Y) X ## Y
#define _CONCAT(X, Y) __CONCAT (X, Y)
#define CONCAT(X, Y) _CONCAT (X, Y)
#define _TOSTR(X) #X
#define TOSTR(X) _TOSTR (X)

/* 何もせず失敗を返す実装。`WSOCKDEF` の第 4 引数がその失敗値である
   (`INVALID_SOCKET` / `SOCKET_ERROR` / `WSASYSNOTREADY`)。 */
#define WSOCKDEF(TYPE, NAME, ARGS, RESULT) \
  static TYPE WINAPI CONCAT (dummy_, NAME) ARGS {return RESULT;}
  WINSOCK_FUNCTIONS
#undef WSOCKDEF

/* **表は最初から埋めておく。null にしない** (issue #223)。

   `WS_CALL (FN)` は `(*WINSOCK::FN)(...)` で、**null なら関数ポインタの
   null 呼び出し = SIGSEGV になる。** 実際に POSIX がその状態だった:
   表を埋める `init_winsock_functions` を呼ぶのは `sock::init_winsock` の
   `#ifdef _WIN32` 側だけで、しかも `sock::init_winsock` 自体を呼ぶのは
   `src/frontend/win32/init.cc` の 1 か所だけだったので、**POSIX では
   一度も埋まらないまま `(connect ...)` が呼べた。** `handler-case` でも
   捕まらないので、対話中に呼べば未保存のバッファごとプロセスが消えた。

   ここで dummy を入れておけば、**呼ばれる順序に関係なく最悪でも「正直な
   失敗」**になる。Win32 では `init_winsock_functions` が本物で上書きする。
   その関数を呼び忘れても落ちなくなるので、Win32 側にとっても安全側である。 */
#define WSOCKDEF(TYPE, NAME, ARGS, RESULT) \
  TYPE (WINAPI *WINSOCK::NAME) ARGS = CONCAT (dummy_, NAME);
  WINSOCK_FUNCTIONS
#undef WSOCKDEF

static FARPROC
get_wsock_fn (HINSTANCE h, const char *name, FARPROC dummy)
{
  if (!h)
    return dummy;
  FARPROC fn = GetProcAddress (h, name);
  return fn ? fn : dummy;
}

static void
init_winsock_functions ()
{
  HINSTANCE h = LoadLibraryW (L"WSOCK32.DLL");
#define WSOCKDEF(TYPE, NAME, ARGS, RESULT) \
  WINSOCK::NAME = \
    (TYPE (WINAPI *) ARGS)get_wsock_fn (h, TOSTR (NAME), \
                                        FARPROC (CONCAT (dummy_, NAME)));
  WINSOCK_FUNCTIONS
#undef WSOCKDEF
}

#ifdef __XYZZY__
static int WINAPI
blocking_hook ()
{
  Fdo_events ();
  if (QUITP)
    WS_CALL (WSACancelBlockingCall)();
  return 0;
}
#endif

sock_error::sock_error (const char *ope)
     : e_error (WS_CALL (WSAGetLastError)()), e_ope (ope)
{
}

const char *
sock::errmsg (int e)
{
  static const struct {int e; const char *s;} msg[] =
    {
      {WSAEINTR,           "Interrupted system call"},
      {WSAEBADF,           "Bad file descriptor"},
      {WSAEACCES,          "Permission denied"},
      {WSAEFAULT,          "Bad address"},
      {WSAEINVAL,          "Invalid argument"},
      {WSAEMFILE,          "Too many open files"},
      {WSAEWOULDBLOCK,     "Resource temporarily unavailable"},
      {WSAEINPROGRESS,     "Operation now in progress"},
      {WSAEALREADY,        "Operation already in progress"},
      {WSAENOTSOCK,        "Socket operation on non-socket"},
      {WSAEDESTADDRREQ,    "Destination address required"},
      {WSAEMSGSIZE,        "Message too long"},
      {WSAEPROTOTYPE,      "Protocol wrong type for socket"},
      {WSAENOPROTOOPT,     "Protocol not available"},
      {WSAEPROTONOSUPPORT, "Protocol not supported"},
      {WSAESOCKTNOSUPPORT, "Socket type not supported"},
      {WSAEOPNOTSUPP,      "Operation not supported"},
      {WSAEPFNOSUPPORT,    "Protocol family not supported"},
      {WSAEAFNOSUPPORT,    "Address family not supported by protocol family"},
      {WSAEADDRINUSE,      "Address already in use"},
      {WSAEADDRNOTAVAIL,   "Can't assign requested address"},
      {WSAENETDOWN,        "Network is down"},
      {WSAENETUNREACH,     "Network is unreachable"},
      {WSAENETRESET,       "Network dropped connection on reset"},
      {WSAECONNABORTED,    "Software caused connection abort"},
      {WSAECONNRESET,      "Connection reset by peer"},
      {WSAENOBUFS,         "No buffer space available"},
      {WSAEISCONN,         "Socket is already connected"},
      {WSAENOTCONN,        "Socket is not connected"},
      {WSAESHUTDOWN,       "Can't send after socket shutdown"},
      {WSAETOOMANYREFS,    "Too many references: can't splice"},
      {WSAETIMEDOUT,       "Operation timed out"},
      {WSAECONNREFUSED,    "Connection refused"},
      {WSAELOOP,           "Too many levels of symbolic links"},
      {WSAENAMETOOLONG,    "File name too long"},
      {WSAEHOSTDOWN,       "Host is down"},
      {WSAEHOSTUNREACH,    "No route to host"},
      {WSAENOTEMPTY,       "Directory not empty"},
      {WSAEPROCLIM,        "Too many processes"},
      {WSAEUSERS,          "Too many users"},
      {WSAEDQUOT,          "Disc quota exceeded"},
      {WSAESTALE,          "Stale NFS file handle"},
      {WSAEREMOTE,         "Too many levels of remote in path"},
      {WSASYSNOTREADY,     "The network subsystem is unusable"},
      {WSAVERNOTSUPPORTED, "The Windows Sockets DLL cannot support this app"},
      {WSANOTINITIALISED,  "A successful WSAStartup, has not yet been performed"},
      {WSAEDISCON,         "The message terminated gracefully"},
      {WSAHOST_NOT_FOUND,  "Authoritative Answer; Host not found"},
      {WSATRY_AGAIN,       "Non-Authoritative; Host not found, or SERVERFAIL"},
      {WSANO_RECOVERY,     "Non recoverable errors, FORMERR, REFUSED, NOTIMP"},
      {WSANO_DATA,         "Valid name, no data record of requested type"},
    };
  if (e < WSABASEERR || e > WSANO_DATA)
    return 0;
  for (int i = 0; i < numberof (msg); i++)
    if (e == msg[i].e)
      return msg[i].s;
  return 0;
}

#ifdef _WIN32
int
sock::init_winsock (HINSTANCE hinst)
{
  init_winsock_functions ();

  WSADATA data;
  int e = WS_CALL (WSAStartup)(MAKEWORD (1, 1), &data);
  if (e)
    return 0;

#ifdef __XYZZY__
  WS_CALL (WSASetBlockingHook)((FARPROC)blocking_hook);
#endif

  if (!s_resolver.initialize (hinst)
      || !s_resolver.create (hinst))
    return 0;
  return 1;
}

void
sock::term_winsock ()
{
  WS_CALL (WSACleanup)();
}
#else /* !_WIN32 */

/* **BSD ソケットを表に入れる** (issue #223 の段取り 2)。

   `WSOCKDEF` の並びは Winsock で、BSD とほぼ 1:1 だが**型がずれる**ので
   そのままアドレスを取って代入できない。ずれるのは主に 3 つ:

     * 長さの引数が `int *` (Winsock) と `socklen_t *` (BSD)
     * バッファが `char *` (Winsock) と `void *` (BSD)
     * `send` / `recv` の戻りが `int` (Winsock) と `ssize_t` (BSD)

   さらに `htons` などは Linux では**マクロ**なのでアドレスが取れない。
   なので薄いアダプタを並べる。**使われていないものは dummy のままにする** —
   埋めた分だけが「動く」と主張していることになる。

   `SOCKET` は `int`、`INVALID_SOCKET` と `SOCKET_ERROR` は -1 で BSD と同じ
   (src/core/platform.h)。 */

/* `select` の第 1 引数。**Winsock はここを無視するので core は `1` を渡して
   いる** (`sock::readablep` / `writablep`)。POSIX では「最大の fd + 1」で
   なければならず、**`1` を渡すと fd 1 以外を一切見ない** = 常に 0 が返る。
   呼び出し側を直すのではなくここで数える: 表の裏に隠す差は表の裏で閉じる。 */
static int
posix_select_nfds (fd_set *a, fd_set *b, fd_set *c)
{
  fd_set *sets[3];
  sets[0] = a; sets[1] = b; sets[2] = c;
  int n = 0;
  for (int i = 0; i < 3; i++)
    if (sets[i])
      for (int fd = 0; fd < FD_SETSIZE; fd++)
        if (FD_ISSET (fd, sets[i]) && fd + 1 > n)
          n = fd + 1;
  return n;
}

static int WINAPI
posix_select (int, fd_set *r, fd_set *w, fd_set *e, const struct timeval *tv)
{
  struct timeval t;
  if (tv)
    t = *tv;
  return ::select (posix_select_nfds (r, w, e), r, w, e, tv ? &t : 0);
}

/* **ブロッキングするたびに `do-events` を回す。**

   Win32 は `WSASetBlockingHook` で、ブロッキング中に Winsock 側から
   `blocking_hook` を呼び返してもらって `Fdo_events` を回す。POSIX にその
   仕組みは無いので、**そのまま `::accept` / `::recv` / `::send` を呼ぶと
   エディタが固まって C-g も効かない。**

   既定のタイムアウトは -1 (無限) で、`sock::send` / `recv` の
   `writablep` / `readablep` の門は `s_wtimeo.tv_sec >= 0` でしか通らない
   から、**既定では core 側に一切の待ちが無い。** ここで受ける。

   0 = 使える / -1 = 中断かエラー (errno を立てる)。 */
static int
posix_wait_ready (SOCKET s, int for_write)
{
  for (;;)
    {
      fd_set fds;
      FD_ZERO (&fds);
      FD_SET (s, &fds);
      struct timeval tv;
      tv.tv_sec = 0;
      tv.tv_usec = 100000;
      int n = ::select (s + 1, for_write ? 0 : &fds, for_write ? &fds : 0,
                        0, &tv);
      if (n > 0)
        return 0;
      if (n < 0 && errno != EINTR)
        return -1;
#ifdef __XYZZY__
      Fdo_events ();
      if (QUITP)
        {
          errno = EINTR;
          return -1;
        }
#endif
    }
}

static SOCKET WINAPI
posix_socket (int domain, int type, int proto)
{
  return ::socket (domain, type, proto);
}

static int WINAPI
posix_closesocket (SOCKET s)
{
  return ::close (s);
}

static int WINAPI
posix_bind (SOCKET s, const struct sockaddr *a, int l)
{
  return ::bind (s, a, socklen_t (l));
}

static int WINAPI
posix_listen (SOCKET s, int backlog)
{
  return ::listen (s, backlog);
}

static SOCKET WINAPI
posix_accept (SOCKET s, struct sockaddr *a, int *l)
{
  if (posix_wait_ready (s, 0) < 0)
    return INVALID_SOCKET;
  socklen_t n = l ? socklen_t (*l) : 0;
  SOCKET r = ::accept (s, a, l ? &n : 0);
  if (l)
    *l = int (n);
  return r;
}

static int WINAPI
posix_shutdown (SOCKET s, int how)
{
  return ::shutdown (s, how);
}

static int WINAPI
posix_getpeername (SOCKET s, struct sockaddr *a, int *l)
{
  socklen_t n = l ? socklen_t (*l) : 0;
  int r = ::getpeername (s, a, l ? &n : 0);
  if (l)
    *l = int (n);
  return r;
}

static int WINAPI
posix_getsockname (SOCKET s, struct sockaddr *a, int *l)
{
  socklen_t n = l ? socklen_t (*l) : 0;
  int r = ::getsockname (s, a, l ? &n : 0);
  if (l)
    *l = int (n);
  return r;
}

static int WINAPI
posix_getsockopt (SOCKET s, int level, int name, char *val, int *l)
{
  socklen_t n = l ? socklen_t (*l) : 0;
  int r = ::getsockopt (s, level, name, val, l ? &n : 0);
  if (l)
    *l = int (n);
  return r;
}

static int WINAPI
posix_setsockopt (SOCKET s, int level, int name, const char *val, int l)
{
  return ::setsockopt (s, level, name, val, socklen_t (l));
}

static int WINAPI
posix_send (SOCKET s, const char *b, int l, int flags)
{
  if (posix_wait_ready (s, 1) < 0)
    return SOCKET_ERROR;
  return int (::send (s, b, size_t (l), flags));
}

static int WINAPI
posix_recv (SOCKET s, char *b, int l, int flags)
{
  if (posix_wait_ready (s, 0) < 0)
    return SOCKET_ERROR;
  return int (::recv (s, b, size_t (l), flags));
}

static int WINAPI
posix_sendto (SOCKET s, const char *b, int l, int flags,
              const struct sockaddr *to, int tolen)
{
  if (posix_wait_ready (s, 1) < 0)
    return SOCKET_ERROR;
  return int (::sendto (s, b, size_t (l), flags, to, socklen_t (tolen)));
}

static int WINAPI
posix_recvfrom (SOCKET s, char *b, int l, int flags,
                struct sockaddr *from, int *fromlen)
{
  if (posix_wait_ready (s, 0) < 0)
    return SOCKET_ERROR;
  socklen_t n = fromlen ? socklen_t (*fromlen) : 0;
  int r = int (::recvfrom (s, b, size_t (l), flags, from,
                           fromlen ? &n : 0));
  if (fromlen)
    *fromlen = int (n);
  return r;
}

/* **`ioctlsocket` と `gethostname` は dummy のままにする。**
   `sock::ioctl` には呼び出し元が 1 つも無く (`WS_CALL (ioctlsocket)` は
   `sock::ioctl` の中だけ)、`gethostname` は `WS_CALL` がどこにも無い。
   **到達しないものにアダプタを書くと、動くと主張したことになる** ので
   書かない。使うようになったときに書く。 */

/* `htons` などは Linux ではマクロなのでアドレスが取れない。包む。 */
static u_long WINAPI posix_htonl (u_long x) {return htonl (x);}
static u_short WINAPI posix_htons (u_short x) {return htons (x);}
static u_long WINAPI posix_ntohl (u_long x) {return ntohl (x);}
static u_short WINAPI posix_ntohs (u_short x) {return ntohs (x);}

static unsigned long WINAPI posix_inet_addr (const char *s) {return ::inet_addr (s);}
static char * WINAPI posix_inet_ntoa (struct in_addr a) {return ::inet_ntoa (a);}

/* **エラー番号は errno そのもの。** `platform.h` が `WSAE*` を errno の
   別名として define しているので、番号の空間が一致する。 */
static int WINAPI posix_WSAGetLastError () {return errno;}
static void WINAPI posix_WSASetLastError (int e) {errno = e;}

/* Winsock の初期化・終了に相当するものは無い。**成功を返して良い** --
   実際に何もする必要がないので嘘ではない。 */
static int WINAPI
posix_WSAStartup (WORD, LPWSADATA data)
{
  if (data)
    memset (data, 0, sizeof *data);
  return 0;
}

static int WINAPI posix_WSACleanup () {return 0;}

/* **`connect` は非ブロッキングにして待つ。**

   Win32 は `WSASetBlockingHook` で、ブロッキング中に Winsock 側から
   `blocking_hook` を呼び返してもらい `Fdo_events` を回す。POSIX にその
   仕組みは無いので、**そのまま `::connect` を呼ぶと届かない相手に対して
   エディタが 2 分ほど固まって C-g も効かない。** 非ブロッキングにして
   `select` で刻みながら待ち、その隙間で同じことをする。

   終わったら元のフラグに戻す。`sock` は後で `ioctlsocket (FIONBIO)` を
   自分で使うので、ここが勝手に非ブロッキングを残してはいけない。 */
static int WINAPI
posix_connect (SOCKET s, const struct sockaddr *a, int l)
{
  int fl = ::fcntl (s, F_GETFL);
  if (fl < 0)
    return ::connect (s, a, socklen_t (l));

  ::fcntl (s, F_SETFL, fl | O_NONBLOCK);
  int r = ::connect (s, a, socklen_t (l));
  if (r == 0 || errno != EINPROGRESS)
    {
      int e = errno;
      ::fcntl (s, F_SETFL, fl);
      errno = e;
      return r;
    }

  if (posix_wait_ready (s, 1) < 0)
    {
      int e = errno;
      ::fcntl (s, F_SETFL, fl);
      errno = e;
      return -1;
    }

  int err = 0;
  socklen_t el = sizeof err;
  if (::getsockopt (s, SOL_SOCKET, SO_ERROR, &err, &el) < 0)
    err = errno;
  ::fcntl (s, F_SETFL, fl);
  if (err)
    {
      errno = err;
      return -1;
    }
  return 0;
}

/* 表に実体を入れる。**埋めた分だけが「動く」と主張していることになる** ので、
   使われていないもの (`WSAAsyncGet*` の名前解決、`WSASetBlockingHook` などの
   Win16 の遺物) は dummy のままにしてある。名前解決は issue #223 の段取り 3。 */
static void
init_posix_socket_functions ()
{
#define SET(NAME) WINSOCK::NAME = posix_##NAME
  SET (socket); SET (closesocket); SET (bind); SET (listen); SET (accept);
  SET (connect); SET (shutdown); SET (select);
  SET (getpeername); SET (getsockname); SET (getsockopt); SET (setsockopt);
  SET (send); SET (recv); SET (sendto); SET (recvfrom);
  SET (htonl); SET (htons); SET (ntohl); SET (ntohs);
  SET (inet_addr); SET (inet_ntoa);
  SET (WSAGetLastError); SET (WSASetLastError);
  SET (WSAStartup); SET (WSACleanup);
#undef SET
}

/* **フロントエンドの呼び出しを待たない。**

   `sock::init_winsock` を呼ぶのは Win32 のフロントエンドだけで、POSIX 側は
   呼んでいなかった。それが段取り 1 のバグ (表が null のまま = SIGSEGV) の
   原因である。**「どこかから呼ばれる」に頼る形をもう一度作らない。**

   ここは同じ翻訳単位のファイルスコープ初期化で、表そのものは関数の
   アドレス (定数式) で初期化されているので**動的初期化より前に確定して
   いる**。つまり順序の心配が無い。

   `sock::init_winsock` からも呼ぶ (下)。何度呼んでも同じなので、Win32 と
   読み比べたときに経路が消えていない方が分かりやすい。 */
static const int posix_socket_table_installed
  = (init_posix_socket_functions (), 1);

int
sock::init_winsock (HINSTANCE)
{
  init_posix_socket_functions ();
  return 1;
}

void
sock::term_winsock ()
{
}
#endif

void
sock::initsock (SOCKET so)
{
  s_so = so;
  s_rtimeo.tv_sec = s_wtimeo.tv_sec = -1;
  s_eof_error_p = 1;
  s_rbuf.b_ptr = s_rbuf.b_base;
  s_rbuf.b_cnt = 0;
  s_wbuf.b_ptr = s_wbuf.b_base;
  s_wbuf.b_cnt = 0;
}

void
sock::closesock (int no_throw)
{
  SOCKET so = s_so;
  initsock (INVALID_SOCKET);
  if (WS_CALL (closesocket)(so) < 0 && !no_throw)
    throw sock_error ("closesocket");
}

void
sock::close_socket (SOCKET s)
{
  WS_CALL (closesocket)(s);
}

sock::sock ()
{
  initsock (INVALID_SOCKET);
}

sock::sock (SOCKET so)
{
  initsock (so);
}

sock::~sock ()
{
  if (s_so != INVALID_SOCKET)
    {
      try {sflush ();} catch (sock_error &) {}
      shutdown (1, 1);
      closesock (1);
    }
}

void
sock::create (int domain, sock_type type, int proto)
{
  s_so = WS_CALL (socket)(domain, type, proto);
  if (s_so == INVALID_SOCKET)
    throw sock_error ("socket");
}

void
sock::close (int abort)
{
  if (s_so != INVALID_SOCKET)
    {
      if (!abort)
        {
          try
            {
              sflush ();
            }
          catch (sock_error &)
            {
              shutdown (1, 1);
              closesock (1);
              throw;
            }
        }
      shutdown (1, abort);
      closesock (abort);
    }
}

void
sock::shutdown (int how, int no_throw)
{
  if (WS_CALL (shutdown)(s_so, how) < 0 && !no_throw)
    {
      int e = WS_CALL (WSAGetLastError) ();
      if (e != WSAENOTCONN)
        throw sock_error ("shutdown", e);
    }
}

void
sock::cancel ()
{
  WS_CALL (WSACancelBlockingCall)();
}

int
sock::readablep (const timeval &tv) const
{
  fd_set fds;
  FD_ZERO (&fds);
  FD_SET (s_so, &fds);

  int n = WS_CALL (select)(1, &fds, 0, 0, &tv);
  if (n < 0)
    {
      int e = WS_CALL (WSAGetLastError)();
      if (!s_eof_error_p && e == WSAECONNRESET)
        return 1;
      throw sock_error ("select", e);
    }
  return n;
}

int
sock::writablep (const timeval &tv) const
{
  fd_set fds;
  FD_ZERO (&fds);
  FD_SET (s_so, &fds);

  int n = WS_CALL (select)(1, 0, &fds, 0, &tv);
  if (n < 0)
    throw sock_error ("select");
  return n;
}

void
sock::send (const void *buf, int len, int flags) const
{
  for (const char *b = (const char *)buf, *be = b + len; b < be;)
    {
      if (s_wtimeo.tv_sec >= 0 && !writablep (s_wtimeo))
        throw sock_error ("sock::send", WSAETIMEDOUT);
      int n = WS_CALL (send)(s_so, b, min ((int)(be - b), 65535), flags);
      if (n <= 0)
        throw sock_error ("send", n ? WS_CALL (WSAGetLastError)() : WSAECONNRESET);
      b += n;
    }
}

void
sock::sendto (const saddr &to, const void *buf, int len, int flags) const
{
  for (const char *b = (const char *)buf, *be = b + len; b < be;)
    {
      if (s_wtimeo.tv_sec >= 0 && !writablep (s_wtimeo))
        throw sock_error ("sock::sendto", WSAETIMEDOUT);
      int n = WS_CALL (sendto)(s_so, b, min ((int)(be - b), 65535), flags,
                               to.addr (), to.length ());
      if (n <= 0)
        throw sock_error ("sendto", n ? WS_CALL (WSAGetLastError)() : WSAECONNRESET);
      b += n;
    }
}

int
sock::recv (void *buf, int len, int flags) const
{
  if (s_rtimeo.tv_sec >= 0 && !readablep (s_rtimeo))
    throw sock_error ("sock::recv", WSAETIMEDOUT);
  int n = WS_CALL (recv)(s_so, (char *)buf, min (len, 65535), flags);
  if (n <= 0)
    {
      int e = n ? WS_CALL (WSAGetLastError)() : WSAECONNRESET;
      if (!s_eof_error_p && e == WSAECONNRESET)
        return 0;
      throw sock_error ("recv", e);
    }
  return n;
}

int
sock::recvfrom (saddr &from, void *buf, int len, int flags) const
{
  if (s_rtimeo.tv_sec >= 0 && !readablep (s_rtimeo))
    throw sock_error ("sock::recvfrom", WSAETIMEDOUT);
  int l = from.length ();
  int n = WS_CALL (recvfrom)(s_so, (char *)buf, min (len, 65535), flags,
                             from.addr (), &l);
  if (n <= 0)
    throw sock_error ("recvfrom", n ? WS_CALL (WSAGetLastError)() : WSAECONNRESET);
  return n;
}

void
sock::listen (int backlog) const
{
  if (WS_CALL (listen)(s_so, backlog) < 0)
    throw sock_error ("listen");
}

SOCKET
sock::accept (saddr &addr) const
{
  int l = addr.length ();
  SOCKET so = WS_CALL (accept)(s_so, addr.addr (), &l);
  if (so == INVALID_SOCKET)
    throw sock_error ("accept");
  return so;
}

SOCKET
sock::accept () const
{
  SOCKET so = WS_CALL (accept)(s_so, 0, 0);
  if (so == INVALID_SOCKET)
    throw sock_error ("accept");
  return so;
}

void
sock::bind (const saddr &addr) const
{
  if (WS_CALL (bind)(s_so, addr.addr (), addr.length ()) < 0)
    throw sock_error ("bind");
}

void
sock::connect (const saddr &addr) const
{
  if (WS_CALL (connect)(s_so, addr.addr (), addr.length ()) < 0)
    throw sock_error ("connect");
}

void
sock::peeraddr (saddr &addr) const
{
  int l = addr.length ();
  if (WS_CALL (getpeername)(s_so, addr.addr (), &l) < 0)
    throw sock_error ("getpeername");
}

void
sock::localaddr (saddr &addr) const
{
  int l = addr.length ();
  if (WS_CALL (getsockname)(s_so, addr.addr (), &l) < 0)
    throw sock_error ("getsockname");
}

void
sock::getopt (int level, optname opt, void *val, int l) const
{
  if (WS_CALL (getsockopt)(s_so, level, opt, (char *)val, &l) < 0)
    throw sock_error ("getsockopt");
}

void
sock::setopt (int level, optname opt, const void *val, int l) const
{
  if (WS_CALL (setsockopt)(s_so, level, opt, (const char *)val, l) < 0)
    throw sock_error ("setsockopt");
}

void
sock::ioctl (int cmd, u_long *arg) const
{
  if (WS_CALL (ioctlsocket)(s_so, cmd, arg) < 0)
    throw sock_error ("ioctl");
}

#ifdef _WIN32
u_short
sock::htons (u_short x)
{
  return WS_CALL (htons)(x);
}

u_long
sock::htonl (u_long x)
{
  return WS_CALL (htonl)(x);
}

u_short
sock::ntohs (u_short x)
{
  return WS_CALL (ntohs)(x);
}

u_long
sock::ntohl (u_long x)
{
  return WS_CALL (ntohl)(x);
}
#endif

void
sock::sflush ()
{
  if (s_wbuf.b_ptr > s_wbuf.b_base)
    send (s_wbuf.b_base, s_wbuf.b_ptr - s_wbuf.b_base);
  s_wbuf.b_ptr = s_wbuf.b_base;
  s_wbuf.b_cnt = 0;
}

void
sock::sflush_buf (int c)
{
  sflush ();
  s_wbuf.b_ptr = s_wbuf.b_base + 1;
  s_wbuf.b_cnt = SOCKBUFSIZ - 1;
  *s_wbuf.b_base = c;
}

int
sock::srefill ()
{
  sflush ();
  s_rbuf.b_ptr = s_rbuf.b_base;
  s_rbuf.b_cnt = 0;
  int nread = recv (s_rbuf.b_base, SOCKBUFSIZ);
  if (!nread)
    return eof;
  s_rbuf.b_ptr = s_rbuf.b_base + 1;
  s_rbuf.b_cnt = nread - 1;
  return *s_rbuf.b_base & 0xff;
}

void
sock::sputs (const char *s)
{
  for (; *s; s++)
    sputc (*s);
}

int
sock::sgets (char *buf, size_t size)
{
  if (int (size) <= 0)
    return 0;
  char *b = buf;
  char *const be = buf + size - 1;
  while (b < be)
    {
      int c = sgetc ();
      if (c == eof)
        break;
      *b++ = c;
      if (c == '\n')
        break;
    }
  *b = 0;
  return b - buf;
}

void
sock::sungetc (int c)
{
  if (c >= 0 && s_rbuf.b_ptr > s_rbuf.b_base)
    {
      *--s_rbuf.b_ptr = (char)c;
      s_rbuf.b_cnt++;
    }
}

hostent *
sock::netdb::host (const char *hostname)
{
  return s_resolver.lookup_host (hostname);
}

hostent *
sock::netdb::host (const void *addr, int addrlen, int type)
{
  return s_resolver.lookup_host (addr, addrlen, type);
}

servent *
sock::netdb::serv (const char *service, const char *proto)
{
  return s_resolver.lookup_serv (service, proto);
}
