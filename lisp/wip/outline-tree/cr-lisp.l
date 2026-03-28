;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-lisp.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:20:56 +0900>

;;; Code:

(provide "outline-tree/cr-lisp")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-lisp-ignore-interactive* nil)

;; lisp 解析
(defun outline-tree-create-outline-lisp (root-node)
  (let (package)
    (unwind-protect
        (progn
          (do ((i 0 (+ i 1)))
              ((let ((name (format nil "OUTLINE-TREE2-CR-LISP-~D" i)))
                 (unless (find-package name)
                   (setq package (make-package name :external-size 0))))))
          (labels ((trim-text (str)
                     (substitute-string str "OUTLINE-TREE2-CR-LISP-[0-9]+::" ""))
                   (outline-tree-find-interactive (body)
                     (or (lisp::find-interactive body)
                         (if (endp body)
                             (values nil body)
                           (if (and (consp (car body))
                                    (string= (trim-text (format nil "~S" (car (car body)))) "interactive"))
                               (values (list (car body)) (cdr body))
                             (if (and (stringp (car body))
                                      (not (endp (cdr body)))
                                      (consp (car (cdr body)))
                                      (string= (trim-text (format nil "~S" (car (car (cdr body))))) "interactive"))
                                 (values (list (car (cdr body))) (cons (car body) (cdr (cdr body))))
                               (values nil body))))))
                   (outline-tree-create-outline-lisp-defvar-type (root-node section-name regexp)
                     (let (section-node range-node from to lst name val doc pos)
                       (goto-char (point-min))
                       (setq section-node (outline-tree-insert-section-node section-name root-node))
                       (while (scan-buffer regexp :regexp t)
                         (setq pos (match-end 0))
                         (setq from (point))
                         (skip-chars-forward " \t")
                         (when (and (eq (parse-point-syntax) nil)
                                    (not (find (char-before (point)) '(#\' #\`)))
                                    (goto-matched-parenthesis))
                           (setq to (1+ (point)))
                           (with-input-from-buffer ((selected-buffer) from)
                             (let ((*package* package))
                               (handler-case
                                   (setq lst (read *standard-input* nil))
                                 (error (c)
                                   (setq lst nil)))))
                           (when lst
                             (when (<= 2 (length lst))
                               (setq name (nth 1 lst)))
                             (setq range-node (outline-tree-insert-range-node
                                               (trim-text (format nil "~S" name)) section-node :whole-range (cons from to)))
                             (when (setq doc (and (stringp (cadddr lst)) (cadddr lst)))
                               (outline-tree-insert-info-node (concat "【" doc "】") range-node))
                             (when (<= 3 (length lst))
                               (setq val (nth 2 lst))
                               (outline-tree-insert-info-node (trim-text (format nil "~S" val)) range-node))))
                         (goto-char pos))
                       (unless range-node
                         (outline-tree-remove-section-node section-node))))
                   (outline-tree-create-outline-lisp-defun-type (root-node section-name regexp commandp)
                     (let (section-node range-node from to lst name doc args pos)
                       (goto-char (point-min))
                       (setq section-node (outline-tree-insert-section-node section-name root-node))
                       (while (scan-buffer regexp :regexp t)
                         (setq pos (match-end 0))
                         (setq from (point))
                         (skip-chars-forward " \t")
                         (when (and (eq (parse-point-syntax) nil)
                                    (not (find (char-before (point)) '(#\' #\`)))
                                    (goto-matched-parenthesis))
                           (setq to (1+ (point)))
                           (with-input-from-buffer ((selected-buffer) from)
                             (let ((*package* package))
                               (handler-case
                                   (setq lst (read *standard-input* nil))
                                 (error (c)
                                   (setq lst nil)))))
                           (when lst
                             (when (<= 2 (length lst))
                               (setq name (nth 1 lst)))
                             (when (or (eq commandp :ignore)
                                       (if commandp
                                           (outline-tree-find-interactive (cdddr lst))
                                         (not (outline-tree-find-interactive (cdddr lst)))))
                               (setq range-node (outline-tree-insert-range-node
                                                 (trim-text (format nil "~S" name)) section-node :whole-range (cons from to)))
                               (when (setq doc (lisp::find-documentation (cdddr lst)))
                                 (outline-tree-insert-info-node (concat "【" doc "】") range-node))
                               (when (<= 3 (length lst))
                                 (setq args (nth 2 lst))
                                 (dolist (arg args)
                                   (outline-tree-insert-info-node (trim-text (format nil "~S" arg)) range-node))))))
                         (goto-char pos))
                       (unless range-node
                         (outline-tree-remove-section-node section-node))))
                   (outline-tree-create-outline-lisp-define-dll-entry-type (root-node section-name regexp)
                     (let (section-node range-node from to lst name doc args pos)
                       (goto-char (point-min))
                       (setq section-node (outline-tree-insert-section-node section-name root-node))
                       (while (scan-buffer regexp :regexp t)
                         (setq pos (match-end 0))
                         (setq from (point))
                         (skip-chars-forward " \t")
                         (when (and (eq (parse-point-syntax) nil)
                                    (not (find (char-before (point)) '(#\' #\`)))
                                    (goto-matched-parenthesis))
                           (setq to (1+ (point)))
                           (with-input-from-buffer ((selected-buffer) from)
                             (let ((*package* package))
                               (handler-case
                                   (setq lst (read *standard-input* nil))
                                 (error (c)
                                   (setq lst nil)))))
                           (when lst
                             (when (<= 3 (length lst))
                               (setq name (nth 2 lst)))
                             (setq range-node (outline-tree-insert-range-node
                                               (trim-text (format nil "~S" name)) section-node :whole-range (cons from to)))
                             (when (<= 4 (length lst))
                               (setq args (nth 3 lst))
                               (dolist (arg args)
                                 (outline-tree-insert-info-node (trim-text (format nil "~S" arg)) range-node)))))
                         (goto-char pos))
                       (unless range-node
                         (outline-tree-remove-section-node section-node)))))
            (outline-tree-create-outline-lisp-defvar-type
             root-node "[defconstant]" (compile-regexp "[ \t]*(defconstant\\_S"))
            (outline-tree-create-outline-lisp-defvar-type
             root-node "[defvar-local]" (compile-regexp "[ \t]*(defvar-local\\_S"))
            (outline-tree-create-outline-lisp-defvar-type
             root-node "[defvar]" (compile-regexp "[ \t]*(defvar\\_S"))
            (outline-tree-create-outline-lisp-defvar-type
             root-node "[defparameter]" (compile-regexp "[ \t]*(defparameter\\_S"))
            (outline-tree-create-outline-lisp-defvar-type
             root-node "[define-history-variable]"
             (compile-regexp "[ \t]*(define-history-variable\\_S"))
            (if *outline-tree-create-outline-lisp-ignore-interactive*
                (progn
                  (outline-tree-create-outline-lisp-defun-type
                   root-node "[defun]" (compile-regexp "[ \t]*(defun\\_S") :ignore)
                  (outline-tree-create-outline-lisp-defun-type
                   root-node "[defmacro]" (compile-regexp "[ \t]*(defmacro\\_S") :ignore))
              (progn
                (outline-tree-create-outline-lisp-defun-type
                 root-node "[defun (not command)]" (compile-regexp "[ \t]*(defun\\_S") nil)
                (outline-tree-create-outline-lisp-defun-type
                 root-node "[defun (command)]" (compile-regexp "[ \t]*(defun\\_S") t)
                (outline-tree-create-outline-lisp-defun-type
                 root-node "[defmacro (not command)]" (compile-regexp "[ \t]*(defmacro\\_S") nil)
                (outline-tree-create-outline-lisp-defun-type
                 root-node "[defmacro (command)]" (compile-regexp "[ \t]*(defmacro\\_S") t)))
            (outline-tree-create-outline-lisp-define-dll-entry-type
             root-node "[define-dll-entry]" (compile-regexp "[ \t]*(\\(?:\\_s+:\\)?\\*?define-dll-entry\\_S"))))
      (when package
        (delete-package package)))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-lisp "LISP" '(:type-program)
 "LISP ファイルの関数・変数定義を列挙します。")

;;; cr-lisp.l ends here
