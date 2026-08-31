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
  /* **ファイル名の大文字小文字を区別しないファイルシステムか。**
     Win32 は区別しない (1)、POSIX は区別する (0)。ファイル名補完がこれを見る。

     これがプラットフォームの `#ifdef` ではなくファイルシステムの seam に
     居るのは、**区別するかどうかはファイルシステムの性質であって
     フロントエンドの性質ではない**ため。GUI 版と端末版で違ってはいけない。

     厳密には Windows でも POSIX でも例外はある (macOS の既定は区別しない、
     Linux 上の一部のマウントは区別しない) が、それを本当に知るには
     パスごとに問い合わせるしか無い。ここが対象にしているのは
     「打った字を勝手に書き換えて存在しないパスを作らない」ことで、
     ビルド単位の既定で足りる。 */
  static const int case_insensitive_names;

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

  /* **FROM のモード (Windows なら属性) を TO へ写す。**

     一時ファイルへ書いてから rename で置き換える経路 (`close_file_stream`、
     `Buffer::save_buffer` の precious な経路) が使う。**置き換えた後も元の
     ファイルのモードが残る**ようにするためのもので、これが無いと
     `0755` のファイルを `:supersede` で書き直すと実行ビットが落ちる。

     `SetFileAttributes` で済まないのは、**POSIX のモードが Win32 の属性の
     ビットに収まらない**ため。`GetFileAttributes` は POSIX では
     「書けるか」を `FILE_ATTRIBUTE_READONLY` に潰すので、それを書き戻すと
     `0755` が `0644` になる。ここがファイルシステムの seam に居るのは、
     **モードの持ち方がファイルシステムの性質**だからである (vfs.h の
     `case_insensitive_names` と同じ理由)。 */
  static BOOL WINAPI CopyFileMode (LPCWSTR from, LPCWSTR to);
  static DWORD WINAPI WNetOpenEnum (DWORD dwScope, DWORD dwType, DWORD dwUsage,
                                    LPNETRESOURCEW lpNetResource, LPHANDLE lphEnum);

  static int WINAPI get_file_data (const wchar_t *, WIN32_FIND_DATAW &);
};

#endif /* _vfs_h_ */
