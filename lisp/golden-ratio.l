;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 選択中のウィンドウを自動的に黄金比まで広げる (Emacs の golden-ratio 相当)。
;;;
;;; 分割して作業していると、見ている側が狭くて読みにくい。`C-x o` で移った先が
;;; 毎回広がるようにして、手で `C-x ^` を叩かなくて済むようにする。
;;;
;;; **既定は無効。** 打鍵ごとにレイアウトが動くのは好みが分かれるうえ、
;;; 「自分で調整した分割を勝手に戻される」形になるので、`M-x
;;; toggle-golden-ratio` (`Leader t g`) で入れる形にした。セッション復元
;;; (#78) と同じ判断。
;;;
;;; 実装は `enlarge-window` に任せる。**幅と高さの両方を試して、変えられ
;;; なかった方は黙って諦める。** 横に並んでいるウィンドウの高さは画面の高さと
;;; 同じで変えようがなく、縦に積んである方の幅も同じなので、「どちらの向きに
;;; 分割されているか」を自分で判定するより、両方試して失敗を捨てる方が短い
;;; (`enlarge-window` は変えられないとエラーを上げる)。

(provide "golden-ratio")

(in-package "editor")

(export '(toggle-golden-ratio golden-ratio-adjust golden-ratio-target
	  *golden-ratio-mode* *golden-ratio*
	  *golden-ratio-exclude-buffer-names*))

(defvar *golden-ratio-mode* nil
  "nil でなければ、選択中のウィンドウを黄金比まで自動で広げる。")

(defvar *golden-ratio* 1.618
  "黄金比。画面の大きさをこれで割った値を目標にする。")

(defvar *golden-ratio-exclude-buffer-names*
  '("*Candidates*" "*Completion*" "*Apropos*")
  "選択中のバッファがこの名前なら何もしない。

一時的に出る候補一覧などは、出した側が自分で大きさを決めている。そこへ
割り込むと、出た瞬間に黄金比へ引き伸ばして候補が読めなくなる。")

(defun golden-ratio-target (total)
  "画面の大きさ TOTAL に対する、選択中のウィンドウの目標の大きさ。"
  (max 1 (round total *golden-ratio*)))

(defun golden-ratio-excluded-p ()
  (let ((name (buffer-name (window-buffer (selected-window)))))
    (and (member name *golden-ratio-exclude-buffer-names* :test #'string=) t)))

(defun golden-ratio-grow (goal now side)
  "選択中のウィンドウを GOAL の大きさへ近づける。SIDE が non-nil なら幅。

変えられない向き (横並びの高さなど) では `enlarge-window' がエラーを上げる。
それは「この向きには分割されていない」という意味なので捨てる。"
  (unless (= goal now)
    (ignore-errors (enlarge-window (- goal now) side))))

(defun golden-ratio-adjust ()
  "選択中のウィンドウを黄金比まで広げる。`*post-command-hook*' から呼ばれる。"
  (when (and *golden-ratio-mode*
	     (> (count-windows) 1)
	     (not (minibuffer-window-p (selected-window)))
	     (not (golden-ratio-excluded-p)))
    (ignore-errors
      (golden-ratio-grow (golden-ratio-target (screen-height))
			 (window-height) nil))
    (ignore-errors
      (golden-ratio-grow (golden-ratio-target (screen-width))
			 (window-width) t))))

(defun toggle-golden-ratio (&optional (arg nil sv))
  "選択中のウィンドウを自動的に黄金比まで広げるかどうかを切り替える。"
  (interactive)
  (setq *golden-ratio-mode*
	(if sv (and arg t) (not *golden-ratio-mode*)))
  (when *golden-ratio-mode*
    (golden-ratio-adjust))
  (message "黄金比の自動調整: ~:[off~;on~]" *golden-ratio-mode*)
  *golden-ratio-mode*)

(add-hook '*post-command-hook* 'golden-ratio-adjust)
