#include "stdafx.h"
#include "ed.h"
#include "kanji.h"
#include "encoding.h"
#include "byte-stream.h"
#include "clipboard.h"

clipboard g_clipboard;

clipboard::clipboard ()
       : AddClipboardFormatListenerProc (nullptr),
         RemoveClipboardFormatListenerProc (nullptr)
{
  HMODULE user32 = GetModuleHandleW (L"user32");
  if (!user32)
    user32 = LoadLibraryW (L"user32");
  if (!user32)
    return;

  AddClipboardFormatListenerProc =
    (AddClipboardFormatListener) GetProcAddress (user32, "AddClipboardFormatListener");
  RemoveClipboardFormatListenerProc =
    (RemoveClipboardFormatListener) GetProcAddress (user32, "RemoveClipboardFormatListener");
  use_newapi_p = (AddClipboardFormatListenerProc != nullptr && RemoveClipboardFormatListenerProc != nullptr);
}


void
clipboard::add_clipboard_chain (HWND hwnd)
{
  hwnd_next_clipboard = SetClipboardViewer (hwnd);
  last_clipboard_seqno = GetClipboardSequenceNumber ();
}

void
clipboard::remove_clipboard_chain (HWND hwnd)
{
  ChangeClipboardChain (hwnd, hwnd_next_clipboard);
  hwnd_next_clipboard = 0;
  last_clipboard_seqno = 0;
}


void
clipboard::add_listener (HWND hwnd)
{
  if (use_newapi_p)
    AddClipboardFormatListenerProc (hwnd);
  else
    add_clipboard_chain (hwnd);
}

void
clipboard::remove_listener (HWND hwnd)
{
  if (use_newapi_p)
    RemoveClipboardFormatListenerProc (hwnd);
  else
    remove_clipboard_chain (hwnd);
}

void
clipboard::repair_clipboard_chain_if_need (HWND hwnd)
{
  if (use_newapi_p) return;
  if (last_clipboard_seqno == GetClipboardSequenceNumber ()) return;

  remove_clipboard_chain (hwnd);
  add_clipboard_chain (hwnd);
}

void
clipboard::draw_clipboard (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
  if (hwnd_next_clipboard)
    SendMessage (hwnd_next_clipboard, msg, wparam, lparam);
  clipboard_update (hwnd, msg, wparam, lparam);
}

void
clipboard::change_clipboard_chain (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
  if (HWND (wparam) == hwnd_next_clipboard)
    hwnd_next_clipboard = HWND (lparam);
  else if (hwnd_next_clipboard)
    SendMessage (hwnd_next_clipboard, msg, wparam, lparam);
}

void
clipboard::clipboard_update (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
  if (last_clipboard_seqno == GetClipboardSequenceNumber ())
    return;
  last_clipboard_seqno = GetClipboardSequenceNumber ();
  xsymbol_value (Vclipboard_newer_than_kill_ring_p) = Qt;
  xsymbol_value (Vkill_ring_newer_than_clipboard_p) = Qnil;
  if (selected_window ())
    selected_buffer ()->safe_run_hook (Vchange_clipboard_hook, 0);
}

/* Clipboard text conversion functions (moved from core/insdel.cc) */

static int
encoding_auto_detect_p (lisp encoding)
{
  return (char_encoding_p (encoding)
          && xchar_encoding_type (encoding) == encoding_auto_detect);
}

#ifndef UNICODE
static int
encoding_sjis_p (lisp encoding)
{
  return (!char_encoding_p (encoding)
          || xchar_encoding_type (encoding) == encoding_sjis);
}
#endif

static int
encoding_utf16_p (lisp encoding)
{
  return (char_encoding_p (encoding)
          && xchar_encoding_type (encoding) == encoding_utf16);
}

static void *
galloc (CLIPBOARDTEXT &clp, int size)
{
  clp.hgl = GlobalAlloc (GMEM_MOVEABLE, size);
  if (!clp.hgl)
    return 0;
  void *p = GlobalLock (clp.hgl);
  if (p)
    return p;
  GlobalFree (clp.hgl);
  clp.hgl = 0;
  return 0;
}

#ifndef UNICODE
static int
make_cf_text_sjis (CLIPBOARDTEXT &clp, lisp string)
{
  const Char *s = xstring_contents (string);
  const Char *const se = s + xstring_length (string);

  int extra;
  for (extra = 0; s < se; s++)
    if (*s == '\n' || DBCP (*s))
      extra++;

  clp.fmt = CF_TEXT;
  char *b = (char *)galloc (clp, xstring_length (string) + extra + 1);
  if (!b)
    return 0;

  for (s = xstring_contents (string); s < se; s++)
    {
      Char cc = *s;
      if (DBCP (cc))
        {
          if (code_charset (cc) == ccs_cp932)
            *b++ = cc >> 8;
          else
            {
              Char c2 = wc2cp932 (i2w (cc));
              if (c2 != Char (-1))
                {
                  cc = c2;
                  if (DBCP (cc))
                    *b++ = cc >> 8;
                }
              else
                cc = '?';
            }
        }
      else if (cc == '\n')
        *b++ = '\r';
      *b++ = char (cc);
    }
  *b = 0;

  GlobalUnlock (clp.hgl);
  return 1;
}
#endif /* !UNICODE */

static int
make_cf_text (CLIPBOARDTEXT &clp, lisp string, lisp encoding)
{
#ifndef UNICODE
  if (encoding_sjis_p (encoding) || encoding_auto_detect_p (encoding))
    return make_cf_text_sjis (clp, string);
#endif

  Char_input_string_stream str1 (string);
  encoding_output_stream_helper is1 (encoding, str1, eol_crlf);
  int l = is1->total_length ();

  clp.fmt = CF_TEXT;
  char *b = (char *)galloc (clp, l + 1);
  if (!b)
    return 0;

  Char_input_string_stream str2 (string);
  encoding_output_stream_helper is2 (encoding, str2, eol_crlf);
  is2->copyto ((u_char *)b, l + 1);

  GlobalUnlock (clp.hgl);
  return 1;
}

static int
make_cf_wtext (CLIPBOARDTEXT &clp, lisp string)
{
  /* 5b-6: Phase 2 で buffer Char は UTF-16 code unit (ucs2_t と同型)。
     CF_UNICODETEXT も UTF-16 なので、\n → \r\n の挿入だけして memcpy
     相当の write で十分。旧 i2w() / utf16_undef_pair 機構 (Phase 1
     internal encoding 用) は撤廃。surrogate pair も buffer 上の 2 つの
     Char をそのまま 2 wchar として書き出すだけで Windows 側に正しく
     伝わる。 */
  const ucs4_t *s = xstring_contents (string);
  const ucs4_t *const se = s + xstring_length (string);

  int extra = 0;
  for (const ucs4_t *p = s; p < se; p++)
    if (*p == '\n')
      extra++;

  clp.fmt = CF_UNICODETEXT;
  ucs2_t *b = (ucs2_t *) galloc (clp,
                                 (2 * xstring_length (string) + extra + 1)
                                 * sizeof *b);
  if (!b)
    return 0;

  for (; s < se; s++)
    {
      if (*s == '\n')
        *b++ = '\r';
      ucs4_t cp = *s;
      if (cp < 0x10000)
        *b++ = ucs2_t (cp);
      else
        {
          cp -= 0x10000;
          *b++ = ucs2_t (0xD800 + (cp >> 10));
          *b++ = ucs2_t (0xDC00 + (cp & 0x3FF));
        }
    }
  *b = 0;

  GlobalUnlock (clp.hgl);
  return 1;
}

int
make_clipboard_text (CLIPBOARDTEXT &clp, lisp string, int req)
{
  clp.hgl = 0;
  clp.fmt = 0;
  lisp encoding = symbol_value (Vclipboard_char_encoding, selected_buffer ());
  if (req == CF_UNICODETEXT || encoding_utf16_p (encoding))
    return make_cf_wtext (clp, string);
  return make_cf_text (clp, string, encoding);
}

static int
open_clipboard (HWND hwnd)
{
  for (int i = 0; i < 100; i++)
    {
      if (OpenClipboard (hwnd))
        return 1;
      Sleep (0);
    }
  return 0;
}

/* **Win32 に bracketed paste は無い** (issue #241)。あれは端末が貼り付けを
   囲んで送る仕組みで、GUI の貼り付けは `paste-from-clipboard` が
   クリップボードから読む。ここは常に nil を返す。 */
lisp
Fsi_take_pasted_text ()
{
  return Qnil;
}

lisp
Fcopy_to_clipboard (lisp string)
{
  check_string (string);
  if (!xstring_length (string))
    return Qnil;

  CLIPBOARDTEXT clp[2];
  memset (clp, 0, sizeof clp);
#ifdef UNICODE
  if (!make_cf_wtext (clp[0], string))
    FEstorage_error ();
#else
  lisp encoding = symbol_value (Vclipboard_char_encoding, selected_buffer ());
  if (encoding_utf16_p (encoding))
    {
      if (!make_cf_wtext (clp[0], string))
        FEstorage_error ();
    }
  else if (encoding_sjis_p (encoding) || encoding_auto_detect_p (encoding))
    {
      if (!make_cf_text_sjis (clp[0], string))
        FEstorage_error ();
    }
  else
    {
      if (!make_cf_wtext (clp[0], string))
        FEstorage_error ();
      if (!make_cf_text (clp[1], string, encoding))
        {
          GlobalFree (clp[0].hgl);
          FEstorage_error ();
        }
    }
#endif

  int result = 0;
  if (open_clipboard (app.toplev))
    {
      if (EmptyClipboard ())
        for (int i = 0; i < numberof (clp) && clp[i].hgl; i++)
          {
            if (!SetClipboardData (clp[i].fmt, clp[i].hgl))
              break;
            result = 1;
            clp[i].hgl = 0;
          }
      CloseClipboard ();
    }
  for (int i = 0; i < numberof (clp); i++)
    if (clp[i].hgl)
      GlobalFree (clp[i].hgl);
  xsymbol_value (Vclipboard_newer_than_kill_ring_p) = Qnil;
  xsymbol_value (Vkill_ring_newer_than_clipboard_p) = Qnil;
  return boole (result);
}

#ifndef UNICODE
static int
count_cf_text_length (const u_char *string)
{
  int l = 0;
  const u_char *s;
  for (s = string; *s;)
    {
      if (SJISP (*s))
        {
          if (!s[1])
            {
              s++;
              break;
            }
          l++;
          s += 2;
        }
      else
        {
          if (*s == '\r' && s[1] == '\n')
            l++;
          s++;
        }
    }
  return s - string - l;
}

static int
make_string_from_cf_text_sjis (lisp lstring, const u_char *s)
{
  int l = count_cf_text_length (s);
  Char *b = (Char *)malloc (l * sizeof *b);
  if (!b)
    return 0;
  xstring_contents (lstring) = b;
  xstring_length (lstring) = l;
  while (*s)
    {
      if (SJISP (*s))
        {
          if (!s[1])
            {
              *b = *s;
              break;
            }
          *b++ = (*s << 8) | s[1];
          s += 2;
        }
      else if (*s == '\r' && s[1] == '\n')
        s++;
      else
        *b++ = *s++;
    }
  return 1;
}
#endif /* !UNICODE */

static int
make_string_from_cf_text (lisp lstring, const u_char *s)
{
  const char* ss = reinterpret_cast<const char*> (s);
  lisp encoding = symbol_value (Vclipboard_char_encoding, selected_buffer ());
#ifndef UNICODE
  if (encoding_auto_detect_p (encoding))
    encoding = detect_char_encoding (ss, strlen (ss));
  if (encoding_sjis_p (encoding))
    return make_string_from_cf_text_sjis (lstring, s);
#endif

  int sl = strlen (ss);
  xinput_strstream str1 (ss, sl);
  encoding_input_stream_helper is1 (encoding, str1);
  int l = is1->total_length ();
  ucs4_t *b = (ucs4_t *)malloc (l * sizeof *b);
  if (!b)
    return 0;
  xstring_contents (lstring) = b;
  xinput_strstream str2 (ss, sl);
  encoding_input_stream_helper is2 (encoding, str2);
  int c;
  while ((c = is2->get ()) != xstream::eof)
    if (c != '\r')
      *b++ = c;
    else
      while (1)
        {
          c = is2->get ();
          if (c == '\n')
            {
              *b++ = c;
              break;
            }
          *b++ = '\r';
          if (c == xstream::eof)
            goto eof;
          if (c != '\r')
            {
              *b++ = c;
              break;
            }
        }
eof:
  xstring_length (lstring) = b - xstring_contents (lstring);

  return 1;
}

static int
count_cf_wtext_length (const ucs2_t *string)
{
  /* 5b-6: UTF-16 → Lisp string (ucs4_t = code point 列)。\r\n を \n に
     折り畳むので、その分だけ詰む。surrogate pair も 1 文字に詰む。 */
  int n = 0;
  for (const ucs2_t *s = string; *s; s++)
    {
      if (*s == '\r' && s[1] == '\n')
        continue;          /* CR を 1 文字落とす */
      if (*s >= 0xD800 && *s <= 0xDBFF && s[1] >= 0xDC00 && s[1] <= 0xDFFF)
        s++;               /* pair で 1 文字 */
      n++;
    }
  return n;
}

static int
make_string_from_cf_wtext (lisp lstring, const ucs2_t *s, int /*lang*/)
{
  /* 5b-6: clipboard CF_UNICODETEXT (UTF-16) を Lisp string (ucs4_t =
     code point 列) にコピー。\r\n → \n の正規化のみ。lang による
     translate table (旧 internal encoding 向け) は撤廃。
     surrogate pair は 1 code point に合成する。half を 2 要素として
     置くと (length "😀") が 2 になり、buffer に入れたときの code point
     数とも食い違う。 */
  int l = count_cf_wtext_length (s);
  ucs4_t *b = (ucs4_t *) malloc (l * sizeof *b);
  if (!b)
    return 0;
  xstring_contents (lstring) = b;
  xstring_length (lstring) = l;

  for (; *s; s++)
    {
      if (*s == '\r' && s[1] == '\n')
        continue;
      if (*s >= 0xD800 && *s <= 0xDBFF && s[1] >= 0xDC00 && s[1] <= 0xDFFF)
        {
          *b++ = 0x10000 + ((ucs4_t (*s) - 0xD800) << 10)
                 + (ucs4_t (s[1]) - 0xDC00);
          s++;
        }
      else
        *b++ = ucs4_t (*s);
    }

  return 1;
}

int
make_string_from_clipboard_text (lisp lstring, const void *data, UINT fmt, int lang)
{
  switch (fmt)
    {
    case CF_TEXT:
      return make_string_from_cf_text (lstring, (const u_char *)data);

    case CF_UNICODETEXT:
      return make_string_from_cf_wtext (lstring, (const ucs2_t *)data, lang);

    default:
      assert (0);
      return 0;
    }
}

static int
get_clipboatd_data (UINT fmt, lisp lstring, int lang)
{
  HGLOBAL hgl = GetClipboardData (fmt);
  if (!hgl)
    return -1;
  void *data = GlobalLock (hgl);
  if (!data)
    return 0;
  int r = make_string_from_clipboard_text (lstring, data, fmt, lang);
  GlobalUnlock (hgl);
  return r;
}

lisp
Fget_clipboard_data ()
{
  int result = -1;
  lisp lstring = make_simple_string ();
  if (open_clipboard (app.toplev))
    {
      lisp encoding = symbol_value (Vclipboard_char_encoding,
                                    selected_buffer ());
      if (encoding_utf16_p (encoding))
        result = get_clipboatd_data (CF_UNICODETEXT, lstring,
                                     xchar_encoding_utf_cjk (encoding));
      // Always prefer CF_UNICODETEXT over CF_TEXT.
      // CF_TEXT uses ACP which may not be CP932 (e.g. CP1252 on ARM64).
      if (result == -1)
        result = get_clipboatd_data (CF_UNICODETEXT, lstring, ENCODING_LANG_NIL);
      if (result == -1)
        result = get_clipboatd_data (CF_TEXT, lstring, ENCODING_LANG_NIL);
      CloseClipboard ();
    }
  if (!result)
    FEstorage_error ();
  if (result == -1)
    return Qnil;
  return lstring;
}

lisp
Fclipboard_empty_p ()
{
  return boole (!IsClipboardFormatAvailable (CF_TEXT)
                && (sysdep.WinNTp ()
                    || !IsClipboardFormatAvailable (CF_UNICODETEXT)));
}
