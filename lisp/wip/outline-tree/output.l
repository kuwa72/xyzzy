;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; output.l --- outline-tree

;; Copyright (C) 2001-2007 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2007/02/11 11:06:22 +0900>

;;; Code:

(provide "outline-tree/output")

; (require "buf2html") ; HTML出力未移植
(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-output-directory* nil)
(defvar *outline-tree-output-buffer* "*OutlineTree OUTPUT*")

(defun outline-tree-set-output-buffer ()
  (save-excursion
    (let (output-buffer)
      (setq output-buffer (get-buffer-create *outline-tree-output-buffer*))
      (set-buffer output-buffer)
      (erase-buffer (selected-buffer))
      (make-local-variable 'ed::need-not-save)
      (setq ed::need-not-save t)
      output-buffer)))

(defun outline-tree-output-get-output-dir ()
  (or *outline-tree-output-directory*
      (and (get-buffer-file-name)
           (directory-namestring (get-buffer-file-name)))
      (default-directory)))

(defun outline-tree-output-pre-check (&optional target-buffer)
  "最新のアウトラインが存在しているか確認し、作成・更新を促す"
  (cond ((not (outline-tree-exist-outline-p-by-buffer target-buffer))
         (when (yes-or-no-p "<~A> バッファにはアウトラインが存在しません。~%アウトラインを作成しますか？"
                            (buffer-name target-buffer))
           (outline-tree-create-outline-by-buffer target-buffer)
           t))
        ((not (outline-tree-latest-outline-p-by-buffer target-buffer))
         (when (yes-or-no-p "<~A> バッファのアウトラインが最新ではありません。~%アウトラインを更新しますか？"
                            (buffer-name target-buffer))
           (outline-tree-create-outline-by-buffer target-buffer)
           t))
        (t
         t)))

(defun outline-tree-output-confirm-output-files-p (files &optional directory)
  "ファイルを出力してよければ non-nil、そうでなければ nil を返す"
  (let (exist-output-files)
    (dolist (file files)
      (if (file-exist-p (merge-pathnames file directory))
          (push file exist-output-files)))
    (not (and exist-output-files
              (not (no-or-yes-p "~A~{        ~A~%~}ファイルが存在しています。~%上書きしてもよろしいですか？"
                                (if directory (format nil "~A フォルダに~%" directory) "")
                                (nreverse exist-output-files)))))))

;;; output.l ends here
