// Core command loop: keymap dispatch + main editing loop
// Extracted from src/frontend/win32/toplev.cc
// Platform-independent: calls refresh_screen() and pending_refresh_screen()
// which are provided by each frontend.

#include "stdafx.h"
#include "ed.h"
#include "Window.h"
#include "vfs.h"

/* 宣言は kbd.h、立てるのは stream.cc の *keyboard* 読み出しだけ。 */
int kbd_inhibit_terminal_forward;

class keyvec
{
  lisp v_buf[64];
  long v_length;
  long v_size;
  lisp *v_vec;
  int v_finished;
public:
  keyvec () : v_length (0), v_size (numberof (v_buf)), v_vec (v_buf), v_finished (1) {}
  ~keyvec () {if (v_vec != v_buf) free (v_vec);}
  void init ();
  void finish () {v_finished = 1;}
  int finished_p () const {return v_finished;}
  lisp lookup (lChar lc) {return lookup_keymap (lc, v_vec, v_length);}
  void translate (lisp, lisp);
  void gc_mark_object (void (*)(lisp));
  lisp pending_keymaps () const;
};

/* プレフィックスキー待ちのときに、次のキーを探しているキーマップの一覧。
   lookup_keymap は v_vec の各要素を「そのキーの先のキーマップ」に進め、
   行き先が無かったものを Qnil にするので、残っている keymap がそれである。
   先にあるものが優先 (selection → minor → local → global)。 */
lisp
keyvec::pending_keymaps () const
{
  lisp r = Qnil;
  for (long i = v_length - 1; i >= 0; i--)
    if (v_vec[i] != Qnil && Fkeymapp (v_vec[i]) != Qnil)
      {
        protect_gc gcpro (r);
        r = xcons (v_vec[i], r);
      }
  return r;
}

void
keyvec::init ()
{
  Buffer *bp = selected_buffer ();
  long l, n;

  if (safe_fixnum_value (Flist_length (bp->lminor_map), &l))
    {
      n = l + 3;
      if (n > v_size)
        {
          long size = (n + 63) & ~63;
          lisp *x = (lisp *)malloc (sizeof *x * size);
          if (x)
            {
              if (v_vec != v_buf)
                free (v_vec);
              v_vec = x;
              v_size = size;
            }
        }
      n = min (n, v_size) - 2;
      l = 0;
      v_vec[l++] = Fcurrent_selection_keymap ();
      for (lisp p = bp->lminor_map; consp (p) && l < n; l++, p = xcdr (p))
        v_vec[l] = xcar (p);
    }
  else
    {
      l = 0;
      v_vec[l++] = Fcurrent_selection_keymap ();
    }

  v_vec[l++] = bp->lmap;
  v_vec[l++] = xsymbol_value (Vglobal_keymap);
  v_length = l;
  v_finished = 0;
}

void
keyvec::translate (lisp old_command, lisp new_command)
{
  for (long i = 0; i < v_length; i++)
    if (v_vec[i] == old_command)
      v_vec[i] = new_command;
}

void
keyvec::gc_mark_object (void (*fn)(lisp))
{
  for (long i = 0; i < v_length; i++)
    (*fn)(v_vec[i]);
}

static keyvec g_map;

/* *prefix-key-hook* を「出した」かどうか。プレフィックス待ちに入るたびに
   立て、待ちが終わったら nil を渡して下ろす。フックが画面に何か出している
   場合、それを片付ける機会をこちらから作らないと出したままになる:
   キーが未定義だった経路 (C-x の下に無いキー) は *post-command-hook* まで
   来ないし、逆にコマンドが走る経路では *pre-command-hook* より先に片付けて
   もらう必要がある (後片付けでウィンドウ構成を戻すので、コマンドの結果を
   消してしまう)。 */
static int g_prefix_hook_shown;

static void
run_prefix_key_hook (lisp keymaps, lisp key)
{
  protect_gc gcpro1 (keymaps);
  protect_gc gcpro2 (key);
  try
    {
      selected_buffer ()->run_hook (Vprefix_key_hook, keymaps, key);
    }
  catch (nonlocal_jump &)
    {
      /* 待ちの最中なので黙って捨てたくなるが、黙ると「候補が出ない」が
         原因不明になる。1 回出す。 */
      print_condition (nonlocal_jump::data ());
    }
}

static void
prefix_key_hook_enter (lChar cp)
{
  lisp maps = g_map.pending_keymaps ();
  protect_gc gcpro (maps);
  g_prefix_hook_shown = 1;
  run_prefix_key_hook (maps, make_char (ucs4_t (cp)));
}

static void
prefix_key_hook_leave ()
{
  if (g_prefix_hook_shown)
    {
      g_prefix_hook_shown = 0;
      run_prefix_key_hook (Qnil, Qnil);
    }
}

void
toplev_gc_mark (void (*fn)(lisp))
{
  g_map.gc_mark_object (fn);
}

int
toplev_accept_mouse_move_p ()
{
  return g_map.finished_p ();
}

int
g_map_finished_p ()
{
  return g_map.finished_p ();
}

int
char_mouse_move_p (lChar lc)
{
  /* 旧 Char (CCF_MOUSEMOVE = 0xff09 系)、mouse.cc が LCHAR_MOUSE を素の
     `|` で重ねた中間形態、新 lChar (LCKEY_MOUSEMOVE) の三形式に対応。
     cmdloop 呼び出し側が完全に新 encoding 化するまで後方互換を保持 */
  if (LCHAR_KIND (lc) == LCKIND_MOUSE)
    lc = lc_from_raw_mouse (lc);
  if (!(lc & ~lChar (0xFFFF)))
    {
      Char cc = Char (lc);
      if (function_char_p (cc))
        cc = meta_function_to_function (cc & ~(CCF_SHIFT_BIT | CCF_CTRL_BIT));
      return cc == CCF_MOUSEMOVE;
    }
  /* 新 encoding: Meta 剥がして LCKEY_MOUSEMOVE 一致判定 */
  return (lc & ~LCMOD_META) == LCKEY_MOUSEMOVE;
}

#ifndef _WIN32
#include <fcntl.h>
#include <unistd.h>
int g_fetchlog_fd = -1;
static void
dlog (const char *fmt, ...)
{
  if (g_fetchlog_fd < 0)
    return;
  char buf[256];
  va_list ap;
  va_start (ap, fmt);
  int n = vsnprintf (buf, sizeof (buf), fmt, ap);
  va_end (ap);
  if (n > 0)
    { ssize_t r __attribute__((unused)) = write (g_fetchlog_fd, buf, n); }
}
#else
#define dlog(...) ((void)0)
#endif

static lisp
dispatch (lChar cc)
{
  lisp command;
  Char c = Char (cc);
  /* BMP 外の文字は Char (16bit) に落とすと function key の空間と
     ぶつかる (U+1F600 → 0xF600 = CCF_META)。文字としての判定と
     *last-command-char* には code point をそのまま使う。BMP 内では
     cp == c なので、旧来の経路は何も変わらない。 */
  const lChar cp = lchar_astral_char_p (cc) ? LCHAR_PAYLOAD (cc) : lChar (c);
  const int astral_p = cp >= 0x10000;
  dlog ("dispatch: cc=0x%lx c=0x%x\n", (unsigned long)cc, (unsigned)c);

  app.gc_itimer.reset ();
  app.as_itimer.reset ();
  app.last_cmd_tick = GetTickCount ();

  /* 端末の貼り付け (issue #241)。**キーマップを通さない** -- 貼り付けは
     キーではなく出来事で、`LCHAR_MENU` と同じ側にある。走らせるものは
     `bracketed-paste-function` から引く (`default-input-function` と同じ
     形。下の astral の分岐がそれ)。**変数にしてあるので Lisp から
     差し替えられる。** */
  if (LCHAR_KIND (cc) == LCHAR_PASTE)
    {
      command = symbol_value (Vbracketed_paste_function, selected_buffer ());
      if (command == Qnil || command == Qunbound)
        return Qt;
      goto run_command;
    }

  /* **`&` ではなく kind の一致で見る。** kind 4 (menu) と kind 5 (paste) は
     bit 2 を共有するので、`&` だと paste がここへ落ちる (chtype.h の注記)。 */
  if (LCHAR_KIND (cc) == LCHAR_MENU)
    {
      if (c >= MENU_ID_RANGE_MIN && c < MENU_ID_RANGE_MAX)
        command = lookup_menu_command (c);
      else if (c >= TOOL_ID_RANGE_MIN && c < TOOL_ID_RANGE_MAX)
        /* **フロントエンドに聞く。** ここに `g_frame.lookup_command` を直に
           書いていたので core が `mainframe.h` を include していた
           (issue #185)。端末は nil を返す。 */
        command = frontend_lookup_tool_command (c);
      else
        return Qt;
      if (command == Qnil)
        return Qt;
    }
  else
    {
      if (g_map.finished_p ())
        {
          xsymbol_value (Vprefix_args) = xsymbol_value (Vnext_prefix_args);
          xsymbol_value (Vnext_prefix_args) = Qnil;
          xsymbol_value (Vprefix_value) = xsymbol_value (Vnext_prefix_value);
          xsymbol_value (Vnext_prefix_value) = Qnil;

          if (astral_p
              || (!meta_char_p (c) && !meta_function_char_p (c)
                  && !function_char_p (c)
                  && (DBCP (c) || (SBCP (c) && !ascii_char_p (c)))))
            {
              command = symbol_value (Vdefault_input_function, selected_buffer ());
              if (command == Qnil || command == Qunbound)
                return Qt;
              goto run_command;
            }
          g_map.init ();
        }
      else if (char_mouse_move_p (cc))
        return Qt;

      command = g_map.lookup (cc);
      dlog ("dispatch: lookup → command=%p (Qnil=%p)\n", (void*)command, (void*)Qnil);
      if (command && symbolp (command))
        {
          lisp name = xsymbol_name (command);
          if (stringp (name))
            {
              const ucs4_t *s = xstring_contents (name);
              int l = xstring_length (name);
              char mb[128];
              int mi = 0;
              for (int i = 0; i < l && mi < 120; i++)
                mb[mi++] = (s[i] < 0x80) ? (char)s[i] : '?';
              mb[mi] = 0;
              dlog ("dispatch: command=%s\n", mb);
            }
        }
      if (!command)
        {
          dlog ("dispatch: no binding for 0x%x\n", (unsigned)c);
          app.keyseq.push (c, !app.kbdq.macro_is_running ());
          Fcontinue_pre_selection ();
          app.kbdq.close_ime ();
          /* キーボードマクロの再生中は誰も見ていないので出さない
             (出すと 1 打鍵ごとに画面を作り直すことになる)。 */
          if (!app.kbdq.macro_is_running ())
            prefix_key_hook_enter (cp);
          return Qt;
        }
    }

run_command:
  /* ここまで来たらプレフィックスの列は解決した (未定義だった場合も含む)。
     *pre-command-hook* より先に片付けさせる。 */
  prefix_key_hook_leave ();
  xsymbol_value (Vlast_command) = xsymbol_value (Vthis_command);
  xsymbol_value (Vthis_command) = command;
  xsymbol_value (Vlast_command_char) = make_char (ucs4_t (cp));
  if (command != Qnil)
    {
      selected_buffer ()->safe_run_hook (Vpre_command_hook, 1);
      if (xsymbol_value (Vthis_command) != command)
        {
          lisp new_command = xsymbol_value (Vthis_command);
          if (Fkeymapp (new_command) != Qnil)
            {
              xsymbol_value (Vthis_command) = xsymbol_value (Vlast_command);
              g_map.translate (command, new_command);
              app.keyseq.push (c, !app.kbdq.macro_is_running ());
              Fcontinue_pre_selection ();
              app.kbdq.close_ime ();
              if (!app.kbdq.macro_is_running ())
                prefix_key_hook_enter (cp);
              return Qt;
            }
          command = new_command;
        }
    }

  g_map.finish ();

  if (!app.kbdq.macro_is_running ())
    app.status_window.clear ();
  app.keyseq.done (c, !app.kbdq.macro_is_running ());
  app.kbdq.restore_ime ();
  app.kbdq.set_next_command_key ();

  selected_buffer ()->b_ime_mode = app.ime_open_mode;

  if (command == Qnil)
    {
      if (!char_mouse_move_p (cc))
        {
          app.status_window.puts (Ekey_not_bound, 1);
          if (xsymbol_value (Vbeep_on_warn) != Qnil)
            Fding ();
        }
      app.kbdq.clear ();
      app.kbdq.end_last_command_key ();
      return Qnil;
    }

  dlog ("dispatch: executing command\n");
  lisp result = Qnil;
  try
    {
      stack_trace trace (stack_trace::apply, Scommand_execute, command, 0);
      result = Fcommand_execute (command, 0);
      dlog ("dispatch: command returned ok, nchars=%ld\n",
            (long)selected_buffer()->b_nchars);
    }
  catch (nonlocal_jump &)
    {
      nonlocal_data *nld = nonlocal_jump::data ();
      dlog ("dispatch: command threw (type=%p)\n", (void*)nld->type);
      if (nld->type && symbolp (nld->type))
        {
          lisp name = xsymbol_name (nld->type);
          if (stringp (name))
            {
              const ucs4_t *s = xstring_contents (name);
              int l = xstring_length (name);
              char mb[128];
              int mi = 0;
              for (int i = 0; i < l && mi < 120; i++)
                mb[mi++] = (s[i] < 0x80) ? (char)s[i] : '?';
              mb[mi] = 0;
              dlog ("dispatch: throw type=%s\n", mb);
            }
        }
      // Log the condition message
      if (nld->id && nld->id != Qnil)
        {
          try
            {
              lisp cs = Fsi_condition_string (nld->id);
              if (stringp (cs))
                {
                  const ucs4_t *s = xstring_contents (cs);
                  int l = xstring_length (cs);
                  char mb[512];
                  int mi = 0;
                  for (int i = 0; i < l && mi < 500; i++)
                    mb[mi++] = (s[i] < 0x80) ? (char)s[i] : '?';
                  mb[mi] = 0;
                  dlog ("dispatch: condition=%s\n", mb);
                }
            }
          catch (...) {}
        }
      if (nld->type == Qexit_this_level)
        throw;
      print_condition (nonlocal_jump::data ());
      app.kbdq.clear ();
    }
  protect_gc gcpro (result);
  selected_buffer ()->safe_run_hook (Vpost_command_hook, 1);
  app.kbdq.end_last_command_key ();
  erase_popup (0, 0);
  end_wait_cursor (1);
  WINFS::clear_share_cache ();
  return result;
}

void
command_loop ()
{
  dynamic_bind dynb0 (Vsi_condition_handlers, Qnil);
  dynamic_bind dynb1 (Vprefix_value, Qnil);
  dynamic_bind dynb2 (Vprefix_args, Qnil);
  dynamic_bind dynb3 (Vnext_prefix_value, Qnil);
  dynamic_bind dynb4 (Vnext_prefix_args, Qnil);
  dynamic_bind dynb5 (Vthis_command, Qnil);
  dynamic_bind dynb6 (Vlast_command, Qnil);

  save_command_key_index sck (app.kbdq);
  while (1)
    {
      if (app.kbdq.macro_is_running ())
        pending_refresh_screen ();
      else
        refresh_screen (1);
      xsymbol_value (Vquit_flag) = Qnil;
      xsymbol_value (Vinhibit_quit) = Qnil;
      xsymbol_value (Vsi_find_motion) = Qt;
      xsymbol_value (Vevalhook) = Qnil;
      xsymbol_value (Vapplyhook) = Qnil;
      app.mouse.clear_move ();
      lChar c = app.kbdq.fetch (1, toplev_accept_mouse_move_p ());
      if (c == lChar_EOF)
        break;

      /* エコー領域のメッセージは**次の打鍵で消す。** 以前はキーを待つ前に
         消していた。プロンプト (interactive "c" など、同じコマンドの中で
         出して読んで消すもの) にはそれで足りたが、`message' の出力先を
         ここへ回すと**読む前に消える。** 打鍵まで残す方が Emacs の
         エコー領域と同じで、待っている間ずっと読める (issue #97)。 */
      if (stringp (xsymbol_value (Vminibuffer_message)))
        {
          xsymbol_value (Vminibuffer_message) = Qnil;
          Window *mw = Window::minibuffer_window ();
          if (mw)
            mw->w_disp_flags |= Window::WDF_WINDOW;
        }

      while (1)
        {
          dispatch (c);
          c = app.kbdq.peek (toplev_accept_mouse_move_p ());
          if (c == lChar_EOF)
            break;
          pending_refresh_screen ();
          if (!app.kbdq.macro_is_running ())
            Fundo_boundary ();
        }

      if (!app.f_auto_save_pending
          && !app.kbdq.macro_is_running ())
        {
          app.auto_save_count++;
          long interval;
          if (safe_fixnum_value (xsymbol_value (Vauto_save_interval),
                                 &interval)
              && interval > 0 && app.auto_save_count >= interval)
            app.f_auto_save_pending = 1;
        }
    }
}

lisp
execute_string (lisp string)
{
  check_stack_overflow ();
  save_command_key_index sck (app.kbdq);
  check_string (string);
  if (app.kbdq.lookup_kbd_macro (string))
    FEsimple_error (Ekbd_macro_called_recursively);
  lisp val = xsymbol_value (Vprefix_value);
  int n = val == Qnil ? 1 : fixnum_value (val);
  lisp result = Qt;
  if (xstring_length (string))
    for (int i = 0; !n || i < n; i++)
      {
        kbd_macro_context macro (app.kbdq, string);
        while (macro.running ())
          {
            xsymbol_value (Vquit_flag) = Qnil;
            xsymbol_value (Vinhibit_quit) = Qnil;
            lChar c = app.kbdq.fetch (0, 0);
            if (c == lChar_EOF)
              return result;
            result = dispatch (c);
            if (result == Qnil)
              return result;
            pending_refresh_screen ();
            QUIT;
          }
        QUIT;
      }
  return result;
}
