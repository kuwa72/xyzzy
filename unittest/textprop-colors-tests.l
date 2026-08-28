;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; 「文字1〜15」(set-text-attribute の :foreground / :background が指す 16 色
;;; 表) をカラーテーマに合わせる処理のテスト。issue #98。
;;;
;;; **見ているのは「どのテーマでも読める色になること」である。** テーマごとに
;;; 15 色を書き並べるのではなく標準色から導いているので、30 個のうち 1 つでも
;;; 背景に沈む色が出れば、その番号を使っている色付け (tree-sitter、calendar の
;;; 土日、diff、hideif、ispell) がそのテーマで読めなくなる。テーマを 1 つずつ
;;; 目で確かめるわけにはいかないので、全テーマ x 15 色を機械で見る。

(require "color-theme")

(defun textprop-test-low-contrast (name)
  "NAME のテーマで、文字色が背景に対して沈んでいる番号を集める。"
  (let* ((colors (ed::color-theme-colors name))
	 (bg (aref colors 1))
	 (table (ed::color-theme-textprop-foreground colors))
	 (bad nil))
    (dotimes (i 15)
      (let ((n (1+ i)))
	(when (< (ed::%color-theme-contrast-ratio (aref table n) bg)
		 ed::*color-theme-textprop-contrast-ratio*)
	  (push n bad))))
    (nreverse bad)))

(deftest textprop-colors-are-readable-in-every-theme ()
  "全テーマの文字1〜15 が背景に対して 4.5:1 を保つこと。

**ここが落ちたら、そのテーマでその番号の色が読めない。** 白 (黒) まで
寄せても目標に届かない背景があれば、導出は諦めてそのまま返すので、
テーマを増やしたときにここで分かる。"
  (let ((bad nil))
    (dolist (theme ed::*color-theme-table*)
      (let ((entries (textprop-test-low-contrast (car theme))))
	(when entries
	  (push (cons (car theme) entries) bad))))
    (nreverse bad))
  => nil)

(defun textprop-test-hue-broken (name)
  "NAME のテーマで、単色 (赤・緑・青) の主成分が主でなくなった番号を集める。"
  (let ((table (ed::color-theme-textprop-foreground
		(ed::color-theme-colors name)))
	(bad nil))
    (dolist (entry '((1 . 0) (2 . 1) (4 . 2) (9 . 0) (10 . 1) (12 . 2)))
      (let* ((c (aref table (car entry)))
	     (parts (list (logand c #xff)
			  (logand (ash c -8) #xff)
			  (logand (ash c -16) #xff)))
	     (mine (nth (cdr entry) parts))
	     (others nil))
	(dotimes (k 3)
	  (unless (eql k (cdr entry))
	    (push (nth k parts) others)))
	(unless (every #'(lambda (p) (> mine p)) others)
	  (push (car entry) bad))))
    (nreverse bad)))

(deftest textprop-colors-keep-their-hue ()
  "赤は赤、緑は緑、青は青のままであること。

番号の意味を当てにしているコードがある (calendar は日曜日に 1 の赤、
土曜日に 4 の青)。明るさだけを直す実装なので、色みが動いたら実装が
変わってしまっている。"
  (let ((bad nil))
    (dolist (theme ed::*color-theme-table*)
      (let ((entries (textprop-test-hue-broken (car theme))))
	(when entries
	  (push (cons (car theme) entries) bad))))
    (nreverse bad))
  => nil)

(deftest textprop-colors-lift-black-on-a-dark-theme ()
  "暗いテーマでは黒 (8) が灰色まで持ち上がること。

標準色の 8 は真っ黒で、暗い背景では見えない。**そこが直っていることを
具体的な値で見る。** 上のコントラスト比のテストは実装と同じ式を使うので、
実装が「白へ振り切る」ような直し方をしていても通ってしまう。"
  (let* ((table (ed::color-theme-textprop-foreground
		 (ed::color-theme-colors "One Dark")))
	 (black (aref table 8)))
    (values (> (logand black #xff) 0)
	    ;; 灰色のまま (色みが付いていない)
	    (eql (logand black #xff) (logand (ash black -8) #xff))
	    ;; 白へ振り切っていない
	    (< (logand black #xff) 220)))
  => t
  => t
  => t)

(deftest textprop-colors-darken-yellow-on-a-light-theme ()
  "明るいテーマでは、黄 (3) が読める暗さまで落ちること。

**明るい背景がこの直しの難しい側である。** 白地の #ffff00 は輝度の単純な
加重平均で見ると白との差が小さくないので、そういう式では『足りている』と
判定されて手つかずのまま残る。"
  (let* ((colors (ed::color-theme-colors "One Light"))
	 (yellow (aref (ed::color-theme-textprop-foreground colors) 3)))
    (values (>= (ed::%color-theme-contrast-ratio yellow (aref colors 1)) 45)
	    ;; 黄色のまま (赤と緑が残り、青が乗っていない)
	    (eql (logand yellow #xff) (logand (ash yellow -8) #xff))
	    (eql (logand (ash yellow -16) #xff) 0)))
  => t
  => t
  => t)

(deftest textprop-background-colors-stay-quiet ()
  "背景色表はテーマの背景に寄せること。

`:background' で敷く色なので、文字色と同じに扱ってはいけない。純色の赤や
黄をそのまま敷くと上に載る文字が読めなくなる。背景とのコントラスト比が
小さいこと (3:1 未満) で「静か」を見る。それ以上あると、地色ではなく
色の塊として読める。"
  (let* ((colors (ed::color-theme-colors "One Dark"))
	 (bg (aref colors 1))
	 (table (ed::color-theme-textprop-background colors))
	 (loud nil))
    (dotimes (i 15)
      (let ((n (1+ i)))
	(when (>= (ed::%color-theme-contrast-ratio (aref table n) bg) 30)
	  (push n loud))))
    (nreverse loud))
  => nil)

(deftest textprop-colors-mix-is-a-linear-blend ()
  "%color-theme-mix が成分ごとの線形補間であること"
  (values (ed::%color-theme-mix #x000000 #xffffff 0)
	  (ed::%color-theme-mix #x000000 #xffffff 100)
	  (ed::%color-theme-mix #x000000 #xffffff 50))
  => #x000000
  => #xffffff
  => #x7f7f7f)

(deftest textprop-colors-relative-luminance ()
  "相対輝度が成分の 2 乗の加重和 (0〜1000) であること。

黄色が白に近い値にならないことが要点。COLORREF は 0x00BBGGRR なので、
下位バイトが赤である。"
  (values (ed::%color-theme-relative-luminance #x000000)
	  (ed::%color-theme-relative-luminance #xffffff)
	  ;; 赤
	  (ed::%color-theme-relative-luminance #x0000ff)
	  ;; 緑
	  (ed::%color-theme-relative-luminance #x00ff00)
	  ;; 黄 (赤 + 緑)
	  (ed::%color-theme-relative-luminance #x00ffff))
  => 0
  => 1000
  => 213
  => 715
  => 928)

(deftest textprop-colors-contrast-ratio ()
  "コントラスト比が WCAG の式 (10 倍した整数) であること。
白と黒は 21:1、同じ色どうしは 1:1。"
  (values (ed::%color-theme-contrast-ratio #xffffff #x000000)
	  (ed::%color-theme-contrast-ratio #x000000 #xffffff)
	  (ed::%color-theme-contrast-ratio #x808080 #x808080))
  => 210
  => 210
  => 10)

;;; ここから下は C++ 側の入口 (set-text-attribute-colors) を見る。

(deftest set-text-attribute-colors-round-trip ()
  "設定した色がそのまま読めること。番号 0 は使われないので触らないこと。

**設定は xyzzy.ini へ書かない。** テーマによる上書きはユーザーの表示色設定
ではないので、保存してしまうとテーマを解除しても戻らなくなる。ini を見る
テストは書けないが、nil で元へ戻せること (下のテスト) がその裏になる。"
  (let ((saved (get-text-attribute-colors))
	(wanted (make-vector 16 :initial-element 0)))
    (dotimes (i 16)
      (setf (aref wanted i) (* i #x010101)))
    (unwind-protect
	(progn
	  (set-text-attribute-colors wanted t)
	  (let ((got (get-text-attribute-colors))
		(bad nil))
	    (dotimes (i 15)
	      (let ((n (1+ i)))
		(unless (eql (aref got n) (aref wanted n))
		  (push n bad))))
	    (nreverse bad)))
      (set-text-attribute-colors saved t)))
  => nil)

(deftest set-text-attribute-colors-t-leaves-the-table-alone ()
  "t は「そのまま」。fg だけ変えたいときに bg が巻き添えにならないこと"
  (let ((saved-fg (get-text-attribute-colors))
	(saved-bg (get-text-attribute-colors t))
	(wanted (make-vector 16 :initial-element #x123456)))
    (unwind-protect
	(progn
	  (set-text-attribute-colors wanted t)
	  (equalp (get-text-attribute-colors t) saved-bg))
      (set-text-attribute-colors saved-fg saved-bg)))
  => t)

(deftest set-text-attribute-colors-nil-restores-the-saved-setting ()
  "nil は「表示色の設定として保存されている値へ戻す」"
  (let ((saved (get-text-attribute-colors))
	(wanted (make-vector 16 :initial-element #x654321)))
    (unwind-protect
	(progn
	  (set-text-attribute-colors wanted t)
	  (set-text-attribute-colors nil t)
	  ;; 戻した後は、上書きした値とは違う値になっていること
	  (notany #'(lambda (n) (eql (aref (get-text-attribute-colors) n) #x654321))
		  '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)))
      (set-text-attribute-colors saved t)))
  => t)
