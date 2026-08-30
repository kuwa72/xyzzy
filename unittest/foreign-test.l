;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(require "foreign")

;;; **C のライブラリの名前がプラットフォームで違う。** ここは "msvcrt" 決め打ち
;;; だったので POSIX では `dlopen` が失敗し、**その関数を使うテストが全部
;;; 「共有ライブラリを読み込めません」で落ちていた。**
;;;
;;; 落ちていたものの多くはプラットフォームに関係が無かった。たとえば可変長引数の
;;; 型検査 (`funcall-invalid-vaargs-*` 7 件) は `si:make-c-function` に渡す型を
;;; 見るだけで、**関数を呼ぶ所まで行かない。** 期待していたのは
;;; 「不正な可変長引数です: 123」で、返っていたのは
;;; 「共有ライブラリを読み込めません」だった (issue #50)。
;;;
;;; **`si:load-dll-module` を呼ぶのは define-dll-entry が展開した defun の中**
;;; なので、ライブラリ名は式で書ける (関数の名前だけは展開時に文字列である
;;; 必要があるので、そこは読み込み時条件で分ける)。

(defun foreign-test-libc ()
  "C の標準ライブラリ。**在るものを選ぶ**: 名前は配布によって違う。"
  (if (featurep :unix)
      (or (find-if #'(lambda (n) (ignore-errors (si:load-dll-module n) t))
                   '("libc.so.6" "libc.so" "libSystem.dylib"))
          "libc.so.6")
    "msvcrt"))

(c:define-dll-entry
  c:int
  EnumWindows ((c:void *)       ; lpEnumFunc
               (c:void *))      ; lParam
  "user32")

(c:defun-c-callable
  c:int
  enum-windows-proc
  ((c:int hwnd)
   ((c:void *) data))
  (push hwnd *enum-windows-result*)
  1)

(deftest defun-c-callable-stdcall ()
  (let ((*enum-windows-result* nil))
    (declare (special *enum-windows-result*))
    (EnumWindows #'enum-windows-proc 0)
    (member (get-window-handle) *enum-windows-result*))
  => non-nil)


(c:define-dll-entry
  c:void
  (qsort :convention :cdecl)
  ((c:void *)             ; base
   c:size_t               ; num
   c:size_t               ; width
   (c:void *))            ; compare
  (foreign-test-libc) "qsort")

(c:defun-c-callable
  c:int
  (int32-comparator :convention :cdecl) (((c:void *) elem1)
                                         ((c:void *) elem2))
  (let ((a (si:unpack-int32 (si:make-chunk 'int 4 nil elem1) 0))
        (b (si:unpack-int32 (si:make-chunk 'int 4 nil elem2) 0)))
    (cond ((= a b) 0)
          ((< a b) -1)
          (t 1))))

(deftest defun-c-callable-cdecl ()
  (flet ((unpack-int32-array (array n)
           (let (r)
             (dotimes (i n)
               (push (si:unpack-int32 array (* i 4)) r))
             (nreverse r))))
    (let* ((n 10)
           (array (si:make-chunk 'int[] (* n 4))))
      (dotimes (i n)
        (si:pack-int32 array (* i 4) (- n i)))
      (values (unpack-int32-array array n)
              (progn
                (qsort array n 4 #'int32-comparator)
                (unpack-int32-array array n)))))
  => (10 9 8 7 6 5 4 3 2 1)
  => (1 2 3 4 5 6 7 8 9 10))


;; int32

(c:define-dll-entry
  c:int
  (_atoi :convention :cdecl) ((c:void *))
  (foreign-test-libc) "atoi")

(deftest define-dll-entry-return-int32 ()
  (flet ((atoi (str)
           (_atoi (si:make-string-chunk str))))
    (values
     (atoi "0")
     (atoi "1")
     (atoi "-1")
     (atoi "2147483647")))
  => 0
  => 1
  => -1
  => #x7FFFFFFF)



;;; **`_itoa` / `_ultoa` / `_i64toa` / `_ui64toa` は msvcrt にしか無い。**
;;; POSIX では `sprintf` に書式を渡して同じことをする。テストが渡す基数は 10
;;; だけなので、そこだけ受ける。
;;;
;;; **経路は同じではない。** msvcrt 側は固定引数、POSIX 側は可変長引数として
;;; 整数が渡る。どちらも測っているのは「その幅の整数が C 側に正しく届くか」で、
;;; **符号無しの 64 ビットで最上位ビットが立っている場合**が本番である。
;;; 整数の可変長引数は POSIX でも通る (浮動小数は通らない — issue #133)。

#+unix
(defun foreign-test-sprintf-int (type fmt n chunk radix)
  (unless (eql radix 10)
    (error "基数 ~D は未対応" radix))
  (sprintf chunk (si:make-string-chunk fmt)
           (c:expand-c-vaargs (list (list type n))))
  chunk)

#-unix
(c:define-dll-entry
  (c:void *)
  (_itoa :convention :cdecl) (c:int (c:void *) c:int)
  "msvcrt")

#+unix
(defun _itoa (n chunk radix)
  (foreign-test-sprintf-int 'c:int "%d" n chunk radix))

(deftest define-dll-entry-int32-arg ()
  (flet ((itoa (n)
           (let ((c (si:make-chunk nil 30)))
             (_itoa n c 10)
             (si:unpack-string c 0))))
    (values
     (itoa 0)
     (itoa 1)
     (itoa -1)
     (itoa #x7FFFFFFF)))
  => "0"
  => "1"
  => "-1"
  => "2147483647")


;; uint32

(c:define-dll-entry
  c:u_int
  (strtoul :convention :cdecl) ((c:void *) (c:void *) c:int)
  (foreign-test-libc) "strtoul")

(deftest define-dll-entry-return-uint32 ()
  (flet ((atoi (str)
           (strtoul (si:make-string-chunk str) 0 10)))
    (values
     (atoi "0")
     (atoi "1")
     (atoi "-1")
     (atoi "2147483647")
     (atoi "4294967295")))
  => 0
  => 1
  => #xFFFFFFFF
  => #x7FFFFFFF
  => #xFFFFFFFF)

#-unix
(c:define-dll-entry
  (c:void *)
  (_ultoa :convention :cdecl) (c:u_int (c:void *) c:int)
  "msvcrt")

#+unix
(defun _ultoa (n chunk radix)
  (foreign-test-sprintf-int 'c:u_int "%u" n chunk radix))

(deftest define-dll-entry-uint32-arg ()
  (flet ((itoa (n)
           (let ((c (si:make-chunk nil 30)))
             (_ultoa n c 10)
             (si:unpack-string c 0))))
    (values
     (itoa 0)
     (itoa 1)
     (itoa -1)
     (itoa #x7FFFFFFF)
     (itoa #xFFFFFFFF)))
  => "0"
  => "1"
  => "4294967295"
  => "2147483647"
  => "4294967295")


;; int64

(c:define-dll-entry
  c:int64
  (_atoi64 :convention :cdecl) ((c:void *))
  ;; msvcrt の _atoi64 に当たるのは glibc の atoll。
  (foreign-test-libc) #+unix "atoll" #-unix "_atoi64")

(deftest define-dll-entry-return-int64 ()
  (flet ((atoi (str)
           (_atoi64 (si:make-string-chunk str))))
    (values
     (atoi "0")
     (atoi "1")
     (atoi "-1")
     (atoi "2147483647")
     (atoi "4294967295")
     (atoi "9223372036854775807")))
  => 0
  => 1
  => -1
  => #x7FFFFFFF
  => #xFFFFFFFF
  => #x7FFFFFFFFFFFFFFF)


#-unix
(c:define-dll-entry
  (c:void *)
  (_i64toa :convention :cdecl) (c:int64 (c:void *) c:int)
  "msvcrt")

#+unix
(defun _i64toa (n chunk radix)
  (foreign-test-sprintf-int 'c:int64 "%lld" n chunk radix))

(deftest define-dll-entry-int64-arg ()
  (flet ((itoa (n)
           (let ((c (si:make-chunk nil 30)))
             (_i64toa n c 10)
             (si:unpack-string c 0))))
    (values
     (itoa 0)
     (itoa 1)
     (itoa -1)
     (itoa #x7FFFFFFF)
     (itoa #xFFFFFFFF)
     (itoa #x7FFFFFFFFFFFFFFF)))
  => "0"
  => "1"
  => "-1"
  => "2147483647"
  => "4294967295"
  => "9223372036854775807")


;; u_int64

(c:define-dll-entry
  c:u_int64
  (_strtoui64 :convention :cdecl) ((c:void *) (c:void *) c:int)
  (foreign-test-libc) #+unix "strtoull" #-unix "_strtoui64")

(deftest define-dll-entry-return-uint64 ()
  (flet ((atoi (str)
           (_strtoui64 (si:make-string-chunk str) 0 10)))
    (values
     (atoi "0")
     (atoi "1")
     (atoi "-1")
     (atoi "2147483647")
     (atoi "4294967295")
     (atoi "9223372036854775807")
     (atoi "18446744073709551615")))
  => 0
  => 1
  => #xFFFFFFFFFFFFFFFF
  => #x7FFFFFFF
  => #xFFFFFFFF
  => #x7FFFFFFFFFFFFFFF
  => #xFFFFFFFFFFFFFFFF)


#-unix
(c:define-dll-entry
  (c:void *)
  (_ui64toa :convention :cdecl) (c:u_int64 (c:void *) c:int)
  "msvcrt")

#+unix
(defun _ui64toa (n chunk radix)
  (foreign-test-sprintf-int 'c:u_int64 "%llu" n chunk radix))

(deftest define-dll-entry-uint64-arg ()
  (flet ((itoa (n)
           (let ((c (si:make-chunk nil 30)))
             (_ui64toa n c 10)
             (si:unpack-string c 0))))
    (values
     (itoa 0)
     (itoa 1)
     (itoa -1)
     (itoa #x7FFFFFFF)
     (itoa #xFFFFFFFF)
     (itoa #x7FFFFFFFFFFFFFFF)
     (itoa #xFFFFFFFFFFFFFFFF)))
  => "0"
  => "1"
  => "18446744073709551615"
  => "2147483647"
  => "4294967295"
  => "9223372036854775807"
  => "18446744073709551615")


;; c:last-win32-error

(c:define-dll-entry
  c:int
  MultiByteToWideChar (c:u_int         ; code page
                       c:u_long        ; character-type options
                       (c:void *)      ; string to map
                       c:int           ; number of bytes in string
                       (c:void *)      ; wide-character buffer
                       c:int)          ; size of buffer
  "kernel32")

(deftest last-win32-error ()
  (let ((a (si:make-string-chunk "abc"))
        (u (si:make-chunk nil 9)))
    (si:clear-chunk u)
    (values
     (progn
       (setf (c:last-win32-error) 0)
       (MultiByteToWideChar 932 0
                            a (si:chunk-size a)
                            u (si:chunk-size u))
       (c:last-win32-error))
     (progn
       (setf (c:last-win32-error) 0)
       (MultiByteToWideChar 932932 0
                            a (si:chunk-size a)
                            u (si:chunk-size u))
       (c:last-win32-error))
     (progn
       (setf (c:last-win32-error) 0)
       (MultiByteToWideChar 932 0
                            a (si:chunk-size a)
                            u (si:chunk-size u))
       (c:last-win32-error))
     (progn
       (setf u (si:make-chunk nil 1))
       (setf (c:last-win32-error) 0)
       (MultiByteToWideChar 932 0
                            a (si:chunk-size a)
                            u (si:chunk-size u))
       (c:last-win32-error))
     ))
  => 0
  => 87   ; ERROR_INVALID_PARAMETER
  => 0
  => 122) ; ERROR_INSUFFICIENT_BUFFER

(c:define-dll-entry
  c:int
  GetLastError ()
  "kernel32")

(deftest last-win32-error-GetLastError ()
  (let ((a (si:make-string-chunk "abc"))
        (u (si:make-chunk nil 9)))
    (si:clear-chunk u)
    (setf (c:last-win32-error) 0)
    (MultiByteToWideChar 932932 0
                         a (si:chunk-size a)
                         u (si:chunk-size u))
    (values
     (c:last-win32-error)
     (GetLastError)))
  => 87   ; ERROR_INVALID_PARAMETER
  => 87)  ; ERROR_INVALID_PARAMETER


(c:define-dll-entry
  c:u_int64 ; ほんとは div_t だが構造体の戻り値は未サポート
  (div :convention :cdecl)
  (c:int c:int)
  (foreign-test-libc) "div")

;;; --- ハードウェア例外 ----------------------------------------------------
;;;
;;; **POSIX では走らせない。走らせるとプロセスが死ぬ。**
;;;
;;; ここは 0 除算と不正アドレスへの書き込みを起こして、それが Lisp の
;;; `win32-exception` として返ることを見るテストである。Win32 は SEH で
;;; ハードウェア例外を拾えるが、**POSIX でそれに相当するのは SIGFPE /
;;; SIGSEGV で、拾って Lisp へ戻す仕組みが無い。**
;;;
;;; 以前は `div` / `strcat` を "msvcrt" から引いていたので POSIX では
;;; `dlopen` に失敗し、「共有ライブラリを読み込めません」で*無害に*落ちて
;;; いた。ライブラリ名を直したら**本当に 0 除算が起きて、スイートごと
;;; SIGFPE で死んだ** (`run-tests.sh` が「summary が無い」と言う形で出る)。
;;;
;;; **既知失敗に載せる話ではない。** 載せても走った時点で終わりなので、
;;; 走らせない方に倒す。

#-unix
(deftest handle-divide-by-zero ()
  (flet ((unpack-div_t (div_t)
           (list (logand #xFFFF div_t)
                 (logand #xFFFF (ash div_t -32)))))
    (values
     (unpack-div_t (div 10 3))
     (handler-case
         (div 10 0)
       (win32-exception (e)
         (list (win32-exception-description e)
               (win32-exception-code e))))))
  => (3 1)
  => ("Integer divide by zero" #xc0000094))


(c:define-dll-entry
  (c:char *)
  (strcat :convention :cdecl)
  ((c:char *) (c:char *))
  (foreign-test-libc) "strcat")

#-unix
(deftest handle-access-violation ()
  (let ((c (si:make-chunk nil 5)))
    (si:clear-chunk c)
    (strcat c (si:make-string-chunk "hoge"))
    (values
     (si:unpack-string c 0)
     (handler-case
         (strcat 0 (si:make-string-chunk "fuga"))
       (win32-exception (e)
         (list (win32-exception-description e)
               (win32-exception-code e))))))
  => "hoge"
  => ("Access violation" #xc0000005))


(c:define-dll-entry
  c:int
  GetModuleHandleA ((c:void *))
  "kernel32")

#-unix
(deftest handle-access-violation-2 ()
  (handler-case
      (GetModuleHandleA 32)
    (win32-exception (e)
      (list (win32-exception-description e)
            (win32-exception-code e))))
  => ("Access violation" #xc0000005))


(c:define-dll-entry
  c:int
  (sprintf :convention :cdecl)
  ((c:char *) (c:char *) &rest)
  (foreign-test-libc) "sprintf")


(deftest expand-c-vaargs ()
  (c:expand-c-vaargs '((c:int 123)
                       (c:double 1.23)
                       (c:string 0)))
  => ((:int32 123) (:double 1.23) (#+64bit :int64 #-64bit :int32 0)))

(deftest vaargs-macro ()
  (c:c-vaargs (c:int 123)
            (c:double 1.23)
            (c:string 0))
  => ((:int32 123) (:double 1.23) (#+64bit :int64 #-64bit :int32 0)))

(c:define-c-struct INVALID_VAARGS
  (c:int a))

(deftest expand-c-vaargs-struct ()
  (handler-case
      (c:expand-c-vaargs `((INVALID_VAARGS 123)))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((INVALID_VAARGS 123))")

(deftest funcall-expand-vaargs ()
  (let ((b (si:make-chunk nil 200)))
    (values
     (sprintf b (si:make-string-chunk "foo: %d, %.3f, %s")
              (c:expand-c-vaargs `((c:int 123)
                                   (c:double 1.23)
                                   (c:string ,(si:make-string-chunk "bar")))))
     (si:unpack-string b 0)))
  => 20
  => "foo: 123, 1.230, bar")

(deftest funcall-vaargs ()
  (let ((b (si:make-chunk nil 200)))
    (values
     (sprintf b (si:make-string-chunk "foo: %d, %.3f, %s")
              (c:c-vaargs (c:int 123)
                        (c:double 1.23)
                        (c:string (si:make-string-chunk "bar"))))
     (si:unpack-string b 0)))
  => 20
  => "foo: 123, 1.230, bar")

(deftest funcall-vaargs-2 ()
  (let ((b (si:make-chunk nil 200)))
    (values
     (sprintf b (si:make-string-chunk "foo: %d, %.3f, %s")
              (append
               (c:c-vaargs (c:int 123))
               (c:c-vaargs (c:double 1.23)
                         (c:string (si:make-string-chunk "bar")))))
     (si:unpack-string b 0)))
  => 20
  => "foo: 123, 1.230, bar")

(deftest funcall-vaargs-default-argument-promotions ()
  (let ((b (si:make-chunk nil 200)))
    (values
     (sprintf b (si:make-string-chunk "foo: %d, %d, %.3f")
              (c:c-vaargs (c:char 123)
                        (c:short 123)
                        (c:float 1.23)))
     (si:unpack-string b 0)))
  => 20
  => "foo: 123, 123, 1.230")

(deftest funcall-vaargs-noarg ()
  (let ((b (si:make-chunk nil 200)))
    (values
     (sprintf b (si:make-string-chunk "foo"))
     (si:unpack-string b 0)
     (sprintf b (si:make-string-chunk "foobar") nil)
     (si:unpack-string b 0)))
  => 3
  => "foo"
  => 6
  => "foobar")

(deftest c-vaargs-invalid-vaargs-0 ()
  (handler-case
      (let ((b (si:make-chunk nil 200)))
        (sprintf b (si:make-string-chunk "foo: %d, %.3f, %d")
                 (append
                  (c:c-vaargs (c:int 123))
                  (c:c-vaargs (c:double 1.23))
                  (list 123))))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (123)")

(deftest c-vaargs-invalid-vaargs-1 ()
  (handler-case
      (c:c-vaargs 123)
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (123)")

(deftest c-vaargs-invalid-vaargs-2 ()
  (handler-case
      (c:c-vaargs (123))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((123))")

(deftest c-vaargs-invalid-vaargs-3 ()
  (handler-case
      (c:c-vaargs :int32 123)
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (:int32 123)")

(deftest c-vaargs-invalid-vaargs-4 ()
  (handler-case
      (c:c-vaargs (:int32))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:int32))")

(deftest c-vaargs-invalid-vaargs-5 ()
  (handler-case
      (c:c-vaargs (:int32 123 234))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:int32 123 234))")

(deftest c-vaargs-invalid-vaargs-6 ()
  (handler-case
      (c:c-vaargs nil (:int32 123))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (nil (:int32 123))")

(deftest c-vaargs-invalid-vaargs-7 ()
  (handler-case
      (c:c-vaargs (:void 123))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:void 123))")


(deftest funcall-invalid-vaargs-1 ()
  (handler-case
      (sprintf 0 0 123)
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: 123")

(deftest funcall-invalid-vaargs-2 ()
  (handler-case
      (sprintf 0 0 '(123))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (123)")

(deftest funcall-invalid-vaargs-3 ()
  (handler-case
      (sprintf 0 0 '(:int32 123))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (:int32 123)")

(deftest funcall-invalid-vaargs-4 ()
  (handler-case
      (sprintf 0 0 '((:int32)))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:int32))")

(deftest funcall-invalid-vaargs-5 ()
  (handler-case
      (sprintf 0 0 '((:int32 123 234)))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:int32 123 234))")

(deftest funcall-invalid-vaargs-6 ()
  (handler-case
      (sprintf 0 0 '(nil (:int32 123)))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: (nil (:int32 123))")

(deftest funcall-invalid-vaargs-7 ()
  (handler-case
      (sprintf 0 0 '((:void 123)))
    (error (c)
      (si:*condition-string c)))
  => "不正な可変長引数です: ((:void 123))")


(deftest make-c-function-stdcall-rest ()
  (handler-case
      (si:make-c-function (si:load-dll-module (foreign-test-libc))
                          "sprintf"
                          '(:int32 :int32 :int32)
                          :int32
                          :vaarg t :convention :stdcall)
    (error (c)
      (si:*condition-string c)))
  => "stdcall呼び出し規約の場合、可変長引数は利用できません")

(deftest define-dll-entry-stdcall-rest ()
  (handler-case
      (c:define-dll-entry
        c:int
        sprintf_stdcall ((c:char *) (c:char *) &rest)
        (foreign-test-libc) "sprintf")
    (error (c)
      (si:*condition-string c)))
  => "stdcall呼び出し規約の場合、可変長引数は利用できません")


(c:define-dll-entry
  c:int
  (sprintf_no_vaarg :convention :cdecl)
  ((c:char *) (c:char *))
  (foreign-test-libc) "sprintf")

(deftest funcall-invalid-c-args ()
  (sprintf_no_vaarg 0 0 '((:int32 123)))
  !! too-many-arguments)


(deftest c-size-of-premitive ()
  (values
   (c:c-size-of :void)
   (c:c-size-of :int8)
   (c:c-size-of :uint8)
   (c:c-size-of :int16)
   (c:c-size-of :uint16)
   (c:c-size-of :int32)
   (c:c-size-of :uint32)
   (c:c-size-of :int64)
   (c:c-size-of :uint64)
   (c:c-size-of :float)
   (c:c-size-of :double))
  => 0
  => 1
  => 1
  => 2
  => 2
  => 4
  => 4
  => 8
  => 8
  => 4
  => 8)

(deftest c-size-of-define-c-type ()
  (values
   (c:c-size-of c:void)
   (c:c-size-of c:char)
   (c:c-size-of c:short)
   (c:c-size-of c:int)
   (c:c-size-of c:long)
   (c:c-size-of c:int64)
   (c:c-size-of c:u_char)
   (c:c-size-of c:u_short)
   (c:c-size-of c:u_int)
   (c:c-size-of c:u_long)
   (c:c-size-of c:u_int64)
   (c:c-size-of c:float)
   (c:c-size-of c:double)

   (c:c-size-of c:wchar_t)
   (c:c-size-of c:size_t)
   (c:c-size-of c:time_t)
   (c:c-size-of c:ptrdiff_t)
   (c:c-size-of c:clock_t)
   (c:c-size-of c:off_t)

   (c:c-size-of c:void*)
   (c:c-size-of c:char*)
   (c:c-size-of c:string))
  => 0
  => 1
  => 2
  => 4
  => 4
  => 8
  => 1
  => 2
  => 4
  => 4
  => 8
  => 4
  => 8
  => 2
  => #+:64bit 8 #-:64bit 4
  => #+:64bit 8 #-:64bit 4
  => #+:64bit 8 #-:64bit 4
  => 4
  => 4
  => #+:64bit 8 #-:64bit 4
  => #+:64bit 8 #-:64bit 4
  => #+:64bit 8 #-:64bit 4)


(c:define-c-struct c-size-of-test
  (c:int a)
  (c:double a)
  (c:char a))

(deftest c-size-of-struct ()
  (values
   (c:c-size-of c-size-of-test)
   (c:c-struct-size-of c-size-of-test))
  => 20
  => 20)
