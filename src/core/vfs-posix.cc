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
const int WINFS::case_insensitive_names = 0;

// POSIX implementations of WINFS methods for ncurses frontend

#include <sys/stat.h>
#include <sys/statvfs.h>
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
      /* **`\' を区切りとして受ける。** core のパス層はどのプラットフォームでも
         `/` と `\` の両方を区切りとして扱い、`namestring' は `\` を `/` に
         直して返す (src/core/pathname.cc)。したがって **xyzzy から見て
         「名前に `\` を含むファイル」は POSIX でも最初から到達できない。**
         にもかかわらずここが `\` をただのバイトとして通していたため、
         `map_sl_to_backsl' を掛けてから WINFS を呼ぶ経路 (mkdirhier,
         Ftruename, rename_short_name) が `\home\kuwa72\...` という 1 個の
         **相対ディレクトリ名**を OS に渡していた。mkdir はそれを作れてしまう
         ので、カレントディレクトリにゴミが出来た上で成功が返っていた。
         境界で core と同じ解釈に揃える。 */
      for (char *p = buf; *p; p++)
        if (*p == '\\')
          *p = '/';
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

#if defined (__APPLE__)
# define ST_ATIME(st) ((st).st_atimespec)
# define ST_MTIME(st) ((st).st_mtimespec)
# define ST_CTIME(st) ((st).st_ctimespec)
#else
# define ST_ATIME(st) ((st).st_atim)
# define ST_MTIME(st) ((st).st_mtim)
# define ST_CTIME(st) ((st).st_ctim)
#endif

// FILETIME counts 100ns units from 1601-01-01; the offset to the Unix epoch is
// the same constant SystemTimeToFileTime in platform.h uses.
#define FILETIME_EPOCH_OFFSET 11644473600ULL

static void
timespec_to_filetime (const struct timespec &ts, FILETIME *ft)
{
  uint64_t v = ((uint64_t)ts.tv_sec + FILETIME_EPOCH_OFFSET) * 10000000ULL
               + (uint64_t)ts.tv_nsec / 100;
  ft->dwLowDateTime = (DWORD)v;
  ft->dwHighDateTime = (DWORD)(v >> 32);
}

static void
filetime_to_timespec (const FILETIME *ft, struct timespec &ts)
{
  uint64_t v = ((uint64_t)ft->dwHighDateTime << 32) | ft->dwLowDateTime;
  ts.tv_sec = (time_t)(v / 10000000ULL - FILETIME_EPOCH_OFFSET);
  ts.tv_nsec = (long)(v % 10000000ULL) * 100;
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
        d->dwFileAttributes |= FILE_ATTRIBUTE_DIRECTORY;
      if (!(st.st_mode & S_IWUSR))
        d->dwFileAttributes |= FILE_ATTRIBUTE_READONLY;
      d->nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
      d->nFileSizeHigh = (DWORD)(st.st_size >> 32);
      // Leaving these zero dated every file 1601-01-01, which is what
      // file-write-time returned for anything on this side, and what the
      // "changed on disk since you read it" check compared against.
      timespec_to_filetime (ST_CTIME (st), &d->ftCreationTime);
      timespec_to_filetime (ST_ATIME (st), &d->ftLastAccessTime);
      timespec_to_filetime (ST_MTIME (st), &d->ftLastWriteTime);
    }
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
  if (slash == dirpath)
    /* **ルート直下は "/" を残す。** ルートに対するグロブ (スラッシュ 1 個の
       あとにワイルドカード) から区切りを切り落とすと空文字列になり、
       opendir ("") が必ず失敗する。`(directory "/")' が nil を返し、
       `/` 直下のファイル名補完が :no-completions になっていた。 */
    dirpath[1] = 0;
  else if (slash)
    *slash = 0;
  else
    strcpy (dirpath, ".");

  /* **失敗するときは必ず errno を立てる。** 非 Win32 では GetLastError () は
     errno を返す (src/core/platform.h) ので、ここが errno に触らずに
     INVALID_HANDLE_VALUE を返すと、**呼び出し側が前の操作の errno を
     「この失敗の理由」として読む。** 補完はこれを見て「候補が無い」と
     「そこを読めない」を分けるので (src/core/completion.cc)、残り物の errno で
     file_error が上がる。 */
  errno = 0;
  DIR *dir = opendir (dirpath);
  if (!dir)
    {
      if (!errno)
        errno = ENOENT;
      return INVALID_HANDLE_VALUE;
    }

  /* **"." と ".." も返す。** Win32 の FindFirstFile はディレクトリに対する
     グロブでこの 2 つを返し、**弾くのは呼び出し側の仕事**である
     (src/core/glob.cc の DF_SHOW_DOTS、src/core/completion.cc)。ここで
     先に落としていたため `(directory dir :show-dots t)' が "./" と "../" を
     返さず、Win32 と挙動が違っていた。
     再帰で無限に潜る心配は無い: glob.cc はドットのときは `continue' して
     再帰の枝に入らない。 */
  struct dirent *ent = readdir (dir);
  if (!ent)
    {
      closedir (dir);
      /* 空のディレクトリ。Win32 の FindFirstFile がグロブに何も合わない
         ときに返す ERROR_FILE_NOT_FOUND と同じ意味にする (その値は 2 で、
         ENOENT も 2)。**"." が必ずあるので、実在するディレクトリでここへ
         来ることは無い** (Win32 も同じ)。 */
      errno = ENOENT;
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

  struct dirent *ent = readdir (fh->dir);
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

/* ディスクの空き。`statvfs` で埋まる。
   **これがスタブだったので `get-disk-usage` は失敗を返し、`Fget_disk_usage`
   が `file_error` を投げていた** — 実在するディレクトリを渡しても
   「file-not-found」になる。使う側 (ファイラの容量表示など) からは
   「そのディレクトリが無い」と読めるので、たちが悪い。

   `lpRootPathName` が 0 なら「今いるボリューム」の意味 (呼ぶ側が先に
   `SetCurrentDirectory` している)。

   **欄が DWORD なので、大きなファイルシステムでは数が入り切らない。**
   これは Win32 の `GetDiskFreeSpace` も同じで (だから
   `GetDiskFreeSpaceEx` がある)、呼ぶ側はブロック数 x ブロックの大きさで
   バイト数を出す。**ブロックの大きさを 2 倍にして数を半分にすれば積は
   変わらない**ので、入り切るまでそれを繰り返す。 */
BOOL WINAPI WINFS::GetDiskFreeSpace (LPCWSTR root,
                                     LPDWORD lpSectorsPerCluster,
                                     LPDWORD lpBytesPerSector,
                                     LPDWORD lpNumberOfFreeClusters,
                                     LPDWORD lpTotalNumberOfClusters)
{
  struct statvfs st;
  if (root)
    {
      if (statvfs (os_path (root), &st) < 0)
        return FALSE;
    }
  else if (statvfs (".", &st) < 0)
    return FALSE;

  /* f_frsize が 0 を返すものがある (その場合は f_bsize を使う)。 */
  u_long unit = st.f_frsize ? (u_long)st.f_frsize : (u_long)st.f_bsize;
  if (!unit)
    unit = 512;

  /* f_bavail は root 以外が使える分。`get-disk-usage` の「空き」はこちらが
     欲しい値である (f_bfree には予約分が入っている)。 */
  uint64_t total = (uint64_t)st.f_blocks;
  uint64_t avail = (uint64_t)st.f_bavail;

  u_long spc = 1;
  while ((total > 0xffffffffULL || avail > 0xffffffffULL)
         && spc <= 0x40000000UL)
    {
      spc *= 2;
      total /= 2;
      avail /= 2;
    }

  if (lpSectorsPerCluster)      *lpSectorsPerCluster      = spc;
  if (lpBytesPerSector)         *lpBytesPerSector         = unit;
  if (lpNumberOfFreeClusters)   *lpNumberOfFreeClusters   = (DWORD)avail;
  if (lpTotalNumberOfClusters)  *lpTotalNumberOfClusters  = (DWORD)total;
  return TRUE;
}

DWORD WINAPI WINFS::internal_GetFileAttributes (LPCWSTR p)
{
  return posix_get_file_attrs (os_path (p));
}

DWORD WINAPI WINFS::GetFileAttributes (LPCWSTR p)
{
  return posix_get_file_attrs (os_path (p));
}

/* 通常のファイルを作ったときと同じモード。`open (..., 0666)` に umask が
   掛かった結果と同じものを返す。

   umask を「読む」方法が POSIX には無い (`umask` は設定して前の値を返す
   関数しか無い) ので、設定して戻す。**ファイルを作るスレッドが 1 本しか
   無い前提**である: xyzzy が別スレッドを作るのは
   src/core/ts.cc の tree-sitter の問い合わせだけで、あれはファイルを
   作らない。 */
static mode_t
default_file_mode ()
{
  mode_t m = umask (0);
  umask (m);
  return 0666 & ~m;
}

UINT WINAPI WINFS::GetTempFileName (LPCWSTR dir, LPCWSTR prefix, UINT, LPWSTR buf)
{
  char tem[PATH_MAX];
  snprintf (tem, sizeof tem, "%s/%sXXXXXX",
            os_path (dir).c_str (), prefix ? os_path (prefix).c_str () : "tmp");
  int fd = mkstemp (tem);
  if (fd < 0)
    return 0;
  /* **`mkstemp` は 0600 で作る。** 一時ファイルの中身を他人に見せないため
     なので、それ自体は正しい。ところがこの名前は
     `close_file_stream` (src/core/stream.cc) が**そのまま本来の名前へ
     rename する**ので、0600 が最終的なファイルのモードになっていた
     (issue #169)。`:if-exists :supersede` で書いたファイルが全部 0600 で、
     コンテナ (root) でバイトコンパイルした `lisp/*.lc` が**ホストのユーザから
     読めなくなる**という形で出ていた。

     モードを緩めるのは rename する直前ではなく**ここ**でよい: 名前は
     `mkstemp` が付けた予測できないもので、O_EXCL で作られている。 */
  fchmod (fd, default_file_mode ());
  close (fd);
  from_os_path (tem, buf, MAX_PATH);
  return 1;
}

BOOL WINAPI WINFS::CopyFileMode (LPCWSTR from, LPCWSTR to)
{
  struct stat st;
  if (stat (os_path (from), &st) != 0)
    return FALSE;
  return chmod (os_path (to), st.st_mode & 07777) == 0;
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
  timespec_to_filetime (ST_CTIME (st), &fd.ftCreationTime);
  timespec_to_filetime (ST_ATIME (st), &fd.ftLastAccessTime);
  timespec_to_filetime (ST_MTIME (st), &fd.ftLastWriteTime);
  // Extract filename from path
  const char *name = strrchr (p.c_str (), '/');
  from_os_path (name ? name + 1 : p.c_str (), fd.cFileName, MAX_PATH);
  return 1;
}

// ============================================================
// File calls that core makes directly rather than through WINFS.
// These were declared in src/core/platform.h as inline stubs returning
// "failed", which is why copy-file and everything that reads or writes a file
// time did nothing here.  A HANDLE outside Windows is the fd (see
// WINFS::CreateFile above), so all of them are one fstat away.
// ============================================================

BOOL
GetFileTime (HANDLE h, FILETIME *ctime, FILETIME *atime, FILETIME *mtime)
{
  struct stat st;
  if (h == INVALID_HANDLE_VALUE || fstat ((int)(intptr_t)h, &st) != 0)
    return FALSE;
  // POSIX has no creation time.  st_ctime is the inode change time, which is
  // not the same thing, but every caller here compares one file's timestamps
  // against another's rather than reading a wall clock date out of it.
  if (ctime)
    timespec_to_filetime (ST_CTIME (st), ctime);
  if (atime)
    timespec_to_filetime (ST_ATIME (st), atime);
  if (mtime)
    timespec_to_filetime (ST_MTIME (st), mtime);
  return TRUE;
}

BOOL
SetFileTime (HANDLE h, const FILETIME *, const FILETIME *atime,
             const FILETIME *mtime)
{
  // The creation time is dropped: nothing on POSIX can set it.
  if (h == INVALID_HANDLE_VALUE)
    return FALSE;
  struct timespec ts[2];
  if (atime)
    filetime_to_timespec (atime, ts[0]);
  else
    ts[0].tv_sec = 0, ts[0].tv_nsec = UTIME_OMIT;
  if (mtime)
    filetime_to_timespec (mtime, ts[1]);
  else
    ts[1].tv_sec = 0, ts[1].tv_nsec = UTIME_OMIT;
  return futimens ((int)(intptr_t)h, ts) == 0;
}

BOOL
GetFileInformationByHandle (HANDLE h, BY_HANDLE_FILE_INFORMATION *info)
{
  struct stat st;
  if (!info || h == INVALID_HANDLE_VALUE
      || fstat ((int)(intptr_t)h, &st) != 0)
    return FALSE;
  memset (info, 0, sizeof *info);
  if (S_ISDIR (st.st_mode))
    info->dwFileAttributes |= FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR))
    info->dwFileAttributes |= FILE_ATTRIBUTE_READONLY;
  timespec_to_filetime (ST_CTIME (st), &info->ftCreationTime);
  timespec_to_filetime (ST_ATIME (st), &info->ftLastAccessTime);
  timespec_to_filetime (ST_MTIME (st), &info->ftLastWriteTime);
  // The one caller (fileio.cc) asks "are these two handles the same file",
  // which on POSIX is exactly the device and inode pair.
  info->dwVolumeSerialNumber = (DWORD)st.st_dev;
  info->nFileSizeLow = (DWORD)(st.st_size & 0xffffffff);
  info->nFileSizeHigh = (DWORD)((uint64_t)st.st_size >> 32);
  info->nNumberOfLinks = (DWORD)st.st_nlink;
  info->nFileIndexLow = (DWORD)((uint64_t)st.st_ino & 0xffffffff);
  info->nFileIndexHigh = (DWORD)((uint64_t)st.st_ino >> 32);
  return TRUE;
}

static BOOL
copy_file (const char *from, const char *to, BOOL fail_if_exists)
{
  int rfd = open (from, O_RDONLY);
  if (rfd < 0)
    return FALSE;
  struct stat st;
  if (fstat (rfd, &st) != 0)
    {
      close (rfd);
      return FALSE;
    }
  int flags = O_WRONLY | O_CREAT | (fail_if_exists ? O_EXCL : O_TRUNC);
  int wfd = open (to, flags, st.st_mode & 0777);
  if (wfd < 0)
    {
      close (rfd);
      return FALSE;
    }

  char buf[64 * 1024];
  BOOL ok = TRUE;
  for (;;)
    {
      ssize_t n = read (rfd, buf, sizeof buf);
      if (n < 0)
        {
          ok = FALSE;
          break;
        }
      if (!n)
        break;
      for (ssize_t off = 0; off < n;)
        {
          ssize_t w = write (wfd, buf + off, n - off);
          if (w <= 0)
            {
              ok = FALSE;
              break;
            }
          off += w;
        }
      if (!ok)
        break;
    }

  if (ok)
    {
      // CopyFile keeps the timestamps; a backup copy that claims to have been
      // written now is not a backup of anything.
      struct timespec ts[2];
      ts[0] = ST_ATIME (st);
      ts[1] = ST_MTIME (st);
      futimens (wfd, ts);
    }

  close (rfd);
  if (close (wfd) != 0)
    ok = FALSE;
  if (!ok)
    unlink (to);
  return ok;
}

BOOL
CopyFileA (LPCSTR from, LPCSTR to, BOOL fail_if_exists)
{
  return from && to ? copy_file (from, to, fail_if_exists) : FALSE;
}

BOOL
CopyFileW (LPCWSTR from, LPCWSTR to, BOOL fail_if_exists)
{
  if (!from || !to)
    return FALSE;
  os_path f (from), t (to);
  return copy_file (f, t, fail_if_exists);
}
