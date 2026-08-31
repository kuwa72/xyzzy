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

;;; --- ウィンドウ単位・バッファ単位 ------------------------------------------
;;;
;;; **端末では `get-local-window-flags` が 0、`set-local-window-flags` が nil を
;;; 返すスタブだった** (issue #50)。Win32 側 (src/frontend/win32/Window.cc) に
;;; 80 行あり、**写すのではなく core へ移した** (src/core/window-config.cc、
;;; #16 Phase 4)。
;;;
;;; フラグは 3 段の重ね合わせで、`Window::flags ()` が
;;;
;;;   ウィンドウ局所  w_flags / w_flags_mask
;;;   バッファ局所    b_wflags / b_wflags_mask
;;;   全体の既定      Window::w_default_flags
;;;
;;; を重ねる。mask は「そのビットについては上位に従う」という意味なので、
;;; **`on-or-off` は 3 値である**: t = 立てる、nil = 倒す、それ以外 =
;;; 上位に従うへ戻す。`get-local-window-flags` は 1 つ目に「局所的に立てた
;;; ビット」、2 つ目に「局所的に倒したビット」を返す。

(defun window-flags-test-call-with-saved-local-flags (obj fn)
  "OBJ (ウィンドウかバッファ) の局所フラグを元に戻してから抜ける。"
  (multiple-value-bind (on off)
      (get-local-window-flags obj)
    (unwind-protect
        (funcall fn)
      (progn
        ;; **まず全ビットを「上位に従う」へ戻す。** ここを
        ;; `(logior on off)` にすると、**初期状態が (0 0) のときに何も
        ;; 戻らない** (テストが触ったビットはどちらの集合にも入っていない)。
        ;; -1 で全ビットを指定するのが初期状態そのものである
        ;; (flags = 0、mask = 全ビット)。
        (set-local-window-flags obj -1 :default)
        (when (/= on 0) (set-local-window-flags obj on t))
        (when (/= off 0) (set-local-window-flags obj off nil))))))

(deftest set-local-window-flags-has-three-states ()
  "t / nil / それ以外 の 3 通りが、2 つの戻り値へどう出るか。

**`:default` (t でも nil でもない値) はどちらの集合からも外れる**のが要点で、
そこが「上位に従う」を表している。以前は 4 つとも中身が無かった。"
  (let ((w (selected-window))
        (f ed::*window-flag-newline*))
    (window-flags-test-call-with-saved-local-flags w
      #'(lambda ()
          (labels ((probe ()
                     (multiple-value-bind (on off)
                         (get-local-window-flags w)
                       (list (and (logtest on f) t)
                             (and (logtest off f) t)))))
            (set-local-window-flags w f t)
            (let ((a (probe)))
              (set-local-window-flags w f nil)
              (let ((b (probe)))
                (set-local-window-flags w f :default)
                (list a b (probe))))))))
  => ((t nil) (nil t) (nil nil)))

(deftest set-local-window-flags-does-not-touch-the-default ()
  "局所の指定が**全体の既定を書き換えないこと。** 全体は
`get-window-flags` の側で、そこが動いたら局所ではない。"
  (let ((w (selected-window))
        (f ed::*window-flag-newline*))
    (window-flags-test-call-with-saved-local-flags w
      #'(lambda ()
          (let ((before (get-window-flags)))
            (set-local-window-flags w f t)
            (set-local-window-flags w f nil)
            (= before (get-window-flags))))))
  => t)

(deftest set-local-window-flags-accepts-a-buffer ()
  "バッファを渡した場合。**ウィンドウとは別の欄** (b_wflags) を使う。"
  (let ((buf (selected-buffer))
        (f ed::*window-flag-newline*))
    (window-flags-test-call-with-saved-local-flags buf
      #'(lambda ()
          (set-local-window-flags buf f t)
          (multiple-value-bind (on off)
              (get-local-window-flags buf)
            (list (and (logtest on f) t)
                  (and (logtest off f) t))))))
  => (t nil))

(deftest local-window-flags-beat-the-default ()
  "**局所の指定が実際に効くこと。** ここまでのテストは覚えた値を読み返して
いるだけなので、`Window::flags ()` を通って幾何に届いた結果も見る。

行番号は左に桁を取るので、**選択されているウィンドウで局所的に立てると
`window-columns` が狭くなる。** 以前は端末で何も起きなかった
(スタブが nil を返していた)。

見る対象に行番号を選んだのは、**両方のプラットフォームで幾何が動く**のが
これだからである (ルーラは端末では描いていないので動かない)。"
  (let ((w (selected-window))
        (f ed::*window-flag-line-number*))
    (window-flags-test-call-with-saved-local-flags w
      #'(lambda ()
          (set-local-window-flags w f nil)
          (let ((without (window-columns)))
            (set-local-window-flags w f t)
            (< (window-columns) without)))))
  => t)

(deftest mode-line-flag-changes-the-number-of-text-lines ()
  "**モード行の分が行数から引かれること。** 局所的に消すと `window-lines` が
1 増える。

端末側は `compute_geometry` と `window-lines` のどちらも **`- 1` の決め打ち**
だった (「ミニバッファでなければ 1 行引く」) ので、`toggle-mode-line` で
消しても値が動かなかった (issue #173)。

**`1` という数を見られるのは桁で数える側だけ。** Win32 の `window-lines` は
`w_clsize.cy / text_font.cell ().cy` = **ピクセルの割り算**で、モード行を
消して空くのは `modeline_param.m_height + 4` ピクセルなので、テキスト 1 行
ちょうどとは限らない (0 行にも 2 行にもなりうる)。
`abbreviate-display-string` と同じ形の食い違いである。"
  (if (featurep :unix)
      (let ((w (selected-window))
            (f ed::*window-flag-mode-line*))
        (window-flags-test-call-with-saved-local-flags w
          #'(lambda ()
              (set-local-window-flags w f t)
              (let ((with-it (window-lines)))
                (set-local-window-flags w f nil)
                (- (window-lines) with-it)))))
    1)
  => 1)
