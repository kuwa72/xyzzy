#include "stdafx.h"
#include "ed.h"

lisp
Fstandard_char_p (lisp cc)
{
  check_char (cc);
  ucs4_t c = xchar_code (cc);
  return boole (c == '\n' || (c >= ' ' && c < CC_DEL));
}

lisp
Fgraphic_char_p (lisp cc)
{
  check_char (cc);
  ucs4_t c = xchar_code (cc);
#if 0
  return boole ((c >= ' ' && c < CC_DEL)
                || kana_char_p (c)
                || (SJISP (c >> 8) && SJIS2P (c & 0xff))
                || cs_char_charset_bit (c) & (CCSF_ISO8859 | CCSF_JISX0212 \
                                              | CCSF_KSC5601 | CCSF_GB2312 \
                                              | CCSF_BIG5));
#else
  if ((c >= ' ' && c < CC_DEL) || kana_char_p (c))
    return Qt;
  if (c < 0x100)
    return Qnil;
  if (code_charset_bit (c) & ccsf_utf16_surrogate)
    return Qnil;
  /* Phase 2: Char は UTF-16 code unit。surrogate half は non-graphic。
     D600-D7FF (旧 internal encoding の undef_char 域) は正当な Unicode
     コードポイントなので graphic 扱いにする。 */
  return Qt;
#endif
}

lisp
Falpha_char_p (lisp cc)
{
  check_char (cc);
  return boole (alpha_char_p (xchar_code (cc)));
}

lisp
Fupper_case_p (lisp cc)
{
  check_char (cc);
  return boole (upper_char_p (xchar_code (cc)));
}

lisp
Flower_case_p (lisp cc)
{
  check_char (cc);
  return boole (lower_char_p (xchar_code (cc)));
}

lisp
Fboth_case_p (lisp cc)
{
  check_char (cc);
  return boole (alpha_char_p (xchar_code (cc)));
}

lisp
Fdigit_char_p (lisp cc, lisp radix)
{
  check_char (cc);
  int r = (radix && radix != Qnil) ? fixnum_value (radix) : 10;
  int n = digit_char (xchar_code (cc));
  return n < r ? make_fixnum (n) : Qnil;
}

lisp
Falphanumericp (lisp cc)
{
  check_char (cc);
  return boole (alphanumericp (xchar_code (cc)));
}

lisp
Fcharacter (lisp object)
{
  if (charp (object))
    return object;
  if (symbolp (object) && xstring_length (xsymbol_name (object)) == 1)
    return make_char (xstring_contents (xsymbol_name (object)) [0]);
  if (stringp (object) && xstring_length (object) == 1)
    return make_char (xstring_contents (object) [0]);
  return FEprogram_error (Ecannot_coerce_to_character, object);
}

lisp
Fchar_eql (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = xchar_code (first);
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      if (x != xchar_code (xcar (rest)))
        return Qnil;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_eql (lisp args)
{
  int nargs = 0;
  for (lisp p = args; consp (p); p = xcdr (p), nargs++)
    {
      check_char (xcar (p));
      QUIT;
    }

  switch (nargs)
    {
    case 0:
      return FEtoo_few_arguments ();

    case 1:
      return Qt;

    case 2:
      return boole (xchar_code (xcar (args)) != xchar_code (xcar (xcdr (args))));

    default:
      for (lisp p = args; consp (p); p = xcdr (p))
        for (lisp q = args; consp (q); q = xcdr (q))
          if (p != q && xchar_code (xcar (p)) == xchar_code (xcar (q)))
            return Qnil;
      return Qt;
    }
}

lisp
Fchar_less (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = xchar_code (first);
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = xchar_code (xcar (rest));
      if (x >= y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_greater (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = xchar_code (first);
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = xchar_code (xcar (rest));
      if (x <= y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_greater (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = xchar_code (first);
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = xchar_code (xcar (rest));
      if (x > y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_less (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = xchar_code (first);
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = xchar_code (xcar (rest));
      if (x < y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_equal (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = char_upcase (xchar_code (first));
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      if (x != char_upcase (xchar_code (xcar (rest))))
        return Qnil;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_equal (lisp args)
{
  int nargs = 0;
  for (lisp p = args; consp (p); p = xcdr (p), nargs++)
    {
      check_char (xcar (p));
      QUIT;
    }

  switch (nargs)
    {
    case 0:
      return FEtoo_few_arguments ();

    case 1:
      return Qt;

    case 2:
      return boole (char_upcase (xchar_code (xcar (args)))
                    != char_upcase (xchar_code (xcar (xcdr (args)))));

    default:
      for (lisp p = args; consp (p); p = xcdr (p))
        for (lisp q = args; consp (q); q = xcdr (q))
          if (p != q
              && (char_upcase (xchar_code (xcar (p)))
                  == char_upcase (xchar_code (xcar (q)))))
            return Qnil;
      return Qt;
    }
}

lisp
Fchar_lessp (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = char_upcase (xchar_code (first));
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = char_upcase (xchar_code (xcar (rest)));
      if (x >= y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_greaterp (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = char_upcase (xchar_code (first));
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = char_upcase (xchar_code (xcar (rest)));
      if (x <= y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_greaterp (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = char_upcase (xchar_code (first));
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = char_upcase (xchar_code (xcar (rest)));
      if (x > y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_not_lessp (lisp first, lisp rest)
{
  check_char (first);
  ucs4_t x = char_upcase (xchar_code (first));
  for (; consp (rest); rest = xcdr (rest))
    {
      check_char (xcar (rest));
      ucs4_t y = char_upcase (xchar_code (xcar (rest)));
      if (x < y)
        return Qnil;
      x = y;
      QUIT;
    }
  return Qt;
}

lisp
Fchar_code (lisp cc)
{
  check_char (cc);
  return make_fixnum (xchar_code (cc));
}

lisp
Fcode_char (lisp code)
{
  /* A character holds a full code point now, so do not truncate to 16 bits:
     that is what turned (code-char 128512) into char-code 62976.

     Every code below char-code-limit names a character, surrogate halves
     included: buffer text is UTF-16 code units and an unpaired surrogate can
     turn up in one, so it has to be nameable. Returning nil for those broke
     charname.l, which walks the whole range. */
  long c = fixnum_value (code);
  if (c < 0 || c >= CHAR_LIMIT)
    return Qnil;
  return make_char (ucs4_t (c));
}

lisp
Fchar_upcase (lisp cc)
{
  check_char (cc);
  return make_char (char_upcase (xchar_code (cc)));
}

lisp
Fchar_downcase (lisp cc)
{
  check_char (cc);
  return make_char (char_downcase (xchar_code (cc)));
}

lisp
Fdigit_char (lisp weight, lisp radix)
{
  int w = fixnum_value (weight);
  int r = (radix && radix != Qnil) ? fixnum_value (radix) : 10;
  return ((r >= 2 && r <= 36 && w >= 0 && w < r)
          ? make_char (upcase_digit_char[w]) : Qnil);
}

lisp
Fset_meta_bit (lisp cc, lisp f)
{
  check_char (cc);
  ucs4_t c = xchar_code (cc);
  if (f != Qnil)
    {
      if (ascii_char_p (c))
        c = char_to_meta_char (c);
      else if (function_char_p (c))
        c = function_to_meta_function (c);
    }
  else
    {
      if (meta_char_p (c))
        c = meta_char_to_char (c);
      else if (meta_function_char_p (c))
        c = meta_function_to_function (c);
    }
  return make_char (c);
}

lisp
Fdbc_first_byte_p (lisp x)
{
  int n = fixnum_value (x);
  return boole (n < 0x100 && SJISP (n));
}

lisp
Fdbc_second_byte_p (lisp x)
{
  int n = fixnum_value (x);
  return boole (n < 0x100 && SJIS2P (n));
}

lisp
Fkanji_char_p (lisp x)
{
  check_char (x);
  return boole (kanji_char_p (xchar_code (x)));
}

lisp
Fkana_char_p (lisp x)
{
  check_char (x);
  return boole (kana_char_p (xchar_code (x)));
}

lisp
Fchar_unicode (lisp cc)
{
  check_char (cc);
  /* Phase 2: 内部 Char は UTF-16 code unit。BMP char は値そのものが
     code point。surrogate half は単独では完全な code point にならず、
     char object 1 個からは復元不能なので nil。
     BMP の判定を先に置くこと: utf16_surrogate_*_p は ucs2_t を取るので
     code point を渡すと切り詰まり、U+1D800 等が nil になってしまう。 */
  ucs4_t c = xchar_code (cc);
  if (c < 0x10000
      && (utf16_surrogate_high_p (ucs2_t (c))
          || utf16_surrogate_low_p (ucs2_t (c))))
    return Qnil;
  return make_fixnum (c);
}

lisp
Funicode_char (lisp code)
{
  ucs4_t wc = fixnum_value (code);
  if (wc >= UNICODE_CHAR_LIMIT)
    return Qnil;

  /* A character holds a full code point, so a non-BMP code point is a
     character like any other. This used to return a two-element surrogate
     string instead, which made unicode-char the odd one out: char-unicode
     round-trips a non-BMP character, code-char takes the same number, and
     cmds.l's C-q u path feeds the result straight into insert as a
     character.

     A surrogate half is still nil: it is not a code point. code-char does
     name them (buffer text is UTF-16 code units, so an unpaired half has to
     be nameable), but unicode-char is the code-point door.

     The BMP guard matters: utf16_surrogate_*_p take a ucs2_t, so handing
     them a code point truncates it, and U+1D800 would come out nil. */
  if (wc < 0x10000
      && (utf16_surrogate_high_p (ucs2_t (wc))
          || utf16_surrogate_low_p (ucs2_t (wc))))
    return Qnil;
  return make_char (wc);
}

lisp
Fiso_char_code (lisp lcc, lisp vender)
{
  check_char (lcc);
  /* Initialize the secondary value before any early return path so that
     callers reading value(1) (e.g. Fiso_char_charset) don't see stale
     data from a previous call. The DEFCHAR early-return below otherwise
     leaves whatever happened to be in value(1) from the prior caller. */
  multiple_value::count () = 2;
  multiple_value::value (1) = Qnil;
  Char cc = xchar_code (lcc);
  if (cc != DEFCHAR)
    {
      cc = (*select_vender_code_mapper (to_vender_code (vender)))(cc);
      if (cc == DEFCHAR)
        return Qnil;
    }
  int ccs = code_charset (cc);
  switch (ccs)
    {
      int c1, c2;
    case ccs_usascii:
      multiple_value::value (1) = Kus_ascii;
      return make_fixnum (cc);

    case ccs_jisx0201_kana:
      if (!kana_char_p (cc))
        return Qnil;
      multiple_value::value (1) = Kjisx0201_kana;
      return make_fixnum (cc);

    case ccs_iso8859_1:
    case ccs_iso8859_2:
    case ccs_iso8859_3:
    case ccs_iso8859_4:
    case ccs_iso8859_5:
    case ccs_iso8859_7:
    case ccs_iso8859_9:
    case ccs_iso8859_10:
    case ccs_iso8859_13:
      {
        static const lisp *const ccs2obj[] =
          {
            &Kiso8859_1,
            &Kiso8859_2,
            &Kiso8859_3,
            &Kiso8859_4,
            &Kiso8859_5,
            &Kiso8859_7,
            &Kiso8859_9,
            &Kiso8859_10,
            &Kiso8859_13,
          };
        multiple_value::value (1) = *ccs2obj[ccs - ccs_iso8859_1];
        return make_fixnum (128 | (cc & 127));
      }

    case ccs_jisx0212:
      if (cc > CCS_JISX0212_MAX)
        return Qnil;
      multiple_value::value (1) = Kjisx0212;
      int_to_jisx0212 (cc, c1, c2);
      return make_fixnum ((c1 << 8) | c2);

    case ccs_gb2312:
      if (cc > CCS_GB2312_MAX)
        return Qnil;
      multiple_value::value (1) = Kgb2312;
      int_to_gb2312 (cc, c1, c2);
      return make_fixnum ((c1 << 8) | c2);

    case ccs_ksc5601:
      if (cc > CCS_KSC5601_MAX)
        return Qnil;
      multiple_value::value (1) = Kksc5601;
      int_to_ksc5601 (cc, c1, c2);
      return make_fixnum ((c1 << 8) | c2);

    case ccs_big5:
      if (cc > CCS_BIG5_MAX)
        return Qnil;
      multiple_value::value (1) = Kbig5;
      int_to_big5 (cc, c1, c2);
      return make_fixnum ((c1 << 8) | c2);

    default:
      c1 = cc >> 8;
      c2 = cc & 255;
      if (!SJISP (c1) || !SJIS2P (c2))
        return Qnil;
      multiple_value::value (1) = Kjisx0208;
      s2j (c1, c2);
      if (c1 >= 95 + 32)
        {
          if (c1 < 105 + 32)
            c1 -= 10;
          else if (c1 < 115 + 32)
            {
              c1 -= 20;
              multiple_value::value (1) = Kjisx0212;
            }
          else
            return Qnil;
        }
      return make_fixnum ((c1 << 8) | c2);
    }
}

lisp
Fiso_code_char (lisp code, lisp charset, lisp vender)
{
  /* Map (code, charset) → legacy internal encoding value, then to UTF-16 via
     i2w. Phase 2 buffer Char is a UTF-16 code unit, so make_char must receive
     a Unicode code point — not a CP932/JIS/CCS slot value as it used to. */
  Char cc = (Char)fixnum_value (code);
  Char internal;
  if (charset == Kus_ascii)
    internal = cc & 127;
  else if (charset == Kjisx0201_kana)
    internal = (cc & 127) | 128;
  else if (charset == Kiso8859_1)
    internal = Char ((cc & 127) | (ccs_iso8859_1 << 7));
  else if (charset == Kiso8859_2)
    internal = Char ((cc & 127) | (ccs_iso8859_2 << 7));
  else if (charset == Kiso8859_3)
    internal = Char ((cc & 127) | (ccs_iso8859_3 << 7));
  else if (charset == Kiso8859_4)
    internal = Char ((cc & 127) | (ccs_iso8859_4 << 7));
  else if (charset == Kiso8859_5)
    internal = Char ((cc & 127) | (ccs_iso8859_5 << 7));
  else if (charset == Kiso8859_7)
    internal = Char ((cc & 127) | (ccs_iso8859_7 << 7));
  else if (charset == Kiso8859_9)
    internal = Char ((cc & 127) | (ccs_iso8859_9 << 7));
  else if (charset == Kiso8859_10)
    internal = Char ((cc & 127) | (ccs_iso8859_10 << 7));
  else if (charset == Kiso8859_13)
    internal = Char ((cc & 127) | (ccs_iso8859_13 << 7));
  else
    {
      int c1 = cc >> 8, c2 = cc & 255;
      if (charset == Kbig5)
        {
          if (!((c1 >= 0xa1 && c1 <= 0xf8 && c1 != 0xc8)
                && ((c2 >= 0x40 && c2 <= 0x7e) || (c2 >= 0xa1 && c2 <= 0xfe))))
            return Qnil;
          internal = big5_to_int (c1, c2);
        }
      else
        {
          c1 &= 127;
          c2 &= 127;
          if (c1 <= 0x20 || c1 == 0x7f || c2 <= 0x20 || c2 == 0x7f)
            return Qnil;
          if (charset == Kjisx0208)
            {
              if (c1 >= 0x75
                  && vender_depend_code (to_vender_code (vender)) == ENCODING_ISO_VENDER_OSFJVC)
                c1 += 10;
              internal = (j2sh (c1, c2) << 8) | j2sl (c1, c2);
            }
          else if (charset == Kjisx0212)
            internal = jisx0212_to_internal (c1, c2,
                                             (vender_depend_code (to_vender_code (vender))));
          else if (charset == Kgb2312)
            internal = gb2312_to_int (c1, c2);
          else if (charset == Kksc5601)
            internal = ksc5601_to_int (c1, c2);
          else if (charset == Kbig5_1)
            {
              mule_g2b (ccs_big5_1, c1, c2);
              internal = big5_to_int (c1, c2);
            }
          else if (charset == Kbig5_2)
            {
              mule_g2b (ccs_big5_2, c1, c2);
              internal = big5_to_int (c1, c2);
            }
          else if (charset == Kcns11643_1)
            {
              init_cns11643_table ();
              internal = cns11643_1_to_internal[c1 * 94 + c2 - (0x21 * 94 + 0x21)];
              if (internal == Char (-1))
                return Qnil;
            }
          else if (charset == Kcns11643_2)
            {
              init_cns11643_table ();
              internal = cns11643_2_to_internal[c1 * 94 + c2 - (0x21 * 94 + 0x21)];
              if (internal == Char (-1))
                return Qnil;
            }
          else
            return FEsimple_error (Eunknown_charset, charset);
        }
    }
  ucs2_t wc = i2w (internal);
  if (wc == ucs2_t (-1))
    return Qnil;
  return make_char (Char (wc));
}

lisp
Fiso_char_charset (lisp lcc, lisp vender)
{
  Fiso_char_code (lcc, vender);
  multiple_value::count () = 1;
  return multiple_value::value (1);
}

lisp
Fword_char_p (lisp lcc)
{
  check_char (lcc);
  return boole (word_state::char_category
                (xsyntax_table (selected_buffer ()->lsyntax_table),
                 xchar_code (lcc)) == word_state::WCword);
}
