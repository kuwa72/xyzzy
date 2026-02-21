;;; -*-Lisp-*-
;;;
;;; This file is part of xyzzy.
;;;

;; Use .l explicitly for ncurses to bypass .lc files
;; (.lc was compiled without :ncurses in *features*)
#+ncurses (si:*load-library "loadup.l")
#-ncurses (si:*load-library "loadup")

;; Define variables from #-ncurses excluded files that cmds.l references
;; Must use ed:: prefix since these are in the editor package
#+ncurses
(progn
  (defvar-local ed::abbrev-mode nil)
  (defvar ed::*buffer-package* nil)
  (make-variable-buffer-local 'ed::*buffer-package*)
  (defvar ed::*minibuffer-complex-command-history* nil)
  (defvar ed::*minibuffer-default-history* nil))

(provide "startup")

#-ncurses
(defun si:*startup ()
  (ed::startup))

#+ncurses
(defun si:*startup ()
  (trap-errors (ed::init-misc-objects))
  t)

#-ncurses
(unless (xyzzy-dumped-p)
  (si:*show-window-foreground)
  (ed::init-misc-objects)
  (lisp::snarf-documentation)
  (dump-xyzzy))

(si:*startup)

