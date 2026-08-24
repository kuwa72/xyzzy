// -*-C++-*-
#ifndef _char_h_
# define _char_h_

# include "chtype.h"
# include "charset.h"

inline lisp
make_char (ucs4_t c)
{
  return make_immediate (Lchar, c);
}

inline int
charp (lisp x)
{
  return immediate_tag (x) == Lchar;
}

inline ucs4_t
xchar_code (lisp x)
{
  assert (charp (x));
  return ucs4_t (ximmediate_data (x));
}

inline void
check_char (lisp x)
{
  if (!charp (x))
    FEtype_error (x, Qcharacter);
}

/* stream / keyboard から取った lChar を char object にする。

   Lisp の char は今も旧 Char encoding で、#\Up は CCF_UP (0xff05) の
   ことである (chname.cc)。一方 decode_keys は lc_from_ccf を通した新
   lChar encoding を queue に積むので、機能キーは LCKEY_UP (0x200005)
   のように kind field (bit 21-23) を持つ。

   ここで下位 16bit を取ると kind が落ちて LCKEY_UP が 0x0005 = #\C-e に
   なる。(read-char *keyboard*) が矢印キーを C-e と報告し、それを
   lookup-keymap や si:terminal-send-key に渡すと別のキーとして扱われる。
   ccf_from_lc で旧 encoding に戻す。

   修飾の付かない素の code point だけは変換を通さない。Char (16bit) に
   落とすと BMP 外の文字が function key の空間とぶつかるため
   (U+1F600 → 0xF600 = CCF_META)、そのまま渡す必要がある。 */
inline lisp
make_char_from_lchar (lChar c)
{
  if (LCHAR_KIND (c) == LCKIND_CHAR && !LCHAR_MODS (c) && c < CHAR_LIMIT)
    return make_char (ucs4_t (c));
  return make_char (ucs4_t (ccf_from_lc (c)));
}

#endif
