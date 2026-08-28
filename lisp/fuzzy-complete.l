;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Fuzzy narrowing for candidate selection (project-find-file 等から使う)。
;;;
;;; completing-read には候補の絞り込み方をフックする手段が無いため、
;;; isearch.l / leader.l の which-key-guide と同じ手法 (read-char を1文字ずつ
;;; 読み、minibuffer-prompt でステータス行を都度書き換える) で独自の
;;; インクリメンタル絞り込みループを実装している。
;;;
;;; 候補の見せ方は 2 つある。
;;;
;;;   * 縦型 (既定、Vertico 相当) -- 一時バッファ *Candidates* を分割
;;;     ウィンドウに出し、1 行 1 候補で並べる。打鍵のたびに書き換える。
;;;     1 行に収まらない情報 (キー割り当てなどの注釈、Marginalia 相当) を
;;;     右端へ寄せて出せるのはこちらだけ。
;;;   * 横型 -- ステータス行 1 行に幅の許すだけ並べる。*fuzzy-vertical* を
;;;     nil にするとこちらになる。
;;;
;;; 縦型が既定なのは、M-x のように候補が数百件ある相手では 1 行に数件しか
;;; 入らず、絞り込みの効きが目で見えないため。クエリ自体は縦型でも
;;; ステータス行に出し続ける (打っている文字が見えないと話にならない)。
;;;

(provide "fuzzy-complete")

(in-package "editor")

(require "popup-window")

(export '(fuzzy-score fuzzy-filter fuzzy-completing-read
	  fuzzy-split-query
	  *fuzzy-max-candidates*
	  *fuzzy-vertical* *fuzzy-vertical-lines*
	  *fuzzy-candidates-buffer-name*))

(defvar *fuzzy-vertical* t
  "non-nil なら候補を縦に並べたウィンドウ (Vertico 相当) で見せる。
nil ならステータス行 1 行に並べる。")

(defvar *fuzzy-vertical-lines* 12
  "縦表示に使うウィンドウの行数。画面が狭いときはそれに合わせて縮む。")

(defvar *fuzzy-candidates-buffer-name* "*Candidates*"
  "縦表示に使う一時バッファの名前。")

(defvar *fuzzy-max-candidates* 15
  "fuzzy-completing-read がステータス行に同時表示する候補の最大件数。
実際に並ぶ件数はステータス行の幅からも制限されるので、これは上限。
絞り込みや選択の対象は常に全件で、ここで切られるのは表示だけ。")

(defun fuzzy-score-1 (candidate query)
  "CANDIDATE が QUERY の (大小無視) 部分列であればスコアを、そうでなければ
nil を返す、貪欲な左から右への1回走査によるスコア計算。呼び出し元は
fuzzy-score を使うこと (このバージョンは basename 優遇をしない生の値)。"
  (let ((cn (length candidate))
	(qn (length query)))
    (if (zerop qn)
	0
      (let ((ci 0) (qi 0) (score 0) (run 0) (first nil) (last 0))
	(while (and (< ci cn) (< qi qn))
	  (if (char-equal (char candidate ci) (char query qi))
	      (progn
		(setq run (1+ run))
		(incf score (* 10 run))
		(when (or (zerop ci)
			  (member (char candidate (1- ci))
				  '(#\/ #\_ #\- #\. #\Space) :test #'char=))
		  (incf score 50))
		(unless first (setq first ci))
		(setq last ci)
		(setq qi (1+ qi)))
	    (setq run 0))
	  (setq ci (1+ ci)))
	;; 引くものが 2 つある。
	;;
	;; CANDIDATE の長さは単なるタイブレークで、一致の質を表す上のボーナスに
	;; 比べて十分小さいので、明確な優劣があるときの順位には影響しない。
	;;
	;; 一致が散らばった分 (先頭の一致から末尾の一致までの間にある、
	;; 一致しなかった文字数) はそうではなく、これが無いと長い名前の中に
	;; 文字がばらばらに散っているものが、単語区切りボーナスを何度も
	;; 稼いで上に来てしまう。実例: \"buf\" で `save-buffer' よりも
	;; `backward-delete-char-untabify' (b...u...b...if) が上に出た。
	(if (= qi qn)
	    (- score cn (- (1+ (- last (or first 0))) qn))
	  nil)))))

(defun fuzzy-score-token (candidate token)
  "CANDIDATE が TOKEN の (大文字小文字を無視した) 部分列であればスコアを
返す。一致しなければ nil。

CANDIDATE がパス (例: \"lisp/project.l\") のときは、パス全体とファイル名
部分 (最後の '/' より後ろ) の両方でスコアを計算し、良い方を採用する。
貪欲な1回走査 (fuzzy-score-1) は、ディレクトリ名側に TOKEN の先頭文字と
たまたま一致する文字があると、そちらに食いつかれてファイル名側の綺麗な
連続一致を見逃すことがあるため、ファイル名部分だけの再走査で補う。"
  (let* ((full (fuzzy-score-1 candidate token))
	 (slash (position #\/ candidate :from-end t))
	 (base (and slash (fuzzy-score-1 (subseq candidate (1+ slash)) token))))
    (cond
     ((and full base) (max full (+ base 50)))
     (base (+ base 50))
     (t full))))

(defun fuzzy-split-query (query)
  "QUERY を空白 (スペースまたはタブ) で区切ってトークンのリストにする。
空要素は捨てるので、区切りが連続していても空トークンは出ない。

split-string の第 3 引数は builtin.l では ignore-empty という名前だが、
実装 (src/core/string.cc の Fsplit_string) では empty_ok で、non-nil の
ときに空要素を「残す」。ここで nil を渡しているのはそのため。"
  (split-string query " \t" nil))

(defun fuzzy-score (candidate query)
  "CANDIDATE が QUERY に一致すればスコアを返す。一致しなければ nil。
連続一致・単語区切り直後の一致にボーナスを付けるので、スコアが大きいほど
良い一致とみなせる。

QUERY が空白を含むときは、空白区切りの各トークンが「どれも CANDIDATE の
部分列である」ことを求め、スコアはその合計にする (Emacs の orderless
相当)。トークンの間に順序の制約は無いので、\"file open\" と \"open file\"
はどちらも `open-filer' に一致する。1 トークンずつは順序を守った部分列
一致のままなので、絞り込みの効きは変わらない。"
  (if (zerop (length query))
      0
    (let ((tokens (fuzzy-split-query query)))
      (cond
       ;; 空白しか入っていないときは絞り込まない (打ちかけの状態)
       ((null tokens) 0)
       ((null (cdr tokens)) (fuzzy-score-token candidate (car tokens)))
       (t
	(let ((total 0))
	  (dolist (tok tokens)
	    (let ((s (fuzzy-score-token candidate tok)))
	      (if (null s)
		  (return-from fuzzy-score nil)
		(incf total s))))
	  total))))))

(defun fuzzy-filter (candidates query &optional limit)
  "CANDIDATES を QUERY でファジー絞り込みし、スコア降順で返す。
QUERY が空 (または空白だけ) のときは絞り込まず、先頭から LIMIT 件を返す。"
  (let ((result
	 (if (null (fuzzy-split-query query))
	     candidates
	   (let (scored)
	     (dolist (c candidates)
	       (let ((s (fuzzy-score c query)))
		 (when s (push (cons s c) scored))))
	     (mapcar #'cdr (sort scored #'> :key #'car))))))
    (if (and limit (> (length result) limit))
	(subseq result 0 limit)
      result)))

(defun fuzzy-render-candidate (candidate selected-p)
  (if selected-p
      (concat "[" candidate "]")
    candidate))

(defun fuzzy-fit-candidates (matches index budget)
  "MATCHES のうち BUDGET 文字に収まる分だけを \" | \" 区切りで並べた文字列を
返す。選択中の候補 (INDEX) は必ず含め、そこから前後へ交互に広げる:
選択中のものが表示から外れると、何を選んでいるのか分からなくなる。
入り切らなかった側には … を付けて、まだ先があることを示す。

幅は文字数で数えている。全角文字は 2 桁を占めるので日本語混じりの候補では
実際より多く詰めようとするが、ステータス行は溢れた分が切れるだけなので
表示が壊れることはない。"
  (let* ((n (length matches))
	 (vec (coerce matches 'vector)))
    (if (zerop n)
	""
      (let* ((lo index)
	     (hi index)
	     ;; 両端の … の分を先に取っておく。
	     (room (- budget 4))
	     (len (length (fuzzy-render-candidate (aref vec index) t)))
	     (shown 1)
	     (limit (max 1 *fuzzy-max-candidates*)))
	(loop
	  (let ((extended nil))
	    (when (and (< shown limit) (< (1+ hi) n))
	      (let ((w (+ 3 (length (aref vec (1+ hi))))))
		(when (<= (+ len w) room)
		  (incf hi) (incf len w) (incf shown) (setq extended t))))
	    (when (and (< shown limit) (> lo 0))
	      (let ((w (+ 3 (length (aref vec (1- lo))))))
		(when (<= (+ len w) room)
		  (decf lo) (incf len w) (incf shown) (setq extended t))))
	    (unless extended (return))))
	(let ((items nil))
	  (do ((i hi (1- i)))
	      ((< i lo))
	    (push (fuzzy-render-candidate (aref vec i) (= i index)) items))
	  (format nil "~:[~;… ~]~{~A~^ | ~}~:[~; …~]"
		  (> lo 0) items (< hi (1- n))))))))

(defun fuzzy-status-width ()
  "ステータス行に使える桁数の見積り。"
  (popup-window-measured-columns))

(defun fuzzy-format-candidates (matches index query total &optional head-length)
  "ステータス行1行に収める候補一覧の表示文字列を作る。選択中の候補は
[...] で囲んで示す。HEAD-LENGTH はプロンプトなど既に書いた分の桁数。"
  (cond
   ((null matches)
    (if (null (fuzzy-split-query query)) "" "  (0 件一致)"))
   (t
    (let* ((counter (format nil "  (~D/~D件) " (1+ index) total))
	   (budget (max 12 (- (fuzzy-status-width)
			      (or head-length 0)
			      (length counter)
			      1))))
      (concat counter (fuzzy-fit-candidates matches index budget))))))

;;;
;;; 縦型表示 (Vertico 相当)
;;;

(defun fuzzy-vertical-window-start (index n lines)
  "N 件のうち LINES 行だけ見せるとき、INDEX が見えるような窓の先頭を返す。

選択を真ん中に置いて両端で止める。打鍵ごとに状態を持たずに決められる
(スクロール位置を覚えておく必要が無い) のが利点で、そのかわり選択を
1 つ動かすと一覧全体が 1 行ずれる。件数が行数より少なければ 0。"
  (cond ((<= n lines) 0)
	(t (min (max 0 (- index (truncate lines 2)))
		(- n lines)))))

(defun fuzzy-vertical-row (candidate selected-p annotation width)
  "縦表示の 1 行。選択行は \"> \" で始める。注釈があれば右端へ寄せる。

幅が足りないときは注釈を落とす。行が折り返すと一覧全体が読めなくなるので、
注釈より候補そのものを優先する。"
  (let ((left (concat (if selected-p "> " "  ") candidate)))
    (if (or (null annotation) (zerop (length annotation)))
	left
      (let ((pad (- width (length left) (length annotation))))
	(if (>= pad 2)
	    (concat left
		    (make-sequence 'string pad :initial-element #\SPC)
		    annotation)
	  left)))))

(defun fuzzy-vertical-lines (matches index lines &optional annotate (width 80))
  "縦表示に出す行のリストと、その中で選択中の行が何行目かを
(values LINES SELECTED-ROW) で返す。

ANNOTATE は候補名から注釈文字列 (または nil) を返す関数。**見えている行に
対してだけ呼ぶ。** M-x のように候補が数百件ある相手で、打鍵ごとに全件の
キー割り当てを引いていては間に合わない。"
  (let* ((n (length matches))
	 (vec (coerce matches 'vector))
	 (start (fuzzy-vertical-window-start index n lines))
	 (end (min n (+ start lines)))
	 (result nil))
    (do ((i start (1+ i)))
	((>= i end))
      (let ((cand (aref vec i)))
	(push (fuzzy-vertical-row cand (= i index)
				  (and annotate
				       (ignore-errors (funcall annotate cand)))
				  width)
	      result)))
    (values (nreverse result) (- index start))))

(defun fuzzy-vertical-header (prompt query n index)
  "候補ウィンドウの 1 行目。プロンプトと打ちかけのクエリを自分で表示する。

ステータス行 (minibuffer-prompt) にも同じものを出しているが、そちらは
message を書いた直後に read-char で待つと描かれないフロントエンドがある
(issue #66)。打っている文字が見えないのは致命的なので、ウィンドウの中に持つ。"
  (if (zerop n)
      (format nil "~A~A    -- 0 件一致 --" prompt query)
    (format nil "~A~A    -- ~D/~D 件 --" prompt query (1+ index) n)))

(defun fuzzy-vertical-available-p ()
  "縦表示ができる状況か。ミニバッファの中と、分割する余地が無い画面では
横表示に落とす。"
  (and *fuzzy-vertical*
       (popup-window-available-p)))

(defun fuzzy-vertical-draw (prompt query matches index annotate)
  "候補ウィンドウを書き換える。"
  (let* ((n (length matches))
	 (width (popup-window-measured-columns))
	 (lines (let ((*popup-window-max-lines* *fuzzy-vertical-lines*))
		  (popup-window-body-lines 1))))
    (multiple-value-bind (rows row)
	(fuzzy-vertical-lines matches index lines annotate (max 20 (1- width)))
      (popup-window-draw *fuzzy-candidates-buffer-name*
			 (cons (fuzzy-vertical-header prompt query n index) rows)
			 ;; 見出しが 1 行あるので 1 つ下。
			 (1+ row)))))

(defun fuzzy-read-loop (prompt candidates must-match vertical annotate allow-new)
  "fuzzy-completing-read の本体。VERTICAL が non-nil なら候補を縦型で見せる。"
  (let ((query "") (index 0))
    (catch 'fuzzy-complete-exit
      (while t
	;; 絞り込みは全件に対してかける。表示だけを幅 (または行数) に
	;; 合わせて切るので、C-n で 16 件目以降にも行ける (以前は表示件数で
	;; 切っていたため上限より後ろの候補は選べなかった)。
	(let* ((matches (fuzzy-filter candidates query))
	       (n (length matches)))
	  (when (>= index (max n 1))
	    (setq index (max 0 (1- n))))
	  (if vertical
	      (progn
		;; ステータス行にも出すが、消えることがあるので当てにしない
		;; (fuzzy-vertical-header の説明を参照)。
		(fuzzy-vertical-draw prompt query matches index annotate)
		(minibuffer-prompt "~A~A" prompt query))
	    (minibuffer-prompt "~A~A~A" prompt query
			       (fuzzy-format-candidates
				matches index query n
				(+ (length prompt) (length query)))))
	  (let ((ch (read-char *keyboard*)))
	    (cond
	     ((char= ch #\RET)
	      (let ((selected (nth index matches)))
		(cond
		 (selected (throw 'fuzzy-complete-exit selected))
		 ;; 一致が無くても、打った文字列そのものを返してよい場合。
		 ;; 「無い名前を打って新しいバッファを作る」ような用途のため。
		 ((and allow-new (plusp (length query)))
		  (throw 'fuzzy-complete-exit query))
		 ((not must-match) (throw 'fuzzy-complete-exit nil))
		 (t (ding)))))
	     ((char= ch #\C-g)
	      (throw 'fuzzy-complete-exit nil))
	     ((or (char= ch #\C-h) (char= ch #\DEL) (char= ch #\Delete))
	      (if (zerop (length query))
		  (ding)
		(progn
		  (setq query (subseq query 0 (1- (length query))))
		  (setq index 0))))
	     ((char= ch #\C-u)
	      (setq query "")
	      (setq index 0))
	     ((or (char= ch #\C-n) (char= ch #\Down) (char= ch #\TAB))
	      (when (> n 0) (setq index (mod (1+ index) n))))
	     ((or (char= ch #\C-p) (char= ch #\Up))
	      (when (> n 0) (setq index (mod (1- index) n))))
	     ((graphic-char-p ch)
	      (setq query (concat query (string ch)))
	      (setq index 0))
	     (t
	      (ding)))))))))

(defun fuzzy-completing-read (prompt candidates &key must-match annotate allow-new)
  "CANDIDATES を対象に、入力するそばからファジー絞り込みしながら1件選ぶ。

- 文字入力: クエリに追加し、絞り込み直す。空白で区切ると順不同の
  多角絞り込みになる。
- C-h / DEL / Delete: クエリの末尾を1文字削除。
- C-u: クエリを全消去。
- C-n / Down / TAB: 絞り込み結果内で選択を1件進める。
- C-p / Up: 選択を1件戻す。
- RET: 選択中の候補を返す。MUST-MATCH が non-nil のとき、絞り込み結果が
  空ならば無視する (呼び出し元には必ず候補のいずれかか nil しか返らない)。
- C-g: nil を返す (キャンセル)。

ALLOW-NEW が non-nil なら、一致する候補が無いときの RET で「打った文字列
そのもの」を返す。無い名前を打って新しいバッファを作る、といった用途のため。

ANNOTATE は候補名から注釈文字列 (または nil) を返す関数 (Marginalia 相当)。
縦表示のときだけ使われ、各行の右端へ寄せて出す。**見えている行に対して
だけ呼ばれる**ので、1 件あたりの計算が多少重くても構わない。

候補は *fuzzy-vertical* が non-nil なら縦型のウィンドウ、nil なら
ステータス行に並ぶ。縦型のウィンドウは with-popup-window で囲ってあるので、
選び終わった時点で元のウィンドウ構成に戻る。"
  (if (fuzzy-vertical-available-p)
      (with-popup-window (*fuzzy-candidates-buffer-name* "Candidates")
	(fuzzy-read-loop prompt candidates must-match t annotate allow-new))
    (fuzzy-read-loop prompt candidates must-match nil nil allow-new)))
