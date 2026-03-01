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
  ;; BS/DEL key binding (terminal sends 0x7f for backspace)
  (global-set-key #\DEL 'ed::delete-backward-char-or-selection)
  t)

#-ncurses
(unless (xyzzy-dumped-p)
  (si:*show-window-foreground)
  (ed::init-misc-objects)
  (lisp::snarf-documentation)
  (dump-xyzzy))

(si:*startup)

