;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `shell-command-line' (lisp/process.l) のテスト。
;;;
;;; ここが壊れると `M-x shell-command`、`M-x format-buffer`、grep、
;;; `execute-subprocess` が**全部**静かにおかしくなる。コマンドは起動する
;;; ので終了コードは 0 で返り、出力だけが空になる。
;;;
;;; **見るのは「引数が残っているか」。** POSIX で `sh -c' を二重に被せて
;;; いたため、`echo hi' が `sh -c "sh -c echo hi"' になり、内側の sh が
;;; `echo' だけをコマンドとして受け取って `hi' を $0 に食わせていた
;;; (出力が空行 1 つ)。
;;;
;;; 使うコマンドは `echo' だけ。cmd.exe の内部コマンドにも sh の組み込みにも
;;; あるので、Win32 と POSIX で同じテストが書ける。

(defun shell-command-line-test-run (cmd)
  "CMD を `shell-command-line' 経由で起動して、出力を文字列で返す。
CR は落とす: Win32 では CRLF で来る。"
  (let ((outfile (make-temp-file-name)))
    (unwind-protect
	(multiple-value-bind (cmdline dir)
	    ;; `shell-command-line' は editor パッケージから export されて
	    ;; いないので、テストのパッケージからは修飾して呼ぶ。
	    (ed::shell-command-line cmd (default-directory))
	  (call-process cmdline
			:output outfile
			:exec-directory dir
			:show :hide
			:wait t)
	  (let ((buf (create-new-buffer " *shell-command-line test*")))
	    (unwind-protect
		(save-excursion
		  (set-buffer buf)
		  (and (ignore-errors (insert-file-contents outfile))
		       (remove #\RET
			       (buffer-substring (point-min) (point-max)))))
	      (ignore-errors (delete-buffer buf)))))
      (ignore-errors (delete-file outfile)))))

;; 引数が落ちないこと。**これが本体。**
(deftest shell-command-line-keeps-arguments ()
  (let ((out (shell-command-line-test-run "echo arg-survived")))
    (and out (string-matchp "arg-survived" out) t))
  => t)

;; 引数が 2 つ以上でも落ちないこと。1 つだけ通って 2 つ目が落ちる形の
;; 壊れ方もあるので、別に見る。
(deftest shell-command-line-keeps-several-arguments ()
  (let ((out (shell-command-line-test-run "echo one two three")))
    (and out
	 (string-matchp "one" out)
	 (string-matchp "two" out)
	 (string-matchp "three" out)
	 t))
  => t)

;; **シェルを通っていること。** 引数を落とさない直し方として「シェルを
;; 通さない」もありえるが、それをするとリダイレクトやパイプが使えなくなる。
;; `M-x shell-command` が `ls | head` を受け取れなくなるので、通っている
;; ことを確かめる。
(deftest shell-command-line-goes-through-a-shell ()
  (let* ((tmp (make-temp-file-name))
	 (out (unwind-protect
		  (progn
		    (shell-command-line-test-run
		     (format nil "echo redirected> \"~A\"" tmp))
		    (let ((buf (create-new-buffer " *redirect test*")))
		      (unwind-protect
			  (save-excursion
			    (set-buffer buf)
			    (and (ignore-errors (insert-file-contents tmp))
				 (remove #\RET (buffer-substring (point-min)
								 (point-max)))))
			(ignore-errors (delete-buffer buf)))))
		(ignore-errors (delete-file tmp)))))
    (and out (string-matchp "redirected" out) t))
  => t)
