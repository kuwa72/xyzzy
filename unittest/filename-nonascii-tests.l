;;; -*- Encoding: utf-8 -*-
;;; 非 ASCII を含むファイル名の往復: 作って、見つけて、読んで、並べて、補完する。
;;;
;;; pathnames-tests.l が丸ごと除外されているため、この経路にはテストが無かった。
;;; ファイル名の文字コードは Win32 の W-API と内部表現の境界にあり、壊れても
;;; 「開けない」としか見えないので、境界そのものを測っておく。

(defun fname-test-directory ()
  (merge-pathnames "unittest/data/fname-nonascii/" (si:system-root)))

(defun fname-test-file (name)
  (merge-pathnames name (fname-test-directory)))

(defun fname-test-setup (name)
  (let ((dir (fname-test-directory)))
    (unless (file-directory-p dir)
      (create-directory dir))
    (let ((f (fname-test-file name)))
      (with-open-file (s f :direction :output :if-exists :supersede)
        (princ "content" s))
      f)))

(defun fname-test-teardown ()
  (let ((dir (fname-test-directory)))
    (when (file-directory-p dir)
      (dolist (f (directory dir :absolute t))
        (when (file-exist-p f)
          (delete-file f)))
      (delete-directory dir))))

;; 作ったファイルが在ることになっていて、読み出せて、真名も同じ名前になるか
(deftest filename-nonascii-roundtrip ()
  (unwind-protect
      (let ((f (fname-test-setup "日本語テスト.txt")))
        (list (and (file-exist-p f) t)
              (file-namestring (truename f))
              (with-open-file (s f) (read-line s nil :eof))))
    (fname-test-teardown))
  => (t "日本語テスト.txt" "content"))

;; directory が名前を壊さずに返すか
(deftest filename-nonascii-directory ()
  (unwind-protect
      (progn
        (fname-test-setup "日本語テスト.txt")
        (mapcar #'file-namestring
                (directory (fname-test-directory))))
    (fname-test-teardown))
  => ("日本語テスト.txt"))

;; 非 ASCII の前置に対して補完が効くか (ミニバッファの補完が通る経路)
(deftest filename-nonascii-completion ()
  (unwind-protect
      (progn
        (fname-test-setup "日本語テスト.txt")
        ;; namestring は末尾の / を付けないので自分で足す。付け忘れると
        ;; ディレクトリ名と前置がつながって :no-match になる。
        (file-namestring
         (*do-completion (concat (namestring (fname-test-directory)) "/日本")
                         :exist-file-name)))
    (fname-test-teardown))
  => "日本語テスト.txt")

;; 内部表現は文字単位である (バイト単位に戻ると補完の突き合わせが崩れる)
(deftest filename-nonascii-string-length ()
  (length "日本語テスト.txt")
  => 10)
