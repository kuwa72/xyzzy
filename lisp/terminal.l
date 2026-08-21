;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Terminal keymap and commands for terminal buffers
;;;

(provide "terminal")

(in-package "editor")

(export '(*terminal-map* terminal-self-insert terminal-send-ctrl-c
	  terminal-scroll-back terminal-scroll-forward terminal-paste))

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
  (define-key *terminal-map* #\S-PageDown 'terminal-scroll-forward)
  ;; 貼り付けはバッファではなく pty へ送る。通常の paste-from-clipboard は
  ;; バッファに insert するだけで、ターミナルでは何も起きなかった。
  (define-key *terminal-map* #\C-v 'terminal-paste)
  (define-key *terminal-map* #\S-Insert 'terminal-paste))

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

(defun terminal-paste ()
  "クリップボードの文字列をターミナルへ流す。

アプリが bracketed paste を有効にしていれば ESC[200~ ... ESC[201~ で囲まれる
ので、複数行でも一塊として扱われる。無効なら改行がそのまま Enter になる
(行が順に実行される) ので、そこはアプリ側の対応次第。"
  (interactive)
  (let ((proc (buffer-process (selected-buffer)))
        (s (get-clipboard-data)))
    (cond ((not (and proc (si:process-terminal-p proc)))
           (ding))
          ((not (stringp s))
           (message "クリップボードに文字列がありません"))
          (t
           (si:terminal-paste-string proc s)))))
