// -*-C++-*-
#ifndef _eaw_h_
#define _eaw_h_

/* East Asian Width based character width lookup.

   Phase 2 (UTF-16LE 化) で SBCP/DBCP 判定 (`chtype.h:282-283`) を置き換える
   ための code point → 表示列幅 マップ。戻り値:
     0 = combining / zero-width
     1 = narrow / halfwidth
     2 = wide / fullwidth

   現時点では主要 Unicode block のみカバーする簡易実装。将来 UCD 由来の
   正確な East Asian Width (UAX #11) と General Category (combining) 完全
   データに差し替える。Ambiguous は常に 1 で返している (従来 xyzzy 流儀の
   2 選好に合わせるには将来設定化)。                                    */

int unicode_width (unsigned int cp);

#endif
