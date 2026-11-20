// -*-C++-*-
#ifndef _char_h_
# define _char_h_

# include "chtype.h"
# include "charset.h"

/* Lisp の char オブジェクトは即値のデータ部に lChar (kind + modifier +
   payload) をそのまま保持する。かつては旧 Char encoding (あるいは code
   point) を保持していたため、全角 U+FF00..U+FF3E が旧 function key の
   CCF_CHAR_MIN..MAX と数値で衝突し、#\？ と #\F17 が区別できなかった
   (issue #431)。lChar 化で kind が残るので区別できる。

   - LCKIND_CHAR の値には LCEXPLICIT_CHAR が立つ (chtype.h 参照)
   - function key / meta function / pseudo ctlchar は lc_from_ccf を
     通した lChar (kind=FNKEY 等) として保持される
   - xchar_code は互換のため旧 encoding の数値を返す */

/* kind==CHAR の lChar に LCEXPLICIT_CHAR を保証した形に正規化する。
   make_char_from_lchar / make_char_key の共通後処理。 */
inline lChar
lchar_char_tag (lChar lc)
{
  return LCHAR_KIND (lc) == LCKIND_CHAR ? lc | LCEXPLICIT_CHAR : lc;
}

inline lisp
make_char (ucs4_t c)
{
  /* code point をそのまま持つ文字。呼び出し側が旧 Char encoding の値
     (CCF_*、meta char、pseudo ctlchar) を渡す場合は make_char_key を使う。 */
  return make_immediate (Lchar, lchar_char_tag (LCKIND_CHAR | lChar (c)));
}

/* 旧 Char encoding の値から char オブジェクトを作る。
   リーダの #\F1 やキーマップの要素など、機能キーを指す char 用。 */
inline lisp
make_char_key (Char c)
{
  return make_immediate (Lchar, lchar_char_tag (lc_from_ccf (c)));
}

inline int
charp (lisp x)
{
  return immediate_tag (x) == Lchar;
}

/* char オブジェクトが保持する lChar (kind + modifier + payload) を返す。
   キー判定・表示で「文字か機能キーか」を区別したいときはこちらを使う。

   32bit 環境では immediate data が 28bit しかなく LCEXPLICIT_CHAR
   (bit 28) が格納時に落ちるので、kind=CHAR ならここで必ず立て直す。
   64bit では冪等。 */
inline lChar
xchar_lchar (lisp x)
{
  assert (charp (x));
  return lchar_char_tag (lChar (ximmediate_data (x)));
}

inline ucs4_t
xchar_code (lisp x)
{
  assert (charp (x));
  lChar lc = xchar_lchar (x);
  /* 素の文字は code point をそのまま返す (BMP 外も切り詰めない)。
     それ以外 (function key、meta 付き) は旧 encoding に戻して返す。
     どちらも従来の xchar_code と同じ数値になる。 */
  if (LCHAR_KIND (lc) == LCKIND_CHAR && !LCHAR_MODS (lc))
    return ucs4_t (LCHAR_PAYLOAD (lc));
  return ucs4_t (ccf_from_lc (lc));
}

inline void
check_char (lisp x)
{
  if (!charp (x))
    FEtype_error (x, Qcharacter);
}

/* stream / keyboard から取った lChar を char object にする。
   保持している lChar をそのまま入れるので kind (CHAR/FNKEY) が残り、
   全角文字と機能キーを区別できる (issue #431)。 */
inline lisp
make_char_from_lchar (lChar c)
{
  return make_immediate (Lchar, lchar_char_tag (c));
}

#endif
