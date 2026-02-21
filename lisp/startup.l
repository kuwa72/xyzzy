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
  ;; Minimal pop-to-buffer for ncurses (no window splitting yet)
  (defun ed::pop-to-buffer (buffer &optional popup-windows vert-p)
    (set-buffer buffer))

  ;; Suppress completion list display (needs window splitting)
  (setq ed::*completion-auto-help* nil)

  ;; pos-visible-in-window-p: defined in window.l (#-ncurses excluded)
  ;; C builtin pos-not-visible-in-window-p is stubbed (always returns nil = visible)
  (defun ed::pos-visible-in-window-p (point &optional window)
    (not (pos-not-visible-in-window-p point window)))

  ;; recenter: defined in window.l (#-ncurses excluded)
  (defun ed::recenter (&optional arg)
    (interactive "p"))

  ;; get-selection-start-end: defined in select.l (#-ncurses excluded)
  ;; Returns nil nil (no selection) since selection is not implemented yet
  (defun ed::get-selection-start-end ()
    (values nil nil))

  ;; selection-start-end macro: defined in select.l
  (defmacro ed::selection-start-end ((start end) &body body)
    `(multiple-value-bind (,start ,end)
         (ed::get-selection-start-end)
       (when ,start
         ,@body))))

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

