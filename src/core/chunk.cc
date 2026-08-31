#include "stdafx.h"
#include "ed.h"
#include "except.h"

/* --- チャンクのバイト列の意味 --------------------------------------------
 *
 * チャンクは C の `char *` である。**そのバイト列が何のエンコーディングかは
 * プラットフォームで違う**: Win32 の ANSI API (`MessageBoxA`、`atoi` など) は
 * CP932 を読み、POSIX の C 関数は UTF-8 を読む。
 *
 * ここは `w2s` / `s2w` (CP932) 決め打ちだった。**内部表現が CP932 のバイト列
 * だった頃はそれが恒等変換で、移行のときに残った。** POSIX では
 * `(si:make-string-chunk "日本語")` が CP932 のバイトを作るので、**渡した先の
 * C 関数が読めない。** 読み書きが対称なので Lisp の中で往復させる限りは
 * 気付かず、C に渡したときだけ壊れる。
 *
 * 変換の向きは 2 つ、区切り方が 3 つ (長さ無し / 長さで区切る / 書き込み先を
 * 長さで区切る) あるので、**プラットフォームの分岐をこの 6 つに閉じ込める。**
 * パスと環境変数が同じ考え方で書かれている (src/core/vfs-posix.cc の
 * `os_path`、src/core/environ.cc)。
 */

static size_t
chunk_encode_len (const ucs4_t *s, size_t size)
{
#ifdef _WIN32
  return w2sl (s, size);
#else
  return i2u8l (s, int (size)) - 1;   /* i2u8l は NUL の分を含む */
#endif
}

static void
chunk_encode (char *b, const ucs4_t *s, size_t size)
{
#ifdef _WIN32
  w2s (b, s, size);
#else
  i2u8 (s, int (size), b);
#endif
}

static void
chunk_encode (char *b, char *be, const ucs4_t *s, size_t size)
{
#ifdef _WIN32
  w2s (b, be, s, size);
#else
  /* **`w2s (b, be, s, size)` と同じ約束**にする: 末尾に NUL を置く分を残し、
     入り切らない文字は書かない (`w2s_chunk` は NUL を置かない別物なので、
     ここで使うと振る舞いが変わる)。 */
  be--;
  char *p = i2u8 (b, be, s, size);
  *p = 0;
#endif
}

static size_t
chunk_decode_len (const char *s, const char *se, int zero_term)
{
#ifdef _WIN32
  return s2wl (s, se, zero_term);
#else
  return u82il (s, se, zero_term);
#endif
}

static void
chunk_decode (ucs4_t *b, const char *s, const char *se, int zero_term)
{
#ifdef _WIN32
  s2w (b, s, se, zero_term);
#else
  u82i (b, s, se, zero_term);
#endif
}

static size_t
chunk_decode_len (const char *s)
{
#ifdef _WIN32
  return s2wl (s);
#else
  return u82il (s);
#endif
}

static void
chunk_decode (ucs4_t *b, const char *s)
{
#ifdef _WIN32
  s2w (b, s);
#else
  u82i (s, b);
#endif
}

lchunk *
make_chunk ()
{
  lchunk *p = ldata <lchunk, Tchunk>::lalloc ();
  p->type = Qnil;
  p->size = 0;
  p->data = 0;
  p->owner = Qnil;
  return p;
}

static void *
chunk_ptr (lisp chunk, lisp lsize)
{
  char *p0 = (char *)xchunk_data (chunk);
  char *pe = p0 + fixnum_value (lsize);
  if (pe < p0 || pe > p0 + xchunk_size (chunk)) // check overflow
    FErange_error (lsize);
  return p0;
}

static void *
chunk_ptr (lisp chunk, lisp loffset, lisp lsize)
{
  char *p0 = (char *)xchunk_data (chunk);
  char *p = p0 + unsigned_long_value (loffset);
  if (p < p0)  // avoid overflow
    FErange_error (loffset);
  char *pe = p + fixnum_value (lsize);
  if (pe < p || pe > p0 + xchunk_size (chunk))
    FErange_error (lsize);
  return p;
}

static void *
chunk_ptr (char *address, lisp lsize)
{
  char *ae = address + fixnum_value (lsize);
  if (ae < address)
    FErange_error (lsize);
  return address;
}

lisp
Fsi_make_chunk (lisp type, lisp lsize, lisp src_chunk, lisp loffset)
{
  int size = fixnum_value (lsize);
  if (size < 0)
    FErange_error (lsize);

  lisp chunk = make_chunk ();
  xchunk_type (chunk) = type;
  xchunk_size (chunk) = size;

  if (!src_chunk || src_chunk == Qnil)
    {
      if (!loffset || loffset == Qnil)
        {
          xchunk_data (chunk) = xmalloc (size);
          xchunk_owner (chunk) = chunk;
        }
      else
        {
          xchunk_data (chunk) =
            chunk_ptr ((char *)(uintptr_t)coerce_to_int64 (loffset), lsize);
          xchunk_owner (chunk) = Qnil;
        }
    }
  else
    {
      check_chunk (src_chunk);
      xchunk_owner (chunk) = src_chunk;
      if (!loffset || loffset == Qnil)
        xchunk_data (chunk) = chunk_ptr (src_chunk, lsize);
      else
        xchunk_data (chunk) = chunk_ptr (src_chunk, loffset, lsize);
    }
  return chunk;
}

lisp
Fsi_make_string_chunk (lisp string)
{
  check_string (string);
  int l = int (chunk_encode_len (xstring_contents (string),
                                xstring_length (string)));
  lisp chunk = make_chunk ();
  xchunk_type (chunk) = Qnil;
  xchunk_size (chunk) = l + 1;
  char *b = (char *)xmalloc (l + 1);
  xchunk_data (chunk) = b;
  xchunk_owner (chunk) = chunk;
  chunk_encode (b, xstring_contents (string), xstring_length (string));
  b[l] = 0;
  return chunk;
}

lisp
Fsi_chunkp (lisp data)
{
  return boole (chunkp (data));
}

lisp
Fsi_chunk_data (lisp chunk)
{
  check_chunk (chunk);
#ifdef _WIN64
  return make_integer ((int64_t)(intptr_t)xchunk_data (chunk));
#else
  return make_fixnum (long (xchunk_data (chunk)));
#endif
}

lisp
Fsi_chunk_size (lisp chunk)
{
  check_chunk (chunk);
  return make_fixnum (xchunk_size (chunk));
}

lisp
Fsi_chunk_type (lisp chunk)
{
  check_chunk (chunk);
  return xchunk_type (chunk);
}

lisp
Fsi_chunk_owner (lisp chunk)
{
  check_chunk (chunk);
  return xchunk_owner (chunk);
}

lisp
Fsi_address_of (lisp object)
{
#ifdef _WIN64
  return make_integer ((int64_t)(intptr_t)object);
#else
  return make_fixnum (long (object));
#endif
}

static char *
calc_chunk_ptr (lisp chunk, lisp loffset)
{
  check_chunk (chunk);
  char *p0 = (char *)xchunk_data (chunk);
  if (!loffset || loffset == Qnil)
    return p0;
  char *p = p0 + unsigned_long_value (loffset);
  if (p < p0 || p > p0 + xchunk_size (chunk))
    FErange_error (loffset);
  return p;
}

static lisp
fill_chunk (lisp chunk, int byte, lisp loffset, lisp lsize)
{
  char *p = calc_chunk_ptr (chunk, loffset);
  char *pe = (char *)xchunk_data (chunk) + xchunk_size (chunk);
  int size;
  if (!lsize || lsize == Qnil)
    size = pe - p;
  else
    {
      size = fixnum_value (lsize);
      if (size < 0 || p + size > pe)
        FErange_error (lsize);
    }
  memset (p, byte, size);
  return Qt;
}

lisp
Fsi_fill_chunk (lisp chunk, lisp lbyte, lisp loffset, lisp lsize)
{
  return fill_chunk (chunk, fixnum_value (lbyte), loffset, lsize);
}

lisp
Fsi_clear_chunk (lisp chunk, lisp loffset, lisp lsize)
{
  return fill_chunk (chunk, 0, loffset, lsize);
}

lisp
Fsi_copy_chunk (lisp fchunk, lisp tchunk, lisp lsize, lisp foffset, lisp toffset)
{
  char *f = calc_chunk_ptr (fchunk, foffset);
  char *t = calc_chunk_ptr (tchunk, toffset);
  char *fe = (char *)xchunk_data (fchunk) + xchunk_size (fchunk);
  char *te = (char *)xchunk_data (tchunk) + xchunk_size (tchunk);
  int size;
  if (!lsize || lsize == Qnil)
    size = min (fe - f, te - t);
  else
    {
      size = fixnum_value (lsize);
      if (size < 0 || f + size > fe || t + size > te)
        FErange_error (lsize);
    }

  memmove (t, f, size);
  return Qt;
}

static void *
chunk_ptr (lisp chunk, lisp loffset, int size)
{
  check_chunk (chunk);
  char *p0 = (char *)xchunk_data (chunk);
  char *p = p0 + unsigned_long_value (loffset);
  if (p < p0)  // avoid overflow
    FErange_error (loffset);
  char *pe = p + size;
  if (pe > p0 + xchunk_size (chunk))
    FErange_error (loffset);
  return p;
}

/* **幅は必ず固定幅の型で書く。** ここは `int8` に `char`、`int32` に `long`
   といった素の型を渡していた。`long` が 32bit の Windows (LLP64) では合って
   いるが、64bit の LP64 では `unpack-int32` が**4 バイトの欄から 8 バイト
   読む**ことになり、32bit からの符号拡張も起きない:

     0xFFFFFFFF を pack して (si:unpack-int32 ...)  =>  4294967295
                                                    (正: -1)

   `char` も同じ理由で危ない。符号の有無が処理系任せで、**Linux の ARM では
   `char` は符号無し**なので `unpack-int8` が負の値を返せなくなる
   (MSVC は常に符号付きなので Windows では表に出ない)。 */
template<typename T>
lisp
unpack_integer (lisp chunk, lisp offset)
{
  T *p = static_cast <T *> (chunk_ptr (chunk, offset, sizeof *p));
  try
    {
      return make_integer (*p);
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
}

lisp
Fsi_unpack_int8 (lisp chunk, lisp offset)
{
  return unpack_integer <int8_t> (chunk, offset);
}

lisp
Fsi_unpack_uint8 (lisp chunk, lisp offset)
{
  return unpack_integer <uint8_t> (chunk, offset);
}

lisp
Fsi_unpack_int16 (lisp chunk, lisp offset)
{
  return unpack_integer <int16_t> (chunk, offset);
}

lisp
Fsi_unpack_uint16 (lisp chunk, lisp offset)
{
  return unpack_integer <uint16_t> (chunk, offset);
}

lisp
Fsi_unpack_int32 (lisp chunk, lisp offset)
{
  return unpack_integer <int32_t> (chunk, offset);
}

lisp
Fsi_unpack_uint32 (lisp chunk, lisp offset)
{
  return unpack_integer <uint32_t> (chunk, offset);
}

lisp
Fsi_unpack_int64 (lisp chunk, lisp offset)
{
  return unpack_integer <int64_t> (chunk, offset);
}

lisp
Fsi_unpack_uint64 (lisp chunk, lisp offset)
{
  return unpack_integer <uint64_t> (chunk, offset);
}

lisp
Fsi_unpack_float (lisp chunk, lisp offset)
{
  float *p = (float *)chunk_ptr (chunk, offset, sizeof *p);
  try
    {
      return make_single_float (*p);
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
}

lisp
Fsi_unpack_double (lisp chunk, lisp offset)
{
  double *p = (double *)chunk_ptr (chunk, offset, sizeof *p);
  try
    {
      return make_double_float (*p);
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
}

lisp
unpack_string_chunk (lisp chunk, lisp loffset, lisp lsize, lisp lzero_term)
{
  check_chunk (chunk);
  char *p0 = (char *)xchunk_data (chunk);
  char *p = p0 + unsigned_long_value (loffset);
  if (p < p0 || p > p0 + xchunk_size (chunk))
    FErange_error (loffset);
  char *pe;
  if (!lsize || lsize == Qnil)
    pe = p0 + xchunk_size (chunk);
  else
    {
      pe = p + fixnum_value (lsize);
      if (pe < p || pe > p0 + xchunk_size (chunk))
        FErange_error (lsize);
    }
  int zero_term = !lzero_term || lzero_term != Qnil;
  try
    {
      size_t l = chunk_decode_len (p, pe, zero_term);
      lisp string = make_string (l);
      chunk_decode (xstring_contents (string), p, pe, zero_term);
      return string;
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
}

lisp
unpack_string_pointer (lisp laddress, lisp lsize, lisp lzero_term)
{
  char *p = reinterpret_cast <char*> ((uintptr_t)coerce_to_int64 (laddress));

  int zero_term = !lzero_term || lzero_term != Qnil;
  if (!lsize || lsize == Qnil)
    {
      if (!zero_term)
        FErange_error (lsize);
      try
        {
          size_t l = chunk_decode_len (p);
          lisp string = make_string (l);
          chunk_decode (xstring_contents (string), p);
          return string;
        }
      catch (Win32Exception &e)
        {
          e.throw_lisp_error ();
          throw;
        }
    }
  else
    {
      char *pe = p + fixnum_value (lsize);
      if (pe < p)
        FErange_error (lsize);
      try
        {
          size_t l = chunk_decode_len (p, pe, zero_term);
          lisp string = make_string (l);
          chunk_decode (xstring_contents (string), p, pe, zero_term);
          return string;
        }
      catch (Win32Exception &e)
        {
          e.throw_lisp_error ();
          throw;
        }
    }
}

// si:unpack-string chunk offset &optional size (zero_term t)
lisp
Fsi_unpack_string (lisp chunk, lisp loffset, lisp lsize, lisp lzero_term)
{
  if (chunk == Qnil)
    return unpack_string_pointer (loffset, lsize, lzero_term);
  else
    return unpack_string_chunk (chunk, loffset, lsize, lzero_term);
}

int64_t
cast_to_int64 (lisp object)
{
  if (pointerp (object))
    switch (object_typeof (object))
      {
      case Tchunk:
        return int64_t (xchunk_data (object));

      case Tdll_module:
        return int64_t (xdll_module_handle (object));

      case Tdll_function:
        return int64_t (xdll_function_proc (object));

      case Tc_callable:
        return int64_t (xc_callable_address (object));
      }
  return coerce_to_int64 (object);
}

long
cast_to_long (lisp object)
{
  return static_cast <long> (cast_to_int64 (object));
}

template<typename T>
lisp
pack_integer (lisp chunk, lisp offset, lisp value)
{
  T *p = static_cast <T *> (chunk_ptr (chunk, offset, sizeof *p));
  try
    {
      *p = static_cast <T> (cast_to_int64 (value));
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
  return value;
}

lisp
Fsi_pack_int8 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <int8_t> (chunk, offset, value);
}

lisp
Fsi_pack_uint8 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <uint8_t> (chunk, offset, value);
}

lisp
Fsi_pack_int16 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <int16_t> (chunk, offset, value);
}

lisp
Fsi_pack_uint16 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <uint16_t> (chunk, offset, value);
}

lisp
Fsi_pack_int32 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <int32_t> (chunk, offset, value);
}

lisp
Fsi_pack_uint32 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <uint32_t> (chunk, offset, value);
}

lisp
Fsi_pack_int64 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <int64_t> (chunk, offset, value);
}

lisp
Fsi_pack_uint64 (lisp chunk, lisp offset, lisp value)
{
  return pack_integer <uint64_t> (chunk, offset, value);
}

lisp
Fsi_pack_float (lisp chunk, lisp offset, lisp value)
{
  float *p = (float *)chunk_ptr (chunk, offset, sizeof *p);
  try
    {
      *p = coerce_to_single_float (value);
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
  return value;
}

lisp
Fsi_pack_double (lisp chunk, lisp offset, lisp value)
{
  double *p = (double *)chunk_ptr (chunk, offset, sizeof *p);
  try
    {
      *p = coerce_to_double_float (value);
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
  return value;
}

lisp
Fsi_pack_string (lisp chunk, lisp loffset, lisp value, lisp lsize)
{
  check_chunk (chunk);
  check_string (value);
  char *p0 = (char *)xchunk_data (chunk);
  char *p = p0 + unsigned_long_value (loffset);
  if (p < p0 || p > p0 + xchunk_size (chunk))
    FErange_error (loffset);
  char *pe;
  if (!lsize || lsize == Qnil)
    pe = p0 + xchunk_size (chunk);
  else
    {
      pe = p + fixnum_value (lsize);
      if (pe < p || pe > p0 + xchunk_size (chunk))
        FErange_error (lsize);
    }
  try
    {
      chunk_encode (p, pe, xstring_contents (value), xstring_length (value));
    }
  catch (Win32Exception &e)
    {
      e.throw_lisp_error ();
      throw;
    }
  return value;
}
