// -*-C++-*-
#ifndef _chtype_h_
#define _chtype_h_

#include "cdecl.h"

#define CC_BEL 7
#define CC_BS 8
#define CC_HT 9
#define CC_TAB CC_HT
#define CC_NL 10
#define CC_LFD CC_NL
#define CC_VT 11
#define CC_FF 12
#define CC_CR 13
#define CC_RET CC_CR
#define CC_SO 14
#define CC_SI 15
#define CC_ESC 27
#define CC_SPC 32
#define CC_DEL 127
#define CC_SS2 142
#define CC_SS3 143

#ifdef UNICODE
#define CCF_SHIFT_BIT 0x0040
#define CCF_CTRL_BIT  0x0080
#define CC_META       0xf800

#define CCF_FUNCTION_MASK 0xf700
#define CCF_META          0xf600
#else /* !UNICODE */
#define CC_META_BIT 0x8000
#endif

#define CCF_CHAR_MIN CCF_PRIOR
// See WINUSER.H
#define  CCF_PRIOR 0xff00
#define  CCF_NEXT 0xff01
#define  CCF_END 0xff02
#define  CCF_HOME 0xff03
#define  CCF_LEFT 0xff04
#define  CCF_UP 0xff05
#define  CCF_RIGHT 0xff06
#define  CCF_DOWN 0xff07
#define  CCF_SCROLL 0xff08
#define  CCF_MOUSEMOVE 0xff09
#define  CCF_PAUSE 0xff0a
#define  CCF_APPS 0xff0b
#define  CCF_INSERT 0xff0c
#define  CCF_DELETE 0xff0d
#define  CCF_HELP 0xff0e

#define  CCF_F1 0xff0f
#define  CCF_F2 0xff10
#define  CCF_F3 0xff11
#define  CCF_F4 0xff12
#define  CCF_F5 0xff13
#define  CCF_F6 0xff14
#define  CCF_F7 0xff15
#define  CCF_F8 0xff16
#define  CCF_F9 0xff17
#define  CCF_F10 0xff18
#define  CCF_F11 0xff19
#define  CCF_F12 0xff1a
#define  CCF_F13 0xff1b
#define  CCF_F14 0xff1c
#define  CCF_F15 0xff1d
#define  CCF_F16 0xff1e
#define  CCF_F17 0xff1f
#define  CCF_F18 0xff20
#define  CCF_F19 0xff21
#define  CCF_F20 0xff22
#define  CCF_F21 0xff23
#define  CCF_F22 0xff24
#define  CCF_F23 0xff25
#define  CCF_F24 0xff26
#define CCF_Fn_MAX CCF_F24

#define  CCF_LBTNDOWN 0xff27
#define  CCF_LBTNMOVE 0xff28
#define  CCF_LBTNUP 0xff29
#define  CCF_RBTNDOWN 0xff2a
#define  CCF_RBTNMOVE 0xff2b
#define  CCF_RBTNUP 0xff2c
#define  CCF_MBTNDOWN 0xff2d
#define  CCF_MBTNMOVE 0xff2e
#define  CCF_MBTNUP 0xff2f

#define CCF_CTLCHAR_MIN CCF_EXCLAM
#define  CCF_EXCLAM 0xff30
#define  CCF_DQUOTE 0xff31
#define  CCF_NUMBER 0xff32
#define  CCF_DOLLAR 0xff33
#define  CCF_PERCENT 0xff34
#define  CCF_AMPER 0xff35
#define  CCF_QUOTE 0xff36
#define  CCF_LPAREN 0xff37
#define  CCF_RPAREN 0xff38
#define CCF_CTLCHAR_MAX CCF_RPAREN

#define  CCF_ASTER 0xff70
#define  CCF_PLUS 0xff71
#define  CCF_COMMA 0xff72
#define  CCF_MINUS 0xff73
#define  CCF_DOT 0xff74
#define  CCF_SLASH 0xff75
#define  CCF_0 0xff76
#define  CCF_1 0xff77
#define  CCF_2 0xff78

#define  CCF_3 0xffb0
#define  CCF_4 0xffb1
#define  CCF_5 0xffb2
#define  CCF_6 0xffb3
#define  CCF_7 0xffb4
#define  CCF_8 0xffb5
#define  CCF_9 0xffb6
#define  CCF_COLON 0xffb7
#define  CCF_SEMI 0xffb8

#define  CCF_LT 0xfff0
#define  CCF_EQ 0xfff1
#define  CCF_GT 0xfff2
//#define  CCF_QUESTION  --> DEL
#define  CCF_BACKQ 0xfff3
#define  CCF_LBRACE 0xfff4
#define  CCF_VER 0xfff5
#define  CCF_RBRACE 0xfff6
#define  CCF_TILDE 0xfff7
#define  CCF_EMPTY_CHAR 0xfff8 // XXX

#define  CCF_XBTN1DOWN 0xff39
#define  CCF_XBTN1UP 0xff3a
#define  CCF_XBTN1MOVE 0xff3b
#define  CCF_XBTN2DOWN 0xff3c
#define  CCF_XBTN2UP 0xff3d
#define  CCF_XBTN2MOVE 0xff3e

#define CCF_CHAR_MAX CCF_XBTN2MOVE

#define CCF_CHAR_MASK 0x003f

#define NFUNCTION_KEYS (CCF_CHAR_MAX - CCF_CHAR_MIN + 1)

#ifndef UNICODE
#define CCF_SHIFT_BIT 0x0040
#define CCF_CTRL_BIT 0x0080
#define CCF_FUNCTION_MASK 0xff00
#define CCF_META 0xfe00
#endif

/* ============================================================
   lChar bit layout (Phase 1 unicode migration)

    31..28    27  26  25  24   23..21    20..0
   +--------+---+---+---+---+---------+--------------------+
   |  予約  |Met|Alt|Ctl|Shf|  kind   |  payload (21 bit)  |
   +--------+---+---+---+---+---------+--------------------+

   modifier (bit 24-27): Shift / Ctrl / Alt / Meta を別ビットで保持
   予約 (bit 28-31):     Win / Super / Hyper / keyup 等の将来拡張
   kind (bit 21-23):     0=CHAR, 1=FNKEY, 2=MOUSE, 3=IME, 4..7=予約
   payload (bit 0-20):   kind=CHAR なら Unicode code point (U+0000..U+10FFFF)、
                         その他 kind は各イベントの ID 空間

   既存の Char ベース CCF_* や CC_META と並行稼働。Phase 1 後半で呼出箇所
   を順次新マクロに移行し、最終的に旧定数を削除する。
   ============================================================ */

/* modifier flags (bit 24-27) */
#define LCMOD_SHIFT  0x01000000
#define LCMOD_CTRL   0x02000000
#define LCMOD_ALT    0x04000000
#define LCMOD_META   0x08000000
#define LCMOD_MASK   0x0F000000

/* kind field (bit 21-23) */
#define LCKIND_SHIFT 21
#define LCKIND_MASK  0x00E00000
#define LCKIND_CHAR  (0 << LCKIND_SHIFT)
#define LCKIND_FNKEY (1 << LCKIND_SHIFT)
#define LCKIND_MOUSE (2 << LCKIND_SHIFT)
#define LCKIND_IME   (3 << LCKIND_SHIFT)

/* payload field (bit 0-20) */
#define LCHAR_PAYLOAD_MASK 0x001FFFFF

/* accessor macros (引数・戻値とも lChar 前提) */
#define LCHAR_PAYLOAD(lc) ((lc) & LCHAR_PAYLOAD_MASK)
#define LCHAR_KIND(lc)    ((lc) & LCKIND_MASK)
#define LCHAR_MODS(lc)    ((lc) & LCMOD_MASK)

/* mouse / menu 由来の lChar を見分ける flag。

   以前は 0x10000 / 0x20000 だった。これは payload (bit 0-20 = code point)
   の中に食い込んでいる。BMP 外の文字 (U+10000 以上) を 1 個の code point
   として queue に流すと 0x10000 bit が立ち、`c & LCHAR_MOUSE` が真に
   なって文字が mouse event 扱いされてしまう。kind field (bit 21-23) 側の
   値に移す。判定は常に `&` なので、payload とぶつからない場所であれば
   値そのものに意味はない。 */
#define LCHAR_MOUSE LCKIND_MOUSE          /* kind 2 */
#define LCHAR_MENU  (4 << LCKIND_SHIFT)   /* kind 4 (予約枠) */

/* 端末の貼り付け (bracketed paste、issue #241)。**キーではなく「その動作を
   しろ」という出来事**なので、`LCHAR_MENU` と同じ側に置く -- キーマップを
   通さず `dispatch` が早い所で分岐する。

   **文字として流してはいけない。** 貼り付けを 1 文字ずつキューへ入れると、
   自動インデント・自動ペア・electric がそれぞれに反応して、
   **貼ったものと違うものが入る** (c-mode で 4 桁のインデントが 6 桁に
   なった)。中身は `si:*take-pasted-text` で受け取る。 */
#define LCHAR_PASTE (5 << LCKIND_SHIFT)   /* kind 5 */

/* **kind が 4 以上のものは `&` で見分けられない。** kind 4 (menu) と
   kind 5 (paste) は bit 2 を共有するので、`cc & LCHAR_MENU` は paste にも
   当たり、`cc & LCHAR_PASTE` は menu にも当たる。**実際に踏んだ**: paste の
   分岐を `&` で書いたら、メニューから選んだコマンドが走らなくなった
   (`tools/linux-smoke.sh` の「メニューの実行」が落ちた)。
   **kind を見るときは `LCHAR_KIND (cc) == ...` で比べる。**

   **union の判定も `&` では書けない。** `LCHAR_MENU | LCHAR_PASTE` は
   `7 << 21` = kind mask 全体になるので、`c & (LCHAR_MENU | LCHAR_PASTE)` は
   **kind 1 (function key) にも当たる。** これも実際に踏んだ:
   `terminal-key-*` が 8 件まとめて落ちた (`src/core/term.cc` の guard)。
   下の `lchar_event_p` を使う。 */

/* キーや文字ではなく「出来事」の lChar か (mouse / menu / paste)。
   **キーマップにも表示にもマクロにも載らないもの**をまとめて聞くための判定。 */
static inline int
lchar_event_p (lChar lc)
{
  lChar k = LCHAR_KIND (lc);
  return k == LCKIND_MOUSE || k == LCHAR_MENU || k == LCHAR_PASTE;
}

/* code point をそのまま載せた lChar か (modifier なし・kind CHAR・
   BMP 外)。BMP 内なら旧 Char encoding と値が一致するので、この判定が
   必要になるのは 0x10000 以上だけ。 */
static inline int
lchar_astral_char_p (lChar lc)
{
  return (LCHAR_KIND (lc) == LCKIND_CHAR
          && !LCHAR_MODS (lc)
          && LCHAR_PAYLOAD (lc) >= 0x10000
          && LCHAR_PAYLOAD (lc) < CHAR_LIMIT);
}

/* function key IDs (完全な lChar 値: LCKIND_FNKEY と OR 済み)
   既存 CCF_PRIOR..CCF_F24 の順序を保存して 0 起算で再採番。
   マウス系 (LBTNDOWN..XBTN2MOVE) と擬似制御文字 (CCF_EXCLAM 等) は
   新スキームでは modifier + kind=MOUSE / modifier + kind=CHAR で
   表現するため、ここには定義しない。                                   */
#define LCKEY_PRIOR     (LCKIND_FNKEY | 0x00) /* Page Up   */
#define LCKEY_NEXT      (LCKIND_FNKEY | 0x01) /* Page Down */
#define LCKEY_END       (LCKIND_FNKEY | 0x02)
#define LCKEY_HOME      (LCKIND_FNKEY | 0x03)
#define LCKEY_LEFT      (LCKIND_FNKEY | 0x04)
#define LCKEY_UP        (LCKIND_FNKEY | 0x05)
#define LCKEY_RIGHT     (LCKIND_FNKEY | 0x06)
#define LCKEY_DOWN      (LCKIND_FNKEY | 0x07)
#define LCKEY_SCROLL    (LCKIND_FNKEY | 0x08) /* Scroll Lock */
#define LCKEY_MOUSEMOVE (LCKIND_FNKEY | 0x09) /* XXX 歴史的事情。将来 kind=MOUSE へ */
#define LCKEY_PAUSE     (LCKIND_FNKEY | 0x0A)
#define LCKEY_APPS      (LCKIND_FNKEY | 0x0B) /* Application/Menu */
#define LCKEY_INSERT    (LCKIND_FNKEY | 0x0C)
#define LCKEY_DELETE    (LCKIND_FNKEY | 0x0D)
#define LCKEY_HELP      (LCKIND_FNKEY | 0x0E)

#define LCKEY_F1        (LCKIND_FNKEY | 0x0F)
#define LCKEY_F2        (LCKIND_FNKEY | 0x10)
#define LCKEY_F3        (LCKIND_FNKEY | 0x11)
#define LCKEY_F4        (LCKIND_FNKEY | 0x12)
#define LCKEY_F5        (LCKIND_FNKEY | 0x13)
#define LCKEY_F6        (LCKIND_FNKEY | 0x14)
#define LCKEY_F7        (LCKIND_FNKEY | 0x15)
#define LCKEY_F8        (LCKIND_FNKEY | 0x16)
#define LCKEY_F9        (LCKIND_FNKEY | 0x17)
#define LCKEY_F10       (LCKIND_FNKEY | 0x18)
#define LCKEY_F11       (LCKIND_FNKEY | 0x19)
#define LCKEY_F12       (LCKIND_FNKEY | 0x1A)
#define LCKEY_F13       (LCKIND_FNKEY | 0x1B)
#define LCKEY_F14       (LCKIND_FNKEY | 0x1C)
#define LCKEY_F15       (LCKIND_FNKEY | 0x1D)
#define LCKEY_F16       (LCKIND_FNKEY | 0x1E)
#define LCKEY_F17       (LCKIND_FNKEY | 0x1F)
#define LCKEY_F18       (LCKIND_FNKEY | 0x20)
#define LCKEY_F19       (LCKIND_FNKEY | 0x21)
#define LCKEY_F20       (LCKIND_FNKEY | 0x22)
#define LCKEY_F21       (LCKIND_FNKEY | 0x23)
#define LCKEY_F22       (LCKIND_FNKEY | 0x24)
#define LCKEY_F23       (LCKIND_FNKEY | 0x25)
#define LCKEY_F24       (LCKIND_FNKEY | 0x26)

#define LCKEY_Fn_MAX    LCKEY_F24

#define _CTN 1
#define _CTU 2
#define _CTL 4
#define _CTK 8
#define _CTK1 0x10
#define _CTK2 0x20

#define UTF7_SET_D 1
#define UTF7_SET_O 2
#define UTF7_SET_B 4
#define UTF7_WHITE 8
#define UTF7_IMAP4_MAILBOX_NAME 16
#define UTF7_SHIFT_CHAR 32
#define UTF7_IMAP4_SHIFT_CHAR 64

#ifndef NOT_COMPILE_TIME

inline int
_char_type (int c)
{
  extern u_char char_type_table[];
  return (char_type_table + 1) [c];
}

inline int digit_char_p (int c) {return _char_type (c) & _CTN;}
inline int upper_char_p (int c) {return _char_type (c) & _CTU;}
inline int lower_char_p (int c) {return _char_type (c) & _CTL;}
inline int alpha_char_p (int c) {return _char_type (c) & (_CTL | _CTU);}
inline int alphanumericp (int c) {return _char_type (c) & (_CTL | _CTU | _CTN);}
inline int kana_char_p (int c) {return _char_type (c) & _CTK;}
inline int kanji_char_p (int c) {return _char_type (c) & _CTK1;}
inline int kanji2_char_p (int c) {return _char_type (c) & _CTK2;}
inline int SJISP (int c) {return kanji_char_p (c);}
inline int SJIS2P (int c) {return kanji2_char_p (c);}

inline int ascii_char_p (int c) {return u_int (c) < 128;}

inline int SBCP (Char c) {return c < 256;}
inline int DBCP (Char c) {return c >= 256;}
inline int digit_char_p (Char c)
  {return ascii_char_p (c) && digit_char_p (int (c));}
inline int upper_char_p (Char c)
  {return ascii_char_p (c) && upper_char_p (int (c));}
inline int lower_char_p (Char c)
  {return ascii_char_p (c) && lower_char_p (int (c));}
inline int alpha_char_p (Char c)
  {return ascii_char_p (c) && alpha_char_p (int (c));}
inline int alphanumericp (Char c)
  {return ascii_char_p (c) && alphanumericp (int (c));}
inline int kana_char_p (Char c)
  {return SBCP (c) && kana_char_p (int (c));}
inline int kanji_char_p (Char c)
  {return DBCP (c);}

inline int SBCP (lChar c)
  {return c < 256;}
inline int DBCP (lChar c)
  {return c >= 256 && c < CHAR_LIMIT;}
inline int digit_char_p (lChar c)
  {return ascii_char_p (c) && digit_char_p (int (c));}
inline int upper_char_p (lChar c)
  {return ascii_char_p (c) && upper_char_p (int (c));}
inline int lower_char_p (lChar c)
  {return ascii_char_p (c) && lower_char_p (int (c));}
inline int alpha_char_p (lChar c)
  {return ascii_char_p (c) && alpha_char_p (int (c));}
inline int alphanumericp (lChar c)
  {return ascii_char_p (c) && alphanumericp (int (c));}
inline int kana_char_p (lChar c)
  {return SBCP (c) && kana_char_p (int (c));}
inline int kanji_char_p (lChar c)
  {return DBCP (c);}

// lChar (u_long, native width) and ucs4_t (a fixed uint32_t) are always
// distinct types now, even on LLP64 (Win32) where u_long happens to be
// 32-bit too — uint32_t and unsigned long are still different types. So a
// ucs4_t argument is ambiguous between the int / Char / lChar overloads
// above on every platform; add ucs4_t overloads to give it an exact match.
inline int SBCP (ucs4_t c)
  {return c < 256;}
inline int DBCP (ucs4_t c)
  {return c >= 256 && c < CHAR_LIMIT;}
inline int digit_char_p (ucs4_t c)
  {return ascii_char_p (int (c)) && digit_char_p (int (c));}
inline int upper_char_p (ucs4_t c)
  {return ascii_char_p (int (c)) && upper_char_p (int (c));}
inline int lower_char_p (ucs4_t c)
  {return ascii_char_p (int (c)) && lower_char_p (int (c));}
inline int alpha_char_p (ucs4_t c)
  {return ascii_char_p (int (c)) && alpha_char_p (int (c));}
inline int alphanumericp (ucs4_t c)
  {return ascii_char_p (int (c)) && alphanumericp (int (c));}
inline int kana_char_p (ucs4_t c)
  {return SBCP (c) && kana_char_p (int (c));}
inline int kanji_char_p (ucs4_t c)
  {return DBCP (c);}

inline int
_char_downcase (int c)
{
  extern u_char char_translate_downcase_table[];
  return char_translate_downcase_table[c];
}

inline int
_char_upcase (int c)
{
  extern u_char char_translate_upcase_table[];
  return char_translate_upcase_table[c];
}

inline int
_char_transpose_case (int c)
{
  return c ^ 0x20;
}

inline int char_downcase (int c)
  {return ascii_char_p (c) ? _char_downcase (c) : c;}
inline int char_upcase (int c)
  {return ascii_char_p (c) ? _char_upcase (c) : c;}
inline int char_transpose_case (int c)
  {return alpha_char_p (c) ? _char_transpose_case (c) : c;}
inline Char char_downcase (Char c)
  {return ascii_char_p (c) ? Char (_char_downcase (c)) : c;}
inline Char char_upcase (Char c)
  {return ascii_char_p (c) ? Char (_char_upcase (c)) : c;}
inline Char char_transpose_case (Char c)
  {return alpha_char_p (c) ? (Char)_char_transpose_case (c) : c;}
inline ucs4_t char_downcase (ucs4_t c)
  {return ascii_char_p (int (c)) ? ucs4_t (_char_downcase (int (c))) : c;}
inline ucs4_t char_upcase (ucs4_t c)
  {return ascii_char_p (int (c)) ? ucs4_t (_char_upcase (int (c))) : c;}

inline int
_digit_char (int c)
{
  extern char char_numeric_table[];
  return char_numeric_table[c];
}

inline int
digit_char (int c)
{
  return ascii_char_p (c) ? _digit_char (c) : 36;
}

inline int
_digit_char_p (int c, int base)
{
  int n = _digit_char (c);
  return n < base ? n : -1;
}

inline int
digit_char_p (int c, int base)
{
  return ascii_char_p (c) ? _digit_char_p (c, base) : -1;
}

extern char upcase_digit_char[];
extern char downcase_digit_char[];

inline int
meta_char_p (Char c)
{
#ifdef UNICODE
  return ((c & CC_META) == CC_META && c <= CC_META + 127
          && ascii_char_p (c & ~CC_META));
#else
  return (c & CC_META_BIT && c <= CC_META_BIT + 127
          && ascii_char_p (c & ~CC_META_BIT));
#endif
}

inline Char
char_to_meta_char (Char c)
{
#ifdef UNICODE
  return Char (c | CC_META);
#else
  return Char (c | CC_META_BIT);
#endif
}

inline Char
meta_char_to_char (Char c)
{
#ifdef UNICODE
  return Char (c & ~CC_META);
#else
  return Char (c & ~CC_META_BIT);
#endif
}

inline Char
function_to_meta_function (Char c)
{
  return Char ((c & ~CCF_FUNCTION_MASK) | CCF_META);
}

inline Char
meta_function_to_function (Char c)
{
  return Char (c | CCF_FUNCTION_MASK);
}

inline int
function_char_p (Char c)
{
  if (c == CCF_EMPTY_CHAR)
    return 0;
  c &= ~(CCF_CTRL_BIT | CCF_SHIFT_BIT);
  return c >= CCF_CHAR_MIN && c <= CCF_CHAR_MAX;
}

inline int
meta_function_char_p (Char c)
{
  return ((c & CCF_FUNCTION_MASK) == CCF_META
          && function_char_p (meta_function_to_function (c)));
}

inline int
pseudo_ctlchar_p (Char c)
{
  c &= ~(CCF_CTRL_BIT | CCF_SHIFT_BIT);
  return c >= CCF_CTLCHAR_MIN && c <= CCF_CTLCHAR_MAX;
}

inline int
meta_pseudo_ctlchar_p (Char c)
{
  return ((c & CCF_FUNCTION_MASK) == CCF_META
          && pseudo_ctlchar_p (meta_function_to_function (c)));
}

/* ============================================================
   旧 Char encoding <--> 新 lChar encoding の相互変換

   旧 Char encoding (16bit):
     - ASCII / UCS2 / SJIS char    : そのまま (C-a = 0x01 等の制御文字)
     - function key / mouse         : CCF_CHAR_MIN + id (0xff00..0xff3e)
     - function key + Shift         : 上記 | CCF_SHIFT_BIT (0x0040)
     - function key + Ctrl          : 上記 | CCF_CTRL_BIT  (0x0080)
     - meta + ASCII char            : CC_META (0xf800) | ascii
     - meta + function key          : function_to_meta_function (CCF_META | id)
     - pseudo control chars (C-! 等): CCF_CTLCHAR_MIN..MAX (0xff30..0xff38) 他

   新 lChar encoding (32bit):
     - modifier (bit 24-27) : LCMOD_SHIFT / CTRL / ALT / META
     - kind     (bit 21-23) : LCKIND_CHAR (0) / FNKEY / MOUSE / IME
     - payload  (bit 0-20)  : code point (kind=CHAR) or id (kind=FNKEY 等)

   Phase 1 の Commit 8b で kbd.cc / keymap.cc / Lisp char を新 encoding に
   切り替える際の橋渡しとして、本 helper を使って境界で変換する。   */

inline lChar
lc_from_ccf (Char c)
{
  lChar mods = 0;
  Char base = c;

  if (meta_char_p (c))
    {
      mods |= LCMOD_META;
      base = meta_char_to_char (c);
    }
  else if (meta_function_char_p (c))
    {
      mods |= LCMOD_META;
      base = meta_function_to_function (c);
    }

  if (function_char_p (base))
    {
      if (base & CCF_SHIFT_BIT) { mods |= LCMOD_SHIFT; base = Char (base & ~CCF_SHIFT_BIT); }
      if (base & CCF_CTRL_BIT)  { mods |= LCMOD_CTRL;  base = Char (base & ~CCF_CTRL_BIT); }
      return mods | LCKIND_FNKEY | lChar (base - CCF_CHAR_MIN);
    }

  /* Regular char (ASCII/SJIS/UCS2) または pseudo_ctlchar の一部 (0xff70+ 等)
     は code point 空間に収まるので LCKIND_CHAR として渡す */
  return mods | LCKIND_CHAR | lChar (base);
}

inline Char
ccf_from_lc (lChar lc)
{
  lChar mods = LCHAR_MODS (lc);
  lChar kind = LCHAR_KIND (lc);
  lChar payload = LCHAR_PAYLOAD (lc);
  Char result;

  if (kind == LCKIND_FNKEY)
    {
      Char fn = Char (CCF_CHAR_MIN + payload);
      if (mods & LCMOD_SHIFT) fn = Char (fn | CCF_SHIFT_BIT);
      if (mods & LCMOD_CTRL)  fn = Char (fn | CCF_CTRL_BIT);
      if (mods & LCMOD_META)  fn = function_to_meta_function (fn);
      return fn;
    }

  /* LCKIND_CHAR : regular character + optional Meta */
  result = Char (payload);
  if (mods & LCMOD_META)
    result = char_to_meta_char (result);
  /* LCMOD_SHIFT / CTRL / ALT on LCKIND_CHAR は旧 encoding に表現がなく
     欠落する。C-a は旧表現では 0x01 (ASCII control char) として呼び出し側で
     既に処理されているため、ここでは通常通過で問題ない想定。 */
  return result;
}

/* mouse.cc / ncurses-*.cc は CCF_LBTNDOWN 等 (旧 Char encoding、必要なら
   CCF_SHIFT_BIT / CCF_CTRL_BIT も OR 済み) に LCHAR_MOUSE (= kind field の
   MOUSE 値) を素の `|` で重ねて queue に積む。kind field は CHAR/FNKEY/
   MOUSE/IME のどれか一つを表す値なので、この生値は「新 encoding の
   完全な lChar」でも「16bit に収まる旧 Char」でもない中間形態になり、
   normalize_for_keymap や char_mouse_move_p の判定をすり抜けて
   キーマップ検索が引けなくなる (マウスクリックがバッファに一切効かない)。
   ここで旧 Char 部分 (payload に無傷で残っている) を取り出し、通常の
   lc_from_ccf 変換に通して正規の lChar (kind=FNKEY) に直す。 */
inline lChar
lc_from_raw_mouse (lChar lc)
{
  return lc_from_ccf (Char (LCHAR_PAYLOAD (lc)));
}

inline int
base64_decode (int c)
{
  extern u_char base64_decode_table[];
  return c < 128 ? base64_decode_table[c] : 65;
}

inline int
imap4_base64_decode (int c)
{
  extern u_char imap4_base64_decode_table[];
  return c < 128 ? imap4_base64_decode_table[c] : 65;
}

inline u_char
utf7_set (int c)
{
  extern u_char utf7_set_table[];
  return utf7_set_table[c];
}

inline int
hqx_decode (int c)
{
  extern u_char hqx_decode_table[];
  return c < 128 ? hqx_decode_table[c] : 64;
}

extern u_char pseudo_char2ctl_table[];
extern u_char pseudo_ctl2char_table[];

#endif /* not NOT_COMPILE_TIME */

#endif
