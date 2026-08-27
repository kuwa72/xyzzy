;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Fuzzy narrowing for candidate selection (project-find-file 等から使う)。
;;;
;;; completing-read には候補の絞り込み方をフックする手段が無いため、
;;; isearch.l / leader.l の which-key-guide と同じ手法 (read-char を1文字ずつ
;;; 読み、minibuffer-prompt でステータス行を都度書き換える) で独自の
;;; インクリメンタル絞り込みループを実装している。
;;;

(provide "fuzzy-complete")

(in-package "editor")

(export '(fuzzy-score fuzzy-filter fuzzy-completing-read
	  fuzzy-split-query
	  *fuzzy-max-candidates*))

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
  (or (ignore-errors (window-columns)) 80))

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

(defun fuzzy-completing-read (prompt candidates &key must-match)
  "CANDIDATES を対象に、入力するそばからファジー絞り込みしながら1件選ぶ。

- 文字入力: クエリに追加し、絞り込み直す。
- C-h / DEL / Delete: クエリの末尾を1文字削除。
- C-u: クエリを全消去。
- C-n / Down / TAB: 絞り込み結果内で選択を1件進める。
- C-p / Up: 選択を1件戻す。
- RET: 選択中の候補を返す。MUST-MATCH が non-nil のとき、絞り込み結果が
  空ならば無視する (呼び出し元には必ず候補のいずれかか nil しか返らない)。
- C-g: nil を返す (キャンセル)。"
  (let ((query "") (index 0))
    (catch 'fuzzy-complete-exit
      (while t
	;; 絞り込みは全件に対してかける。表示だけを幅に合わせて切るので、
	;; C-n で 16 件目以降にも行ける (以前は表示件数で切っていたため
	;; 上限より後ろの候補は選べなかった)。
	(let* ((matches (fuzzy-filter candidates query))
	       (n (length matches)))
	  (when (>= index (max n 1))
	    (setq index (max 0 (1- n))))
	  (minibuffer-prompt "~A~A~A" prompt query
			      (fuzzy-format-candidates
			       matches index query n
			       (+ (length prompt) (length query))))
	  (let ((ch (read-char *keyboard*)))
	    (cond
	     ((char= ch #\RET)
	      (let ((selected (nth index matches)))
		(when (or selected (not must-match))
		  (throw 'fuzzy-complete-exit selected))
		(ding)))
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
