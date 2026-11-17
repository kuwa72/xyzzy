;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; go-mode: Go editing support
;;;
;;; Go 向けのメジャーモード。.go が *auto-mode-alist* に登録されておらず
;;; fundamental-mode で開かれていた (#433)。rust-mode と同型で、
;;; シンタックスハイライトは compile-regexp-keyword-list ベース、
;;; インデントは cc-mode 系に乗せる。

(provide "go-mode")

(in-package "editor")

(require "cc-mode")
(require "re-kwd")

(export '(*go-mode-hook* *go-mode-map* go-mode
	  go-indent-level *go-indent-tabs-mode*))

(defvar *go-mode-hook* nil)
(defvar *go-mode-map* nil)

(unless (boundp 'go-indent-level)
  (setq go-indent-level 4))
(defvar *go-indent-tabs-mode* nil)

;;; ============================================================
;;; Syntax table (C++ style: // and /* */ comments)
;;; ============================================================
;;;
;;; ' は Go では文字リテラル ('a', '\n') で閉じクォートが必ずあるので
;;; string syntax にしてよい (ライフタイムのある Rust とは違う)。
;;; ` の生文字列も string syntax にすると、複数行にまたがるものや
;;; 中の // をそのまま文字列として扱える。

(defvar *go-mode-syntax-table* nil)
(unless *go-mode-syntax-table*
  (setq *go-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
	(set-syntax-punctuation *go-mode-syntax-table* c))))
  (set-syntax-string *go-mode-syntax-table* #\")
  (set-syntax-string *go-mode-syntax-table* #\')
  (set-syntax-string *go-mode-syntax-table* #\`)
  (set-syntax-escape *go-mode-syntax-table* #\\)
  (set-syntax-symbol *go-mode-syntax-table* #\_)
  (set-syntax-match *go-mode-syntax-table* #\( #\))
  (set-syntax-match *go-mode-syntax-table* #\{ #\})
  (set-syntax-match *go-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment *go-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *go-mode-syntax-table* "*/")
  (set-syntax-start-c++-comment *go-mode-syntax-table* #\/)
  (set-syntax-end-c++-comment *go-mode-syntax-table* #\LFD))

;;; ============================================================
;;; Keymap
;;; ============================================================

(unless *go-mode-map*
  (setq *go-mode-map* (make-sparse-keymap))
  (define-key *go-mode-map* #\{ 'c-electric-insert)
  (define-key *go-mode-map* #\} 'c-electric-close)
  (define-key *go-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *go-mode-map* #\TAB 'c-indent-line)
  (define-key *go-mode-map* #\C-M-q 'indent-sexp)
  (define-key *go-mode-map* #\RET 'c-newline-and-indent))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *go-regexp-keyword-list* nil)

(defun go-setup-keywords ()
  (unless *go-regexp-keyword-list*
    (setq *go-regexp-keyword-list*
	  (compile-regexp-keyword-list
	   '(;; キーワード (Go spec の予約語 25 個)
	     ("\\b\\(break\\|case\\|chan\\|const\\|continue\\|default\\|defer\\|else\\|fallthrough\\|for\\|func\\|go\\|goto\\|if\\|import\\|interface\\|map\\|package\\|range\\|return\\|select\\|struct\\|switch\\|type\\|var\\)\\b" nil 0)
	     ;; 定義済みの定数
	     ("\\b\\(true\\|false\\|iota\\|nil\\)\\b" nil 2)
	     ;; 組み込み型
	     ("\\b\\(bool\\|byte\\|complex64\\|complex128\\|error\\|float32\\|float64\\|int8\\|int16\\|int32\\|int64\\|rune\\|string\\|uint8\\|uint16\\|uint32\\|uint64\\|uintptr\\|int\\|uint\\)\\b" nil :tag)
	     ;; 組み込み関数
	     ("\\b\\(append\\|cap\\|close\\|complex\\|copy\\|delete\\|imag\\|len\\|make\\|new\\|panic\\|print\\|println\\|real\\|recover\\)\\b" nil 2)
	     ;; 大文字始まりは export された型・関数・定数
	     ("\\b[A-Z][A-Za-z0-9_]*\\b" nil :tag)
	     ;; 演算子
	     ("\\(:=\\|<-\\)\\|\\.\\.\\." nil 0)
	     ;; 数値リテラル (16/8/2 進, 桁区切りの _, 浮動小数, 虚数 i)
	     ("\\b0[xX][0-9a-fA-F_]+\\|\\b0[bB][01_]+\\|\\b0[oO][0-7_]+\\|\\b[0-9][0-9_]*\\(\\.[0-9_]+\\)?\\([eE][-+]?[0-9_]+\\)?i?\\b" nil :tag)
	     ))))
  *go-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun go-mode ()
  "Go ソース編集用のメジャーモード。"
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Go")
  (setq buffer-mode 'go-mode)
  (use-syntax-table *go-mode-syntax-table*)
  (use-keymap *go-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  (make-local-variable 'c-indent-level)
  (setq c-indent-level go-indent-level)
  (make-local-variable 'c-continued-statement-offset)
  (setq c-continued-statement-offset go-indent-level)
  (make-local-variable 'c-brace-offset)
  (setq c-brace-offset 0)
  (make-local-variable 'c-label-offset)
  (setq c-label-offset (- go-indent-level))
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode *go-indent-tabs-mode*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (go-setup-keywords))
  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (run-hooks '*go-mode-hook*))
