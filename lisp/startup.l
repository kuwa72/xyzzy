;;; -*- Encoding: utf-8 -*-
;;; -*-Lisp-*-
;;;
;;; This file is part of xyzzy.
;;;

;; Use .l explicitly for ncurses to bypass .lc files
;; (.lc was compiled without :ncurses in *features*)
#+ncurses (si:*load-library "loadup.l")
#-ncurses (si:*load-library "loadup")

;; Define variables from #-ncurses excluded files that are still needed
;; Must use ed:: prefix since these are in the editor package
#+ncurses
(progn
  (defvar ed::*buffer-package* nil)
  (make-variable-buffer-local 'ed::*buffer-package*))

(provide "startup")

#-ncurses
(defun si:*startup ()
  (ed::startup))

#+ncurses
(progn
  ;; Use popup-list for completion display
  (setq ed::*popup-completion-list-default* t)
  (setq ed::*minibuffer-popup-completion-list* t))

#+ncurses
(defun si:*startup ()
  (trap-errors (ed::init-misc-objects))
  (ignore-errors (ed::init-app-menus))
  ;; BS/DEL key binding (terminal sends 0x7f for backspace)
  (global-set-key #\DEL 'ed::delete-backward-char-or-selection)
  ;; F10: activate menu bar (call-menu requires an arg on Win32,
  ;; so wrap it as an interactive command for ncurses keybinding)
  (defun ed::activate-menu ()
    (interactive)
    (call-menu 0))
  (global-set-key #\F10 'ed::activate-menu)
  ;; Set *scratch* encoding to match *default-fileio-encoding* (same as Win32 startup)
  (trap-errors
    (let ((scratch (find-buffer "*scratch*")))
      (when scratch
        (save-excursion
          (set-buffer scratch)
          (set-buffer-fileio-encoding *default-fileio-encoding*)
          (funcall ed::*initial-buffer-mode*)))))
  t)

#-ncurses
(unless (xyzzy-dumped-p)
  (si:*show-window-foreground)
  (ed::init-misc-objects)
  (lisp::snarf-documentation)
  (dump-xyzzy))

(si:*startup)

