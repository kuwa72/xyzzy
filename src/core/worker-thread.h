#ifndef _worker_thread_h_
#define _worker_thread_h_

/* 使い捨ての worker スレッド。**tree-sitter (src/core/ts.cc) の中に閉じて
   いたものを、名前解決 (issue #223) が 2 つめの使い手になったので出した。**

   **3 つめの写しを作らないために出した。** このリポジトリは「同じことをする
   コードが 2 か所にあって片方だけが直っている」で何度も刺されている
   (補完エンジンが win32/minibuf.cc の写しだった件、#50 の記録)。ここは
   orphan の扱いが繊細なので、写すと必ずずれる。

   **共有できる不変条件が 1 つある: worker は Lisp オブジェクトを触らない。**
   `gc_mark_in_stack` (src/core/data.cc) が走査するスタックは 1 本
   (`&tem` から `app.initial_stack` まで) なので、**worker だけが持っている
   Lisp 参照は回収される。** worker へ渡すものは main スレッドで snapshot した
   plain なメモリ (`malloc`、`xmalloc` ではない) に限り、結果の取り付けも
   main スレッドでやる。**これは機械では守れないので、使う側が守る。**

   **`platform.h` の `HANDLE` には手を出さない。** あちらの `HANDLE` は
   ファイル記述子で、`CloseHandle` は中身を fd として `close()` を呼ぶ。
   スレッドのハンドルをそこへ通すと fd を閉じにかかるので、POSIX 側は
   ここで完結する型を持って pthread を直に使う (issue #150)。

   要る操作は 4 つだけ: 起こす / 終わるのを期限付きで待つ / 手放す /
   CPU を譲る。それと印を書く atomic が 1 つ。

   **期限付きの join に `pthread_timedjoin_np` は使わない** (Linux 専用で
   macOS に無い)。終了の印と条件変数を自分で持って `pthread_cond_timedwait`
   で待つ。

   **手放すときに終わっていなければ detach する。** Win32 側も
   `CloseHandle` は走っているスレッドを止めない (取り消しは cancel の印で
   協調的にやる) ので、同じ振る舞いになる。

   確認は `src/core/worker-thread-test.cc` (tools/linux-smoke.sh から走る)。 */

#ifdef _WIN32

# define WORKER_THREAD_RET   DWORD
# define WORKER_THREAD_CALL  WINAPI
# define WORKER_THREAD_DONE  0

typedef WORKER_THREAD_RET (WORKER_THREAD_CALL *worker_thread_fn) (void *);
typedef HANDLE worker_thread;

static inline worker_thread
worker_thread_start (worker_thread_fn fn, void *arg)
{
  return CreateThread (NULL, 0, (LPTHREAD_START_ROUTINE)fn, arg, 0, NULL);
}

static inline void
worker_thread_join (worker_thread h, int timeout_ms)
{
  if (h)
    WaitForSingleObject (h, timeout_ms);
}

static inline void
worker_thread_release (worker_thread h)
{
  if (h)
    CloseHandle (h);
}

static inline void
worker_yield ()
{
  SwitchToThread ();
}

static inline void
worker_atomic_set (volatile LONG *p, LONG v)
{
  InterlockedExchange (p, v);
}

#else /* !_WIN32 */

# include <pthread.h>
# include <sched.h>

# define WORKER_THREAD_RET   void *
# define WORKER_THREAD_CALL
# define WORKER_THREAD_DONE  nullptr

typedef WORKER_THREAD_RET (WORKER_THREAD_CALL *worker_thread_fn) (void *);

struct worker_thread_rec
{
  pthread_t       tid;
  pthread_mutex_t mtx;
  pthread_cond_t  cv;
  int             done;    /* 本体が返った */
  int             orphan;  /* 持ち主が先に手放した: 本体が自分で片付ける */
  worker_thread_fn    fn;
  void           *arg;
};

typedef worker_thread_rec *worker_thread;

static inline void
worker_thread_rec_free (worker_thread_rec *r)
{
  pthread_cond_destroy (&r->cv);
  pthread_mutex_destroy (&r->mtx);
  delete r;
}

static inline void *
worker_thread_trampoline (void *arg)
{
  worker_thread_rec *r = (worker_thread_rec *) arg;
  r->fn (r->arg);
  pthread_mutex_lock (&r->mtx);
  r->done = 1;
  int orphan = r->orphan;
  pthread_cond_broadcast (&r->cv);
  pthread_mutex_unlock (&r->mtx);
  if (orphan)
    {
      /* 誰も join しに来ないので、自分で切り離してから片付ける。
         orphan を見た時点で r を触るのは自分だけなので、解放して安全。 */
      pthread_detach (pthread_self ());
      worker_thread_rec_free (r);
    }
  return nullptr;
}

static inline worker_thread
worker_thread_start (worker_thread_fn fn, void *arg)
{
  worker_thread_rec *r = new worker_thread_rec;
  r->done   = 0;
  r->orphan = 0;
  r->fn     = fn;
  r->arg    = arg;
  pthread_mutex_init (&r->mtx, 0);
  pthread_cond_init (&r->cv, 0);
  if (pthread_create (&r->tid, 0, worker_thread_trampoline, r) != 0)
    {
      worker_thread_rec_free (r);
      return nullptr;
    }
  return r;
}

static inline void
worker_thread_join (worker_thread h, int timeout_ms)
{
  if (!h)
    return;
  /* `pthread_cond_timedwait` の期限は既定で CLOCK_REALTIME。 */
  struct timespec ts;
  clock_gettime (CLOCK_REALTIME, &ts);
  ts.tv_sec  += timeout_ms / 1000;
  ts.tv_nsec += (long)(timeout_ms % 1000) * 1000000L;
  if (ts.tv_nsec >= 1000000000L)
    {
      ts.tv_sec++;
      ts.tv_nsec -= 1000000000L;
    }
  pthread_mutex_lock (&h->mtx);
  int rc = 0;
  while (!h->done && rc == 0)
    rc = pthread_cond_timedwait (&h->cv, &h->mtx, &ts);
  pthread_mutex_unlock (&h->mtx);
}

static inline void
worker_thread_release (worker_thread h)
{
  if (!h)
    return;
  pthread_mutex_lock (&h->mtx);
  if (h->done)
    {
      /* **本体は orphan を見ていないので r を解放しない。** それでも tid は
         外す前に控えておく (読む順序を人が追える形にしておく)。 */
      pthread_t tid = h->tid;
      pthread_mutex_unlock (&h->mtx);
      pthread_join (tid, 0);
      worker_thread_rec_free (h);
      return;
    }
  h->orphan = 1;
  pthread_mutex_unlock (&h->mtx);
}

static inline void
worker_yield ()
{
  sched_yield ();
}

/* 読む側は volatile のままにしてある (Win32 側と同じ)。**印は 32 ビットで
   境界も合っているので、読みが途中の値を見ることはない。** */
static inline void
worker_atomic_set (volatile LONG *p, LONG v)
{
  __atomic_store_n (p, v, __ATOMIC_SEQ_CST);
}

#endif /* !_WIN32 */

#endif /* _worker_thread_h_ */
