;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/file-tree.l と lisp/pane.l のテスト。
;;;
;;; 本体はエントリの並び (ディレクトリ優先・名前順) と、展開状態をまたいだ
;;; ツリーの平坦化、展開セットの toggle、描画した行からエントリを
;;; 引き戻すところ。ウィンドウの開閉は pane.l 側で最小限だけ見る。

(require "file-tree")
(require "pane")

(defun file-tree-test-delete-tree (dir)
  "DIR 以下を中身ごと消す (深いものから消す)。"
  (dolist (f (directory dir :absolute t :recursive t :file-only t))
    (delete-file f))
  (dolist (d (sort (directory dir :absolute t :recursive t :directory-only t)
                   #'> :key #'length))
    (delete-directory d)))

(defmacro with-file-tree-test ((root) &body body)
  "ROOT に次の木を作って BODY を評価する。

    adir/inner.txt
    bdir/
    a.txt
    z.txt
    .hidden"
  `(with-temp-dirs (,root)
     (unwind-protect
         (progn
           (create-directory (merge-pathnames "adir/" ,root))
           (create-directory (merge-pathnames "bdir/" ,root))
           (dolist (f '("adir/inner.txt" "a.txt" "z.txt" ".hidden"))
             (with-open-file (s (merge-pathnames f ,root) :direction :output)
               (princ "x" s)))
           ,@body)
       (file-tree-test-delete-tree ,root))))
(setf (get 'with-file-tree-test 'ed:lisp-indent-hook) 1)

(deftest file-tree-children-order ()
  "直下の子はディレクトリ優先、それぞれ名前順で返ること"
  (with-file-tree-test (root)
    (mapcar #'ed::file-tree-entry-name
            (ed::file-tree-children root nil)))
  => ("adir" "bdir" "a.txt" "z.txt"))

(deftest file-tree-children-kinds ()
  "ディレクトリかどうかが取れること"
  (with-file-tree-test (root)
    (mapcar #'ed::file-tree-entry-dir-p
            (ed::file-tree-children root nil)))
  => (t t nil nil))

(deftest file-tree-children-hidden ()
  "ドットで始まる名前は既定で除き、show-hidden が non-nil なら含めること"
  (with-file-tree-test (root)
    (values
     (mapcar #'ed::file-tree-entry-name
             (ed::file-tree-children root nil))
     (mapcar #'ed::file-tree-entry-name
             (ed::file-tree-children root t))))
  => ("adir" "bdir" "a.txt" "z.txt")
  => ("adir" "bdir" ".hidden" "a.txt" "z.txt"))

(deftest file-tree-entries-collapsed ()
  "何も展開していなければ直下の子だけが深さ 0 で並ぶこと"
  (with-file-tree-test (root)
    (mapcar #'ed::file-tree-entry-name
            (ed::file-tree-entries root nil nil)))
  => ("adir" "bdir" "a.txt" "z.txt"))

(deftest file-tree-entries-expanded ()
  "展開済みディレクトリの子だけが一段深く並ぶこと"
  (with-file-tree-test (root)
    (let* ((collapsed (ed::file-tree-entries root nil nil))
           (adir (ed::file-tree-entry-path (car collapsed)))
           (entries (ed::file-tree-entries root (list adir) nil)))
      (values
       (mapcar #'ed::file-tree-entry-name entries)
       (mapcar #'ed::file-tree-entry-depth entries)
       (mapcar #'ed::file-tree-entry-dir-p entries))))
  => ("adir" "inner.txt" "bdir" "a.txt" "z.txt")
  => (0 1 0 0 0)
  => (t nil t nil nil))

(deftest file-tree-toggle-expanded ()
  "展開のトグル。折りたたむときは配下の展開も外すこと"
  (let ((expanded '("r/a/" "r/a/b/" "r/c/")))
    (values
     (ed::file-tree-toggle-expanded expanded "r/a/")
     (ed::file-tree-toggle-expanded expanded "r/z/")
     ;; 折りたたんだあとでなければ入れ子だけ消してはいけない
     (ed::file-tree-toggle-expanded '("r/a/") "r/a/b/")))
  => ("r/c/")
  => ("r/a/" "r/a/b/" "r/c/" "r/z/")
  => ("r/a/" "r/a/b/"))

(deftest file-tree-render-lines ()
  "行テキストは深さぶんの字下げと展開マーカーを持つこと。
先頭行はルートディレクトリのパスそのもの"
  (with-file-tree-test (root)
    (let* ((collapsed (ed::file-tree-entries root nil nil))
           (adir (ed::file-tree-entry-path (car collapsed)))
           (lines (ed::file-tree-render-lines root (list adir) nil)))
      (values
       (string= (car (car lines)) (ed::file-tree-dirstring root))
       (mapcar #'car (cdr lines)))))
  => t
  => ("[-] adir" "      inner.txt" "[+] bdir" "    a.txt" "    z.txt"))

(deftest file-tree-draw-and-entry-at-point ()
  "描画したバッファで行からエントリが引き戻せること"
  (with-file-tree-test (root)
    (with-temp-buffer
      (ed::file-tree-mode)
      (setq ed::file-tree-root (ed::file-tree-dirstring root))
      (ed::file-tree-draw)
      (values
       (progn (goto-line 1)
              (ed::file-tree-entry-at-point))
       (progn (goto-line 2)
              (ed::file-tree-entry-name
               (ed::file-tree-entry-at-point)))
       (progn (goto-line 4)
              (ed::file-tree-entry-name
               (ed::file-tree-entry-at-point))))))
  => :root
  => "adir"
  => "a.txt")

(deftest file-tree-draw-restores-point ()
  "再描画しても同じエントリの上にポイントが残ること"
  (with-file-tree-test (root)
    (with-temp-buffer
      (ed::file-tree-mode)
      (setq ed::file-tree-root (ed::file-tree-dirstring root))
      (ed::file-tree-draw)
      (goto-line 4)
      (ed::file-tree-draw)
      (ed::file-tree-entry-name (ed::file-tree-entry-at-point))))
  => "a.txt")

(deftest file-tree-toggle-command ()
  "行の上でトグルすると展開セットが変わり再描画されること"
  (with-file-tree-test (root)
    (with-temp-buffer
      (ed::file-tree-mode)
      (setq ed::file-tree-root (ed::file-tree-dirstring root))
      (ed::file-tree-draw)
      (goto-line 2)                     ; adir
      (ed::file-tree-toggle)
      (values
       ;; 展開されたので inner.txt が見える
       (progn (goto-line 3)
              (ed::file-tree-entry-name
               (ed::file-tree-entry-at-point)))
       ;; もう一度で畳む
       (progn (goto-line 2)
              (ed::file-tree-toggle)
              (goto-line 3)
              (ed::file-tree-entry-name
               (ed::file-tree-entry-at-point))))))
  => "inner.txt"
  => "bdir")

(deftest file-tree-up-dir ()
  "ルートを親ディレクトリに上げられること"
  (with-file-tree-test (root)
    (with-temp-buffer
      (ed::file-tree-mode)
      (setq ed::file-tree-root (ed::file-tree-dirstring root))
      (let ((expected (parent-directory ed::file-tree-root)))
        (ed::file-tree-up-dir)
        (and expected (path-equal ed::file-tree-root expected)))))
  => t)

(deftest pane-toggle-show-hide ()
  "ペインを開いて閉じられること"
  (save-window-excursion
    (let ((buf (get-buffer-create " *pane-test*")))
      (unwind-protect
          (values
           (progn (ed::pane-toggle buf)
                  (and (get-buffer-window buf) t))
           (progn (ed::pane-toggle buf)
                  (get-buffer-window buf)))
        (delete-buffer buf))))
  => t
  => nil)

(deftest pane-show-reuses-window ()
  "既に表示されているバッファを再び開いてもウィンドウは増えないこと"
  (save-window-excursion
    (let ((buf (get-buffer-create " *pane-test2*")))
      (unwind-protect
          (let ((w1 (ed::pane-show buf)))
            (values (eq w1 (ed::pane-show buf))
                    (progn (ed::pane-hide buf)
                           (get-buffer-window buf))))
        (delete-buffer buf))))
  => t
  => nil)
