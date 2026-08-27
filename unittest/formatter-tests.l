;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/formatter.l のテスト。
;;;
;;; 外部コマンドを本当に起動する部分も見ている。フォーマッタ本体
;;; (clang-format 等) は環境に無いので、代わりを 4 つ用意した:
;;;
;;;   with-fake-formatter -- 入力の前に FORMATTED を 1 行足すだけの .cmd。
;;;                          「成功して内容が変わる」経路。Wine の cmd には
;;;                          sort が無く more は入力をそのまま返すだけなので、
;;;                          変換するフィルタは自分で書くしかない。
;;;   cmd /c more         -- 入力をそのまま返す。「成功したが内容は同じ」経路
;;;   cmd /c exit 1       -- 終了コード非 0 の失敗例
;;;   cmd /c break        -- 0 で終わるが何も出力しない例 (ここが一番危ない)
;;;   no-such-formatter   -- 起動できない例
;;;
;;; 大事なのは後ろの 3 つで、いずれもバッファに触らないこと。触ると
;;; 「保存したらファイルが空になった」になる。

(require "formatter")

(defun formatter-test-contents ()
  "バッファの中身。CR は落とす: 外部コマンドの出力は CRLF で来るので、
改行の扱いに環境差が出てもテストが揺れないようにする。"
  (remove #\CR (buffer-substring (point-min) (point-max))))

(defmacro with-fake-formatter ((var) &body body)
  "入力の前に FORMATTED という 1 行を足すだけの .cmd を作り、その
コマンド文字列を VAR に束縛して BODY を実行する。"
  `(let ((,var nil)
	 (%file (concat (make-temp-file-name) ".cmd")))
     (unwind-protect
	 (progn
	   (with-open-file (s %file :direction :output :if-exists :supersede)
	     (format s "@echo off~%echo FORMATTED~%more~%"))
	   (setq ,var (format nil "cmd /c \"~A\"" %file))
	   ,@body)
       (ignore-errors (delete-file %file)))))

;;;
;;; コマンドの選択
;;;

(deftest formatter-command-for-buffer ()
  "モードから引けること。~A はファイル名に置き換わること"
  (with-temp-buffer
    (let ((ed::*formatter-alist* '((ed::lisp-mode . "fake-fmt")
				   (ed::text-mode . "fake-fmt --file \"~A\""))))
      (ed::lisp-mode)
      (let ((a (ed::formatter-command-for-buffer)))
	(ed::text-mode)
	;; ファイルを持たないバッファではバッファ名で埋める
	(let ((b (ed::formatter-command-for-buffer)))
	  (values a
		  (and (string-match (regexp-quote (buffer-name (selected-buffer))) b)
		       t))))))
  => "fake-fmt"
  => t)

(deftest formatter-command-for-unknown-mode ()
  "登録の無いモードでは nil"
  (with-temp-buffer
    (let ((ed::*formatter-alist* nil))
      (ed::lisp-mode)
      (ed::formatter-command-for-buffer)))
  => nil)

;;;
;;; 外部コマンドを実際に起動する
;;;

(deftest formatter-run-replaces-on-success ()
  "0 で終わって出力があれば差し替えること"
  (with-temp-buffer
    (insert "ccc\naaa\n")
    (with-fake-formatter (fmt)
      (values (ed::formatter-run fmt t)
	      (formatter-test-contents))))
  => t
  => "FORMATTED\nccc\naaa\n")

(deftest formatter-run-keeps-buffer-on-failure ()
  "終了コードが 0 でなければバッファに触らないこと"
  (with-temp-buffer
    (insert "ccc\naaa\n")
    (values (ed::formatter-run "cmd /c exit 1" t)
	    (formatter-test-contents)))
  => nil
  => "ccc\naaa\n")

(deftest formatter-run-keeps-buffer-on-empty-output ()
  "0 で終わっても出力が空ならバッファに触らないこと
(ここで差し替えるとファイルが消える)"
  (with-temp-buffer
    (insert "ccc\naaa\n")
    (values (ed::formatter-run "cmd /c break" t)
	    (formatter-test-contents)))
  => nil
  => "ccc\naaa\n")

(deftest formatter-run-keeps-buffer-when-command-missing ()
  "起動できないコマンドでもバッファに触らないこと"
  (with-temp-buffer
    (insert "ccc\naaa\n")
    (values (ed::formatter-run "no-such-formatter-xyzzy" t)
	    (formatter-test-contents)))
  => nil
  => "ccc\naaa\n")

(deftest formatter-run-does-nothing-when-already-formatted ()
  "出力が今の内容と同じなら差し替えないこと (バッファを無駄に変更済みに
しないため)。cmd /c more は入力をそのまま返す。"
  (with-temp-buffer
    (insert "aaa\nbbb\nccc\n")
    (values (ed::formatter-run "cmd /c more" t)
	    (formatter-test-contents)))
  => nil
  => "aaa\nbbb\nccc\n")

(deftest formatter-run-keeps-cursor-line-and-column ()
  "差し替えた後もカーソルの行と桁が保たれること
(整形で行がずれる分までは追わない。行と桁をそのまま戻すだけ)"
  (with-temp-buffer
    (insert "ccc\naaa\nbbb\n")
    (goto-line 2)
    (goto-column 2)
    (with-fake-formatter (fmt)
      (ed::formatter-run fmt t))
    (values (current-line-number) (current-column)))
  => 2
  => 2)

;;;
;;; 保存時の掃除
;;;

(deftest formatter-trim-trailing-whitespace ()
  "行末の空白だけを落とし、行の中の空白は残すこと"
  (with-temp-buffer
    (insert "a b  \nc\t\nd\n   \n")
    (let ((n (ed::formatter-trim-trailing-whitespace)))
      (values n (formatter-test-contents))))
  => 3
  => "a b\nc\nd\n\n")

(deftest formatter-trim-trailing-whitespace-nothing-to-do ()
  "落とすものが無ければ 0 を返してバッファは変わらないこと"
  (with-temp-buffer
    (insert "a\nb\n")
    (values (ed::formatter-trim-trailing-whitespace)
	    (formatter-test-contents)))
  => 0
  => "a\nb\n")

(deftest formatter-ensure-final-newline ()
  "末尾に改行が無ければ足すこと"
  (with-temp-buffer
    (insert "a\nb")
    (values (ed::formatter-ensure-final-newline)
	    (formatter-test-contents)))
  => t
  => "a\nb\n")

(deftest formatter-ensure-final-newline-already-there ()
  "既に改行で終わっていれば足さないこと (毎回 1 行増えては困る)"
  (with-temp-buffer
    (insert "a\nb\n")
    (values (ed::formatter-ensure-final-newline)
	    (formatter-test-contents)))
  => nil
  => "a\nb\n")

(deftest formatter-ensure-final-newline-empty-buffer ()
  "空のバッファには足さないこと"
  (with-temp-buffer
    (values (ed::formatter-ensure-final-newline)
	    (formatter-test-contents)))
  => nil
  => "")

;;;
;;; 保存フック
;;;

(deftest formatter-before-save-returns-nil ()
  "*before-save-buffer-hook* は run-hook-until-success なので、
non-nil を返すと保存が中止される。必ず nil を返すこと。
掃除も整形も全部有効にした状態で確認する。"
  (with-temp-files (file)
    (with-temp-buffer
      (insert "ccc   \naaa")
      (write-file file)
      ;; write-file はバッファのファイル名を設定しないので明示的に付ける。
      ;; formatter-before-save は「ファイルを持つバッファ」でしか動かない。
      (set-buffer-file-name file)
      (with-fake-formatter (fmt)
	(let ((ed::*on-save-trim-trailing-whitespace* t)
	      (ed::*on-save-ensure-final-newline* t)
	      (ed::*format-on-save* t)
	      (ed::*formatter-alist*
	       (list (cons ed::buffer-mode fmt))))
	  (values (ed::formatter-before-save)
		  (formatter-test-contents))))))
  => nil
  => "FORMATTED\nccc\naaa\n")

(deftest formatter-before-save-does-nothing-by-default ()
  "既定 (全部 nil) では何もしないこと"
  (with-temp-files (file)
    (with-temp-buffer
      (insert "ccc   \naaa")
      (write-file file)
      (set-buffer-file-name file)
      (values (ed::formatter-before-save)
	      (formatter-test-contents))))
  => nil
  => "ccc   \naaa")

(deftest formatter-before-save-skips-buffers-without-a-file ()
  "ファイルを持たないバッファ (*scratch* など) では何もしないこと"
  (with-temp-buffer
    (insert "ccc   \n")
    (let ((ed::*on-save-trim-trailing-whitespace* t))
      (values (ed::formatter-before-save)
	      (formatter-test-contents))))
  => nil
  => "ccc   \n")

(deftest formatter-hook-is-installed ()
  "*before-save-buffer-hook* に入っていること"
  (and (member 'ed::formatter-before-save ed::*before-save-buffer-hook*) t)
  => t)

(deftest formatter-defaults-are-off ()
  "保存時にファイルを書き換える設定は既定で全部 nil であること"
  (values ed::*format-on-save*
	  ed::*on-save-trim-trailing-whitespace*
	  ed::*on-save-ensure-final-newline*)
  => nil
  => nil
  => nil)
