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
	  popup-window-open
	  popup-window-close
	  popup-window-draw
	  popup-window-body-lines
	  popup-window-fit
	  popup-window-columns
	  *popup-window-min-column-width*))

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
  "一時ウィンドウを閉じてバッファを消す。

**ウィンドウを明示的に消すのが要点である。** ウィンドウ構成の復元
(save-window-excursion / set-window-configuration) は端末フロントエンド
(ncurses) では何もしない: WindowConfiguration が空の実装で、
current-window-configuration は nil を返す (issue #82)。構成の復元に任せると、
端末では一時ウィンドウが画面に残ったままになる (実際に残っていた)。"
  (let ((buf (find-buffer name)))
    (when buf
      (let ((obuf (selected-buffer))
	    (w (get-buffer-window buf)))
	(when w
	  (ignore-errors
	    (set-window w)
	    (delete-window))
	  (unless (eq obuf buf)
	    (let ((ow (get-buffer-window obuf)))
	      (when ow (ignore-errors (set-window ow))))))
	(ignore-errors (delete-buffer buf)))))
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

(defvar *popup-window-min-column-width* 16
  "段組みを詰めるときの 1 列の下限。これより狭くするとコマンド名が読めない。")

(defun popup-window-fit (string width)
  "STRING を幅 WIDTH に収める。長ければ後ろを落とす。"
  (if (or (null width) (<= (length string) width))
      string
    (subseq string 0 (max 0 width))))

(defun popup-window-columns (items width &optional max-rows)
  "ITEMS (文字列のリスト) を幅 WIDTH に収まる段組みにして、行のリストで返す。

縦に読んで順番になるよう列優先で詰める。横優先だと、項目が増えたときに
同じものが毎回違う列に来て目が慣れない。

MAX-ROWS を渡すと、その行数に収まるよう **列を増やして** 詰める。増やしても
入り切らない場合は入る分だけ出し、最後に「... +N」と残りの個数を書く。
**黙って切ると「これで全部だ」と読めてしまう。** 一時ウィンドウは画面の
半分しか無いので、C-x のように 60 個以上あるキーマップでは実際に起きる。"
  (if (null items)
      nil
    (let* ((n (length items))
	   (natural (+ 2 (reduce #'max (mapcar #'length items))))
	   (ncols (max 1 (truncate (max width natural) natural)))
	   (nrows (ceiling n ncols))
	   (dropped 0)
	   (w natural))
      (when (and max-rows (> nrows max-rows))
	;; 列を増やす。1 列の幅が下限を切るところで打ち切る。
	(setq ncols (min (ceiling n max-rows)
			 (max 1 (truncate width *popup-window-min-column-width*))))
	(setq w (max *popup-window-min-column-width* (truncate width ncols)))
	(if (>= (* ncols max-rows) n)
	    (setq nrows (ceiling n ncols))
	  ;; 入り切らない。残りの個数を書く 1 行を空けておく。
	  (progn
	    (setq nrows (max 1 (1- max-rows)))
	    (setq dropped (- n (* ncols nrows))))))
      (let ((cap (- n dropped))
	    (vec (coerce items 'vector))
	    (rows nil))
	(dotimes (r nrows)
	  (let ((out (make-string-output-stream)))
	    (dotimes (c ncols)
	      (let ((i (+ r (* c nrows))))
		(when (< i cap)
		  (let ((s (popup-window-fit (aref vec i) (- w 2))))
		    (princ s out)
		    ;; 右にまだ列があるときだけ埋める (行末に空白を残さない)。
		    (when (< (+ r (* (1+ c) nrows)) cap)
		      (princ (make-sequence 'string (- w (length s))
					    :initial-element #\SPC)
			     out))))))
	    (push (string-right-trim " " (get-output-stream-string out)) rows)))
	(setq rows (nreverse rows))
	(if (plusp dropped)
	    (append rows (list (format nil "... +~D" dropped)))
	  rows)))))
