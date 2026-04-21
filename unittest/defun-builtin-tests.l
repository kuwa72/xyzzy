;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(defun list-wrong-builtin-function-definition (pkg)
  (let ((fns nil)
        (defs nil))
    (do-external-symbols (sym pkg)
      (when (fboundp sym)
        (when (si:*builtin-function-p (symbol-function sym))
          (push sym fns))
        (when (member 'si::builtin-function-argument (symbol-plist sym))
          (push sym defs))))
    (list (set-difference fns defs)
          (set-difference defs fns))))

(deftest test-defun-builtin-1 ()
  "builtin.l で定義されていない builtin 関数が存在しないこと"
  (values-list
   (mapcar #'car
           (mapcar #'list-wrong-builtin-function-definition
                   '(:lisp :system :editor))))
  => nil
  => nil
  => nil)

(deftest test-defun-builtin-2 ()
  "builtin.l で定義されている非 builtin 関数が存在しないこと"
  (values-list
   (mapcar #'cadr
           (mapcar #'list-wrong-builtin-function-definition
                   '(:lisp :system :editor))))
  => nil
  => nil
  => nil)
