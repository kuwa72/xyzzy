// -*-C++-*-
#ifndef _fontmap_h_
#define _fontmap_h_

/* Code point → FontSet slot index の写像。

   Phase 2 (UTF-16LE 化) の display で、charset bit による font 切替
   (現行 disp.cc:470+) を置き換えるための lookup。

   戻り値は font.h 定義の FONT_* のいずれか:
     FONT_ASCII, FONT_JP, FONT_LATIN, FONT_CYRILLIC, FONT_GREEK,
     FONT_CN_SIMPLIFIED, FONT_CN_TRADITIONAL, FONT_HANGUL, FONT_GEORGIAN,
     FONT_SYMBOL

   現時点では Unicode block による静的写像のみ。将来 Lisp 変数
   *unicode-font-ranges* で上書き可能にする。                          */

int get_font_idx (unsigned int cp);

#endif
