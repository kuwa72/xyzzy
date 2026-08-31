#ifndef _clipboard_h_
# define _clipboard_h_

/* Win32 のクリップボードのウィンドウメッセージ (WM_DRAWCLIPBOARD /
   WM_CHANGECBCHAIN / WM_CLIPBOARDUPDATE) を捌く道具。**src/core/clipboard.h に
   居た**が、`src/core/` の中から触っているコードが 1 つも無かったので出した
   (issue #195 / #185)。

   **`clipboard` は `Application` (ed.h) のメンバだった。** そのため `ed.h` を
   include する全ての翻訳単位がこのクラスの定義を要求し、`HWND` が core に
   残っていた。実体は `g_clipboard` で、`src/frontend/win32/clipboard.cc` が
   持つ。

   **Lisp から見えるクリップボードの入口はこちらではない。**
   `copy-to-clipboard` / `get-clipboard-data` は
   `Frontend::copy_to_clipboard` / `get_clipboard_data`
   (src/core/frontend.h) を通る。こちらはそれとは別に、**他のアプリが
   クリップボードを書き換えたことを知る**ための仕掛けである
   (`*clipboard-change-hook*`)。 */

typedef BOOL (WINAPI *AddClipboardFormatListener)(HWND hwnd);
typedef BOOL (WINAPI *RemoveClipboardFormatListener)(HWND hwnd);

class clipboard
{
private:
  AddClipboardFormatListener AddClipboardFormatListenerProc;
  RemoveClipboardFormatListener RemoveClipboardFormatListenerProc;

  HWND hwnd_next_clipboard;
  DWORD last_clipboard_seqno;
  bool use_newapi_p;

  void add_clipboard_chain (HWND hwnd);
  void remove_clipboard_chain (HWND hwnd);

public:
  clipboard ();
  void add_listener (HWND hwnd);
  void remove_listener (HWND hwnd);
  void repair_clipboard_chain_if_need (HWND hwnd);
  void draw_clipboard (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
  void change_clipboard_chain (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
  void clipboard_update (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
};

/* 実体は src/frontend/win32/clipboard.cc。**`Application` のメンバから
   ここへ移した。** */
extern clipboard g_clipboard;

struct CLIPBOARDTEXT
{
  UINT fmt;
  HGLOBAL hgl;
};

int make_clipboard_text (CLIPBOARDTEXT &, lisp, int);
int make_string_from_clipboard_text (lisp, const void *, UINT, int);

#endif
