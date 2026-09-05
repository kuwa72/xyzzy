;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; tree-sitter による色付けの切り替えのテスト。
;;;
;;; **色そのものはテストできない** (描画結果を Lisp から読めない)。ここで
;;; 守るのは「切れること」「切ったら新しく開いたバッファでも有効にならない
;;; こと」である。tree-sitter の色はカラーテーマに従わない (issue #98) ので、
;;; テーマを使う人にはこの逃げ道が必要になる。

(require "ts")

(deftest ts-highlight-is-on-by-default ()
  "既定では有効であること (既定を変えるときはこのテストも直る)"
  ed::*ts-highlight*
  => t)

(deftest toggle-ts-highlight-flips ()
  "引数なしで反転し、引数付きでその値になること"
  (let ((saved ed::*ts-highlight*))
    (unwind-protect
	(progn
	  (setq ed::*ts-highlight* t)
	  (values (ed::toggle-ts-highlight)
		  (ed::toggle-ts-highlight)
		  (ed::toggle-ts-highlight nil)
		  (ed::toggle-ts-highlight t)))
      (setq ed::*ts-highlight* saved)))
  => nil
  => t
  => nil
  => t)

(deftest ts-enable-for-buffer-does-nothing-when-off ()
  "無効なら ts-enable-for-buffer が有効化しないこと。
**ここが効いていないと、切ったつもりでも開いたバッファで色が付く。**"
  (let ((saved ed::*ts-highlight*)
	(buf (create-new-buffer " *ts test*")))
    (unwind-protect
	(save-excursion
	  (set-buffer buf)
	  (setq ed::*ts-highlight* nil)
	  (ed::ts-enable-for-buffer)
	  (let ((off ed::*ts-highlight-active*))
	    (values off)))
      (progn
	(setq ed::*ts-highlight* saved)
	(set-buffer-modified-p nil buf)
	(ignore-errors (delete-buffer buf)))))
  => nil)

(deftest ts-highlight-leader-binding ()
  "Leader t s に割り当てられていること"
  (lookup-keymap ed::*leader-toggle-map* #\s)
  => toggle-ts-highlight)


(deftest ts-repository-language-registrations ()
  "リポジトリで使う言語の文法がモードへ登録されること"
  (dolist (file '("cmake-mode" "python-mode" "json-mode" "yaml-mode"
                  "shell-mode" "javascript-mode"))
    (require file))
  (mapcar (lambda (mode) (not (null (gethash mode ed::*ts-grammar-registry*))))
          '(cmake-mode python-mode json-mode yaml-mode shell-script-mode
            javascript-mode))
  => (t t t t t t))
