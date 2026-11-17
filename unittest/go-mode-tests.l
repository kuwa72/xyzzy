;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for go-mode (lisp/go-mode.l)
;;;

(use-package "editor")

(deftest go-mode-defined ()
  "go-mode コマンドが定義されている (issue #433)"
  (fboundp 'go-mode)
  => t)

(deftest go-mode-auto-mode-alist ()
  ".go ファイルが go-mode に割り当てられている (issue #433)"
  (cdr (assoc "\\.go$" *auto-mode-alist* :test #'string=))
  => go-mode)

(deftest go-mode-activates ()
  "go-mode がバッファを設定する: モード名、シンタクステーブル、
regexp-keyword-list が有効になる"
  (let ((buf (create-new-buffer " *go-mode-test*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (go-mode)
          (list mode-name
                buffer-mode
                (and (boundp 'regexp-keyword-list)
                     regexp-keyword-list
                     t)
                comment-start))
      (ignore-errors (delete-buffer buf))))
  => ("Go" go-mode t "// "))

(deftest go-mode-highlights-go-syntax ()
  "キーワード・組み込み型・数値が色付けの対象になっている。
highlight されないと .go を開いても fundamental-mode と見分けがつかない
(issue #433)。"
  (let ((buf (create-new-buffer " *go-mode-test*"))
        (keyword nil)
        (type nil)
        (number nil))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (go-mode)
          (dolist (rule regexp-keyword-list)
            (let ((re (car rule)))
              (when (string-match re "func main() {}") (setq keyword t))
              (when (string-match re "var n int") (setq type t))
              (when (string-match re "x := 42") (setq number t)))))
      (ignore-errors (delete-buffer buf)))
    (list keyword type number))
  => (t t t))
