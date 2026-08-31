;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; `rename-file' の `:if-exists'。
;;;
;;; **POSIX では `:if-exists` が一度も見られていなかった** (issue #170)。
;;; `Frename_file` は「`MoveFile` が失敗したこと」で行き先の存在を知るが、
;;; `WINFS::MoveFile` が `rename` をそのまま呼んでいて、**POSIX の `rename` は
;;; 行き先があっても成功して上書きする。** 既定は `:if-exists :error` なので、
;;; **何も指定しなければエラーになるはずのものが、相手のファイルを消していた。**
;;;
;;; 直す前に測ったもの (linux ネイティブビルド。`from.txt` に "FROM"、
;;; `to.txt` に "TO" を入れて `(rename-file from to :if-exists MODE)`):
;;;
;;;   MODE          戻り値  エラー  from が残る  to の中身
;;;   :error        t       なし    いいえ       "FROM"   <- 消している
;;;   :skip         t       なし    いいえ       "FROM"   <- 消している
;;;   :overwrite    t       なし    いいえ       "FROM"
;;;
;;; **3 つとも同じ動作**で、`:overwrite` だけが正しかった。
;;;
;;; 直したのは `WINFS::MoveFile` の側 (Win32 の約束に揃えて、行き先があれば
;;; 失敗する)。**同じ前提に乗っている呼び出しが他にもある**ので、そちらも
;;; 一緒に直る: `src/core/fileio.cc` のバックアップ名の候補を 1 つずつ試す
;;; loop は、上書きされると最初の候補で必ず成功するため**既にある
;;; バックアップを潰していた。**
;;;
;;; **ここは両方のプラットフォームで同じことを聞く。** Win32 は元から
;;; こう動いていたので、これは「POSIX を Win32 に合わせた」テストである。

(defun rename-file-test-with-pair (fn)
  "`from.txt` (中身 FROM) と `to.txt` (中身 TO) を作って FN に渡す。
FN は (from to dir) を受ける。"
  (let ((dir (make-temp-file-name nil nil nil t)))
    (unwind-protect
        (let ((from (concat dir "/from.txt"))
              (to (concat dir "/to.txt")))
          (with-open-file (s from :direction :output :if-does-not-exist :create
                             :if-exists :overwrite)
            (format s "FROM~%"))
          (with-open-file (s to :direction :output :if-does-not-exist :create
                             :if-exists :overwrite)
            (format s "TO~%"))
          (funcall fn from to (concat dir "/")))
      (progn
        (dolist (f (directory dir :absolute t))
          (ignore-errors (delete-file f)))
        (ignore-errors (delete-directory dir))))))

(defun rename-file-test-first-line (file)
  (with-open-file (s file :direction :input)
    (read-line s nil)))

(defun rename-file-test-try (mode)
  "MODE で rename して、(エラーが出たか from が残っているか to の中身) を返す。"
  (rename-file-test-with-pair
    #'(lambda (from to dir)
        (multiple-value-bind (v e)
            (ignore-errors (rename-file from to :if-exists mode))
          (list (and e t)
                (and (file-exist-p from) t)
                (rename-file-test-first-line to))))))

(deftest rename-file-if-exists-error-does-not-destroy-the-target ()
  "**これが本体。** 既定の `:error` は**エラーを出して、行き先を残す。**
以前は POSIX で行き先を黙って消していた。"
  (rename-file-test-try :error)
  => (t t "TO"))

(deftest rename-file-if-exists-error-is-the-default ()
  "`:if-exists` を省いたときも同じであること。**省略時が一番よく通る道**で、
そこが壊れていた。"
  (rename-file-test-with-pair
    #'(lambda (from to dir)
        (multiple-value-bind (v e)
            (ignore-errors (rename-file from to))
          (list (and e t)
                (and (file-exist-p from) t)
                (rename-file-test-first-line to)))))
  => (t t "TO"))

(deftest rename-file-if-exists-skip-leaves-both-files ()
  "`:skip` は nil を返して、どちらのファイルにも触らない。"
  (rename-file-test-try :skip)
  => (nil t "TO"))

(deftest rename-file-if-exists-overwrite-replaces-the-target ()
  "`:overwrite` は置き換える。**ここだけは直す前から正しかった** (POSIX の
`rename` の動作がたまたま一致していた)。"
  (rename-file-test-try :overwrite)
  => (nil nil "FROM"))

(deftest rename-file-to-a-new-name-works ()
  "行き先が無い普通の場合。**上の直しで壊していないことを見る側。**"
  (rename-file-test-with-pair
    #'(lambda (from to dir)
        (let ((new (concat dir "new.txt")))
          (list (and (rename-file from new) t)
                (and (file-exist-p from) t)
                (rename-file-test-first-line new)))))
  => (t nil "FROM"))

(deftest rename-file-rejects-an-unknown-if-exists ()
  "知らない値は `:if-exists` のエラーになること。**行き先を触る前に断る。**"
  (rename-file-test-with-pair
    #'(lambda (from to dir)
        (multiple-value-bind (v e)
            (ignore-errors (rename-file from to :if-exists :no-such-option))
          (list (and e t)
                (rename-file-test-first-line to)))))
  => (t "TO"))

(deftest rename-file-to-itself-succeeds ()
  "**同じ名前への rename は成功する。** Win32 の `MoveFileW` が同じ名前を
受けるのでそうなっており、`WINFS::MoveFile` を「行き先があれば失敗する」に
揃えたときに**ここだけ答えが分かれた** (POSIX で `file-exists` になった)。

POSIX の `rename` も「2 つの名前が同じファイルへのリンクなら成功して何も
しない」と決まっているので、同じ inode を指していれば成功にしてある。"
  (rename-file-test-with-pair
    #'(lambda (from to dir)
        (list (and (rename-file from from) t)
              (and (file-exist-p from) t)
              (rename-file-test-first-line from))))
  => (t t "FROM"))
