;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for lisp/errors.l — build-error-list / first-error / next-error.
;;;
;;; issue #410 の退行テスト。直前の調査で見つかった 3 つの壊れ方を固定する:
;;;   1. `next-error' が「最初のエラー」を visit しない — goto-error が
;;;      visit 前にエントリを *rerror-list* へ移すので、1 件だけなら
;;;      必ず「これ以上エラーはありません」。
;;;   2. エラーリスト未構築のバッファ (grep 出力など) で最初の next-error
;;;      が必ず失敗する — first-error の wrap 経路が build-error-list
;;;      を呼ばない。
;;;   3. build-error-list がポイント位置以降しか走査しない — *compilation*
;;;      を再利用したりジャンプで point が動くと先頭のエラーを取りこぼす。
;;;
;;; ファイルシステムには触らない。ジャンプ先は `<名前>' 形式 (find-buffer
;;; 経路) で作る。

(require "errors")

(use-package "editor")

(defun errors-test-target (name nlines)
  "NAME という名のバッファに NLINES 行入れて返す。"
  (let ((buf (create-new-buffer name)))
    (save-excursion
      (set-buffer buf)
      (erase-buffer buf)
      (dotimes (i nlines)
	(insert (format nil "line ~A of ~A\n" (1+ i) name))))
    buf))

(defun errors-test-compilation (name &rest lines)
  "NAME のバッファに LINES を書き、選択して先頭に置く。
build-error-list はポイントから前方向に走査するので、呼ぶ側が
(point-min) に置くのが作り手側の責任。"
  (let ((buf (get-buffer-create name)))
    (set-buffer buf)
    (setq buffer-read-only nil)
    (erase-buffer buf)
    (dolist (l lines)
      (insert l) (insert "\n"))
    (goto-char (point-min))
    buf))

(defun errors-test-reset ()
  (setq ed::*error-list* nil
	ed::*rerror-list* nil
	ed::*error-buffer* nil
	ed::*last-error* nil))

(defun errors-test-cleanup (&rest bufs)
  (ignore-errors (delete-other-windows))
  (dolist (b bufs)
    (ignore-errors (delete-buffer b)))
  (errors-test-reset))

(defun errors-test-visit ()
  "現在のバッファ名と行番号を返す (ジャンプ先の検証用)。"
  (list (buffer-name (selected-buffer)) (current-line-number)))

;;; ------------------------------------------------------------------
;;; 1. エラー 1 件で next-error が失敗する

(deftest next-error-visits-single-error ()
  "構築済みリストが 1 件だけでも最初の next-error でそこに飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-single" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-single>:3:boom"))
	  (ed::build-error-list)
	  (and (ed::next-error)
	       (equal (errors-test-visit) '("err-single" 3))))
      (errors-test-cleanup target comp)))
  => t)

;;; ------------------------------------------------------------------
;;; 2. 複数エラーで先頭がスキップされる

(deftest next-error-visits-first-then-second ()
  "構築済みリスト [3 7] で next-error が順に 3 行目、7 行目へ飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-multi" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-multi>:3:one"
					      "<err-multi>:7:two"))
	  (ed::build-error-list)
	  (list (progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))))
      (errors-test-cleanup target comp)))
  => (3 7))

;;; ------------------------------------------------------------------
;;; 3. リスト未構築 (grep など) で最初の next-error が失敗する

(deftest next-error-builds-list-when-empty ()
  "リストが無いバッファでの最初の next-error がその場で構築して飛ぶ"
  (errors-test-reset)
  (let ((target (errors-test-target "err-fresh" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*grep-out*"
					      "<err-fresh>:5:hit"))
	  ;; build-error-list を呼ばないまま next-error する
	  (and (ed::next-error)
	       (equal (errors-test-visit)
		      '("err-fresh" 5))))
      (errors-test-cleanup target comp)))
  => t)

;;; ------------------------------------------------------------------
;;; 4. first-error からの連続ジャンプ

(deftest first-error-then-next-error ()
  "first-error が先頭を visit し、続く next-error が 2, 3 件目へ進む"
  (errors-test-reset)
  (let ((target (errors-test-target "err-seq" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-seq>:2:a"
					      "<err-seq>:4:b"
					      "<err-seq>:9:c"))
	  (list (progn (ed::first-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))
		(progn (ed::next-error)
		       (and (eq (selected-buffer) target)
			    (current-line-number)))))
      (errors-test-cleanup target comp)))
  => (2 4 9))

(deftest next-error-at-end-says-no-more ()
  "全部 visit した後の next-error は nil を返す"
  (errors-test-reset)
  (let ((target (errors-test-target "err-end" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (setq comp (errors-test-compilation "*compilation*"
					      "<err-end>:2:only"))
	  (ed::build-error-list)
	  (list (and (ed::next-error) t)   ; 1 件目に行ける
		(and (ed::next-error) t))) ; 次は無い -> nil
      (errors-test-cleanup target comp)))
  => (t nil))

;;; ------------------------------------------------------------------
;;; 5. build-error-list はポイント位置によらずバッファ全体を見る

(deftest build-error-list-scans-from-point-min ()
  "ポイントが末尾にあっても全行を走査する

*compilation* は再利用されるので、前の表示位置が末尾なら
先頭のエラーを取りこぼす。issue #410 の調査中に確認した実害。"
  (errors-test-reset)
  (let ((target (errors-test-target "err-tail" 10))
	(comp nil))
    (unwind-protect
	(progn
	  (let ((buf (get-buffer-create "*compilation*")))
	    (set-buffer buf)
	    (setq buffer-read-only nil)
	    (erase-buffer buf)
	    (insert "<err-tail>:3:one\n<err-tail>:8:two\n")
	    (goto-char (point-max))   ; 前の利用で末尾に残っていた想定
	    (setq comp buf))
	  (ed::build-error-list)
	  (and (ed::next-error)
	       (equal (errors-test-visit)
		      '("err-tail" 3))))
      (errors-test-cleanup target comp)))
  => t)
