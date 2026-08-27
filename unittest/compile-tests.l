;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;; #16 Phase 3: lisp/compile.l のバイトコード最適化パスのテスト。
;;; optimize-null-if-goto は NULL/NOT の直後に続く条件ジャンプを検出し、
;;; NULL/NOT の呼び出し自体を消してジャンプの向きを反転させる。
;;; ただし対象は -AND-POP 系 (3引数 if・when・unless などで使われる) の
;;; ジャンプ命令だけであり、-AND-POP でない IF-NIL-GOTO/IF-NON-NIL-GOTO
;;; (2引数 if 専用) には適用してはいけない。後者はジャンプ時にテスト値
;;; そのものを if の戻り値として残す設計のため、テスト対象を NULL/NOT の
;;; 結果から元の値へすり替えると戻り値の意味が変わってしまう。
;;; 以下は主にその境界条件 (2引数 if で条件が偽になる経路) を固定する
;;; 回帰テストであり、それ以外は最適化の有無に関わらず成立すべき
;;; 通常の意味論の確認である。
;;;
;;; "compiler" パッケージ (insn-call 等の内部シンボルが属する) は
;;; lisp/compile.l が autoload で実際にロードされるまで存在しない。
;;; このファイルの後半で compiler:: 修飾シンボルをリーダーが読める
;;; ようにするため、ここで明示的に読み込んでおく。
(require "compile")

(deftest compile-2-arg-if-null-false-path ()
  ;; (if (null x) then) は x が non-nil (条件偽) のとき NIL を返す
  ;; べきで、x 自身を返してはいけない。
  (let ((f (compile nil '(lambda (x) (if (null x) 'yes)))))
    (funcall f 5))
  => nil)

(deftest compile-2-arg-if-not-false-path ()
  (let ((f (compile nil '(lambda (x) (if (not x) 'yes)))))
    (funcall f 5))
  => nil)

(deftest compile-2-arg-if-null-true-path ()
  (let ((f (compile nil '(lambda (x) (if (null x) 'yes)))))
    (funcall f nil))
  => yes)

(deftest compile-2-arg-if-null-false-path-non-symbol-value ()
  ;; 戻り値がすり替わるバグは特に x が truthy な非シンボル値のときに
  ;; 顕在化しやすい (NIL と誤認しにくい値)。
  (let ((f (compile nil '(lambda (x) (if (null x) 'yes)))))
    (funcall f "not-nil"))
  => nil)

(deftest compile-3-arg-if-null ()
  (let ((f (compile nil '(lambda (x) (if (null x) 'yes 'no)))))
    (values (funcall f nil) (funcall f 5)))
  => yes
  => no)

(deftest compile-3-arg-if-not ()
  (let ((f (compile nil '(lambda (x) (if (not x) 'yes 'no)))))
    (values (funcall f nil) (funcall f 5)))
  => yes
  => no)

(deftest compile-when-null ()
  (let ((f (compile nil '(lambda (x) (when (null x) 'yes)))))
    (values (funcall f nil) (funcall f 5)))
  => yes
  => nil)

(deftest compile-unless-not-null ()
  (let ((f (compile nil '(lambda (x) (unless (null x) 'yes)))))
    (values (funcall f nil) (funcall f 5)))
  => nil
  => yes)

(deftest compile-unless-plain ()
  ;; unless の条件式自体が NOT を経由しないケースも念のため確認する。
  (let ((f (compile nil '(lambda (x) (unless x 'yes)))))
    (values (funcall f nil) (funcall f 5)))
  => yes
  => nil)

;; ここから下は上の振る舞いテストが実際に融合パスを経由していることを
;; 直接確認するホワイトボックステスト。挙動が正しいだけでは、そもそも
;; optimize-null-if-goto が一度も発火していなくても (元の NULL-call を
;; 経由する遅いコードのままでも) 通ってしまうため、insn 列そのものへの
;; 変換を検証する。

;; insn-call/insn-if-nil-goto(-and-pop)/optimize-null-if-goto 等は
;; "compiler" パッケージ (lisp/compile.l が (in-package "compiler") して
;; いる) の非 export シンボル。パッケージ修飾なしで書くと "compiler" を
;; :use していないこのファイルでは全く別のシンボルが新たに interne
;; されてしまい、optimize-null-if-goto 内の eq 比較が黙って不一致になる
;; (エラーにはならず、素通りするだけ)。そのため insn タグと
;; optimize-null-if-goto 自体は compiler:: で明示的に修飾する。
;; null/consp は "compiler" が :use している "lisp" の外部シンボルなので
;; 素のシンボル参照で問題ない。ラベル (l1 相当) は eq 比較の対象では
;; ないのでそのままでよい。

(deftest compile-null-if-goto-fusion-fires ()
  (compiler::optimize-null-if-goto
   (list (list 'compiler::insn-call 'null 1)
         (list 'compiler::insn-if-nil-goto-and-pop 'l1)))
  => ((compiler::insn-if-non-nil-goto-and-pop l1)))

(deftest compile-null-if-goto-fusion-fires-reverse ()
  (compiler::optimize-null-if-goto
   (list (list 'compiler::insn-call 'null 1)
         (list 'compiler::insn-if-non-nil-goto-and-pop 'l1)))
  => ((compiler::insn-if-nil-goto-and-pop l1)))

(deftest compile-null-if-goto-fusion-skips-non-and-pop ()
  ;; -AND-POP でないジャンプには適用してはいけない (戻り値の意味が
  ;; 変わってしまうため)。insn 列は変更されずそのまま返る。
  (compiler::optimize-null-if-goto
   (list (list 'compiler::insn-call 'null 1)
         (list 'compiler::insn-if-nil-goto 'l1)))
  => ((compiler::insn-call null 1) (compiler::insn-if-nil-goto l1)))

(deftest compile-null-if-goto-fusion-skips-unrelated-call ()
  (compiler::optimize-null-if-goto
   (list (list 'compiler::insn-call 'consp 1)
         (list 'compiler::insn-if-nil-goto-and-pop 'l1)))
  => ((compiler::insn-call consp 1) (compiler::insn-if-nil-goto-and-pop l1)))
