;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; FFI を**両方のプラットフォームで**測る (issue #133)。
;;;
;;; `unittest/foreign-test.l` は `msvcrt` の `_itoa` / `_atoi64` / `_i64toa`
;;; のような **MSVC のランタイム固有の関数**を呼ぶので、POSIX では動かない。
;;; そのため **POSIX 側の FFI は 1 件も測られていなかった。** ここは標準 C の
;;; 関数だけを使うので、どちらでも同じテストになる。
;;;
;;; 使う関数は msvcrt.dll と glibc の両方にあるものだけ:
;;; `abs` `labs` `atoi` `strtol` `strlen` `memcmp` `toupper`。
;;;
;;; **C ライブラリの名前はプラットフォームで違う。** `define-dll-entry` の
;;; 展開は `(si:load-dll-module <名前>)` を**最初の呼び出しのときに**評価する
;;; ので、名前の所に関数呼び出しを書ける。

(defun ffi-test-c-library ()
  "この環境の C ライブラリの名前。読めるものを順に試す。"
  (dolist (name '("msvcrt" "libc.so.6" "libc.so" "libSystem.dylib"))
    (when (ignore-errors (si:load-dll-module name))
      (return name))))

;;;
;;; 引数と返り値の型
;;;

(c:define-dll-entry c:int (ffi-abs :convention :cdecl) (c:int)
  (ffi-test-c-library) "abs")

;; **32bit の端。** LP64 では `long` が 64bit なので、int32 の欄を
;; `long` で読み書きすると符号拡張が起きない (PR #118 / #132 で踏んだ)。
(deftest ffi-int32-argument-and-return ()
  (list (ffi-abs 0) (ffi-abs 1) (ffi-abs -1)
        (ffi-abs -2147483647) (ffi-abs 2147483647))
  => (0 1 1 2147483647 2147483647))

(c:define-dll-entry c:int64 (ffi-labs :convention :cdecl) (c:int64)
  (ffi-test-c-library) #+unix "llabs" #-unix "_abs64")

;; **64bit の引数と返り値。** 32bit の枠に収まらない値を通す。
;; 名前が違う: glibc は `llabs`、msvcrt は `_abs64`。
(deftest ffi-int64-argument-and-return ()
  (list (ffi-labs -8589934592) (ffi-labs 8589934592)
        (ffi-labs -4294967296))
  => (8589934592 8589934592 4294967296))

(c:define-dll-entry c:int (ffi-atoi :convention :cdecl) ((c:void *))
  (ffi-test-c-library) "atoi")

;; ポインタ引数 (chunk のアドレスが渡ること)。
(deftest ffi-pointer-argument ()
  (list (ffi-atoi (si:make-string-chunk "0"))
        (ffi-atoi (si:make-string-chunk "42"))
        (ffi-atoi (si:make-string-chunk "-42"))
        (ffi-atoi (si:make-string-chunk "2147483647")))
  => (0 42 -42 2147483647))

(c:define-dll-entry c:size_t (ffi-strlen :convention :cdecl) ((c:void *))
  (ffi-test-c-library) "strlen")

;; **符号無しの返り値。** `size_t` を fixnum の範囲で受ける。
(deftest ffi-unsigned-return ()
  (list (ffi-strlen (si:make-string-chunk ""))
        (ffi-strlen (si:make-string-chunk "hello"))
        (ffi-strlen (si:make-string-chunk "0123456789")))
  => (0 5 10))

(c:define-dll-entry c:int (ffi-memcmp :convention :cdecl)
  ((c:void *) (c:void *) c:size_t)
  (ffi-test-c-library) "memcmp")

;; 引数 3 つ。**符号を見る** (memcmp は 0 以外の値の大きさを約束しない)。
(deftest ffi-three-arguments ()
  (let ((a (si:make-string-chunk "abc"))
        (b (si:make-string-chunk "abd")))
    (list (zerop (ffi-memcmp a a 3))
          (minusp (ffi-memcmp a b 3))
          (plusp (ffi-memcmp b a 3))))
  => (t t t))

(c:define-dll-entry c:int (ffi-toupper :convention :cdecl) (c:int)
  (ffi-test-c-library) "toupper")

(deftest ffi-small-integers ()
  (mapcar #'(lambda (c) (code-char (ffi-toupper (char-code c))))
          '(#\a #\z #\A #\1))
  => (#\A #\Z #\A #\1))

;;;
;;; 断るべきもの
;;;

;; **float / double の引数を断るのは 64bit だけ。**
;;
;; 64bit (Win64 / SysV / AAPCS) は整数と浮動小数で**別のレジスタ列**を使うので、
;; `int64_t` を並べるキャスト 1 本では渡せない。**黙って違う値を渡すより
;; 断る** (`FEprogram_error`)。
;;
;; **i386 は引数を全部スタックに積むので、float もそのまま渡せる**
;; (`src/frontend/win32/dll.cc` の i386 の枝は `push_arg` で扱っている)。
;; だからこのテストは 64bit にしか無い — 32bit で「断る」を期待すると、
;; **できることをできないと書いたテストになる** (実際に i686 の CI で
;; それを踏んだ)。
#+64bit
(deftest ffi-float-argument-is-refused ()
  (handler-case
      (progn
        (funcall (si:make-c-function (si:load-dll-module (ffi-test-c-library))
                                     "atoi" '(:double) :int32)
                 1.0d0)
        nil)
    (error (c) t))
  => t)

;; 知らない型は断ること。
(deftest ffi-unknown-type-is-refused ()
  (handler-case
      (progn (si:make-c-function (si:load-dll-module (ffi-test-c-library))
                                 "atoi" '(:nosuchtype) :int32)
             nil)
    (error (c) t))
  => t)

;; 無い名前は断ること。
(deftest ffi-missing-symbol-is-refused ()
  (handler-case
      (progn (si:make-c-function (si:load-dll-module (ffi-test-c-library))
                                 "no_such_function_anywhere" '() :int32)
             nil)
    (error (c) t))
  => t)

;;; --- チャンクの中の文字列のエンコーディング -------------------------------
;;;
;;; **チャンクは C の `char *` で、そのバイト列の意味はプラットフォームで
;;; 違う。** Win32 の ANSI API は CP932 を読み、POSIX の C 関数は UTF-8 を
;;; 読む。`si:make-string-chunk` / `si:unpack-string` / `si:pack-string` は
;;; どちらも CP932 決め打ちだった (内部表現が CP932 のバイト列だった頃は
;;; それが恒等変換で、Unicode 移行のときに残った)。
;;;
;;; **読み書きが対称なので、Lisp の中で往復させる限り気付かない。** POSIX で
;;; 壊れるのは C に渡したときだけで、そこには自動のテストが届かない。
;;; **だからバイト列そのものを見る。**

(defun chunk-test-bytes (chunk n)
  (let (r)
    (dotimes (i n)
      (push (si:unpack-uint8 chunk i) r))
    (nreverse r)))

(defun chunk-test-expected-bytes ()
  "\"日本語\" のバイト列。"
  (if (featurep :unix)
      '(230 151 165 230 156 172 232 170 158)   ; UTF-8
    '(147 250 150 123 140 234)))               ; CP932

(deftest chunk-string-uses-the-platform-byte-encoding ()
  (let* ((c (si:make-string-chunk "日本語"))
         (n (1- (si:chunk-size c))))
    (list (equal (chunk-test-bytes c n) (chunk-test-expected-bytes))
          (si:unpack-string c 0)))
  => (t "日本語"))

(deftest chunk-string-round-trips ()
  "書いて読んで元に戻ること。**これは前からできていた** (両方向が同じ
エンコーディングだったので)。ここが崩れていないことを見る。"
  (let ((s "abc 日本語 aあb"))
    (equal s (si:unpack-string (si:make-string-chunk s) 0)))
  => t)

(deftest pack-string-uses-the-same-encoding ()
  "`si:pack-string` も同じバイト列を書くこと。**`si:make-string-chunk` だけ
直しても、こちらが違うと同じチャンクの中で 2 通りのバイト列が混ざる。**"
  (let ((c (si:make-chunk nil 64)))
    (si:pack-string c 0 "日本語" 32)
    (list (equal (chunk-test-bytes c (length (chunk-test-expected-bytes)))
                 (chunk-test-expected-bytes))
          (si:unpack-string c 0)))
  => (t "日本語"))
