;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; gen-cr-user-topic.l --- outline-tree

;; Copyright (C) 2001-2006 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2006/10/21 17:16:20 +0900>

;;; Code:

(provide "outline-tree/gen-cr-user-topic")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-topic")

(in-package "outline-tree2")

(defun outline-tree-gen-cr-user-topic ()
  (interactive)
  (let (
        heading-skip-regexp
        enable-skip-width
        heading-chars
        heading-chars-group-list
        heading-regexp-list
        heading-regexp-list-case-fold
        func-name
        func-menu-name
        func-doc
        file-name
        write-file-path)
    (setq heading-skip-regexp
          (cond
           ((symbolp outline-tree-create-outline-topic-heading-skip-regexp)
            (symbol-value outline-tree-create-outline-topic-heading-skip-regexp))
           ((stringp outline-tree-create-outline-topic-heading-skip-regexp)
            outline-tree-create-outline-topic-heading-skip-regexp)
           (t nil)))
    (setq enable-skip-width
          (cond
           ((symbolp outline-tree-create-outline-topic-enable-skip-width)
            (symbol-value outline-tree-create-outline-topic-enable-skip-width))
           (t
            outline-tree-create-outline-topic-enable-skip-width)))
    (setq heading-chars
          (cond
           ((symbolp outline-tree-create-outline-topic-heading-chars)
            (symbol-value outline-tree-create-outline-topic-heading-chars))
           ((stringp outline-tree-create-outline-topic-heading-chars)
            outline-tree-create-outline-topic-heading-chars)
           (t nil)))
    (setq heading-chars-group-list
          (cond
           ((symbolp outline-tree-create-outline-topic-heading-chars-group-list)
            (symbol-value outline-tree-create-outline-topic-heading-chars-group-list))
           ((listp outline-tree-create-outline-topic-heading-chars-group-list)
            outline-tree-create-outline-topic-heading-chars-group-list)
           (t nil)))
    (setq heading-regexp-list
          (cond
           ((symbolp outline-tree-create-outline-topic-heading-regexp-list)
            (symbol-value outline-tree-create-outline-topic-heading-regexp-list))
           ((listp outline-tree-create-outline-topic-heading-regexp-list)
            outline-tree-create-outline-topic-heading-regexp-list)
           (t nil)))
    (setq heading-regexp-list-case-fold
          outline-tree-create-outline-topic-heading-regexp-list-case-fold)

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
      (return-from outline-tree-gen-cr-user-topic nil))
    (setq file-name (concat "cr-user-topic-" func-name ".l"))
    (unless (outline-tree-check-autoload-directory)
      (return-from outline-tree-gen-cr-user-topic nil))
    (setq write-file-path
          (merge-pathnames file-name *outline-tree-autoload-directory*))
    (when (and (file-exist-p write-file-path)
               (not (yes-or-no-p "~A が存在します。上書きしてよいですか？" write-file-path)))
      (return-from outline-tree-gen-cr-user-topic nil))
    ;;
    (let ((buffer (create-new-buffer " outline-tree-gen-cr-user-topic")))
      (with-output-to-buffer (buffer)
        (format t ";;; -*- Mode: Lisp; Package: OUTLINE-TREE2 -*-~%")
        (format t ";;; ~A --- outline-tree~%" file-name)
        (format t "~%")
        (format t ";; Generator: outline-tree-gen-cr-user-topic~%")
        (format t ";; Time-stamp: <~A>~%" (format-date-string "%Y/%m/%d %H:%M:%S %Z"))
        (format t "~%")
        (format t ";;; Code:~%")
        (format t "~%")
        (format t "(require \"outline-tree/outline-tree\")~%")
        (format t "(require \"outline-tree/cr-topic-internal\")~%")
        (format t "~%")
        (format t "(in-package \"outline-tree2\")~%")
        (format t "~%")
        (format t ";; definition
(defun outline-tree-create-outline-user-topic-~A (root-node)
  (outline-tree-create-outline-topic-internal
   :root-node root-node
   :heading-skip-regexp ~S
   :enable-skip-width ~S
   :heading-chars ~S
   :heading-chars-group-list '~S
   :heading-regexp-list '~S
   :heading-regexp-list-case-fold ~S
   :sub-type :heading-node
   :line-oriented t
   :title-converter nil))
;; register
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-user-topic-~A \"* user : ~A\" '(:user :line-oriented :sequential)
 ~S)
"
                   func-name
                   heading-skip-regexp
                   enable-skip-width
                   heading-chars
                   heading-chars-group-list
                   heading-regexp-list
                   heading-regexp-list-case-fold
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

;; gen-cr-user-topic.l ends here
