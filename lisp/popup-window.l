;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 「キーを 1 文字ずつ読みながら一覧を見せる」ための一時ウィンドウ。
;;;
;;; ステータス行 (message / minibuffer-prompt) を使わないのが要点である。
;;; message を書いた直後に read-char で待つと、ステータス行が描かれないまま
;;; 待ちに入るフロントエンドがある (端末側で確認済み、issue #66)。プロンプトが
;;; 見えないと、Leader メニューも絞り込みも「反応が無い」ように見える。
;;;
;;; 一時バッファを分割ウィンドウに出して、打鍵のたびに中身を書き換える形なら
;;; 通常のバッファ描画の経路を通るので、その問題を踏まない。ついでに 1 行に
;;; 収める必要が無くなるので、候補を段組みや縦並びで読みやすく出せる。
;;;
;;; 呼び出し側は with-popup-window で囲む。ウィンドウ構成は
;;; save-window-excursion が戻し、バッファはこちらで消す。
;;;

(provide "popup-window")

(in-package "editor")

(export '(*popup-window-max-lines*
	  with-popup-window
	  popup-window-available-p
	  popup-window-draw
	  popup-window-body-lines
	  popup-window-columns))

(defvar *popup-window-max-lines* 12
  "一時ウィンドウに使う行数の上限。画面が狭いときはそれに合わせて縮む。")

(defun popup-window-available-p ()
  "一時ウィンドウを出せる状況か。ミニバッファの中と、分割する余地が無い
画面では出さない (呼び出し側はステータス行へ落とす)。"
  (and (not (minibuffer-window-p (selected-window)))
       (ignore-errors (>= (window-lines) 6))))

(defun popup-window-open (name label)
  "NAME のバッファを分割ウィンドウに出して選択する。
呼び出し元は save-window-excursion の中で呼ぶこと。"
  (let ((buf (get-buffer-create name)))
    ;; pop-to-buffer は既にそのバッファを出しているウィンドウがあれば
    ;; それを使い、無ければ分割する。
    (pop-to-buffer buf t)
    (setq mode-name label)
    (setq need-not-save t)
    (setq auto-save nil)
    (setq kept-undo-information nil)
    buf))

(defun popup-window-close (name)
  "一時バッファを消す。ウィンドウ構成は save-window-excursion が戻す。"
  (let ((buf (find-buffer name)))
    (when buf
      (ignore-errors (delete-buffer buf))))
  t)

(defmacro with-popup-window ((name &optional (label "Popup")) &body body)
  "NAME の一時ウィンドウを開いて BODY を実行し、後始末する。"
  `(save-window-excursion
     (unwind-protect
	 (progn
	   (popup-window-open ,name ,label)
	   ,@body)
       (popup-window-close ,name))))

(setf (get 'with-popup-window 'lisp-indent-hook) 1)

(defun popup-window-body-lines (&optional (reserve 0))
  "一時ウィンドウの中身に使える行数。RESERVE は見出しなどに取っておく分。"
  (max 1 (min (- *popup-window-max-lines* reserve)
	      (max 1 (- (or (ignore-errors (window-lines)) 12) 1 reserve)))))

(defun popup-window-draw (name lines &optional (cursor-row 0))
  "NAME のバッファの中身を LINES (文字列のリスト) で置き換え、
CURSOR-ROW 行目 (0 起点) に点を置いて画面を更新する。"
  (let ((buf (find-buffer name)))
    (when buf
      (save-excursion
	(set-buffer buf)
	(let ((buffer-read-only nil))
	  (erase-buffer buf)
	  (dolist (l lines)
	    (insert l)
	    (insert "\n"))))
      ;; 点はウィンドウ側で動かす: 端末ではカーソルの位置も手がかりになる。
      (goto-line (1+ cursor-row))
      (goto-bol)
      (refresh-screen)
      t)))

(defun popup-window-columns (items width)
  "ITEMS (文字列のリスト) を幅 WIDTH に収まる段組みにして、行のリストで返す。

縦に読んで順番になるよう列優先で詰める。横優先だと、項目が増えたときに
同じものが毎回違う列に来て目が慣れない。"
  (if (null items)
      nil
    (let* ((n (length items))
	   (w (+ 2 (reduce #'max (mapcar #'length items))))
	   (ncols (max 1 (truncate (max width w) w)))
	   (nrows (ceiling n ncols))
	   (vec (coerce items 'vector))
	   (rows nil))
      (dotimes (r nrows)
	(let ((out (make-string-output-stream)))
	  (dotimes (c ncols)
	    (let ((i (+ r (* c nrows))))
	      (when (< i n)
		(let ((s (aref vec i)))
		  (princ s out)
		  ;; 右にまだ列があるときだけ埋める (行末に空白を残さない)。
		  (when (< (+ r (* (1+ c) nrows)) n)
		    (princ (make-sequence 'string (- w (length s))
					  :initial-element #\SPC)
			   out))))))
	  (push (string-right-trim " " (get-output-stream-string out)) rows)))
      (nreverse rows))))
