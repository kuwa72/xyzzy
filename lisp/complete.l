;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "complete")

(in-package "editor")

(export '(*completion-auto-help* do-completion do-completion-internal
	  completion-message print-completion-list
	  *print-completion-list-hook*
	  *print-completion-sort-function*
	  *popup-completion-list-default*
	  *minibuffer-completion-cycle*
	  *executable-file-suffixes*))

(defvar *completion-auto-help* t)
(defvar *popup-completion-list-default* nil)
;;; TAB 連打で候補を順に挿入するサイクル補完 (ミニバッファ)。nil で従来通り
;;; (一覧表示どまり・2 回目は *Completion* バッファのスクロール) に戻す。
(defvar *minibuffer-completion-cycle* t)

(defvar-local *completion-related-buffer* nil)
(defvar-local *completion-list* nil)
(defvar-local *completion-list-column* nil)
(defvar-local *completion-prefix* nil)
(defvar-local *completion-last-string* nil)
;;; サイクル補完の状態 (ミニバッファのバッファローカルで持つ)。
;;; origin: サイクル開始時の入力、list: 挿入する候補全文の並び。
(defvar-local *completion-cycle-origin* nil)
(defvar-local *completion-cycle-list* nil)
(defvar-local *completion-cycle-index* nil)

(defvar *executable-list* nil)
(defvar *executable-file-suffixes* '("*.exe" "*.bat" "*.com" "*.lnk"))

(defvar *completion-list-keymap* nil)
(unless *completion-list-keymap*
  (setq *completion-list-keymap* (make-sparse-keymap))
  (define-key *completion-list-keymap* #\RET 'completion-list-copy))

(defvar *print-completion-list-hook* nil)
(defvar *print-completion-sort-function* #'string<)

(defun completion-list-copy ()
  (interactive)
  (let ((w (when *completion-related-buffer*
	     (get-buffer-window *completion-related-buffer*))))
    (unless w
      (return-from completion-list-copy nil))
    (let ((s (nth (if (= *completion-list-column* 2)
		      (+ (* (- (current-line-number) 3) 2)
			 (if (< (current-column) 40) 0 1))
		    (- (current-line-number) 3))
		  *completion-list*)))
      (unless (stringp s)
	(plain-error))
      (when (stringp *completion-prefix*)
	(setq s (concatenate 'string *completion-prefix* s)))
      (save-excursion
	(set-buffer *completion-related-buffer*)
	(let ((o (buffer-substring (point-min) (point-max))))
	  (unless (eql (string-not-equal s o) (length o))
	    (plain-error)))
	(delete-region (point-min) (point-max))
	(insert s))
      (set-window w)
      (goto-char (point-max)))))

(defun scroll-completion-list (list prefix)
  (let ((w (let ((buffer (find-buffer " *Completion*")))
	     (and buffer (get-buffer-window buffer)))))
    (when w
      (let ((ow (selected-window))
	    (buffer (selected-buffer)))
	(unwind-protect
	    (progn
	      (set-window w)
	      (when (and (eq *completion-related-buffer* buffer)
			 (equal *completion-prefix* prefix)
			 (equal *completion-list* list))
		(if (pos-visible-in-window-p (point-max))
		    (goto-char (point-min))
		  (next-page))
		t))
	  (set-window ow))))))

(defun popup-completion-list (list from &optional (to from))
  (let ((buffer (selected-buffer))
	(point (point)))
    (popup-list list #'(lambda (string)
			 (when (and (eq buffer (selected-buffer))
				    (= point (point)))
			   (let ((l (- to from)))
			     (when (and (>= (length string) l)
					(save-excursion
					  (goto-char from)
					  (looking-for (subseq string 0 l))))
			       (incf from l)
			       (setq string (subseq string l))))
			   (delete-region from to)
			   (insert string)
			   (refresh-screen)))
		from)))

(defun print-completion-list (list prefix &optional string popup-p from to)
  (unless *executing-macro*
    (let ((last-string *completion-last-string*))
      (setq *completion-last-string* string)
      (if *print-completion-sort-function*
	  (setq list (sort list *print-completion-sort-function*))
	(setq list (nreverse list)))
      (cond (*print-completion-list-hook*
	     (funcall *print-completion-list-hook* list prefix))
	    ((and (cond ((eq popup-p ':always) t)
			((eq popup-p ':never) nil)
			((eq *popup-completion-list-default* ':always) t)
			((eq *popup-completion-list-default* ':never) nil)
			(t popup-p))
		  from to)
	     (popup-completion-list list (if prefix (+ from (length prefix)) from) to))
	    ((and (eq *last-command* 'minibuffer-complete)
		  (equal string last-string)
		  (scroll-completion-list list prefix)))
	    (t
	     (long-operation
	       (message "Making completion list...")
	       (let ((w (selected-window))
		     (buffer (selected-buffer)))
		 (unwind-protect
		     (with-output-to-temp-buffer (" *Completion*")
		       (setq *completion-list* list)
		       (setq *completion-related-buffer* buffer)
		       (setq *completion-prefix* prefix)
		       (use-keymap *completion-list-keymap*)
		       (cond ((< (apply #'max (mapcar #'length *completion-list*)) 40)
			      (format t "Possible completions are:~%~%~{~A~^~39T ~A~%~}"
				      *completion-list*)
			      (setq *completion-list-column* 2))
			     (t
			      (format t "Possible completions are:~%~%~{~A~^~%~}"
				      *completion-list*)
			      (setq *completion-list-column* 1)))
		       (setq buffer-read-only t))
		   (set-window w)
		   (unless (eq buffer (selected-buffer))
		     (pop-to-buffer buffer))))
	       (message "Making completion list...done")))))))

(defun completion-insert-self (string list prefix last-char to)
  (when (and last-char
	     (eq *last-command* 'minibuffer-complete)
	     (equal string *completion-last-string*)
	     (let* ((s (concat (if (and prefix
					(eql (string-not-equal string prefix)
					     (length prefix)))
				   (subseq string (length prefix))
				 prefix)
			       (string last-char)))
		    (l (length s)))
	       (find-if #'(lambda (x)
			    (let ((d (string-not-equal s x)))
			      (or (null d) (eql d l))))
			list)))
    (goto-char to)
    (insert last-char)
    t))

(defun completion-cycle-full-string (item prefix)
  (let ((s (if (symbolp item) (symbol-name item) item)))
    (if (stringp prefix)
	(concat prefix s)
      s)))

(defun completion-cycle-sorted-full-list (list prefix)
  "一覧表示と同じ並びで、挿入用の候補全文を作る。"
  (let ((sorted (copy-list list)))
    (setq sorted (if *print-completion-sort-function*
		     (sort sorted *print-completion-sort-function*)
		   (nreverse sorted)))
    (mapcar #'(lambda (x) (completion-cycle-full-string x prefix)) sorted)))

(defun completion-cycle-clear ()
  (setq *completion-cycle-origin* nil)
  (setq *completion-cycle-list* nil)
  (setq *completion-cycle-index* nil))

(defun completion-cycle-start (string list prefix)
  (when list
    (setq *completion-cycle-origin* string)
    (setq *completion-cycle-list*
	  (completion-cycle-sorted-full-list list prefix))
    (setq *completion-cycle-index* -1)))

(defun completion-cycle-try (from to)
  "TAB 連打の継続なら次候補を挿入して t を返す。継続でなければ nil。"
  (and *minibuffer-completion-cycle*
       (eq *last-command* 'minibuffer-complete)
       (eq *this-command* 'minibuffer-complete)
       *completion-cycle-list*
       (let ((string (buffer-substring from to)))
	 (when (or (equal string *completion-cycle-origin*)
		   (member string *completion-cycle-list* :test #'equal))
	   (let* ((pos (position string *completion-cycle-list* :test #'equal))
		  (next (if (null pos)
			    0
			  (mod (1+ pos) (length *completion-cycle-list*)))))
	     (setq *completion-cycle-index* next)
	     (delete-region from to)
	     (insert (nth next *completion-cycle-list*))
	     t)))))

(defun do-completion-internal (from to type &optional compl not-uniq-ok word last-char popup-p)
  (let ((string (buffer-substring from to)))
    (when (completion-cycle-try from to)
      (return-from do-completion-internal t))
    (completion-cycle-clear)
    (when (and (member type '(:file-name :exist-file-name
			      :file-name-list :directory-name))
	       (string-match "\\(^\\|[\\/]\\)\\.\\.[\\/]?$" string)
	       (or (string-match "[\\/]$" string)
		   (null (directory (concat string "*") :count 1))))
      (delete-region from to)
      (insert (append-trail-slash (namestring string)))
      (return-from do-completion-internal t))
    (long-operation
      (multiple-value-bind (result list prefix)
	  (*do-completion string type word compl)
	(cond ((stringp result)
	       (cond ((eq string result)
		      (cond ((completion-insert-self string list prefix last-char to)
			     t)
			    (*completion-auto-help*
			     (completion-cycle-start string list prefix)
			     (print-completion-list list prefix string popup-p from to)
			     't)
			    (t
			     (setq *completion-last-string* string)
			     :ambigous)))
		     (t
		      (delete-region from to)
		      (insert result)
		      't)))
	      ((eq result :not-unique)
	       (cond ((completion-insert-self string list prefix last-char to)
		      t)
		     (t
		      (completion-cycle-start string list prefix)
		      (or not-uniq-ok
			  (print-completion-list list prefix string popup-p from to))
		      result)))
	      (t result))))))

(defun build-executable-list ()
  (message "Building executable list...")
  (setq *executable-list*
	(delete-duplicates
	 (mapcan #'(lambda (dir)
		     (directory dir :wild *executable-file-suffixes*))
		 (split-string (si:getenv "PATH") #\; nil))
	 :test #'equalp))
  (message "Building executable list...done"))

(defun complete-command-line (from word)
  (let ((point (point))
	beg end
	cmdb cmde
	quote
	slash
	clist)
    (save-excursion
      (save-restriction
	(narrow-to-region from point)
	(goto-char from)
	(while (< (point) point)
	  (skip-chars-forward " \t")
	  (cond ((looking-for "\"")
		 (forward-char 1)
		 (setq quote t)
		 (setq beg (point))
		 (setq end (if (skip-chars-forward "^\"")
			       (prog1
				   (point)
				 (forward-char 1))
			     (progn
			       (goto-char point)
			       point))))
		(t
		 (setq quote nil)
		 (setq beg (point))
		 (skip-chars-forward "^ \t")
		 (setq end (point))))
	  (setq end (min end point))
	  (setq beg (min beg end))
	  (or cmdb
	      (setq cmdb beg cmde end)))
	(or beg
	    (setq beg point end point cmdb point cmde point))
	(unless quote
	  (save-restriction
	    (narrow-to-region beg end)
	    (goto-char end)
	    (skip-chars-backward "^&|<>(")
	    (setq beg (point))))
	(unless (= beg cmdb)
	  (goto-char beg)
	  (when quote
	    (forward-char -1))
	  (skip-chars-backward " \t")
	  (and (forward-char -1)
	       (looking-at "[&|(]")
	       (setq cmdb beg)))
	(setq slash (progn
		      (goto-char end)
		      (and (scan-buffer "[:/\\]" :reverse t :regexp t :limit beg :tail t)
			   (point)))))
      (let ((d (if slash
		   (buffer-substring beg slash)
		 ".")))
	(cond ((= cmdb beg)
	       (or slash
		   (setq clist (or *executable-list*
				   (progn
				     (build-executable-list)
				     *executable-list*))))
	       (setq clist (nconc (directory d :directory-only t :show-dots t)
				  (directory d :wild *executable-file-suffixes*)
				  clist)))
	      (t
	       (setq clist (directory d :show-dots t))))))
    (let ((status (do-completion-internal (or slash beg) point :list-ignore-case
					  clist nil word)))
      (save-excursion
	(setq end (point))
	(goto-char beg)
	(if (or (string-matchp *shell* "command.com$")
		(string-matchp *shell* "cmd.exe$"))
	    (replace-buffer "/" "\\" :limit end)
	  (replace-buffer "\\" "/" :limit end))
	(unless quote
	  (goto-char beg)
	  (when (scan-buffer " " :limit end)
	    (goto-char beg)
	    (insert "\"")
	    (setq quote t))))
      (when (eq status :solo-match)
	(or (looking-at " \t")
	    (insert (if quote "\" " " "))))
      status)))

(defun completion-message (status)
  (unless *executing-macro*
    (cond ((eq status :no-match)
	   (message "No match"))
	  ((eq status :no-completions)
	   (message "No completions"))
	  ((eq status :ambigous)
	   (message "Ambigous"))
	  ((eq status :solo-match)
	   (message "Solo match"))
	  ((eq status :not-unique)
	   (message "Complete, but not unique"))))
  status)

(defun do-completion (from to type &optional compl word last-char
			   (popup-p *popup-completion-list-default*))
  (completion-message
   (if (eq type ':command-line)
       (complete-command-line from word)
     (do-completion-internal from to type compl nil word last-char popup-p))))
