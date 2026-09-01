;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(deftest shell-operation-invalid-arg-1 ()
  (si:*file-operation :copy nil nil)
  !! type-error)

(deftest shell-operation-invalid-arg-2 ()
  (si:*file-operation :copy 1 nil)
  !! type-error)

(deftest shell-operation-invalid-arg-3 ()
  (si:*file-operation :copy :hoge nil)
  !! type-error)

(deftest shell-operation-invalid-arg-4 ()
  (si:*file-operation :copy "c:/" nil)
  !! type-error)

(deftest shell-operation-invalid-arg-5 ()
  (si:*file-operation :copy "c:/" 1)
  !! type-error)

(deftest shell-operation-invalid-arg-6 ()
  (si:*file-operation :copy "c:/" :hoge)
  !! type-error)

(deftest shell-operation-invalid-arg-7 ()
  (si:*file-operation nil "c:/" "d:/")
  !! simple-program-error)

(deftest shell-operation-invalid-arg-8 ()
  (si:*file-operation :hoge "c:/" "d:/")
  !! simple-program-error)


(deftest shell-operation-copy ()
  (with-temp-files (file)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file))
    (si:*file-operation :copy file (concat file ".tmp") :no-ui t)
    (values
     (file-exist-p file)
     (with-temp-buffer
       (read-file (concat file ".tmp"))
       (buffer-substring (point-min) (point-max)))))
  => t
  => "abc\n")

(deftest shell-operation-move ()
  (with-temp-files (file)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file))
    (si:*file-operation :move file (concat file ".tmp") :no-ui t)
    (values
     (file-exist-p file)
     (with-temp-buffer
       (read-file (concat file ".tmp"))
       (buffer-substring (point-min) (point-max)))))
  => nil
  => "abc\n")

(deftest shell-operation-rename ()
  (with-temp-files (file)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file))
    (si:*file-operation :rename file (concat file ".tmp") :no-ui t)
    (values
     (file-exist-p file)
     (with-temp-buffer
       (read-file (concat file ".tmp"))
       (buffer-substring (point-min) (point-max)))))
  => nil
  => "abc\n")

(deftest shell-operation-delete ()
  (with-temp-files (file)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file))
    (values
     (file-exist-p file)
     (progn
       (si:*file-operation :delete file nil :no-ui t)
       (file-exist-p file))))
  => t
  => nil)


(deftest shell-operation-copy-multi ()
  (with-temp-files (file1 file2)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file1)
      (write-file file2))
    (with-temp-dirs (tmpdir)
      (let ((new-file1 (merge-pathnames (file-namestring file1) tmpdir))
            (new-file2 (merge-pathnames (file-namestring file2) tmpdir)))
        (unwind-protect
            (progn
              (si:*file-operation :copy
                                  (list file1 file2)
                                  tmpdir
                                  :no-ui t)
              (values
               (file-exist-p file1)
               (file-exist-p file2)
               (file-exist-p new-file1)
               (file-exist-p new-file2)
               (compare-file file1 new-file1)
               (compare-file file2 new-file2)
               ))
          (delete-file new-file1)
          (delete-file new-file2)))))
  => t
  => t
  => t
  => t
  => t
  => t)

(deftest shell-operation-move-multi ()
  (with-temp-files (file1 file2)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file1)
      (write-file file2))
    (with-temp-dirs (tmpdir)
      (let ((new-file1 (merge-pathnames (file-namestring file1) tmpdir))
            (new-file2 (merge-pathnames (file-namestring file2) tmpdir)))
        (unwind-protect
            (progn
              (si:*file-operation :move
                                  (list file1 file2)
                                  tmpdir
                                  :no-ui t)
              (values
               (file-exist-p file1)
               (file-exist-p file2)
               (file-exist-p new-file1)
               (file-exist-p new-file2)
               ))
          (delete-file new-file1)
          (delete-file new-file2)))))
  => nil
  => nil
  => t
  => t)

(deftest shell-operation-move-multi2 ()
  (with-temp-files (file1 file2)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file1)
      (write-file file2))
    (with-temp-dirs (tmpdir)
      (let ((new-file1 (merge-pathnames (file-namestring file1) tmpdir))
            (new-file2 (merge-pathnames (file-namestring file2) tmpdir)))
        (unwind-protect
            (progn
              (si:*file-operation :move
                                  (list file1 file2)
                                  (list new-file1 new-file2)
                                  :no-ui t)
              (values
               (file-exist-p file1)
               (file-exist-p file2)
               (file-exist-p new-file1)
               (file-exist-p new-file2)
               ))
          (delete-file new-file1)
          (delete-file new-file2)))))
  => nil
  => nil
  => t
  => t)

(deftest shell-operation-delete-multi ()
  (with-temp-files (file1 file2)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file1)
      (write-file file2))
    (si:*file-operation :delete
                        (list file1 file2)
                        nil
                        :no-ui t)
    (values
     (file-exist-p file1)
     (file-exist-p file2)
     ))
  => nil
  => nil)


;;;;; special-file-p

;; **判定は「開いて GetFileType を聞く」でやっている** (special_file_p,
;; src/core/pathname.cc)。POSIX ではその GetFileType が platform.h で
;; 常に FILE_TYPE_DISK を返すスタブだったので、**デバイスノードにも FIFO にも
;; nil を返していた** (issue #206)。nil で困るのは (special-file-p ...) 自身
;; だけではない: find-file / read-file / insert-file (lisp/files.l)、
;; insert-file-contents (src/core/insdel.cc)、save-buffer / do-auto-save /
;; write-region (src/core/fileio.cc) が**全部この 1 個の答えで門を開け閉め
;; している**。門に条件変数は無いので、既定の設定でそのまま通る。

(defun special-file-test-device ()
  "実在するキャラクタデバイスの名前。**両プラットフォームに 1 つずつある。**"
  (if (featurep :unix) "/dev/null" "//./NUL"))

(deftest special-file-p-device-node ()
  (special-file-p (special-file-test-device))
  => t)

(deftest special-file-p-regular-file ()
  (with-temp-files (file)
    (with-temp-buffer
      (insert "abc" #\LFD)
      (write-file file))
    (special-file-p file))
  => nil)

(deftest special-file-p-missing-file ()
  "開けなければ nil。**存在しないことを特殊だと言わない。**"
  (with-temp-files (file)
    ;; make-temp-file-name はファイルも作るので、消さないと 1 つ上の
    ;; テストと同じものを測ることになる。
    (delete-file file)
    (special-file-p file))
  => nil)

(deftest special-file-p-directory ()
  "ディレクトリは特殊ではない。

Windows では CreateFile がディレクトリを (FILE_FLAG_BACKUP_SEMANTICS 無しで
は) 開けないので 0、POSIX では開けるが FILE_TYPE_DISK なので 0 -- **理由は
違うが答えは同じ。** 呼び出し元はどれもディレクトリを別に弾いている。"
  (special-file-p (directory-namestring (make-temp-file-name)))
  => nil)

(deftest special-file-p-fifo-comes-back ()
  "FIFO に t を返すこと、そして**戻ってくること。**

POSIX の open(2) は FIFO の相手側を待ち合わせる。special_file_p は種類を
知るために一度開くだけなのに、O_NONBLOCK を付けていなかったので
**書き手が現れるまで xyzzy 全体が固まっていた** -- C-x C-f で FIFO を指すと
戻ってこない。GetFileType を直すだけでは、この経路は固まったまま**答えに
到達しない。**

別プロセスで測るのは、戻らなくなったときに**スイート全体を止めずに赤に
する**ため (eval-in-another-xyzzy の :timeout)。Windows に FIFO は無いので
POSIX だけで測る。"
  (if (featurep :unix)
      (with-temp-files (fifo)
        ;; make-temp-file-name は**名前だけでなくファイルを作る。** 消して
        ;; おかないと mkfifo が "File exists" で失敗し、ふつうのファイルを
        ;; 測ることになる (それでも t を期待していると赤にはなるが、理由が
        ;; FIFO と関係なくなる)。
        (delete-file fifo)
        (call-process (format nil "mkfifo ~A" fifo) :wait t :show :hide)
        (eval-in-another-xyzzy `(special-file-p ,fifo)
                               :options "-q" :timeout 30))
    t)
  => t)

(deftest find-file-refuses-a-device-node ()
  "門が閉まっていること。**これが (special-file-p ...) が nil で困る所。**"
  (handler-case
      (progn (ed::find-file-internal (special-file-test-device)) :opened)
    (error () :refused))
  => :refused)
