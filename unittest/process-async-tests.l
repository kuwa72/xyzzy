;;; -*- Encoding: utf-8 -*-
;;;
;;; 非同期のプロセス (`make-process`) の出力 (issue #250)。
;;;
;;; **どれも一度も測られていなかった。** `#50` の「サブプロセスは動く」は
;;; `call-process` (同期) で確かめたもので、**非同期の側は測っていなかった。**
;;; その間、POSIX では
;;;
;;;   * 出力がバッファに入らず (端末エミュレータへ行き、子の終了と同時に
;;;     エミュレータごと辿れなくなって消えた)
;;;   * **`set-process-filter` が一度も呼ばれず** (呼ぶ場所が
;;;     `Process::insert_output` の中で、そこへ来なかった)
;;;
;;; という状態だった。`M-x execute-subprocess-dialog`
;;; (「コンソールプログラムを非同期で実行」) が空のバッファを出していた。
;;;
;;; **待ち方は期限付きで書く。** 固定の `sleep-for` にすると、子プロセスの
;;; 往復を 1 つの枠に押し込むことになるので機械が混んでいると落ちる
;;; (`unittest/timer-tests.l` / `unittest/flymake-tests.l` と同じ形)。

(defun process-async-test-wait (predicate limit)
  "PREDICATE が真になるまで待つ。LIMIT 秒で諦める。真になったら t。"
  (let ((start (get-internal-real-time)))
    (loop
      (when (funcall predicate)
        (return t))
      (when (> (- (get-internal-real-time) start) (* limit 1000))
        (return nil))
      (sleep-for 0.02))))

(defmacro with-process-async-buffer ((var) &body body)
  `(let ((,var (create-new-buffer "*process async test*")))
     (unwind-protect
         (progn ,@body)
       (ignore-errors (delete-buffer ,var)))))
(setf (get 'with-process-async-buffer 'ed:lisp-indent-hook) 1)

(defun process-async-test-command (text)
  "TEXT を 1 行出すだけのコマンド。`echo` は cmd.exe の内部コマンドにも
sh の組み込みにもある (`unittest/flymake-tests.l` と同じ判断)。"
  (concat "echo " text))


;;;; 出力がバッファに入る

(deftest process-async-output-reaches-the-buffer ()
  "**これが空だったのが issue #250 である。**"
  (with-process-async-buffer (buf)
    (let ((p (make-process (process-async-test-command "async-output-here")
                           :output buf)))
      (process-async-test-wait
       #'(lambda () (not (eq (process-status p) :run))) 30)
      ;; 終了を見てから、残りが流れ込むのを待つ。
      (process-async-test-wait
       #'(lambda () (plusp (save-excursion (set-buffer buf) (buffer-size)))) 30)
      (let ((s (save-excursion (set-buffer buf)
                 (buffer-substring (point-min) (point-max)))))
        (and (stringp s) (string-match "async-output-here" s) t))))
  => t)

;;; **行末に CR が混ざらないこと。** pty の行規則は `\n` を `\r\n` にする。
;;; 端末エミュレータはそれを解釈するが、**バッファのテキストとして入れる
;;; 経路では CR が文字として残る** ので、端末として使わないときは ONLCR を
;;; 切ってある。実際に `"hello\r\n"` が入っていた。
(deftest process-async-output-has-no-carriage-return ()
  (if (not (featurep :unix))
      '(t nil)
    (with-process-async-buffer (buf)
      (let ((p (make-process (process-async-test-command "no-cr-here")
                             :output buf)))
        (process-async-test-wait
         #'(lambda () (not (eq (process-status p) :run))) 30)
        (process-async-test-wait
         #'(lambda () (plusp (save-excursion (set-buffer buf) (buffer-size)))) 30)
        (let ((s (save-excursion (set-buffer buf)
                   (buffer-substring (point-min) (point-max)))))
          ;; **中身が来ていることも見る。** CR の有無だけを見ると、
          ;; **何も入らなかったときにも通ってしまう** (負の確認でそうなった)。
          (list (and s (string-match "no-cr-here" s) t)
                (and s (string-match "\r" s) t))))))
  => (t nil))


;;;; プロセスフィルタ

;;; **一度も呼ばれていなかった。** 呼ぶ場所が `Process::insert_output` の
;;; 中で、端末エミュレータを必ず作っていたのでそこへ来なかった。
(deftest process-async-filter-is-called ()
  (with-process-async-buffer (buf)
    (let ((got "")
          (p (make-process (process-async-test-command "filtered-text")
                           :output buf)))
      (set-process-filter p #'(lambda (proc s) (setq got (concat got s))))
      (process-async-test-wait
       #'(lambda () (not (eq (process-status p) :run))) 30)
      (process-async-test-wait
       #'(lambda () (string-match "filtered-text" got)) 30)
      (and (string-match "filtered-text" got) t)))
  => t)

;;; **フィルタが付いているとバッファには入らない。** どちらか一方である
;;; (`insert_output` はフィルタがあればそちらへ渡して戻る)。**両方に入ると、
;;; フィルタで加工したものとそのままのものが混ざる。**
(deftest process-async-filter-takes-the-output-instead-of-the-buffer ()
  (with-process-async-buffer (buf)
    (let ((got "")
          (p (make-process (process-async-test-command "only-to-filter")
                           :output buf)))
      (set-process-filter p #'(lambda (proc s) (setq got (concat got s))))
      (process-async-test-wait
       #'(lambda () (not (eq (process-status p) :run))) 30)
      (process-async-test-wait
       #'(lambda () (string-match "only-to-filter" got)) 30)
      ;; **フィルタが受けたことも見る。** バッファが空であることだけを
      ;; 見ると、**何も流れなかったときにも通ってしまう。**
      (list (and (string-match "only-to-filter" got) t)
            (save-excursion (set-buffer buf) (buffer-size)))))
  => (t 0))


;;;; :terminal は頼まれたときだけ

;;; **既定で端末エミュレータを作らない。** 作ると出力がそちらへ行き、
;;; バッファにもフィルタにも来ない (それが issue #250 だった)。
(deftest process-async-no-terminal-by-default ()
  (if (not (featurep :unix))
      '(nil t)
    (with-process-async-buffer (buf)
      (let ((p1 (make-process "sleep 2" :output buf)))
        (unwind-protect
            (let ((without (si:process-terminal-p p1)))
              (signal-process p1)
              (process-async-test-wait
               #'(lambda () (not (eq (process-status p1) :run))) 30)
              (with-process-async-buffer (buf2)
                (let ((p2 (make-process "sleep 2" :output buf2 :terminal t)))
                  (unwind-protect
                      (list without (and (si:process-terminal-p p2) t))
                    (ignore-errors (signal-process p2))))))
          (ignore-errors (signal-process p1))))))
  => (nil t))
