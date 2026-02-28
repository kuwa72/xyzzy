;;; -*- Mode: Lisp; Package: WINAPI -*-
;;; winapi.l --- treeview

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/10/21 17:09:05 +0900>

;;; Code:

(provide "wip/treeview/winapi")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi"))

(in-package "winapi")

;; WINNT.H
(*define-c-type LPSTR    LPTSTR)
(*define-c-type LPCSTR   LPCTSTR)
(*define-c-type (WCHAR *) LPWSTR)

;; WINUSER.H
(*define-dll-entry HWND SetFocus (HWND) "user32")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TreeView
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COMMCTRL.H
(*define TV_FIRST                #x1100); // TreeView messages

;#define TVN_FIRST               (0U-400U)       // treeview
;#define TVN_LAST                (0U-499U)

(*define WC_TREEVIEWA            "SysTreeView32")
(*define WC_TREEVIEW             WC_TREEVIEWA)

;// begin_r_commctrl
(*define TVS_HASBUTTONS          #x0001)
(*define TVS_HASLINES            #x0002)
(*define TVS_LINESATROOT         #x0004)
(*define TVS_EDITLABELS          #x0008)
(*define TVS_DISABLEDRAGDROP     #x0010)
(*define TVS_SHOWSELALWAYS       #x0020)
(*define TVS_RTLREADING          #x0040)
(*define TVS_NOTOOLTIPS          #x0080)
(*define TVS_CHECKBOXES          #x0100)
(*define TVS_TRACKSELECT         #x0200)
(*define TVS_SINGLEEXPAND        #x0400)
(*define TVS_INFOTIP             #x0800)
(*define TVS_FULLROWSELECT       #x1000)
(*define TVS_NOSCROLL            #x2000)
(*define TVS_NONEVENHEIGHT       #x4000)
(*define TVS_NOHSCROLL           #x8000)
;// end_r_commctrl

(*define-c-type HANDLE   HTREEITEM)

(*define TVIF_TEXT               #x0001)
(*define TVIF_IMAGE              #x0002)
(*define TVIF_PARAM              #x0004)
(*define TVIF_STATE              #x0008)
(*define TVIF_HANDLE             #x0010)
(*define TVIF_SELECTEDIMAGE      #x0020)
(*define TVIF_CHILDREN           #x0040)
(*define TVIF_INTEGRAL           #x0080)

(*define TVIS_SELECTED           #x0002)
(*define TVIS_CUT                #x0004)
(*define TVIS_DROPHILITED        #x0008)
(*define TVIS_BOLD               #x0010)
(*define TVIS_EXPANDED           #x0020)
(*define TVIS_EXPANDEDONCE       #x0040)
(*define TVIS_EXPANDPARTIAL      #x0080)
(*define TVIS_OVERLAYMASK        #x0F00)
(*define TVIS_STATEIMAGEMASK     #xF000)
(*define TVIS_USERMASK           #xF000)

(*define-c-struct TVITEMA
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPSTR     pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        ))
(*define-c-type (TVITEMA *) LPTVITEMA)

(*define-c-struct TVITEMW
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPWSTR    pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        ))
(*define-c-type (TVITEMW *) LPTVITEMW)

(*define-c-struct TVITEM
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPSTR     pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        ))
(*define-c-type (TVITEM *) LPTVITEM)

(*define-c-struct TVITEMEXA
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPSTR     pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        )
  (int       iIntegral     ))
(*define-c-type (TVITEMEXA *) LPTVITEMEXA)

(*define-c-struct TVITEMEXW
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPWSTR    pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        )
  (int       iIntegral     ))
(*define-c-type (TVITEMEXW *) LPTVITEMEXW)

(*define-c-struct TVITEMEX
  (UINT      mask          )
  (HTREEITEM hItem         )
  (UINT      state         )
  (UINT      stateMask     )
  (LPSTR     pszText       )
  (int       cchTextMax    )
  (int       iImage        )
  (int       iSelectedImage)
  (int       cChildren     )
  (LPARAM    lParam        )
  (int       iIntegral     ))
(*define-c-type (TVITEMEX *) LPTVITEMEX)

;#define TVI_ROOT                ((HTREEITEM)0xFFFF0000)
;#define TVI_FIRST               ((HTREEITEM)0xFFFF0001)
;#define TVI_LAST                ((HTREEITEM)0xFFFF0002)
;#define TVI_SORT                ((HTREEITEM)0xFFFF0003)
(*define TVI_ROOT                (- 0 #x10000))
(*define TVI_FIRST               (- 0 #x0FFFF))
(*define TVI_LAST                (- 0 #x0FFFE))
(*define TVI_SORT                (- 0 #x0FFFD))

(*define-c-struct TVINSERTSTRUCTA
  (HTREEITEM hParent     )
  (HTREEITEM hInsertAfter)
  (TVITEMEXA itemex      ))
(*define-c-type (TVINSERTSTRUCTA *) LPTVINSERTSTRUCTA)

(*define-c-struct TVINSERTSTRUCTW
  (HTREEITEM hParent     )
  (HTREEITEM hInsertAfter)
  (TVITEMEXW itemex      ))
(*define-c-type (TVINSERTSTRUCTW *) LPTVINSERTSTRUCTW)

(*define-c-struct TVINSERTSTRUCT
  (HTREEITEM hParent     )
  (HTREEITEM hInsertAfter)
  (TVITEMEX  itemex      ))
(*define-c-type (TVINSERTSTRUCT *) LPTVINSERTSTRUCT)

(*define TVM_INSERTITEMA         (+ TV_FIRST 0))
(*define TVM_INSERTITEMW         (+ TV_FIRST 50))
(*define TVM_INSERTITEM          TVM_INSERTITEMA)
(*define TVM_DELETEITEM          (+ TV_FIRST 1))
(*define TVM_EXPAND              (+ TV_FIRST 2))

(*define TVE_COLLAPSE            #x0001)
(*define TVE_EXPAND              #x0002)
(*define TVE_TOGGLE              #x0003)
(*define TVE_EXPANDPARTIAL       #x4000)
(*define TVE_COLLAPSERESET       #x8000)

(*define TVM_GETITEMRECT         (+ TV_FIRST 4))
(*define TVM_GETCOUNT            (+ TV_FIRST 5))
(*define TVM_GETINDENT           (+ TV_FIRST 6))
(*define TVM_SETINDENT           (+ TV_FIRST 7))
(*define TVM_GETIMAGELIST        (+ TV_FIRST 8))

(*define TVSIL_NORMAL            0)
(*define TVSIL_STATE             2)

(*define TVM_SETIMAGELIST        (+ TV_FIRST 9))
(*define TVM_GETNEXTITEM         (+ TV_FIRST 10))

(*define TVGN_ROOT               #x0000)
(*define TVGN_NEXT               #x0001)
(*define TVGN_PREVIOUS           #x0002)
(*define TVGN_PARENT             #x0003)
(*define TVGN_CHILD              #x0004)
(*define TVGN_FIRSTVISIBLE       #x0005)
(*define TVGN_NEXTVISIBLE        #x0006)
(*define TVGN_PREVIOUSVISIBLE    #x0007)
(*define TVGN_DROPHILITE         #x0008)
(*define TVGN_CARET              #x0009)
(*define TVGN_LASTVISIBLE        #x000A)

(*define TVM_SELECTITEM          (+ TV_FIRST 11))

(*define TVM_GETITEMA            (+ TV_FIRST 12))
(*define TVM_GETITEMW            (+ TV_FIRST 62))
(*define TVM_GETITEM             TVM_GETITEMA)

(*define TVM_SETITEMA            (+ TV_FIRST 13))
(*define TVM_SETITEMW            (+ TV_FIRST 63))
(*define TVM_SETITEM             TVM_SETITEMA)

(*define TVM_EDITLABELA          (+ TV_FIRST 14))
(*define TVM_EDITLABELW          (+ TV_FIRST 65))
(*define TVM_EDITLABEL           TVM_EDITLABELA)

(*define TVM_GETEDITCONTROL      (+ TV_FIRST 15))
(*define TVM_GETVISIBLECOUNT     (+ TV_FIRST 16))
(*define TVM_HITTEST             (+ TV_FIRST 17))

(*define-c-struct TVHITTESTINFO
  (POINT     pt   )
  (UINT      flags)
  (HTREEITEM hItem))

(*define TVHT_NOWHERE            #x0001)
(*define TVHT_ONITEMICON         #x0002)
(*define TVHT_ONITEMLABEL        #x0004)
(*define TVHT_ONITEMINDENT       #x0008)
(*define TVHT_ONITEMBUTTON       #x0010)
(*define TVHT_ONITEMRIGHT        #x0020)
(*define TVHT_ONITEMSTATEICON    #x0040)
(*define TVHT_ONITEM             (logior TVHT_ONITEMICON TVHT_ONITEMLABEL TVHT_ONITEMSTATEICON))

(*define TVHT_ABOVE              #x0100)
(*define TVHT_BELOW              #x0200)
(*define TVHT_TORIGHT            #x0400)
(*define TVHT_TOLEFT             #x0800)

(*define TVM_CREATEDRAGIMAGE     (+ TV_FIRST 18))
(*define TVM_SORTCHILDREN        (+ TV_FIRST 19))
(*define TVM_ENSUREVISIBLE       (+ TV_FIRST 20))
(*define TVM_SORTCHILDRENCB      (+ TV_FIRST 21))
(*define TVM_ENDEDITLABELNOW     (+ TV_FIRST 22))

(*define TVM_GETISEARCHSTRINGA   (+ TV_FIRST 23))
(*define TVM_GETISEARCHSTRINGW   (+ TV_FIRST 64))
(*define TVM_GETISEARCHSTRING    TVM_GETISEARCHSTRINGA)

(*define TVM_SETTOOLTIPS         (+ TV_FIRST 24))
(*define TVM_GETTOOLTIPS         (+ TV_FIRST 25))
(*define TVM_SETINSERTMARK       (+ TV_FIRST 26))

;#define TVM_SETUNICODEFORMAT     CCM_SETUNICODEFORMAT
;#define TVM_GETUNICODEFORMAT     CCM_GETUNICODEFORMAT

(*define TVM_SETITEMHEIGHT       (+ TV_FIRST 27))
(*define TVM_GETITEMHEIGHT       (+ TV_FIRST 28))
(*define TVM_SETBKCOLOR          (+ TV_FIRST 29))
(*define TVM_SETTEXTCOLOR        (+ TV_FIRST 30))
(*define TVM_GETBKCOLOR          (+ TV_FIRST 31))
(*define TVM_GETTEXTCOLOR        (+ TV_FIRST 32))
(*define TVM_SETSCROLLTIME       (+ TV_FIRST 33))
(*define TVM_GETSCROLLTIME       (+ TV_FIRST 34))

(*define TVM_SETINSERTMARKCOLOR  (+ TV_FIRST 37))
(*define TVM_GETINSERTMARKCOLOR  (+ TV_FIRST 38))

#|
;; typedef int (CALLBACK *PFNTVCOMPARE)(LPARAM lParam1, LPARAM lParam2, LPARAM lParamSort);
The callback function must return a negative value if the first item should
precede the second, a positive value if the first item should follow the
second, or zero if the two items are equivalent.

The lParam1 and lParam2 parameters correspond to the lParam member of the
TVITEM structure for the two items being compared. The lParamSort parameter
corresponds to the lParam member of this structure.
|#
(*define-c-type (void *) PFNTVCOMPARE)
(*define-c-struct TVSORTCB
  (HTREEITEM    hParent)
  (PFNTVCOMPARE lpfnCompare)
  (LPARAM       lParam))
(*define-c-type (TVSORTCB *) LPTVSORTCB)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINUSER.H
; Scroll Bar Constants
(*define SB_HORZ             0)
(*define SB_VERT             1)
(*define SB_CTL              2)
(*define SB_BOTH             3)

; Scroll Bar Commands
(*define SB_LINEUP           0)
(*define SB_LINELEFT         0)
(*define SB_LINEDOWN         1)
(*define SB_LINERIGHT        1)
(*define SB_PAGEUP           2)
(*define SB_PAGELEFT         2)
(*define SB_PAGEDOWN         3)
(*define SB_PAGERIGHT        3)
(*define SB_THUMBPOSITION    4)
(*define SB_THUMBTRACK       5)
(*define SB_TOP              6)
(*define SB_LEFT             6)
(*define SB_BOTTOM           7)
(*define SB_RIGHT            7)
(*define SB_ENDSCROLL        8)

(*define WM_HSCROLL          #x0114)
(*define WM_VSCROLL          #x0115)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; F
(*define CLR_NONE                #xFFFFFFFF)
(*define CLR_DEFAULT             #xFF000000)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(*define-dll-entry BOOL RedrawWindow (HWND (RECT *) HRGN UINT) "user32")

(*define RDW_INVALIDATE          #x0001)
(*define RDW_INTERNALPAINT       #x0002)
(*define RDW_ERASE               #x0004)

(*define RDW_VALIDATE            #x0008)
(*define RDW_NOINTERNALPAINT     #x0010)
(*define RDW_NOERASE             #x0020)

(*define RDW_NOCHILDREN          #x0040)
(*define RDW_ALLCHILDREN         #x0080)

(*define RDW_UPDATENOW           #x0100)
(*define RDW_ERASENOW            #x0200)

(*define RDW_FRAME               #x0400)
(*define RDW_NOFRAME             #x0800)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; WINUSER.H
(*define-dll-entry HWND WindowFromPoint (LONG LONG) "user32")
(*define-dll-entry BOOL GetWindowRect (HWND (RECT *)) "user32")
(*define-dll-entry BOOL IsZoomed (HWND) "user32")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mouse_event
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINUSER.H
(*define MOUSEEVENTF_MOVE        #x0001) ; mouse move
(*define MOUSEEVENTF_LEFTDOWN    #x0002) ; left button down
(*define MOUSEEVENTF_LEFTUP      #x0004) ; left button up
(*define MOUSEEVENTF_RIGHTDOWN   #x0008) ; right button down
(*define MOUSEEVENTF_RIGHTUP     #x0010) ; right button up
(*define MOUSEEVENTF_MIDDLEDOWN  #x0020) ; middle button down
(*define MOUSEEVENTF_MIDDLEUP    #x0040) ; middle button up
(*define MOUSEEVENTF_WHEEL       #x0800) ; wheel button rolled
(*define MOUSEEVENTF_ABSOLUTE    #x8000) ; absolute move

(*define-dll-entry LPVOID mouse_event (DWORD DWORD DWORD DWORD DWORD) "user32")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CursorPos
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINUSER.H
(*define-dll-entry BOOL SetCursorPos (int int) "user32")
(*define-dll-entry BOOL GetCursorPos ((POINT *)) "user32")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; focus
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINUSER.H
(*define-dll-entry HWND GetFocus () "user32")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; style
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINUSER.H
(*define GWL_WNDPROC     -4)
(*define GWL_HINSTANCE   -6)
(*define GWL_HWNDPARENT  -8)
(*define GWL_STYLE      -16)
(*define GWL_EXSTYLE    -20)
(*define GWL_USERDATA   -21)
(*define GWL_ID         -12)

(*define-dll-entry LONG GetWindowLong (HWND int)
  "user32" "GetWindowLongA")
(*define-dll-entry LONG SetWindowLong (HWND int LONG)
  "user32" "SetWindowLongA")

;; WINDOWSX.H
(export '(GetWindowStyle))
(defun GetWindowStyle (hwnd)
  (GetWindowLong hwnd GWL_STYLE))

(export '(GetWindowExStyle))
(defun GetWindowExStyle (hwnd)
  (GetWindowLong hwnd GWL_EXSTYLE))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; font
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINNT.H
(*define-dll-entry void RtlMoveMemory ((void *) (void *) size_t) "Kernel32")

;; WINDEF.H
(*define FALSE 0)
(*define TRUE 1)

;; WINDOWSX.H
(*define WM_SETFONT          #x0030)
(*define WM_GETFONT          #x0031)

(export '(SetWindowFont))
(defun SetWindowFont (hwnd hfont fRedraw)
  (SendMessage hwnd WM_SETFONT hfont fRedraw))
(export '(GetWindowFont))
(defun GetWindowFont (hwnd)
  (SendMessage hwnd WM_GETFONT 0 0))

;; WINGDI.H
(*define-c-struct FONTSIGNATURE
  (DWORD fsUsb 4)
  (DWORD fsCsb 2))

(*define-c-struct NEWTEXTMETRIC
  (LONG  tmHeight)
  (LONG  tmAscent)
  (LONG  tmDescent)
  (LONG  tmInternalLeading)
  (LONG  tmExternalLeading)
  (LONG  tmAveCharWidth)
  (LONG  tmMaxCharWidth)
  (LONG  tmWeight)
  (LONG  tmOverhang)
  (LONG  tmDigitizedAspectX)
  (LONG  tmDigitizedAspectY)
  (BYTE  tmFirstChar)
  (BYTE  tmLastChar)
  (BYTE  tmDefaultChar)
  (BYTE  tmBreakChar)
  (BYTE  tmItalic)
  (BYTE  tmUnderlined)
  (BYTE  tmStruckOut)
  (BYTE  tmPitchAndFamily)
  (BYTE  tmCharSet)
  (DWORD ntmFlags)
  (UINT  ntmSizeEM)
  (UINT  ntmCellHeight)
  (UINT  ntmAvgWidth))

(*define-c-struct NEWTEXTMETRICEX
  (NEWTEXTMETRIC ntmTm)
  (FONTSIGNATURE ntmFontSig))

(*define LF_FULLFACESIZE 64)
(*define-c-struct ENUMLOGFONTEX
  (LOGFONT     elfLogFont)
  (BYTE        elfFullName LF_FULLFACESIZE)
  (BYTE        elfStyle LF_FACESIZE)
  (BYTE        elfScript LF_FACESIZE))
(*define-c-type (ENUMLOGFONTEX *) LPENUMLOGFONTEX)

;/* Font Weights */
(*define FW_DONTCARE         0)
(*define FW_THIN             100)
(*define FW_EXTRALIGHT       200)
(*define FW_LIGHT            300)
(*define FW_NORMAL           400)
(*define FW_MEDIUM           500)
(*define FW_SEMIBOLD         600)
(*define FW_BOLD             700)
(*define FW_EXTRABOLD        800)
(*define FW_HEAVY            900)

(*define FW_ULTRALIGHT       FW_EXTRALIGHT)
(*define FW_REGULAR          FW_NORMAL)
(*define FW_DEMIBOLD         FW_SEMIBOLD)
(*define FW_ULTRABOLD        FW_EXTRABOLD)
(*define FW_BLACK            FW_HEAVY)

;/* EnumFonts Masks */
(*define RASTER_FONTTYPE     #x0001)
(*define DEVICE_FONTTYPE     #x002)
(*define TRUETYPE_FONTTYPE   #x004)

;/* Stock Logical Objects */
(*define WHITE_BRUSH         0)
(*define LTGRAY_BRUSH        1)
(*define GRAY_BRUSH          2)
(*define DKGRAY_BRUSH        3)
(*define BLACK_BRUSH         4)
(*define NULL_BRUSH          5)
(*define HOLLOW_BRUSH        NULL_BRUSH)
(*define WHITE_PEN           6)
(*define BLACK_PEN           7)
(*define NULL_PEN            8)
(*define OEM_FIXED_FONT      10)
(*define ANSI_FIXED_FONT     11)
(*define ANSI_VAR_FONT       12)
(*define SYSTEM_FONT         13)
(*define DEVICE_DEFAULT_FONT 14)
(*define DEFAULT_PALETTE     15)
(*define SYSTEM_FIXED_FONT   16)
;#if(WINVER >= 0x0400)
(*define DEFAULT_GUI_FONT    17)
;#endif /* WINVER >= 0x0400 */
;#if (_WIN32_WINNT >= 0x0500)
(*define DC_BRUSH            18)
(*define DC_PEN              19)
;#endif
;#if (_WIN32_WINNT >= 0x0500)
(*define STOCK_LAST          19)
;#elif (WINVER >= 0x0400)
(*define STOCK_LAST          17)
;#else
(*define STOCK_LAST          16)
;#endif
(*define CLR_INVALID         #xFFFFFFFF)

(*define-c-type FARPROC FONTENUMPROC)
(*define-c-type (LOGFONT *) LPLOGFONT)

;#if(WINVER >= 0x0400)
(*define-dll-entry int EnumFontFamiliesEx
  (HDC LPLOGFONT FONTENUMPROC LPARAM DWORD) "gdi32" "EnumFontFamiliesExA")
;#endif /* WINVER >= 0x0400 */
(*define-dll-entry int EnumFontFamilies
  (HDC LPCSTR FONTENUMPROC LPARAM) "gdi32" "EnumFontFamiliesA")

#|
 |int CALLBACK EnumFontFamExProc(
 |	ENUMLOGFONTEX *lpelfe,
 |	NEWTEXTMETRICEX *lpntme,
 |	int FontType , LPARAM lParam
 |);
 |#

(*define-dll-entry HGDIOBJ GetStockObject (c:int) "gdi32")

;;; winapi.l ends here
