#ifndef _xmessagebox_h_
# define _xmessagebox_h_

/* Win32 のメッセージボックスのダイアログ。**src/core/msgbox.h に居た**が、
   GUI のクラスなので core から出した (issue #185)。core が呼ぶのは
   `MsgBox` / `MsgBoxEx` (宣言は src/core/msgbox.h) だけで、このクラスは
   その Win32 側の実装 (src/frontend/win32/msgbox.cc) の道具である。

   **ここに居たせいで、端末とヘッドレスのフロントエンドが
   `XMessageBox::add_button` / `set_button` / `doit` の空実装を置く必要が
   あった。** クラスが core から消えたので、あの 3 行ずつも要らなくなった。 */

/* **ボタンの番号のために自分で include する。** `ed.h` 経由で先に入るので
   include 無しでも通るが、**順番に依存する形は次に触る人が踏む。** */
# include "msgbox.h"

class XMessageBox
{
public:
  /* 番号は src/core/msgbox.h に置いてある (`message-box` の戻り値が
     これで決まるので、番号は GUI の話ではない)。 */
  enum {MAX_BUTTONS = MSGBOX_MAX_BUTTONS};
protected:
  HINSTANCE hinst;
  const Char *msg;
  const Char *title;
  HFONT hfont;
  HICON hicon;
  HWND hwnd;
  HWND owner;
  enum {XOFF = 14, YOFF = 12};
  int nbuttons;
  struct
    {
      UINT id;
      const Char *caption;
    } btn[MAX_BUTTONS];
  int close_id;
  int default_btn;
  int f_crlf;
  int f_no_wrap;

  BOOL WndProc (UINT, WPARAM, LPARAM);
  BOOL init_dialog ();
  void end_dialog (UINT result);
  void calc_text_rect (RECT &) const;
  void calc_button_size (RECT br[MAX_BUTTONS]) const;
  HWND create_ctl (const char *cls, const Char *caption, DWORD, UINT, const RECT &) const;
  void create_btn (const Char *, UINT, const RECT &) const;
  void create_label (const Char *, const RECT &, int) const;
  void create_icon (const RECT &) const;
  void create_buttons (const RECT br[MAX_BUTTONS]) const;
  static INT_PTR CALLBACK WndProc (HWND, UINT, WPARAM, LPARAM);
public:
  XMessageBox (HINSTANCE hinst_, const Char *msg_, const Char *title_,
               int crlf, int no_wrap)
       : hinst (hinst_), msg (msg_), title (title_), nbuttons (0),
         close_id (-1), default_btn (0), hicon (0), owner (0),
         f_crlf (crlf), f_no_wrap (no_wrap) {}
  void add_button (UINT, const Char *);
  void set_button (int, UINT, const Char *);
  void set_default (int n) {default_btn = n;}
  void set_close (int id) {close_id = id;}
  void set_icon (HICON h) {hicon = h;}
  int doit (HWND);
};

#endif /* _xmessagebox_h_ */
