// Lisp API for terminal emulator (si:terminal-*)

#include "stdafx.h"
#include "ed.h"
#include "term.h"
#include "lprocess.h"

// Defined in frontend (ncurses-process.cc / win32 process.cc)
extern Terminal *buffer_terminal (const Buffer *bp);
extern int buffer_terminal_send (const Buffer *bp, const char *data, int len);
extern void buffer_terminal_resize (const Buffer *bp, int rows, int cols);

// Get Terminal* from a process lisp object.
// Returns NULL if the process has no terminal.
static Terminal *
process_terminal (lisp process)
{
  check_process (process);
  /* 実体が在るかだけを見る。**基底の型で足りる** (Terminal はバッファから
     フロントエンドに聞く)。 */
  if (!xprocess_data (process))
    return 0;
  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return 0;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  return buffer_terminal (bp);
}

// (si:process-terminal-p process) → t/nil
lisp
Fsi_process_terminal_p (lisp process)
{
  return boole (process_terminal (process) != 0);
}

// (si:terminal-screen-line process row) → string
lisp
Fsi_terminal_screen_line (lisp process, lisp lrow)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  int row = fixnum_value (lrow);
  if (row < 0 || row >= term->rows ())
    FErange_error (lrow);

  int cols = term->cols ();
  Char buf[1024];
  int len = 0;

  // Find last non-empty cell
  int last = -1;
  for (int c = cols - 1; c >= 0; c--)
    {
      const TermCell *tc = term->cell_at (row, c);
      if (tc->ch != 0 && tc->ch != ' ')
        { last = c; break; }
      if (tc->ch == ' ' && (tc->fg || tc->bg || tc->attrs))
        { last = c; break; }
    }

  /* TermCell::ch は code point、buf は UTF-16 なので BMP 外は
     surrogate pair に展開する。1 文字で 2 単位使うので余裕を 2 見る。 */
  for (int c = 0; c <= last && len < (int)(sizeof buf / sizeof buf[0]) - 3; c++)
    {
      const TermCell *tc = term->cell_at (row, c);
      if (tc->wide == 2)
        continue;
      ucs4_t ch = tc->ch ? tc->ch : ' ';
      if (ch < 0x10000)
        buf[len++] = Char (ch);
      else
        {
          buf[len++] = utf16_ucs4_to_pair_high (ch);
          buf[len++] = utf16_ucs4_to_pair_low (ch);
        }
    }

  return make_string (buf, len);
}

// (si:terminal-screen-size process) → (values rows cols)
lisp
Fsi_terminal_screen_size (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (term->cols ());
  return make_fixnum (term->rows ());
}

// (si:terminal-cursor-position process) → (values row col)
lisp
Fsi_terminal_cursor_position (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    FEsimple_error (Einvalid_function, process);

  multiple_value::count () = 2;
  multiple_value::value (1) = make_fixnum (term->cursor_col ());
  return make_fixnum (term->cursor_row ());
}

// (si:terminal-resize process rows cols)
lisp
Fsi_terminal_resize (lisp process, lisp lrows, lisp lcols)
{
  check_process (process);
  int rows = fixnum_value (lrows);
  int cols = fixnum_value (lcols);
  if (rows < 1 || cols < 1)
    FErange_error (rows < 1 ? lrows : lcols);

  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return Qnil;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  buffer_terminal_resize (bp, rows, cols);
  return Qt;
}

// (si:terminal-app-cursor-keys-p process) → t/nil
lisp
Fsi_terminal_app_cursor_keys_p (lisp process)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  return boole (term->app_cursor_keys ());
}

/* Lisp から渡されたキーを lChar にする。

   char で渡されたら Lisp 側の encoding、つまり旧 Char encoding なので
   lc_from_ccf で昇格する。これを忘れると #\Up (CCF_UP = 0xff05) の
   LCHAR_KIND が CHAR に見えて、機能キーではなく U+FF05 (全角パーセント) の
   UTF-8 が pty へ流れる。整数で渡された場合は lChar そのものとして扱う
   (C++ 側の呼び出しと、lChar を直に指定したいテストがこちら)。 */
static lChar
lchar_from_lisp_key (lisp lkey)
{
  if (!charp (lkey))
    return fixnum_value (lkey);
  /* BMP 外は Char (16bit) に落とせない (U+1F600 → 0xF600 = CCF_META)。
     機能キーの空間と重ならないので、そのまま code point として渡す。 */
  ucs4_t cc = xchar_code (lkey);
  return cc >= 0x10000 ? (LCKIND_CHAR | lChar (cc)) : lc_from_ccf (Char (cc));
}

// (si:terminal-send-key process key)
// Convert an lChar key to VT100 escape sequence and send to process.
lisp
Fsi_terminal_send_key (lisp process, lisp lkey)
{
  check_process (process);
  lChar c = lchar_from_lisp_key (lkey);

  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return Qnil;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);
  Terminal *term = buffer_terminal (bp);
  if (!term)
    return Qnil;

  char buf[16];
  int len = terminal_key_to_bytes (term, c, buf, sizeof buf);
  if (len > 0)
    {
      buffer_terminal_send (bp, buf, len);
      return Qt;
    }
  return Qnil;
}

// (si:terminal-scroll-back process delta)
// Scroll the terminal view back (positive) or forward (negative).
lisp
Fsi_terminal_scroll_back (lisp process, lisp ldelta)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  int delta = fixnum_value (ldelta);
  term->scrollback_scroll (delta);
  return make_fixnum (term->scrollback_offset ());
}

// (si:terminal-scrollback-line process index)
// Get a scrollback line (0=most recent). Returns string or nil.
lisp
Fsi_terminal_scrollback_line (lisp process, lisp lindex)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  int index = fixnum_value (lindex);
  const TermCell *line = term->scrollback_line (index);
  if (!line)
    return Qnil;

  int cols = term->cols ();
  Char buf[1024];
  int len = 0;
  int last = -1;
  for (int c = cols - 1; c >= 0; c--)
    {
      if (line[c].ch != 0 && line[c].ch != ' ')
        { last = c; break; }
    }
  /* 上と同じ理由で surrogate pair に展開する。 */
  for (int c = 0; c <= last && len < (int)(sizeof buf / sizeof buf[0]) - 3; c++)
    {
      if (line[c].wide == 2)
        continue;
      ucs4_t ch = line[c].ch ? line[c].ch : ' ';
      if (ch < 0x10000)
        buf[len++] = Char (ch);
      else
        {
          buf[len++] = utf16_ucs4_to_pair_high (ch);
          buf[len++] = utf16_ucs4_to_pair_low (ch);
        }
    }
  return make_string (buf, len);
}

/* (si:*terminal-feed-for-test rows cols string)
     => 各行のリスト。行は各セルの (code-point fg bg attrs) のリスト。

   VT パーサ (色・カーソル・消去・スクロール) に自動テストを付けるための
   口。Terminal は本来 ConPtyProcess が抱えていて、process 無しに作る手段が
   無かったため、パーサには自動テストが一切なかった。SGR の色解釈を書き
   直した際にここを塞いだ。

   fg / bg は term_color_t をそのまま整数で返す:
     0                = 端末の既定色
     #x1000000 + n    = xterm palette index n (0-255)
     #x2000000 + RGB  = 24bit 直接指定 (0xRRGGBB)
   attrs は TATTR_* のビット和。

   string は code point 列。UTF-8 に直してから流すので、エスケープ列も
   日本語も同じように書ける。                                             */
lisp
Fsi_terminal_feed_for_test (lisp lrows, lisp lcols, lisp string)
{
  int rows = fixnum_value (lrows);
  int cols = fixnum_value (lcols);
  if (rows < 1 || rows > 200)
    FErange_error (lrows);
  if (cols < 1 || cols > 500)
    FErange_error (lcols);
  check_string (string);

  Terminal term (rows, cols);

  int l = xstring_length (string);
  if (l > 0)
    {
      size_t n = i2u8l (xstring_contents (string), l);
      char *b = (char *)xmalloc (n + 1);
      i2u8 (xstring_contents (string), l, b);
      term.feed ((const u_char *)b, int (n));
      xfree (b);
    }

  lisp result = Qnil;
  for (int r = rows - 1; r >= 0; r--)
    {
      lisp row = Qnil;
      for (int c = cols - 1; c >= 0; c--)
        {
          const TermCell *tc = term.cell_at (r, c);
          lisp cell = xcons (make_fixnum (tc->ch),
                             xcons (make_fixnum (tc->fg),
                                    xcons (make_fixnum (tc->bg),
                                           xcons (make_fixnum (tc->attrs),
                                                  Qnil))));
          row = xcons (cell, row);
        }
      result = xcons (row, result);
    }
  return result;
}

/* (si:terminal-paste-string process string)

   クリップボードの文字列をターミナルへ流す。ターミナルバッファには
   貼り付けのコマンドがそもそも無く、通常の paste-from-clipboard は
   バッファに insert するだけで pty には何も行かなかった。

   アプリが bracketed paste (DECSET 2004) を有効にしていれば
   ESC[200~ ... ESC[201~ で囲む。これが無いと複数行の貼り付けが「1 行ごとに
   Enter を押した」のと同じになり、行が順に実行されたり、途中で補完が
   走ったりする。囲んであるとアプリは「これは貼り付けであって入力では
   ない」と判って一塊として扱える。

   改行は CR に寄せる (端末が Enter として送るのは CR)。CRLF は CR 1 個に
   潰す。 */
lisp
Fsi_terminal_paste_string (lisp process, lisp string)
{
  Terminal *term = process_terminal (process);
  if (!term)
    return Qnil;
  check_string (string);

  lisp lbuf = xprocess_buffer (process);
  if (!bufferp (lbuf))
    return Qnil;
  Buffer *bp = Buffer::coerce_to_buffer (lbuf);

  int l = xstring_length (string);
  const ucs4_t *s = xstring_contents (string);

  /* 改行を潰した code point 列を作る。 */
  ucs4_t *cp = (ucs4_t *)xmalloc ((l + 1) * sizeof *cp);
  int n = 0;
  for (int i = 0; i < l; i++)
    {
      if (s[i] == '\r')
        {
          cp[n++] = '\r';
          if (i + 1 < l && s[i + 1] == '\n')
            i++;
        }
      else if (s[i] == '\n')
        cp[n++] = '\r';
      else
        cp[n++] = s[i];
    }

  size_t u8l = i2u8l (cp, n);
  char *b = (char *)xmalloc (u8l + 1);
  i2u8 (cp, n, b);

  if (term->bracketed_paste_p ())
    buffer_terminal_send (bp, "\033[200~", 6);
  if (u8l)
    buffer_terminal_send (bp, b, int (u8l));
  if (term->bracketed_paste_p ())
    buffer_terminal_send (bp, "\033[201~", 6);

  xfree (b);
  xfree (cp);
  return Qt;
}

/* (si:terminal-bracketed-paste-p process) → t/nil
   アプリが貼り付けを一塊として受け取れる状態か。 */
lisp
Fsi_terminal_bracketed_paste_p (lisp process)
{
  Terminal *term = process_terminal (process);
  return boole (term && term->bracketed_paste_p ());
}

/* (si:*terminal-key-for-test key setup)
     => pty へ送るバイト列 (整数のリスト)。送らない場合は nil。

   key は lChar (整数) か Lisp の char。char なら si:terminal-send-key と
   同じ昇格を通るので、(read-char *keyboard*) から送る経路も試せる。
   setup は先に feed するエスケープ列で、モードを
   立てるのに使う (例: ESC[?1h で application cursor keys、ESC[?2004h で
   bracketed paste)。

   キー送出は process が無いと呼べなかったのでテストが書けず、
   「decode_keys は新 lChar encoding を返すのに terminal_key_to_bytes は
   旧 CCF_* と比べていて、矢印キーが全部捨てられていた」という不具合を
   実機で踏むまで気付けなかった。ここを塞ぐ。                            */
lisp
Fsi_terminal_key_for_test (lisp lkey, lisp setup)
{
  lChar key = lchar_from_lisp_key (lkey);

  Terminal term (4, 20);
  if (setup && setup != Qnil)
    {
      check_string (setup);
      int l = xstring_length (setup);
      if (l > 0)
        {
          size_t n = i2u8l (xstring_contents (setup), l);
          char *b = (char *)xmalloc (n + 1);
          i2u8 (xstring_contents (setup), l, b);
          term.feed ((const u_char *)b, int (n));
          xfree (b);
        }
    }

  char buf[32];
  int len = terminal_key_to_bytes (&term, key, buf, sizeof buf);
  if (len <= 0)
    return Qnil;

  lisp r = Qnil;
  for (int i = len - 1; i >= 0; i--)
    r = xcons (make_fixnum ((u_char)buf[i]), r);
  return r;
}
