;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 行 / 選択範囲をそのまま上下へ移動する (Emacs の move-text 相当)。
;;;
;;; 「この行を 1 行上へ」は kill-line + previous-line + yank でも書けるが、
;;; それだと kill-ring を汚す上に選択範囲が失われる。ここでは行単位の
;;; 2 ブロックを文字列として入れ替えるだけにして、kill-ring には触らず、
;;; 選択範囲は移動後の同じテキストへ張り直す。
;;;
;;; バッファ最終行に改行が無い場合が唯一の面倒なところで、素朴に 2 つの
;;; ブロックを連結すると改行の位置が食い違う。move-text-swap-text が
;;; そこだけを吸収している。
;;;

(provide "move-text")

(in-package "editor")

(export '(move-text-up move-text-down))

(defun move-text-ends-with-newline-p (s)
  (let ((n (length s)))
    (and (plusp n) (char= (char s (1- n)) #\LFD))))

(defun move-text-drop-newline (s)
  (if (move-text-ends-with-newline-p s)
      (subseq s 0 (1- (length s)))
    s))

(defun move-text-line-region ()
  "点、または選択範囲を覆う行単位の範囲を (values FROM TO) で返す。
FROM は先頭行の行頭、TO は最終行の改行の直後 (改行が無ければ point-max)。"
  (let (from to)
    (multiple-value-bind (a b)
	(if (get-selection-type)
	    (let ((m (selection-mark)) (p (selection-point)))
	      (values (min m p) (max m p)))
	  (values (point) (point)))
      (save-excursion
	(goto-char a)
	(goto-bol)
	(setq from (point))
	(goto-char b)
	;; 選択終端がちょうど行頭にあるとき、その行自体は選択されていない。
	;; 行頭までのドラッグで次の行まで巻き込まないようにする。
	(when (and (> b a) (bolp))
	  (forward-char -1))
	(goto-eol)
	(setq to (if (eobp) (point) (1+ (point))))))
    (values from to)))

(defun move-text-swap-text (first second)
  "改行区切りの 2 ブロック FIRST・SECOND を入れ替えた文字列と、その中で
FIRST が始まる位置のオフセットを (values TEXT OFFSET) で返す。

普通はどちらのブロックも末尾に改行を持つので単に連結を逆にするだけだが、
バッファ最終行に改行が無い場合はそのブロックだけが改行なしで終わる。
改行なしのブロックが前へ来るときは改行を足し、後ろへ回るブロックからは
末尾の改行を落とす: そうしないと 2 行が 1 行に潰れる。

FIRST が改行を持たないのは FIRST がバッファ末尾のブロックのときで、
その場合はもう後ろに動かす相手が居ないので呼び出し元が先に弾いている。"
  (if (move-text-ends-with-newline-p second)
      (values (concat second first) (length second))
    (values (concat second "\n" (move-text-drop-newline first))
	    (1+ (length second)))))

(defun move-text-replace (start end text)
  "[START,END) を TEXT で置き換える。長さが違うときは何も書かずに nil を返す。

move-text は必ず「同じ文字を並べ替える」操作なので、置き換えの前後で
バッファの長さが変わることは無い。にもかかわらず変わるなら、この関数より
手前の計算がどこかで狂っている。そのまま書き込むとユーザのバッファが
壊れる (実際に「最下行の直前で M-Down するとテキストが増える」という
報告があり、手元では再現できていない) ので、書かずに諦める。

安全側に倒すのが目的で、これが nil を返すのは常にバグである。"
  (if (/= (length text) (- end start))
      nil
    (progn
      (delete-region start end)
      (goto-char start)
      (insert text)
      t)))

(defun move-text-restore (block-from rel col selection)
  "移動後のブロック先頭 BLOCK-FROM を基準に、点と選択範囲を張り直す。"
  (if selection
      (progn
	(goto-char (+ block-from (second selection)))
	(start-selection (first selection) nil)
	(goto-char (+ block-from (third selection))))
    (progn
      (goto-char (+ block-from rel))
      ;; 桁は覚えた値へ戻す。移動先の行が短ければ goto-column が行内へ
      ;; 収めてくれる。
      (goto-bol)
      (goto-column col)))
  t)

(defun move-text-move (dir)
  "DIR が負なら 1 行上へ、正なら 1 行下へ、行単位のブロックを移動する。
移動できなければ何もせず nil を返す。"
  (multiple-value-bind (from to) (move-text-line-region)
    ;; FROM と TO が同じになるのは「バッファ末尾の改行の後ろ」に点が
    ;; あるときだけ。ここは行ではなく位置なので、動かす中身が無い。
    ;;
    ;; 弾かずに進むと、空の塊と隣の行を入れ替える形になって、末尾の改行が
    ;; 消えたうえに空行が 1 本前に現れる ("aaa\nbbb\n" が "aaa\n\nbbb" に
    ;; なる)。文字数は変わらないが、見た目には行が増えたことになる。
    ;; 上下を繰り返すとその空行が行間を渡り歩く。
    (when (= from to)
      (return-from move-text-move nil))
    (let* ((type (get-selection-type))
	   (selection (and type
			   (list type
				 (- (selection-mark) from)
				 (- (selection-point) from))))
	   (col (current-column))
	   (rel (- (point) from)))
      (cond
       ((minusp dir)
	(when (<= from (point-min))
	  (return-from move-text-move nil))
	(let* ((prev-from (save-excursion
			   (goto-char from)
			   (forward-char -1)
			   (goto-bol)
			   (point)))
	       (block-text (buffer-substring from to))
	       (prev-text (buffer-substring prev-from from))
	       ;; 上へ動かすので (前の行, ブロック) を入れ替える。入れ替え後
	       ;; ブロックは先頭に来るので、開始位置は範囲の先頭そのもの。
	       (text (move-text-swap-text prev-text block-text)))
	  (when (move-text-replace prev-from to text)
	    (move-text-restore prev-from rel col selection))))
       (t
	(when (>= to (point-max))
	  (return-from move-text-move nil))
	(let ((next-to (save-excursion
			(goto-char to)
			(goto-eol)
			(if (eobp) (point) (1+ (point))))))
	  (multiple-value-bind (text offset)
	      (move-text-swap-text (buffer-substring from to)
				   (buffer-substring to next-to))
	    (when (move-text-replace from next-to text)
	      (move-text-restore (+ from offset) rel col selection)))))))))

(defun move-text-up (&optional (n 1))
  "現在行、または選択範囲の行をまとめて N 行上へ移動する。"
  (interactive "*p")
  (dotimes (i (max (or n 1) 1))
    (unless (move-text-move -1)
      (ding)
      (return))))

(defun move-text-down (&optional (n 1))
  "現在行、または選択範囲の行をまとめて N 行下へ移動する。"
  (interactive "*p")
  (dotimes (i (max (or n 1) 1))
    (unless (move-text-move 1)
      (ding)
      (return))))

(global-set-key #\M-Up 'move-text-up)
(global-set-key #\M-Down 'move-text-down)
