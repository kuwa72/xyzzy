/* POSIX の名前解決 (issue #223)。**worker スレッドで引いて、main は 100ms
   刻みで C-g を見ながら待つ。**

   ## 直前の状態

   `resolver.h` の非 Win32 側は `gethostbyname` を直に呼ぶだけだった。
   **引けてはいたが、遅い DNS でエディタが数秒固まり、C-g でも戻れなかった。**
   `gethostbyname` には `poll_quit_char` を挟む隙が無い。

   ## なぜ worker スレッドか

   **fd が無いブロッキング呼び出し**なので、既にある「fd を主 `select` に
   入れる」形 (サブプロセス) には乗らない。子プロセスで引く案もあるが、

     * Lisp ヒープごと `fork` するのは名前解決 1 回には重い
     * **tree-sitter が既にスレッドを使っているので、multi-threaded な
       プロセスからの `fork` になる。** 危ない側の組み合わせである

   スレッドなら、**worker が触るのは自分の `job` だけ**で Lisp を触らないので
   `gc_mark_in_stack` の制約 (走査するスタックは 1 本) に抵触しない。
   土台は `src/core/worker-thread.h` (tree-sitter と共有)。

   ## `gethostbyname` ではなく `getaddrinfo` を使う

   `gethostbyname` は静的な領域を返すのでスレッドから呼べない。
   `getaddrinfo` / `getnameinfo` は呼ぶ側の領域に書くので使える。

   ## 結果の寿命は Win32 と同じ約束にする

   `sockinet::saddr::hostname ()` (src/core/sockinet.cc) は
   **`hostent::h_name` をそのまま `const char *` として返す。** Win32 側は
   結果を `resolver` のメンバ (`r_buf`) に置いていて、**次の lookup まで
   有効**という約束になっている。ここも同じで、メンバに置く。

   ## job の持ち主が 2 人いる

   main が諦めた (C-g / 期限切れ) 後も、**worker はまだ `job` に書いている。**
   どちらかが勝手に解放すると use-after-free になるので、**参照数を 2 で
   始めて、後に手を離した方が解放する** (`worker_atomic_dec`)。

   読む順序も決まっている: worker は結果を書いてから最後に `done` を立て、
   main は `done` を見てから結果を読む。印は SEQ_CST なので、`done` が見えた
   時点で結果も見える。**main は諦めたときは結果を読まない。**

   ## エラーは `h_errno` に写す

   `EAI_*` をそのまま持ち回るには category を 1 つ増やすことになる
   (`src/core/error.h` の `DNS_ERROR` の隣)。**今はそこまでせず、
   `h_errno` の 4 値へ写す。** 呼ぶ側 (`sockinet.cc`) が
   `sock_error ("gethostbyname", h_errno, DNS_ERROR)` を投げる経路は
   PR #228 で作って測ってあるので、それをそのまま使う方が確かである。
   **写して落ちる情報が実務で問題になったら、そのとき category を足す。** */

#ifndef _WIN32

#include "stdafx.h"
#include "ed.h"
#include "sock.h"
#include "resolver.h"
#include "worker-thread.h"

#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>
#include <stdlib.h>

/* main と worker が共有する箱。**Lisp のものを一切置かない**
   (`malloc` で取り、`xmalloc` は使わない)。 */
struct resolver::job
{
  volatile LONG refs;           /* 2 で始め、手を離した方が減らす */
  volatile LONG done;           /* 最後に立つ: これが見えたら結果も見える */
  int reverse;                  /* 0 = 名前 -> アドレス、1 = その逆 */
  int ok;
  int err;                      /* h_errno 相当 */
  /* 入力と出力を兼ねる。forward は name が入力、reverse は addr が入力。 */
  char name[NI_MAXHOST];
  unsigned char addr[16];
  int addrlen;
  int family;
};

/* `getaddrinfo` / `getnameinfo` の失敗を `h_errno` の 4 値へ写す。
   **`EAI_*` をそのまま errno として扱ってはいけない** -- 番号の空間が違う
   (issue #212 / #223 で同じ形の嘘を直している)。 */
static int
eai_to_h_errno (int e)
{
  switch (e)
    {
    case EAI_NONAME:
#ifdef EAI_NODATA
    case EAI_NODATA:
#endif
      return HOST_NOT_FOUND;
    case EAI_AGAIN:
      return TRY_AGAIN;
    default:
      return NO_RECOVERY;
    }
}

static void
release_job (resolver::job *j)
{
  if (worker_atomic_dec (&j->refs) == 0)
    free (j);
}

static WORKER_THREAD_RET WORKER_THREAD_CALL
resolver_body (void *arg)
{
  resolver::job *j = (resolver::job *)arg;

  if (!j->reverse)
    {
      struct addrinfo hints;
      memset (&hints, 0, sizeof hints);
      hints.ai_family = AF_INET;        /* core が渡すのは IPv4 の sockaddr */
      hints.ai_socktype = SOCK_STREAM;
      struct addrinfo *res = 0;
      int e = getaddrinfo (j->name, 0, &hints, &res);
      if (e || !res)
        j->err = eai_to_h_errno (e);
      else
        {
          const struct sockaddr_in *sin = (const struct sockaddr_in *)res->ai_addr;
          j->family = AF_INET;
          j->addrlen = sizeof sin->sin_addr;
          memcpy (j->addr, &sin->sin_addr, j->addrlen);
          j->ok = 1;
        }
      if (res)
        freeaddrinfo (res);
    }
  else
    {
      struct sockaddr_in sin;
      memset (&sin, 0, sizeof sin);
      sin.sin_family = AF_INET;
      memcpy (&sin.sin_addr, j->addr, j->addrlen < int (sizeof sin.sin_addr)
                                      ? j->addrlen : int (sizeof sin.sin_addr));
      char host[NI_MAXHOST];
      int e = getnameinfo ((const struct sockaddr *)&sin, sizeof sin,
                           host, sizeof host, 0, 0, NI_NAMEREQD);
      if (e)
        j->err = eai_to_h_errno (e);
      else
        {
          strncpy (j->name, host, sizeof j->name - 1);
          j->name[sizeof j->name - 1] = 0;
          j->ok = 1;
        }
    }

  /* **結果を書いてから最後に立てる。** */
  worker_atomic_set (&j->done, 1);
  release_job (j);
  return WORKER_THREAD_DONE;
}

resolver::resolver (int timeout_ms)
     : r_timeout (timeout_ms)
{
  memset (&r_hostent, 0, sizeof r_hostent);
  r_name[0] = 0;
  r_addr_list[0] = (char *)r_addr;
  r_addr_list[1] = 0;
  memset (r_addr, 0, sizeof r_addr);
}

resolver::~resolver ()
{
}

/* worker を起こして、**100ms 刻みで C-g を見ながら**待つ。
   期限切れか C-g なら諦めて 0 を返す (`h_errno` を立てる)。 */
resolver::job *
resolver::wait_for_job (job *j)
{
  worker_thread h = worker_thread_start (resolver_body, j);
  if (!h)
    {
      /* スレッドが起きなかった。**同期で引く方へ落ちない** -- 固まる形へ
         戻ることになるので、正直に失敗を返す。 */
      release_job (j);
      h_errno = NO_RECOVERY;
      return 0;
    }

  long waited = 0;
  for (;;)
    {
      worker_thread_join (h, 100);
      if (j->done)
        {
          worker_thread_release (h);
          return j;
        }
      waited += 100;

      poll_quit_char ();
      if (QUITP)
        {
          worker_thread_release (h);   /* orphan: 本体が自分で片付ける */
          release_job (j);
          h_errno = TRY_AGAIN;
          return 0;
        }
      if (r_timeout > 0 && waited >= r_timeout)
        {
          worker_thread_release (h);
          release_job (j);
          h_errno = TRY_AGAIN;
          return 0;
        }
    }
}

hostent *
resolver::lookup_host (const char *name)
{
  if (!name)
    return 0;
  job *j = (job *)calloc (1, sizeof *j);
  if (!j)
    {
      h_errno = NO_RECOVERY;
      return 0;
    }
  j->refs = 2;
  j->reverse = 0;
  strncpy (j->name, name, sizeof j->name - 1);

  j = wait_for_job (j);
  if (!j)
    return 0;

  hostent *r = 0;
  if (j->ok)
    {
      strncpy (r_name, j->name, sizeof r_name - 1);
      r_name[sizeof r_name - 1] = 0;
      memcpy (r_addr, j->addr, sizeof r_addr);
      r_hostent.h_name = r_name;
      r_hostent.h_aliases = 0;
      r_hostent.h_addrtype = j->family;
      r_hostent.h_length = j->addrlen;
      r_hostent.h_addr_list = r_addr_list;
      r = &r_hostent;
    }
  else
    h_errno = j->err;
  release_job (j);
  return r;
}

hostent *
resolver::lookup_host (const void *addr, int len, int type)
{
  if (!addr || len <= 0 || len > int (sizeof ((job *)0)->addr))
    {
      h_errno = NO_RECOVERY;
      return 0;
    }
  job *j = (job *)calloc (1, sizeof *j);
  if (!j)
    {
      h_errno = NO_RECOVERY;
      return 0;
    }
  j->refs = 2;
  j->reverse = 1;
  j->addrlen = len;
  j->family = type;
  memcpy (j->addr, addr, len);

  j = wait_for_job (j);
  if (!j)
    return 0;

  hostent *r = 0;
  if (j->ok)
    {
      strncpy (r_name, j->name, sizeof r_name - 1);
      r_name[sizeof r_name - 1] = 0;
      memcpy (r_addr, j->addr, sizeof r_addr);
      r_hostent.h_name = r_name;
      r_hostent.h_aliases = 0;
      r_hostent.h_addrtype = j->family;
      r_hostent.h_length = j->addrlen;
      r_hostent.h_addr_list = r_addr_list;
      r = &r_hostent;
    }
  else
    h_errno = j->err;
  release_job (j);
  return r;
}

/* **サービス名はスレッドへ出さない。** `/etc/services` を引くだけで
   ネットワークへ出ないので、固まる余地が無い。 */
servent *
resolver::lookup_serv (const char *name, const char *proto)
{
  return getservbyname (name, proto);
}

/* **呼ぶ人が居ない。** Win32 側は `post_bad_result (WSAEINTR)` で待ちを
   落とすが、`grep` した限り in-tree の呼び元は 0 で、こちらは待ちの中で
   `poll_quit_char` を見ているので C-g の経路も要らない。**空にしておいて、
   使い手が現れたら書く。** */
void
resolver::cancel ()
{
}

#endif /* !_WIN32 */
