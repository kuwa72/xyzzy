;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; utils.l --- outline-tree

;; Copyright (C) 2001-2004 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2004/09/24 11:25:23 +0900>

;;; Code:

(provide "outline-tree/utils")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; エスケープ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *outline-tree-escape-char-alist*
  '(("\n" . "\\\\n")
    ("\r" . "\\\\r")
    ("\t" . "\\\\t")
    ("\f" . "\\\\f")))
(defun outline-tree-encode-escape-sequence (string)
  (cond
   ((stringp string)
    (dolist (ec *outline-tree-escape-char-alist*)
      (setq string (substitute-string string (car ec) (cdr ec))))
    string)
   (t nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; バッファローカルにする/しないの同期
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *outline-tree-sync-local-variables-list* nil)
(defun outline-tree-sync-local-variables (sym &optional (local t))
  (dolist (variables *outline-tree-sync-local-variables-list*)
    (when (find sym variables)
      (if local
          (dolist (variable variables)
            (set variable (symbol-value variable)))
        (dolist (variable variables)
          (set-default variable (symbol-value variable))
          (kill-local-variable variable))))))
(defun outline-tree-local-variables-local-p (sym)
  "グループ内のいずれかが local なら t"
  (let (result)
    (dolist (variables *outline-tree-sync-local-variables-list*)
      (when (find sym variables)
        (dolist (variable variables)
          (when (local-variable-p variable)
            (setq result t)
            (return)))
        (return)))
    result))

;;; utils.l ends here
