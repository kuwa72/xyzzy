;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; dockerfile-mode: Dockerfile editing support
;;;

(provide "dockerfile-mode")

(in-package "editor")

(require "re-kwd")

(export '(*dockerfile-mode-hook* *dockerfile-mode-map* dockerfile-mode))

(defvar *dockerfile-mode-hook* nil)
(defvar *dockerfile-mode-map* nil)

(unless *dockerfile-mode-map*
  (setq *dockerfile-mode-map* (make-sparse-keymap)))

;;; ============================================================
;;; Syntax table
;;; ============================================================

(defvar *dockerfile-mode-syntax-table* nil)
(unless *dockerfile-mode-syntax-table*
  (setq *dockerfile-mode-syntax-table* (make-syntax-table))
  (set-syntax-string *dockerfile-mode-syntax-table* #\")
  (set-syntax-string *dockerfile-mode-syntax-table* #\')
  (set-syntax-escape *dockerfile-mode-syntax-table* #\\)
  (set-syntax-start-comment *dockerfile-mode-syntax-table* #\# nil)
  (set-syntax-end-comment *dockerfile-mode-syntax-table* #\LFD nil t)
  (set-syntax-symbol *dockerfile-mode-syntax-table* #\_)
  (set-syntax-symbol *dockerfile-mode-syntax-table* #\-)
  (set-syntax-match *dockerfile-mode-syntax-table* #\[ #\])
  (set-syntax-match *dockerfile-mode-syntax-table* #\{ #\}))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *dockerfile-regexp-keyword-list* nil)

(defun dockerfile-setup-keywords ()
  (unless *dockerfile-regexp-keyword-list*
    (setq *dockerfile-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(;; Instructions
             ("^[ \t]*\\(FROM\\|RUN\\|CMD\\|LABEL\\|MAINTAINER\\|EXPOSE\\|ENV\\|ADD\\|COPY\\|ENTRYPOINT\\|VOLUME\\|USER\\|WORKDIR\\|ARG\\|ONBUILD\\|STOPSIGNAL\\|HEALTHCHECK\\|SHELL\\)\\b" nil 0)
             ;; FROM with AS
             ("\\bAS\\b" nil 0)
             ;; Variable references
             ("\\$\\{[^}\n]*\\}\\|\\$[A-Za-z_][A-Za-z0-9_]*" nil 2)
             ;; --flag=value
             ("--[A-Za-z_][A-Za-z0-9_-]*" nil :tag)
             ))))
  *dockerfile-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun dockerfile-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Dockerfile")
  (setq buffer-mode 'dockerfile-mode)
  (use-keymap *dockerfile-mode-map*)
  (use-syntax-table *dockerfile-mode-syntax-table*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (dockerfile-setup-keywords))
  (make-local-variable 'comment-start)
  (setq comment-start "# ")
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (run-hooks '*dockerfile-mode-hook*))
