// window-lisp.cc -- ウィンドウを触る Lisp 関数のうち、**プラットフォームに
// 依らないもの。**
//
// ここに集めた 13 個は src/frontend/win32/Window.cc と
// src/frontend/ncurses/ncurses-stubs.cc に**空白を除いて 1 文字も違わない形で
// 2 つあった。** 触るのは `Window' と `Buffer' — どちらも core のクラス
// (src/core/Window.h, src/core/Buffer.h) で、GUI の資源は出てこない。
//
// **同じものが 2 つある状態が実際にバグを産んでいる。** 補完エンジン
// (src/core/completion.cc) では片方だけにスタック破壊が残り (issue #49)、
// 片方だけが大文字小文字を無視していた (issue #111)。ミニバッファの
// プロンプト (src/core/minibuffer-read.cc) では片方が nil を返すだけの
// スタブだった (issue #114)。**測ったところ、この形の複製が他に 34 個
// あった。** その最初の 13 個をここへ移す。
//
// フロントエンドに残るのは `Window' のメソッドの実装
// (`split' / `delete_window' / `set_window' / `compute_geometry' など)。
// **宣言は core の Window.h にあるので、ここから呼べる。** 画面の実体を
// 持っているのはフロントエンドだけなので、その境界は保つ。
//
// 移していないもの:
//   * `Fselected_window' と `Fenlarge_window' は中身が違う (前者は win32 が
//     余分なことをし、後者はピクセルと文字セルで計算が違う)。
//   * `Fselected_window' と `Fenlarge_window' は中身が違っていたが、あとで
//     揃えて移した。
//
// **メニューの 5 個について、ここに間違ったことを書いていた。**
// 「`check_popup_menu' / `get_menu' / `find_tag_position' / `win32_menu_p' と
// いうフロントエンド側のヘルパに依っている」と書いたが、測ったら違った:
// `win32_menu_p' は core のマクロ、`check_popup_menu' は core で宣言済み、
// 残る 2 つが触るのは core のアクセサだけだった。**名前に win32 と付いて
// いるだけで Win32 だと決めつけていた。** src/core/menu-lisp.cc へ移した。

#include "stdafx.h"
#include "ed.h"

lisp
Fsplit_window (lisp arg, lisp verticalp)
{
  selected_window ()->split (!arg || arg == Qnil || arg == Qt ? 0 : fixnum_value (arg),
                             verticalp && verticalp != Qnil);
  return Qt;
}

lisp
Fdelete_window ()
{
  return boole (selected_window ()->delete_window ());
}

lisp
Fdelete_other_windows ()
{
  selected_window ()->delete_other_windows ();
  return Qt;
}

lisp
Fdeleted_window_p (lisp window)
{
  check_window (window);
  return boole (!xwindow_wp (window));
}

lisp
Fwindow_buffer (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  return wp->w_bufp ? wp->w_bufp->lbp : Qnil;
}

lisp
Fminibuffer_window_p (lisp window)
{
  check_window (window);
  return boole (xwindow_wp (window) && xwindow_wp (window)->minibuffer_window_p ());
}

lisp
Fnext_window (lisp window, lisp minibufp)
{
  Window *wp = Window::coerce_to_window (window);
  if (!minibufp)
    minibufp = Qnil;
  Window *next = wp->w_next;
  if (!next
      || (!next->w_bufp && minibufp != Qt)
      || (next->minibuffer_window_p ()
          && minibufp != Qnil && minibufp != Qt))
    next = app.active_frame.windows;
  return next->lwp;
}

lisp
Fprevious_window (lisp window, lisp minibufp)
{
  Window *wp = Window::coerce_to_window (window);
  if (!minibufp)
    minibufp = Qnil;
  Window *prev = wp->w_prev;
  if (!prev)
    prev = Window::minibuffer_window ();
  if ((!prev->w_bufp && minibufp != Qt)
      || (prev->minibuffer_window_p ()
          && minibufp != Qnil && minibufp != Qt))
    prev = prev->w_prev;
  return prev->lwp;
}

lisp
Fget_buffer_window (lisp buffer, lisp curwin)
{
  Buffer *bp = Buffer::coerce_to_buffer (buffer);
  Window *cwp = ((curwin && curwin != Qnil)
                 ? Window::coerce_to_window (curwin) : 0);
  int f = 0;
  for (Window *wp = app.active_frame.windows; wp; wp = wp->w_next)
    if (wp->w_bufp == bp)
      {
        if (wp != cwp)
          return wp->lwp;
        if (f)
          return wp->lwp;
        f = 1;
      }
  return f ? cwp->lwp : Qnil;
}

lisp
Fset_window (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  wp->set_window ();
  return Qt;
}

lisp
Fget_window_line (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  return make_fixnum (wp->w_bufp->b_fold_columns == Buffer::FOLD_NONE
                      ? (wp->w_bufp->point_linenum (wp->w_point)
                         - wp->w_bufp->point_linenum (wp->w_disp))
                      : (wp->w_bufp->folded_point_linenum (wp->w_point)
                         - wp->w_bufp->folded_point_linenum (wp->w_disp)));
}

lisp
Fget_window_start_line (lisp window)
{
  Window *wp = Window::coerce_to_window (window);
  if (!wp->w_bufp)
    return Qnil;
  return make_fixnum (wp->w_bufp->b_fold_columns == Buffer::FOLD_NONE
                      ? wp->w_bufp->point_linenum (wp->w_disp)
                      : wp->w_bufp->folded_point_linenum (wp->w_disp));
}

lisp
Fwindow_coordinate (lisp lwindow)
{
  Window *wp = Window::coerce_to_window (lwindow);
  return make_list (make_fixnum (wp->w_rect.left),
                    make_fixnum (wp->w_rect.top),
                    make_fixnum (wp->w_rect.right),
                    make_fixnum (wp->w_rect.bottom),
                    0);
}


/* `Window::coerce_to_window' も win32 と ncurses に 1 文字も違わない形で
   2 つあった。**メソッドだが中身は core だけ** (selected_window /
   check_window / xwindow_wp) なので、ここに置く。CLI も含め 3 つの
   フロントエンドが同じものを使えるようになる。

   引数が無い / nil なら選択中のウィンドウ、というのがこの関数の要点で、
   ここを取り違えると「引数省略が効かない」形で静かに壊れる。 */
Window *
Window::coerce_to_window (lisp object)
{
  if (!object || object == Qnil)
    return selected_window ();
  check_window (object);
  if (!xwindow_wp (object))
    FEprogram_error (Edeleted_window);
  return xwindow_wp (object);
}

/* **null を返す形に揃えた。** win32 側は `assert` 2 つのあと
   `selected_window ()->lwp` を返していて、選択中のウィンドウが無いときは
   ヌル参照になる。端末側は `?:` で nil を返していた。**`assert` は
   リリースビルドで消えるので、win32 側は実質何も守っていない。**

   画面がまだ無い (端末の起動途中) / そもそも無い (ヘッドレスの CLI) 状態は
   実在するので、Lisp から呼んで落ちない方を採る。不変条件の検査は
   ウィンドウが在るときだけ残した。 */
lisp
Fselected_window ()
{
  Window *wp = selected_window ();
  if (!wp)
    return Qnil;
  assert (xwindow_wp (wp->lwp) == wp);
  return wp->lwp;
}

/* `Window::enlarge_window' は src/core/Window.h で宣言されている seam。
   **端末側はこれを実装せず、この Lisp 関数の中に 80 行のジオメトリ計算を
   直に書いていた**ので、同じ関数が 2 つの別物になっていた。実装を
   src/frontend/ncurses/ncurses-stubs.cc のメソッドへ移したので、入口は
   1 つで済む。 */
lisp
Fenlarge_window (lisp nlines, lisp side)
{
  Window *wp = selected_window ();
  if (!wp
      || !wp->enlarge_window ((!nlines || nlines == Qnil)
                              ? 1 : fixnum_value (nlines),
                              side && side != Qnil))
    FEsimple_error (Ecannot_change_window_size);
  return Qt;
}
