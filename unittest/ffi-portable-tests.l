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

;; **float / double の引数は断ること。** SysV では整数と浮動小数で別の
;; レジスタ列を使うので、int64_t を並べるキャスト 1 本では渡せない。
;; Win32 の x86_64 側も同じ理由で断る。**黙って違う値を渡すより、断る。**
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
