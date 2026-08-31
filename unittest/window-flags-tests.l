;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; ウィンドウの表示フラグ (`get-window-flags` / `set-window-flags`) と
;;; それを使う `toggle-*` の一群。
;;;
;;; **端末では `get-window-flags` が 0 を返し、`set-window-flags` が nil を
;;; 返すスタブだった。** `lisp/window.l` の `toggle-window-flag` はこの 2 つしか
;;; 使わないので、**`toggle-line-number` / `toggle-ruler` / `toggle-newline` /
;;; `toggle-tab` / `toggle-eof` / `toggle-fold-mark` / `toggle-cursor-line` など
;;; 14 個のコマンドが何もしていなかった** (issue #50)。描く側
;;; (`src/core/glyph.cc`) は最初からフラグを見ている。
;;;
;;; **ここは両方のプラットフォームで同じことを聞く。** フラグの意味は
;;; フロントエンドの性質ではなく、`Window::flags ()` の性質である。

(defun window-flags-test-call-with-saved-flags (fn)
  "フラグを元に戻してから抜ける。**戻さないと後続のテストの見た目が変わる。**"
  (let ((saved (get-window-flags)))
    (unwind-protect
        (funcall fn)
      (set-window-flags saved))))

(deftest get-window-flags-returns-a-number ()
  "**0 を返すスタブだった。** 数であること、そして
`*window-flag-*` の定数と論理積が取れること。"
  (let ((f (get-window-flags)))
    (list (integerp f)
          (integerp (logand f ed::*window-flag-line-number*))))
  => (t t))

(deftest set-window-flags-round-trips ()
  "書いたものが読めること。**nil を返すだけのスタブだった。**"
  (window-flags-test-call-with-saved-flags
    #'(lambda ()
        (let ((f (get-window-flags)))
          (set-window-flags (logior f ed::*window-flag-newline*))
          (let ((on (logtest (get-window-flags) ed::*window-flag-newline*)))
            (set-window-flags (logandc2 (get-window-flags)
                                        ed::*window-flag-newline*))
            (list (and on t)
                  (logtest (get-window-flags) ed::*window-flag-newline*))))))
  => (t nil))

(deftest toggle-window-flag-commands-take-effect ()
  "`toggle-*` が本当にフラグを動かすこと。
**これが動いていなかったので、端末では行番号を出すこともできなかった。**"
  (window-flags-test-call-with-saved-flags
    #'(lambda ()
        (ed::toggle-line-number t)
        (let ((on (logtest (get-window-flags) ed::*window-flag-line-number*)))
          (ed::toggle-line-number nil)
          (list (and on t)
                (logtest (get-window-flags) ed::*window-flag-line-number*)))))
  => (t nil))

;;; --- インデントガイド ----------------------------------------------------

;; **「既定で有効」はここでは測れない。**
;;
;; 既定は C 側の `Window::w_default_flags` に入れてあるが、
;; `src/core/environ.cc` の `read_conf (cfgMisc, cfgWindowFlags, ...)` が
;; **`xyzzy.ini` に保存されたフラグでそれを上書きする。** つまり
;;
;;   * 新しい環境 (ini に windowFlags が無い) -> 既定が効いてガイドが出る
;;   * 前から使っている環境 -> 保存された設定が勝ってガイドは出ない
;;
;; どちらも正しい (保存された設定を勝手に変えない方が正しい) が、**テストが
;; どちらの環境で走るかは決められない。** 実際に Wine の環境では ini が
;; あるので落ちた。
;;
;; **新しい環境で本当に出ることは `tools/linux-smoke.sh` が見ている**
;; (何も切り替えずに画面へ縦線が出るかどうか)。ここでは切り替えられることだけ
;; を見る。

(deftest toggle-indent-guide-flips ()
  (window-flags-test-call-with-saved-flags
    #'(lambda ()
        (ed::toggle-indent-guide nil)
        (let ((off (logtest (get-window-flags)
                            ed::*window-flag-indent-guide*)))
          (ed::toggle-indent-guide t)
          (list off
                (and (logtest (get-window-flags)
                              ed::*window-flag-indent-guide*)
                     t)))))
  => (nil t))

(deftest indent-guide-char-is-one-column ()
  "ガイドの字が 1 桁であること。

**2 桁の字だと桁がずれるので、C 側が断って何も出なくなる。** 既定を
`│` (U+2502) にして実際にそれを踏んだ: xyzzy は Box Drawing
(U+2500-U+259F) を East Asian Ambiguous として 2 桁に数える
(`src/core/eaw.cc` の `is_ambiguous`)。**端末と xyzzy の幅の解釈が一致する
のは ASCII だけ**なので既定は `|` にしてある。"
  (let ((c ed::display-indent-guide-char))
    (list (characterp c)
          (= 1 (length (format nil "~C" c)))
          (char-code c)))
  => (t t 124))
