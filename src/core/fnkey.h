#ifndef _fnkey_h_
# define _fnkey_h_

/* ファンクションバーの「ラベルの数え方」。**GUI の話ではない**ので core に
   残してある (issue #185)。

   `MAX_Fn` はファンクションキーの本数 (`CCF_F1`..`CCF_Fn_MAX` の幅)、
   `MAX_FUNCTION_BAR_LABEL` はラベルを置ける総数で、**シフト / コントロール /
   メタの組み合わせ 8 通りぶん**ある。ラベルを入れるベクタの大きさを決めるのに
   使うので、**端末のフロントエンドも読む**
   (src/frontend/ncurses/ncurses-main.cc)。

   **`FKWin` (Win32 のファンクションバーのウィンドウ) はここに居た。** GUI の
   クラスなのに core に居たので、端末とヘッドレスのフロントエンドが
   `FKWin::fk_default_nbuttons` の定義を置く必要があった。
   src/frontend/win32/fkwin.h へ移した。ラベルの数の設定値は
   `g_fnkey_default_nbuttons` (src/core/environ.h) にある。 */

# define MAX_Fn (CCF_Fn_MAX - CCF_F1 + 1)
# define MAX_FUNCTION_BAR_LABEL (MAX_Fn * 8)

#endif /* _fnkey_h_ */
