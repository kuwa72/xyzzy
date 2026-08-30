// abbrev-columns.cc -- `abbreviate-display-string' を桁で数える版。
//
// Win32 側 (src/frontend/win32/abbrev.cc) は GDI で**ピクセル**を測る
// (`GetTextExtentPoint32W`、上限は `tmAveCharWidth * maxlen`)。端末には
// プロポーショナルフォントが無く、画面は文字セルの格子なので、**同じ戦略を
// 桁で測る。**
//
// これが無かったので、端末では `abbreviate-display-string` が
// ncurses-stubs.cc で**引数をそのまま返すスタブ**だった。呼んでいるのは
// lisp/app-menu.l (最近使ったファイルの一覧) と lisp/mouse.l (URL の表示) で、
// **長いパスが縮まないまま出ていた。**
//
// **数える単位が違うので、答えもプラットフォームで違う。** Win32 は可変幅
// フォントのピクセル幅で決まるので、「40 桁ぶんの幅」に 38 文字が入らない
// ことがある (既知失敗 `fix-abbreviate-display-string` がまさにそれ)。桁で
// 数える方は 38 <= 40 なので縮めない。**どちらも正しい。** テストは、どちらの
// 数え方でも成り立つ性質 (十分長いものは縮む、`...` が入る、末尾の名前は
// 残る) で書いてある。
//
// 戦略は Win32 側と同じ:
//
//   パス名   -- 末尾のファイル名は必ず残し、先頭のドライブ (`X:/`、UNC の
//               `//host/share/`) が入るなら残し、その間を `...` にする。
//               ファイル名だけで入り切らないときは、頭から入るところまでを
//               残して `...` を後ろに付ける。
//   それ以外 -- 前半と後半を半分ずつ残して真ん中を `...` にする。
//
// **`__WIN32__` の枝は無い。** このファイルは POSIX のフロントエンドだけが
// リンクする (CMakeLists.txt の NCURSES_SOURCES)。

#include "stdafx.h"
#include "ed.h"

static int
columns (const ucs4_t *s, const ucs4_t *se)
{
  int w = 0;
  for (; s < se; s++)
    w += char_width (*s);
  return w;
}

static int
slash_p (ucs4_t c)
{
  return c == '/' || c == '\\';
}

/* [B, E) の中で最後の区切り。無ければ 0。 */
static const ucs4_t *
find_last_slash (const ucs4_t *b, const ucs4_t *e)
{
  for (const ucs4_t *p = e; p > b;)
    if (slash_p (*--p))
      return p;
  return 0;
}

/* [B, E) の中で最初の区切り。無ければ 0。 */
static const ucs4_t *
find_slash (const ucs4_t *b, const ucs4_t *e)
{
  for (const ucs4_t *p = b; p < e; p++)
    if (slash_p (*p))
      return p;
  return 0;
}

/* 先頭の「ドライブ」の長さ。`X:` / `X:/` と UNC の `//host/share/` を見る。
   POSIX に本来こういうものは無いが、**core のパス層はどちらの書き方も受ける**
   ので、Win32 側と同じ判断をしておく (`D:/src/...` を渡されたときに答えが
   プラットフォームで食い違わない)。 */
static int
device_length (const ucs4_t *b, const ucs4_t *e, const ucs4_t *rb)
{
  if (e - b >= 2 && alpha_char_p (int (*b & 255)) && b[1] == ':')
    return (e - b >= 3 && slash_p (b[2])) ? 3 : 2;
  if (e - b >= 2 && slash_p (b[0]) && slash_p (b[1]))
    {
      const ucs4_t *sl = find_slash (b + 2, e);
      if (sl)
        {
          const ucs4_t *sl2 = find_slash (sl + 1, e);
          if (sl2 && sl2 < rb)
            return int (sl2 - b + 1);
        }
    }
  return 0;
}

/* 結果を組み立てる。LB..LE + "..." + RB..RE。

   **Win32 側にある「縮めても短くならないなら諦める」という判定は要らない。**
   あちらはバッファを in-place で書き換えるので溢れを見る必要があり、その判定が
   兼ねている。こちらは新しい文字列を作るし、**どの枝も桁数が MAX + 3 (= 元の
   上限) 以下になる**ことが上で保証されているので、必ず短くなる。 */
static lisp
build (const ucs4_t *lb, const ucs4_t *le, const ucs4_t *rb, const ucs4_t *re)
{
  int n = int ((le - lb) + 3 + (re - rb));
  lisp string = make_string (n);
  ucs4_t *p = xstring_contents (string);
  for (const ucs4_t *q = lb; q < le; q++)
    *p++ = *q;
  for (int i = 0; i < 3; i++)
    *p++ = '.';
  for (const ucs4_t *q = rb; q < re; q++)
    *p++ = *q;
  return string;
}

lisp
Fabbreviate_display_string (lisp string, lisp maxlen, lisp pathname_p)
{
  check_string (string);
  int max = fixnum_value (maxlen);
  if (max <= 0)
    return make_string ("");

  const ucs4_t *const b = xstring_contents (string);
  const ucs4_t *const e = b + xstring_length (string);
  const int total = columns (b, e);
  if (total <= max)
    return string;

  /* `...` の 3 桁を先に取っておく。ここが負になるなら何も入らない。 */
  max -= 3;
  if (max <= 0)
    return string;

  if (!pathname_p || pathname_p == Qnil)
    {
      /* 前半と後半を半分ずつ。**Win32 側と同じく上限を 2 で割る。** */
      const int half = max / 2;
      const ucs4_t *const mid = b + (e - b) / 2;
      const ucs4_t *le = mid;
      while (le > b && columns (b, le) > half)
        le--;
      const ucs4_t *rb = mid;
      while (rb < e && columns (rb, e) > half)
        rb++;
      return build (b, le, rb, e);
    }

  const ucs4_t *rb = find_last_slash (b, e);
  if (!rb)
    {
      /* 区切りが無い = 名前だけ。頭から入るところまでを残す。 */
      const ucs4_t *re = e;
      while (re > b && columns (b, re) > max)
        re--;
      return build (b, re, e, e);
    }

  /* 末尾のファイル名 (区切りを含む) だけで入り切らないなら、そこを頭から
     詰める。**Win32 側の trim_tail と同じ。** */
  if (columns (rb, e) > max)
    {
      rb++;
      const ucs4_t *re = e;
      while (re > rb && columns (rb, re) > max)
        re--;
      return build (rb, re, e, e);
    }

  int used = columns (rb, e);
  const ucs4_t *le = b;
  const int dev = device_length (b, e, rb);
  if (dev)
    {
      if (used + columns (b, b + dev) <= max)
        {
          used += columns (b, b + dev);
          le = b + dev;
        }
    }

  /* 右から順に、丸ごと入る間だけディレクトリを 1 段ずつ足す。 */
  while (rb > le)
    {
      const ucs4_t *slash = find_last_slash (le, rb);
      if (!slash)
        break;
      int w = columns (slash, rb);
      if (used + w > max)
        break;
      rb = slash;
      used += w;
    }

  return build (b, le, rb, e);
}
