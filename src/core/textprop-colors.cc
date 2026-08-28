// 「文字1〜文字15」— set-text-attribute の :foreground / :background が指す
// 16 色表と、それを Lisp から差し替えるための入口。
//
// この表 (Window::w_textprop_forecolor / w_textprop_backcolor) は、共通設定→
// 表示色のダイアログからしか変えられなかった。カラーテーマ (lisp/color-theme.l)
// が書き換えるのは set-buffer-colors の役割色 (USER_DEFINABLE_COLORS) という
// **別の表**なので、:foreground を使う色付け — tree-sitter、calendar の土日、
// diff、hideif、ispell — だけがテーマから取り残され、選んだ配色の上に
// 赤・緑・黄の固定色で塗り重なっていた (issue #98)。
//
// 表の定義もここへ移した。以前は src/frontend/win32/Window.cc にあり、端末
// フロントエンドには存在しなかったので、共通のコードから触れなかった。
//
// x 付き (w_textprop_xforecolor) が「設定として保存されている値」、x 無しが
// 「実際に描画で使う値」である。Window::init_colors が x → 実値へ写して
// xyzzy.ini へ書く。ここの入口は**実値だけを書き換え、ini には書かない。**
// テーマは一時的な上書きであってユーザーの表示色設定ではないので、テーマを
// 解除したら元へ戻せなければならない (nil を渡すと x から戻す)。

#include "stdafx.h"
#include "ed.h"
#include "Window.h"

COLORREF Window::w_textprop_forecolor[GLYPH_TEXTPROP_NCOLORS] =
{
  RGB (0x00, 0x00, 0x00),
  RGB (0xff, 0x00, 0x00),
  RGB (0x00, 0xff, 0x00),
  RGB (0xff, 0xff, 0x00),
  RGB (0x00, 0x00, 0xff),
  RGB (0xff, 0x00, 0xff),
  RGB (0x00, 0xff, 0xff),
  RGB (0xff, 0xff, 0xff),
  RGB (0x00, 0x00, 0x00),
  RGB (0x80, 0x00, 0x00),
  RGB (0x00, 0x80, 0x00),
  RGB (0x80, 0x80, 0x00),
  RGB (0x00, 0x00, 0x80),
  RGB (0x80, 0x00, 0x80),
  RGB (0x00, 0x80, 0x80),
  RGB (0x80, 0x80, 0x80),
};

COLORREF Window::w_textprop_backcolor[GLYPH_TEXTPROP_NCOLORS] =
{
  RGB (0x00, 0x00, 0x00),
  RGB (0xff, 0x00, 0x00),
  RGB (0x00, 0xff, 0x00),
  RGB (0xff, 0xff, 0x00),
  RGB (0x00, 0x00, 0xff),
  RGB (0xff, 0x00, 0xff),
  RGB (0x00, 0xff, 0xff),
  RGB (0xff, 0xff, 0xff),
  RGB (0x00, 0x00, 0x00),
  RGB (0x80, 0x00, 0x00),
  RGB (0x00, 0x80, 0x00),
  RGB (0x80, 0x80, 0x00),
  RGB (0x00, 0x00, 0x80),
  RGB (0x80, 0x00, 0x80),
  RGB (0x00, 0x80, 0x80),
  RGB (0x80, 0x80, 0x80),
};

// **既定値で初期化しておく。** 端末フロントエンドでは Window::init_colors が
// 空実装で、ここへ ini の値を写す処理が走らない。ゼロのままだと
// (set-text-attribute-colors nil) が全部を黒にしてしまう。
XCOLORREF Window::w_textprop_xforecolor[GLYPH_TEXTPROP_NCOLORS] =
{
  RGB (0x00, 0x00, 0x00),
  RGB (0xff, 0x00, 0x00),
  RGB (0x00, 0xff, 0x00),
  RGB (0xff, 0xff, 0x00),
  RGB (0x00, 0x00, 0xff),
  RGB (0xff, 0x00, 0xff),
  RGB (0x00, 0xff, 0xff),
  RGB (0xff, 0xff, 0xff),
  RGB (0x00, 0x00, 0x00),
  RGB (0x80, 0x00, 0x00),
  RGB (0x00, 0x80, 0x00),
  RGB (0x80, 0x80, 0x00),
  RGB (0x00, 0x00, 0x80),
  RGB (0x80, 0x00, 0x80),
  RGB (0x00, 0x80, 0x80),
  RGB (0x80, 0x80, 0x80),
};

XCOLORREF Window::w_textprop_xbackcolor[GLYPH_TEXTPROP_NCOLORS] =
{
  RGB (0x00, 0x00, 0x00),
  RGB (0xff, 0x00, 0x00),
  RGB (0x00, 0xff, 0x00),
  RGB (0xff, 0xff, 0x00),
  RGB (0x00, 0x00, 0xff),
  RGB (0xff, 0x00, 0xff),
  RGB (0x00, 0xff, 0xff),
  RGB (0xff, 0xff, 0xff),
  RGB (0x00, 0x00, 0x00),
  RGB (0x80, 0x00, 0x00),
  RGB (0x00, 0x80, 0x00),
  RGB (0x80, 0x80, 0x00),
  RGB (0x00, 0x00, 0x80),
  RGB (0x80, 0x00, 0x80),
  RGB (0x00, 0x80, 0x80),
  RGB (0x80, 0x80, 0x80),
};

// 添字 0 は「文字色」を指す番号で、この表は引かれない (glyph.cc の kwd_val が
// GLYPH_TEXTPROP_FG_BIT を立てるのは添字が 0 以外のときだけ)。なので 1 から。
static void
store_textprop_colors (lisp seq, COLORREF *dest, const XCOLORREF *saved)
{
  if (seq == Qt)
    return;                     // このまま変えない
  if (seq == Qnil)
    {
      for (int i = 1; i < GLYPH_TEXTPROP_NCOLORS; i++)
        dest[i] = saved[i];
      return;
    }
  check_general_vector (seq);
  int n = min (int (GLYPH_TEXTPROP_NCOLORS), xvector_length (seq));
  for (int i = 1; i < GLYPH_TEXTPROP_NCOLORS; i++)
    dest[i] = (i < n && xvector_contents (seq) [i] != Qnil
               ? COLORREF (fixnum_value (xvector_contents (seq) [i]))
               : COLORREF (saved[i]));
}

lisp
Fset_text_attribute_colors (lisp lfg, lisp lbg)
{
  store_textprop_colors (lfg, Window::w_textprop_forecolor,
                         Window::w_textprop_xforecolor);
  store_textprop_colors (lbg, Window::w_textprop_backcolor,
                         Window::w_textprop_xbackcolor);
  Window::textprop_colors_changed ();
  return Qt;
}

lisp
Fget_text_attribute_colors (lisp lbackground)
{
  const COLORREF *src = (lbackground != Qnil && lbackground != 0
                         ? Window::w_textprop_backcolor
                         : Window::w_textprop_forecolor);
  lisp v = make_vector (GLYPH_TEXTPROP_NCOLORS, Qnil);
  for (int i = 0; i < GLYPH_TEXTPROP_NCOLORS; i++)
    xvector_contents (v) [i] = make_fixnum (src[i]);
  return v;
}
