;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; cr-range-internal.l --- outline-tree

;; Copyright (C) 2001-2005 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2005/11/12 14:23:47 +0900>

;;; Code:

(provide "outline-tree/cr-range-internal")

(require "outline-tree/outline-tree")

(in-package "outline-tree2")

;;; アウトライン作成関数
(defun outline-tree-create-outline-range-internal
  (&key root-node get-range-func child-only
        create-contents-outline-func
        create-begin-outline-func
        create-end-outline-func
        (sub-outline-order '(:begin :end :contents)))
  (let (range-node)
    (save-excursion
      (goto-char (point-min))
      (when child-only
        (setq range-node root-node))
      (loop
        (multiple-value-bind (begin-range end-range name)
            (multiple-value-call get-range-func)
          (unless begin-range
            (return-from outline-tree-create-outline-range-internal))
          (if child-only
              (outline-tree-update-node
               root-node
               :group-count (1+ (outline-tree-data-get-group-count root-node)))
            (setq range-node (outline-tree-insert-range-node
                              name root-node
                              :whole-range (cons (outline-tree-get-range-from begin-range)
                                                 (if (outline-tree-range-to-unlimited-p end-range)
                                                     nil
                                                   (outline-tree-get-range-to end-range))))))
          (let ((*outline-tree-range-node-group-p* child-only))
            (dolist (type sub-outline-order)
              (case type
                (:begin
                 (when create-begin-outline-func
                   (save-restriction
                     (narrow-to-region (outline-tree-get-range-from begin-range)
                                       (outline-tree-get-range-to begin-range))
                     (goto-char (point-min))
                     (funcall create-begin-outline-func range-node name))))
                (:end
                 (when create-end-outline-func
                   (save-restriction
                     (narrow-to-region (outline-tree-get-range-from end-range)
                                       (outline-tree-get-range-to end-range))
                     (goto-char (point-min))
                     (funcall create-end-outline-func range-node name))))
                (:contents
                 (when create-contents-outline-func
                   (save-restriction
                     (narrow-to-region (outline-tree-get-range-to begin-range)
                                       (outline-tree-get-range-from end-range))
                     (goto-char (point-min))
                     (funcall create-contents-outline-func range-node name))))))
            (goto-char (outline-tree-get-range-to end-range))))))))

;;; cr-range-internal.l ends here
