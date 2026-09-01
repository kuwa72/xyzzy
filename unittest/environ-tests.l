;;; -*- Mode: Lisp; Encoding: utf-8 -*-
(defun execute-shell-command-string (command)
  (let ((b (create-new-buffer "*command*")))
    (unwind-protect
        (save-window-excursion
          (execute-shell-command command nil b)
          (set-buffer b)
          (buffer-substring (point-min) (point-max)))
      (delete-buffer b))))

;; シェルから見た環境変数。**`si:environ' と突き合わせるための「外の目」**で、
;; ここが Windows 専用だったため POSIX ではこのファイルの 2 件が測れず、
;; **`si:putenv' が POSIX で黙って何もしていないのを何年も見逃していた**
;; (putenv がスタックの文字列のポインタを環境に置いていた)。
(defun my-environ-command ()
  (if (featurep :unix) "env" "cmd.exe /c set"))

;; シェル自身が足す / 書き換える名前。突き合わせから外す。
;;
;;   PROMPT  cmd.exe が自分で持っている
;;   _       sh が「直前に実行したコマンド」として置く
;;   PWD SHLVL OLDPWD  sh がサブシェルで更新する
;;
;; **「シェルの側にしか無いもの」を外すだけ**で、`si:environ' の側にある
;; ものは全部突き合わせる。そうでないと putenv の壊れ方を見逃す。
(defparameter *my-environ-ignore*
  '("PROMPT" "_" "PWD" "SHLVL" "OLDPWD"))

(defun my-environ ()
  (remove-if #'(lambda (pair)
                 (member (car pair) *my-environ-ignore* :test #'string=))
    (mapcar #'(lambda (kv)
                (let ((pos (position #\= kv)))
                  (cons (subseq kv 0 pos)
                        (subseq kv (1+ pos)))))
            (remove-if #'(lambda (kv) (null (position #\= kv)))
                       (split-string (execute-shell-command-string
                                      (my-environ-command))
                                     #\LFD)))))

(defun si-environ-filtered ()
  (remove-if #'(lambda (pair)
                 (member (car pair) *my-environ-ignore* :test #'string=))
             (si:environ)))

(deftest test-environ-1 ()
  (equal (sort (my-environ) #'string< :key 'car)
         (sort (si-environ-filtered) #'string< :key 'car))
  => t)

;; **`si:putenv' で足したものが、子プロセスから見えること。**
;; POSIX の `putenv' は渡した文字列を複写せずポインタを環境に置くので、
;; スタックの文字列を渡すと**成功を返しておいて何も起きない。**
;; ここはそれを捕まえる唯一のテスト。
(deftest test-environ-2 ()
  (si:putenv "test" "hoge")
  (unwind-protect
      (equal (sort (my-environ) #'string< :key 'car)
             (sort (si-environ-filtered) #'string< :key 'car))
    (si:putenv "test" nil))
  => t)

(deftest test-setf-getenv ()
  (unwind-protect
      (values
       (setf (si:getenv "test") "hoge1")
       (setf (si:getenv "test") "hoge2")
       (si:getenv "test"))
    (si:putenv "test" nil))
  => "hoge1"
  => "hoge2"
  => "hoge2")

;;; --- Windows 固有のディレクトリ -----------------------------------------

;; **未束縛の変数を読むと `#:unbound' がそのまま出てくる。** 値を入れている
;; のは src/frontend/win32/init.cc の `init_windows_dir' だけで、POSIX には
;; それに当たるものが無い。読んでも `unbound-variable' にならないので
;; `ignore-errors' でも捕まらず、**どこにも無い値が merge-pathnames や
;; リストへ静かに流れていく。** `unittest/editor-tests.l' の chdir-* 7 件と
;; `unittest/lisp-tests.l' の fix-truename-* 4 件がこれを踏んでいた
;; (issue #50)。
;;
;; POSIX に Windows ディレクトリは無いので、**「無い」を表す nil が正しい。**
(deftest windows-directories-are-bound ()
  (list (let ((d (get-windows-directory))) (if (featurep :unix) (null d) (stringp d)))
        (let ((d (get-system-directory)))  (if (featurep :unix) (null d) (stringp d))))
  => (t t))

;;; --- タイムゾーン --------------------------------------------------------
;;;
;;; **POSIX では `GetTimeZoneInformation' が `Bias' を 0 のままにしていたので、
;;; 常に UTC だった** (issue #204)。`(get-decoded-time)' のタイムゾーンの欄が
;;; 常に 0、`encode-universal-time' / `decode-universal-time' をタイムゾーン
;;; 無しで呼ぶと**地方時の offset の分だけ間違った値**を返していた。
;;; エラーは出ない。
;;;
;;; **devenv のコンテナと CI の runner が両方 TZ=UTC なので、間違った値と
;;; 正しい値が一致して見えなかった。** 同じ理由で見逃していたバグが既に 1 件
;;; ある (`SystemTimeToFileTime' が `mktime' を使っていた件)。
;;; **だから TZ を変えた子プロセスで測る。**

;; **両方のプラットフォームで成り立つ性質。** 地方時の欄とタイムゾーンの欄が
;; 同じ時刻を指していること。
;;
;; `(get-decoded-time)' が返すタイムゾーンは**標準時の**offset で、夏時間は
;; 別の値 (8 番目) で来る。`encode-universal-time' にタイムゾーンを明示すると
;; 夏時間を足さないので、夏時間の最中はそのぶん引く。
;;
;; **UTC の環境ではこのテストは壊れた実装でも通る** (offset が 0 なので
;; 間違いが見えない)。TZ の効きを見るのは下の 2 件で、こちらは
;; 「関係が崩れていないこと」を両方のプラットフォームで押さえるためにある。
(deftest get-decoded-time-agrees-with-get-universal-time ()
  (multiple-value-bind (sec min hour day month year dow daylight zone)
      (get-decoded-time)
    (let ((u (encode-universal-time sec min hour day month year zone)))
      (when daylight
        (setq u (- u 3600)))
      ;; 2 回の呼び出しの間に時計が進むので少しだけ緩める。
      (< (abs (- u (get-universal-time))) 3)))
  => t)

;; **TZ を変えた子プロセスで測る。** POSIX 限定 — Win32 は TZ 環境変数では
;; タイムゾーンが変わらない (レジストリを見る) ので、同じテストにならない。
;;
;; `JST-9` は POSIX 形式の TZ (名前 + UTC からの offset を東を負で書く) で、
;; **`Asia/Tokyo` と違って tzdata のファイルが要らない。** テストが
;; `/usr/share/zoneinfo` の中身に依らないようにこちらを使う。
;;
;; **夏時間は測っていない。** POSIX 形式で夏時間を書くと「今が夏時間の期間か」
;; に答えが依ってしまい、走らせる日で結果が変わる。
(deftest get-decoded-time-timezone-follows-tz ()
  (if (featurep :unix)
      (list (eval-in-another-xyzzy '(nth 8 (multiple-value-list (get-decoded-time)))
                                   :environ '(("TZ" . "JST-9")))
            (eval-in-another-xyzzy '(nth 8 (multiple-value-list (get-decoded-time)))
                                   :environ '(("TZ" . "UTC0"))))
    '(-9 0))
  => (-9 0))

;; **`encode-universal-time' がタイムゾーンを省略したときに地方時として
;; 解釈すること。** 上のテストは `(get-decoded-time)' の欄を見るだけなので、
;; `get_timezone' (src/core/environ.cc) を通る経路はこちらで測る。
;;
;; JST の 2000-01-01 00:00 は UTC の 1999-12-31 15:00 なので、タイムゾーンを
;; 0 と明示したときより 32400 秒だけ小さい universal time になる。
(deftest encode-universal-time-uses-the-local-timezone ()
  (if (featurep :unix)
      (eval-in-another-xyzzy '(- (encode-universal-time 0 0 0 1 1 2000)
                                 (encode-universal-time 0 0 0 1 1 2000 0))
                             :environ '(("TZ" . "JST-9")))
    -32400)
  => -32400)
