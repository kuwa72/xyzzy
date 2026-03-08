;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-ctags.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/05/21 13:57:18 +0900>

;;; Code:

(provide "outline-tree/cr-ctags")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

(defvar *outline-tree-create-outline-ctags-buffer* " *outline-tree: ctags*")

(defun outline-tree-create-outline-ctags-buffer ()
  (let (working-buffer)
    (save-excursion
      (setq working-buffer (create-new-buffer *outline-tree-create-outline-ctags-buffer*))
      (set-buffer working-buffer)
      (make-local-variable 'need-not-save)
      (setq need-not-save t)
      (make-local-variable 'kept-undo-information)
      (setq kept-undo-information nil))
    working-buffer))

(defun outline-tree-create-outline-ctags-get-tags-path (file)
  (let ((tags-dir (directory-namestring file)) tags-file relative-path)
    (loop
      (setq tags-file (merge-pathnames "tags" tags-dir))
      (when (file-exist-p tags-file)
        (return))
      (setq tags-dir (remove-trail-slash tags-dir))
      (unless (string-match "/" tags-dir)
        (return-from outline-tree-create-outline-ctags-get-tags-path nil))
      (setq tags-dir (directory-namestring tags-dir)))
    (setq relative-path
          (map-slash-to-backslash
           (substring (get-buffer-file-name) (length (append-trail-slash tags-dir)))))
    (values tags-file relative-path)))

(defun outline-tree-create-outline-ctags-parse-line ()
  (let (tag-name file-name ex-cmd extension-fields extension-fields-alist)
    (save-excursion
      (goto-bol)
      (when (looking-at "^\\([^\t\n]+\\)\t\\([^\t\n]+\\)\t\\(.+?\\);\"\\(.+\\)?$")
        (setq tag-name (match-string 1)
              file-name (match-string 2)
              ex-cmd (match-string 3)
              extension-fields (match-string 4))
        (dolist (field (reverse (split-string extension-fields "\t")))
          (if (string-match "\\([^:]+\\):\\(.*\\)" field)
              (push (cons (match-string 1) (match-string 2)) extension-fields-alist)
            (push (cons "kind" field) extension-fields-alist)))
        (list tag-name file-name ex-cmd extension-fields-alist)))))

(defun outline-tree-create-outline-ctags-pattern-to-regexp (ctags-pattern)
  (let (regexp)
    (if (string-match "\\^\\(.+\\)\\$" ctags-pattern)
        (progn
          (setq regexp (match-string 1))
          (setq regexp (substitute-string regexp "\\\\\\\\" "\\\\"))
          (setq regexp (substitute-string regexp "\\\\/" "/"))
          (setq regexp (concat "^" (regexp-quote regexp) "$")))
      (setq regexp ctags-pattern))
    regexp))

(defun outline-tree-create-outline-ctags-possible-p (buffer)
  (let (working-buffer tags-file relative-path relative-path-regexp
        fields file-name)
    (save-excursion
      (set-buffer buffer)
      (unless (get-buffer-file-name)
        (return-from outline-tree-create-outline-ctags-possible-p nil))
      (multiple-value-setq (tags-file relative-path)
        (outline-tree-create-outline-ctags-get-tags-path (get-buffer-file-name)))
      (unless tags-file
        (return-from outline-tree-create-outline-ctags-possible-p nil))
      (setq relative-path-regexp (concat "\\(\\.\\\\\\)?" (regexp-quote relative-path)))
      (setq working-buffer (outline-tree-create-outline-ctags-buffer))
      (set-buffer working-buffer)
      (insert-file tags-file)
      (while (scan-buffer (concat "\t" relative-path-regexp "\t") :regexp t)
        (setq fields (outline-tree-create-outline-ctags-parse-line))
        (setq file-name (nth 1 fields))
        (when (string-match (concat "^" relative-path-regexp "$") file-name)
          (delete-buffer working-buffer)
          (return-from outline-tree-create-outline-ctags-possible-p t))
        (goto-eol)))
    (delete-buffer working-buffer)
    nil))

;; > ctags --list-maps=all
(defvar *outline-tree-create-outline-ctags-list-maps*
"Asm      *.asm *.ASM *.s *.S *.A51 *.29[kK] *.[68][68][kKsSxX] *.[xX][68][68]
Asp      *.asp *.asa
Awk      *.awk *.gawk *.mawk
Basic    *.bas *.bi *.bb *.pb
BETA     *.bet
C        *.c
C++      *.c++ *.cc *.cp *.cpp *.cxx *.h *.h++ *.hh *.hp *.hpp *.hxx
C#       *.cs
Cobol    *.cbl *.cob *.CBL *.COB
Eiffel   *.e
Erlang   *.erl *.ERL *.hrl *.HRL
Fortran  *.f *.for *.ftn *.f77 *.f90 *.f95
HTML     *.htm *.html
Java     *.java
JavaScript *.js
Lisp     *.cl *.clisp *.el *.l *.lisp *.lsp *.ml
Lua      *.lua
Make     *.mak *.mk [Mm]akefile
Pascal   *.p *.pas
Perl     *.pl *.pm *.plx *.perl
PHP      *.php *.php3 *.phtml
Python   *.py *.pyx *.pxd *.scons
REXX     *.cmd *.rexx *.rx
Ruby     *.rb *.ruby
Scheme   *.SCM *.SM *.sch *.scheme *.scm *.sm
Sh       *.sh *.SH *.bsh *.bash *.ksh *.zsh
SLang    *.sl
SML      *.sml *.sig
SQL      *.sql
Tcl      *.tcl *.tk *.wish *.itcl
Vera     *.vr *.vri *.vrh
Verilog  *.v
Vim      *.vim
YACC     *.y")
(defvar *outline-tree-create-outline-ctags-auto-maps-alist* nil)
(unless *outline-tree-create-outline-ctags-auto-maps-alist*
  (setq *outline-tree-create-outline-ctags-auto-maps-alist*
        (let (line map language extensions alist)
          (dolist (line (split-string *outline-tree-create-outline-ctags-list-maps* "\n"))
            (setq map (split-string line " "))
            (setq language (car map))
            (setq extensions (cdr map))
            (dolist (ext extensions)
              (when (string-match "^\\*\\(\\..+\\)" ext)
                (setq ext (concat "\\" (match-string 1) "$"))
                (push (cons ext (copy-string language)) alist))))
          (nreverse alist))))
;; (defvar *outline-tree-create-outline-ctags-auto-maps-alist*
;;   '(("\\.asm$" . "Asm") ("\\.ASM$" . "Asm") ("\\.s$" . "Asm") ("\\.S$" . "Asm")
;;     ("\\.A51$" . "Asm") ("\\.29[kK]$" . "Asm") ("\\.[68][68][kKsSxX]$" . "Asm")
;;     ("\\.[xX][68][68]$" . "Asm") ("\\.asp$" . "Asp") ("\\.asa$" . "Asp")
;;     ("\\.awk$" . "Awk") ("\\.gawk$" . "Awk") ("\\.mawk$" . "Awk")
;;     ("\\.bas$" . "Basic") ("\\.bi$" . "Basic") ("\\.bb$" . "Basic")
;;     ("\\.pb$" . "Basic") ("\\.bet$" . "BETA") ("\\.c$" . "C")
;;     ("\\.c++$" . "C++") ("\\.cc$" . "C++") ("\\.cp$" . "C++")
;;     ("\\.cpp$" . "C++") ("\\.cxx$" . "C++") ("\\.h$" . "C++")
;;     ("\\.h++$" . "C++") ("\\.hh$" . "C++") ("\\.hp$" . "C++")
;;     ("\\.hpp$" . "C++") ("\\.hxx$" . "C++") ("\\.cs$" . "C#")
;;     ("\\.cbl$" . "Cobol") ("\\.cob$" . "Cobol") ("\\.CBL$" . "Cobol")
;;     ("\\.COB$" . "Cobol") ("\\.e$" . "Eiffel") ("\\.erl$" . "Erlang")
;;     ("\\.ERL$" . "Erlang") ("\\.hrl$" . "Erlang") ("\\.HRL$" . "Erlang")
;;     ("\\.f$" . "Fortran") ("\\.for$" . "Fortran") ("\\.ftn$" . "Fortran")
;;     ("\\.f77$" . "Fortran") ("\\.f90$" . "Fortran") ("\\.f95$" . "Fortran")
;;     ("\\.htm$" . "HTML") ("\\.html$" . "HTML") ("\\.java$" . "Java")
;;     ("\\.js$" . "JavaScript") ("\\.cl$" . "Lisp") ("\\.clisp$" . "Lisp")
;;     ("\\.el$" . "Lisp") ("\\.l$" . "Lisp") ("\\.lisp$" . "Lisp")
;;     ("\\.lsp$" . "Lisp") ("\\.ml$" . "Lisp") ("\\.lua$" . "Lua")
;;     ("\\.mak$" . "Make") ("\\.mk$" . "Make") ("\\.p$" . "Pascal")
;;     ("\\.pas$" . "Pascal") ("\\.pl$" . "Perl") ("\\.pm$" . "Perl")
;;     ("\\.plx$" . "Perl") ("\\.perl$" . "Perl") ("\\.php$" . "PHP")
;;     ("\\.php3$" . "PHP") ("\\.phtml$" . "PHP") ("\\.py$" . "Python")
;;     ("\\.pyx$" . "Python") ("\\.pxd$" . "Python") ("\\.scons$" . "Python")
;;     ("\\.cmd$" . "REXX") ("\\.rexx$" . "REXX") ("\\.rx$" . "REXX")
;;     ("\\.rb$" . "Ruby") ("\\.ruby$" . "Ruby") ("\\.SCM$" . "Scheme")
;;     ("\\.SM$" . "Scheme") ("\\.sch$" . "Scheme") ("\\.scheme$" . "Scheme")
;;     ("\\.scm$" . "Scheme") ("\\.sm$" . "Scheme") ("\\.sh$" . "Sh")
;;     ("\\.SH$" . "Sh") ("\\.bsh$" . "Sh") ("\\.bash$" . "Sh") ("\\.ksh$" . "Sh")
;;     ("\\.zsh$" . "Sh") ("\\.sl$" . "SLang") ("\\.sml$" . "SML")
;;     ("\\.sig$" . "SML") ("\\.sql$" . "SQL") ("\\.tcl$" . "Tcl")
;;     ("\\.tk$" . "Tcl") ("\\.wish$" . "Tcl") ("\\.itcl$" . "Tcl")
;;     ("\\.vr$" . "Vera") ("\\.vri$" . "Vera") ("\\.vrh$" . "Vera")
;;     ("\\.v$" . "Verilog") ("\\.vim$" . "Vim") ("\\.y$" . "YACC")))

;; > ctags --list-kinds=all
(defvar *outline-tree-create-outline-ctags-list-kinds*
"Asm
    d  defines
    l  labels
    m  macros
    t  types (structs and records)
Asp
    c  constants
    f  functions
    s  subroutines
    v  variables
Awk
    f  functions
Basic
    c  constants
    f  functions
    l  labels
    t  types
    v  variables
    g  enumerations
BETA
    f  fragment definitions
    p  all patterns [off]
    s  slots (fragment uses)
    v  patterns (virtual or rebound)
C
    c  classes
    d  macro definitions
    e  enumerators (values inside an enumeration)
    f  function definitions
    g  enumeration names
    l  local variables [off]
    m  class, struct, and union members
    n  namespaces
    p  function prototypes [off]
    s  structure names
    t  typedefs
    u  union names
    v  variable definitions
    x  external and forward variable declarations [off]
C++
    c  classes
    d  macro definitions
    e  enumerators (values inside an enumeration)
    f  function definitions
    g  enumeration names
    l  local variables [off]
    m  class, struct, and union members
    n  namespaces
    p  function prototypes [off]
    s  structure names
    t  typedefs
    u  union names
    v  variable definitions
    x  external and forward variable declarations [off]
C#
    c  classes
    d  macro definitions
    e  enumerators (values inside an enumeration)
    E  events
    f  fields
    g  enumeration names
    i  interfaces
    l  local variables [off]
    m  methods
    n  namespaces
    p  properties
    s  structure names
    t  typedefs
Cobol
    d  data items
    f  file descriptions (FD, SD, RD)
    g  group items
    p  paragraphs
    P  program ids
    s  sections
Eiffel
    c  classes
    f  features
    l  local entities [off]
Erlang
    d  macro definitions
    f  functions
    m  modules
    r  record definitions
Fortran
    b  block data
    c  common blocks
    e  entry points
    f  functions
    i  interface contents, generic names, and operators [off]
    k  type and structure components
    l  labels
    L  local, common block, and namelist variables [off]
    m  modules
    n  namelists
    p  programs
    s  subroutines
    t  derived types and structures
    v  program (global) and module variables
HTML
    a  named anchors
    f  JavaScript functions
Java
    c  classes
    e  enum constants
    f  fields
    g  enum types
    i  interfaces
    l  local variables [off]
    m  methods
    p  packages
JavaScript
    f  functions
    c  classes
    m  methods
    v  global variables
Lisp
    f  functions
Lua
    f  functions
Make
    m  macros
Pascal
    f  functions
    p  procedures
Perl
    c  constants
    f  formats
    l  labels
    p  packages
    s  subroutines
    d  subroutine declarations [off]
PHP
    c  classes
    i  interfaces
    d  constant definitions
    f  functions
    v  variables
    j  javascript functions
    j  javascript functions
    j  javascript functions
Python
    c  classes
    f  functions
    m  class members
REXX
    s  subroutines
Ruby
    c  classes
    f  methods
    m  modules
    F  singleton methods
Scheme
    f  functions
    s  sets
Sh
    f  functions
SLang
    f  functions
    n  namespaces
SML
    e  exception declarations
    f  function definitions
    c  functor definitions
    s  signature declarations
    r  structure declarations
    t  type definitions
    v  value bindings
SQL
    c  cursors
    d  prototypes [off]
    f  functions
    F  record fields
    l  local variables [off]
    L  block label
    P  packages
    p  procedures
    r  records [off]
    s  subtypes
    t  tables
    T  triggers
    v  variables
    i  indexes
    e  events
    U  publications
    R  services
    D  domains
    V  views
    n  synonyms
    x  MobiLink Table Scripts
    y  MobiLink Conn Scripts
Tcl
    c  classes
    m  methods
    p  procedures
Vera
    c  classes
    d  macro definitions
    e  enumerators (values inside an enumeration)
    f  function definitions
    g  enumeration names
    l  local variables [off]
    m  class, struct, and union members
    p  programs
    P  function prototypes [off]
    t  tasks
    T  typedefs
    v  variable definitions
    x  external variable declarations [off]
Verilog
    c  constants (define, parameter, specparam)
    e  events
    f  functions
    m  modules
    n  net data types
    p  ports
    r  register data types
    t  tasks
Vim
    a  autocommand groups
    c  user-defined commands
    f  function definitions
    m  maps
    v  variable definitions
YACC
    l  labels")
(defvar *outline-tree-create-outline-ctags-list-kinds-list* nil)
(unless *outline-tree-create-outline-ctags-list-kinds-list*
  (setq *outline-tree-create-outline-ctags-list-kinds-list*
        (let (line language alist kind-pairs kind kind-fullname)
          (dolist (line (split-string *outline-tree-create-outline-ctags-list-kinds* "\n"))
            (cond
             ((string-match "^[^ ]" line)
              (when kind-pairs
                (push (cons language (nreverse kind-pairs)) alist)
                (setq kind-pairs nil))
              (setq language line))
             ((string-match "^ +\\([^ ]\\) +\\(.+\\)" line)
              (setq kind (match-string 1)
                    kind-fullname (match-string 2))
              (when (string-match "\\(.+\\) *\\[off\\] *$" kind-fullname)
                (setq kind-fullname (match-string 1)))
              (push (cons kind kind-fullname) kind-pairs))))
          (push (cons language (nreverse kind-pairs)) alist)
          (nreverse alist))))
;; (defvar *outline-tree-create-outline-ctags-list-kinds-list*
;;   '(("Asm" ("d" . "defines") ("l" . "labels") ("m" . "macros") ("t" . "types (structs and records)"))
;;     ("Asp" ("c" . "constants") ("f" . "functions") ("s" . "subroutines") ("v" . "variables"))
;;     ("Awk" ("f" . "functions"))
;;     ("Basic" ("c" . "constants") ("f" . "functions") ("l" . "labels") ("t" . "types") ("v" . "variables") ("g" . "enumerations"))
;;     ("BETA" ("f" . "fragment definitions") ("p" . "all patterns ") ("s" . "slots (fragment uses)") ("v" . "patterns (virtual or rebound)"))
;;     ("C" ("c" . "classes") ("d" . "macro definitions") ("e" . "enumerators (values inside an enumeration)") ("f" . "function definitions") ("g" . "enumeration names") ("l" . "local variables ") ("m" . "class, struct, and union members") ("n" . "namespaces") ("p" . "function prototypes ") ("s" . "structure names") ("t" . "typedefs") ("u" . "union names") ("v" . "variable definitions") ("x" . "external and forward variable declarations "))
;;     ("C++" ("c" . "classes") ("d" . "macro definitions") ("e" . "enumerators (values inside an enumeration)") ("f" . "function definitions") ("g" . "enumeration names") ("l" . "local variables ") ("m" . "class, struct, and union members") ("n" . "namespaces") ("p" . "function prototypes ") ("s" . "structure names") ("t" . "typedefs") ("u" . "union names") ("v" . "variable definitions") ("x" . "external and forward variable declarations "))
;;     ("C#" ("c" . "classes") ("d" . "macro definitions") ("e" . "enumerators (values inside an enumeration)") ("E" . "events") ("f" . "fields") ("g" . "enumeration names") ("i" . "interfaces") ("l" . "local variables ") ("m" . "methods") ("n" . "namespaces") ("p" . "properties") ("s" . "structure names") ("t" . "typedefs"))
;;     ("Cobol" ("d" . "data items") ("f" . "file descriptions (FD, SD, RD)") ("g" . "group items") ("p" . "paragraphs") ("P" . "program ids") ("s" . "sections"))
;;     ("Eiffel" ("c" . "classes") ("f" . "features") ("l" . "local entities "))
;;     ("Erlang" ("d" . "macro definitions") ("f" . "functions") ("m" . "modules") ("r" . "record definitions"))
;;     ("Fortran" ("b" . "block data") ("c" . "common blocks") ("e" . "entry points") ("f" . "functions") ("i" . "interface contents, generic names, and operators ") ("k" . "type and structure components") ("l" . "labels") ("L" . "local, common block, and namelist variables ") ("m" . "modules") ("n" . "namelists") ("p" . "programs") ("s" . "subroutines") ("t" . "derived types and structures") ("v" . "program (global) and module variables"))
;;     ("HTML" ("a" . "named anchors") ("f" . "JavaScript functions"))
;;     ("Java" ("c" . "classes") ("e" . "enum constants") ("f" . "fields") ("g" . "enum types") ("i" . "interfaces") ("l" . "local variables ") ("m" . "methods") ("p" . "packages"))
;;     ("JavaScript" ("f" . "functions") ("c" . "classes") ("m" . "methods") ("v" . "global variables"))
;;     ("Lisp" ("f" . "functions"))
;;     ("Lua" ("f" . "functions"))
;;     ("Make" ("m" . "macros"))
;;     ("Pascal" ("f" . "functions") ("p" . "procedures"))
;;     ("Perl" ("c" . "constants") ("f" . "formats") ("l" . "labels") ("p" . "packages") ("s" . "subroutines") ("d" . "subroutine declarations "))
;;     ("PHP" ("c" . "classes") ("i" . "interfaces") ("d" . "constant definitions") ("f" . "functions") ("v" . "variables") ("j" . "javascript functions") ("j" . "javascript functions") ("j" . "javascript functions"))
;;     ("Python" ("c" . "classes") ("f" . "functions") ("m" . "class members"))
;;     ("REXX" ("s" . "subroutines"))
;;     ("Ruby" ("c" . "classes") ("f" . "methods") ("m" . "modules") ("F" . "singleton methods"))
;;     ("Scheme" ("f" . "functions") ("s" . "sets"))
;;     ("Sh" ("f" . "functions"))
;;     ("SLang" ("f" . "functions") ("n" . "namespaces"))
;;     ("SML" ("e" . "exception declarations") ("f" . "function definitions") ("c" . "functor definitions") ("s" . "signature declarations") ("r" . "structure declarations") ("t" . "type definitions") ("v" . "value bindings"))
;;     ("SQL" ("c" . "cursors") ("d" . "prototypes ") ("f" . "functions") ("F" . "record fields") ("l" . "local variables ") ("L" . "block label") ("P" . "packages") ("p" . "procedures") ("r" . "records ") ("s" . "subtypes") ("t" . "tables") ("T" . "triggers") ("v" . "variables") ("i" . "indexes") ("e" . "events") ("U" . "publications") ("R" . "services") ("D" . "domains") ("V" . "views") ("n" . "synonyms") ("x" . "MobiLink Table Scripts") ("y" . "MobiLink Conn Scripts"))
;;     ("Tcl" ("c" . "classes") ("m" . "methods") ("p" . "procedures"))
;;     ("Vera" ("c" . "classes") ("d" . "macro definitions") ("e" . "enumerators (values inside an enumeration)") ("f" . "function definitions") ("g" . "enumeration names") ("l" . "local variables ") ("m" . "class, struct, and union members") ("p" . "programs") ("P" . "function prototypes ") ("t" . "tasks") ("T" . "typedefs") ("v" . "variable definitions") ("x" . "external variable declarations "))
;;     ("Verilog" ("c" . "constants (define, parameter, specparam)") ("e" . "events") ("f" . "functions") ("m" . "modules") ("n" . "net data types") ("p" . "ports") ("r" . "register data types") ("t" . "tasks"))
;;     ("Vim" ("a" . "autocommand groups") ("c" . "user-defined commands") ("f" . "function definitions") ("m" . "maps") ("v" . "variable definitions"))
;;     ("YACC" ("l" . "labels"))))

(defun outline-tree-create-outline-ctags-buffer-to-langege (buffer)
  (let (item)
    (when (setq item (find (buffer-name buffer) *outline-tree-create-outline-ctags-auto-maps-alist*
                           :test #'(lambda (name regexp) (string-matchp regexp name)) :key 'car))
      (cdr item))))

(defun outline-tree-create-outline-ctags-kind-to-kind-fullname (language kind)
  (let (item kind-pairs kind-fullname)
    (when (setq item (find language *outline-tree-create-outline-ctags-list-kinds-list*
                           :test 'string-equal :key 'car))
      (setq kind-pairs (cdr item))
      (when (setq item (find kind kind-pairs :test 'string= :key 'car))
        (setq kind-fullname (cdr item))))
    (or kind-fullname kind)))

;; ctags 解析
(defun outline-tree-create-outline-ctags (root-node)
  (treeview::with-app (*outline-tree-app-id*)
    (let ((src-buffer (outline-tree-get-buffer-by-node root-node))
          working-buffer tags-file relative-path relative-path-regexp
          kind kind-types (kind-node-hash (make-hash-table :test #'equal))
          fields fields-list
          tag-name file-name ex-cmd extension-fields-alist
          xyzzy-regexp node language)
      (save-excursion
        (set-buffer src-buffer)
        (unless (get-buffer-file-name)
          (treeview::treeview-message "ファイル名がありません。")
          (return-from outline-tree-create-outline-ctags))
        (multiple-value-setq (tags-file relative-path)
          (outline-tree-create-outline-ctags-get-tags-path (get-buffer-file-name)))
        (unless tags-file
          (treeview::treeview-message "適切な tags ファイルが存在しません。")
          (return-from outline-tree-create-outline-ctags))

        (setq relative-path-regexp (concat "\\(\\.\\\\\\)?" (regexp-quote relative-path)))
        (setq working-buffer (outline-tree-create-outline-ctags-buffer))
        (set-buffer working-buffer)
        (insert-file tags-file)
        (while (scan-buffer (concat "\t" relative-path-regexp "\t") :regexp t)
          (setq fields (outline-tree-create-outline-ctags-parse-line))
          (setq tag-name (nth 0 fields)
                file-name (nth 1 fields)
                ex-cmd (nth 2 fields)
                extension-fields-alist (nth 3 fields))
          (when (string-match (concat "^" relative-path-regexp "$") file-name)
            (setq kind (cdr (assoc "kind" extension-fields-alist :test #'string=)))
            (unless kind
              (setq kind "*"))
            (pushnew kind kind-types :test #'string=)
            (push fields fields-list))
          (goto-eol))
        (delete-buffer working-buffer)

        (set-buffer src-buffer)
        (setq language (outline-tree-create-outline-ctags-buffer-to-langege src-buffer))
        (dolist (kind (sort kind-types #'string-lessp))
          (setf (gethash kind kind-node-hash)
                (outline-tree-insert-section-node
                 (format nil "[~A]"
                         (outline-tree-create-outline-ctags-kind-to-kind-fullname language kind)) root-node)))
        (dolist (fields (nreverse fields-list))
          (setq tag-name (nth 0 fields)
                file-name (nth 1 fields)
                ex-cmd (nth 2 fields)
                extension-fields-alist (nth 3 fields))
          (setq kind (cdr (assoc "kind" extension-fields-alist :test #'string=)))
          (unless kind
            (setq kind "*"))
          (cond
           ((string-match "^[1-9][0-9]*$" ex-cmd)
            (setq node (outline-tree-insert-point-node tag-name (gethash kind kind-node-hash)
                                                       :point (progn (goto-line (parse-integer ex-cmd)) (point)))))
           ((string-match "^/\\(.+\\)/$" ex-cmd)
            (setq xyzzy-regexp (outline-tree-create-outline-ctags-pattern-to-regexp (match-string 1)))
            (goto-char (point-min))
            (if (scan-buffer xyzzy-regexp :regexp t)
                (setq node (outline-tree-insert-point-node tag-name (gethash kind kind-node-hash)
                                                           :point (progn (goto-bol) (point))))
              (setq node (outline-tree-insert-info-node tag-name (gethash kind kind-node-hash)))))
           (t
            (setq node (outline-tree-insert-info-node tag-name (gethash kind kind-node-hash)))))
          (outline-tree-insert-info-node ex-cmd node)
          (dolist (extension-field extension-fields-alist)
            (when (string/= "kind" (car extension-field))
              (outline-tree-insert-info-node (format nil "~S" extension-field) node))))))))

(outline-tree-add-create-outline-function
 'outline-tree-create-outline-ctags "ctags" '(:type-program-general)
 "バッファに対応する tags ファイルを元に情報を表示します。
tags ファイルとは、exuberant ctags
  本家         <http://ctags.sourceforge.net/>
  日本語対応版 <http://hp.vector.co.jp/authors/VA025040/ctags/>
により生成されるファイルです。")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; > ctags --version
;; Exuberant Ctags 5.7J1, Copyright (C) 1996-2007 Darren Hiebert
;;   Compiled: Sep 11 2007, 19:51:57
;;   Addresses: <dhiebert@users.sourceforge.net>, http://ctags.sourceforge.net
;;   Japanese patch  by Hirohito Higashi <h_east@pop11.odn.ne.jp>
;;                      http://hp.vector.co.jp/authors/VA025040/
;;   Optional compiled features: +win32, +regex, +internal-sort, +kanji

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; > ctags --help
;; Exuberant Ctags 5.7J1, Copyright (C) 1996-2007 Darren Hiebert
;;   Compiled: Sep 11 2007, 19:51:57
;;   Addresses: <dhiebert@users.sourceforge.net>, http://ctags.sourceforge.net
;;   Japanese patch  by Hirohito Higashi <h_east@pop11.odn.ne.jp>
;;                      http://hp.vector.co.jp/authors/VA025040/
;;   Optional compiled features: +win32, +regex, +internal-sort, +kanji
;; 
;; Usage: ctags [options] [file(s)]
;; 
;;   -a   Append the tags to an existing tag file.
;;   -B   Use backward searching patterns (?...?).
;;   -e   Output tag file for use with Emacs.
;;   -f <name>
;;        Write tags to specified file. Value of "-" writes tags to stdout
;;        ["tags"; or "TAGS" when -e supplied].
;;   -F   Use forward searching patterns (/.../) (default).
;;   -h <list>
;;        Specify list of file extensions to be treated as include files.
;;        [".h.H.hh.hpp.hxx.h++"].
;;   -I <list|@file>
;;        A list of tokens to be specially handled is read from either the
;;        command line or the specified file.
;;   -L <file>
;;        A list of source file names are read from the specified file.
;;        If specified as "-", then standard input is read.
;;   -n   Equivalent to --excmd=number.
;;   -N   Equivalent to --excmd=pattern.
;;   -o   Alternative for -f.
;;   -R   Equivalent to --recurse.
;;   -u   Equivalent to --sort=no.
;;   -V   Equivalent to --verbose.
;;   -x   Print a tabular cross reference file to standard output.
;;   --append=[yes|no]
;;        Should tags should be appended to existing tag file [no]?
;;   --etags-include=file
;;       Include reference to 'file' in Emacs-style tag file (requires -e).
;;   --exclude=pattern
;;       Exclude files and directories matching 'pattern'.
;;   --excmd=number|pattern|mix
;;        Uses the specified type of EX command to locate tags [mix].
;;   --extra=[+|-]flags
;;       Include extra tag entries for selected information (flags: "fq").
;;   --fields=[+|-]flags
;;       Include selected extension fields (flags: "afmikKlnsStz") [fks].
;;   --file-scope=[yes|no]
;;        Should tags scoped only for a single file (e.g. "static" tags
;;        be included in the output [yes]?
;;   --filter=[yes|no]
;;        Behave as a filter, reading file names from standard input and
;;        writing tags to standard output [no].
;;   --filter-terminator=string
;;        Specify string to print to stdout following the tags for each file
;;        parsed when --filter is enabled.
;;   --format=level
;;        Force output of specified tag file format [2].
;;   --help
;;        Print this option summary.
;;   --if0=[yes|no]
;;        Should C code within #if 0 conditional branches be parsed [no]?
;;   --jcode=ascii|sjis|euc|utf8
;;        Specify Japanese kanji code [sjis].
;;   --<LANG>-kinds=[+|-]kinds
;;        Enable/disable tag kinds for language <LANG>.
;;   --langdef=name
;;        Define a new language to be parsed with regular expressions.
;;   --langmap=map(s)
;;        Override default mapping of language to source file extension.
;;   --language-force=language
;;        Force all files to be interpreted using specified language.
;;   --languages=[+|-]list
;;        Restrict files scanned for tags to those mapped to langauges
;;        specified in the comma-separated 'list'. The list can contain any
;;        built-in or user-defined language [all].
;;   --license
;;        Print details of software license.
;;   --line-directives=[yes|no]
;;        Should #line directives be processed [no]?
;;   --links=[yes|no]
;;        Indicate whether symbolic links should be followed [yes].
;;   --list-kinds=[language|all]
;;        Output a list of all tag kinds for specified language or all.
;;   --list-languages
;;        Output list of supported languages.
;;   --list-maps=[language|all]
;;        Output list of language mappings.
;;   --options=file
;;        Specify file from which command line options should be read.
;;   --recurse=[yes|no]
;;        Recurse into directories supplied on command line [no].
;;   --regex-<LANG>=/line_pattern/name_pattern/[flags]
;;        Define regular expression for locating tags in specific language.
;;   --sort=[yes|no|foldcase]
;;        Should tags be sorted (optionally ignoring case) [yes]?.
;;   --tag-relative=[yes|no]
;;        Should paths be relative to location of tag file [no; yes when -e]?
;;   --totals=[yes|no]
;;        Print statistics about source and tag files [no].
;;   --verbose=[yes|no]
;;        Enable verbose messages describing actions on each source file.
;;   --version
;;        Print version identifier to standard output.

;; > ctags *
;; > ctags -R

;;; cr-ctags.l ends here
