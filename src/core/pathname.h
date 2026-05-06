#ifndef _pathname_h_
# define _pathname_h_

# define WPATH_MAX (PATH_MAX / 2)

typedef ucs4_t pathbuf_t[WPATH_MAX * 2 + 1];

struct pathname
{
  const ucs4_t *dev;
  const ucs4_t *deve;
  const ucs4_t *trail;
  const ucs4_t *traile;
};

# define SEPCHAR '/'

#endif
