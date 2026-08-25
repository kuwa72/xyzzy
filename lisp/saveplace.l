;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "saveplace")

(in-package "editor")

(export '(*save-place* *save-place-limit* *save-place-alist*
	  toggle-save-place save-place-find-file-hook
	  save-place-record-point save-place-save-all))

(defvar *save-place* t
  "nil でなければ、ファイルを開いたときに前回のカーソル位置を自動復元する。")

(defvar *save-place-limit* 500
  "記録するカーソル位置の最大ファイル数。")

(define-history-variable *save-place-alist* nil)

(defun save-place-record-point (&optional (buf (selected-buffer)))
  "指定バッファのファイル名とカーソル位置を *save-place-alist* に記録する。"
  (when *save-place*
    (when (bufferp buf)
      (let ((file (get-buffer-file-name buf)))
	(when (and file (stringp file) (file-exist-p file))
	  (setq file (namestring (truename file)))
	  (let ((pos (save-excursion
		       (set-buffer buf)
		       (point))))
	    (setq *save-place-alist*
		  (delete file *save-place-alist* :key #'car :test #'equal))
	    (push (cons file pos) *save-place-alist*)
	    (when (and (integerp *save-place-limit*)
		       (> (length *save-place-alist*) *save-place-limit*))
	      (setq *save-place-alist*
		    (subseq *save-place-alist* 0 *save-place-limit*)))))))))

(defun save-place-save-all ()
  "開いている全バッファのカーソル位置を記録する。"
  (when *save-place*
    (dolist (buf (buffer-list))
      (when (get-buffer-file-name buf)
	(save-place-record-point buf)))))

(defun save-place-find-file-hook ()
  "ファイルを開いた際に、保存されたカーソル位置へ移動する。"
  (when *save-place*
    (let ((file (get-buffer-file-name)))
      (when (and file (stringp file) (file-exist-p file))
	(setq file (namestring (truename file)))
	(let ((entry (assoc file *save-place-alist* :test #'equal)))
	  (when entry
	    (let ((pos (cdr entry)))
	      (when (and (integerp pos)
			 (<= (point-min) pos (point-max)))
		(goto-char pos)))))))))

(defun toggle-save-place (&optional (arg nil sv))
  (interactive "p")
  (toggle-mode '*save-place* arg sv)
  (message "Save place mode is ~:[disabled~;enabled~]" *save-place*))

;; フックの登録
(add-hook '*find-file-hooks* 'save-place-find-file-hook)
(add-hook '*before-delete-buffer-hook* #'(lambda (&optional (buf (selected-buffer)))
					   (save-place-record-point buf)
					   t))
(add-hook '*save-history-hook* 'save-place-save-all)
