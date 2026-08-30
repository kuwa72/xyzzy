// quit-poll.cc -- 走っている Lisp を C-g で止められるようにする (POSIX)。
//
// **`quit-flag` を立てる者が居なかった。** Win32 は専用のスレッドが
// `RegisterHotKey` で C-g を受けて `Vquit_flag = Qt` にする
// (src/frontend/win32/toplev.cc)。端末にそれに当たるものが無いので、
// 走り出した Lisp を止める手段が無く、**暴走したらプロセスを殺すしかなかった**
// (issue #162)。`raw()` を使っているので C-c も signal にならない
// (ISIG が落ちる) し、xyzzy の C-c は前置キーなので ISIG を戻す方には
// 倒せない。
//
// **`QUIT` から主スレッドで端末を覗く。** `QUIT` (= `check_quit`) は
// インタプリタの最も熱い所に居るので、あちらでやるのは「カウンタを 1 つ
// 減らして分岐する」だけにして、実際の仕事をここへ置いた。
//
// **シグナルは使わない。** ハンドラの中で端末から読むと主入力経路と
// バイトを取り合う。ここは主スレッドの上なので、読んだバイトを入力キューへ
// 戻すのも安全である。
//
// 覗く間隔に**時計の下限を掛ける**のが要点。カウンタだけだと、速いループでは
// 数マイクロ秒に 1 回 `select` を呼ぶことになる。時計を読むのはカウンタが
// 尽きたときだけで、`QUIT` ごとではない。

#include "stdafx.h"
#include "ed.h"

#ifndef _WIN32

/* `QUIT` がこれだけ呼ばれたら `poll_quit_char` へ来る。**小さすぎると
   時計を読む回数が増え、大きすぎると遅いループで反応が鈍る。** */
enum {QUIT_POLL_INTERVAL = 4096};

/* 端末を覗く間隔の下限。C-g を押してからここまでの遅れが出る。 */
enum {QUIT_POLL_MIN_MS = 50};

int g_quit_poll_countdown = QUIT_POLL_INTERVAL;

/* 端末を覗く手。フロントエンドが入れる (端末を持たない xyzzy-cli では
   ぬるままで、何も起きない)。 */
void (*g_quit_poll_hook) () = 0;

static long
monotonic_ms ()
{
  struct timespec ts;
  clock_gettime (CLOCK_MONOTONIC, &ts);
  return long (ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}

void
poll_quit_char ()
{
  g_quit_poll_countdown = QUIT_POLL_INTERVAL;

  if (!g_quit_poll_hook)
    return;

  static long last;
  long now = monotonic_ms ();
  if (now - last < QUIT_POLL_MIN_MS)
    return;
  last = now;

  g_quit_poll_hook ();
}

#endif /* !_WIN32 */
