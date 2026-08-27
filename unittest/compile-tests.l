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

;; #16 Phase 3: 自己末尾再帰のループ化 ("poor man's TCO")。
;;
;; 一般の TCO (相互再帰・高階関数経由の末尾呼び出しも含む) には
;; VM 側の呼び出し規約変更が要りリスクが高いため対象外とした。ここで
;; 実装したのは「関数が自分自身を末尾位置で同じ引数個数で呼ぶ」場合
;; だけをコンパイラ側の変換 (引数を評価してから仮引数を束縛し直し、
;; 関数先頭 (block 確立後) へ GOTO) で扱う限定版。
;;
;; defun の展開は本体を必ず (block 関数名 ...) で包む (CLHS) ので、
;; その形と「必須引数のみのラムダリスト」が揃った場合だけが対象。
;; &optional/&rest/&key を含む場合、self-call が非末尾位置 (引数・
;; let の中など) にある場合、相互再帰の場合はすべて安全に対象外へ
;; フォールバックし、通常の INSN-CALL のまま (常に正しく動く)。
;;
;; if/progn/block だけが *tail-position-p* を伝播させる。テストが
;; 検証する「深い再帰でスタックオーバーフローしない」という結果は、
;; 挙動が正しいだけでなく実際にループへ変換されたことの直接的な証拠
;; になる (素朴な再帰では millions 回のネストは通常どの環境でも
;; 破綻する)。

(deftest compile-self-tail-call-eligible-name-basic ()
  (compiler::self-tail-call-eligible-name
   '(n acc) '((block %tco-fn (if (= n 0) acc (%tco-fn (1- n) acc)))))
  => %tco-fn)

(deftest compile-self-tail-call-eligible-name-rejects-optional ()
  (compiler::self-tail-call-eligible-name
   '(n &optional acc) '((block %tco-fn (if (= n 0) acc (%tco-fn (1- n) acc)))))
  => nil)

(deftest compile-self-tail-call-eligible-name-rejects-rest ()
  (compiler::self-tail-call-eligible-name
   '(n &rest r) '((block %tco-fn nil)))
  => nil)

(deftest compile-self-tail-call-eligible-name-rejects-multi-form-body ()
  ;; body が単一の (block ...) でなければ対象外 (defun の展開形とは
  ;; 異なる。手書きの (lambda (x) (foo) (block name ...)) 等)。
  (compiler::self-tail-call-eligible-name
   '(n) '((foo n) (block %tco-fn nil)))
  => nil)

(deftest compile-self-tail-call-eligible-name-rejects-non-block-body ()
  (compiler::self-tail-call-eligible-name '(n) '((if n n n)))
  => nil)

(deftest compile-self-tail-call-p-requires-tail-position ()
  (let ((compiler::*tail-position-p* nil)
        (compiler::*self-tail-call-tag* '(some-tag 0 nil))
        (compiler::*self-tail-call-name* '%tco-fn)
        (compiler::*self-tail-call-args* '(n acc)))
    (compiler::self-tail-call-p '%tco-fn 2))
  => nil)

(deftest compile-self-tail-call-p-requires-matching-name-and-arity ()
  (let ((compiler::*tail-position-p* t)
        (compiler::*self-tail-call-tag* '(some-tag 0 nil))
        (compiler::*self-tail-call-name* '%tco-fn)
        (compiler::*self-tail-call-args* '(n acc)))
    (values
     (and (compiler::self-tail-call-p '%tco-fn 2) t)
     (compiler::self-tail-call-p '%other-fn 2)
     (compiler::self-tail-call-p '%tco-fn 1)))
  => t
  => nil
  => nil)

;; 基本の正しさ: 末尾再帰でのアキュムレータ渡し。
;; compile は「空でない環境で定義された関数」(自由変数を持つ closure)
;; をコンパイルできない (compile.l 自身の既存の制約)。deftest の本体は
;; それ自体レキシカルな環境の中で評価されるため、そこで直接 defun する
;; と定義される関数がその環境を抱え込んでしまいコンパイルできない。
;; unittest/simple-test.l の compile-and-eval マクロや defstruct 系の
;; 既存テストと同じ理由・同じ回避策で、defun フォームを (eval '...) 越し
;; に評価してトップレベル (空) の環境で定義する。

(deftest compile-self-tail-call-accumulator-correctness ()
  (eval '(defun %tco-sum-acc (lst acc)
	   (if (null lst)
	       acc
	     (%tco-sum-acc (cdr lst) (+ acc (car lst))))))
  (compile '%tco-sum-acc)
  (%tco-sum-acc '(1 2 3 4 5) 0)
  => 15)

;; 並行代入の意味論: 後の引数式が前の仮引数の (再束縛前の) 値を
;; 参照していても正しく計算できる。(* n acc) は再束縛前の n を使う
;; 必要がある。
(deftest compile-self-tail-call-parallel-assignment ()
  (eval '(defun %tco-fact-acc (n acc)
	   (if (= n 0)
	       acc
	     (%tco-fact-acc (1- n) (* n acc)))))
  (compile '%tco-fact-acc)
  (%tco-fact-acc 10 1)
  => 3628800)

;; 本命: 素朴な再帰なら確実に破綻する深さ (数百万) でもスタック
;; オーバーフローせずに正しい値を返す。これはループへの変換が実際に
;; 発火していることの直接的な証拠。
(deftest compile-self-tail-call-deep-recursion-no-overflow ()
  (eval '(defun %tco-count-down (n)
	   (if (= n 0)
	       :done
	     (%tco-count-down (1- n)))))
  (compile '%tco-count-down)
  (%tco-count-down 3000000)
  => :done)

(deftest compile-self-tail-call-deep-recursion-accumulator ()
  (eval '(defun %tco-sum-to (n acc)
	   (if (= n 0)
	       acc
	     (%tco-sum-to (1- n) (+ acc n)))))
  (compile '%tco-sum-to)
  (%tco-sum-to 1000000 0)
  => 500000500000)

;; 非末尾の再帰呼び出しは対象外のまま (安全なフォールバック)。
;; 最適化されなくても正しく動くことだけを確認する (深くはしない)。
(deftest compile-self-tail-call-non-tail-call-still-correct ()
  (eval '(defun %tco-sum-non-tail (n)
	   (if (= n 0)
	       0
	     (+ n (%tco-sum-non-tail (1- n))))))
  (compile '%tco-sum-non-tail)
  (%tco-sum-non-tail 100)
  => 5050)

;; &optional を含む場合は対象外 (self-tail-call-eligible-name が
;; nil を返す) だが、通常の再帰として正しく動く。
(deftest compile-self-tail-call-skipped-for-optional-args ()
  (eval '(defun %tco-opt (n &optional (acc 0))
	   (if (= n 0)
	       acc
	     (%tco-opt (1- n) (+ acc n)))))
  (compile '%tco-opt)
  (%tco-opt 100)
  => 5050)

;; 自己呼び出しが引数位置 (非末尾) にある場合は対象外だが正しく動く。
(deftest compile-self-tail-call-skipped-when-call-is-an-argument ()
  (eval '(defun %tco-arg-pos (n)
	   (if (= n 0)
	       0
	     (1+ (%tco-arg-pos (1- n))))))
  (compile '%tco-arg-pos)
  (%tco-arg-pos 100)
  => 100)

;; let の中にある自己呼び出しは対象外 (動的環境を持ち越すため意図的
;; に伝播させない) だが正しく動く。
(deftest compile-self-tail-call-skipped-inside-let ()
  (eval '(defun %tco-in-let (n acc)
	   (if (= n 0)
	       acc
	     (let ((next (1- n)))
	       (%tco-in-let next (+ acc n))))))
  (compile '%tco-in-let)
  (%tco-in-let 100 0)
  => 5050)

;; 相互再帰は対象外 (名前が一致しない) だが正しく動く。
(deftest compile-self-tail-call-mutual-recursion-still-correct ()
  (eval '(defun %tco-even-p (n)
	   (if (= n 0)
	       t
	     (%tco-odd-p (1- n)))))
  (eval '(defun %tco-odd-p (n)
	   (if (= n 0)
	       nil
	     (%tco-even-p (1- n)))))
  (compile '%tco-even-p)
  (compile '%tco-odd-p)
  (values (%tco-even-p 100) (%tco-odd-p 100))
  => t
  => nil)

;; when/unless/and は if/progn へ展開されるので、その中の末尾呼び出し
;; も検出される。
(deftest compile-self-tail-call-through-when ()
  (eval '(defun %tco-when (n acc)
	   (when t
	     (if (= n 0)
		 acc
	       (%tco-when (1- n) (+ acc n))))))
  (compile '%tco-when)
  (%tco-when 1000000 0)
  => 500000500000)

(deftest compile-self-tail-call-through-unless ()
  ;; unless 自体が (if の then 分岐として) 関数の末尾位置にあり、かつ
  ;; unless の中の自己呼び出しがその唯一のフォーム (= unless 自身の
  ;; 末尾位置) である場合にだけ検出される。
  (eval '(defun %tco-unless (n acc)
	   (if (= n 0)
	       acc
	     (unless nil
	       (%tco-unless (1- n) (+ acc n))))))
  (compile '%tco-unless)
  (%tco-unless 1000000 0)
  => 500000500000)

(deftest compile-self-tail-call-through-and ()
  (eval '(defun %tco-and (n acc)
	   (if (= n 0)
	       acc
	     (and t (%tco-and (1- n) (+ acc n))))))
  (compile '%tco-and)
  (%tco-and 1000000 0)
  => 500000500000)
