;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Terminal keymap and commands for terminal buffers
;;;

(provide "terminal")

(in-package "editor")

(export '(*terminal-map* terminal-self-insert terminal-send-ctrl-c
	  terminal-scroll-back terminal-scroll-forward))

(defvar *terminal-map* nil)
(unless *terminal-map*
  (setq *terminal-map* (make-sparse-keymap))
  ;; C-c prefix: escape from terminal to editor commands
  (define-key *terminal-map* '(#\C-c #\C-c) 'terminal-send-ctrl-c)
  (define-key *terminal-map* '(#\C-c #\o) 'other-window)
  (define-key *terminal-map* '(#\C-c #\b) 'switch-to-buffer)
  (define-key *terminal-map* '(#\C-c #\0) 'delete-window)
  (define-key *terminal-map* '(#\C-c #\1) 'delete-other-windows)
  (define-key *terminal-map* '(#\C-c #\2) 'split-window)
  (define-key *terminal-map* '(#\C-c #\k) 'kill-buffer)
  (define-key *terminal-map* '(#\C-c #\C-f) 'find-file)
  ;; Scrollback
  (define-key *terminal-map* #\S-PageUp 'terminal-scroll-back)
  (define-key *terminal-map* #\S-PageDown 'terminal-scroll-forward))

(defun terminal-self-insert ()
  (interactive)
  (let ((proc (buffer-process (selected-buffer))))
    (when (and proc (si:process-terminal-p proc))
      (si:terminal-send-key proc *last-command-char*))))

(defun terminal-send-ctrl-c ()
  (interactive)
  (let ((proc (buffer-process (selected-buffer))))
    (when (and proc (si:process-terminal-p proc))
      (si:terminal-send-key proc 3))))

(defun terminal-scroll-back ()
  (interactive)
  (let ((proc (buffer-process (selected-buffer))))
    (when (and proc (si:process-terminal-p proc))
      (si:terminal-scroll-back proc (window-height)))))

(defun terminal-scroll-forward ()
  (interactive)
  (let ((proc (buffer-process (selected-buffer))))
    (when (and proc (si:process-terminal-p proc))
      (si:terminal-scroll-back proc (- (window-height))))))
