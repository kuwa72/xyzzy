;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/color-theme.l の暗い/明るい切り替えのテスト。
;;;
;;; 判定は名前ではなく背景色の明るさで行う。名前に Dark/Light と入って
;;; いないテーマ (Dracula, Nord, Molokai ...) が多数あるので、名前を見る
;;; 方法では大半を判定できない。そこを外していないかを見る。

(require "color-theme")

(deftest color-theme-dark-p-by-background ()
  "背景色の明るさで判定していること。名前に Dark/Light が無いものも含む"
  (values (ed::color-theme-dark-p "Solarized Dark")
	  (ed::color-theme-dark-p "Solarized Light")
	  (ed::color-theme-dark-p "Dracula")
	  (ed::color-theme-dark-p "Nord")
	  (ed::color-theme-dark-p "Molokai")
	  (ed::color-theme-dark-p "One Light")
	  (ed::color-theme-dark-p "Catppuccin Latte")
	  ;; 無いテーマは nil
	  (ed::color-theme-dark-p "No Such Theme"))
  => t
  => nil
  => t
  => t
  => t
  => nil
  => nil
  => nil)

(deftest color-theme-swap-dark-light ()
  "\" Dark\" と \" Light\" を入れ替えること。どちらでもなければ nil"
  (values (ed::color-theme-swap-dark-light "Solarized Dark")
	  (ed::color-theme-swap-dark-light "Solarized Light")
	  (ed::color-theme-swap-dark-light "Dracula"))
  => "Solarized Light"
  => "Solarized Dark"
  => nil)

(deftest color-theme-counterpart ()
  "相方が引けること。名前から導ける組と、表に書いた組の両方"
  (values (ed::color-theme-counterpart "Solarized Dark")
	  (ed::color-theme-counterpart "Gruvbox Light")
	  ;; 表に書いた組 (片方向しか書いていないので逆向きも引けること)
	  (ed::color-theme-counterpart "One Dark")
	  (ed::color-theme-counterpart "One Light")
	  ;; 相方の無いテーマは nil
	  (ed::color-theme-counterpart "Dracula"))
  => "Solarized Light"
  => "Gruvbox Dark"
  => "One Light"
  => "One Dark"
  => nil)

(deftest color-theme-counterpart-must-exist ()
  "名前を機械的に入れ替えた結果が実在しないなら nil を返すこと
(\"Tokyo Night Light\" のような存在しないテーマへ飛ばさない)"
  (let ((swapped (ed::color-theme-swap-dark-light "Everforest Dark")))
    (values swapped
	    (and (ed::color-theme-colors swapped) t)
	    (ed::color-theme-counterpart "Everforest Dark")))
  => "Everforest Light"
  => nil
  => nil)

(deftest color-theme-every-theme-is-classified ()
  "全テーマについて色が引けること (表とデータのずれを検出する)"
  (let ((bad nil))
    (dolist (entry ed::*color-theme-table*)
      (unless (ed::color-theme-colors (car entry))
	(push (car entry) bad)))
    bad)
  => nil)

(deftest color-theme-counterpart-alist-is-valid ()
  "*color-theme-counterpart-alist* に実在しないテーマ名が無いこと"
  (let ((bad nil))
    (dolist (pair ed::*color-theme-counterpart-alist*)
      (unless (ed::color-theme-colors (car pair)) (push (car pair) bad))
      (unless (ed::color-theme-colors (cdr pair)) (push (cdr pair) bad)))
    bad)
  => nil)

(deftest color-theme-counterpart-crosses-dark-light ()
  "相方が本当に明暗の逆側であること (表の書き間違いを検出する)"
  (let ((bad nil))
    (dolist (entry ed::*color-theme-table*)
      (let* ((name (car entry))
	     (other (ed::color-theme-counterpart name)))
	(when (and other
		   (eq (not (ed::color-theme-dark-p name))
		       (not (ed::color-theme-dark-p other))))
	  (push (list name other) bad))))
    bad)
  => nil)

(deftest color-theme-defaults-exist ()
  "既定の暗い/明るいテーマが実在し、明暗が逆であること"
  (values (and (ed::color-theme-colors ed::*color-theme-default-dark*) t)
	  (and (ed::color-theme-colors ed::*color-theme-default-light*) t)
	  (ed::color-theme-dark-p ed::*color-theme-default-dark*)
	  (ed::color-theme-dark-p ed::*color-theme-default-light*))
  => t
  => t
  => t
  => nil)

(deftest toggle-color-theme-dark-light ()
  "切り替えると明暗が反対のテーマになること"
  (let ((ed::*current-color-theme* nil))
    (unwind-protect
	(let* ((a (progn (setq ed::*current-color-theme* "Solarized Dark")
			 (ed::color-theme-counterpart "Solarized Dark")))
	       ;; テーマを当てていない状態からは暗い方へ
	       (b (progn (setq ed::*current-color-theme* nil)
			 (or (ed::color-theme-counterpart nil)
			     ed::*color-theme-default-dark*))))
	  (values a b))
      (setq ed::*current-color-theme* nil)))
  => "Solarized Light"
  => "One Dark")

(deftest color-theme-toggle-keys ()
  "Leader t T / Leader t C に割り当てられていること"
  (values (lookup-keymap ed::*leader-toggle-map* #\T)
	  (lookup-keymap ed::*leader-toggle-map* #\C))
  => toggle-color-theme-dark-light
  => select-color-theme)
