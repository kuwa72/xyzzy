// -*-C++-*-
#ifndef _char_h_
# define _char_h_

# include "chtype.h"
# include "charset.h"

inline lisp
make_char (ucs4_t c)
{
  return make_immediate (Lchar, c);
}

inline int
charp (lisp x)
{
  return immediate_tag (x) == Lchar;
}

inline ucs4_t
xchar_code (lisp x)
{
  assert (charp (x));
  return ucs4_t (ximmediate_data (x));
}

inline void
check_char (lisp x)
{
  if (!charp (x))
    FEtype_error (x, Qcharacter);
}

#endif
