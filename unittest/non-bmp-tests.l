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

;; code-char は char-code-limit 未満のすべてに文字を返す。サロゲートの片割れも
;; 含む: バッファの本文は UTF-16 の code unit なので片割れが現れうる。
(deftest non-bmp-code-char-lone-surrogate ()
  (list (char-code (code-char #xD800)) (char-code (code-char #xDFFF)))
  => (#xD800 #xDFFF))

(deftest non-bmp-code-char-out-of-range ()
  (list (code-char char-code-limit) (code-char (1+ char-code-limit)))
  => (nil nil))

;; charname.l は起動時にこの範囲を歩くので、途中で nil を返すと落ちる。
;; 全部 (110 万回) 歩くと遅いので、境界の帯だけ見る。
(deftest non-bmp-code-char-total ()
  (let ((n 0))
    (dolist (band (list (cons 0 #x100)                  ; 制御文字と ASCII
                        (cons #xD700 #xE000)            ; サロゲート域の前後
                        (cons #xF600 #x10000)           ; 機能キー/メタの領域
                        (cons #x10000 #x10100)          ; BMP の直後
                        (cons (- char-code-limit 256) char-code-limit)))
      (do ((i (car band) (1+ i))) ((>= i (cdr band)))
        (unless (code-char i) (incf n))))
    n)
  => 0)

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
