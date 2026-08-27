(deftest wait-object-typep ()
  (values
   (typep (si:*create-wait-object) 'wait-object)
   (typep nil 'wait-object)
   (typep 0 'wait-object)
   (typep "" 'wait-object))
  => t
  => nil
  => nil
  => nil)

(deftest wait-object-check-type-1 ()
  (check-type (si:*create-wait-object) wait-object)
  => nil)

(deftest wait-object-check-type-2 ()
  (check-type "" wait-object)
  !! type-error)


(deftest char-encoding-typep ()
  (values
   (typep *encoding-sjis* 'char-encoding)
   (typep nil 'char-encoding)
   (typep 0 'char-encoding)
   (typep "" 'char-encoding))
  => t
  => nil
  => nil
  => nil)

(deftest char-encoding-check-type-1 ()
  (check-type *encoding-sjis* char-encoding)
  => nil)

(deftest char-encoding-check-type-2 ()
  (check-type "" char-encoding)
  !! type-error)


(deftest structure-definition-typep ()
  (values
   (typep (defstruct structure-definition-typep)
          'si:structure-definition)
   (typep nil 'si:structure-definition)
   (typep 0 'si:structure-definition)
   (typep "" 'si:structure-definition))
  => t
  => nil
  => nil
  => nil)

(deftest structure-definition-check-type-1 ()
  (check-type (defstruct structure-definition-check-type-1)
              si:structure-definition)
  => nil)

(deftest structure-definition-check-type-2 ()
  (check-type "" si:structure-definition)
  !! type-error)


(deftest dll-module-p ()
  (values
   (si:*dll-module-p (si:load-dll-module "msvcrt"))
   (si:*dll-module-p nil)
   (si:*dll-module-p 0)
   (si:*dll-module-p ""))
  => t
  => nil
  => nil
  => nil)

(deftest dll-module-typep ()
  (values
   (typep (si:load-dll-module "msvcrt")
          'si:dll-module)
   (typep nil 'si:dll-module)
   (typep 0 'si:dll-module)
   (typep "" 'si:dll-module))
  => t
  => nil
  => nil
  => nil)

(deftest dll-module-check-type-1 ()
  (check-type (si:load-dll-module "msvcrt")
              si:dll-module)
  => nil)

(deftest dll-module-check-type-2 ()
  (check-type "" si:dll-module)
  !! type-error)


(deftest c-function-typep ()
  (values
   (typep (si:make-c-function (si:load-dll-module "msvcrt")
                              "atoi" '(:int32) :int32)
          'si:c-function)
   (typep nil 'si:c-function)
   (typep 0 'si:c-function)
   (typep "" 'si:c-function))
  => t
  => nil
  => nil
  => nil)

(deftest c-function-check-type-1 ()
  (check-type (si:make-c-function (si:load-dll-module "msvcrt")
                                  "atoi" '(:int32) :int32)
              si:c-function)
  => nil)

(deftest c-function-check-type-2 ()
  (check-type "" si:c-function)
  !! type-error)


(deftest c-callable-typep ()
  (values
   (typep (si:make-c-callable #'car :void :void)
          'si:c-callable)
   (typep nil 'si:c-callable)
   (typep 0 'si:c-callable)
   (typep "" 'si:c-callable))
  => t
  => nil
  => nil
  => nil)

(deftest c-callable-check-type-1 ()
  (check-type (si:make-c-callable #'car :void :void)
              si:c-callable)
  => nil)

(deftest c-callable-check-type-2 ()
  (check-type "" si:c-callable)
  !! type-error)


(deftest environment-typep ()
  (values
   (typep (macrolet ((env (&environment env)
                       env))
            (env))
          'si:environment)
   (typep nil 'si:environment)
   (typep 0 'si:environment)
   (typep "" 'si:environment))
  => t
  => nil
  => nil
  => nil)

(deftest environment-check-type-1 ()
  (check-type (macrolet ((env (&environment env)
                           env))
                (env))
              si:environment)
  => nil)

(deftest environment-check-type-2 ()
  (check-type "" si:environment)
  !! type-error)


;; #16 Phase 2: typespec / type system coverage. subtypep is a real
;; implementation (numeric-interval subsumption, array dimensions,
;; and/or/not, member, satisfies), not a toy that always answers
;; (values nil nil); these tests lock in the ANSI-core behavior that
;; had zero prior coverage. subtypep's first value only has to be a
;; generalized boolean per ANSI CL (not necessarily the symbol T), so
;; tests normalize it with (and ... t) rather than pinning the exact
;; truthy value some branches happen to return (e.g. member's tail).

(deftest subtypep-member-regression ()
  ;; Regression test: this branch used to call the undefined function
  ;; `value' instead of `values' whenever a MEMBER element did not
  ;; satisfy the target type, so this signalled an
  ;; undefined-function error instead of returning (values nil t).
  (multiple-value-bind (sub certain)
      (subtypep '(member 1 2 "a") 'integer)
    (list (and sub t) certain))
  => (nil t))

(deftest subtypep-member-all-match ()
  (multiple-value-bind (sub certain)
      (subtypep '(member 1 2 3) 'integer)
    (list (and sub t) certain))
  => (t t))

(deftest subtypep-numeric-ranges ()
  (values
   (and (subtypep 'fixnum 'integer) t)
   (and (subtypep '(integer 0 10) '(integer 0 20)) t)
   (and (subtypep '(integer 0 20) '(integer 0 10)) t)
   (and (subtypep '(integer 5 10) 'integer) t)
   (and (subtypep 'integer 'rational) t)
   (and (subtypep 'null 'symbol) t))
  => t
  => t
  => nil
  => t
  => t
  => t)

(deftest subtypep-and-or-not ()
  (values
   (and (subtypep '(and integer (satisfies oddp)) 'integer) t)
   (and (subtypep 'integer '(or integer float)) t)
   (and (subtypep '(not null) 'symbol) t))
  => t
  => t
  => nil)

;; Regression tests: the (eq t2 'or) and (eq t2 'and) branches (type1
;; tested against a compound OR/AND type2) had their loop logic
;; inverted from each other -- (t2 'or) required type1 to be a subtype
;; of EVERY disjunct (should be: at least one) and (t2 'and) accepted
;; as soon as type1 was a subtype of ANY ONE conjunct (should be:
;; every one), so e.g. INTEGER wrongly tested as not a subtype of
;; (OR INTEGER FLOAT), and wrongly tested as a subtype of
;; (AND INTEGER STRING).
(deftest subtypep-t2-or-requires-any-disjunct ()
  (values
   (and (subtypep 'integer '(or integer float)) t)
   (and (subtypep 'string '(or integer float)) t))
  => t
  => nil)

(deftest subtypep-t2-and-requires-every-conjunct ()
  (values
   (and (subtypep 'integer '(and integer real)) t)
   (and (subtypep 'integer '(and integer string)) t)
   (and (subtypep 'fixnum '(and integer real)) t))
  => t
  => nil
  => t)

;; Regression test: (deftype eql (x) `(member (,x))) double-wrapped the
;; value in an extra list, so canonicalize-type turned (eql 5) into
;; (member (5)) instead of (member 5). typep was unaffected (it has
;; its own direct `eql' handler and never canonicalizes), but subtypep
;; goes through canonicalize-type and so ended up testing whether the
;; list (5) -- not the number 5 -- satisfied the target type,
;; making (subtypep '(eql 5) 'integer) wrongly answer NIL.
(deftest subtypep-eql-canonicalizes-correctly ()
  (and (subtypep '(eql 5) 'integer) t)
  => t)

(deftest subtypep-eql-and-satisfies ()
  (values
   (and (subtypep '(eql 5) 'integer) t)
   (multiple-value-bind (sub certain) (subtypep '(satisfies oddp) 'integer)
     (list (and sub t) certain)))
  => t
  => (nil nil))

(deftest typep-integer-range ()
  (values
   (typep 5 '(integer 0 10))
   (typep 15 '(integer 0 10))
   (typep 5 '(integer (0) (10)))
   (typep 0 '(integer (0) 10)))
  => t
  => nil
  => t
  => nil)

(deftest typep-member-and-eql ()
  ;; typep on a MEMBER type specifier delegates to the built-in `member'
  ;; function, whose true value is a generalized boolean (the matching
  ;; sublist), not necessarily the literal symbol T.
  (values
   (and (typep 2 '(member 1 2 3)) t)
   (typep 4 '(member 1 2 3))
   (typep 5 '(eql 5))
   (typep 6 '(eql 5)))
  => t
  => nil
  => t
  => nil)

(deftest typep-and-or-not-satisfies ()
  (values
   (typep 4 '(and integer (satisfies evenp)))
   (typep 3 '(and integer (satisfies evenp)))
   (typep "x" '(or integer string))
   (typep 3.0 '(or integer string))
   (typep 3 '(not string)))
  => t
  => nil
  => t
  => nil
  => t)

;; Stream subtypes: two-way-stream/echo-stream/broadcast-stream/
;; synonym-stream/string-stream/concatenated-stream previously had no
;; type-predicate entry in typespec-alist even though their builtin
;; predicates (two-way-stream-p etc.) already existed, so typep always
;; answered NIL for them despite subtypep already listing them as
;; recognized subtypes of STREAM.
(deftest typep-stream-subtypes ()
  (values
   (typep (make-two-way-stream (make-string-input-stream "")
                                (make-string-output-stream))
          'two-way-stream)
   (typep (make-echo-stream (make-string-input-stream "")
                             (make-string-output-stream))
          'echo-stream)
   (typep (make-broadcast-stream) 'broadcast-stream)
   (typep (make-string-output-stream) 'string-stream)
   (typep (make-concatenated-stream) 'concatenated-stream)
   (typep (make-string-output-stream) 'stream))
  => t
  => t
  => t
  => t
  => t
  => t)

(deftest subtypep-stream-subtypes ()
  (values
   (and (subtypep 'two-way-stream 'stream) t)
   (and (subtypep 'string-stream 'stream) t))
  => t
  => t)
