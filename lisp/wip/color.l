;;; -*- Mode: Lisp; Package: EDITOR -*-
;;; color.l

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/10/06 22:41:08 +0900>

;;; Commentary:

;; Description:
;;
;;  COLOR-NAME と RGB値 の対応リスト、操作関数の提供。
;;

;; Installation:
;;
;;      1. アーカイブを展開して color.l を $XYZZY/site-lisp に
;;         コピーします。
;;
;;      2. 必要ならばバイトコンパイルします。
;;
;;              M-x byte-compile-file
;;              Byte compile file: $XYZZY/site-lisp/color.l
;;
;;      3. ~/.xyzzy または $XYZZY/site-lisp/siteinit.l に以下のコードを
;;         追加します。
;;
;;              (require "wip/color")
;;
;;      4. 上記の設定を反映させるために、xyzzy を再起動します。
;;         siteinit.l に記述した場合は Ctrl キーと Shift キーを押しながら
;;         xyzzy を再起動し、ダンプファイルを再構築します。
;;

;; Uninstallation:
;;
;;      1. color.l に関する記述を削除します。
;;
;;      2. siteinit.l に記述していた場合は Ctrl キーと Shift キーを押し
;;         ながら xyzzy を再起動し、ダンプファイルを再構築します。
;;

;; Usage:
;;
;;      color.l を必要とするコードを評価(ロード)する前に require する。
;;

;; Changes:
;;
;;      Thu, 06 Oct 2005 22:29:23 +0900
;;        ・ライセンス条項(修正BSDライセンス)を記載。
;;
;;      Mon, 23 May 2005 00:05:10 +0900
;;        ・xyzzy 0.2.2.234 対応
;;          - "ＭＳ Ｐゴシック" ⇒ "MS UI Gothic"
;;          - 半角カナを全角カナに変更。
;;
;;      Tue, 22 Feb 2005 00:28:21 +0900
;;        ・*color-xyzzy-colors-name-display-name-alist* を
;;          *color-xyzzy-colors-alist* に名称変更
;;
;;      Thu, 21 Aug 2003 01:49:06 +0900
;;        ・作成
;;

;; Licence:
;;
;;    color は修正BSDライセンスに基づいて利用可能です。
;;    <http://www.opensource.org/licenses/bsd-license.php>
;;
;;
;;    Copyright (C) 2001-2005, OHKUBO Hiroshi.  All rights reserved.
;;
;;    Redistribution and use in source and binary forms, with or without
;;    modification, are permitted provided that the following conditions
;;    are met:
;;
;;    1. Redistributions of source code must retain the above copyright
;;       notice, this list of conditions and the following disclaimer.
;;
;;    2. Redistributions in binary form must reproduce the above copyright
;;       notice, this list of conditions and the following disclaimer in
;;       the documentation and/or other materials provided with the
;;       distribution.
;;
;;    3. Neither the name of the University nor the names of its
;;       contributors may be used to endorse or promote products derived
;;       from this software without specific prior written permission.
;;
;;    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;    ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;    A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;    OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;;    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;;    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;;    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;;    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;;    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;

;;; Code:

(provide "wip/color")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi"))

(in-package "winapi")

;; WINUSER.H
; Color Types
(*define COLOR_SCROLLBAR           0)
(*define COLOR_BACKGROUND          1)
(*define COLOR_ACTIVECAPTION       2)
(*define COLOR_INACTIVECAPTION     3)
(*define COLOR_MENU                4)
(*define COLOR_WINDOW              5)
(*define COLOR_WINDOWFRAME         6)
(*define COLOR_MENUTEXT            7)
(*define COLOR_WINDOWTEXT          8)
(*define COLOR_CAPTIONTEXT         9)
(*define COLOR_ACTIVEBORDER        10)
(*define COLOR_INACTIVEBORDER      11)
(*define COLOR_APPWORKSPACE        12)
(*define COLOR_HIGHLIGHT           13)
(*define COLOR_HIGHLIGHTTEXT       14)
(*define COLOR_BTNFACE             15)
(*define COLOR_BTNSHADOW           16)
(*define COLOR_GRAYTEXT            17)
(*define COLOR_BTNTEXT             18)
(*define COLOR_INACTIVECAPTIONTEXT 19)
(*define COLOR_BTNHIGHLIGHT        20)

;#if(WINVER >= 0x0400)
(*define COLOR_3DDKSHADOW          21)
(*define COLOR_3DLIGHT             22)
(*define COLOR_INFOTEXT            23)
(*define COLOR_INFOBK              24)
;#endif /* WINVER >= 0x0400 */

;#if(WINVER >= 0x0500)
(*define COLOR_HOTLIGHT                  26)
(*define COLOR_GRADIENTACTIVECAPTION     27)
(*define COLOR_GRADIENTINACTIVECAPTION   28)
;#endif /* WINVER >= 0x0500 */

;#if(WINVER >= 0x0400)
(*define COLOR_DESKTOP           COLOR_BACKGROUND)
(*define COLOR_3DFACE            COLOR_BTNFACE)
(*define COLOR_3DSHADOW          COLOR_BTNSHADOW)
(*define COLOR_3DHIGHLIGHT       COLOR_BTNHIGHLIGHT)
(*define COLOR_3DHILIGHT         COLOR_BTNHIGHLIGHT)
(*define COLOR_BTNHILIGHT        COLOR_BTNHIGHLIGHT)
;#endif /* WINVER >= 0x0400 */

(*define-dll-entry DWORD GetSysColor (int) "user32")

#|
WINUSERAPI
DWORD
WINAPI
GetSysColor(
    int nIndex);
|#

;; WINBASE.H
(*define-dll-entry DWORD GetPrivateProfileString
                   ;AppName KeyName Default ReturnedString Size  FileName
                   (LPCSTR  LPCSTR  LPCSTR  LPCSTR         DWORD LPCSTR)
                   "kernel32" "GetPrivateProfileStringA")

(in-package "editor")

(export '(color-bgr2rgb
          color-rgb2bgr
          color-code2str
          color-str2code
          color-code2name
          color-name2code
          color-code-dialog-box
          color-code-all-dialog-box
          *color-X11R6-name-alist*
          *color-X11R6-unique-name-alist*
          *color-HTML3.2/4.0-name-alist*
          *color-Mozilla/MSIE-name-alist*
          *color-discrepancy-X11R6-and-Mozilla/MSIE-name-list*
          *color-system-colors-id-xyzzy-name-alist*
          *color-system-colors-id-alist*
          *color-system-colors-xyzzy-name-alist*
          *color-xyzzy-colors-name-alist*
          *color-all-colors-name-alist*))

(defun color-bgr2rgb (bgr)
  "BGR の数値を RGB の数値に変換"
  (let ((b (floor (mod bgr #x1000000) #x10000))
        (g (floor (mod bgr #x10000) #x100))
        (r (mod bgr #x100)))
    (+ (* r #x10000) (* g #x100) b)))
(defun color-rgb2bgr (rgb)
  "RGB の数値を BGR の数値に変換"
  (color-bgr2rgb rgb))
(defun color-code2str (code)
  "数値を 000000 ～ FFFFFF の文字列に変換"
  (let ((x (floor (mod code #x1000000) #x10000))
        (y (floor (mod code #x10000) #x100))
        (z (mod code #x100)))
    (format nil "~:@(~{~2,'0X~}~)" (list x y z))))
(defun color-str2code (str)
  "000000 ～ FFFFFF の文字列を数値に変換"
  (when (string-matchp
         "\\([0-9a-f]\\{2\\}\\)\\([0-9a-f]\\{2\\}\\)\\([0-9a-f]\\{2\\}\\)" str)
    (let ((x (parse-integer (match-string 1) :radix 16))
          (y (parse-integer (match-string 2) :radix 16))
          (z (parse-integer (match-string 3) :radix 16)))
      (+ (* x #x10000) (* y #x100) z))))
(defun color-code2name (code &optional name-code-alist)
  "RGB の数値を対応する色名に変換"
  (unless name-code-alist
    (setq name-code-alist ed::*color-X11R6-name-alist*))
  (car (find code name-code-alist :key #'cdr :test #'eql)))
(defun color-name2code (name &optional name-code-alist)
  "色名を対応する RGB の数値に変換"
  (unless name-code-alist
    (setq name-code-alist ed::*color-X11R6-name-alist*))
  (cdr (find name name-code-alist :key #'car :test #'string-equal)))

(defvar *color-X11R6-name-alist*
  '(("snow"                   . #xfffafa) ; 255 250 250
    ("ghost white"            . #xf8f8ff) ; 248 248 255
    ("GhostWhite"             . #xf8f8ff) ; 248 248 255
    ("white smoke"            . #xf5f5f5) ; 245 245 245
    ("WhiteSmoke"             . #xf5f5f5) ; 245 245 245
    ("gainsboro"              . #xdcdcdc) ; 220 220 220
    ("floral white"           . #xfffaf0) ; 255 250 240
    ("FloralWhite"            . #xfffaf0) ; 255 250 240
    ("old lace"               . #xfdf5e6) ; 253 245 230
    ("OldLace"                . #xfdf5e6) ; 253 245 230
    ("linen"                  . #xfaf0e6) ; 250 240 230
    ("antique white"          . #xfaebd7) ; 250 235 215
    ("AntiqueWhite"           . #xfaebd7) ; 250 235 215
    ("papaya whip"            . #xffefd5) ; 255 239 213
    ("PapayaWhip"             . #xffefd5) ; 255 239 213
    ("blanched almond"        . #xffebcd) ; 255 235 205
    ("BlanchedAlmond"         . #xffebcd) ; 255 235 205
    ("bisque"                 . #xffe4c4) ; 255 228 196
    ("peach puff"             . #xffdab9) ; 255 218 185
    ("PeachPuff"              . #xffdab9) ; 255 218 185
    ("navajo white"           . #xffdead) ; 255 222 173
    ("NavajoWhite"            . #xffdead) ; 255 222 173
    ("moccasin"               . #xffe4b5) ; 255 228 181
    ("cornsilk"               . #xfff8dc) ; 255 248 220
    ("ivory"                  . #xfffff0) ; 255 255 240
    ("lemon chiffon"          . #xfffacd) ; 255 250 205
    ("LemonChiffon"           . #xfffacd) ; 255 250 205
    ("seashell"               . #xfff5ee) ; 255 245 238
    ("honeydew"               . #xf0fff0) ; 240 255 240
    ("mint cream"             . #xf5fffa) ; 245 255 250
    ("MintCream"              . #xf5fffa) ; 245 255 250
    ("azure"                  . #xf0ffff) ; 240 255 255
    ("alice blue"             . #xf0f8ff) ; 240 248 255
    ("AliceBlue"              . #xf0f8ff) ; 240 248 255
    ("lavender"               . #xe6e6fa) ; 230 230 250
    ("lavender blush"         . #xfff0f5) ; 255 240 245
    ("LavenderBlush"          . #xfff0f5) ; 255 240 245
    ("misty rose"             . #xffe4e1) ; 255 228 225
    ("MistyRose"              . #xffe4e1) ; 255 228 225
    ("white"                  . #xffffff) ; 255 255 255
    ("black"                  . #x000000) ;   0   0   0
    ("dark slate gray"        . #x2f4f4f) ;  47  79  79
    ("DarkSlateGray"          . #x2f4f4f) ;  47  79  79
    ("dark slate grey"        . #x2f4f4f) ;  47  79  79
    ("DarkSlateGrey"          . #x2f4f4f) ;  47  79  79
    ("dim gray"               . #x696969) ; 105 105 105
    ("DimGray"                . #x696969) ; 105 105 105
    ("dim grey"               . #x696969) ; 105 105 105
    ("DimGrey"                . #x696969) ; 105 105 105
    ("slate gray"             . #x708090) ; 112 128 144
    ("SlateGray"              . #x708090) ; 112 128 144
    ("slate grey"             . #x708090) ; 112 128 144
    ("SlateGrey"              . #x708090) ; 112 128 144
    ("light slate gray"       . #x778899) ; 119 136 153
    ("LightSlateGray"         . #x778899) ; 119 136 153
    ("light slate grey"       . #x778899) ; 119 136 153
    ("LightSlateGrey"         . #x778899) ; 119 136 153
    ("gray"                   . #xbebebe) ; 190 190 190
    ("grey"                   . #xbebebe) ; 190 190 190
    ("light grey"             . #xd3d3d3) ; 211 211 211
    ("LightGrey"              . #xd3d3d3) ; 211 211 211
    ("light gray"             . #xd3d3d3) ; 211 211 211
    ("LightGray"              . #xd3d3d3) ; 211 211 211
    ("midnight blue"          . #x191970) ;  25  25 112
    ("MidnightBlue"           . #x191970) ;  25  25 112
    ("navy"                   . #x000080) ;   0   0 128
    ("navy blue"              . #x000080) ;   0   0 128
    ("NavyBlue"               . #x000080) ;   0   0 128
    ("cornflower blue"        . #x6495ed) ; 100 149 237
    ("CornflowerBlue"         . #x6495ed) ; 100 149 237
    ("dark slate blue"        . #x483d8b) ;  72  61 139
    ("DarkSlateBlue"          . #x483d8b) ;  72  61 139
    ("slate blue"             . #x6a5acd) ; 106  90 205
    ("SlateBlue"              . #x6a5acd) ; 106  90 205
    ("medium slate blue"      . #x7b68ee) ; 123 104 238
    ("MediumSlateBlue"        . #x7b68ee) ; 123 104 238
    ("light slate blue"       . #x8470ff) ; 132 112 255
    ("LightSlateBlue"         . #x8470ff) ; 132 112 255
    ("medium blue"            . #x0000cd) ;   0   0 205
    ("MediumBlue"             . #x0000cd) ;   0   0 205
    ("royal blue"             . #x4169e1) ;  65 105 225
    ("RoyalBlue"              . #x4169e1) ;  65 105 225
    ("blue"                   . #x0000ff) ;   0   0 255
    ("dodger blue"            . #x1e90ff) ;  30 144 255
    ("DodgerBlue"             . #x1e90ff) ;  30 144 255
    ("deep sky blue"          . #x00bfff) ;   0 191 255
    ("DeepSkyBlue"            . #x00bfff) ;   0 191 255
    ("sky blue"               . #x87ceeb) ; 135 206 235
    ("SkyBlue"                . #x87ceeb) ; 135 206 235
    ("light sky blue"         . #x87cefa) ; 135 206 250
    ("LightSkyBlue"           . #x87cefa) ; 135 206 250
    ("steel blue"             . #x4682b4) ;  70 130 180
    ("SteelBlue"              . #x4682b4) ;  70 130 180
    ("light steel blue"       . #xb0c4de) ; 176 196 222
    ("LightSteelBlue"         . #xb0c4de) ; 176 196 222
    ("light blue"             . #xadd8e6) ; 173 216 230
    ("LightBlue"              . #xadd8e6) ; 173 216 230
    ("powder blue"            . #xb0e0e6) ; 176 224 230
    ("PowderBlue"             . #xb0e0e6) ; 176 224 230
    ("pale turquoise"         . #xafeeee) ; 175 238 238
    ("PaleTurquoise"          . #xafeeee) ; 175 238 238
    ("dark turquoise"         . #x00ced1) ;   0 206 209
    ("DarkTurquoise"          . #x00ced1) ;   0 206 209
    ("medium turquoise"       . #x48d1cc) ;  72 209 204
    ("MediumTurquoise"        . #x48d1cc) ;  72 209 204
    ("turquoise"              . #x40e0d0) ;  64 224 208
    ("cyan"                   . #x00ffff) ;   0 255 255
    ("light cyan"             . #xe0ffff) ; 224 255 255
    ("LightCyan"              . #xe0ffff) ; 224 255 255
    ("cadet blue"             . #x5f9ea0) ;  95 158 160
    ("CadetBlue"              . #x5f9ea0) ;  95 158 160
    ("medium aquamarine"      . #x66cdaa) ; 102 205 170
    ("MediumAquamarine"       . #x66cdaa) ; 102 205 170
    ("aquamarine"             . #x7fffd4) ; 127 255 212
    ("dark green"             . #x006400) ;   0 100   0
    ("DarkGreen"              . #x006400) ;   0 100   0
    ("dark olive green"       . #x556b2f) ;  85 107  47
    ("DarkOliveGreen"         . #x556b2f) ;  85 107  47
    ("dark sea green"         . #x8fbc8f) ; 143 188 143
    ("DarkSeaGreen"           . #x8fbc8f) ; 143 188 143
    ("sea green"              . #x2e8b57) ;  46 139  87
    ("SeaGreen"               . #x2e8b57) ;  46 139  87
    ("medium sea green"       . #x3cb371) ;  60 179 113
    ("MediumSeaGreen"         . #x3cb371) ;  60 179 113
    ("light sea green"        . #x20b2aa) ;  32 178 170
    ("LightSeaGreen"          . #x20b2aa) ;  32 178 170
    ("pale green"             . #x98fb98) ; 152 251 152
    ("PaleGreen"              . #x98fb98) ; 152 251 152
    ("spring green"           . #x00ff7f) ;   0 255 127
    ("SpringGreen"            . #x00ff7f) ;   0 255 127
    ("lawn green"             . #x7cfc00) ; 124 252   0
    ("LawnGreen"              . #x7cfc00) ; 124 252   0
    ("green"                  . #x00ff00) ;   0 255   0
    ("chartreuse"             . #x7fff00) ; 127 255   0
    ("medium spring green"    . #x00fa9a) ;   0 250 154
    ("MediumSpringGreen"      . #x00fa9a) ;   0 250 154
    ("green yellow"           . #xadff2f) ; 173 255  47
    ("GreenYellow"            . #xadff2f) ; 173 255  47
    ("lime green"             . #x32cd32) ;  50 205  50
    ("LimeGreen"              . #x32cd32) ;  50 205  50
    ("yellow green"           . #x9acd32) ; 154 205  50
    ("YellowGreen"            . #x9acd32) ; 154 205  50
    ("forest green"           . #x228b22) ;  34 139  34
    ("ForestGreen"            . #x228b22) ;  34 139  34
    ("olive drab"             . #x6b8e23) ; 107 142  35
    ("OliveDrab"              . #x6b8e23) ; 107 142  35
    ("dark khaki"             . #xbdb76b) ; 189 183 107
    ("DarkKhaki"              . #xbdb76b) ; 189 183 107
    ("khaki"                  . #xf0e68c) ; 240 230 140
    ("pale goldenrod"         . #xeee8aa) ; 238 232 170
    ("PaleGoldenrod"          . #xeee8aa) ; 238 232 170
    ("light goldenrod yellow" . #xfafad2) ; 250 250 210
    ("LightGoldenrodYellow"   . #xfafad2) ; 250 250 210
    ("light yellow"           . #xffffe0) ; 255 255 224
    ("LightYellow"            . #xffffe0) ; 255 255 224
    ("yellow"                 . #xffff00) ; 255 255   0
    ("gold"                   . #xffd700) ; 255 215   0
    ("light goldenrod"        . #xeedd82) ; 238 221 130
    ("LightGoldenrod"         . #xeedd82) ; 238 221 130
    ("goldenrod"              . #xdaa520) ; 218 165  32
    ("dark goldenrod"         . #xb8860b) ; 184 134  11
    ("DarkGoldenrod"          . #xb8860b) ; 184 134  11
    ("rosy brown"             . #xbc8f8f) ; 188 143 143
    ("RosyBrown"              . #xbc8f8f) ; 188 143 143
    ("indian red"             . #xcd5c5c) ; 205  92  92
    ("IndianRed"              . #xcd5c5c) ; 205  92  92
    ("saddle brown"           . #x8b4513) ; 139  69  19
    ("SaddleBrown"            . #x8b4513) ; 139  69  19
    ("sienna"                 . #xa0522d) ; 160  82  45
    ("peru"                   . #xcd853f) ; 205 133  63
    ("burlywood"              . #xdeb887) ; 222 184 135
    ("beige"                  . #xf5f5dc) ; 245 245 220
    ("wheat"                  . #xf5deb3) ; 245 222 179
    ("sandy brown"            . #xf4a460) ; 244 164  96
    ("SandyBrown"             . #xf4a460) ; 244 164  96
    ("tan"                    . #xd2b48c) ; 210 180 140
    ("chocolate"              . #xd2691e) ; 210 105  30
    ("firebrick"              . #xb22222) ; 178  34  34
    ("brown"                  . #xa52a2a) ; 165  42  42
    ("dark salmon"            . #xe9967a) ; 233 150 122
    ("DarkSalmon"             . #xe9967a) ; 233 150 122
    ("salmon"                 . #xfa8072) ; 250 128 114
    ("light salmon"           . #xffa07a) ; 255 160 122
    ("LightSalmon"            . #xffa07a) ; 255 160 122
    ("orange"                 . #xffa500) ; 255 165   0
    ("dark orange"            . #xff8c00) ; 255 140   0
    ("DarkOrange"             . #xff8c00) ; 255 140   0
    ("coral"                  . #xff7f50) ; 255 127  80
    ("light coral"            . #xf08080) ; 240 128 128
    ("LightCoral"             . #xf08080) ; 240 128 128
    ("tomato"                 . #xff6347) ; 255  99  71
    ("orange red"             . #xff4500) ; 255  69   0
    ("OrangeRed"              . #xff4500) ; 255  69   0
    ("red"                    . #xff0000) ; 255   0   0
    ("hot pink"               . #xff69b4) ; 255 105 180
    ("HotPink"                . #xff69b4) ; 255 105 180
    ("deep pink"              . #xff1493) ; 255  20 147
    ("DeepPink"               . #xff1493) ; 255  20 147
    ("pink"                   . #xffc0cb) ; 255 192 203
    ("light pink"             . #xffb6c1) ; 255 182 193
    ("LightPink"              . #xffb6c1) ; 255 182 193
    ("pale violet red"        . #xdb7093) ; 219 112 147
    ("PaleVioletRed"          . #xdb7093) ; 219 112 147
    ("maroon"                 . #xb03060) ; 176  48  96
    ("medium violet red"      . #xc71585) ; 199  21 133
    ("MediumVioletRed"        . #xc71585) ; 199  21 133
    ("violet red"             . #xd02090) ; 208  32 144
    ("VioletRed"              . #xd02090) ; 208  32 144
    ("magenta"                . #xff00ff) ; 255   0 255
    ("violet"                 . #xee82ee) ; 238 130 238
    ("plum"                   . #xdda0dd) ; 221 160 221
    ("orchid"                 . #xda70d6) ; 218 112 214
    ("medium orchid"          . #xba55d3) ; 186  85 211
    ("MediumOrchid"           . #xba55d3) ; 186  85 211
    ("dark orchid"            . #x9932cc) ; 153  50 204
    ("DarkOrchid"             . #x9932cc) ; 153  50 204
    ("dark violet"            . #x9400d3) ; 148   0 211
    ("DarkViolet"             . #x9400d3) ; 148   0 211
    ("blue violet"            . #x8a2be2) ; 138  43 226
    ("BlueViolet"             . #x8a2be2) ; 138  43 226
    ("purple"                 . #xa020f0) ; 160  32 240
    ("medium purple"          . #x9370db) ; 147 112 219
    ("MediumPurple"           . #x9370db) ; 147 112 219
    ("thistle"                . #xd8bfd8) ; 216 191 216
    ("snow1"                  . #xfffafa) ; 255 250 250
    ("snow2"                  . #xeee9e9) ; 238 233 233
    ("snow3"                  . #xcdc9c9) ; 205 201 201
    ("snow4"                  . #x8b8989) ; 139 137 137
    ("seashell1"              . #xfff5ee) ; 255 245 238
    ("seashell2"              . #xeee5de) ; 238 229 222
    ("seashell3"              . #xcdc5bf) ; 205 197 191
    ("seashell4"              . #x8b8682) ; 139 134 130
    ("AntiqueWhite1"          . #xffefdb) ; 255 239 219
    ("AntiqueWhite2"          . #xeedfcc) ; 238 223 204
    ("AntiqueWhite3"          . #xcdc0b0) ; 205 192 176
    ("AntiqueWhite4"          . #x8b8378) ; 139 131 120
    ("bisque1"                . #xffe4c4) ; 255 228 196
    ("bisque2"                . #xeed5b7) ; 238 213 183
    ("bisque3"                . #xcdb79e) ; 205 183 158
    ("bisque4"                . #x8b7d6b) ; 139 125 107
    ("PeachPuff1"             . #xffdab9) ; 255 218 185
    ("PeachPuff2"             . #xeecbad) ; 238 203 173
    ("PeachPuff3"             . #xcdaf95) ; 205 175 149
    ("PeachPuff4"             . #x8b7765) ; 139 119 101
    ("NavajoWhite1"           . #xffdead) ; 255 222 173
    ("NavajoWhite2"           . #xeecfa1) ; 238 207 161
    ("NavajoWhite3"           . #xcdb38b) ; 205 179 139
    ("NavajoWhite4"           . #x8b795e) ; 139 121  94
    ("LemonChiffon1"          . #xfffacd) ; 255 250 205
    ("LemonChiffon2"          . #xeee9bf) ; 238 233 191
    ("LemonChiffon3"          . #xcdc9a5) ; 205 201 165
    ("LemonChiffon4"          . #x8b8970) ; 139 137 112
    ("cornsilk1"              . #xfff8dc) ; 255 248 220
    ("cornsilk2"              . #xeee8cd) ; 238 232 205
    ("cornsilk3"              . #xcdc8b1) ; 205 200 177
    ("cornsilk4"              . #x8b8878) ; 139 136 120
    ("ivory1"                 . #xfffff0) ; 255 255 240
    ("ivory2"                 . #xeeeee0) ; 238 238 224
    ("ivory3"                 . #xcdcdc1) ; 205 205 193
    ("ivory4"                 . #x8b8b83) ; 139 139 131
    ("honeydew1"              . #xf0fff0) ; 240 255 240
    ("honeydew2"              . #xe0eee0) ; 224 238 224
    ("honeydew3"              . #xc1cdc1) ; 193 205 193
    ("honeydew4"              . #x838b83) ; 131 139 131
    ("LavenderBlush1"         . #xfff0f5) ; 255 240 245
    ("LavenderBlush2"         . #xeee0e5) ; 238 224 229
    ("LavenderBlush3"         . #xcdc1c5) ; 205 193 197
    ("LavenderBlush4"         . #x8b8386) ; 139 131 134
    ("MistyRose1"             . #xffe4e1) ; 255 228 225
    ("MistyRose2"             . #xeed5d2) ; 238 213 210
    ("MistyRose3"             . #xcdb7b5) ; 205 183 181
    ("MistyRose4"             . #x8b7d7b) ; 139 125 123
    ("azure1"                 . #xf0ffff) ; 240 255 255
    ("azure2"                 . #xe0eeee) ; 224 238 238
    ("azure3"                 . #xc1cdcd) ; 193 205 205
    ("azure4"                 . #x838b8b) ; 131 139 139
    ("SlateBlue1"             . #x836fff) ; 131 111 255
    ("SlateBlue2"             . #x7a67ee) ; 122 103 238
    ("SlateBlue3"             . #x6959cd) ; 105  89 205
    ("SlateBlue4"             . #x473c8b) ;  71  60 139
    ("RoyalBlue1"             . #x4876ff) ;  72 118 255
    ("RoyalBlue2"             . #x436eee) ;  67 110 238
    ("RoyalBlue3"             . #x3a5fcd) ;  58  95 205
    ("RoyalBlue4"             . #x27408b) ;  39  64 139
    ("blue1"                  . #x0000ff) ;   0   0 255
    ("blue2"                  . #x0000ee) ;   0   0 238
    ("blue3"                  . #x0000cd) ;   0   0 205
    ("blue4"                  . #x00008b) ;   0   0 139
    ("DodgerBlue1"            . #x1e90ff) ;  30 144 255
    ("DodgerBlue2"            . #x1c86ee) ;  28 134 238
    ("DodgerBlue3"            . #x1874cd) ;  24 116 205
    ("DodgerBlue4"            . #x104e8b) ;  16  78 139
    ("SteelBlue1"             . #x63b8ff) ;  99 184 255
    ("SteelBlue2"             . #x5cacee) ;  92 172 238
    ("SteelBlue3"             . #x4f94cd) ;  79 148 205
    ("SteelBlue4"             . #x36648b) ;  54 100 139
    ("DeepSkyBlue1"           . #x00bfff) ;   0 191 255
    ("DeepSkyBlue2"           . #x00b2ee) ;   0 178 238
    ("DeepSkyBlue3"           . #x009acd) ;   0 154 205
    ("DeepSkyBlue4"           . #x00688b) ;   0 104 139
    ("SkyBlue1"               . #x87ceff) ; 135 206 255
    ("SkyBlue2"               . #x7ec0ee) ; 126 192 238
    ("SkyBlue3"               . #x6ca6cd) ; 108 166 205
    ("SkyBlue4"               . #x4a708b) ;  74 112 139
    ("LightSkyBlue1"          . #xb0e2ff) ; 176 226 255
    ("LightSkyBlue2"          . #xa4d3ee) ; 164 211 238
    ("LightSkyBlue3"          . #x8db6cd) ; 141 182 205
    ("LightSkyBlue4"          . #x607b8b) ;  96 123 139
    ("SlateGray1"             . #xc6e2ff) ; 198 226 255
    ("SlateGray2"             . #xb9d3ee) ; 185 211 238
    ("SlateGray3"             . #x9fb6cd) ; 159 182 205
    ("SlateGray4"             . #x6c7b8b) ; 108 123 139
    ("LightSteelBlue1"        . #xcae1ff) ; 202 225 255
    ("LightSteelBlue2"        . #xbcd2ee) ; 188 210 238
    ("LightSteelBlue3"        . #xa2b5cd) ; 162 181 205
    ("LightSteelBlue4"        . #x6e7b8b) ; 110 123 139
    ("LightBlue1"             . #xbfefff) ; 191 239 255
    ("LightBlue2"             . #xb2dfee) ; 178 223 238
    ("LightBlue3"             . #x9ac0cd) ; 154 192 205
    ("LightBlue4"             . #x68838b) ; 104 131 139
    ("LightCyan1"             . #xe0ffff) ; 224 255 255
    ("LightCyan2"             . #xd1eeee) ; 209 238 238
    ("LightCyan3"             . #xb4cdcd) ; 180 205 205
    ("LightCyan4"             . #x7a8b8b) ; 122 139 139
    ("PaleTurquoise1"         . #xbbffff) ; 187 255 255
    ("PaleTurquoise2"         . #xaeeeee) ; 174 238 238
    ("PaleTurquoise3"         . #x96cdcd) ; 150 205 205
    ("PaleTurquoise4"         . #x668b8b) ; 102 139 139
    ("CadetBlue1"             . #x98f5ff) ; 152 245 255
    ("CadetBlue2"             . #x8ee5ee) ; 142 229 238
    ("CadetBlue3"             . #x7ac5cd) ; 122 197 205
    ("CadetBlue4"             . #x53868b) ;  83 134 139
    ("turquoise1"             . #x00f5ff) ;   0 245 255
    ("turquoise2"             . #x00e5ee) ;   0 229 238
    ("turquoise3"             . #x00c5cd) ;   0 197 205
    ("turquoise4"             . #x00868b) ;   0 134 139
    ("cyan1"                  . #x00ffff) ;   0 255 255
    ("cyan2"                  . #x00eeee) ;   0 238 238
    ("cyan3"                  . #x00cdcd) ;   0 205 205
    ("cyan4"                  . #x008b8b) ;   0 139 139
    ("DarkSlateGray1"         . #x97ffff) ; 151 255 255
    ("DarkSlateGray2"         . #x8deeee) ; 141 238 238
    ("DarkSlateGray3"         . #x79cdcd) ; 121 205 205
    ("DarkSlateGray4"         . #x528b8b) ;  82 139 139
    ("aquamarine1"            . #x7fffd4) ; 127 255 212
    ("aquamarine2"            . #x76eec6) ; 118 238 198
    ("aquamarine3"            . #x66cdaa) ; 102 205 170
    ("aquamarine4"            . #x458b74) ;  69 139 116
    ("DarkSeaGreen1"          . #xc1ffc1) ; 193 255 193
    ("DarkSeaGreen2"          . #xb4eeb4) ; 180 238 180
    ("DarkSeaGreen3"          . #x9bcd9b) ; 155 205 155
    ("DarkSeaGreen4"          . #x698b69) ; 105 139 105
    ("SeaGreen1"              . #x54ff9f) ;  84 255 159
    ("SeaGreen2"              . #x4eee94) ;  78 238 148
    ("SeaGreen3"              . #x43cd80) ;  67 205 128
    ("SeaGreen4"              . #x2e8b57) ;  46 139  87
    ("PaleGreen1"             . #x9aff9a) ; 154 255 154
    ("PaleGreen2"             . #x90ee90) ; 144 238 144
    ("PaleGreen3"             . #x7ccd7c) ; 124 205 124
    ("PaleGreen4"             . #x548b54) ;  84 139  84
    ("SpringGreen1"           . #x00ff7f) ;   0 255 127
    ("SpringGreen2"           . #x00ee76) ;   0 238 118
    ("SpringGreen3"           . #x00cd66) ;   0 205 102
    ("SpringGreen4"           . #x008b45) ;   0 139  69
    ("green1"                 . #x00ff00) ;   0 255   0
    ("green2"                 . #x00ee00) ;   0 238   0
    ("green3"                 . #x00cd00) ;   0 205   0
    ("green4"                 . #x008b00) ;   0 139   0
    ("chartreuse1"            . #x7fff00) ; 127 255   0
    ("chartreuse2"            . #x76ee00) ; 118 238   0
    ("chartreuse3"            . #x66cd00) ; 102 205   0
    ("chartreuse4"            . #x458b00) ;  69 139   0
    ("OliveDrab1"             . #xc0ff3e) ; 192 255  62
    ("OliveDrab2"             . #xb3ee3a) ; 179 238  58
    ("OliveDrab3"             . #x9acd32) ; 154 205  50
    ("OliveDrab4"             . #x698b22) ; 105 139  34
    ("DarkOliveGreen1"        . #xcaff70) ; 202 255 112
    ("DarkOliveGreen2"        . #xbcee68) ; 188 238 104
    ("DarkOliveGreen3"        . #xa2cd5a) ; 162 205  90
    ("DarkOliveGreen4"        . #x6e8b3d) ; 110 139  61
    ("khaki1"                 . #xfff68f) ; 255 246 143
    ("khaki2"                 . #xeee685) ; 238 230 133
    ("khaki3"                 . #xcdc673) ; 205 198 115
    ("khaki4"                 . #x8b864e) ; 139 134  78
    ("LightGoldenrod1"        . #xffec8b) ; 255 236 139
    ("LightGoldenrod2"        . #xeedc82) ; 238 220 130
    ("LightGoldenrod3"        . #xcdbe70) ; 205 190 112
    ("LightGoldenrod4"        . #x8b814c) ; 139 129  76
    ("LightYellow1"           . #xffffe0) ; 255 255 224
    ("LightYellow2"           . #xeeeed1) ; 238 238 209
    ("LightYellow3"           . #xcdcdb4) ; 205 205 180
    ("LightYellow4"           . #x8b8b7a) ; 139 139 122
    ("yellow1"                . #xffff00) ; 255 255   0
    ("yellow2"                . #xeeee00) ; 238 238   0
    ("yellow3"                . #xcdcd00) ; 205 205   0
    ("yellow4"                . #x8b8b00) ; 139 139   0
    ("gold1"                  . #xffd700) ; 255 215   0
    ("gold2"                  . #xeec900) ; 238 201   0
    ("gold3"                  . #xcdad00) ; 205 173   0
    ("gold4"                  . #x8b7500) ; 139 117   0
    ("goldenrod1"             . #xffc125) ; 255 193  37
    ("goldenrod2"             . #xeeb422) ; 238 180  34
    ("goldenrod3"             . #xcd9b1d) ; 205 155  29
    ("goldenrod4"             . #x8b6914) ; 139 105  20
    ("DarkGoldenrod1"         . #xffb90f) ; 255 185  15
    ("DarkGoldenrod2"         . #xeead0e) ; 238 173  14
    ("DarkGoldenrod3"         . #xcd950c) ; 205 149  12
    ("DarkGoldenrod4"         . #x8b6508) ; 139 101   8
    ("RosyBrown1"             . #xffc1c1) ; 255 193 193
    ("RosyBrown2"             . #xeeb4b4) ; 238 180 180
    ("RosyBrown3"             . #xcd9b9b) ; 205 155 155
    ("RosyBrown4"             . #x8b6969) ; 139 105 105
    ("IndianRed1"             . #xff6a6a) ; 255 106 106
    ("IndianRed2"             . #xee6363) ; 238  99  99
    ("IndianRed3"             . #xcd5555) ; 205  85  85
    ("IndianRed4"             . #x8b3a3a) ; 139  58  58
    ("sienna1"                . #xff8247) ; 255 130  71
    ("sienna2"                . #xee7942) ; 238 121  66
    ("sienna3"                . #xcd6839) ; 205 104  57
    ("sienna4"                . #x8b4726) ; 139  71  38
    ("burlywood1"             . #xffd39b) ; 255 211 155
    ("burlywood2"             . #xeec591) ; 238 197 145
    ("burlywood3"             . #xcdaa7d) ; 205 170 125
    ("burlywood4"             . #x8b7355) ; 139 115  85
    ("wheat1"                 . #xffe7ba) ; 255 231 186
    ("wheat2"                 . #xeed8ae) ; 238 216 174
    ("wheat3"                 . #xcdba96) ; 205 186 150
    ("wheat4"                 . #x8b7e66) ; 139 126 102
    ("tan1"                   . #xffa54f) ; 255 165  79
    ("tan2"                   . #xee9a49) ; 238 154  73
    ("tan3"                   . #xcd853f) ; 205 133  63
    ("tan4"                   . #x8b5a2b) ; 139  90  43
    ("chocolate1"             . #xff7f24) ; 255 127  36
    ("chocolate2"             . #xee7621) ; 238 118  33
    ("chocolate3"             . #xcd661d) ; 205 102  29
    ("chocolate4"             . #x8b4513) ; 139  69  19
    ("firebrick1"             . #xff3030) ; 255  48  48
    ("firebrick2"             . #xee2c2c) ; 238  44  44
    ("firebrick3"             . #xcd2626) ; 205  38  38
    ("firebrick4"             . #x8b1a1a) ; 139  26  26
    ("brown1"                 . #xff4040) ; 255  64  64
    ("brown2"                 . #xee3b3b) ; 238  59  59
    ("brown3"                 . #xcd3333) ; 205  51  51
    ("brown4"                 . #x8b2323) ; 139  35  35
    ("salmon1"                . #xff8c69) ; 255 140 105
    ("salmon2"                . #xee8262) ; 238 130  98
    ("salmon3"                . #xcd7054) ; 205 112  84
    ("salmon4"                . #x8b4c39) ; 139  76  57
    ("LightSalmon1"           . #xffa07a) ; 255 160 122
    ("LightSalmon2"           . #xee9572) ; 238 149 114
    ("LightSalmon3"           . #xcd8162) ; 205 129  98
    ("LightSalmon4"           . #x8b5742) ; 139  87  66
    ("orange1"                . #xffa500) ; 255 165   0
    ("orange2"                . #xee9a00) ; 238 154   0
    ("orange3"                . #xcd8500) ; 205 133   0
    ("orange4"                . #x8b5a00) ; 139  90   0
    ("DarkOrange1"            . #xff7f00) ; 255 127   0
    ("DarkOrange2"            . #xee7600) ; 238 118   0
    ("DarkOrange3"            . #xcd6600) ; 205 102   0
    ("DarkOrange4"            . #x8b4500) ; 139  69   0
    ("coral1"                 . #xff7256) ; 255 114  86
    ("coral2"                 . #xee6a50) ; 238 106  80
    ("coral3"                 . #xcd5b45) ; 205  91  69
    ("coral4"                 . #x8b3e2f) ; 139  62  47
    ("tomato1"                . #xff6347) ; 255  99  71
    ("tomato2"                . #xee5c42) ; 238  92  66
    ("tomato3"                . #xcd4f39) ; 205  79  57
    ("tomato4"                . #x8b3626) ; 139  54  38
    ("OrangeRed1"             . #xff4500) ; 255  69   0
    ("OrangeRed2"             . #xee4000) ; 238  64   0
    ("OrangeRed3"             . #xcd3700) ; 205  55   0
    ("OrangeRed4"             . #x8b2500) ; 139  37   0
    ("red1"                   . #xff0000) ; 255   0   0
    ("red2"                   . #xee0000) ; 238   0   0
    ("red3"                   . #xcd0000) ; 205   0   0
    ("red4"                   . #x8b0000) ; 139   0   0
    ("DeepPink1"              . #xff1493) ; 255  20 147
    ("DeepPink2"              . #xee1289) ; 238  18 137
    ("DeepPink3"              . #xcd1076) ; 205  16 118
    ("DeepPink4"              . #x8b0a50) ; 139  10  80
    ("HotPink1"               . #xff6eb4) ; 255 110 180
    ("HotPink2"               . #xee6aa7) ; 238 106 167
    ("HotPink3"               . #xcd6090) ; 205  96 144
    ("HotPink4"               . #x8b3a62) ; 139  58  98
    ("pink1"                  . #xffb5c5) ; 255 181 197
    ("pink2"                  . #xeea9b8) ; 238 169 184
    ("pink3"                  . #xcd919e) ; 205 145 158
    ("pink4"                  . #x8b636c) ; 139  99 108
    ("LightPink1"             . #xffaeb9) ; 255 174 185
    ("LightPink2"             . #xeea2ad) ; 238 162 173
    ("LightPink3"             . #xcd8c95) ; 205 140 149
    ("LightPink4"             . #x8b5f65) ; 139  95 101
    ("PaleVioletRed1"         . #xff82ab) ; 255 130 171
    ("PaleVioletRed2"         . #xee799f) ; 238 121 159
    ("PaleVioletRed3"         . #xcd6889) ; 205 104 137
    ("PaleVioletRed4"         . #x8b475d) ; 139  71  93
    ("maroon1"                . #xff34b3) ; 255  52 179
    ("maroon2"                . #xee30a7) ; 238  48 167
    ("maroon3"                . #xcd2990) ; 205  41 144
    ("maroon4"                . #x8b1c62) ; 139  28  98
    ("VioletRed1"             . #xff3e96) ; 255  62 150
    ("VioletRed2"             . #xee3a8c) ; 238  58 140
    ("VioletRed3"             . #xcd3278) ; 205  50 120
    ("VioletRed4"             . #x8b2252) ; 139  34  82
    ("magenta1"               . #xff00ff) ; 255   0 255
    ("magenta2"               . #xee00ee) ; 238   0 238
    ("magenta3"               . #xcd00cd) ; 205   0 205
    ("magenta4"               . #x8b008b) ; 139   0 139
    ("orchid1"                . #xff83fa) ; 255 131 250
    ("orchid2"                . #xee7ae9) ; 238 122 233
    ("orchid3"                . #xcd69c9) ; 205 105 201
    ("orchid4"                . #x8b4789) ; 139  71 137
    ("plum1"                  . #xffbbff) ; 255 187 255
    ("plum2"                  . #xeeaeee) ; 238 174 238
    ("plum3"                  . #xcd96cd) ; 205 150 205
    ("plum4"                  . #x8b668b) ; 139 102 139
    ("MediumOrchid1"          . #xe066ff) ; 224 102 255
    ("MediumOrchid2"          . #xd15fee) ; 209  95 238
    ("MediumOrchid3"          . #xb452cd) ; 180  82 205
    ("MediumOrchid4"          . #x7a378b) ; 122  55 139
    ("DarkOrchid1"            . #xbf3eff) ; 191  62 255
    ("DarkOrchid2"            . #xb23aee) ; 178  58 238
    ("DarkOrchid3"            . #x9a32cd) ; 154  50 205
    ("DarkOrchid4"            . #x68228b) ; 104  34 139
    ("purple1"                . #x9b30ff) ; 155  48 255
    ("purple2"                . #x912cee) ; 145  44 238
    ("purple3"                . #x7d26cd) ; 125  38 205
    ("purple4"                . #x551a8b) ;  85  26 139
    ("MediumPurple1"          . #xab82ff) ; 171 130 255
    ("MediumPurple2"          . #x9f79ee) ; 159 121 238
    ("MediumPurple3"          . #x8968cd) ; 137 104 205
    ("MediumPurple4"          . #x5d478b) ;  93  71 139
    ("thistle1"               . #xffe1ff) ; 255 225 255
    ("thistle2"               . #xeed2ee) ; 238 210 238
    ("thistle3"               . #xcdb5cd) ; 205 181 205
    ("thistle4"               . #x8b7b8b) ; 139 123 139
    ("gray0"                  . #x000000) ;   0   0   0
    ("grey0"                  . #x000000) ;   0   0   0
    ("gray1"                  . #x030303) ;   3   3   3
    ("grey1"                  . #x030303) ;   3   3   3
    ("gray2"                  . #x050505) ;   5   5   5
    ("grey2"                  . #x050505) ;   5   5   5
    ("gray3"                  . #x080808) ;   8   8   8
    ("grey3"                  . #x080808) ;   8   8   8
    ("gray4"                  . #x0a0a0a) ;  10  10  10
    ("grey4"                  . #x0a0a0a) ;  10  10  10
    ("gray5"                  . #x0d0d0d) ;  13  13  13
    ("grey5"                  . #x0d0d0d) ;  13  13  13
    ("gray6"                  . #x0f0f0f) ;  15  15  15
    ("grey6"                  . #x0f0f0f) ;  15  15  15
    ("gray7"                  . #x121212) ;  18  18  18
    ("grey7"                  . #x121212) ;  18  18  18
    ("gray8"                  . #x141414) ;  20  20  20
    ("grey8"                  . #x141414) ;  20  20  20
    ("gray9"                  . #x171717) ;  23  23  23
    ("grey9"                  . #x171717) ;  23  23  23
    ("gray10"                 . #x1a1a1a) ;  26  26  26
    ("grey10"                 . #x1a1a1a) ;  26  26  26
    ("gray11"                 . #x1c1c1c) ;  28  28  28
    ("grey11"                 . #x1c1c1c) ;  28  28  28
    ("gray12"                 . #x1f1f1f) ;  31  31  31
    ("grey12"                 . #x1f1f1f) ;  31  31  31
    ("gray13"                 . #x212121) ;  33  33  33
    ("grey13"                 . #x212121) ;  33  33  33
    ("gray14"                 . #x242424) ;  36  36  36
    ("grey14"                 . #x242424) ;  36  36  36
    ("gray15"                 . #x262626) ;  38  38  38
    ("grey15"                 . #x262626) ;  38  38  38
    ("gray16"                 . #x292929) ;  41  41  41
    ("grey16"                 . #x292929) ;  41  41  41
    ("gray17"                 . #x2b2b2b) ;  43  43  43
    ("grey17"                 . #x2b2b2b) ;  43  43  43
    ("gray18"                 . #x2e2e2e) ;  46  46  46
    ("grey18"                 . #x2e2e2e) ;  46  46  46
    ("gray19"                 . #x303030) ;  48  48  48
    ("grey19"                 . #x303030) ;  48  48  48
    ("gray20"                 . #x333333) ;  51  51  51
    ("grey20"                 . #x333333) ;  51  51  51
    ("gray21"                 . #x363636) ;  54  54  54
    ("grey21"                 . #x363636) ;  54  54  54
    ("gray22"                 . #x383838) ;  56  56  56
    ("grey22"                 . #x383838) ;  56  56  56
    ("gray23"                 . #x3b3b3b) ;  59  59  59
    ("grey23"                 . #x3b3b3b) ;  59  59  59
    ("gray24"                 . #x3d3d3d) ;  61  61  61
    ("grey24"                 . #x3d3d3d) ;  61  61  61
    ("gray25"                 . #x404040) ;  64  64  64
    ("grey25"                 . #x404040) ;  64  64  64
    ("gray26"                 . #x424242) ;  66  66  66
    ("grey26"                 . #x424242) ;  66  66  66
    ("gray27"                 . #x454545) ;  69  69  69
    ("grey27"                 . #x454545) ;  69  69  69
    ("gray28"                 . #x474747) ;  71  71  71
    ("grey28"                 . #x474747) ;  71  71  71
    ("gray29"                 . #x4a4a4a) ;  74  74  74
    ("grey29"                 . #x4a4a4a) ;  74  74  74
    ("gray30"                 . #x4d4d4d) ;  77  77  77
    ("grey30"                 . #x4d4d4d) ;  77  77  77
    ("gray31"                 . #x4f4f4f) ;  79  79  79
    ("grey31"                 . #x4f4f4f) ;  79  79  79
    ("gray32"                 . #x525252) ;  82  82  82
    ("grey32"                 . #x525252) ;  82  82  82
    ("gray33"                 . #x545454) ;  84  84  84
    ("grey33"                 . #x545454) ;  84  84  84
    ("gray34"                 . #x575757) ;  87  87  87
    ("grey34"                 . #x575757) ;  87  87  87
    ("gray35"                 . #x595959) ;  89  89  89
    ("grey35"                 . #x595959) ;  89  89  89
    ("gray36"                 . #x5c5c5c) ;  92  92  92
    ("grey36"                 . #x5c5c5c) ;  92  92  92
    ("gray37"                 . #x5e5e5e) ;  94  94  94
    ("grey37"                 . #x5e5e5e) ;  94  94  94
    ("gray38"                 . #x616161) ;  97  97  97
    ("grey38"                 . #x616161) ;  97  97  97
    ("gray39"                 . #x636363) ;  99  99  99
    ("grey39"                 . #x636363) ;  99  99  99
    ("gray40"                 . #x666666) ; 102 102 102
    ("grey40"                 . #x666666) ; 102 102 102
    ("gray41"                 . #x696969) ; 105 105 105
    ("grey41"                 . #x696969) ; 105 105 105
    ("gray42"                 . #x6b6b6b) ; 107 107 107
    ("grey42"                 . #x6b6b6b) ; 107 107 107
    ("gray43"                 . #x6e6e6e) ; 110 110 110
    ("grey43"                 . #x6e6e6e) ; 110 110 110
    ("gray44"                 . #x707070) ; 112 112 112
    ("grey44"                 . #x707070) ; 112 112 112
    ("gray45"                 . #x737373) ; 115 115 115
    ("grey45"                 . #x737373) ; 115 115 115
    ("gray46"                 . #x757575) ; 117 117 117
    ("grey46"                 . #x757575) ; 117 117 117
    ("gray47"                 . #x787878) ; 120 120 120
    ("grey47"                 . #x787878) ; 120 120 120
    ("gray48"                 . #x7a7a7a) ; 122 122 122
    ("grey48"                 . #x7a7a7a) ; 122 122 122
    ("gray49"                 . #x7d7d7d) ; 125 125 125
    ("grey49"                 . #x7d7d7d) ; 125 125 125
    ("gray50"                 . #x7f7f7f) ; 127 127 127
    ("grey50"                 . #x7f7f7f) ; 127 127 127
    ("gray51"                 . #x828282) ; 130 130 130
    ("grey51"                 . #x828282) ; 130 130 130
    ("gray52"                 . #x858585) ; 133 133 133
    ("grey52"                 . #x858585) ; 133 133 133
    ("gray53"                 . #x878787) ; 135 135 135
    ("grey53"                 . #x878787) ; 135 135 135
    ("gray54"                 . #x8a8a8a) ; 138 138 138
    ("grey54"                 . #x8a8a8a) ; 138 138 138
    ("gray55"                 . #x8c8c8c) ; 140 140 140
    ("grey55"                 . #x8c8c8c) ; 140 140 140
    ("gray56"                 . #x8f8f8f) ; 143 143 143
    ("grey56"                 . #x8f8f8f) ; 143 143 143
    ("gray57"                 . #x919191) ; 145 145 145
    ("grey57"                 . #x919191) ; 145 145 145
    ("gray58"                 . #x949494) ; 148 148 148
    ("grey58"                 . #x949494) ; 148 148 148
    ("gray59"                 . #x969696) ; 150 150 150
    ("grey59"                 . #x969696) ; 150 150 150
    ("gray60"                 . #x999999) ; 153 153 153
    ("grey60"                 . #x999999) ; 153 153 153
    ("gray61"                 . #x9c9c9c) ; 156 156 156
    ("grey61"                 . #x9c9c9c) ; 156 156 156
    ("gray62"                 . #x9e9e9e) ; 158 158 158
    ("grey62"                 . #x9e9e9e) ; 158 158 158
    ("gray63"                 . #xa1a1a1) ; 161 161 161
    ("grey63"                 . #xa1a1a1) ; 161 161 161
    ("gray64"                 . #xa3a3a3) ; 163 163 163
    ("grey64"                 . #xa3a3a3) ; 163 163 163
    ("gray65"                 . #xa6a6a6) ; 166 166 166
    ("grey65"                 . #xa6a6a6) ; 166 166 166
    ("gray66"                 . #xa8a8a8) ; 168 168 168
    ("grey66"                 . #xa8a8a8) ; 168 168 168
    ("gray67"                 . #xababab) ; 171 171 171
    ("grey67"                 . #xababab) ; 171 171 171
    ("gray68"                 . #xadadad) ; 173 173 173
    ("grey68"                 . #xadadad) ; 173 173 173
    ("gray69"                 . #xb0b0b0) ; 176 176 176
    ("grey69"                 . #xb0b0b0) ; 176 176 176
    ("gray70"                 . #xb3b3b3) ; 179 179 179
    ("grey70"                 . #xb3b3b3) ; 179 179 179
    ("gray71"                 . #xb5b5b5) ; 181 181 181
    ("grey71"                 . #xb5b5b5) ; 181 181 181
    ("gray72"                 . #xb8b8b8) ; 184 184 184
    ("grey72"                 . #xb8b8b8) ; 184 184 184
    ("gray73"                 . #xbababa) ; 186 186 186
    ("grey73"                 . #xbababa) ; 186 186 186
    ("gray74"                 . #xbdbdbd) ; 189 189 189
    ("grey74"                 . #xbdbdbd) ; 189 189 189
    ("gray75"                 . #xbfbfbf) ; 191 191 191
    ("grey75"                 . #xbfbfbf) ; 191 191 191
    ("gray76"                 . #xc2c2c2) ; 194 194 194
    ("grey76"                 . #xc2c2c2) ; 194 194 194
    ("gray77"                 . #xc4c4c4) ; 196 196 196
    ("grey77"                 . #xc4c4c4) ; 196 196 196
    ("gray78"                 . #xc7c7c7) ; 199 199 199
    ("grey78"                 . #xc7c7c7) ; 199 199 199
    ("gray79"                 . #xc9c9c9) ; 201 201 201
    ("grey79"                 . #xc9c9c9) ; 201 201 201
    ("gray80"                 . #xcccccc) ; 204 204 204
    ("grey80"                 . #xcccccc) ; 204 204 204
    ("gray81"                 . #xcfcfcf) ; 207 207 207
    ("grey81"                 . #xcfcfcf) ; 207 207 207
    ("gray82"                 . #xd1d1d1) ; 209 209 209
    ("grey82"                 . #xd1d1d1) ; 209 209 209
    ("gray83"                 . #xd4d4d4) ; 212 212 212
    ("grey83"                 . #xd4d4d4) ; 212 212 212
    ("gray84"                 . #xd6d6d6) ; 214 214 214
    ("grey84"                 . #xd6d6d6) ; 214 214 214
    ("gray85"                 . #xd9d9d9) ; 217 217 217
    ("grey85"                 . #xd9d9d9) ; 217 217 217
    ("gray86"                 . #xdbdbdb) ; 219 219 219
    ("grey86"                 . #xdbdbdb) ; 219 219 219
    ("gray87"                 . #xdedede) ; 222 222 222
    ("grey87"                 . #xdedede) ; 222 222 222
    ("gray88"                 . #xe0e0e0) ; 224 224 224
    ("grey88"                 . #xe0e0e0) ; 224 224 224
    ("gray89"                 . #xe3e3e3) ; 227 227 227
    ("grey89"                 . #xe3e3e3) ; 227 227 227
    ("gray90"                 . #xe5e5e5) ; 229 229 229
    ("grey90"                 . #xe5e5e5) ; 229 229 229
    ("gray91"                 . #xe8e8e8) ; 232 232 232
    ("grey91"                 . #xe8e8e8) ; 232 232 232
    ("gray92"                 . #xebebeb) ; 235 235 235
    ("grey92"                 . #xebebeb) ; 235 235 235
    ("gray93"                 . #xededed) ; 237 237 237
    ("grey93"                 . #xededed) ; 237 237 237
    ("gray94"                 . #xf0f0f0) ; 240 240 240
    ("grey94"                 . #xf0f0f0) ; 240 240 240
    ("gray95"                 . #xf2f2f2) ; 242 242 242
    ("grey95"                 . #xf2f2f2) ; 242 242 242
    ("gray96"                 . #xf5f5f5) ; 245 245 245
    ("grey96"                 . #xf5f5f5) ; 245 245 245
    ("gray97"                 . #xf7f7f7) ; 247 247 247
    ("grey97"                 . #xf7f7f7) ; 247 247 247
    ("gray98"                 . #xfafafa) ; 250 250 250
    ("grey98"                 . #xfafafa) ; 250 250 250
    ("gray99"                 . #xfcfcfc) ; 252 252 252
    ("grey99"                 . #xfcfcfc) ; 252 252 252
    ("gray100"                . #xffffff) ; 255 255 255
    ("grey100"                . #xffffff) ; 255 255 255
    ("dark grey"              . #xa9a9a9) ; 169 169 169
    ("DarkGrey"               . #xa9a9a9) ; 169 169 169
    ("dark gray"              . #xa9a9a9) ; 169 169 169
    ("DarkGray"               . #xa9a9a9) ; 169 169 169
    ("dark blue"              . #x00008b) ;   0   0 139
    ("DarkBlue"               . #x00008b) ;   0   0 139
    ("dark cyan"              . #x008b8b) ;   0 139 139
    ("DarkCyan"               . #x008b8b) ;   0 139 139
    ("dark magenta"           . #x8b008b) ; 139   0 139
    ("DarkMagenta"            . #x8b008b) ; 139   0 139
    ("dark red"               . #x8b0000) ; 139   0   0
    ("DarkRed"                . #x8b0000) ; 139   0   0
    ("light green"            . #x90ee90) ; 144 238 144
    ("LightGreen"             . #x90ee90) ; 144 238 144
    )
  "X11R6 での COLOR-NAME と RGB値 の対応リスト")

(defvar *color-X11R6-unique-name-alist* nil
  "*color-X11R6-name-alist* から別名の COLOR-NAME を除外した対応リスト")
(defun color-get-X11R6-unique-name-alist (&optional (gray t) space)
  "別名を除外した X11R6 での COLOR-NAME と RGB値 の対応を生成。
*color-X11R6-unique-name-alist* に値をセットする。
引数：
  GRAY
    t   : gray を含む名前を残す
    nil : grey を含む名前を残す
  SPACE
    t   : 空白を含む名前を残す
    nil : 空白を含まない名前を残す"
  (flet ((color-get-X11R6-unique-name-alist-1 (name-list)
           (when (> (length name-list) 1)
             (let (tmp-name-list)
               (dolist (name name-list)
                 (if (string-matchp (if gray "gray" "grey") name)
                     (push name tmp-name-list)))
               (when tmp-name-list
                 (setq name-list (nreverse tmp-name-list))
                 (setq tmp-name-list nil))
               (when (plusp (length name-list))
                 (dolist (name name-list)
                   (if space
                       (if (string-match " " name)
                           (push name tmp-name-list))
                     (if (not (string-match " " name))
                         (push name tmp-name-list))))
                 (when tmp-name-list
                   (setq name-list (nreverse tmp-name-list))))))
           (car name-list)))
  (let (next-name code next-code name-list unique-name-alist)
    (setq code (cdar *color-X11R6-name-alist*))
    (push (caar *color-X11R6-name-alist*) name-list)
    (dolist (x (cdr *color-X11R6-name-alist*))
      (setq next-name (car x)
            next-code (cdr x))
      (when (/= code next-code)
        (push (cons (color-get-X11R6-unique-name-alist-1 name-list) code)
              unique-name-alist)
        (setq code next-code)
        (setq name-list nil))
      (push next-name name-list))
    (push (cons (color-get-X11R6-unique-name-alist-1 name-list) next-code)
          unique-name-alist)
    (setq *color-X11R6-unique-name-alist* (nreverse unique-name-alist)))))
(color-get-X11R6-unique-name-alist)

;; case-fold t
(defvar *color-HTML3.2/4.0-name-alist*
  '(("Black"                   . #x000000)
    ("Gray"                    . #x808080)
    ("Silver"                  . #xc0c0c0)
    ("White"                   . #xffffff)
    ("Maroon"                  . #x800000)
    ("Red"                     . #xff0000)
    ("Purple"                  . #x800080)
    ("Fuchsia"                 . #xff00ff)
    ("Green"                   . #x008000)
    ("Lime"                    . #x00ff00)
    ("Olive"                   . #x808000)
    ("Yellow"                  . #xffff00)
    ("Navy"                    . #x000080)
    ("Blue"                    . #x0000ff)
    ("Teal"                    . #x008080)
    ("Aqua"                    . #x00ffff))
  "HTML3.2/4.0 での COLOR-NAME と RGB値 の対応リスト")

(defvar *color-Mozilla/MSIE-name-alist*
  '(("AliceBlue"               . #xf0f8ff)
    ("AntiqueWhite"            . #xfaebd7)
    ("Aqua"                    . #x00ffff)
    ("Aquamarine"              . #x7fffd4)
    ("Azure"                   . #xf0ffff)
    ("Beige"                   . #xf5f5dc)
    ("Bisque"                  . #xffe4c4)
    ("Black"                   . #x000000)
    ("BlanchedAlmond"          . #xffebcd)
    ("Blue"                    . #x0000ff)
    ("BlueViolet"              . #x8a2be2)
    ("Brown"                   . #xa52a2a)
    ("Burlywood"               . #xdeb887)
    ("CadetBlue"               . #x5f9ea0)
    ("Chartreuse"              . #x7fff00)
    ("Chocolate"               . #xd2691e)
    ("Coral"                   . #xff7f50)
    ("CornflowerBlue"          . #x6495ed)
    ("CornSilk"                . #xfff8dc)
    ("Crimson"                 . #xdc143c)
    ("Cyan"                    . #x00ffff)
    ("DarkBlue"                . #x00008b)
    ("DarkCyan"                . #x008b8b)
    ("DarkGoldenrod"           . #xb8860b)
    ("DarkGray"                . #xa9a9a9)
    ("DarkGreen"               . #x006400)
    ("DarkKhaki"               . #xbdb76b)
    ("DarkMagenta"             . #x8b008b)
    ("DarkOliveGreen"          . #x556b2f)
    ("DarkOrange"              . #xff8c00)
    ("DarkOrchid"              . #x9932cc)
    ("DarkRed"                 . #x8b0000)
    ("DarkSalmon"              . #xe9967a)
    ("DarkSeaGreen"            . #x8fbc8f)
    ("DarkSlateBlue"           . #x483d8b)
    ("DarkSlateGray"           . #x2f4f4f)
    ("DarkTurquoise"           . #x00ced1)
    ("DarkViolet"              . #x9400d3)
    ("DeepPink"                . #xff1493)
    ("DeepSkyBlue"             . #x00bfff)
    ("DimGray"                 . #x696969)
    ("DodgerBlue"              . #x1e90ff)
    ("FireBrick"               . #xb22222)
    ("FloralWhite"             . #xfffaf0)
    ("ForestGreen"             . #x228b22)
    ("Fuchsia"                 . #xff00ff)
    ("Gainsboro"               . #xdcdcdc)
    ("GhostWhite"              . #xf8f8ff)
    ("Gold"                    . #xffd700)
    ("Goldenrod"               . #xdaa520)
    ("Gray"                    . #x808080)
    ("Green"                   . #x008000)
    ("GreenYellow"             . #xadff2f)
    ("Honeydew"                . #xf0fff0)
    ("HotPink"                 . #xff69b4)
    ("IndianRed"               . #xcd5c5c)
    ("Indigo"                  . #x4b0082)
    ("Ivory"                   . #xfffff0)
    ("Khaki"                   . #xf0e68c)
    ("Lavender"                . #xe6e6fa)
    ("LavenderBlush"           . #xfff0f5)
    ("LawnGreen"               . #x7cfc00)
    ("LemonChiffon"            . #xfffacd)
    ("LightBlue"               . #xadd8e6)
    ("LightCoral"              . #xf08080)
    ("LightCyan"               . #xe0ffff)
    ("LightGoldenrodYellow"    . #xfafad2)
    ("LightGreen"              . #x90ee90)
    ("LightGrey"               . #xd3d3d3)
    ("LightPink"               . #xffb6c1)
    ("LightSalmon"             . #xffa07a)
    ("LightSeaGreen"           . #x20b2aa)
    ("LightSkyBlue"            . #x87cefa)
    ("LightSlateGray"          . #x778899)
    ("LightSteelBlue"          . #xb0c4de)
    ("LightYellow"             . #xffffe0)
    ("Lime"                    . #x00ff00)
    ("LimeGreen"               . #x32cd32)
    ("Linen"                   . #xfaf0e6)
    ("Magenta"                 . #xff00ff)
    ("Maroon"                  . #x800000)
    ("MediumAquamarine"        . #x66cdaa)
    ("MediumBlue"              . #x0000cd)
    ("MediumOrchid"            . #xba55d3)
    ("MediumPurple"            . #x9370db)
    ("MediumSeaGreen"          . #x3cb371)
    ("MediumSlateBlue"         . #x7b68ee)
    ("MediumSpringGreen"       . #x00fa9a)
    ("MediumTurquoise"         . #x48d1cc)
    ("MediumVioletRed"         . #xc71585)
    ("MidnightBlue"            . #x191970)
    ("MintCream"               . #xf5fffa)
    ("MistyRose"               . #xffe4e1)
    ("Moccasin"                . #xffe4b5)
    ("NavajoWhite"             . #xffdead)
    ("Navy"                    . #x000080)
    ("OldLace"                 . #xfdf5e6)
    ("Olive"                   . #x808000)
    ("OliveDrab"               . #x6b8e23)
    ("Orange"                  . #xffa500)
    ("OrangeRed"               . #xff4500)
    ("Orchid"                  . #xda70d6)
    ("PaleGoldenrod"           . #xeee8aa)
    ("PaleGreen"               . #x98fb98)
    ("PaleTurquoise"           . #xafeeee)
    ("PaleVioletRed"           . #xdb7093)
    ("PapayaWhip"              . #xffefd5)
    ("PeachPuff"               . #xffdab9)
    ("Peru"                    . #xcd853f)
    ("Pink"                    . #xffc0cb)
    ("Plum"                    . #xdda0dd)
    ("PowderBlue"              . #xb0e0e6)
    ("Purple"                  . #x800080)
    ("Red"                     . #xff0000)
    ("RosyBrown"               . #xbc8f8f)
    ("RoyalBlue"               . #x4169e1)
    ("SaddleBrown"             . #x8b4513)
    ("Salmon"                  . #xfa8072)
    ("SandyBrown"              . #xf4a460)
    ("SeaGreen"                . #x2e8b57)
    ("SeaShell"                . #xfff5ee)
    ("Sienna"                  . #xa0522d)
    ("Silver"                  . #xc0c0c0)
    ("SkyBlue"                 . #x87ceeb)
    ("SlateBlue"               . #x6a5acd)
    ("SlateGray"               . #x708090)
    ("Snow"                    . #xfffafa)
    ("SpringGreen"             . #x00ff7f)
    ("SteelBlue"               . #x4682b4)
    ("Tan"                     . #xd2b48c)
    ("Teal"                    . #x008080)
    ("Thistle"                 . #xd8bfd8)
    ("Tomato"                  . #xff6347)
    ("Turquoise"               . #x40e0d0)
    ("Violet"                  . #xee82ee)
    ("Wheat"                   . #xf5deb3)
    ("White"                   . #xffffff)
    ("WhiteSmoke"              . #xf5f5f5)
    ("Yellow"                  . #xffff00)
    ("YellowGreen"             . #x9acd32))
  "Mozilla/MSIE での COLOR-NAME と RGB値 の対応リスト")

(defvar *color-discrepancy-X11R6-and-Mozilla/MSIE-name-list*
  '("Gray"
    "Green"
    "Maroon"
    "Purple")
  "X11R6 と Mozilla/MSIE で RGB値 の異なる COLOR-NAME のリスト")

(defvar *color-system-colors-id-xyzzy-name-alist*
  `((,winapi::COLOR_SCROLLBAR           . "スクロールバー")
    (,winapi::COLOR_BACKGROUND          . "デスクトップ")
    (,winapi::COLOR_ACTIVECAPTION       . "アクティブタイトルバー")
    (,winapi::COLOR_INACTIVECAPTION     . "非アクティブタイトルバー")
    (,winapi::COLOR_MENU                . "メニューの背景")
    (,winapi::COLOR_WINDOW              . "ウィンドウの背景")
    (,winapi::COLOR_WINDOWFRAME         . "ウィンドウの枠")
    (,winapi::COLOR_MENUTEXT            . "メニューの文字")
    (,winapi::COLOR_WINDOWTEXT          . "ウィンドウの文字")
    (,winapi::COLOR_CAPTIONTEXT         . "アクティブタイトルの文字")
    (,winapi::COLOR_ACTIVEBORDER        . "アクティブウィンドウの境界")
    (,winapi::COLOR_INACTIVEBORDER      . "非アクティブウィンドウの境界")
    (,winapi::COLOR_APPWORKSPACE        . "アプリケーション作業域")
    (,winapi::COLOR_HIGHLIGHT           . "選択項目の背景")
    (,winapi::COLOR_HIGHLIGHTTEXT       . "選択項目の文字")
    (,winapi::COLOR_BTNFACE             . "3Dオブジェクトの表面")
    (,winapi::COLOR_BTNSHADOW           . "3Dオブジェクトの影")
    (,winapi::COLOR_GRAYTEXT            . "灰色の文字")
    (,winapi::COLOR_BTNTEXT             . "3Dオブジェクトの文字")
    (,winapi::COLOR_INACTIVECAPTIONTEXT . "非アクティブタイトルの文字")
    (,winapi::COLOR_BTNHILIGHT          . "3Dオブジェクトのテカリ"))
  "SYSTEM COLOR-ID と xyzzy での SYSTEM COLOR-NAME の対応リスト")
(defvar *color-system-colors-id-alist* nil
  "SYSTEM COLOR-ID と RGB値 の対応リスト")
(defvar *color-system-colors-xyzzy-name-alist* nil
  "xyzzy での SYSTEM COLOR-NAME と RGB値 の対応リスト")
(defun color-get-system-colors ()
  "SYSTEM COLOR-ID と RGB値 の対応、を生成。
*color-system-colors-id-alist*, *color-system-colors-xyzzy-name-alist* に
値をセットする。"
  (let (id xyzzy-name code colors-id-alist colors-name-alist)
    (dolist (x *color-system-colors-id-xyzzy-name-alist*)
      (setq id (car x))
      (setq xyzzy-name (cdr x))
      (setq code (color-bgr2rgb (winapi::GetSysColor id)))
      (push (cons id code) colors-id-alist)
      (push (cons xyzzy-name code) colors-name-alist))
    (setq *color-system-colors-id-alist* (nreverse colors-id-alist))
    (setq *color-system-colors-xyzzy-name-alist* (nreverse colors-name-alist))))

(color-get-system-colors)

(defvar *color-xyzzy-colors-alist*
  ;; name                           display-name             default
  '(("[Colors]textColor"            "文字色"                 winapi::COLOR_WINDOWTEXT)
    ("[Colors]backColor"            "背景色"                 winapi::COLOR_WINDOW)
    ("[Colors]ctlColor"             "制御文字"               #x808000)
    ("[Colors]selectionTextColor"   "選択文字色"             winapi::COLOR_HIGHLIGHTTEXT)
    ("[Colors]selectionBackColor"   "選択背景色"             winapi::COLOR_HIGHLIGHT)
    ("[Colors]kwdColor1"            "キーワード1"            #x0000ff)
    ("[Colors]kwdColor2"            "キーワード2"            #x004000)
    ("[Colors]kwdColor3"            "キーワード3"            #x800080)
    ("[Colors]stringColor"          "文字列"                 #x004000)
    ("[Colors]commentColor"         "コメント"               #x008000)
    ("[Colors]tagColor"             "タグ"                   #x404000)
    ("[Colors]cursorColor"          "行カーソル"             #x800080)
    ("[Colors]caretColor"           "キャレット"             #x000000)
    ("[Colors]imeCaretColor"        "IMEキャレット"          #x800000)
    ("[Colors]linenum"              "行番号"                 winapi::COLOR_WINDOWTEXT)
    ("[Colors]reverse"              "ニセ反転色"             winapi::COLOR_BACKGROUND)
    ("[Colors]unselectedModeLineFg" "モード行文字色"         winapi::COLOR_BTNTEXT)
    ("[Colors]unselectedModeLineBg" "モード行背景色"         winapi::COLOR_BTNFACE)
    ("[Colors]modeLineFg"           "選択モード行文字色"     winapi::COLOR_BTNHILIGHT)
    ("[Colors]modeLineBg"           "選択モード行背景色"     winapi::COLOR_BTNTEXT)
    ("[Filer]textColor"             "ファイラ文字色"         winapi::COLOR_WINDOWTEXT)
    ("[Filer]backColor"             "ファイラ背景色"         winapi::COLOR_WINDOW)
    ("[Filer]highlightTextColor"    "ファイラ選択文字色"     winapi::COLOR_HIGHLIGHTTEXT)
    ("[Filer]highlightBackColor"    "ファイラ選択背景色"     winapi::COLOR_HIGHLIGHT)
    ("[Filer]cursorColor"           "ファイラカーソル色"     #xc000c0)
    ("[Colors]buftabSelFg"          "選択バッファタブ文字色" winapi::COLOR_BTNTEXT)
    ("[Colors]buftabSelBg"          "選択バッファタブ背景色" winapi::COLOR_BTNFACE)
    ("[Colors]buftabDispFg"         "表示バッファタブ文字色" winapi::COLOR_BTNTEXT)
    ("[Colors]buftabDispBg"         "表示バッファタブ背景色" winapi::COLOR_BTNFACE)
    ("[Colors]buftabFg"             "バッファタブ文字色"     winapi::COLOR_BTNTEXT)
    ("[Colors]buftabBg"             "バッファタブ背景色"     winapi::COLOR_BTNFACE)
    ("[Colors]tabSelFg"             "選択タブ文字色"         winapi::COLOR_BTNTEXT)
    ("[Colors]tabSelBg"             "選択タブ背景色"         winapi::COLOR_BTNFACE)
    ("[Colors]tabFg"                "タブ文字色"             winapi::COLOR_BTNTEXT)
    ("[Colors]tabBg"                "タブ背景色"             winapi::COLOR_BTNFACE)
    ("[Colors]fg1"                  "文字1"                  #xff0000)
    ("[Colors]fg2"                  "文字2"                  #x00ff00)
    ("[Colors]fg3"                  "文字3"                  #xffff00)
    ("[Colors]fg4"                  "文字4"                  #x0000ff)
    ("[Colors]fg5"                  "文字5"                  #xff00ff)
    ("[Colors]fg6"                  "文字6"                  #x00ffff)
    ("[Colors]fg7"                  "文字7"                  #xffffff)
    ("[Colors]fg8"                  "文字8"                  #x000000)
    ("[Colors]fg9"                  "文字9"                  #x800000)
    ("[Colors]fg10"                 "文字10"                 #x008000)
    ("[Colors]fg11"                 "文字11"                 #x808000)
    ("[Colors]fg12"                 "文字12"                 #x000080)
    ("[Colors]fg13"                 "文字13"                 #x800080)
    ("[Colors]fg14"                 "文字14"                 #x008080)
    ("[Colors]fg15"                 "文字15"                 #x808080)
    ("[Colors]bg1"                  "背景1"                  #xff0000)
    ("[Colors]bg2"                  "背景2"                  #x00ff00)
    ("[Colors]bg3"                  "背景3"                  #xffff00)
    ("[Colors]bg4"                  "背景4"                  #x0000ff)
    ("[Colors]bg5"                  "背景5"                  #xff00ff)
    ("[Colors]bg6"                  "背景6"                  #x00ffff)
    ("[Colors]bg7"                  "背景7"                  #xffffff)
    ("[Colors]bg8"                  "背景8"                  #x000000)
    ("[Colors]bg9"                  "背景9"                  #x800000)
    ("[Colors]bg10"                 "背景10"                 #x008000)
    ("[Colors]bg11"                 "背景11"                 #x808000)
    ("[Colors]bg12"                 "背景12"                 #x000080)
    ("[Colors]bg13"                 "背景13"                 #x800080)
    ("[Colors]bg14"                 "背景14"                 #x008080)
    ("[Colors]bg15"                 "背景15"                 #x808080)
    ;;
#|
    ("[Colors]custColor0"           "?カスタムカラー0"       #xffffff)
    ("[Colors]custColor1"           "?カスタムカラー1"       #xffffff)
    ("[Colors]custColor2"           "?カスタムカラー2"       #xffffff)
    ("[Colors]custColor3"           "?カスタムカラー3"       #xffffff)
    ("[Colors]custColor4"           "?カスタムカラー4"       #xffffff)
    ("[Colors]custColor5"           "?カスタムカラー5"       #xffffff)
    ("[Colors]custColor6"           "?カスタムカラー6"       #xffffff)
    ("[Colors]custColor7"           "?カスタムカラー7"       #xffffff)
    ("[Colors]custColor8"           "?カスタムカラー8"       #xffffff)
    ("[Colors]custColor9"           "?カスタムカラー9"       #xffffff)
    ("[Colors]custColor10"          "?カスタムカラー10"      #xffffff)
    ("[Colors]custColor11"          "?カスタムカラー11"      #xffffff)
    ("[Colors]custColor12"          "?カスタムカラー12"      #xffffff)
    ("[Colors]custColor13"          "?カスタムカラー13"      #xffffff)
    ("[Colors]custColor14"          "?カスタムカラー14"      #xffffff)
    ("[Colors]custColor15"          "?カスタムカラー15"      #xffffff)
|#
    )
  "xyzzy の色情報を取得するために必要な内部情報")

(defvar *color-xyzzy-colors-name-alist* nil
  "xyzzy での COLOR-NAME と RGB値 の対応リスト")
(defun color-get-xyzzy-colors ()
  "xyzzy での COLOR-NAME と RGB値 の対応リストを生成。
*color-xyzzy-colors-name-alist* に値をセットする。"
  (let ((ini (si:make-string-chunk
              (map-slash-to-backslash (merge-pathnames "xyzzy.ini" (user-config-path)))))
        colors-name-alist bgr-str bgr system-color-id default-value)
    (flet ((color-get-xyzzy-colors-1 (name)
             (when (string-match "^\\[\\(.+\\)\\]\\(.+\\)$" name)
               (let* ((sec (si:make-string-chunk (match-string 1)))
                      (key (si:make-string-chunk (match-string 2)))
                      (non (si:make-string-chunk ""))
                      (sz 500)
                      (color (si:make-chunk nil sz)))
                 (winapi:GetPrivateProfileString sec key non color sz ini)
                 (si:unpack-string color 0)))))
      (dolist (name (mapcar #'car *color-xyzzy-colors-alist*))
        (setq bgr-str (color-get-xyzzy-colors-1 name))
        (if (and bgr-str (string/= bgr-str ""))
            (progn
              (setq bgr (parse-integer bgr-str :start 1 :radix 16))
              (setq system-color-id (floor bgr #x1000000))
              (push (cons name
                          (if (plusp system-color-id)
                              (winapi::GetSysColor (1- system-color-id))
                            (color-bgr2rgb bgr)))
                    colors-name-alist))
          (progn
            (setq default-value (nth 2 (find name *color-xyzzy-colors-alist*
                                             :key #'car :test #'string=)))
            (push (cons name
                        (cond ((numberp default-value)
                               default-value)
                              ((symbolp default-value)
                               (winapi::GetSysColor
                                (symbol-value default-value)))
                              (t 0)))
                  colors-name-alist))))
      (setq *color-xyzzy-colors-name-alist* (nreverse colors-name-alist)))))

(color-get-xyzzy-colors)

(defvar *color-all-colors-name-alist* nil
  "各種方式での COLOR-NAME と RGB値 の対応リスト
cons 部が nil の要素は、仕切り文字列表示用")
(defun color-get-all-colors-name-alist ()
  "各種方式での COLOR-NAME と RGB値 の対応リストを生成。
*color-all-colors-name-alist* に値をセットする。
COLOR-NAME と RGB値 の対応以外に、種類の仕切り文字列も含む。"
  (let (all-alist alist name color code)
    ;; XYZZY
    (setq alist *color-xyzzy-colors-name-alist*)
    (push (cons "===== XYZZY =====" nil) all-alist)
    (dolist (x alist)
      (push (cons (concat "[XYZ] "
                          (nth 1 (assoc (car x) *color-xyzzy-colors-alist*
                                        :test 'string=)))
                  (cdr x)) all-alist))
    ;; SYSTEM
    (setq alist *color-system-colors-xyzzy-name-alist*)
    (push (cons "===== SYSTEM =====" nil) all-alist)
    (dolist (x alist)
      (push (cons (concat "[SYS] " (car x)) (cdr x)) all-alist))
    ;; X11R6
    (setq alist *color-X11R6-unique-name-alist*)
    (push (cons "===== X11R6 =====" nil) all-alist)
    (dolist (x alist)
      (push (cons (concat "[X11] " (car x)) (cdr x)) all-alist))
    ;; HTML3.2/4.0
    (setq alist *color-HTML3.2/4.0-name-alist*)
    (push (cons "===== HTML3.2/4.0 =====" nil) all-alist)
    (dolist (x alist)
      (push (cons (concat "[HTM] " (car x)) (cdr x)) all-alist))
    ;; Mozilla/MSIE
    (setq alist *color-Mozilla/MSIE-name-alist*)
    (push (cons "===== Mozilla/MSIE =====" nil) all-alist)
    (dolist (x alist)
      (push (cons (concat "[M/M] " (car x)) (cdr x)) all-alist))
    (setq *color-all-colors-name-alist* (nreverse all-alist))))

(color-get-all-colors-name-alist)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun color-code-dialog-box ()
  "選択された X11R6 の COLOR-NAME に対応する RGB値 を入力するダイアログボックス"
  (interactive "*")
  (let (code)
    (multiple-value-bind (result data)
        (dialog-box '(dialog 0 0 186 162
                      (:caption "カラーコードの入力")
                      (:font 9 "MS UI Gothic")
                      (:control
                       (:listbox list nil #x50b10111 7 7 116 148)
                       (:button IDOK "OK" #x50010001 129 7 50 14)
                       (:button IDCANCEL "キャンセル" #x50010000 129 24 50 14)))
                    `((list . ,*color-X11R6-name-alist*))
                    '((list :column (10 30) :must-match t :enable (IDOK))))
      (when result
        (setq code (cddr (assoc 'list data)))
        (if (numberp code)
            (insert (color-code2str code)))))))

(defun color-code-all-dialog-box ()
  "選択された各種 COLOR-NAME に対応する RGB値 を入力するダイアログボックス"
  (interactive "*")
  (let (code)
    (multiple-value-bind (result data)
        (dialog-box '(dialog 0 0 186 162
                      (:caption "カラーコードの入力")
                      (:font 9 "MS UI Gothic")
                      (:control
                       (:listbox list nil #x50b10111 7 7 116 148)
                       (:button IDOK "OK" #x50010001 129 7 50 14)
                       (:button IDCANCEL "キャンセル" #x50010000 129 24 50 14)))
                    `((list . ,*color-all-colors-name-alist*))
                    '((list :column (10 30) :must-match t :enable (IDOK))))
      (when result
        (setq code (cddr (assoc 'list data)))
        (if (numberp code)
            (insert (color-code2str code)))))))

;;; color.l ends here
