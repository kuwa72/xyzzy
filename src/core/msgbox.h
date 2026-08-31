#ifndef _msgbox_h_
# define _msgbox_h_

/* メッセージボックスの seam。**core が呼ぶのは `MsgBox` / `MsgBoxEx` の
   2 つだけ**で、Win32 はダイアログを出し (src/frontend/win32/msgbox.cc)、
   端末は最下行に出して打鍵を待つ (src/frontend/ncurses/ncurses-main.cc の
   `message_box`)。

   **`XMessageBox` (Win32 のダイアログの実装) はここに居た。** GUI のクラスな
   のに core に居たので、端末とヘッドレスのフロントエンドが
   `XMessageBox::add_button` などの空実装を置く必要があった。
   src/frontend/win32/xmessagebox.h へ移した (issue #185)。

   **ボタンの番号だけは core に残す。** `message-box` の戻り値
   (`:button1`..`:button5`) がこれで決まるので、**番号は GUI の話ではない。**
   `src/core/lprint.cc` の `msgbox_result` が見ている。 */
enum
  {
    MSGBOX_MAX_BUTTONS = 5,
    MSGBOX_IDBUTTON1 = 1000,
    MSGBOX_IDBUTTON2,
    MSGBOX_IDBUTTON3,
    MSGBOX_IDBUTTON4,
    MSGBOX_IDBUTTON5,
  };

int MsgBox (HWND, const Char *, const Char *, UINT, int);
int MsgBoxEx (HWND, const Char *, const Char *, int, int, int, int,
              const Char **, int, int, int);

/* Char is a UTF-16 code unit and so is wchar_t on Windows; callers that
   already hold a wchar_t buffer should not have to spell out the cast. */
inline int
MsgBox (HWND hwnd, const wchar_t *msg, const Char *title, UINT flags, int beep)
{
  return MsgBox (hwnd, (const Char *)msg, title, flags, beep);
}

#endif
