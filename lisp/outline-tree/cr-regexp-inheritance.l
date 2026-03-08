;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-regexp-inheritance.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/06/23 16:46:47 +0900>

;;; Code:

(provide "outline-tree/cr-regexp-inheritance")

(require "outline-tree/outline-tree")
(require "outline-tree/cr-regexp-internal")

(in-package "outline-tree2")

;; 行頭区切り
(defun outline-tree-create-outline-line (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list '("^\\(.+$\\|\n\\)")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :non-miss
   :line-oriented t
   :title-converter #'(lambda (str) (if (string= "\n" str) "" str))))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-line "行頭区切り(全行)" '(:type-general :line-oriented :sequential)
 "各行を全て表示します。
各行の入替え処理に適しています。")

;; インデント無し行頭区切り
(defun outline-tree-create-outline-no-space-line (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list '("^[^ 　\t\n].*$")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :non-miss
   :line-oriented t))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-no-space-line "行頭区切り(インデント無し行頭)" '(:type-general :line-oriented :sequential)
 "行頭にインデントがない行で区切ります。")

;; バッチファイル 解析
(defun outline-tree-create-outline-bat (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list '("^\\(:\\S+\\)$")
   :layer-regexp-list-case-fold t
   :layer-regexp-list-order :non-miss
   :line-oriented t))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-bat "BAT (ラベル)" '(:type-program :line-oriented :sequential)
 "バッチファイル (*.bat) を行頭のラベル (:***) 毎に表示します。")

;; LISP コメント 解析
(defun outline-tree-create-outline-lisp-comment (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^;;;?"
     "^ *(\\(?:[a-zA-Z]+::?\\)?\\(?:defun\\|defmacro\\|defvar\\|defvar-local\\|defconstant\\|define-dll-entry\\)")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :top-miss))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-lisp-comment "LISP (コメント)" '(:type-program :line-oriented :sequential)
 "LISP ファイルを行頭の \";;\" で始まるコメントと、各種定義 S 式で
アウトライン表示します。")

;; info フォーマット
(defun outline-tree-create-outline-info (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^\\([^ \t\n].+\\)\n\\*\\{2,\\}$"
     "^\\([^ \t\n].+\\)\n=\\{2,\\}$"
     "^\\([^ \t\n].+\\)\n-\\{2,\\}$"
     "^\\([^ \t\n].+\\)\n\\.\\{2,\\}$")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :top-miss
   :sub-type :heading-node))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-info "info" '(:type-document :line-oriented :sequential)
 "info フォーマットをアウトライン表示します。")

;; ChangeLog フォーマット
(defun outline-tree-create-outline-changelog (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} .+<.*>\\)"
     "^\t\\* \\(.+\\)")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :non-miss
   :sub-type :heading-node
   :line-oriented t))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-changelog "ChangeLog" '(:type-document :line-oriented :sequential)
 "ChangeLog フォーマットをアウトライン表示します。")

;; roff フォーマット
(defun outline-tree-create-outline-roff (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^\\.TH \\(.+\\)$"
     "^\\.SH \"?\\(.+?\\)\"? *$"
     "^\\.[^ \n]+ \"?\\(.+?\\)\"? *$")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :any-miss
   :line-oriented t
   :sub-type :heading-node))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-roff "roff" '(:type-document :line-oriented :sequential)
 "roff フォーマットをアウトライン表示します。")

;; Java 解析
(defun outline-tree-create-outline-java (root-node)
  (outline-tree-create-outline-regexp-internal
   :root-node root-node
   :layer-regexp-list
   '("^[ \t]*\\(\\(?:package\\|[^{\n]*?class[ \t]+[a-zA-Z]+\\)[^;{]*?\\)[;{]"
     "^[ \t]*\\([^{\n()]*?\\(?:public\\|private\\)[^{\n()]*?[a-zA-Z]+[ \t]*(.*)[^(){}]*\\)[ \t]*{")
;   '("^[ \t]*\\(\\(?:package\\|import\\|[^{\n]*?class[ \t]+[a-zA-Z]+\\)[^;{]*?\\)[;{]"
;     "^[ \t]*\\([^{\n()]*?\\(?:public\\|private\\)[^{\n()]*?[a-zA-Z]+[ \t]*(.*)[^(){}]*\\)[ \t]*{")
   :layer-regexp-list-case-fold nil
   :layer-regexp-list-order :non-miss))
(outline-tree-add-create-outline-function
 'outline-tree-create-outline-java "Java" '(:type-program :line-oriented :sequential)
 "Java 言語を非常に簡易的な方法でアウトライン表示します。
実用に耐える実装には至っていません。")

;;; cr-regexp-inheritance.l ends here
