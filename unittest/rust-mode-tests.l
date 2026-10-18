;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; Tests for rust-mode (lisp/rust-mode.l)
;;;

(use-package "editor")

(deftest rust-mode-defined ()
  "rust-mode コマンドが定義されている (issue #404)"
  (fboundp 'rust-mode)
  => t)

(deftest rust-mode-auto-mode-alist ()
  ".rs ファイルが rust-mode に割り当てられている (issue #404)"
  (cdr (assoc "\\.rs$" *auto-mode-alist* :test #'string=))
  => rust-mode)

(deftest rust-mode-activates ()
  "rust-mode がバッファを設定する: モード名、シンタクステーブル、
regexp-keyword-list が有効になる"
  (let ((buf (create-new-buffer " *rust-mode-test*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (rust-mode)
          (list mode-name
                buffer-mode
                (and (boundp 'regexp-keyword-list)
                     regexp-keyword-list
                     t)
                comment-start))
      (ignore-errors (delete-buffer buf))))
  => ("Rust" rust-mode t "// "))
