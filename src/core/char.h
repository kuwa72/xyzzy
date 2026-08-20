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

   code point の範囲内ならそのまま渡す。Char (16bit) に落とすと BMP 外の
   文字が function key の空間とぶつかる (U+1F600 → 0xF600 = CCF_META)。
   範囲外 (機能キーや mouse の lChar encoding) は char として意味を持た
   ないので、従来どおり下位 16bit を使う。 */
inline lisp
make_char_from_lchar (lChar c)
{
  return make_char (c < CHAR_LIMIT ? ucs4_t (c) : ucs4_t (Char (c)));
}

#endif
