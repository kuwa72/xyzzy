;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `(open ... :share ...)' の既定値 (issue #381)。
;;;
;;; **Windows で `:share` を省略すると、開いたハンドルが他の open を
;;; 締め出していた。** 既定は「`:input` / `:probe` なら共有読み、
;;; それ以外は共有なし」だったので、読み手がハンドルを持っている間は
;;; 書き手の open が共有違反 (Errno 13) で失敗する。POSIX の `open(2)`
;;; には共有モードが無く、誰が開いていても後から誰でも開けるので、
;;; **Windows だけの違いだった。**
;;;
;;; 実際に踏んだのは PR #380 の LSP E2E テストで、fake 言語サーバーが
;;; ログへ 1 行ずつ append するのをテスト側がポーリングして読んでいた
;;; ところ、**2 行目の append から必ず失敗した。** `:share :read-write`
;;; を明示すれば避けられるが、既定が POSIX と違うのはバグなので直す。
;;;
;;; 直し方は「`:share` 省略時は常に `:read-write` と同じ」。
;;; `src/core/vfs-posix.cc` の `WINFS::CreateFile` は share 引数を
;;; 丸ごと無視している (= POSIX は最初からこの挙動) なので、
;;; **既定を揃えると Windows 側が POSIX に追いつくだけである。**
;;; バッファのファイルロック (`Buffer::lock_file`) は `open` とは別系で
;;; 自分用のハンドルを握るので、この既定に影響されない。

(defun open-share-test-with-dir (fn)
  "空のディレクトリを作って FN に渡し、後で消す。"
  (let ((dir (make-temp-file-name nil nil nil t)))
    (unwind-protect
        (funcall fn (concat dir "/"))
      (progn
        (dolist (f (directory dir :absolute t))
          (ignore-errors (delete-file f)))
        (ignore-errors (delete-directory dir))))))

(defun open-share-test-write (file text)
  (with-open-file (s file :direction :output
                     :if-exists :overwrite :if-does-not-exist :create)
    (format s "~A~%" text)))

(defun open-share-test-open-again (file &rest keys)
  "FILE を KEYS で開く。開けたら close して :opened、
エラー (共有違反を含む) なら :denied を返す。"
  (multiple-value-bind (s e) (ignore-errors (apply #'open file keys))
    (cond (e :denied)
          (s (close s) :opened)
          (t :denied))))

;;; --- :share 省略時の既定 ---------------------------------------------------

(deftest open-share-default-input-does-not-lock-out-writers ()
  "**issue #381 の本体。** `:share` 省略の読み手がハンドルを持っている
間に、別の open が書き手として開けること。以前は読み手が
FILE_SHARE_READ だけを許すので、書き手は共有違反で弾かれていた。"
  (open-share-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (open-share-test-write file "x")
          (let ((in (open file :direction :input)))
            (unwind-protect
                (open-share-test-open-again
                 file :direction :output :if-exists :append)
              (close in))))))
  => :opened)

(deftest open-share-default-output-does-not-lock-out-others ()
  "`:share` 省略の書き手が、後から開く読み手・書き手の両方を
締め出さないこと。以前は share=0 (共有なし) だったので全部弾かれた。"
  (open-share-test-with-dir
    #'(lambda (dir)
        (let ((file (concat dir "out.txt")))
          (open-share-test-write file "x")
          (let ((out (open file :direction :output :if-exists :append)))
            (unwind-protect
                (list (open-share-test-open-again file :direction :input)
                      (open-share-test-open-again
                       file :direction :output :if-exists :append))
              (close out))))))
  => (:opened :opened))

;;; --- 明示した `:share` は変わらない -------------------------------------------
;;;
;;; **共有モードを聞けるのは Windows だけ** (POSIX の open(2) には無い)。
;;; だから 2 件とも `(featurep :unix)` では期待値と同じセンチネルを
;;; そのまま返して、実際に開いて確かめるのは Windows 側だけにする。

(deftest open-share-explicit-nil-is-still-exclusive ()
  "`:share nil` を明示した場合は排他のままであること
\(既定を緩めても「締めたい」という明示は効き続ける)。"
  (if (featurep :unix)
      :denied
    (open-share-test-with-dir
      #'(lambda (dir)
          (let ((file (concat dir "out.txt")))
            (open-share-test-write file "x")
            (let ((in (open file :direction :input :share nil)))
              (unwind-protect
                  (open-share-test-open-again file :direction :input)
                (close in)))))))
  => :denied)

(deftest open-share-explicit-read-still-blocks-writers ()
  "`:share :read` を明示した読み手は、引き続き書き手を拒否すること
\(既定が変わっても既存の明示オプションの意味は変えていない)。"
  (if (featurep :unix)
      :denied
    (open-share-test-with-dir
      #'(lambda (dir)
          (let ((file (concat dir "out.txt")))
            (open-share-test-write file "x")
            (let ((in (open file :direction :input :share :read)))
              (unwind-protect
                  (open-share-test-open-again
                   file :direction :output :if-exists :append)
                (close in)))))))
  => :denied)
