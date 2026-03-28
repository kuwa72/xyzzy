;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-global.l --- outline-tree

;; Copyright (C) 2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/03/18 10:53:49 +0900>

;;; Code:

(provide "outline-tree/cr-global")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-global-buffer* " *outline-tree: global*")

(defun outline-tree-create-outline-global-buffer ()
  (let (working-buffer)
    (save-excursion
      (setq working-buffer (create-new-buffer *outline-tree-create-outline-global-buffer*))
      (set-buffer working-buffer)
      (make-local-variable 'need-not-save)
      (setq need-not-save t)
      (make-local-variable 'kept-undo-information)
      (setq kept-undo-information nil))
    working-buffer))

(defun outline-tree-create-outline-global-get-GTAGS-path (file)
  (let ((tags-dir (directory-namestring file)) tags-file relative-path)
    (loop
      (setq tags-file (merge-pathnames "GTAGS" tags-dir))
      (when (file-exist-p tags-file)
        (return))
      (setq tags-dir (remove-trail-slash tags-dir))
      (unless (string-match "/" tags-dir)
        (return-from outline-tree-create-outline-global-get-GTAGS-path nil))
      (setq tags-dir (directory-namestring tags-dir)))
    (setq relative-path
          (concat ".\\" 
                  (map-slash-to-backslash
                   (substring (get-buffer-file-name) (length (append-trail-slash tags-dir))))))
    (values tags-file relative-path)))

(defun outline-tree-create-outline-global-parse-line ()
  (let (tag-name line-num file-name line-str)
    (save-excursion
      (goto-bol)
      (when (looking-at "^\\([^\t\n]+?\\) +\\([0-9]+\\) +\\(.+?\\) +\\(.+\\)$")
        (setq tag-name (match-string 1)
              line-num (parse-integer (match-string 2))
              file-name (match-string 3)
              line-str (match-string 4))
        (list tag-name line-num file-name line-str)))))

(defun outline-tree-create-outline-global-possible-p (buffer)
  (let (working-buffer tags-file relative-path fields file-name)
    (save-excursion
      (set-buffer buffer)
      (unless (get-buffer-file-name)
        (return-from outline-tree-create-outline-global-possible-p nil))
      (multiple-value-setq (tags-file relative-path)
        (outline-tree-create-outline-global-get-GTAGS-path (get-buffer-file-name)))
      (unless tags-file
        (return-from outline-tree-create-outline-global-possible-p nil))
      t)))

;; global 解析
(defun outline-tree-create-outline-global (root-node)
  (treeview::with-app (*outline-tree-app-id*)
    (let ((src-buffer (outline-tree-get-buffer-by-node root-node))
          working-buffer tags-file relative-path
          fields fields-list
          tag-name line-num file-name line-str
          node)
      (save-excursion
        (set-buffer src-buffer)
        (unless (get-buffer-file-name)
          (treeview::treeview-message "ファイル名がありません。")
          (return-from outline-tree-create-outline-global))
        (multiple-value-setq (tags-file relative-path)
          (outline-tree-create-outline-global-get-GTAGS-path (get-buffer-file-name)))
        (unless tags-file
          (treeview::treeview-message "GTAGS ファイルが存在しません。")
          (return-from outline-tree-create-outline-global))

        (setq working-buffer (outline-tree-create-outline-global-buffer))
        (set-buffer working-buffer)
        (let ((dir (directory-namestring (get-buffer-file-name src-buffer)))
              (file (file-namestring (get-buffer-file-name src-buffer)))
              (cmd "global -f"))
          (execute-shell-command (format nil "~A ~A" cmd file)
                                 nil
                                 working-buffer
                                 dir))
        (while (setq fields (outline-tree-create-outline-global-parse-line))
          (push fields fields-list)
          (goto-eol)
          (forward-char))
        (delete-buffer working-buffer)
        (set-buffer src-buffer)
        (dolist (fields (nreverse fields-list))
          (setq tag-name (nth 0 fields)
                line-num (nth 1 fields)
                file-name (nth 2 fields)
                line-str (nth 3 fields))
          (goto-line line-num)
;          (setq node (outline-tree-insert-point-node
;                      tag-name root-node
;                      :point (point)))
;          (outline-tree-insert-info-node line-str node)
          (outline-tree-insert-point-node line-str root-node
                                          :point (point)))
        ))))

(outline-tree-add-create-outline-function
 'outline-tree-create-outline-global "GNU GLOBAL(gtags)" '(:type-program-general)
 "GNU GLOBAL(gtags) を用いて情報を表示します。
  GNU GLOBAL プロジェクト <http://www.gnu.org/software/global/>
  Win32版バイナリ         <http://www.geocities.com/jadoxa/global/index.html>")

;;; cr-global.l ends here
