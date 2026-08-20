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

/* UAX #11 で locale に依らず Wide / Fullwidth な範囲。 */
static inline int
is_wide_always (unsigned int cp)
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
          /* Emoji presentation (Extended_Pictographic かつ EAW=Wide)。 */
          || cp == 0x231A || cp == 0x231B
          || cp == 0x23E9 || cp == 0x23EA || cp == 0x23EB || cp == 0x23EC
          || cp == 0x23F0 || cp == 0x23F3
          || cp == 0x25FD || cp == 0x25FE
          || cp == 0x2614 || cp == 0x2615
          || (cp >= 0x2648 && cp <= 0x2653)
          || cp == 0x267F || cp == 0x2693 || cp == 0x26A1
          || cp == 0x26AA || cp == 0x26AB
          || cp == 0x26BD || cp == 0x26BE
          || cp == 0x26C4 || cp == 0x26C5 || cp == 0x26CE
          || cp == 0x26D4 || cp == 0x26EA
          || cp == 0x26F2 || cp == 0x26F3 || cp == 0x26F5
          || cp == 0x26FA || cp == 0x26FD
          || cp == 0x2705 || cp == 0x270A || cp == 0x270B
          || cp == 0x2728 || cp == 0x274C || cp == 0x274E
          || (cp >= 0x2753 && cp <= 0x2755)
          || cp == 0x2757
          || (cp >= 0x2795 && cp <= 0x2797)
          || cp == 0x27B0 || cp == 0x27BF
          || cp == 0x2B1B || cp == 0x2B1C
          || cp == 0x2B50 || cp == 0x2B55
          || cp == 0x1F004 || cp == 0x1F0CF
          || cp == 0x1F18E
          || (cp >= 0x1F191 && cp <= 0x1F19A)
          || (cp >= 0x1F200 && cp <= 0x1F2FF)
          || (cp >= 0x1F300 && cp <= 0x1F64F) /* Misc Symbols and Pictographs + Emoticons */
          || (cp >= 0x1F680 && cp <= 0x1F6FF) /* Transport and Map Symbols */
          || (cp >= 0x1F7E0 && cp <= 0x1F7EB) /* 大きい丸・四角 */
          || (cp >= 0x1F900 && cp <= 0x1F9FF) /* Supplemental Symbols and Pictographs */
          || (cp >= 0x1FA70 && cp <= 0x1FAFF) /* Symbols and Pictographs Extended-A */
          || (cp >= 0x20000 && cp <= 0x2FFFD) /* CJK Extension B..F + Compatibility Supplement */
          || (cp >= 0x30000 && cp <= 0x3FFFD)); /* CJK Extension G+ */
}

/* UAX #11 の Ambiguous (locale 依存で Wide / Narrow が変わる範囲)。
   xyzzy はエディタ本文では伝統的に CJK 環境として Wide 扱いにしている。 */
static inline int
is_ambiguous (unsigned int cp)
{
  /* U+2010-U+215F の Ambiguous (General Punctuation, Currency,
     Letterlike Symbols, Number Forms 等) は典型的な日本語フォントに
     glyph が無く豆腐化するため、CJK 環境でも wide 扱いから外している。 */
  return ((cp >= 0x2160 && cp <= 0x217F) /* Roman numerals */
          || (cp >= 0x2190 && cp <= 0x21FF) /* Arrows */
          || (cp >= 0x2200 && cp <= 0x22FF) /* Mathematical Operators */
          || (cp >= 0x2460 && cp <= 0x24FF) /* Enclosed Alphanumerics */
          || (cp >= 0x2500 && cp <= 0x259F) /* Box Drawing + Block Elements */
          || (cp >= 0x25A0 && cp <= 0x25FF) /* Geometric Shapes */
          || (cp >= 0x2600 && cp <= 0x26FF) /* Miscellaneous Symbols */
          || (cp >= 0x1D000 && cp <= 0x1D24F) /* Byzantine + Musical Symbols */
          || (cp >= 0x1D300 && cp <= 0x1D7FF) /* Tai Xuan Jing .. Math Alphanumeric */
          || (cp >= 0x1F000 && cp <= 0x1F0FF) /* Mahjong, Domino, Playing Cards */
          || (cp >= 0x1F100 && cp <= 0x1F1FF)); /* Enclosed Alphanumeric Supplement */
}

int
unicode_width_ex (unsigned int cp, int ambiguous_is_wide)
{
  /* Surrogate half (never appears in valid UTF-16 as standalone code point) */
  if (cp >= 0xD800 && cp <= 0xDFFF)
    return 1;

  if (is_combining (cp))
    return 0;
  if (is_wide_always (cp))
    return 2;
  if (ambiguous_is_wide && is_ambiguous (cp))
    return 2;
  return 1;
}

int
unicode_width (unsigned int cp)
{
  return unicode_width_ex (cp, 1);
}
