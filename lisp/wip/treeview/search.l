;;; -*- Mode: Lisp; Package: TREEVIEW ; Encoding: utf-8 -*-
;;; search.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 12:56:47 +0900>

;;; Code:

(provide "wip/treeview/search")

(require "wip/treeview/defs")

(in-package "treeview")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; treeview 検索
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *treeview-scan-treeview-hook* #'treeview-select-item
  "treeview-scan-treeview で検索したアイテムに対して実行する関数")
(defun treeview-scan-treeview (pattern &key hitem no-dup case-fold reverse regexp
                                       part limit)
  "treeview のアイテムを検索する。"
  (when (treeview-exist-p)
    (let (node-mover text)
      (if reverse
          (setq node-mover #'treeview-get-up-item)
        (setq node-mover #'treeview-get-down-item))
      (unless (treeview-hitem-valid-p hitem)
        (setq hitem (treeview-get-selected-item)))
      (if (treeview-hitem-valid-p hitem)
          (if no-dup
              (setq hitem (funcall node-mover hitem)))
        (if reverse
            (setq hitem (treeview-get-bottom-item))
          (setq hitem (treeview-get-root-item))))
      (unless (treeview-hitem-valid-p limit)
        (setq limit nil))
      (if (and limit
               (or (and (not reverse)
                        (treeview-hitem-not-lessp hitem limit))
                   (and reverse
                        (treeview-hitem-lessp hitem limit))))
          (return-from treeview-scan-treeview nil))
      (when (not regexp)
        (setq pattern (regexp-quote pattern))
        (if (not part)
            (setq pattern (concat "^" pattern "$"))))
      (setq pattern (compile-regexp pattern case-fold))
      (while (and (treeview-hitem-valid-p hitem)
                  (not (string-match pattern (treeview-get-item-text hitem))))
        (when (and limit reverse (treeview-hitem-equal hitem limit))
          (setq hitem nil)
          (return))
        (setq hitem (funcall node-mover hitem))
        (when (and limit (not reverse) (treeview-hitem-equal hitem limit))
          (setq hitem nil)
          (return)))
      (if (treeview-hitem-valid-p hitem)
          (progn
            (if *treeview-scan-treeview-hook*
                (funcall *treeview-scan-treeview-hook* hitem))
            hitem)
        nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; search
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *treeview-last-search-string* "")
(defvar *treeview-last-search-regexp* "")
(defvar *treeview-last-search-regexp-p* nil)
(defvar *treeview-last-search-p* nil)
(defvar *treeview-case-fold-search* :smart)
(defvar *treeview-part-search* t)
(defvar *treeview-wrap-search* t)

(defun treeview-search-command (pattern reverse regexp interactive-p &optional hitem noerror nomsg)
  (let ((no-dup (equal pattern (if regexp
                                   *treeview-last-search-regexp*
                                 *treeview-last-search-string*)))
        (wrapped nil)
        ohitem no-wrap)
    (unless hitem
      (setq hitem (treeview-get-selected-item)))
    (unless (treeview-hitem-valid-p hitem)
      (setq hitem (if reverse
                      (treeview-get-bottom-item)
                    (treeview-get-root-item)))
      (setq no-dup nil))
    (when interactive-p
      (setq *treeview-last-search-p* t)
      (setq *treeview-last-search-regexp-p* regexp)
      (if regexp
          (setq *treeview-last-search-regexp* pattern)
        (setq *treeview-last-search-string* pattern))
      (or nomsg
          (progn
            (message "Searching...")
            (refresh-screen))))
    (setq ohitem hitem)
    (if (or (and reverse (treeview-hitem-equal
                          hitem (treeview-get-bottom-item)))
            (and (not reverse) (treeview-hitem-equal
                                hitem (treeview-get-root-item))))
        (setq no-wrap t))
    (cond ((or (treeview-hitem-valid-p
                (setq hitem (treeview-scan-treeview pattern
                                                    :hitem ohitem
                                                    :regexp regexp
                                                    :no-dup no-dup
                                                    :case-fold *treeview-case-fold-search*
                                                    :reverse reverse
                                                    :part *treeview-part-search*)))
               (and interactive-p
                    *treeview-wrap-search*
                    (not no-wrap)
                    (progn
                      (setq hitem (if reverse
                                      (treeview-get-bottom-item)
                                    (treeview-get-root-item)))
                      (setq wrapped
                            (treeview-hitem-valid-p
                             (setq hitem (treeview-scan-treeview
                                          pattern
                                          :hitem hitem
                                          :regexp regexp
                                          :no-dup nil
                                          :case-fold *treeview-case-fold-search*
                                          :reverse reverse
                                          :part *treeview-part-search*
                                          :limit (if reverse
                                                     (treeview-get-down-item ohitem)
                                                   ohitem))))))))
           (when interactive-p
             (or nomsg
                 (progn
                   (message "Searching...done~A" (if wrapped "(Wrapped)" ""))
                   (refresh-screen))))
           hitem)
          (noerror
           nil)
          (t
;           (plain-error "文字列が見つかりません")
           (message "文字列が見つかりません")
           (refresh-screen)
           nil))))

(defun treeview-search-forward (pattern &optional noerror)
  (interactive
      (list
       (read-string (concat (treeview-get-id-display-name)
                            "Search forward: ")
                    :default *treeview-last-search-string*
                    :history 'ed::search)
       nil))
  (treeview-search-command pattern nil nil (interactive-p) nil noerror))

(defun treeview-search-backward (pattern &optional noerror)
  (interactive
      (list
       (read-string (concat (treeview-get-id-display-name)
                            "Search backward: ")
                    :default *treeview-last-search-string*
                    :history 'ed::search)
       nil))
  (treeview-search-command pattern t nil (interactive-p) nil noerror))

(defun treeview-search-forward-again ()
  (interactive)
  (when (equal *treeview-last-search-string* "")
    (plain-error "No last search"))
  (treeview-search-command *treeview-last-search-string* nil nil (interactive-p) nil nil))

(defun treeview-search-backward-again ()
  (interactive)
  (when (equal *treeview-last-search-string* "")
    (plain-error "No last search"))
  (treeview-search-command *treeview-last-search-string* t nil (interactive-p) nil nil))

(defun treeview-re-search-forward (regexp &optional noerror)
  (interactive
      (list
       (read-string (concat (treeview-get-id-display-name)
                            "Re-search forward: ")
                    :default *treeview-last-search-regexp*
                    :history 'ed::search)
       nil))
  (treeview-search-command regexp nil t (interactive-p) nil noerror))

(defun treeview-re-search-backward (regexp &optional noerror)
  (interactive
      (list
       (read-string (concat (treeview-get-id-display-name)
                            "Re-search backward: ")
                    :default *treeview-last-search-regexp*
                    :history 'ed::search)
       nil))
  (treeview-search-command regexp t t (interactive-p) nil noerror))

(defun treeview-re-search-forward-again ()
  (interactive)
  (when (equal *treeview-last-search-regexp* "")
    (plain-error "No last search"))
  (treeview-search-command *treeview-last-search-regexp* nil t (interactive-p) nil nil))

(defun treeview-re-search-backward-again ()
  (interactive)
  (when (equal *treeview-last-search-regexp* "")
    (plain-error "No last search"))
  (treeview-search-command *treeview-last-search-regexp* t t (interactive-p) nil nil))

(defun treeview-repeat-forward-search ()
  (interactive)
  (if (interactive-p)
      (call-interactively (if *treeview-last-search-regexp-p*
                              'treeview-re-search-forward-again
                            'treeview-search-forward-again))
    (if *treeview-last-search-regexp-p*
        (treeview-re-search-forward-again)
      (treeview-search-forward-again))))

(defun treeview-repeat-backward-search ()
  (interactive)
  (if (interactive-p)
      (call-interactively (if *treeview-last-search-regexp-p*
                              'treeview-re-search-backward-again
                            'treeview-search-backward-again))
    (if *treeview-last-search-regexp-p*
        (treeview-re-search-backward-again)
      (treeview-search-backward-again))))

;;; search.l ends here
