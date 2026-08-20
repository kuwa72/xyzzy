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
   データに差し替える。

   UAX #11 の Ambiguous (罫線 U+2500-259F、幾何図形 U+25A0-25FF、矢印
   U+2190-21FF 等) は locale 依存で Wide / Narrow が変わる。xyzzy は
   エディタ本文では伝統的に CJK 環境として Wide 扱いにしている。

   ターミナル (src/core/term.cc) はこれを Narrow で引く。向こう側で動く
   アプリ (npm string-width や wcwidth を使う TUI) が Ambiguous を 1 桁で
   数えるので、こちらが 2 桁で数えるとカーソル位置が 1 文字ごとにずれ、
   罫線を使った表やサイドバーが崩れる。 */

int unicode_width (unsigned int cp);              /* Ambiguous = 2 (CJK 流儀) */
int unicode_width_ex (unsigned int cp, int ambiguous_is_wide);

#endif
