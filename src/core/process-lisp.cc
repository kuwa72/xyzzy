// process-lisp.cc -- プロセスを触る Lisp 関数のうち、**`Process` の実体に
// 触らないもの。**
//
// ここに集めた 11 個は src/frontend/win32/process.cc と
// src/frontend/ncurses/ncurses-process.cc に**空白を除いて 1 文字も違わない形で
// 2 つあった。** 読み書きしているのは `lprocess` の枠 (src/core/lprocess.h) —
// バッファ、コマンド行、状態、終了コード、入出力の文字コード、改行コード —
// だけで、プロセスの実体 (Win32 のスレッドとハンドル / POSIX の pid とパイプ)
// には触らない。
//
// **`Process` に触る 6 個はここに来ていない。** `filter` / `sentinel` /
// `marker` / `signal-process` / `kill-process` / `process-send-string` は
// `Process` のメソッドを呼ぶが、**`class Process` は両フロントエンドに
// 別々に定義されていて core に宣言が無い** (`lprocess.h` は
// `class Process;` の前方宣言だけ)。共通の基底クラスを切り出す作業が先に
// 要るので、issue に分けた。
//
// `process_char_encoding` と `process_io_encoding` も 1 文字も違わなかったので
// 一緒に移した。`process_eol_code` だけは**中身が違う** (既定が Win32 は
// `eol_crlf`、POSIX は `eol_lf`) ので、フロントエンドの seam として
// src/core/fns.h で宣言してある。

#include "stdafx.h"
#include "ed.h"

/* 文字コードの指定を検査して正規化する。nil なら
   `*default-process-encoding*`。自動判別は入力の途中で切り替わるので
   プロセスには使えない。 */
static lisp
process_char_encoding (lisp encoding)
{
  if (encoding == Qnil)
    encoding = xsymbol_value (Vdefault_process_encoding);
  check_char_encoding (encoding);
  if (xchar_encoding_type (encoding) == encoding_auto_detect)
    FEtype_error (encoding, Qchar_encoding);
  return encoding;
}

void
process_io_encoding (lisp &incode, lisp &outcode, lisp keys)
{
  incode = process_char_encoding (find_keyword (Kincode, keys));
  outcode = process_char_encoding (find_keyword (Koutcode, keys));
}

lisp
Fbuffer_process (lisp buffer)
{
  return Buffer::coerce_to_buffer (buffer)->lprocess;
}

lisp
Fprocess_buffer (lisp process)
{
  check_process (process);
  return xprocess_buffer (process);
}

lisp
Fprocess_command (lisp process)
{
  check_process (process);
  return xprocess_command (process);
}

lisp
Fprocess_status (lisp process)
{
  check_process (process);
  switch (xprocess_status (process))
    {
    case PS_RUN:
      return Krun;

    case PS_EXIT:
      return Kexit;

    default:
      return Qnil;
    }
}

lisp
Fprocess_exit_code (lisp process)
{
  check_process (process);
  return (xprocess_status (process) == PS_EXIT
          ? make_fixnum (xprocess_exit_code (process)) : Qnil);
}

lisp
Fprocess_incode (lisp process)
{
  check_process (process);
  return xprocess_incode (process);
}

lisp
Fprocess_outcode (lisp process)
{
  check_process (process);
  return xprocess_outcode (process);
}

lisp
Fset_process_incode (lisp process, lisp encoding)
{
  check_process (process);
  xprocess_incode (process) = process_char_encoding (encoding);
  return Qt;
}

lisp
Fset_process_outcode (lisp process, lisp encoding)
{
  check_process (process);
  xprocess_outcode (process) = process_char_encoding (encoding);
  return Qt;
}

lisp
Fprocess_eol_code (lisp process)
{
  check_process (process);
  return make_fixnum (xprocess_eol_code (process));
}

lisp
Fset_process_eol_code (lisp process, lisp code)
{
  check_process (process);
  xprocess_eol_code (process) = process_eol_code (code);
  return Qt;
}

