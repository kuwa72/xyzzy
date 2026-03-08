;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; output-html-heading.l --- outline-tree

;; Copyright (C) 2001-2007 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2007/07/06 11:25:16 +0900>

;;; Code:

(provide "outline-tree/output-html-heading")

(require "outline-tree/outline-tree")
(require "outline-tree/output")
(require "outline-tree/output-html")

(in-package "outline-tree2")

(defun outline-tree-output-html-heading-target-node-count (root-node output-depth)
  "見出しノードHTML出力: 処理対象のノードの数を返す"
  (let ((count 0) node)
    (labels ((outline-tree-output-html-heading-target-node-count-1 (node level)
               (when (or (outline-tree-heading-node-p node)
                         (and (= level 1) (outline-tree-header-node-p node)))
                 (incf count)
                 (when (and (outline-tree-node-has-children-p node)
                            (or (not (eq output-depth :expand)) (treeview::treeview-expand-p node)))
                   (setq node (treeview::treeview-get-child-item node))
                   (while (outline-tree-node-valid-p node)
                     (outline-tree-output-html-heading-target-node-count-1 node (1+ level))
                     (setq node (treeview::treeview-get-next-sibling-item node)))))))
      (when (and (outline-tree-node-has-children-p root-node)
                 (or (not (eq output-depth :expand)) (treeview::treeview-expand-p root-node)))
        (setq node (treeview::treeview-get-child-item root-node))
        (while (outline-tree-node-valid-p node)
          (outline-tree-output-html-heading-target-node-count-1 node 1)
          (setq node (treeview::treeview-get-next-sibling-item node))))
      count)))

(defun outline-tree-output-html-heading-toc (root-node target-node-count output-depth frame-p)
  "見出しノードHTML出力: メニュー部HTMLの <body></body> 内文字列を返す"
  (let ((sec-num 0) node (node-count 0))
    (labels ((outline-tree-output-html-heading-toc-1 (node level)
               (let (str)
                 (format t "~V@{~A~:*~}" (1+ (* 2 (1- level))) "  ")
                 (setq str (outline-tree-data-get-node-name node))
                 (dolist (x *outline-tree-output-html-string-encode-alist*)
                   (setq str (substitute-string str (car x) (cdr x))))
                 (format t "<li class=\"lv~D\">" level)
                 (cond
                  ((or (outline-tree-heading-node-p node)
                       (and (= level 1) (outline-tree-header-node-p node)))
                   (incf node-count)
                   (message "toc processing: ~D/~D" node-count target-node-count)
                   (incf sec-num)
                   (format t "<a href=\"~A#SEC~D\" name=\"TOC~D\"~A>~A</a>"
                           (if frame-p *outline-tree-output-html-frame-main-file* "")
                           sec-num sec-num (if frame-p " target=\"main\"" "") str))
                  (t
                   (format t "~A" str)))
                 (when (and (outline-tree-node-has-children-p node)
                            (or (not (eq output-depth :expand)) (treeview::treeview-expand-p node)))
                   (format t "~%")
                   (incf level)
                   (format t "~V@{~A~:*~}" (* 2 (1- level)) "  ")
                   (format t "<ul class=\"lv~D\">~%" level)
                   (setq node (treeview::treeview-get-child-item node))
                   (while (outline-tree-node-valid-p node)
                     (outline-tree-output-html-heading-toc-1 node level)
                     (setq node (treeview::treeview-get-next-sibling-item node)))
                   (format t "~V@{~A~:*~}" (* 2 (1- level)) "  ")
                   (format t "</ul>~%")
                   (decf level)
                   (format t "~V@{~A~:*~}" (1+ (* 2 (1- level))) "  "))
                 (format t "</li>~%"))))
      (format t "~A~%" "<div id=\"toc\">")
      (when (and (outline-tree-node-has-children-p root-node)
                 (or (not (eq output-depth :expand)) (treeview::treeview-expand-p root-node)))
        (format t "~A~%" "<ul class=\"lv1\">")
        (setq node (treeview::treeview-get-child-item root-node))
        (while (outline-tree-node-valid-p node)
          (outline-tree-output-html-heading-toc-1 node 1)
          (setq node (treeview::treeview-get-next-sibling-item node)))
        (format t "~A~%" "</ul>"))
      (format t "~A~%" "</div>"))))

(defun outline-tree-output-html-heading-main (root-node target-node-count output-depth frame-p)
  "見出しノードHTML出力: メイン部HTMLの <body></body> 内文字列を返す"
  (let ((sec-num 0) node (node-count 0))
    (labels ((outline-tree-output-html-heading-main-1 (node level)
               (let (str range from to)
                 (cond
                  ((or (outline-tree-heading-node-p node)
                       (and (= level 1) (outline-tree-header-node-p node)))
                   (incf node-count)
                   (message "main processing: ~D/~D: ~A"
                            node-count target-node-count (outline-tree-data-get-node-name node))
                   (setq str (outline-tree-data-get-node-name node))
                   (dolist (x *outline-tree-output-html-string-encode-alist*)
                     (setq str (substitute-string str (car x) (cdr x))))
                   (incf sec-num)
                   (format t "<h~D class=\"lv~D\">" (if (<= level 6) level 6) level)
                   (format t "<a href=\"~A#TOC~D\" name=\"SEC~D\"~A>~A</a>"
                           (if frame-p *outline-tree-output-html-frame-toc-file* "")
                           sec-num sec-num (if frame-p " target=\"toc\"" "") str)
                   (format t "</h~D>~%" (if (<= level 6) level 6))
                   (format t "<div class=\"lv~D\">" level)
                   (cond
                    ((outline-tree-header-node-p node)
                     (setq range (outline-tree-data-get-whole-range node)))
                    ((eq output-depth :expand)
                     (setq range (outline-tree-data-get-output-range node)))
                    (t
                     (setq range (outline-tree-data-get-contents-range node))))

                   (setq from (outline-tree-get-range-from range)
                         to (outline-tree-get-range-to range))
                   (if (and (< from to)
                            (save-excursion (goto-char from) (skip-chars-forward " \t\n") (< (point) to)))
                       (setq str (buf2html-get-region-string from to nil t))
                     (setq str ""))
                   (format t "~A" str)
                   (format t "</div>~%")))
                 (when (and (outline-tree-node-has-children-p node)
                            (or (not (eq output-depth :expand)) (treeview::treeview-expand-p node)))
                   (setq node (treeview::treeview-get-child-item node))
                   (while (outline-tree-node-valid-p node)
                     (outline-tree-output-html-heading-main-1 node (1+ level))
                     (setq node (treeview::treeview-get-next-sibling-item node)))))))
      (save-excursion
        (save-restriction
          (widen)
          (set-buffer (outline-tree-get-buffer-by-node root-node))
          (format t "~A~%" "<div id=\"main\">")
          (when (and (outline-tree-node-has-children-p root-node)
                     (or (not (eq output-depth :expand)) (treeview::treeview-expand-p root-node)))
            (setq node (treeview::treeview-get-child-item root-node))
            (while (outline-tree-node-valid-p node)
              (outline-tree-output-html-heading-main-1 node 1)
              (setq node (treeview::treeview-get-next-sibling-item node))))
          (format t "~A~%" "</div>"))))))

;;; output-html-heading.l ends here
