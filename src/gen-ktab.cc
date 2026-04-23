#include "gen-stdafx.h"

typedef unsigned char u_char;
typedef unsigned short u_short;
typedef unsigned int u_int;

/* Unicode half-width / full-width mapping tables.

   Source of truth for the forward direction (halfwidth → fullwidth). All values
   are Unicode code points, derived from Unicode NFKD compatibility decomposition
   and canonical decomposition (for voicing).

   Coverage:
     - ASCII 0x20-0x7e → U+3000 / U+FF01-U+FF5E  (fullwidth ASCII)
     - U+FF61-U+FF9F  → fullwidth katakana / hiragana  (halfwidth kana block)
     - Halfwidth BASE + ﾞ / ﾟ → voiced / semi-voiced kana

   Reverse tables (fullwidth → halfwidth) are computed from the forward tables
   at gen-ktab run time.                                                          */

/* ASCII 0x20-0x7e → fullwidth.
   U+0020 → U+3000 (ideographic space); U+0021-U+007E → U+FF01-U+FF5E.            */
static const u_short f_ascii[95] = {
  0x3000, 0xff01, 0xff02, 0xff03, 0xff04, 0xff05, 0xff06, 0xff07,
  0xff08, 0xff09, 0xff0a, 0xff0b, 0xff0c, 0xff0d, 0xff0e, 0xff0f,
  0xff10, 0xff11, 0xff12, 0xff13, 0xff14, 0xff15, 0xff16, 0xff17,
  0xff18, 0xff19, 0xff1a, 0xff1b, 0xff1c, 0xff1d, 0xff1e, 0xff1f,
  0xff20, 0xff21, 0xff22, 0xff23, 0xff24, 0xff25, 0xff26, 0xff27,
  0xff28, 0xff29, 0xff2a, 0xff2b, 0xff2c, 0xff2d, 0xff2e, 0xff2f,
  0xff30, 0xff31, 0xff32, 0xff33, 0xff34, 0xff35, 0xff36, 0xff37,
  0xff38, 0xff39, 0xff3a, 0xff3b, 0xff3c, 0xff3d, 0xff3e, 0xff3f,
  0xff40, 0xff41, 0xff42, 0xff43, 0xff44, 0xff45, 0xff46, 0xff47,
  0xff48, 0xff49, 0xff4a, 0xff4b, 0xff4c, 0xff4d, 0xff4e, 0xff4f,
  0xff50, 0xff51, 0xff52, 0xff53, 0xff54, 0xff55, 0xff56, 0xff57,
  0xff58, 0xff59, 0xff5a, 0xff5b, 0xff5c, 0xff5d, 0xff5e,
};

/* Halfwidth kana U+FF61-U+FF9F → fullwidth katakana (NFKD decomposition).        */
static const u_short fk_half[63] = {
  0x3002, 0x300c, 0x300d, 0x3001, 0x30fb,                     /* ｡｢｣､･        */
  0x30f2, 0x30a1, 0x30a3, 0x30a5, 0x30a7, 0x30a9,             /* ｦｧｨｩｪｫ       */
  0x30e3, 0x30e5, 0x30e7, 0x30c3,                             /* ｬｭｮｯ         */
  0x30fc,                                                      /* ｰ            */
  0x30a2, 0x30a4, 0x30a6, 0x30a8, 0x30aa,                     /* ｱｲｳｴｵ        */
  0x30ab, 0x30ad, 0x30af, 0x30b1, 0x30b3,                     /* ｶｷｸｹｺ        */
  0x30b5, 0x30b7, 0x30b9, 0x30bb, 0x30bd,                     /* ｻｼｽｾｿ        */
  0x30bf, 0x30c1, 0x30c4, 0x30c6, 0x30c8,                     /* ﾀﾁﾂﾃﾄ        */
  0x30ca, 0x30cb, 0x30cc, 0x30cd, 0x30ce,                     /* ﾅﾆﾇﾈﾉ        */
  0x30cf, 0x30d2, 0x30d5, 0x30d8, 0x30db,                     /* ﾊﾋﾌﾍﾎ        */
  0x30de, 0x30df, 0x30e0, 0x30e1, 0x30e2,                     /* ﾏﾐﾑﾒﾓ        */
  0x30e4, 0x30e6, 0x30e8,                                     /* ﾔﾕﾖ          */
  0x30e9, 0x30ea, 0x30eb, 0x30ec, 0x30ed,                     /* ﾗﾘﾙﾚﾛ        */
  0x30ef, 0x30f3,                                             /* ﾜﾝ           */
  0x309b, 0x309c,                                             /* ﾞﾟ           */
};

/* Halfwidth kana → fullwidth hiragana. Non-kana symbols stay as fullwidth
   CJK symbols; kana chars map to hiragana (U+3041-U+3093).                       */
static const u_short fh_half[63] = {
  0x3002, 0x300c, 0x300d, 0x3001, 0x30fb,
  0x3092, 0x3041, 0x3043, 0x3045, 0x3047, 0x3049,
  0x3083, 0x3085, 0x3087, 0x3063,
  0x30fc,
  0x3042, 0x3044, 0x3046, 0x3048, 0x304a,
  0x304b, 0x304d, 0x304f, 0x3051, 0x3053,
  0x3055, 0x3057, 0x3059, 0x305b, 0x305d,
  0x305f, 0x3061, 0x3064, 0x3066, 0x3068,
  0x306a, 0x306b, 0x306c, 0x306d, 0x306e,
  0x306f, 0x3072, 0x3075, 0x3078, 0x307b,
  0x307e, 0x307f, 0x3080, 0x3081, 0x3082,
  0x3084, 0x3086, 0x3088,
  0x3089, 0x308a, 0x308b, 0x308c, 0x308d,
  0x308f, 0x3093,
  0x309b, 0x309c,
};

/* Halfwidth BASE (U+FF73 ｳ to U+FF8E ﾎ, 28 slots) + ﾞ → fullwidth voiced kana.
   0 means no voiced form exists (ｴ ｵ ﾅ-ﾉ etc.).                                  */
static const u_short fk_voiced[28] = {
  0x30f4, 0, 0,                                   /* ｳ → ヴ, ｴ ｵ (なし)          */
  0x30ac, 0x30ae, 0x30b0, 0x30b2, 0x30b4,         /* ｶ-ｺ → ガギグゲゴ             */
  0x30b6, 0x30b8, 0x30ba, 0x30bc, 0x30be,         /* ｻ-ｿ → ザジズゼゾ             */
  0x30c0, 0x30c2, 0x30c5, 0x30c7, 0x30c9,         /* ﾀ-ﾄ → ダヂヅデド             */
  0, 0, 0, 0, 0,                                   /* ﾅ-ﾉ                         */
  0x30d0, 0x30d3, 0x30d6, 0x30d9, 0x30dc,         /* ﾊ-ﾎ → バビブベボ             */
};

/* Halfwidth BASE (U+FF73 ｳ to U+FF8E ﾎ) + ﾞ → fullwidth voiced hiragana.
   ゔ (U+3094) exists since Unicode 3.2.                                          */
static const u_short fh_voiced[28] = {
  0x3094, 0, 0,                                   /* ｳ → ゔ, ｴ ｵ (なし)          */
  0x304c, 0x304e, 0x3050, 0x3052, 0x3054,
  0x3056, 0x3058, 0x305a, 0x305c, 0x305e,
  0x3060, 0x3062, 0x3065, 0x3067, 0x3069,
  0, 0, 0, 0, 0,
  0x3070, 0x3073, 0x3076, 0x3079, 0x307c,
};

/* Halfwidth BASE (U+FF8A ﾊ to U+FF8E ﾎ) + ﾟ → fullwidth semi-voiced.             */
static const u_short fk_semi_voiced[5] = {
  0x30d1, 0x30d4, 0x30d7, 0x30da, 0x30dd,         /* パピプペポ                    */
};

static const u_short fh_semi_voiced[5] = {
  0x3071, 0x3074, 0x3077, 0x307a, 0x307d,         /* ぱぴぷぺぽ                    */
};

/* ranges / constants                                                             */
#define CJK_RANGE_MIN           0x3000
#define CJK_RANGE_MAX           0x30fc
#define CJK_RANGE_SIZE          (CJK_RANGE_MAX - CJK_RANGE_MIN + 1)

#define FULL_ASCII_MIN          0xff01
#define FULL_ASCII_MAX          0xff5e
#define FULL_ASCII_SIZE         (FULL_ASCII_MAX - FULL_ASCII_MIN + 1)

#define HALFWIDTH_KANA_MIN      0xff61
#define HALFWIDTH_KANA_MAX      0xff9f

#define VOICED_MARK_CP          0x309b       /* ゛                                 */
#define SEMI_VOICED_MARK_CP     0x309c       /* ゜                                 */
#define HALFWIDTH_VOICED_MARK   0xff9e       /* ﾞ                                  */
#define HALFWIDTH_SEMI_VOICED_MARK 0xff9f    /* ﾟ                                  */

static void
print_char_tab (const char *name, const u_short *t, int size)
{
  printf ("static const Char %s[] = {\n", name);
  for (int i = 0; i < size; i++)
    {
      if (i % 8 == 0)
        printf ("  ");
      printf ("0x%04x,", t[i]);
      printf ((i % 8 == 7 || i == size - 1) ? "\n" : " ");
    }
  printf ("};\n\n");
}

void
gen_ktab (int argc, char **argv)
{
  /* forward tables (direct dump)                                                */
  print_char_tab ("to_full_20_7e", f_ascii, 95);
  print_char_tab ("to_fullkata_ff61_ff9f", fk_half, 63);
  print_char_tab ("to_fullhira_ff61_ff9f", fh_half, 63);
  print_char_tab ("to_fullkata_voiced_ff73_ff8e", fk_voiced, 28);
  print_char_tab ("to_fullhira_voiced_ff73_ff8e", fh_voiced, 28);
  print_char_tab ("to_fullkata_semi_voiced_ff8a_ff8e", fk_semi_voiced, 5);
  print_char_tab ("to_fullhira_semi_voiced_ff8a_ff8e", fh_semi_voiced, 5);

  /* reverse tables (computed from forward).
     cjk_to_half covers U+3000-U+30FC (CJK symbols + hiragana + katakana),
     excluding voiced/semi-voiced fullwidth chars (those go in cjk_*_voiced_base). */
  u_short cjk_to_half[CJK_RANGE_SIZE];
  u_short cjk_voiced_base[CJK_RANGE_SIZE];
  u_short cjk_semi_voiced_base[CJK_RANGE_SIZE];
  for (int i = 0; i < CJK_RANGE_SIZE; i++)
    {
      cjk_to_half[i] = 0;
      cjk_voiced_base[i] = 0;
      cjk_semi_voiced_base[i] = 0;
    }

  /* U+3000 (ideographic space) → U+0020 (ASCII space)                            */
  cjk_to_half[0] = 0x0020;

  /* Invert fk_half / fh_half tables.                                             */
  for (int i = 0; i < 63; i++)
    {
      u_short c = fk_half[i];
      if (c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_to_half[c - CJK_RANGE_MIN] = HALFWIDTH_KANA_MIN + i;
      c = fh_half[i];
      if (c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_to_half[c - CJK_RANGE_MIN] = HALFWIDTH_KANA_MIN + i;
    }

  /* Invert fk_voiced / fh_voiced. Halfwidth BASE = U+FF73 + i.                   */
  for (int i = 0; i < 28; i++)
    {
      u_short c = fk_voiced[i];
      if (c && c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_voiced_base[c - CJK_RANGE_MIN] = 0xff73 + i;
      c = fh_voiced[i];
      if (c && c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_voiced_base[c - CJK_RANGE_MIN] = 0xff73 + i;
    }

  /* Invert fk_semi_voiced / fh_semi_voiced. Halfwidth BASE = U+FF8A + i.         */
  for (int i = 0; i < 5; i++)
    {
      u_short c = fk_semi_voiced[i];
      if (c && c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_semi_voiced_base[c - CJK_RANGE_MIN] = 0xff8a + i;
      c = fh_semi_voiced[i];
      if (c && c >= CJK_RANGE_MIN && c <= CJK_RANGE_MAX)
        cjk_semi_voiced_base[c - CJK_RANGE_MIN] = 0xff8a + i;
    }

  print_char_tab ("to_half_width_cjk", cjk_to_half, CJK_RANGE_SIZE);
  print_char_tab ("voiced_to_half_cjk", cjk_voiced_base, CJK_RANGE_SIZE);
  print_char_tab ("semi_voiced_to_half_cjk", cjk_semi_voiced_base, CJK_RANGE_SIZE);

  /* Compose tables for map-to-full-width: unvoiced fullwidth + ゛/゜ → voiced
     fullwidth. Indexed by unvoiced char - FULL_WIDTH_{HIRAGANA,KATAKANA}_MIN.    */
#define HIRA_SIZE 0x54   /* U+3041-U+3094                                         */
#define KATA_SIZE 0x5A   /* U+30A1-U+30FA                                         */
  u_short voiced_from_hira[HIRA_SIZE], voiced_from_kata[KATA_SIZE];
  u_short semi_voiced_from_hira[HIRA_SIZE], semi_voiced_from_kata[KATA_SIZE];
  for (int i = 0; i < HIRA_SIZE; i++)
    { voiced_from_hira[i] = 0; semi_voiced_from_hira[i] = 0; }
  for (int i = 0; i < KATA_SIZE; i++)
    { voiced_from_kata[i] = 0; semi_voiced_from_kata[i] = 0; }

  /* fk_half / fh_half indices 18-45 hold unvoiced bases (halfwidth U+FF73-U+FF8E). */
  for (int i = 0; i < 28; i++)
    {
      u_short unv_k = fk_half[18 + i];
      u_short v_k = fk_voiced[i];
      if (v_k && unv_k >= 0x30a1 && unv_k <= 0x30fa)
        voiced_from_kata[unv_k - 0x30a1] = v_k;
      u_short unv_h = fh_half[18 + i];
      u_short v_h = fh_voiced[i];
      if (v_h && unv_h >= 0x3041 && unv_h <= 0x3094)
        voiced_from_hira[unv_h - 0x3041] = v_h;
    }
  /* Semi-voiced: halfwidth U+FF8A-U+FF8E = indices 41-45 in fk_half / fh_half.   */
  for (int i = 0; i < 5; i++)
    {
      u_short unv_k = fk_half[41 + i];
      u_short sv_k = fk_semi_voiced[i];
      if (sv_k && unv_k >= 0x30a1 && unv_k <= 0x30fa)
        semi_voiced_from_kata[unv_k - 0x30a1] = sv_k;
      u_short unv_h = fh_half[41 + i];
      u_short sv_h = fh_semi_voiced[i];
      if (sv_h && unv_h >= 0x3041 && unv_h <= 0x3094)
        semi_voiced_from_hira[unv_h - 0x3041] = sv_h;
    }
  print_char_tab ("voiced_from_hira", voiced_from_hira, HIRA_SIZE);
  print_char_tab ("voiced_from_kata", voiced_from_kata, KATA_SIZE);
  print_char_tab ("semi_voiced_from_hira", semi_voiced_from_hira, HIRA_SIZE);
  print_char_tab ("semi_voiced_from_kata", semi_voiced_from_kata, KATA_SIZE);

  /* Fullwidth ASCII reverse: U+FF01-U+FF5E → ASCII 0x21-0x7E (simple offset).    */
  u_short fullascii_to_half[FULL_ASCII_SIZE];
  for (int i = 0; i < FULL_ASCII_SIZE; i++)
    fullascii_to_half[i] = 0x21 + i;
  print_char_tab ("to_half_width_fullascii", fullascii_to_half, FULL_ASCII_SIZE);

  printf ("#define CJK_RANGE_MIN 0x%04x\n", CJK_RANGE_MIN);
  printf ("#define CJK_RANGE_MAX 0x%04x\n", CJK_RANGE_MAX);
  printf ("#define FULL_ASCII_MIN 0x%04x\n", FULL_ASCII_MIN);
  printf ("#define FULL_ASCII_MAX 0x%04x\n", FULL_ASCII_MAX);
  printf ("#define HALFWIDTH_KANA_MIN 0x%04x\n", HALFWIDTH_KANA_MIN);
  printf ("#define HALFWIDTH_KANA_MAX 0x%04x\n", HALFWIDTH_KANA_MAX);
  printf ("#define FULL_WIDTH_HIRAGANA_MIN 0x3041\n");
  printf ("#define FULL_WIDTH_HIRAGANA_MAX 0x3094\n");
  printf ("#define FULL_WIDTH_KATAKANA_MIN 0x30a1\n");
  printf ("#define FULL_WIDTH_KATAKANA_MAX 0x30fa\n");
  printf ("#define VOICED_SOUND_MARK 0x%04x\n", VOICED_MARK_CP);
  printf ("#define SEMI_VOICED_SOUND_MARK 0x%04x\n", SEMI_VOICED_MARK_CP);
  printf ("#define HALFWIDTH_VOICED_MARK 0x%04x\n", HALFWIDTH_VOICED_MARK);
  printf ("#define HALFWIDTH_SEMI_VOICED_MARK 0x%04x\n", HALFWIDTH_SEMI_VOICED_MARK);

  exit (0);
}
