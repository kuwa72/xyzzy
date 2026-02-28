;;; -*- Mode: Lisp; Package: USER -*-
;;; makefile.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/12/12 00:15:22 +0900>

;;; Code:

(provide "wip/treeview/makefile")

(in-package "user")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "wip/treeview/defs")
  (require "wip/treeview/macro"))

(defvar *treeview-file-list* '("defs.l"
                               "macro.l"
                               "setup.l"
                               "winapi.l"
                               "virtual-keys.l"
                               "dll.l"
                               "get-item.l"
                               "base.l"
                               "search.l"
                               "isearch.l"
                               "search-ext.l"
                               "frame-work.l"
                               "setfont.l"
                               "sort.l"
                               "dialog.l"
                               "utils.l"
                               "unicode.l"))

(defvar *treeview-root-directory*
  (merge-pathnames "lisp/wip/treeview" (si:system-root)))

(defun treeview-make ()
  (interactive)
  (let ((files *treeview-file-list*)
        (path *treeview-root-directory*))
    (dolist (f files)
      (let ((file (merge-pathnames f path))
            filec)
        (setq filec (concat file "c"))
        (if (file-newer-than-file-p file filec)
            (byte-compile-file file)
          (message "skipping file: ~A" file))))))

(defun treeview-make-tags-file ()
  (interactive)
  (let ((path *treeview-root-directory*)
        (default-directory (default-directory)))
    (set-default-directory path)
    (make-tags-file path)
    (set-default-directory default-directory)))

(defun treeview-make-all ()
  (interactive)
  (treeview-make)
  (treeview-make-tags-file))

(defun treeview-make-clean ()
  (interactive)
  (let ((path *treeview-root-directory*)
        (default-directory (default-directory)))
    (set-default-directory path)
    (dolist (f (directory path))
      (when (or (string-match "~$" f)
                (string-match "\\.lc" f)
                (string-matchp "^XTAGS$" f))
        (delete-file f)
        (message "File deleted: ~A" f)))
    (set-default-directory default-directory)))

;;; makefile.l ends here
