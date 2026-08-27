;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/fuzzy-buffer.l のテスト。
;;;
;;; 候補の並び順が本体。C-x b は「さっきの所に戻る」のに一番よく使うので、
;;; 直前のバッファが先頭に来ていないと RET 一発で戻れない。

(require "fuzzy-buffer")

(deftest fuzzy-buffer-internal-p ()
  "名前が空白で始まるバッファを内部扱いすること"
  (values (ed::fuzzy-buffer-internal-p " *Minibuf0*")
	  (ed::fuzzy-buffer-internal-p "*scratch*")
	  (ed::fuzzy-buffer-internal-p "foo.l")
	  (let ((ed::*fuzzy-buffer-hide-internal* nil))
	    (ed::fuzzy-buffer-internal-p " *Minibuf0*")))
  => t
  => nil
  => nil
  => nil)

(deftest fuzzy-buffer-names-hides-internal ()
  "内部バッファが候補に出ないこと"
  (remove-if-not #'(lambda (n) (ed::fuzzy-buffer-internal-p n))
		 (ed::fuzzy-buffer-names))
  => nil)

(deftest fuzzy-buffer-names-puts-current-last ()
  "今のバッファが最後に来ること (選んでも何も起きないだけで済む)"
  (with-temp-buffer
    (let ((names (ed::fuzzy-buffer-names)))
      (string= (car (last names)) (buffer-name (selected-buffer)))))
  => t)

(deftest fuzzy-buffer-names-has-no-duplicates ()
  "同じバッファが 2 度出ないこと (直前のバッファを先頭へ持ち上げる処理で
重複しやすい)"
  (with-temp-buffer
    (let* ((names (ed::fuzzy-buffer-names))
	   (uniq (remove-duplicates names :test #'string=)))
      (= (length names) (length uniq))))
  => t)

(deftest fuzzy-buffer-names-includes-every-visible-buffer ()
  "内部バッファ以外は全部候補に出ること"
  (with-temp-buffer
    (let ((names (ed::fuzzy-buffer-names))
	  (missing nil))
      (dolist (b (buffer-list))
	(let ((n (buffer-name b)))
	  (unless (or (ed::fuzzy-buffer-internal-p n)
		      (member n names :test #'string=))
	    (push n missing))))
      missing))
  => nil)

(deftest fuzzy-buffer-annotation ()
  "ファイルを持つバッファにはディレクトリ、持たないバッファには nil"
  (with-temp-files (file)
    (with-temp-buffer
      (insert "x")
      (write-file file)
      (set-buffer-file-name file)
      (values (and (ed::fuzzy-buffer-annotation (buffer-name (selected-buffer))) t)
	      (ed::fuzzy-buffer-annotation "*scratch*")
	      ;; 無い名前なら nil
	      (ed::fuzzy-buffer-annotation "*no-such-buffer-at-all*"))))
  => t
  => nil
  => nil)

(deftest fuzzy-buffer-keys ()
  "C-x b と Leader b b に割り当てられていること"
  (values (lookup-keymap ed::ctl-x-map #\b)
	  (lookup-keymap ed::*leader-buffer-map* #\b))
  => fuzzy-switch-to-buffer
  => fuzzy-switch-to-buffer)
