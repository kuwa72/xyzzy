;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; Win32 GUI 依存を core から frontend へ出す改修 (issues #281, #284,
;;; #294, #295, #296) のうち、実行時に測れる不変条件を固定するテスト。
;;;
;;; ソース構造の不変条件は tools/check-win32-separation.py で検査する。

(in-package :user)

;; format-drive の unsupported 化は POSIX/CLI フロントエンドでのみ測る。
(when (featurep :unix)
  (deftest format-drive-is-unsupported-on-posix
      "POSIX/CLI フロントエンドでは format-drive を unsupported-on-this-platform
エラーにする (issue #284)。"
    (handler-case (progn (format-drive) :no-error)
      (error (c) (declare (ignore c)) :error))
    => :error))

(deftest refresh-screen-runs-without-error
    "リフレッシュ経路 (paint_window / paint_region などの Painter& 描画パイプライン)
が例外を上げない (issue #296)。"
  (handler-case (progn (refresh-screen) :ok)
    (error (c) (princ-to-string c)))
  => :ok)
