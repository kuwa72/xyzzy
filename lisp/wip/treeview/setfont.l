;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; setfont.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 12:51:56 +0900>

;;; Code:

(provide "wip/treeview/setfont")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "foreign")
  (require "wip/winapi")
  (require "wip/treeview/defs")
  (require "wip/treeview/winapi"))

(in-package "win-user")

(let (facename-list)
  (unless (fboundp 'treeview-enum-font-fam-ex-proc)
    (defun-c-callable int treeview-enum-font-fam-ex-proc
      (((ENUMLOGFONTEX *) lpelfe) ((NEWTEXTMETRICEX *) lpntme)
       (int FontType) (LPARAM lParam))
      (let ((enum-log-font-ex (make-ENUMLOGFONTEX)) logfont)
        (RtlMoveMemory (si:chunk-data enum-log-font-ex) lpelfe
                       (si:chunk-size enum-log-font-ex))
        (setq logfont (make-LOGFONT
                       (ENUMLOGFONTEX-elfLogFont enum-log-font-ex) 0))
        (push (si:unpack-string logfont 28) facename-list))
      (return-from treeview-enum-font-fam-ex-proc 1))
    (defun treeview-font-facename-list-set (arg)
      (setq facename-list arg))
    (defun treeview-font-facename-list-get (&key (horizontal-p t) (vertical-p nil))
      (unless facename-list
        (let ((hdc (winapi:GetDC (ed:get-window-handle)))
              (lf (winapi:make-LOGFONT)))
          (si:clear-chunk lf)
          (setf (winapi:LOGFONT-lfCharSet lf) winapi:SHIFTJIS_CHARSET);DEFAULT_CHARSET;
          (winapi:EnumFontFamiliesEx hdc lf #'treeview-enum-font-fam-ex-proc 0 0)
          (winapi:ReleaseDC (ed:get-window-handle) hdc)))
      (let (h-list v-list)
        (dolist (facename facename-list)
          (if (string= "@" facename :start2 0 :end2 1)
              (push facename v-list)
            (push facename h-list)))
        (append (if horizontal-p h-list) (if vertical-p v-list))))
    ))

(in-package "treeview")

(export '(treeview-font-all-del
          treeview-font-del
          treeview-font-set
          treeview-font-facename-list-get))

(if (fboundp 'treeview-font-all-del)
    (treeview-font-all-del))

(defun treeview-font-all-del ()
  (dolist (app-id *treeview-app-id-list*)
    (with-app (app-id)
      (treeview-font-del))))

(defun treeview-font-del ()
  (when (and (treeview-data-get 'treeview::hfont)
             (/= (winapi:DeleteObject (treeview-data-get 'treeview::hfont)) 0))
    (treeview-data-set 'treeview::hfont nil))
  (when (treeview-exist-p)
    (winapi:SetWindowFont (treeview-get-htree)
                          (winapi::GetStockObject winapi::DEFAULT_GUI_FONT)
                          winapi::TRUE)))

(defun treeview-font-set (&key font-facename font-height font-bold font-italic font-underline)
  (unless (treeview-exist-p)
    (return-from treeview-font-set))
  (let ((lf (winapi:make-LOGFONT)))
    (treeview-font-del)
    (si:clear-chunk lf)
    (setf (winapi:LOGFONT-lfCharSet lf) winapi:SHIFTJIS_CHARSET)
    (if (stringp font-facename)
        (si:pack-string lf (c:c-struct-offset-of winapi:LOGFONT winapi::lfFaceName)
                        font-facename))
    (if (and font-height
             (integerp font-height)
             (plusp font-height))
        (setf (winapi:LOGFONT-lfHeight lf) font-height))
    (setf (winapi:LOGFONT-lfWeight lf) (if font-bold winapi::FW_BOLD winapi::FW_DONTCARE))
    (setf (winapi:LOGFONT-lfUnderline lf) (if font-underline winapi::TRUE winapi::FALSE))
    (setf (winapi:LOGFONT-lfItalic lf) (if font-italic winapi::TRUE winapi::FALSE))
    (treeview-data-set 'treeview::hfont (winapi:CreateFontIndirect lf))
    (winapi:SetWindowFont (treeview-get-htree)
                          (treeview-data-get 'treeview::hfont) winapi::TRUE))
  (ed:add-hook '*treeview-delete-hook* 'treeview-font-del)
  (ed:add-hook 'ed::*kill-xyzzy-hook* 'treeview-font-all-del)
  t)

(defun treeview-font-facename-list-get (&key (horizontal-p t) (vertical-p nil))
  (stable-sort (win-user::treeview-font-facename-list-get
                :horizontal-p horizontal-p
                :vertical-p vertical-p)
               #'string<))

;;; setfont.l ends here
