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
	  popup-window-window-list
	  popup-window-close
	  popup-window-refresh-frame
	  popup-window-draw
	  popup-window-body-lines
	  popup-window-measured-lines
	  popup-window-measured-columns
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

(defun popup-window-window-list ()
  "今のフレームのウィンドウを並べたリスト (ミニバッファは含まない)。"
  (let ((ws nil)
	(w (selected-window)))
    (loop
      (push w ws)
      (setq w (next-window w))
      (when (eq w (selected-window))
	(return)))
    (nreverse ws)))

(defun popup-window-open (name label)
  "NAME のバッファを一時ウィンドウに出して選択する。
呼び出し元は with-popup-window (または save-window-excursion) の中で呼ぶこと。

**今いるウィンドウを分割する。pop-to-buffer は使わない。**
`pop-to-buffer' は「画面が既に分割されていたら新たに分割せず、別のウィンドウへ
移ってそこに出す」仕様なので、**無関係なウィンドウを奪う。** シェルを出して
いるウィンドウを奪われると、そのウィンドウは描き直されないまま中身だけ
入れ替わり、**候補が出ていないように見えた** (報告あり: 端末を並べた状態で
M-m を打つと、モード行だけ *Which Key* になってシェルの画面が残る)。

既にこのバッファを出しているウィンドウがあれば、それを使う (打鍵ごとに
描き直す間、同じウィンドウを使い続けるため)。"
  (let* ((buf (get-buffer-create name))
	 (shown (get-buffer-window buf)))
    (if shown
	(set-window shown)
      (let ((before (popup-window-window-list)))
	;; 分割できないほど狭い場合は今のウィンドウをそのまま使う
	;; (ウィンドウ構成は呼び出し元が戻す)。
	(when (ignore-errors (split-window) t)
	  ;; split-window は元のウィンドウを選択したままにするので、
	  ;; 増えたウィンドウを差分で見つけて移る (next-window の順序に
	  ;; 依存しない)。
	  (let ((new (car (set-difference (popup-window-window-list) before))))
	    (when new
	      (set-window new))))))
    (set-buffer buf)
    (setq mode-name label)
    (setq need-not-save t)
    (setq auto-save nil)
    (setq kept-undo-information nil)
    ;; **大きさを確定させる。** Win32 では split-window の直後のウィンドウは
    ;; window-lines / window-columns が 1 を返し、実際の大きさになるのは次の
    ;; 描画のときである (フレームのウィンドウ配置は refresh_screen の
    ;; move_all_windows で反映される)。ここで測らずに段組みを組むと「1 行 x
    ;; 1 桁」として計算して、候補が 1 個しか出ない (実際にそうなった)。
    (ignore-errors (refresh-screen))
    buf))

(defun popup-window-close (name)
  "一時バッファを消す。

**ウィンドウは消さない。** ウィンドウ構成の復元 (save-window-excursion /
set-window-configuration) が消す。ここで delete-window していた時期があるが
(端末フロントエンドで構成の復元が効かなかった #82 への回避)、#82 が直った後は
不要になったうえ、**Win32 で一時ウィンドウの文字が画面に残る**原因になった
(M-x shell で実際に残った。下の popup-window-refresh-frame の説明を参照)。"
  (let ((buf (find-buffer name)))
    (when buf
      (ignore-errors (delete-buffer buf))))
  t)

(defun popup-window-refresh-frame ()
  "画面全体を描き直させる。**一時ウィンドウを片付けた後に呼ぶ。**

一時ウィンドウが消えて残りのウィンドウが広がった行は、そのままだと誰も
描き直さない。その後に走るのが「変わった行だけ描く」種類の描画 (非同期の
プロセス出力など) だけだと、**一時ウィンドウの文字が画面に残ったままになる。**
`M-x shell` で実際に残った: 候補一覧が消えた後、shell の出力は最初の 3 行しか
無いので、候補が描かれていた 4 行目以降が誰にも塗り直されなかった。

Win32 では (refresh-screen t) は全ウィンドウに再描画の印を付けるだけで、
実際に描くのは次の描画のタイミングなので安い。"
  (ignore-errors (refresh-screen t))
  t)

(defmacro with-popup-window ((name &optional (label "Popup")) &body body)
  "NAME の一時ウィンドウを開いて BODY を実行し、後始末する。

BODY の値をそのまま返す。**再描画は save-window-excursion がウィンドウ構成を
戻した後で行う** (戻す前に印を付けても、戻す処理でウィンドウの大きさが変わる)。"
  (let ((result (gensym "popup-result-")))
    `(let ((,result
	    (save-window-excursion
	      (unwind-protect
		  (progn
		    (popup-window-open ,name ,label)
		    ,@body)
		(popup-window-close ,name)))))
       (popup-window-refresh-frame)
       ,result)))

(setf (get 'with-popup-window 'lisp-indent-hook) 1)

(defun popup-window-measured-lines ()
  "今のウィンドウの行数。**確定していなければ nil。**

Win32 では作りたてのウィンドウが 1 を返す (上の popup-window-open の説明)。
一時ウィンドウが 1 行や 2 行ということは実際には無いので、そういう値は
「まだ分からない」として扱う。段組みの計算に 1 を渡すと候補が 1 個しか
出なくなるので、黙って小さい値を信じてはいけない。"
  (let ((n (ignore-errors (window-lines))))
    (and (integerp n) (> n 2) n)))

(defun popup-window-measured-columns (&optional (default 80))
  "今のウィンドウの桁数。確定していなければ DEFAULT。"
  (let ((n (ignore-errors (window-columns))))
    (if (and (integerp n) (> n 20)) n default)))

(defun popup-window-body-lines (&optional (reserve 0))
  "一時ウィンドウの中身に使える行数。RESERVE は見出しなどに取っておく分。"
  (max 1 (min (- *popup-window-max-lines* reserve)
	      (max 1 (- (or (popup-window-measured-lines)
			    (1+ *popup-window-max-lines*))
			1 reserve)))))

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
