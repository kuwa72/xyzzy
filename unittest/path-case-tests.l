;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; パス名の突き合わせで大文字小文字を区別するかどうか。
;;;
;;; **POSIX で `path-equal` と `sub-directory-p` が大文字小文字を無視して
;;; いた** (issue #183)。別々に存在する 2 つのファイルを「同じファイル」と
;;; 答える:
;;;
;;;   (path-equal "/tmp/a" "/tmp/A")              => t    (nil であるべき)
;;;   (sub-directory-p "/tmp/Foo/bar" "/tmp/foo") => t    (nil であるべき)
;;;
;;; 判定そのものは正しく移植されていた (`same_file_p` の後段は device +
;;; inode の比較)。**その手前の速い経路** (`pathname_equal`) が
;;; `_wcsnicmp` を直に呼んでいて、POSIX ではそれが `wcsncasecmp` に当たる。
;;;
;;; **区別するかどうかを聞く seam は最初からあった** —
;;; `WINFS::case_insensitive_names` (`src/core/vfs.h`) で、ヘッダのコメントが
;;; 「区別するかどうかはファイルシステムの性質であってフロントエンドの性質
;;; ではない」とまさにこの用途で置かれたことを書いている。使っていたのは
;;; ファイル名補完の 1 箇所だけだった。
;;;
;;; **ここは期待値をプラットフォームで分ける。** 大文字小文字を区別するかは
;;; 本当にファイルシステムの性質が違う所なので、`abbreviate-display-string`
;;; と同じく両方で同じ答えを期待できない。

(defun path-case-test-with-files (fn)
  "同じディレクトリに `a` と `A`、`Foo/bar` と `foo` を作って FN を呼ぶ。
FN は (dir) を受ける。**大文字小文字を区別しないファイルシステムでは
`a` と `A` が同じファイルになる**ので、作れたかどうかも FN に渡さず、
呼ぶ側が `(featurep :unix)` で分ける。"
  (let ((dir (make-temp-file-name nil nil nil t)))
    (unwind-protect
        (progn
          (dolist (name '("a" "A"))
            (with-open-file (s (concat dir "/" name) :direction :output
                               :if-does-not-exist :create :if-exists :overwrite)
              (format s "~A~%" name)))
          (create-directory (concat dir "/Foo") :if-exists :skip)
          (create-directory (concat dir "/Foo/bar") :if-exists :skip)
          (create-directory (concat dir "/foo") :if-exists :skip)
          (funcall fn (concat dir "/")))
      (progn
        ;; 作った順の逆に消す。`delete-directory` は空でないと消せない。
        (dolist (d '("Foo/bar" "foo" "Foo"))
          (ignore-errors (delete-directory (concat dir "/" d))))
        (dolist (f (directory dir :absolute t))
          (ignore-errors (delete-file f)))
        (ignore-errors (delete-directory dir))))))

(deftest path-equal-respects-case-on-a-case-sensitive-filesystem ()
  "**これが本体。** 大文字違いの 2 つのファイルを「同じ」と答えないこと。

POSIX では別のファイルなので nil。Win32 は同じファイルなので t
(そちらでは `a` を作った後に `A` を開くと同じファイルを開き直すだけ)。"
  (path-case-test-with-files
    #'(lambda (dir)
        (let ((r (and (path-equal (concat dir "a") (concat dir "A")) t)))
          ;; **期待値そのものをプラットフォームで分ける。** reader conditional
          ;; (`#+unix`) を使わないのは、`.lc` に焼き付くと片方の
          ;; プラットフォームで作った `.lc` がもう片方で嘘になるため。
          (if (featurep :unix) r (not r)))))
  => nil)

(deftest path-equal-says-yes-for-the-same-path ()
  "同じパスは同じ。**上の直しで壊していないことを見る側。**"
  (path-case-test-with-files
    #'(lambda (dir)
        (and (path-equal (concat dir "a") (concat dir "a")) t)))
  => t)

(deftest sub-directory-p-respects-case-on-a-case-sensitive-filesystem ()
  "`Foo/bar` が `foo` の下だと答えないこと。

**この後に両方がディレクトリであることは確かめているが、それは
「別のディレクトリだ」ということの反証にならない。**"
  (path-case-test-with-files
    #'(lambda (dir)
        (let ((r (and (sub-directory-p (concat dir "Foo/bar")
                                       (concat dir "foo")) t)))
          (if (featurep :unix) r (not r)))))
  => nil)

(deftest sub-directory-p-says-yes-for-the-real-parent ()
  "本当の親子は t。"
  (path-case-test-with-files
    #'(lambda (dir)
        (and (sub-directory-p (concat dir "Foo/bar") (concat dir "Foo")) t)))
  => t)

;;; --- device (ドライブ / UNC のホスト) の突き合わせ -------------------------
;;;
;;; **`platform.h` が `memicmp` を `strncasecmp` の別名にしていた**
;;; (issue #184)。この 2 つは約束が違う: `memicmp` は指定バイト数を必ず
;;; 比べるが、`strncasecmp` は **NUL で止まる。**
;;;
;;; 呼んでいたのは `parse_namestring` が defaults の device と突き合わせる所
;;; で、渡しているのは `ucs4_t` の配列である。リトルエンディアンでは
;;; **先頭 1 文字の次のバイトが 0 なのでそこで止まり、device 全体ではなく
;;; 1 文字目だけを比べていた。**
;;;
;;;   c:  と d:      -> 先頭が違うので偶然合う
;;;   c:  と C:      -> 偶然合う
;;;   //a/b と //x/y -> **どちらも先頭が `/` なので「同じ」になる**
;;;
;;; **ここは両方のプラットフォームで同じ答えを期待できる。** Win32 の
;;; `_memicmp` はバイト数どおり比べるので、元から正しく「違う」と答えて
;;; いた (POSIX のシムだけが壊れていた)。

(deftest merge-pathnames-does-not-confuse-two-unc-hosts ()
  "**別のホストの device に、defaults の trail を継がないこと。**

直す前の POSIX は `\"//x/y/dir\"` を返していた: `//x/y` と `//a/b` を
「同じ device」と見て、defaults の `dir` を被せていた。"
  (merge-pathnames "//x/y" "//a/b/dir/")
  => "//x/y/")

(deftest merge-pathnames-keeps-the-trail-for-the-same-host ()
  "同じホストなら defaults の trail を継ぐ。**上の直しで
「いつも継がない」にしていないことを見る側。**"
  (merge-pathnames "//a/b" "//a/b/dir/")
  => "//a/b/dir")
