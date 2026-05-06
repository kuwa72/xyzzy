#include "stdafx.h"
#include "ed.h"
#include "byte-stream.h"

/* Phase 3: Lisp strings store ucs4_t code points. To emit as bytes,
   BMP chars that fit in 1 byte go raw; others are converted via cp932.
   Non-BMP and non-cp932 chars map to '?'. */
static inline void
emit_char_as_bytes (u_char *&b, ucs4_t cc)
{
  if (cc < 0x100)
    *b++ = u_char (cc);
  else if (cc > 0xFFFF)
    *b++ = '?';
  else
    {
      Char sjis = wc2cp932 (ucs2_t (cc));
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
      emit_char_as_bytes (b, ucs4_t (lcc));
    }
  return setbuf (s_buf, b);
}

u_char *
byte_output_wstream::sflush (u_char *b0, u_char *be, int)
{
  /* Phase 3: bytes from the encoding layer are single-byte values
     (0-255 per encoded byte). Store each as a ucs4_t in the StrBuf. */
  ucs4_t wbuf[sizeof s_buf];
  u_char *b = b0;
  ucs4_t *w = wbuf;
  while (b < be)
    *w++ = ucs4_t (*b++);
  if (w - wbuf)
    swrite (wbuf, w - wbuf);
  return b0;
}

int
Char_input_string_stream::refill ()
{
  ucs4_t *b = s_buf, *const be = s_buf + numberof (s_buf);
  while (b < be && s_wp < s_we)
    *b++ = *s_wp++;
  return setbuf (s_buf, b);
}

int
Char_input_streams_stream::refill ()
{
  ucs4_t *b = s_buf, *const be = s_buf + numberof (s_buf);
  while (b < be)
    {
      lChar lcc = readc_stream (s_stream);
      if (lcc == lChar_EOF)
        break;
      *b++ = ucs4_t (lcc);
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
