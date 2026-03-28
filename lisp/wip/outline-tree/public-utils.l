;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; public-utils.l

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:28:43 +0900>

;;; Code:

(provide "outline-tree/public-utils")

(require "outline-tree/defs")

(in-package "outline-tree2")

;; buffer
(defun outline-tree-buffer-read-only-p (&optional buffer)
  (if buffer
      (save-excursion
        (set-buffer buffer)
        (symbol-value 'buffer-read-only))
    (symbol-value 'buffer-read-only)))

;; filer
(defun outline-tree-filer-open-p ()
  (handler-case
      (progn
        (filer-reload)
        t)
    (error (c)
      nil)))

;; tag
(defun outline-tree-goto-next-tag ()
  (interactive)
  (unless (and html-highlight-mode
               (syntax-open-tag-p #\<) (syntax-close-tag-p #\>))
    (return-from outline-tree-goto-next-tag nil))
  (let (point)
    (save-excursion
      (while (scan-buffer "<" :no-dup t)
        (when (eq (parse-point-syntax) nil)
          (setq point (point))
          (return))))
    (when point
      (goto-char point))))

(defun outline-tree-goto-matched-tag (&optional point)
  (interactive)
  (let ((matched-tag-range (outline-tree-get-matched-tag)))
    (when matched-tag-range
      (goto-char (car matched-tag-range)))))

(defun outline-tree-get-current-tag (&optional point)
  (unless (and html-highlight-mode
               (syntax-open-tag-p #\<) (syntax-close-tag-p #\>))
    (return-from outline-tree-get-current-tag nil))
  (let (from to tag-range tag-type tagname)
    (save-excursion
      (when point
        (goto-char point))
      (cond
       ((member (parse-point-syntax) '(:tag :string :comment))
        (skip-syntax-spec-backward "^{")
        (backward-char))
       ((and (eq (parse-point-syntax) nil)
             (eq (parse-point-syntax (1+ (point))) :tag)))
       (t
        (return-from outline-tree-get-current-tag nil)))
      (setq from (point))
      (if (char/= #\/ (char-after (1+ from)))
          (setq tag-type :start-tag)
        (setq tag-type :end-tag))
      (skip-syntax-spec-forward "^}")
      (unless (char= (char-after (point)) #\>)
        (return-from outline-tree-get-current-tag nil))
      (when (and (eq tag-type :start-tag)
                 (char= (char-before (point)) #\/))
        (setq tag-type :empty-element-tag))
      (setq to (1+ (point)))
      (setq tag-range (cons from to))
      (goto-char from)
      (if (member tag-type '(:start-tag :empty-element-tag))
          (looking-at "<[ \t\n]*\\([^ \t\n>]+\\)")
        (looking-at "</[ \t\n]*\\([^ \t\n>]+\\)"))
      (setq tagname (match-string 1))
      (values tag-range tag-type tagname))))

(defun outline-tree-get-matched-tag (&optional point)
  (unless (and html-highlight-mode
               (syntax-open-tag-p #\<) (syntax-close-tag-p #\>))
    (return-from outline-tree-get-matched-tag nil))
  (let (from to start-tag-range end-tag-range empty-element-tag-range
        current-tag-type tagname nest regexp)
    (save-excursion
      (when point
        (goto-char point))
      (cond
       ((eq (parse-point-syntax) :tag)
        (skip-syntax-spec-backward "^{")
        (backward-char))
       ((and (eq (parse-point-syntax) nil)
             (eq (parse-point-syntax (1+ (point))) :tag)))
       (t
        (return-from outline-tree-get-matched-tag nil)))
      (setq from (point))
      (if (char/= #\/ (char-after (1+ from)))
          (setq current-tag-type :start-tag)
        (setq current-tag-type :end-tag))
      (skip-syntax-spec-forward "^}")
      (unless (char= (char-after (point)) #\>)
        (return-from outline-tree-get-matched-tag nil))
      (when (and (eq current-tag-type :start-tag)
                 (char= (char-before (point)) #\/))
        (setq current-tag-type :empty-element-tag))
      (setq to (1+ (point)))
      (cond
       ((eq current-tag-type :start-tag)
        (setq start-tag-range (cons from to)))
       ((eq current-tag-type :end-tag)
        (setq end-tag-range (cons from to)))
       ((eq current-tag-type :empty-element-tag)
        (setq empty-element-tag-range (cons from to))))
      (goto-char from)
      (if (member current-tag-type '(:start-tag :empty-element-tag))
          (looking-at "<[ \t\n]*\\([^ \t\n>]+\\)")
        (looking-at "</[ \t\n]*\\([^ \t\n>]+\\)"))
      (setq tagname (match-string 1))
      (setq nest 1)
      (cond
       ((eq current-tag-type :start-tag)
        (goto-char to)
        (setq regexp (compile-regexp (concat "<\\(/\\)?" (regexp-quote tagname) "[ \t\n>]") t))
        (while (scan-buffer regexp :tail t)
          (when (eq (parse-point-syntax (match-beginning 0)) nil)
            (if (match-string 1)
                (decf nest)
              (progn
                (backward-char)
                (skip-syntax-spec-forward "^}")
                (unless (and (char= (char-after (point)) #\>)
                             (char= (char-before (point)) #\/))
                  (incf nest))))
            (when (= nest 0)
              (setq end-tag-range (cons (match-beginning 0) (match-end 0)))
              (return)))))
       ((eq current-tag-type :end-tag)
        (goto-char from)
        (setq regexp (compile-regexp (concat "<\\(/\\)?" (regexp-quote tagname) "[ \t\n>]") t))
        (while (scan-buffer regexp :reverse t :no-dup t)
          (when (eq (parse-point-syntax (match-beginning 0)) nil)
            (if (match-string 1)
                (incf nest)
              (save-excursion
                (skip-syntax-spec-forward "^}")
                (unless (and (char= (char-after (point)) #\>)
                             (char= (char-before (point)) #\/))
                  (decf nest))))
            (when (= nest 0)
              (setq start-tag-range (cons (match-beginning 0) (match-end 0)))
              (return))))))
      (when (or (eq current-tag-type :empty-element-tag)
                (and start-tag-range end-tag-range))
        (cond
         ((eq current-tag-type :start-tag)
          (values end-tag-range start-tag-range current-tag-type tagname))
         ((eq current-tag-type :end-tag)
          (values start-tag-range end-tag-range current-tag-type tagname))
         ((eq current-tag-type :empty-element-tag)
          (values nil empty-element-tag-range current-tag-type tagname)))))))

;; public-utils.l ends here
