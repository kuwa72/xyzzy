(deftest make-vector--fill-pointer-and-initial-contents ()
  (let ((v (make-array 3 :fill-pointer 2 :initial-contents '(0 1 2))))
    (values
     (fill-pointer v)
     (aref v 0)
     (aref v 1)
     (aref v 2)
     (format nil "~A" v)
     (setf (fill-pointer v) 3)
     (format nil "~A" v)
     ))
  => 2
  => 0
  => 1
  => 2
  => "#(0 1)"
  => 3
  => "#(0 1 2)")

(deftest make-string--fill-pointer-and-initial-contents ()
  (let ((v (make-array 3 :element-type 'character :fill-pointer 2
                       :initial-contents "abc")))
    (values
     (fill-pointer v)
     (aref v 0)
     (aref v 1)
     (aref v 2)
     (format nil "~A" v)
     (setf (fill-pointer v) 3)
     (format nil "~A" v)
     ))
  => 2
  => #\a
  => #\b
  => #\c
  => "ab"
  => 3
  => "abc")

(deftest find-clhs-examples ()
  (values
   (find #\d "here are some letters that can be looked at" :test #'char>)
   (find-if #'oddp '(1 2 3 4 5) :end 3 :from-end t)
   (find-if-not #'evenp #(1 3 4 6 8) :start 2))
  => #\Space
  => 3
  => nil)

(deftest find-test-not ()
  ;; :test-not is the negation of :test: matches where (test-not item x)
  ;; is false, so :test-not #'/= behaves like :test #'=.
  (values
   (find 4 '(1 2 4 1 3 4 5) :test-not #'/=)
   (find 99 '(1 2 4 1 3 4 5) :test-not #'/=))
  => 4
  => nil)

(deftest position-clhs-examples ()
  (values
   (position #\a "baobab" :from-end t)
   (position-if #'oddp '((1) (2) (3) (4)) :start 1 :key #'car)
   (position 595 '())
   (position-if-not #'integerp '(1 2 3 4 5.0)))
  => 4
  => 2
  => nil
  => 4)

(deftest position-test-not ()
  (values
   (position 4 '(1 2 4 1 3 4 5) :test-not #'/=)
   (position 4 '(1 2 4 1 3 4 5) :test-not #'/= :from-end t))
  => 2
  => 5)

(deftest remove-clhs-examples ()
  (values
   (remove 4 '(1 3 4 5 9))
   (remove 4 '(1 2 4 1 3 4 5))
   (remove 4 '(1 2 4 1 3 4 5) :count 1)
   (remove 4 '(1 2 4 1 3 4 5) :count 1 :from-end t)
   (remove 3 '(1 2 4 1 3 4 5) :test #'> )
   (remove-if #'oddp '(1 2 4 1 3 4 5))
   (remove-if #'evenp '(1 2 4 1 3 4 5) :count 1 :from-end t)
   (remove-if-not #'evenp '(1 2 3 4 5 6 7 8 9) :count 2 :from-end t))
  => (1 3 5 9)
  => (1 2 1 3 5)
  => (1 2 1 3 4 5)
  => (1 2 4 1 3 5)
  => (4 3 4 5)
  => (2 4 4)
  => (1 2 4 1 3 5)
  => (1 2 3 4 5 6 8))

(deftest remove-test-not ()
  (values
   (remove 4 '(1 2 4 1 3 4 5) :test-not #'/=)
   (remove 99 '(1 2 4 1 3 4 5) :test-not #'/=))
  => (1 2 1 3 5)
  => (1 2 4 1 3 4 5))

(deftest delete-clhs-examples ()
  (values
   (delete 4 (list 1 2 4 1 3 4 5))
   (delete 4 (list 1 2 4 1 3 4 5) :count 1)
   (delete 4 (list 1 2 4 1 3 4 5) :count 1 :from-end t)
   (delete 3 (list 1 2 4 1 3 4 5) :test #'> )
   (delete-if #'oddp (list 1 2 4 1 3 4 5))
   (delete-if #'evenp (list 1 2 4 1 3 4 5) :count 1 :from-end t))
  => (1 2 1 3 5)
  => (1 2 1 3 4 5)
  => (1 2 4 1 3 5)
  => (4 3 4 5)
  => (2 4 4)
  => (1 2 4 1 3 5))

(deftest remove-duplicates-nil-key (:compare equalp)
  (values
   (remove-duplicates '(1 2 1))
   (remove-duplicates '(1 2 1) :key nil)
   (remove-duplicates #(1 2 1))
   (remove-duplicates #(1 2 1) :key nil))
  => (2 1)
  => (2 1)
  => #(2 1)
  => #(2 1))

(deftest delete-duplicates-nil-key (:compare equalp)
  (values
   (delete-duplicates '(1 2 1))
   (delete-duplicates '(1 2 1) :key nil)
   (delete-duplicates #(1 2 1))
   (delete-duplicates #(1 2 1) :key nil))
  => (2 1)
  => (2 1)
  => #(2 1)
  => #(2 1))

(deftest substitute-nil-key ()
  (values
   (substitute #\a #\b "abcd")
   (substitute #\a #\b "abcd" :key nil))
  => "aacd"
  => "aacd")

(deftest substitute-if-nil-key ()
  (values
   (substitute-if nil #'oddp '(1 2 3 4))
   (substitute-if nil #'oddp '(1 2 3 4) :key nil))
  => (nil 2 nil 4)
  => (nil 2 nil 4))

(deftest substitute-if-not-nil-key ()
  (values
   (substitute-if-not nil #'oddp '(1 2 3 4))
   (substitute-if-not nil #'oddp '(1 2 3 4) :key nil))
  => (1 nil 3 nil)
  => (1 nil 3 nil))

(deftest nsubstitute-nil-key ()
  (values
   (nsubstitute #\b #\a "abcd")
   (nsubstitute #\b #\a "abcd" :key nil))
  => "bbcd"
  => "bbcd")

(deftest nsubstitute-if-nil-key ()
  (values
   (nsubstitute-if nil #'oddp '(1 2 3 4))
   (nsubstitute-if nil #'oddp '(1 2 3 4) :key nil))
  => (nil 2 nil 4)
  => (nil 2 nil 4))

(deftest nsubstitute-if-not-nil-key ()
  (values
   (nsubstitute-if-not nil #'oddp '(1 2 3 4))
   (nsubstitute-if-not nil #'oddp '(1 2 3 4) :key nil))
  => (1 nil 3 nil)
  => (1 nil 3 nil))

(deftest count-nil-key ()
  (values
   (count 1 '(1 2 3 4))
   (count 1 '(1 2 3 4) :key nil))
  => 1
  => 1)

(deftest count-if-nil-key ()
  (values
   (count-if #'oddp '(1 2 3 4))
   (count-if #'oddp '(1 2 3 4) :key nil))
  => 2
  => 2)

(deftest count-if-not-nil-key ()
  (values
   (count-if-not #'oddp '(1 2 3 4))
   (count-if-not #'oddp '(1 2 3 4) :key nil))
  => 2
  => 2)

(deftest mismatch-nil-key ()
  (values
   (mismatch '(1 3) '(1 2 3))
   (mismatch '(1 3) '(1 2 3) :key nil))
  => 1
  => 1)

(deftest mismatch-clhs-examples ()
  (values
   (mismatch "abcd" "ABCDE" :test #'char-equal)
   (mismatch '(3 2 1 1 2 3) '(1 2 3) :from-end t)
   (mismatch '(1 2 3) '(2 3 4) :test-not #'eq :key #'oddp)
   (mismatch '(1 2 3 4 5 6) '(3 4 5 6 7) :start1 2 :end2 4))
  => 4
  => 3
  => nil
  => nil)

(deftest mismatch-from-end ()
  (values
   ;; equal within the overlap, but sequence1 has a longer tail:
   ;; the mismatch is the length difference, not a byte compare.
   (mismatch '(1 2 3 4 5) '(3 4 5) :from-end t)
   ;; a real rightmost difference within an equal-length pair.
   (mismatch '(1 2 9 4) '(1 2 3 4) :from-end t)
   ;; identical sequences => nil regardless of direction.
   (mismatch '(1 2 3) '(1 2 3) :from-end t))
  => 2
  => 3
  => nil)

(deftest merge-nil-key ()
  (values
   (merge 'list '(1 2 3 5 8) '(2 4 6) #'<)
   (merge 'list '(1 2 3 5 8) '(2 4 6) #'< :key nil)
   (merge 'string "AbCF" "aBcd" #'char-lessp)
   (merge 'string "AbCF" "aBcd" #'char-lessp :key nil))
  => (1 2 2 3 4 5 6 8)
  => (1 2 2 3 4 5 6 8)
  => "AabBCcdF"
  => "AabBCcdF")

(deftest reduce-nil-key ()
  (values
   (reduce #'+ '(1 2 3))
   (reduce #'+ '(1 2 3) :key nil))
  => 6
  => 6)

(deftest reduce-with-key ()
  (values
   (reduce #'+ '((1) (1 2) (1 2 3)) :key #'length)
   (reduce #'* #(0 1 2 3 4 0) :key #'1+ :start 1 :end 5)
   (reduce #'+ "123456789" :key #'digit-char-p)
   (reduce #'- '(1 2 3 4) :key #'1- :from-end t))
  => 6
  => 120
  => 45
  => -2)

(deftest reduce-clhs-examples ()
  (values
   (reduce #'* '(1 2 3 4 5))
   (reduce #'append '((1) (2)) :initial-value '(i n i t))
   (reduce #'append '((1) (2)) :from-end t :initial-value '(i n i t))
   (reduce #'- '(1 2 3 4))
   (reduce #'- '(1 2 3 4) :from-end t)    ;Alternating sum.
   (reduce #'+ '())
   (reduce #'+ '(3))
   (reduce #'+ '(foo))
   (reduce #'list '(1 2 3 4))
   (reduce #'list '(1 2 3 4) :from-end t)
   (reduce #'list '(1 2 3 4) :initial-value 'foo)
   (reduce #'list '(1 2 3 4) :from-end t :initial-value 'foo))
  => 120
  => (i n i t 1 2)
  => (1 2 i n i t)
  => -8
  => -2
  => 0
  => 3
  => foo
  => (((1 2) 3) 4)
  => (1 (2 (3 4)))
  => ((((foo 1) 2) 3) 4)
   => (1 (2 (3 (4 foo)))))

(deftest search-clhs-examples ()
  (values
   (search "cat" "concatenate")
   (search '(3 4) '(1 2 3 4 5) :from-end t))
  => 3
  => 2)

(deftest search-basic ()
  (values
   (search "ab" "xabx")
   (search "ab" "xabx" :from-end t)
   (search "xyz" "hello")
   (search "" "hello")
   (search "hello" "hello"))
  => 1
  => 1
  => nil
  => 0
  => 0)

(deftest search-with-test ()
  (values
   (search '(1 2) '(0 1 2 3) :test #'=)
   (search "ab" "xABx" :test #'char-equal))
  => 1
  => 1)

(deftest search-with-start-end ()
  (values
   (search '(2 3) '(1 2 3 4 5) :start2 1 :end2 4)
   (search '(2 3) '(1 2 3 4 5) :start2 3)
   (search '(1 2) '(1 2 1 2) :start1 0 :end1 1 :start2 2))
  => 1
  => nil
  => 2)

(deftest search-with-key ()
  (values
   (search '() '(1 2 3 4 5))
   (search "ab" "xABx" :key #'char-downcase)
   (search "cd" "abcde" :key #'char-code))
  => 0
  => 1
  => 2)
