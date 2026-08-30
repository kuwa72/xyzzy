#include "stdafx.h"
#include "system.h"

#ifdef _WIN32
lisp
Fsi_uuid_create (lisp keys)
{
  UUID uuid;

  if (find_keyword_bool (Ksequential, keys))
    rpc_error (UuidCreateSequential (&uuid));
  else
    rpc_error (UuidCreate (&uuid));

  safe_rpc_str uuidstr;
  rpc_error (UuidToStringA (&uuid, &uuidstr));

  multiple_value::count () = 2;
  multiple_value::value (1) = make_list (
    make_integer (int64_t (uuid.Data1)),           // time-low
    make_fixnum (uuid.Data2),                      // time-mid
    make_fixnum (uuid.Data3),                      // time-high-and-version
    make_fixnum (uuid.Data4[0]),                   // clock-seq-and-reserved
    make_fixnum (uuid.Data4[1]),                   // clock-seq-low
    make_list (                                    // node
      make_fixnum (uuid.Data4[2]),
      make_fixnum (uuid.Data4[3]),
      make_fixnum (uuid.Data4[4]),
      make_fixnum (uuid.Data4[5]),
      make_fixnum (uuid.Data4[6]),
      make_fixnum (uuid.Data4[7]),
      0),
    0);

  return uuidstr.make_string ();
}

lisp
Fsi_get_key_state (lisp lvkey)
{
  int vkey = fixnum_value (lvkey);
  int flag = GetKeyState (vkey);

  multiple_value::count () = 2;
  multiple_value::value (1) = boole (flag & 0x01);
  return boole (flag < 0);
}

lisp
Fsi_search_path (lisp lfile, lisp lpath, lisp lext)
{
  /* These are pathnames; keep them UTF-16 rather than going through CP932. */
  wchar_t *path = 0;
  wchar_t *file = 0;
  wchar_t *ext = 0;

  check_string (lfile);
  file = (wchar_t *)alloca (i2wl (xstring_contents (lfile),
                                  xstring_length (lfile)) * sizeof (wchar_t));
  i2w (xstring_contents (lfile), xstring_length (lfile), file);

  if (lpath && lpath != Qnil)
    {
      check_string (lpath);
      path = (wchar_t *)alloca (i2wl (xstring_contents (lpath),
                                      xstring_length (lpath)) * sizeof (wchar_t));
      i2w (xstring_contents (lpath), xstring_length (lpath), path);
    }
  if (lext && lext != Qnil)
    {
      check_string (lext);
      ext = (wchar_t *)alloca (i2wl (xstring_contents (lext),
                                     xstring_length (lext)) * sizeof (wchar_t));
      i2w (xstring_contents (lext), xstring_length (lext), ext);
    }

  DWORD len = SearchPathW (path, file, ext, 0, 0, 0);
  if (!len)
    return Qnil;

  wchar_t *file_part = 0;
  wchar_t *buffer = (wchar_t *)alloca (len * sizeof (wchar_t));
  if (!SearchPathW (path, file, ext, len, buffer, &file_part))
    return Qnil;

  return make_path (buffer, 0);
}

lisp
Fadmin_user_p ()
{
  if (IsUserAnAdmin ())
    return Qt;
  else
    return Qnil;
}

#else // !_WIN32

/* `si:uuid-create' の POSIX 版。
 *
 * Win32 は RPC の `UuidCreate` / `UuidCreateSequential` を呼ぶ。POSIX に
 * 対応するものは無いが、**RFC 4122 の中身は「乱数」か「時刻 + 機械の
 * 識別子」**で、どちらも標準の手段で作れる。**libuuid には依存しない**
 * (Linux ビルドの依存は ncurses と zlib だけに保つ)。
 *
 *   既定 (`:sequential' なし)   version 4 — 122bit の乱数
 *   `:sequential t'             version 1 — 100ns 刻みの時刻 + clock-seq + node
 *
 * `node' は RFC 4122 §4.5 が「MAC が取れないときは乱数にしてマルチキャスト
 * ビットを立てる」と決めているのでそうする。**プロセスの間は変えない**ので
 * 「同じ機械の連番」という性質は保たれる (clock-seq も同じ)。
 */

#include <fcntl.h>
#include <unistd.h>
#include <time.h>

/* 乱数。**`/dev/urandom' を使う。** UUID の一意性はここに全部かかっているので、
   再現性のある擬似乱数 (core の `Random') では困る。読めなかったときだけ
   時刻と pid を混ぜた値で埋める — 一意性は落ちるが、UUID を返せないより
   ましなので。 */
static void
uuid_random_bytes (u_char *buf, int n)
{
  int fd = open ("/dev/urandom", O_RDONLY);
  if (fd >= 0)
    {
      int got = 0;
      while (got < n)
        {
          ssize_t r = read (fd, buf + got, n - got);
          if (r <= 0)
            break;
          got += int (r);
        }
      close (fd);
      if (got == n)
        return;
      n -= got;
      buf += got;
    }

  struct timespec ts;
  clock_gettime (CLOCK_REALTIME, &ts);
  u_long seed = u_long (ts.tv_nsec) ^ (u_long (ts.tv_sec) << 16) ^ u_long (getpid ());
  for (int i = 0; i < n; i++)
    {
      seed = seed * 6364136223846793005ULL + 1442695040888963407ULL;
      buf[i] = u_char (seed >> 33);
    }
}

/* プロセスの間ずっと同じ値を使う node と clock-seq。 */
static u_char uuid_node[6];
static u_short uuid_clock_seq;
static int uuid_node_ready;

static void
uuid_init_node ()
{
  if (uuid_node_ready)
    return;
  uuid_random_bytes (uuid_node, sizeof uuid_node);
  /* RFC 4122 §4.5: MAC でない node はマルチキャストビットを立てて、
     本物の MAC と衝突しないようにする。 */
  uuid_node[0] |= 0x01;
  u_char cs[2];
  uuid_random_bytes (cs, sizeof cs);
  uuid_clock_seq = u_short (((cs[0] & 0x3f) << 8) | cs[1]);
  uuid_node_ready = 1;
}

/* 1582-10-15 00:00:00 UTC から 1970-01-01 までの 100ns 刻みの数。 */
#define UUID_EPOCH_OFFSET 0x01b21dd213814000ULL

lisp
Fsi_uuid_create (lisp keys)
{
  u_char b[16];

  if (find_keyword_bool (Ksequential, keys))
    {
      uuid_init_node ();

      struct timespec ts;
      clock_gettime (CLOCK_REALTIME, &ts);
      uint64_t t = (uint64_t (ts.tv_sec) * 10000000ULL
                    + uint64_t (ts.tv_nsec) / 100ULL
                    + UUID_EPOCH_OFFSET);

      /* **同じ tick で 2 回呼ばれたら 1 進める。** RFC 4122 が求める
         「時刻が戻らない」を満たすため。 */
      static uint64_t last_time;
      if (t <= last_time)
        t = last_time + 1;
      last_time = t;

      b[0] = u_char (t >> 24); b[1] = u_char (t >> 16);
      b[2] = u_char (t >> 8);  b[3] = u_char (t);
      b[4] = u_char (t >> 40); b[5] = u_char (t >> 32);
      b[6] = u_char ((t >> 56) & 0x0f); b[7] = u_char (t >> 48);
      b[6] |= 0x10;                     /* version 1 */
      b[8] = u_char (uuid_clock_seq >> 8) | 0x80;   /* variant RFC 4122 */
      b[9] = u_char (uuid_clock_seq);
      memcpy (b + 10, uuid_node, 6);
    }
  else
    {
      uuid_random_bytes (b, sizeof b);
      b[6] = u_char ((b[6] & 0x0f) | 0x40);         /* version 4 */
      b[8] = u_char ((b[8] & 0x3f) | 0x80);         /* variant RFC 4122 */
    }

  /* **小文字で出す。** RFC 4122 がそう決めているし、xyzzy の `~X' も
     小文字を出すので、`si:uuid-create' の 2 つの戻り値を `format' で
     突き合わせるテストと一致する。 */
  char s[37];
  snprintf (s, sizeof s,
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]);

  multiple_value::count () = 2;
  multiple_value::value (1) = make_list (
    make_integer (uint32_t ((u_long (b[0]) << 24) | (u_long (b[1]) << 16)
                            | (u_long (b[2]) << 8) | u_long (b[3]))),  // time-low
    make_fixnum ((b[4] << 8) | b[5]),              // time-mid
    make_fixnum ((b[6] << 8) | b[7]),              // time-high-and-version
    make_fixnum (b[8]),                            // clock-seq-and-reserved
    make_fixnum (b[9]),                            // clock-seq-low
    make_list (                                    // node
      make_fixnum (b[10]), make_fixnum (b[11]), make_fixnum (b[12]),
      make_fixnum (b[13]), make_fixnum (b[14]), make_fixnum (b[15]),
      0),
    0);

  return make_string (s);
}

#endif // _WIN32
