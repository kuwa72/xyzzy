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
#include "byte-stream.h"
#include "encoding.h"

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


/* ここから下は `Process` の実体に触るもの。**core の基底
   (`ProcessBase`, src/core/process-base.h) 越しに触るので、フロントエンドの
   `class Process` の宣言は要らない。** 以前は基底が無く、`xprocess_data` が
   フロントエンドの不完全型を返していたので、この 8 個が両方に 2 つあった
   (issue #127)。 */

/* 文字列を送る先。**`send` が基底の virtual なので core に置ける。**
   これも両フロントエンドに 1 文字も違わない形で 2 つあった。 */
class process_output_byte_stream: public byte_output_stream
{
  ProcessBase &p_proc;
  u_char p_buf[1024];
protected:
  virtual u_char *sflush (u_char *b, u_char *be, int)
    {
      p_proc.send ((char *)b, be - b);
      return b;
    }
public:
  process_output_byte_stream (ProcessBase &proc)
       : byte_output_stream (p_buf, p_buf + sizeof p_buf), p_proc (proc) {}
};

/* 送信中であることを実体へ知らせる。**Win32 だけが中身を持つ**
   (別スレッドが読んでいる間に溜まった出力を、書き終わってから本体へ
   知らせる)。POSIX は同期なので基底の何もしない実装が使われる。 */
class in_process_send_string
{
  ProcessBase &i_pr;
public:
  in_process_send_string (ProcessBase &pr) : i_pr (pr)
    {i_pr.begin_send_string ();}
  ~in_process_send_string ()
    {i_pr.end_send_string ();}
};

lisp
Fsignal_process (lisp process)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (pr)
    pr->signal_proc ();
  return Qt;
}

lisp
Fkill_process (lisp process)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (pr)
    pr->kill_proc ();
  return Qt;
}

lisp
Fprocess_send_string (lisp process, lisp string)
{
  check_process (process);
  check_string (string);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  Char_input_string_stream is (string);
  process_output_byte_stream os (*pr);
  encoding_output_stream_helper s (xprocess_outcode (process), is, eol_noconv);

  in_process_send_string in (*pr);
  copy_xstream (s, os);

  return Qt;
}

lisp
Fset_process_filter (lisp process, lisp filter)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  pr->filter () = filter;
  return Qt;
}

lisp
Fprocess_filter (lisp process)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->filter ();
}

lisp
Fset_process_sentinel (lisp process, lisp sentinel)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  pr->sentinel () = sentinel;
  return Qt;
}

lisp
Fprocess_sentinel (lisp process)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->sentinel ();
}

lisp
Fprocess_marker (lisp process)
{
  check_process (process);
  ProcessBase *pr = xprocess_data (process);
  if (!pr)
    return Qnil;
  return pr->marker ();
}
