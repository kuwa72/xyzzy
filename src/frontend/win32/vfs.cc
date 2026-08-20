#include "stdafx.h"
#include "ed.h"
#include "dyn-handle.h"
#include "vwin32.h"

class NetPassDlg
{
  HWND hwnd;
public:
  wchar_t username[256];
  wchar_t passwd[256];
  const wchar_t *remote;

private:
  static INT_PTR CALLBACK netpass_dlgproc (HWND, UINT, WPARAM, LPARAM);
  BOOL dlgproc (UINT, WPARAM, LPARAM);
  void do_command (int, int);
  void init_dialog ();

public:
  NetPassDlg (const wchar_t *);
  int do_modal ();
};

NetPassDlg::NetPassDlg (const wchar_t *r)
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
  SetDlgItemTextW (hwnd, IDC_SHARE_NAME, remote);
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
  { wchar_t *__path = (wchar_t *)alloca ((wcslen (PATH) + 1) * sizeof (wchar_t)); \
    wcscpy (__path, (PATH)); \
    map_sl_to_backsl (__path, int (wcslen (__path))); \
    (PATH) = __path; }

static const wchar_t *
skip_share (const wchar_t *path, int noshare_ok)
{
  const wchar_t *p = path;
  if ((*p != '/' && *p != '\\')
      || (p[1] != '/' && p[1] != '\\'))
    return 0;
  p = find_slash_w (p + 2);
  if (p)
    {
      const wchar_t *e = find_slash_w (p + 1);
      return e ? e : p + wcslen (p);
    }
  return noshare_ok ? path + wcslen (path) : 0;
}

static int
try_connect (wchar_t *remote, int e)
{
  NETRESOURCEW nr;
  nr.dwType = RESOURCETYPE_DISK;
  nr.lpLocalName = 0;
  nr.lpRemoteName = remote;
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
askpass1 (const wchar_t *path, int noshare_ok)
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

  const wchar_t *root = skip_share (path, noshare_ok);
  if (!root)
    return 0;
  int l = root - path;
  wchar_t *remote = (wchar_t *)alloca ((l + 1) * sizeof (wchar_t));
  wmemcpy (remote, path, l);
  remote[l] = 0;
  map_sl_to_backsl (remote, l);
  if (!wcsicmp (WINFS::wfs_share_cache, remote))
    return 0;
  if (try_connect (remote, e))
    {
      *WINFS::wfs_share_cache = 0;
      return 1;
    }
  wcscpy (WINFS::wfs_share_cache, remote);
  SetLastError (e);
  return 0;
}

static inline int
askpass (const wchar_t *path)
{
  return askpass1 (path, 0);
}

static inline int
askpass_noshare (const wchar_t *path)
{
  return askpass1 (path, 1);
}

static inline int
askpass (const wchar_t *path1, const wchar_t *path2)
{
  return askpass1 (path1, 0) || askpass1 (path2, 0);
}

wchar_t WINFS::wfs_share_cache[MAX_PATH * 2];

const WINFS::GETDISKFREESPACEEX WINFS::GetDiskFreeSpaceEx =
  (WINFS::GETDISKFREESPACEEX)GetProcAddress (GetModuleHandleW (L"KERNEL32"),
                                             "GetDiskFreeSpaceExW");

BOOL WINAPI
WINFS::CreateDirectory (LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes)
{
  WINFS_CALL1 (BOOL, FALSE, lpPathName, CreateDirectoryW (lpPathName, lpSecurityAttributes));
}

HANDLE WINAPI
WINFS::CreateFile (LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                   LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition,
                   DWORD dwFlagsAndAttributes, HANDLE hTemplateFile)
{
  HANDLE r = ::CreateFileW (lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
                            dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
  if (r != INVALID_HANDLE_VALUE)
    return r;
  if (!sysdep.WinNTp () || !(dwFlagsAndAttributes & FILE_FLAG_BACKUP_SEMANTICS))
    {
      int e = GetLastError ();
      if (e == ERROR_ACCESS_DENIED)
        {
          DWORD a = ::GetFileAttributesW (lpFileName);
          SetLastError (e);
          if (a != -1 && a & FILE_ATTRIBUTE_DIRECTORY)
            return r;
        }
    }
  if (askpass (lpFileName))
    r = ::CreateFileW (lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes,
                       dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
  return r;
}

BOOL WINAPI
WINFS::DeleteFile (LPCWSTR lpFileName)
{
  WINFS_CALL1 (BOOL, FALSE, lpFileName, DeleteFileW (lpFileName));
}

HANDLE WINAPI
WINFS::FindFirstFile (LPCWSTR lpFileName, LPWIN32_FIND_DATAW lpFindFileData)
{
  HANDLE h = ::FindFirstFileW (lpFileName, lpFindFileData);
  if (h == INVALID_HANDLE_VALUE && askpass (lpFileName))
    h = ::FindFirstFileW (lpFileName, lpFindFileData);
  return h;
}

BOOL WINAPI
WINFS::FindNextFile (HANDLE hFindFile, LPWIN32_FIND_DATAW lpFindFileData)
{
  *lpFindFileData->cFileName = 0;
  if (::FindNextFileW (hFindFile, lpFindFileData)
      || (GetLastError () == ERROR_MORE_DATA && *lpFindFileData->cFileName))
    return TRUE;
  *lpFindFileData->cFileName = 0;
  return FALSE;
}

// Win9x FAT32 VxD interface — dead code on NT/ARM64, kept for compatibility
static BOOL WINAPI
GetDiskFreeSpaceFAT32 (LPCWSTR lpRootPathName, LPDWORD lpSectorsPerCluster,
                       LPDWORD lpBytesPerSector, LPDWORD lpNumberOfFreeClusters,
                       LPDWORD lpTotalNumberOfClusters)
{
  wchar_t buf[PATH_MAX + 1];
  if (!lpRootPathName)
    {
      if (!GetCurrentDirectoryW (PATH_MAX + 1, buf))
        return 0;
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
WINFS::GetDiskFreeSpace (LPCWSTR lpRootPathName, LPDWORD lpSectorsPerCluster,
                         LPDWORD lpBytesPerSector, LPDWORD lpNumberOfFreeClusters,
                         LPDWORD lpTotalNumberOfClusters)
{
  LPCWSTR wRootPath = lpRootPathName;

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
WINFS::internal_GetFileAttributes (LPCWSTR lpFileName)
{
  WINFS_CALL1 (DWORD, -1, lpFileName, GetFileAttributesW (lpFileName));
}

DWORD WINAPI
WINFS::GetFileAttributes (LPCWSTR lpFileName)
{
  DWORD attr = internal_GetFileAttributes (lpFileName);
  if (attr == DWORD (-1) && GetLastError () != ERROR_INVALID_NAME)
    {
      WIN32_FIND_DATAW fd;
      if (get_file_data (lpFileName, fd))
        attr = fd.dwFileAttributes;
    }
  return attr;
}

UINT WINAPI
WINFS::GetTempFileName (LPCWSTR lpPathName, LPCWSTR lpPrefixString, UINT uUnique, LPWSTR lpTempFileName)
{
  UINT r = ::GetTempFileNameW (lpPathName, lpPrefixString, uUnique, lpTempFileName);
  if (!r && askpass (lpPathName))
    r = ::GetTempFileNameW (lpPathName, lpPrefixString, uUnique, lpTempFileName);
  return r;
}

BOOL WINAPI
WINFS::GetVolumeInformation (LPCWSTR lpRootPathName, LPWSTR lpVolumeNameBuffer,
                             DWORD nVolumeNameSize, LPDWORD lpVolumeSerialNumber,
                             LPDWORD lpMaximumComponentLength, LPDWORD lpFileSystemFlags,
                             LPWSTR lpFileSystemNameBuffer, DWORD nFileSystemNameSize)
{
  WINFS_CALL1 (BOOL, FALSE, lpRootPathName,
               GetVolumeInformationW (lpRootPathName,
                 lpVolumeNameBuffer, nVolumeNameSize, lpVolumeSerialNumber,
                 lpMaximumComponentLength, lpFileSystemFlags,
                 lpFileSystemNameBuffer, nFileSystemNameSize));
}

HMODULE WINAPI
WINFS::LoadLibrary (LPCWSTR lpLibFileName)
{
  WINFS_CALL1 (HMODULE, NULL, lpLibFileName, LoadLibraryW (lpLibFileName));
}

static BOOL
move_file (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName)
{
  WINFS_CALL2 (BOOL, FALSE, lpExistingFileName, lpNewFileName,
               MoveFileW (lpExistingFileName, lpNewFileName));
}

BOOL WINAPI
WINFS::MoveFile (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName)
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
WINFS::RemoveDirectory (LPCWSTR lpPathName)
{
  WINFS_CALL1 (BOOL, FALSE, lpPathName, RemoveDirectoryW (lpPathName));
}

BOOL WINAPI
WINFS::SetFileAttributes (LPCWSTR lpFileName, DWORD dwFileAttributes)
{
  WINFS_CALL1 (BOOL, FALSE, lpFileName,
               SetFileAttributesW (lpFileName, dwFileAttributes));
}

DWORD WINAPI
WINFS::internal_GetFullPathName (LPCWSTR lpFileName, DWORD nBufferLength,
                                 LPWSTR lpBuffer, LPWSTR *lpFilePart)
{
  WINFS_MAPSL (lpFileName);
  WINFS_CALL1 (DWORD, 0, lpFileName,
               GetFullPathNameW (lpFileName, nBufferLength, lpBuffer, lpFilePart));
}

BOOL WINAPI
WINFS::SetCurrentDirectory (LPCWSTR lpPathName)
{
  WINFS_MAPSL (lpPathName);
  WINFS_CALL1 (BOOL, FALSE, lpPathName, SetCurrentDirectoryW (lpPathName));
}

DWORD WINAPI
WINFS::GetFullPathName (LPCWSTR path, DWORD size, LPWSTR buf, LPWSTR *name)
{
  DWORD l = internal_GetFullPathName (path, size, buf, name);
  if (!l || l >= size)
    return l;
  if (!dir_separator_p (*path) || !dir_separator_p (path[1]))
    return l;
  if (alpha_char_p (*buf) && buf[1] == ':'
      && dir_separator_p (buf[2]) && dir_separator_p (buf[3]))
    {
      wcscpy (buf, buf + 2);
      l -= 2;
      if (name && *name >= buf + 2)
        *name -= 2;
    }
  return l;
}

DWORD WINAPI
WINFS::WNetOpenEnum (DWORD dwScope, DWORD dwType, DWORD dwUsage,
                     LPNETRESOURCEW lpNetResource, LPHANDLE lphEnum)
{
  if (!lpNetResource)
    return ::WNetOpenEnumW (dwScope, dwType, dwUsage, 0, lphEnum);

  DWORD r = ::WNetOpenEnumW (dwScope, dwType, dwUsage, lpNetResource, lphEnum);
  if (r != NO_ERROR && askpass_noshare (lpNetResource->lpRemoteName))
    r = ::WNetOpenEnumW (dwScope, dwType, dwUsage, lpNetResource, lphEnum);
  return r;
}

int WINAPI
WINFS::get_file_data (const wchar_t *path, WIN32_FIND_DATAW &fd)
{
  HANDLE h = FindFirstFile (path, &fd);
  if (h == INVALID_HANDLE_VALUE)
    return 0;
  FindClose (h);
  return 1;
}
