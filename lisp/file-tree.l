;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;
;;; ファイルツリーペイン。
;;;
;;; フレーム左端に常駐する IDE 風のサイドペインとして、ディレクトリの
;;; ツリーをテキストで描画する (pane.l)。ncurses / POSIX 版でも動くよう
;;; ネイティブコントロールには依存しない。
;;;
;;;   M-x file-tree   ペインの開閉
;;;
;;; ペイン内:
;;;   RET / 左クリック  ファイルを他ウィンドウで開く、ディレクトリは展開/折りたたみ
;;;   TAB              展開/折りたたみ
;;;   g                再読み込み
;;;   -                ルートを親ディレクトリへ
;;;   H                ドットファイルの表示切り替え
;;;   q                ペインを閉じる
;;;
;;; バッファの各行は file-tree-lines (ベクタ) が対応するエントリを持つ。
;;; エントリは (path dirp depth) のリストで、root 行だけ :root になる。

(provide "file-tree")

(in-package "editor")

(require "pane")
(require "project")
(require "re-kwd")

(export '(file-tree file-tree-mode file-tree-buffer
	  *file-tree-buffer-name* *file-tree-mode-map* *file-tree-mode-hook*))

(defvar *file-tree-buffer-name* "*file-tree*"
  "ファイルツリーを表示するバッファ名。")

;;; バッファローカルな状態 (file-tree-mode で make-local-variable される)
(defvar file-tree-root nil
  "ツリーのルートディレクトリ (末尾 / 付きの名前文字列)。")
(defvar file-tree-expanded nil
  "展開済みディレクトリの file-tree-dirstring のリスト。")
(defvar file-tree-show-hidden nil
  "non-nil ならドットで始まる名前も表示する。")
(defvar file-tree-lines nil
  "行番号 - 1 を添字にエントリ ((path dirp depth) または :root) を返すベクタ。")

;;; ---------------------------------------------------------------------------
;;; エントリ: (path dirp depth)

(defun file-tree-entry-path (entry) (car entry))
(defun file-tree-entry-dir-p (entry) (cadr entry))
(defun file-tree-entry-depth (entry) (caddr entry))

(defun file-tree-dirstring (path)
  "PATH を末尾 / 付きのディレクトリ名文字列に正規化する。
namestring には絶対化を求めない (相対パスは相対のまま)。"
  (append-trail-slash (if (stringp path) path (namestring path))))

(defun file-tree-basename (path)
  "PATH の最後の要素名。末尾の / は落とす。"
  (let ((s (file-namestring (remove-trail-slash path))))
    (if (zerop (length s)) path s)))

(defun file-tree-entry-name (entry)
  (file-tree-basename (file-tree-entry-path entry)))

;;; ---------------------------------------------------------------------------
;;; ツリーのモデル

(defun file-tree-children (dir show-hidden)
  "DIR の直下の子を ((path dirp) ...) で返す。
ディレクトリが先で、それぞれ名前順。ドットで始まる名前は SHOW-HIDDEN が
non-nil のときだけ含める。"
  (flet ((visible-p (path)
           (or show-hidden
               (let ((n (file-tree-basename path)))
                 (not (and (plusp (length n))
                           (char= (char n 0) #\.))))))
         (name< (a b)
           (string-lessp (file-tree-basename a) (file-tree-basename b))))
    (nconc (mapcar #'(lambda (p) (list p t))
		   (sort (directory dir :absolute t :directory-only t
				    :test #'visible-p)
			 #'name<))
	   (mapcar #'(lambda (p) (list p nil))
		   (sort (directory dir :absolute t :file-only t
				    :test #'visible-p)
			 #'name<)))))

(defun file-tree-path-same-p (a b)
  "2 つのパスが同じ場所を指すか。末尾 / の有無は吸収する。
path-equal は存在しない相対パスを比較できないので、まず文字列として
見てから path-equal に預ける。"
  (or (string= (file-tree-dirstring a) (file-tree-dirstring b))
      (path-equal a b)))

(defun file-tree-path-in-p (path dir)
  "PATH が DIR 自身または配下にあるか。"
  (let ((d (file-tree-dirstring dir))
        (p (file-tree-dirstring path)))
    (let ((m (mismatch d p :test #'char-equal)))
      (or (null m) (>= m (length d))))))

(defun file-tree-expanded-p (expanded dir)
  "EXPANDED (ディレクトリ名文字列のリスト) に DIR が含まれるか。"
  (member dir expanded :test #'file-tree-path-same-p))

(defun file-tree-entries-1 (dir depth expanded show-hidden)
  (let (result)
    (dolist (child (file-tree-children dir show-hidden))
      (push (list (car child) (cadr child) depth) result)
      (when (and (cadr child)
		 (file-tree-expanded-p expanded (car child)))
        ;; push は先頭に積むので、子孫も順番に積めば nreverse で DFS 順になる
        (dolist (gc (file-tree-entries-1 (car child) (1+ depth)
					 expanded show-hidden))
          (push gc result))))
    (nreverse result)))

(defun file-tree-entries (root expanded show-hidden)
  "ROOT の可視エントリを ((path dirp depth) ...) の平坦なリストで返す。
ROOT 自身は含まない。展開済みディレクトリの子は一段深く続く。"
  (file-tree-entries-1 root 0 expanded show-hidden))

(defun file-tree-toggle-expanded (expanded dir)
  "EXPANDED 中の DIR をトグルした新しいリストを返す。
折りたたむときは DIR 配下の展開も外す。"
  (let ((d (file-tree-dirstring dir)))
    (if (file-tree-expanded-p expanded d)
        ;; DIR 自身と DIR 配下を外す
        (remove-if #'(lambda (p) (file-tree-path-in-p p d)) expanded)
      (append expanded (list d)))))

;;; ---------------------------------------------------------------------------
;;; 描画

(defvar *file-tree-regexp-keyword-list* nil)
(defun file-tree-setup-keywords ()
  (unless *file-tree-regexp-keyword-list*
    (setq *file-tree-regexp-keyword-list*
          (compile-regexp-keyword-list
           '(("^ *\\[[-+]\\] " nil 1)))))
  *file-tree-regexp-keyword-list*)

(defun file-tree-render-lines (root expanded show-hidden)
  "(line-text . entry) のリストを返す。先頭行はルートで entry は :root。"
  (cons (cons (file-tree-dirstring root) :root)
        (mapcar #'(lambda (e)
		    (cons (concat (make-sequence 'string (* 2 (caddr e))
						 :initial-element #\SPC)
				  (cond ((not (cadr e)) "    ")
					((file-tree-expanded-p expanded
							       (car e))
					 "[-] ")
					(t "[+] "))
				  (file-tree-entry-name e))
			  e))
		(file-tree-entries root expanded show-hidden))))

(defun file-tree-line-of-entry (path)
  "PATH を持つエントリの行番号を返す。無ければ nil。"
  (dotimes (i (length file-tree-lines))
    (let ((e (aref file-tree-lines i)))
      (when (and (consp e) (file-tree-path-same-p (car e) path))
        (return (1+ i))))))

(defun file-tree-entry-at-point ()
  "ポイントのある行のエントリを返す。ルート行なら :root、該当なしなら nil。"
  (let ((n (1- (current-line-number))))
    (and file-tree-lines (< -1 n (length file-tree-lines))
         (aref file-tree-lines n))))

(defun file-tree-draw ()
  "file-tree バッファを現在の状態で描き直す。
同じエントリが残っていればポイントをそこへ戻す。"
  (let ((entry (file-tree-entry-at-point))
        (line (current-line-number)))
    (let ((buffer-read-only nil))
      (declare (special buffer-read-only))
      (erase-buffer (selected-buffer))
      (let ((lines (file-tree-render-lines file-tree-root
                                           file-tree-expanded
                                           file-tree-show-hidden)))
        (setq file-tree-lines (make-vector (length lines)))
        (let ((i 0))
          (dolist (l lines)
            (setf (aref file-tree-lines i) (cdr l))
            (insert (car l) #\LFD)
            (incf i)))))
    (set-buffer-modified-p nil)
    (goto-line (max 1 (or (and (consp entry)
			       (file-tree-line-of-entry (car entry)))
			  (min line (length file-tree-lines)))))))

;;; ---------------------------------------------------------------------------
;;; コマンド

(defun file-tree-toggle ()
  "ポイント行のディレクトリを展開/折りたたみする。"
  (interactive)
  (let ((e (file-tree-entry-at-point)))
    (when (and (consp e) (file-tree-entry-dir-p e))
      (setq file-tree-expanded
            (file-tree-toggle-expanded file-tree-expanded (car e)))
      (file-tree-draw))))

(defun file-tree-visit ()
  "ポイント行を開く。ファイルは他ウィンドウで開き、
ディレクトリは展開/折りたたみする。"
  (interactive)
  (let ((e (file-tree-entry-at-point)))
    (cond ((not (consp e)) nil)
          ((file-tree-entry-dir-p e) (file-tree-toggle))
          (t (find-file-other-window (car e))))))

(defun file-tree-mouse-visit ()
  (interactive)
  ;; LBtnDown はクリック先ではなくカレントバッファのキーマップで解決される。
  ;; ツリーのウィンドウ以外がクリックされたときは通常のマウス処理
  ;; (フォーカス移動など) に委譲する。
  (if (eq (selected-window) *last-mouse-window*)
      (progn
        (goto-last-mouse-point)
        (file-tree-visit))
    (mouse-left-press)))

(defun file-tree-refresh ()
  "ツリーを再読み込みする。"
  (interactive)
  (file-tree-draw))

(defun file-tree-up-dir ()
  "ルートを親ディレクトリに上げる。"
  (interactive)
  (let ((parent (parent-directory file-tree-root)))
    (when parent
      ;; 来た道は開いたままにしておくと迷子になりにくい
      (pushnew file-tree-root file-tree-expanded :test #'file-tree-path-same-p)
      (setq file-tree-root (file-tree-dirstring parent))
      (file-tree-draw))))

(defun file-tree-toggle-hidden ()
  "ドットファイルの表示を切り替える。"
  (interactive)
  (setq file-tree-show-hidden (not file-tree-show-hidden))
  (file-tree-draw))

(defun file-tree-close ()
  "ペインを閉じる。"
  (interactive)
  (pane-hide (selected-buffer)))

;;; ---------------------------------------------------------------------------
;;; モードとエントリポイント

(defvar *file-tree-mode-hook* nil)
(defvar *file-tree-mode-map* nil)
(unless *file-tree-mode-map*
  (setq *file-tree-mode-map* (make-sparse-keymap))
  (define-key *file-tree-mode-map* #\RET 'file-tree-visit)
  (define-key *file-tree-mode-map* #\TAB 'file-tree-toggle)
  (define-key *file-tree-mode-map* #\LBtnDown 'file-tree-mouse-visit)
  (define-key *file-tree-mode-map* #\g 'file-tree-refresh)
  (define-key *file-tree-mode-map* #\q 'file-tree-close)
  (define-key *file-tree-mode-map* #\- 'file-tree-up-dir)
  (define-key *file-tree-mode-map* #\H 'file-tree-toggle-hidden)
  (define-key *file-tree-mode-map* #\n 'next-line)
  (define-key *file-tree-mode-map* #\p 'previous-line))

(defun file-tree-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "file-tree")
  (setq buffer-mode 'file-tree-mode)
  (use-keymap *file-tree-mode-map*)
  (make-local-variable 'file-tree-root)
  (make-local-variable 'file-tree-expanded)
  (make-local-variable 'file-tree-show-hidden)
  (make-local-variable 'file-tree-lines)
  (setq file-tree-expanded nil)
  (setq file-tree-show-hidden nil)
  (setq file-tree-lines nil)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (file-tree-setup-keywords))
  (setq buffer-read-only t)
  (run-hooks '*file-tree-mode-hook*))

(defun file-tree-buffer (&optional root)
  "*file-tree* バッファを返す。無ければ作って ROOT で初期化する。
with-set-buffer はバッファを切り替えない (ミニバッファ回避のためだけの
マクロ) ことに注意。描き込みは save-excursion + set-buffer で行う。"
  (let ((buf (get-buffer-create *file-tree-buffer-name*)))
    (save-excursion
      (set-buffer buf)
      (unless (eq buffer-mode 'file-tree-mode)
        (file-tree-mode))
      (when root
        (setq file-tree-root (file-tree-dirstring root)))
      (unless file-tree-root
        (setq file-tree-root (file-tree-dirstring (default-directory))))
      (file-tree-draw))
    buf))

(defun file-tree (&optional root)
  "ファイルツリーペインを開閉する。
開くときのルートは ROOT、省略時は `project-current-root'。"
  (interactive)
  (if (pane-window *file-tree-buffer-name*)
      (pane-hide *file-tree-buffer-name*)
    (pane-show (file-tree-buffer (or root (project-current-root))))))
