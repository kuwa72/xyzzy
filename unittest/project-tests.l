;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Tests for Project Management (project.l)
;;;

(unless (member "test-helpers" *modules* :test #'string=)
  (load-file (merge-pathnames "test-helpers.l" (directory-namestring *load-pathname*))))
(require "leader")
(require "project")

(in-package "editor")

(defun test-project-root-detection ()
  ;; 現在のリポジトリルート（CMakeLists.txt や .git がある）を正しく検出できるか
  (let ((root (project-current-root (si:system-root))))
    (assert-true (stringp root))
    (assert-true (file-exist-p (merge-pathnames "CMakeLists.txt" root)))))

(defun test-project-remember-list ()
  (let ((*project-list* nil))
    (project-remember-project "Z:/work/")
    (project-remember-project "Z:/foo/bar/")
    (assert-equal 2 (length *project-list*))
    ;; 重複追加の防止
    (project-remember-project "Z:/work/")
    (assert-equal 2 (length *project-list*))
    (assert-equal "Z:/work/" (car *project-list*))))

;; test-project-list-files 用のフィクスチャ。以前はリポジトリ全体
;; (2000+ファイル) を直接対象にしていたが、32bit MSVC の CI で
;; project-list-files がリポジトリ全体を正しく (=以前より遥かに多く)
;; 見つけるようになった際にメモリ不足でクラッシュした。project-list-files
;; の再帰・除外ロジックを検証するのに巨大な対象は不要なので、専用の
;; 小さなディレクトリに切り出す。
(defun project-test-fixture-root ()
  ;; merge-pathnames は、第1引数がそれ自体 "/" を含む複数階層のパスで
  ;; 末尾も "/" の場合、末尾の "/" を落とすことがある (実測済み)。単純な
  ;; 文字列連結ならその心配が無いので concat を使う。
  (concat (si:system-root) "unittest/data/project-fixture/"))

(defun project-test-fixture-write (path content)
  (with-open-file (s path :direction :output :if-exists :supersede)
    (princ content s)))

(defun project-test-fixture-setup ()
  (let* ((root (project-test-fixture-root))
	 (sub (concat root "sub/"))
	 (ignored (concat root "node_modules/")))
    (unless (file-directory-p root) (create-directory root))
    (unless (file-directory-p sub) (create-directory sub))
    (unless (file-directory-p ignored) (create-directory ignored))
    (project-test-fixture-write (merge-pathnames ".project" root) "marker")
    (project-test-fixture-write (merge-pathnames "a.txt" root) "a")
    (project-test-fixture-write (merge-pathnames "b.txt" sub) "b")
    (project-test-fixture-write (merge-pathnames "ignored.txt" ignored) "ignored")
    root))

(defun project-test-fixture-teardown ()
  (let ((root (project-test-fixture-root)))
    (when (file-directory-p root)
      (dolist (f (directory root :recursive t :file-only t :absolute t))
	(delete-file f :if-does-not-exist :skip))
      ;; 深い方から消さないと空でないディレクトリの削除に失敗する。
      (dolist (d (sort (directory root :recursive t :directory-only t :absolute t)
			#'>  :key #'(lambda (p) (length (namestring p)))))
	(delete-directory d :if-does-not-exist :skip))
      (delete-directory root :if-does-not-exist :skip))))

(defun test-project-leader-bindings ()
  (assert-equal 'project-find-file (lookup-keymap *leader-project-map* #\f))
  (assert-equal 'project-grep (lookup-keymap *leader-project-map* #\g))
  (assert-equal 'project-filer (lookup-keymap *leader-project-map* #\d))
  (assert-equal 'project-open-terminal (lookup-keymap *leader-project-map* #\t))
  (assert-equal 'project-switch-project (lookup-keymap *leader-project-map* #\p)))

(defun run-project-unit-tests ()
  ;; TODO(debug): 診断用のブレッドクラム。MSVC x86 の CI がこのファイルの
  ;; 実行開始直後に原因不明のメモリ不足で落ちる問題を追跡するためのもの。
  ;; 原因が判明したらこの関数全体をシンプルな形に戻すこと。
  (format t "Running project unit tests...~%") (finish-output)
  (format t "[debug] before test-project-root-detection~%") (finish-output)
  (test-project-root-detection)
  (format t "[debug] after test-project-root-detection~%") (finish-output)
  (test-project-remember-list)
  (format t "[debug] after test-project-remember-list~%") (finish-output)
  (format t "[debug] before fixture setup~%") (finish-output)
  (let ((root (project-test-fixture-setup)))
    (format t "[debug] fixture created at ~S~%" root) (finish-output)
    (unwind-protect
	(let ((files (project-list-files root)))
	  (format t "[debug] project-list-files returned ~D files~%" (length files)) (finish-output)
	  (assert-true (consp files))
	  (assert-true (member ".project" files :test #'string-equal))
	  (assert-true (member "a.txt" files :test #'string-equal))
	  (assert-true (member "sub/b.txt" files :test #'string-equal))
	  (assert-false (some #'(lambda (f) (string-match "^node_modules/" f)) files))
	  (format t "[debug] test-project-list-files assertions OK~%") (finish-output))
      (project-test-fixture-teardown)))
  (format t "[debug] after test-project-list-files~%") (finish-output)
  (test-project-leader-bindings)
  (format t "[debug] after test-project-leader-bindings~%") (finish-output)
  (format t "All project unit tests PASSED.~%"))

(run-project-unit-tests)
