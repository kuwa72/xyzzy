;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;; tree-sitter: generic syntax highlighting infrastructure
;;;
;;; Language-specific support lives in the respective mode files:
;;;   c-mode.l   — C and C++ (colors, indentation, key bindings)
;;;   cc-mode.l  — C++ key bindings and grammar registration
;;;   perl.l     — Perl (colors, indentation, key bindings)
;;;   markdown.l — Markdown (colors)
;;;
;;; Debug commands bound by mode setup:
;;;   C-c C-t  ts-show-ancestors  — show node chain at point
;;;   C-c C-i  ts-test-indent     — show ts indent column for current line

(in-package "editor")

(export '(*ts-highlight* toggle-ts-highlight))

;;; --- Configuration -------------------------------------------------------

(defvar *ts-grammar-directory*
  (merge-pathnames "grammars/" (si:system-root))
  "Root directory for per-language subdirectories (grammars/<lang>/).")

(defvar *ts-default-color-alist*
  '(("comment" . 15)
    ("string" . 9)
    ("number" . 13)
    ("constant" . 13)
    ("operator" . 12)
    ("keyword" . 12)
    ("type" . 13)
    ("function" . 10)
    ("function.call" . 10)
    ("function.definition" . 10)
    ("variable" . 7)
    ("property" . 7)
    ("tag" . 12))
  "Default Tree-sitter capture colors for modes without a custom palette.")

(defvar *ts-grammar-suffix* (if (featurep :unix) ".so" ".dll")
  "文法の共有ライブラリの拡張子。

**ここが合っていないと C++ 側が動いていても色が付かない。** 探すファイルが
見つからないだけなので `si:load-ts-grammar' まで届かず、例外も出ないまま
諦める (issue #150)。

読み込み時に決めているのは、`.lc' が同じプラットフォームの別アーキとの間で
使い回されるため。**読み込み時条件 (`#+unix') で書くとバイトコンパイルした
機械の側に焼き付く。**

macOS は `.dylib' になるが、リポジトリに置いてある文法は `.dll' と `.so'
だけなので、そこは自分でビルドする話になる。")

;;; --- Grammar registry ----------------------------------------------------

(defvar *ts-grammar-registry* (make-hash-table)
  "Hash table mapping mode symbol -> (grammar query colors).")

(defun ts-mode-to-lang (mode)
  "Derive grammar lang name from MODE: strip trailing -mode suffix."
  (let* ((name (string-downcase (symbol-name mode)))
         (pos  (- (length name) 5)))
    (if (and (> pos 0) (string= name "-mode" :start1 pos))
        (subseq name 0 pos)
      name)))

(defun ts-grammar-file (lang)
  "Return the path to the grammar DLL for LANG."
  (merge-pathnames (format nil "~A/tree-sitter-~A~A" lang lang *ts-grammar-suffix*)
                   *ts-grammar-directory*))

(defun ts-grammar-query-file (lang)
  "Return the path to highlights.scm for LANG."
  (merge-pathnames (format nil "~A/highlights.scm" lang)
                   *ts-grammar-directory*))

(defun ts-read-query-file (path)
  "Read PATH as text and return its contents as a string, or nil."
  (when (file-exist-p path)
    (with-open-file (s path :direction :input)
      (let ((result ""))
        (loop
          (let ((line (read-line s nil nil)))
            (unless line (return result))
            (setq result (concat result line "\n"))))))))

(defun ts-register-mode (mode &key lang query colors)
  "Register tree-sitter support for MODE.
LANG defaults to MODE name with -mode suffix stripped (c-mode -> \"c\").
QUERY defaults to reading grammars/<lang>/highlights.scm.
COLORS is an alist of (capture-name . fg-color-number)."
  (let* ((lang-name    (or lang (ts-mode-to-lang mode)))
         (query-str    (or query
                           (ts-read-query-file (ts-grammar-query-file lang-name))
                           (error "ts: no query for ~A (tried ~A)"
                                  lang-name (ts-grammar-query-file lang-name))))
         (gram         (si:load-ts-grammar (ts-grammar-file lang-name) lang-name)))
    (setf (gethash mode *ts-grammar-registry*)
          (list gram query-str (or colors *ts-default-color-alist*)))
    gram))

;;; --- Buffer-local state --------------------------------------------------

(defvar-local *ts-highlight-active* nil)
(defvar-local *ts-buffer-grammar*   nil)
(defvar-local *ts-buffer-query*     nil)
(defvar-local *ts-buffer-colors*    nil)
(defvar-local *ts-calc-indent-function* nil
  "Mode-specific indent calculator. Set by each mode's ts enable hook.
Called by ts-test-indent with no arguments; should return a column or nil.")

(defvar *ts-highlight* t
  "nil なら tree-sitter による色付けを行わない。`toggle-ts-highlight' で
切り替えられる。

tree-sitter が使う `set-text-attribute' の `:foreground' が指すのは
「文字1〜文字15」という 16 色表で、カラーテーマが書き換える役割色
(`set-buffer-colors') とは別物である。以前はこの表を Lisp から触れず、
選んだ配色の上に赤・緑・黄の固定色が塗り重なっていた (issue #98)。今は
カラーテーマが `set-text-attribute-colors' でこの表も背景に合わせるので、
色付けを切らなくてもテーマから浮かない。

**色みそのものは番号で決まったまま**である (1 は赤、2 は緑…)。テーマの
キーワード色をそのまま使うわけではないので、配色が気に入らなければこれを
nil にしてキーワードファイルの色付けだけにできる。")

(defun ts-enable-for-buffer ()
  "Enable tree-sitter highlighting for the current buffer (uses buffer-mode)."
  (interactive)
  (let ((entry (and *ts-highlight* (gethash buffer-mode *ts-grammar-registry*))))
    (when entry
      (setq *ts-buffer-grammar*   (first  entry)
            *ts-buffer-query*     (second entry)
            *ts-buffer-colors*    (third  entry)
            *ts-highlight-active* t)
      (add-hook '*post-command-hook* 'ts-schedule-highlight)
      (ts-schedule-highlight))))

(defun ts-disable-for-buffer ()
  "Disable tree-sitter highlighting for the current buffer."
  (interactive)
  (setq *ts-highlight-active* nil)
  (stop-timer 'ts-do-highlight)
  (save-excursion
    (delete-text-attributes 'ts-face)))

(defun toggle-ts-highlight (&optional (arg nil sv))
  "tree-sitter による色付けの有効・無効を切り替える。

無効にすると、開いているバッファの色付けもその場で外す。有効にしても
既に開いているバッファには効かないので、そのバッファで
`ts-enable-for-buffer' を呼ぶか開き直すこと。"
  (interactive)
  (setq *ts-highlight* (if sv arg (not *ts-highlight*)))
  (unless *ts-highlight*
    (dolist (buf (buffer-list))
      (ignore-errors
	(save-excursion
	  (set-buffer buf)
	  (when *ts-highlight-active*
	    (ts-disable-for-buffer))))))
  (message "tree-sitter highlight: ~:[off~;on~]" *ts-highlight*)
  *ts-highlight*)


;;; --- Highlight scheduling ------------------------------------------------

(defun ts-visible-range ()
  "Return (start-row . end-row) as 0-based rows for the visible window ±5."
  (let* ((win-start (1- (get-window-start-line)))
         (start-row (max 0 (- win-start 5)))
         (end-row   (+ win-start (window-lines) 5)))
    (cons start-row end-row)))

(defun ts-do-highlight ()
  "Timer target: apply highlights for the current buffer if ts is active."
  (ignore-errors
    (when *ts-highlight-active*
      (let ((range (ts-visible-range)))
        (unless (si:ts-apply-highlights *ts-buffer-grammar* *ts-buffer-query*
                                        (selected-buffer)
                                        (car range) (cdr range)
                                        'ts-face *ts-buffer-colors*)
          (start-timer 0.1 'ts-do-highlight t)))))
  (refresh-screen))

(defun ts-schedule-highlight ()
  "Post-command hook: apply cached highlights immediately, then reschedule."
  (when *ts-highlight-active*
    (ignore-errors
      (let ((range (ts-visible-range)))
        (si:ts-apply-highlights *ts-buffer-grammar* *ts-buffer-query*
                                (selected-buffer)
                                (car range) (cdr range)
                                'ts-face *ts-buffer-colors*)))
    (stop-timer 'ts-do-highlight)
    (start-timer 0.1 'ts-do-highlight t)))

;;; --- Debug utilities -----------------------------------------------------

(defun ts-show-ancestors ()
  "Show tree-sitter node chain at point in *ts-ancestors* buffer."
  (interactive)
  (let* ((g         *ts-buffer-grammar*)
         (ancestors (and g (si:ts-node-ancestors g (selected-buffer) (point)))))
    (if (null ancestors)
        (message "ts: no parse tree yet")
      (progn
        (message "ts: ~A" (first (first ancestors)))
        (with-output-to-temp-buffer ("*ts-ancestors*")
          (dolist (a ancestors)
            (format t "~A  [~D, ~D)~%" (first a) (second a) (third a))))))))

(defun ts-test-indent ()
  "Show what the ts indent calculator would return for the current line."
  (interactive)
  (if (null *ts-calc-indent-function*)
      (message "ts-indent: not available in this mode")
    (let ((col (funcall *ts-calc-indent-function*)))
      (if (integerp col)
          (message "ts-indent: ~D  (current: ~D)"
                   col
                   (save-excursion
                     (goto-bol) (skip-chars-forward " \t") (current-column)))
        (message "ts-indent: no parse tree yet")))))

(defun ts-print-spans (&optional buffer)
  "Print tree-sitter capture spans to *ts*."
  (interactive)
  (let ((spans (si:ts-query-buffer *ts-buffer-grammar*
                                   *ts-buffer-query*
                                   buffer)))
    (with-output-to-temp-buffer ("*ts*")
      (format t "ts:~D spans~%" (length spans))
      (dolist (s spans)
        (format t "  ~A  [~D, ~D)~%" (first s) (second s) (third s))))))


;;; Register grammars for modes whose source files may have been loaded before ts.l.
(dolist (entry '((cmake-mode . "cmake")
                 (python-mode . "python")
                 (json-mode . "json")
                 (yaml-mode . "yaml")
                 (shell-script-mode . "bash")
                 (javascript-mode . "javascript")))
  (ignore-errors (ts-register-mode (car entry) :lang (cdr entry))))
