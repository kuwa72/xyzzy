(require "leader")
(require "project")
(require "git")
(require "terminal")

(in-package "editor")

(defvar *symbols-to-check*
  '(find-file
    recentf-open
    save-buffer
    write-file
    open-filer
    switch-to-buffer
    kill-selected-buffer
    list-buffers
    revert-buffer
    next-buffer
    previous-buffer
    isearch-forward
    isearch-backward
    grep
    query-replace
    toggle-truncate-lines
    toggle-line-number
    calc
    split-window
    split-window-vertically
    split-window-horizontally
    split-window-below
    split-window-right
    other-window
    delete-window
    delete-other-windows
    describe-key
    describe-function
    describe-variable
    describe-bindings
    apropos
    project-find-file
    project-grep
    project-filer
    project-open-terminal
    project-switch-project
    git-status
    git-diff
    git-log
    git-blame
    toggle-terminal-drawer))

(let ((logfile (format nil "~Asymbol-check.txt" (si:system-root)))
      (missing nil))
  (with-open-file (out logfile :direction :output :if-exists :supersede)
    (dolist (sym *symbols-to-check*)
      (let ((bound (or (fboundp sym) (autoload-function-p sym))))
        (format out "~30A : ~:[MISSING ***~;OK~]~%" sym bound)
        (unless bound
          (push sym missing))))
    (if missing
        (format out "~%FAILED: ~D symbols are MISSING:~%~{  ~A~%~}"
                (length missing) (nreverse missing))
      (format out "~%All ~D symbols are defined or autoloaded.~%" (length *symbols-to-check*))))
  ;; kill-xyzzy must run after with-open-file's unwind-protect has closed
  ;; and flushed the stream, or the log file ends up empty/missing.
  (kill-xyzzy (null missing)))
