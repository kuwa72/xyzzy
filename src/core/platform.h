// platform.h - Platform abstraction layer
// On _WIN32: just includes <windows.h> and related headers.
// On other platforms: provides type definitions and stubs.

#ifndef _platform_h_
#define _platform_h_

#ifdef _WIN32

// Windows platform - use native headers
# include <windows.h>
# include <winreg.h>
# include <commctrl.h>

#else // !_WIN32

// ============================================================
// Non-Windows platform abstraction
// ============================================================

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <wchar.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>
#include <errno.h>
#include <limits.h>

// ------------------------------------------------------------
// Calling conventions (no-op on non-Windows)
// ------------------------------------------------------------
#define WINAPI
#define CALLBACK
#define APIENTRY
#define DECLSPEC_IMPORT
#define DECLSPEC_EXPORT
#define PASCAL
#define __cdecl
#define __stdcall
#define CDECL
#define FAR
#define NEAR

// ------------------------------------------------------------
// Basic scalar types
// ------------------------------------------------------------
typedef int BOOL;
typedef uint8_t BYTE;
typedef unsigned char byte;  // from rpcndr.h on Windows
typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef int32_t LONG;
typedef uint32_t ULONG;
typedef int INT;
typedef unsigned int UINT;
typedef int64_t LONGLONG;
typedef uint64_t ULONGLONG;
typedef intptr_t INT_PTR;
typedef uintptr_t UINT_PTR;
typedef intptr_t LONG_PTR;
typedef uintptr_t ULONG_PTR;
typedef ULONG_PTR DWORD_PTR;
typedef UINT_PTR WPARAM;
typedef LONG_PTR LPARAM;
typedef LONG_PTR LRESULT;

#ifndef TRUE
# define TRUE 1
#endif
#ifndef FALSE
# define FALSE 0
#endif

// ------------------------------------------------------------
// Handle types (opaque pointers on non-Windows)
// ------------------------------------------------------------
typedef void *HANDLE;
typedef void *HWND;
typedef void *HMENU;
typedef void *HFONT;
typedef void *HCURSOR;
typedef void *HGDIOBJ;
typedef void *HINSTANCE;
typedef void *HMODULE;
typedef void *HKEY;
typedef void *HCONV;
typedef void *HSZ;
typedef void *HDDEDATA;
typedef void *HMONITOR;
typedef void *HIMAGELIST;
typedef void *HCRYPTPROV;
typedef void *HDC;
typedef void *HBITMAP;
typedef void *HBRUSH;
typedef void *HPEN;
typedef void *HRGN;
typedef void *HICON;
typedef void *HIMC;
typedef void *HKL;
typedef long HRESULT;
typedef void *LPHANDLE;
typedef void *PVOID;
typedef WORD ATOM;

typedef unsigned short USHORT;
typedef unsigned short WCHAR;
typedef WORD LANGID;
typedef void *HGLOBAL;
typedef void *HHOOK;
typedef void *HDWP;
typedef LRESULT (CALLBACK *WNDPROC)(HWND, UINT, WPARAM, LPARAM);

// COM/OLE stubs
#define interface struct
#define STDMETHOD(m) virtual long m
#define STDMETHOD_(t,m) virtual t m
#define REFIID void*
typedef struct _GUID { DWORD Data1; WORD Data2; WORD Data3; BYTE Data4[8]; } GUID, IID, CLSID;
struct IUnknown { virtual ~IUnknown() {} virtual ULONG Release() { return 0; } virtual ULONG AddRef() { return 0; } };
struct IDispatch : IUnknown {};
struct ITypeInfo {};
struct IConnectionPoint {};
struct IActiveIMMApp {};
struct IActiveIMMMessagePumpOwner {};
struct IEnumVARIANT { virtual ~IEnumVARIANT() {} void Release() {} };
typedef DWORD LCID;
typedef LONG DISPID;
struct DISPPARAMS {};
struct EXCEPINFO {};
typedef DWORD IMMGETPROPERTYPROC;
// OLE types
typedef short VARIANT_BOOL;
typedef double DATE;
typedef WCHAR OLECHAR;
typedef OLECHAR *BSTR;
typedef unsigned short VARTYPE;
typedef struct tagVARIANT { VARTYPE vt; union { long lVal; double dblVal; BSTR bstrVal; void *punkVal; }; } VARIANT;
#define VT_EMPTY 0
#define VT_I4 3
#define VT_R8 5
#define VT_BSTR 8
#define VT_DISPATCH 9
#define VT_BOOL 11

// DDE stubs
inline BOOL DdeDisconnect(HCONV) { return FALSE; }
inline void DdeFreeStringHandle(DWORD, HSZ) {}
inline void DdeUninitialize(DWORD) {}

// Windows hooks
typedef LRESULT (CALLBACK *HOOKPROC)(int, WPARAM, LPARAM);
inline HHOOK SetWindowsHookEx(int, HOOKPROC, HINSTANCE, DWORD) { return 0; }
inline BOOL UnhookWindowsHookEx(HHOOK) { return FALSE; }

// PostThreadMessage alias
#define PostThreadMessage PostThreadMessageA

// Socket type
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
typedef int SOCKET;
#define INVALID_SOCKET (-1)
#define SOCKET_ERROR (-1)

// ------------------------------------------------------------
// Color type
// ------------------------------------------------------------
typedef DWORD COLORREF;
#define RGB(r,g,b) ((COLORREF)(((BYTE)(r)|((WORD)((BYTE)(g))<<8))|(((DWORD)(BYTE)(b))<<16)))
#define GetRValue(rgb) ((BYTE)(rgb))
#define GetGValue(rgb) ((BYTE)(((WORD)(rgb)) >> 8))
#define GetBValue(rgb) ((BYTE)((rgb)>>16))

// ------------------------------------------------------------
// String pointer types
// ------------------------------------------------------------
typedef char *LPSTR;
typedef const char *LPCSTR;
typedef wchar_t *LPWSTR;
typedef const wchar_t *LPCWSTR;
typedef void *LPVOID;
typedef const void *LPCVOID;
typedef BYTE *LPBYTE;
typedef DWORD *LPDWORD;
typedef WORD *LPWORD;

// Under UNICODE builds
typedef wchar_t TCHAR;
typedef LPWSTR LPTSTR;
typedef LPCWSTR LPCTSTR;

// Function pointer type
typedef void (*FARPROC)(void);

// ------------------------------------------------------------
// Constants
// ------------------------------------------------------------
#define INVALID_HANDLE_VALUE ((HANDLE)(intptr_t)-1)

#ifndef MAX_PATH
# define MAX_PATH 260
#endif

#define MAX_COMPUTERNAME_LENGTH 31
#define MAXGETHOSTSTRUCT 1024

// File operation constants
#define GENERIC_READ  0x80000000
#define GENERIC_WRITE 0x40000000
#define FILE_SHARE_READ   0x00000001
#define FILE_SHARE_WRITE  0x00000002
#define FILE_SHARE_DELETE 0x00000004
#define CREATE_NEW        1
#define CREATE_ALWAYS     2
#define OPEN_EXISTING     3
#define OPEN_ALWAYS       4
#define TRUNCATE_EXISTING 5
#define FILE_FLAG_SEQUENTIAL_SCAN 0x08000000
#define FILE_ATTRIBUTE_READONLY  0x00000001
#define FILE_ATTRIBUTE_HIDDEN    0x00000002
#define FILE_ATTRIBUTE_SYSTEM    0x00000004
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010
#define FILE_ATTRIBUTE_ARCHIVE   0x00000020
#define FILE_ATTRIBUTE_NORMAL    0x00000080
#define INVALID_FILE_ATTRIBUTES  ((DWORD)-1)

// Duplicate handle
#define DUPLICATE_SAME_ACCESS 0x00000002

// Dialog results
#define IDOK     1
#define IDCANCEL 2
#define IDABORT  3
#define IDRETRY  4
#define IDIGNORE 5
#define IDYES    6
#define IDNO     7

// Message box flags
#define MB_OK              0x00000000
#define MB_OKCANCEL        0x00000001
#define MB_YESNOCANCEL     0x00000003
#define MB_YESNO           0x00000004
#define MB_ICONERROR       0x00000010
#define MB_ICONQUESTION    0x00000020
#define MB_ICONWARNING     0x00000030
#define MB_ICONINFORMATION 0x00000040

// Key modifiers
#define MOD_ALT     0x0001
#define MOD_CONTROL 0x0002
#define MOD_SHIFT   0x0004

// Window messages
#define WM_USER     0x0400
#define WM_CREATE   0x0001
#define WM_DESTROY  0x0002
#define WM_CLOSE    0x0010
#define WM_QUIT     0x0012
#define WM_TIMER    0x0113
#define WM_CHAR     0x0102
#define WM_KEYDOWN  0x0100
#define WM_COMMAND  0x0111
#define WM_IME_CHAR 0x0286
#define WM_IME_REQUEST 0x0288
#define WM_XBUTTONDOWN    0x020B
#define WM_XBUTTONUP      0x020C
#define WM_XBUTTONDBLCLK  0x020D
#define WM_NCXBUTTONDOWN   0x00AB
#define WM_NCXBUTTONUP     0x00AC
#define WM_NCXBUTTONDBLCLK 0x00AD
#define WM_MOUSEWHEEL     0x020A

// Hook types
#define WH_MOUSE 7

// Time zone
#define TIME_ZONE_ID_UNKNOWN  0
#define TIME_ZONE_ID_STANDARD 1
#define TIME_ZONE_ID_DAYLIGHT 2

// System metrics
#define SM_CYSIZEFRAME 33
#define SM_CYBORDER    6
#define SM_CYCAPTION   4
#define CW_USEDEFAULT  ((int)0x80000000)

// File constants
#define FILE_BEGIN   0
#define FILE_END     2
#define FILE_FLAG_BACKUP_SEMANTICS    0x02000000
#define FILE_FLAG_DELETE_ON_CLOSE     0x04000000
#define DRIVE_REMOVABLE 2
#define DRIVE_FIXED     3
#define DRIVE_CDROM     5
#define DRIVE_RAMDISK   6

// Win32 exception codes
#define EXCEPTION_IN_PAGE_ERROR 0xC0000006

// Win32 error codes
#define NO_ERROR 0
#define ERROR_ACCESS_DENIED 5
#define ERROR_INVALID_DRIVE 15
#define ERROR_CURRENT_DIRECTORY 16
#define ERROR_NOT_SAME_DEVICE 17
#define ERROR_WRITE_PROTECT 19
#define ERROR_BAD_UNIT 20
#define ERROR_NOT_READY 21
#define ERROR_LOCK_VIOLATION 33
#define ERROR_WRONG_DISK 34
#define ERROR_DIR_NOT_EMPTY 145
#define ERROR_EXTENDED_ERROR 1208
#define ERROR_NO_MORE_ITEMS 259
#define ERROR_INVALID_NAME 123
#define ERROR_BAD_DEVICE 1200
#define ERROR_DRIVE_LOCKED 108
#define ERROR_UNABLE_TO_LOCK_MEDIA 1108
#define ERROR_UNABLE_TO_UNLOAD_MEDIA 1109

// MessageBox flags (extended)
#define MB_ABORTRETRYIGNORE 0x00000002
#define MB_RETRYCANCEL     0x00000005
#define MB_ICONHAND        MB_ICONERROR
#define MB_ICONEXCLAMATION MB_ICONWARNING
#define MB_ICONASTERISK    MB_ICONINFORMATION
#define MB_ICONSTOP        MB_ICONERROR

// File type
#define FILE_TYPE_DISK 0x0001
inline DWORD GetFileType(HANDLE) { return FILE_TYPE_DISK; }

// Shell file operations
typedef WORD FILEOP_FLAGS;
#define FO_MOVE   1
#define FO_COPY   2
#define FO_DELETE 3
#define FO_RENAME 4
#define FOF_MULTIDESTFILES  0x0001
#define FOF_ALLOWUNDO       0x0040
#define FOF_FILESONLY        0x0080
#define FOF_NOCONFIRMATION  0x0010
#define FOF_SILENT          0x0004
typedef struct _SHFILEOPSTRUCTA {
  HWND hwnd;
  UINT wFunc;
  LPCSTR pFrom;
  LPCSTR pTo;
  FILEOP_FLAGS fFlags;
  BOOL fAnyOperationsAborted;
  LPVOID hNameMappings;
  LPCSTR lpszProgressTitle;
} SHFILEOPSTRUCTA;
typedef struct _SHFILEOPSTRUCTW {
  HWND hwnd;
  UINT wFunc;
  LPCWSTR pFrom;
  LPCWSTR pTo;
  FILEOP_FLAGS fFlags;
  BOOL fAnyOperationsAborted;
  LPVOID hNameMappings;
  LPCWSTR lpszProgressTitle;
} SHFILEOPSTRUCTW;
typedef int (*SHFILEOPERATION)(SHFILEOPSTRUCTW *);
inline DWORD GetShortPathNameA(LPCSTR s, LPSTR buf, DWORD n) {
  if (s && buf && n > 0) { strncpy(buf, s, n); buf[n-1] = 0; return (DWORD)strlen(buf); }
  return 0;
}
inline HWND GetFocus() { return 0; }

// ShellExecuteEx
typedef struct _SHELLEXECUTEINFOW {
  DWORD cbSize;
  ULONG fMask;
  HWND hwnd;
  LPCWSTR lpVerb;
  LPCWSTR lpFile;
  LPCWSTR lpParameters;
  LPCWSTR lpDirectory;
  int nShow;
  HINSTANCE hInstApp;
  void *lpIDList;
} SHELLEXECUTEINFOW;
#define SEE_MASK_INVOKEIDLIST 0x0C
inline BOOL ShellExecuteExW(SHELLEXECUTEINFOW*) { return FALSE; }

// DeviceIoControl
#define CTL_CODE(t,f,m,a) (((t)<<16)|((a)<<14)|((f)<<2)|(m))
#define METHOD_BUFFERED 0
#define FILE_READ_ACCESS 1
#define FSCTL_LOCK_VOLUME CTL_CODE(9,6,METHOD_BUFFERED,0)
#define FSCTL_DISMOUNT_VOLUME CTL_CODE(9,8,METHOD_BUFFERED,0)
typedef BYTE BOOLEAN;
typedef struct _PREVENT_MEDIA_REMOVAL { BOOLEAN PreventMediaRemoval; } PREVENT_MEDIA_REMOVAL;
inline BOOL DeviceIoControl(HANDLE, DWORD, LPVOID, DWORD, LPVOID, DWORD, LPDWORD, void*) { return FALSE; }

// GDI
#define DSTINVERT 0x00550009
inline BOOL GdiFlush() { return TRUE; }
inline void MessageBeep(UINT) {}

// Network resources
#define RESOURCE_GLOBALNET  2
#define RESOURCETYPE_ANY    0
#define RESOURCETYPE_DISK   1
#define RESOURCEUSAGE_CONTAINER 1
#define RESOURCEDISPLAYTYPE_GENERIC 0
#define RESOURCEDISPLAYTYPE_DOMAIN  1
#define RESOURCEDISPLAYTYPE_SERVER  2
#define RESOURCEDISPLAYTYPE_SHARE   3
#define RESOURCEDISPLAYTYPE_NETWORK 6
inline DWORD WNetGetLastErrorA(DWORD*, LPSTR, DWORD, LPSTR, DWORD) { return (DWORD)-1; }
inline DWORD WNetDisconnectDialog(HWND, DWORD) { return (DWORD)-1; }

// Page protection
#define PAGE_GUARD    0x100
#define PAGE_NOCACHE  0x200
#define PAGE_WRITECOPY 0x08
#define PAGE_EXECUTE  0x10
#define PAGE_EXECUTE_READ 0x20
#define PAGE_EXECUTE_READWRITE 0x40
#define PAGE_EXECUTE_WRITECOPY 0x80

// Version platform IDs
#define VER_PLATFORM_WIN32_NT 2

// Registry
#define REG_SZ     1
#define REG_DWORD  4
#define REG_BINARY 3
#define REG_EXPAND_SZ 2
#define REG_MULTI_SZ 7
#define KEY_READ   0x20019
#define KEY_WRITE  0x20006
#define REG_OPTION_NON_VOLATILE 0
#define ERROR_SUCCESS 0
#define ERROR_FILE_NOT_FOUND 2
#define ERROR_PATH_NOT_FOUND 3
#define ERROR_FILE_EXISTS 80
#define ERROR_ALREADY_EXISTS 183
#define ERROR_SHARING_VIOLATION 32
#define ERROR_FILE_CORRUPT 1392
#define ERROR_BAD_NETPATH 53
#define ERROR_BAD_PATHNAME 161

/* Wait constants */
#define WAIT_TIMEOUT 258
#define WAIT_OBJECT_0 0
#define INFINITE 0xFFFFFFFF
inline DWORD WaitForSingleObject(HANDLE, DWORD) { return WAIT_TIMEOUT; }

/* CRT compatibility */
#define _fdopen fdopen
#define _close close
#define _fileno fileno
#define HKEY_CURRENT_USER ((HKEY)(ULONG_PTR)0x80000001)
#define HKEY_CLASSES_ROOT ((HKEY)(ULONG_PTR)0x80000000)
#define HKEY_LOCAL_MACHINE ((HKEY)(ULONG_PTR)0x80000002)
#define HKEY_USERS ((HKEY)(ULONG_PTR)0x80000003)

// DDE
#define XTYP_EXECUTE  0x4050
#define XTYP_POKE     0x4090
#define XTYP_REQUEST  0x20B0
#define CF_TEXT        1

// Code page
#define CP_WINANSI 1004

// Device caps
#define LOGPIXELSY 90

// Socket constants
#define WSAEINTR       EINTR

// SSL/Security constants
#define SECURITY_WIN32
#define SECBUFFER_VERSION  0
#define SECBUFFER_EMPTY    0
#define SECBUFFER_DATA     1
#define SECBUFFER_TOKEN    2
#define SECBUFFER_STREAM_HEADER  7
#define SECBUFFER_STREAM_TRAILER 6

// I/O control
#ifndef FIONREAD
#define FIONREAD 0x541B
#endif

// Window style constants (minimal set)
#define GWL_WNDPROC  (-4)
#define GWL_STYLE    (-16)
#define GWL_EXSTYLE  (-20)
#define GWL_ID       (-12)
#define DWL_USER     0
#define DWL_MSGRESULT 0

// Common controls constants
#define WC_TABCONTROL L"SysTabControl32"
#define TCM_FIRST       0x1300
#define TCM_GETITEMCOUNT (TCM_FIRST + 4)
#define TCM_GETITEM     (TCM_FIRST + 5)
#define TCM_SETITEM     (TCM_FIRST + 6)
#define TCM_INSERTITEM  (TCM_FIRST + 7)
#define TCM_DELETEITEM  (TCM_FIRST + 8)
#define TCM_GETTOOLTIPS (TCM_FIRST + 45)
#define TCM_GETITEMRECT (TCM_FIRST + 10)
#define TCM_SETITEMSIZE (TCM_FIRST + 41)
#define TCM_HITTEST     (TCM_FIRST + 13)
#define TCM_SETCURSEL   (TCM_FIRST + 12)
#define TCM_GETCURSEL   (TCM_FIRST + 11)
#define TCM_SETPADDING  (TCM_FIRST + 43)
#define TCM_ADJUSTRECT  (TCM_FIRST + 40)
#define TCS_FOCUSNEVER  0x8000
#define TTS_NOPREFIX    0x02
#define HTCLIENT        1

// Toolbar
#define TB_SETBITMAPSIZE  (WM_USER + 32)
#define TB_SETBUTTONSIZE  (WM_USER + 31)
#define TB_ADDBITMAP      (WM_USER + 19)
#define TB_BUTTONCOUNT    (WM_USER + 24)
#define TB_ADDBUTTONS     (WM_USER + 20)
#define TB_GETTOOLTIPS    (WM_USER + 35)
#define TB_GETBUTTON      (WM_USER + 23)
#define TB_INSERTBUTTON   (WM_USER + 21)
#define TB_DELETEBUTTON   (WM_USER + 22)
#define TB_GETITEMRECT    (WM_USER + 29)
#define TB_GETSTATE       (WM_USER + 18)
#define TB_SETSTATE       (WM_USER + 17)
#define TB_ENABLEBUTTON   (WM_USER + 1)
#define TB_CHECKBUTTON    (WM_USER + 2)
#define TB_PRESSBUTTON    (WM_USER + 3)
#define WM_SETFONT        0x0030

// SWP flags
#define SWP_NOZORDER    0x0004
#define SWP_NOACTIVATE  0x0010
#define SWP_SHOWWINDOW  0x0040
#define SWP_HIDEWINDOW  0x0080

// List view
#define LVN_PROCESSKEY 0

// SendMessage / PostMessage (no-op stubs)
#define LVM_FIRST 0x1000

// ------------------------------------------------------------
// Function-like macros
// ------------------------------------------------------------
#define MAKELONG(a, b) ((LONG)(((WORD)(a)) | ((DWORD)((WORD)(b))) << 16))
#define MAKELPARAM(l, h) ((LPARAM)MAKELONG(l, h))
#define LOWORD(l) ((WORD)((DWORD_PTR)(l) & 0xffff))
#define HIWORD(l) ((WORD)((DWORD_PTR)(l) >> 16))
#define MAKEWORD(a, b) ((WORD)(((BYTE)(a)) | ((WORD)((BYTE)(b))) << 8))
#define LOBYTE(w) ((BYTE)((DWORD_PTR)(w) & 0xff))
#define HIBYTE(w) ((BYTE)((DWORD_PTR)(w) >> 8))

inline int MulDiv(int a, int b, int c) { return (int)(((int64_t)a * b) / c); }

// ------------------------------------------------------------
// Structures
// ------------------------------------------------------------

typedef struct _FILETIME {
  DWORD dwLowDateTime;
  DWORD dwHighDateTime;
} FILETIME;

inline LONG CompareFileTime(const FILETIME *a, const FILETIME *b) {
  if (a->dwHighDateTime != b->dwHighDateTime) return a->dwHighDateTime < b->dwHighDateTime ? -1 : 1;
  if (a->dwLowDateTime != b->dwLowDateTime) return a->dwLowDateTime < b->dwLowDateTime ? -1 : 1;
  return 0;
}
inline BOOL SetFileTime(HANDLE, const FILETIME*, const FILETIME*, const FILETIME*) { return FALSE; }

typedef union _LARGE_INTEGER {
  struct { DWORD LowPart; LONG HighPart; };
  LONGLONG QuadPart;
} LARGE_INTEGER;

typedef union _ULARGE_INTEGER {
  struct { DWORD LowPart; DWORD HighPart; };
  ULONGLONG QuadPart;
} ULARGE_INTEGER;
typedef ULARGE_INTEGER *PULARGE_INTEGER;

typedef struct _SECURITY_ATTRIBUTES {
  DWORD nLength;
  LPVOID lpSecurityDescriptor;
  BOOL bInheritHandle;
} SECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

typedef struct tagSIZE {
  LONG cx;
  LONG cy;
} SIZE;

typedef struct tagPOINT {
  LONG x;
  LONG y;
} POINT;

typedef struct tagRECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECT, *LPRECT;
typedef const RECT *LPCRECT;

typedef struct _OSVERSIONINFOA {
  DWORD dwOSVersionInfoSize;
  DWORD dwMajorVersion;
  DWORD dwMinorVersion;
  DWORD dwBuildNumber;
  DWORD dwPlatformId;
  char szCSDVersion[128];
} OSVERSIONINFOA;

typedef struct tagLOGFONTA {
  LONG lfHeight;
  LONG lfWidth;
  LONG lfEscapement;
  LONG lfOrientation;
  LONG lfWeight;
  BYTE lfItalic;
  BYTE lfUnderline;
  BYTE lfStrikeOut;
  BYTE lfCharSet;
  BYTE lfOutPrecision;
  BYTE lfClipPrecision;
  BYTE lfQuality;
  BYTE lfPitchAndFamily;
  char lfFaceName[32];
} LOGFONTA;

typedef struct tagLOGFONTW {
  LONG lfHeight;
  LONG lfWidth;
  LONG lfEscapement;
  LONG lfOrientation;
  LONG lfWeight;
  BYTE lfItalic;
  BYTE lfUnderline;
  BYTE lfStrikeOut;
  BYTE lfCharSet;
  BYTE lfOutPrecision;
  BYTE lfClipPrecision;
  BYTE lfQuality;
  BYTE lfPitchAndFamily;
  wchar_t lfFaceName[32];
} LOGFONTW;

#define LF_FACESIZE 32

typedef struct tagTEXTMETRICA {
  LONG tmHeight;
  LONG tmAscent;
  LONG tmDescent;
  LONG tmInternalLeading;
  LONG tmExternalLeading;
  LONG tmAveCharWidth;
  LONG tmMaxCharWidth;
  LONG tmWeight;
  LONG tmOverhang;
  LONG tmDigitizedAspectX;
  LONG tmDigitizedAspectY;
  BYTE tmFirstChar;
  BYTE tmLastChar;
  BYTE tmDefaultChar;
  BYTE tmBreakChar;
  BYTE tmItalic;
  BYTE tmUnderlined;
  BYTE tmStruckOut;
  BYTE tmPitchAndFamily;
  BYTE tmCharSet;
} TEXTMETRICA;

typedef struct tagNEWTEXTMETRIC {
  LONG tmHeight;
  LONG tmAscent;
  LONG tmDescent;
  LONG tmInternalLeading;
  LONG tmExternalLeading;
  LONG tmAveCharWidth;
  LONG tmMaxCharWidth;
  LONG tmWeight;
  LONG tmOverhang;
  LONG tmDigitizedAspectX;
  LONG tmDigitizedAspectY;
  BYTE tmFirstChar;
  BYTE tmLastChar;
  BYTE tmDefaultChar;
  BYTE tmBreakChar;
  BYTE tmItalic;
  BYTE tmUnderlined;
  BYTE tmStruckOut;
  BYTE tmPitchAndFamily;
  BYTE tmCharSet;
  DWORD ntmFlags;
  UINT ntmSizeEM;
  UINT ntmCellHeight;
  UINT ntmAvgWidth;
} NEWTEXTMETRIC;

typedef struct _WIN32_FIND_DATAA {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
  DWORD dwReserved0;
  DWORD dwReserved1;
  char cFileName[MAX_PATH];
  char cAlternateFileName[14];
} WIN32_FIND_DATAA;
typedef WIN32_FIND_DATAA *LPWIN32_FIND_DATAA;

typedef struct _WIN32_FIND_DATAW {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
  DWORD dwReserved0;
  DWORD dwReserved1;
  wchar_t cFileName[MAX_PATH];
  wchar_t cAlternateFileName[14];
} WIN32_FIND_DATAW;
typedef WIN32_FIND_DATAW *LPWIN32_FIND_DATAW;

typedef struct _WINDOWPLACEMENT {
  UINT length;
  UINT flags;
  UINT showCmd;
  POINT ptMinPosition;
  POINT ptMaxPosition;
  RECT rcNormalPosition;
} WINDOWPLACEMENT;

typedef struct tagDRAWITEMSTRUCT {
  UINT CtlType;
  UINT CtlID;
  UINT itemID;
  UINT itemAction;
  UINT itemState;
  HWND hwndItem;
  HDC hDC;
  RECT rcItem;
  ULONG_PTR itemData;
} DRAWITEMSTRUCT;

typedef struct tagMEASUREITEMSTRUCT {
  UINT CtlType;
  UINT CtlID;
  UINT itemID;
  UINT itemWidth;
  UINT itemHeight;
  ULONG_PTR itemData;
} MEASUREITEMSTRUCT;

typedef struct tagMENUITEMINFOA {
  UINT cbSize;
  UINT fMask;
  UINT fType;
  UINT fState;
  UINT wID;
  HMENU hSubMenu;
  HBITMAP hbmpChecked;
  HBITMAP hbmpUnchecked;
  ULONG_PTR dwItemData;
  LPSTR dwTypeData;
  UINT cch;
  HBITMAP hbmpItem;
} MENUITEMINFOA;

typedef struct tagSCROLLINFO {
  UINT cbSize;
  UINT fMask;
  int nMin;
  int nMax;
  UINT nPage;
  int nPos;
  int nTrackPos;
} SCROLLINFO;

typedef struct tagNMHDR {
  HWND hwndFrom;
  UINT_PTR idFrom;
  UINT code;
} NMHDR;

typedef struct tagMSG {
  HWND hwnd;
  UINT message;
  WPARAM wParam;
  LPARAM lParam;
  DWORD time;
  POINT pt;
} MSG;

// Toolbar structures
typedef struct tagTBADDBITMAP { HINSTANCE hInst; UINT_PTR nID; } TBADDBITMAP;
typedef struct tagTBBUTTON { int iBitmap; int idCommand; BYTE fsState; BYTE fsStyle; DWORD_PTR dwData; INT_PTR iString; } TBBUTTON;

// Tab control
typedef struct tagTCITEM { UINT mask; DWORD dwState; DWORD dwStateMask; LPSTR pszText; int cchTextMax; int iImage; LPARAM lParam; } TC_ITEM;
typedef struct tagTCHITTESTINFO { POINT pt; UINT flags; } TC_HITTESTINFO;

// Tooltip
typedef struct tagTOOLTIPTEXT { NMHDR hdr; LPSTR lpszText; char szText[80]; HINSTANCE hinst; UINT uFlags; } TOOLTIPTEXT;

// Notification
#define TCN_FIRST       ((UINT)-550)
#define TCN_SELCHANGE   (TCN_FIRST - 1)

typedef struct _PROCESS_INFORMATION {
  HANDLE hProcess;
  HANDLE hThread;
  DWORD dwProcessId;
  DWORD dwThreadId;
} PROCESS_INFORMATION;

typedef struct _STARTUPINFOA {
  DWORD cb;
  LPSTR lpReserved;
  LPSTR lpDesktop;
  LPSTR lpTitle;
  DWORD dwX;
  DWORD dwY;
  DWORD dwXSize;
  DWORD dwYSize;
  DWORD dwXCountChars;
  DWORD dwYCountChars;
  DWORD dwFillAttribute;
  DWORD dwFlags;
  WORD wShowWindow;
  WORD cbReserved2;
  LPBYTE lpReserved2;
  HANDLE hStdInput;
  HANDLE hStdOutput;
  HANDLE hStdError;
} STARTUPINFOA;

typedef struct _NETRESOURCEA {
  DWORD dwScope;
  DWORD dwType;
  DWORD dwDisplayType;
  DWORD dwUsage;
  LPSTR lpLocalName;
  LPSTR lpRemoteName;
  LPSTR lpComment;
  LPSTR lpProvider;
} NETRESOURCEA;
typedef NETRESOURCEA *LPNETRESOURCEA;

typedef struct tagBITMAPINFOHEADER {
  DWORD biSize;
  LONG biWidth;
  LONG biHeight;
  WORD biPlanes;
  WORD biBitCount;
  DWORD biCompression;
  DWORD biSizeImage;
  LONG biXPelsPerMeter;
  LONG biYPelsPerMeter;
  DWORD biClrUsed;
  DWORD biClrImportant;
} BITMAPINFOHEADER;

typedef struct tagRGBQUAD {
  BYTE rgbBlue;
  BYTE rgbGreen;
  BYTE rgbRed;
  BYTE rgbReserved;
} RGBQUAD;

typedef struct tagBITMAPINFO {
  BITMAPINFOHEADER bmiHeader;
  RGBQUAD bmiColors[1];
} BITMAPINFO;

typedef struct tagPAINTSTRUCT {
  HDC hdc;
  BOOL fErase;
  RECT rcPaint;
  BOOL fRestore;
  BOOL fIncUpdate;
  BYTE rgbReserved[32];
} PAINTSTRUCT;

typedef struct tagWNDCLASSEXA {
  UINT cbSize;
  UINT style;
  void *lpfnWndProc;
  int cbClsExtra;
  int cbWndExtra;
  HINSTANCE hInstance;
  HICON hIcon;
  HCURSOR hCursor;
  HBRUSH hbrBackground;
  LPCSTR lpszMenuName;
  LPCSTR lpszClassName;
  HICON hIconSm;
} WNDCLASSEXA;

typedef struct tagCREATESTRUCTA {
  LPVOID lpCreateParams;
  HINSTANCE hInstance;
  HMENU hMenu;
  HWND hwndParent;
  int cy;
  int cx;
  int y;
  int x;
  LONG style;
  LPCSTR lpszName;
  LPCSTR lpszClass;
  DWORD dwExStyle;
} CREATESTRUCTA;

typedef struct tagNONCLIENTMETRICSA {
  UINT cbSize;
  int iBorderWidth;
  int iScrollWidth;
  int iScrollHeight;
  int iCaptionWidth;
  int iCaptionHeight;
  LOGFONTA lfCaptionFont;
  int iSmCaptionWidth;
  int iSmCaptionHeight;
  LOGFONTA lfSmCaptionFont;
  int iMenuWidth;
  int iMenuHeight;
  LOGFONTA lfMenuFont;
  LOGFONTA lfStatusFont;
  LOGFONTA lfMessageFont;
} NONCLIENTMETRICSA;

// MONITORINFO
typedef struct tagMONITORINFO {
  DWORD cbSize;
  RECT rcMonitor;
  RECT rcWork;
  DWORD dwFlags;
} MONITORINFO, *LPMONITORINFO;

// IME composition
typedef struct tagCOMPOSITIONFORM {
  DWORD dwStyle;
  POINT ptCurrentPos;
  RECT rcArea;
} COMPOSITIONFORM;

// Register word
typedef struct tagREGISTERWORDA {
  LPSTR lpReading;
  LPSTR lpWord;
} REGISTERWORDA;

// SYSTEMTIME
typedef struct _SYSTEMTIME {
  WORD wYear; WORD wMonth; WORD wDayOfWeek; WORD wDay;
  WORD wHour; WORD wMinute; WORD wSecond; WORD wMilliseconds;
} SYSTEMTIME;

typedef struct _TIME_ZONE_INFORMATION {
  LONG Bias;
  WCHAR StandardName[32];
  SYSTEMTIME StandardDate;
  LONG StandardBias;
  WCHAR DaylightName[32];
  SYSTEMTIME DaylightDate;
  LONG DaylightBias;
} TIME_ZONE_INFORMATION;

inline void GetSystemTime(SYSTEMTIME *st) {
  time_t t = time(0);
  struct tm *tm = gmtime(&t);
  st->wYear = tm->tm_year + 1900; st->wMonth = tm->tm_mon + 1;
  st->wDay = tm->tm_mday; st->wDayOfWeek = tm->tm_wday;
  st->wHour = tm->tm_hour; st->wMinute = tm->tm_min;
  st->wSecond = tm->tm_sec; st->wMilliseconds = 0;
}

inline BOOL SystemTimeToFileTime(const SYSTEMTIME *st, FILETIME *ft) {
  struct tm tm = {};
  tm.tm_year = st->wYear - 1900; tm.tm_mon = st->wMonth - 1;
  tm.tm_mday = st->wDay; tm.tm_hour = st->wHour;
  tm.tm_min = st->wMinute; tm.tm_sec = st->wSecond;
  time_t t = mktime(&tm);
  uint64_t v = ((uint64_t)t + 11644473600ULL) * 10000000ULL;
  ft->dwLowDateTime = (DWORD)v;
  ft->dwHighDateTime = (DWORD)(v >> 32);
  return TRUE;
}

// CRITICAL_SECTION (stub as pthread_mutex_t on Linux)
#include <pthread.h>
typedef pthread_mutex_t CRITICAL_SECTION;
inline void InitializeCriticalSection(CRITICAL_SECTION *cs) { pthread_mutex_init(cs, 0); }
inline void DeleteCriticalSection(CRITICAL_SECTION *cs) { pthread_mutex_destroy(cs); }
inline void EnterCriticalSection(CRITICAL_SECTION *cs) { pthread_mutex_lock(cs); }
inline void LeaveCriticalSection(CRITICAL_SECTION *cs) { pthread_mutex_unlock(cs); }

// PROPSHEETPAGEW (stub)
typedef struct _PROPSHEETPAGEW {
  DWORD dwSize;
  DWORD dwFlags;
  HINSTANCE hInstance;
  LPCWSTR pszTemplate;
  void *pfnDlgProc;
  LPARAM lParam;
} PROPSHEETPAGEW;

// DDE
typedef struct tagCONVCONTEXT {
  UINT cb;
  UINT wFlags;
  UINT wCountryID;
  int iCodePage;
  DWORD dwLangID;
  DWORD dwSecurity;
} CONVCONTEXT;

// Security/SSL structures (stubs)
typedef struct _SecBuffer {
  unsigned long cbBuffer;
  unsigned long BufferType;
  void *pvBuffer;
} SecBuffer;

typedef struct _SecBufferDesc {
  unsigned long ulVersion;
  unsigned long cBuffers;
  SecBuffer *pBuffers;
} SecBufferDesc;

typedef struct _SecHandle {
  ULONG_PTR dwLower;
  ULONG_PTR dwUpper;
} SecHandle;

typedef SecHandle CtxtHandle;
typedef SecHandle CredHandle;

typedef struct _SCHANNEL_CRED {
  DWORD dwVersion;
  DWORD cCreds;
  void *paCred;
  DWORD grbitEnabledProtocols;
  DWORD dwMinimumCipherStrength;
  DWORD dwMaximumCipherStrength;
  DWORD dwSessionLifespan;
  DWORD dwFlags;
  DWORD dwCredFormat;
} SCHANNEL_CRED;

typedef struct _SecPkgContext_StreamSizes {
  unsigned long cbHeader;
  unsigned long cbTrailer;
  unsigned long cbMaximumMessage;
  unsigned long cBuffers;
  unsigned long cbBlockSize;
} SecPkgContext_StreamSizes;

// Winsock compatibility structures
typedef struct _WSADATA {
  WORD wVersion;
  WORD wHighVersion;
  char szDescription[257];
  char szSystemStatus[129];
  unsigned short iMaxSockets;
  unsigned short iMaxUdpDg;
  char *lpVendorInfo;
} WSADATA;
typedef WSADATA *LPWSADATA;

// LV_PROCESSKEY (defined in privctrl.h on Win32, minimal stub here)
#ifndef LVS_TYPEMASKEX
typedef struct tagLV_PROCESSKEY {
  NMHDR hdr;
  UINT ch;
  UINT flags;
} LV_PROCESSKEY;
#endif

// DIOC_REGISTERS stub (x86 DOS compat)
typedef struct _DIOC_REGISTERS {
  DWORD reg_EBX;
  DWORD reg_EDX;
  DWORD reg_ECX;
  DWORD reg_EAX;
  DWORD reg_EDI;
  DWORD reg_ESI;
  DWORD reg_Flags;
} DIOC_REGISTERS;

// List view styles
#ifndef LVS_TYPEMASKEX
# define LVS_TYPEMASKEX  0
# define LVS_EXREPORT    0
# define LVS_EXREPORTEX  0
# define LVS_EXTENDKBD   0
# define LVS_PROCESSKEY  0
#endif

// WSADATA helpers
#define WSAMAKEASYNCREPLY(buflen, error) MAKELONG(buflen, error)

// Winsock error codes (mapped to POSIX errno on Linux)
#define WSABASEERR      0
#define WSAEBADF        EBADF
#define WSAEACCES       EACCES
#define WSAEFAULT       EFAULT
#define WSAEINVAL       EINVAL
#define WSAEMFILE       EMFILE
#define WSAEWOULDBLOCK  EWOULDBLOCK
#define WSAEINPROGRESS  EINPROGRESS
#define WSAEALREADY     EALREADY
#define WSAENOTSOCK     ENOTSOCK
#define WSAEDESTADDRREQ EDESTADDRREQ
#define WSAEMSGSIZE     EMSGSIZE
#define WSAEPROTOTYPE   EPROTOTYPE
#define WSAENOPROTOOPT  ENOPROTOOPT
#define WSAEPROTONOSUPPORT EPROTONOSUPPORT
#define WSAESOCKTNOSUPPORT ESOCKTNOSUPPORT
#define WSAEOPNOTSUPP   EOPNOTSUPP
#define WSAEPFNOSUPPORT EPFNOSUPPORT
#define WSAEAFNOSUPPORT EAFNOSUPPORT
#define WSAEADDRINUSE   EADDRINUSE
#define WSAEADDRNOTAVAIL EADDRNOTAVAIL
#define WSAENETDOWN     ENETDOWN
#define WSAENETUNREACH  ENETUNREACH
#define WSAENETRESET    ENETRESET
#define WSAECONNABORTED ECONNABORTED
#define WSAECONNRESET   ECONNRESET
#define WSAENOBUFS      ENOBUFS
#define WSAEISCONN      EISCONN
#define WSAENOTCONN     ENOTCONN
#define WSAESHUTDOWN    ESHUTDOWN
#define WSAETOOMANYREFS ETOOMANYREFS
#define WSAETIMEDOUT    ETIMEDOUT
#define WSAECONNREFUSED ECONNREFUSED
#define WSAELOOP        ELOOP
#define WSAENAMETOOLONG ENAMETOOLONG
#define WSAEHOSTDOWN    EHOSTDOWN
#define WSAEHOSTUNREACH EHOSTUNREACH
#define WSAENOTEMPTY    ENOTEMPTY
#define WSAEPROCLIM     ENOSPC
#define WSAEUSERS       EUSERS
#define WSAEDQUOT       EDQUOT
#define WSAESTALE       ESTALE
#define WSAEREMOTE      EREMOTE
#define WSASYSNOTREADY  10091
#define WSAVERNOTSUPPORTED 10092
#define WSANOTINITIALISED  10093
#define WSAEDISCON      10101
#define WSAHOST_NOT_FOUND  1
#define WSATRY_AGAIN    2
#define WSANO_RECOVERY  3
#define WSANO_DATA      4

// SChannel constants
#define SCHANNEL_CRED_VERSION 4
#define SP_PROT_SSL3TLS1_X_CLIENTS 0
#define SCH_CRED_MANUAL_CRED_VALIDATION 0
#define ISC_REQ_SEQUENCE_DETECT  0
#define ISC_REQ_REPLAY_DETECT    0
#define ISC_REQ_CONFIDENTIALITY  0
#define ISC_REQ_ALLOCATE_MEMORY  0
#define ISC_REQ_STREAM           0
#define SEC_E_OK                 0
#define SEC_I_CONTINUE_NEEDED    0x00090312
#define SEC_E_INCOMPLETE_MESSAGE 0x80090318
#define SEC_I_INCOMPLETE_CREDENTIALS 0x00090320
#define SECPKG_ATTR_STREAM_SIZES 4
#define SEC_I_CONTEXT_EXPIRED    0x00090317
#define SEC_I_RENEGOTIATE        0x00090321

// SECURITY_STATUS
typedef LONG SECURITY_STATUS;

// ------------------------------------------------------------
// Win32 API stubs (inline no-ops)
// ------------------------------------------------------------

// Tick count
inline DWORD GetTickCount() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (DWORD)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

// Performance counter
inline BOOL QueryPerformanceFrequency(LARGE_INTEGER *f) {
  f->QuadPart = 1000000000LL;
  return TRUE;
}

inline BOOL QueryPerformanceCounter(LARGE_INTEGER *c) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  c->QuadPart = (LONGLONG)ts.tv_sec * 1000000000LL + ts.tv_nsec;
  return TRUE;
}

// System info
inline BOOL GetVersionExA(OSVERSIONINFOA *v) {
  memset(v, 0, sizeof(*v));
  v->dwMajorVersion = 10;
  v->dwMinorVersion = 0;
  v->dwPlatformId = VER_PLATFORM_WIN32_NT;
  return TRUE;
}

inline DWORD GetCurrentDirectoryA(DWORD n, LPSTR buf) {
  if (getcwd(buf, n)) return (DWORD)strlen(buf);
  return 0;
}
inline DWORD GetCurrentDirectoryW(DWORD n, LPWSTR buf) {
  char tmp[4096];
  if (!getcwd(tmp, sizeof(tmp))) return 0;
  size_t len = strlen(tmp);
  for (size_t i = 0; i < len && i < (size_t)(n - 1); i++)
    buf[i] = (wchar_t)(unsigned char)tmp[i];
  if (len < (size_t)n) buf[len] = 0;
  return (DWORD)len;
}

inline BOOL GetComputerNameA(LPSTR buf, DWORD *len) {
  if (gethostname(buf, *len) == 0) {
    *len = (DWORD)strlen(buf);
    return TRUE;
  }
  return FALSE;
}

inline DWORD GetCurrentProcessId() { return (DWORD)getpid(); }
inline HANDLE GetCurrentProcess() { return (HANDLE)(intptr_t)-1; }
inline DWORD GetCurrentThreadId() { return (DWORD)(uintptr_t)pthread_self(); }
inline DWORD GetLastError() { return (DWORD)errno; }
inline void SetLastError(DWORD e) { errno = (int)e; }

// File operations — POSIX implementations (HANDLE = (intptr_t)fd)
inline HANDLE CreateFileA(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE) { return INVALID_HANDLE_VALUE; }
inline BOOL CloseHandle(HANDLE h) {
  if (h && h != INVALID_HANDLE_VALUE)
    return ::close((int)(intptr_t)h) == 0;
  return FALSE;
}
inline BOOL DuplicateHandle(HANDLE, HANDLE, HANDLE, HANDLE*, DWORD, BOOL, DWORD) { return FALSE; }
inline BOOL CreatePipe(HANDLE*, HANDLE*, LPSECURITY_ATTRIBUTES, DWORD) { return FALSE; }
inline HANDLE CreateFileMappingA(HANDLE, LPSECURITY_ATTRIBUTES, DWORD, DWORD, DWORD, LPCSTR) { return 0; }
#define CreateFileMapping CreateFileMappingA
inline void *MapViewOfFile(HANDLE, DWORD, DWORD, DWORD, size_t) { return 0; }
inline BOOL UnmapViewOfFile(const void*) { return FALSE; }
inline DWORD GetFileSize(HANDLE h, DWORD*) {
  struct stat st;
  if (h != INVALID_HANDLE_VALUE && fstat((int)(intptr_t)h, &st) == 0)
    return (DWORD)st.st_size;
  return (DWORD)-1;
}
inline BOOL ReadFile(HANDLE h, void* buf, DWORD n, DWORD* nread, void*) {
  ssize_t r = ::read((int)(intptr_t)h, buf, n);
  if (r < 0) return FALSE;
  if (nread) *nread = (DWORD)r;
  return TRUE;
}
inline BOOL WriteFile(HANDLE h, const void* buf, DWORD n, DWORD* nwritten, void*) {
  ssize_t r = ::write((int)(intptr_t)h, buf, n);
  if (r < 0) return FALSE;
  if (nwritten) *nwritten = (DWORD)r;
  return TRUE;
}

// File attributes / find
inline DWORD GetFileAttributesA(LPCSTR path) {
  if (!path) return INVALID_FILE_ATTRIBUTES;
  struct stat st;
  if (stat(path, &st) != 0) return INVALID_FILE_ATTRIBUTES;
  DWORD attr = FILE_ATTRIBUTE_NORMAL;
  if (S_ISDIR(st.st_mode)) attr = FILE_ATTRIBUTE_DIRECTORY;
  if (!(st.st_mode & S_IWUSR)) attr |= FILE_ATTRIBUTE_READONLY;
  return attr;
}
inline BOOL SetFileAttributesA(LPCSTR, DWORD) { return FALSE; }
inline HANDLE FindFirstFileA(LPCSTR, WIN32_FIND_DATAA*) { return INVALID_HANDLE_VALUE; }
inline BOOL FindNextFileA(HANDLE, WIN32_FIND_DATAA*) { return FALSE; }
BOOL FindClose(HANDLE h);
inline BOOL DeleteFileA(LPCSTR) { return FALSE; }
inline BOOL MoveFileA(LPCSTR, LPCSTR) { return FALSE; }
inline BOOL CreateDirectoryA(LPCSTR, LPSECURITY_ATTRIBUTES) { return FALSE; }
inline BOOL RemoveDirectoryA(LPCSTR) { return FALSE; }
inline DWORD GetFullPathNameA(LPCSTR f, DWORD n, LPSTR b, LPSTR*) {
  if (!f || !b) return 0;
  // Minimal: just copy
  size_t len = strlen(f);
  if (len >= n) return 0;
  strcpy(b, f);
  return (DWORD)len;
}
inline BOOL IsDBCSLeadByte(BYTE) { return FALSE; }

// W-suffix file operation stubs (for cli-stubs.cc WINFS methods)
inline HANDLE CreateFileW(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE) { return INVALID_HANDLE_VALUE; }
inline DWORD GetFileAttributesW(LPCWSTR) { return INVALID_FILE_ATTRIBUTES; }
inline BOOL SetFileAttributesW(LPCWSTR, DWORD) { return FALSE; }
inline HANDLE FindFirstFileW(LPCWSTR, WIN32_FIND_DATAW*) { return INVALID_HANDLE_VALUE; }
inline BOOL FindNextFileW(HANDLE, WIN32_FIND_DATAW*) { return FALSE; }
inline BOOL DeleteFileW(LPCWSTR) { return FALSE; }
inline BOOL MoveFileW(LPCWSTR, LPCWSTR) { return FALSE; }
inline BOOL CreateDirectoryW(LPCWSTR, LPSECURITY_ATTRIBUTES) { return FALSE; }
inline BOOL RemoveDirectoryW(LPCWSTR) { return FALSE; }
inline DWORD GetFullPathNameW(LPCWSTR f, DWORD n, LPWSTR b, LPWSTR*) {
  if (!f || !b) return 0;
  size_t len = wcslen(f);
  if (len >= n) return 0;
  wcscpy(b, f);
  return (DWORD)len;
}
inline BOOL SetCurrentDirectoryW(LPCWSTR) { return FALSE; }
inline UINT GetTempFileNameW(LPCWSTR, LPCWSTR, UINT, LPWSTR) { return 0; }
inline BOOL GetDiskFreeSpaceW(LPCWSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD) { return FALSE; }
inline BOOL GetVolumeInformationW(LPCWSTR, LPWSTR, DWORD, LPDWORD, LPDWORD, LPDWORD, LPWSTR, DWORD) { return FALSE; }
inline DWORD GetTempPathA(DWORD n, LPSTR buf) {
  const char *tmp = "/tmp";
  if (strlen(tmp) < n) { strcpy(buf, tmp); return (DWORD)strlen(buf); }
  return 0;
}

// Module/DLL stubs
inline HMODULE GetModuleHandleA(LPCSTR) { return 0; }
inline HMODULE GetModuleHandleW(LPCWSTR) { return 0; }
inline HMODULE LoadLibraryA(LPCSTR) { return 0; }
inline HMODULE LoadLibraryW(LPCWSTR) { return 0; }
inline BOOL FreeLibrary(HMODULE) { return FALSE; }
inline FARPROC GetProcAddress(HMODULE, LPCSTR) { return 0; }
inline DWORD GetModuleFileNameA(HMODULE, LPSTR buf, DWORD n) { if (buf && n) *buf = 0; return 0; }

// Window stubs
inline BOOL DestroyMenu(HMENU) { return FALSE; }
inline BOOL DestroyWindow(HWND) { return FALSE; }
inline ATOM RegisterClassExA(const WNDCLASSEXA*) { return 0; }
inline BOOL SetTimer(HWND, UINT_PTR, UINT, void*) { return FALSE; }
inline BOOL KillTimer(HWND, UINT_PTR) { return FALSE; }
inline BOOL PostThreadMessageA(DWORD, UINT, WPARAM, LPARAM) { return FALSE; }
inline HWND GetActiveWindow() { return 0; }
inline COLORREF GetSysColor(int) { return 0; }
inline int GetDeviceCaps(HDC, int) { return 0; }
inline HDC GetDC(HWND) { return 0; }
inline int ReleaseDC(HWND, HDC) { return 0; }
inline BOOL PostMessageA(HWND, UINT, WPARAM, LPARAM) { return FALSE; }
inline LRESULT SendMessageA(HWND, UINT, WPARAM, LPARAM) { return 0; }

extern volatile int g_quit_message_posted;
inline void PostQuitMessage(int) { g_quit_message_posted = 1; }
inline BOOL SetWindowTextW(HWND, LPCWSTR) { return FALSE; }
inline BOOL SetWindowTextA(HWND, LPCSTR) { return FALSE; }
inline HWND SetFocus(HWND) { return 0; }
inline BOOL InvalidateRect(HWND, const RECT*, BOOL) { return FALSE; }
inline BOOL IsBadWritePtr(void*, size_t) { return FALSE; }
inline LRESULT CallWindowProc(WNDPROC, HWND, UINT, WPARAM, LPARAM) { return 0; }
inline BOOL SetProp(HWND, LPCWSTR, HANDLE) { return FALSE; }
inline HANDLE GetProp(HWND, LPCWSTR) { return 0; }
inline LONG_PTR GetWindowLongPtr(HWND, int) { return 0; }
inline LONG_PTR SetWindowLongPtr(HWND, int, LONG_PTR) { return 0; }
inline HWND CreateWindowEx(DWORD, LPCWSTR, LPCWSTR, DWORD, int, int, int, int, HWND, HMENU, HINSTANCE, LPVOID) { return 0; }
#define CreateWindowExW CreateWindowEx
inline int MessageBoxA(HWND, LPCSTR, LPCSTR, UINT) { return IDOK; }
inline BOOL GetClientRect(HWND, RECT*) { return FALSE; }
inline BOOL GetWindowRect(HWND, RECT*) { return FALSE; }
inline BOOL EnableWindow(HWND, BOOL) { return FALSE; }
inline LRESULT SendMessageW(HWND, UINT, WPARAM, LPARAM) { return 0; }
inline BOOL PostMessageW(HWND, UINT, WPARAM, LPARAM) { return FALSE; }

// Message aliases
#define PostMessage PostMessageA
#define SendMessage SendMessageA

// Network shares stub
inline DWORD WNetOpenEnumA(DWORD, DWORD, DWORD, LPNETRESOURCEA, LPHANDLE) { return (DWORD)-1; }
inline DWORD WNetEnumResourceA(HANDLE, LPDWORD, LPVOID, LPDWORD) { return (DWORD)-1; }
inline DWORD WNetCloseEnum(HANDLE) { return 0; }
inline DWORD WNetConnectionDialogA(HWND, DWORD) { return (DWORD)-1; }
#define WNetConnectionDialog WNetConnectionDialogA

// UUID stubs
inline long UuidCreate(void *) { return -1; }
inline long UuidCreateSequential(void *) { return -1; }

// MultiByteToWideChar / WideCharToMultiByte stubs
inline int MultiByteToWideChar(UINT, DWORD, LPCSTR s, int slen, LPWSTR w, int wlen) {
  if (!s) return 0;
  size_t len = (slen == -1) ? strlen(s) : (size_t)slen;
  if (wlen == 0) return (int)(len + 1);
  size_t i;
  for (i = 0; i < len && (int)i < wlen - 1; i++)
    w[i] = (wchar_t)(unsigned char)s[i];
  if ((int)i < wlen) w[i] = 0;
  return (int)(i + 1);
}

inline int WideCharToMultiByte(UINT, DWORD, LPCWSTR w, int wlen, LPSTR s, int slen, LPCSTR, BOOL*) {
  if (!w) return 0;
  size_t len = (wlen == -1) ? wcslen(w) : (size_t)wlen;
  if (slen == 0) return (int)(len + 1);
  size_t i;
  for (i = 0; i < len && (int)i < slen - 1; i++)
    s[i] = (char)(w[i] & 0xff);
  if ((int)i < slen) s[i] = 0;
  return (int)(i + 1);
}

// SSL stubs
inline SECURITY_STATUS AcquireCredentialsHandleA(void*, void*, DWORD, void*, void*, void*, void*, CredHandle*, void*) { return -1; }
inline SECURITY_STATUS FreeCredentialsHandle(CredHandle*) { return 0; }
inline SECURITY_STATUS InitializeSecurityContextA(CredHandle*, CtxtHandle*, void*, DWORD, DWORD, DWORD, SecBufferDesc*, DWORD, CtxtHandle*, SecBufferDesc*, DWORD*, void*) { return -1; }
inline SECURITY_STATUS DeleteSecurityContext(CtxtHandle*) { return 0; }
inline SECURITY_STATUS QueryContextAttributesA(CtxtHandle*, DWORD, void*) { return -1; }
inline SECURITY_STATUS EncryptMessage(CtxtHandle*, DWORD, SecBufferDesc*, DWORD) { return -1; }
inline SECURITY_STATUS DecryptMessage(CtxtHandle*, SecBufferDesc*, DWORD, DWORD*) { return -1; }
inline SECURITY_STATUS FreeContextBuffer(void*) { return 0; }

// Debug output
inline void OutputDebugStringA(LPCSTR) {}

// Time zone
inline DWORD GetTimeZoneInformation(TIME_ZONE_INFORMATION *tzi) {
  memset(tzi, 0, sizeof(*tzi));
  return TIME_ZONE_ID_UNKNOWN;
}
inline void GetLocalTime(SYSTEMTIME *st) {
  time_t t = time(0);
  struct tm *tm = localtime(&t);
  st->wYear = tm->tm_year + 1900; st->wMonth = tm->tm_mon + 1;
  st->wDay = tm->tm_mday; st->wDayOfWeek = tm->tm_wday;
  st->wHour = tm->tm_hour; st->wMinute = tm->tm_min;
  st->wSecond = tm->tm_sec; st->wMilliseconds = 0;
}

// File operations
inline BOOL GetFileTime(HANDLE, FILETIME*, FILETIME*, FILETIME*) { return FALSE; }
inline DWORD SetFilePointer(HANDLE h, LONG lo, LONG* hi, DWORD method) {
  int whence = (method == 0) ? SEEK_SET : (method == 1) ? SEEK_CUR : SEEK_END;
  off_t offset = (off_t)(unsigned long)lo;
  if (hi) offset |= (off_t)(*hi) << 32;
  off_t r = lseek((int)(intptr_t)h, offset, whence);
  if (r == (off_t)-1) { if (hi) *hi = -1; return (DWORD)-1; }
  if (hi) *hi = (LONG)(r >> 32);
  return (DWORD)r;
}
inline BOOL SetEndOfFile(HANDLE h) {
  off_t pos = lseek((int)(intptr_t)h, 0, SEEK_CUR);
  if (pos == (off_t)-1) return FALSE;
  return ftruncate((int)(intptr_t)h, pos) == 0;
}
inline DWORD GetDriveTypeW(LPCWSTR) { return 0; }
inline BOOL CopyFileA(LPCSTR, LPCSTR, BOOL) { return FALSE; }

// BY_HANDLE_FILE_INFORMATION
typedef struct _BY_HANDLE_FILE_INFORMATION {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastAccessTime;
  FILETIME ftLastWriteTime;
  DWORD dwVolumeSerialNumber;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
  DWORD nNumberOfLinks;
  DWORD nFileIndexHigh;
  DWORD nFileIndexLow;
} BY_HANDLE_FILE_INFORMATION;
inline BOOL GetFileInformationByHandle(HANDLE, BY_HANDLE_FILE_INFORMATION*) { return FALSE; }

// User
inline BOOL GetUserNameA(LPSTR buf, DWORD *len) {
  const char *user = getenv("USER");
  if (!user) user = getenv("LOGNAME");
  if (user && buf && len) {
    DWORD l = (DWORD)strlen(user);
    if (l < *len) { strcpy(buf, user); *len = l; return TRUE; }
  }
  return FALSE;
}

// Window placement
inline BOOL GetWindowPlacement(HWND, WINDOWPLACEMENT*) { return FALSE; }

// Text detection
inline BOOL IsTextUnicode(const void*, int, int*) { return FALSE; }

// Global memory (used by ColorDialog.h)
inline BOOL GlobalUnlock(HGLOBAL) { return FALSE; }
inline HGLOBAL GlobalFree(HGLOBAL) { return 0; }

// Dialog
inline BOOL IsDialogMessage(HWND, MSG*) { return FALSE; }

// Misc stubs
inline void Sleep(DWORD ms) { usleep(ms * 1000); }
inline DWORD GetEnvironmentVariableA(LPCSTR name, LPSTR buf, DWORD n) {
  const char *val = getenv(name);
  if (!val) return 0;
  DWORD len = (DWORD)strlen(val);
  if (len < n) { strcpy(buf, val); return len; }
  return len + 1;
}
inline BOOL SetEnvironmentVariableA(LPCSTR name, LPCSTR val) {
  if (val) return setenv(name, val, 1) == 0;
  else return unsetenv(name) == 0;
}
inline DWORD ExpandEnvironmentStringsW(LPCWSTR src, LPWSTR dst, DWORD n) {
  // Minimal: just copy
  size_t l = 0;
  while (src[l]) l++;
  if (dst && n) {
    size_t i = 0;
    for (; i < l && i < n - 1; i++) dst[i] = src[i];
    dst[i] = 0;
  }
  return (DWORD)(l + 1);
}
inline int GetSystemMetrics(int) { return 0; }
inline LONG RegOpenKeyExW(HKEY, LPCWSTR, DWORD, DWORD, HKEY*) { return 1; }
inline LONG RegQueryValueExW(HKEY, LPCWSTR, DWORD*, DWORD*, BYTE*, DWORD*) { return 1; }
inline LONG RegCloseKey(HKEY) { return 0; }
inline LONG RegCreateKeyExW(HKEY, LPCWSTR, DWORD, LPWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, HKEY*, DWORD*) { return 1; }
inline LONG RegSetValueExW(HKEY, LPCWSTR, DWORD, DWORD, const BYTE*, DWORD) { return 1; }
inline LONG RegDeleteValueW(HKEY, LPCWSTR) { return 1; }
inline LONG RegDeleteKeyW(HKEY, LPCWSTR) { return 1; }
inline LONG RegEnumKeyExW(HKEY, DWORD, LPWSTR, DWORD*, DWORD*, LPWSTR, DWORD*, FILETIME*) { return 1; }
inline LONG RegEnumValueW(HKEY, DWORD, LPWSTR, DWORD*, DWORD*, DWORD*, BYTE*, DWORD*) { return 1; }
inline LONG RegQueryInfoKeyW(HKEY, LPWSTR, DWORD*, DWORD*, DWORD*, DWORD*, DWORD*, DWORD*, DWORD*, DWORD*, DWORD*, FILETIME*) { return 1; }

// GDI stubs
inline HGDIOBJ SelectObject(HDC, HGDIOBJ) { return 0; }
inline BOOL DeleteObject(HGDIOBJ) { return FALSE; }
inline BOOL GetTextExtentPoint32A(HDC, LPCSTR, int, SIZE*) { return FALSE; }
inline BOOL GetTextExtentPoint32W(HDC, LPCWSTR, int, SIZE*) { return FALSE; }

// Key state
#define VK_SHIFT   0x10
#define VK_CONTROL 0x11
#define VK_MENU    0x12
inline short GetKeyState(int) { return 0; }

// Page constants for CreateFileMapping
#define PAGE_READONLY 0x02
#define PAGE_READWRITE 0x04
#define PAGE_NOACCESS 0x01
#define FILE_MAP_READ 0x04
#define FILE_MAP_WRITE 0x02

// VirtualAlloc/VirtualFree
#define MEM_COMMIT    0x1000
#define MEM_RESERVE   0x2000
#define MEM_DECOMMIT  0x4000
#define MEM_RELEASE   0x8000

// GDI raster ops
#define PATINVERT 0x005A0049

typedef struct _SYSTEM_INFO {
  DWORD dwPageSize;
  LPVOID lpMinimumApplicationAddress;
  LPVOID lpMaximumApplicationAddress;
  DWORD_PTR dwActiveProcessorMask;
  DWORD dwNumberOfProcessors;
  DWORD dwProcessorType;
  DWORD dwAllocationGranularity;
  WORD wProcessorLevel;
  WORD wProcessorRevision;
} SYSTEM_INFO;

inline void GetSystemInfo(SYSTEM_INFO *si) {
  long pgsz = sysconf(_SC_PAGESIZE);
  si->dwPageSize = (pgsz > 0) ? (DWORD)pgsz : 4096;
  // Allocation granularity: use max(page_size, 65536) so that
  // VirtualAlloc reservations are at least 64KB-aligned.
  si->dwAllocationGranularity = (si->dwPageSize > 65536) ? si->dwPageSize : 65536;
  si->dwNumberOfProcessors = 1;
}

// VirtualAlloc/VirtualFree using mmap
//
// Windows VirtualAlloc guarantees MEM_RESERVE returns addresses aligned to
// dwAllocationGranularity (64KB). The xyzzy allocator (alloc.cc) depends on
// this alignment for page management and GC bit tracking.
// Linux mmap only guarantees page (4KB) alignment, so we over-allocate and
// align manually for MEM_RESERVE.
//
// We also track the original mmap base/size for proper munmap on MEM_RELEASE
// (Windows allows size=0 to release the whole region; munmap needs exact range).
#include <sys/mman.h>
#include <stdlib.h>

// Track reserved regions for proper cleanup
struct _VirtualAllocInfo {
  void *mmap_base;    // original mmap return
  size_t mmap_size;   // original mmap size
  void *aligned_base; // aligned address returned to caller
  size_t region_size; // requested size
  _VirtualAllocInfo *next;
};
static _VirtualAllocInfo *_va_regions = nullptr;

// Return the OS allocation granularity (max of page size and 64KB).
// Cached after first call.
static inline size_t _va_granularity() {
  static size_t g = 0;
  if (!g) {
    long pgsz = sysconf(_SC_PAGESIZE);
    size_t pg = (pgsz > 0) ? (size_t)pgsz : 4096;
    g = (pg > 65536) ? pg : 65536;
  }
  return g;
}

inline LPVOID VirtualAlloc(LPVOID addr, size_t size, DWORD type, DWORD protect) {
  int prot = PROT_NONE;
  if (protect == PAGE_READWRITE) prot = PROT_READ | PROT_WRITE;
  if (type & MEM_COMMIT) prot = PROT_READ | PROT_WRITE;

  if (addr) {
    // MEM_COMMIT within existing reservation.
    // On Linux, MAP_FIXED can overwrite an existing PROT_NONE mapping.
    // On macOS, mprotect is the correct approach for already-reserved pages.
    if (mprotect(addr, size, prot) == 0)
      return addr;
    // Fallback for cases where the region wasn't previously mapped (e.g. MEM_RESERVE+MEM_COMMIT)
    void *p = mmap(addr, size, prot, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
    return (p == MAP_FAILED) ? 0 : p;
  }

  // MEM_RESERVE (new allocation): need alignment-aligned address.
  // Use the OS allocation granularity (at least 64KB, or page size on
  // systems with larger pages like Apple Silicon with 16KB pages).
  size_t alignment = _va_granularity();
  size_t alloc_size = size + alignment - 1;
  void *raw = mmap(NULL, alloc_size, prot, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (raw == MAP_FAILED) return 0;

  // Align up to granularity boundary
  void *aligned = (void *)(((uintptr_t)raw + alignment - 1) & ~(alignment - 1));

  // Trim excess at front and back
  size_t front = (uintptr_t)aligned - (uintptr_t)raw;
  size_t back = alloc_size - front - size;
  if (front > 0) munmap(raw, front);
  if (back > 0) munmap((void *)((uintptr_t)aligned + size), back);

  // Track for MEM_RELEASE (which passes size=0)
  _VirtualAllocInfo *info = (_VirtualAllocInfo *)malloc(sizeof(_VirtualAllocInfo));
  if (info) {
    info->mmap_base = aligned;
    info->mmap_size = size;
    info->aligned_base = aligned;
    info->region_size = size;
    info->next = _va_regions;
    _va_regions = info;
  }

  return (LPVOID)aligned;
}

inline BOOL VirtualFree(LPVOID addr, size_t size, DWORD type) {
  if (type == MEM_DECOMMIT) {
    // Make pages inaccessible (like Windows MEM_DECOMMIT)
    return mprotect(addr, size, PROT_NONE) == 0;
  }
  if (type == MEM_RELEASE) {
    // Find tracked region (Windows allows size=0 to free whole region)
    _VirtualAllocInfo **pp = &_va_regions;
    while (*pp) {
      if ((*pp)->aligned_base == addr) {
        _VirtualAllocInfo *info = *pp;
        *pp = info->next;
        BOOL result = munmap(info->mmap_base, info->mmap_size) == 0;
        ::free(info);
        return result;
      }
      pp = &(*pp)->next;
    }
    // Not tracked - try direct munmap with given size
    if (size > 0) return munmap(addr, size) == 0;
    return FALSE;
  }
  return FALSE;
}

// GDI stubs
inline BOOL PatBlt(HDC, int, int, int, int, DWORD) { return FALSE; }

// Winsock stubs
inline int WSAStartup(WORD, LPWSADATA) { return 0; }
inline int WSACleanup() { return 0; }
inline int WSAGetLastError() { return errno; }

// _beginthreadex stub
inline uintptr_t _beginthreadex(void*, unsigned, unsigned int (*)(void*), void*, unsigned, unsigned*) { return 0; }

// Missing MSVC-isms
#ifndef _MSC_VER
#include <cmath>
#define _finite std::isfinite
#define _isnan std::isnan
#define _copysign copysign
#define _chgsign(x) (-(x))
#define stricmp strcasecmp
#define strnicmp strncasecmp
#define memicmp(a,b,n) strncasecmp((const char*)(a),(const char*)(b),(n))
#define _memicmp(a,b,n) strncasecmp((const char*)(a),(const char*)(b),(n))
#define _environ environ
extern char **environ;
#define _putenv(s) putenv(s)

// MSVC float classification
#include <cfloat>
inline char *_ecvt(double value, int ndigit, int *dec, int *sign) { return ecvt(value, ndigit, dec, sign); }
inline int _fpclass(double x) {
  if (std::isinf(x)) return x < 0 ? 0x0004 : 0x0200;
  if (std::isnan(x)) return 0;
  return 0x0100; // normal
}
#define _FPCLASS_NINF  0x0004
#define _FPCLASS_PINF  0x0200

// FormatMessage
#define FORMAT_MESSAGE_FROM_SYSTEM 0x00001000
#define FORMAT_MESSAGE_ARGUMENT_ARRAY 0x00002000
#define FORMAT_MESSAGE_MAX_WIDTH_MASK 0x000000FF
inline DWORD FormatMessageW(DWORD, LPCVOID, DWORD, DWORD, LPWSTR buf, DWORD n, ...) {
  if (buf && n) *buf = 0;
  return 0;
}
inline LANGID GetUserDefaultLangID() { return 0; }
#define wsprintfA sprintf

// Window DC
#define DCX_WINDOW      0x00000001
#define DCX_CLIPSIBLINGS 0x00000010
#define DCX_CACHE       0x00000002
#define DCX_LOCKWINDOWUPDATE 0x00000400
inline HDC GetDCEx(HWND, HRGN, DWORD) { return 0; }
inline BOOL LockWindowUpdate(HWND) { return FALSE; }
#endif

// _open, _close, _read, _write, _lseek, _eof
#define _open open
#define _close close
#define _read read
#define _write write
#define _lseek lseek
inline int _eof(int fd) { off_t cur = lseek(fd, 0, SEEK_CUR); off_t end = lseek(fd, 0, SEEK_END); lseek(fd, cur, SEEK_SET); return cur >= end; }
#include <fcntl.h>
#ifndef _O_RDONLY
#define _O_RDONLY O_RDONLY
#define _O_WRONLY O_WRONLY
#define _O_RDWR   O_RDWR
#define _O_CREAT  O_CREAT
#define _O_TRUNC  O_TRUNC
#define _O_APPEND O_APPEND
#define _O_BINARY 0
#define _O_TEXT   0
#define _O_SEQUENTIAL 0
#define _O_NOINHERIT 0
#endif
#ifndef O_BINARY
#define O_BINARY 0
#endif
#ifndef _SH_DENYNO
#define _SH_DENYNO 0
#define _SH_DENYWR 0
#define _SH_DENYRW 0
#endif
inline int _isatty(int fd) { return isatty(fd); }
#define _fileno fileno

// _get_osfhandle / _open_osfhandle (stubs)
inline intptr_t _get_osfhandle(int fd) { return (intptr_t)(intptr_t)fd; }
inline int _open_osfhandle(intptr_t h, int) { return (int)h; }

// _heapmin (MSVC heap minimization - no-op on Linux)
inline int _heapmin() { return 0; }

// _filelength (get file length from fd)
inline long _filelength(int fd) {
  struct stat st;
  if (fstat(fd, &st) == 0) return (long)st.st_size;
  return -1L;
}

// _fsopen (fopen with sharing mode - ignore sharing on Linux)
#include <stdio.h>
inline FILE *_fsopen(const char *filename, const char *mode, int) {
  return fopen(filename, mode);
}

// share.h compat
#ifndef _SH_COMPAT
#define _SH_COMPAT 0
#endif

#endif // !_WIN32

#endif // _platform_h_
