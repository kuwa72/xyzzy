;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; toml-mode: TOML editing support
;;;

(provide "toml-mode")

(in-package "editor")

(require "re-kwd")

(export '(*toml-mode-hook* *toml-mode-map* toml-mode))

(defvar *toml-mode-hook* nil)
(defvar *toml-mode-map* nil)

(unless *toml-mode-map*
  (setq *toml-mode-map* (make-sparse-keymap)))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *toml-mode-syntax-table* nil)
(unless *toml-mode-syntax-table*
  (setq *toml-mode-syntax-table* (make-syntax-table))
  (set-syntax-string *toml-mode-syntax-table* #\")
  (set-syntax-string *toml-mode-syntax-table* #\')
  (set-syntax-escape *toml-mode-syntax-table* #\\)
  (set-syntax-start-comment *toml-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *toml-mode-syntax-table* #\LFD nil t)
  (set-syntax-symbol *toml-mode-syntax-table* #\_)
  (set-syntax-symbol *toml-mode-syntax-table* #\-)
  (set-syntax-match *toml-mode-syntax-table* #\[ #\])
  (set-syntax-match *toml-mode-syntax-table* #\{ #\}))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *toml-regexp-keyword-list* nil)

(defun toml-setup-keywords ()
  (unless *toml-regexp-keyword-list*
    (setq *toml-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Table headers
             ("^[ \t]*\\[\\[[^]\n]+\\]\\]" nil (:keyword 0 :bold))
             ("^[ \t]*\\[[^]\n]+\\]" nil 0)
             ;; Keys
             ("^[ \t]*[A-Za-z0-9_-][A-Za-z0-9_.-]*[ \t]*=" nil :tag)
             ;; Boolean and special values
             ("\\btrue\\b\\|\\bfalse\\b" nil 2)
             ;; Dates
             ("[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}" nil :tag)
             ))))
  *toml-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun toml-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "TOML")
  (setq buffer-mode 'toml-mode)
  (use-keymap *toml-mode-map*)
  (use-syntax-table *toml-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (toml-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (run-hooks '*toml-mode-hook*))
