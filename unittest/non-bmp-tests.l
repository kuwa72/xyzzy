;;; -*- Encoding: utf-8 -*-
;;; BMP の外にある文字 (絵文字など) が文字として扱えること。
;;;
;;; 以前は二か所で落ちていた。文字の即値がデータを上位 16bit に詰めていたので
;;; code point が 16bit に切り詰められ、UTF-8 のデコーダは 4 バイト列を読み
;;; 飛ばして '?' に置き換えていた。前者は (code-char 128512) が 62976 になる、
;;; 後者はソースやファイルに書いた絵文字が '?' になる、という形で出る。

(deftest non-bmp-code-char ()
  (let ((c (code-char 128512)))         ; U+1F600 😀
    (list (and c t) (char-code c)))
  => (t 128512))

(deftest non-bmp-code-char-max ()
  (char-code (code-char #x10FFFF))
  => #x10FFFF)

;; サロゲートの片割れは文字ではない
(deftest non-bmp-code-char-lone-surrogate ()
  (list (code-char #xD800) (code-char #xDFFF))
  => (nil nil))

(deftest non-bmp-code-char-out-of-range ()
  (code-char #x110000)
  => nil)

;; リーダが 4 バイトの UTF-8 を 1 文字として読むこと
(deftest non-bmp-literal ()
  (list (length "a😀b") (map 'list #'char-code "a😀b"))
  => (3 (97 128512 98)))

(deftest non-bmp-char-literal ()
  (char-code #\😀)
  => 128512)

;; 文字列と文字の行き来
(deftest non-bmp-string-roundtrip ()
  (let ((s (string (code-char 128512))))
    (list (length s) (char-code (char s 0))))
  => (1 128512))

;; ファイルに書いて読み直す (UTF-8)
(defun non-bmp-test-file ()
  (merge-pathnames "unittest/data/non-bmp.txt" (si:system-root)))

(deftest non-bmp-file-roundtrip ()
  (let ((f (non-bmp-test-file)))
    (unwind-protect
        (progn
          (with-open-file (s f :direction :output :if-exists :supersede
                             :encoding :utf8)
            (princ "a😀b" s))
          (with-open-file (s f :encoding :utf8)
            (let ((line (read-line s nil "")))
              (list (length line) (map 'list #'char-code line)))))
      (when (file-exist-p f) (delete-file f))))
  => (3 (97 128512 98)))

;; バッファに入れて取り出す (chunk は UTF-16 なのでサロゲート対で保持される)
(deftest non-bmp-buffer-roundtrip ()
  (with-output-to-temp-buffer ("*non-bmp-test*")
    nil)
  (let ((buf (get-buffer-create "*non-bmp-test*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "a😀b")
          (list (point-max)
                (map 'list #'char-code (buffer-substring (point-min) (point-max)))))
      (delete-buffer buf)))
  => (3 (97 128512 98)))

;; バッファ内の検索。chunk は UTF-16 なので絵文字は 2 単位だが、パターンも
;; 同じ表現なので素直に一致する。
(deftest non-bmp-buffer-search ()
  (let ((buf (get-buffer-create "*non-bmp-search*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "abc😀def")
          (goto-char (point-min))
          (list (and (scan-buffer "😀") t) (point)))
      (delete-buffer buf)))
  => (t 3))
