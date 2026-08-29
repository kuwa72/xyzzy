;;; -*- Encoding: utf-8 -*-
;;; ファイル名補完の大文字小文字。**「どちらが正しいか」ではなく
;;; 「ファイルシステムと一致しているか」を聞く。**
;;;
;;; 大文字小文字を区別するかはファイルシステムの性質なので、期待値を
;;; プラットフォームで書き分けると、そのプラットフォームでしか意味を
;;; 持たないテストになる。代わりに **その場でファイルシステムに聞いて**、
;;; 補完の答えがそれと合っているかだけを見る。こうすると Win32 でも POSIX でも
;;; 同じ 1 行が同じことを検査する。
;;;
;;; 元の実装は突き合わせを常に「区別しない」で行っていて、POSIX ビルドでは
;;; `/work/RE' が `/work/re' に化けていた (README.md / RELEASING.md /
;;; reference/ が混ざると、最初に見つかった候補の綴りに寄る)。
;;; **打った字を書き換えて、存在しないパスを返していた。**

(defun compcase-test-directory ()
  (merge-pathnames "unittest/data/compcase/" (si:system-root)))

(defun compcase-setup ()
  (let ((dir (compcase-test-directory)))
    (compcase-teardown)
    (create-directory dir)
    ;; 前置 "Zz" / "zz" までは大文字小文字だけの違い、その先は別の名前。
    ;; **Win32 でも両方が別のファイルとして共存できる**形にしてある。
    (dolist (name '("Zz-alpha" "zz-beta"))
      (with-open-file (s (merge-pathnames name dir)
                         :direction :output :if-exists :supersede)
        (princ "x" s)))
    dir))

(defun compcase-teardown ()
  (let ((dir (compcase-test-directory)))
    (when (file-directory-p dir)
      (dolist (f (directory dir :absolute t))
        (when (file-exist-p f)
          (ignore-errors (delete-file f))))
      (ignore-errors (delete-directory dir)))))

;; ファイルシステムが大文字小文字を区別するかを、その場で測る。
;; Zz-alpha を作ってから zz-alpha が見えるなら、区別していない。
(defun compcase-filesystem-case-sensitive-p (dir)
  (not (file-exist-p (concat (namestring dir) "/zz-alpha"))))

;; 候補の数がファイルシステムの扱いと一致するか。
;; 区別するなら "Zz" に合うのは Zz-alpha だけ、しないなら 2 つとも。
(deftest completion-case-matches-filesystem ()
  (unwind-protect
      (let ((dir (compcase-setup)))
        (multiple-value-bind (result matches)
            (*do-completion (concat (namestring dir) "/Zz") :exist-file-name)
          result
          (= (length matches)
             (if (compcase-filesystem-case-sensitive-p dir) 1 2))))
    (compcase-teardown))
  => t)

;; 打った字がそのまま返ってくるか。**区別するファイルシステムでは、
;; 補完の結果は必ず打った前置で始まらなければならない** (書き換えたら
;; 存在しないパスになる)。区別しないなら書き換えても実在するので問わない。
(deftest completion-case-keeps-typed-prefix ()
  (unwind-protect
      (let* ((dir (compcase-setup))
             (input (concat (namestring dir) "/Zz"))
             (result (*do-completion input :exist-file-name)))
        (if (compcase-filesystem-case-sensitive-p dir)
            (and (stringp result)
                 (string= result input :end1 (length input))
                 t)
          t))
    (compcase-teardown))
  => t)

;; 実在する名前をそのまま渡したら確定する (両方で同じ)。
;; *do-completion は候補一覧と前置も返すので、第 1 値だけを見る。
(deftest completion-case-exact-name-is-solo ()
  (unwind-protect
      (let ((dir (compcase-setup)))
        (values
         (*do-completion (concat (namestring dir) "/Zz-alpha") :exist-file-name)))
    (compcase-teardown))
  => :solo-match)
