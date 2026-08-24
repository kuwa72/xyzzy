;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Tests for Leader Key and Which-key guidance
;;;

(unless (member "test-helpers" *modules* :test #'string=)
  (load-file (merge-pathnames "test-helpers.l" (directory-namestring *load-pathname*))))
(require "leader")

(in-package "editor")

(defun test-leader-map-structure ()
  ;; 基本キーマップの存在確認
  (assert-true (keymapp *leader-map*))
  (assert-true (keymapp *leader-file-map*))
  (assert-true (keymapp *leader-buffer-map*))
  (assert-true (keymapp *leader-project-map*))
  (assert-true (keymapp *leader-search-map*))
  (assert-true (keymapp *leader-git-map*))
  (assert-true (keymapp *leader-toggle-map*))
  (assert-true (keymapp *leader-window-map*))
  (assert-true (keymapp *leader-help-map*))

  ;; Root Leader Map へのカテゴリバインド
  (assert-equal *leader-file-map* (lookup-keymap *leader-map* #\f))
  (assert-equal *leader-buffer-map* (lookup-keymap *leader-map* #\b))
  (assert-equal *leader-project-map* (lookup-keymap *leader-map* #\p))
  (assert-equal *leader-search-map* (lookup-keymap *leader-map* #\s))
  (assert-equal *leader-git-map* (lookup-keymap *leader-map* #\g))
  (assert-equal *leader-toggle-map* (lookup-keymap *leader-map* #\t))
  (assert-equal *leader-window-map* (lookup-keymap *leader-map* #\w))
  (assert-equal *leader-help-map* (lookup-keymap *leader-map* #\h))

  ;; ダイレクトキー
  (assert-equal 'execute-extended-command (lookup-keymap *leader-map* #\SPC))
  (assert-equal 'grep (lookup-keymap *leader-map* #\/)))

(defun test-leader-category-bindings ()
  ;; File
  (assert-equal 'find-file (lookup-keymap *leader-file-map* #\f))
  (assert-equal 'recentf-open (lookup-keymap *leader-file-map* #\r))
  (assert-equal 'save-buffer (lookup-keymap *leader-file-map* #\s))
  (assert-equal 'open-filer (lookup-keymap *leader-file-map* #\d))

  ;; Buffer
  (assert-equal 'switch-to-buffer (lookup-keymap *leader-buffer-map* #\b))
  (assert-equal 'kill-selected-buffer (lookup-keymap *leader-buffer-map* #\k))
  (assert-equal 'list-buffers (lookup-keymap *leader-buffer-map* #\l))

  ;; Window
  (assert-equal 'split-window (lookup-keymap *leader-window-map* #\s))
  (assert-equal 'split-window-vertically (lookup-keymap *leader-window-map* #\v))
  (assert-equal 'split-window (lookup-keymap *leader-window-map* #\2))
  (assert-equal 'split-window-vertically (lookup-keymap *leader-window-map* #\5))
  (assert-equal 'other-window (lookup-keymap *leader-window-map* #\o))
  (assert-equal 'delete-window (lookup-keymap *leader-window-map* #\d))
  (assert-equal 'delete-other-windows (lookup-keymap *leader-window-map* #\m))

  ;; Help
  (assert-equal 'describe-key (lookup-keymap *leader-help-map* #\k))
  (assert-equal 'describe-function (lookup-keymap *leader-help-map* #\f))
  (assert-equal 'describe-bindings (lookup-keymap *leader-help-map* #\b)))

(defun test-which-key-formatting ()
  (let ((prompt (which-key-format-prompt "Leader" *leader-map*)))
    (assert-true (stringp prompt))
    (assert-true (string-match "\\[Leader\\]" prompt))
    (assert-true (string-match "f:File\\+" prompt))
    (assert-true (string-match "b:Buffer\\+" prompt))
    (assert-true (string-match "SPC:M-x" prompt)))

  (let ((file-prompt (which-key-format-prompt "Leader > File" *leader-file-map*)))
    (assert-true (stringp file-prompt))
    (assert-true (string-match "\\[Leader > File\\]" file-prompt))
    (assert-true (string-match "f:Find" file-prompt))
    (assert-true (string-match "r:Recent" file-prompt))
    (assert-true (string-match "s:Save" file-prompt))))

(defun test-leader-define-key-custom ()
  ;; カスタムキーの動的登録テスト
  (leader-define-key "o z" 'describe-bindings "MyBindings")
  (let ((submap (lookup-keymap *leader-map* #\o)))
    (assert-true (keymapp submap))
    (assert-equal 'describe-bindings (lookup-keymap submap #\z))
    (assert-equal "MyBindings" (which-key-get-description 'describe-bindings))))

(defun test-leader-global-keys ()
  ;; M-m と C-c SPC のバインド確認
  (assert-equal 'execute-leader-key (lookup-keymap *global-keymap* '(#\M-m)))
  (assert-equal 'execute-leader-key (lookup-keymap *global-keymap* '(#\C-c #\SPC))))

(defun test-all-bound-commands-exist ()
  ;; 全 Leader キーマップ内のすべてのバインド先コマンドが実際に存在するか再帰チェック
  (labels ((check-map (keymap path)
	     (let ((bindings (which-key-collect-bindings keymap)))
	       (dolist (b bindings)
		 (let ((target (cdr b))
		       (k (car b)))
		   (cond
		    ((keymapp target)
		     (check-map target (format nil "~A ~:C" path k)))
		    ((symbolp target)
		     (let ((bound (or (fboundp target) (autoload-function-p target))))
		       (unless bound
			 (error "Leader command is undefined: ~A in ~A" target path))
		       (assert-true bound)))
		    (t nil)))))))
    (check-map *leader-map* "Leader")))

(defun run-leader-unit-tests ()
  (format t "Running leader unit tests...~%")
  (test-leader-map-structure)
  (test-leader-category-bindings)
  (test-which-key-formatting)
  (test-leader-define-key-custom)
  (test-leader-global-keys)
  (test-all-bound-commands-exist)
  (format t "All leader unit tests PASSED.~%"))

(run-leader-unit-tests)
