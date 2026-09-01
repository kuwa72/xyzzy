/* `src/core/mem-posix.cc` の単体確認 (issue #240)。

   **なぜ C++ のテストが要るか。** 見たい性質は「予約しただけのページは
   `IsBadWritePtr` が『悪い』と答える」で、これは**Lisp から呼べない。**
   症状 (GC が `PROT_NONE` のページを読んで SIGSEGV) はスタックのゴミが
   ちょうどそのページを指す必要があるので**Lisp からは作れない。** 測れる
   のは述語そのものだけである。

   このリポジトリのテストは全部 Lisp (unittest の `*-tests.l`) と pty の
   シェル (`tools/linux-smoke.sh`) なので、**C++ の置き場はここが最初**である。
   小さく保つ: `mem-posix.cc` 1 つだけとリンクし、core の他とは繋がない。

   `tools/linux-smoke.sh` から走らせる。落ちた項目は名前で出る。 */

#include "stdafx.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int failures;
static int checks;

static void
check (const char *name, int ok)
{
  checks++;
  if (!ok)
    {
      failures++;
      printf ("mem-posix-test: FAILED %s\n", name);
    }
}

int
main ()
{
  size_t ps = size_t (sysconf (_SC_PAGESIZE));
  size_t block = 64 * 1024;
  if (block < ps * 4)
    block = ps * 4;

  /* 予約だけ。`alloc_page::alloc` が最初にやるのと同じ形。 */
  char *base = (char *)VirtualAlloc (0, block, MEM_RESERVE, PAGE_NOACCESS);
  check ("reserve returns an address", base != 0);
  if (!base)
    {
      printf ("mem-posix-test: %d checks, %d failed\n", checks, failures);
      return 1;
    }

  check ("reserved address is granularity aligned",
         (uintptr_t (base) % block) == 0 || (uintptr_t (base) % (64 * 1024)) == 0);

  /* **予約しただけのページは「悪い」。** ここが `return FALSE;` のスタブ
     だったので guard が効いていなかった。 */
  check ("reserved but not committed is bad", IsBadWritePtr (base, ps));
  check ("last page of the reservation is bad too",
         IsBadWritePtr (base + block - ps, ps));

  /* 1 ページ commit する。 */
  void *p = VirtualAlloc (base, ps, MEM_COMMIT, PAGE_READWRITE);
  check ("commit returns the same address", p == base);
  check ("committed page is good", !IsBadWritePtr (base, ps));
  check ("the page after it is still bad", IsBadWritePtr (base + ps, ps));

  /* **commit 済みと未 commit をまたぐ範囲は「悪い」。** GC は
     `LDATA_PAGE_SIZE` 分をまとめて聞くので、ここを「良い」と答えると
     後ろ半分で落ちる。 */
  check ("a range straddling committed and uncommitted is bad",
         IsBadWritePtr (base, ps * 2));

  /* 本当に書ける (mprotect が効いている)。 */
  base[0] = 'x';
  base[ps - 1] = 'y';
  check ("the committed page really is writable",
         base[0] == 'x' && base[ps - 1] == 'y');

  /* 2 ページ目も commit してから、またぐ範囲が「良い」になる。 */
  VirtualAlloc (base + ps, ps, MEM_COMMIT, PAGE_READWRITE);
  check ("straddling range is good once both pages are committed",
         !IsBadWritePtr (base, ps * 2));

  /* **decommit で「悪い」へ戻る。** `alloc_page::free` がこれをやる。 */
  check ("decommit succeeds", VirtualFree (base + ps, ps, MEM_DECOMMIT));
  check ("decommitted page is bad again", IsBadWritePtr (base + ps, ps));
  check ("the page still committed stays good", !IsBadWritePtr (base, ps));

  /* 表に無いアドレスは「悪い」。**Win32 より厳しい側に倒してある** --
     生きている ldata_rep ページは必ずこのシムを通るので、偽の「悪い」は
     出ない。 */
  void *heap = malloc (ps);
  check ("malloc'd memory is bad (not handed out by this shim)",
         IsBadWritePtr (heap, ps));
  free (heap);
  int on_stack = 0;
  check ("the stack is bad (not handed out by this shim)",
         IsBadWritePtr (&on_stack, sizeof on_stack));
  check ("a null pointer is bad", IsBadWritePtr (0, ps));
  check ("a zero size is bad", IsBadWritePtr (base, 0));

  /* 解放したら表から消える。 */
  check ("release succeeds", VirtualFree (base, 0, MEM_RELEASE));
  check ("released memory is bad", IsBadWritePtr (base, ps));

  printf ("mem-posix-test: %d checks, %d failed\n", checks, failures);
  return failures ? 1 : 0;
}
