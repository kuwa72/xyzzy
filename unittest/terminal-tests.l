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
