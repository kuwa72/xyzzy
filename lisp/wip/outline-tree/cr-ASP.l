;;; -*- Mode: asp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-ASP.l --- outline-tree

;; Copyright (C) 2006-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:25:00 +0900>

;;; Code:

(provide "outline-tree/cr-ASP")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-range-internal")

(in-package "outline-tree2")

;; asp 解析
(defun outline-tree-create-outline-ASP-VBScript (root-node)
  (let (script-section-node sub-section-node function-section-node)
    (setq script-section-node (outline-tree-insert-section-node "[script]" root-node))
    (setq sub-section-node (outline-tree-insert-section-node "[Sub]" root-node))
    (setq function-section-node (outline-tree-insert-section-node "[Function]" root-node))
    (outline-tree-create-outline-range-internal
     :root-node script-section-node
     :get-range-func #'outline-tree-create-outline-ASP-get-range-script
     :create-contents-outline-func
     #'(lambda (root-node range-name)
         (outline-tree-create-outline-ASP-VBScript-begin-end
          sub-section-node
          "^[ \t]*\\(?:\\(?:Private\\|Public\\)[ \t]+\\)?Sub[ \t]+\\(.+?\\)[ \t]*$"
          "^[ \t]*End Sub[ \t]*$")
         (outline-tree-create-outline-ASP-VBScript-begin-end
          function-section-node
          "^[ \t]*\\(?:\\(?:Private\\|Public\\)[ \t]+\\)?Function[ \t]+\\(.+?\\)[ \t]*$"
          "^[ \t]*End Function[ \t]*$")))
    (unless (outline-tree-node-has-children-p sub-section-node)
      (outline-tree-remove-section-node sub-section-node))
    (unless (outline-tree-node-has-children-p function-section-node)
      (outline-tree-remove-section-node function-section-node))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-ASP-VBScript "ASP (VBScript)" '(:type-program)
 "ASP (VBScript) の各種定義を列挙します。")

(defun outline-tree-create-outline-ASP-get-range-script ()
  (let (begin-range end-range name)
    (save-excursion
      (when (scan-buffer "<\\(script\\|%\\)" :regexp t :case-fold t)
        (setq begin-range (cons (match-beginning 0) (match-end 0)))
        (setq name (match-string 1))
        (when (string-equal name "script")
          (unless (scan-buffer ">" :tail t)
            (return-from outline-tree-create-outline-ASP-get-range-script nil))
          (rplacd begin-range (point)))
        (goto-char (cdr begin-range))
        (when (scan-buffer (if (string-equal name "script") "</script>" "%>") :case-fold t)
          (setq end-range (cons (match-beginning 0) (match-end 0)))
          (return-from outline-tree-create-outline-ASP-get-range-script
            (values begin-range end-range name)))))))

(defun outline-tree-create-outline-ASP-VBScript-begin-end (root-node begin-regexp end-regexp)
  (when (stringp begin-regexp)
    (setq begin-regexp (compile-regexp begin-regexp)))
  (when (stringp end-regexp)
    (setq end-regexp (compile-regexp end-regexp)))
  (let (range-node range-name next-point from to
        main-from main-to comment-from comment-to)
    (goto-char (point-min))
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
                          range-name root-node :whole-range (cons from to)))
        (when (< comment-from comment-to)
          (outline-tree-insert-range-node
           "コメント" range-node :whole-range (cons comment-from comment-to))
          (outline-tree-insert-range-node
           "定義" range-node :whole-range (cons main-from main-to))))
      (goto-char next-point))))

;;; cr-ASP.l ends here
