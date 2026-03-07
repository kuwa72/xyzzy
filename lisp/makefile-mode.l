;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; makefile-mode: Makefile editing support
;;;

(provide "makefile-mode")

(in-package "editor")

(require "re-kwd")

(export '(*makefile-mode-hook* *makefile-mode-map* makefile-mode))

(defvar *makefile-mode-hook* nil)
(defvar *makefile-mode-map* nil)

(unless *makefile-mode-map*
  (setq *makefile-mode-map* (make-sparse-keymap)))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *makefile-mode-syntax-table* nil)
(unless *makefile-mode-syntax-table*
  (setq *makefile-mode-syntax-table* (make-syntax-table))
  (set-syntax-string *makefile-mode-syntax-table* #\")
  (set-syntax-string *makefile-mode-syntax-table* #\')
  (set-syntax-escape *makefile-mode-syntax-table* #\\)
  (set-syntax-start-comment *makefile-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *makefile-mode-syntax-table* #\LFD nil t)
  (set-syntax-symbol *makefile-mode-syntax-table* #\_)
  (set-syntax-symbol *makefile-mode-syntax-table* #\-)
  (set-syntax-symbol *makefile-mode-syntax-table* #\.)
  (set-syntax-match *makefile-mode-syntax-table* #\( #\))
  (set-syntax-match *makefile-mode-syntax-table* #\{ #\}))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *makefile-regexp-keyword-list* nil)

(defun makefile-setup-keywords ()
  (unless *makefile-regexp-keyword-list*
    (setq *makefile-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Targets
             ("^[A-Za-z0-9_./-]+[ \t]*:" nil 0)
             ;; Variable assignment
             ("^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\\([:?+!]\\)?=" nil :tag)
             ;; Variable references
             ("\\$(\\([^)\n]*\\))\\|\\${\\([^}\n]*\\)}" nil 2)
             ;; Directives
             ("^[ \t]*\\(-\\|@\\)" nil :comment)
             ;; Include, ifdef, etc.
             ("^[ \t]*\\(include\\|sinclude\\|-include\\|ifdef\\|ifndef\\|ifeq\\|ifneq\\|else\\|endif\\|define\\|endef\\|export\\|unexport\\|override\\|vpath\\)\\b" nil 0)
             ;; Automatic variables
             ("\\$[@<^?*%+]\\|\\$([<@^?*%+][DF])" nil 2)
             ;; .PHONY etc
             ("^\\.[A-Z_]+:" nil (:keyword 0 :bold))
             ))))
  *makefile-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun makefile-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Makefile")
  (setq buffer-mode 'makefile-mode)
  (use-keymap *makefile-mode-map*)
  (use-syntax-table *makefile-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (makefile-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  ;; Makefiles require hard tabs
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode t)
  (run-hooks '*makefile-mode-hook*))
