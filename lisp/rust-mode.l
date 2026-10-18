;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; rust-mode: Rust editing support
;;;
;;; Rust 向けのメジャーモード。.rs が *auto-mode-alist* に登録されて
;;; おらず fundamental-mode で開かれていた (#404)。
;;; シンタックスハイライトは compile-regexp-keyword-list ベースで、
;;; インデントは C 系の cc-mode 系に乗せる。

(provide "rust-mode")

(in-package "editor")

(require "cc-mode")
(require "re-kwd")

(export '(*rust-mode-hook* *rust-mode-map* rust-mode
	  rust-indent-level *rust-indent-tabs-mode*))

(defvar *rust-mode-hook* nil)
(defvar *rust-mode-map* nil)

(unless (boundp 'rust-indent-level)
  (setq rust-indent-level 4))
(defvar *rust-indent-tabs-mode* nil)

;;; ============================================================
;;; Syntax table (C++ style: // and /* */ comments)
;;; ============================================================
;;;
;;; **' は文字列扱いしない。** Rust のライフタイム ('a, 'static) が
;;; あるので ' を string syntax にするとそれ以降が文字列として
;;; 解釈されて画面が壊れる。文字リテラルは regexp キーワード側で
;;; 「閉じクォートがあるものだけ」に限定して色づけする。

(defvar *rust-mode-syntax-table* nil)
(unless *rust-mode-syntax-table*
  (setq *rust-mode-syntax-table* (make-syntax-table))
  (do ((x #x21 (1+ x))) ((>= x #x7f))
    (let ((c (code-char x)))
      (unless (alphanumericp c)
	(set-syntax-punctuation *rust-mode-syntax-table* c))))
  (set-syntax-string *rust-mode-syntax-table* #\")
  (set-syntax-escape *rust-mode-syntax-table* #\\)
  (set-syntax-symbol *rust-mode-syntax-table* #\_)
  (set-syntax-match *rust-mode-syntax-table* #\( #\))
  (set-syntax-match *rust-mode-syntax-table* #\{ #\})
  (set-syntax-match *rust-mode-syntax-table* #\[ #\])
  (set-syntax-start-multi-comment *rust-mode-syntax-table* "/*")
  (set-syntax-end-multi-comment *rust-mode-syntax-table* "*/")
  (set-syntax-start-c++-comment *rust-mode-syntax-table* #\/)
  (set-syntax-end-c++-comment *rust-mode-syntax-table* #\LFD))

;;; ============================================================
;;; Keymap
;;; ============================================================

(unless *rust-mode-map*
  (setq *rust-mode-map* (make-sparse-keymap))
  (define-key *rust-mode-map* #\{ 'c-electric-insert)
  (define-key *rust-mode-map* #\} 'c-electric-close)
  (define-key *rust-mode-map* #\C-h 'backward-delete-char-untabify-or-selection)
  (define-key *rust-mode-map* #\TAB 'c-indent-line)
  (define-key *rust-mode-map* #\C-M-q 'indent-sexp)
  (define-key *rust-mode-map* #\RET 'c-newline-and-indent))

;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *rust-regexp-keyword-list* nil)

(defun rust-setup-keywords ()
  (unless *rust-regexp-keyword-list*
    (setq *rust-regexp-keyword-list*
	  (compile-regexp-keyword-list
	   '(;; 文字リテラルは「閉じ ' があるものだけ」。ライフタイム
	     ;; ('a, 'static) との区別のため先に置く。
	     ("'\\([^'\n]\\|\\\\.\\)'" nil :string)
	     ;; 属性 #[...] / #![...]
	     ("#\\!?\\[[^]\n]*\\]" nil 0)
	     ;; キーワード
	     ("\\b\\(as\\|async\\|await\\|break\\|const\\|continue\\|crate\\|dyn\\|else\\|enum\\|extern\\|fn\\|for\\|if\\|impl\\|in\\|let\\|loop\\|match\\|mod\\|move\\|mut\\|pub\\|ref\\|return\\|static\\|struct\\|super\\|trait\\|type\\|unsafe\\|use\\|where\\|while\\)\\b" nil 0)
	     ;; 値キーワードと self/Self
	     ("\\b\\(true\\|false\\|self\\|Self\\)\\b" nil 2)
	     ;; マクロ呼び出し foo!
	     ("\\b[A-Za-z_][A-Za-z0-9_]*!" nil :tag)
	     ;; 型らしきもの (大文字始まり)
	     ("\\b[A-Z][A-Za-z0-9_]*" nil :tag)
	     ;; ライフタイム 'a
	     ("'[a-zA-Z_][a-zA-Z0-9_]*" nil :tag)
	     ;; 演算子 -> => ::
	     ("\\(->\\|=>\\|::\\)" nil 0)
	     ;; 数値リテラル (10進・16進・8進・2進・浮動小数)
	     ("\\b0x[0-9a-fA-F_]+\\|\\b0o[0-7_]+\\|\\b0b[01_]+\\|\\b[0-9][0-9_]*\\(\\.[0-9_]+\\)?\\([eE][-+]?[0-9_]+\\)?\\(u8\\|u16\\|u32\\|u64\\|u128\\|usize\\|i8\\|i16\\|i32\\|i64\\|i128\\|isize\\|f32\\|f64\\)?\\b" nil :tag)
	     ))))
  *rust-regexp-keyword-list*)

;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun rust-mode ()
  "Rust ソース編集用のメジャーモード。"
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Rust")
  (setq buffer-mode 'rust-mode)
  (use-syntax-table *rust-mode-syntax-table*)
  (use-keymap *rust-mode-map*)
  (make-local-variable 'mode-specific-indent-command)
  (setq mode-specific-indent-command 'c-indent-line)
  (make-local-variable 'c-indent-level)
  (setq c-indent-level rust-indent-level)
  (make-local-variable 'c-continued-statement-offset)
  (setq c-continued-statement-offset rust-indent-level)
  (make-local-variable 'c-brace-offset)
  (setq c-brace-offset 0)
  (make-local-variable 'c-label-offset)
  (setq c-label-offset (- rust-indent-level))
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|\f")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'indent-tabs-mode)
  (setq indent-tabs-mode *rust-indent-tabs-mode*)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (rust-setup-keywords))
  (setq comment-start "// ")
  (setq comment-end "")
  (setq comment-start-skip "/\\(\\*+\\|/\\)[ \t]*")
  (run-hooks '*rust-mode-hook*))
