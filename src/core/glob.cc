#include "stdafx.h"
#include "ed.h"
#include "glob.h"

int
file_masks::match (const wchar_t *name) const
{
  if (empty_p ())
    return 0;
  int not = 0, match = 0;
  for (wchar_t **p = fm_masks; *p; p++)
    if (**p == GLOB_NOT)
      {
        match |= pathname_match_p (*p + 1, name);
        not = 1;
      }
    else if (pathname_match_p (*p, name))
      return 1;
  return not ? !match : 0;
}

wchar_t **
file_masks::build_masks (lisp lmasks)
{
  int nfiles = 0;
  int nunits = 0;
  for (lisp p = lmasks; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      check_string (x);
      if (xstring_length (x))
        {
          nunits += i2wl (xstring_contents (x), xstring_length (x));
          nfiles++;
        }
    }

  if (!nfiles)
    return 0;

  nfiles++;
  wchar_t **b0 = (wchar_t **)xmalloc (sizeof (wchar_t *) * nfiles
                                      + nunits * sizeof (wchar_t));
  wchar_t **b = b0;
  wchar_t *s = (wchar_t *)((char *)b0 + sizeof (wchar_t *) * nfiles);
  for (lisp p = lmasks; consp (p); p = xcdr (p))
    {
      lisp x = xcar (p);
      if (xstring_length (x))
        {
          *b++ = s;
          s = i2w (xstring_contents (x), xstring_length (x), s) + 1;
        }
    }
  *b = 0;
  return b0;
}

void
file_masks::set_text (HWND hwnd) const
{
  if (empty_p ())
    SetWindowTextW (hwnd, L"");
  else
    {
      int nunits = 16;
      for (wchar_t **p = fm_masks; *p; p++)
        nunits += wcslen (*p) + 1;

      wchar_t *b0 = (wchar_t *)alloca (nunits * sizeof (wchar_t));
      wchar_t *b = wstpcpy (b0, L"Mask:");
      for (wchar_t **p = fm_masks; *p; p++)
        {
          *b++ = ' ';
          b = wstpcpy (b, *p);
        }
      SetWindowTextW (hwnd, b0);
    }
}

/* One pattern matcher, over UTF-16.

   There used to be three: pattern and name both in CP932, pattern in CP932
   against a wide name, and both wide but without bracket expressions. The
   SJIS ones had to step over trail bytes at every turn, which is where the
   `[a-z]` ranges got their odd two-byte special cases. With both sides wide
   a code unit is a code unit and the three collapse into one. */

static const wchar_t *
find_matched_bracket (const wchar_t *s)
{
  if (*s == L'^')
    s++;
  if (*s == L']')
    s++;
  for (; *s; s++)
    if (*s == L']')
      return s;
  return 0;
}

int
wild_pathname_p (const wchar_t *filename)
{
  const wchar_t *p = filename;
  int unmatched_bracket = xsymbol_value (Vbrackets_is_wildcard_character) == Qnil;

  if (*p == GLOB_NOT)
    return 1;

  while (1)
    {
      wchar_t c = *p++;
      switch (c)
        {
        case 0:
          return 0;

        case L'[':
          if (!unmatched_bracket && find_matched_bracket (p))
            return 1;
          unmatched_bracket = 1;
          break;

        case L'*':
        case L'?':
          return 1;
        }
    }
}

static inline wchar_t
wupcase (wchar_t c)
{
  return (wchar_t)towupper ((wint_t)c);
}

static int
pathname_match_p1 (const wchar_t *p, const wchar_t *s, int nodot)
{
  int unmatched_bracket = xsymbol_value (Vbrackets_is_wildcard_character) == Qnil;

  while (1)
    {
      wchar_t c = *p++;
      switch (c)
        {
        case 0:
          return !*s;

        case L'[':
          {
            if (unmatched_bracket)
              goto normal;
            const wchar_t *pe = find_matched_bracket (p);
            if (!pe)
              {
                unmatched_bracket = 1;
                goto normal;
              }
            if (!*s)
              return 0;
            int not = 0;
            if (*p == L'^')
              {
                not = 1;
                p++;
              }

            while (p < pe)
              {
                c = *p++;
                if (*p == L'-' && p + 1 < pe)
                  {
                    wchar_t x = wupcase (*s);
                    if (x >= wupcase (c) && x <= wupcase (p[1]))
                      {
                        not ^= 1;
                        break;
                      }
                    p += 2;
                  }
                else if (wupcase (c) == wupcase (*s))
                  {
                    not ^= 1;
                    break;
                  }
              }
            if (!not)
              return 0;
            p = pe + 1;
            s++;
            break;
          }

        case L'?':
          if (!*s)
            return 0;
          if (nodot && *s == L'.')
            return 0;
          s++;
          break;

        case L'*':
          while (*p == L'*')
            p++;
          if (!*p)
            return 1;
          while (1)
            {
              if (pathname_match_p1 (p, s, nodot))
                return 1;
              if (!*s)
                return 0;
              if (nodot && *s == L'.')
                return 0;
              s++;
            }
          /* NOTREACHED */

        case L'.':
          if (*s == L'.')
            s++;
          else
            return !*p && !*s;
          break;

        default:
        normal:
          if (wupcase (c) != wupcase (*s))
            return 0;
          s++;
        }
    }
}

int
pathname_match_p (const wchar_t *pat, const wchar_t *str)
{
  int l = (int) wcslen (pat);
  int nodot = l > 1 && pat[l - 1] == L'.';
  return pathname_match_p1 (pat, str, nodot);
}

#define DF_ABSOLUTE 1
#define DF_RECURSIVE 2
#define DF_FILE_ONLY 4
#define DF_SHOW_DOTS 8
#define DF_COUNT 16
#define DF_DIR_ONLY 32
#define DF_FILE_INFO 64

static lisp
directory (wchar_t *path, const wchar_t *pat, wchar_t *name, file_masks &masks, int flags,
           int depth, int max_depth, long &count, lisp callback, lisp test, lisp result)
{
  QUIT;

  if (max_depth && depth >= max_depth)
    return result;

  int l = int (wcslen (path));
  if (l >= PATH_MAX)
    return result;

  wchar_t *pe = path + l;
  *pe = '*';
  pe[1] = 0;

  wchar_t *ne = name + wcslen (name);

  WIN32_FIND_DATAW fd;

  HANDLE h = WINFS::FindFirstFile (path, &fd);
  if (h != INVALID_HANDLE_VALUE)
    {
      find_handle fh (h);
      do
        {
#ifndef PATHNAME_ESCAPE_TILDE
          if (*fd.cFileName == '~' && !fd.cFileName[1])
            continue;
#endif
          bool test_called = false;
          if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            {
              if (*fd.cFileName == '.'
                  && (!fd.cFileName[1]
                      || (fd.cFileName[1] == '.' && !fd.cFileName[2])))
                {
                  if (!(flags & DF_SHOW_DOTS))
                    continue;
                }
              else if (*pat == GLOB_NOT
                       ? pathname_match_p (pat + 1, fd.cFileName)
                       : (*pat && !pathname_match_p (pat, fd.cFileName)))
                continue;
              else if (flags & DF_RECURSIVE)
                {
                  if (!(flags & DF_ABSOLUTE))
                    wcscpy (wstpcpy (ne, fd.cFileName), L"/");
                  wcscpy (wstpcpy (pe, fd.cFileName), L"/");
                  if (test != Qnil)
                    {
                      lisp lpath = make_string ((flags & DF_ABSOLUTE) ? path : name);
                      if (flags & DF_FILE_INFO)
                        lpath = xcons (lpath, make_file_info (fd));
                      test_called = true;
                      if (funcall_1 (test, lpath) == Qnil)
                        continue;
                    }
                  result = directory (path, L"", name, masks, flags,
                                      depth + 1, max_depth, count, callback, test, result);
                  if (flags & DF_COUNT && count <= 0)
                    break;
                }
              if (flags & DF_FILE_ONLY)
                continue;
              if (!masks.empty_p () && !masks.match (fd.cFileName))
                continue;
              if (flags & DF_ABSOLUTE)
                wcscpy (wstpcpy (pe, fd.cFileName), L"/");
              else
                wcscpy (wstpcpy (ne, fd.cFileName), L"/");
            }
          else
            {
              if (flags & DF_DIR_ONLY)
                continue;
              if (*pat)
                {
                  if (*pat == GLOB_NOT
                      ? pathname_match_p (pat + 1, fd.cFileName)
                      : !pathname_match_p (pat, fd.cFileName))
                    continue;
                }
              else
                {
                  if (!masks.empty_p () && !masks.match (fd.cFileName))
                    continue;
                }
              if (flags & DF_ABSOLUTE)
                wcscpy (pe, fd.cFileName);
              else
                wcscpy (ne, fd.cFileName);
            }
          lisp lpath = make_string ((flags & DF_ABSOLUTE) ? path : name);
          if (flags & DF_FILE_INFO)
            lpath = xcons (lpath, make_file_info (fd));
          if (test != Qnil && !test_called)
            {
              if (funcall_1 (test, lpath) == Qnil)
                continue;
            }

          if (callback != Qnil)
            {
              lisp arg = xcons (lpath, Qnil);
              protect_gc gcpro (arg);
              Ffuncall (callback, arg);
            }
          else
            result = xcons (lpath, result);
          if (flags & DF_COUNT && --count <= 0)
            break;
        }
      while (WINFS::FindNextFile (h, &fd));
    }
  return result;
}

lisp
Fdirectory (lisp dirname, lisp keys)
{
  wchar_t path[PATH_MAX * 2];
  wchar_t pat[PATH_MAX + 1];
  pathname2wstr (dirname, path);
  wchar_t *p = wcsrchr (path, L'/');
  int f = WINFS::GetFileAttributes (path);
  if (f != -1 && f & FILE_ATTRIBUTE_DIRECTORY)
    {
      if (p && p[1])
        wcscat (path, L"/");
      *pat = 0;
    }
  else
    {
      if (p)
        {
          wcscpy (pat, p + 1);
          p[1] = 0;
        }
      else
        {
          wcscpy (pat, path);
          *path = 0;
        }
    }

  lisp wild = find_keyword (Kwild, keys, Qnil);
  file_masks masks (stringp (wild) ? xcons (wild, Qnil) : wild);

  wchar_t name[PATH_MAX * 2];
  *name = 0;

  int flags = 0;
  int max_depth = 0;
  long count = 0;
  if (find_keyword (Kabsolute, keys, Qnil) != Qnil)
    flags |= DF_ABSOLUTE;
  if (find_keyword (Krecursive, keys, Qnil) != Qnil)
    {
      flags |= DF_RECURSIVE;
      lisp x = find_keyword (Kdepth, keys, Qnil);
      if (x != Qnil)
        max_depth = fixnum_value (x);
    }
  if (find_keyword (Kfile_only, keys, Qnil) != Qnil)
    flags |= DF_FILE_ONLY;
  if (find_keyword (Kshow_dots, keys, Qnil) != Qnil)
    flags |= DF_SHOW_DOTS;
  lisp lcount = find_keyword (Kcount, keys, Qnil);
  if (lcount != Qnil)
    {
      flags |= DF_COUNT;
      count = fixnum_value (lcount);
      if (count <= 0)
        return Qnil;
    }
  else if (find_keyword (Kany_one, keys, Qnil) != Qnil) // for compatibility
    {
      flags |= DF_COUNT;
      count = 1;
    }
  if (find_keyword (Kdirectory_only, keys, Qnil) != Qnil)
    flags |= DF_DIR_ONLY;
  if (find_keyword (Kfile_info, keys, Qnil) != Qnil)
    flags |= DF_FILE_INFO;
  lisp callback = find_keyword (Kcallback, keys, Qnil);
  lisp test = find_keyword (Ktest, keys, Qnil);
  return Fnreverse (directory (path, pat, name, masks, flags,
                               0, max_depth, count, callback, test, Qnil));
}

lisp
Fpathname_match_p (lisp pathname, lisp wildname)
{
  check_string (pathname);
  check_string (wildname);
  wchar_t *path = (wchar_t *)alloca (i2wl (xstring_contents (pathname),
                                           xstring_length (pathname))
                                     * sizeof (wchar_t));
  i2w (xstring_contents (pathname), xstring_length (pathname), path);
  wchar_t *wild = (wchar_t *)alloca (i2wl (xstring_contents (wildname),
                                           xstring_length (wildname))
                                     * sizeof (wchar_t));
  i2w (xstring_contents (wildname), xstring_length (wildname), wild);
  return boole (*wild == GLOB_NOT
                ? !pathname_match_p (wild + 1, path)
                : pathname_match_p (wild, path));
}

lisp
Fwild_pathname_p (lisp pathname)
{
  wchar_t path[PATH_MAX + 1];
  pathname2wstr (pathname, path);
  return boole (wild_pathname_p (path));
}
