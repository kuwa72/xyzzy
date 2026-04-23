#include "stdafx.h"
#include "ed.h"
#include "byte-stream.h"

// Phase 2: Char は UTF-16 code unit。byte stream は Lisp 文字列を「原文の
// バイト列」として扱いたいので、< 256 の Char は raw byte としてそのまま、
// 256 以上は cp932 へ変換してから 1–2 byte 出力する。pre-Phase-2 は Char
// 自体が SJIS-packed value で直 byte-split していたが、Phase 2 以降は
// "あ" リテラルが U+3042 になったため wc2cp932 ブリッジが必要。
static inline void
emit_char_as_bytes (u_char *&b, Char cc)
{
  if (cc < 0x100)
    *b++ = u_char (cc);
  else
    {
      Char sjis = wc2cp932 (cc);
      if (sjis == Char (-1))
        *b++ = '?';
      else if (DBCP (sjis))
        {
          *b++ = u_char (sjis >> 8);
          *b++ = u_char (sjis);
        }
      else
        *b++ = u_char (sjis);
    }
}

int
byte_input_string_stream::refill ()
{
  u_char *b = s_buf, *const be = s_buf + sizeof s_buf - 1;
  while (b < be && s_wp < s_we)
    emit_char_as_bytes (b, *s_wp++);
  return setbuf (s_buf, b);
}

int
byte_input_streams_stream::refill ()
{
  u_char *b = s_buf, *const be = s_buf + sizeof s_buf - 1;
  while (b < be)
    {
      lChar lcc = readc_stream (s_stream);
      if (lcc == lChar_EOF)
        break;
      emit_char_as_bytes (b, Char (lcc));
    }
  return setbuf (s_buf, b);
}

u_char *
byte_output_wstream::sflush (u_char *b0, u_char *be, int)
{
  // Phase 2: 内部 Char は UTF-16 code unit。byte stream 出力は「この
  // バイト列を Lisp 文字列として保持する」ため、1 byte = 1 Char で透過的に
  // 格納する (<0x100)。旧実装は SJIS lead+trail を 1 Char に pack していたが、
  // Phase 2 では Lisp 文字列の意味論が Unicode になったので pack 不可。
  Char *w, wbuf[sizeof s_buf];
  u_char *b = b0;
  for (w = wbuf; b < be;)
    *w++ = *b++;
  if (w - wbuf)
    swrite (wbuf, w - wbuf);
  return b0;
}

int
Char_input_streams_stream::refill ()
{
  Char *b = s_buf, *const be = s_buf + numberof (s_buf);
  while (b < be)
    {
      lChar lcc = readc_stream (s_stream);
      if (lcc == lChar_EOF)
        break;
      *b++ = Char (lcc);
    }
  return setbuf (s_buf, b);
}

xstream_ibyte_helper::xstream_ibyte_helper (lisp obj)
{
  if (stringp (obj))
    s_stream = new (&s_xbuf) byte_input_string_stream (obj);
  else if (obj == Qnil || obj == Qt || streamp (obj))
    s_stream = new (&s_xbuf) byte_input_streams_stream (input_stream (obj));
  else
    FEtype_error (obj, xsymbol_value (Qor_string_stream));
}

xstream_obyte_helper::xstream_obyte_helper (lisp obj)
{
  if (!obj || obj == Qnil)
    {
      s_stream = new (&s_xbuf) byte_output_string_stream;
      s_string_stream_p = 1;
    }
  else
    {
      if (obj == Qt)
        obj = xsymbol_value (Vstandard_output);
      check_stream (obj);
      s_stream = new (&s_xbuf) byte_output_streams_stream (obj);
      s_string_stream_p = 0;
    }
}

xstream_iChar_helper::xstream_iChar_helper (lisp obj)
{
  if (stringp (obj))
    s_stream = new (&s_xbuf) Char_input_string_stream (obj);
  else if (obj == Qnil || obj == Qt || streamp (obj))
    s_stream = new (&s_xbuf) Char_input_streams_stream (input_stream (obj));
  else
    FEtype_error (obj, xsymbol_value (Qor_string_stream));
}

xstream_oChar_helper::xstream_oChar_helper (lisp obj)
{
  if (!obj || obj == Qnil)
    {
      s_stream = new (&s_xbuf) Char_output_string_stream;
      s_string_stream_p = 1;
    }
  else
    {
      if (obj == Qt)
        obj = xsymbol_value (Vstandard_output);
      check_stream (obj);
      s_stream = new (&s_xbuf) Char_output_streams_stream (obj);
      s_string_stream_p = 0;
    }
}

void
copy_xstream (xread_stream &i, byte_output_stream &o)
{
  int c;
  while ((c = i.get ()) != xstream::eof)
    o.put (c);
  o.flush (1);
}

void
copy_xstream (xread_stream &is, Char_output_stream &os)
{
  int c;
  while ((c = is.get ()) != xstream::eof)
    os.put (c);
  os.flush (1);
}

void
copy_xstream (xwrite_stream &is, byte_output_stream &os)
{
  int c;
  while ((c = is.get ()) != xstream::eof)
    os.put (c);
  os.flush (1);
}
