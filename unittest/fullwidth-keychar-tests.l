;;; -*- Encoding: utf-8 -*-
;;; 全角 U+FF00..U+FF3E の文字と旧 function key の Char が数値で衝突する問題
;;; (issue #431)。char オブジェクトは lChar (kind + modifier + payload) を
;;; 保持するので、文字と機能キーを区別できる。
;;;
;;; 例: #\？ (U+FF1F) と #\F17 (CCF_F17 = 0xff1f) は旧 encoding では同じ値
;;; だったが、別の文字として扱われる。

(deftest fullwidth-char-code ()
  (char-code #\？)
  => #xFF1F)

;; プリンタが全角文字を function key 名にしないこと。
;; BMP 内の非 SJIS 文字は #\xNNNN 形式で出る (読み戻せる)。
(deftest fullwidth-char-print ()
  (prin1-to-string #\？)
  => "#\\xff1f")

;; function key の名前表示は維持する
(deftest function-char-print ()
  (prin1-to-string #\F17)
  => "#\\F17")

;; 文字と機能キーは eq で区別できる
;;   #\？ = U+FF1F = CCF_F17、#\＜ = U+FF1C = CCF_F14
(deftest fullwidth-vs-function-char-eq ()
  (list (eq #\？ #\F17) (eq #\＜ #\F14))
  => (nil nil))

;; char-code は互換のため旧 encoding の値を返す (どちらも 0xff1f)
(deftest fullwidth-char-code-compat ()
  (list (char-code #\？) (char-code #\F17))
  => (#xFF1F #xFF1F))

;; sparse keymap で全角文字にキーを割り当てられる
(deftest fullwidth-char-keymap ()
  (let ((m (make-sparse-keymap)))
    (define-key m #\？ 'fullwidth-query)
    (define-key m #\F17 'function-f17)
    (list (lookup-keymap m #\？) (lookup-keymap m #\F17)))
  => (fullwidth-query function-f17))

;; 全角文字だけに割り当てた場合、機能キー側は未定義のまま
(deftest fullwidth-char-keymap-isolated ()
  (let ((m (make-sparse-keymap)))
    (define-key m #\？ 'fullwidth-query)
    (list (lookup-keymap m #\？) (lookup-keymap m #\F17)))
  => (fullwidth-query nil))

;; 機能キーのキー割り当ては従来どおり効く
(deftest function-char-keymap ()
  (let ((m (make-sparse-keymap)))
    (define-key m #\F1 'function-f1)
    (lookup-keymap m #\F1))
  => function-f1)

;; set-meta-bit: 全角文字に M- を付けても meta function key にならない
(deftest set-meta-bit-fullwidth ()
  (char-code (set-meta-bit #\？ t))
  => #xFF1F)

;; set-meta-bit: ASCII の M- は従来どおり
(deftest set-meta-bit-ascii ()
  (char-code (set-meta-bit #\a t))
  => #xF861)

;; set-meta-bit: 機能キーの M- は往復できる
(deftest set-meta-bit-function-roundtrip ()
  (char-code (set-meta-bit (set-meta-bit #\F1 t) nil))
  => #xFF0F)
