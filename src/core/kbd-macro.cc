// kbd-macro.cc -- キーボードマクロの記録と再生。
//
// **Win32 の API は出てこない。** 触っているのは `src/core/kbd.h` の欄
// (`current_mode` / `saved[]` / `nsaved` / `last_command_key_index` /
// `kbd_macro`) だけで、`Window::modify_all_mode_line` の呼び出しも
// 「記録中の印を出し直す」という表示の話である。
//
// それでも src/frontend/win32/kbd.cc に居たので、**端末では記録も再生も
// できなかった** (issue #181):
//
//   C-x (   何も起きない (`start-save-kbd-macro` が nil を返すスタブ)
//   hello
//   C-x )   「キーボードマクロは定義していません」
//   C-x e   e が挿入される
//
// **`C-x (` が黙って成功したように見えるのが厄介**で、次の打鍵で初めて
// 分かる。
//
// 再生の土台は最初から core にあった: `kbd_macro_context` (kbd.h の inline)
// と `command-execute` の文字列の枝 (src/core/cmdloop.cc)。足りなかったのは
// **入力経路から呼ぶ 2 つ** (`macro_getc` / `save_key`) と、それを呼ぶ端末側の
// 実装である。

#include "stdafx.h"
#include "ed.h"

void
kbd_queue::start_macro ()
{
  assert (!save_p ());
  current_mode = input_mode (disablep () | im_save);
  /* 記録中の印を出し直す。**端末では何もしない** (`modify_all_mode_line` が
     スタブ) ので、端末のモード行に「記録中」は出ない。 */
  Window::modify_all_mode_line ();
  nsaved = 0;
  last_command_key_index = 0;
  command_key_keeped = 0;
}

lisp
kbd_queue::end_macro ()
{
  assert (save_p ());
  stop_macro ();
  /* **`last_command_key_index` までしか返さない。** `C-x )` 自身の打鍵が
     `saved[]` の末尾に入っているので、それを落とす。 */
  return make_string (saved, min (nsaved, last_command_key_index));
}

void
kbd_queue::stop_macro ()
{
  if (save_p ())
    Window::modify_all_mode_line ();
  current_mode = input_mode (disablep () | im_normal);
}

void
kbd_queue::save_key (lChar c)
{
  /* **マクロから来た字は記録しない。** 再生しながら記録すると、同じ打鍵が
     二重に入る。Win32 側も `if (kbd_macro)` の else の枝でだけ保存していた。 */
  if (kbd_macro || !save_p ())
    return;
  /* メニューの選択とマウスの移動は打鍵ではない。 */
  if ((c & LCHAR_MENU) || char_mouse_move_p (c))
    return;
  if (nsaved == KBDMACRO_MAX)
    stop_macro ();
  else
    saved[nsaved++] = (lchar_astral_char_p (c)
                       ? ucs4_t (LCHAR_PAYLOAD (c))
                       : ucs4_t (Char (c)));
}

lChar
kbd_queue::macro_char ()
{
  assert (kbd_macro);
  assert (kbd_macro->index < xstring_length (kbd_macro->string));
  lChar c = xstring_contents (kbd_macro->string) [kbd_macro->index++];
  /* 使い切ったら 1 段外へ戻す。**入れ子で再生できる** (マクロの中から
     別のマクロを呼ぶ)。 */
  if (kbd_macro->index >= xstring_length (kbd_macro->string))
    kbd_macro = kbd_macro->last;
  return c;
}

lChar
kbd_queue::macro_getc ()
{
  return kbd_macro ? macro_char () : lChar_EOF;
}

lisp
Fstart_save_kbd_macro ()
{
  if (app.kbdq.save_p ())
    return Qnil;
  app.kbdq.start_macro ();
  return Qt;
}

lisp
Fstop_save_kbd_macro ()
{
  if (!app.kbdq.save_p ())
    return Qnil;
  return app.kbdq.end_macro ();
}

lisp
Fkbd_macro_saving_p ()
{
  return boole (app.kbdq.save_p ());
}
