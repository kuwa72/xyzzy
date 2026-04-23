#ifndef _binfo_h_
#define _binfo_h_

#include "version.h"

/* Phase 2: mode line buffer は UTF-16 code unit 列 (Char *)。以前は cp932
   バイト列を組み立ててから cp932_to_wcs で wchar_t 化していたが、buffer
   名 / ファイル名に cp932 外の Unicode (emoji, 非 JIS 漢字等) が含まれると
   w2s で '?' 脱落していた。直接 Char で組み立てれば roundtrip なしで
   ExtTextOutW へ渡せる。 */
class buffer_info
{
  const Window *const b_wp;
  const Buffer *const b_bufp;
  Char **const b_posp;
  Char **const b_percentp;
  int *const b_ime;
  static const Char *const b_eol_name[];

  Char *minor_mode (lisp, Char *, Char *, int &) const;
public:
  buffer_info (const Window *wp, const Buffer *bp, Char **posp, int *ime, Char **percentp)
       : b_wp (wp), b_bufp (bp), b_posp (posp), b_ime (ime), b_percentp(percentp) {}
  Char *format (lisp, Char *, Char *) const;
  Char *modified (Char *, int) const;
  Char *read_only (Char *, int) const;
  Char *progname (Char *b, Char *be) const;
  Char *version (Char *, Char *, int) const;
  Char *buffer_name (Char *, Char *) const;
  Char *file_name (Char *, Char *, int) const;
  Char *file_or_buffer_name (Char *, Char *, int) const;
  Char *mode_name (Char *, Char *, int) const;
  Char *encoding (Char *b, Char *be) const;
  Char *eol_code (Char *b, Char *be) const;
  Char *ime_mode (Char *, Char *) const;
  Char *position (Char *, Char *) const;
  Char *host_name (Char *, Char *, int) const;
  Char *process_id (Char *, Char *) const;
  Char *admin_user (Char *, Char *) const;
  Char *percent(Char *, Char *) const;
};

#endif
