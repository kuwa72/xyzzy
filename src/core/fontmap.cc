#include "stdafx.h"
#include "ed.h"
#include "fontmap.h"

/* Code point → font slot index の静的マップ。

   FontSet には 10 スロット (FONT_ASCII .. FONT_SYMBOL) が用意されている。
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

  /* General Punctuation .. Misc Symbols (U+2000-U+2E7F)。
     U+2010-U+215F (General Punctuation, Currency, Letterlike Symbols,
     Number Forms 等) は Latin font に振る — JP font に glyph が無くて
     豆腐化しがちな † ™ € ‰ などはこちら。
     U+2160-U+22FF (Roman numerals, Arrows, Math) と U+2460-U+26FF
     (Enclosed alpha, Box, Block, Geometric, Misc symbols) は CJK fullwidth
     glyph が定着しているので JP font。eaw.cc の wide 範囲と揃える。 */
  if (cp < 0x2160)
    return FONT_LATIN;       /* General Punct, Currency, Letterlike, etc. */
  if (cp < 0x2300)
    return FONT_JP;          /* Roman numerals, Arrows, Math */
  if (cp < 0x2460)
    return FONT_LATIN;       /* Misc Technical */
  if (cp < 0x2700)
    return FONT_JP;          /* Enclosed + Box + Block + Geometric + Misc symbols */
  if (cp < 0x2E80)
    return FONT_LATIN;       /* Dingbats / Misc */

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

  /* Private Use Area (U+E000-F8FF): 記号用フォント。

     PUA に何の字形が来るかは font 側の取り決めで決まる。実際に置かれている
     のは Nerd Font 系のアイコンで、Powerline の三角 (U+E0B0-)、Devicons
     (U+E700-)、Codicons (U+EA60-)、Font Awesome (U+ED00-, U+F000-) などが
     この範囲に固まっている。本文用の font にこれらの glyph は無く、Latin に
     振っても豆腐になるだけなので、専用の枠を当てる。

     幅は 1 桁のまま (eaw.cc は PUA を Wide 扱いにしていない)。Nerd Font の
     Mono 版が 1 セル幅で作られているのと、モダンなターミナルがこの範囲を
     1 桁で数えるのに揃う。 */
  if (cp < 0xF900)
    return FONT_SYMBOL;

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

  /* Supplementary Private Use Area-A/B。Nerd Font の Material Design Icons
     (U+F0001-U+F1AF0) がここにある。 */
  if (cp >= 0xF0000)
    return FONT_SYMBOL;

  /* SMP 以上 (絵文字・CJK 拡張等): とりあえず JP */
  return FONT_JP;
}
