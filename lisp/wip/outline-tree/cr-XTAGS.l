;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-XTAGS.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/04/03 14:26:46 +0900>

;;; Code:

(provide "outline-tree/cr-XTAGS")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-XTAGS-buffer* " *outline-tree: XTAGS*")

(defun outline-tree-create-outline-XTAGS-buffer ()
  (let (working-buffer)
    (save-excursion
      (setq working-buffer (create-new-buffer *outline-tree-create-outline-XTAGS-buffer*))
      (set-buffer working-buffer)
      (make-local-variable 'need-not-save)
      (setq need-not-save t)
      (make-local-variable 'kept-undo-information)
      (setq kept-undo-information nil))
    working-buffer))

(defun outline-tree-create-outline-XTAGS-get-tags-path (file)
  (let ((tags-dir (directory-namestring file))
        tags-file relative-path working-buffer)
    (save-excursion
      (setq working-buffer (outline-tree-create-outline-XTAGS-buffer))
      (set-buffer working-buffer)
      (loop
        (setq tags-file (merge-pathnames "XTAGS" tags-dir))
        (unless (file-exist-p tags-file)
          (delete-buffer working-buffer)
          (return-from outline-tree-create-outline-XTAGS-get-tags-path nil))
        (insert-file tags-file)
        (if (looking-at "^#USE \\(.+\\)$")
            (progn
              (setq tags-dir (merge-pathnames (match-string 1) tags-dir))
              (delete-region (point-min) (point-max)))
          (return)))
      ;; 相対パスを単純に長さのみで生成している。危険か？
      (setq relative-path (substring file (length (append-trail-slash tags-dir))))
      (delete-buffer working-buffer)
      (values tags-file relative-path))))

(defun outline-tree-create-outline-XTAGS-possible-p (buffer)
  (let (working-buffer tags-file relative-path)
    (save-excursion
      (set-buffer buffer)
      (unless (get-buffer-file-name)
        (return-from outline-tree-create-outline-XTAGS-possible-p nil))
      (multiple-value-setq (tags-file relative-path)
        (outline-tree-create-outline-XTAGS-get-tags-path (get-buffer-file-name)))
      (unless tags-file
        (return-from outline-tree-create-outline-XTAGS-possible-p nil))
      (setq relative-path (concat "" relative-path ""))
      (setq working-buffer (outline-tree-create-outline-XTAGS-buffer))
      (set-buffer working-buffer)
      (insert-file tags-file)
      (unless (scan-buffer relative-path :case-fold t)
        (delete-buffer working-buffer)
        (return-from outline-tree-create-outline-XTAGS-possible-p nil))
      (delete-buffer working-buffer)
      t)))

;; XTAGS 解析
(defun outline-tree-create-outline-XTAGS (root-node)
  (treeview::with-app (*outline-tree-app-id*)
    (let* ((src-buffer (outline-tree-get-buffer-by-node root-node))
           src-buffer-mode working-buffer tags-file relative-path
           point-node S-section-node F-section-node V-section-node
           whole-range)
      (save-excursion
        (set-buffer src-buffer)
        (setq src-buffer-mode buffer-mode)
        (unless (get-buffer-file-name)
          (treeview::treeview-message "ファイル名がありません。")
          (return-from outline-tree-create-outline-XTAGS))
        (multiple-value-setq (tags-file relative-path)
          (outline-tree-create-outline-XTAGS-get-tags-path (get-buffer-file-name)))
        (unless tags-file
          (treeview::treeview-message "適切な XTAGS ファイルが存在しません。")
          (return-from outline-tree-create-outline-XTAGS))
        (setq relative-path (concat "" relative-path ""))
        (setq working-buffer (outline-tree-create-outline-XTAGS-buffer))
        (set-buffer working-buffer)
        (insert-file tags-file)
        (setq S-section-node (outline-tree-insert-section-node "[S]" root-node))
        (setq F-section-node (outline-tree-insert-section-node "[F]" root-node))
        (setq V-section-node (outline-tree-insert-section-node "[V]" root-node))
        (let (class sep name args file type point node-name)
          (while (scan-buffer relative-path :case-fold t)
            (goto-bol)
            (setq class "" sep "")
            (unless (looking-at "[]")
              (setq class (buffer-substring
                           (point) (progn (skip-chars-forward "^") (point)))
                    sep ed::tags-class-method-separator))
            (setq type (ed::tags-looking-entry-type))
            (setq name (buffer-substring
                        (1+ (point)) (progn (skip-chars-forward "^") (point)))
                  file (progn
                         (forward-char 1)
                         (buffer-substring
                          (point) (progn (skip-chars-forward "^") (point))))
                  point (parse-integer
                         (buffer-substring
                          (1+ (point)) (progn (skip-chars-forward "^\n") (point))))
                  args (progn
                         (skip-chars-forward "^\n")
                         (if (looking-for "")
                             (buffer-substring (1+ (point)) (progn (goto-eol) (point)))
                           "")))
            (setq whole-range nil)
            (cond
             ((member src-buffer-mode '(ed::lisp-mode ed::lisp-interaction-mode))
              (save-excursion
                (set-buffer src-buffer)
                (goto-char (1- point))
                (if (goto-matched-parenthesis)
                    (setq whole-range (cons (point) point))))))
            (setq node-name (concat class sep name " " args))
            (case type
              ('ed::structure
               (if whole-range
                   (outline-tree-insert-range-node node-name S-section-node :whole-range whole-range)
                 (outline-tree-insert-point-node node-name S-section-node :point point)))
              ('ed::function
               (if whole-range
                   (outline-tree-insert-range-node node-name F-section-node :whole-range whole-range)
                 (outline-tree-insert-point-node node-name F-section-node :point point)))
              (t
               (if whole-range
                   (outline-tree-insert-range-node node-name V-section-node :whole-range whole-range)
                 (outline-tree-insert-point-node node-name V-section-node :point point)))))))
      (delete-buffer working-buffer)
      (unless (outline-tree-node-has-children-p S-section-node)
        (outline-tree-remove-section-node S-section-node))
      (unless (outline-tree-node-has-children-p F-section-node)
        (outline-tree-remove-section-node F-section-node))
      (unless (outline-tree-node-has-children-p V-section-node)
        (outline-tree-remove-section-node V-section-node)))))

(outline-tree-add-create-outline-function
 'outline-tree-create-outline-XTAGS "XTAGS" '(:type-program-general)
 "バッファに対応する XTAGS ファイルを元に、S,F,V 情報を表示します。
XTAGS ファイルとは、[メニュー]-[ツール]-[TAGSファイルの作成] により
生成されるファイルです。")

;;; cr-XTAGS.l ends here
