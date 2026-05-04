;;; -*- Mode: Lisp; Package: EDITOR; Encoding: utf-8 -*-
;;; emmet.l — Emmet abbreviation expander

(in-package "editor")

(export '(emmet-expand-at-point emmet-expand))

;;; ---- configuration ------------------------------------------------------

(defvar *emmet-indent* "  "
  "Indent unit for expanded HTML.")

(defvar *emmet-void-elements*
  '("area" "base" "br" "col" "embed" "hr" "img" "input"
    "link" "meta" "param" "source" "track" "wbr")
  "Elements that take no closing tag.")

;;; ---- parse state (globals for simplicity) -------------------------------

(defvar *ep-src* "")
(defvar *ep-pos* 0)

(defun ep-char ()
  (and (< *ep-pos* (length *ep-src*)) (aref *ep-src* *ep-pos*)))

(defun ep-skip (ch)
  (when (eql (ep-char) ch) (incf *ep-pos*) t))

(defun ep-read-name ()
  (let ((s *ep-pos*))
    (loop
      (let ((c (ep-char)))
        (unless (and c (or (alphanumericp c) (eql c #\-) (eql c #\_) (eql c #\:)))
          (return)))
      (incf *ep-pos*))
    (subseq *ep-src* s *ep-pos*)))

(defun ep-read-until (end-ch)
  (let ((s *ep-pos*))
    (loop
      (let ((c (ep-char)))
        (when (or (null c) (eql c end-ch)) (return)))
      (incf *ep-pos*))
    (prog1 (subseq *ep-src* s *ep-pos*)
      (ep-skip end-ch))))

(defun ep-read-int ()
  (let ((s *ep-pos*))
    (loop
      (let ((c (ep-char)))
        (unless (and c (digit-char-p c)) (return)))
      (incf *ep-pos*))
    (if (> *ep-pos* s)
        (parse-integer (subseq *ep-src* s *ep-pos*))
      1)))

;;; ---- parser -------------------------------------------------------------
;;; Node: (tag classes id attrs text mult children)
;;;   0:tag  1:classes  2:id  3:attrs  4:text  5:mult  6:children

(defun ep-parse-tag ()
  (let* ((tag (if (let ((c (ep-char))) (and c (alpha-char-p c)))
                  (ep-read-name)
                "div"))
         classes id attrs text (mult 1))
    (loop
      (cond ((ep-skip #\.) (push (ep-read-name) classes))
            ((ep-skip #\#) (setq id (ep-read-name)))
            ((ep-skip #\[) (setq attrs (ep-read-until #\])))
            ((ep-skip #\{) (setq text (ep-read-until #\})))
            ((ep-skip #\*) (setq mult (ep-read-int)) (return))
            (t (return))))
    (list tag (nreverse classes) id attrs text mult nil)))

(defun ep-parse-siblings ()
  (let (nodes)
    (push (ep-parse-chain) nodes)
    (loop
      (unless (ep-skip #\+) (return))
      (push (ep-parse-chain) nodes))
    (nreverse nodes)))

(defun ep-parse-chain ()
  (let ((node (ep-parse-tag)))
    (when (ep-skip #\>)
      (setf (nth 6 node) (ep-parse-siblings)))
    node))

;;; ---- renderer -----------------------------------------------------------

(defun emmet-void-p (tag)
  (member tag *emmet-void-elements* :test #'string=))

(defun emmet-subst-n (s n)
  "Replace $ with repetition index N in string S."
  (let ((result "") (i 0) (len (length s)))
    (loop
      (when (>= i len) (return result))
      (if (eql (aref s i) #\$)
          (setq result (concat result (format nil "~D" n)))
        (setq result (concat result (string (aref s i)))))
      (incf i))))

(defun emmet-join (lst sep)
  (if (null lst) ""
    (let ((r (first lst)))
      (dolist (x (rest lst) r)
        (setq r (concat r sep x))))))

(defun emmet-indent-str (depth)
  (let ((r ""))
    (dotimes (i depth r)
      (setq r (concat r *emmet-indent*)))))

(defun emmet-open-tag (tag classes id attrs)
  (let ((s (concat "<" tag)))
    (when id
      (setq s (concat s " id=\"" id "\"")))
    (when classes
      (setq s (concat s " class=\"" (emmet-join classes " ") "\"")))
    (when attrs
      (setq s (concat s " " attrs)))
    (concat s ">")))

(defun emmet-render-node (node depth n)
  (let* ((tag      (nth 0 node))
         (classes  (mapcar (lambda (c) (emmet-subst-n c n)) (nth 1 node)))
         (id       (let ((x (nth 2 node))) (when x (emmet-subst-n x n))))
         (attrs    (let ((x (nth 3 node))) (when x (emmet-subst-n x n))))
         (text     (let ((x (nth 4 node))) (when x (emmet-subst-n x n))))
         (children (nth 6 node))
         (pad      (emmet-indent-str depth))
         (open     (emmet-open-tag tag classes id attrs)))
    (cond
      ((emmet-void-p tag)
       (concat pad "<" tag
               (when id      (concat " id=\"" id "\""))
               (when classes (concat " class=\"" (emmet-join classes " ") "\""))
               (when attrs   (concat " " attrs))
               ">\n"))
      (children
       (concat pad open "\n"
               (emmet-render-siblings children (1+ depth))
               pad "</" tag ">\n"))
      (text
       (concat pad open text "</" tag ">\n"))
      (t
       (concat pad open "</" tag ">\n")))))

(defun emmet-render-siblings (nodes depth)
  (let ((r ""))
    (dolist (node nodes r)
      (let ((mult (nth 5 node)))
        (dotimes (i mult)
          (setq r (concat r (emmet-render-node node depth (1+ i)))))))))

;;; ---- entry points -------------------------------------------------------

(defun emmet-expand (abbrev &optional (base-depth 0))
  "Expand Emmet abbreviation string to HTML. Returns the HTML string."
  (let ((*ep-src* abbrev)
        (*ep-pos* 0))
    (let ((nodes (ep-parse-siblings)))
      (emmet-render-siblings nodes base-depth))))

(defun emmet-abbrev-start ()
  "Return start point of Emmet abbreviation ending at point.
Handles spaces inside {text} and [attrs] blocks."
  (save-excursion
    (let ((brace 0) (bracket 0))
      (loop
        (let ((c (preceding-char)))
          (when (null c) (return))
          (cond
            ;; inside {} — skip everything including spaces
            ((> brace 0)
             (when (eql c #\{) (decf brace))
             (backward-char 1))
            ;; closing brace — enter brace mode
            ((eql c #\}) (incf brace) (backward-char 1))
            ;; inside [] — skip everything including spaces
            ((> bracket 0)
             (when (eql c #\[) (decf bracket))
             (backward-char 1))
            ;; closing bracket — enter bracket mode
            ((eql c #\]) (incf bracket) (backward-char 1))
            ;; normal abbreviation characters
            ((or (alphanumericp c) (find c ">+.#*$_:-"))
             (backward-char 1))
            ;; anything else — stop
            (t (return))))))
    (point)))

(defun emmet-expand-at-point ()
  "Expand Emmet abbreviation before point, replacing it with HTML."
  (interactive "*")
  (let* ((end (point))
         (start (emmet-abbrev-start))
         (abbrev (buffer-substring start end)))
    (when (string= abbrev "")
      (error "emmet: no abbreviation before point"))
    (let* ((depth (save-excursion
                    (goto-char start)
                    (goto-bol)
                    (skip-chars-forward " \t")
                    (truncate (current-column) (length *emmet-indent*))))
           (expanded (emmet-expand abbrev depth))
           (pad      (emmet-indent-str depth))
           ; cursor is already at the right column; strip leading pad from first line
           (to-insert (if (and (>= (length expanded) (length pad))
                               (string= expanded pad :end1 (length pad)))
                          (subseq expanded (length pad))
                        expanded)))
      (delete-region start end)
      (insert (string-right-trim (string #\Newline) to-insert)))))
