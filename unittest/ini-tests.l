;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; xyzzy.ini の読み書きのテスト (src/core/conf-io.cc と
;;; src/core/ini-posix.cc、issue #143)。
;;;
;;; **Win32 と POSIX で同じテストになる。** 読む側の入口は
;;; `GetPrivateProfileStringW` (Win32) と src/core/ini-posix.cc (POSIX) で
;;; 別だが、**上に載っている書式の処理 (src/core/conf-io.cc) は共通**なので、
;;; ini ファイルを置いて設定が効くかを見れば両方を測れる。
;;;
;;; 観測に `default-fold-width` を使う。**Lisp から見える ini 由来の設定が
;;; これしか無い**ため: `[Misc] foldMode` が `Buffer::b_default_fold_mode`
;;; に入り、`(default-fold-width)` がそれを返す。ウィンドウの位置や色は
;;; 端末ビルドに無いので使えない。
;;;
;;; 既定 (折り返し無し) では**数ではなく nil** が返る。「読まれた = 40」
;;; 「読まれていない = nil」で見る。
;;;
;;; **子プロセスを起こして測る。** ini を読むのは起動時 1 回だけなので、
;;; 走っているプロセスに後から ini を渡しても効かない。

(defun ini-test-write (path contents)
  "PATH に CONTENTS を書く。ini は ASCII なので encoding は既定でよい。"
  (let ((buf (create-new-buffer " *ini test*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (insert contents)
          (write-region (point-min) (point-max) path))
      (ignore-errors (delete-buffer buf)))))

(defun ini-test-read (path)
  "PATH の中身を文字列で返す。無ければ nil。CR は落とす。"
  (let ((buf (create-new-buffer " *ini read*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (and (ignore-errors (insert-file-contents path))
               (remove #\RET (buffer-substring (point-min) (point-max)))))
      (ignore-errors (delete-buffer buf)))))

;; **ini の値が起動時に読まれること。** これが本体。
(deftest ini-value-is-read-at-startup ()
  (with-temp-files (ini)
    (ini-test-write ini (format nil "[Misc]~%foldMode=40~%"))
    (eval-in-another-xyzzy '(default-fold-width)
                           :options (format nil "-ini \"~A\" -q" ini)))
  => 40)

;; 節が違えば読まない (節を見ずにキー名だけで拾っていないこと)。
;;
;; **既定は nil。** 折り返し無しは幅を持たないので `default-fold-width` は
;; 数ではなく nil を返す。「40 でないこと」ではなく「読まれていないこと」を
;; そのまま書く。
(deftest ini-value-in-another-section-is-ignored ()
  (with-temp-files (ini)
    (ini-test-write ini (format nil "[NotMisc]~%foldMode=40~%"))
    (eval-in-another-xyzzy '(default-fold-width)
                           :options (format nil "-ini \"~A\" -q" ini)))
  => nil)

;; **コメントと空行と大文字小文字。** ini は人が手で編集するので、
;; 綺麗に整形されたものしか読めないと使えない。
(deftest ini-tolerates-comments-and-case ()
  (with-temp-files (ini)
    (ini-test-write ini (format nil "; コメント~%~%[misc]~%~%  FOLDMODE = 40  ~%"))
    (eval-in-another-xyzzy '(default-fold-width)
                           :options (format nil "-ini \"~A\" -q" ini)))
  => 40)

;; 無い ini を指しても落ちないこと (既定のまま動く)。
(deftest ini-missing-file-is-harmless ()
  (with-temp-dirs (dir)
    (eval-in-another-xyzzy '(default-fold-width)
                           :options (format nil "-ini \"~Ano-such.ini\" -q" dir)))
  => nil)

;; **`-ini` は絶対パスで返ること。** 途中で `chdir` すると相対パスは別の
;; ファイルを指すので、決めた時点で固定していなければならない。
(deftest ini-path-is-absolute ()
  (with-temp-files (ini)
    (let ((path (eval-in-another-xyzzy '(xyzzy-ini-path)
                                       :options (format nil "-ini \"~A\" -q" ini))))
      (and (stringp path)
           ;; 先頭が区切りかドライブ文字。どちらの形も絶対パス。
           (or (char= (char path 0) #\/)
               (and (> (length path) 1) (char= (char path 1) #\:)))
           t)))
  => t)
