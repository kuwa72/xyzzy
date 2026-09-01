/* `src/core/worker-thread.h` の単体確認。

   **これが無いと抽出が verify できない。** shim は tree-sitter の中に閉じて
   いたが、tree-sitter のテストは 14 件しか無く、**非同期の経路を名指しで
   測っているものが 1 つも無い。** つまり「ts のテストが通ったから抽出は
   安全」とは言えなかった。

   ここで測るのは shim の 4 操作そのもの:

     * 起こしたら本体が走る
     * **期限付きの join が、終わっていなければ待ちすぎずに戻る**
     * 終わってから release すると join して片付く
     * **走っている最中に release すると orphan になり、本体が自分で片付ける**
       (ここが一番繊細で、写すとずれる所)

   `src/core/mem-posix-test.cc` と同じ形で、core とはリンクせずヘッダ 1 つ
   だけを持つ。`tools/linux-smoke.sh` から走らせる。 */

#include "stdafx.h"
#include "worker-thread.h"

#include <stdio.h>
#include <unistd.h>
#include <time.h>

static int failures;
static int checks;

static void
check (const char *name, int ok)
{
  checks++;
  if (!ok)
    {
      failures++;
      printf ("worker-thread-test: FAILED %s\n", name);
    }
}

static long
now_ms ()
{
  struct timespec ts;
  clock_gettime (CLOCK_MONOTONIC, &ts);
  return long (ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}

/* **待つところに必ず期限を付ける。** 期限の無い `while (!flag)` を書いたら、
   負の確認 (スレッドを起こさない形に潰す) で**テストが落ちる代わりに
   固まった。** 固まったテストは CI では step timeout として出るので、
   「何が壊れたか」が読めない -- smoke の予算で同じ失敗をしたのと同じ形。
   立たなければ 0 を返して、呼ぶ側が check として落とす。 */
static int
wait_for (volatile LONG *flag, int timeout_ms)
{
  long deadline = now_ms () + timeout_ms;
  while (!*flag)
    {
      if (now_ms () > deadline)
        return 0;
      usleep (1000);
    }
  return 1;
}

/* 立てるだけの本体。 */
static volatile LONG g_ran;

static WORKER_THREAD_RET WORKER_THREAD_CALL
body_quick (void *)
{
  worker_atomic_set (&g_ran, 1);
  return WORKER_THREAD_DONE;
}

/* 印が立つまで回る本体。**取り消しは協調的である** -- shim はスレッドを
   殺さない。 */
static volatile LONG g_stop;
static volatile LONG g_long_ran;

static WORKER_THREAD_RET WORKER_THREAD_CALL
body_until_stopped (void *)
{
  worker_atomic_set (&g_long_ran, 1);
  while (!g_stop)
    {
      worker_yield ();
      usleep (1000);
    }
  return WORKER_THREAD_DONE;
}

int
main ()
{
  /* 起こす -> 走る -> 待つ -> 手放す。 */
  worker_atomic_set (&g_ran, 0);
  worker_thread h = worker_thread_start (body_quick, 0);
  check ("start returns a handle", h != 0);
  worker_thread_join (h, 5000);
  check ("the body ran", g_ran == 1);
  worker_thread_release (h);

  /* **期限付きの join は待ちすぎない。** 本体は止めるまで終わらないので、
     100ms を渡したら 100ms 前後で戻ってくること。上限を甘め (2 秒) に
     取ってあるのは、遅い runner で落ちないため -- **見たいのは「無限に
     待たない」であって、正確な時間ではない。** */
  worker_atomic_set (&g_stop, 0);
  worker_atomic_set (&g_long_ran, 0);
  worker_thread h2 = worker_thread_start (body_until_stopped, 0);
  check ("start returns a handle (long body)", h2 != 0);
  check ("the long body did start", wait_for (&g_long_ran, 5000));
  long t0 = now_ms ();
  worker_thread_join (h2, 100);
  long elapsed = now_ms () - t0;
  check ("a timed join returns while the body is still running",
         elapsed < 2000);

  /* 止めてから join すると、こちらは終わっている。 */
  worker_atomic_set (&g_stop, 1);
  worker_thread_join (h2, 5000);
  worker_thread_release (h2);
  check ("release after the body finished", 1);

  /* **走っている最中に手放す (orphan)。** 本体が自分で片付けるので、
     ここで待たずに戻れること。片付けそのものは外から見えないが、
     **止めた後にプロセスが生きていること**が見える (二重解放していれば
     ここで落ちる)。 */
  worker_atomic_set (&g_stop, 0);
  worker_atomic_set (&g_long_ran, 0);
  worker_thread h3 = worker_thread_start (body_until_stopped, 0);
  check ("start returns a handle (orphan case)", h3 != 0);
  check ("the orphan-case body started", wait_for (&g_long_ran, 5000));
  worker_thread_release (h3);          /* まだ走っている */
  check ("release while running returns", 1);
  worker_atomic_set (&g_stop, 1);
  usleep (200000);                     /* 本体が片付ける間 */
  check ("still alive after the orphan cleaned itself up", 1);

  /* null を渡しても落ちない (呼ぶ側が握っていないことがある)。 */
  worker_thread_join (0, 10);
  worker_thread_release (0);
  check ("join/release tolerate a null handle", 1);

  printf ("worker-thread-test: %d checks, %d failed\n", checks, failures);
  return failures ? 1 : 0;
}
