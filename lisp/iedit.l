;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; バッファ内の同じシンボルを一度に書き換える (Emacs の iedit の軽い版)。
;;;
;;;   Leader c r   カーソル位置のシンボル (または選択範囲) を全部まとめて直す
;;;
;;; query-replace との違いは **確認しないこと** である。変数名を直したいだけの
;;; ときに y/n を 20 回押すのが本題ではない。全部の箇所に色を付けてから、
;;; 打った文字をその場で全部へ反映する。
;;;
;;; **打鍵ごとにキーを自分で読む形にした (モーダル)。** xyzzy の
;;; *self-insert-hook* は関数 1 つしか持てず、既に自動ペア挿入 (autopair.l) が
;;; 入っている。そこへ割り込む形にすると 2 つの機能が互いの返り値に依存して
;;; しまう。キーを自分で読むなら、どのキーを受けてどのキーで終わるかが
;;; 1 箇所に書けて、途中で他のコマンドが走らないことも保証できる。
;;; 代わりに、名前の途中へカーソルを移して直すことはできない (末尾への追加と
;;; Backspace だけ)。変数名の付け替えではそれで足りる。
;;;
;;; **位置はマーカーではなく「置換の差分から計算」する。** 置換はどの箇所でも
;;; 同じ長さの入れ替えなので、k 番目の箇所は (差分 x k) だけ後ろへずれる。
;;; マーカーを使うと「挿入位置にあるマーカーが動くかどうか」に依存してしまう。
;;;
;;; **書き込む前に、その箇所が本当に想定の文字列かを確かめる。** 違っていたら
;;; 何も書かずに諦める。計算がずれているということなので、そのまま書くと
;;; ユーザのバッファを壊す (move-text.l で同じ判断をしている)。
;;;

(provide "iedit")

(in-package "editor")

(require "select")

(export '(iedit
	  *iedit-case-fold*
	  *iedit-tag*
	  iedit-occurrences
	  iedit-shifted-positions
	  iedit-replace-all
	  iedit-target-at-point))

(defvar *iedit-case-fold* nil
  "non-nil なら大文字小文字を区別せずに探す。既定は区別する
(識別子の付け替えに使うので、Foo と foo を混ぜるとまずい)。")

(defvar *iedit-tag* 'iedit
  "色を付けるときの text-attribute のタグ。")

(defvar *iedit-attribute-args*
  '(:underline t :bold t)
  "色の付け方。set-text-attribute のキーワード引数をそのまま並べる。")

;;; ---------------------------------------------------------------- 探す

(defun iedit-target-at-point ()
  "カーソル位置のシンボル、または選択範囲の文字列を (文字列 開始 終了) で返す。
取れなければ nil。"
  (if (pre-selection-p)
      ;; 選択範囲があればそれを対象にする。get-selection-start-end は
      ;; 選択を解除して (開始 終了) を返すので、順序は自分で揃える。
      (multiple-value-bind (a b) (get-selection-start-end)
	(when (and a b (/= a b))
	  (let ((from (min a b))
		(to (max a b)))
	    (list (buffer-substring from to) from to))))
    (let ((bounds (save-excursion
		    (let ((origin (point)))
		      (goto-char origin)
		      (skip-syntax-spec-backward "w_")
		      (let ((from (point)))
			(goto-char origin)
			(skip-syntax-spec-forward "w_")
			(let ((to (point)))
			  (and (< from to) (cons from to))))))))
      (when bounds
	(list (buffer-substring (car bounds) (cdr bounds))
	      (car bounds) (cdr bounds))))))

(defun iedit-occurrences (target &optional (whole-symbol t))
  "TARGET が現れる位置を昇順のリストで返す。

WHOLE-SYMBOL が non-nil なら、シンボルの途中に埋まっているものは拾わない
(`foo` を直すときに `foobar` を巻き込まない)。"
  (let ((positions nil))
    (save-excursion
      (goto-char (point-min))
      (while (scan-buffer target
			  :tail nil
			  :case-fold *iedit-case-fold*
			  :left-bound (and whole-symbol :symbol)
			  :right-bound (and whole-symbol :symbol))
	(push (match-beginning 0) positions)
	(goto-char (1+ (match-beginning 0)))))
    (nreverse positions)))

;;; ---------------------------------------------------------------- 置き換える

(defun iedit-shifted-positions (positions oldlen newlen)
  "POSITIONS を順に置き換えていったときの、実際に書く位置を返す。

置換はどこでも同じ長さの入れ替えなので、k 番目 (0 起点) の箇所は
(newlen - oldlen) * k だけ後ろへずれる。"
  (let ((delta (- newlen oldlen))
	(i 0)
	(out nil))
    (dolist (p positions)
      (push (+ p (* i delta)) out)
      (incf i))
    (nreverse out)))

(defun iedit-verify (positions oldtext)
  "POSITIONS のそれぞれが OLDTEXT で始まっているか。1 つでも違えば nil。"
  (let ((len (length oldtext))
	(max (point-max)))
    (dolist (p positions t)
      (when (or (< p (point-min)) (> (+ p len) max))
	(return nil))
      (unless (if *iedit-case-fold*
		  (string-equal oldtext (buffer-substring p (+ p len)))
		(string= oldtext (buffer-substring p (+ p len))))
	(return nil)))))

(defun iedit-replace-all (positions oldtext newtext)
  "POSITIONS の OLDTEXT を NEWTEXT に置き換え、置き換え後の位置を返す。

**書く前に全部の箇所を確かめる。** 想定と違っていたら何も書かずに nil を
返す。位置の計算がずれているということなので、そのまま書くとバッファが壊れる。"
  (let* ((oldlen (length oldtext))
	 (newlen (length newtext))
	 (shifted (iedit-shifted-positions positions oldlen newlen)))
    (when (iedit-verify positions oldtext)
      (let ((i 0))
	(dolist (p positions)
	  (let ((q (+ p (* i (- newlen oldlen)))))
	    (goto-char q)
	    (delete-char oldlen)
	    (insert newtext))
	  (incf i)))
      shifted)))

;;; ---------------------------------------------------------------- 見せる

(defun iedit-highlight (positions len)
  "POSITIONS の箇所に色を付ける。"
  (delete-text-attributes *iedit-tag*)
  (dolist (p positions)
    (apply #'set-text-attribute p (+ p len) *iedit-tag* *iedit-attribute-args*)))

(defun iedit-unhighlight ()
  (delete-text-attributes *iedit-tag*))

(defun iedit-prompt (text n)
  (format nil "iedit: ~A   (~D places)   RET:done  C-g:cancel  BS:erase" text n))

;;; ---------------------------------------------------------------- 本体

(defun iedit ()
  "カーソル位置のシンボル (または選択範囲) と同じものを、バッファ全体で
まとめて書き換える。

打った文字はその場で全部の箇所へ入る。`RET` で確定、`C-g` で元に戻して中止。
`BS` で 1 文字消す。**名前の途中へカーソルを移すことはできない**
(末尾への追加と Backspace だけ)。"
  (interactive)
  (let ((target (iedit-target-at-point)))
    (unless target
      (message "iedit: カーソル位置にシンボルがありません")
      (return-from iedit nil))
    (let* ((original (first target))
	   (positions (iedit-occurrences original))
	   (n (length positions)))
      (when (zerop n)
	(message "iedit: ~A は見つかりません" original)
	(return-from iedit nil))
      (stop-selection)
      (unwind-protect
	  (iedit-loop original positions)
	(iedit-unhighlight)
	(refresh-screen)))))

(defun iedit-loop (original positions)
  "ORIGINAL を POSITIONS で置き換えながらキーを読む。確定した文字列を返す。"
  (let ((current original)
	(current-positions positions))
    (iedit-highlight current-positions (length current))
    (loop
      (message "~A" (iedit-prompt current (length current-positions)))
      (let ((ch (read-char *keyboard*)))
	(cond
	 ((char= ch #\C-g)
	  ;; 元に戻す。1 回で全部戻すので、undo を何度も押すより確実。
	  (unless (string= current original)
	    (unless (iedit-replace-all current-positions current original)
	      (message "iedit: 途中で中身が変わったので戻せませんでした")))
	  (return current))
	 ((or (char= ch #\RET) (char= ch #\ESC))
	  (message "iedit: ~D places -> ~A" (length current-positions) current)
	  (return current))
	 ((or (char= ch #\C-h) (char= ch #\DEL))
	  ;; **最後の 1 文字は消させない。** 空文字列にすると「どこを直して
	  ;; いるか」が消え、置換の対象も決められなくなる。
	  (if (<= (length current) 1)
	      (ding)
	    (let* ((new (subseq current 0 (1- (length current))))
		   (moved (iedit-replace-all current-positions current new)))
	      (if moved
		  (progn
		    (setq current new)
		    (setq current-positions moved)
		    (iedit-highlight current-positions (length current))
		    (iedit-goto-first current-positions (length current)))
		(progn
		  (message "iedit: 中身が想定と違うので中止しました")
		  (return current))))))
	 ((and (graphic-char-p ch) (not (char= ch #\SPC)))
	  (let* ((new (concat current (string ch)))
		 (moved (iedit-replace-all current-positions current new)))
	    (if moved
		(progn
		  (setq current new)
		  (setq current-positions moved)
		  (iedit-highlight current-positions (length current))
		  (iedit-goto-first current-positions (length current)))
	      (progn
		(message "iedit: 中身が想定と違うので中止しました")
		(return current)))))
	 (t
	  ;; 知らないキーは無視する。ここで抜けると打ち間違いで中途半端な
	  ;; 名前が残るので、抜けるのは RET / ESC / C-g だけにしてある。
	  (ding)))))))

(defun iedit-goto-first (positions len)
  "最初の箇所の末尾へ点を置く (どこを直しているか見えるように)。"
  (when positions
    (goto-char (min (point-max) (+ (car positions) len)))
    (refresh-screen)))
