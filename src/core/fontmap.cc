#include "stdafx.h"
#include "ed.h"
#include "fontmap.h"

/* Code point → font slot index の静的マップ。

   FontSet には 9 スロット (FONT_ASCII .. FONT_GEORGIAN) が用意されている。
   charset-based な switch 分岐 (disp.cc:467-510 付近) を置き換える意図で、
   UTF-16 code point から適切なフォントスロットを返す関数。

   将来 Lisp 設定 (*unicode-font-ranges*) で上書きできるようにする予定。
   現時点では主要 Unicode block を静的にマップする粗い実装。           */

int
get_font_idx (unsigned int cp)
{
  /* ASCII / Latin-1 / Latin Extended: 欧文フォント */
  if (cp < 0x0180)
    return FONT_ASCII;

  /* Latin Extended-A/B, IPA, Spacing Modifier, Combining Diacriticals */
  if (cp < 0x0400)
    return FONT_LATIN;

  /* Cyrillic (U+0400-04FF, U+0500-052F Supplement) */
  if (cp < 0x0530)
    return FONT_CYRILLIC;

  /* Armenian, Hebrew, Arabic, Syriac, Thaana ... : Latin extended へ fallback */
  if (cp < 0x10A0)
    return FONT_LATIN;

  /* Georgian (U+10A0-10FF) */
  if (cp < 0x1100)
    return FONT_GEORGIAN;

  /* Hangul Jamo (U+1100-11FF) */
  if (cp < 0x1200)
    return FONT_HANGUL;

  /* 各種拡張 (Ethiopic, Cherokee 等): Latin fallback */
  if (cp < 0x1E00)
    return FONT_LATIN;

  /* Latin Extended Additional, Greek Extended */
  if (cp < 0x1F00)
    return FONT_LATIN;

  /* Greek Extended (U+1F00-1FFF) */
  if (cp < 0x2000)
    return FONT_GREEK;

  /* General Punctuation ... Box Drawing (U+2000-25FF): Latin */
  if (cp < 0x2E80)
    return FONT_LATIN;

  /* CJK Radicals .. CJK Unified Ideographs まで: まず日本語フォント */
  if (cp < 0xA000)
    return FONT_JP;

  /* Yi Syllables (U+A000-A4CF): 簡体中文 */
  if (cp < 0xA500)
    return FONT_CN_SIMPLIFIED;

  /* Hangul Jamo Extended-A/B, Hangul Syllables */
  if (cp >= 0xA960 && cp < 0xD800)
    {
      if (cp < 0xA980) return FONT_HANGUL;  /* Jamo Ext-A */
      if (cp >= 0xAC00 && cp < 0xD7B0) return FONT_HANGUL;  /* Syllables */
      return FONT_JP;  /* その他拡張 CJK 等 */
    }

  /* Surrogate half: 便宜上 JP 扱い (実運用では上位 cp に合流) */
  if (cp < 0xE000)
    return FONT_JP;

  /* Private Use Area (U+E000-F8FF): Latin fallback */
  if (cp < 0xF900)
    return FONT_LATIN;

  /* CJK Compatibility Ideographs */
  if (cp < 0xFB00)
    return FONT_JP;

  /* Alphabetic Presentation Forms, Arabic Presentation: Latin */
  if (cp < 0xFE30)
    return FONT_LATIN;

  /* CJK Compatibility Forms, Small Form Variants */
  if (cp < 0xFE70)
    return FONT_JP;

  /* Arabic Presentation Forms-B: Latin */
  if (cp < 0xFF00)
    return FONT_LATIN;

  /* Fullwidth Forms, Halfwidth Forms */
  if (cp < 0x10000)
    return FONT_JP;

  /* SMP 以上 (絵文字・CJK 拡張等): とりあえず JP */
  return FONT_JP;
}
