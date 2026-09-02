;;; -*- Encoding: utf-8 -*-
;;; ターミナルエミュレータ (src/core/term.cc) の VT パーサ。
;;;
;;; Terminal は本来 ConPtyProcess が抱えていて process 無しには作れなかった
;;; ので、パーサには自動テストが一切なかった。SGR の色解釈を書き直したとき
;;; に si:*terminal-feed-for-test を足して塞いだ。
;;;
;;; si:*terminal-feed-for-test は (rows cols 文字列) を取り、各行の各セルを
;;; (code-point fg bg attrs) で返す。fg / bg の表現は
;;;   0                = 端末の既定色
;;;   #x1000000 + n    = xterm palette index n
;;;   #x2000000 + RGB  = 24bit
;;; attrs は TATTR_* のビット和 (bold=1 dim=2 underline=4 reverse=8
;;; invisible=#x10 italic=#x20 strike=#x40)。

(defun term-feed (rows cols string)
  (si:*terminal-feed-for-test rows cols string))

(defun term-cell (rows cols string row col)
  (nth col (nth row (term-feed rows cols string))))

;; 1 行目を文字列にして返す (末尾の空白は落とす)
(defun term-line-string (rows cols string &optional (row 0))
  (string-right-trim " "
    (map 'string #'(lambda (cell)
                     (let ((c (first cell)))
                       (if (zerop c) #\SPC (code-char c))))
         (nth row (term-feed rows cols string)))))

(defun esc (&rest args)
  (apply #'concatenate 'string (string #\ESC) args))


;;; ------------------------------------------------------------------
;;; 素の文字出力

(deftest terminal-plain-text ()
  (term-line-string 2 20 "hello")
  => "hello")

(deftest terminal-japanese ()
  ;; 全角は 2 セル使う。2 セル目は wide=2 で ch=0 になる。
  (let ((cells (nth 0 (term-feed 2 20 "日本"))))
    (list (first (nth 0 cells)) (first (nth 1 cells))
          (first (nth 2 cells)) (first (nth 3 cells))))
  => (26085 0 26412 0))

;; BMP 外。以前は w2i() を通していたので別の文字になり、さらに 16bit に
;; 切り詰めて豆腐になっていた。
(deftest terminal-non-bmp ()
  (first (term-cell 2 20 (string (code-char 128512)) 0 0))
  => 128512)

(deftest terminal-non-bmp-is-wide ()
  ;; 絵文字は全角なので 2 セル目が継続セルになる
  (let ((cells (nth 0 (term-feed 2 20 (string (code-char 128512))))))
    (list (first (nth 0 cells)) (first (nth 1 cells))))
  => (128512 0))

(deftest terminal-newline ()
  (list (term-line-string 3 20 (concat "one" (string #\LFD) "two") 0)
        (term-line-string 3 20 (concat "one" (string #\LFD) "two") 1))
  => ("one" "   two"))


;;; ------------------------------------------------------------------
;;; SGR: 基本 16 色

(deftest terminal-sgr-basic-fg ()
  ;; ESC[31m → palette index 1 (赤)
  (let ((cell (term-cell 2 20 (esc "[31mX") 0 0)))
    (list (second cell) (third cell)))
  => (#x1000001 0))

(deftest terminal-sgr-basic-bg ()
  (let ((cell (term-cell 2 20 (esc "[44mX") 0 0)))
    (list (second cell) (third cell)))
  => (0 #x1000004))

(deftest terminal-sgr-bright-fg ()
  ;; ESC[91m → index 9
  (second (term-cell 2 20 (esc "[91mX") 0 0))
  => #x1000009)

(deftest terminal-sgr-reset ()
  (let ((cell (term-cell 2 20 (esc "[31;44;1m" (esc "[0mX")) 0 0)))
    (list (second cell) (third cell) (fourth cell)))
  => (0 0 0))

(deftest terminal-sgr-default-fg-bg ()
  (let ((cell (term-cell 2 20 (esc "[31;44m" (esc "[39;49mX")) 0 0)))
    (list (second cell) (third cell)))
  => (0 0))


;;; ------------------------------------------------------------------
;;; SGR: 256 色

(deftest terminal-sgr-256-fg ()
  (second (term-cell 2 20 (esc "[38;5;208mX") 0 0))
  => #x10000D0)                         ; 208

(deftest terminal-sgr-256-bg ()
  (third (term-cell 2 20 (esc "[48;5;236mX") 0 0))
  => #x10000EC)                         ; 236

;; 239 以上。以前は uint8_t を溢れて別の色になっていた。
(deftest terminal-sgr-256-high-index ()
  (list (second (term-cell 2 20 (esc "[38;5;239mX") 0 0))
        (second (term-cell 2 20 (esc "[38;5;255mX") 0 0)))
  => (#x10000EF #x10000FF))

(deftest terminal-sgr-256-both ()
  (let ((cell (term-cell 2 20 (esc "[38;5;208;48;5;236mX") 0 0)))
    (list (second cell) (third cell)))
  => (#x10000D0 #x10000EC))


;;; ------------------------------------------------------------------
;;; SGR: 24bit 色
;;;
;;; 以前は 38;2;... を認識せず、しかもパラメータを食い残していた。続く
;;; 2, r, g, b が SGR コードとして再解釈されるので、色が付かないどころか
;;; DIM が立ち背景色が変わっていた。カラフルなテーマが再現されない主因。

(deftest terminal-sgr-truecolor-fg ()
  (second (term-cell 2 20 (esc "[38;2;255;100;50mX") 0 0))
  => #x2FF6432)                         ; RGB(255,100,50)

(deftest terminal-sgr-truecolor-bg ()
  (third (term-cell 2 20 (esc "[48;2;40;44;52mX") 0 0))
  => #x2282C34)                         ; RGB(40,44,52)

;; 属性を壊さないこと。以前は 2 → DIM、100 → 背景に化けていた。
(deftest terminal-sgr-truecolor-does-not-corrupt-attrs ()
  (let ((cell (term-cell 2 20 (esc "[38;2;255;100;50mX") 0 0)))
    (list (second cell) (third cell) (fourth cell)))
  => (#x2FF6432 0 0))

;; 後続のパラメータが正しく読まれること
(deftest terminal-sgr-truecolor-then-attr ()
  (let ((cell (term-cell 2 20 (esc "[38;2;0;255;0;1mX") 0 0)))
    (list (second cell) (fourth cell)))
  => (#x200FF00 1))

(deftest terminal-sgr-truecolor-fg-and-bg ()
  (let ((cell (term-cell 2 20 (esc "[38;2;1;2;3;48;2;4;5;6mX") 0 0)))
    (list (second cell) (third cell)))
  => (#x2010203 #x2040506))

;; T.416 の ':' 形式。以前は ':' が intermediate 扱いで区切りにならず、
;; 38:2:255:0:0 が 1 個の巨大な数値に潰れていた。
(deftest terminal-sgr-truecolor-colon ()
  (second (term-cell 2 20 (esc "[38:2::255:100:50mX") 0 0))
  => #x2FF6432)

(deftest terminal-sgr-truecolor-colon-no-colorspace ()
  (second (term-cell 2 20 (esc "[38:2:255:100:50mX") 0 0))
  => #x2FF6432)

(deftest terminal-sgr-256-colon ()
  (second (term-cell 2 20 (esc "[38:5:208mX") 0 0))
  => #x10000D0)


;;; ------------------------------------------------------------------
;;; SGR: 属性

(deftest terminal-sgr-attrs ()
  (list (fourth (term-cell 2 20 (esc "[1mX") 0 0))     ; bold
        (fourth (term-cell 2 20 (esc "[2mX") 0 0))     ; dim
        (fourth (term-cell 2 20 (esc "[3mX") 0 0))     ; italic
        (fourth (term-cell 2 20 (esc "[4mX") 0 0))     ; underline
        (fourth (term-cell 2 20 (esc "[7mX") 0 0))     ; reverse
        (fourth (term-cell 2 20 (esc "[9mX") 0 0)))    ; strike
  => (1 2 #x20 4 8 #x40))

(deftest terminal-sgr-attr-off ()
  (list (fourth (term-cell 2 20 (esc "[1m" (esc "[22mX")) 0 0))
        (fourth (term-cell 2 20 (esc "[3m" (esc "[23mX")) 0 0))
        (fourth (term-cell 2 20 (esc "[4m" (esc "[24mX")) 0 0))
        (fourth (term-cell 2 20 (esc "[9m" (esc "[29mX")) 0 0)))
  => (0 0 0 0))

;; 点滅は属性を持たないが、パラメータとして食っておかないと後続が
;; 色指定に化ける。
(deftest terminal-sgr-blink-is-swallowed ()
  (let ((cell (term-cell 2 20 (esc "[5;31mX") 0 0)))
    (list (second cell) (fourth cell)))
  => (#x1000001 0))


;;; ------------------------------------------------------------------
;;; カーソル移動と消去

(deftest terminal-cup ()
  ;; ESC[2;3H で 2 行 3 桁目へ
  (term-line-string 3 20 (concat (esc "[2;3H") "X") 1)
  => "  X")

(deftest terminal-cuf-cub ()
  ;; "ab" で桁 2 → ESC[2C で桁 4 → "c" を置いて桁 5 → ESC[4D で桁 1
  ;; → "Z" が 'b' を上書きする
  (term-line-string 2 20 (concat "ab" (esc "[2C") "c" (esc "[4D") "Z"))
  => "aZ  c")

;;; **保存位置は画面ごとに 1 つ。** alternate 画面の中で DECSC しても、
;;; primary 側の保存位置は壊れない。1 つしか無かったときはここが壊れていた。
(deftest terminal-mode-1049-save-survives-decsc-in-alt ()
  (let ((s (concat (esc "[2;3H") (esc "[?1049h")
                   (esc "[3;5H") (esc "7")
                   (esc "[?1049l") "P")))
    (term-line-string 4 10 s 1))
  => "  P")

;;; **1049 は DECSC と同じ所へ保存する** (xterm ctlseqs)。だから 1049h の
;;; あとの DECRC は「1049h が保存した位置」へ戻る -- DECSC で保存した古い
;;; 位置ではない。**1049 専用の保存位置を作るとここが変わる**ので、境界を
;;; テストで押さえる。
;;;
;;;   ESC[1;1H  ESC 7        (0,0) を DECSC で保存
;;;   ESC[3;4H  ESC[?1049h   (2,3) を 1049 で保存 -> alt へ
;;;   ESC[?1049l             primary へ戻り (2,3) を復元
;;;   ESC 8                  DECRC -> (2,3) に戻る (0,0) ではない
;;;   "R"
(deftest terminal-mode-1049-shares-the-decsc-slot ()
  (let ((s (concat (esc "[1;1H") (esc "7")
                   (esc "[3;4H") (esc "[?1049h")
                   (esc "[?1049l") (esc "8") "R")))
    (list (term-line-string 4 10 s 0)
          (term-line-string 4 10 s 2)))
  => ("" "   R"))

(deftest terminal-decsc-restores-attributes ()
  (second (term-cell 4 10
                     (concat (esc "[31m") (esc "7")
                             (esc "[32m") (esc "8") "X")
                     0 0))
  => #x1000001)

(deftest terminal-decsc-restores-origin-mode ()
  (let ((s (concat (esc "[2;4r") (esc "[?6h")
                   (esc "[2;2H") (esc "7")
                   (esc "[?6l") (esc "8")
                   (esc "[1;1H") "O")))
    (list (term-line-string 5 10 s 0)
          (term-line-string 5 10 s 1)))
  => ("" "O"))

(deftest terminal-el-to-eol ()
  ;; 行頭に戻して ESC[0K で右を消す
  (term-line-string 2 20 (concat "abcdef" (esc "[1;4H") (esc "[0K")))
  => "abc")

(deftest terminal-ed-all ()
  (term-line-string 3 20 (concat "abc" (esc "[2J")))
  => "")

(deftest terminal-ech ()
  (term-line-string 2 20 (concat "abcdef" (esc "[1;2H") (esc "[3X")))
  => "a   ef")

(deftest terminal-ich-dch ()
  (list (term-line-string 2 20 (concat "abc" (esc "[1;2H") (esc "[2@")))
        (term-line-string 2 20 (concat "abcdef" (esc "[1;2H") (esc "[2P"))))
  => ("a  bc" "adef"))

(deftest terminal-cr-overwrite ()
  (term-line-string 2 20 (concat "abcdef" (string #\RET) "XY"))
  => "XYcdef")

(deftest terminal-backspace ()
  (term-line-string 2 20 (concat "abc" (string #\Backspace) "Z"))
  => "abZ")

(deftest terminal-tab ()
  ;; タブ停止は 8 桁ごと
  (term-line-string 2 20 (concat "a" (string #\TAB) "b"))
  => "a       b")


;;; ------------------------------------------------------------------
;;; スクロール

(deftest terminal-scroll-on-overflow ()
  ;; 2 行の端末に 3 行入れると 1 行目が押し出される
  (let ((s (concat "one" (string #\LFD) "two" (string #\LFD) "three")))
    (list (term-line-string 2 20 s 0) (term-line-string 2 20 s 1)))
  => ("   two" "      three"))

(deftest terminal-ri-scroll-down ()
  ;; ESC M は 1 行目にいるとき下方向にスクロールする
  (let ((s (concat "one" (esc "[1;1H") (esc "M") "top")))
    (list (term-line-string 3 20 s 0) (term-line-string 3 20 s 1)))
  => ("top" "one"))


;;; ------------------------------------------------------------------
;;; 折返し

(deftest terminal-wrap ()
  (let ((s "abcdef"))
    (list (term-line-string 3 4 s 0) (term-line-string 3 4 s 1)))
  => ("abcd" "ef"))

(deftest terminal-wrap-off ()
  ;; ESC[?7l で折返しを切ると右端で止まる
  (let ((s (concat (esc "[?7l") "abcdef")))
    (list (term-line-string 3 4 s 0) (term-line-string 3 4 s 1)))
  => ("abcf" ""))


;;; ------------------------------------------------------------------
;;; 色が属性と一緒に残ること (実際のプロンプトの形)

(deftest terminal-sgr-carries-over-cells ()
  ;; 色を付けた 3 文字すべてに色が乗る
  (let ((cells (nth 0 (term-feed 2 20 (esc "[38;2;10;20;30mabc")))))
    (mapcar #'second (subseq cells 0 4)))
  => (#x20A141E #x20A141E #x20A141E 0))


;;; ------------------------------------------------------------------
;;; 文字幅: Ambiguous はターミナルでは半角
;;;
;;; エディタ本文は CJK 流儀で East Asian Ambiguous を 2 桁にしている。
;;; ターミナルでそれをやると向こう側のアプリと食い違う。TUI は
;;; npm string-width / wcwidth を使って 1 桁で数えるので、罫線や
;;; 幾何図形が出るたびに 1 桁ずれ、表やサイドバーが崩れた。

;; 罫線 (U+2500-259F)。表の枠に使われる。
(deftest terminal-box-drawing-is-narrow ()
  ;; ─ を 3 個並べたら 3 セル。以前は全角扱いで 6 セル使っていた。
  (let ((cells (nth 0 (term-feed 2 20 "───X"))))
    (mapcar #'first (subseq cells 0 4)))
  => (#x2500 #x2500 #x2500 88))

;; 幾何図形 (U+25A0-25FF)。サイドバーの ● ○ など。
(deftest terminal-geometric-is-narrow ()
  (let ((cells (nth 0 (term-feed 2 20 "●○X"))))
    (mapcar #'first (subseq cells 0 3)))
  => (#x25CF #x25CB 88))

;; 矢印 (U+2190-21FF)
(deftest terminal-arrows-are-narrow ()
  (let ((cells (nth 0 (term-feed 2 20 "↓→X"))))
    (mapcar #'first (subseq cells 0 3)))
  => (#x2193 #x2192 88))

;; 一方で本物の全角は全角のまま
(deftest terminal-cjk-still-wide ()
  (let ((cells (nth 0 (term-feed 2 20 "日X"))))
    (mapcar #'first (subseq cells 0 3)))
  => (26085 0 88))

(deftest terminal-fullwidth-still-wide ()
  ;; Ａ (U+FF21 全角 A)
  (let ((cells (nth 0 (term-feed 2 20 "ＡX"))))
    (mapcar #'first (subseq cells 0 3)))
  => (#xFF21 0 88))

(deftest terminal-emoji-still-wide ()
  (let ((cells (nth 0 (term-feed 2 20 (concat (string (code-char 128512)) "X")))))
    (mapcar #'first (subseq cells 0 3)))
  => (128512 0 88))

;; 罫線で表を書いても桁がずれないこと (実機で崩れていた形)
(deftest terminal-table-alignment ()
  (term-line-string 2 20 "┌──┬──┐")
  => "┌──┬──┐")

;; エディタ本文側 (char-columns) は CJK 流儀のまま = 2 桁。
;; ターミナルとは意図的に違う。
(deftest terminal-editor-keeps-ambiguous-wide ()
  (list (char-columns (code-char #x2500)) (char-columns (code-char #x25CF))
        (char-columns (code-char #x2193)) (char-columns #\A))
  => (2 2 2 1))


;;; ------------------------------------------------------------------
;;; キー送出
;;;
;;; decode_keys は lc_from_ccf を通した新 lChar encoding
;;; (LCKEY_UP = LCKIND_FNKEY | 5 = #x200005) を返すのに、
;;; terminal_key_to_bytes は旧 Char encoding (CCF_UP = #xff05) と比べていた。
;;; 一致しないので矢印・Home/End・F キー・PageUp/Down が全部黙って捨てられ、
;;; pty には何も届いていなかった。Claude Code の選択肢を上下キーで選べ
;;; なかったのがこれ。process が無いと呼べずテストが書けなかったので、
;;; si:*terminal-key-for-test を足して塞いだ。

(defconstant *lckind-fnkey* #x200000)
(defconstant *lcmod-shift*  #x01000000)
(defconstant *lcmod-ctrl*   #x02000000)
(defconstant *lcmod-alt*    #x04000000)

(defun term-key (key &optional setup)
  (si:*terminal-key-for-test key setup))

(defun esc-bytes (&rest args)
  ;; 期待値を書きやすくする: 27 とあとは文字コード
  (mapcar #'(lambda (x) (if (characterp x) (char-code x) x)) args))

;; 矢印。修飾なし・DECCKM オフなら CSI 終端 1 文字。
(deftest terminal-key-arrows ()
  (list (term-key (+ *lckind-fnkey* 5))    ; UP
        (term-key (+ *lckind-fnkey* 7))    ; DOWN
        (term-key (+ *lckind-fnkey* 6))    ; RIGHT
        (term-key (+ *lckind-fnkey* 4)))   ; LEFT
  => ((27 91 65) (27 91 66) (27 91 67) (27 91 68)))

;; application cursor keys (DECCKM) を立てると ESC O_ になる
(deftest terminal-key-arrows-app-mode ()
  (term-key (+ *lckind-fnkey* 5) (concat (string #\ESC) "[?1h"))
  => (27 79 65))

;; Home / End
(deftest terminal-key-home-end ()
  (list (term-key (+ *lckind-fnkey* 3))    ; HOME
        (term-key (+ *lckind-fnkey* 2)))   ; END
  => ((27 91 72) (27 91 70)))

;; CSI n ~ 形式
(deftest terminal-key-insert-delete-pages ()
  (list (term-key (+ *lckind-fnkey* #x0C))  ; INSERT -> ESC[2~
        (term-key (+ *lckind-fnkey* #x0D))  ; DELETE -> ESC[3~
        (term-key (+ *lckind-fnkey* #x00))  ; PRIOR  -> ESC[5~
        (term-key (+ *lckind-fnkey* #x01))) ; NEXT   -> ESC[6~
  => ((27 91 50 126) (27 91 51 126) (27 91 53 126) (27 91 54 126)))

;; F1-F4 は SS3、F5 以降は CSI n ~
(deftest terminal-key-function-keys ()
  (list (term-key (+ *lckind-fnkey* #x0F))  ; F1 -> ESC O P
        (term-key (+ *lckind-fnkey* #x12))  ; F4 -> ESC O S
        (term-key (+ *lckind-fnkey* #x13))  ; F5 -> ESC[15~
        (term-key (+ *lckind-fnkey* #x1A))) ; F12 -> ESC[24~
  => ((27 79 80) (27 79 83) (27 91 49 53 126) (27 91 50 52 126)))

;; 修飾キー付き。xterm の番号は Shift=1 Alt=2 Ctrl=4 を足して +1。
(deftest terminal-key-modified-arrows ()
  (list (term-key (+ *lckind-fnkey* 5 *lcmod-ctrl*))    ; Ctrl+Up  -> ESC[1;5A
        (term-key (+ *lckind-fnkey* 5 *lcmod-shift*)))  ; Shift+Up -> ESC[1;2A
  => ((27 91 49 59 53 65) (27 91 49 59 50 65)))

;; 通常文字はそのまま。日本語は UTF-8。
(deftest terminal-key-plain-chars ()
  (list (term-key 65)          ; A
        (term-key #x3042))     ; あ -> E3 81 82
  => ((65) (227 129 130)))

;; BMP 外は 4 バイトの UTF-8
(deftest terminal-key-non-bmp ()
  (term-key 128512)
  => (240 159 152 128))

;; Shift+Tab は CBT (ESC[Z)。Claude Code の「shift+tab to cycle」がこれ。
(deftest terminal-key-shift-tab ()
  (list (term-key (+ 9 *lcmod-shift*))
        (term-key 9))
  => ((27 91 90) (9)))

;; Alt 付きは ESC を前置する
(deftest terminal-key-alt-char ()
  (term-key (+ 65 *lcmod-alt*))
  => (27 65))

;;; ------------------------------------------------------------
;;; Lisp の char で渡す経路
;;;
;;; terminal-send-next-key は (read-char *keyboard*) の結果をそのまま
;;; si:terminal-send-key に渡す。Lisp の char は旧 Char encoding なので
;;; #\Up は CCF_UP = #xff05 であり、lChar としては LCHAR_KIND が CHAR に
;;; 見える。昇格を忘れると機能キーではなく U+FF05 (全角パーセント) の
;;; UTF-8 が pty へ流れるので、そこを固定する。

(deftest terminal-key-from-char-fnkeys ()
  (list (term-key #\Up)
        (term-key #\Down)
        (term-key #\Home)
        (term-key #\F1)
        (term-key #\PageUp))
  => ((27 91 65) (27 91 66) (27 91 72) (27 79 80) (27 91 53 126)))

(deftest terminal-key-from-char-modified-fnkeys ()
  (list (term-key #\C-Up)
        (term-key #\S-Up))
  => ((27 91 49 59 53 65) (27 91 49 59 50 65)))

;; 普通の文字と制御文字はそのまま。C-v は 0x16 で、素通しの主な用途がこれ
;; (vim の page down)。
(deftest terminal-key-from-char-plain ()
  (list (term-key #\A)
        (term-key #\C-v)
        (term-key #\あ))
  => ((65) (22) (227 129 130)))

;; BMP 外の char は Char (16bit) に落とすと #xF600 = CCF_META とぶつかる。
;; code point のまま渡さなければならない。
(deftest terminal-key-from-char-non-bmp ()
  (term-key (code-char 128512))
  => (240 159 152 128))
