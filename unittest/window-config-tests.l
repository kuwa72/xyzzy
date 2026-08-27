;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; ウィンドウ構成の保存と復元 (save-window-excursion /
;;; current-window-configuration / set-window-configuration) のテスト。
;;;
;;; **これは長らく端末フロントエンドでは何もしていなかった** (issue #82:
;;; WindowConfiguration が空の実装で、current-window-configuration は nil)。
;;; 実装を src/core/window-config.cc へ移して両方のフロントエンドで動くように
;;; したので、その振る舞いをここで固定する。
;;;
;;; Lisp スイートは Windows ビルドでしか走らないので、**このテストが通ることは
;;; 端末側が動くことの保証にはならない**。端末側は tools/x pty で確認する。
;;; ここで守るのは「core へ移した実装が Windows 側で退行していないこと」。

(defun window-config-count-windows ()
  (let ((n 0)
	(w (selected-window)))
    (loop
      (incf n)
      (setq w (next-window w))
      (when (eq w (selected-window))
	(return)))
    n))

(deftest window-configuration-is-a-configuration ()
  "current-window-configuration が window-configuration を返すこと
(nil を返していたのが issue #82 だった)"
  (let ((c (current-window-configuration)))
    (values (consp c) (and (consp c) (car c))))
  => t
  => window-configuration)

(deftest window-configuration-round-trip ()
  "分割した後に元の構成へ戻せること。

**数は「開始時との差」で見る。** スイートの中では開始時のウィンドウ数が 1 とは
限らないので、絶対値で書くと他のテストの後始末に依存して落ちる。"
  (let ((before (window-config-count-windows))
	(c (current-window-configuration)))
    (unwind-protect
	(progn
	  (split-window)
	  (let ((split (window-config-count-windows)))
	    (set-window-configuration c)
	    (values (- split before) (- (window-config-count-windows) before))))
      (ignore-errors (set-window-configuration c))))
  => 1
  => 0)

(deftest window-configuration-restores-fewer-windows ()
  "3 枚の状態から 2 枚の構成へ戻せること"
  (let ((before (window-config-count-windows))
	(base (current-window-configuration)))
    (unwind-protect
	(progn
	  (split-window)
	  (let ((c (current-window-configuration)))
	    (split-window)
	    (let ((three (window-config-count-windows)))
	      (set-window-configuration c)
	      (values (- three before)
		      (- (window-config-count-windows) before)))))
      (ignore-errors (set-window-configuration base))))
  => 2
  => 1)

(deftest save-window-excursion-restores-the-layout ()
  "save-window-excursion の中で分割しても外へ持ち出さないこと。
**これが効いていないと、一時ウィンドウを出す機能が画面に残す。**"
  (let ((before (window-config-count-windows)))
    (save-window-excursion
      (split-window)
      (split-window))
    (- (window-config-count-windows) before))
  => 0)

(deftest save-window-excursion-returns-the-body-value ()
  "戻り値を素通しすること"
  (save-window-excursion
    (split-window)
    (+ 1 2))
  => 3)

(deftest window-configuration-restores-the-buffer ()
  "別のバッファを出してから戻すと、元のバッファに戻ること"
  (let ((c (current-window-configuration))
	(name " *window-config test*"))
    (unwind-protect
	(let ((buf (get-buffer-create name)))
	  (set-buffer buf)
	  (let ((switched (buffer-name (selected-buffer))))
	    (set-window-configuration c)
	    (values switched
		    (and (string/= (buffer-name (selected-buffer)) name) t))))
      (progn
	(ignore-errors (set-window-configuration c))
	(let ((buf (find-buffer name)))
	  (when buf
	    (set-buffer-modified-p nil buf)
	    (ignore-errors (delete-buffer buf)))))))
  => " *window-config test*"
  => t)

(deftest set-window-configuration-rejects-junk ()
  "window-configuration でないものを渡したらエラーにすること
(黙って無視されると、戻したつもりで戻っていない状態になる)"
  (values (and (ignore-errors (progn (set-window-configuration '(1 2 3)) t)) t)
	  (and (ignore-errors (progn (set-window-configuration "x") t)) t))
  => nil
  => nil)
