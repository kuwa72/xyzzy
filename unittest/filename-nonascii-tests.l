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

;;; ここから下は CP932 に無い文字。以前はパス層が CP932 を経由していたので、
;;; 変換できない文字が '?' になり、ファイル名として不正だと拒否されていた。
;;; 「日本語なら通るのに韓国語だと開けない」という形で出る。

(deftest filename-hangul-roundtrip ()
  (unwind-protect
      (let ((f (fname-test-setup "한국어시험.txt")))
        (list (and (file-exist-p f) t)
              (file-namestring (truename f))
              (with-open-file (s f) (read-line s nil :eof))))
    (fname-test-teardown))
  => (t "한국어시험.txt" "content"))

(deftest filename-hangul-directory ()
  (unwind-protect
      (progn
        (fname-test-setup "한국어시험.txt")
        (mapcar #'file-namestring
                (directory (fname-test-directory))))
    (fname-test-teardown))
  => ("한국어시험.txt"))

(deftest filename-hangul-completion ()
  (unwind-protect
      (progn
        (fname-test-setup "한국어시험.txt")
        (file-namestring
         (*do-completion (concat (namestring (fname-test-directory)) "/한국")
                         :exist-file-name)))
    (fname-test-teardown))
  => "한국어시험.txt")

;; ディレクトリ名自体が CP932 の外にある場合
(deftest filename-hangul-directory-name ()
  (let ((dir (merge-pathnames "unittest/data/디렉터리/" (si:system-root))))
    (unwind-protect
        (progn
          (create-directory dir)
          (let ((f (merge-pathnames "abc.txt" dir)))
            (with-open-file (s f :direction :output :if-exists :supersede)
              (princ "x" s))
            (list (and (file-directory-p dir) t)
                  (and (file-exist-p f) t)
                  (mapcar #'file-namestring (directory dir)))))
      (when (file-directory-p dir)
        (dolist (f (directory dir :absolute t))
          (when (file-exist-p f) (delete-file f)))
        (delete-directory dir))))
  => (t t ("abc.txt")))

;;; BMP の外にある文字を含むファイル名。パス層が UTF-16 になり、かつ文字が
;;; code point を丸ごと持てるようになって初めて通る。報告の
;;; 「パスに絵文字を含むファイルはいかなる手段でも開けない」がこれ。

(deftest filename-emoji-roundtrip ()
  (unwind-protect
      (let ((f (fname-test-setup "絵文字😀.txt")))
        (list (and (file-exist-p f) t)
              (file-namestring (truename f))
              (with-open-file (s f) (read-line s nil :eof))))
    (fname-test-teardown))
  => (t "絵文字😀.txt" "content"))

(deftest filename-emoji-directory ()
  (unwind-protect
      (progn
        (fname-test-setup "絵文字😀.txt")
        (mapcar #'file-namestring
                (directory (fname-test-directory))))
    (fname-test-teardown))
  => ("絵文字😀.txt"))

;; 補完で '??' に化けないこと (UTF-16 の 2 単位が '?' 2 個になっていた)
(deftest filename-emoji-completion ()
  (unwind-protect
      (progn
        (fname-test-setup "絵文字😀.txt")
        (file-namestring
         (*do-completion (concat (namestring (fname-test-directory)) "/絵文字")
                         :exist-file-name)))
    (fname-test-teardown))
  => "絵文字😀.txt")

;; 名前は 8 文字 (絵 文 字 😀 . t x t)。バイト数や UTF-16 単位数ではない。
(deftest filename-emoji-length ()
  (length "絵文字😀.txt")
  => 8)

;; wild card の突き合わせも CP932 を経由しなくなったこと
(deftest filename-hangul-wild ()
  (unwind-protect
      (progn
        (fname-test-setup "한국어시험.txt")
        (mapcar #'file-namestring
                (directory (fname-test-directory) :wild "한*.txt")))
    (fname-test-teardown))
  => ("한국어시험.txt"))
