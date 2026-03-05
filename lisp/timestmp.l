;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

;;;
;;; format-date
;;;
;;; a: 短い形式の曜日
;;; A: 長い形式の曜日
;;; b: 短い形式の月
;;; B: 長い形式の月
;;; d: 日(00～31)                     # (0～31)
;;; e: 和暦の年(01～)                 # (1～)
;;; E: 和暦の年(元, 02～)             # (元, 2～)
;;; g: 元号(明治,大正,昭和,平成,令和) # (明,大,昭,平,令)
;;; G: 元号(M, T, S, H, R)
;;; H: 時(00～23)                     # (0～23)
;;; I: 12時間の時(01～12)             # (1～12)
;;; i: Internet Time(000～999)
;;; m: 月(01～12)                     # (1～12)
;;; M: 分(00～59)                     # (0～59)
;;; p: 午前/午後
;;; P: AM/PM                          # am/pm
;;; S: 秒(00～59)                     # (0～59)
;;; v: 曜日(日本語)
;;; y: 年(2桁)
;;; Y: 年(4桁)
;;; z: タイムゾーン名(JST-9)
;;; Z: タイムゾーン(+0900)            # (+09:00)

(provide "timestmp")

(in-package "editor")

(export '(format-date format-date-string *date-formats* add-date-format
	  insert-date-string parse-date-string))

(defconstant *abbreviated-weekday-names*
  #("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"))

(defconstant *full-weekday-names*
  #("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday"))

(defconstant *japanese-weekday-names* "月火水木金土日")

(defconstant *abbreviated-month-names*
  #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

(defconstant *full-month-names*
  #("January" "February" "March" "April" "May" "June"
    "July" "August" "September" "October" "November" "December"))

(defvar *timezone-name* "JST")

;; 元号と西暦の対応表(たぶん合ってる)
(defconstant *japanese-era-list*
  '(("令和" "R" 2019 5 1)
    ("平成" "H" 1989 1 8)
    ("昭和" "S" 1926 12 25)
    ("大正" "T" 1912 7 30)
    ;; Common LispではGMT1900年より前は存在しない
    ;; ("明治" "M" 1868 5 9)
   ))

(defconstant *japanese-era*
  (mapcar #'(lambda (x)
	      (list (encode-universal-time
		     0 0 0 (fifth x) (fourth x) (third x) -9)
		    (third x) (first x) (second x)))
	  *japanese-era-list*))

(defun get-japanese-era (universal-time year)
  (let ((x (find universal-time *japanese-era* :test #'>= :key #'car)))
    (if x
	(cons (+ (- year (cadr x)) 1) (cddr x))
      (list (- year 1867) "明治" "M")  ; いまいち
    )))

(defun format-date (s fmt &optional universal-time)
  (unless universal-time
    (setq universal-time (get-universal-time)))
  (multiple-value-bind (sec min hour day mon year dow daylight tz)
      (decode-universal-time universal-time)
    (do ((i 0 (+ i 1))
	 (l (length fmt))
	 (jp nil))
	((= i l))
      (let ((c (elt fmt i)))
	(cond ((char= c #\%)
	       (let ((pound nil))
		 (incf i)
		 (when (= i l)
		   (return))
		 (setq c (elt fmt i))
		 (when (char= c #\#)
		   (setq pound t)
		   (incf i)
		   (when (= i l)
		     (return))
		   (setq c (elt fmt i)))
		 (let ((fmtd (if pound "~d" "~2,'0d")))
		   (case c
		     (#\a
		      (princ (svref *abbreviated-weekday-names* dow) s))
		     (#\A
		      (princ (svref *full-weekday-names* dow) s))
		     (#\b
		      (princ (svref *abbreviated-month-names* (- mon 1)) s))
		     (#\B
		      (princ (svref *full-month-names* (- mon 1)) s))
		     (#\d
		      (format s fmtd day))
		     (#\e
		      (unless jp
			(setq jp (get-japanese-era universal-time year)))
		      (format s fmtd (car jp)))
		     (#\E
		      (unless jp
			(setq jp (get-japanese-era universal-time year)))
		      (if (= (car jp) 1)
			  (princ "元" s)
			(format s fmtd (car jp))))
		     (#\g
		      (unless jp
			(setq jp (get-japanese-era universal-time year)))
		      (princ (if pound (svref (cadr jp) 0) (cadr jp)) s))
		     (#\G
		      (unless jp
			(setq jp (get-japanese-era universal-time year)))
		      (princ (caddr jp) s))
		     (#\H
		      (format s fmtd hour))
		     (#\I
		      (let ((h (mod hour 12)))
			(format s fmtd (if (zerop h) 12 h))))
		     (#\i
		      (format s "~3,'0d"
			      (truncate (rem (+ universal-time 3600) 86400) 86.4)))
		     (#\m
		      (format s fmtd mon))
		     (#\M
		      (format s fmtd min))
		     (#\p
		      (princ (if (< hour 12) "午前" "午後") s))
		     (#\P
		      (if pound
			  (princ (if (< hour 12) "am" "pm") s)
			(princ (if (< hour 12) "AM" "PM") s)))
		     (#\S
		      (format s fmtd sec))
		     (#\v
		      (princ (svref *japanese-weekday-names* dow) s))
		     (#\y
		      (format s "~2,'0d" (mod year 100)))
		     (#\Y
		      (princ year s))
		     (#\z
		      (format s "~A~D" *timezone-name* tz))
		     (#\Z
		      (let ((x (abs tz)))
			(format s "~:[+~;-~]~2,'0d~:[~;:~]~2,'0d"
				(plusp tz) (truncate x) pound
				(mod (truncate (* x 60)) 60))))
		     (t
		      (write-char c s))))))
	      (t
	       (write-char c s)))))))

(defun format-date-string (fmt &optional universal-time)
  (with-output-to-string (s)
    (format-date s fmt universal-time)))

(defvar *date-formats*
  '("%a, %d %b %Y %H:%M:%S %Z"
    "%a, %d %b %Y %H:%M:%S %z"
    "%a %b %d %H:%M:%S %Y"
    "%d %b %Y %H:%M:%S %Z"
    "%d %b %Y %H:%M:%S %z"
    "%Y-%m-%dT%H:%M:%S%#Z"
    "%B %d, %Y"
    "%b %d %Y"
    "%Y-%m-%d"
    "%d %b %y"
    "%y/%m/%d"
    "%y-%m-%d"
    "%g%#e年%#m月%#d日 %v曜日"
    "%g%#e年%#m月%#d日"
    "%Y年%#m月%#d日(%v)"
    "%Y年%#m月%#d日"
    "%y年%#m月%#d日(%v)"
    "%y年%#m月%#d日"
    " %H:%M:%S"
    " %#H:%M:%S"
    " %#I:%M:%S %P"
    " %#H時%#M分%#S秒"
    " %p%#I時%#M分%#S秒"
    "@%i"
    ))

(defun add-date-format (fmt)
  (pushnew fmt *date-formats* :test #'string=))

(defun insert-date-string ()
  (interactive "*")
  (multiple-value-bind (result data)
      (dialog-box '(dialog 0 0 260 120
		    (:caption "日付と時刻")
		    (:font 9 "MS UI Gothic")
		    (:control
		     (:listbox list nil #x50a10001 4 5 192 114)
		     (:button IDOK "OK" #x50030001 205 5 52 14)
		     (:button IDCANCEL "キャンセル" #x50030000 205 22 52 14)))
		  (list (cons 'list (mapcar #'format-date-string *date-formats*)))
		  '((list :must-match t :enable (IDOK))))
    (when result
      (insert (cdr (assoc 'list data))))))

(defvar *date-format-regexp*
  (ed:compile-regexp
   "\\([0-9][0-9]?\\)/\\([0-9][0-9]?\\)/\\([0-9][0-9]?\\) +\\([0-9][0-9]?\\):\\([0-9][0-9]?\\):\\([0-9][0-9]?\\)"))

(defun parse-date-string (string)
  (when (and (stringp string)
	     (ed:string-match *date-format-regexp* string))
    (handler-case (apply #'encode-universal-time
			 (do ((x 1 (1+ x))
			      (r nil))
			     ((> x 6) r)
			   (push (parse-integer (substring string
							   (ed:match-beginning x)
							   (ed:match-end x)))
				 r)))
      (error () nil))))
