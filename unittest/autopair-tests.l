;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/autopair.l と、それを載せている lisp/cmds.l の *self-insert-hook*
;;; のテスト。
;;;
;;; 打鍵はキーマップを経由せず、self-insert-command を *last-command-char*
;;; を束縛して呼ぶ形で再現している。C++ のコマンドループがやっているのは
;;; まさにこれなので、キーマップの外側を除けば実際の打鍵と同じ経路を通る。

(require "autopair")

(defun autopair-test-type (string)
  "STRING の各文字を 1 打鍵ずつ入力したのと同じ経路で挿入する。"
  (dotimes (i (length string))
    (let ((ed::*last-command-char* (char string i)))
      (ed::self-insert-command 1))))

(defun autopair-test-buffer ()
  (buffer-substring (point-min) (point-max)))

(deftest autopair-open-paren-inserts-pair ()
  "開き括弧を打つと閉じ括弧も入り、点はその間に来ること"
  (with-temp-buffer
    (autopair-test-type "(")
    (values (autopair-test-buffer) (point)))
  => "()"
  => 1)

(deftest autopair-all-default-pairs ()
  "既定の対 3 種 (丸・角・波) がいずれも閉じ側を入れること"
  (with-temp-buffer
    (autopair-test-type "([{")
    (values (autopair-test-buffer) (point)))
  => "([{}])"
  => 3)

(deftest autopair-quote-inserts-pair ()
  "二重引用符も対になること"
  (with-temp-buffer
    (autopair-test-type "\"")
    (values (autopair-test-buffer) (point)))
  => "\"\""
  => 1)

(deftest autopair-single-quote-is-not-paired ()
  "シングルクォートは既定の対に入っていないこと (Lisp のクォートなので)"
  (with-temp-buffer
    (autopair-test-type "'")
    (autopair-test-buffer))
  => "'")

(deftest autopair-not-before-word ()
  "語の直前では対にしない (既にあるテキストを挟み込まない)"
  (with-temp-buffer
    (insert "foo")
    (goto-char (point-min))
    (autopair-test-type "(")
    (values (autopair-test-buffer) (point)))
  => "(foo"
  => 1)

(deftest autopair-before-close-paren ()
  "閉じ括弧の直前では対にする (f(|) のような形を作れること)"
  (with-temp-buffer
    (insert "()")
    (goto-char 1)
    (autopair-test-type "(")
    (values (autopair-test-buffer) (point)))
  => "(())"
  => 2)

(deftest autopair-before-whitespace-and-eol ()
  "空白の直前・行末では対にすること"
  (with-temp-buffer
    (insert " x")
    (goto-char (point-min))
    (autopair-test-type "(")
    (autopair-test-buffer))
  => "() x")

(deftest autopair-close-paren-skips-over ()
  "閉じ括弧を打ったところに閉じ括弧があれば、重ねずに乗り越えるだけ"
  (with-temp-buffer
    (autopair-test-type "(")
    (autopair-test-type ")")
    (values (autopair-test-buffer) (point)))
  => "()"
  => 2)

(deftest autopair-close-paren-inserted-when-nothing-to-skip ()
  "乗り越える相手が無ければ閉じ括弧はそのまま挿入されること"
  (with-temp-buffer
    (autopair-test-type ")")
    (values (autopair-test-buffer) (point)))
  => ")"
  => 1)

(deftest autopair-quote-skips-over ()
  "閉じ引用符も同じく乗り越えるだけ (\"\" の中で \" を打っても \"\"\"\" にならない)"
  (with-temp-buffer
    (autopair-test-type "\"")
    (autopair-test-type "\"")
    (values (autopair-test-buffer) (point)))
  => "\"\""
  => 2)

(deftest autopair-quote-after-word-is-plain ()
  "語の直後の引用符は対にしない (foo\" のように閉じるために打つことが多い)"
  (with-temp-buffer
    (insert "don")
    (autopair-test-type "\"")
    (values (autopair-test-buffer) (point)))
  => "don\""
  => 4)

(deftest autopair-typing-a-word-inside-a-pair ()
  "対の中に文字を打っても閉じ側が残ること (通常の入力を壊さない)"
  (with-temp-buffer
    (autopair-test-type "(defun")
    (values (autopair-test-buffer) (point)))
  => "(defun)"
  => 6)

(deftest autopair-not-in-string ()
  "文字列の中では対にしないこと"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "\"abc")
    (autopair-test-type "(")
    (values (parse-point-syntax) (autopair-test-buffer)))
  => :string
  => "\"abc(")

(deftest autopair-not-in-comment ()
  "コメントの中では対にしないこと"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert ";; abc ")
    (autopair-test-type "(")
    (values (parse-point-syntax) (autopair-test-buffer)))
  => :comment
  => ";; abc (")

(deftest autopair-not-after-escape ()
  "エスケープの直後では対にしないこと"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "\\")
    (autopair-test-type "(")
    (autopair-test-buffer))
  => "\\(")

(deftest autopair-disabled ()
  "*autopair-mode* を nil にすれば素の挿入に戻ること"
  (with-temp-buffer
    (let ((ed::*autopair-mode* nil))
      (autopair-test-type "("))
    (values (autopair-test-buffer) (point)))
  => "("
  => 1)

(deftest autopair-prefix-arg-is-plain ()
  "繰り返し引数付きの挿入 (C-u 3 など) は対にしないこと"
  (with-temp-buffer
    (let ((ed::*last-command-char* #\())
      (ed::self-insert-command 3))
    (values (autopair-test-buffer) (point)))
  => "((("
  => 3)

(deftest autopair-overwrite-mode-is-plain ()
  "上書きモードでは対にしないこと (閉じ側を入れると 1 文字余分に潰す)"
  (with-temp-buffer
    (insert "abcd")
    (goto-char (point-min))
    ;; overwrite-mode はバッファローカルにされていないと setq が
    ;; グローバルの値を書き換えるので、必ず戻す (戻さないと以降の
    ;; テストが全部「上書きモード」で走る)。
    (let ((saved overwrite-mode))
      (unwind-protect
	  (progn
	    (setq overwrite-mode t)
	    (autopair-test-type "("))
	(setq overwrite-mode saved)))
    (values (autopair-test-buffer) (point)))
  => "(bcd"
  => 1)

(deftest autopair-delete-backward-deletes-empty-pair ()
  "空の対の中で BS を押すと 2 文字まとめて消えること"
  (with-temp-buffer
    (autopair-test-type "x(")
    (ed::delete-backward-char-or-selection)
    (values (autopair-test-buffer) (point)))
  => "x"
  => 1)

(deftest autopair-delete-backward-deletes-one-char-otherwise ()
  "対でないところでは 1 文字だけ消えること"
  (with-temp-buffer
    (insert "abc")
    (ed::delete-backward-char-or-selection)
    (values (autopair-test-buffer) (point)))
  => "ab"
  => 2)

(deftest autopair-delete-backward-keeps-non-empty-pair ()
  "対の中身があるときは片側だけ消さないこと"
  (with-temp-buffer
    (insert "(x)")
    (goto-char 1)
    (ed::delete-backward-char-or-selection)
    (autopair-test-buffer))
  => "x)")

(deftest autopair-wraps-selection ()
  "選択したまま開き括弧を打つと、置き換えではなく囲むこと"
  (with-temp-buffer
    (insert "abc def")
    (goto-char 0)
    (start-selection 2 nil)
    (goto-char 3)
    (autopair-test-type "(")
    (values (autopair-test-buffer)
	    (buffer-substring (min (selection-mark) (selection-point))
			      (max (selection-mark) (selection-point)))))
  => "(abc) def"
  => "abc")

(deftest autopair-wraps-selection-with-quotes ()
  "引用符でも同じく囲めること"
  (with-temp-buffer
    (insert "abc")
    (goto-char 0)
    (start-selection 2 nil)
    (goto-char 3)
    (autopair-test-type "\"")
    (autopair-test-buffer))
  => "\"abc\"")

(deftest autopair-pairs-are-customizable ()
  "*autopair-pairs* に足した対が効くこと"
  (with-temp-buffer
    (let ((ed::*autopair-pairs* (cons (cons #\< #\>) ed::*autopair-pairs*)))
      (autopair-test-type "<"))
    (autopair-test-buffer))
  => "<>")

(deftest self-insert-hook-can-take-over ()
  "*self-insert-hook* が non-nil を返したとき、self-insert-command が
自分では何も挿入しないこと (autopair 以外の用途でも使えるという確認)"
  (with-temp-buffer
    (let ((ed::*self-insert-hook*
	   #'(lambda (char arg) (insert "<" char ">") t)))
      (autopair-test-type "a"))
    (autopair-test-buffer))
  => "<a>")

(deftest self-insert-hook-falls-through-on-nil ()
  "*self-insert-hook* が nil を返したときは通常の挿入が行われること"
  (with-temp-buffer
    (let ((ed::*self-insert-hook* #'(lambda (char arg) nil)))
      (autopair-test-type "a"))
    (autopair-test-buffer))
  => "a")

(deftest autopair-hooked-into-self-insert ()
  "既定で *self-insert-hook* に autopair が入っていること"
  ed::*self-insert-hook*
  => ed::autopair-self-insert-hook)

(deftest autopair-hooked-into-delete-backward ()
  "既定で *delete-backward-hook* に autopair が入っていること"
  ed::*delete-backward-hook*
  => ed::autopair-delete-backward-hook)

(deftest delete-backward-hook-falls-through-on-nil ()
  "*delete-backward-hook* が nil を返したときは通常の 1 文字削除になること"
  (with-temp-buffer
    (insert "abc")
    (let ((ed::*delete-backward-hook* #'(lambda (n) nil)))
      (ed::delete-backward-char-or-selection))
    (autopair-test-buffer))
  => "ab")

(deftest autopair-leader-toggle ()
  "Leader t p でトグルできること"
  (lookup-keymap ed::*leader-toggle-map* #\p)
  => toggle-autopair)
