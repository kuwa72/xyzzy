;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; gen-cr-user-regexp.l --- outline-tree

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/10/21 17:16:26 +0900>

;;; Code:

(provide "outline-tree/gen-cr-user-regexp")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp")

(in-package "outline-tree2")

(defun outline-tree-gen-cr-user-regexp ()
  (interactive)
  (let (layer-regexp-list
        layer-regexp-list-case-fold
        layer-regexp-list-order
        func-name
        func-menu-name
        func-doc
        file-name
        write-file-path)
    (setq layer-regexp-list
          (cond
           ((symbolp outline-tree-create-outline-regexp-layer-regexp-list)
            (symbol-value outline-tree-create-outline-regexp-layer-regexp-list))
           ((listp outline-tree-create-outline-regexp-layer-regexp-list)
            outline-tree-create-outline-regexp-layer-regexp-list)
           (t nil)))
    (setq layer-regexp-list-case-fold
          outline-tree-create-outline-regexp-layer-regexp-list-case-fold)
    (setq layer-regexp-list-order
          outline-tree-create-outline-regexp-layer-regexp-list-order)

    (setq func-name "")
    (loop
      (message "~S のみで入力してください" "a-zA-Z0-9-")
      (setq func-name (read-string "アウトライン関数名: " :default func-name))
      (when (string-match "^[a-zA-Z0-9-]+$" func-name 0 (length func-name))
        (return)))
    (setq func-menu-name (read-string "メニュー表示名: "))
    (setq func-doc (read-string "アウトライン説明: "))

    (unless (yes-or-no-p "次の情報で保存しますか？~%
アウトライン関数名: ~A
メニュー表示名:     ~A
アウトライン説明:
-----------------
~A"
                         func-name
                         func-menu-name
                         func-doc)
      (return-from outline-tree-gen-cr-user-regexp nil))
    (setq file-name (concat "cr-user-regexp-" func-name ".l"))
    (unless (outline-tree-check-autoload-directory)
      (return-from outline-tree-gen-cr-user-regexp nil))
    (setq write-file-path
          (merge-pathnames file-name *outline-tree-autoload-directory*))
    (when (and (file-exist-p write-file-path)
               (not (yes-or-no-p "~A が存在します。上書きしてよいですか？" write-file-path)))
      (return-from outline-tree-gen-cr-user-regexp nil))
    ;;
    (let ((buffer (create-new-buffer " outline-tree-gen-cr-user-regexp")))
      (with-output-to-buffer (buffer)
        (format t ";;; -*- Mode: Lisp; Package: OUTLINE-TREE2 -*-~%")
        (format t ";;; ~A --- outline-tree~%" file-name)
        (format t "~%")
        (format t ";; Generator: outline-tree-gen-cr-user-regexp~%")
        (format t ";; Time-stamp: <~A>~%" (format-date-string "%Y/%m/%d %H:%M:%S %Z"))
        (format t "~%")
        (format t ";;; Code:~%")
        (format t "~%")
        (format t "(require \"outline-tree/outline-tree\")~%")
        (format t "(require \"outline-tree/cr-regexp-internal\")~%")
        (format t "~%")
        (format t "(in-package \"outline-tree2\")~%")
        (format t "~%")
        (format t ";; definition
(defun outline-tree-create-outline-user-regexp-~A (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list-order ~S
   :layer-regexp-list '~S
   :layer-regexp-list-case-fold ~S
   :sub-type :heading-node
   :line-oriented nil
   :title-converter nil))
;; register
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-user-regexp-~A \"* user : ~A\" '(:user :sequential)
 ~S)
"
                   func-name
                   layer-regexp-list-order
                   layer-regexp-list
                   layer-regexp-list-case-fold
                   func-name
                   func-menu-name
                   func-doc)
        (format t "~%")
        (format t ";;; ~A ends here~%" file-name))
      (save-excursion
        (set-buffer buffer)
        (write-file write-file-path))
      (load write-file-path)
      (outline-tree-create-outline-function-menu-gen)
      (outline-tree-create-outline-function-info-menu-gen)
      (delete-buffer buffer))
    ))

;; gen-cr-user-regexp.l ends here
