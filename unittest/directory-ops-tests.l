;;; -*- Encoding: utf-8 -*-
;;; ディレクトリを作る・並べる経路。**core が OS へ渡す直前のパスの形**を測る。
;;;
;;; ここが無かったので、POSIX ビルドで次の 3 つが誰にも気付かれずに壊れていた:
;;;   * 多段の `create-directory' が何も作らずに t を返す
;;;   * カレントディレクトリに `\home\kuwa72\...` というゴミが出来る
;;;   * `(directory "/")' が nil を返す
;;; いずれも「パスを `\` に直してから OS に渡す」ことが原因で、Win32 では
;;; `/` も `\` も区切りなので表に出ない。**プラットフォームの違いが結果に
;;; 出る場所なので、両方で同じことを聞く形で書いてある。**

(defun dirops-test-root ()
  (merge-pathnames "unittest/data/dirops/" (si:system-root)))

(defun dirops-cleanup ()
  (let ((root (dirops-test-root)))
    (when (file-directory-p root)
      ;; 深い方から消す。delete-directory は空でないと消せない。
      (dolist (d (sort (directory root :recursive t :absolute t :file-only nil)
                       #'> :key #'length))
        (when (file-directory-p d)
          (ignore-errors (delete-directory d))))
      (ignore-errors (delete-directory root)))))

;; 多段のディレクトリを作ると、葉まで本当に出来ているか。
;; 戻り値が t でも中身が無い、という壊れ方をしていたので両方見る。
(deftest create-directory-nested ()
  (unwind-protect
      (let* ((root (dirops-test-root))
             (leaf (merge-pathnames "a/b/c/" root)))
        (dirops-cleanup)
        (list (and (create-directory leaf) t)
              (and (file-directory-p leaf) t)
              (and (file-directory-p (merge-pathnames "a/b/" root)) t)))
    (dirops-cleanup))
  => (t t t))

;; 区切りを `\` で書いても同じ場所に出来るか。**`\` を名前の一部として
;; OS に渡すと、ここでカレントディレクトリにゴミが出来る。**
(deftest create-directory-backslash-separator ()
  (unwind-protect
      ;; namestring は末尾の / を落とすので自分で足す
      (let* ((root (dirops-test-root))
             (leaf (concat (namestring root) "/x\\y")))
        (dirops-cleanup)
        (create-directory leaf)
        (list (and (file-directory-p (merge-pathnames "x/y/" root)) t)
              ;; ゴミが出来ていないこと。名前に区切りが残っていたら、
              ;; それは 1 個のディレクトリ名として作られてしまった証拠。
              (and (member "x\\y" (directory root) :test #'string=) t)))
    (dirops-cleanup))
  => (t nil))

;; 作ったものが directory に出てくるか (FindFirstFile / FindNextFile の往復)
(deftest create-directory-then-list ()
  (unwind-protect
      (let ((root (dirops-test-root)))
        (dirops-cleanup)
        (create-directory (merge-pathnames "one/" root))
        (create-directory (merge-pathnames "two/" root))
        (sort (directory root) #'string<))
    (dirops-cleanup))
  => ("one/" "two/"))

;; ルートディレクトリが並べられるか。**区切り 1 個だけのパスは
;; 「区切りを切り落とす」実装で空文字列になり、必ず失敗する。**
(deftest directory-root-not-empty ()
  (and (directory "/") t)
  => t)

;; 既にあるディレクトリを作ろうとしたらエラーになるか。**戻り値だけを
;; 見ると通ってしまう**ので、エラーになることと `:if-exists :skip' で
;; 通ることを別々に見る。
;;
;; POSIX では errno を Win32 のコードと突き合わせていたため、`EEXIST' (17) が
;; `ERROR_FILE_EXISTS' (80) にも `ERROR_ALREADY_EXISTS' (183) にも一致せず、
;; **エラーにならず t が返っていた** (Windows では "File already exists.")。
(deftest create-directory-existing-signals ()
  (unwind-protect
      (let ((root (dirops-test-root)))
        (dirops-cleanup)
        (create-directory root)
        (list (handler-case (progn (create-directory root) :no-error)
                (file-error () :file-error))
              (create-directory root :if-exists :skip)))
    (dirops-cleanup))
  => (:file-error t))

;; エラーの文言が、その環境で意味を持たないものになっていないか。
;;
;; **期待値を文言そのもので書かない** (環境で変わる)。代わりに「出てはいけない
;; もの」を見る。POSIX では `GetLastError ()' が errno を返すのに、それを
;; Win32 のコードとして引いていたので、ファイルのエラーが
;;   * ソケットの表に当たって "Non-Authoritative; Host not found, or SERVERFAIL"
;;     (WSA* 定数が POSIX では errno そのものなので、ENOENT の 2 が
;;      WSATRY_AGAIN の 2 に当たる)
;;   * あるいは "Undocumented win32 error: 39"
;; になっていた。**どちらもファイル操作の説明として成立しない。**
(deftest file-error-message-is-not-nonsense ()
  (let ((msg (handler-case
                 (progn (delete-file "/nonexistent-dir-for-xyzzy-test/a") nil)
               (file-error (e) (format nil "~A" e)))))
    (list (and msg t)
          (not (and msg (string-match "Undocumented win32 error" msg)))
          (not (and msg (string-match "SERVERFAIL" msg)))))
  => (t t t))
