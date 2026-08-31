#ifndef _fkwin_h_
# define _fkwin_h_

/* Win32 のファンクションバーのウィンドウ。**src/core/fnkey.h に居た**が、
   GUI のクラスなので core から出した (issue #185)。ラベルの数え方
   (`MAX_Fn` / `MAX_FUNCTION_BAR_LABEL`) は端末も読むので core に残してある。

   **ここに居たせいで、端末とヘッドレスのフロントエンドが
   `FKWin::fk_default_nbuttons` の定義を置く必要があった。** */

/* **ラベルの数え方のために自分で include する** (`MAX_Fn` を使う)。 */
# include "fnkey.h"

LRESULT CALLBACK fnkey_wndproc (HWND, UINT, WPARAM, LPARAM);

extern const wchar_t FunctionKeyClassName[];

class FKWin
{
protected:
  HWND fk_hwnd;    //
  SIZE fk_sz;      // クライアント領域のサイズ
  SIZE fk_btn;     // ボタンサイズ
  int fk_nbuttons; // ボタンの数
  int fk_height;   // FKWinの高さ
  int fk_offset[MAX_Fn]; // 各ボタンの開始位置

  RECT fk_cur_rect; // 処理対象(fk_cur_btn)の矩形
  int fk_cur_btn;   // 処理対象ボタン(なければ-1)
  int fk_cur_on;    // 沈んでいるボタン(必ずfk_cur_btnと同じか-1)
  int fk_vkey;      // シフトキーの状態
  enum
    {
      FVK_SHIFT = 1,
      FVK_CONTROL = 2,
      FVK_META = 4
    };

  void get_button_rect (int, RECT &) const;
  void paint_off (HDC hdc, int n, const RECT &r) const;
  void paint_on (HDC hdc, int n, const RECT &r) const;
  void paint_text (HDC, int, const RECT &, int) const;
  void paint_buttons (HDC) const;
  void button_on (int);
  int vk2fvk (int) const;

  struct divinfo
    {
      int nbuttons;
      int ndiv;
    };
  static const divinfo fk_divinfo[];

public:
  FKWin ();
  void refresh_button (int) const;
  void set_hwnd (HWND hwnd) {fk_hwnd = hwnd;};
  HWND hwnd () const {return fk_hwnd;}
  int height () const {return fk_height;}
  void OnPaint ();
  void OnSize (int, int);
  void OnLButtonDown (int, int, int);
  void OnLButtonUp (int, int, int);
  void OnMouseMove (int, int, int);
  void OnKillFocus ();
  void OnCancelMode ();
  void set_vkey (int);
  void unset_vkey (int);
  void update_vkey (int);
  int get_nbuttons () const {return fk_nbuttons;}
  int set_nbuttons (int);

};

#endif /* _fkwin_h_ */
