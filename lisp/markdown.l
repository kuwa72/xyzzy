;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; markdown-mode: Markdown editing support
;;;

(provide "markdown")

(in-package "editor")

(require "re-kwd")

(export '(*markdown-mode-hook* *markdown-mode-map*
	  markdown-mode
	  markdown-heading-next markdown-heading-previous
	  markdown-heading-up markdown-heading-forward markdown-heading-backward
	  markdown-heading-promote markdown-heading-demote
	  markdown-toggle-bold markdown-toggle-italic markdown-toggle-code
	  markdown-insert-link markdown-insert-heading
	  markdown-continue-list markdown-toggle-checkbox
	  markdown-follow-link))

(defvar *markdown-mode-hook* nil)
(defvar *markdown-mode-map* nil)

(unless *markdown-mode-map*
  (setq *markdown-mode-map* (make-sparse-keymap))
  ;; Heading navigation
  (define-key *markdown-mode-map* '(#\C-c #\C-n) 'markdown-heading-next)
  (define-key *markdown-mode-map* '(#\C-c #\C-p) 'markdown-heading-previous)
  (define-key *markdown-mode-map* '(#\C-c #\C-u) 'markdown-heading-up)
  (define-key *markdown-mode-map* '(#\C-c #\C-f) 'markdown-heading-forward)
  (define-key *markdown-mode-map* '(#\C-c #\C-b) 'markdown-heading-backward)
  ;; Heading promote/demote
  (define-key *markdown-mode-map* '(#\C-c #\C-=) 'markdown-heading-promote)
  (define-key *markdown-mode-map* '(#\C-c #\C--) 'markdown-heading-demote)
  ;; Style toggles (C-c C-s prefix)
  (define-key *markdown-mode-map* '(#\C-c #\C-s #\b) 'markdown-toggle-bold)
  (define-key *markdown-mode-map* '(#\C-c #\C-s #\i) 'markdown-toggle-italic)
  (define-key *markdown-mode-map* '(#\C-c #\C-s #\c) 'markdown-toggle-code)
  (define-key *markdown-mode-map* '(#\C-c #\C-s #\h) 'markdown-insert-heading)
  ;; Insert
  (define-key *markdown-mode-map* '(#\C-c #\C-l) 'markdown-insert-link)
  ;; List continuation
  (define-key *markdown-mode-map* #\M-RET 'markdown-continue-list)
  ;; Checkbox
  (define-key *markdown-mode-map* '(#\C-c #\C-x) 'markdown-toggle-checkbox)
  ;; Link follow
  (define-key *markdown-mode-map* '(#\C-c #\C-o) 'markdown-follow-link))


;;; ============================================================
;;; Regexp keyword highlighting
;;; ============================================================

(defvar *markdown-regexp-keyword-list* nil)

(defun markdown-setup-keywords ()
  (unless *markdown-regexp-keyword-list*
    (setq *markdown-regexp-keyword-list*
	  (compile-regexp-keyword-list
	   '(;; Headings: keyword1 = cyan on ncurses, blue on Win32
	     ("^#+[ \t].*$" nil 0)
	     ;; Fenced code blocks
	     ("^```.*$" nil :string)
	     ;; Inline code
	     ("`[^`\n]+`" nil :string)
	     ;; Bold
	     ("\\*\\*[^*\n]+\\*\\*" nil (:keyword 2 :bold))
	     ("__[^_\n]+__" nil (:keyword 2 :bold))
	     ;; Links [text](url) and images ![alt](url)
	     ("!?\\[\\([^\]\n]*\\)\\](\\([^)\n]*\\))" nil (:keyword :string :underline))
	     ;; Blockquote
	     ("^>+ .*$" nil :comment)
	     ;; Horizontal rules
	     ("^\\(---+\\|\\*\\*\\*+\\|___+\\)$" nil :comment)
	     ))))
  *markdown-regexp-keyword-list*)


;;; ============================================================
;;; Mode definition
;;; ============================================================

(defun markdown-mode ()
  (interactive)
  (kill-all-local-variables)
  (setq mode-name "Markdown")
  (setq buffer-mode 'markdown-mode)
  (use-keymap *markdown-mode-map*)
  (setq need-not-save nil)
  (setq auto-save t)
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list (markdown-setup-keywords))
  (make-local-variable 'paragraph-start)
  (setq paragraph-start "^$\\|^#\\|^[-*+] \\|^[0-9]+\\. \\|^>\\|^```")
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate "^$\\|^```")
  (run-hooks '*markdown-mode-hook*))


;;; ============================================================
;;; Heading navigation
;;; ============================================================

(defun markdown-heading-regexp ()
  "^#+ ")

(defun markdown-current-heading-level ()
  (save-excursion
    (goto-bol)
    (if (looking-at "^\\(#+\\) ")
	(length (match-string 1))
      0)))

(defun markdown-heading-next ()
  (interactive)
  (forward-line 1)
  (unless (scan-buffer (markdown-heading-regexp) :regexp t :tail nil)
    (message "No more headings")))

(defun markdown-heading-previous ()
  (interactive)
  (goto-bol)
  (unless (scan-buffer (markdown-heading-regexp) :regexp t :reverse t :tail nil)
    (message "No more headings")))

(defun markdown-heading-up ()
  (interactive)
  (let ((level (markdown-current-heading-level)))
    (when (zerop level)
      ;; Not on a heading; find the current heading first
      (save-excursion
	(when (scan-buffer (markdown-heading-regexp) :regexp t :reverse t :tail nil)
	  (setq level (markdown-current-heading-level)))))
    (if (> level 1)
	(let ((target (format nil "^~A " (make-sequence 'string (1- level)
							:initial-element #\#))))
	  (goto-bol)
	  (unless (scan-buffer target :regexp t :reverse t :tail nil)
	    (message "No parent heading")))
      (message "Already at top level"))))

(defun markdown-heading-forward ()
  (interactive)
  (let ((level (markdown-current-heading-level)))
    (when (zerop level)
      (message "Not on a heading")
      (return-from markdown-heading-forward))
    (let ((target (format nil "^~A " (make-sequence 'string level
						    :initial-element #\#))))
      (forward-line 1)
      (unless (scan-buffer target :regexp t :tail nil)
	(message "No next sibling heading")))))

(defun markdown-heading-backward ()
  (interactive)
  (let ((level (markdown-current-heading-level)))
    (when (zerop level)
      (message "Not on a heading")
      (return-from markdown-heading-backward))
    (let ((target (format nil "^~A " (make-sequence 'string level
						    :initial-element #\#))))
      (goto-bol)
      (unless (scan-buffer target :regexp t :reverse t :tail nil)
	(message "No previous sibling heading")))))


;;; ============================================================
;;; Heading promote/demote
;;; ============================================================

(defun markdown-heading-promote ()
  (interactive)
  (save-excursion
    (goto-bol)
    (when (looking-at "^## ")
      (delete-char 1)
      (message "Promoted to h%d" (1- (markdown-current-heading-level))))
    (when (looking-at "^##+ ")
      (delete-char 1)
      (message "Promoted to h%d" (markdown-current-heading-level)))))

(defun markdown-heading-demote ()
  (interactive)
  (save-excursion
    (goto-bol)
    (when (looking-at "^\\(#+\\) ")
      (let ((level (length (match-string 1))))
	(if (>= level 6)
	    (message "Already at h6")
	  (progn
	    (insert "#")
	    (message "Demoted to h%d" (1+ level))))))))


;;; ============================================================
;;; Style toggles
;;; ============================================================

(defun markdown-toggle-markup (before after)
  (let ((blen (length before))
	(alen (length after)))
    (if (pre-selection-p)
	(let ((start (selection-mark))
	      (end (selection-point)))
	  (when (> start end) (rotatef start end))
	  (stop-selection)
	  ;; Check if already wrapped
	  (save-excursion
	    (goto-char start)
	    (if (and (looking-at (regexp-quote before))
		     (progn (goto-char (- end blen))
			    (looking-at (regexp-quote after))))
		;; Remove markup
		(progn
		  (goto-char (- end blen))
		  (delete-char alen)
		  (goto-char start)
		  (delete-char blen))
	      ;; Add markup
	      (progn
		(goto-char end)
		(insert after)
		(goto-char start)
		(insert before)))))
      ;; No selection: insert pair and position between
      (insert before after)
      (backward-char alen))))

(defun markdown-toggle-bold ()
  (interactive)
  (markdown-toggle-markup "**" "**"))

(defun markdown-toggle-italic ()
  (interactive)
  (markdown-toggle-markup "*" "*"))

(defun markdown-toggle-code ()
  (interactive)
  (markdown-toggle-markup "`" "`"))


;;; ============================================================
;;; Insert commands
;;; ============================================================

(defun markdown-insert-heading ()
  (interactive)
  (goto-bol)
  (if (looking-at "^\\(#+\\) ")
      (let ((level (length (match-string 1))))
	(if (>= level 6)
	    ;; Cycle back to h1
	    (progn
	      (delete-region (point) (match-end 1))
	      (insert "#"))
	  (insert "#")))
    (insert "# ")))

(defun markdown-insert-link ()
  (interactive)
  (let* ((text (if (pre-selection-p)
		   (let ((s (selection-mark))
			 (e (selection-point)))
		     (when (> s e) (rotatef s e))
		     (stop-selection)
		     (prog1 (buffer-substring s e)
		       (delete-region s e)))
		 (read-string "Link text: ")))
	 (url (read-string "URL: ")))
    (insert (format nil "[~A](~A)" text url))))


;;; ============================================================
;;; List continuation
;;; ============================================================

(defun markdown-continue-list ()
  (interactive)
  (goto-eol)
  (let ((marker nil)
	(indent ""))
    (save-excursion
      (goto-bol)
      (cond
       ;; Checkbox list
       ((looking-at "^\\([ \t]*\\)\\([-*+]\\) \\[[ xX]\\] ")
	(setq indent (match-string 1))
	(setq marker (format nil "~A [ ] " (match-string 2))))
       ;; Unordered list
       ((looking-at "^\\([ \t]*\\)\\([-*+]\\) ")
	(setq indent (match-string 1))
	(setq marker (format nil "~A " (match-string 2))))
       ;; Ordered list
       ((looking-at "^\\([ \t]*\\)\\([0-9]+\\)\\. ")
	(setq indent (match-string 1))
	(setq marker (format nil "~D. " (1+ (parse-integer (match-string 2))))))))
    (insert "\n")
    (when marker
      (insert indent marker))))


;;; ============================================================
;;; Checkbox toggle
;;; ============================================================

(defun markdown-toggle-checkbox ()
  (interactive)
  (save-excursion
    (goto-bol)
    (cond
     ((scan-buffer "\\[ \\]" :regexp t :limit (save-excursion (goto-eol) (point)))
      (goto-char (match-beginning 0))
      (delete-char 3)
      (insert "[x]"))
     ((scan-buffer "\\[[xX]\\]" :regexp t :limit (save-excursion (goto-eol) (point)))
      (goto-char (match-beginning 0))
      (delete-char 3)
      (insert "[ ]"))
     (t (message "No checkbox on this line")))))


;;; ============================================================
;;; Link following
;;; ============================================================

(defun markdown-follow-link ()
  (interactive)
  (save-excursion
    (goto-bol)
    (if (scan-buffer "\\[\\([^\]\n]*\\)\\](\\([^)\n]*\\))"
		     :regexp t
		     :limit (save-excursion (goto-eol) (point)))
	(let ((url (match-string 2)))
	  (cond
	   ;; HTTP/HTTPS URL
	   ((string-match "^https?://" url)
	    #+unix (call-process (format nil "xdg-open '~A'" url)
				 :no-std-handles t)
	    #-unix (shell-execute url)
	    (message "Opening ~A" url))
	   ;; Local file
	   ((file-exist-p url)
	    (find-file url))
	   (t (message "Cannot follow: ~A" url))))
      (message "No link on this line"))))
