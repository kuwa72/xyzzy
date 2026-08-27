;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; ウィンドウ分割の状態を戻す / やり直す (Emacs の winner-mode 相当)。
;;;
;;; 「分割して覗いて、閉じたつもりが元の形に戻らない」を無くすのが目的。
;;; *post-command-hook* でウィンドウ構成の変化を見張り、変わる直前の構成を
;;; 溜めておいて winner-undo で戻す。
;;;
;;; current-window-configuration は不透明な値で比較できないので、変化の
;;; 検出には「ウィンドウごとのバッファ名と大きさ」を並べた署名を使う。
;;; 署名は並べ替えて持つ: そうしないと選択中のウィンドウを移すだけ
;;; (C-x o) でも「構成が変わった」ことになり、Leader w u が「さっきの
;;; ウィンドウへ戻る」だけの操作に化けてしまう。
;;;

(provide "winner")

(in-package "editor")

(export '(winner-undo winner-redo toggle-winner-mode
	  *winner-mode* *winner-ring-max*))

(defvar *winner-mode* t
  "nil でなければウィンドウ構成の変化を記録し、winner-undo で戻せるようにする。")

(defvar *winner-ring-max* 30
  "覚えておくウィンドウ構成の数。")

(defvar *winner-undo-ring* nil
  "戻せるウィンドウ構成 (新しいものが先頭)。")

(defvar *winner-redo-ring* nil
  "winner-undo で戻した分のやり直し先 (新しいものが先頭)。")

(defvar *winner-last-signature* nil)
(defvar *winner-last-configuration* nil)

(defun winner-window-descriptors ()
  "今あるウィンドウを (バッファ名 高さ 幅) のリストで返す。
ミニバッファのウィンドウは数えない。"
  (let ((start (selected-window))
	(descs nil))
    (let ((w start))
      (loop
	(unless (minibuffer-window-p w)
	  (push (list (buffer-name (window-buffer w))
		      (window-height w)
		      (window-width w))
		descs))
	(setq w (next-window w))
	(when (eq w start) (return))))
    descs))

(defun winner-descriptor-lessp (a b)
  (cond ((/= (second a) (second b)) (< (second a) (second b)))
	((/= (third a) (third b)) (< (third a) (third b)))
	(t (string< (first a) (first b)))))

(defun winner-configuration-signature ()
  "ウィンドウ構成を比較できる値にする。並べ替えてあるので、選択中の
ウィンドウを移しただけでは変わらない。"
  (sort (winner-window-descriptors) #'winner-descriptor-lessp))

(defun winner-remember ()
  "今の構成を「直前の構成」として覚え直す。undo/redo の後に呼ぶ。"
  (setq *winner-last-signature* (winner-configuration-signature))
  (setq *winner-last-configuration* (current-window-configuration)))

(defun winner-record ()
  "*post-command-hook* から呼ばれる。構成が変わっていたら、変わる直前の
構成を undo 側へ積む。"
  (when *winner-mode*
    (let ((sig (winner-configuration-signature)))
      (unless (equal sig *winner-last-signature*)
	(when *winner-last-configuration*
	  (push *winner-last-configuration* *winner-undo-ring*)
	  (when (> (length *winner-undo-ring*) *winner-ring-max*)
	    (setq *winner-undo-ring*
		  (subseq *winner-undo-ring* 0 *winner-ring-max*)))
	  ;; 新しい変更が入った時点で、やり直し先は意味を失う。
	  (setq *winner-redo-ring* nil))
	(winner-remember)))))

(defun winner-apply (conf other-ring-symbol)
  "CONF を適用し、今の構成を OTHER-RING-SYMBOL の側へ積む。"
  (push (current-window-configuration) (symbol-value other-ring-symbol))
  (set-window-configuration conf)
  (winner-remember)
  t)

(defun winner-undo ()
  "ウィンドウ分割の状態を 1 つ前へ戻す。"
  (interactive)
  (let ((conf (pop *winner-undo-ring*)))
    (if (null conf)
	(progn
	  (message "これ以上戻せるウィンドウ構成はありません")
	  nil)
      (progn
	(winner-apply conf '*winner-redo-ring*)
	(message "ウィンドウ構成を戻しました (あと ~D 回戻せます)"
		 (length *winner-undo-ring*))
	t))))

(defun winner-redo ()
  "winner-undo で戻した分をやり直す。"
  (interactive)
  (let ((conf (pop *winner-redo-ring*)))
    (if (null conf)
	(progn
	  (message "やり直せるウィンドウ構成はありません")
	  nil)
      (progn
	(winner-apply conf '*winner-undo-ring*)
	(message "ウィンドウ構成をやり直しました (あと ~D 回やり直せます)"
		 (length *winner-redo-ring*))
	t))))

(defun toggle-winner-mode (&optional (arg nil sv))
  "ウィンドウ構成の記録の有効/無効を切り替える。"
  (interactive "p")
  (toggle-mode '*winner-mode* arg sv)
  (message "Winner mode is ~:[disabled~;enabled~]" *winner-mode*))

(add-hook '*post-command-hook* 'winner-record)
