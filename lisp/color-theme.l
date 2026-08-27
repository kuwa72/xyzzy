;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "color-theme")

(in-package "editor")

(export '(*color-theme-table* *current-color-theme*
	  set-color-theme clear-color-theme select-color-theme
	  toggle-color-theme-dark-light color-theme-dark-p
	  *color-theme-counterpart-alist*
	  *color-theme-default-dark* *color-theme-default-light*))

;;; 表示色をまとめて切り替えるカラーテーマ。
;;;
;;; xyzzy の「表示色」は色ごとの個別設定 (ツール→ローカル設定→表示色) しか
;;; 無く、公開されている配色 (Solarized, Molokai など) を一括で当てはめる
;;; 手段が無かった。ここでは `set-buffer-colors' (USER_DEFINABLE_COLORS,
;;; src/core/Buffer.h) が受け取るベクタを丸ごと用意しておき、全バッファと
;;; 新規バッファに適用することでテーマ切り替えを実現する。
;;;
;;; ベクタの並びは wcolor_index_name テーブル (src/frontend/win32/Window.cc)
;;; の定義順そのもの:
;;;   0 文字色       1 背景色       2 制御文字     3 選択文字色
;;;   4 選択背景色   5 キーワード1  6 キーワード2  7 キーワード3
;;;   8 文字列       9 コメント     10 タグ        11 行カーソル
;;;   12 キャレット  13 IMEキャレット 14 行番号    15 ニセ反転色
;;;   16 モード行文字色 17 モード行背景色

(defun %rgb-to-colorref (rgb)
  "0xRRGGBB (配色表でふつうに使われる並び) を Windows の COLORREF
   (0x00BBGGRR, RGB マクロと同じ並び) に変換する。set-buffer-colors が
   受け取るのは後者なので、これを通さずに書いた 0xRRGGBB の値を渡すと
   赤と青が入れ替わった色になる。"
  (logior (logand (ash rgb -16) #xff)
	  (ash (logand (ash rgb -8) #xff) 8)
	  (ash (logand rgb #xff) 16)))

;; 変数名はあえて *color-themes* にしていない。手元のビルド環境では
;; その名前だと *color-theme-table* の初期値 (mapcar の結果) が起動時に
;; 空リストへ化けて再現した (原因はローカルの生成物 src/core/gen/ 内に
;; 同名のシンボルテーブルエントリが残っていたこと、gitignore 対象なので
;; リポジトリには影響しない)。別名にするだけで再現しなくなったため、この
;; 名前を保っている。

;; テーマ名と、0xRRGGBB のまま並べた素データ。BGR への変換は下の1回の
;; mapcar にまとめて行わせる。
(defvar *color-theme-raw-data*
  '(;; Ethan Schoonover, Solarized (MIT). base03/02/01/00/0/1/2/3 +
    ;; アクセント8色から xyzzy の役割へ割り当て。
    ("Solarized Dark"
     #x839496 #x002b36 #x586e75 #x93a1a1 #x073642
     #x268bd2 #x859900 #x6c71c4 #x2aa198 #x586e75 #xcb4b16
     #x073642 #x93a1a1 #xdc322f #x586e75 #x073642
     #x93a1a1 #x073642)
    ("Solarized Light"
     #x657b83 #xfdf6e3 #x93a1a1 #x002b36 #xeee8d5
     #x268bd2 #x859900 #x6c71c4 #x2aa198 #x93a1a1 #xcb4b16
     #xeee8d5 #x657b83 #xdc322f #x93a1a1 #x073642
     #x586e75 #xeee8d5)
    ;; Monokai 系 (TextMate 由来、vim 版が "Molokai" として広まったもの)。
    ("Molokai"
     #xf8f8f2 #x272822 #x75715e #xf8f8f2 #x49483e
     #xf92672 #x66d9ef #xae81ff #xe6db74 #x75715e #xfd971f
     #x3e3d32 #xf8f8f0 #xf92672 #x90908a #x49483e
     #xf8f8f2 #x3e3d32)
    ;; Pavel Pertsev, gruvbox (MIT)
    ("Gruvbox Dark"
     #xebdbb2 #x282828 #x928374 #x282828 #x504945
     #xfb4934 #x83a598 #xd3869b #xb8bb26 #x928374 #xfe8019
     #x3c3836 #xebdbb2 #xfb4934 #x7c6f64 #x504945
     #xebdbb2 #x3c3836)
    ;; Arctic Ice Studio / Sven Greb, Nord (MIT)
    ("Nord"
     #xd8dee9 #x2e3440 #x4c566a #xe5e9f0 #x434c5e
     #x81a1c1 #x88c0d0 #xb48ead #xa3be8c #x4c566a #xd08770
     #x3b4252 #xd8dee9 #xbf616a #x4c566a #x434c5e
     #xeceff4 #x3b4252)
    ;; Zeno Rocha ほか, Dracula (MIT)
    ("Dracula"
     #xf8f8f2 #x282a36 #x6272a4 #xf8f8f2 #x44475a
     #xff79c6 #x8be9fd #xbd93f9 #xf1fa8c #x6272a4 #xffb86c
     #x44475a #xf8f8f2 #xff5555 #x6272a4 #x44475a
     #xf8f8f2 #x44475a)
    ;; Atom, One Dark (MIT)
    ("One Dark"
     #xabb2bf #x282c34 #x5c6370 #xabb2bf #x3e4451
     #xc678dd #x61afef #x56b6c2 #x98c379 #x5c6370 #xe06c75
     #x2c323c #xabb2bf #xe06c75 #x4b5263 #x3e4451
     #xabb2bf #x21252b)
    ;; Chris Kempson, Tomorrow Night (MIT)
    ("Tomorrow Night"
     #xc5c8c6 #x1d1f21 #x969896 #xc5c8c6 #x373b41
     #xb294bb #x81a2be #x8abeb7 #xb5bd68 #x969896 #xde935f
     #x282a2e #xc5c8c6 #xcc6666 #x969896 #x373b41
     #xc5c8c6 #x282a2e)
    ;; Catppuccin, Mocha (MIT)
    ("Catppuccin Mocha"
     #xcdd6f4 #x1e1e2e #x6c7086 #x1e1e2e #x313244
     #xcba6f7 #x89b4fa #x74c7ec #xa6e3a1 #x6c7086 #xfab387
     #x313244 #xcdd6f4 #xf38ba8 #x6c7086 #x313244
     #xcdd6f4 #x181825)
    ;; enkia ほか, Tokyo Night (MIT)
    ("Tokyo Night"
     #xc0caf5 #x1a1b26 #x565f89 #xc0caf5 #x292e42
     #xbb9af7 #x7aa2f7 #x7dcfff #x9ece6a #x565f89 #xff9e64
     #x292e42 #xc0caf5 #xf7768e #x3b4261 #x292e42
     #xc0caf5 #x16161e)
    ;; sainnhe, Everforest Dark (MIT)
    ("Everforest Dark"
     #xd3c6aa #x2d353b #x7a8478 #xd3c6aa #x3d484d
     #xe67e80 #x7fbbb3 #xd699b6 #xa7c080 #x7a8478 #xe69875
     #x343f44 #xd3c6aa #xe67e80 #x7a8478 #x3d484d
     #xd3c6aa #x343f44)
    ;; GitHub Primer, GitHub Dark (MIT)
    ("GitHub Dark"
     #xc9d1d9 #x0d1117 #x8b949e #xc9d1d9 #x30363d
     #xff7b72 #xd2a8ff #x79c0ff #xa5d6ff #x8b949e #xffa657
     #x161b22 #xc9d1d9 #xf85149 #x484f58 #x21262d
     #xc9d1d9 #x161b22)
    ;; dempfi, Ayu Dark (MIT)
    ("Ayu Dark"
     #xbfbdb6 #x0a0e14 #x5c6773 #xbfbdb6 #x253340
     #xff8f40 #xffb454 #xd2a6ff #xaad94c #x5c6773 #x39bae6
     #x11151c #xbfbdb6 #xf07178 #x6c7380 #x253340
     #xbfbdb6 #x11151c)
    ;; Rosé Pine (MIT)
    ("Rose Pine"
     #xe0def4 #x191724 #x6e6a86 #xe0def4 #x403d52
     #xc4a7e7 #x9ccfd8 #x31748f #xf6c177 #x6e6a86 #xeb6f92
     #x26233a #xe0def4 #xeb6f92 #x6e6a86 #x403d52
     #xe0def4 #x1f1d2e)
    ;; Atom, One Light (MIT) -- One Dark の明色版
    ("One Light"
     #x383a42 #xfafafa #xa0a1a7 #x383a42 #xe5e5e6
     #xa626a4 #x4078f2 #x0184bc #x50a14f #xa0a1a7 #xe45649
     #xf0f0f1 #x383a42 #xe45649 #x9d9d9f #xe5e5e6
     #x383a42 #xe5e5e6)
    ;; Catppuccin, Latte (MIT) -- 明色版
    ("Catppuccin Latte"
     #x4c4f69 #xeff1f5 #x9ca0b0 #xeff1f5 #xccd0da
     #x8839ef #x1e66f5 #x209fb5 #x40a02b #x9ca0b0 #xfe640b
     #xccd0da #x4c4f69 #xd20f39 #x9ca0b0 #xccd0da
     #x4c4f69 #xe6e9ef)
    ;; Catppuccin, Frappé (MIT)
    ("Catppuccin Frappe"
     #xc6d0f5 #x303446 #x737994 #x303446 #x414559
     #xca9ee6 #x8caaee #x85c1dc #xa6d189 #x737994 #xef9f76
     #x414559 #xc6d0f5 #xe78284 #x737994 #x414559
     #xc6d0f5 #x292c3c)
    ;; Catppuccin, Macchiato (MIT)
    ("Catppuccin Macchiato"
     #xcad3f5 #x24273a #x6e738d #x24273a #x363a4f
     #xc6a0f6 #x8aadf4 #x7dc4e4 #xa6da95 #x6e738d #xf5a97f
     #x363a4f #xcad3f5 #xed8796 #x6e738d #x363a4f
     #xcad3f5 #x1e2030)
    ;; Rosé Pine, Moon (MIT)
    ("Rose Pine Moon"
     #xe0def4 #x232136 #x6e6a86 #xe0def4 #x44415a
     #xc4a7e7 #x9ccfd8 #x3e8fb0 #xf6c177 #x6e6a86 #xeb6f92
     #x2a273f #xe0def4 #xeb6f92 #x6e6a86 #x44415a
     #xe0def4 #x2a273f)
    ;; Rosé Pine, Dawn (MIT) -- 明色版
    ("Rose Pine Dawn"
     #x575279 #xfaf4ed #x9893a5 #xfaf4ed #xdfdad9
     #x907aa9 #x56949f #x286983 #xea9d34 #x9893a5 #xb4637a
     #xf2e9e1 #x575279 #xb4637a #x9893a5 #xdfdad9
     #x575279 #xfffaf3)
    ;; Pavel Pertsev, gruvbox (MIT) -- Gruvbox Dark の明色版
    ("Gruvbox Light"
     #x3c3836 #xfbf1c7 #x928374 #xfbf1c7 #xebdbb2
     #x9d0006 #x076678 #x8f3f71 #x79740e #x928374 #xaf3a03
     #xebdbb2 #x3c3836 #x9d0006 #x7c6f64 #xebdbb2
     #x3c3836 #xebdbb2)
    ;; dempfi, Ayu Light (MIT) -- Ayu Dark の明色版
    ("Ayu Light"
     #x5c6166 #xfafafa #x787b80 #x5c6166 #xf0eee4
     #xfa8d3e #xf2ae49 #xa37acc #x86b300 #x787b80 #x399ee6
     #xf0eee4 #x5c6166 #xe65050 #x828c99 #xf0eee4
     #x5c6166 #xf0eee4)
    ;; dempfi, Ayu Mirage (MIT)
    ("Ayu Mirage"
     #xcbccc6 #x1f2430 #x565b66 #x1f2430 #x2d3441
     #xffa759 #xffd580 #xdfbfff #xbae67e #x565b66 #x5ccfe6
     #x2d3441 #xcbccc6 #xff3333 #x707a8c #x2d3441
     #xcbccc6 #x232834)
    ;; Sarah Drasner, Night Owl (MIT)
    ("Night Owl"
     #xd6deeb #x011627 #x637777 #xd6deeb #x1d3b53
     #xc792ea #x82aaff #xffcb8b #xecc48d #x637777 #x7fdbca
     #x0e293f #xd6deeb #xf78c6c #x4b6479 #x1d3b53
     #xd6deeb #x0e293f)
    ;; Dmitri Voronianski, Oceanic Next (MIT)
    ("Oceanic Next"
     #xc0c5ce #x1b2b34 #x65737e #xc0c5ce #x4f5b66
     #xc594c5 #x6699cc #x5fb3b3 #x99c794 #x65737e #xec5f67
     #x343d46 #xc0c5ce #xec5f67 #x65737e #x4f5b66
     #xc0c5ce #x343d46)
    ;; EdenEast, Nightfox (MIT)
    ("Nightfox"
     #xcdcecf #x192330 #x71839b #xcdcecf #x223249
     #x9d79d6 #x719cd6 #x63cdcf #x81b29a #x71839b #xc94f6d
     #x212e3f #xcdcecf #xc94f6d #x71839b #x223249
     #xcdcecf #x212e3f)
    ;; rebelot, Kanagawa (MIT)
    ("Kanagawa"
     #xdcd7ba #x1f1f28 #x727169 #xdcd7ba #x2a2a37
     #x957fb8 #x7e9cd8 #x7aa89f #x98bb6c #x727169 #xc34043
     #x2a2a37 #xdcd7ba #xc34043 #x54546d #x2a2a37
     #xdcd7ba #x16161d)
    ;; Wes Bos, Cobalt2 (MIT)
    ("Cobalt2"
     #xffffff #x193549 #x0088ff #x193549 #x1f4662
     #xffc600 #x9effff #xff628c #x3ad900 #x0088ff #xff9d00
     #x1f4662 #xffffff #xff628c #x0d3a58 #x1f4662
     #xffffff #x0d3a58)
    ;; Jani Nurminen, Zenburn (BSD) -- 低コントラストの古典配色
    ("Zenburn"
     #xdcdccc #x3f3f3f #x656555 #xdcdccc #x4f4f4f
     #xf0dfaf #x8cd0d3 #xdc8cc3 #xcc9393 #x7f9f7f #xdfaf8f
     #x4f4f4f #xdcdccc #xcc9393 #x656555 #x4f4f4f
     #xdcdccc #x4f4f4f)
    ;; Visual Studio Code 既定の Dark+ (VS Code 本体と同じ MIT)
    ("VS Code Dark+"
     #xd4d4d4 #x1e1e1e #x808080 #xffffff #x264f78
     #x569cd6 #xdcdcaa #x4ec9b0 #xce9178 #x6a9955 #x9cdcfe
     #x2a2a2a #xd4d4d4 #xf44747 #x858585 #x264f78
     #xffffff #x007acc)))

(defvar *color-theme-table*
  (mapcar #'(lambda (theme)
	      (cons (car theme)
		    (map 'vector #'%rgb-to-colorref (cdr theme))))
	  *color-theme-raw-data*))

(define-history-variable *current-color-theme* nil
  "現在適用中のカラーテーマ名 (*color-theme-table* の car)。nil ならテーマ未
   適用 (xyzzy 標準の表示色)。次回起動時にも復元される。")

(defun color-theme-colors (name)
  (cdr (assoc name *color-theme-table* :test #'string=)))

(defun apply-color-theme (name &optional force)
  "NAME のテーマを開いている全バッファへ適用する。FORCE が nil の場合、
   ディレクトリ単位で個別に色設定済みのバッファ (find-buffer-colors) は
   そちらを優先してスキップする。"
  (let ((colors (color-theme-colors name)))
    (unless colors
      (error "不明なカラーテーマです: ~A" name))
    (dolist (buffer (buffer-list))
      (when (or force (null (find-buffer-colors buffer)))
	(set-buffer-colors colors buffer)))
    (refresh-screen t)))

(defun set-color-theme (name)
  (interactive
   (list (completing-read "カラーテーマ: " (mapcar #'car *color-theme-table*)
			   :must-match t :default *current-color-theme*)))
  (apply-color-theme name t)
  (setq *current-color-theme* name)
  (message "カラーテーマ: ~A" name))

(defvar *color-theme-counterpart-alist*
  '(("Catppuccin Mocha"    . "Catppuccin Latte")
    ("Catppuccin Macchiato" . "Catppuccin Latte")
    ("Catppuccin Frappe"   . "Catppuccin Latte")
    ("Rose Pine"           . "Rose Pine Dawn")
    ("Rose Pine Moon"      . "Rose Pine Dawn")
    ("Ayu Mirage"          . "Ayu Light")
    ("One Dark"            . "One Light"))
  "暗い/明るいの対応のうち、名前から機械的に導けないもの。
「X Dark」と「X Light」の組は下の色替えで自動的に対応が付くので、ここには
書かない。片方向だけ書けばよい (逆向きも探す)。")

(defvar *color-theme-default-dark* "One Dark"
  "対応する暗いテーマが見つからないときに使うテーマ。")

(defvar *color-theme-default-light* "One Light"
  "対応する明るいテーマが見つからないときに使うテーマ。")

(defun color-theme-dark-p (name)
  "NAME のテーマが暗いか。**名前ではなく背景色の明るさで決める。**
名前に Dark/Light と入っていないテーマ (Dracula, Nord, Molokai …) が
たくさんあるので、名前を見る方法では大半を判定できない。

背景色はベクタの 1 番目。COLORREF は 0x00BBGGRR なので、そこから
R/G/B を取り出して輝度 (ITU-R BT.601) を出す。"
  (let ((colors (color-theme-colors name)))
    (and colors
	 (let* ((bg (aref colors 1))
		(r (logand bg #xff))
		(g (logand (ash bg -8) #xff))
		(b (logand (ash bg -16) #xff)))
	   (< (+ (* 299 r) (* 587 g) (* 114 b)) 128000)))))

(defun color-theme-swap-dark-light (name)
  "\"X Dark\" と \"X Light\" を入れ替えた名前を返す。どちらでもなければ nil。"
  (let ((n (length name)))
    (cond ((and (> n 5) (string= name " Dark" :start1 (- n 5)))
	   (concat (subseq name 0 (- n 5)) " Light"))
	  ((and (> n 6) (string= name " Light" :start1 (- n 6)))
	   (concat (subseq name 0 (- n 6)) " Dark"))
	  (t nil))))

(defun color-theme-counterpart (name)
  "NAME の暗い/明るい相方のテーマ名。無ければ nil。"
  (let ((pair (or (cdr (assoc name *color-theme-counterpart-alist*
			      :test #'string=))
		  (car (rassoc name *color-theme-counterpart-alist*
			       :test #'string=))
		  (color-theme-swap-dark-light name))))
    (and pair (color-theme-colors pair) pair)))

(defun toggle-color-theme-dark-light ()
  "暗いテーマと明るいテーマを切り替える。

相方が分かるならそれへ、分からなければ *color-theme-default-dark* /
*color-theme-default-light* の反対側へ移る。テーマを当てていない状態からは
暗い方へ移る (xyzzy 標準の表示色は明るいので)。"
  (interactive)
  (let* ((current *current-color-theme*)
	 (target (or (and current (color-theme-counterpart current))
		     (if (and current (color-theme-dark-p current))
			 *color-theme-default-light*
		       *color-theme-default-dark*))))
    (if (null (color-theme-colors target))
	(progn
	  (message "切り替え先のテーマがありません: ~A" target)
	  nil)
      (progn
	(set-color-theme target)
	target))))

(defun color-theme-snapshot ()
  "全バッファの現在の表示色 (get-buffer-colors) を控える。プレビューを
   キャンセルしたときに、テーマ名の再適用ではなくバッファごとの生の値で
   正確に戻すために使う。プレビューは force t で適用するため、ディレクト
   リ単位の色設定 (loptprop.l) が乗ったバッファも一時的に上書きされる。
   テーマ名ベースで『戻す』とそちらは復元できないので、生の値を控える。"
  (mapcar #'(lambda (buffer) (cons buffer (get-buffer-colors buffer)))
	  (buffer-list)))

(defun color-theme-restore (snapshot)
  (dolist (entry snapshot)
    (set-buffer-colors (cdr entry) (car entry)))
  (refresh-screen t))

;;; カラーテーマ選択バッファ。
;;;
;;; ミニバッファでの絞り込み選択は候補が多いと途中で切れて一覧性が無い
;;; ので、専用バッファに全テーマを1行1件で並べ、カーソル移動 (通常の
;;; C-n/C-p/矢印キーに加え、検索やジャンプもバッファそのものの機能が
;;; そのまま使える) で選ぶ形にしている。行が変わるたびに *post-command-hook*
;;; (ts.l のシンタックスハイライト再計算と同じ仕組み) でその行のテーマを
;;; 全バッファへプレビュー適用し、RET で確定、q / C-g でプレビュー開始前の
;;; 色に戻す。

(defconstant +color-theme-picker-header-lines+ 2)

(defvar-local *color-theme-picker-active* nil)
(defvar-local *color-theme-picker-snapshot* nil)
(defvar-local *color-theme-picker-window-config* nil)
(defvar-local *color-theme-picker-last-previewed* nil)

(defun color-theme-picker-line-name ()
  "現在行に対応するテーマ名。テーマの行でなければ nil。"
  (let ((idx (- (current-line-number) (1+ +color-theme-picker-header-lines+))))
    (and (>= idx 0) (< idx (length *color-theme-table*))
	 (car (nth idx *color-theme-table*)))))

(defun color-theme-picker-post-command ()
  (when *color-theme-picker-active*
    (let ((name (color-theme-picker-line-name)))
      (when (and name (not (equal name *color-theme-picker-last-previewed*)))
	(setq *color-theme-picker-last-previewed* name)
	(apply-color-theme name t)))))

(add-hook '*post-command-hook* 'color-theme-picker-post-command)

(defun color-theme-picker-finish ()
  "選択バッファを畳んで、開く前の窓構成に戻す。"
  (let ((config *color-theme-picker-window-config*)
	(buffer (selected-buffer)))
    (setq *color-theme-picker-active* nil)
    (set-window-configuration config)
    (kill-buffer buffer)))

(defun color-theme-picker-commit ()
  (interactive)
  (let ((name (color-theme-picker-line-name)))
    (unless name
      (ding)
      (return-from color-theme-picker-commit))
    (color-theme-picker-finish)
    (setq *current-color-theme* name)
    (message "カラーテーマ: ~A" name)))

(defun color-theme-picker-cancel ()
  (interactive)
  (let ((snapshot *color-theme-picker-snapshot*))
    (color-theme-picker-finish)
    (color-theme-restore snapshot)
    (message "カラーテーマの選択をキャンセルしました")))

(defvar *color-theme-select-mode-map* nil)
(unless *color-theme-select-mode-map*
  (setq *color-theme-select-mode-map* (make-sparse-keymap))
  (define-key *color-theme-select-mode-map* #\RET 'color-theme-picker-commit)
  (define-key *color-theme-select-mode-map* #\q 'color-theme-picker-cancel)
  (define-key *color-theme-select-mode-map* #\C-g 'color-theme-picker-cancel))

(defun color-theme-select-mode ()
  (kill-all-local-variables)
  (setq buffer-mode 'color-theme-select-mode)
  (setq mode-name "Color Theme")
  (use-keymap *color-theme-select-mode-map*)
  (setq buffer-read-only t)
  (set-buffer-fold-width nil)
  (make-local-variable 'kept-undo-information)
  (setq kept-undo-information nil)
  (make-local-variable 'need-not-save)
  (setq need-not-save t)
  (make-local-variable 'auto-save)
  (setq auto-save nil))

(defun select-color-theme ()
  "カラーテーマ選択バッファを開く。カーソルを合わせたテーマがその場で
   全バッファへプレビュー適用される。RET で確定、q / C-g でプレビュー
   開始前の色に戻す。"
  (interactive)
  (let ((snapshot (color-theme-snapshot))
	(config (current-window-configuration))
	(current *current-color-theme*))
    (with-output-to-temp-buffer ("*Color Theme*")
      (princ "カラーテーマ選択  (RET: 決定  q, C-g: キャンセル)\n\n")
      (dolist (theme *color-theme-table*)
	(format t "~:[  ~;* ~]~A~%" (equal (car theme) current) (car theme))))
    (color-theme-select-mode)
    (setq *color-theme-picker-snapshot* snapshot)
    (setq *color-theme-picker-window-config* config)
    (setq *color-theme-picker-last-previewed* nil)
    (goto-char (point-min))
    (forward-line +color-theme-picker-header-lines+)
    (when current
      (let ((pos (position current *color-theme-table* :key #'car :test #'string=)))
	(when pos
	  (goto-line (+ pos +color-theme-picker-header-lines+ 1)))))
    (setq *color-theme-picker-active* t)
    (color-theme-picker-post-command)))

(defun clear-color-theme ()
  (interactive)
  (setq *current-color-theme* nil)
  (dolist (buffer (buffer-list))
    (unless (find-buffer-colors buffer)
      (set-buffer-colors nil buffer)))
  (refresh-screen t)
  (message "カラーテーマを解除しました"))

;;; 新規バッファ (*Shell* を含む) にも現在のテーマを自動適用する。
;;; ディレクトリ単位の色設定 (loptprop.l) が優先されるようにするため、
;;; *create-buffer-hook* の中で create-buffer-hook (buffer.l) より後に
;;; 走ればよい。add-hook は末尾に足すので順序はこれで保証される。
(defun color-theme-create-buffer-hook (buffer)
  (when (and *current-color-theme* (null (find-buffer-colors buffer)))
    (set-buffer-colors (color-theme-colors *current-color-theme*) buffer)))

(add-hook '*create-buffer-hook* 'color-theme-create-buffer-hook)

;;; 履歴ファイルの読み込みで *current-color-theme* の値が復元されるのは
;;; *load-history-hook* が走った後。*scratch* など、それより前に存在して
;;; いたバッファへも反映させる。
(add-hook '*load-history-hook*
	  #'(lambda ()
	      (when *current-color-theme*
		(apply-color-theme *current-color-theme*))))

(defun make-color-theme-popup-menu ()
  (let ((menu (create-popup-menu)))
    (add-menu-item menu nil "プレビューして選択(&P)..."
		   #'(lambda () (interactive) (select-color-theme)))
    (add-menu-separator menu)
    (add-menu-item menu nil "デフォルトに戻す"
		   #'(lambda () (interactive) (clear-color-theme))
		   #'(lambda () (if (null *current-color-theme*) :check)))
    (add-menu-separator menu)
    (mapc #'(lambda (theme)
	      (add-menu-item menu nil (car theme)
			     #'(lambda ()
				 (interactive)
				 (set-color-theme (car theme)))
			     #'(lambda ()
				 (if (equal *current-color-theme* (car theme))
				     :check))))
	  *color-theme-table*)
    menu))
