;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/expand-region.l のテスト。
;;;
;;; 「1 段階ごとに何が選ばれるか」を選択された文字列そのもので見ている。
;;; 段階の並びは候補の集合と「今の範囲を真に含む中で最小」という規則から
;;; 決まるので、途中の 1 段を取り違えるとその後ろも全部ずれる。

(require "expand-region")

(defun expand-region-test-selection ()
  "選択されているテキスト。選択が無ければ nil。"
  (and (get-selection-type)
       (buffer-substring (min (selection-mark) (selection-point))
			 (max (selection-mark) (selection-point)))))

(defun expand-region-test-steps (text search n &optional (mode 'ed::lisp-mode))
  "TEXT を入れて SEARCH の位置に点を置き、expand-region を N 回かけて
そのたびの選択テキストをリストで返す。"
  (funcall mode)
  (insert text)
  (goto-char (string-match search (buffer-substring (point-min) (point-max))))
  (let ((acc nil))
    (dotimes (i n)
      (ed::expand-region)
      (push (expand-region-test-selection) acc))
    (nreverse acc)))

(deftest expand-region-word-then-symbol ()
  "単語 → シンボル (ハイフン込み) の順に広がること"
  (with-temp-buffer
    (expand-region-test-steps "(foo-bar baz)" "bar" 2))
  => ("bar" "foo-bar"))

(deftest expand-region-symbol-then-list ()
  "シンボル → 括弧の中 → 括弧ごと の順に広がること"
  (with-temp-buffer
    (expand-region-test-steps "(foo-bar baz)" "bar" 4))
  => ("bar" "foo-bar" "foo-bar baz" "(foo-bar baz)"))

(deftest expand-region-nested-lists ()
  "括弧を内側から外側へ 1 段ずつ辿ること"
  (with-temp-buffer
    (expand-region-test-steps "(a (b (c d) e) f)" "c" 6))
  => ("c" "c d" "(c d)" "b (c d) e" "(b (c d) e)" "a (b (c d) e) f"))

(deftest expand-region-string ()
  "引用符の中 → 引用符ごと の順に広がること"
  (with-temp-buffer
    (expand-region-test-steps "(list \"hi there\" x)" "there" 4))
  => ("there" "hi there" "\"hi there\"" "list \"hi there\" x"))

(deftest expand-region-from-empty-selection-at-symbol-start ()
  "シンボルの先頭に点があっても、そのシンボルから始まること"
  (with-temp-buffer
    (expand-region-test-steps "(foo bar)" "foo" 2))
  => ("foo" "foo bar"))

(deftest expand-region-line-when-no-list ()
  "括弧の外では 行 → バッファ全体 になること"
  (with-temp-buffer
    (expand-region-test-steps "alpha beta
gamma
" "beta" 3 'ed::fundamental-mode))
  => ("beta" "alpha beta" "alpha beta
gamma
"))

(deftest expand-region-stops-at-buffer ()
  "バッファ全体まで行ったらそれ以上広がらず、選択も変わらないこと"
  (with-temp-buffer
    (ed::fundamental-mode)
    (insert "abc")
    (goto-char 1)
    (dotimes (i 8) (ed::expand-region))
    (values (expand-region-test-selection)
	    (ed::expand-region)))
  => "abc"
  => nil)

(deftest contract-region-retraces ()
  "contract-region が広げてきた道を逆に戻ること"
  (with-temp-buffer
    (expand-region-test-steps "(foo-bar baz)" "bar" 4)
    (let ((acc nil))
      (dotimes (i 4)
	(ed::contract-region)
	(push (expand-region-test-selection) acc))
      (nreverse acc)))
  => ("foo-bar baz" "foo-bar" "bar" nil))

(deftest contract-region-without-history ()
  "広げていないときの contract-region は何もしないこと"
  (with-temp-buffer
    (ed::fundamental-mode)
    (insert "abc")
    (goto-char 1)
    (values (ed::contract-region) (expand-region-test-selection)))
  => nil
  => nil)

(deftest expand-region-restarts-after-moving ()
  "途中で点を動かしたら、履歴を捨てて新しい位置から数え直すこと"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "(foo-bar baz)")
    (goto-char (string-match "bar" (buffer-substring (point-min) (point-max))))
    (ed::expand-region)
    (ed::expand-region)
    ;; ここで別の場所へ移動する
    (stop-selection)
    (goto-char (string-match "baz" (buffer-substring (point-min) (point-max))))
    (ed::expand-region)
    (expand-region-test-selection))
  => "baz")

(deftest expand-region-existing-selection-is-honored ()
  "手で作った選択範囲からでも、それを含む最小の単位へ広がること"
  (with-temp-buffer
    (ed::lisp-mode)
    (insert "(foo-bar baz)")
    ;; "o-b" を選択した状態から
    (goto-char 3)
    (start-selection 2 nil)
    (goto-char 6)
    (ed::expand-region)
    (expand-region-test-selection))
  => "foo-bar")

(deftest expand-region-keys ()
  "C-= / M-= と Leader v / V に割り当てられていること"
  (values (lookup-keymap *global-keymap* #\C-=)
	  (lookup-keymap *global-keymap* #\M-=)
	  (lookup-keymap ed::*leader-map* #\v)
	  (lookup-keymap ed::*leader-map* #\V))
  => expand-region
  => contract-region
  => expand-region
  => contract-region)
