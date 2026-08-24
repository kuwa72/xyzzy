;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; Simple Git integration for xyzzy
;;;

(provide "git")

(in-package "editor")

(require "project")
(require "diff")

(export '(git-status
	  git-diff
	  git-log
	  git-blame
	  git-status-mode
	  *git-status-mode-map*))

(defvar *git-status-mode-map* nil)
(unless *git-status-mode-map*
  (setq *git-status-mode-map* (make-sparse-keymap))
  (define-key *git-status-mode-map* #\q 'kill-selected-buffer)
  (define-key *git-status-mode-map* #\g 'git-status)
  (define-key *git-status-mode-map* #\d 'git-diff)
  (define-key *git-status-mode-map* #\l 'git-log)
  (define-key *git-status-mode-map* #\RET 'git-status-open-file))

(defun git-status-mode ()
  (setq mode-name "Git-Status")
  (setq buffer-mode 'git-status-mode)
  (use-keymap *git-status-mode-map*)
  (setq need-not-save t)
  (setq auto-save nil)
  (setq kept-undo-information nil)
  (setq buffer-read-only t))

(defun git-run-command-to-buffer (buffer-name cmd-args &optional dir)
  "指定ディレクトリで Git コマンドを実行し、出力をバッファに書き込む。"
  (let* ((work-dir (or dir (project-current-root)))
	 (buf (get-buffer-create buffer-name)))
    (save-excursion
      (set-buffer buf)
      (let ((buffer-read-only nil))
	(erase-buffer buf)
	(let ((default-dir (default-directory)))
	  (set-default-directory work-dir)
	  (call-process (format nil "git ~A" cmd-args) :output buf :show :hide)
	  (set-default-directory default-dir))))
    buf))

(defun git-status (&optional dir)
  "プロジェクトルートで git status を実行し、一覧を表示する。"
  (interactive)
  (let* ((work-dir (or dir (project-current-root)))
	 (buf (git-run-command-to-buffer "*git status*" "status --short --branch" work-dir)))
    (pop-to-buffer buf)
    (git-status-mode)
    (goto-char (point-min))
    (message "Git status for ~A (q:quit, g:refresh, d:diff, l:log, RET:open)" work-dir)))

(defun git-status-open-file ()
  "git-status バッファ内のカーソル行のファイルを開く。"
  (interactive)
  (let* ((line (buffer-substring (progn (goto-bol) (point))
				 (progn (goto-eol) (point))))
	 (root (project-current-root)))
    (when (and line (> (length line) 3))
      (let ((rel-file (string-trim " " (subseq line 3))))
	(when (and rel-file (not (string= rel-file "")))
	  (let ((full-path (merge-pathnames rel-file root)))
	    (when (file-exist-p full-path)
	      (find-file full-path))))))))

(defun git-diff (&optional file)
  "Git 差分を表示する。file が指定されていればそのファイル、なければプロジェクト全体。"
  (interactive)
  (let* ((target-file (or file (get-buffer-file-name)))
	 (root (project-current-root))
	 (args (if target-file
		   (format nil "diff -- \"~A\"" target-file)
		 "diff"))
	 (buf (git-run-command-to-buffer "*git diff*" args root)))
    (pop-to-buffer buf)
    (when (fboundp 'diff-mode)
      (diff-mode))
    (goto-char (point-min))
    (message "Git diff for ~A" (or target-file root))))

(defun git-log (&optional count)
  "直近のコミットログを表示する。"
  (interactive)
  (let* ((n (or count 50))
	 (root (project-current-root))
	 (buf (git-run-command-to-buffer "*git log*"
					(format nil "log --graph --oneline --decorate -n ~D" n)
					root)))
    (pop-to-buffer buf)
    (setq buffer-read-only t)
    (goto-char (point-min))
    (message "Git log for ~A" root)))

(defun git-blame (&optional file)
  "現在のファイルの git blame を表示する。"
  (interactive)
  (let ((target (or file (get-buffer-file-name))))
    (unless target
      (message "No file associated with current buffer.")
      (return-from git-blame nil))
    (let* ((root (project-current-root))
	   (buf (git-run-command-to-buffer "*git blame*"
					  (format nil "blame -- \"~A\"" target)
					  root)))
      (pop-to-buffer buf)
      (setq buffer-read-only t)
      (goto-char (point-min))
      (message "Git blame for ~A" target))))

;;;
;;; Leader Key への登録
;;;

(when (boundp '*leader-git-map*)
  (define-key *leader-git-map* #\s 'git-status)
  (define-key *leader-git-map* #\d 'git-diff)
  (define-key *leader-git-map* #\l 'git-log)
  (define-key *leader-git-map* #\b 'git-blame)

  (when (fboundp 'which-key-add-description)
    (which-key-add-description 'git-status "Status")
    (which-key-add-description 'git-diff "Diff")
    (which-key-add-description 'git-log "Log")
    (which-key-add-description 'git-blame "Blame")))
