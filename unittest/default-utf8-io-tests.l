;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;; `open` と `load` の既定エンコーディングが UTF-8 であること。

(defvar *default-utf8-test-dir* (merge-pathnames "unittest/data/default-utf8/" (si:system-root)))
(defvar *default-utf8-test-file* (merge-pathnames "utf8-no-marker.l" *default-utf8-test-dir*))
(defvar default-utf8-test-loaded nil)

(defun default-utf8-test-setup ()
  (let ((dir *default-utf8-test-dir*))
    (unless (file-directory-p dir)
      (create-directory dir))
    (with-open-file (s *default-utf8-test-file*
                       :direction :output
                       :if-exists :supersede
                       :encoding :utf8)
      (format s "(setq default-utf8-test-loaded ~S)~%" "日本語"))
    *default-utf8-test-file*))

(defun default-utf8-test-teardown ()
  (when (file-exist-p *default-utf8-test-file*)
    (delete-file *default-utf8-test-file*))
  (when (file-directory-p *default-utf8-test-dir*)
    (let ((files (directory *default-utf8-test-dir* :absolute t)))
      (dolist (f files)
        (when (file-exist-p f)
          (delete-file f))))
    (delete-directory *default-utf8-test-dir*)))

(deftest open-default-utf8 ()
  "open 時に :encoding を指定しなくても UTF-8 のファイルを文字化けせず読める"
  (unwind-protect
      (progn
        (default-utf8-test-setup)
        (with-open-file (s *default-utf8-test-file* :direction :input)
          (let ((line (read-line s nil :eof)))
            line)))
    (default-utf8-test-teardown))
  => "(setq default-utf8-test-loaded \"日本語\")")

(deftest load-default-utf8 ()
  "load 時に :encoding を指定しなくても UTF-8 のファイルを化けずに読める"
  (unwind-protect
      (progn
        (default-utf8-test-setup)
        (setq default-utf8-test-loaded nil)
        (load *default-utf8-test-file* :verbose nil :print nil)
        default-utf8-test-loaded)
    (default-utf8-test-teardown))
  => "日本語")
