#include "stdafx.h"
#ifdef __XYZZY__
#include "ed.h"
#endif
#include "sockinet.h"
#include "sockimpl.h"

const char *
sockinet::ntoa (in_addr in)
{
  const char *a = WS_CALL (inet_ntoa)(in);
  if (!a)
    throw sock_error ("inet_ntoa");
  return a;
}

sockinet::saddr::saddr ()
{
  sin_family = af_inet;
  sin_addr.s_addr = WS_CALL (htonl)(INADDR_ANY);
  sin_port = 0;
}

sockinet::saddr::saddr (const saddr &src)
{
  sin_family = src.sin_family;
  sin_addr.s_addr = src.sin_addr.s_addr;
  sin_port = src.sin_port;
}

sockinet::saddr::saddr (u_long addr, u_short port)
{
  sin_family = af_inet;
  sin_addr.s_addr = WS_CALL (htonl)(addr);
  sin_port = WS_CALL (htons)(port);
}

sockinet::saddr::saddr (u_long addr, const char *service, const char *proto)
{
  sin_family = af_inet;
  sin_addr.s_addr = WS_CALL (htonl)(addr);
  set_port (service, proto);
}

sockinet::saddr::saddr (const char *hostname, u_short port)
{
  sin_family = af_inet;
  set_addr (hostname);
  sin_port = WS_CALL (htons)(port);
}

sockinet::saddr::saddr (const char *hostname, const char *service, const char *proto)
{
  sin_family = af_inet;
  set_addr (hostname);
  set_port (service, proto);
}

#ifdef __XYZZY__
sockinet::saddr::saddr (lisp hostname, lisp port)
{
  sin_family = af_inet;
  set_addr (hostname);
  set_port (port);
}
#endif /* __XYZZY__ */

void
sockinet::saddr::set_addr (u_long addr)
{
  sin_addr.s_addr = WS_CALL (htonl)(addr);
}

void
sockinet::saddr::set_addr (const char *hostname)
{
  sin_addr.s_addr = WS_CALL (inet_addr)(hostname);
  if (sin_addr.s_addr == INADDR_NONE)
    {
      hostent *e = netdb::host (hostname);
      if (!e)
        /* **`h_errno` を DNS_ERROR で運ぶ。** `sock_error (ope)` の 1 引数
           版は `WSAGetLastError ()` = errno を読むが、`gethostbyname` は
           errno を触らないので**「Success」と出ていた** (issue #223)。 */
        throw sock_error ("gethostbyname", h_errno, DNS_ERROR);
      sin_family = e->h_addrtype;
      memcpy (&sin_addr, e->h_addr, e->h_length);
    }
}

void
sockinet::saddr::set_port (u_short port)
{
  sin_port = WS_CALL (htons)(port);
}

void
sockinet::saddr::set_port (const char *service, const char *proto)
{
  int n = atoi (service);
  if (n)
    sin_port = WS_CALL (htons)(n);
  else
    {
      servent *sv = netdb::serv (service, proto);
      if (!sv)
        throw sock_error ("getservbyname");
      sin_port = sv->s_port;
    }
}

#ifdef __XYZZY__
void
sockinet::saddr::set_addr (lisp lhost)
{
  long x;
  if (!lhost || lhost == Qnil)
    set_addr ((u_long)INADDR_ANY);
  else if (safe_fixnum_value (lhost, &x))
    set_addr ((u_long)x);
  else if (stringp (lhost))
    {
      /* **POSIX の名前解決は UTF-8 のバイト列を取る。** `w2s` は CP932 に
         するので、非 ASCII のホスト名が解決できなかった (issue #258):
         `/etc/hosts` に UTF-8 で置いた「日本.test」を引くと
         `gethostbyname: Host not found` になる (ASCII の名前は引ける)。
         `src/core/environ.cc` の環境変数と同じ形で分ける。

         **コマンドラインから渡すと通ってしまう**ので、そういう測り方では
         見つからない: 引数のバイト列を CP932 として読んだ文字列を `w2s` が
         CP932 へ戻すため、2 つの誤りが打ち消し合う。測るときは
         `(code-char #x65e5)` のようにコードポイントから名前を組む。 */
#ifdef _WIN32
      char *host = (char *)alloca (xstring_length (lhost) * 2 + 1);
      w2s (host, lhost);
#else
      char *host = (char *)alloca (i2u8l (xstring_contents (lhost),
                                          xstring_length (lhost)));
      i2u8 (xstring_contents (lhost), xstring_length (lhost), host);
#endif
      set_addr (host);
    }
  else
    FEtype_error (lhost, xsymbol_value (Qor_string_integer));
}

void
sockinet::saddr::set_port (lisp lport)
{
  long x;
  if (!lport || lport == Qnil)
    set_port (u_short (0));
  else if (safe_fixnum_value (lport, &x))
    set_port (u_short (x));
  else if (stringp (lport))
    {
      /* サービス名も同じ (`getservbyname`)。**`/etc/services` は UTF-8。** */
#ifdef _WIN32
      char *port = (char *)alloca (xstring_length (lport) * 2 + 1);
      w2s (port, lport);
#else
      char *port = (char *)alloca (i2u8l (xstring_contents (lport),
                                          xstring_length (lport)));
      i2u8 (xstring_contents (lport), xstring_length (lport), port);
#endif
      set_port (port, "tcp");
    }
  else
    FEtype_error (lport, xsymbol_value (Qor_string_integer));
}
#endif /* __XYZZY__ */

const char *
sockinet::saddr::hostname () const
{
  if (sin_addr.s_addr == WS_CALL (htonl)(INADDR_NONE)
      || sin_addr.s_addr == WS_CALL (htonl)(INADDR_ANY))
    return 0;
  hostent *hp = netdb::host (&sin_addr, sizeof sin_addr, sin_family);
  return hp ? hp->h_name : 0;
}
