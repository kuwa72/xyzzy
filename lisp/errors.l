;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "errors")

(in-package "editor")

(export '(first-error next-error *parse-errors-at-once* *highlight-error*
	  *error-window-size* *error-regexp-list*
	  *find-errors-find-buffers*))

(defvar *parse-errors-at-once* nil)
(defvar *highlight-error* t)

(defvar *error-list* nil)
(defvar *rerror-list* nil)
;;; **car of *error-list* = 現在表示中 (または未表示なら次に行く)
;;; エントリ、*rerror-list* = すでに通過した履歴。** この不変条件が成り
;;; 立つのは「先頭を visit してから履歴へ移す」ときだけで、逆順だと
;;; 1 件だけのエラーが永遠に visit されない (issue #410)。未表示状態は
;;; *error-shown-p* が nil の間だけで、first-error 直後も nil ではない
;;; (次の next-error が 2 件目へ進むために t になっている必要がある)。
(defvar *error-shown-p* nil)
(defvar *max-error-list* 100)
(defvar *error-buffer* nil)
(defvar *last-error* nil)
(defvar *nerrors-found* nil)
(defvar *error-window-size* 4)
(defvar *find-errors-find-buffers* nil)

(defvar-local *find-error-scanner* nil)

(defun find-errors-get-buffer (name later)
  (setq name (string-trim " \t" name))
  (let ((file (substitute-string name "[/\\]+" "/"))
	buffer)
    (cond ((equal (car *last-error*) file)
	   (cdr *last-error*))
	  ((and later (null *parse-errors-at-once*))
	   t)
	  ((setq buffer (if (string-match "^<.+>$" name)
			    (find-buffer (subseq name 1 (- (length name) 1)))
			  (and (file-exist-p file)
			       (or (get-file-buffer file)
				   (save-excursion
				     (find-file file nil t)
				     (selected-buffer))))))
	   (setq *last-error* (cons file buffer))
	   buffer)
	  ((and *find-errors-find-buffers*
		(setq buffer (find-buffer name)))
	   (setq *last-error* (cons file buffer))
	   buffer)
	  (t nil))))

(defvar *error-regexp-list*
  (list
   ;; file(line) / file(line,col): MSVC 系と tsc 系
   (list (compile-regexp "^\\(.+\\)[ \t]*(\\([0-9]+\\)[,)]") 1 2)
   (list (compile-regexp "^\\(.+\\)[:：][ \t]*\\([0-9]+\\)\\([:： \t]\\|$\\)") 1 2)
   (list (compile-regexp "^[^ \n]+ \\(.+\\) \\([0-9]+\\):") 1 2)
   (list (compile-regexp "^[^ \n]+ [^ \n]+ \\(.+\\) \\([0-9]+\\):") 1 2)
   ;; python traceback:   File "x.py", line N, in ...
   (list (compile-regexp "^[ \t]*File \"\\(.+\\)\", line \\([0-9]+\\)") 1 2)
   ;; rustc:   --> src/main.rs:line:col
   (list (compile-regexp "^[ \t]*-->[ \t]+\\(.+\\)[:：]\\([0-9]+\\)[:：][0-9]+") 1 2)
   ;; clojure:   Syntax error compiling at (foo.clj:line:col)
   ;;          at user$eval.invoke(foo.clj:line)
   ;; **ファイル名に : を許さない** のは greedy な前置きが最後の `(' に
   ;; 食いついても `foo.clj:11:2' を `foo.clj' `11' と正しく割るため。
   (list (compile-regexp "^.*(\\([^(): \t]+\\)[:：]\\([0-9]+\\)") 1 2)
   ;; chez scheme:   at line N, char C of file.ss
   (list (compile-regexp "^[ \t]*at line \\([0-9]+\\)[^\n]*of \\([^ \t\n]+\\)") 2 1)))

(defun find-errors (later)
  (let ((opoint (point))
	buffer file line file-regnum line-regnum)
    (goto-bol)
    (loop
      (dolist (x *error-regexp-list*)
	(let ((regexp (pop x)))
	  (when (looking-at regexp)
	    (let ((file-regnum (pop x))
		  (line-regnum (pop x)))
	      (setq line (parse-integer (match-string line-regnum)))
	      (setq file (match-string file-regnum))
	      (setq buffer (find-errors-get-buffer file later))
	      (while (and (not (bufferp buffer))
			  (string-match regexp file))
		(setq line (parse-integer (subseq file
						  (match-beginning line-regnum)
						  (match-end line-regnum))))
		(setq file (subseq file (match-beginning file-regnum)
				   (match-end file-regnum)))
		(setq buffer (find-errors-get-buffer file later))))
	    (when buffer
	      (unless (bufferp buffer)
		(return-from find-errors nil))
	      (save-excursion
		(set-buffer buffer)
		(goto-line line)
		(let ((marker (make-marker)))
		  (set-marker marker)
		  (return-from find-errors marker)))))))
      (unless (forward-line 1)
	(goto-char opoint)
	(return)))))

#|
(defvar *error-regexp*
  (compile-regexp
   "^[ \t]*\\(.+\\)[:：][ \t]*\\([0-9]+\\)\\([:： \t]\\|$\\)\\|^\\(.+\\)[ \t]*(\\([0-9]+\\))"))

(defun error-regexp-regnum ()
  (if (match-beginning 1) (values 1 2) (values 4 5)))

(defvar *error-regexp-regnum* #'error-regexp-regnum)

(defun find-errors (later)
  (let (buffer file line file-regnum line-regnum)
    (goto-bol)
    (while (scan-buffer *error-regexp*)
      (multiple-value-setq (file-regnum line-regnum)
	(funcall *error-regexp-regnum*))
      (setq file (match-string file-regnum))
      (setq line (parse-integer (match-string line-regnum)))
      (setq buffer (find-errors-get-buffer
		    (substitute-string file "[/\\]+" "/") later))
      (while (and (not (bufferp buffer))
		  (string-match *error-regexp* file))
	(multiple-value-setq (file-regnum line-regnum)
	  (funcall *error-regexp-regnum*))
	(setq line (parse-integer (subseq file
					  (match-beginning line-regnum)
					  (match-end line-regnum))))
	(setq file (subseq file (match-beginning file-regnum) (match-end file-regnum)))
	(setq buffer (find-errors-get-buffer file later)))
      (when buffer
	(unless (bufferp buffer)
	  (return))
	(save-excursion
	  (set-buffer buffer)
	  (goto-line line)
	  (let ((marker (make-marker)))
	    (set-marker marker)
	    (return marker))))
      (unless (forward-line 1)
	(return)))))
|#

(defun build-error-list-1 ()
  (long-operation
    (message "Parsing error messages...")
    (let (errors percent opercent (nerrors 0))
      (loop
	(let ((marker (find-errors errors)))
	  (or marker
	      (return))
	  (push (cons marker (current-line-number)) errors))
	(incf *nerrors-found*)
	(incf nerrors)
	(when (<= *max-error-list* nerrors)
	  (return))
	(setq percent (truncate (* 100 (point)) (point-max)))
	(unless (and opercent (eql percent opercent))
	  (setq opercent percent)
	  (message "Parsing error messages...~d (~d% of buffer)"
		   *nerrors-found* percent))
	(or (forward-line 1)
	    (return)))
      (setq *error-list* (nreverse errors)))
    (message "Parsing error messages...done")))

(defun build-error-list ()
  (setq *last-error* nil)
  (setq *nerrors-found* 0)
  ;; **バッファ全体を走査する。** find-errors はポイントから前方向しか
  ;; 見ないので、呼ぶ側が末尾に点を残していると先頭のエラーを丸ごと
  ;; 取りこぼす (*compilation* は再利用されるので起きうる)。
  (goto-char (point-min))
  (build-error-list-1)
  (setq *rerror-list* nil)
  ;; 新しいリストはまだ何も表示していない。これがないと最初の
  ;; next-error が先頭を「表示済み」とみなして捨てる (issue #410)。
  (setq *error-shown-p* nil)
  (setq *error-buffer* (selected-buffer)))

(defun rebuild-error-list ()
  (message "Parsing error messages...")
  (let (errors)
    (save-excursion
      (set-buffer *error-buffer*)
      (goto-line (cdr (car *rerror-list*)))
      (forward-line 1)
      (build-error-list-1))))

(defun goto-error (next)
  ;; 「次へ」は**表示済みの先頭だけ**を履歴へ移す。無条件に移すと
  ;; まだ見せていないエントリが捨てられ、1 件だけのとき rebuild が
  ;; 空を返して最初の next-error が必ず失敗する (issue #410)。
  (when (and next *error-list* *error-shown-p*)
    (setq *rerror-list* (cons (car *error-list*) *rerror-list*))
    (setq *error-list* (cdr *error-list*)))
  (when (and *rerror-list*
	     (null *error-list*))
    (rebuild-error-list))
  (when *error-list*
    (let ((error (car *error-list*)))
      (if (= (count-windows 'arg) 1)
	  (progn
	    (split-window *error-window-size*)
	    (set-buffer *error-buffer*))
	(pop-to-buffer *error-buffer*))
      (goto-line (cdr error))
      (reverse-region (progn
			(goto-eol)
			(point))
		      (progn
			(goto-bol)
			(point)))
      (recenter)
      (let ((scanner (and *highlight-error* *find-error-scanner*)))
	(other-window)
	(set-buffer (marker-buffer (car error)))
	(goto-marker (car error))
	(and scanner
	     (funcall scanner (save-excursion (goto-eol) (point)))
	     (eq *highlight-error* t)
	     (show-match)))
      (recenter)
      ;; ここまで来たということは car を表示したということ。
      ;; 次の goto-error t がそれを履歴へ移せるように立てる。
      (setq *error-shown-p* t)
      t)))

(defun first-error (&optional arg wrap)
  (interactive "p")
  (if (or (and arg (eq *error-buffer* (selected-buffer)))
	  wrap)
      (progn
	(dolist (x *rerror-list*)
	  (setq *error-list* (cons x *error-list*)))
	(setq *rerror-list* nil)
	(or wrap
	    (let ((l (current-line-number)))
	      (while *error-list*
		(let ((x (car *error-list*)))
		  (and (= (cdr x) l)
		       (return))
		  (setq *error-list* (cdr *error-list*))
		  (setq *rerror-list* (cons x *rerror-list*))))))
	;; `next-error' 経由 (wrap) で来たとき、まだリスト自体が無いことが
	;; ある —— grep 系は build-error-list を呼ばないので、そのままだと
	;; 最初の C-x ` が必ず失敗する。空ならこのバッファから構築する
	;; (issue #410)。
	(unless *error-list*
	  (build-error-list)))
    (build-error-list))
  (if (goto-error nil)
      t
    (progn
      (message "エラーはありません")
      nil)))

(defun next-error (&optional arg)
  (interactive "p")
  (if (or *error-list* arg)
      (if (if arg
	      (progn
		(when *rerror-list*
		  (setq *error-list* (cons (car *rerror-list*) *error-list*))
		  (setq *rerror-list* (cdr *rerror-list*)))
		(goto-error nil))
	    (goto-error t))
	  t
	(progn
	  (message "これ以上エラーはありません")
	  nil))
    ;; リストが空なら first-error wrap 経路で構築 (または巻き戻し) する。
    ;; バカチンは「末尾を超えて巻き戻した」時だけ: 未構築バッファでの
    ;; 最初の成功にまで出すと、動いたのに怒られた読みになる (issue #410)。
    (let ((wrapped *rerror-list*))
      (and (first-error nil t)
	   (progn
	     (when wrapped
	       (message "これ以上エラーはないっつってんだろうがこのバカチンが!"))
	     t)))))

#-ncurses
(global-set-key #\F10 'first-error)
(global-set-key #\F11 'next-error)
(define-key ctl-x-map #\` 'next-error)
