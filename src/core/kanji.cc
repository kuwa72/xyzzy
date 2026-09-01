#include "stdafx.h"
#include "ed.h"
#include "StrBuf.h"
#include "safe_ptr.h"
#include "byte-stream.h"
#include "iso2022state.h"
#include "guess.h"

int
check_kanji2 (const char *string, u_int off)
{
  const u_char *s0, *se, *s;
  for (s0 = (u_char *)string, se = s0 + off, s = se;
       s-- > s0 && SJISP (*s);)
    ;
  return !((se - s) & 1);
}

static inline int
char_defined_p (Char c)
{
  ucs2_t w = i2w (c);
  return w != ucs2_t (-1) && !ucs2_PUA_p (w);
}

class iso2022_state
{
  u_char s_state;
  u_long s_charset;
public:
  iso2022_state () : s_state (0), s_charset (0) {}
  void update (int c)
    {
      s_state = iso2022state[iso2022state_chars[c]][s_state];
      if (s_state & ISO2022STATE_TERM)
        {
          s_charset |= 1 << (s_state & ISO2022STATE_MASK);
          s_state = 0;
        }
    }
  int ok () const {return s_charset;}
  lisp encoding () const;
};

lisp
iso2022_state::encoding () const
{
#define CCS_MATCH(CCS, MASK)  (((CCS) & (MASK)) == (CCS))
  int cjk = ENCODING_LANG_NIL;
  if (CCS_MATCH (s_charset, (1 << ccs_usascii) | (1 << ccs_jisx0201_kana) | (1 << ccs_jisx0208)))
    cjk = ENCODING_LANG_JP;
  else if (CCS_MATCH (s_charset, (1 << ccs_usascii) | (1 << ccs_jisx0201_kana)
                      | (1 << ccs_jisx0208) | (1 << ccs_jisx0212)))
    cjk = ENCODING_LANG_JP2;
  else if (CCS_MATCH (s_charset, (1 << ccs_usascii) | (1 << ccs_ksc5601)))
    cjk = ENCODING_LANG_KR;
  else if (CCS_MATCH (s_charset, ((1 << ccs_usascii) | (1 << ccs_gb2312)
                                  | (1 << ccs_cns11643_1) | (1 << ccs_cns11643_2))))
    cjk = ENCODING_LANG_CN;
  else if (CCS_MATCH (s_charset, (1 << ccs_usascii) | (1 << ccs_gb2312)))
    cjk = ENCODING_LANG_CN_GB;
  else if (CCS_MATCH (s_charset, (1 << ccs_usascii) | (1 << ccs_big5_1) | (1 << ccs_big5_2)))
    cjk = ENCODING_LANG_CN_BIG5;

  lisp x = xsymbol_value (Vencoding_default_iso_2022);
  for (; consp (x); x = xcdr (x))
    {
      lisp p = xcar (x);
      if (char_encoding_p (p)
          && xchar_encoding_type (p) == encoding_iso2022
          && (xchar_encoding_iso_cjk (p) == cjk
              || xchar_encoding_iso_cjk (p) == ENCODING_LANG_NIL))
        return p;
    }

  x = xsymbol_value (Vencoding_default_iso_2022);
  if (consp (x))
    x = xcar (x);
  if (char_encoding_p (x) && xchar_encoding_type (x) != encoding_auto_detect)
    return x;
  return symbol_value_char_encoding (Vencoding_jis);
}

class euc_state
{
  enum estate
    {
      ES_NIL,
      ES_C1,
      ES_SS2,
      ES_SS3_1,
      ES_SS3_2
    };
  enum
    {
      F_JP = 1,
      F_KR = 2,
      F_GB = 4
    };
  estate s_state;
  int s_c1;
  int s_bad_char;
  int s_bad_range;
  int s_may_be_try;
  int s_may_be_sum;

  int good_charset_p (int) const;
public:
  euc_state ()
       : s_state (ES_NIL), s_bad_char (0), s_bad_range (0),
         s_may_be_try (0), s_may_be_sum (0) {}
  void update (int);
  int bad_range_p () const {return s_bad_range;}
  int bad_char_p () const {return s_bad_char == (F_JP | F_KR | F_GB);}
  int may_be () const {return s_may_be_sum >= 3;}
  lisp encoding (int) const;
};

int
euc_state::good_charset_p (int charset) const
{
  switch (charset)
    {
    case ccs_jisx0208:
      return !(s_bad_char & F_JP);

    case ccs_gb2312:
      return !(s_bad_char & F_GB);

    case ccs_ksc5601:
      return !(s_bad_char & F_KR);

    default:
      return 1;
    }
}

lisp
euc_state::encoding (int has_escseq) const
{
  lisp x;

  if (has_escseq)
    for (x = xsymbol_value (Vencoding_default_euc); consp (x); x = xcdr (x))
      {
        lisp p = xcar (x);
        if (char_encoding_p (p)
            && xchar_encoding_type (p) == encoding_iso2022
            && good_charset_p (xchar_encoding_iso_initial (p)[1]))
          return p;
      }

  for (x = xsymbol_value (Vencoding_default_euc); consp (x); x = xcdr (x))
    {
      lisp p = xcar (x);
      if (char_encoding_p (p)
          && (xchar_encoding_type (p) == encoding_iso2022
              || xchar_encoding_type (p) == encoding_iso2022_noesc)
          && good_charset_p (xchar_encoding_iso_initial (p)[1]))
        return p;
    }

  x = xsymbol_value (Vencoding_default_euc);
  if (consp (x))
    x = xcar (x);
  if (char_encoding_p (x) && xchar_encoding_type (x) != encoding_auto_detect)
    return x;
  return symbol_value_char_encoding (Vencoding_euc_jp);
}

void
euc_state::update (int c)
{
  if (s_bad_range)
    return;
  switch (s_state)
    {
    case ES_NIL:
      if (c >= 0xa1 && c <= 0xfe)
        {
          s_c1 = c;
          s_state = ES_C1;
        }
      else
        {
          s_may_be_try = 0;
          if (c >= 0x80)
            {
              if (c == CC_SS2)
                {
                  s_state = ES_SS2;
                  s_bad_char |= F_KR | F_GB;
                }
              else if (c == CC_SS3)
                {
                  s_state = ES_SS3_1;
                  s_bad_char |= F_KR | F_GB;
                }
              else
                s_bad_range = 1;
            }
        }
      break;

    case ES_C1:
      if (c < 0xa1 || c > 0xfe)
        s_bad_range = 1;
      else
        {
          if (s_bad_char != (F_JP | F_KR | F_GB))
            {
              int t1 = s_c1 & 127, t2 = c & 127;

              if (!(s_bad_char & F_JP)
                  && !char_defined_p ((j2sh (t1, t2) << 8) | j2sl (t1, t2)))
                s_bad_char |= F_JP;

              if (!(s_bad_char & F_KR)
                  && !char_defined_p (ksc5601_to_int (t1, t2)))
                s_bad_char |= F_KR;

              if (!(s_bad_char & F_GB)
                  && !char_defined_p (gb2312_to_int (t1, t2)))
                s_bad_char |= F_GB;
            }

          if (s_c1 <= 0xa5 && c <= 0xdf)
            {
              if (++s_may_be_try == 3)
                {
                  s_may_be_try = 0;
                  s_may_be_sum++;
                }
            }
          else
            s_may_be_try = 0;
        }
      s_state = ES_NIL;
      break;

    case ES_SS2:
      if (!kana_char_p (c))
        s_bad_range = 1;
      s_state = ES_NIL;
      break;

    case ES_SS3_1:
      if (c >= 0xa1 && c <= 0xfe)
        s_state = ES_SS3_2;
      else
        s_bad_range = 1;
      break;

    case ES_SS3_2:
      if (c >= 0xa1 && c <= 0xfe)
        {
          if (!(s_bad_char & F_JP))
            {
              if (s_c1 == 0xf4 || (s_c1 == 0xf3 && c >= 0xf3))
                ;
              else
                {
                  s_c1 &= 127;
                  c &= 127;
                  if (!char_defined_p (jisx0212_to_int (s_c1, c)))
                    s_bad_char |= F_JP;
                }
            }
          s_state = ES_NIL;
        }
      else
        s_bad_range = 1;
      break;
    }
}

class sjis_state
{
  int s_state;
  int s_c1;
  int s_bad_char;
  int s_bad_range;
public:
  sjis_state () : s_state (0), s_bad_char (0), s_bad_range (0) {}
  void update (int);
  int bad_range_p () const {return s_bad_range;}
  int bad_char_p () const {return s_bad_char;}
};

void
sjis_state::update (int c)
{
  if (s_bad_range)
    return;
  if (!s_state)
    {
      if (SJISP (c))
        {
          s_c1 = c;
          s_state = 1;
        }
      else if (c >= 0x80 && !kana_char_p (c))
        s_bad_range = 1;
    }
  else
    {
      if (!SJIS2P (c))
        s_bad_range = 1;
      else if (!char_defined_p ((s_c1 << 8) | c))
        s_bad_char = 1;
      s_state = 0;
    }
}

class utf8_state
{
  ucs4_t s_code;
  int s_nchars;
  int s_not;
  int s_accept_mule_ucs;
public:
  utf8_state ()
       : s_nchars (0), s_not (0),
         s_accept_mule_ucs (xsymbol_value (Vaccept_mule_ucs_funny_utf8) != Qnil) {}
  void update (int);
  int ok () const {return !s_not;}
};

void
utf8_state::update (int c)
{
  extern u_char utf8_chtab[];
  extern u_char utf8_chmask[];

  if (s_not)
    return;
  u_char nbits = utf8_chtab[c];
  c &= utf8_chmask[nbits];
  if (!s_nchars)
    {
      switch (nbits)
        {
        case 7:
          break;

        case 0:
        case 6:
          s_not = 1;
          break;

        default:
          s_code = c;
          s_nchars = 6 - nbits;
          break;
        }
    }
  else
    {
      if (nbits != 6 && (!s_accept_mule_ucs || nbits < 6))
        s_not = 1;
      else
        {
          s_code = (s_code << 6) | c;
          if (!--s_nchars && (s_code >= UNICODE_CHAR_LIMIT
                              || ucs2_t (s_code) == 0xffff
                              || ucs2_t (s_code) == 0xfffe))
            s_not = 1;
        }
    }
}

class big5_state
{
  int s_state;
  int s_not;
public:
  big5_state () : s_state (0), s_not (0) {}
  void update (int);
  int ok () const {return !s_not;}
};

void
big5_state::update (int c)
{
  if (s_not)
    return;

  if (!s_state)
    {
      if (c >= 0x80)
        {
          if (c >= 0xa1 && c <= 0xf8 && c != 0xc8)
            s_state = 1;
          else
            s_not = 1;
        }
    }
  else
    {
      if (c >= 0x40 && c <= 0x7e || c >= 0xa1 && c <= 0xfe)
        s_state = 0;
      else
        s_not = 1;
    }
}

static int
simple_unicode_p (const ucs2_t *w, int l)
{
  if (!l)
    return 0;
  for (const ucs2_t *we = w + l; w < we; w++)
    switch (*w)
      {
      case 0xffff:
      case 0xfffe:
      case 0x00ff:
      case 0x0a0d:
        return 0;
      }
  return 1;
}

static int
simple_rev_unicode_p (const ucs2_t *w, int l)
{
  if (!l)
    return 0;
  for (const ucs2_t *we = w + l; w < we; w++)
    switch (*w)
      {
      case 0xffff:
      case 0xfeff:
      case 0xff00:
      case 0x0a0d:
        return 0;
      }
  return 1;
}

static lisp
judge_char_encoding (const iso2022_state &iso2022, const euc_state &euc,
                     const sjis_state &sjis, const utf8_state &utf8,
                     const big5_state &big5,
                     int sum, const char *string, int size)
{
  if (!(sum & 0x80))
    return iso2022.ok () ? iso2022.encoding () : Qnil;

  int type = 0;
  if (!sjis.bad_range_p ())
    type |= DCE_SJIS;
  if (!euc.bad_range_p ())
    type |= DCE_EUC;

  switch (type)
    {
    case DCE_SJIS | DCE_EUC:
      if (!sjis.bad_char_p () && euc.bad_char_p ())
        return symbol_value_char_encoding (Vencoding_sjis);
      if (sjis.bad_char_p () && !euc.bad_char_p ())
        return euc.encoding (iso2022.ok ());
      return (euc.may_be ()
              ? euc.encoding (iso2022.ok ())
              : symbol_value_char_encoding (Vencoding_sjis));

    case DCE_SJIS:
      if (sjis.bad_char_p () && utf8.ok ()
          && utf8_signature_p (string, size))
        return symbol_value_char_encoding (Vencoding_default_utf8);
      return symbol_value_char_encoding (Vencoding_sjis);

    case DCE_EUC:
      return euc.encoding (iso2022.ok ());

    default:
      if (utf8.ok ())
        return (utf8_signature_p (string, size)
                ? symbol_value_char_encoding (Vencoding_default_utf8)
                : symbol_value_char_encoding (Vencoding_default_utf8n));
      if (big5.ok ())
        return symbol_value_char_encoding (Vencoding_big5);
      return Qnil;
    }
}

static lisp
detect_char_encoding_xyzzy (const char *string, int size, int real_size)
{
  if (size >= 2 && !(real_size & 1))
    {
      /* **LE も BE と同じ `simple_*_unicode_p` で見る。** ここは
         `!sysdep.WinNTp () ? simple_unicode_p (...) : IsTextUnicode (...)`
         と書いてあった。Win9x では `IsTextUnicode` が当てにならないので
         自前で見て、NT では API に任せる、という Win9x 時代の分岐である。

         **POSIX では `IsTextUnicode` が常に FALSE を返すスタブ**で、
         `WinNTp ()` は偽の `GetVersionExW` のおかげで真になるので、
         **UTF-16LE の BOM 付きファイルが一度も判定されなかった**
         (issue #204 と同じ「呼ばれているのに no-op」の類、issue #205)。
         すぐ下の BE の枝には `simple_rev_unicode_p` という本物の判定が
         あるので、**BE は判定されるのに LE は判定されない**という非対称に
         なっていた。

         **直し方として「POSIX だけ `simple_unicode_p`」は選ばなかった。**
         core に `#ifdef` を増やすことになる (issue #16 の方針) 上に、
         **BOM が既にある場所で `IsTextUnicode` の統計的な判定を通す必要が
         そもそも無い。** BE の枝がまさにそう書かれていて、この 2 つが
         非対称だったこと自体がおかしい。

         **Win32 の挙動は変わる。** `IsTextUnicode` は引数 0 で「全部の
         テストを行う」意味になり、**本物の UTF-16 を弾くことがある**
         (有名な "Bush hid the facts" と同じ性質)。変わる方向は
         「BOM 付きの UTF-16LE を弾かなくなる」側だけである。 */
      if (*(u_short *)string == UNICODE_BOM
          && simple_unicode_p ((const ucs2_t *)string, size / sizeof (ucs2_t)))
        return symbol_value_char_encoding (Vencoding_default_utf16le_bom);
      else if (*(u_short *)string == UNICODE_REVBOM
               && simple_rev_unicode_p ((const ucs2_t *)string, size / sizeof (ucs2_t)))
        return symbol_value_char_encoding (Vencoding_default_utf16be_bom);
    }

  iso2022_state iso2022;
  euc_state euc;
  sjis_state sjis;
  utf8_state utf8;
  big5_state big5;
  int sum = 0;
  for (const u_char *s = (const u_char *)string, *se = s + size; s < se; s++)
    {
      int c = *s;
      iso2022.update (c);
      euc.update (c);
      sjis.update (c);
      utf8.update (c);
      big5.update (c);
      sum |= c;
    }

  return judge_char_encoding (iso2022, euc, sjis, utf8, big5, sum, string, size);
}

static lisp
detect_char_encoding_xyzzy (lisp string)
{
  xstream_ibyte_helper is (string);

  iso2022_state iso2022;
  euc_state euc;
  sjis_state sjis;
  utf8_state utf8;
  big5_state big5;
  int sum = 0;
  int c;
  char buf[3];
  int nb = 0;
  while ((c = is->get ()) != xstream::eof)
    {
      iso2022.update (c);
      euc.update (c);
      sjis.update (c);
      utf8.update (c);
      big5.update (c);
      sum |= c;
      if (nb < sizeof buf)
        buf[nb++] = c;
    }

  return judge_char_encoding (iso2022, euc, sjis, utf8, big5, sum, buf, nb);
}

static lisp
detect_char_encoding_libguess (const char *string, int size, int real_size)
{
  if (!string || size == 0)
    return Qnil;
  return Fdetect_char_encoding (make_string_simple (string, size));
}

static lisp
detect_char_encoding_libguess (lisp string)
{
#define score xcdr
#define encoding xcar
  // r == ((<encoding> . <score>) (<encoding> . <score>) ...)

  lisp r = Fguess_char_encoding (string);
  if (r == Qnil)
    return Qnil;

  if (xlist_length (r) == 1)
    return encoding (xcar (r));

  // 曖昧な場合は一番高いスコアのエンコーディングを返す。
  // 一番高いスコアが複数ある場合は nil を返す。
  lisp top = Qnil;
  for (; consp (r); r = xcdr (r))
    {
      lisp x = xcar (r);
      // sjis の半角カナだけだと big5 のスコアが高くなるので
      // 曖昧な場合は big5 は無視して判定する。
      if (xchar_encoding_type (encoding (x)) == encoding_big5)
          continue;

      if (top == Qnil || number_compare (score (xcar (top)), score (x)) < 0)
        top = xcons (x, Qnil);
      else if (number_compare (score (xcar (top)), score (x)) == 0)
        top = xcons (x, top);
    }

  size_t len = xlist_length (top);
  if (len == 1)
    return encoding (xcar (top));

  if (len == 2)
    {
      // sjis を utf-8 と誤認することはあまりないが、
      // utf-8 を sjis と誤認することが多いので、
      // sjis と utf-8 が同スコアの場合は utf-8 を優先する。
      lisp a = xcar (top);
      lisp b = Fcadr (top);
      if (xchar_encoding_type (encoding (a)) == encoding_sjis &&
          xchar_encoding_type (encoding (b)) == encoding_utf8)
        return encoding (b);
      if (xchar_encoding_type (encoding (b)) == encoding_sjis &&
          xchar_encoding_type (encoding (a)) == encoding_utf8)
        return encoding (a);
    }

  return Qnil;
#undef score
#undef encoding
}

lisp
detect_char_encoding (const char *string, int size)
{
  return detect_char_encoding (string, size, size);
}

lisp
detect_char_encoding (const char *string, int size, int real_size)
{
  lisp mode = xsymbol_value (Vdetect_char_encoding_mode);
  if (mode == Kxyzzy)
    return detect_char_encoding_xyzzy (string, size, real_size);
  else
    return detect_char_encoding_libguess (string, size, real_size);
}

lisp
Fdetect_char_encoding (lisp string)
{
  lisp mode = xsymbol_value (Vdetect_char_encoding_mode);
  if (mode == Kxyzzy)
    return detect_char_encoding_xyzzy (string);
  else
    return detect_char_encoding_libguess (string);
}

lisp
Fconvert_encoding_to_internal (lisp encoding, lisp input, lisp output)
{
  check_char_encoding (encoding);
  if (xchar_encoding_type (encoding) == encoding_auto_detect)
    FEtype_error (encoding, Qchar_encoding);
  xstream_ibyte_helper is (input);
  xstream_oChar_helper os (output);
  encoding_input_stream_helper s (encoding, is);
  copy_xstream (s, os);
  return os.result ();
}

lisp
Fconvert_encoding_from_internal (lisp encoding, lisp input, lisp output)
{
  check_char_encoding (encoding);
  if (xchar_encoding_type (encoding) == encoding_auto_detect)
    FEtype_error (encoding, Qchar_encoding);
  xstream_iChar_helper is (input);
  xstream_obyte_helper os (output);
  encoding_output_stream_helper s (encoding, is, eol_noconv);
  copy_xstream (s, os);
  return os.result ();
}

#include "kanjitab.h"

/* Full-/half-width conversion (`map-to-*-width-*`) — Unicode-native.

   Forward direction (halfwidth → fullwidth): halfwidth kana U+FF61-U+FF9F feeds
   `to_full{hira,kata}_ff61_ff9f`; ASCII 0x20-0x7E feeds `to_full_20_7e`. Voicing
   marks are absorbed in the backward compose pass that follows.

   Reverse direction (fullwidth → halfwidth): non-voiced fullwidth chars look up
   in `to_half_width_cjk` / `to_half_width_fullascii`. Voiced/semi-voiced
   fullwidth kana are detected via `voiced_to_half_cjk` / `semi_voiced_to_half_cjk`
   and emitted as {halfwidth base, ﾞ or ﾟ} pairs.                                */
struct to_half
{
  Char min, max;
  const Char *b;
};

static const to_half toh[] =
{
  {CJK_RANGE_MIN, CJK_RANGE_MAX, to_half_width_cjk},
  {FULL_ASCII_MIN, FULL_ASCII_MAX, to_half_width_fullascii},
};

#define ASC 1
#define HIRA 2
#define KATA 4

static int
map_flags (lisp keys)
{
  int flags = 0;
  if (find_keyword_bool (Kascii, keys, 0))
    flags |= ASC;
  if (find_keyword_bool (Khiragana, keys, 0))
    flags |= HIRA;
  if (find_keyword_bool (Kkatakana, keys, 0))
    flags |= KATA;
  return flags;
}

struct to_half_param
{
  int flags;
  Char skip_min, skip_max;   /* fullwidth range to preserve (other kana kind).  */
  to_half_param (lisp);
  bool should_skip (Char c) const { return c >= skip_min && c <= skip_max; }
  bool accept_half (Char c) const
    {
      if ((flags & ASC) && c >= 0x20 && c <= 0x7e)
        return true;
      if ((flags & (HIRA | KATA)) && c >= HALFWIDTH_KANA_MIN && c <= HALFWIDTH_KANA_MAX)
        return true;
      return false;
    }
};

to_half_param::to_half_param (lisp keys)
{
  flags = map_flags (keys);
  skip_min = 0xffff;
  skip_max = 0;
  if (!flags)
    return;
  switch (flags & (HIRA | KATA))
    {
    case HIRA:
      skip_min = FULL_WIDTH_KATAKANA_MIN;
      skip_max = FULL_WIDTH_KATAKANA_MAX;
      break;
    case KATA:
      skip_min = FULL_WIDTH_HIRAGANA_MIN;
      skip_max = FULL_WIDTH_HIRAGANA_MAX;
      break;
    }
}

lisp
Fmap_to_half_width_region (lisp from, lisp to, lisp keys)
{
  to_half_param thp (keys);
  if (!thp.flags)
    return Qnil;

  Window *wp = selected_window ();
  Buffer *bp = wp->w_bufp;
  point_t p2 = bp->prepare_modify_region (wp, from, to);
  if (p2 == -1)
    return Qt;
  wp->w_disp_flags |= Window::WDF_GOAL_COLUMN;

  Point &point = wp->w_point;
  point_t p1 = point.p_point;
  /* Forward pass: non-voiced fullwidth → halfwidth (single char replacement). */
  while (point.p_point < p2)
    {
      Char c = point.ch ();
      if (!thp.should_skip (c))
        for (int i = 0; i < numberof (toh); i++)
          if (c >= toh[i].min && c <= toh[i].max)
            {
              Char h = toh[i].b[c - toh[i].min];
              if (h && thp.accept_half (h))
                point.ch () = h;
              break;
            }
      if (!bp->forward_char (point, 1))
        break;
    }

  /* Backward pass: voiced/semi-voiced fullwidth kana → {halfwidth base, mark}. */
  if (thp.flags & (HIRA | KATA))
    {
      int nconv = 0;
      while (bp->forward_char (point, -1) && point.p_point >= p1)
        {
          Char c = point.ch ();
          if (thp.should_skip (c))
            continue;
          if (c < CJK_RANGE_MIN || c > CJK_RANGE_MAX)
            continue;
          Char base = voiced_to_half_cjk[c - CJK_RANGE_MIN];
          Char mark = HALFWIDTH_VOICED_MARK;
          if (!base)
            {
              base = semi_voiced_to_half_cjk[c - CJK_RANGE_MIN];
              mark = HALFWIDTH_SEMI_VOICED_MARK;
            }
          if (!base || !thp.accept_half (base) || !thp.accept_half (mark))
            continue;
          point.ch () = mark;
          if (!bp->insert_chars_internal (point, &base, 1, 1))
            {
              bp->post_buffer_modified (Kmodify, point, p1, p2 + nconv);
              FEstorage_error ();
            }
          bp->forward_char (point, -1);
          nconv++;
        }
      bp->goto_char (point, p2 + nconv);
    }

  bp->post_buffer_modified (Kmodify, point, p1, point.p_point);
  return Qt;
}

static int
to_full_flags (lisp keys)
{
  int flags = map_flags (keys);
  if ((flags & (HIRA | KATA)) == (HIRA | KATA))
    FEprogram_error (Ehiragana_and_katakana_are_both_specified);
  return flags;
}

lisp
Fmap_to_full_width_region (lisp from, lisp to, lisp keys)
{
  int flags = to_full_flags (keys);
  if (!flags)
    return Qnil;

  const Char *tof = flags & HIRA ? to_fullhira_ff61_ff9f : to_fullkata_ff61_ff9f;
  const Char *voiced_from = flags & HIRA ? voiced_from_hira : voiced_from_kata;
  const Char *semi_voiced_from = flags & HIRA ? semi_voiced_from_hira : semi_voiced_from_kata;
  Char compose_min = flags & HIRA ? FULL_WIDTH_HIRAGANA_MIN : FULL_WIDTH_KATAKANA_MIN;
  Char compose_max = flags & HIRA ? FULL_WIDTH_HIRAGANA_MAX : FULL_WIDTH_KATAKANA_MAX;

  Window *wp = selected_window ();
  Buffer *bp = wp->w_bufp;
  point_t p2 = bp->prepare_modify_region (wp, from, to);
  if (p2 == -1)
    return Qt;
  wp->w_disp_flags |= Window::WDF_GOAL_COLUMN;

  Point &point = wp->w_point;
  point_t p1 = point.p_point;
  /* Forward pass: halfwidth → fullwidth (1:1; halfwidth ﾞ/ﾟ become fullwidth ゛/゜
     that the backward pass below then consumes and composes with preceding kana). */
  while (point.p_point < p2)
    {
      Char c = point.ch ();
      if ((flags & (HIRA | KATA))
          && c >= HALFWIDTH_KANA_MIN && c <= HALFWIDTH_KANA_MAX)
        point.ch () = tof[c - HALFWIDTH_KANA_MIN];
      else if ((flags & ASC) && c >= 0x20 && c <= 0x7e)
        point.ch () = to_full_20_7e[c - 0x20];
      if (!bp->forward_char (point, 1))
        break;
    }

  /* Backward pass: absorb a ゛/゜ into the preceding unvoiced kana.               */
  if (flags & (HIRA | KATA))
    {
      int nconv = 0;
      while (bp->forward_char (point, -1) && point.p_point >= p1)
        {
          Char c = point.ch (), c2;
          if (c != VOICED_SOUND_MARK && c != SEMI_VOICED_SOUND_MARK)
            continue;
          while (1)
            {
              if (!bp->forward_char (point, -1) || point.p_point < p1)
                goto done;
              c2 = point.ch ();
              if (c2 != VOICED_SOUND_MARK && c2 != SEMI_VOICED_SOUND_MARK)
                break;
              c = c2;
            }
          if (c2 < compose_min || c2 > compose_max)
            continue;
          Char composed = (c == VOICED_SOUND_MARK
                           ? voiced_from[c2 - compose_min]
                           : semi_voiced_from[c2 - compose_min]);
          if (!composed)
            continue;
          if (!bp->delete_region_internal (point, point.p_point,
                                           point.p_point + 1))
            {
              bp->post_buffer_modified (Kmodify, point, p1, p2 + nconv);
              FEstorage_error ();
            }
          point.ch () = composed;
          nconv++;
        }
    done:
      bp->goto_char (point, p2 - nconv);
    }

  bp->post_buffer_modified (Kmodify, point, p1, point.p_point);
  return Qt;
}

lisp
Fmap_to_half_width_string (lisp string, lisp keys)
{
  check_string (string);

  to_half_param thp (keys);
  if (!thp.flags)
    return string;

  /* Worst case: every fullwidth voiced kana becomes 2 halfwidth chars.           */
  safe_ptr <ucs4_t> s0 (new ucs4_t [xstring_length (string) * 2]);
  memcpy (s0, xstring_contents (string), (xstring_length (string)) * sizeof (*(xstring_contents (string))));
  ucs4_t *s, *se;
  /* Forward pass: non-voiced fullwidth → halfwidth (in-place).                   */
  for (s = s0, se = s + xstring_length (string); s < se; s++)
    {
      ucs4_t c = *s;
      if (thp.should_skip (c))
        continue;
      for (int i = 0; i < numberof (toh); i++)
        if (c >= toh[i].min && c <= toh[i].max)
          {
            ucs4_t h = toh[i].b[c - toh[i].min];
            if (h && thp.accept_half (h))
              *s = h;
            break;
          }
    }

  if (!(thp.flags & (HIRA | KATA)))
    return make_string (s0, xstring_length (string));

  /* Backward voicing pass: decompose voiced kana into {base, mark}. Writes
     backward into the second half of the buffer to avoid slide.                  */
  ucs4_t *de = s0 + xstring_length (string) * 2;
  ucs4_t *d = de;
  for (s = s0; se > s;)
    {
      ucs4_t c = *--se;
      *--d = c;
      if (thp.should_skip (c))
        continue;
      if (c < CJK_RANGE_MIN || c > CJK_RANGE_MAX)
        continue;
      ucs4_t base = voiced_to_half_cjk[c - CJK_RANGE_MIN];
      ucs4_t mark = HALFWIDTH_VOICED_MARK;
      if (!base)
        {
          base = semi_voiced_to_half_cjk[c - CJK_RANGE_MIN];
          mark = HALFWIDTH_SEMI_VOICED_MARK;
        }
      if (!base || !thp.accept_half (base) || !thp.accept_half (mark))
        continue;
      *d = mark;
      *--d = base;
    }
  return make_string (d, de - d);
}

lisp
Fmap_to_full_width_string (lisp string, lisp keys)
{
  check_string (string);
  int flags = to_full_flags (keys);
  if (!flags)
    return string;

  const Char *tof = flags & HIRA ? to_fullhira_ff61_ff9f : to_fullkata_ff61_ff9f;
  const Char *voiced_from = flags & HIRA ? voiced_from_hira : voiced_from_kata;
  const Char *semi_voiced_from = flags & HIRA ? semi_voiced_from_hira : semi_voiced_from_kata;
  Char compose_min = flags & HIRA ? FULL_WIDTH_HIRAGANA_MIN : FULL_WIDTH_KATAKANA_MIN;
  Char compose_max = flags & HIRA ? FULL_WIDTH_HIRAGANA_MAX : FULL_WIDTH_KATAKANA_MAX;

  int n = xstring_length (string);
  safe_ptr <ucs4_t> s0 (new ucs4_t [n]);
  memcpy (s0, xstring_contents (string), (n) * sizeof (*(xstring_contents (string))));

  /* Forward pass: halfwidth → fullwidth (in-place; halfwidth ﾞ/ﾟ become ゛/゜).  */
  for (ucs4_t *s = s0, *se = s + n; s < se; s++)
    {
      ucs4_t c = *s;
      if ((flags & (HIRA | KATA))
          && c >= HALFWIDTH_KANA_MIN && c <= HALFWIDTH_KANA_MAX)
        *s = tof[c - HALFWIDTH_KANA_MIN];
      else if ((flags & ASC) && c >= 0x20 && c <= 0x7e)
        *s = to_full_20_7e[c - 0x20];
    }

  if (!(flags & (HIRA | KATA)))
    return make_string (s0, n);

  /* Compose pass: base + ゛/゜ → voiced. Build output by scanning forward;
     output length ≤ input length (never expands).                                */
  safe_ptr <ucs4_t> out (new ucs4_t [n]);
  ucs4_t *o = out;
  int i = 0;
  while (i < n)
    {
      ucs4_t c = s0[i];
      if (i + 1 < n
          && (s0[i + 1] == VOICED_SOUND_MARK || s0[i + 1] == SEMI_VOICED_SOUND_MARK)
          && c >= compose_min && c <= compose_max)
        {
          ucs4_t composed = (s0[i + 1] == VOICED_SOUND_MARK
                           ? voiced_from[c - compose_min]
                           : semi_voiced_from[c - compose_min]);
          if (composed)
            {
              *o++ = composed;
              i += 2;
              continue;
            }
        }
      *o++ = c;
      i++;
    }
  return make_string (out, o - out);
}
