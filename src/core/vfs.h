#ifndef _vfs_h_
#define _vfs_h_

/* Filesystem entry points. Paths are UTF-16 (wchar_t) end to end: the
   internal string is ucs4_t, Win32 wants UTF-16, and nothing in between
   needs a byte encoding. Going through CP932 here used to turn every
   character outside that code page into '?', which the filesystem then
   rejected as an invalid name. */

class WINFS
{
protected:
  typedef BOOL (WINAPI *GETDISKFREESPACEEX)(LPCWSTR, PULARGE_INTEGER,
                                            PULARGE_INTEGER, PULARGE_INTEGER);
  static const GETDISKFREESPACEEX GetDiskFreeSpaceEx;

  static DWORD WINAPI internal_GetFullPathName (LPCWSTR lpFileName, DWORD nBufferLength,
                                                LPWSTR lpBuffer, LPWSTR *lpFilePart);
  static DWORD WINAPI internal_GetFileAttributes (LPCWSTR lpFileName);
public:
  static wchar_t wfs_share_cache[MAX_PATH * 2];

  static void clear_share_cache () {*wfs_share_cache = 0;}

  static BOOL WINAPI CreateDirectory (LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  static HANDLE WINAPI CreateFile (LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                                   LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition,
                                   DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
  static BOOL WINAPI DeleteFile (LPCWSTR lpFileName);
  static HANDLE WINAPI FindFirstFile (LPCWSTR lpFileName, LPWIN32_FIND_DATAW lpFindFileData);
  static BOOL WINAPI FindNextFile (HANDLE hFindFile, LPWIN32_FIND_DATAW lpFindFileData);
  static BOOL WINAPI GetDiskFreeSpace (LPCWSTR lpRootPathName, LPDWORD lpSectorsPerCluster,
                                       LPDWORD lpBytesPerSector, LPDWORD lpNumberOfFreeClusters,
                                       LPDWORD lpTotalNumberOfClusters);
  static DWORD WINAPI GetFileAttributes (LPCWSTR lpFileName);
  static DWORD WINAPI GetFullPathName (LPCWSTR lpFileName, DWORD nBufferLength, LPWSTR lpBuffer, LPWSTR *lpFilePart);
  static UINT WINAPI GetTempFileName (LPCWSTR lpPathName, LPCWSTR lpPrefixString, UINT uUnique, LPWSTR lpTempFileName);
  static BOOL WINAPI GetVolumeInformation (LPCWSTR lpRootPathName, LPWSTR lpVolumeNameBuffer,
                                           DWORD nVolumeNameSize, LPDWORD lpVolumeSerialNumber,
                                           LPDWORD lpMaximumComponentLength, LPDWORD lpFileSystemFlags,
                                           LPWSTR lpFileSystemNameBuffer, DWORD nFileSystemNameSize);
  static HMODULE WINAPI LoadLibrary (LPCWSTR lpLibFileName);
  static BOOL WINAPI MoveFile (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName);
  static BOOL WINAPI RemoveDirectory (LPCWSTR lpPathName);
  static BOOL WINAPI SetCurrentDirectory (LPCWSTR lpPathName);
  static BOOL WINAPI SetFileAttributes (LPCWSTR lpFileName, DWORD dwFileAttributes);
  static DWORD WINAPI WNetOpenEnum (DWORD dwScope, DWORD dwType, DWORD dwUsage,
                                    LPNETRESOURCEW lpNetResource, LPHANDLE lphEnum);

  static int WINAPI get_file_data (const wchar_t *, WIN32_FIND_DATAW &);
};

#endif /* _vfs_h_ */
