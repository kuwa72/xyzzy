#include "stdafx.h"
#include "eaw.h"

/* 主要 Unicode block の East Asian Width 判定 (簡易版)。

   現時点では:
     - 結合文字 (主要な combining marks range) → 0
     - CJK / 全角 / Hangul / Emoji 等 → 2
     - それ以外 (ASCII, Latin, 記号, etc.) → 1

   将来 UCD 由来の正確なデータで置き換える予定。Ambiguous 範囲
   (e.g. U+00A1) は narrow (1) 固定。xyzzy 流儀の wide 選好に
   したい場合は設定フラグで切替可能にする。                          */

static inline int
is_combining (unsigned int cp)
{
  /* 主要な Combining Marks range のみ。完全な General_Category=Mn/Mc/Me
     カバーは UCD 差し替え時に対応。                                  */
  return ((cp >= 0x0300 && cp <= 0x036F)   /* Combining Diacritical Marks */
          || (cp >= 0x1AB0 && cp <= 0x1AFF) /* Combining Diacritical Marks Extended */
          || (cp >= 0x1DC0 && cp <= 0x1DFF) /* Combining Diacritical Marks Supplement */
          || (cp >= 0x20D0 && cp <= 0x20FF) /* Combining Diacritical Marks for Symbols */
          || (cp >= 0xFE20 && cp <= 0xFE2F) /* Combining Half Marks */
          || (cp >= 0x1F3FB && cp <= 0x1F3FF) /* Emoji Modifier (skin tone) は 0 扱い */
          || cp == 0x200D                   /* Zero Width Joiner */
          || cp == 0xFEFF);                 /* Zero Width No-Break Space (BOM) */
}

static inline int
is_wide (unsigned int cp)
{
  return ((cp >= 0x1100 && cp <= 0x115F)   /* Hangul Jamo */
          || (cp >= 0x2E80 && cp <= 0x303E) /* CJK Radicals Supplement .. CJK Symbols and Punctuation */
          || (cp >= 0x3041 && cp <= 0x33FF) /* Hiragana .. CJK Compatibility */
          || (cp >= 0x3400 && cp <= 0x4DBF) /* CJK Unified Ideographs Extension A */
          || (cp >= 0x4E00 && cp <= 0x9FFF) /* CJK Unified Ideographs */
          || (cp >= 0xA000 && cp <= 0xA4CF) /* Yi Syllables */
          || (cp >= 0xA960 && cp <= 0xA97F) /* Hangul Jamo Extended-A */
          || (cp >= 0xAC00 && cp <= 0xD7A3) /* Hangul Syllables */
          || (cp >= 0xF900 && cp <= 0xFAFF) /* CJK Compatibility Ideographs */
          || (cp >= 0xFE30 && cp <= 0xFE4F) /* CJK Compatibility Forms */
          || (cp >= 0xFF00 && cp <= 0xFF60) /* Fullwidth ASCII variants */
          || (cp >= 0xFFE0 && cp <= 0xFFE6) /* Fullwidth Signs */
          || (cp >= 0x1F300 && cp <= 0x1F64F) /* Miscellaneous Symbols and Pictographs + Emoticons */
          || (cp >= 0x1F680 && cp <= 0x1F6FF) /* Transport and Map Symbols */
          || (cp >= 0x1F900 && cp <= 0x1F9FF) /* Supplemental Symbols and Pictographs */
          || (cp >= 0x1FA70 && cp <= 0x1FAFF) /* Symbols and Pictographs Extended-A */
          || (cp >= 0x20000 && cp <= 0x2FFFD) /* CJK Extension B..F + Compatibility Supplement */
          || (cp >= 0x30000 && cp <= 0x3FFFD)); /* CJK Extension G+ */
}

int
unicode_width (unsigned int cp)
{
  /* Surrogate half (never appears in valid UTF-16 as standalone code point) */
  if (cp >= 0xD800 && cp <= 0xDFFF)
    return 1;

  if (is_combining (cp))
    return 0;
  if (is_wide (cp))
    return 2;
  return 1;
}
