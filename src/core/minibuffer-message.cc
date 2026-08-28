// ステータス行 (エコー領域) のメッセージを行に割る。issue #97。
//
// `message' の出力先は長く 1 行だけで、収まらない分は切られていた。
// `ESC ESC' の結果が読めない、which-key が 63 個のうち 8 個しか出せない、
// 長いエラーメッセージが途中で切れる、といった不便がそこから来ていた。
//
// **割り方をここ 1 箇所に置いている理由:** 高さを決める側 (ウィンドウの
// 行数) と描く側が別々に数えると、「4 行分の高さを取ったのに 3 行しか
// 描かない」という食い違いになる。フロントエンドは 2 つあるので、別々に
// 書くと 4 箇所へ散る。
//
// 幅の数え方は Win32 の描画 (paint_minibuffer_message) に合わせてある:
// 制御文字は `^X' の 2 桁、DEL も 2 桁、それ以外は unicode_width。

#include "stdafx.h"
#include "ed.h"
#include "minibuffer-message.h"

static int
message_char_width (ucs4_t cc)
{
  if (cc < ' ' || cc == CC_DEL)
    return 2;                   // ^X の形で 2 桁
  int w = unicode_width (uint32_t (cc));
  return w > 0 ? w : 1;
}

int
minibuffer_message_layout (lisp string, int columns, int maxrows,
                           minibuffer_row *rows)
{
  if (columns < 1)
    columns = 1;
  if (maxrows < 1)
    maxrows = 1;

  const ucs4_t *p = xstring_contents (string);
  const int len = xstring_length (string);

  int nrows = 0;
  int start = 0;
  int x = 0;

  for (int i = 0; i < len; i++)
    {
      // 改行はここで行を割る。**メッセージ側が明示的に折り返せる**ように
      // するためで、以前は ^J と描かれていた。
      if (p[i] == '\n')
        {
          rows[nrows].p1 = start;
          rows[nrows].p2 = i;
          nrows++;
          if (nrows >= maxrows)
            return nrows;
          start = i + 1;
          x = 0;
          continue;
        }

      int w = message_char_width (p[i]);
      if (x + w > columns && i > start)
        {
          rows[nrows].p1 = start;
          rows[nrows].p2 = i;
          nrows++;
          if (nrows >= maxrows)
            return nrows;
          start = i;
          x = 0;
        }
      x += w;
    }

  // 最後の行。中身が無ければ足さない (幅ぴったりで終わった場合に空行を
  // 作らないため)。1 行も無いときだけ、空のメッセージ用に 1 行返す。
  if (start < len || nrows == 0)
    {
      rows[nrows].p1 = start;
      rows[nrows].p2 = len;
      nrows++;
    }
  return nrows;
}

int
minibuffer_message_lines (lisp string, int columns, int maxrows)
{
  if (maxrows < 1)
    maxrows = 1;
  minibuffer_row *rows
    = (minibuffer_row *)alloca (sizeof (minibuffer_row) * maxrows);
  return minibuffer_message_layout (string, columns, maxrows, rows);
}

// ---------------------------------------------------------------------------
// ステータス行の行数
//
// **今の高さから行数を割り戻すのをやめて、行数を持つようにした。**
// Win32 の compute_geometry は `old_h / lcell` で行数を出しており、
// 「フォントを変えても行数が変わらない」ようにするための計算だったが、
// 副作用として**行数を変える手段が無かった。** ここが行数の持ち主である。

#include "Window.h"

int Window::w_minibuffer_lines = 1;

// *max-minibuffer-message-lines* が整数でなければこの値。
#define DEFAULT_MAX_MINIBUFFER_LINES 10

// **画面に収まるかはフロントエンドが決める。** ここは上限だけを返す。
// Win32 は画素、端末は行で高さを持っており、端末側は app.text_font を
// 初期化していない (cell () が 0 を返す) ので、共通のコードで「画面の
// 何分の 1」を計算する手段が無い。compute_geometry が入り切る高さへ
// 丸め、描画側は w_ch_max.cy までしか描かない。
static int
max_minibuffer_lines ()
{
  lisp v = xsymbol_value (Vmax_minibuffer_message_lines);
  int n = fixnump (v) ? int (fixnum_value (v)) : DEFAULT_MAX_MINIBUFFER_LINES;
  return n < 1 ? 1 : n;
}

int
Window::adjust_minibuffer_lines ()
{
  Window *mini = minibuffer_window ();
  if (!mini)
    return 0;

  int want = 1;
  lisp msg = xsymbol_value (Vminibuffer_message);
  if (stringp (msg))
    {
      // 先頭の 1 桁は余白なので幅から引く (描画側と同じ)。
      int columns = max (1, int (mini->w_ch_max.cx) - 1);
      want = minibuffer_message_lines (msg, columns, max_minibuffer_lines ());
    }

  if (want == w_minibuffer_lines)
    return 0;
  w_minibuffer_lines = want;
  compute_geometry ();
  return 1;
}
