;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; search-ext.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 13:01:46 +0900>

;;; Code:

(provide "wip/treeview/search-ext")

(require "wip/treeview/defs")
(require "wip/treeview/search")

(in-package "treeview")

(defun treeview-find-nodes (pattern &key (regexp nil) (case-fold t) (part t))
  (let ((hitem winapi:TVI_ROOT) nodes (i 0)
        (*treeview-scan-treeview-hook* nil))
    (declare (special *treeview-scan-treeview-hook*))
    (while (treeview-hitem-valid-p
            (setq hitem (treeview-scan-treeview
                         pattern :hitem hitem :regexp regexp :no-dup t
                         :case-fold case-fold :part part)))
      (push hitem nodes))
    (nreverse nodes)))

;;; search-ext.l ends here
