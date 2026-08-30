// menu-lisp.cc -- メニューを触る Lisp 関数のうち、**プラットフォームに
// 依らないもの。**
//
// ここに集めた 5 個とヘルパ 3 個は src/frontend/win32/menu.cc と
// src/frontend/ncurses/ncurses-stubs.cc に**空白を除いて 1 文字も違わない形で
// 2 つあった。**
//
// **一度「移せない」と判断して間違えた場所である。** src/core/window-lisp.cc
// の冒頭に「`win32_menu_p` などフロントエンド側のヘルパに依っている」と
// 書いたが、測ったら違った:
//
//   * `win32_menu_p` は **core のマクロ** (src/core/ed.h)。
//   * `check_popup_menu` は **core で宣言されている** (同じく ed.h)。
//     フロントエンドが定義を 2 つ持っていただけ。
//   * `find_tag_position` と `get_menu` が触るのは `xwin32_menu_tag` /
//     `xwin32_menu_handle` / `xwin32_menu_items` で、前 2 つは core の
//     アクセサ。
//
// **名前に win32 と付いているだけで Win32 だと決めつけていた。** `HMENU` の
// 値は `lwin32_menu` の中に入っているが、それを解釈するのはフロントエンド
// だけで、ここは「ハンドルが立っているか」しか見ない。
//
// 移すときに 1 つだけ本当に足りないものがあった: `xwin32_menu_items` は
// **両フロントエンドがローカルに `#define xwin32_menu_items
// xwin32_menu_command` と書いていた。** 同じ枠が葉では「コマンド」、
// ポップアップでは「中の項目のリスト」という二役を持つ。名前ごと
// src/core/ed.h へ上げて、その二役を説明するコメントを付けた。

#include "stdafx.h"
#include "ed.h"

void
check_popup_menu (lisp lmenu)
{
  check_win32_menu (lmenu);
  if (!xwin32_menu_handle (lmenu))
    {
      if (!xwin32_menu_id (lmenu))
        FEprogram_error (Euninitialized_menu_item);
      FEprogram_error (Eis_not_popup_menu);
    }
}


static int
find_tag_position (lisp &lmenu, lisp tag)
{
  for (lisp p = xwin32_menu_items (lmenu); consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (xwin32_menu_tag (x) == tag)
        return xlist_length (xcdr (p));
      if (xwin32_menu_handle (x))
        {
          int pos = find_tag_position (x, tag);
          if (pos >= 0)
            {
              lmenu = x;
              return pos;
            }
        }
    }
  return -1;
}


/* `Fdelete_menu' が両フロントエンドで使うので公開する (宣言は
   src/core/ed.h)。**あちらは本物のメニューを触るので移せない。** */
lisp
get_menu (lisp lmenu, lisp tag, lisp positionp, int &pos)
{
  check_popup_menu (lmenu);
  if (positionp && positionp != Qnil)
    {
      pos = fixnum_value (tag);
      if (pos < 0)
        FErange_error (tag);
    }
  else
    {
      pos = find_tag_position (lmenu, tag);
      if (pos < 0)
        return Qnil;
    }

  int l = xlist_length (xwin32_menu_items (lmenu));
  if (pos >= l)
    return Qnil;

  l -= pos + 1;
  return Fnth (make_fixnum (l), xwin32_menu_items (lmenu));
}

lisp
Fset_menu (lisp lmenu)
{
  if (lmenu != Qnil)
    check_popup_menu (lmenu);
  xsymbol_value (Vdefault_menu) = lmenu;
  return lmenu;
}

lisp
Fget_menu (lisp lmenu, lisp tag, lisp positionp)
{
  int pos;
  return get_menu (lmenu, tag, positionp, pos);
}

lisp
Fget_menu_position (lisp lmenu, lisp tag)
{
  check_popup_menu (lmenu);
  int pos = find_tag_position (lmenu, tag);
  if (pos < 0)
    return Qnil;
  multiple_value::count () = 2;
  multiple_value::value (1) = lmenu;
  return make_fixnum (pos);
}

lisp
Fcurrent_menu (lisp buffer)
{
  if (!buffer)
    return (win32_menu_p (selected_buffer ()->lmenu)
            ? selected_buffer ()->lmenu
            : xsymbol_value (Vdefault_menu));
  else if (buffer == Qnil)
    return xsymbol_value (Vdefault_menu);
  else
    return Buffer::coerce_to_buffer (buffer)->lmenu;
}

lisp
Fuse_local_menu (lisp lmenu)
{
  if (lmenu != Qnil)
    check_popup_menu (lmenu);
  selected_buffer ()->lmenu = lmenu;
  return lmenu;
}

