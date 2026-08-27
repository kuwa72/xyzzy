;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/fuzzy-mx.l と、lisp/fuzzy-complete.l に足した
;;; orderless (空白区切り順不同) 絞り込み・幅に合わせた候補表示のテスト。
;;;
;;; 絞り込みループ本体 (read-char で 1 文字ずつ読む部分) も、read-char を
;;; 差し替えて打鍵列を流し込む形でテストしている。キーマップを経由しない
;;; だけで、ループの中身は実際の操作と同じ経路を通る。

(require "fuzzy-mx")

(defmacro with-fuzzy-keys (keys &body body)
  "KEYS (文字のリスト) を read-char が順に返すようにして BODY を実行する。
尽きたら C-g を返す: 打鍵列を取り違えてもテストが無限ループにならない。"
  `(let ((%orig (symbol-function 'read-char))
	 (%keys ,keys))
     (unwind-protect
	 (progn
	   (setf (symbol-function 'read-char)
		 #'(lambda (&rest args) (if %keys (pop %keys) #\C-g)))
	   ,@body)
       (setf (symbol-function 'read-char) %orig))))

(defun fuzzy-keys (string &rest extra)
  "STRING の各文字に EXTRA のキーを続けた打鍵列。"
  (append (coerce string 'list) extra))

(defvar *fuzzy-test-candidates*
  '("list-buffers" "buffer-menu" "switch-to-buffer" "list-holidays"))

(defun fuzzy-test-read (keys &rest args)
  (with-fuzzy-keys keys
    (apply #'ed::fuzzy-completing-read "test: " *fuzzy-test-candidates* args)))

;;;
;;; orderless (空白区切り・順不同)
;;;

(deftest fuzzy-orderless-matches-in-any-order ()
  "空白区切りのキーワードは順不同でどれも含めば一致すること"
  (values
   (and (ed::fuzzy-score "open-filer" "file open") t)
   (and (ed::fuzzy-score "open-filer" "open file") t)
   ;; 片方が含まれなければ不一致
   (ed::fuzzy-score "open-filer" "open zzz"))
  => t
  => t
  => nil)

(deftest fuzzy-orderless-single-token-unchanged ()
  "空白が無いときのスコアは今までと同じ (1 トークンの部分列一致)"
  (values
   (ed::fuzzy-score "project.l" "prl")
   (ed::fuzzy-score "project.l" "lpr"))
  => #.(ed::fuzzy-score-token "project.l" "prl")
  => nil)

(deftest fuzzy-orderless-blank-query-does-not-narrow ()
  "空白だけのクエリでは絞り込まないこと (打ちかけの状態)"
  (let ((c '("aaa" "bbb" "ccc")))
    (values (ed::fuzzy-filter c "")
	    (ed::fuzzy-filter c " ")
	    (ed::fuzzy-filter c "   ")))
  => ("aaa" "bbb" "ccc")
  => ("aaa" "bbb" "ccc")
  => ("aaa" "bbb" "ccc"))

(deftest fuzzy-orderless-filter ()
  "空白区切りで両方を含むものだけが残ること"
  (ed::fuzzy-filter '("list-buffers" "buffer-menu" "switch-to-buffer" "list-holidays")
		    "buf list")
  => ("list-buffers"))

(deftest fuzzy-split-query ()
  "クエリの分割 (連続する空白・タブは 1 つの区切り扱い)"
  (values (ed::fuzzy-split-query "a b")
	  (ed::fuzzy-split-query "  a   b  ")
	  (ed::fuzzy-split-query "")
	  (ed::fuzzy-split-query "   "))
  => ("a" "b")
  => ("a" "b")
  => nil
  => nil)

(deftest fuzzy-score-penalizes-scattered-matches ()
  "一致が散らばっているものより、まとまっているものが上に来ること。
これが無いと \"buf\" で save-buffer より backward-delete-char-untabify
(b...u...b...if) が上に出た"
  (values
   (> (ed::fuzzy-score "save-buffer" "buf")
      (ed::fuzzy-score "backward-delete-char-untabify" "buf"))
   ;; 散らばりのペナルティを入れても、既にあった性質は保つこと
   (> (ed::fuzzy-score "foo_bar_baz.l" "fbb")
      (ed::fuzzy-score "xfooxbarxbazx" "fbb"))
   (> (ed::fuzzy-score "project.l" "proj")
      (ed::fuzzy-score "myproject.l" "proj")))
  => t
  => t
  => t)

;;;
;;; 幅に合わせた候補表示
;;;

(deftest fuzzy-fit-selected-is-always-shown ()
  "幅が足りなくても選択中の候補は必ず出ること"
  (ed::fuzzy-fit-candidates '("aaaa" "bbbb" "cccc" "dddd") 2 8)
  => "… [cccc] …")

(deftest fuzzy-fit-grows-both-ways ()
  "幅に余裕があれば選択中の候補の前後へ広がること"
  (ed::fuzzy-fit-candidates '("aa" "bb" "cc" "dd" "ee") 2 80)
  => "aa | bb | [cc] | dd | ee")

(deftest fuzzy-fit-marks-truncated-side ()
  "入り切らなかった側に … が付くこと"
  (values
   (ed::fuzzy-fit-candidates '("aa" "bb" "cc" "dd" "ee") 0 20)
   (ed::fuzzy-fit-candidates '("aa" "bb" "cc" "dd" "ee") 4 20))
  => "[aa] | bb | cc …"
  => "… cc | dd | [ee]")

(deftest fuzzy-fit-respects-max-candidates ()
  "*fuzzy-max-candidates* が表示件数の上限として効くこと"
  (let ((ed::*fuzzy-max-candidates* 2))
    (ed::fuzzy-fit-candidates '("aa" "bb" "cc" "dd" "ee") 0 200))
  => "[aa] | bb …")

(deftest fuzzy-fit-empty ()
  "候補が無ければ空文字列"
  (ed::fuzzy-fit-candidates nil 0 80)
  => "")

(deftest fuzzy-format-candidates-no-match ()
  "0 件のときの表示 (クエリが空なら何も出さない)"
  (values (ed::fuzzy-format-candidates nil 0 "" 0)
	  (ed::fuzzy-format-candidates nil 0 "zzz" 0))
  => ""
  => "  (0 件一致)")

;;;
;;; コマンド一覧と履歴
;;;

(deftest fuzzy-command-table-has-commands ()
  "コマンド一覧に主要なコマンドが入っていて、シンボルが引けること"
  (let ((table (ed::fuzzy-command-table)))
    (values
     (> (length table) 100)
     (cdr (assoc "list-buffers" table :test #'string=))
     ;; まだ読み込んでいないライブラリの autoload コマンドも入ること
     (and (assoc "gomoku" table :test #'string=) t)
     ;; コマンドでない関数は入らないこと
     (assoc "car" table :test #'string=)))
  => t
  => ed::list-buffers
  => t
  => nil)

(deftest fuzzy-command-table-has-no-duplicates ()
  "do-all-symbols が import されたシンボルを重複して返しても
一覧には 1 度しか出ないこと"
  (let* ((names (mapcar #'car (ed::fuzzy-command-table)))
	 (uniq (remove-duplicates names :test #'string=)))
    (= (length names) (length uniq)))
  => t)

(deftest fuzzy-command-table-is-sorted ()
  "名前順に並んでいること (履歴が無いときの候補順になる)"
  (let ((names (mapcar #'car (ed::fuzzy-command-table))))
    (equal names (sort (copy-seq names) #'string<)))
  => t)

(deftest fuzzy-mx-order-candidates ()
  "履歴にあるものが履歴順で先に来て、残りは元の順のままであること"
  (ed::fuzzy-mx-order-candidates '("aaa" "bbb" "ccc" "ddd")
				 '("ccc" "aaa"))
  => ("ccc" "aaa" "bbb" "ddd"))

(deftest fuzzy-mx-order-candidates-ignores-unknown-history ()
  "候補に無い履歴は無視されること (ライブラリを外した後など)"
  (ed::fuzzy-mx-order-candidates '("aaa" "bbb") '("zzz" "bbb"))
  => ("bbb" "aaa"))

(deftest fuzzy-mx-order-candidates-without-history ()
  "履歴が空なら元の順のまま"
  (ed::fuzzy-mx-order-candidates '("aaa" "bbb") nil)
  => ("aaa" "bbb"))

(deftest fuzzy-mx-add-history ()
  "履歴は新しい順で、同じものは重複せず、上限で切られること"
  (let ((ed::*fuzzy-mx-history* nil)
	(ed::*fuzzy-mx-history-max* 3))
    (ed::fuzzy-mx-add-history "a")
    (ed::fuzzy-mx-add-history "b")
    (ed::fuzzy-mx-add-history "a")
    (let ((after-dup (copy-seq ed::*fuzzy-mx-history*)))
      (ed::fuzzy-mx-add-history "c")
      (ed::fuzzy-mx-add-history "d")
      (values after-dup ed::*fuzzy-mx-history*)))
  => ("a" "b")
  => ("d" "c" "a"))

(deftest fuzzy-mx-keys ()
  "M-x と Leader SPC がファジー版に差し替わっていること"
  (values (lookup-keymap ed::esc-map #\x)
	  (lookup-keymap ed::*leader-map* #\SPC))
  => fuzzy-execute-extended-command
  => fuzzy-execute-extended-command)

;;;
;;; 絞り込みループ (read-char を差し替えて打鍵を流し込む)
;;;

(deftest fuzzy-read-select-by-typing ()
  "打った通りに絞り込まれ、RET で先頭の候補が返ること"
  (fuzzy-test-read (fuzzy-keys "buf list" #\RET))
  => "list-buffers")

(deftest fuzzy-read-next-and-previous ()
  "C-n で次へ、C-p で戻れること"
  (values (fuzzy-test-read (fuzzy-keys "list" #\C-n #\RET))
	  (fuzzy-test-read (fuzzy-keys "list" #\C-n #\C-p #\RET)))
  => "list-holidays"
  => "list-buffers")

(deftest fuzzy-read-previous-wraps ()
  "先頭で C-p すると末尾へ回ること"
  (fuzzy-test-read (fuzzy-keys "list" #\C-p #\RET))
  => "list-holidays")

(deftest fuzzy-read-backspace ()
  "C-h でクエリが 1 文字戻ること (打ち間違いの取り消し)"
  (fuzzy-test-read (fuzzy-keys "listz" #\C-h #\RET))
  => "list-buffers")

(deftest fuzzy-read-clear-query ()
  "C-u でクエリが全部消えて、候補が元の順に戻ること"
  (fuzzy-test-read (fuzzy-keys "buffer" #\C-u #\RET))
  => "list-buffers")

(deftest fuzzy-read-cancel ()
  "C-g で nil が返ること"
  (fuzzy-test-read (fuzzy-keys "list" #\C-g))
  => nil)

(deftest fuzzy-read-must-match-ignores-ret-with-no-match ()
  ":must-match のとき 0 件で RET を押しても確定せず、
その後の打鍵が続けて効くこと"
  (fuzzy-test-read (fuzzy-keys "zzz" #\RET #\C-h #\C-h #\C-h)
		   :must-match t)
  => nil)

(deftest fuzzy-read-reaches-candidates-beyond-the-display-limit ()
  "表示件数の上限より後ろの候補にも C-n で到達できること。
以前は絞り込み結果自体を *fuzzy-max-candidates* 件に切っていたため、
16 件目以降は選べなかった"
  (let ((candidates nil))
    (dotimes (i 30)
      (push (format nil "cand-~2,'0D" i) candidates))
    (setq candidates (nreverse candidates))
    (with-fuzzy-keys (list #\C-n #\C-n #\C-n #\C-n #\C-n
			   #\C-n #\C-n #\C-n #\C-n #\C-n
			   #\C-n #\C-n #\C-n #\C-n #\C-n
			   #\C-n #\C-n #\C-n #\C-n #\C-n #\RET)
      (let ((ed::*fuzzy-max-candidates* 5))
	(ed::fuzzy-completing-read "test: " candidates))))
  => "cand-20")

;;;
;;; 縦型表示 (Vertico 相当)
;;;

(deftest fuzzy-vertical-window-start-fits ()
  "件数が行数に収まるなら先頭から出すこと"
  (values (ed::fuzzy-vertical-window-start 0 3 10)
	  (ed::fuzzy-vertical-window-start 2 3 10))
  => 0
  => 0)

(deftest fuzzy-vertical-window-start-centers-and-clamps ()
  "選択を真ん中に置き、両端では止まること"
  (values (ed::fuzzy-vertical-window-start 0 100 10)
	  (ed::fuzzy-vertical-window-start 20 100 10)
	  (ed::fuzzy-vertical-window-start 99 100 10))
  => 0
  => 15
  => 90)

(deftest fuzzy-vertical-lines-marks-selection ()
  "選択行だけ \"> \" で始まり、その行が何行目かも返すこと"
  (multiple-value-bind (rows row)
      (ed::fuzzy-vertical-lines '("aa" "bb" "cc") 1 10)
    (values rows row))
  => ("  aa" "> bb" "  cc")
  => 1)

(deftest fuzzy-vertical-lines-scrolls ()
  "行数より件数が多いときは窓の中だけを返し、選択行の位置も窓内の値になること"
  (let ((c '("c0" "c1" "c2" "c3" "c4" "c5" "c6" "c7" "c8" "c9")))
    (multiple-value-bind (rows row)
	(ed::fuzzy-vertical-lines c 7 4)
      (values rows row)))
  => ("  c5" "  c6" "> c7" "  c8")
  => 2)

(deftest fuzzy-vertical-header ()
  "1 行目にプロンプトと打ちかけのクエリと件数が出ること"
  (values (ed::fuzzy-vertical-header "M-x " "buf" 6 0)
	  (ed::fuzzy-vertical-header "M-x " "zzz" 0 0))
  => "M-x buf    -- 1/6 件 --"
  => "M-x zzz    -- 0 件一致 --")

(deftest fuzzy-read-horizontal-path ()
  "*fuzzy-vertical* を nil にしてもステータス行表示で同じように選べること"
  (let ((ed::*fuzzy-vertical* nil))
    (fuzzy-test-read (fuzzy-keys "buf list" #\RET)))
  => "list-buffers")

(deftest fuzzy-read-vertical-cleans-up ()
  "縦型で選んだ後に候補バッファが残らないこと"
  (let ((ed::*fuzzy-vertical* t))
    (fuzzy-test-read (fuzzy-keys "buf list" #\RET))
    (find-buffer ed::*fuzzy-candidates-buffer-name*))
  => nil)

;;;
;;; 注釈 (Marginalia 相当)
;;;

(deftest fuzzy-vertical-row-right-aligns-annotation ()
  "注釈を行の右端へ寄せること"
  (ed::fuzzy-vertical-row "save-buffer" nil "C-x C-s" 30)
  => "  save-buffer          C-x C-s")

(deftest fuzzy-vertical-row-marks-selection ()
  "選択行は \"> \" で始まること (注釈があっても)"
  (ed::fuzzy-vertical-row "save-buffer" t "C-x C-s" 30)
  => "> save-buffer          C-x C-s")

(deftest fuzzy-vertical-row-without-annotation ()
  "注釈が nil / 空なら何も足さないこと"
  (values (ed::fuzzy-vertical-row "abc" nil nil 30)
	  (ed::fuzzy-vertical-row "abc" nil "" 30))
  => "  abc"
  => "  abc")

(deftest fuzzy-vertical-row-drops-annotation-when-too-narrow ()
  "幅が足りなければ注釈を落とすこと (行が折り返すと一覧が読めなくなる)"
  (ed::fuzzy-vertical-row "a-very-long-candidate-name" nil "C-x C-s" 20)
  => "  a-very-long-candidate-name")

(deftest fuzzy-vertical-lines-annotates-visible-rows-only ()
  "注釈は見えている行に対してだけ引くこと
(M-x のように候補が数百件あると、打鍵ごとに全件引いていては間に合わない)"
  (let ((asked nil)
	(candidates nil))
    (dotimes (i 30)
      (push (format nil "c~2,'0D" i) candidates))
    (setq candidates (nreverse candidates))
    (ed::fuzzy-vertical-lines candidates 0 3
			      #'(lambda (name) (push name asked) "X")
			      40)
    (length asked))
  => 3)

(deftest fuzzy-mx-format-keys ()
  "キーシーケンスの表示"
  (values (ed::fuzzy-mx-format-keys #\C-s)
	  (ed::fuzzy-mx-format-keys (list #\C-x #\C-s)))
  => "C-s"
  => "C-x C-s")

(deftest fuzzy-mx-key-annotation-picks-the-shortest ()
  "割り当てが複数あるときは一番短いものを出すこと
(一覧の目的は近道を知ることなので、C-x C-b と F2 があるなら F2)"
  (values (ed::fuzzy-mx-key-annotation 'ed::save-buffer)
	  (ed::fuzzy-mx-key-annotation 'ed::select-buffer)
	  ;; 割り当ての無いコマンドは nil
	  (ed::fuzzy-mx-key-annotation 'ed::gomoku))
  => "C-x C-s"
  => "F2"
  => nil)

(deftest fuzzy-mx-annotator ()
  "コマンド表から注釈を引く関数を作れること"
  (let* ((table (ed::fuzzy-command-table))
	 (annotate (ed::fuzzy-mx-annotator table)))
    (values (funcall annotate "save-buffer")
	    (funcall annotate "no-such-command-at-all")))
  => "C-x C-s"
  => nil)

(deftest fuzzy-read-allow-new-returns-the-query ()
  ":allow-new のとき、一致が無ければ打った文字列そのものが返ること
(無い名前を打って新しいバッファを作る用途)"
  (values (with-fuzzy-keys (fuzzy-keys "brand-new-name" #\RET)
	    (ed::fuzzy-completing-read "test: " *fuzzy-test-candidates*
				       :allow-new t))
	  ;; 一致があるときは候補の方を返す
	  (with-fuzzy-keys (fuzzy-keys "buf list" #\RET)
	    (ed::fuzzy-completing-read "test: " *fuzzy-test-candidates*
				       :allow-new t)))
  => "brand-new-name"
  => "list-buffers")

(deftest fuzzy-read-allow-new-ignores-empty-query ()
  "クエリが空のままの RET では、打った文字列 (空) ではなく候補が返ること"
  (with-fuzzy-keys (list #\RET)
    (ed::fuzzy-completing-read "test: " *fuzzy-test-candidates* :allow-new t))
  => "list-buffers")
