;;; -*- Encoding: utf-8 -*-
;;;
;;; フロントエンドの Lisp 入口のうち、**実装があるのにテストが 1 件も
;;; 無かったもの** (issue #234)。
;;;
;;; `src/frontend/ncurses/ncurses-stubs.cc` の Lisp 入口 183 個を中身の
;;; 行数で分けると、実質スタブが 153、実装があるものが 30 で、**そのうち
;;; 24 個が `unittest/` と `tools/linux-smoke.sh` に名前が 1 度も出て
;;; いなかった。** 画面が要るもの (`popup-list` / `popup-string` /
;;; メニュー) は `tools/linux-smoke.sh` の pty で見ている。**ここに置いて
;;; あるのは `--batch` から測れるものだけである。**
;;;
;;; **書いてある値は両プラットフォームで実際に測った** (linux native と
;;; Wine x86_64)。分けてあるのは本当に違うものだけで、理由を各所に書いた。

(require "misc")

;;;; 画面と窓の大きさ
;;;
;;; **数を期待してはいけない。** 実測で linux は 80x24、Wine は 119x45 で、
;;; 端末の大きさと GUI のフォントで決まる。**「桁」であることは両方で同じ**
;;; (Win32 側も `app.active_frame.size.cx / app.text_font.cell ().cx` で
;;; ピクセルを桁に割っている) ので、**関係だけを見る。**

(deftest screen-size-is-a-positive-number-of-columns ()
  (list (and (integerp (screen-width)) (plusp (screen-width)))
        (and (integerp (screen-height)) (plusp (screen-height))))
  => (t t))

(deftest screen-size-does-not-change-between-calls ()
  "同じ質問に同じ答えを返すこと。**毎回数え直して違う値が出ると、
`window-width` との比較が成り立たない瞬間ができる。**"
  (list (= (screen-width) (screen-width))
        (= (screen-height) (screen-height)))
  => (t t))

(deftest window-fits-in-the-screen ()
  "窓は画面より広くならない。行はモード行とエコー領域の分だけ必ず少ない。"
  (list (<= (window-width) (screen-width))
        (< (window-lines) (screen-height)))
  => (t t))

;;; **分割してから足すのが本題である。** 1 つの窓だけ見ていると、境界の桁を
;;; 二重に数えていても気付けない (`compute_geometry` の境界の扱いは
;;; issue #83 で実際に壊れていた)。実測では linux が 79 <= 80、
;;; Wine が 116 <= 119 で、**余りの桁数はプラットフォームで違う**ので
;;; 等号ではなく `<=` で見る。
(deftest split-windows-fit-side-by-side ()
  (unwind-protect
      (progn
        (delete-other-windows)
        (split-window-vertically)
        (let* ((a (window-width))
               (b (progn (other-window) (window-width)))
               (n (count-windows)))
          (list n (<= (+ a b) (screen-width)))))
    (ignore-errors (delete-other-windows)))
  => (2 t))

(deftest window-width-checks-its-argument ()
  "窓でないものを渡すと型エラーになること。"
  (handler-case (progn (window-width 'foo) :no-error)
    (type-error () :type-error))
  => :type-error)


;;;; 中断文字 (quit-char / set-quit-char)
;;;
;;; **端末では `C-g` を入力から直に見ている** (`ncurses-kbd.cc` の
;;; `ncurses_quit_char`) ので、ここが効かないと**走っている Lisp を止められ
;;; なくなる** (issue #162)。読み書きの往復は両方で同じだった。

(deftest quit-char-defaults-to-C-g ()
  (quit-char)
  => #\C-g)

(deftest quit-char-round-trips ()
  "設定した文字がそのまま読めること。**書く方だけ測ると、返り値を返して
何も設定していない形が通る。**"
  (unwind-protect
      (progn (set-quit-char #\C-c)
             (quit-char))
    (set-quit-char #\C-g))
  => #\C-c)

(deftest set-quit-char-returns-the-character ()
  (unwind-protect
      (set-quit-char #\C-c)
    (set-quit-char #\C-g))
  => #\C-c)

;;; **`nil` は型エラーである。** 端末側は
;;; `if (!c || c == Qnil) return Qnil;` を持っていて、**同じ呼びが端末では
;;; nil、Win32 では型エラー**になっていた。引数は 1 つ必須なので nil は
;;; 呼ぶ側の間違いで、受け側で黙って飲むと「効かない」形で残る。Win32 に
;;; 揃えた。
(deftest set-quit-char-refuses-nil ()
  (unwind-protect
      (handler-case (progn (set-quit-char nil) :no-error)
        (type-error () :type-error))
    (set-quit-char #\C-g))
  => :type-error)

(deftest set-quit-char-refuses-a-non-character ()
  (unwind-protect
      (handler-case (progn (set-quit-char 'foo) :no-error)
        (type-error () :type-error))
    (set-quit-char #\C-g))
  => :type-error)


;;;; エコー領域のメッセージ (si:*minibuffer-message)
;;;
;;; **`message` とは別の入口である。** `message` は同じ変数を経由して同じ
;;; 場所に出るが、**通る関数が違う** -- 端末側の
;;; `Fsi_minibuffer_message` は以前**空実装**で、`message` の出力先を
;;; エコー領域へ回した時点 (issue #97) でメッセージが 1 つも見えなくなった。
;;; `unittest/echo-area-tests.l` は `message` の側だけを見ている。
;;;
;;; 変数 `*minibuffer-message*` は uninterned なので Lisp から見えない。
;;; **見えるのはエコー領域の行数**で、そこは `echo-area-tests.l` と同じ
;;; 測り方をする。

(deftest minibuffer-message-returns-t ()
  (unwind-protect
      (si:*minibuffer-message "SMOKE")
    (si:*minibuffer-message nil))
  => t)

(deftest minibuffer-message-grows-the-echo-area ()
  "3 行のメッセージで 3 行になり、nil で 1 行に戻ること。

**戻ることの方が大事である。** 伸びたまま戻らないと、メッセージを 1 回
出すごとに編集できる行が減る。"
  (unwind-protect
      (progn
        (si:*minibuffer-message "a
b
c")
        (refresh-screen)
        (let ((grown (window-lines (minibuffer-window))))
          (si:*minibuffer-message nil)
          (refresh-screen)
          (list grown (window-lines (minibuffer-window)))))
    (progn (si:*minibuffer-message nil)
           (ignore-errors (refresh-screen))))
  => (3 1))

(deftest minibuffer-message-checks-its-argument ()
  "文字列以外は型エラーになること (nil は「消す」なので通る)。"
  (unwind-protect
      (handler-case (progn (si:*minibuffer-message 'foo) :no-error)
        (type-error () :type-error))
    (si:*minibuffer-message nil))
  => :type-error)

(deftest minibuffer-message-takes-a-prompt-flag ()
  "第 2 引数 (プロンプトかどうか) を受けること。**表示の違いは
`*minibuffer-prompt*` が uninterned なので Lisp から見えない**ので、
受け付けることだけを見る。"
  (unwind-protect
      (si:*minibuffer-message "P" t)
    (si:*minibuffer-message nil))
  => t)


;;;; ヘルプ文字列 (si:get-documentation-string)

(deftest get-documentation-string-returns-the-whole-string ()
  (progn
    (setf (get 'frontend-entry-doc-sym 'documentation)
          "1 行目です
2 行目です")
    (si:get-documentation-string 'frontend-entry-doc-sym 'documentation nil nil))
  => "1 行目です
2 行目です")

(deftest get-documentation-string-apropos-takes-the-first-line-only ()
  "apropos の一覧に 2 行目まで出ると表が崩れる。"
  (progn
    (setf (get 'frontend-entry-doc-sym 'documentation)
          "1 行目です
2 行目です")
    (si:get-documentation-string 'frontend-entry-doc-sym 'documentation t nil))
  => "1 行目です")

(deftest get-documentation-string-returns-nil-when-there-is-none ()
  (si:get-documentation-string 'frontend-entry-no-such-sym 'documentation nil nil)
  => nil)

;;; **ここは分かれる。** property が文字列でないとき、端末側は nil を返す
;;; (POSIX では `si:*snarf-documentation` が空実装なので、property が
;;; DOC ファイルの位置を表す整数になることがない)。Win32 側はその整数を
;;; 位置として DOC ファイルを開こうとして、**pathname の型エラーになる。**
;;; Win32 の方は DOC ファイルの扱いの話なので、ここでは測らない。
(deftest get-documentation-string-ignores-a-non-string-property ()
  (if (featurep :unix)
      (progn
        (setf (get 'frontend-entry-doc-sym2 'documentation) 42)
        (si:get-documentation-string 'frontend-entry-doc-sym2 'documentation nil nil))
    nil)
  => nil)


;;;; 前置引数 (reset-prefix-args / set-next-prefix-args)
;;;
;;; **設定した値は Lisp から見えない。** 入れ先の `*next-prefix-args*` /
;;; `*next-prefix-value*` は uninterned で、次のコマンドが
;;; `*prefix-args*` として受け取る形なので、**コマンドループを 1 周
;;; 回さないと観測できない。** ここで測るのは受け付ける形だけである
;;; (第 3 引数の型検査は Win32 側にもある)。

(deftest reset-prefix-args-accepts-two-arguments ()
  (unwind-protect
      (reset-prefix-args 3 7)
    (reset-prefix-args nil nil))
  => t)

(deftest set-next-prefix-args-accepts-an-optional-character ()
  (unwind-protect
      (list (set-next-prefix-args 4 9)
            (set-next-prefix-args 4 9 #\a))
    (reset-prefix-args nil nil))
  => (t t))

(deftest set-next-prefix-args-checks-the-character ()
  "第 3 引数が文字でなければ型エラーになること。"
  (unwind-protect
      (handler-case (progn (set-next-prefix-args 1 2 'foo) :no-error)
        (type-error () :type-error))
    (reset-prefix-args nil nil))
  => :type-error)


;;;; continue-popup
;;;
;;; ポップアップを次のコマンドまで残す指示。**残るかどうかは画面の話**で、
;;; `tools/linux-smoke.sh` の pty 側で `popup-list` / `popup-string` を
;;; 見ている。ここで測れるのは呼べることだけである。
(deftest continue-popup-returns-t ()
  (continue-popup)
  => t)
