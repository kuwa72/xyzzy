;;; -*- Mode: Lisp; Package: SYSTEM; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(in-package "system")

(provide "charname")
(require "cnamedef")

;; *character-name-alist* のコードはすべて BMP 内 (最大 #xffe6) なので、名前を
;; 引く表は 65536 で足り、逆引きの走査も BMP だけでよい。char-code-limit まで
;; 歩くと BMP 外で (ed:char-unicode c) が 65536 以上を返して svref が範囲外に
;; なるうえ、17 倍の空回りになる。
(defconstant *character-name-code-limit* 65536)

(defun make-character-name-hash-table ()
  (let ((v (make-vector *character-name-code-limit*))
	(h (make-hash-table :size 1 :test 'equal)))
    (dolist (x *character-name-alist*)
      (setf (svref v (cdr x)) (car x))
      (setf (gethash (car x) h) (ed:unicode-char (cdr x))))
    (dotimes (i *character-name-code-limit*)
      (let* ((c (code-char i))
	     (u (ed:char-unicode c)))
	(when (and u (< u *character-name-code-limit*) (svref v u))
	  (let ((cs (ed:iso-char-charset c)))
	    (when cs
	      (setf (gethash (concatenate 'string (symbol-name cs)
					  "_" (svref v u)) h)
		    (code-char i)))))))
    h))

(setq *character-name-hash-table*
      (make-character-name-hash-table))
