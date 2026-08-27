;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; バッファ切り替えをファジー絞り込みにする (C-x b)。
;;;
;;; 素の switch-to-buffer は `interactive' の "B" 指定から C++ 側の
;;; バッファ名読み取りを呼ぶので、絞り込み方に手を入れる隙が無い。
;;; M-x のとき (lisp/fuzzy-mx.l) と同じ形で、候補を Lisp 側で作って
;;; lisp/fuzzy-complete.l の絞り込みループに渡す。
;;;
;;; 並び順は「直前のバッファが先頭、今のバッファは最後」。C-x b は
;;; 「さっきの所に戻る」のに一番よく使うので、RET だけで戻れる方が速い。
;;; 今のバッファを候補から外さないのは、うっかり選んでも何も起きないだけで
;;; 済むのに対し、外すと「一覧にあるはずのものが無い」ことになるため。
;;;
;;; 注釈にはファイルのディレクトリを出す。同じ名前のファイルを複数開いて
;;; いるときに、名前だけでは選べないのを補う。
;;;

(provide "fuzzy-buffer")

(in-package "editor")

(require "fuzzy-complete")

(export '(fuzzy-switch-to-buffer *fuzzy-buffer-hide-internal*))

(defvar *fuzzy-buffer-hide-internal* t
  "nil でなければ、名前が空白で始まる内部バッファ (\" *Minibuf0*\" など) を
候補に出さない。")

(defun fuzzy-buffer-internal-p (name)
  (and *fuzzy-buffer-hide-internal*
       (plusp (length name))
       (char= (char name 0) #\SPC)))

(defun fuzzy-buffer-names ()
  "切り替え先の候補。直前のバッファが先頭、今のバッファが最後。"
  (let* ((current (selected-buffer))
	 (prev (ignore-errors (other-buffer)))
	 (rest nil))
    (dolist (b (buffer-list))
      (let ((name (buffer-name b)))
	(unless (or (fuzzy-buffer-internal-p name)
		    (eq b current)
		    (eq b prev))
	  (push name rest))))
    (append (and prev (not (eq prev current)) (list (buffer-name prev)))
	    (nreverse rest)
	    (list (buffer-name current)))))

(defun fuzzy-buffer-annotation (name)
  "候補の右端に出す注釈。ファイルを持つバッファならそのディレクトリ。"
  (let ((b (find-buffer name)))
    (and b
	 (let ((file (get-buffer-file-name b)))
	   (and file (directory-namestring file))))))

(defun fuzzy-switch-to-buffer ()
  "バッファをファジー絞り込みで選んで切り替える。

一覧に無い名前を打って RET すると、その名前のバッファを作る (素の C-x b と
同じ)。空白で区切って複数のキーワードを打つと順不同で絞られる。"
  (interactive)
  (let* ((names (fuzzy-buffer-names))
	 (name (fuzzy-completing-read "Switch to buffer: " names
				      :allow-new t
				      :annotate #'fuzzy-buffer-annotation)))
    (if (null name)
	(progn (message "Quit") nil)
      (switch-to-buffer name))))

(define-key ctl-x-map #\b 'fuzzy-switch-to-buffer)
(define-key *leader-buffer-map* #\b 'fuzzy-switch-to-buffer)
