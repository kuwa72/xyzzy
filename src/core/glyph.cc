// glyph.cc — Glyph calculation functions extracted from frontend/win32/disp.cc
// These are platform-independent: buffer content → glyph_data conversion.
// Rendering (paint_*) remains in each frontend.

#include "stdafx.h"
#include "ed.h"
#include "binfo.h"
#include "syntaxinfo.h"
#include "jisx0212-hash.h"
#include "regex.h"
#include "eaw.h"
#include "fontmap.h"
#include "font.h"
#include "glyph.h"

#define MAX_KWDLEN 256

/* ASCII narrow 1 cell の補助。実体は glyph.h の glyph_ascii_cell。 */
static inline glyph_t
ga (uint32_t cp)
{
  return glyph_ascii_cell (cp);
}

/* bitmap 1 cell の補助。bm は GLYPH_BM_* を期待。font_idx は paint で
   未使用だが書き込んでおく。width は呼び元で必要に応じて指定。 */
static inline glyph_t
gb (glyph_t bm)
{
  return bm | MAKE_GLYPH_FONT (FONT_ASCII) | GLYPH_WIDTH_NARROW;
}

/* UTF-16 surrogate pair 検出と code point 合成。p は high surrogate を
   既に *p++ で消費済の状態で呼ぶ。peek 範囲は同一 chunk 内に限定し、
   chunk 境界をまたぐ surrogate pair は high surrogate 単独として扱う
   (まれな edge case、Phase 3 で正規化候補)。
   return: 合成後の code point。p が surrogate pair 後半を消費した場合
           consumed = 1、それ以外 0。 */
static inline uint32_t
fold_surrogate (Char first, const Char *&p, const Char *pe, int &consumed)
{
  consumed = 0;
  if (first >= 0xD800 && first <= 0xDBFF
      && p < pe && *p >= 0xDC00 && *p <= 0xDFFF)
    {
      uint32_t cp = 0x10000u
                     + ((uint32_t (first) - 0xD800u) << 10)
                     + (uint32_t (*p) - 0xDC00u);
      p++;
      consumed = 1;
      return cp;
    }
  return first;
}

int
Buffer::next_char (Point &point) const
{
  Chunk *cp = point.p_chunk;
  if (point.p_offset == cp->c_used)
    return 0;
  point.p_point++;
  if (++point.p_offset == cp->c_used)
    {
      if (!cp->c_next)
        return 1;
      point.p_chunk = cp->c_next;
      point.p_offset = 0;
    }
  return 1;
}

#define KWD_PROP  1
#define KWD_FILL  2
#define KWD_KWD2  4

static int
kwd_val (int xval, int f, int &revkwd)
{
  if (xval < 0)
    return f;

  if (xval & KWD_PROP)
    {
      f |= xval & (((GLYPH_TEXTPROP_NCOLORS - 1)
                    << GLYPH_TEXTPROP_FG_SHIFT_BITS)
                   | ((GLYPH_TEXTPROP_NCOLORS - 1)
                      << GLYPH_TEXTPROP_BG_SHIFT_BITS)
                   | GLYPH_BOLD | GLYPH_UNDERLINE | GLYPH_STRIKEOUT);
      if (f & ((GLYPH_TEXTPROP_NCOLORS - 1)
               << GLYPH_TEXTPROP_FG_SHIFT_BITS))
        f |= GLYPH_TEXTPROP_FG_BIT;
    }
  else
    {
      int x = xval & (15 << GLYPH_COLOR_SHIFT_BITS);
      if (xsymbol_value (Vinhibit_reverse_keywords) != Qnil
          && x >= GLYPH_KEYWORD1R && x <= GLYPH_KEYWORD3R)
        x += GLYPH_KEYWORD1 - GLYPH_KEYWORD1R;
      f |= x | (xval & (GLYPH_BOLD | GLYPH_UNDERLINE | GLYPH_STRIKEOUT));
    }
  if (xval & KWD_FILL && !revkwd)
    revkwd = f & ~GLYPH_HIDDEN;
  return f;
}

static inline int
kwd_val (lisp x, int f, int &revkwd)
{
  return kwd_val (xshort_int_value (x), f, revkwd);
}

int
Window::kwdmatch (lisp kwdhash, const Char *p, const Chunk *cp,
                  int &symlen, int &revkwd, int defalt,
                  int &long_kwd, int kwdf) const
{
  const syntax_table *tab = xsyntax_table (w_bufp->lsyntax_table);

  Char cc = *p;
  if (!ascii_char_p (cc))
    {
      symlen = 0;
      long_kwd = 0;
      return defalt;
    }

  int f;
  int prefix = 0;
  switch (xchar_syntax (tab, cc))
    {
    case SCsymbol_prefix:
      prefix = 1;
      f = 0;
      break;

    case SCword:
    case SCsymbol:
    case SCescape:
      f = 0;
      break;

    case SCtag_start:
      f = GLYPH_HIDDEN;
      break;

    default:
      symlen = 0;
      long_kwd = 0;
      return defalt;
    }

  if (long_kwd)
    {
      symlen = 0;
      return defalt;
    }

  if (!f && !prefix)
    {
      Char pc;
      if (p != cp->c_text)
        pc = p[-1];
      else
        {
          const Chunk *prev = cp->c_prev;
          pc = prev ? prev->c_text[prev->c_used - 1] : Char (-1);
        }
      if (ascii_char_p (pc)
          && (xchar_syntax (tab, pc) == SCword
              || xchar_syntax (tab, pc) == SCsymbol))
        {
          symlen = 0;
          long_kwd = 0;
          return defalt;
        }
    }

  p++;
  const Char *pe = cp->c_text + cp->c_used;

  ucs4_t buf[MAX_KWDLEN];
  int l = 1, sl = 1;
  int f_pound = tab->flags & SYNTAX_OPT_CPP && cc == '#';
  buf[0] = cc;
  while (1)
    {
      if (p == pe)
        {
          cp = cp->c_next;
          if (!cp)
            break;
          p = cp->c_text;
          pe = p + cp->c_used;
        }
      cc = *p++;
      if (f_pound && (cc == ' ' || cc == '\t'))
        ;
      else
        {
          if (!ascii_char_p (cc)
              || (xchar_syntax (tab, cc) != SCword
                  && xchar_syntax (tab, cc) != SCsymbol))
            break;
          if (sl < numberof (buf))
            buf[sl] = cc;
          else
            {
              long_kwd = 1;
              break;
            }
          sl++;
          f_pound = 0;
        }
      l++;
    }

  symlen = l;
  if (sl < numberof (buf))
    {
      temporary_string t (buf, sl);
      lisp x = gethash (t.string (), kwdhash, Qnil);
      if (x != Qnil)
        {
          if (!short_int_p (x))
            {
              if (!(kwdf & syntax_state::KWD_OK))
                goto nomatch;
              return f;
            }
          int xval = xshort_int_value (x);
          if (!(kwdf & syntax_state::KWD_OK) && (xval < 0 || !(xval & KWD_KWD2)))
            goto nomatch;
          f &= ~KWD_KWD2;
          return kwd_val (x, f, revkwd);
        }
    }
nomatch:
  if (f & GLYPH_HIDDEN)
    symlen = 1;
  return defalt;
}

int
Window::kwdmatch (lisp kwdhash, const Point &point,
                  int &symlen, int &revkwd, int &long_kwd, int kwdf) const
{
  const syntax_table *tab = xsyntax_table (w_bufp->lsyntax_table);
  const Chunk *cp = point.p_chunk;
  const Char *p = cp->c_text + point.p_offset;
  int tag = 0;
  Char cc = *p;
  int l = 0;
  int f;
  int sym = (ascii_char_p (cc)
             && (xchar_syntax (tab, cc) == SCword
                 || xchar_syntax (tab, cc) == SCsymbol));
  if (sym)
    {
      for (;; l++)
        {
          if (l == MAX_KWDLEN)
            {
              long_kwd = 1;
              symlen = 0;
              return 0;
            }
          if (p == cp->c_text)
            {
              if (!cp->c_prev)
                break;
              cp = cp->c_prev;
              p = cp->c_text + cp->c_used;
            }
          cc = *--p;
          if (ascii_char_p (cc))
            {
              switch (xchar_syntax (tab, cc))
                {
                case SCtag_start:
                  tag = 1;
                  l++;
                  goto end;

                case SCescape:
                case SCsymbol_prefix:
                  l++;
                  goto end;

                case SCword:
                case SCsymbol:
                  continue;
                }
            }
          if (++p == cp->c_text + cp->c_used)
            {
              cp = cp->c_next;
              p = cp->c_text;
            }
          break;
        }
    end:
      if (!l)
        return 0;
      f = kwdmatch (kwdhash, p, cp, symlen, revkwd, 0, long_kwd, kwdf);
    }
  else
    f = 0;

  if (tab->flags & SYNTAX_OPT_CPP && !f)
    {
      const Chunk *cq = cp;
      const Char *q = p;
      int qs = 0;
      int lq = 0;
      while (1)
        {
          if (q == cq->c_text)
            {
              if (!cq->c_prev)
                break;
              cq = cq->c_prev;
              q = cq->c_text + cq->c_used;
            }
          cc = *--q;
          lq++;
          if (cc == '#')
            {
              qs++;
              break;
            }
          if (cc != ' ' && cc != '\t')
            break;
          if (lq == MAX_KWDLEN)
            {
              long_kwd = 1;
              symlen = 0;
              return 0;
            }
          qs = 1;
        }
      if (qs == 2 && (f = kwdmatch (kwdhash, q, cq, symlen,
                                    revkwd, 0, long_kwd, kwdf)))
        l += lq;
    }
  if (!f && tag && l > 1)
    {
      if (++p == cp->c_text + cp->c_used)
        {
          cp = cp->c_next;
          p = cp->c_text;
        }
      l--;
      f = kwdmatch (kwdhash, p, cp, symlen, revkwd, 0, long_kwd, kwdf);
    }
  f &= ~GLYPH_HIDDEN;
  symlen -= l;
  return f;
}

glyph_t *
glyph_dbchar (glyph_t *g, uint32_t cp, int f, int flags)
{
  /* 5b-2: cp は wide (display width 2) と判明した Unicode code point。
     gd_cc 配列は「1 column = 1 cell」の旧レイアウトを 5b-2 では維持し、
     wide は 2 cell を消費する: 先頭に code_point + width=WIDE、後続 cell
     は同 cp + JUNK trail (paint 側 5b-3 が JUNK で skip 判定する想定)。 */

  int font_idx = get_font_idx (cp);

  if (cp == 0x3000 && (flags & Window::WF_FULLSPC))
    {
      /* 全角スペース: bitmap 描画 (FULLSPC1 + FULLSPC2 の二分割) */
      glyph_t base = (((glyph_t) (uint32_t) f & ~(glyph_t) GLYPH_TEXT_MASK)
                      | GLYPH_CTRL
                      | MAKE_GLYPH_FONT (font_idx));
      *g++ = base | GLYPH_BM_FULLSPC1 | GLYPH_WIDTH_WIDE;
      *g++ = base | GLYPH_BM_FULLSPC2 | GLYPH_JUNK;
    }
  else
    {
      glyph_t base = ((glyph_t) (uint32_t) f
                      | MAKE_GLYPH_CP (cp)
                      | MAKE_GLYPH_FONT (font_idx));
      *g++ = base | GLYPH_WIDTH_WIDE;
      *g++ = base | GLYPH_JUNK;
    }
  return g;
}

glyph_t *
glyph_sbchar (glyph_t *g, uint32_t cp, int f, int flags)
{
  /* 5b-2: cp は narrow (display width 1) または combining (width 0) と
     判明した code point。combining は当面 emit せず skip する (gd_cc の
     1 cell = 1 column 制約を 5b-2 では維持するため。cluster 形成は後の
     step に延期する未解決事項として docs/plans/2026-04-19-phase2-glyph-rewrite.md
     の「未解決の決定事項」を参照)。 */

  int w = unicode_width (cp);
  if (w == 0)
    return g;

  int font_idx = get_font_idx (cp);

  /* ASCII の特殊 bitmap: backslash と HALFSPC */
  if (cp == '\\' && app.text_font.use_backsl_p ())
    {
      *g++ = ((glyph_t) (uint32_t) f
              | GLYPH_BM_BACKSL
              | MAKE_GLYPH_FONT (font_idx)
              | GLYPH_WIDTH_NARROW);
      return g;
    }
  if (cp == ' ' && (flags & Window::WF_HALFSPC))
    {
      *g++ = (((glyph_t) (uint32_t) f & ~(glyph_t) GLYPH_TEXT_MASK)
              | GLYPH_CTRL | GLYPH_BM_HALFSPC
              | MAKE_GLYPH_FONT (font_idx)
              | GLYPH_WIDTH_NARROW);
      return g;
    }

  /* 通常 narrow cell。低 8 bit の char byte は 5b-3 までの後方互換のため
     ASCII 範囲のみ残す (BMP 以上は 0)。 */
  glyph_t base = ((glyph_t) (uint32_t) f
                  | MAKE_GLYPH_CP (cp)
                  | MAKE_GLYPH_FONT (font_idx)
                  | GLYPH_WIDTH_NARROW);
  *g++ = (cp < 0x80) ? (base | (glyph_t) cp) : base;
  return g;
}

glyph_t *
glyph_bmchar (glyph_t *g, Char bm, lisp ch, int f, int n)
{
  ch = xsymbol_value (ch);
  if (ch == Qnil)
    for (int i = 0; i < n; i++)
      *g++ = (glyph_t) (uint32_t) f | ga (' ');
  else if (charp (ch) && unicode_width (xchar_code (ch)) == 1)
    for (int i = 0; i < n; i++)
      g = glyph_sbchar (g, (uint32_t) xchar_code (ch), f, 0);
  else
    {
      glyph_t cell = (glyph_t) (uint32_t) f | gb (bm);
      for (int i = 0; i < n; i++)
        *g++ = cell;
    }
  return g;
}

class regexp_kwd
{
private:
  lisp rk_list;
  char rk_fastmap[256];
  int rk_can_fastmap;
  point_t rk_last_try;
  point_t rk_match_beg;
  point_t rk_match_end;
  int rk_val;
  int rk_vals[MAX_KWDLEN];
  int rk_use_vals;
  int rk_match;
  const Buffer *const rk_bufp;
  const syntax_table *const rk_tab;
  int rk_ctx_mask;

  lisp check_format (lisp);
  int sc2mask (int sc) {return 1 << ((sc >> GLYPH_KEYWORD_SHIFT_BITS) & 3);}
public:
  regexp_kwd (lisp, point_t, const Buffer *);
  int kwdmatch (const Point &, int, int &);
  int kwdmatch_begin (const Point &, int);
  int valid_p () const {return rk_list != 0;}
  point_t match_beg () const {return rk_match_beg;}
  point_t match_end () const {return rk_match_end;}
  int value (int i) const {return rk_use_vals ? rk_vals[i] : rk_val;}
  int match_p () const {return rk_match;}
  void clear () {rk_match = 0;}
  int ctx_mask () const {return rk_ctx_mask;}
  int possible_match_p (Char c) const
    {return !rk_can_fastmap || rk_fastmap[c >= 0x100 ? c >> 8 : c];}
};

// (regexp color [context [begin [end]]])

lisp
regexp_kwd::check_format (lisp x)
{
  if (!consp (x))
    return 0;
  lisp regex = xcar (x);
  if (!regexpp (regex))
    return 0;

  // color
  if (!consp (x = xcdr (x)))
    return 0;
  lisp c = xcar (x);
  if (short_int_p (c))
    ;
  else
    {
      if (!consp (c))
        return 0;
      do
        {
          lisp a = xcar (c);
          if (!consp (a)
              || !short_int_p (xcar (a))
              || (xcdr (a) != Qnil && !short_int_p (xcdr (a))))
            return 0;
          int v = xshort_int_value (xcar (a));
          if (v < 0 || v >= MAX_REGS)
            return 0;
          c = xcdr (c);
        }
      while (consp (c));
    }

  int ctx;
  if (!consp (x = xcdr (x)))
    ctx = 1;
  else
    {
      // context
      if (!short_int_p (xcar (x)))
        return 0;
      ctx = xshort_int_value (xcar (x));

      if (consp (x = xcdr (x)))
        {
          // begin
          if (!short_int_p (xcar (x)))
            return 0;
          int v = xshort_int_value (xcar (x));
          if (v <= -MAX_REGS || v >= MAX_REGS)
            return 0;

          // end
          if (consp (x = xcdr (x)))
            {
              if (!short_int_p (xcar (x)))
                return 0;
              v = xshort_int_value (xcar (x));
              if (v <= -MAX_REGS || v >= MAX_REGS)
                return 0;
            }
        }
    }
  rk_ctx_mask |= ctx;
  return regex;
}

inline
regexp_kwd::regexp_kwd (lisp list, point_t point, const Buffer *bp)
     : rk_list (list), rk_last_try (point_t (-1)),
       rk_match_beg (point), rk_match_end (point),
       rk_match (0), rk_val (0), rk_use_vals (0),
       rk_bufp (bp), rk_tab (xsyntax_table (rk_bufp->lsyntax_table)),
       rk_ctx_mask (0)
{
  if (!consp (rk_list))
    {
      rk_list = 0;
      return;
    }

  lisp r = rk_list;
  rk_can_fastmap = 1;
  memset (rk_fastmap, 0, sizeof rk_fastmap);
  do
    {
      lisp regex = check_format (xcar (r));
      if (!regex)
        xcar (r) = Qnil;
      else if (!Regexp::merge_fastmap (regex, rk_fastmap, rk_tab))
        {
          rk_can_fastmap = 0;
          break;
        }
    }
  while (consp (r = xcdr (r)));

  for (; consp (r); r = xcdr (r))
    if (!check_format (xcar (r)))
      xcar (r) = Qnil;
}

int
regexp_kwd::kwdmatch (const Point &point, int scolor, int &revkwd)
{
  int mask = sc2mask (scolor);
  if (mask & ctx_mask ())
    {
      const point_t limit = min (rk_bufp->b_contents.p2,
                                 point_t (point.p_point + MAX_KWDLEN - 1));
      lisp r = rk_list;
      do
        {
          lisp x = xcar (r);
          if (consp (x))
            {
              lisp regex = xcar (x);
              x = xcdr (x);
              lisp val = xcar (x);
              int ctx = consp (x = xcdr (x)) ? xshort_int_value (xcar (x)) : 1;
              if (mask & ctx)
                {
                  try
                    {
                      extern u_char char_no_translate_table[];
                      Regexp re (char_no_translate_table, rk_tab);
                      re.compile (regex, 0);
                      if (re.match (rk_bufp, point, rk_bufp->b_contents.p1, limit)
                          && re.re_regs.end[0] <= limit)
                        {
                          point_t beg, end;
                          if (!consp (x = xcdr (x)))
                            {
                              beg = re.re_regs.start[0];
                              end = re.re_regs.end[0];
                            }
                          else
                            {
                              int b = xshort_int_value (xcar (x));
                              int e = (consp (x = xcdr (x))
                                       ? xshort_int_value (xcar (x)) : 0);
                              if (b >= 0)
                                {
                                  if (b > re.re_regs.nregs)
                                    goto nomatch;
                                  beg = re.re_regs.start[b];
                                }
                              else
                                {
                                  b = -b;
                                  if (b > re.re_regs.nregs)
                                    goto nomatch;
                                  beg = re.re_regs.end[b];
                                }
                              if (e >= 0)
                                {
                                  if (e > re.re_regs.nregs)
                                    goto nomatch;
                                  end = re.re_regs.end[e];
                                }
                              else
                                {
                                  e = -e;
                                  if (e > re.re_regs.nregs)
                                    goto nomatch;
                                  end = re.re_regs.start[e];
                                }
                            }

                          if (end > beg && beg >= point.p_point)
                            {
                              if (end > point.p_point + MAX_KWDLEN)
                                end = point.p_point + MAX_KWDLEN;
                              rk_match = 1;
                              if (consp (val))
                                {
                                  rk_use_vals = 1;
                                  int vals[MAX_REGS];
                                  vals[0] = 0;
                                  for (int i = 1; i <= re.re_regs.nregs; i++)
                                    vals[i] = -1;
                                  do
                                    {
                                      lisp a = xcar (val);
                                      if (xcdr (a) != Qnil)
                                        vals[xshort_int_value (xcar (a))] =
                                          kwd_val (xcdr (a), 0, revkwd);
                                      val = xcdr (val);
                                    }
                                  while (consp (val));

                                  for (int i = end - beg - 1; i >= 0; i--)
                                    rk_vals[i] = 0;

                                  for (int i = 0; i <= re.re_regs.nregs; i++)
                                    if (vals[i] >= 0)
                                      {
                                        point_t b = re.re_regs.start[i];
                                        point_t e = re.re_regs.end [i];
                                        if (b >= 0 && e >= 0)
                                          {
                                            b = max (b, beg);
                                            e = min (e, end);
                                            for (int o = end - b - 1; b < e; b++, o--)
                                            rk_vals[o] = vals[i];
                                          }
                                      }
                                }
                              else
                                {
                                  rk_use_vals = 0;
                                  rk_val = kwd_val (val, 0, revkwd);
                                }
                              rk_match_beg = beg;
                              rk_match_end = end;
                              rk_last_try = end;
                              return end - point.p_point;
                            }
                        }
                    }
                  catch (nonlocal_jump &)
                    {
                    }
                }
            }
        nomatch:;
        }
      while (consp (r = xcdr (r)));
    }
  clear ();
  rk_last_try = point.p_point;
  return 0;
}

inline int
regexp_kwd::kwdmatch_begin (const Point &opoint, int scolor)
{
  if (!(sc2mask (scolor) & ctx_mask ()))
    return 0;

  Point point;
  point.p_point = opoint.p_point;

  Chunk *cp = opoint.p_chunk;
  const Char *p = cp->c_text + opoint.p_offset;
  int l;
  for (l = 0; l < MAX_KWDLEN; l++)
    {
      if (point.p_point <= rk_last_try)
        break;
      if (p == cp->c_text)
        {
          if (!cp->c_prev)
            break;
          cp = cp->c_prev;
          p = cp->c_text + cp->c_used;
        }
      if (*--p == CC_LFD)
        {
          if (++p == cp->c_text + cp->c_used && cp->c_next)
            {
              cp = cp->c_next;
              p = cp->c_text;
            }
          break;
        }
      point.p_point--;
    }
  if (!l)
    return 0;

  point.p_chunk = cp;
  point.p_offset = p - cp->c_text;

  do
    {
      int revkwd;
      if (kwdmatch (point, scolor, revkwd) > 0
          && match_end () > opoint.p_point)
        return match_end () - opoint.p_point;
      point.p_point++;
      if (++point.p_offset == point.p_chunk->c_used)
        {
          point.p_chunk = point.p_chunk->c_next;
          if (!point.p_chunk)
            break;
          point.p_offset = 0;
        }
    }
  while (point.p_point < opoint.p_point);
  return 0;
}

int
Window::redraw_line (glyph_data *gd, Point &point, long vlinenum, long plinenum,
                     int hide, lisp kwdhash, syntax_info *psi, textprop *&tprop,
                     regexp_kwd &re_kwd) const
{
  glyph_t *g = gd->gd_cc;
  glyph_t *const ge = g + w_ch_max.cx;

  if (g < ge)
    *g++ = ga (' ');

  for (; tprop; tprop = tprop->t_next)
    if (*tprop > point.p_point)
      break;

  int wflags = flags ();
  if (wflags & WF_LINE_NUMBER)
    {
      glyph_t f = (vlinenum == w_last_mark_linenum
                   ? (GLYPH_REVERSED | GLYPH_LINENUM)
                   : GLYPH_LINENUM);
      if (plinenum != -1 && point.p_point && point.prevch () != '\n')
        {
          glyph_t cell = f | ga (' ');
          for (glyph_t *e = min (ge, g + LINENUM_COLUMNS); g < e; g++)
            *g = cell;
          if (g < ge)
            *g++ = GLYPH_LINENUM | gb (GLYPH_BM_SEP);
        }
      else
        {
          if (plinenum == -1)
            plinenum = vlinenum;
          if (w_ch_max.cx >= LINENUM_COLUMNS + 1)
            {
              glyph_t *p = g + LINENUM_COLUMNS;
              do
                {
                  *--p = f | ga (plinenum % 10 + '0');
                  plinenum /= 10;
                }
              while (p > g && plinenum);
              while (p > g)
                *--p = f | ga (' ');
              g += LINENUM_COLUMNS;
              *g++ = GLYPH_LINENUM | gb (GLYPH_BM_SEP);
            }
          else
            {
              char buf[32];
              if (plinenum >= 1000000)
                sprintf (buf, "%06d", plinenum % 1000000);
              else
                sprintf (buf, "%6d", plinenum);
              int n = min (6, int (w_ch_max.cx));
              for (int i = 0; i < n; i++)
                *g++ = f | ga ((u_char) buf[i]);
              if (g < ge)
                *g++ = GLYPH_LINENUM | gb (GLYPH_BM_SEP);
            }
        }

      if (tprop && point.p_point >= tprop->t_range.p1
          && *tprop > point.p_point
          && tprop->t_attrib & 0xff
          && g == gd->gd_cc + LINENUM_COLUMNS + 2)
        g[-2] = tprop->t_attrib & ~TEXTPROP_EXTEND_EOL_BIT;
    }

  if (w_bufp->b_prompt_columns)
    {
      glyph_t *ge2 = g + w_bufp->b_prompt_columns;
      if (ge2 > ge)
        ge2 = ge;
      if (vlinenum == 1)
        {
          for (const u_char *u = (u_char *)w_bufp->b_prompt_arg; *u && g < ge;)
            *g++ = ga (*u++);
          const ucs4_t *s = w_bufp->b_prompt;
          const ucs4_t *se = s + w_bufp->b_prompt_length;
          while (s < se && g < ge)
            {
              ucs4_t cc = *s++;
              if (cc < ' ')
                {
                  if (g + 1 == ge)
                    break;
                  *g++ = GLYPH_CTRL | ga ('^');
                  *g++ = GLYPH_CTRL | ga (cc + '@');
                }
              else if (cc == CC_DEL)
                {
                  if (g + 1 == ge)
                    break;
                  *g++ = GLYPH_CTRL | ga ('^');
                  *g++ = GLYPH_CTRL | ga ('?');
                }
              else
                {
                  uint32_t cp = uint32_t (cc);
                  int w = unicode_width (cp);
                  if (w == 2)
                    {
                      if (g + 1 == ge)
                        break;
                      g = glyph_dbchar (g, cp, 0, 0);
                    }
                  else
                    g = glyph_sbchar (g, cp, 0, 0);
                }
            }
        }
      while (g < ge2)
        *g++ = ga (' ');
    }

  int seltype = w_selection_type & Buffer::SELECTION_TYPE_MASK;
  long rcol1 = w_goal_column;
  long rcol2 = w_selection_column;
  if (rcol1 > rcol2)
    swap (rcol1, rcol2);

  int symlen = 0;
  int kwdflag = 0;
  int revkwd = 0;
  int long_kwd = 0;
  int scolor;

  glyph_t *const g0 = g;

  point_t limit;
  Point fold_eol;
  if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
    {
      fold_eol = point;
      w_bufp->folded_go_eol (fold_eol);
      limit = min (w_bufp->b_nchars, point_t (fold_eol.p_point + 1));
    }
  else
    limit = w_bufp->b_nchars;

  const int fold_column = w_bufp->b_fold_columns - w_top_column;
  if (w_top_column)
    {
      long col = w_bufp->forward_column (point, w_top_column, 0, 1, 0);
      if (col < w_top_column || point.p_point >= limit)
        {
          if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
            {
              point = fold_eol;
              if (wflags & WF_FOLD_LINE && fold_column >= 0)
                {
                  glyph_t *const e = g0 + fold_column;
                  if (g < e && e < ge)
                    {
                      glyph_t pad = ga (' ');
                      for (; g < e; g++)
                        *g = pad;
                      *g++ = (GLYPH_CTRL | gb (GLYPH_BM_FOLD_SEP0)) + (vlinenum & 1);
                    }
                }
            }
          *g = 0;
          gd->gd_len = g - gd->gd_cc;
          gd->gd_mod = 1;
          return 0;
        }

      if (psi)
        {
          psi->point_syntax (point);
          scolor = syntax_state::ss_colors[syntax_state::SS_NORMAL][psi->si.ss_state];
          if (scolor & (syntax_state::KWD_OK | syntax_state::KWD2_OK)
              && !re_kwd.match_p () && kwdhash
              && point.p_offset < point.p_chunk->c_used)
            kwdflag = kwdmatch (kwdhash, point, symlen, revkwd, long_kwd, scolor);
        }
      else
        scolor = 0;

      int n = min (int (col - w_top_column), int (ge - g));
      if (n)
        {
          int f = 0;
          if (point.p_point < w_bufp->b_contents.p1
              || point.p_point >= w_bufp->b_contents.p2)
            f |= GLYPH_HIDDEN;

          if (hide && f & GLYPH_HIDDEN)
            f = 0;
          else
            {
              if (seltype != Buffer::SELECTION_VOID
                  && point.p_point > w_selection_region.p1
                  && point.p_point <= w_selection_region.p2
                  && (seltype != Buffer::SELECTION_RECTANGLE
                      || (w_top_column >= rcol1 && w_top_column < rcol2)))
                f |= GLYPH_SELECTED;
              if (w_reverse_region.p1 != NO_MARK_SET
                  && point.p_point > w_reverse_region.p1
                  && point.p_point <= w_reverse_region.p2)
                f |= GLYPH_REVERSED;
            }

          glyph_t cell = (glyph_t) (uint32_t) f | ga (' ');
          while (n-- > 0)
            *g++ = cell;
        }
    }
  else
    {
      if (psi)
        {
          psi->point_syntax (point);
          scolor = syntax_state::ss_colors[syntax_state::SS_NORMAL][psi->si.ss_state];
          if (scolor & (syntax_state::KWD_OK | syntax_state::KWD2_OK)
              && !re_kwd.match_p ()
              && w_bufp->b_fold_columns != Buffer::FOLD_NONE
              && kwdhash && point.p_point && point.prevch () != '\n'
              && point.p_offset < point.p_chunk->c_used)
            kwdflag = kwdmatch (kwdhash, point, symlen, revkwd, long_kwd, scolor);
        }
      else
        scolor = 0;
    }

  if (re_kwd.valid_p () && (!symlen || !((kwdflag ^ scolor) | re_kwd.match_p ())))
    {
      if (re_kwd.match_p () && re_kwd.match_end () > point.p_point)
        symlen = re_kwd.match_end () - point.p_point;
      else
        symlen = re_kwd.kwdmatch_begin (point, scolor);
      if (!symlen)
        re_kwd.clear ();
    }

  for (; tprop; tprop = tprop->t_next)
    if (tprop->t_range.p2 > point.p_point)
      break;

  int start_in_range = (point.p_point >= w_bufp->b_contents.p1
                        && point.p_point <= w_bufp->b_contents.p2);

  Chunk *cp = point.p_chunk;
  const Char *p = cp->c_text + point.p_offset;
  const Char *pe = cp->c_text + cp->c_used;
  int eol = 0, eof = 0;
  int exceed = 0;
  syntax_state osi;
  int last_attrib = 0;

  syntax_state::define_chunk (cp);

  while (g < ge)
    {
      if (p == pe)
        {
          if (psi)
            cp->update_syntax (*psi);
          if (!cp->c_next)
            {
              eof = 1;
              if (wflags & WF_EOF
                  && (!hide || w_bufp->b_contents.p2 == w_bufp->b_nchars))
                {
                  if (w_bufp->b_fold_columns != Buffer::FOLD_NONE)
                    {
                      Point tem (fold_eol);
                      if (w_bufp->next_char (tem))
                        break;
                    }

                  int f = GLYPH_CTRL;
                  if (last_attrib & TEXTPROP_EXTEND_EOL_BIT)
                    f |= last_attrib & ((GLYPH_TEXTPROP_NCOLORS - 1)
                                        << GLYPH_TEXTPROP_BG_SHIFT_BITS);
                  int n = min (int (ge - g), 5);
                  for (int i = 0; i < n; i++)
                    *g++ = (glyph_t) (uint32_t) f | ga ((u_char) "[EOF]"[i]);
                }
              break;
            }
          cp = cp->c_next;
          p = cp->c_text;
          pe = p + cp->c_used;
          syntax_state::define_chunk (cp);
        }

      if (point.p_point == limit)
        break;

      int f = 0;
      if (point.p_point < w_bufp->b_contents.p1
          || point.p_point >= w_bufp->b_contents.p2)
        f |= GLYPH_HIDDEN;

      if (seltype != Buffer::SELECTION_VOID
          && point.p_point >= w_selection_region.p1
          && point.p_point < w_selection_region.p2
          && (seltype != Buffer::SELECTION_RECTANGLE
              || w_top_column + (g - g0) >= rcol1))
        f |= GLYPH_SELECTED;

      if (w_reverse_region.p1 != NO_MARK_SET
          && point.p_point >= w_reverse_region.p1
          && point.p_point < w_reverse_region.p2)
        f |= GLYPH_REVERSED;

      int kwdf = 0;
      if (psi)
        {
          osi = psi->si;
          (psi->si.*syntax_state::update) (p);
          psi->point = point.p_point + 1;
          if (g > g0 && !(g[-1] & ((glyph_t) GLYPH_JUNK | GLYPH_TEXTPROP_FG_BIT)))
            g[-1] |= syntax_state::ss_prev_colors[osi.ss_state][psi->si.ss_state];
          scolor = syntax_state::ss_colors[osi.ss_state][psi->si.ss_state];
          int kwd_ok = scolor & (syntax_state::KWD_OK | syntax_state::KWD2_OK);
          scolor &= ~(syntax_state::KWD_OK | syntax_state::KWD2_OK);
          f |= scolor;
          if (!re_kwd.match_p ())
            {
              if (kwd_ok)
                {
                  if (kwdhash && !symlen)
                    kwdflag = kwdmatch (kwdhash, p, cp, symlen,
                                        revkwd, scolor, long_kwd, kwd_ok);
                  if (symlen > 0)
                    {
                      symlen--;
                      if (kwdflag & GLYPH_HIDDEN)
                        kwdflag &= ~GLYPH_HIDDEN;
                      else
                        {
                          f = (f & ~GLYPH_TEXT_MASK) | kwdflag;
                          kwdf = 1;
                        }
                    }
                }
              else
                symlen = 0;
            }
        }
      else
        scolor = 0;

      if (re_kwd.valid_p ())
        {
          if (!(symlen | kwdf) || !((kwdflag ^ scolor) | re_kwd.match_p ()))
            {
              if (re_kwd.possible_match_p (*p))
                {
                  point.p_chunk = cp;
                  point.p_offset = p - cp->c_text;
                  symlen = re_kwd.kwdmatch (point, scolor, revkwd);
                  if (symlen)
                    {
                      symlen--;
                      if (point.p_point >= re_kwd.match_beg ())
                        f = (f & ~GLYPH_TEXT_MASK) | re_kwd.value (symlen);
                      if (!symlen)
                        re_kwd.clear ();
                    }
                }
            }
          else if (re_kwd.match_p ())
            {
              symlen--;
              if (point.p_point >= re_kwd.match_beg ())
                f = (f & ~GLYPH_TEXT_MASK) | re_kwd.value (symlen);
              if (!symlen)
                re_kwd.clear ();
            }
        }

      last_attrib = 0;
      if (tprop && point.p_point >= tprop->t_range.p1
          && *tprop > point.p_point)
        {
          if (point.p_point < tprop->t_range.p2)
            {
              if (!(f & (GLYPH_HIDDEN | GLYPH_SELECTED /*| GLYPH_REVERSED*/)))
                {
                  if (tprop->t_attrib & ((GLYPH_TEXTPROP_NCOLORS - 1)
                                         << GLYPH_TEXTPROP_FG_SHIFT_BITS))
                    f = (f & ~GLYPH_TEXT_MASK) | GLYPH_TEXTPROP_FG_BIT;
                  f |= tprop->t_attrib & ~(TEXTPROP_EXTEND_EOL_BIT | 0xff);
                }
              last_attrib = tprop->t_attrib;
            }
          while (point.p_point >= tprop->t_range.p2 - 1)
            {
              tprop = tprop->t_next;
              if (!tprop)
                break;
            }
        }

      Char cc = *p++;
      point.p_point++;

      if (hide && f & GLYPH_HIDDEN)
        {
          if (cc == CC_LFD)
            {
              eol = 1;
              break;
            }
          else if (cc == CC_TAB)
            {
              int col = w_top_column + (g - g0);
              int goal = ((col + w_bufp->b_tab_columns) / w_bufp->b_tab_columns
                          * w_bufp->b_tab_columns);
              int n = min (goal - col, int (ge - g));
              glyph_t pad = ga (' ');
              while (n-- > 0)
                *g++ = pad;
            }
          else
            {
              int extra = 0;
              uint32_t cp = fold_surrogate (cc, p, pe, extra);
              /* Phase 2-1: p_point は cp 単位。pair を渡っても既に 1 cp 進んで
                 いるので extra (= pair の low surrogate 分の cu) を加えない。 */
              (void) extra;
              int w = unicode_width (cp);
              if (w == 2)
                {
                  if (g + 1 == ge)
                    {
                      exceed = 1;
                      break;
                    }
                  *g++ = ga (' ');
                  *g++ = ga (' ');
                }
              else if (w == 1)
                *g++ = ga (' ');
              /* w == 0: combining mark — skip (5b-2 では cluster shaping 未対応) */
            }
        }
      else
        {
          glyph_t *gr = g;

          if (cc < ' ')
            {
              if (cc == CC_LFD)
                {
                  if (seltype == Buffer::SELECTION_RECTANGLE)
                    f &= ~GLYPH_SELECTED;
                  if (wflags & WF_NEWLINE)
                    g = glyph_bmchar (g, GLYPH_BM_NEWLINE, Vdisplay_newline_char,
                                      (f & ~GLYPH_TEXT_MASK) | GLYPH_CTRL, 1);
                  else
                    *g++ = ((glyph_t) (uint32_t) f & ~(glyph_t) GLYPH_TEXT_MASK)
                           | ga (' ');
                  eol = 1;
                  break;
                }
              else if (cc == CC_TAB)
                {
                  int col = w_top_column + (g - g0);
                  int goal = ((col + w_bufp->b_tab_columns) / w_bufp->b_tab_columns
                              * w_bufp->b_tab_columns);
                  int n = min (goal - col, int (ge - g));
                  if (wflags & WF_HTAB)
                    {
                      g = glyph_bmchar (g, GLYPH_BM_HTAB, Vdisplay_first_tab_char,
                                        (f & ~GLYPH_TEXT_MASK) | GLYPH_CTRL, 1);
                      if (--n > 0)
                        g = glyph_bmchar (g, '.', Vdisplay_rest_tab_char,
                                          (f & ~GLYPH_TEXT_MASK) | GLYPH_CTRL, n);
                    }
                  else
                    {
                      glyph_t cell = (glyph_t) (uint32_t) f | ga (' ');
                      while (n-- > 0)
                        *g++ = cell;
                    }
                }
              else
                {
                  if (g + 1 == ge)
                    {
                      exceed = 1;
                      break;
                    }
                  glyph_t fbase = ((glyph_t) (uint32_t) f
                                   & ~(glyph_t) GLYPH_TEXT_MASK)
                                  | GLYPH_CTRL;
                  *g++ = fbase | ga ('^');
                  *g++ = fbase | ga (cc + '@');
                }
            }
          else if (cc == CC_DEL)
            {
              if (g + 1 == ge)
                {
                  exceed = 1;
                  break;
                }
              glyph_t fbase = ((glyph_t) (uint32_t) f
                               & ~(glyph_t) GLYPH_TEXT_MASK)
                              | GLYPH_CTRL;
              *g++ = fbase | ga ('^');
              *g++ = fbase | ga ('?');
            }
          else
            {
              int extra = 0;
              uint32_t cp = fold_surrogate (cc, p, pe, extra);
              /* Phase 2-1: extra は cu 分、p_point (cp) には加算しない。 */
              (void) extra;
              int w = unicode_width (cp);
              if (w == 2)
                {
                  if (g + 1 == ge)
                    {
                      exceed = 1;
                      break;
                    }
                  g = glyph_dbchar (g, cp, f, wflags);
                }
              else
                g = glyph_sbchar (g, cp, f, wflags);
            }

          if (f & GLYPH_SELECTED
              && seltype == Buffer::SELECTION_RECTANGLE
              && w_top_column + (g - g0) > rcol2)
            while (gr < g)
              *gr++ &= ~(glyph_t) GLYPH_SELECTED;
        }
    }

  int end_in_range = (point.p_point >= w_bufp->b_contents.p1
                      && point.p_point <= w_bufp->b_contents.p2);

  glyph_t *tailg = g;
  int hiddenf = g > g0 ? g[-1] & GLYPH_HIDDEN : 0;
  int f = (last_attrib & TEXTPROP_EXTEND_EOL_BIT
           ? last_attrib & ((GLYPH_TEXTPROP_NCOLORS - 1)
                            << GLYPH_TEXTPROP_BG_SHIFT_BITS)
           : 0);
  glyph_t *const grev = (w_bufp->b_fold_columns == Buffer::FOLD_NONE
                         ? ge : min (ge, max (g0 + max (fold_column, 0), g)));
  glyph_t *const gfold = g0 + fold_column;

  if (end_in_range)
    {
      if (w_bufp->b_fold_columns != Buffer::FOLD_NONE
          && wflags & WF_FOLD_MARK
          && !eof && !eol && g < ge
          && !exceed && point.p_point == limit)
        {
          if (g == gfold && wflags & WF_FOLD_LINE)
            {
              glyph_t bm0 = hiddenf
                            ? gb (GLYPH_BM_FOLD_SEP0)
                            : gb (GLYPH_BM_FOLD_MARK_SEP0);
              *g++ = (GLYPH_CTRL | bm0) + (vlinenum & 1);
            }
          else
            *g++ = (glyph_t) (uint32_t) (f | hiddenf) | GLYPH_CTRL | ga ('<');
        }

      if (f)
        {
          glyph_t fill = (glyph_t) (uint32_t) f | ga (' ');
          for (; g < grev; g++)
            *g = fill;
        }
    }

  if (revkwd && (start_in_range || end_in_range || !hide))
    {
#define REVMASK (GLYPH_TEXT_MASK | ((GLYPH_TEXTPROP_NCOLORS - 1) \
                                    << GLYPH_TEXTPROP_BG_SHIFT_BITS))
      if ((revkwd & ((GLYPH_TEXTPROP_NCOLORS - 1)
                     << GLYPH_TEXTPROP_BG_SHIFT_BITS))
          || (!(revkwd & GLYPH_TEXTPROP_FG_BIT)
              && (revkwd & (15 << GLYPH_COLOR_SHIFT_BITS)) >= GLYPH_KEYWORD1R
              && (revkwd & (15 << GLYPH_COLOR_SHIFT_BITS)) <= GLYPH_KEYWORD3R))
        {
          for (glyph_t *p = g0; p < g; p++)
            *p = (*p & ~(glyph_t) REVMASK) | (uint32_t) revkwd;
          glyph_t fill = (glyph_t) (uint32_t) (revkwd | hiddenf) | ga (' ');
          for (; g < grev; g++)
            *g = fill;
        }
      else
        {
          for (glyph_t *p = g0; p < g; p++)
            if (!(*p & GLYPH_CTRL))
              *p = (*p & ~(glyph_t) REVMASK) | (uint32_t) revkwd;
        }
    }

  if (w_bufp->b_fold_columns != Buffer::FOLD_NONE
      && wflags & WF_FOLD_LINE && g <= gfold && gfold < ge)
    {
      glyph_t pad = ga (' ');
      for (; g < gfold; g++)
        *g = pad;
      *g++ = (GLYPH_CTRL | gb (GLYPH_BM_FOLD_SEP0)) + (vlinenum & 1);
    }

  {
    glyph_t blank = ga (' ');
    for (; g > gd->gd_cc && g[-1] == blank; g--)
      ;
  }

  *g = 0;
  gd->gd_len = g - gd->gd_cc;
  gd->gd_mod = 1;

  if (p == pe && cp->c_next)
    {
      if (psi)
        cp->update_syntax (*psi);
      point.p_chunk = cp->c_next;
      point.p_offset = 0;
    }
  else
    {
      point.p_chunk = cp;
      point.p_offset = p - cp->c_text;
    }

  if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
    return eol;

  if (psi && point.p_offset < point.p_chunk->c_used && tailg > g0
      && psi->si.maybe_comment_p ())
    {
      osi = psi->si;
      syntax_state::define_chunk (point.p_chunk);
      (osi.*syntax_state::update) (&point.ch ());
      if (syntax_state::ss_colors[psi->si.ss_state][osi.ss_state] == GLYPH_COMMENT)
        if (!(tailg[-1] & GLYPH_TEXTPROP_FG_BIT))
          tailg[-1] |= GLYPH_COMMENT;
    }

  point = fold_eol;
  return 0;
}

#define NO_MATCH 0
#define FULL_MATCH 1
#define HALF_MATCH 2

int
compare_glyph (const glyph_data *g1, const glyph_data *g2, int offset)
{
  if (g1->gd_len != g2->gd_len)
    return NO_MATCH;
  if (offset < g1->gd_len)
    {
      if (memcmp (g1->gd_cc + offset, g2->gd_cc + offset,
                  sizeof (glyph_t) * (g1->gd_len - offset)))
        return NO_MATCH;
      return (memcmp (g1->gd_cc, g2->gd_cc, sizeof (glyph_t) * offset)
              ? HALF_MATCH : FULL_MATCH);
    }
  return (memcmp (g1->gd_cc, g2->gd_cc, sizeof (glyph_t) * g1->gd_len)
          ? NO_MATCH : FULL_MATCH);
}

void
Window::redraw_window (Point &p, long vlinenum, int all, int hide) const
{
  lisp kwdhash;
  syntax_info psi (w_bufp,
                   symbol_value (Vparentheses_hash_table, w_bufp),
                   symbol_value (Vhtml_highlight_mode, w_bufp) != Qnil);
  syntax_info *ppsi;
  if (minibuffer_window_p ()
      || symbol_value (Vhighlight_keyword, w_bufp) == Qnil)
    {
      kwdhash = 0;
      ppsi = 0;
    }
  else
    {
      kwdhash = symbol_value (Vkeyword_hash_table, w_bufp);
      if (!hash_table_p (kwdhash))
        kwdhash = 0;
      ppsi = &psi;
    }

  regexp_kwd re_kwd (symbol_value (Vregexp_keyword_list, w_bufp),
                     p.p_point, w_bufp);

  int plf = (flags () & WF_LINE_NUMBER
             && w_bufp->b_fold_columns != Buffer::FOLD_NONE
             && w_bufp->linenum_mode () == Buffer::LNMODE_LF);
  long plinenum = plf ? w_bufp->point_linenum (p) : -1;
  textprop *tprop = w_bufp->textprop_head (p.p_point);
  glyph_data **g = w_glyphs.g_rep->gr_nglyph;
  for (int y = 0; y < w_ch_max.cy; y++, g++, vlinenum++)
    {
      if ((!all && !(*g)->gd_mod)
          || !redraw_line (*g, p, vlinenum, plinenum, hide,
                           kwdhash, ppsi, tprop, re_kwd))
        {
          if (w_bufp->b_fold_columns == Buffer::FOLD_NONE)
            w_bufp->go_eol (p);
          else
#if 0
            w_bufp->folded_forward_column (p, w_bufp->b_fold_columns, 0, 0, 0);
#else
            w_bufp->folded_go_eol (p);
#endif
          if (!w_bufp->next_char (p))
            {
              for (y++, g++; y < w_ch_max.cy; y++, g++)
                {
                  (*g)->gd_len = 0;
                  (*g)->gd_mod = 1;
                  *(*g)->gd_cc = 0;
                }
              break;
            }
        }
      if (plf && p.prevch () == '\n')
        plinenum++;
    }
}

void
set_region (Region &r, point_t p1, point_t p2)
{
  if (p1 > p2)
    swap (p1, p2);
  if (r.p1 == -1)
    {
      r.p1 = p1;
      r.p2 = p2;
    }
  else
    {
      r.p1 = min (r.p1, p1);
      r.p2 = max (r.p2, p2);
    }
}

point_t
Window::bol_point (point_t goal) const
{
  Point p (w_point);
  w_bufp->goto_char (p, goal);
  w_bufp->goto_bol (p);
  return p.p_point;
}

point_t
Window::folded_bol_point (point_t goal) const
{
  Point p (w_point);
  w_bufp->goto_char (p, goal);
  w_bufp->folded_goto_bol (p);
  return p.p_point;
}

// ============================================================
// glyph_rep — glyph buffer management (moved from frontend/win32/Window.cc)
// These are platform-independent.
// ============================================================

glyph_rep::glyph_rep (int w, int h)
{
  gr_size.cx = w;
  gr_size.cy = h;
  gr_oglyph = (glyph_data **)((char *)this + sizeof *this);
  gr_nglyph = gr_oglyph + h;
  gr_ref = 0;

  char *p = (char *)(gr_nglyph + h);
  for (int i = 0; i < 2 * h; i++)
    {
      gr_oglyph[i] = (glyph_data *)p;
      gr_oglyph[i]->gd_len = 0;
      gr_oglyph[i]->gd_mod = 0;
      gr_oglyph[i]->gd_cc[0] = 0;
      p += sizeof (glyph_data) + sizeof (glyph_t) * (w + 1);
    }
  assert (p - (char *)this == size (w, h));
}

void
glyph_rep::copy (const glyph_rep *src)
{
  if (src)
    {
      int h = min (gr_size.cy, src->gr_size.cy);
      int y;
      for (y = 0; y < h; y++)
        {
          int w = min (gr_size.cx, LONG (src->gr_oglyph[y]->gd_len));
          memcpy (gr_oglyph[y]->gd_cc, src->gr_oglyph[y]->gd_cc, sizeof (glyph_t) * w);
          glyph_t *g, *ge;
          for (g = gr_oglyph[y]->gd_cc + w,
               ge = gr_oglyph[y]->gd_cc + gr_size.cx;
               g < ge; g++)
            *g = GLYPH_JUNK;
          *g = 0;
          gr_oglyph[y]->gd_len = short (gr_size.cx);
        }

      for (; y < gr_size.cy; y++)
        {
          glyph_t *g, *ge;
          for (g = gr_oglyph[y]->gd_cc, ge = g + gr_size.cx; g < ge; g++)
            *g = GLYPH_JUNK;
          *g = 0;
          gr_oglyph[y]->gd_len = short (gr_size.cx);
        }

      if (gr_size.cy >= src->gr_size.cy && src->gr_size.cy)
        for (glyph_t *g = gr_oglyph[src->gr_size.cy - 1]->gd_cc,
             *ge = g + gr_oglyph[src->gr_size.cy - 1]->gd_len;
             g < ge; g++)
          glyph_make_junk (g);
      if (gr_size.cx >= src->gr_size.cx && src->gr_size.cx)
        for (y = 0; y < h; y++)
          glyph_make_junk (&gr_oglyph[y]->gd_cc[src->gr_size.cx - 1]);
    }
  else
    {
      for (int y = 0; y < gr_size.cy; y++)
        {
          glyph_t *g, *ge;
          for (g = gr_oglyph[y]->gd_cc, ge = g + gr_size.cx; g < ge; g++)
            *g = GLYPH_JUNK;
          *g = 0;
          gr_oglyph[y]->gd_len = short (gr_size.cx);
        }
    }
}

int
Window::alloc_glyph_rep ()
{
  void *tem = malloc (glyph_rep::size (w_ch_max.cx, w_ch_max.cy));
  if (!tem)
    return 0;
  glyph_rep *rep = new (tem) glyph_rep (w_ch_max.cx, w_ch_max.cy);
  rep->copy (w_glyphs.g_rep);
  w_glyphs = Glyphs (rep);
  return 1;
}
