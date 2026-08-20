#include "stdafx.h"
#include "system.h"

#ifdef _WIN32
lisp
Fsi_uuid_create (lisp keys)
{
  UUID uuid;

  if (find_keyword_bool (Ksequential, keys))
    rpc_error (UuidCreateSequential (&uuid));
  else
    rpc_error (UuidCreate (&uuid));

  safe_rpc_str uuidstr;
  rpc_error (UuidToStringA (&uuid, &uuidstr));

  multiple_value::count () = 2;
  multiple_value::value (1) = make_list (
    make_integer (int64_t (uuid.Data1)),           // time-low
    make_fixnum (uuid.Data2),                      // time-mid
    make_fixnum (uuid.Data3),                      // time-high-and-version
    make_fixnum (uuid.Data4[0]),                   // clock-seq-and-reserved
    make_fixnum (uuid.Data4[1]),                   // clock-seq-low
    make_list (                                    // node
      make_fixnum (uuid.Data4[2]),
      make_fixnum (uuid.Data4[3]),
      make_fixnum (uuid.Data4[4]),
      make_fixnum (uuid.Data4[5]),
      make_fixnum (uuid.Data4[6]),
      make_fixnum (uuid.Data4[7]),
      0),
    0);

  return uuidstr.make_string ();
}

lisp
Fsi_get_key_state (lisp lvkey)
{
  int vkey = fixnum_value (lvkey);
  int flag = GetKeyState (vkey);

  multiple_value::count () = 2;
  multiple_value::value (1) = boole (flag & 0x01);
  return boole (flag < 0);
}

lisp
Fsi_search_path (lisp lfile, lisp lpath, lisp lext)
{
  /* These are pathnames; keep them UTF-16 rather than going through CP932. */
  wchar_t *path = 0;
  wchar_t *file = 0;
  wchar_t *ext = 0;

  check_string (lfile);
  file = (wchar_t *)alloca (i2wl (xstring_contents (lfile),
                                  xstring_length (lfile)) * sizeof (wchar_t));
  i2w (xstring_contents (lfile), xstring_length (lfile), file);

  if (lpath && lpath != Qnil)
    {
      check_string (lpath);
      path = (wchar_t *)alloca (i2wl (xstring_contents (lpath),
                                      xstring_length (lpath)) * sizeof (wchar_t));
      i2w (xstring_contents (lpath), xstring_length (lpath), path);
    }
  if (lext && lext != Qnil)
    {
      check_string (lext);
      ext = (wchar_t *)alloca (i2wl (xstring_contents (lext),
                                     xstring_length (lext)) * sizeof (wchar_t));
      i2w (xstring_contents (lext), xstring_length (lext), ext);
    }

  DWORD len = SearchPathW (path, file, ext, 0, 0, 0);
  if (!len)
    return Qnil;

  wchar_t *file_part = 0;
  wchar_t *buffer = (wchar_t *)alloca (len * sizeof (wchar_t));
  if (!SearchPathW (path, file, ext, len, buffer, &file_part))
    return Qnil;

  return make_path (buffer, 0);
}

lisp
Fadmin_user_p ()
{
  if (IsUserAnAdmin ())
    return Qt;
  else
    return Qnil;
}
#endif // _WIN32
