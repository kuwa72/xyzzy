;;; -*- Mode: Lisp; Package: LISP; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setq *package* (find-package "lisp")))

(export '(not rest))
(export '(mapcan mapcon))
(export '(values multiple-value-list))
(export '(*gensym-counter* gensym gentemp))
(export '(defmacro defun defvar defparameter defconstant do* psetq do dolist dotimes
	  while prog prog* cond case when unless return loop and or prog1 prog2
	  nth-value destructuring-bind &allow-other-keys
	  lambda-list-keywords type otherwise))
(export '(*modules* require provide modulep featurep mc-require))

(si:*fset 'defmacro
	  '(macro (name (&rest lambda-list) &body body)
	    `(si:*fset ',name '(macro ,lambda-list ,@body))))

(defmacro defun (name (&rest lambda-list) &body body)
  `(let ()
     (si:*fset ',name
	       (si:*set-function-name
		#'(lambda ,lambda-list ,@body)
		',name))))

(defmacro defvar (name &optional (initial-value nil sv) doc)
  `(progn
     (si:*make-special ',name)
     ,(if doc
	  `(si:*putprop ',name ,doc 'variable-documentation))
     ,(if sv
	  `(or (boundp ',name)
	       (set ',name ,initial-value)))
     ',name))

(defmacro defparameter (name value &optional doc)
  `(progn
     (si:*make-special ',name)
     (set ',name ,value)
     ,(if doc
	  `(si:*putprop ',name ,doc 'variable-documentation))
     ',name))

(defmacro defconstant (name value &optional doc)
  `(progn
     (if (not (constantp ',name))
	 (set ',name ,value))
     (si:*make-constant ',name)
     ,(if doc
	  `(si:*putprop ',name ,doc 'variable-documentation))
     ',name))

(si:*fset 'not #'null)
(si:*fset 'rest #'cdr)

(defun mapcan (fn lists &rest more-lists)
  (apply #'nconc (apply #'mapcar fn lists more-lists)))

(defun mapcon (fn lists &rest more-lists)
  (apply #'nconc (apply #'maplist fn lists more-lists)))

(defun values (&rest args)
  (values-list args))

(defmacro multiple-value-list (form)
  `(multiple-value-call #'list ,form))

;;;(defmacro multiple-value-setq (vars form)
;;;  (do ((vl vars (cdr vl))
;;;       (set-forms '())
;;;       (syms (gensym))
;;;       (n 0 (+ n 1)))
;;;      ((endp vl)
;;;       `(let ((,syms (multiple-value-list ,form)))
;;;	  ,@set-forms))
;;;    (setq set-forms (cons `(setq ,(car vl) (nth ,n ,syms)) set-forms))))

;;;(defmacro multiple-value-bind ((&rest vars) values-form &rest form)
;;;  (do ((vl vars (cdr vl))
;;;       (bind-forms '())
;;;       (syms (gensym))
;;;       (n 0 (+ n 1)))
;;;      ((endp vl)
;;;       `(let* ((,syms (multiple-value-list ,values-form)) ,@(nreverse bind-forms))
;;;	  ,@form))
;;;    (setq bind-forms (cons `(,(car vl) (nth ,n ,syms)) bind-forms))))

(defmacro when (test &body body)
  `(if ,test
       (progn ,@body)))

(defmacro unless (test &body body)
  `(if (not ,test)
       (progn ,@body)))

(defmacro return (&optional result)
  `(return-from nil ,result))

(defmacro loop (&body body)
  `(block nil
     (tagbody
       #1=#:loop
       (progn ,@body)
       (go #1#))))

(defmacro *loop (&body body)
  `(block nil
     (tagbody
       #1=#:loop
       (progn ,@body)
       (go #1#))))

(defmacro and (&rest forms)
  (if forms
      (let* ((forms (reverse forms))
	     (newform (car forms)))
	(*loop
	 (setq forms (cdr forms))
	 (if (null forms)
	     (return newform))
	 (setq newform `(if ,(car forms) ,newform))))
    't))

(defmacro or (&rest forms)
  (let* ((forms (reverse forms))
	 (newform (car forms)))
    (*loop
      (setq forms (cdr forms))
      (if (null forms)
	  (return `(let (#1=#:tem) ,newform)))
      (setq newform `(if (setq #1# ,(car forms)) #1# ,newform)))))

(defmacro prog1 (first &body body)
  `(let ((#1=#:result ,first))
     (progn ,@body)
     #1#))

(defmacro prog2 (first second &body body)
  `(progn
     ,first
     (prog1
	 ,second
       ,@body)))

(defvar *gensym-counter* 1)

(defun gensym (&optional x)
  (make-symbol (format nil "~A~D"
		       (if (stringp x) x "G")
		       (if (integerp x)
			   x
			 (prog1
			     *gensym-counter*
			   (setq *gensym-counter* (+ *gensym-counter* 1)))))))

(let ((counter 1))
  (defun gentemp (&optional (prefix "T") (package *package*))
    (*loop
     (multiple-value-bind (s f)
	 (intern (format nil "~A~D" prefix counter) package)
       (setq counter (+ counter 1))
       (unless f
	 (return s))))))

(defun find-declaration (body)
  (let ((decl '())
	(new-body '())
	(form nil)
	(intr-p nil)
	(doc-p nil)
	(body-p nil))
    (*loop
      (unless body (return))
      (setq form (car body)
	    body (cdr body))
      (if (and (consp form)
	       (eq (car form) 'declare))
	  (progn
	    (when body-p
	      (error "不正な declare です: ~S" form))
	    (setq decl (cons form decl)))
	(if (and (not intr-p)
		 (consp form)
		 (eq (car form) 'editor:interactive))
	    (progn
	      (setq new-body (cons form new-body))
	      (setq intr-p t))
	  (if (and (not doc-p)
		   (stringp form)
		   (find-if #'(lambda (e) (not (eq (safe-car e) 'declare))) body))
	      (progn
		(setq new-body (cons form new-body))
		(setq doc-p t))
	    (progn
	      (setq new-body (cons form new-body))
	      (setq body-p t))))))
    (values (if decl
		(list (cons 'declare
			    (apply #'append
				   (mapcar #'cdr (nreverse decl)))))
	      nil)
	    (nreverse new-body))))

(defun find-documentation (body)
  (*loop
    (if (or (endp body)
	    (endp (cdr body)))
	(return 'nil))
    (let ((form (car body)))
      (if (stringp form)
	  (return form))
      (if (and (consp form)
	       (eq (car form) 'declare))
	  (setq body (cdr body))
	(return 'nil)))))

(defun find-interactive (body)
  (if (endp body)
      (values nil body)
    (if (and (consp (car body))
	     (eq (car (car body)) 'editor:interactive))
	(values (list (car body)) (cdr body))
      (if (and (stringp (car body))
	       (not (endp (cdr body)))
	       (consp (car (cdr body)))
	       (eq (car (car (cdr body))) 'editor:interactive))
	  (values (list (car (cdr body))) (cons (car body) (cdr (cdr body))))
	(values nil body)))))

(defmacro defmacro (name (&rest lambda-list) &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    (let ((doc (find-documentation body)))
      `(progn
	 ,(if doc
	      `(si:*putprop ',name ,doc 'function-documentation))
	 (si:*fset ',name '(macro ,lambda-list ,@decl (block ,name ,@body)))))))

(defmacro lambda (&whole form &rest bvl-decls-and-body)
  `#',form)

(defmacro defun (name (&rest lambda-list) &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    (multiple-value-bind (intr body)
	(find-interactive body)
      (let ((doc (find-documentation body)))
	`(let ()
	   ,(if doc
		`(si:*putprop ',name ,doc 'function-documentation)
	      `(remprop ',name 'function-documentation))
	   (si:*fset ',name
		     (si:*set-function-name
		      #'(lambda ,lambda-list ,@decl ,@intr
			  (block ,name ,@body))
		      ',name)))))))

(defmacro do* ((&rest varlist)
	       (&optional end-test &rest result)
	       &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    `(block nil
       (let* ,(mapcar #'(lambda (x) (list (car x) (cadr x))) varlist)
	 ,@decl
	 (*loop
	   (if ,end-test
	     (return (progn ,@result)))
	   (tagbody ,@body)
	   (setq ,@(mapcan #'(lambda (x)
			      (if (consp (cddr x)) (list (car x) (caddr x)) 'nil))
			   varlist)))))))

(defmacro psetq (&rest args)
  (do* ((l args (cddr l))
	(bindings '())
	(forms '(nil)))
      ((endp l)
       `(let* ,(nreverse bindings) ,@forms))
    (let ((var (gensym)))
      (setq bindings (cons `(,var ,(cadr l)) bindings))
      (setq forms (cons `(setq ,(car l) ,var) forms)))))

(defmacro do ((&rest varlist)
	      (&optional end-test &rest result)
	      &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    `(block nil
       (let ,(mapcar #'(lambda (x) (list (car x) (cadr x))) varlist)
	 ,@decl
	 (*loop
	   (if ,end-test
	     (return (progn ,@result)))
	   (tagbody ,@body)
	   (psetq ,@(mapcan #'(lambda (x)
			       (if (consp (cddr x)) (list (car x) (caddr x)) 'nil))
			    varlist)))))))

(defmacro dolist ((var listform &optional (resultform ''nil)) &body body)
  `(do* ((#1=#:tailvar ,listform (cdr #1#))
	 (,var (car #1#) (car #1#)))
       ((null #1#) ,resultform)
     ,@body))

(defmacro dotimes ((var countform &optional (resultform ''nil)) &body body)
  `(do* ((,var 0 (+ ,var 1))
	 (#1=#:count ,countform))
       ((>= ,var #1#) ,resultform)
     ,@body))

(defmacro while (test &body body)
  `(do ()
       ((not ,test))
     ,@body))

(defmacro prog (varlist &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    `(block nil
       (let ,varlist
	 ,@decl
	 (tagbody ,@body)))))

(defmacro prog* (varlist &body body)
  (multiple-value-bind (decl body)
      (find-declaration body)
    `(block nil
       (let* ,varlist
	 ,@decl
	 (tagbody ,@body)))))

(defmacro cond (&rest forms)
  (let ((newform '()))
    (dolist (f (reverse forms))
      (if (endp (cdr f))
	  (if (eq (car f) 't)
	      (setq newform 't)
	    (setq newform `(let ((#1=#:tem ,(car f)))
			     (if #1# #1# ,newform))))
	(if (eq (car f) 't)
	    (setq newform (if (endp (cddr f))
			      (cadr f)
			    `(progn ,@(cdr f))))
	  (setq newform (if (endp (cddr f))
			    `(if ,(car f) ,(cadr f) ,newform)
			  `(if ,(car f) (progn ,@(cdr f)) ,newform))))))
    newform))

(defmacro case (keyform &rest forms)
  (let ((newform '()))
    (dolist (f (reverse forms) `(let ((#1=#:key ,keyform)) ,newform))
      (cond ((or (eq (car f) 't)
		 (eq (car f) 'otherwise))
	     (setq newform `(progn ,@(cdr f))))
	    ((consp (car f))
	     (if (endp (cdar f))
		 (setq newform `(if (eql #1# ',(caar f))
				    (progn ,@(cdr f))
				  ,newform))
	       (setq newform `(if (member #1# ',(car f))
				  (progn ,@(cdr f))
				,newform))))
	    ((car f)
	     (setq newform `(if (eql #1# ',(car f))
				(progn ,@(cdr f))
			      ,newform)))))))

(defmacro nth-value (n form)
  `(let ((#1=#:n ,n))
     (check-type #1# (integer 0 *))
     (nth #1# (multiple-value-list ,form))))

;;;; destructuring-bind
;;;
;;; #16 Phase 2: xyzzy にはこれまで destructuring-bind が無かった。
;;; 破壊束縛ラムダリストの解析自体は lex_env::lambda_bind
;;; (macro_level=1, src/core/lex.cc) がマクロ呼び出しの構文形に対しては
;;; &whole・入れ子パターンを含めて既に正しく実装しているが、それは
;;; 未評価の呼び出しフォームを破壊する経路であり、destructuring-bind
;;; のように評価済みの値を破壊する用途とは前提が異なる。一方 lambda
;;; (funcall_lambda, macro_level=0) は &whole と入れ子パターンを明示的
;;; に禁止している。どちらの既存経路も転用できないため、
;;; destructuring-bind は独立した Lisp マクロとして一から実装する。
;;; ラムダリストをマクロ展開時に静的に解析し対応する let* 束縛節を
;;; 生成するだけなので、defmacro/macrolet 等すべてのマクロ定義の土台
;;; である C++ 側の共有破壊束縛機構には一切触れない。
;;;
;;; push/pop/member 等の setf.l/builtin.l 由来のマクロはこのファイル
;;; (evalmacs.l) 自身のコンパイル時点ではまだ使えないため使わない
;;; (member 等 C++ 組み込み関数自体は defun-builtin の有無に関係なく
;;; 常に呼べる。避けているのは Lisp マクロとして setf.l で定義される
;;; push/pop のみ)。

;; &key の1要素 SPEC を分解し
;; (values キーワード名 変数 デフォルト値 supplied-p用の変数) を返す。
;;
;; 先頭を文字列リテラル (docstring) にしないこと: find-declaration
;; (defun/defmacro が展開時に必ず呼ぶ) は本体の先頭が文字列だと
;; docstring 判定のため safe-car を呼ぶが、safe-car は list.l 側の
;; 関数でこのファイル (evalmacs.l) の読み込み時点ではまだ定義されて
;; いない。実際にこれで一度ブートストラップが壊れて踏んだ。
(defun destructuring-bind-key-spec (spec)
  (if (symbolp spec)
      (values (intern (symbol-name spec) "keyword") spec nil nil)
    (let ((name (car spec)))
      (if (consp name)
	  (values (car name) (cadr name) (cadr spec) (caddr spec))
	(values (intern (symbol-name name) "keyword") name (cadr spec) (caddr spec))))))

;; 破壊束縛ラムダリスト PATTERN を、リストを保持するシンボルまたは
;; フォーム LIST-FORM に対して破壊するための let* 束縛節のリストを
;; 返す。PATTERN の各変数位置には (destructuring-bind 自身と同じく)
;; 入れ子のパターンを書ける。(docstring を避ける理由は上と同じ)
(defun destructuring-bind-clauses (pattern list-form)
  (let ((clauses nil)
	(rest (gensym "DSTR-REST"))
	(state :required)
	(saw-rest-or-key nil)
	(saw-key nil)
	(allow-other-keys nil)
	(key-keywords nil))
    (labels ((add (var form)
	       (setq clauses (cons (list var form) clauses)))
	     (splice (cs)
	       (dolist (c cs)
		 (setq clauses (cons c clauses))))
	     (bind (var form)
	       (if (consp var)
		   (let ((tmp (gensym "DSTR-SUB")))
		     (add tmp form)
		     (splice (destructuring-bind-clauses var tmp)))
		 (add var form))))
      (add rest list-form)
      (when (and (consp pattern) (eq (car pattern) '&whole))
	(bind (cadr pattern) rest)
	(setq pattern (cddr pattern)))
      (*loop
	(when (null pattern) (return))
	(unless (consp pattern)
	  ;; ドット対 (a b . tail): 残りを &rest 相当として扱う。
	  (bind pattern rest)
	  (setq saw-rest-or-key t)
	  (setq pattern nil)
	  (return))
	(let ((x (car pattern)))
	  (cond
	   ((eq x '&optional)
	    (setq state :optional)
	    (setq pattern (cdr pattern)))
	   ((or (eq x '&rest) (eq x '&body))
	    (setq state :rest saw-rest-or-key t)
	    (setq pattern (cdr pattern)))
	   ((eq x '&key)
	    (setq state :key saw-rest-or-key t saw-key t)
	    (setq pattern (cdr pattern)))
	   ((eq x '&allow-other-keys)
	    (setq allow-other-keys t)
	    (setq pattern (cdr pattern)))
	   ((eq x '&aux)
	    (setq state :aux)
	    (setq pattern (cdr pattern)))
	   (t
	    (case state
	      (:required
	       (bind x `(if (consp ,rest)
			    (car ,rest)
			  (error 'too-few-arguments)))
	       (add rest `(cdr ,rest))
	       (setq pattern (cdr pattern)))
	      (:optional
	       (multiple-value-bind (var default supplied-p)
		   (if (consp x)
		       (values (car x) (cadr x) (caddr x))
		     (values x nil nil))
		 (let ((sp (gensym "DSTR-SUPPLIEDP")))
		   (add sp `(consp ,rest))
		   (bind var `(if ,sp (car ,rest) ,default))
		   (when supplied-p (add supplied-p sp))
		   (add rest `(if ,sp (cdr ,rest) ,rest))))
	       (setq pattern (cdr pattern)))
	      (:rest
	       (bind x rest)
	       (setq pattern (cdr pattern)))
	      (:key
	       (multiple-value-bind (keyword var default supplied-p)
		   (destructuring-bind-key-spec x)
		 (setq key-keywords (cons keyword key-keywords))
		 (let ((sp (gensym "DSTR-SUPPLIEDP"))
		       (marker (gensym "DSTR-NOT-FOUND")))
		   (add sp `(getf ,rest ,keyword ',marker))
		   (bind var `(if (eq ,sp ',marker) ,default ,sp))
		   (when supplied-p
		     (add supplied-p `(not (eq ,sp ',marker))))))
	       (setq pattern (cdr pattern)))
	      (:aux
	       (if (consp x)
		   (bind (car x) (cadr x))
		 (bind x nil))
	       (setq pattern (cdr pattern)))
	      (t
	       (error "不正な破壊束縛ラムダリストです: ~S" x)))))))
      (cond
       (saw-key
	(unless allow-other-keys
	  (add (gensym "DSTR-CHECK-KEYS")
	       `(do ((%p ,rest (cddr %p)))
		    ((null %p))
		  (unless (member (car %p) ',key-keywords)
		    (error "認識できないキーワード引数です: ~S" (car %p)))))))
       ((not saw-rest-or-key)
	(add (gensym "DSTR-CHECK-EXTRA")
	     `(when (consp ,rest) (error 'too-many-arguments))))))
    (nreverse clauses)))

(defmacro destructuring-bind (lambda-list expr &body body)
  (multiple-value-bind (decl body) (find-declaration body)
    (let ((whole (gensym "DESTRUCTURING-BIND")))
      `(let* ((,whole ,expr)
	      ,@(destructuring-bind-clauses lambda-list whole))
	 ,@decl
	 ,@body))))

(defconstant lambda-list-keywords
  '(&optional &rest &key &aux &body &whole &environment &allow-other-keys))

(defun si::*flet-helper (name body macro-p)
  (let ((lambda-list (car body)))
    (multiple-value-bind (decl body)
	(find-declaration (cdr body))
      (if macro-p
	  `(macro ,lambda-list ,@decl (block ,name ,@body))
	(multiple-value-bind (intr body)
	    (find-interactive body)
	  `(lambda ,lambda-list ,@decl ,@intr (block ,name ,@body)))))))

(defvar *modules* nil)

(defun provide (module-name)
  (setq module-name (string module-name))
  (unless (member module-name *modules* :test #'string=)
    (setq *modules* (cons module-name *modules*))))

(defun require (module-name &optional pathname)
  (setq module-name (string module-name))
  (unless (member module-name *modules* :test #'string=)
    (si:*load-library (or pathname module-name))))

(defun mc-require (module-name &optional pathname)
  (setq module-name (string module-name))
  (unless (member module-name *modules* :test #'string=)
    (mc-load-library (or pathname module-name))))

(defun modulep (module-name)
  (member (string module-name) *modules* :test #'string=))

(defun featurep (feature)
  (member feature *features* :test #'eq))

(provide "evalmacs")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (setq *package* (find-package "editor")))

(export '(lisp-indent-hook lisp-indent-handler))
