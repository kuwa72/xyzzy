;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 括弧・引用符の自動ペア挿入 (Emacs の electric-pair-mode 相当)。
;;;
;;; 入口は 2 つある。
;;;
;;;   * 文字の挿入 -- lisp/cmds.l の *self-insert-hook* に掛ける。キーマップに
;;;     `(` や `{` を割り当てないのは、c-mode / lisp-mode / json-mode 等が
;;;     それらをローカルキーマップで既に奪っているため (c-electric-insert,
;;;     lisp-electric-close, json-electric-close)。それらもいずれも
;;;     self-insert-command を通るので、フック 1 箇所で全モードに効く。
;;;   * BS での対の削除 -- 同じく lisp/cmds.l の *delete-backward-hook* に
;;;     掛ける。Backspace の届き方がフロントエンドごとに違う (Windows は
;;;     C-h、ncurses は lisp/startup.l が入れる #\DEL) ため、キーではなく
;;;     コマンド 1 箇所に掛けるほうが確実。
;;;
;;; 「余計なことをしない」ほうへ倒してある。すなわち
;;;
;;;   * 単語や記号の直前では対にしない (`foo` の前で `(` を打っても
;;;     `(foo` になるだけで `()foo` にはしない)
;;;   * 文字列・コメントの中では対にしない
;;;   * エスケープ (`\`) の直後では対にしない
;;;   * 引数付き (C-u 3 など)・上書きモード・キーボードマクロ実行中は
;;;     素の挿入に任せる
;;;

(provide "autopair")

(in-package "editor")

(export '(*autopair-mode* *autopair-pairs* *autopair-in-minibuffer*
	  toggle-autopair))

(defvar *autopair-mode* t
  "nil でなければ、開き括弧・引用符の入力時に閉じ側も自動で挿入する。")

(defvar *autopair-in-minibuffer* nil
  "nil なら、ミニバッファの中では自動ペア挿入をしない。ファイル名や検索
文字列を打っているときに勝手に閉じ引用符が付くのは邪魔なので既定は nil。")

(defvar *autopair-pairs*
  '((#\( . #\))
    (#\[ . #\])
    (#\{ . #\})
    (#\" . #\"))
  "自動ペア挿入の対象となる (開き文字 . 閉じ文字) の alist。

`'` と `` ` `` を既定で入れていないのは、この 2 つが Lisp では対ではなく
クォート (前置演算子) であり、xyzzy 自身の設定ファイルが Lisp である以上
対にすると邪魔になる場面のほうが多いため。必要なモードでは
make-local-variable してから push する。")

(defun autopair-close-for (char)
  "CHAR が開き文字なら対応する閉じ文字を、そうでなければ nil を返す。"
  (cdr (assoc char *autopair-pairs* :test #'eql)))

(defun autopair-closer-p (char)
  "CHAR がいずれかの対の閉じ文字なら non-nil。"
  (and (find char *autopair-pairs* :key #'cdr :test #'eql) t))

(defun autopair-following-char ()
  "点の直後の文字。バッファ末尾なら nil。
char-after はバッファ末尾で #\\NUL を返すので、位置で判定している。"
  (and (< (point) (point-max)) (char-after (point))))

(defun autopair-preceding-char ()
  "点の直前の文字。バッファ先頭なら nil。"
  (and (> (point) (point-min)) (char-before (point))))

(defun autopair-escaped-p ()
  "点の直前がエスケープされているか (直前に続くエスケープ文字が奇数個)。"
  (let ((n 0)
	(p (1- (point))))
    (while (and (>= p (point-min))
		(syntax-escape-p (char-after p)))
      (incf n)
      (decf p))
    (oddp n)))

(defun autopair-word-before-p ()
  "点の直前が語・シンボルを構成する文字か。
`don't` の `'` や `foo\"` のように、語の直後の引用符は対にしない。"
  (let ((ch (autopair-preceding-char)))
    (and ch (or (syntax-word-p ch) (syntax-symbol-p ch)))))

(defun autopair-pairable-following-p ()
  "点の直後が「対にしてよい」文字か。行末・空白・閉じ括弧・句読点なら
対にする。語や記号の直前では対にしない (既にあるテキストを括弧で
挟んでしまわないように)。"
  (let ((ch (autopair-following-char)))
    (or (null ch)
	(char= ch #\LFD)
	(syntax-whitespace-p ch)
	(syntax-close-p ch)
	(syntax-close-tag-p ch)
	(syntax-punctuation-p ch))))

(defun autopair-wrap-selection (open close)
  "選択範囲を OPEN と CLOSE で囲み、中身を選択したまま残す。"
  (let* ((m (selection-mark))
	 (p (selection-point))
	 (from (min m p))
	 (to (max m p)))
    (stop-selection)
    ;; 後ろから入れる。先に前へ入れると TO がずれる。
    (save-excursion
      (goto-char to)
      (insert close))
    (save-excursion
      (goto-char from)
      (insert open))
    (goto-char (1+ from))
    (start-selection 2 nil)
    (goto-char (1+ to))
    t))

(defun autopair-self-insert-hook (char arg)
  "*self-insert-hook* の本体。CHAR の挿入を自動ペアとして処理したら
non-nil を返す。処理しなかったときは nil を返して通常の挿入に任せる。"
  (and *autopair-mode*
       (eql arg 1)
       (not overwrite-mode)
       (not *executing-macro*)
       (or *autopair-in-minibuffer*
	   (not (minibuffer-window-p (selected-window))))
       (let ((close (autopair-close-for char)))
	 (cond
	  ;; 選択範囲があれば、置き換えるのではなく囲む。
	  ((and close (get-selection-type))
	   (autopair-wrap-selection char close))
	  ;; 目の前に同じ閉じ文字があるなら、重ねずに乗り越えるだけ。
	  ;; 文字列・コメントの中でも同じにしたいので、下の除外より先に見る。
	  ((and (autopair-closer-p char)
		(eql (autopair-following-char) char))
	   (forward-char 1)
	   t)
	  ((null close) nil)
	  ((autopair-escaped-p) nil)
	  ((member (parse-point-syntax) '(:string :comment)) nil)
	  ;; 開きと閉じが同じ文字 (引用符) は、語の直後では対にしない。
	  ((and (eql close char) (autopair-word-before-p)) nil)
	  ((not (autopair-pairable-following-p)) nil)
	  (t
	   (insert char)
	   (insert close)
	   (forward-char -1)
	   t)))))

(defun autopair-pair-around-point-p ()
  "点の直前が開き文字で、直後がその対の閉じ文字か。"
  (let ((before (autopair-preceding-char)))
    (and before
	 (eql (autopair-close-for before) (autopair-following-char)))))

(defun autopair-delete-backward-hook (n)
  "*delete-backward-hook* の本体。空の対 (`()` の中など) にいるときは
2 文字まとめて消して non-nil を返す。それ以外は nil を返して通常の
1 文字削除に任せる。"
  (and *autopair-mode*
       (eql n 1)
       (not (get-selection-type))
       (autopair-pair-around-point-p)
       (progn
	 (delete-region (1- (point)) (1+ (point)))
	 t)))

(defun toggle-autopair (&optional (arg nil sv))
  "自動ペア挿入の有効/無効を切り替える。"
  (interactive "p")
  (toggle-mode '*autopair-mode* arg sv)
  (message "Auto pair insertion is ~:[disabled~;enabled~]" *autopair-mode*))

(setq *self-insert-hook* 'autopair-self-insert-hook)
(setq *delete-backward-hook* 'autopair-delete-backward-hook)
