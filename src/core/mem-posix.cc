/* POSIX 側の `VirtualAlloc` / `VirtualFree` / `IsBadWritePtr` (issue #240)。

   **元は `platform.h` の inline 実装だった。ここへ出した理由が本題である。**

   `IsBadWritePtr` は保守的 GC のスタック走査が使う:

       ldata_rep *r = (ldata_rep *)(pointer_t (p) & ~LDATA_PAGE_MASK);
       if (IsBadWritePtr (r, LDATA_PAGE_SIZE))
         continue;
       ... r->dr_used を読む            (src/core/data.cc:812)

   POSIX ではこれが `return FALSE;` (= 「悪くない」) のスタブだったので、
   **guard が一度も効いていなかった。** そして読めないページが実在する:
   `alloc_page::alloc` (src/core/alloc.cc) は 64KB を `MEM_RESERVE` +
   `PAGE_NOACCESS` で予約して **unit ごとに commit** し、`alloc_page::free`
   は unit を decommit して戻す。下の `VirtualAlloc` は予約を `PROT_NONE` で
   mmap し、commit を `mprotect` でやるので、**予約したブロックの未 commit の
   部分は `PROT_NONE` のまま残る。**

   `ld_lower_bound` / `ld_upper_bound` は確保したページの最小と最大を広げて
   いくだけ (data.cc:41-51) なので、その `PROT_NONE` は範囲の中にある。
   実測でも `---p` の領域が commit 済みの Lisp ページに挟まれて 29〜35 個
   見えた。**スタックのゴミがそこを指せば GC 中に SIGSEGV する。**

   ## なぜヘッダに置けないか

   **記帳をヘッダの `static` に置くと GC が生きているオブジェクトを回収する。**
   `_va_regions` は namespace スコープの `static` だったので**翻訳単位ごとに
   別の実体**になる。今それで動いていたのは `VirtualAlloc` を呼ぶのが
   `alloc.cc` だけだったからで、**`IsBadWritePtr` を呼ぶのは `data.cc`** --
   別の翻訳単位である。記帳をヘッダに置いたままにすると `data.cc` から見た
   表は空で、**本物の Lisp ページ全部に「悪い」と答える。** 保守的走査は
   そのページを飛ばすので、そこにしか参照が無いオブジェクトが回収される。

   ヘッダに宣言だけを残して実体をここへ 1 つ持つ形にした。`vfs-posix.cc` /
   `dll-posix.cc` / `ini-posix.cc` と同じ並びである。

   ## 記帳の形

   予約ごとに `{base, size, committed}` を持ち、`committed` は **OS ページ
   1 枚 = 1 ビット**のビットマップ。予約は今どれも 64KB
   (`fixed_heap` の unit は最大 8KB) なので、4KB ページで 16 枚、
   16KB ページで 4 枚。64 ビットで足りる。表は base で整列した配列で、
   二分探索で引く。

   **記帳は正である。** 記帳に入れられなければ予約自体を失敗させる
   (`VirtualAlloc` が 0 を返し、呼ぶ側は `FEstorage_error`)。**「表に無い」が
   「実は良い」を意味する余地を残さない。**

   ## 表に無いアドレスは「悪い」と答える

   **Win32 の `IsBadWritePtr` より厳しい。** あちらは実際に書けるかを見るので、
   malloc したメモリやスタックには「良い」と答える。ここは表に無ければ
   「悪い」と答える。理由:

     * **本物の `ldata_rep` ページは必ずこのシムを通る**
       (`fixed_heap` -> `alloc_page` -> ここ) ので、**生きている Lisp データに
       「悪い」と答える余地が無い**
     * 範囲の中にはシムを通らない mapping も混ざる (実測では tree-sitter の
       `.so` が `[ld_lower_bound, ld_upper_bound)` の中に見えた)。表に無ければ
       弾けるので、そちらも守れる
     * ゴミのポインタが `find_object` のヒープ全走査へ進むのを止められる

   単一スレッドで、ロックは無い (`_beginthreadex` は POSIX ではスタブで、
   `VirtualAlloc` を呼ぶのは `alloc.cc` だけ)。 */

#ifndef _WIN32

#include "stdafx.h"

#include <sys/mman.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

namespace
{

/* 予約 1 つ。`mmap_base` / `mmap_size` は munmap のために元の mmap を覚えて
   おくもので、`base` / `size` は呼ぶ側へ返した (granularity へ揃えた) 範囲。 */
struct region
{
  void *mmap_base;
  size_t mmap_size;
  char *base;
  size_t size;
  u_int64_t committed;          // OS ページ 1 枚 = 1 ビット
};

region *g_regions;
int g_nregions;
int g_regions_capacity;

size_t
page_size ()
{
  static size_t p = 0;
  if (!p)
    {
      long n = sysconf (_SC_PAGESIZE);
      p = n > 0 ? size_t (n) : 4096;
    }
  return p;
}

/* 予約の粒度。Win32 の `MEM_RESERVE` は `dwAllocationGranularity` (64KB) へ
   揃えたアドレスを返すことを約束していて、**`alloc_page` はその揃いに
   依存している** (ブロックの先頭を `& ~(ap_block_size - 1)` で求める)。
   mmap はページ揃えしか約束しないので、多めに取って自分で揃える。 */
size_t
granularity ()
{
  size_t p = page_size ();
  return p > 65536 ? p : 65536;
}

/* base で整列した配列を二分探索する。`addr` を含む予約か、無ければ 0。 */
region *
find_region (const void *addr)
{
  int lo = 0, hi = g_nregions - 1;
  const char *p = (const char *)addr;
  while (lo <= hi)
    {
      int mid = lo + (hi - lo) / 2;
      region &r = g_regions[mid];
      if (p < r.base)
        hi = mid - 1;
      else if (p >= r.base + r.size)
        lo = mid + 1;
      else
        return &r;
    }
  return 0;
}

/* 整列を保ったまま挿入する。**入れられなければ 0 を返す** -- 呼ぶ側は
   予約自体を失敗させる (記帳を正にしておくため)。 */
int
insert_region (void *mmap_base, size_t mmap_size, char *base, size_t size)
{
  if (g_nregions == g_regions_capacity)
    {
      int cap = g_regions_capacity ? g_regions_capacity * 2 : 32;
      region *p = (region *)realloc (g_regions, sizeof *p * cap);
      if (!p)
        return 0;
      g_regions = p;
      g_regions_capacity = cap;
    }
  int i = g_nregions;
  while (i > 0 && g_regions[i - 1].base > base)
    {
      g_regions[i] = g_regions[i - 1];
      i--;
    }
  g_regions[i].mmap_base = mmap_base;
  g_regions[i].mmap_size = mmap_size;
  g_regions[i].base = base;
  g_regions[i].size = size;
  g_regions[i].committed = 0;
  g_nregions++;
  return 1;
}

void
remove_region (region *r)
{
  int i = int (r - g_regions);
  memmove (g_regions + i, g_regions + i + 1,
           sizeof *g_regions * (g_nregions - i - 1));
  g_nregions--;
}

/* `[addr, addr + size)` が覆うページのビットを立てる / 落とす。
   **範囲は予約の中に収まっている前提**で、呼ぶ側が確かめている。 */
u_int64_t
page_mask (const region *r, const char *addr, size_t size)
{
  size_t ps = page_size ();
  size_t first = size_t (addr - r->base) / ps;
  size_t last = size_t (addr + size - 1 - r->base) / ps;
  if (last > 63)
    last = 63;
  u_int64_t m = 0;
  for (size_t i = first; i <= last; i++)
    m |= u_int64_t (1) << i;
  return m;
}

} // namespace

LPVOID
VirtualAlloc (LPVOID addr, size_t size, DWORD type, DWORD protect)
{
  if (!size)
    return 0;

  int prot = PROT_NONE;
  if (protect == PAGE_READWRITE)
    prot = PROT_READ | PROT_WRITE;
  if (type & MEM_COMMIT)
    prot = PROT_READ | PROT_WRITE;

  if (addr)
    {
      /* 既にある予約の中を commit する。 */
      region *r = find_region (addr);
      if (!r || (char *)addr + size > r->base + r->size)
        return 0;
      if (mprotect (addr, size, prot) != 0)
        return 0;
      r->committed |= page_mask (r, (char *)addr, size);
      return addr;
    }

  /* 新しい予約。granularity へ揃えるために多めに取って前後を切る。 */
  size_t align = granularity ();
  size_t alloc_size = size + align - 1;
  void *raw = mmap (0, alloc_size, prot, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (raw == MAP_FAILED)
    return 0;

  char *aligned = (char *)((uintptr_t (raw) + align - 1) & ~(uintptr_t (align) - 1));
  size_t front = size_t (aligned - (char *)raw);
  size_t back = alloc_size - front - size;
  if (front)
    munmap (raw, front);
  if (back)
    munmap (aligned + size, back);

  if (!insert_region (aligned, size, aligned, size))
    {
      /* **記帳できなければ予約を失敗させる。** 表に無いものを配ると
         `IsBadWritePtr` が「悪い」と答えてしまう (= GC が生きている
         オブジェクトを飛ばす)。 */
      munmap (aligned, size);
      return 0;
    }

  region *r = find_region (aligned);
  if (type & MEM_COMMIT)
    r->committed = page_mask (r, aligned, size);
  return (LPVOID)aligned;
}

BOOL
VirtualFree (LPVOID addr, size_t size, DWORD type)
{
  if (type == MEM_DECOMMIT)
    {
      region *r = find_region (addr);
      if (!r || !size || (char *)addr + size > r->base + r->size)
        return FALSE;
      if (mprotect (addr, size, PROT_NONE) != 0)
        return FALSE;
      r->committed &= ~page_mask (r, (char *)addr, size);
      return TRUE;
    }
  if (type == MEM_RELEASE)
    {
      /* Win32 は size 0 で予約全体を解放できる。 */
      region *r = find_region (addr);
      if (r && r->base == addr)
        {
          void *mb = r->mmap_base;
          size_t ms = r->mmap_size;
          remove_region (r);
          return munmap (mb, ms) == 0 ? TRUE : FALSE;
        }
      return FALSE;
    }
  return FALSE;
}

/* **表に無ければ「悪い」。** 上のコメントの通り、Win32 より厳しい側に
   倒してある。生きている `ldata_rep` ページは必ずこのシムを通るので、
   厳しくしても偽の「悪い」は出ない。 */
BOOL
IsBadWritePtr (void *addr, size_t size)
{
  if (!addr || !size)
    return TRUE;
  const region *r = find_region (addr);
  if (!r)
    return TRUE;
  if ((char *)addr + size > r->base + r->size)
    return TRUE;              // 予約をまたぐ範囲は見られない
  u_int64_t need = page_mask (r, (char *)addr, size);
  return (r->committed & need) == need ? FALSE : TRUE;
}

#endif /* !_WIN32 */
