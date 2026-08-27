;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; 定型コードの挿入 (Emacs の yasnippet 相当)。
;;;
;;; テンプレートの書き方は yasnippet と同じ形にしてある。
;;;
;;;   $1 $2 ...    カーソルを順に置く場所 (タブストップ)
;;;   ${1:name}    既定値付き。展開直後は選択された状態になるので、
;;;                そのまま打てば置き換わり、TAB で次へ行けば残る
;;;   $0           最後に行き着く場所。省略すると末尾
;;;   $$           文字としての $
;;;
;;; 場所の追跡にはマーカーを使う。オフセットで覚えると、先の場所を
;;; 打ち替えた分だけ後ろの場所がずれる。
;;;
;;; 複数行のテンプレートは、展開を始めた桁に合わせて 2 行目以降を字下げ
;;; する。モードのインデント関数に任せる手もあるが、それだと「テンプレート
;;; の見た目の通りに入る」という予測が立たない。
;;;

(provide "snippet")

(in-package "editor")

(require "fuzzy-complete")

(export '(snippet-expand snippet-insert-by-name
	  snippet-next-field snippet-previous-field
	  define-snippet
	  *snippet-table*))

(defvar *snippet-table* (make-hash-table :test #'eq)
  "モード (buffer-mode の値) → ((略語 . テンプレート) ...) のハッシュ表。")

(defvar *snippet-fields* nil
  "展開中のテンプレートのタブストップ (マーカーのリスト、前から順)。")

(defvar *snippet-exit* nil
  "展開中のテンプレートの $0 のマーカー。")

(defun define-snippet (mode abbrev template)
  "MODE の略語 ABBREV に TEMPLATE を登録する。同じ略語は上書きする。"
  (let ((alist (gethash mode *snippet-table*)))
    (setq alist (remove abbrev alist :key #'car :test #'string=))
    (setf (gethash mode *snippet-table*)
	  (sort (cons (cons abbrev template) alist) #'string< :key #'car))
    abbrev))

(defun snippet-alist (&optional (mode buffer-mode))
  (gethash mode *snippet-table*))

;;;
;;; テンプレートの解析
;;;

(defun snippet-tokenize (template)
  "TEMPLATE を ((:text . 文字列) | (:field 番号 既定値 明示的か)) の列にする。"
  (let ((tokens nil)
	(plain (make-string-output-stream))
	(i 0)
	(n (length template)))
    (flet ((flush ()
	     (let ((str (get-output-stream-string plain)))
	       (when (plusp (length str))
		 (push (cons :text str) tokens)))))
      (while (< i n)
	(let ((c (char template i)))
	  (cond
	   ;; $$ は文字としての $
	   ((and (char= c #\$) (< (1+ i) n) (char= (char template (1+ i)) #\$))
	    (princ #\$ plain)
	    (incf i 2))
	   ;; $12 のような裸のタブストップ
	   ((and (char= c #\$) (< (1+ i) n) (digit-char-p (char template (1+ i))))
	    (let ((j (1+ i)))
	      (while (and (< j n) (digit-char-p (char template j)))
		(incf j))
	      (flush)
	      (push (list :field (parse-integer template :start (1+ i) :end j) "" nil)
		    tokens)
	      (setq i j)))
	   ;; ${1:既定値}
	   ((and (char= c #\$) (< (1+ i) n) (char= (char template (1+ i)) #\{))
	    (let* ((close (position #\} template :start (+ i 2)))
		   (body (and close (subseq template (+ i 2) close)))
		   (colon (and body (position #\: body)))
		   (numstr (and body (subseq body 0 (or colon (length body)))))
		   (num (and numstr
			     (plusp (length numstr))
			     (every #'digit-char-p numstr)
			     (parse-integer numstr))))
	      (if (null num)
		  ;; 閉じていない、または番号でない ${...} はそのまま文字として出す
		  (progn (princ c plain) (incf i))
		(progn
		  (flush)
		  (push (list :field num (if colon (subseq body (1+ colon)) "") t)
			tokens)
		  (setq i (1+ close))))))
	   (t
	    (princ c plain)
	    (incf i)))))
      (flush))
    (nreverse tokens)))

(defun snippet-parse (template)
  "TEMPLATE を (values TEXT FIELDS) に分解する。

TEXT はタブストップの記法を取り除き、既定値を埋めた文字列。
FIELDS は ((番号 開始オフセット 既定値の長さ) ...) を番号順に並べたもので、
番号 0 ($0) も同じ形で入る。開始オフセットは TEXT の先頭からの位置。

同じ番号が 2 回以上出てきたら、2 回目以降には 1 回目の既定値を
埋めるだけにしてタブストップは作らない。`for (int $1 = 0; $1 < $2; $1++)`
のような書き方 (yasnippet のミラー) をそのまま使えるようにするため。
値を書き替えたときに追随はしない -- そこまでやると挿入後もバッファの
変更を監視し続けることになる。"
  (let ((tokens (snippet-tokenize template))
	(defaults nil)
	(out (make-string-output-stream))
	(pos 0)
	(fields nil)
	(seen nil))
    ;; 先に既定値を集める: ミラーの方が先に出てくることもある。
    (dolist (tok tokens)
      (when (and (eq (car tok) :field) (fourth tok))
	(unless (assoc (second tok) defaults)
	  (push (cons (second tok) (third tok)) defaults))))
    (dolist (tok tokens)
      (if (eq (car tok) :text)
	  (progn
	    (princ (cdr tok) out)
	    (incf pos (length (cdr tok))))
	(let* ((num (second tok))
	       (default (or (cdr (assoc num defaults)) "")))
	  (unless (member num seen)
	    (push num seen)
	    (push (list num pos (length default)) fields))
	  (princ default out)
	  (incf pos (length default)))))
    (values (get-output-stream-string out)
	    (sort (nreverse fields) #'< :key #'car))))

(defun snippet-indent-lines (text column)
  "TEXT の 2 行目以降の先頭に COLUMN 桁分の空白を足した文字列を返す。"
  (if (or (zerop column)
	  (zerop (length text))
	  (not (find #\LFD text)))
      text
    (let ((pad (make-sequence 'string column :initial-element #\SPC))
	  (out (make-string-output-stream))
	  (first t))
      ;; split-string の第 3 引数は「空要素を残す」 (実装は empty_ok)。
      ;; テンプレートの空行を落とされては困るので t を渡す。
      (dolist (line (split-string text #\LFD t))
	(if first
	    (setq first nil)
	  (progn
	    (princ #\LFD out)
	    ;; 空行には字下げを入れない。入れると行末空白になる。
	    (when (plusp (length line))
	      (princ pad out))))
	(princ line out))
      ;; split-string は末尾の区切りに対して空要素を作らないので、
      ;; 元が改行で終わっていたら足し直す。
      (when (char= (char text (1- (length text))) #\LFD)
	(princ #\LFD out))
      (get-output-stream-string out))))

;;;
;;; 展開
;;;

(defun snippet-clear-fields ()
  (dolist (f *snippet-fields*)
    (ignore-errors (delete-marker (car f))))
  (when *snippet-exit*
    (ignore-errors (delete-marker *snippet-exit*)))
  (setq *snippet-fields* nil)
  (setq *snippet-exit* nil))

(defun snippet-insert (template)
  "TEMPLATE を点の位置に展開する。最初のタブストップへ移動して t を返す。"
  (snippet-clear-fields)
  (multiple-value-bind (text fields) (snippet-parse template)
    (let* ((column (current-column))
	   (body (snippet-indent-lines text column))
	   ;; 字下げで増えた分だけ、2 行目以降のオフセットがずれる。
	   ;; ずれ幅は「そのオフセットより前にある改行の数 × column」。
	   (start (point)))
      (insert body)
      (let ((stops nil))
	(dolist (f fields)
	  (let* ((num (first f))
		 (offset (second f))
		 (len (third f))
		 (nl (count #\LFD text :end offset))
		 (p (+ start offset (* nl column)))
		 (m (make-marker)))
	    (set-marker m p)
	    (if (zerop num)
		(setq *snippet-exit* m)
	      (push (cons m len) stops))))
	(setq *snippet-fields* (nreverse stops)))
      (snippet-goto-field (car *snippet-fields*)
			  (or *snippet-exit* (point)))
      t)))

(defun snippet-goto-field (field fallback)
  "FIELD ((マーカー . 既定値の長さ)) へ移動する。既定値があればそれを
選択した状態にする (そのまま打てば置き換わる)。FIELD が nil なら
FALLBACK (マーカーか位置) へ移動する。"
  (cond
   (field
    (let ((p (marker-point (car field)))
	  (len (cdr field)))
      (goto-char p)
      (when (plusp len)
	;; 第 2 引数を t にするのが要点。これで pre-selection になり、
	;; self-insert-command が「打ったら選択範囲を置き換える」経路に
	;; 入る (nil だと既定値の後ろに書き足されてしまう)。
	(start-selection 2 t)
	(goto-char (+ p len)))))
   ((markerp fallback) (goto-char (marker-point fallback)))
   ((integerp fallback) (goto-char fallback)))
  t)

(defun snippet-next-field ()
  "展開中のテンプレートの次のタブストップへ移動する。"
  (interactive)
  (if (null *snippet-fields*)
      (progn (message "展開中のテンプレートがありません") nil)
    (progn
      ;; 今いる場所は使い終わったので捨てる。
      (let ((used (pop *snippet-fields*)))
	(ignore-errors (delete-marker (car used))))
      (if *snippet-fields*
	  (snippet-goto-field (car *snippet-fields*) nil)
	(progn
	  (snippet-goto-field nil (or *snippet-exit* (point)))
	  (snippet-clear-fields)))
      t)))

(defun snippet-previous-field ()
  "直前のタブストップへ戻る。捨てた場所には戻れないので、残っている
最初のタブストップへ移動するだけ。"
  (interactive)
  (if (null *snippet-fields*)
      (progn (message "展開中のテンプレートがありません") nil)
    (snippet-goto-field (car *snippet-fields*) nil)))

(defun snippet-word-before-point ()
  "点の直前の語 (略語の候補) を (values 文字列 開始位置) で返す。"
  (save-excursion
    (let ((end (point)))
      (skip-syntax-spec-backward "w_")
      (values (buffer-substring (point) end) (point)))))

(defun snippet-expand ()
  "点の直前の略語をテンプレートに展開する。

略語が登録されていなければ、一覧から選ぶ方 (snippet-insert-by-name) に
回す。展開する物が無いときに黙って何もしないより、選ばせたほうが早い。"
  (interactive "*")
  (multiple-value-bind (word start) (snippet-word-before-point)
    (let ((template (and (plusp (length word))
			 (cdr (assoc word (snippet-alist) :test #'string=)))))
      (if (null template)
	  (snippet-insert-by-name)
	(progn
	  (delete-region start (point))
	  (snippet-insert template))))))

(defun snippet-insert-by-name ()
  "このモードのテンプレートを一覧から選んで展開する。"
  (interactive "*")
  (let ((alist (snippet-alist)))
    (if (null alist)
	(progn
	  (message "~A モードのテンプレートは登録されていません" mode-name)
	  nil)
      (let ((name (fuzzy-completing-read "Snippet: " (mapcar #'car alist)
					 :must-match t)))
	(if (null name)
	    (progn (message "Quit") nil)
	  (snippet-insert (cdr (assoc name alist :test #'string=))))))))

;;;
;;; 既定のテンプレート
;;;
;;; 少数に絞ってある。使う人がすぐ足せる形 (define-snippet) にしておくのが
;;; 本体で、こちらは「どう書くか」の見本でもある。

(dolist (spec
	 '((lisp-mode
	    ("defun"  "(defun ${1:name} (${2:args})~%  $0)")
	    ("let"    "(let ((${1:var} ${2:val}))~%  $0)")
	    ("dolist" "(dolist (${1:x} ${2:list})~%  $0)")
	    ("when"   "(when ${1:test}~%  $0)")
	    ("deftest" "(deftest ${1:name} ()~%  \"${2:説明}\"~%  $0)"))
	   (c-mode
	    ("if"   "if (${1:cond})~%  {~%    $0~%  }")
	    ("for"  "for (int ${1:i} = 0; $1 < ${2:n}; $1++)~%  {~%    $0~%  }")
	    ("while" "while (${1:cond})~%  {~%    $0~%  }")
	    ("main" "int~%main (int argc, char **argv)~%{~%  $0~%  return 0;~%}"))
	   (c++-mode
	    ("if"   "if (${1:cond})~%  {~%    $0~%  }")
	    ("for"  "for (int ${1:i} = 0; $1 < ${2:n}; $1++)~%  {~%    $0~%  }")
	    ("class" "class ${1:Name}~%{~%public:~%  $0~%};"))
	   (python-mode
	    ("def"   "def ${1:name}(${2:args}):~%    $0")
	    ("class" "class ${1:Name}:~%    def __init__(self${2:, args}):~%        $0")
	    ("if"    "if ${1:cond}:~%    $0")
	    ("for"   "for ${1:x} in ${2:seq}:~%    $0")
	    ("main"  "if __name__ == \"__main__\":~%    $0"))
	   (javascript-mode
	    ("fn"    "function ${1:name}(${2:args}) {~%  $0~%}")
	    ("arrow" "const ${1:name} = (${2:args}) => {~%  $0~%};")
	    ("for"   "for (const ${1:x} of ${2:xs}) {~%  $0~%}")
	    ("if"    "if (${1:cond}) {~%  $0~%}"))
	   (markdown-mode
	    ("code"  "```${1:lang}~%$0~%```")
	    ("link"  "[${1:text}](${2:url})$0")
	    ("table" "| ${1:col} | ${2:col} |~%|---|---|~%| $0 |  |"))))
  (let ((mode (car spec)))
    (dolist (entry (cdr spec))
      (define-snippet mode (first entry)
	;; ~% で書いて format で改行に直す: テンプレートの中に生の改行を
	;; 置くとこのファイルのインデントが崩れて読みにくい。
	(format nil (second entry))))))

;; typescript は javascript と同じもので始める。
(setf (gethash 'typescript-mode *snippet-table*)
      (gethash 'javascript-mode *snippet-table*))

(define-key esc-map #\i 'snippet-next-field)
(define-key *leader-code-map* #\i 'snippet-insert-by-name)
(define-key *leader-code-map* #\e 'snippet-expand)

(which-key-add-description 'snippet-insert-by-name "Snippet")
(which-key-add-description 'snippet-expand "Expand")
(which-key-add-description 'snippet-next-field "NextField")
