;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `pos-not-visible-in-window-p` / `pos-visible-in-window-p`。
;;;
;;; **端末では「常に nil」= 「どこでも見えている」と答えるスタブだった**
;;; (issue #50)。中身は Win32 に依っていない — 表示の先頭 (`w_disp`) と
;;; ウィンドウの高さ (`w_ech.cy`) から行番号を比べるだけで、どちらの
;;; フロントエンドも両方を埋めている。それでも
;;; `src/frontend/win32/Window.cc` に居たので、端末側は書かれていなかった。
;;; `src/core/window-config.cc` へ移した。
;;;
;;; **嘘をつく述語は、呼ぶ側を間違った方に分岐させる。** これを使うのは
;;; `lisp/ispell.l` (見えない位置なら画面を送る) と `lisp/mouse.l`、それに
;;; 公開されている `pos-visible-in-window-p` である。
;;;
;;; 返る値は 3 通り: `-1` = 表示より上、`1` = 表示より下、`nil` = 表示の中。

(defun window-visible-test-call-with-long-buffer (fn)
  "300 行のバッファを選択されているウィンドウに出して FN を呼ぶ。
**一時バッファではだめ**: この述語は選択されているウィンドウの表示範囲を
見るので、ウィンドウに出ていないバッファでは意味が無い。"
  (let ((buf (create-new-buffer " *window-visible-tests*")))
    (unwind-protect
        (progn
          (set-buffer buf)
          (dotimes (i 300)
            (insert (format nil "line ~D~%" i)))
          (funcall fn buf))
      (progn
        (set-buffer-modified-p nil buf)
        (ignore-errors (delete-buffer buf))))))

(deftest pos-not-visible-in-window-p-tells-inside-from-below ()
  "表示の中と、はるか下を見分けること。
**以前はどちらも nil だった** (「どこでも見えている」)。"
  (window-visible-test-call-with-long-buffer
    #'(lambda (buf)
        (goto-char (point-min))
        (list (pos-not-visible-in-window-p (point-min))
              (pos-not-visible-in-window-p (point-max)))))
  => (nil 1))

(deftest pos-visible-in-window-p-agrees ()
  "`pos-visible-in-window-p` (公開されている方) が裏返しになっていること。"
  (window-visible-test-call-with-long-buffer
    #'(lambda (buf)
        (goto-char (point-min))
        (list (and (pos-visible-in-window-p (point-min)) t)
              (and (pos-visible-in-window-p (point-max)) t))))
  => (t nil))

(deftest pos-not-visible-in-window-p-window-height-is-sane ()
  "ウィンドウの高さが 1 行より大きいこと。
**ここが 0 だと上の 2 件は「何を測っても下」になって、たまたま通る。**
`--batch` でも大きさが失われないことは issue #116 で直してある。"
  (window-visible-test-call-with-long-buffer
    #'(lambda (buf)
        (and (> (window-lines) 1) t)))
  => t)
