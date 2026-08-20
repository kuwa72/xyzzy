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

;; 文字 1 個としての挿入。コマンド行やバッファで絵文字を打つとこの経路を通る。
;; 以前は 16bit に切り詰めて 0xF600 を書き込んでいた。0xF600 は CCF_META
;; (メタ機能キー) と同じ値なので、本文に紛れ込んだ時点でプロセスが落ちた。
(deftest non-bmp-insert-char ()
  (let ((buf (get-buffer-create "*non-bmp-insert*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert (code-char 128512))
          (list (point-max)
                (map 'list #'char-code
                     (buffer-substring (point-min) (point-max)))))
      (delete-buffer buf)))
  => (1 (128512)))

;; 繰り返し付き (self-insert-command は (insert char arg) で呼ぶ)
(deftest non-bmp-insert-char-repeat ()
  (let ((buf (get-buffer-create "*non-bmp-insert2*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert (code-char 128512) 3)
          (list (point-max)
                (map 'list #'char-code
                     (buffer-substring (point-min) (point-max)))))
      (delete-buffer buf)))
  => (3 (128512 128512 128512)))

;; 文字と文字列を混ぜた挿入 (Finsert は引数ごとに領域を切る)
(deftest non-bmp-insert-mixed ()
  (let ((buf (get-buffer-create "*non-bmp-insert3*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "a" (code-char 128512) "b" (code-char 128513))
          (map 'list #'char-code (buffer-substring (point-min) (point-max))))
      (delete-buffer buf)))
  => (97 128512 98 128513))

;;; ------------------------------------------------------------------
;;; 入力経路 (WM_CHAR / IME) が surrogate pair を 1 文字として渡すこと
;;;
;;; Windows は BMP 外の文字を WM_CHAR / WM_IME_CHAR で code unit 2 個 =
;;; メッセージ 2 通に分けて渡してくる。以前はそれをそのままキュー に載せて
;;; いたので self-insert-command が 2 回走り、buffer に surrogate の片割れが
;;; 別々の文字として insert された。b_nchars は 2 増えるのに chunk 側の
;;; c_nchars は pair を 1 code point と数えるので、buffer の code point 数が
;;; その場で壊れる。実機では
;;;   - カーソルが 1 個余分に進む
;;;   - アンドゥ・リドゥが元に戻らない
;;;   - 空バッファ (= コマンド行) では forward_char が chunk 末尾を踏み抜いて
;;;     プロセスが落ちる
;;; という形で出た。キューに載せる前に pair を畳むことで直したが、C++ 側の
;;; 入力経路は Lisp から叩けないので、ここでは畳んだ後に通る経路
;;; (= 文字 1 個の insert) の契約を押さえる。

;; insert 後の point は code point 数で進む。2 (code unit 数) ではない。
(deftest non-bmp-insert-advances-one-point ()
  (let ((buf (get-buffer-create "*non-bmp-point*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (let ((p0 (point)))
            (insert (code-char 128512))
            (list (- (point) p0) (point-max))))
      (delete-buffer buf)))
  => (1 1))

;; 文字の前後にテキストがある場合。実機の報告 (本文に絵文字を打つと
;; カーソルが 1 個余分に進む) はこの形。
(deftest non-bmp-insert-advances-one-point-mid ()
  (let ((buf (get-buffer-create "*non-bmp-point2*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "ab")
          (goto-char 1)
          (insert (code-char 128512))
          (list (point) (point-max)
                (map 'list #'char-code
                     (buffer-substring (point-min) (point-max)))))
      (delete-buffer buf)))
  => (2 3 (97 128512 98)))

;; アンドゥで消え、リドゥで戻る。
(deftest non-bmp-insert-undo-redo ()
  (let ((buf (get-buffer-create "*non-bmp-undo*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "ab")
          (goto-char 1)
          (undo-boundary)
          (insert (code-char 128512))
          (let ((after (map 'list #'char-code
                            (buffer-substring (point-min) (point-max)))))
            (undo)
            (let ((undone (map 'list #'char-code
                               (buffer-substring (point-min) (point-max)))))
              (redo)
              (list after undone
                    (map 'list #'char-code
                         (buffer-substring (point-min) (point-max)))))))
      (delete-buffer buf)))
  => ((97 128512 98) (97 98) (97 128512 98)))

;; 削除も 1 文字単位。
(deftest non-bmp-delete-one-char ()
  (let ((buf (get-buffer-create "*non-bmp-del*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "a" (code-char 128512) "b")
          (goto-char 1)
          (delete-char 1)
          (list (point-max)
                (map 'list #'char-code
                     (buffer-substring (point-min) (point-max)))))
      (delete-buffer buf)))
  => (2 (97 98)))

;; 前後移動が 1 回で越える。
(deftest non-bmp-forward-backward-char ()
  (let ((buf (get-buffer-create "*non-bmp-move*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert "a" (code-char 128512) "b")
          (goto-char 1)
          (forward-char 1)
          (let ((fwd (point)))
            (backward-char 1)
            (list fwd (point))))
      (delete-buffer buf)))
  => (2 1))

;; surrogate の片割れを別々に insert すると code point 数の帳尻が合わなく
;; なる。これは入力経路を直したので通常は起きないが、Lisp から明示的に
;; 書けば作れてしまう。以前はこの状態で forward_char が chunk の末尾を
;; 踏み抜いて落ちた。落ちずに返ることだけを見る (値は壊れていてよい)。
(deftest non-bmp-lone-surrogate-halves-do-not-crash ()
  (let ((buf (get-buffer-create "*non-bmp-halves*")))
    (unwind-protect
        (with-set-buffer
          (set-buffer buf)
          (erase-buffer buf)
          (insert (code-char #xD83D))
          (insert (code-char #xDE00))
          (goto-char (point-min))
          (forward-char 1)
          (goto-char (point-max))
          t)
      (delete-buffer buf)))
  => t)

;;; ------------------------------------------------------------------
;;; 同じ 16bit 切り詰めが残っていた場所

;; バイトコンパイルされたコードから呼ぶ code-char。BCcode_char は
;; Fcode_char と別に実装されていて、そちらだけ Char に切り詰めていた。
;; deftest の本体はインタプリタで動くので、バイトコンパイルした関数を
;; 経由して確かめる。
(defun non-bmp-bc-code-char (n) (code-char n))

(deftest non-bmp-bytecode-code-char ()
  (progn
    (compile 'non-bmp-bc-code-char)
    ;; 本当にバイトコンパイルされたか見ておく。インタプリタのままだと
    ;; Fcode_char を通ってしまい、このテストが素通りする。
    (list (and (compiled-function-p (symbol-function 'non-bmp-bc-code-char)) t)
          (char-code (non-bmp-bc-code-char 128512))
          (char-code (non-bmp-bc-code-char #x10FFFF))
          (non-bmp-bc-code-char char-code-limit)))
  => (t 128512 #x10FFFF nil))

;; read-char / peek-char。C-q (quote-char) はここを通るし、UTF-8 の
;; ファイルを read-char で読む場合も通る。
(deftest non-bmp-read-char ()
  (with-input-from-string (s (string (code-char 128512)))
    (let ((c (read-char s)))
      (list (char-code c) (read-char s nil :eof))))
  => (128512 :eof))

(deftest non-bmp-peek-char ()
  (with-input-from-string (s (string (code-char 128512)))
    (let ((p (peek-char nil s)))
      (list (char-code p) (char-code (read-char s)))))
  => (128512 128512))

;; unicode-char は code-point の入口。char-unicode と往復すること。
;; 以前は BMP 外に対してサロゲート 2 要素の文字列を返していたので、
;; C-q u で U+1F600 を入れると文字を期待している cmds.l 側と食い違った。
(deftest non-bmp-unicode-char-roundtrip ()
  (let ((c (unicode-char 128512)))
    (list (characterp c) (char-code c) (char-unicode c)))
  => (t 128512 128512))

;; サロゲートの片割れは code point ではないので nil。
;; ただし U+1D800 のように下位 16bit がサロゲートに見える BMP 外の
;; code point は文字になる (以前は切り詰めて nil にしていた)。
(deftest non-bmp-unicode-char-surrogate ()
  (list (unicode-char #xD800) (unicode-char #xDFFF)
        (char-unicode (unicode-char #x1D800)))
  => (nil nil #x1D800))
