;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;;
;;; This file is part of xyzzy.
;;;

(provide "defs")

(in-package "editor")

(export '(mode-line-format mode-specific-indent-command *auto-mode-alist*
	  show-dots ignored-extensions insert-default-directory
	  mode-specific-indent-command *default-buffer-mode*
	  *caret-shape-block* *caret-shape-thin*
	  *caret-shape-half-block* *caret-shape-underline*
	  *initial-buffer-mode* *tab-columns*
	  *kinsoku-mode* *kinsoku-bol-chars* *kinsoku-eol-chars*
	  *kinsoku-extend-limit* *kinsoku-shorten-limit*
	  *fill-kinsoku-mode*
	  *file-dialog-filter* *file-dialog-filter-index*
	  *syntax-option-c-preprocessor* *syntax-option-indent-c++*
	  *syntax-option-indent-java* *syntax-option-column-comment-char*
	  *syntax-option-indent-c++/cli*
	  ))

(or (boundp 'mode-line-format)
    (setq-default mode-line-format "--%*- %b (%M) [%k:%l] %P %f"))

(defvar *auto-mode-alist* '(("\\.c$" . c-mode)
			    ("\\.h$" . detect-c-or-c++-mode)
			    ("\\.cc$" . c++-mode)
			    ("\\.cxx$" . c++-mode)
			    ("\\.cpp$" . c++-mode)
			    ("\\.hxx$" . c++-mode)
			    ("\\.hpp$" . c++-mode)
			    ("\\.inl$" . c++-mode)
			    ("\\.l$" . lisp-mode)
			    ("\\.lisp$" . lisp-mode)
			    ("\\.txt$" . text-mode)
			    ("\\.log$" . text-mode)
			    ("\\.s?html?$" . html+-mode)
			    ("\\.toml$" . toml-mode)
			    ("\\.xml$" . xml-mode)
			    ("\\.xsl$" . xml-mode)
			    ("\\.xslt$" . xml-mode)
			    ("\\.svg$" . xml-mode)
			    ("\\.xsd$" . xml-mode)
			    ("\\.rss$" . xml-mode)
			    ("\\.pas$" . pascal-mode)
			    ("\\.tex$" . LaTeX-mode)
			    ("\\.java$" . java-mode)
			    ("\\.sql$" . sql-mode)
			    ("\\.idl$" . idl-mode)
			    ("\\.pl$" . perl-mode)
			    ("\\.pm$" . perl-mode)
			    ("\\.cgi$" . perl-mode)
			    ("\\.bas$" . basic-mode)
			    ("\\.mb$" . basic-mode)
			    ("\\.frm$" . basic-mode)
			    ("\\.cls$" . basic-mode)
			    ("\\.css$" . css-mode)
			    ("\\.cs$" . csharp-mode)
			    ("\\.sh$" . shell-script-mode)
			    ("\\.bash$" . shell-script-mode)
			    ("\\.zsh$" . shell-script-mode)
			    ("\\.js$" . javascript-mode)
			    ("\\.jsx$" . javascript-mode)
			    ("\\.mjs$" . javascript-mode)
			    ("\\.cjs$" . javascript-mode)
			    ("\\.ts$" . typescript-mode)
			    ("\\.tsx$" . typescript-mode)
			    ("\\.py$" . python-mode)
			    ("\\.pyw$" . python-mode)
			    ("\\.json$" . json-mode)
			    ("\\.jsonc$" . json-mode)
			    ("\\.ya?ml$" . yaml-mode)
			    ("\\.md$" . markdown-mode)
			    ("\\.markdown$" . markdown-mode)
			    ("\\.mk$" . makefile-mode)
			    ("\\(^\\|/\\)Makefile$" . makefile-mode)
			    ("\\.cmake$" . cmake-mode)
			    ("\\(^\\|/\\)CMakeLists\\.txt$" . cmake-mode)
			    ("\\(^\\|/\\)Dockerfile" . dockerfile-mode)
			    ("\\.dockerfile$" . dockerfile-mode)
			   ))

(defvar show-dots nil)

(defvar ignored-extensions
  '("~" ".lc" ".obj" ".lib" ".exe" ".com" ".lzh" ".dll" ".ocx" ".fnt" ".dct"
    ".bmp" ".hlp" ".fon" ".fot" ".ttf" ".wri" ".pif" ".grp" ".wav"))

(or (boundp 'insert-default-directory)
    (setq insert-default-directory t))

(or (boundp 'mode-specific-indent-command)
    (setq mode-specific-indent-command nil))

(defvar *default-buffer-mode* 'fundamental-mode)

(or *initial-buffer-mode*
    (setq *initial-buffer-mode* 'lisp-interaction-mode))

(or *minor-mode-alist*
    (setq *minor-mode-alist*
	  '((auto-fill . "Fill")
	    (overwrite-mode . "Ovrwt"))))

(setq *ime-control* t)
(setq *drag-and-drop-auto-activate* t)

(defvar *file-dialog-filter*
  '(("テキストファイル(*.txt;*.doc;*.log)" . "*.txt;*.doc;*.log")
    ("C/C++(*.c;*.cpp;*.cxx;*.h)" . "*.c;*.cpp;*.cxx;*.cc;*.h;*.hxx")
    ("Lisp(*.l;*.lisp)" . "*.l;*.lisp")
    ("HTML(*.htm;*.html)" . "*.htm;*.html")
    ("すべてのファイル(*.*)" . "*.*")))

(defvar *file-dialog-filter-index* 5)

(or *protected-local-variables*
    (setq *protected-local-variables*
	  '(kept-undo-information
	    need-not-save
	    buffer-read-only
	    auto-save
	    lock-file
	    abbrev-mode)))

(defvar *tab-columns* 8)

(defvar *kinsoku-mode* 15)
(defvar *kinsoku-bol-chars*
  "!),.:;?]}｡｣､･ﾞﾟ、。，．・：；？！゛゜´ヽヾゝゞ々’”）〕］｝〉》」』】＞≫")
(defvar *kinsoku-eol-chars*
  "([{｢｀‘“（〔［｛〈《「『【＜≪")
(defvar *kinsoku-extend-limit* 3)
(defvar *kinsoku-shorten-limit* 10)
(defvar *fill-kinsoku-mode* 15)

(or (boundp '*inverse-mark-line*)
    (setq-default *inverse-mark-line* nil))

(defconstant *caret-shape-block* 0)
(defconstant *caret-shape-thin* 1)
(defconstant *caret-shape-half-block* 2)
(defconstant *caret-shape-underline* 3)

(or *normal-caret-shape*
    (setq *normal-caret-shape* *caret-shape-block*))
(or *overwrite-caret-shape*
    (setq *overwrite-caret-shape* *caret-shape-half-block*))

(or *std-control-up-char*
    (setq *std-control-up-char* #\C-p))
(or *std-control-down-char*
    (setq *std-control-down-char* #\C-n))
(or *std-control-default-char*
    (setq *std-control-default-char* #\C-m))
;; *std-control-prior-char*
;; *std-control-next-char*

(defconstant *syntax-option-c-preprocessor* 1)
(defconstant *syntax-option-indent-c++* 2)
(defconstant *syntax-option-indent-java* 4)
(defconstant *syntax-option-indent-csharp* 8)
(defconstant *syntax-option-column-comment-char* 16)
(defconstant *syntax-option-indent-c++/cli* 32)

(setq-default display-newline-char t)
(setq-default display-first-tab-char t)
(setq-default display-rest-tab-char t)

;; インデントガイドの縦線。**1 桁の文字であること** (2 桁だと桁が合わない)。
;; nil にすると空白のまま = ガイドが出ない。
;; インデントガイドの縦線。**1 桁の文字であること。**
;;
;; 既定を `|` (ASCII) にしているのは、**端末と xyzzy の幅の解釈が一致するのが
;; ASCII だけ**だからである。`│` (U+2502) の方が見た目は良いが、xyzzy は
;; Box Drawing を East Asian Ambiguous として 2 桁に数えるので (eaw.cc の
;; `is_ambiguous`)、そのままでは桁がずれる — 実際、最初これを既定にして
;; 「何も出ない」状態になった (2 桁の字は断るようにしてある)。
;;
;; Ambiguous を 1 桁と解釈する端末なら次のように置ける:
;;   (setq-default display-indent-guide-char (code-char #x2502))
(setq-default display-indent-guide-char #\|)

(setq-default inverse-cursor-line nil)

(export '(*archiver-dll-list* archiver-dll-file-name))

(defconstant *archiver-dll-list*
  '(:7-zip :bga32 :cab32 :ish32 :tar32 :unarj32 :ungca32
    :unlha32 :unrar32 :unzip32 :yz1 :zip32j))

(mapc #'(lambda (x)
	  (setf (get (car x) 'archiver-dll-file-name) (cdr x)))
      '((:ish32 . "ISH32.DLL")
	(:tar32 . "tar32.dll")
	(:unlha32 . "UNLHA32.DLL")
	(:unarj32 . "UNARJ32J.DLL")
	(:unzip32 . "UNZIP32.DLL")
	(:zip32j . "ZIP32J.DLL")
	(:cab32 . "cab32.dll")
	(:unrar32 . "unrar32.dll")
	(:bga32 . "Bga32.dll")
	(:yz1 . "Yz1.dll")
	(:ungca32 . "UnGCA32.dll")
	(:7-zip . "7-zip32.dll")))

(export '(make-tags-file make-tags-file-dialog *maketags-list*))
(autoload 'make-tags-file "maketags" t)
(autoload 'make-tags-file-dialog "maketags" t)
(defvar *maketags-list* nil)

(export 'hanoi)
(autoload 'hanoi "hanoi" t)

(export '(life life-mode))
(autoload 'life "life" t)
(autoload 'life-mode "life" t)

(export '(search-dialog replace-dialog count-matches-dialog
	  goto-line-dialog open-file-dialog
	  close-selected-buffer
	  close-and-open-file-dialog save-as-dialog
	  save-buffer-dialog insert-file-dialog rename-dialog
	  execute-subprocess-dialog pipe-command-dialog
	  launch-application-dialog print-selected-buffer-dialog
	  control-code-dialog-box select-xyzzy))

(autoload 'search-dialog "dialogs" t)
(autoload 'replace-dialog "dialogs" t)
(autoload 'count-matches-dialog "dialogs" t)
(autoload 'goto-line-dialog "dialogs" t)
(autoload 'open-file-dialog "dialogs" t)
(autoload 'close-and-open-file-dialog "dialogs" t)
(autoload 'save-as-dialog "dialogs" t)
(autoload 'close-selected-buffer "dialogs" t)
(autoload 'save-buffer-dialog "dialogs" t)
(autoload 'insert-file-dialog "dialogs" t)
(autoload 'rename-dialog "dialogs" t)
(autoload 'execute-subprocess-dialog "dialogs" t)
(autoload 'pipe-command-dialog "dialogs" t)
(autoload 'launch-application-dialog "dialogs" t)
(autoload 'print-selected-buffer-dialog "dialogs" t)
(autoload 'print-selected-buffer "dialogs" t)
(autoload 'control-code-dialog-box "dialogs" t)
(autoload 'select-xyzzy "dialogs" t)
(autoload 'create-xyzzy-shortcut-dialog "dialogs" t)

(export 'grep-dialog)
(autoload 'grep-dialog "grepd" t)

(export '(c-curve dragon-curve))
(autoload 'c-curve "ccurve" t)
(autoload 'dragon-curve "ccurve" t)

(export 'gomoku)
(autoload 'gomoku "gomoku" t)

(export '(gresreg re-gresreg query-gresreg query-gresreg-regexp))
(autoload 'gresreg "gresreg" t)
(autoload 're-gresreg "gresreg" t)
(autoload 'query-gresreg "gresreg" t)
(autoload 'query-gresreg-regexp "gresreg" t)

(export 'gresreg-dialog)
(autoload 'gresreg-dialog "gresregd" t)

(export 'calendar)
(autoload 'calendar "calendar" t)

(export 'calc)
(autoload 'calc "calc" t)

(export 'html+-mode)
(autoload 'html+-mode "html+-mode" t)

(export 'pascal-mode)
(autoload 'pascal-mode "pascal" t)

(export 'LaTeX-mode)
(autoload 'LaTeX-mode "LaTeX" t)

(export 'java-mode)
(autoload 'java-mode "java" t)
(autoload 'java-maketags "javafns")
(pushnew '(java-maketags "*.java") *maketags-list* :key #'car)

(export 'sql-mode)
(autoload 'sql-mode "sql-mode" t)

(export 'idl-mode)
(autoload 'idl-mode "idl-mode" t)

(export 'view-mode)
(autoload 'view-mode "viewmode" t)

(export 'markdown-mode)
(autoload 'markdown-mode "markdown" t)

(export 'xml-mode)
(autoload 'xml-mode "xml-mode" t)

(export 'toml-mode)
(autoload 'toml-mode "toml-mode" t)

(export 'makefile-mode)
(autoload 'makefile-mode "makefile-mode" t)

(export 'cmake-mode)
(autoload 'cmake-mode "cmake-mode" t)

(export 'dockerfile-mode)
(autoload 'dockerfile-mode "dockerfile-mode" t)

(export '(javascript-mode typescript-mode))
(autoload 'javascript-mode "javascript-mode" t)
(autoload 'typescript-mode "javascript-mode" t)

(export 'shell-script-mode)
(autoload 'shell-script-mode "shell-mode" t)

(export 'python-mode)
(autoload 'python-mode "python-mode" t)

(export 'json-mode)
(autoload 'json-mode "json-mode" t)

(export 'yaml-mode)
(autoload 'yaml-mode "yaml-mode" t)

(export '(*interpreter-mode-alist* find-file-shebang-mode))

(defvar *interpreter-mode-alist*
  '(("sh" . shell-script-mode)
    ("bash" . shell-script-mode)
    ("zsh" . shell-script-mode)
    ("ksh" . shell-script-mode)
    ("dash" . shell-script-mode)
    ("python" . python-mode)
    ("python2" . python-mode)
    ("python3" . python-mode)
    ("perl" . perl-mode)
    ("perl5" . perl-mode)
    ("node" . javascript-mode)))

(defun find-file-shebang-mode ()
  "Detect mode from shebang line. Called as fallback after *auto-mode-alist*."
  (save-excursion
    (goto-char (point-min))
    (when (looking-at "^#![ \t]*\\([^ \t\n]+\\)\\([ \t]+\\([^ \t\n]+\\)\\)?")
      (let* ((cmd (match-string 1))
             (arg (match-string 3))
             (name (file-namestring cmd)))
        ;; Handle #!/usr/bin/env <interpreter>
        (when (string= name "env")
          (setq name arg))
        (when name
          (let ((mode (cdr (assoc name *interpreter-mode-alist*
                                  :test #'string=))))
            (when mode
              (funcall mode))))))))

(export '(dabbrev-expand *dabbrevs-case-fold* *dabbrevs-no-undo*))
(defvar-local *dabbrevs-case-fold* nil)
(defvar *dabbrevs-no-undo* nil)
(autoload 'dabbrev-expand "dabbrev" t)
(autoload 'dabbrev-popup "dabbrev" t)
(define-key ctl-x-map #\/ 'dabbrev-expand)
(define-key ctl-x-map #\\ 'dabbrev-popup)

(export 'shell)
(autoload 'shell "shell" t)

(export 'hide-ifdef)
(autoload 'hide-ifdef "hideif" t)

(export 'perl-mode)
(autoload 'perl-mode "perl" t)
(autoload 'perl-maketags "perl")
(pushnew '(perl-maketags "*.pl" "*.pm" "*.cgi") *maketags-list* :key #'car)

(export 'basic-mode)
(autoload 'basic-mode "basic-mode" t)
(autoload 'basic-maketags "basic-mode")
(pushnew '(basic-maketags "*.bas" "*.frm" "*.mb") *maketags-list* :key #'car)

(export 'csharp-mode)
(autoload 'csharp-mode "c#-mode" t)

(export 'css-mode)
(autoload 'css-mode "css-mode" t)

(export 'list-function)
(autoload 'list-function "listfn" t)

(export '(hh-open hh-keyword-call hh-sensitive-call *hh-help-file-list*))
(autoload 'hh-open "hh-call" t)
(autoload 'hh-keyword-call "hh-call" t)
(autoload 'hh-sensitive-call "hh-call" t)

(export '(*ispell-command* *ispell-option* ispell-buffer ispell-region))
(autoload 'ispell-buffer "ispell" t)
(autoload 'ispell-region "ispell" t)

(export 'compare-windows)
(autoload 'compare-windows "comparew" t)


(export 'diff)
(autoload 'diff "diff" t)

(export 'tail-f)
(autoload 'tail-f "tail-f" t)

(export 'show-dexplorer)
(autoload 'show-dexplorer "dexplorer" t)

(export '(isearch-forward isearch-backward))
(autoload 'isearch-forward "isearch" t)
(autoload 'isearch-backward "isearch" t)
