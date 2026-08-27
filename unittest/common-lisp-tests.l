(deftest cl-package ()
  (values
   (find-package :common-lisp)
   (package-name :common-lisp)
   (package-nicknames :common-lisp)
   (mapcar 'package-name (package-use-list :common-lisp))
   (member (find-package :common-lisp) (list-all-packages)))
  => non-nil
  => "common-lisp"
  => nil
  => ("lisp")
  => non-nil)

(deftest cl-user-package ()
  (values
   (find-package :cl-user)
   (find-package :common-lisp-user)
   (package-name :cl-user)
   (package-nicknames :cl-user)
   (mapcar 'package-name (package-use-list :cl-user))
   (member (find-package :cl-user) (list-all-packages)))
  => non-nil
  => non-nil
  => "common-lisp-user"
  => ("cl-user")
  => ("common-lisp" "editor")
  => non-nil)

(deftest cl-format-tilde-A ()
  (values
   (lisp:format nil "~10@A" "hoge")
   (common-lisp:format nil "~10@A" "hoge")
   (lisp:format nil "~10@A" :hoge)
   (common-lisp:format nil "~10@A" :hoge))
  => "hoge      "
  => "      hoge"
  => "      hoge"
  => "      hoge")

;; #16 Phase 2: destructuring-bind did not exist in this codebase at all
;; (it is a new implementation, not a keyword-argument fix). It is
;; implemented as a pure Lisp macro in lisp/evalmacs.l that statically
;; walks the destructuring lambda list at macro-expansion time and
;; generates let* bindings, rather than reusing the shared C++
;; lex_env::lambda_bind machinery that defmacro/macrolet depend on.
;;
;; The CLHS example from the destructuring-bind spec page.
(deftest destructuring-bind-clhs-example ()
  (destructuring-bind ((a &optional (b 'bee)) one two three)
      '((alpha) 1 2 3)
    (list a b three two one))
  => (alpha bee 3 2 1))

(deftest destructuring-bind-whole ()
  (destructuring-bind (&whole w a b) '(1 2)
    (list w a b))
  => ((1 2) 1 2))

(deftest destructuring-bind-rest-and-body-are-synonyms ()
  (values
   (destructuring-bind (a &rest r) '(1 2 3) (list a r))
   (destructuring-bind (a &body r) '(1 2 3) (list a r)))
  => (1 (2 3))
  => (1 (2 3)))

(deftest destructuring-bind-optional-default-and-supplied-p ()
  (values
   (destructuring-bind (a &optional (b 10 bp)) '(1)
     (list a b bp))
   (destructuring-bind (a &optional (b 10 bp)) '(1 2)
     (list a b bp)))
  => (1 10 nil)
  => (1 2 t))

;; &key with a plain default, a default plus supplied-p, and a
;; keyword-name override ((:w ww)).
(deftest destructuring-bind-key-default-supplied-p-override ()
  (destructuring-bind (&key x (y 20) (z 30 zp) ((:w ww) 40))
      '(:x 1 :w 4)
    (list x y z zp ww))
  => (1 20 30 nil 4))

(deftest destructuring-bind-allow-other-keys ()
  ;; This is a real cross-package identity check, not just a feature
  ;; check: &allow-other-keys is a plain Lisp-level symbol (unlike
  ;; &optional/&rest/&key/&aux/&whole/&body, which the C++ core
  ;; pre-interns as DEFLAMBDAKEY entries so they are eq everywhere
  ;; regardless of package). It only works from another package
  ;; because lisp/evalmacs.l exports it and every package here uses
  ;; "lisp". This test call is read in the common-lisp-tests.l file's
  ;; own package, not "lisp", so a missing export would make this
  ;; &allow-other-keys a distinct, non-eq symbol and silently fall
  ;; through to being parsed as an ordinary &key variable instead.
  (destructuring-bind (&key x &allow-other-keys) '(:x 1 :bogus 2)
    x)
  => 1)

(deftest destructuring-bind-unrecognized-key-errors ()
  (handler-case
      (progn (destructuring-bind (&key x) '(:x 1 :bogus 2) x)
             :no-error)
    (error () :errored))
  => :errored)

(deftest destructuring-bind-aux ()
  (destructuring-bind (a &aux (b (* a 10))) '(3)
    (list a b))
  => (3 30))

(deftest destructuring-bind-nested-key-var ()
  (destructuring-bind (&key ((:point (px py))))
      '(:point (1 2))
    (list px py))
  => (1 2))

(deftest destructuring-bind-dotted-tail ()
  (destructuring-bind (a b . c) '(1 2 3 4)
    (list a b c))
  => (1 2 (3 4)))

(deftest destructuring-bind-too-few-arguments ()
  (handler-case
      (progn (destructuring-bind (a b) '(1) (list a b))
             :no-error)
    (too-few-arguments () :errored))
  => :errored)

(deftest destructuring-bind-too-many-arguments ()
  (handler-case
      (progn (destructuring-bind (a b) '(1 2 3) (list a b))
             :no-error)
    (too-many-arguments () :errored))
  => :errored)

(deftest destructuring-bind-empty-lambda-list ()
  (destructuring-bind () nil :ok)
  => :ok)
