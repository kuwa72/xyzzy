;;; -*- Mode: Lisp; Package: WINAPI ; Encoding: utf-8 -*-
;;; virtual-keys.l --- Virtual Keys, Standard Set

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 13:06:47 +0900>

;;; Code:

(provide "wip/treeview/virtual-keys")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi"))
(require "keyboard")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package "winapi")

;; winuser.h
(*define VK_LBUTTON        #x01); マウス左ボタン
(*define VK_RBUTTON        #x02); マウス右ボタン
(*define VK_CANCEL         #x03); Ctrl-Break
(*define VK_MBUTTON        #x04); マウス中央ボタン

(*define VK_XBUTTON1       #x05);
(*define VK_XBUTTON2       #x06);

; #x07 unassigned

(*define VK_BACK           #x08); Backspace
(*define VK_TAB            #x09); Tab

; #x0A - #x0B reserved

(*define VK_CLEAR          #x0C); NumLock を外した状態のテンキー5
(*define VK_RETURN         #x0D); Enter

(*define VK_SHIFT          #x10); Shift
(*define VK_CONTROL        #x11); Ctrl
(*define VK_MENU           #x12); Alt
(*define VK_PAUSE          #x13); Pause
(*define VK_CAPITAL        #x14); Caps Lock

(*define VK_KANA           #x15)
(*define VK_HANGEUL        #x15)
(*define VK_HANGUL         #x15)
(*define VK_JUNJA          #x17)
(*define VK_FINAL          #x18)
(*define VK_HANJA          #x19)
(*define VK_KANJI          #x19)

(*define VK_ESCAPE         #x1B); Esc

(*define VK_CONVERT        #x1C)
(*define VK_NONCONVERT     #x1D)
(*define VK_ACCEPT         #x1E)
(*define VK_MODECHANGE     #x1F)

(*define VK_SPACE          #x20); Spacebar
(*define VK_PRIOR          #x21); Page Up
(*define VK_NEXT           #x22); Page Down
(*define VK_END            #x23); End
(*define VK_HOME           #x24); Home
(*define VK_LEFT           #x25); 左方向キー
(*define VK_UP             #x26); 上方向キー
(*define VK_RIGHT          #x27); 右方向キー
(*define VK_DOWN           #x28); 下方向キー
(*define VK_SELECT         #x29)
(*define VK_PRINT          #x2A)
(*define VK_EXECUTE        #x2B)
(*define VK_SNAPSHOT       #x2C); PrintScreen
(*define VK_INSERT         #x2D); Insert
(*define VK_DELETE         #x2E); Delete
(*define VK_HELP           #x2F)

(*define VK_0              #x30) ; (char-code #\0)
(*define VK_1              #x31) ; (char-code #\1)
(*define VK_2              #x32) ; (char-code #\2)
(*define VK_3              #x33) ; (char-code #\3)
(*define VK_4              #x34) ; (char-code #\4)
(*define VK_5              #x35) ; (char-code #\5)
(*define VK_6              #x36) ; (char-code #\6)
(*define VK_7              #x37) ; (char-code #\7)
(*define VK_8              #x38) ; (char-code #\8)
(*define VK_9              #x39) ; (char-code #\9)

; #x40 : unassigned

(*define VK_A              #x41) ; (char-code #\A)
(*define VK_B              #x42) ; (char-code #\B)
(*define VK_C              #x43) ; (char-code #\C)
(*define VK_D              #x44) ; (char-code #\D)
(*define VK_E              #x45) ; (char-code #\E)
(*define VK_F              #x46) ; (char-code #\F)
(*define VK_G              #x47) ; (char-code #\G)
(*define VK_H              #x48) ; (char-code #\H)
(*define VK_I              #x49) ; (char-code #\I)
(*define VK_J              #x4A) ; (char-code #\J)
(*define VK_K              #x4B) ; (char-code #\K)
(*define VK_L              #x4C) ; (char-code #\L)
(*define VK_M              #x4D) ; (char-code #\M)
(*define VK_N              #x4E) ; (char-code #\N)
(*define VK_O              #x4F) ; (char-code #\O)
(*define VK_P              #x50) ; (char-code #\P)
(*define VK_Q              #x51) ; (char-code #\Q)
(*define VK_R              #x52) ; (char-code #\R)
(*define VK_S              #x53) ; (char-code #\S)
(*define VK_T              #x54) ; (char-code #\T)
(*define VK_U              #x55) ; (char-code #\U)
(*define VK_V              #x56) ; (char-code #\V)
(*define VK_W              #x57) ; (char-code #\W)
(*define VK_X              #x58) ; (char-code #\X)
(*define VK_Y              #x59) ; (char-code #\Y)
(*define VK_Z              #x5A) ; (char-code #\Z)

(*define VK_LWIN           #x5B); 左 Windows キー
(*define VK_RWIN           #x5C); 右 Windows キー
(*define VK_APPS           #x5D); アプリケーションキー

; #x5E : reserved

(*define VK_SLEEP          #x5F)

(*define VK_NUMPAD0        #x60); NumLock オン + テンキー 0
(*define VK_NUMPAD1        #x61); NumLock オン + テンキー 1
(*define VK_NUMPAD2        #x62); NumLock オン + テンキー 2
(*define VK_NUMPAD3        #x63); NumLock オン + テンキー 3
(*define VK_NUMPAD4        #x64); NumLock オン + テンキー 4
(*define VK_NUMPAD5        #x65); NumLock オン + テンキー 5
(*define VK_NUMPAD6        #x66); NumLock オン + テンキー 6
(*define VK_NUMPAD7        #x67); NumLock オン + テンキー 7
(*define VK_NUMPAD8        #x68); NumLock オン + テンキー 8
(*define VK_NUMPAD9        #x69); NumLock オン + テンキー 9
(*define VK_MULTIPLY       #x6A); テンキー *
(*define VK_ADD            #x6B); テンキー +
(*define VK_SEPARATOR      #x6C); テンキーの Separator キー テンキーの , キー
(*define VK_SUBTRACT       #x6D); テンキー -
(*define VK_DECIMAL        #x6E); テンキー .
(*define VK_DIVIDE         #x6F); テンキー /
(*define VK_F1             #x70); F1
(*define VK_F2             #x71); F2
(*define VK_F3             #x72); F3
(*define VK_F4             #x73); F4
(*define VK_F5             #x74); F5
(*define VK_F6             #x75); F6
(*define VK_F7             #x76); F7
(*define VK_F8             #x77); F8
(*define VK_F9             #x78); F9
(*define VK_F10            #x79); F10
(*define VK_F11            #x7A); F11
(*define VK_F12            #x7B); F12
(*define VK_F13            #x7C); F13
(*define VK_F14            #x7D); F14
(*define VK_F15            #x7E); F15
(*define VK_F16            #x7F); F16
(*define VK_F17            #x80); F17
(*define VK_F18            #x81); F18
(*define VK_F19            #x82); F19
(*define VK_F20            #x83); F20
(*define VK_F21            #x84); F21
(*define VK_F22            #x85); F22
(*define VK_F23            #x86); F23
(*define VK_F24            #x87); F24

; #x88 - #x8F : unassigned

(*define VK_NUMLOCK        #x90); Num Lock
(*define VK_SCROLL         #x91); Scroll Lock

; NEC PC-9800 kbd definitions
(*define VK_OEM_NEC_EQUAL  #x92); '=' key on numpad

; Fujitsu/OASYS kbd definitions
(*define VK_OEM_FJ_JISHO   #x92); 'Dictionary' key
(*define VK_OEM_FJ_MASSHOU #x93); 'Unregister word' key
(*define VK_OEM_FJ_TOUROKU #x94); 'Register word' key
(*define VK_OEM_FJ_LOYA    #x95); 'Left OYAYUBI' key
(*define VK_OEM_FJ_ROYA    #x96); 'Right OYAYUBI' key

; #x97 - #x9F : unassigned

(*define VK_LSHIFT         #xA0); WinNT 左 Shift キー
(*define VK_RSHIFT         #xA1); WinNT 右 Shift キー
(*define VK_LCONTROL       #xA2); WinNT 左 Ctrl キー
(*define VK_RCONTROL       #xA3); WinNT 右 Ctrl キー
(*define VK_LMENU          #xA4); WinNT 左 Alt キー
(*define VK_RMENU          #xA5); WinNT 左 Alt キー

; #if(_WIN32_WINNT >= 0x0500)
(*define VK_BROWSER_BACK        #xA6)
(*define VK_BROWSER_FORWARD     #xA7)
(*define VK_BROWSER_REFRESH     #xA8)
(*define VK_BROWSER_STOP        #xA9)
(*define VK_BROWSER_SEARCH      #xAA)
(*define VK_BROWSER_FAVORITES   #xAB)
(*define VK_BROWSER_HOME        #xAC)

(*define VK_VOLUME_MUTE         #xAD)
(*define VK_VOLUME_DOWN         #xAE)
(*define VK_VOLUME_UP           #xAF)
(*define VK_MEDIA_NEXT_TRACK    #xB0)
(*define VK_MEDIA_PREV_TRACK    #xB1)
(*define VK_MEDIA_STOP          #xB2)
(*define VK_MEDIA_PLAY_PAUSE    #xB3)
(*define VK_LAUNCH_MAIL         #xB4)
(*define VK_LAUNCH_MEDIA_SELECT #xB5)
(*define VK_LAUNCH_APP1         #xB6)
(*define VK_LAUNCH_APP2         #xB7)
; #endif /* _WIN32_WINNT >= 0x0500 */

; #xB8 - #xB9 : reserved

(*define VK_OEM_1          #xBA); ';:' for US
(*define VK_OEM_PLUS       #xBB); '+' any country
(*define VK_OEM_COMMA      #xBC); ',' any country
(*define VK_OEM_MINUS      #xBD); '-' any country
(*define VK_OEM_PERIOD     #xBE); '.' any country
(*define VK_OEM_2          #xBF); '/?' for US
(*define VK_OEM_3          #xC0); '`~' for US

; #xC1 - #xD7 : reserved

; #xD8 - #xDA : unassigned

(*define VK_OEM_4          #xDB); '[{' for US
(*define VK_OEM_5          #xDC); '\|' for US
(*define VK_OEM_6          #xDD); ']}' for US
(*define VK_OEM_7          #xDE); ''"' for US
(*define VK_OEM_8          #xDF)

; #xE0 : reserved

; Various extended or enhanced keyboards
(*define VK_OEM_AX         #xE1); 'AX' key on Japanese AX kbd
(*define VK_OEM_102        #xE2); "<>" or "\|" on RT 102-key kbd.
(*define VK_ICO_HELP       #xE3); Help key on ICO
(*define VK_ICO_00         #xE4); 00 key on ICO

; #if(WINVER >= 0x0400)
(*define VK_PROCESSKEY     #xE5); WINVER 0x400 以上で定義
; #endif /* WINVER >= 0x0400 */

(*define VK_ICO_CLEAR      #xE6)


; #if(_WIN32_WINNT >= 0x0500)
(*define VK_PACKET         #xE7)
; #endif /* _WIN32_WINNT >= 0x0500 */

; 0xE8 : unassigned

; Nokia/Ericsson definitions
(*define VK_OEM_RESET      #xE9)
(*define VK_OEM_JUMP       #xEA)
(*define VK_OEM_PA1        #xEB)
(*define VK_OEM_PA2        #xEC)
(*define VK_OEM_PA3        #xED)
(*define VK_OEM_WSCTRL     #xEE)
(*define VK_OEM_CUSEL      #xEF)
(*define VK_OEM_ATTN       #xF0)
(*define VK_OEM_FINISH     #xF1)
(*define VK_OEM_COPY       #xF2)
(*define VK_OEM_AUTO       #xF3)
(*define VK_OEM_ENLW       #xF4)
(*define VK_OEM_BACKTAB    #xF5)

(*define VK_ATTN           #xF6)
(*define VK_CRSEL          #xF7)
(*define VK_EXSEL          #xF8)
(*define VK_EREOF          #xF9)
(*define VK_PLAY           #xFA)
(*define VK_ZOOM           #xFB)
(*define VK_NONAME         #xFC)
(*define VK_PA1            #xFD)
(*define VK_OEM_CLEAR      #xFE)

; #xFF : reserved

(*define-dll-entry SHORT GetKeyState (int) "user32")
(*define WM_KEYDOWN          #x0100)
(*define WM_KEYUP            #x0101)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package "win-user")
(export '(vkey-to-key))

(defvar *vkey-to-key-debug* nil)
(defun vkey-to-key (vkey)
  (let ((shift (or (minusp (GetKeyState VK_SHIFT))
                   (minusp (GetKeyState VK_LSHIFT))
                   (minusp (GetKeyState VK_RSHIFT))))
        (ctrl (or (minusp (GetKeyState VK_CONTROL))
                  (minusp (GetKeyState VK_LCONTROL))
                  (minusp (GetKeyState VK_RCONTROL))))
        (meta (or (minusp (GetKeyState VK_MENU))
                  (minusp (GetKeyState VK_LMENU))
                  (minusp (GetKeyState VK_RMENU))))
        (capslock (plusp (logand #x1 (GetKeyState VK_CAPITAL))))
        (numlock (plusp (logand #x1 (GetKeyState VK_NUMLOCK))))
        (scrolllock (plusp (logand #x1 (GetKeyState VK_SCROLL))))
        (insert (plusp (logand #x1 (GetKeyState VK_INSERT)))))
    (cond
     ((and (= vkey VK_OEM_3) (not shift) ctrl (not meta))
      #\NUL)
     ((and (<= VK_A vkey VK_Z) ctrl (not meta))
      (code-char (+ (char-code #\C-a) (- vkey VK_A))))
     ((and (= vkey VK_CANCEL) (not ctrl) (not meta))
      #\C-c)
     ((and (= vkey VK_CANCEL) ctrl (not meta))
      #\C-g)
     ((and (= vkey VK_OEM_4) (not shift) ctrl (not meta))
      #\ESC)
     ((or (and (= vkey VK_OEM_5) (not shift) ctrl (not meta)))
          (and (= vkey VK_OEM_102) (not shift) ctrl (not meta))
      #\C-\\)
     ((and (= vkey VK_OEM_6) (not shift) ctrl (not meta))
      #\C-])
     ((and (= vkey VK_OEM_7) (not shift) ctrl (not meta))
      #\C-^)
     ((and (= vkey VK_OEM_102) shift ctrl (not meta))
      #\C-_)
     ((and (<= VK_1 vkey VK_9) shift (not ctrl) (not meta))
      (code-char (+ (char-code #\!) (- vkey VK_1))))
     ((or (and (= vkey VK_OEM_1) shift (not ctrl) (not meta))
          (and (= vkey VK_MULTIPLY) (not ctrl) (not meta)))
      #\*)
     ((or (and (= vkey VK_OEM_PLUS) shift (not ctrl) (not meta))
          (and (= vkey VK_ADD) (not ctrl) (not meta)))
      #\+)
     ((or (and (= vkey VK_OEM_COMMA) (not shift) (not ctrl) (not meta))
          (and (= vkey VK_SEPARATOR) (not ctrl) (not meta)))
      #\,)
     ((or (and (= vkey VK_OEM_MINUS) (not shift) (not ctrl) (not meta))
          (and (= vkey VK_SUBTRACT) (not ctrl) (not meta)))
      #\-)
     ((or (and (= vkey VK_OEM_PERIOD) (not shift) (not ctrl) (not meta))
          (and (= vkey VK_DECIMAL) (not ctrl) (not meta)))
      #\.)
     ((or (and (= vkey VK_OEM_2) (not shift) (not ctrl) (not meta))
          (and (= vkey VK_DIVIDE) (not ctrl) (not meta)))
      #\/)
     ((and (<= VK_0 vkey VK_9) (not shift) (not ctrl) (not meta))
      (code-char (+ (char-code #\0) (- vkey VK_0))))
     ((and (<= VK_NUMPAD0 vkey VK_NUMPAD9) numlock (not shift) (not ctrl) (not meta))
      (code-char (+ (char-code #\0) (- vkey VK_NUMPAD0))))
     ((and (= vkey VK_OEM_1) (not shift) (not ctrl) (not meta))
      #\:)
     ((and (= vkey VK_OEM_PLUS) (not shift) (not ctrl) (not meta))
      #\;)
     ((and (= vkey VK_OEM_COMMA) shift (not ctrl) (not meta))
      #\<)
     ((and (= vkey VK_OEM_MINUS) shift (not ctrl) (not meta))
      #\=)
     ((and (= vkey VK_OEM_PERIOD) shift (not ctrl) (not meta))
      #\>)
     ((and (= vkey VK_OEM_2) shift (not ctrl) (not meta))
      #\?)
     ((and (= vkey VK_OEM_3) (not shift) (not ctrl) (not meta))
      #\@)
     ((and (<= VK_A vkey VK_Z) (not (eq shift capslock)) (not ctrl) (not meta))
      (code-char (+ (char-code #\A) (- vkey VK_A))))
     ((and (= vkey VK_OEM_4) (not shift) (not ctrl) (not meta))
      #\[)
     ((or (and (= vkey VK_OEM_5) (not shift) (not ctrl) (not meta))
          (and (= vkey VK_OEM_102) (not shift) (not ctrl) (not meta)))
      #\\)
     ((and (= vkey VK_OEM_6) (not shift) (not ctrl) (not meta))
      #\])
     ((and (= vkey VK_OEM_7) (not shift) (not ctrl) (not meta))
      #\^)
     ((and (= vkey VK_OEM_102) shift (not ctrl) (not meta))
      #\_)
     ((and (= vkey VK_OEM_3) shift (not ctrl) (not meta))
      #\`)
     ((and (<= VK_A vkey VK_Z) (eq shift capslock) (not ctrl) (not meta))
      (code-char (+ (char-code #\a) (- vkey VK_A))))
     ((and (= vkey VK_OEM_4) shift (not ctrl) (not meta))
      #\{)
     ((and (= vkey VK_OEM_5) shift (not ctrl) (not meta))
      #\|)
     ((and (= vkey VK_OEM_6) shift (not ctrl) (not meta))
      #\})
     ((and (= vkey VK_OEM_7) shift (not ctrl) (not meta))
      #\~)
     ;; DEL
     ((and (= vkey VK_PRIOR) (not shift) (not ctrl) (not meta))
      #\PageUp)
     ((and (= vkey VK_NEXT) (not shift) (not ctrl) (not meta))
      #\PageDown)
     ((and (= vkey VK_END) (not shift) (not ctrl) (not meta))
      #\End)
     ((and (= vkey VK_HOME) (not shift) (not ctrl) (not meta))
      #\Home)
     ((and (= vkey VK_LEFT) (not shift) (not ctrl) (not meta))
      #\Left)
     ((and (= vkey VK_UP) (not shift) (not ctrl) (not meta))
      #\Up)
     ((and (= vkey VK_RIGHT) (not shift) (not ctrl) (not meta))
      #\Right)
     ((and (= vkey VK_DOWN) (not shift) (not ctrl) (not meta))
      #\Down)
     ((and (= vkey VK_SCROLL) (not shift) (not ctrl) (not meta))
      #\Scroll)
     ;; #\MouseMove
     ((and (= vkey VK_PAUSE) (not shift) (not ctrl) (not meta))
      #\Pause)
     ((and (= vkey VK_APPS) (not shift) (not ctrl) (not meta))
      #\Apps)
     ((and (= vkey VK_INSERT) (not shift) (not ctrl) (not meta))
      #\Insert)
     ((and (= vkey VK_DELETE) (not shift) (not ctrl) (not meta))
      #\Delete)
     ((and (= vkey VK_HELP) (not shift) (not ctrl) (not meta))
      #\Help)
     ((and (<= VK_F1 vkey VK_F24) (not shift) (not ctrl) (not meta))
      (code-char (+ (char-code #\F1) (- vkey VK_F1))))
     ;; #\LBtnDown
     ;; #\LBtnMove
     ;; #\LBtnUp
     ;; #\RBtnDown
     ;; #\RBtnMove
     ;; #\RBtnUp
     ;; #\MBtnDown
     ;; #\MBtnMove
     ;; #\MBtnUp
     ((and (<= VK_1 vkey VK_9) shift ctrl (not meta))
      (code-char (+ (char-code #\C-!) (- vkey VK_1))))
     ;; #\XBtn1Down
     ;; #\XBtn1Up
     ;; #\XBtn1Move
     ;; #\XBtn2Down
     ;; #\XBtn2Up
     ;; #\XBtn2Move
     ((and (= vkey VK_PRIOR) shift (not ctrl) (not meta))
      #\S-PageUp)
     ((and (= vkey VK_NEXT) shift (not ctrl) (not meta))
      #\S-PageDown)
     ((and (= vkey VK_END) shift (not ctrl) (not meta))
      #\S-End)
     ((and (= vkey VK_HOME) shift (not ctrl) (not meta))
      #\S-Home)
     ((and (= vkey VK_LEFT) shift (not ctrl) (not meta))
      #\S-Left)
     ((and (= vkey VK_UP) shift (not ctrl) (not meta))
      #\S-Up)
     ((and (= vkey VK_RIGHT) shift (not ctrl) (not meta))
      #\S-Right)
     ((and (= vkey VK_DOWN) shift (not ctrl) (not meta))
      #\S-Down)
     ((and (= vkey VK_SCROLL) shift (not ctrl) (not meta))
      #\S-Scroll)
     ;; #\S-MouseMove
     ((and (= vkey VK_PAUSE) shift (not ctrl) (not meta))
      #\S-Pause)
     ((and (= vkey VK_APPS) shift (not ctrl) (not meta))
      #\S-Apps)
     ((and (= vkey VK_INSERT) shift (not ctrl) (not meta))
      #\S-Insert)
     ((and (= vkey VK_DELETE) shift (not ctrl) (not meta))
      #\S-Delete)
     ((and (= vkey VK_HELP) shift (not ctrl) (not meta))
      #\S-Help)
     ((and (<= VK_F1 vkey VK_F24) shift (not ctrl) (not meta))
      (code-char (+ (char-code #\S-F1) (- vkey VK_F1))))
     ;; #\S-LBtnDown
     ;; #\S-LBtnMove
     ;; #\S-LBtnUp
     ;; #\S-RBtnDown
     ;; #\S-RBtnMove
     ;; #\S-RBtnUp
     ;; #\S-MBtnDown
     ;; #\S-MBtnMove
     ;; #\S-MBtnUp
     ((or (and (= vkey VK_OEM_1) shift ctrl (not meta))
          (and (= vkey VK_MULTIPLY) ctrl (not meta)))
      #\C-*)
     ((or (and (= vkey VK_OEM_PLUS) shift ctrl (not meta))
          (and (= vkey VK_ADD) ctrl (not meta)))
      #\C-+)
     ((or (and (= vkey VK_OEM_COMMA) (not shift) ctrl (not meta))
          (and (= vkey VK_SEPARATOR) ctrl (not meta)))
      #\C-\,)
     ((or (and (= vkey VK_OEM_MINUS) (not shift) ctrl (not meta))
          (and (= vkey VK_SUBTRACT) ctrl (not meta)))
      #\C--)
     ((or (and (= vkey VK_OEM_PERIOD) (not shift) ctrl (not meta))
          (and (= vkey VK_DECIMAL) ctrl (not meta)))
      #\C-.)
     ((or (and (= vkey VK_OEM_2) (not shift) ctrl (not meta))
          (and (= vkey VK_DIVIDE) ctrl (not meta)))
      #\C-/)
     ((and (<= VK_0 vkey VK_2) (not shift) ctrl (not meta))
      (code-char (+ (char-code #\C-0) (- vkey VK_0))))
     ;; #\S-XBtn1Down
     ;; #\S-XBtn1Up
     ;; #\S-XBtn1Move
     ;; #\S-XBtn2Down
     ;; #\S-XBtn2Up
     ;; #\S-XBtn2Move
     ((and (= vkey VK_PRIOR) (not shift) ctrl (not meta))
      #\C-PageUp)
     ((and (= vkey VK_NEXT) (not shift) ctrl (not meta))
      #\C-PageDown)
     ((and (= vkey VK_END) (not shift) ctrl (not meta))
      #\C-End)
     ((and (= vkey VK_HOME) (not shift) ctrl (not meta))
      #\C-Home)
     ((and (= vkey VK_LEFT) (not shift) ctrl (not meta))
      #\C-Left)
     ((and (= vkey VK_UP) (not shift) ctrl (not meta))
      #\C-Up)
     ((and (= vkey VK_RIGHT) (not shift) ctrl (not meta))
      #\C-Right)
     ((and (= vkey VK_DOWN) (not shift) ctrl (not meta))
      #\C-Down)
     ((and (= vkey VK_SCROLL) (not shift) ctrl (not meta))
      #\C-Scroll)
     ;; #\C-MouseMove
     ((and (= vkey VK_PAUSE) (not shift) ctrl (not meta))
      #\C-Pause)
     ((and (= vkey VK_APPS) (not shift) ctrl (not meta))
      #\C-Apps)
     ((and (= vkey VK_INSERT) (not shift) ctrl (not meta))
      #\C-Insert)
     ((and (= vkey VK_DELETE) (not shift) ctrl (not meta))
      #\C-Delete)
     ((and (= vkey VK_HELP) (not shift) ctrl (not meta))
      #\C-Help)
     ((and (<= VK_F1 vkey VK_F24) (not shift) ctrl (not meta))
      (code-char (+ (char-code #\C-F1) (- vkey VK_F1))))
     ;; #\C-LBtnDown
     ;; #\C-LBtnMove
     ;; #\C-LBtnUp
     ;; #\C-RBtnDown
     ;; #\C-RBtnMove
     ;; #\C-RBtnUp
     ;; #\C-MBtnDown
     ;; #\C-MBtnMove
     ;; #\C-MBtnUp
     ((and (<= VK_3 vkey VK_9) (not shift) ctrl (not meta))
      (code-char (+ (char-code #\C-3) (- vkey VK_3))))
     ((and (= vkey VK_OEM_1) (not shift) ctrl (not meta))
      #\C-:)
     ((and (= vkey VK_OEM_PLUS) (not shift) ctrl (not meta))
      #\C-\;)
     ;; #\C-XBtn1Down
     ;; #\C-XBtn1Up
     ;; #\C-XBtn1Move
     ;; #\C-XBtn2Down
     ;; #\C-XBtn2Up
     ;; #\C-XBtn2Move
     ((and (= vkey VK_PRIOR) shift ctrl (not meta))
      #\S-C-PageUp)
     ((and (= vkey VK_NEXT) shift ctrl (not meta))
      #\S-C-PageDown)
     ((and (= vkey VK_END) shift ctrl (not meta))
      #\S-C-End)
     ((and (= vkey VK_HOME) shift ctrl (not meta))
      #\S-C-Home)
     ((and (= vkey VK_LEFT) shift ctrl (not meta))
      #\S-C-Left)
     ((and (= vkey VK_UP) shift ctrl (not meta))
      #\S-C-Up)
     ((and (= vkey VK_RIGHT) shift ctrl (not meta))
      #\S-C-Right)
     ((and (= vkey VK_DOWN) shift ctrl (not meta))
      #\S-C-Down)
     ((and (= vkey VK_SCROLL) shift ctrl (not meta))
      #\S-C-Scroll)
     ;; #\S-C-MouseMove
     ((and (= vkey VK_PAUSE) shift ctrl (not meta))
      #\S-C-Pause)
     ((and (= vkey VK_APPS) shift ctrl (not meta))
      #\S-C-Apps)
     ((and (= vkey VK_INSERT) shift ctrl (not meta))
      #\S-C-Insert)
     ((and (= vkey VK_DELETE) shift ctrl (not meta))
      #\S-C-Delete)
     ((and (= vkey VK_HELP) shift ctrl (not meta))
      #\S-C-Help)
     ((and (<= VK_F1 vkey VK_F24) shift ctrl (not meta))
      (code-char (+ (char-code #\S-C-F1) (- vkey VK_F1))))
     ;; #\S-C-LBtnDown
     ;; #\S-C-LBtnMove
     ;; #\S-C-LBtnUp
     ;; #\S-C-RBtnDown
     ;; #\S-C-RBtnMove
     ;; #\S-C-RBtnUp
     ;; #\S-C-MBtnDown
     ;; #\S-C-MBtnMove
     ;; #\S-C-MBtnUp
     ((and (= vkey VK_OEM_COMMA) shift ctrl (not meta))
      #\C-<)
     ((and (= vkey VK_OEM_MINUS) shift ctrl (not meta))
      #\C-=)
     ((and (= vkey VK_OEM_PERIOD) shift ctrl (not meta))
      #\C->)

     ((and (= vkey VK_OEM_3) shift ctrl (not meta))
      #\C-\`)
     ((and (= vkey VK_OEM_4) shift ctrl (not meta))
      #\C-{)
     ((and (= vkey VK_OEM_5) shift ctrl (not meta))
      #\C-\|)
     ((and (= vkey VK_OEM_6) shift ctrl (not meta))
      #\C-})
     ((and (= vkey VK_OEM_7) shift ctrl (not meta))
      #\C-~)
     ;; #\xfff8
     ;; #\S-C-XBtn1Down
     ;; #\S-C-XBtn1Up
     ;; #\S-C-XBtn1Move
     ;; #\S-C-XBtn2Down
     ;; #\S-C-XBtn2Up
     ;; #\S-C-XBtn2Move

     ;; keyboard.l
     ; (defconstant exkey-backspace 0)
     ((and (= vkey VK_BACK) (not shift) (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-backspace))
     ; (defconstant exkey-S-backspace 1)
     ((and (= vkey VK_BACK) shift (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-backspace))
     ; (defconstant exkey-C-backspace 2)
     ((and (= vkey VK_BACK) (not shift) ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-C-backspace))
     ; (defconstant exkey-S-C-backspace 3)
     ((and (= vkey VK_BACK) shift ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-C-backspace))
     ; (defconstant exkey-M-backspace 4)
     ; (defconstant exkey-S-M-backspace 5)
     ; (defconstant exkey-C-M-backspace 6)
     ; (defconstant exkey-S-C-M-backspace 7)
     ; (defconstant exkey-tab 8)
     ((and (= vkey VK_TAB) (not shift) (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-tab))
     ; (defconstant exkey-S-tab 9)
     ((and (= vkey VK_TAB) shift (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-tab))
     ; (defconstant exkey-C-tab 10)
     ((and (= vkey VK_TAB) (not shift) ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-C-tab))
     ; (defconstant exkey-S-C-tab 11)
     ((and (= vkey VK_TAB) shift ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-C-tab))
     ; (defconstant exkey-return 16)
     ((and (= vkey VK_RETURN) (not shift) (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-return))
     ; (defconstant exkey-S-return 17)
     ((and (= vkey VK_RETURN) shift (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-return))
     ; (defconstant exkey-C-return 18)
     ((and (= vkey VK_RETURN) (not shift) ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-C-return))
     ; (defconstant exkey-S-C-return 19)
     ((and (= vkey VK_RETURN) shift ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-C-return))
     ; (defconstant exkey-M-return 20)
     ; (defconstant exkey-S-M-return 21)
     ; (defconstant exkey-C-M-return 22)
     ; (defconstant exkey-S-C-M-return 23)
     ; (defconstant exkey-escape 24)
     ((and (= vkey VK_ESCAPE) (not shift) (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-escape))
     ; (defconstant exkey-S-escape 25)
     ((and (= vkey VK_ESCAPE) shift (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-escape))
     ; (defconstant exkey-zenkaku 32)
     ; (defconstant exkey-S-zenkaku 33)
     ; (defconstant exkey-C-zenkaku 34)
     ; (defconstant exkey-S-C-zenkaku 35)
     ; (defconstant exkey-S-M-zenkaku 37)
     ; (defconstant exkey-space 40)
     ((and (= vkey VK_SPACE) (not shift) (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-space))
     ; (defconstant exkey-S-space 41)
     ((and (= vkey VK_SPACE) shift (not ctrl) (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-space))
     ; (defconstant exkey-C-space 42)
     ((and (= vkey VK_SPACE) (not shift) ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-C-space))
     ; (defconstant exkey-S-C-space 43)
     ((and (= vkey VK_SPACE) shift ctrl (not meta))
      (svref ed::*extended-key-translate-table* ed:exkey-S-C-space))
     ; (defconstant exkey-M-space 44)
     ; (defconstant exkey-S-M-space 45)
     ; (defconstant exkey-C-M-space 46)
     ; (defconstant exkey-S-C-M-space 47)
     (t
      (when *vkey-to-key-debug*
        (ed::msgbox "vkey?: ~x" vkey))
      nil))))

;;; virtual-keys.l ends here
