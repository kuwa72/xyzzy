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
	  *fuzzy-max-candidates*))

(defvar *fuzzy-max-candidates* 15
  "fuzzy-completing-read がステータス行に同時表示する候補の最大件数。")

(defun fuzzy-score-1 (candidate query)
  "CANDIDATE が QUERY の (大小無視) 部分列であればスコアを、そうでなければ
nil を返す、貪欲な左から右への1回走査によるスコア計算。呼び出し元は
fuzzy-score を使うこと (このバージョンは basename 優遇をしない生の値)。"
  (let ((cn (length candidate))
	(qn (length query)))
    (if (zerop qn)
	0
      (let ((ci 0) (qi 0) (score 0) (run 0))
	(while (and (< ci cn) (< qi qn))
	  (if (char-equal (char candidate ci) (char query qi))
	      (progn
		(setq run (1+ run))
		(incf score (* 10 run))
		(when (or (zerop ci)
			  (member (char candidate (1- ci))
				  '(#\/ #\_ #\- #\. #\Space) :test #'char=))
		  (incf score 50))
		(setq qi (1+ qi)))
	    (setq run 0))
	  (setq ci (1+ ci)))
	;; CANDIDATE の長さをそのままタイブレークとして引く。一致の質を表す
	;; 上のボーナスに比べて十分小さいので、明確な優劣があるときの
	;; 順位には影響しない。
	(if (= qi qn)
	    (- score cn)
	  nil)))))

(defun fuzzy-score (candidate query)
  "CANDIDATE が QUERY の (大文字小文字を無視した) 部分列であればスコアを
返す。一致しなければ nil。連続一致・単語区切り直後の一致にボーナスを
付けるので、スコアが大きいほど良い一致とみなせる。

CANDIDATE がパス (例: \"lisp/project.l\") のときは、パス全体とファイル名
部分 (最後の '/' より後ろ) の両方でスコアを計算し、良い方を採用する。
貪欲な1回走査 (fuzzy-score-1) は、ディレクトリ名側に QUERY の先頭文字と
たまたま一致する文字があると、そちらに食いつかれてファイル名側の綺麗な
連続一致を見逃すことがあるため、ファイル名部分だけの再走査で補う。"
  (if (zerop (length query))
      0
    (let* ((full (fuzzy-score-1 candidate query))
	   (slash (position #\/ candidate :from-end t))
	   (base (and slash (fuzzy-score-1 (subseq candidate (1+ slash)) query))))
      (cond
       ((and full base) (max full (+ base 50)))
       (base (+ base 50))
       (t full)))))

(defun fuzzy-filter (candidates query &optional limit)
  "CANDIDATES を QUERY でファジー絞り込みし、スコア降順で返す。
QUERY が空文字列のときは絞り込まず、先頭から LIMIT 件を返す。"
  (let ((result
	 (if (zerop (length query))
	     candidates
	   (let (scored)
	     (dolist (c candidates)
	       (let ((s (fuzzy-score c query)))
		 (when s (push (cons s c) scored))))
	     (mapcar #'cdr (sort scored #'> :key #'car))))))
    (if (and limit (> (length result) limit))
	(subseq result 0 limit)
      result)))

(defun fuzzy-format-candidates (matches index query total)
  "ステータス行1行に収める候補一覧の表示文字列を作る。選択中の候補は
[...] で囲んで示す。"
  (cond
   ((null matches)
    (if (zerop (length query)) "" "  (0 件一致)"))
   (t
    (let ((i -1))
      (format nil "  (~D/~D件) ~{~A~^ | ~}"
	      (1+ index) total
	      (mapcar #'(lambda (m)
			  (incf i)
			  (if (= i index) (format nil "[~A]" m) m))
		      matches))))))

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
  (let ((query "") (index 0) (total (length candidates)))
    (catch 'fuzzy-complete-exit
      (while t
	(let* ((matches (fuzzy-filter candidates query *fuzzy-max-candidates*))
	       (n (length matches)))
	  (when (>= index (max n 1))
	    (setq index (max 0 (1- n))))
	  (minibuffer-prompt "~A~A~A" prompt query
			      (fuzzy-format-candidates matches index query total))
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
