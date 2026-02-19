#include "stdafx.h"
#include "ed.h"
#include "dyn-handle.h"
#include "vwin32.h"

// CP932 <-> wchar_t path conversion helpers for WINFS A->W migration.
// Internal strings are always CP932; Win32 W-APIs need wchar_t*.
static inline void
cp932_to_wide_path (wchar_t *w, const char *a)
{
  MultiByteToWideChar (932, 0, a, -1, w, PATH_MAX + 1);
}

static inline void
wide_to_cp932_path (char *a, const wchar_t *w)
{
  WideCharToMultiByte (932, 0, w, -1, a, PATH_MAX + 1, 0, 0);
}

// Convert WIN32_FIND_DATAW to WIN32_FIND_DATAA (CP932 filenames)
static void
find_data_w2a (LPWIN32_FIND_DATAA a, const WIN32_FIND_DATAW *w)
{
  a->dwFileAttributes = w->dwFileAttributes;
  a->ftCreationTime = w->ftCreationTime;
  a->ftLastAccessTime = w->ftLastAccessTime;
  a->ftLastWriteTime = w->ftLastWriteTime;
  a->nFileSizeHigh = w->nFileSizeHigh;
  a->nFileSizeLow = w->nFileSizeLow;
  a->dwReserved0 = w->dwReserved0;
  a->dwReserved1 = w->dwReserved1;
  WideCharToMultiByte (932, 0, w->cFileName, -1,
                       a->cFileName, MAX_PATH, 0, 0);
  WideCharToMultiByte (932, 0, w->cAlternateFileName, -1,
                       a->cAlternateFileName, 14, 0, 0);
}

class NetPassDlg
{
  HWND hwnd;
public:
  wchar_t username[256];
  wchar_t passwd[256];
  const char *remote;

private:
  static INT_PTR CALLBACK netpass_dlgproc (HWND, UINT, WPARAM, LPARAM);
  BOOL dlgproc (UINT, WPARAM, LPARAM);
  void do_command (int, int);
  void init_dialog ();

public:
  NetPassDlg (const char *);
  int do_modal ();
};

NetPassDlg::NetPassDlg (const char *r)
     : remote (r)
{
  *username = 0;
  *passwd = 0;
}

void
NetPassDlg::do_command (int id, int code)
{
  switch (id)
    {
    case IDOK:
      GetDlgItemTextW (hwnd, IDC_USERNAME, username, 256);
      GetDlgItemTextW (hwnd, IDC_PASSWD, passwd, 256);
      /* fall thru... */
    case IDCANCEL:
      EndDialog (hwnd, id);
      break;
    }
}

void
NetPassDlg::init_dialog ()
{
  center_window (hwnd);
  set_window_icon (hwnd);
  wchar_t wremote[MAX_PATH];
  MultiByteToWideChar (932, 0, remote, -1, wremote, MAX_PATH);
  SetDlgItemTextW (hwnd, IDC_SHARE_NAME, wremote);
}

BOOL
NetPassDlg::dlgproc (UINT msg, WPARAM wparam, LPARAM lparam)
{
  switch (msg)
    {
    case WM_INITDIALOG:
      init_dialog ();
      return 1;

    case WM_COMMAND:
      do_command (LOWORD (wparam), HIWORD (wparam));
      return 1;

    default:
      return 0;
    }
}

INT_PTR CALLBACK
NetPassDlg::netpass_dlgproc (HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
  NetPassDlg *p;
  if (msg == WM_INITDIALOG)
    {
      p = (NetPassDlg *)lparam;
      SetWindowLongPtr (hwnd, DWL_USER, lparam);
      p->hwnd = hwnd;
    }
  else
    {
      p = (NetPassDlg *)GetWindowLongPtr (hwnd, DWL_USER);
      if (!p)
        return 0;
    }
  return p->dlgproc (msg, wparam, lparam);
}

int
NetPassDlg::do_modal ()
{
  return DialogBoxParam (app.hinst, MAKEINTRESOURCE (IDD_NETPASSWD),
                         get_active_window (), netpass_dlgproc, LPARAM (this)) == IDOK;
}

#define WINFS_CALL1(TYPE, FAILED, PATH, FN) \
  WINFS_CALL (TYPE, FAILED, askpass (PATH), FN)
#define WINFS_CALL2(TYPE, FAILED, PATH1, PATH2, FN) \
  WINFS_CALL (TYPE, FAILED, askpass (PATH1, PATH2), FN)
#define WINFS_CALL(TYPE, FAILED, ASKPASS, FN) \
  { TYPE r = ::FN; \
    if (r == (FAILED) && ASKPASS) \
      r = ::FN; \
    return r; }

#define WINFS_MAPSL(PATH) \
  { char *__path = (char *)alloca (strlen (PATH) + 1); \
    strcpy (__path, (PATH)); \
    map_sl_to_backsl (__path); \
    (PATH) = __path; }

static const char *
skip_share (const char *path, int noshare_ok)
{
  const char *p = path;
  if ((*p != '/' && *p != '\\')
      || (p[1] != '/' && p[1] != '\\'))
    return 0;
  p = find_slash (p + 2);
  if (p)
    {
      const char *e = find_slash (p + 1);
      return e ? e : p + strlen (p);
    }
  return noshare_ok ? path + strlen (path) : 0;
}

static int
try_connect (char *remote, int e)
{
  wchar_t wremote[MAX_PATH];
  MultiByteToWideChar (932, 0, remote, -1, wremote, MAX_PATH);

  NETRESOURCEW nr;
  nr.dwType = RESOURCETYPE_DISK;
  nr.lpLocalName = 0;
  nr.lpRemoteName = wremote;
  nr.lpProvider = 0;

  if (e == ERROR_ACCESS_DENIED
      && WNetAddConnection2W (&nr, 0, 0, 0) == NO_ERROR)
    return 1;

  while (1)
    {
      NetPassDlg d (remote);
      if (!d.do_modal ())
        return 0;

      switch (WNetAddConnection2W (&nr, d.passwd, d.username, 0))
        {
        case NO_ERROR:
          return 1;

        case ERROR_INVALID_PASSWORD:
        case ERROR_LOGON_FAILURE:
        case ERROR_ACCESS_DENIED:
          break;

        default:
          return 0;
        }
    }
}

static int
askpass1 (const char *path, int noshare_ok)
{
  if (!path)
    return 0;

  int e = GetLastError ();
  switch (e)
    {
    default:
      return 0;

    case ERROR_ACCESS_DENIED:
    case ERROR_INVALID_PASSWORD:
    case ERROR_LOGON_FAILURE:
      break;
    }

  const char *root = skip_share (path, noshare_ok);
  if (!root)
    return 0;
  int l = root - path;
  char *remote = (char *)alloca (l + 1);
  memcpy (remote, path, l);
  remote[l] = 0;
  map_sl_to_backsl (remote);
  if (!stricmp (WINFS::wfs_share_cache, remote))
    return 0;
  if (try_connect (remote, e))
    {
      *WINFS::wfs_share_cache = 0;
      return 1;
    }
  strcpy (WINFS::wfs_share_cache, remote);
  SetLastError (e);
  return 0;
}

static inline int
askpass (const char *path)
{
  return askpass1 (path, 0);
}

static inline int
askpass_noshare (const char *path)
{
  return askpass1 (path, 1);
}

static inline int
askpass (const char *path1, const char *path2)
{
  return askpass1 (path1, 0) || askpass1 (path2, 0);
}

char WINFS::wfs_share_cache[MAX_PATH * 2];

const WINFS::GETDISKFREESPACEEX WINFS::GetDiskFreeSpaceEx =
  (WINFS::GETDISKFREESPACEEX)GetProcAddress (GetModuleHandleW (L"KERNEL32"),
                                             "GetDiskFreeSpaceExW");

BOOL WINAPI
WINFS::CreateDirectory (LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpPathName);
  WINFS_CALL1 (BOOL, FALSE, lpPathName, CreateDirectoryW (wpath, lpSecurityAttributes));
}

HANDLE WINAPI
WINFS::CreateFile (LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                   LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition,
                   DWORD dwFlagsAndAttributes, HANDLE hTemplateFile)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);
  HANDLE r = ::CreateFileW (wpath, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
                            dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
  if (r != INVALID_HANDLE_VALUE)
    return r;
  if (!sysdep.WinNTp () || !(dwFlagsAndAttributes & FILE_FLAG_BACKUP_SEMANTICS))
    {
      int e = GetLastError ();
      if (e == ERROR_ACCESS_DENIED)
        {
          DWORD a = ::GetFileAttributesW (wpath);
          SetLastError (e);
          if (a != -1 && a & FILE_ATTRIBUTE_DIRECTORY)
            return r;
        }
    }
  if (askpass (lpFileName))
    r = ::CreateFileW (wpath, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
                       dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
  return r;
}

BOOL WINAPI
WINFS::DeleteFile (LPCSTR lpFileName)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);
  WINFS_CALL1 (BOOL, FALSE, lpFileName, DeleteFileW (wpath));
}

HANDLE WINAPI
WINFS::FindFirstFile (LPCSTR lpFileName, LPWIN32_FIND_DATAA lpFindFileData)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);
  WIN32_FIND_DATAW wfd;
  HANDLE h = ::FindFirstFileW (wpath, &wfd);
  if (h == INVALID_HANDLE_VALUE && askpass (lpFileName))
    h = ::FindFirstFileW (wpath, &wfd);
  if (h != INVALID_HANDLE_VALUE)
    find_data_w2a (lpFindFileData, &wfd);
  return h;
}

BOOL WINAPI
WINFS::FindNextFile (HANDLE hFindFile, LPWIN32_FIND_DATAA lpFindFileData)
{
  WIN32_FIND_DATAW wfd;
  *wfd.cFileName = 0;
  if (::FindNextFileW (hFindFile, &wfd)
      || (GetLastError () == ERROR_MORE_DATA && *wfd.cFileName))
    {
      find_data_w2a (lpFindFileData, &wfd);
      return TRUE;
    }
  *lpFindFileData->cFileName = 0;
  return FALSE;
}

// Win9x FAT32 VxD interface — dead code on NT/ARM64, kept for compatibility
static BOOL WINAPI
GetDiskFreeSpaceFAT32 (LPCSTR lpRootPathName, LPDWORD lpSectorsPerCluster,
                       LPDWORD lpBytesPerSector, LPDWORD lpNumberOfFreeClusters,
                       LPDWORD lpTotalNumberOfClusters)
{
  char buf[PATH_MAX + 1];
  if (!lpRootPathName)
    {
      wchar_t wbuf[PATH_MAX + 1];
      if (!GetCurrentDirectoryW (PATH_MAX + 1, wbuf))
        return 0;
      wide_to_cp932_path (buf, wbuf);
      lpRootPathName = root_path_name (buf, buf);
    }

  dyn_handle hvwin32 (CreateFileW (L"\\\\.\\vwin32", 0, 0, 0, 0,
                                   FILE_FLAG_DELETE_ON_CLOSE, 0));
  if (!hvwin32.valid ())
    return 0;

  ExtGetDskFreSpcStruc dfs = {0};
  DIOC_REGISTERS regs = {0};
  regs.reg_EAX = 0x7303;
  regs.reg_ECX = sizeof dfs;
  regs.reg_EDX = DWORD (lpRootPathName);
  regs.reg_EDI = DWORD (&dfs);

  DWORD nbytes;
  if (!DeviceIoControl (hvwin32, VWIN32_DIOC_DOS_DRIVEINFO,
                        &regs, sizeof regs, &regs, sizeof regs,
                        &nbytes, 0)
      || regs.reg_Flags & X86_CARRY_FLAG)
    return 0;

  *lpSectorsPerCluster = dfs.SectorsPerCluster;
  *lpBytesPerSector = dfs.BytesPerSector;
  *lpNumberOfFreeClusters = dfs.AvailableClusters;
  *lpTotalNumberOfClusters = dfs.TotalClusters;

  return 1;
}

BOOL WINAPI
WINFS::GetDiskFreeSpace (LPCSTR lpRootPathName, LPDWORD lpSectorsPerCluster,
                         LPDWORD lpBytesPerSector, LPDWORD lpNumberOfFreeClusters,
                         LPDWORD lpTotalNumberOfClusters)
{
  wchar_t wpath[PATH_MAX + 1];
  LPCWSTR wRootPath = 0;
  if (lpRootPathName)
    {
      cp932_to_wide_path (wpath, lpRootPathName);
      wRootPath = wpath;
    }

  BOOL r = ::GetDiskFreeSpaceW (wRootPath, lpSectorsPerCluster, lpBytesPerSector,
                                lpNumberOfFreeClusters, lpTotalNumberOfClusters);
  if (!r)
    {
      if (GetLastError () == ERROR_NOT_SUPPORTED)
        {
          *lpSectorsPerCluster = 1;
          *lpBytesPerSector = 4096;
        }
      else
        {
          if (!askpass (lpRootPathName))
            return 0;
          r = ::GetDiskFreeSpaceW (wRootPath, lpSectorsPerCluster, lpBytesPerSector,
                                   lpNumberOfFreeClusters, lpTotalNumberOfClusters);
          if (!r)
            return 0;
        }
    }

  if (GetDiskFreeSpaceEx)
    {
      if (!sysdep.WinNTp ()
          && GetDiskFreeSpaceFAT32 (lpRootPathName, lpSectorsPerCluster,
                                    lpBytesPerSector, lpNumberOfFreeClusters,
                                    lpTotalNumberOfClusters))
        return 1;

      uint64_t FreeBytesAvailableToCaller;
      uint64_t TotalNumberOfBytes;
      uint64_t TotalNumberOfFreeBytes;
      if (GetDiskFreeSpaceEx (wRootPath,
                              (PULARGE_INTEGER)&FreeBytesAvailableToCaller,
                              (PULARGE_INTEGER)&TotalNumberOfBytes,
                              (PULARGE_INTEGER)&TotalNumberOfFreeBytes))
        {
          DWORD blk = *lpSectorsPerCluster * *lpBytesPerSector;
          if (!blk)
            blk = 512;
          *lpTotalNumberOfClusters = DWORD (TotalNumberOfBytes / blk);
          *lpNumberOfFreeClusters = DWORD (TotalNumberOfFreeBytes / blk);
          r = 1;
        }
    }

  return r;
}

DWORD WINAPI
WINFS::internal_GetFileAttributes (LPCSTR lpFileName)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);
  WINFS_CALL1 (DWORD, -1, lpFileName, GetFileAttributesW (wpath));
}

DWORD WINAPI
WINFS::GetFileAttributes (LPCSTR lpFileName)
{
  DWORD attr = internal_GetFileAttributes (lpFileName);
  if (attr == DWORD (-1) && GetLastError () != ERROR_INVALID_NAME)
    {
      WIN32_FIND_DATAA fd;
      if (get_file_data (lpFileName, fd))
        attr = fd.dwFileAttributes;
    }
  return attr;
}

UINT WINAPI
WINFS::GetTempFileName (LPCSTR lpPathName, LPCSTR lpPrefixString, UINT uUnique, LPSTR lpTempFileName)
{
  wchar_t wpath[PATH_MAX + 1], wprefix[MAX_PATH];
  cp932_to_wide_path (wpath, lpPathName);
  MultiByteToWideChar (932, 0, lpPrefixString, -1, wprefix, MAX_PATH);
  wchar_t wtemp[PATH_MAX + 1];
  UINT r = ::GetTempFileNameW (wpath, wprefix, uUnique, wtemp);
  if (!r && askpass (lpPathName))
    r = ::GetTempFileNameW (wpath, wprefix, uUnique, wtemp);
  if (r)
    wide_to_cp932_path (lpTempFileName, wtemp);
  return r;
}

BOOL WINAPI
WINFS::GetVolumeInformation (LPCSTR lpRootPathName, LPSTR lpVolumeNameBuffer,
                             DWORD nVolumeNameSize, LPDWORD lpVolumeSerialNumber,
                             LPDWORD lpMaximumComponentLength, LPDWORD lpFileSystemFlags,
                             LPSTR lpFileSystemNameBuffer, DWORD nFileSystemNameSize)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpRootPathName);
  wchar_t wvol[MAX_PATH + 1], wfs[MAX_PATH + 1];
  BOOL r = ::GetVolumeInformationW (wpath,
    lpVolumeNameBuffer ? wvol : 0, lpVolumeNameBuffer ? MAX_PATH + 1 : 0,
    lpVolumeSerialNumber, lpMaximumComponentLength, lpFileSystemFlags,
    lpFileSystemNameBuffer ? wfs : 0, lpFileSystemNameBuffer ? MAX_PATH + 1 : 0);
  if (!r && askpass (lpRootPathName))
    r = ::GetVolumeInformationW (wpath,
      lpVolumeNameBuffer ? wvol : 0, lpVolumeNameBuffer ? MAX_PATH + 1 : 0,
      lpVolumeSerialNumber, lpMaximumComponentLength, lpFileSystemFlags,
      lpFileSystemNameBuffer ? wfs : 0, lpFileSystemNameBuffer ? MAX_PATH + 1 : 0);
  if (r)
    {
      if (lpVolumeNameBuffer)
        WideCharToMultiByte (932, 0, wvol, -1, lpVolumeNameBuffer, nVolumeNameSize, 0, 0);
      if (lpFileSystemNameBuffer)
        WideCharToMultiByte (932, 0, wfs, -1, lpFileSystemNameBuffer, nFileSystemNameSize, 0, 0);
    }
  return r;
}

HMODULE WINAPI
WINFS::LoadLibrary (LPCSTR lpLibFileName)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpLibFileName);
  WINFS_CALL1 (HMODULE, NULL, lpLibFileName, LoadLibraryW (wpath));
}

static BOOL
move_file (LPCSTR lpExistingFileName, LPCSTR lpNewFileName)
{
  wchar_t wexist[PATH_MAX + 1], wnew[PATH_MAX + 1];
  cp932_to_wide_path (wexist, lpExistingFileName);
  cp932_to_wide_path (wnew, lpNewFileName);
  WINFS_CALL2 (BOOL, FALSE, lpExistingFileName, lpNewFileName,
               MoveFileW (wexist, wnew));
}

BOOL WINAPI
WINFS::MoveFile (LPCSTR lpExistingFileName, LPCSTR lpNewFileName)
{
  for (int retry = 0;; retry++)
    {
      if (move_file (lpExistingFileName, lpNewFileName))
        return 1;
      if (retry >= 3)
        return 0;
      Sleep (50);
    }
}

BOOL WINAPI
WINFS::RemoveDirectory (LPCSTR lpPathName)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpPathName);
  WINFS_CALL1 (BOOL, FALSE, lpPathName, RemoveDirectoryW (wpath));
}

BOOL WINAPI
WINFS::SetFileAttributes (LPCSTR lpFileName, DWORD dwFileAttributes)
{
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);
  WINFS_CALL1 (BOOL, FALSE, lpFileName,
               SetFileAttributesW (wpath, dwFileAttributes));
}

DWORD WINAPI
WINFS::internal_GetFullPathName (LPCSTR lpFileName, DWORD nBufferLength,
                                 LPSTR lpBuffer, LPSTR *lpFilePart)
{
  WINFS_MAPSL (lpFileName);
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpFileName);

  wchar_t wbuf[PATH_MAX + 1];
  LPWSTR wFilePart = 0;
  DWORD r = ::GetFullPathNameW (wpath, PATH_MAX + 1, wbuf, lpFilePart ? &wFilePart : 0);
  if (!r && askpass (lpFileName))
    r = ::GetFullPathNameW (wpath, PATH_MAX + 1, wbuf, lpFilePart ? &wFilePart : 0);
  if (!r)
    return 0;

  int len = WideCharToMultiByte (932, 0, wbuf, -1, lpBuffer, nBufferLength, 0, 0);
  if (len <= 0)
    return nBufferLength;
  len--;

  if (lpFilePart)
    {
      if (wFilePart)
        {
          int prefixWLen = (int)(wFilePart - wbuf);
          char tmp[PATH_MAX + 1];
          int prefixLen = WideCharToMultiByte (932, 0, wbuf, prefixWLen, tmp, PATH_MAX + 1, 0, 0);
          *lpFilePart = lpBuffer + prefixLen;
        }
      else
        *lpFilePart = 0;
    }

  return (DWORD)len;
}

BOOL WINAPI
WINFS::SetCurrentDirectory (LPCSTR lpPathName)
{
  WINFS_MAPSL (lpPathName);
  wchar_t wpath[PATH_MAX + 1];
  cp932_to_wide_path (wpath, lpPathName);
  WINFS_CALL1 (BOOL, FALSE, lpPathName, SetCurrentDirectoryW (wpath));
}

DWORD WINAPI
WINFS::GetFullPathName (LPCSTR path, DWORD size, LPSTR buf, LPSTR *name)
{
  DWORD l = internal_GetFullPathName (path, size, buf, name);
  if (!l || l >= size)
    return l;
  if (!dir_separator_p (*path) || !dir_separator_p (path[1]))
    return l;
  if (alpha_char_p (*buf & 0xff) && buf[1] == ':'
      && dir_separator_p (buf[2]) && dir_separator_p (buf[3]))
    {
      strcpy (buf, buf + 2);
      l -= 2;
      if (name && *name >= buf + 2)
        *name -= 2;
    }
  return l;
}

DWORD WINAPI
WINFS::WNetOpenEnum (DWORD dwScope, DWORD dwType, DWORD dwUsage,
                     LPNETRESOURCEA lpNetResource, LPHANDLE lphEnum)
{
  if (!lpNetResource)
    return ::WNetOpenEnumW (dwScope, dwType, dwUsage, 0, lphEnum);

  NETRESOURCEW nrw;
  nrw.dwScope = lpNetResource->dwScope;
  nrw.dwType = lpNetResource->dwType;
  nrw.dwDisplayType = lpNetResource->dwDisplayType;
  nrw.dwUsage = lpNetResource->dwUsage;

  wchar_t wLocal[MAX_PATH], wRemote[MAX_PATH], wComment[MAX_PATH], wProvider[MAX_PATH];
  nrw.lpLocalName = lpNetResource->lpLocalName
    ? (MultiByteToWideChar (932, 0, lpNetResource->lpLocalName, -1, wLocal, MAX_PATH), wLocal) : 0;
  nrw.lpRemoteName = lpNetResource->lpRemoteName
    ? (MultiByteToWideChar (932, 0, lpNetResource->lpRemoteName, -1, wRemote, MAX_PATH), wRemote) : 0;
  nrw.lpComment = lpNetResource->lpComment
    ? (MultiByteToWideChar (932, 0, lpNetResource->lpComment, -1, wComment, MAX_PATH), wComment) : 0;
  nrw.lpProvider = lpNetResource->lpProvider
    ? (MultiByteToWideChar (932, 0, lpNetResource->lpProvider, -1, wProvider, MAX_PATH), wProvider) : 0;

  DWORD r = ::WNetOpenEnumW (dwScope, dwType, dwUsage, &nrw, lphEnum);
  if (r != NO_ERROR && askpass_noshare (lpNetResource->lpRemoteName))
    r = ::WNetOpenEnumW (dwScope, dwType, dwUsage, &nrw, lphEnum);
  return r;
}

int WINAPI
WINFS::get_file_data (const char *path, WIN32_FIND_DATAA &fd)
{
  HANDLE h = FindFirstFile (path, &fd);
  if (h == INVALID_HANDLE_VALUE)
    return 0;
  FindClose (h);
  return 1;
}
