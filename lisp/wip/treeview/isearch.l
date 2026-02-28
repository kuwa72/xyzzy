;;; -*- Mode: Lisp; Package: TREEVIEW -*-
;;; isearch.l --- treeview

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 13:11:42 +0900>

;;; Code:

(provide "wip/treeview/isearch")

(require "wip/treeview/defs")
(require "wip/treeview/search")

(in-package "treeview")

(defvar *treeview-isearch-map* nil)
(unless *treeview-isearch-map*
  (setq *treeview-isearch-map* (make-sparse-keymap))
  (define-key *treeview-isearch-map* #\C-s 'treeview-isearch-repeat-forward)
  (define-key *treeview-isearch-map* #\C-r 'treeview-isearch-repeat-backward)
  (define-key *treeview-isearch-map* #\C-h 'treeview-isearch-delete-char)
  (define-key *treeview-isearch-map* #\DEL 'treeview-isearch-delete-char)
  (define-key *treeview-isearch-map* #\Delete 'treeview-isearch-delete-char)
  (define-key *treeview-isearch-map* #\C-g 'treeview-isearch-abort)
  (define-key *treeview-isearch-map* #\ESC 'treeview-isearch-search-or-exit)
  (define-key *treeview-isearch-map* #\Home 'treeview-isearch-search-or-exit)
  (define-key *treeview-isearch-map* #\C-q 'treeview-isearch-quote-char)
  (define-key *treeview-isearch-map* #\Up 'treeview-isearch-search-history-backward)
  (define-key *treeview-isearch-map* #\Down 'treeview-isearch-search-history-forward)
  (define-key *treeview-isearch-map* #\C-w 'treeview-isearch-yank-word)
  (define-key *treeview-isearch-map* #\C-y 'treeview-isearch-yank)
  (define-key *treeview-isearch-map* #\S-Insert 'treeview-isearch-paste-from-clipboard)
  (define-key *treeview-isearch-map* #\RET 'treeview-isearch-exit)
  (define-key *treeview-isearch-map* #\LFD 'treeview-isearch-self-insert)
  ;;
  (define-key *treeview-isearch-map* #\C-o 'toggle-ime))

(defvar *treeview-isearch-history* nil)
(register-history-variable '*treeview-isearch-history*)

(defvar *treeview-isearch-smart-case* nil)
(defvar *treeview-isearch-part* t)

(defvar *treeview-isearch-current-string* nil)
(defvar *treeview-isearch-current-match-string* nil)
(defvar *treeview-isearch-command-char* nil)
(defvar *treeview-isearch-this-command* nil)
(defvar *treeview-isearch-last-command* nil)
(defvar *treeview-isearch-last-match* nil)
(defvar *treeview-isearch-direction* nil)
(defvar *treeview-isearch-wrapped* nil)
(defvar *treeview-isearch-status* nil)
(defvar *treeview-isearch-no-clear* nil)
(defvar *treeview-isearch-last-history* nil)
(defvar *treeview-isearch-history-index* nil)
(defvar *treeview-isearch-history-last-string* nil)
(defvar *treeview-isearch-regexp* nil)
(defvar *treeview-isearch-scanner-hook* nil)

(defun treeview-isearch-scanner (string no-dup &optional (hitem (treeview-get-selected-item)))
  (let ((*treeview-isearch-regexp* nil)
        (pattern string))
    (when *treeview-isearch-scanner-hook*
      (setq pattern (funcall *treeview-isearch-scanner-hook* pattern)))
    (setq *treeview-isearch-current-string* string)
    (setq *treeview-isearch-last-match*
          (if (treeview-hitem-valid-p
               (setq hitem (treeview-scan-treeview
                            pattern
                            :hitem hitem
                            :reverse (not *treeview-isearch-direction*)
                            :no-dup no-dup
                            :regexp *treeview-isearch-regexp*
                            :case-fold *treeview-case-fold-search*
                            :part *treeview-isearch-part*)))
              (progn
                (setq *treeview-isearch-current-match-string* (match-string 0))
                t)
            (progn
              (setq *treeview-isearch-current-match-string* nil)
              (ding)
              nil)))))

(defun treeview-isearch-push-status ()
  (push (list (point) (treeview-get-selected-item)
              *treeview-isearch-direction* *treeview-isearch-last-match*
              *treeview-isearch-current-string* *treeview-isearch-wrapped*)
        *treeview-isearch-status*))

(defun treeview-isearch-pop-status ()
  (let ((x (pop *treeview-isearch-status*)))
    (goto-char (first x))
    (treeview-select-item (second x))
    (setq *treeview-isearch-direction* (third x)
          *treeview-isearch-last-match* (fourth x)
          *treeview-isearch-current-string* (fifth x)
          *treeview-isearch-wrapped* (sixth x))))

(defun treeview-isearch-repeat-forward ()
  (when (string= *treeview-isearch-current-string* "")
    (setq *treeview-isearch-current-string* *treeview-last-search-string*))
  (let ((last-dir *treeview-isearch-direction*)
        (no-wrap t)
        (hitem (treeview-get-selected-item)))
    (setq *treeview-isearch-direction*
          (eq *treeview-isearch-this-command* 'treeview-isearch-repeat-forward))
    (unless (string= *treeview-isearch-current-string* "")
      (treeview-isearch-push-status)
      (or *treeview-isearch-last-match*
          (not (eq last-dir *treeview-isearch-direction*))
          (progn
            (setq *treeview-isearch-wrapped* t no-wrap nil)
            (setq hitem (if *treeview-isearch-direction*
                            (treeview-get-root-item)
                          (treeview-get-bottom-item)))))
      (treeview-isearch-scanner *treeview-isearch-current-string* no-wrap hitem))))

(setf (symbol-function 'treeview-isearch-repeat-backward)
      #'treeview-isearch-repeat-forward)

(defun treeview-isearch-delete-char ()
  (if (or (eq *treeview-isearch-last-command* 'treeview-isearch-search-history-forward)
          (not *treeview-isearch-status*))
      (let ((l (length *treeview-isearch-current-string*)))
        (if (zerop l)
            (ding)
          (setq *treeview-isearch-current-string*
                (subseq *treeview-isearch-current-string* 0 (1- 1))))
        (setq *treeview-isearch-this-command* 'treeview-isearch-search-history-forward))
    (treeview-isearch-pop-status)))

(defun treeview-isearch-abort ()
  (let ((last *treeview-isearch-last-match*)
        (curstr *treeview-isearch-current-string*))
    (loop
      (unless *treeview-isearch-status*
        (unless (string= curstr "")
          (setq *treeview-last-search-string* curstr))
        (quit))
      (and (not last)
           *treeview-isearch-last-match*
           (return))
      (treeview-isearch-pop-status))))

(defun treeview-isearch-search-or-exit ()
  (if *treeview-isearch-status*
      (treeview-isearch-exit)
    (progn
      (setq *treeview-isearch-no-clear* t)
      (throw 'treeview-isearch-exit (call-interactively
                                     (if *treeview-isearch-direction*
                                         'treeview-search-forward
                                       'treeview-search-backward))))))

(defun treeview-isearch-exit ()
  (unless (string= *treeview-isearch-current-string* "")
    (setq *treeview-last-search-string* *treeview-isearch-current-string*))
  (throw 'treeview-isearch-exit t))

(defun treeview-isearch-search-history-backward ()
  (if (eq *treeview-isearch-last-history* *treeview-isearch-current-string*)
      (setq *treeview-isearch-history-index*
            (min (max 0 *treeview-isearch-history-index*)
                 (1- (length *treeview-isearch-history*))))
    (progn
      (setq *treeview-isearch-history-index* -1)
      (setq *treeview-isearch-history-last-string* *treeview-isearch-current-string*)))
  (let ((l (length *treeview-isearch-history-last-string*)))
    (loop
      (if (eq *treeview-isearch-this-command* 'treeview-isearch-search-history-backward)
          (incf *treeview-isearch-history-index*)
        (decf *treeview-isearch-history-index*))
      (let ((s (unless (minusp *treeview-isearch-history-index*)
                 (nth *treeview-isearch-history-index* *treeview-isearch-history*))))
        (unless s
          (ding)
          (return))
        (let ((match (if *treeview-case-fold-search*
                         (string-not-equal s *treeview-isearch-history-last-string*)
                       (string/= s *treeview-isearch-history-last-string*))))
          (when (or (null match)
                    (= match l))
            (setq *treeview-isearch-last-history* s)
            (setq *treeview-isearch-current-string* s)
            (return))))))
  (setq *treeview-isearch-this-command* 'treeview-isearch-search-history-forward))

(setf (symbol-function 'treeview-isearch-search-history-forward)
      #'treeview-isearch-search-history-backward)

(defun treeview-isearch-yank-word ()
  (let* ((hitem (treeview-get-selected-item))
         (text (treeview-get-item-text hitem))
         (start (progn
                  (if (or (and (eq *treeview-case-fold-search* :smart)
                               (not (string-match "[A-Z]" *treeview-isearch-current-string*)))
                          (and (not (eq *treeview-case-fold-search* :smart))
                               *treeview-case-fold-search*))
                      (string-matchp (regexp-quote *treeview-isearch-current-string*) text)
                    (string-match (regexp-quote *treeview-isearch-current-string*) text))
                  (or (match-end 0) 0)))
         (end (progn
                (string-match ".+?\\>" text start)
                (match-end 0)))
         (next-word (substring text start end)))
    (if (and *treeview-isearch-smart-case*
             (eq *treeview-case-fold-search* :smart)
             (not (string-match "[A-Z]" *treeview-isearch-current-string*)))
        (setq next-word (string-downcase next-word)))
    (treeview-isearch-push-status)
    (treeview-isearch-scanner (concat *treeview-isearch-current-string* next-word) nil hitem)))

(defun treeview-isearch-yank ()
  (let ((hitem (treeview-get-selected-item))
        (x (ed::current-kill 0)))
    (if (and *treeview-isearch-smart-case*
             (eq *treeview-case-fold-search* :smart)
             (not (string-match "[A-Z]" *treeview-isearch-current-string*)))
        (setq x (mapcar #'string-downcase x)))
    (treeview-isearch-push-status)
    (treeview-isearch-scanner (apply #'concat *treeview-isearch-current-string* x) nil hitem)))

(defun treeview-isearch-paste-from-clipboard ()
  (let ((x (get-clipboard-data)))
    (when x
      (treeview-isearch-push-status)
      (treeview-isearch-scanner (concat *treeview-isearch-current-string* x) nil
                                (treeview-get-selected-item)))))

(defun treeview-isearch-quote-char ()
  (let ((c (quote-char-read)))
    (treeview-isearch-push-status)
    (treeview-isearch-scanner
     (concat *treeview-isearch-current-string* (string c)) nil
     (treeview-get-selected-item))))

(defun treeview-isearch-self-insert (&optional (ch *treeview-isearch-command-char*))
  (unless (or (eq *treeview-isearch-this-command* 'treeview-isearch-self-insert)
              (graphic-char-p ch))
;   (unread-char ch *keyboard*)
    (treeview-isearch-exit))
  (treeview-isearch-push-status)
  (treeview-isearch-scanner (concat *treeview-isearch-current-string* (string ch)) nil
                            (treeview-get-selected-item)))

(defun treeview-isearch-forward (&optional reverse)
  (interactive)
  (let ((*treeview-isearch-current-string* "")
        (*treeview-isearch-current-match-string* nil)
        (*treeview-isearch-last-match* t)
        (*treeview-isearch-no-clear* nil)
        (*treeview-isearch-history-index* -1)
        (*treeview-isearch-last-history* nil)
        (*treeview-isearch-history-last-string* nil)
        (*treeview-isearch-this-command* nil)
        (*treeview-isearch-last-command* nil)
        (*treeview-isearch-wrapped* nil)
        (*treeview-isearch-status* nil)
        (*treeview-isearch-direction* (not reverse))
        (*treeview-scan-treeview-hook*
           #'(lambda (hitem)
               (let (func-gen func)
                 (treeview-select-item hitem)
                 (when (and (setq func-gen (treeview-data-get 'implicit-func-gen))
                            (setq func (funcall func-gen hitem)))
                   (funcall func)))))
        (hitem (treeview-get-selected-item)))
    (setq *treeview-last-search-regexp-p* nil)
    (unwind-protect
        (catch 'treeview-isearch-exit
          (loop
            (refresh-screen)
            (treeview-minibuffer-prompt "~:[Failing ~;~]~:[~;Wrapped ~]I-search~:[ backward~;~]: ~a"
                               *treeview-isearch-last-match* *treeview-isearch-wrapped*
                               *treeview-isearch-direction* *treeview-isearch-current-string*)
            (let ((*treeview-isearch-command-char* (read-char *keyboard*)))
              (setq *treeview-isearch-this-command*
                    (lookup-keymap *treeview-isearch-map*
                                   *treeview-isearch-command-char* t))
              (if *treeview-isearch-this-command*
                  (funcall *treeview-isearch-this-command*)
                (treeview-isearch-self-insert *treeview-isearch-command-char*))
              (setq *treeview-isearch-last-command* *treeview-isearch-this-command*))))
      (unless *treeview-isearch-no-clear*
        (minibuffer-message "")
        (add-history *treeview-isearch-current-string* '*treeview-isearch-history*)))))

(defun treeview-isearch-backward ()
  (interactive)
  (treeview-isearch-forward t))

;;; isearch.l ends here
