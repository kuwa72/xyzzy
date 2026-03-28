;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-hierarchy-internal.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:31:47 +0900>

;;; Code:

(provide "outline-tree/cr-hierarchy-internal")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")

(in-package "outline-tree2")

(defun outline-tree-create-outline-hierarchy-internal (&key root-node char skip-regexp (depth 30)
                                                            create-sub-outline-func
                                                            title-converter sub-type)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order :non-miss
   :layer-regexp-list (let* ((class-str (string char))
                             (quote-str (regexp-quote (string char)))
                             layer-regexp-list)
                        (while (plusp depth)
                          (push (format nil "^~A~A\\{~D\\}\\([^~A\n].*?\\)[ \t]*$"
                                        (if (stringp skip-regexp) skip-regexp "")
                                        quote-str depth class-str)
                                layer-regexp-list)
                          (decf depth))
                        layer-regexp-list)
   :layer-regexp-list-case-fold nil
   :sub-type sub-type
   :line-oriented t
   :title-converter title-converter
   :create-sub-outline-func create-sub-outline-func))

;;; cr-hierarchy-internal.l ends here
