#include "stdafx.h"
#include "ed.h"

#define KEYMAP_LENGTH (128 + 4 * NFUNCTION_KEYS)

static inline u_int
keymap_length (lisp map)
{
  return u_int (xvector_length (map));
}

lisp
Fkeymapp (lisp map)
{
  if (map == Qnil)
    return Qnil;
  if (symbolp (map))
    map = xsymbol_function (map);
  if (general_vector_p (map))
    return xvector_length (map) == KEYMAP_LENGTH ? map : Qnil;
  return consp (map) && xcar (map) == Qkeymap ? map : Qnil;
}

lisp
Fmake_keymap ()
{
  lisp map = make_vector (KEYMAP_LENGTH, Qnil);
  return map;
}

lisp
Fmake_sparse_keymap ()
{
  return xcons (Qkeymap, Qnil);
}

/* 旧 Char encoding (上位 bit すべて 0) を受けた場合に新 lChar encoding に
   正規化する shim。Phase 1 中は cmdloop/kbd 側が旧 Char 形式を渡してくる
   ので、keymap 内部で一貫して新 encoding で扱うための変換点。                 */
static inline lChar
normalize_for_keymap (lChar lc)
{
  if (LCHAR_KIND (lc) == LCKIND_MOUSE)
    return lc_from_raw_mouse (lc);
  if (!(lc & ~lChar (0xFFFF)))
    return lc_from_ccf (Char (lc));
  return lc;
}

static u_int
full_keymap_index (lChar lc)
{
  lc = normalize_for_keymap (lc);
  if (LCHAR_KIND (lc) == LCKIND_FNKEY)
    {
      int x = 128 + int (LCHAR_PAYLOAD (lc));
      if (lc & LCMOD_SHIFT)
        x += NFUNCTION_KEYS;
      if (lc & LCMOD_CTRL)
        x += 2 * NFUNCTION_KEYS;
      return x;
    }
  if (LCHAR_KIND (lc) == LCKIND_CHAR && !LCHAR_MODS (lc))
    {
      lChar cp = LCHAR_PAYLOAD (lc);
      return cp < 128 ? u_int (cp) : u_int (-1);
    }
  return u_int (-1);
}

lisp
parse_keymap (lChar lc, lisp map)
{
  lc = normalize_for_keymap (lc);
  if (general_vector_p (map))
    {
      u_int i = full_keymap_index (lc);
      if (i < keymap_length (map))
        return xvector_contents (map) [i];
      return Qnil;
    }
  if (consp (map) && xcar (map) == Qkeymap)
    {
      /* 既存の sparse keymap には旧 Char encoding の char object が
         格納されているため、lc を一旦旧形式に戻して eq 比較する。
         Task #12 で Lisp char 自体を lChar 化すれば、この変換は
         ccf_from_lc を直接 make_char へ渡す形で残り、その後 Lisp char が
         lChar 値を持つよう改修された時点で不要になる見込み。           */
      lisp cc = make_char (ccf_from_lc (lc));
      for (map = xcdr (map); consp (map); map = xcdr (map))
        {
          lisp p = xcar (map);
          if (consp (p) && xcar (p) == cc)
            return xcdr (p);
        }
    }
  return Qnil;
}

lisp
Fcurrent_selection_keymap ()
{
  Window *wp = selected_window ();
  if (wp->w_selection_type != Buffer::SELECTION_VOID)
    switch (wp->w_selection_type & Buffer::SELECTION_TYPE_MASK)
      {
      case Buffer::SELECTION_LINEAR:
      case Buffer::SELECTION_REGION:
      case Buffer::SELECTION_RECTANGLE:
        return Fkeymapp (symbol_value (Vselection_keymap, wp->w_bufp));
      }
  return Qnil;
}

lisp
lookup_keymap (lChar lc, lisp *map, int n)
{
  lc = normalize_for_keymap (lc);
  int i;
  if (lc & LCMOD_META)
    {
      for (i = 0; i < n; i++)
        map[i] = parse_keymap (lChar (CC_ESC), Fkeymapp (map[i]));
      lc &= ~LCMOD_META;
    }

  /* case-insensitive fallback 用のスナップショット。Lisp char alpha 判定は
     LCKIND_CHAR かつ ASCII 範囲の場合のみ有効 */
  lisp *save = 0;
  if (LCHAR_KIND (lc) == LCKIND_CHAR
      && LCHAR_PAYLOAD (lc) < 128
      && alpha_char_p (int (LCHAR_PAYLOAD (lc))))
    {
      save = (lisp *)alloca (sizeof *save * n);
      memcpy (save, map, sizeof *save * n);
    }

  for (i = 0; i < n; i++)
    {
      map[i] = parse_keymap (lc, Fkeymapp (map[i]));
      if (map[i] != Qnil)
        save = 0;
    }

  if (save)
    {
      /* case flip: ASCII code point のみ反転、kind/mod は保持 */
      lChar flipped = (lc & ~LCHAR_PAYLOAD_MASK)
                      | lChar (_char_transpose_case (int (LCHAR_PAYLOAD (lc))));
      for (i = 0; i < n; i++)
        map[i] = parse_keymap (flipped, Fkeymapp (save[i]));
    }

  int f_contunue = 0;
  for (i = 0; i < n; i++)
    if (map[i] != Qnil)
      {
        if (!f_contunue && Fkeymapp (map[i]) == Qnil)
          return map[i];
        f_contunue = 1;
      }
  return f_contunue ? 0 : Qnil;
}

lisp
Fuse_keymap (lisp keymap, lisp buffer)
{
  if (Fkeymapp (keymap) == Qnil)
    FEtype_error (keymap, Qkeymap);
  Buffer::coerce_to_buffer (buffer)->lmap = keymap;
  return Qt;
}

lisp
Fset_minor_mode_map (lisp keymap, lisp buffer)
{
  if (Fkeymapp (keymap) == Qnil)
    FEtype_error (keymap, Qkeymap);
  Buffer *bp = Buffer::coerce_to_buffer (buffer);
  if (!memq (keymap, bp->lminor_map))
    bp->lminor_map = xcons (keymap, bp->lminor_map);
  return Qt;
}

lisp
Funset_minor_mode_map (lisp keymap, lisp buffer)
{
  Buffer *bp = Buffer::coerce_to_buffer (buffer);
  return boole (delq (keymap, &bp->lminor_map));
}

lisp
Fminor_mode_map (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lminor_map;
}

static lisp *
scan_key_slot (lisp keymap, lChar lc, int igcase)
{
  /* ASCII alpha の case fallback 用判定を一度だけ評価 */
  int alpha_p = (LCHAR_KIND (lc) == LCKIND_CHAR
                 && LCHAR_PAYLOAD (lc) < 128
                 && alpha_char_p (int (LCHAR_PAYLOAD (lc))));

  if (general_vector_p (keymap))
    {
      u_int i = full_keymap_index (lc);
      if (i >= keymap_length (keymap))
        return 0;
      lisp *v = &xvector_contents (keymap) [i];
      if (!igcase || *v != Qnil || !alpha_p)
        return v;
      lChar flipped = (lc & ~LCHAR_PAYLOAD_MASK)
                      | lChar (_char_transpose_case (int (LCHAR_PAYLOAD (lc))));
      i = full_keymap_index (flipped);
      if (i >= keymap_length (keymap))
        return 0;
      return &xvector_contents (keymap) [i];
    }

  /* sparse keymap: 既存エントリは旧 Char 形式で格納。ccf_from_lc で戻して eq 比較 */
  lisp cc = make_char (ccf_from_lc (lc));
  for (lisp p = keymap; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (consp (x) && xcar (x) == cc)
        return &xcdr (x);
    }

  if (igcase && alpha_p)
    {
      cc = make_char (Char (_char_transpose_case (int (LCHAR_PAYLOAD (lc)))));
      for (lisp p = keymap; consp (p); p = xcdr (p))
        {
          lisp x = xcar (p);
          if (consp (x) && xcar (x) == cc)
            return &xcdr (x);
        }
    }

  return 0;
}

static lisp *
make_key_slot (lisp keymap, lChar lc)
{
  if (general_vector_p (keymap))
    {
      u_int i = full_keymap_index (lc);
      if (i >= keymap_length (keymap))
        return 0;
      return &xvector_contents (keymap) [i];
    }

  if (consp (keymap))
    {
      lisp x = xcons (make_char (ccf_from_lc (lc)), Qnil);
      xcdr (keymap) = xcons (x, xcdr (keymap));
      return &xcdr (x);
    }
  return 0;
}

static lisp *
search_key_slot (lisp keymap, lisp key, int bindp, int igcase)
{
  lisp *v;
  lisp map = Fkeymapp (keymap);
  if (map == Qnil)
    FEtype_error (keymap, Qkeymap);

  if (charp (key))
    {
      /* xchar_code は当面 Char (16bit, 旧 encoding) を返す。
         lc_from_ccf で lChar (新 encoding) に昇格してから処理。 */
      lChar lc = lc_from_ccf (xchar_code (key));

      if (!(lc & LCMOD_META))
        {
          v = scan_key_slot (map, lc, igcase);
          if (v || !bindp)
            return v;
          return make_key_slot (map, lc);
        }

      /* Meta は ESC prefix への indirection で表現 */
      lc &= ~LCMOD_META;

      v = scan_key_slot (map, lChar (CC_ESC), igcase);
      if (!v)
        {
          if (!bindp)
            return 0;
          v = make_key_slot (map, lChar (CC_ESC));
          if (!v)
            return 0;
          map = *v = Fmake_sparse_keymap ();
        }
      else
        {
          map = Fkeymapp (*v);
          if (map == Qnil)
            {
              if (!bindp)
                return 0;
              map = *v = Fmake_sparse_keymap ();
            }
        }

      v = scan_key_slot (map, lc, igcase || !bindp);
      if (v || !bindp)
        return v;
      return make_key_slot (map, lc);
    }

  if (!consp (key))
    FEtype_error (key, xsymbol_value (Qor_character_cons));

  while (1)
    {
      v = search_key_slot (map, xcar (key), bindp, igcase);
      if (!v)
        return 0;
      key = xcdr (key);
      if (!consp (key))
        return v;
      map = Fkeymapp (*v);
      if (map == Qnil)
        {
          if (!bindp)
            return 0;
          map = *v = Fmake_sparse_keymap ();
        }
      if (!bindp)
        igcase = 1;
    }
}

lisp
Fdefine_key (lisp keymap, lisp key, lisp fn)
{
  lisp *x = search_key_slot (keymap, key, 1, 0);
  if (!x)
    return Qnil;
  *x = fn;
  return Qt;
}

lisp LISP_CALL
Flookup_keymap (lisp keymap, lisp key, lisp ignore_case, lisp symbol_only)
{
  lisp *x = search_key_slot (keymap, key, 0, ignore_case && ignore_case != Qnil);
  if (!x)
    return Qnil;
  if (symbol_only && symbol_only != Qnil)
    return symbolp (*x) ? *x : Qnil;
  return *x;
}

lisp
Flocal_keymap (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lmap;
}

lisp
Fkeymap_index_char (lisp code)
{
  int n = fixnum_value (code);
  if (n < 0 || n >= KEYMAP_LENGTH)
    return Qnil;

  if (n < 128)
    return make_char (n);

  n -= 128;
  Char c = CCF_CHAR_MIN + n % NFUNCTION_KEYS;
  n /= NFUNCTION_KEYS;
  if (n & 1)
    c |= CCF_SHIFT_BIT;
  if (n & 2)
    c |= CCF_CTRL_BIT;
  return make_char (c);
}

lisp
Fkeymap_char_index (lisp c)
{
  check_char (c);
  u_int i = full_keymap_index (lc_from_ccf (xchar_code (c)));
  return i < KEYMAP_LENGTH ? make_fixnum (i) : Qnil;
}

static lisp *
expand_keymap (lisp keymap, lisp *buf)
{
  if (general_vector_p (keymap))
    return xvector_contents (keymap);

  for (int i = 0; i < KEYMAP_LENGTH; i++)
    buf[i] = Qnil;

  if (consp (keymap) && xcar (keymap) == Qkeymap)
    for (lisp p = xcdr (keymap); consp (p); p = xcdr (p))
      {
        lisp x = xcar (p);
        if (consp (x) && charp (xcar (x)))
          {
            u_int idx = full_keymap_index (lc_from_ccf (xchar_code (xcar (x))));
            if (idx < KEYMAP_LENGTH)
              buf[idx] = xcdr (x);
          }
      }
  return buf;
}

struct keyseq_list
{
  keyseq_list *prev;
  keyseq_list *next;
  lChar c;
};

static int
command_shadow_p (const keyseq_list *p, lisp keymap)
{
  for (; p; p = p->next)
    {
      keymap = parse_keymap (p->c, Fkeymapp (keymap));
      if (keymap == Qnil)
        return 0;
    }
  return 1;
}

static int
command_shadow_p (keyseq_list *tail, const lisp *shadow, int nshadow)
{
  keyseq_list *head, *last;
  for (head = tail, last = 0;
       (head->next = last), head->prev;
       last = head, head = head->prev)
    ;

  for (int i = 0; i < nshadow; i++)
    if (command_shadow_p (head, shadow[i]))
      return 1;
  return 0;
}

static lisp
command_keys (lisp command, lisp keymap, keyseq_list *prev,
              const lisp *shadow, int nshadow)
{
  keyseq_list keyseq;
  keyseq.prev = prev;
  int i;
  lisp result = Qnil;
  lisp b[KEYMAP_LENGTH];
  lisp *map = expand_keymap (Fkeymapp (keymap), b);
  lisp *p;
  for (i = 0, p = map; i < KEYMAP_LENGTH; i++, p++)
    if (*p == command)
      {
        lisp ch = Fkeymap_index_char (make_fixnum (i));
        keyseq.c = lc_from_ccf (xchar_code (ch));
        if (!command_shadow_p (&keyseq, shadow, nshadow))
          result = Fcons (ch, result);
      }

  for (i = 0, p = map; i < KEYMAP_LENGTH; i++, p++)
    if (Fkeymapp (*p) != Qnil)
      {
        lisp ch = Fkeymap_index_char (make_fixnum (i));
        keyseq.c = lc_from_ccf (xchar_code (ch));
        lisp sub = command_keys (command, *p, &keyseq, shadow, nshadow);
        if (sub != Qnil)
          result = Fcons (Fcons (ch, sub), result);
      }

  return Fnreverse (result);
}

lisp
Fcommand_keys (lisp command, lisp gmap, lisp lmap, lisp minor_map)
{
  if (!minor_map)
    minor_map = Qnil;
  int nmaps = xlist_length (minor_map) + 2;
  lisp *map = (lisp *)alloca (nmaps * sizeof *map);
  lisp *p;
  for (p = map; consp (minor_map); minor_map = xcdr (minor_map))
    *p++ = xcar (minor_map);
  *p++ = lmap;
  *p++ = gmap;

  lisp result = Qnil;
  for (int i = 0; i < nmaps; i++)
    {
      lisp r = command_keys (command, map[i], 0, map, i);
      if (consp (r))
        {
          lisp x;
          for (x = r; consp (xcdr (x)); x = xcdr (x))
            ;
          xcdr (x) = result;
          result = r;
        }
    }
  return result;
}

/* 外部 (menu.cc 等) からは Char* で keyseq を保持したままの方が
   呼び出し側の blast radius が小さい。内部で parse_keymap 呼ぶ時だけ
   lc_from_ccf で lChar に昇格する。Phase 1 後半 (Task #12) で
   Lisp char が lChar 化すれば Char* → lChar* の移行も検討する。      */
static int
command_shadow_p (const Char *b, const Char *be, lisp keymap)
{
  for (; b < be; b++)
    {
      keymap = parse_keymap (lc_from_ccf (*b), Fkeymapp (keymap));
      if (keymap == Qnil)
        return 0;
    }
  return 1;
}

static int
command_shadow_p (const Char *b, const Char *be, const lisp *shadow, int nshadow)
{
  for (int i = 0; i < nshadow; i++)
    if (command_shadow_p (b, be, shadow[i]))
      return 1;
  return 0;
}

Char *
lookup_command_keyseq (lisp command, lisp keymap, const lisp *shadow, int nshadow,
                       Char *keyb, Char *keyp, Char *keye)
{
  if (keyp == keye)
    return 0;

  int i;
  lisp *p;
  lisp b[KEYMAP_LENGTH];
  lisp *map = expand_keymap (Fkeymapp (keymap), b);

  for (i = 0, p = map; i < KEYMAP_LENGTH; i++, p++)
    if (*p == command)
      {
        *keyp++ = xchar_code (Fkeymap_index_char (make_fixnum (i)));
        if (!command_shadow_p (keyb, keyp, shadow, nshadow))
          return keyp;
      }

  for (i = 0, p = map; i < KEYMAP_LENGTH; i++, p++)
    if (Fkeymapp (*p) != Qnil)
      {
        *keyp = xchar_code (Fkeymap_index_char (make_fixnum (i)));
        Char *e = lookup_command_keyseq (command, *p, shadow, nshadow, keyb, keyp + 1, keye);
        if (e)
          return e;
      }
  return 0;
}

static int
find_in_current_keymaps (lChar lc, lisp map)
{
  lisp command = parse_keymap (lc, map);
  return command != Qnil && Fkeymapp (command) == Qnil;
}

int
find_in_current_keymaps (lChar lc)
{
  if (find_in_current_keymaps (lc, xsymbol_value (Vglobal_keymap)))
    return 1;

  Buffer *bp = selected_buffer ();
  if (find_in_current_keymaps (lc, bp->lmap))
    return 1;

  if (Flist_length (bp->lminor_map) != Qnil)
    for (lisp p = bp->lminor_map; consp (p); p = xcdr (p))
      if (find_in_current_keymaps (lc, xcar (p)))
        return 1;

  if (find_in_current_keymaps (lc, Fcurrent_selection_keymap ()))
    return 1;

  return 0;
}
