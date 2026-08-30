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
