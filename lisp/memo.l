;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 走り書きの置き場 (Emacs の scratch / org-capture の軽い版)。
;;;
;;;   Leader o s   *scratch* へ跳ぶ (消えていれば作り直す)
;;;   Leader o m   その日のメモを開き、時刻の見出しを付けて末尾へ
;;;   Leader o M   メモの置き場をファイラで開く
;;;
;;; 「思いついたことを書く場所を探す」だけで思考が途切れるのが問題なので、
;;; 1 打鍵で必ず同じ場所に着くことを優先している。日付ごとにファイルを
;;; 分けるのは、1 つの大きなファイルにすると開くのも探すのも重くなるため。
;;;
;;; メモは *保存されるファイル* である。*scratch* は保存されないので、
;;; 残したいものは Leader o m の方へ書く。
;;;

(provide "memo")

(in-package "editor")

(export '(open-scratch open-memo open-memo-directory
	  *memo-directory* *memo-file-name-format* *memo-heading-format*))

(defvar *memo-directory* nil
  "メモを置くディレクトリ。nil なら user-config-path の memo/ を使う。")

(defvar *memo-file-name-format* "%Y-%m-%d.md"
  "メモのファイル名。format-date-string の書式。")

(defvar *memo-heading-format* "## %H:%M"
  "メモに追記するときの見出し。format-date-string の書式。
nil なら見出しを付けない。")

(defun memo-directory ()
  "メモを置くディレクトリ (末尾に / が付いた形)。無ければ作る。"
  (let ((dir (or *memo-directory*
		 (merge-pathnames "memo/" (user-config-path)))))
    (setq dir (namestring dir))
    (unless (char= (char dir (1- (length dir))) #\/)
      (setq dir (concat dir "/")))
    (unless (file-exist-p dir)
      (create-directory dir))
    dir))

(defun memo-file-name (&optional (format *memo-file-name-format*))
  (merge-pathnames (format-date-string format) (memo-directory)))

(defun open-scratch ()
  "*scratch* へ跳ぶ。消えていれば作り直す。"
  (interactive)
  (let ((buf (or (find-buffer "*scratch*")
		 (let ((b (create-new-buffer "*scratch*")))
		   (save-excursion
		     (set-buffer b)
		     (funcall *initial-buffer-mode*)
		     (setq need-not-save t))
		   b))))
    (switch-to-buffer buf)
    t))

(defun open-memo ()
  "その日のメモを開き、末尾に時刻の見出しを付けて追記できる状態にする。

同じ日に何度も呼んだときは見出しを重ねない: 直前が同じ見出しなら
その下に続けて書けるようにするだけ。"
  (interactive)
  (let ((file (memo-file-name)))
    (find-file file)
    (goto-char (point-max))
    (when *memo-heading-format*
      (let ((heading (format-date-string *memo-heading-format*)))
	(unless (memo-heading-present-p heading)
	  ;; 直前の行が空でなければ 1 行空けてから見出しを置く。
	  (unless (or (= (point) (point-min)) (bolp))
	    (insert "\n"))
	  (unless (memo-preceding-line-blank-p)
	    (insert "\n"))
	  (insert heading)
	  (insert "\n"))))
    (goto-char (point-max))
    t))

(defun memo-heading-present-p (heading)
  "HEADING がバッファの末尾側に既にあるか (同じ分に 2 回呼んだとき用)。"
  (save-excursion
    (goto-char (point-max))
    (and (scan-buffer heading :reverse t :no-dup t)
	 t)))

(defun memo-preceding-line-blank-p ()
  (save-excursion
    (and (forward-line -1)
	 (progn (goto-bol)
		(looking-at "^[ \t]*$")))))

(defun open-memo-directory ()
  "メモの置き場をファイラで開く。"
  (interactive)
  (open-filer (memo-directory)))
