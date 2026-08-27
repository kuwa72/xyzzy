;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/snippet.l のテスト。
;;;
;;; テンプレートの解析 (snippet-parse) と、実際にバッファへ展開したときの
;;; 文字列・カーソル位置・タブストップの巡回を見ている。

(require "snippet")

(defun snippet-test-contents ()
  (buffer-substring (point-min) (point-max)))

(defun snippet-test-parse (template)
  (multiple-value-bind (text fields) (ed::snippet-parse template)
    (list text fields)))

;;;
;;; 解析
;;;

(deftest snippet-parse-plain ()
  "タブストップが無ければそのまま"
  (snippet-test-parse "hello")
  => ("hello" nil))

(deftest snippet-parse-bare-stops ()
  "$1 $2 は位置だけを覚え、文字は残さないこと"
  (snippet-test-parse "a$1b$2c")
  => ("abc" ((1 1 0) (2 2 0))))

(deftest snippet-parse-default-values ()
  "${1:x} は既定値を埋め、その長さも覚えること"
  (snippet-test-parse "f(${1:arg}, ${2:opt})")
  => ("f(arg, opt)" ((1 2 3) (2 7 3))))

(deftest snippet-parse-exit-point ()
  "$0 も同じ形で入り、番号順に並ぶこと"
  (snippet-test-parse "if ${1:c} then $0 end")
  => ("if c then  end" ((0 10 0) (1 3 1))))

(deftest snippet-parse-mirror ()
  "同じ番号が 2 度以上出たら、2 度目以降は既定値を埋めるだけで
タブストップは作らないこと (for (int i = 0; i < n; i++) と書けるように)"
  (snippet-test-parse "for (int ${1:i} = 0; $1 < ${2:n}; $1++)")
  => ("for (int i = 0; i < n; i++)" ((1 9 1) (2 20 1))))

(deftest snippet-parse-mirror-before-default ()
  "ミラーが既定値より先に出てきても埋まること"
  (snippet-test-parse "$1 = ${1:x}")
  => ("x = x" ((1 0 1))))

(deftest snippet-parse-dollar-escape ()
  "$$ は文字としての $"
  (snippet-test-parse "cost: $$${1:100}")
  => ("cost: $100" ((1 7 3))))

(deftest snippet-parse-unclosed-brace ()
  "閉じていない ${ はそのまま文字として出すこと (壊れたテンプレートで
落ちない)"
  (snippet-test-parse "a${1:b")
  => ("a${1:b" nil))

(deftest snippet-parse-non-numeric-brace ()
  "${foo} のように番号でないものは文字として出すこと"
  (snippet-test-parse "${foo}")
  => ("${foo}" nil))

;;;
;;; 字下げ
;;;

(deftest snippet-indent-lines ()
  "2 行目以降に桁数分の空白を足すこと"
  (ed::snippet-indent-lines "a
b
c" 2)
  => "a
  b
  c")

(deftest snippet-indent-lines-keeps-blank-lines ()
  "空行を落とさないこと"
  (ed::snippet-indent-lines "a

b" 1)
  => "a

 b")

(deftest snippet-indent-lines-keeps-trailing-newline ()
  "末尾の改行を落とさないこと"
  (ed::snippet-indent-lines "a
b
" 1)
  => "a
 b
")

(deftest snippet-indent-lines-at-column-zero ()
  "行頭からの展開では何も足さないこと"
  (ed::snippet-indent-lines "a
b" 0)
  => "a
b")

;;;
;;; 展開
;;;

(deftest snippet-insert-puts-cursor-on-first-stop ()
  "展開すると最初のタブストップに来て、既定値が選択されていること"
  (with-temp-buffer
    (ed::snippet-insert "f(${1:arg}, ${2:opt})")
    (values (snippet-test-contents)
	    (buffer-substring (min (selection-mark) (selection-point))
			      (max (selection-mark) (selection-point)))))
  => "f(arg, opt)"
  => "arg")

(deftest snippet-insert-multiline-indents ()
  "複数行のテンプレートが展開を始めた桁に揃うこと"
  (with-temp-buffer
    (insert "  ")
    (ed::snippet-insert "if (${1:c})
  {
    $0
  }")
    (snippet-test-contents))
  => "  if (c)
    {
      
    }")

(deftest snippet-next-field-cycles ()
  "M-i で次のタブストップへ進み、最後は $0 へ行くこと"
  (with-temp-buffer
    (ed::snippet-insert "f(${1:a}, ${2:b})$0")
    ;; 既定値は選択された状態になるので、点は既定値の末尾に来る。
    (let ((first (point)))
      (ed::snippet-next-field)
      (let ((second (point)))
	(ed::snippet-next-field)
	(values first second (point)))))
  => 3
  => 6
  => 7)

(deftest snippet-next-field-without-template ()
  "展開していないときの M-i は何もしないこと"
  (with-temp-buffer
    (ed::snippet-clear-fields)
    (ed::snippet-next-field))
  => nil)

(deftest snippet-fields-follow-edits ()
  "先のタブストップを打ち替えても、後ろのタブストップがずれないこと
(オフセットではなくマーカーで覚えているため)"
  (with-temp-buffer
    (ed::snippet-insert "f(${1:a}, ${2:b})")
    ;; 選択中の "a" を長い名前に打ち替える
    (delete-region (min (selection-mark) (selection-point))
		   (max (selection-mark) (selection-point)))
    (insert "argument")
    (ed::snippet-next-field)
    (values (snippet-test-contents)
	    (buffer-substring (min (selection-mark) (selection-point))
			      (max (selection-mark) (selection-point)))))
  => "f(argument, b)"
  => "b")

;;;
;;; 登録と略語展開
;;;

(deftest define-snippet-and-lookup ()
  "登録した略語が引けて、名前順に並ぶこと"
  (let ((ed::*snippet-table* (make-hash-table :test #'eq)))
    (ed::define-snippet 'ed::text-mode "zzz" "Z")
    (ed::define-snippet 'ed::text-mode "aaa" "A")
    (values (mapcar #'car (ed::snippet-alist 'ed::text-mode))
	    (cdr (assoc "aaa" (ed::snippet-alist 'ed::text-mode) :test #'string=))))
  => ("aaa" "zzz")
  => "A")

(deftest define-snippet-overwrites ()
  "同じ略語は上書きされること (重複して並ばない)"
  (let ((ed::*snippet-table* (make-hash-table :test #'eq)))
    (ed::define-snippet 'ed::text-mode "x" "old")
    (ed::define-snippet 'ed::text-mode "x" "new")
    (values (length (ed::snippet-alist 'ed::text-mode))
	    (cdr (assoc "x" (ed::snippet-alist 'ed::text-mode) :test #'string=))))
  => 1
  => "new")

(deftest snippet-expand-replaces-the-abbrev ()
  "点の直前の略語が消えてテンプレートに置き換わること"
  (with-temp-buffer
    (let ((ed::*snippet-table* (make-hash-table :test #'eq)))
      (ed::text-mode)
      (ed::define-snippet 'ed::text-mode "gr" "greeting: ${1:hi}")
      (insert "x gr")
      (ed::snippet-expand)
      (snippet-test-contents)))
  => "x greeting: hi")

(deftest snippet-word-before-point ()
  "略語として拾う語の範囲"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "(foo bar-baz")
    (multiple-value-bind (word start) (ed::snippet-word-before-point)
      (values word start)))
  => "bar-baz"
  => 5)

(deftest snippet-default-templates-exist ()
  "既定のテンプレートが主要モードに入っていること"
  (values (and (assoc "defun" (ed::snippet-alist 'ed::lisp-mode) :test #'string=) t)
	  (and (assoc "def" (ed::snippet-alist 'ed::python-mode) :test #'string=) t)
	  (and (assoc "for" (ed::snippet-alist 'ed::c++-mode) :test #'string=) t)
	  ;; typescript は javascript と同じ表を共有する
	  (equal (ed::snippet-alist 'ed::typescript-mode)
		 (ed::snippet-alist 'ed::javascript-mode)))
  => t
  => t
  => t
  => t)

(deftest snippet-default-templates-parse ()
  "既定のテンプレートがすべて解析できて、$ の記法が残らないこと"
  (let ((bad nil))
    (maphash #'(lambda (mode alist)
		 (dolist (entry alist)
		   (multiple-value-bind (text fields)
		       (ed::snippet-parse (cdr entry))
		     (declare (ignore fields))
		     (when (find #\$ text)
		       (push (list mode (car entry) text) bad)))))
	     ed::*snippet-table*)
    bad)
  => nil)

(deftest snippet-keys ()
  "M-i と Leader c i / Leader c e に割り当てられていること"
  (values (lookup-keymap ed::esc-map #\i)
	  (lookup-keymap ed::*leader-code-map* #\i)
	  (lookup-keymap ed::*leader-code-map* #\e))
  => snippet-next-field
  => snippet-insert-by-name
  => snippet-expand)
