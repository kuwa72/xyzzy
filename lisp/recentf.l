;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "recentf")

(in-package "editor")

(export '(*recentf-list* *recentf-max-saved-items*
	  recentf-open recentf-cleanup recentf-add-file))

(defvar *recentf-max-saved-items* 200
  "最近開いたファイル一覧に保持する最大件数。")

(define-history-variable *recentf-list* nil
  "最近開いたファイルパスのリスト。")

(defun recentf-add-file (&optional (file (get-buffer-file-name)))
  "ファイルを最近開いた一覧に追加する。"
  (when (and file (stringp file))
    (let ((path (namestring (truename file))))
      (setq *recentf-list* (delete path *recentf-list* :test #'equal))
      (push path *recentf-list*)
      (when (and (integerp *recentf-max-saved-items*)
		 (> (length *recentf-list*) *recentf-max-saved-items*))
	(setq *recentf-list*
	      (subseq *recentf-list* 0 *recentf-max-saved-items*))))))

(defun recentf-cleanup ()
  "存在しないファイルを最近開いた一覧から除去する。"
  (interactive)
  (setq *recentf-list*
	(remove-if-not #'file-exist-p *recentf-list*))
  (message "Recentf cleaned up."))

(defun recentf-open ()
  "最近開いたファイル一覧から選択して開く。"
  (interactive)
  (let ((candidates (remove-if-not #'file-exist-p *recentf-list*)))
    (unless candidates
      (error "最近開いたファイルはありません"))
    (let ((file (completing-read "Recent file: " candidates
				 :default (car candidates)
				 :must-match t)))
      (when (and file (stringp file) (not (string= file "")))
	(find-file file)))))

(defun recentf-find-file-hook ()
  (recentf-add-file (get-buffer-file-name))
  t)

;; フック登録
(add-hook '*find-file-hooks* 'recentf-find-file-hook)

(define-key ctl-x-map #\C-r 'recentf-open)
