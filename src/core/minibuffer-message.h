#ifndef _minibuffer_message_h_
# define _minibuffer_message_h_

// ステータス行 (エコー領域) のメッセージを行に割る。
//
// **描く側と高さを決める側が同じ割り方をしなければならない。** 別々に数えると
// 「4 行分の高さを取ったのに 3 行しか描かない」ような食い違いになるので、
// 両フロントエンドの描画と高さの計算をここへ集約している。
//
// 行は [p1, p2) の範囲で返す。改行はここで行を割り、範囲には含めない。

struct minibuffer_row
{
  int p1, p2;
};

// STRING を幅 COLUMNS の行へ割って ROWS (MAXROWS 個) を埋め、行数を返す。
// MAXROWS に収まらない分は落とす (1 行しか無かった従来と同じ扱い)。
int minibuffer_message_layout (lisp string, int columns, int maxrows,
                              minibuffer_row *rows);

// STRING を幅 COLUMNS で描くのに要る行数 (MAXROWS で頭打ち)。
int minibuffer_message_lines (lisp string, int columns, int maxrows);

#endif /* _minibuffer_message_h_ */
