;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(deftest test-print-debug-output-stream ()
  (string-match "debug-output-stream" (format nil "~A" *debug-output*))
  => non-nil)

(deftest test-output-debug-string-error-nil ()
  (si:output-debug-string nil)
  !! type-error)

(deftest test-output-debug-string-error-number ()
  (si:output-debug-string 123)
  !! type-error)

(deftest test-output-debug-string-error-symbol ()
  (si:output-debug-string :123)
  !! type-error)

(deftest write-debug-output-stream ()
  ;; メッセージの確認ができないので出力するだけ
  (si:output-debug-string "write-debug-output-stream")
  (si:output-debug-string "a")
  (si:output-debug-string "")
  (si:output-debug-string "write-debug-output-stream: ~A" :fuga)
  (format *debug-output* "write-debug-output-stream")
  (format *debug-output* "write-debug-output-stream: ~A" :fuga)
  (write-char #\a *debug-output*)
  (write-char #\NUL *debug-output*)
  (let ((*standard-output* *debug-output*))
    (format t "write-debug-output-stream"))
  nil
  => nil)

(deftest test-debug-output-stream-p ()
  (values
   (debug-output-stream-p *debug-output*)
   (debug-output-stream-p *status-window*)
   (let ((*standard-output* *debug-output*))
     (debug-output-stream-p *standard-output*)))
  => t
  => nil
  => t)

;;; princ で文字を 1 個出すと 0xFF を超える部分が落ちていた。
;;;
;;; StrBuf::add には add(ucs4_t) と add(int) があり、add(int) は
;;; 「add('x') のような char リテラルを byte として足す」ために
;;; & 0xff でマスクする。lprint.cc の print_char が受け取るのは
;;; Char (= u_int16_t) なので、整数拡張で u_int16_t -> int が選ばれ、
;;; U+5E73 (平) が 0x73 ('s') に化けていた。
;;;
;;; 文字列を丸ごと出す print_string は ucs4_t で回していて無事だったので、
;;; (princ "平成") は正しく、(princ (char "平成" 0)) だけが壊れるという
;;; 見つけにくい形になっていた。
(deftest princ-char-above-latin1 ()
  "princ が 1 文字出力で 0xFF を超える文字を切り捨てない"
  (values (princ-to-string (char "平成" 0))
          (princ-to-string (char "令和" 0))
          (princ-to-string (svref "月火水木金土日" 0))
          (with-output-to-string (s)
            (princ (char "昭和" 0) s)))
  => "平"
  => "令"
  => "月"
  => "昭")
