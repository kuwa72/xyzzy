;;; -*- Mode: Lisp; Package: BENCHMARK; Encoding: utf-8 -*-
;;; #16 Phase 3: パフォーマンスベンチマークスイート。
;;;
;;; lisp/compile.l の最適化パス (定数畳み込み、SET/REF/DISCARD 系の
;;; 命令フュージョン、NULL/NOT-IF-GOTO-AND-POP 融合など) の効果を
;;; 定量的に比較するための最小限のマイクロベンチマーク集。
;;; コンパイル済み関数の実行時間だけを計測する (コンパイル自体の時間は
;;; 対象外)。最適化を変更する前後でこのスイートを走らせ、
;;; ここに出た数字の変化を確認する用途を想定している。
;;;
;;; Usage (GUI/対話):
;;;   (require "benchmark") (benchmark:run-all)
;;;
;;; Usage (バッチ):
;;;   tools/x wine x86_64 -q -load misc/benchmark-batch.l
;;;   (misc/benchmark-batch.l から require される)

(provide "benchmark")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "compile"))

(defpackage "benchmark"
  (:use "lisp"))

(in-package "benchmark")
(export '(run-all define-benchmark))

(defvar *benchmarks* nil
  "(NAME . THUNK) のリスト。定義順を保つため push ではなく末尾に追加する。")

(defmacro define-benchmark (name lambda-list &body body)
  "NAME という名前のベンチマークを登録する。BODY は #'compile されたクロージャとして実行される。"
  `(setq *benchmarks*
         (append (remove ',name *benchmarks* :key #'car)
                 (list (cons ',name (compile nil '(lambda ,lambda-list ,@body)))))))

(defun run-one (name thunk &optional (repeat 1))
  (let ((start (get-internal-real-time)))
    (dotimes (i repeat)
      (funcall thunk))
    (let ((elapsed (- (get-internal-real-time) start)))
      ;; Wine のコンソールでは日本語が文字化けすることがあるため、
      ;; このメッセージはあえて ASCII のみにする。
      (format t "~&~A: ~D msec total, ~D run(s), ~,3F msec/run~%"
              name elapsed repeat (/ (float elapsed) repeat)))))

(defun run-all ()
  "登録済みの全ベンチマークを1回ずつ実行して所要時間を表示する。"
  (dolist (b *benchmarks*)
    (run-one (car b) (cdr b))))

;;; 素朴な (末尾呼び出しではない) 再帰。関数呼び出しオーバーヘッドの
;;; 比重が大きいケース。将来 TCO を実装する場合はここに深い再帰版も
;;; 追加できる。
(define-benchmark fib-recursive ()
  (labels ((fib (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))))
    (fib 24)))

;;; cons/GC 負荷が主体のベンチマーク。
(define-benchmark list-building ()
  (let ((l nil))
    (dotimes (i 100000)
      (push i l))
    (length l)))

;;; mapcar/reduce 等、シーケンス関数呼び出しのオーバーヘッド。
;;; xyzzy 標準の loadup には拡張 loop (cmu_loop.l, for/collect 構文) が
;;; 含まれず、evalmacs.l の単純な loop (無条件 tagbody ループ) しか
;;; 有効でないため、ここでは意図的に loop for/collect を使わない。
(define-benchmark sequence-ops ()
  (let ((l nil))
    (dotimes (i 10000)
      (push (1+ i) l))
    (reduce #'+ (mapcar #'(lambda (x) (* x x)) (remove-if #'oddp l)))))

;;; 文字列連結・format のオーバーヘッド。
(define-benchmark string-building ()
  (with-output-to-string (s)
    (dotimes (i 5000)
      (format s "~D," i))))

;;; NULL/NOT を条件に使う分岐が主体のベンチマーク。
;;; optimize-null-if-goto (NULL/NOT - IF-NIL-GOTO-AND-POP 融合) が
;;; 対象にする形の条件分岐をタイトなループで多数回実行し、この最適化
;;; の有無による差が見えやすいよう作ってある。
(define-benchmark null-heavy-branching ()
  (let ((count 0))
    (dotimes (i 2000000)
      (let ((x (if (evenp i) nil i)))
        (when (null x)
          (incf count))
        (unless x
          (incf count))
        (if (not x) (incf count) (decf count))))
    count))
