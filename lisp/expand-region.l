;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 選択範囲を意味のある単位で段階的に広げる / 狭める
;;; (Emacs の expand-region 相当)。
;;;
;;;   単語 → シンボル → 引用符の中 → 引用符ごと → 括弧の中 → 括弧ごと
;;;   → (外側の括弧へ、以下同様) → 行 → 関数定義 → バッファ全体
;;;
;;; 実装は「候補を全部作って、今の範囲を真に含む中で最も小さいものを選ぶ」
;;; だけにしてある。段階を手続きとして順番に並べるより、
;;;
;;;   * 候補の順番と実際の広がり方が食い違わない (小さい順に必ず進む)
;;;   * モードによって成立しない段階 (Lisp でない所の関数定義など) が
;;;     単に候補から抜けるだけで、飛ばす処理を書かなくてよい
;;;
;;; という点で扱いやすい。候補の並び順は同じ大きさになったときの優先順位
;;; としてだけ効く。
;;;

(provide "expand-region")

(in-package "editor")

(export '(expand-region contract-region
	  *expand-region-max-list-depth*))

(defvar *expand-region-max-list-depth* 20
  "括弧の候補を何段まで外へ辿るか。")

(defvar *expand-region-history* nil
  "expand-region で通ってきた範囲のスタック。contract-region が戻る先。")

(defvar *expand-region-origin* nil
  "連続した expand-region の起点となった位置。候補はここを基準に作る。")

(defvar *expand-region-last* nil
  "expand-region が最後に設定した (バッファ 開始 . 終了)。
これと今の範囲が違っていたら、途中で別の操作が入ったものとして
履歴を捨てて数え直す。")

(defun expand-region-current ()
  "今の範囲を (開始 . 終了) で返す。選択が無ければ点の位置だけ。"
  (if (get-selection-type)
      (let ((m (selection-mark))
	    (p (selection-point)))
	(cons (min m p) (max m p)))
    (cons (point) (point))))

(defun expand-region-set (region)
  (goto-char (car region))
  (if (= (car region) (cdr region))
      (stop-selection)
    (progn
      (start-selection 2 nil)
      (goto-char (cdr region))))
  (setq *expand-region-last*
	(list (selected-buffer) (car region) (cdr region)))
  t)

(defun expand-region-chain-broken-p (current)
  "前回 expand-region が置いた範囲から動いていたら non-nil。"
  (not (and *expand-region-last*
	    (eq (first *expand-region-last*) (selected-buffer))
	    (= (second *expand-region-last*) (car current))
	    (= (third *expand-region-last*) (cdr current)))))

;;;
;;; 候補
;;;

(defun expand-region-syntax-bounds (origin spec)
  "ORIGIN を含む「SPEC の文字が続く範囲」を (開始 . 終了) で返す。
広がらなければ nil。SPEC は skip-syntax-spec-forward の構文指定
(\"w\" で単語、\"w_\" でシンボル)。"
  (save-excursion
    (goto-char origin)
    (skip-syntax-spec-backward spec)
    (let ((from (point)))
      (goto-char origin)
      (skip-syntax-spec-forward spec)
      (let ((to (point)))
	(and (< from to) (cons from to))))))

(defun expand-region-string-bounds (origin)
  "ORIGIN が文字列の中なら、引用符の中と引用符ごとの 2 つを返す。

parse-point-syntax は開始引用符では nil、中身と閉じ引用符では :string を
返す (実測)。つまり :string が続く範囲は「開始引用符の直後から閉じ引用符
まで」なので、両端を 1 文字ずつずらして外側を得る。"
  (when (eq (parse-point-syntax origin) :string)
    (let ((from origin)
	  (to origin))
      (while (and (> from (point-min))
		  (eq (parse-point-syntax (1- from)) :string))
	(decf from))
      (while (and (< to (point-max))
		  (eq (parse-point-syntax to) :string))
	(incf to))
      (list (cons from (1- to))
	    (cons (1- from) to)))))

(defun expand-region-list-origin (origin)
  "括弧を辿る起点。ORIGIN が文字列の中だと backward-up-list が失敗する
(xyzzy の S 式スキャナは文字列の中から外へ出られない) ので、その場合は
開始引用符の位置まで戻す。そこは既に文字列の外なので普通に辿れる。"
  (let ((bounds (expand-region-string-bounds origin)))
    (if bounds
	(car (second bounds))
      origin)))

(defun expand-region-list-bounds (origin0)
  "ORIGIN0 を囲む括弧を内側から外側へ辿り、括弧の中と括弧ごとの範囲を
小さい順に並べて返す。"
  (let ((result nil)
	(origin (expand-region-list-origin origin0)))
    (dotimes (i *expand-region-max-list-depth*)
      (let ((found
	     (save-excursion
	       (goto-char origin)
	       (when (backward-up-list (1+ i) t)
		 (let ((open (point)))
		   (when (forward-sexp 1 t)
		     (cons open (point))))))))
	(if (null found)
	    (return)
	  (progn
	    ;; 内側 (括弧を含まない) が先。同じ大きさになることはないので
	    ;; 順序は優先順位ではなく読みやすさのため。
	    (push (cons (1+ (car found)) (1- (cdr found))) result)
	    (push found result)))))
    (nreverse result)))

(defun expand-region-line-bounds (origin)
  (save-excursion
    (goto-char origin)
    (goto-bol)
    (let ((from (point)))
      (goto-eol)
      (cons from (point)))))

(defun expand-region-defun-bounds (origin)
  (save-excursion
    (goto-char origin)
    (when (beginning-of-defun)
      (let ((from (point)))
	(goto-char origin)
	(when (end-of-defun)
	  (cons from (point)))))))

(defun expand-region-candidates (origin)
  "ORIGIN を基準にした候補を、優先したい順に並べて返す。"
  (let ((cands nil))
    (flet ((add (c) (when c (push c cands))))
      (add (expand-region-syntax-bounds origin "w"))
      (add (expand-region-syntax-bounds origin "w_"))
      (dolist (c (expand-region-string-bounds origin)) (add c))
      (dolist (c (expand-region-list-bounds origin)) (add c))
      (add (expand-region-line-bounds origin))
      (add (expand-region-defun-bounds origin))
      (add (cons (point-min) (point-max))))
    (nreverse cands)))

(defun expand-region-next (current origin)
  "CURRENT を真に含む候補のうち最も小さいものを返す。無ければ nil。"
  (let ((from (car current))
	(to (cdr current))
	(best nil))
    (dolist (c (expand-region-candidates origin))
      (when (and (<= (car c) from)
		 (>= (cdr c) to)
		 (or (< (car c) from) (> (cdr c) to))
		 (or (null best)
		     (< (- (cdr c) (car c)) (- (cdr best) (car best)))))
	(setq best c)))
    best))

;;;
;;; コマンド
;;;

(defun expand-region ()
  "選択範囲を 1 段階広げる。選択が無ければ点の位置から始める。"
  (interactive)
  (let ((current (expand-region-current)))
    (when (expand-region-chain-broken-p current)
      (setq *expand-region-history* nil)
      (setq *expand-region-origin* (car current)))
    (let ((next (expand-region-next current (or *expand-region-origin*
						(car current)))))
      (cond (next
	     (push current *expand-region-history*)
	     (expand-region-set next))
	    (t
	     (ding)
	     nil)))))

(defun contract-region ()
  "expand-region で広げた分を 1 段階戻す。"
  (interactive)
  (let ((current (expand-region-current)))
    (if (expand-region-chain-broken-p current)
	(progn (ding) nil)
      (let ((prev (pop *expand-region-history*)))
	(if prev
	    (expand-region-set prev)
	  (progn (ding) nil))))))

(global-set-key #\C-= 'expand-region)
(global-set-key #\M-= 'contract-region)
