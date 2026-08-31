;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `(open ... :if-exists ...)' の 5 通り。
;;;
;;; **`:rename` は書いた内容をどこにも残さず捨てていた** (issue #168)。
;;; `src/core/stream.cc` の `create_file_stream` が一時ファイルへハンドルを
;;; 開いた直後にその名前を捨てていたので、`close_file_stream` は何もせず、
;;; 内容は一時ファイルの中に取り残され、本来のパスは作られないまま終わる。
;;; **Windows でも同じ**で、上流の import (0.2.2.235) からこの形だった。
;;; この tree の `lisp/` には取り残された一時ファイルが 132 個あった
;;; (`.gitignore` に `*.tmp` があるので `git status` には出ない)。
;;;
;;; **一緒に、POSIX でモードが 0600 になっていたのも直した** (issue #169)。
;;; 一時ファイルは `mkstemp` が作る = 0600 で、それが rename でそのまま
;;; 本来の名前になっていた。`lisp/compile.l` は `.lc` を `:supersede` で
;;; 書くので、コンテナ (root) でバイトコンパイルすると**ホストのユーザから
;;; `.lc` が読めなくなる**という形で出ていた。
;;;
;;; **ここは両方のプラットフォームで同じことを聞く。** モードそのものを見る
;;; 2 件だけ POSIX 限定にしてある (Windows のファイルの属性には持ち方が
;;; 無い)。

(defun stream-if-exists-test-with-dir (fn)
  "空のディレクトリを作って FN に渡し、後で消す。
**一時ファイルが残るかどうかを見る**ので、他のものが入っていない
ディレクトリでないと測れない。"
  (let ((dir (make-temp-file-name nil nil nil t)))
    (unwind-protect
        (funcall fn (concat dir "/"))
      (progn
        (dolist (f (directory dir :absolute t))
          (ignore-errors (delete-file f)))
        (ignore-errors (delete-directory dir))))))

(defun stream-if-exists-test-write (file mode text)
  (with-open-file (s file :direction :output
                     :if-exists mode :if-does-not-exist :create)
    (format s "~A~%" text)))

(defun stream-if-exists-test-read (file)
  "FILE の中身を文字列で返す。無ければ nil。CR と LF は落とす
\(Win32 では CRLF で来る)。"
  (let ((buf (create-new-buffer " *stream-if-exists test*")))
    (unwind-protect
        (save-excursion
          (set-buffer buf)
          (and (ignore-errors (insert-file-contents file))
               (remove #\LFD
                       (remove #\RET
                               (buffer-substring (point-min) (point-max))))))
      (ignore-errors (delete-buffer buf)))))

(defun stream-if-exists-test-run (mode)
  "MODE で 2 回書いて、(できたファイルの中身 ディレクトリの中身) を返す。
1 回目はファイルが無い状態、**2 回目が `:if-exists` の本番**である。"
  (stream-if-exists-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (stream-if-exists-test-write file mode "first")
          (stream-if-exists-test-write file mode "second")
          (list (stream-if-exists-test-read file)
                (sort (directory dir) #'string<))))))

;;; --- 書いた内容が残ること --------------------------------------------------

(deftest if-exists-rename-keeps-what-was-written ()
  "**これが本体。** `:rename` で書いた内容がファイルに入っていること、
そして**前の内容が `<path>~` に退避されていること** (CL の `:rename` は
「既存のファイルを別の名前にしてから、新しいファイルを作る」)。

以前は `out.txt` が存在せず、代わりに `xyz4b8b.tmp` のような一時ファイルが
2 つ残っていた。"
  (stream-if-exists-test-run :rename)
  => ("second" ("out.txt" "out.txt~")))

(deftest if-exists-rename-leaves-no-temp-file ()
  "`:rename` が一時ファイルを残さないこと。**上のテストの
ディレクトリの中身でも見えているが、こちらは数で見る**: 残るのは
書いたファイルと退避したファイルの 2 つだけ。"
  (length (second (stream-if-exists-test-run :rename)))
  => 2)

(deftest if-exists-other-modes-keep-what-was-written ()
  "残る 4 通りも最後に書いた内容になること。**`:rename` を直す前から
動いていた**ので、直したことで壊れていないかを見る側である。"
  (mapcar #'(lambda (mode)
              (first (stream-if-exists-test-run mode)))
          '(:new-version :rename-and-delete :supersede :overwrite))
  => ("second" "second" "second" "second"))

(deftest if-exists-temp-based-modes-leave-no-temp-file ()
  "一時ファイルを経由する 3 通りが、経由したものを残さないこと。"
  (mapcar #'(lambda (mode)
              (second (stream-if-exists-test-run mode)))
          '(:new-version :rename-and-delete :supersede))
  => (("out.txt") ("out.txt") ("out.txt")))

;;; --- モード (POSIX 限定) ---------------------------------------------------

(defun stream-if-exists-test-mode (file)
  "FILE のモードを 8 進の文字列で返す。**POSIX 限定。**
Win32 のファイルの属性 (READONLY / HIDDEN / SYSTEM) には対応するものが
無いので、こちらは `(featurep :unix)` の中でだけ呼ぶ。"
  (let ((out (make-temp-file-name)))
    (unwind-protect
        (progn
          (call-process (format nil "stat -c %a '~A'" file)
                        :output out :show :hide :wait t)
          (let ((s (stream-if-exists-test-read out)))
            (and s (string-trim " " s))))
      (ignore-errors (delete-file out)))))

(deftest if-exists-does-not-narrow-the-mode ()
  "**一時ファイルを経由しても、直に書いたのと同じモードになること。**

以前は `mkstemp` の 0600 がそのまま残っていて、`:supersede` で書いた
ファイルが所有者以外から読めなかった。umask に依らない形で見るために、
`:overwrite` (一時ファイルを経由しない) で書いたものと比べている。"
  (if (featurep :unix)
      (stream-if-exists-test-with-dir
        #'(lambda (dir)
            (let ((plain (concat dir "plain.txt"))
                  (temped (concat dir "temped.txt")))
              (stream-if-exists-test-write plain :overwrite "x")
              (stream-if-exists-test-write temped :supersede "x")
              (let ((a (stream-if-exists-test-mode plain))
                    (b (stream-if-exists-test-mode temped)))
                (list (and a b (equal a b) t)
                      ;; **0600 でないこと自体も見る。** 上の比較だけだと、
                      ;; 両方が 0600 になる直し損じを通してしまう。
                      (and b (not (equal b "600")) t))))))
    '(t t))
  => (t t))

(deftest if-exists-keeps-the-mode-of-the-file-it-replaces ()
  "**置き換える相手のモードが残ること。** 一時ファイルを rename で被せる
ので、何もしないと元のモードが消える (`0755` のファイルを `:supersede` で
書き直すと実行ビットが落ちる)。`Buffer::save_buffer` の precious な経路は
`SetFileAttributes (tmpname, filemode)` として最初からこれをしている。"
  (if (featurep :unix)
      (stream-if-exists-test-with-dir
        #'(lambda (dir)
            (let ((file (concat dir "script.sh")))
              (stream-if-exists-test-write file :overwrite "#!/bin/sh")
              (call-process (format nil "chmod 755 '~A'" file)
                            :show :hide :wait t)
              (stream-if-exists-test-write file :supersede "#!/bin/sh")
              (stream-if-exists-test-mode file))))
    "755")
  => "755")

;;; --- 「エラーを出さずに nil を返す」側 -------------------------------------
;;;
;;; **POSIX ではここが全部エラーになっていた。** `create_file_stream` が
;;; `GetLastError ()` の戻り値を `ERROR_*` と直に比べていて、番号の空間が
;;; プラットフォームで違う (Win32 は Win32 のコード、POSIX は errno) ので
;;; どの `case` にも当たらず、`default` の `file_error` に落ちていた。
;;; 意味を聞く述語は issue #120 で `src/core/error.h` に入れたが、**ここが
;;; 漏れていた。**
;;;
;;; 直す前に測ったもの (linux ネイティブビルド):
;;;
;;;   :if-exists :skip        -> simple-program-error 「不正な`:if-exists'…」
;;;   :if-exists nil          -> file-exists          (nil を返すべき)
;;;   存在しないファイル      -> nil                  (ENOENT (2) が
;;;                              ERROR_FILE_NOT_FOUND (2) に偶然一致する)
;;;   途中のディレクトリが無い -> path-not-found       (ENOTDIR (20) は
;;;                              どの ERROR_* にも当たらない)

(defun stream-if-exists-test-quietly (fn)
  "FN を呼んで、値とコンディションを (値 コンディションの型) で返す。
エラーが出なければ型は nil。"
  (multiple-value-bind (v e)
      (ignore-errors (funcall fn))
    (list v (and e (type-of e)))))

(deftest if-exists-nil-returns-nil-instead-of-signalling ()
  "`:if-exists nil` は**エラーを出さずに nil を返す。**"
  (stream-if-exists-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (stream-if-exists-test-write file :overwrite "x")
          (stream-if-exists-test-quietly
            #'(lambda ()
                (open file :direction :output :if-exists nil))))))
  => (nil nil))

(deftest if-exists-skip-is-accepted ()
  "`:skip` を受けること。**reference には「エラーは出力せず、nil を返します」と
書いてあるのに、`不正な :if-exists オプションです` になっていた。**
`create-directory` や `delete-file` は最初から `:skip` を受ける。"
  (stream-if-exists-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (stream-if-exists-test-write file :overwrite "x")
          (stream-if-exists-test-quietly
            #'(lambda ()
                (open file :direction :output :if-exists :skip))))))
  => (nil nil))

(deftest if-does-not-exist-nil-returns-nil-for-a-missing-directory ()
  "**途中のディレクトリが無い**場合も nil を返すこと。ファイルが無いだけの
場合は POSIX でも通っていた (`ENOENT` が `ERROR_FILE_NOT_FOUND` と同じ 2)
ので、**そちらだけ見ていると気付けない。**"
  (stream-if-exists-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (stream-if-exists-test-write file :overwrite "x")
          (list (stream-if-exists-test-quietly
                  #'(lambda ()
                      (open (concat dir "nope.txt")
                            :direction :input :if-does-not-exist nil)))
                (stream-if-exists-test-quietly
                  #'(lambda ()
                      (open (concat file "/x/y.txt")
                            :direction :input :if-does-not-exist nil)))))))
  => ((nil nil) (nil nil)))
