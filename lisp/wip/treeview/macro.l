;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; macro.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 12:55:28 +0900>

;;; Code:

(provide "wip/treeview/macro")

(require "wip/treeview/defs")

(in-package "treeview")

(defmacro with-treeview ((treeview-id) &body body)
  "treeview ライブラリ内でのみ用いる"
  `(let ((*treeview-id* ,treeview-id))
     ,@body))
(setf (get 'with-treeview 'ed:lisp-indent-hook) 1)

(defmacro with-app ((app-id &optional save-last-app-id-p) &body body)
  "treeview ライブラリ外から用いる"
  `(let ((app-id ,app-id)
         (save-last-app-id-p ,save-last-app-id-p))
     (multiple-value-prog1
      (if (eq *treeview-app-id* app-id)
          (progn
            ,@body)
        (let* ((*treeview-app-id* app-id)
               (*treeview-id* (treeview-app-id-get-treeview-id app-id))
               (*treeview-expand-expand-pre-hook*
                (symbol-value (treeview-data-get 'treeview::expand-expand-pre-hook)))
               (*treeview-expand-expand-hook*
                (symbol-value (treeview-data-get 'treeview::expand-expand-hook))))
          ,@body))
      (when (and app-id save-last-app-id-p)
        (setq *treeview-last-app-id* app-id)
        (setq *treeview-last-id* (treeview-app-id-get-treeview-id app-id))))))
(setf (get 'with-app 'ed:lisp-indent-hook) 1)

(defmacro treeview-on-treeview (&rest body)
  "treeview 上から editor のコマンドを実行する"
  `(unwind-protect
       (progn
         (treeview-focus-editor)
         ,@body)
     (progn
       (treeview-focus-treeview)
       (end-wait-cursor)
       (refresh-screen))))

(defmacro treeview-make-tv-command (&rest commands)
  "treeview 用コマンドの作成"
  (let* ((main-command (car commands))
         (sub-functions (cdr commands))
         (name (intern (concatenate 'string (symbol-name main-command) "-on-treeview"))))
    `(progn
       (defun ,name ()
         (interactive)
         (treeview-on-treeview
          (prog1
              (call-interactively ',main-command)
            ,@(mapcar #'(lambda (func) (list 'ed::funcall (list 'quote func)))
                      sub-functions))))
       ',name)))

(defmacro treeview-suppress-redraw (&rest body)
  "再描画を抑制"
  `(unwind-protect
       (progn
         (treeview-data-set 'treeview::suppress-redraw-count
                            (1+ (treeview-data-get 'treeview::suppress-redraw-count 0)))
         (treeview-set-redraw nil)
         ,@body)
     (progn
       (treeview-data-set 'treeview::suppress-redraw-count
                          (1- (treeview-data-get 'treeview::suppress-redraw-count 0)))
       (if (zerop (treeview-data-get 'treeview::suppress-redraw-count 0))
           (treeview-set-redraw t)))))

;;; macro.l ends here
