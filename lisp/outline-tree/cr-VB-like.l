;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-VB-like.l --- outline-tree

;; Copyright (C) 2006-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:21 +0900>

;;; Code:

(provide "outline-tree/cr-VB-like")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-VB-like-separate-comment* nil)

;; VB-like 解析
(defun outline-tree-create-outline-VB-like (root-node)
  (flet ((outline-tree-create-outline-VB-like-begin-end (root-node section-name begin-regexp end-regexp)
           (when (stringp begin-regexp)
             (setq begin-regexp (compile-regexp begin-regexp)))
           (when (stringp end-regexp)
             (setq end-regexp (compile-regexp end-regexp)))
           (let (section-node range-node range-name next-point from to
                 main-from main-to comment-from comment-to)
             (goto-char (point-min))
             (setq section-node (outline-tree-insert-section-node section-name root-node))
             (while (scan-buffer begin-regexp)
               (setq next-point (match-end 0))
               (setq main-from (point))
               (setq range-name (match-string 1))
               (goto-char (match-end 0))
               (when (scan-buffer end-regexp)
                 (goto-eol)
                 (forward-char)
                 (setq main-to (point))
                 (setq comment-from main-from
                       comment-to main-from)
                 (goto-char main-from)
                 (goto-bol)
                 (while (previous-line)
                   (if (looking-at "^[ \t]*\\('.*\\)?$")
                       (when (match-string 1)
                         (setq comment-from (point)))
                     (return)))
                 (if (< comment-from comment-to)
                     (setq from comment-from)
                   (setq from main-from))
                 (setq to main-to)
                 (setq range-node (outline-tree-insert-range-node
                                   range-name section-node :whole-range (cons from to)))
                 (when (and *outline-tree-create-outline-VB-like-separate-comment*
                            (< comment-from comment-to))
                   (outline-tree-insert-range-node
                    "コメント" range-node :whole-range (cons comment-from comment-to))
                   (outline-tree-insert-range-node
                    "定義" range-node :whole-range (cons main-from main-to))))
               (goto-char next-point))
             (unless range-node
               (outline-tree-remove-section-node section-node))))
         (outline-tree-create-outline-VB-like-single (root-node section-name regexp)
           (when (stringp regexp)
             (setq regexp (compile-regexp regexp)))
           (let (section-node range-node range-name next-point from to
                 main-from main-to comment-from comment-to)
             (goto-char (point-min))
             (setq section-node (outline-tree-insert-section-node section-name root-node))
             (while (scan-buffer regexp)
               (setq next-point (match-end 0))
               (setq main-from (point))
               (setq range-name (match-string 1))
               (goto-eol)
               (forward-char)
               (setq main-to (point))
               (setq comment-from main-from
                     comment-to main-from)
               (goto-char main-from)
               (goto-bol)
               (while (previous-line)
                 (if (looking-at "^[ \t]*\\('.*\\)?$")
                     (when (match-string 1)
                       (setq comment-from (point)))
                   (return)))
               (if (< comment-from comment-to)
                   (setq from comment-from)
                 (setq from main-from))
               (setq to main-to)
               (setq range-node (outline-tree-insert-range-node
                                 range-name section-node :whole-range (cons from to)))
               (when (and *outline-tree-create-outline-VB-like-separate-comment*
                          (< comment-from comment-to))
                 (outline-tree-insert-range-node
                  "コメント" range-node :whole-range (cons comment-from comment-to))
                 (outline-tree-insert-range-node
                  "定義" range-node :whole-range (cons main-from main-to)))
               (goto-char next-point))
             (unless range-node
               (outline-tree-remove-section-node section-node))))
         )
    ;; Class
;    (outline-tree-create-outline-VB-like-single
;     root-node "[Class]"
;     "^[ \t]*\\(\\(?:\\(?:Private\\|Public\\)[ \t]+\\)?Class[ \t]+.+?\\)[ \t]*$")
    ;; Enum
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Enum (Private)]"
     "^[ \t]*Private[ \t]+Enum[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Enum[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Enum (Public)]"
     "^[ \t]*Public[ \t]+Enum[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Enum[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Enum]"
     "^[ \t]*Enum[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Enum[ \t]*$")
    ;; Type
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Type (Private)]"
     "^[ \t]*Private[ \t]+Type[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Type[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Type (Public)]"
     "^[ \t]*Public[ \t]+Type[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Type[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Type]"
     "^[ \t]*Type[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Type[ \t]*$")
    ;; Property
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Property (Private)]"
     "^[ \t]*Private[ \t]+Property[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Property[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Property (Public)]"
     "^[ \t]*Public[ \t]+Property[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Property[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Property]"
     "^[ \t]*Property[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Property[ \t]*$")
    ;; Sub
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Sub (Private)]"
     "^[ \t]*Private[ \t]+Sub[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Sub[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Sub (Public)]"
     "^[ \t]*Public[ \t]+Sub[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Sub[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Sub]"
     "^[ \t]*Sub[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Sub[ \t]*$")
    ;; Function
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Function (Private)]"
     "^[ \t]*Private[ \t]+Function[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Function[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Function (Public)]"
     "^[ \t]*Public[ \t]+Function[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Function[ \t]*$")
    (outline-tree-create-outline-VB-like-begin-end
     root-node "[Function]"
     "^[ \t]*Function[ \t]+\\(.+?\\)[ \t]*$" "^[ \t]*End Function[ \t]*$")))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-VB-like "VB like" '(:type-program)
 "VB ライクな言語の各種定義を列挙します。")

;;; cr-VB-like.l ends here
