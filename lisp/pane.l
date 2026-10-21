;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "pane")

(in-package "editor")

(export '(pane-show pane-hide pane-toggle pane-window *pane-width*))

(defvar *pane-width* 28
  "サイドペインの既定の幅 (文字数)。")

(defun pane-window (buffer)
  "BUFFER を表示しているウィンドウを返す。表示されていなければ nil。"
  (let ((buf (if (stringp buffer) (find-buffer buffer) buffer)))
    (and buf (get-buffer-window buf))))

(defun pane-leftmost-window ()
  "フレームの左端にあるウィンドウを返す。
x 座標が最小のものを探し、同じ x に複数あれば一番上のものを返す。"
  (let* ((start (selected-window))
         (w start)
         best bx by)
    (loop
      (unless (minibuffer-window-p w)
        (let* ((c (window-coordinate w))
               (x (car c)) (y (cadr c)))
          (when (or (null best) (< x bx) (and (= x bx) (< y by)))
            (setq best w bx x by y))))
      (setq w (next-window w))
      (when (eq w start)
        (return best)))))

(defun pane-show (buffer &key (width *pane-width*))
  "BUFFER をフレーム左端のペインウィンドウに表示し、そのウィンドウを返す。
既に表示されていれば既存のウィンドウをそのまま返す。
ペインが選択状態になる。"
  (let* ((buf (if (stringp buffer) (get-buffer-create buffer) buffer))
         (win (pane-window buf)))
    (if win
        (progn (set-window win) win)
      (let ((target (pane-leftmost-window)))
        (set-window target)
        ;; 正のサイズの左右分割では選択が左側 (縮んだ target) に残るので、
        ;; そこへペインのバッファを表示すると左端にドックできる。
        (split-window width t)
        (set-buffer buf)
        (let ((pane (selected-window)))
          ;; ncurses 版の split-window はサイズ指定を無視して常に二等分
          ;; するので、実際にできた幅を見て目的の幅に合わせる。
          ;; 環境によっては縮められないこともあるので失敗は無視する。
          (ignore-errors
            (let ((delta (- (window-width pane) width)))
              (when (plusp delta)
                (shrink-window-horizontally delta))))
          (set-local-window-flags pane *window-flag-line-number* nil)
          (set-local-window-flags pane *window-flag-fold-mark* nil)
          (set-local-window-flags pane *window-flag-fold-line* nil)
          pane)))))

(defun pane-hide (buffer)
  "BUFFER を表示しているペインウィンドウを閉じる。閉じたら t。
ペインが唯一のウィンドウなら閉じずに nil を返す。"
  (let ((w (pane-window buffer)))
    (when (and w (> (count-windows) 1))
      (unless (eq w (selected-window))
        (set-window w))
      (delete-window)
      t)))

(defun pane-toggle (buffer &key (width *pane-width*))
  "BUFFER のペインが表示されていれば閉じ、なければフレーム左端に開く。
開いたウィンドウ、閉じたときは nil を返す。"
  (if (pane-window buffer)
      (progn (pane-hide buffer) nil)
    (pane-show buffer :width width)))
