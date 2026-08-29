;;; -*- Encoding: utf-8 -*-
;;; ミニバッファで読む関数が、**ちゃんと繋がっているか**。
;;;
;;; プロンプトを出す関数は入力を待つのでバッチでは動かせない。代わりに
;;; 「引数を検査するか」を見る。`read-string' は最初に prompt が文字列で
;;; あることを確かめるので、**繋がっていれば数を渡すと type-error になり、
;;; スタブなら黙って nil が返る。** 端末フロントエンドでは 15 個全部が
;;; `return Qnil' のスタブで、まさに後者だった (issue #114)。
;;;
;;; 「nil が返る」は呼んだ側から見て「空文字列を入力された」あるいは
;;; 「取り消された」と区別がつかないので、**壊れていても誰も気付かない。**
;;; ここで見ているのは、その静かな壊れ方が戻ってこないことである。
;;;
;;; プロンプトが実際に出て値が返ることは pty で確かめた (端末フロント
;;; エンドの画面はテストスイートから触れないため)。

(defmacro deftest-prompt-checks-string (name form)
  `(deftest ,name ()
     (handler-case
         (progn ,form :no-error)
       (type-error () :type-error))
     => :type-error))

(deftest-prompt-checks-string read-string-checks-prompt
  (read-string 5))

(deftest-prompt-checks-string read-integer-checks-prompt
  (read-integer 5))

(deftest-prompt-checks-string read-sexp-checks-prompt
  (read-sexp 5))

(deftest-prompt-checks-string read-file-name-checks-prompt
  (read-file-name 5))

(deftest-prompt-checks-string read-exist-file-name-checks-prompt
  (read-exist-file-name 5))

(deftest-prompt-checks-string read-directory-name-checks-prompt
  (read-directory-name 5))

(deftest-prompt-checks-string read-file-name-list-checks-prompt
  (read-file-name-list 5))

(deftest-prompt-checks-string read-buffer-name-checks-prompt
  (read-buffer-name 5))

(deftest-prompt-checks-string read-exist-buffer-name-checks-prompt
  (read-exist-buffer-name 5))

(deftest-prompt-checks-string read-command-name-checks-prompt
  (read-command-name 5))

(deftest-prompt-checks-string read-function-name-checks-prompt
  (read-function-name 5))

(deftest-prompt-checks-string read-variable-name-checks-prompt
  (read-variable-name 5))

(deftest-prompt-checks-string read-symbol-name-checks-prompt
  (read-symbol-name 5))

(deftest-prompt-checks-string read-char-encoding-checks-prompt
  (read-char-encoding 5))

(deftest-prompt-checks-string read-exact-char-encoding-checks-prompt
  (read-exact-char-encoding 5))

(deftest-prompt-checks-string completing-read-checks-prompt
  (completing-read 5 nil))

;; `minibuffer-buffer' は「そのミニバッファに入った時点で選ばれていた
;; バッファ」を返す。ミニバッファでないバッファを渡したら nil。
;; **端末フロントエンドはここで「ミニバッファウィンドウのバッファ」を
;; 返していて、引数も見ていなかった。**
(deftest minibuffer-buffer-of-normal-buffer-is-nil ()
  (minibuffer-buffer (selected-buffer))
  => nil)
