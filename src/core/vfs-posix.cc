// POSIX implementation of WINFS (src/core/vfs.h), the filesystem seam every
// frontend has to fill in.  On Windows src/frontend/win32/vfs.cc fills it with
// the real Win32 calls; this is the other side, and it lives in core rather
// than in a frontend because it is not frontend-specific: xyzzy-cli and
// xyzzy-ncurses need exactly the same filesystem.
//
// It used to live in src/frontend/ncurses/ncurses-stubs.cc, which meant
// xyzzy-cli got the src/frontend/cli/cli-stubs.cc version instead -- a
// passthrough to ::CreateFileW and friends, which outside Windows are the
// always-fail stubs in platform.h.  The CLI frontend could therefore not open,
// list, copy or delete a single file, and nothing said so: every call just
// returned "failed".
//
// Built only when NOT WIN32 (see CORE_SOURCES in CMakeLists.txt).

#include "stdafx.h"
#include "ed.h"
#include "vfs.h"


wchar_t WINFS::wfs_share_cache[MAX_PATH * 2];
const WINFS::GETDISKFREESPACEEX WINFS::GetDiskFreeSpaceEx = 0;

// POSIX implementations of WINFS methods for ncurses frontend

#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

/* WINFS speaks wchar_t; a Unix filesystem speaks bytes, and on any system
   this build targets those bytes are UTF-8. This is the whole conversion, and
   it replaces a hop through CP932 that could not represent most filenames.
   The codec itself lives in core (i2u8 / u82i) so both ends agree. */
class os_path
{
  char buf[PATH_MAX * 4 + 1];
public:
  explicit os_path (const wchar_t *w)
    {
      ucs4_t cp[PATH_MAX + 1];
      size_t n = wcslen (w);
      if (n > PATH_MAX)
        n = PATH_MAX;
      ucs4_t *e = w2i (w, int (n), cp);
      i2u8 (cp, int (e - cp), buf);
    }
  operator const char * () const {return buf;}
  const char *c_str () const {return buf;}
};

/* UTF-8 -> wchar_t, writing at most n units including the terminator.
   Returns the number of units written, not counting the terminator. */
static int
from_os_path (const char *s, wchar_t *b, int n)
{
  size_t len = u82il (s);
  ucs4_t *cp = (ucs4_t *)alloca ((len + 1) * sizeof (ucs4_t));
  ucs4_t *e = u82i (s, cp);
  int l = int (e - cp);
  if (l > n - 1)
    l = n - 1;
  i2w (cp, l, b);
  return l;
}

static DWORD posix_get_file_attrs (const char *p)
{
  struct stat st;
  if (stat (p, &st) != 0)
    return INVALID_FILE_ATTRIBUTES;
  DWORD attrs = 0;
  if (S_ISDIR (st.st_mode))
    attrs |= FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR))
    attrs |= FILE_ATTRIBUTE_READONLY;
  return attrs;
}

BOOL WINAPI WINFS::CreateDirectory (LPCWSTR p, LPSECURITY_ATTRIBUTES)
{
  return mkdir (os_path (p), 0755) == 0;
}

HANDLE WINAPI WINFS::CreateFile (LPCWSTR p, DWORD access, DWORD,
  LPSECURITY_ATTRIBUTES, DWORD cd, DWORD, HANDLE)
{
  int flags = 0;
  if ((access & GENERIC_READ) && (access & GENERIC_WRITE))
    flags = O_RDWR;
  else if (access & GENERIC_WRITE)
    flags = O_WRONLY;
  else
    flags = O_RDONLY;

  switch (cd)
    {
    case CREATE_NEW:
      flags |= O_CREAT | O_EXCL;
      break;
    case CREATE_ALWAYS:
      flags |= O_CREAT | O_TRUNC;
      break;
    case OPEN_EXISTING:
      break;
    case OPEN_ALWAYS:
      flags |= O_CREAT;
      break;
    case TRUNCATE_EXISTING:
      flags |= O_TRUNC;
      break;
    }

  int fd = open (os_path (p), flags, 0644);
  if (fd < 0)
    return INVALID_HANDLE_VALUE;
  return (HANDLE)(intptr_t)fd;
}

BOOL WINAPI WINFS::DeleteFile (LPCWSTR p)
{
  return unlink (os_path (p)) == 0;
}

// Directory enumeration state for FindFirstFile/FindNextFile
struct posix_find_handle
{
  DIR *dir;
  char basedir[PATH_MAX];
};

static void
fill_find_data (LPWIN32_FIND_DATAW d, const char *basedir, const char *name)
{
  memset (d, 0, sizeof (*d));
  from_os_path (name, d->cFileName, MAX_PATH);

  char fullpath[PATH_MAX * 2];
  snprintf (fullpath, sizeof (fullpath), "%s/%s", basedir, name);
  struct stat st;
  if (stat (fullpath, &st) == 0)
    {
      if (S_ISDIR (st.st_mode))
        d->dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
      d->nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
      d->nFileSizeHigh = (DWORD)(st.st_size >> 32);
    }
}

static struct dirent *
readdir_skip_dots (DIR *dir)
{
  struct dirent *ent = readdir (dir);
  while (ent && (strcmp (ent->d_name, ".") == 0 || strcmp (ent->d_name, "..") == 0))
    ent = readdir (dir);
  return ent;
}

HANDLE WINAPI WINFS::FindFirstFile (LPCWSTR p, LPWIN32_FIND_DATAW d)
{
  // p might be a glob pattern like "/path/to/dir/*"
  // Extract the directory part
  char dirpath[PATH_MAX];
  strncpy (dirpath, os_path (p), PATH_MAX - 1);
  dirpath[PATH_MAX - 1] = 0;

  // Remove trailing wildcard (e.g., "/*" or "/*.*")
  char *slash = strrchr (dirpath, '/');
  if (slash)
    *slash = 0;
  else
    strcpy (dirpath, ".");

  DIR *dir = opendir (dirpath);
  if (!dir)
    return INVALID_HANDLE_VALUE;

  struct dirent *ent = readdir_skip_dots (dir);
  if (!ent)
    {
      closedir (dir);
      return INVALID_HANDLE_VALUE;
    }

  fill_find_data (d, dirpath, ent->d_name);

  posix_find_handle *fh = new posix_find_handle;
  fh->dir = dir;
  strncpy (fh->basedir, dirpath, PATH_MAX - 1);
  fh->basedir[PATH_MAX - 1] = 0;
  return (HANDLE)fh;
}

BOOL WINAPI WINFS::FindNextFile (HANDLE h, LPWIN32_FIND_DATAW d)
{
  posix_find_handle *fh = (posix_find_handle *)h;
  if (!fh || !fh->dir)
    return FALSE;

  struct dirent *ent = readdir_skip_dots (fh->dir);
  if (!ent)
    return FALSE;

  fill_find_data (d, fh->basedir, ent->d_name);
  return TRUE;
}

BOOL FindClose (HANDLE h)
{
  if (h && h != INVALID_HANDLE_VALUE)
    {
      posix_find_handle *fh = (posix_find_handle *)h;
      if (fh->dir)
        closedir (fh->dir);
      delete fh;
    }
  return TRUE;
}

BOOL WINAPI WINFS::GetDiskFreeSpace (LPCWSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD)
{
  return FALSE;
}

DWORD WINAPI WINFS::internal_GetFileAttributes (LPCWSTR p)
{
  return posix_get_file_attrs (os_path (p));
}

DWORD WINAPI WINFS::GetFileAttributes (LPCWSTR p)
{
  return posix_get_file_attrs (os_path (p));
}

UINT WINAPI WINFS::GetTempFileName (LPCWSTR dir, LPCWSTR prefix, UINT, LPWSTR buf)
{
  char tem[PATH_MAX];
  snprintf (tem, sizeof tem, "%s/%sXXXXXX",
            os_path (dir).c_str (), prefix ? os_path (prefix).c_str () : "tmp");
  int fd = mkstemp (tem);
  if (fd < 0)
    return 0;
  close (fd);
  from_os_path (tem, buf, MAX_PATH);
  return 1;
}

BOOL WINAPI WINFS::GetVolumeInformation (LPCWSTR, LPWSTR vn, DWORD vs, LPDWORD sn,
  LPDWORD mcl, LPDWORD fsf, LPWSTR fsn, DWORD fss)
{
  if (vn && vs > 0) vn[0] = 0;
  if (sn) *sn = 0;
  if (mcl) *mcl = 255;
  if (fsf) *fsf = 0;
  if (fsn && fss > 0) fsn[0] = 0;
  return TRUE;
}

HMODULE WINAPI WINFS::LoadLibrary (LPCWSTR)
{
  return 0;
}

BOOL WINAPI WINFS::MoveFile (LPCWSTR a, LPCWSTR b)
{
  os_path pa (a);
  os_path pb (b);
  return rename (pa, pb) == 0;
}

BOOL WINAPI WINFS::RemoveDirectory (LPCWSTR p)
{
  return rmdir (os_path (p)) == 0;
}

BOOL WINAPI WINFS::SetFileAttributes (LPCWSTR, DWORD)
{
  return TRUE;
}

DWORD WINAPI WINFS::internal_GetFullPathName (LPCWSTR p, DWORD n, LPWSTR b, LPWSTR *f)
{
  os_path path (p);
  char full[PATH_MAX * 2];
  const char *src = 0;

  char resolved[PATH_MAX];
  if (realpath (path, resolved))
    src = resolved;
  else if (path.c_str ()[0] == '/')
    src = path;                       // realpath fails when the file is new
  else
    {
      char cwd[PATH_MAX];
      if (!getcwd (cwd, sizeof cwd))
        return 0;
      snprintf (full, sizeof full, "%s/%s", cwd, path.c_str ());
      src = full;
    }

  int len = from_os_path (src, b, int (n));
  if (DWORD (len) >= n)
    return 0;
  if (f)
    {
      *f = b;
      for (wchar_t *s = b; *s; s++)
        if (*s == L'/')
          *f = s + 1;
    }
  return DWORD (len);
}

BOOL WINAPI WINFS::SetCurrentDirectory (LPCWSTR p)
{
  return chdir (os_path (p)) == 0;
}

DWORD WINAPI WINFS::GetFullPathName (LPCWSTR p, DWORD n, LPWSTR b, LPWSTR *f)
{
  return internal_GetFullPathName (p, n, b, f);
}

DWORD WINAPI WINFS::WNetOpenEnum (DWORD, DWORD, DWORD, LPNETRESOURCEW, LPHANDLE)
{ return (DWORD)-1; }

int WINAPI WINFS::get_file_data (const wchar_t *path, WIN32_FIND_DATAW &fd)
{
  os_path p (path);
  struct stat st;
  if (stat (p, &st) != 0)
    return 0;
  memset (&fd, 0, sizeof (fd));
  if (S_ISDIR (st.st_mode))
    fd.dwFileAttributes = FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR))
    fd.dwFileAttributes |= FILE_ATTRIBUTE_READONLY;
  fd.nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
  fd.nFileSizeHigh = (DWORD)(st.st_size >> 32);
  // Extract filename from path
  const char *name = strrchr (p.c_str (), '/');
  from_os_path (name ? name + 1 : p.c_str (), fd.cFileName, MAX_PATH);
  return 1;
}
