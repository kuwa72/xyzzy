;;; -*- Mode: Lisp; Package: USER ; Encoding: utf-8 -*-
;;; makefile.l --- outline-tree

;; Copyright (C) 2001-2012 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2012/03/30 21:36:11 +0900>

;;; Code:

(provide "outline-tree/makefile")

(in-package "user")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "outline-tree/outline-tree"))

(defvar *outline-tree-file-list* '("defs.l"
                                   "outline-tree.l"
                                   "public-utils.l"
                                   "utils.l"
                                   "expand.l"
                                   "cr-range-internal.l"
                                   "cr-regexp-internal.l"
                                   "cr-topic-internal.l"
                                   "cr-hierarchy-internal.l"
                                   "cr-regexp-inheritance.l"
                                   "cr-hierarchy-inheritance.l"
                                   "cr-topic.l"
                                   "cr-regexp.l"
                                   "cr-tag.l"
                                   "cr-css.l"
                                   "cr-hiki.l"
                                   "cr-html-heading.l"
                                   "cr-html-info-and-heading.l"
                                   "cr-ini.l"
                                   "cr-texinfo.l"
                                   "cr-rd.l"
                                   "cr-Markdown.l"
                                   "cr-LaTeX.l"
                                   "cr-lisp.l"
                                   "cr-perl.l"
                                   "cr-VB-like.l"
                                   "cr-ASP.l"
                                   "cr-XTAGS.l"
                                   "cr-ctags.l"
                                   "cr-global.l"
                                   "cr-list-function.l"
                                   "cr-grep.l"
                                   "cr-2ch.l"
                                   "cr-indent.l"
                                   "cr-sted.l"
                                   "cr-eMemoPad.l"
                                   "cr-FreeMind.l"
                                   "cr-RFC.l"
                                   "cr-xsv.l"
                                   "cr-blank-line.l"
                                   "cr-xdoc2txt-pdf.l"
                                   "cr-xdoc2txt-excel.l"
                                   "get-outline-function.l"
                                   "gen-cr-user-topic.l"
                                   "gen-cr-user-regexp.l"
                                   "output.l"
                                   "output-html.l"
                                   "output-html-range.l"
                                   "output-html-heading.l"
                                   "output-dialog.l"
                                   "toolbar.l"
                                   "app-menu.l"
                                   ))

(defvar *outline-tree-root-directory*
  (merge-pathnames "site-lisp/outline-tree" (si:system-root)))

(defun outline-tree-make ()
  (interactive)
  (let ((files *outline-tree-file-list*)
        (path *outline-tree-root-directory*))
    (dolist (f files)
      (let ((file (merge-pathnames f path))
            filec)
        (setq filec (concat file "c"))
        (if (file-newer-than-file-p file filec)
            (byte-compile-file file)
          (message "skipping file: ~A" file))))))

(defun outline-tree-make-tags-file ()
  (interactive)
  (let ((path *outline-tree-root-directory*)
        (default-directory (default-directory)))
    (set-default-directory path)
    (make-tags-file path)
    (set-default-directory default-directory)))

(defun outline-tree-make-all ()
  (interactive)
  (outline-tree-make)
  (outline-tree-make-tags-file))

(defun outline-tree-make-clean ()
  (interactive)
  (let ((path *outline-tree-root-directory*)
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
