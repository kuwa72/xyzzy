;;; -*- Mode: Lisp; Package: OUTLINE-TREE2 ; Encoding: utf-8 -*-
;;; output-html.l --- outline-tree

;; Copyright (C) 2001-2009 OHKUBO Hiroshi <ohkubo@s53.xrea.com>

;; Author: OHKUBO Hiroshi <ohkubo@s53.xrea.com>
;; Time-stamp: <2009/03/12 18:02:27 +0900>

;;; Code:

(provide "outline-tree/output-html")

; (require "buf2html") ; HTML出力未移植
(require "outline-tree/outline-tree")
(require "outline-tree/output")

(in-package "outline-tree2")

(defvar *outline-tree-output-html-file* "index.html"
  "HTML出力: HTMLファイル名")
(defvar *outline-tree-output-html-frame-frame-file* "index.html"
  "HTML出力: フレームHTMLファイル名")
(defvar *outline-tree-output-html-frame-toc-file* "toc.html"
  "HTML出力: メニュー部HTMLファイル名")
(defvar *outline-tree-output-html-frame-main-file* "main.html"
  "HTML出力: メイン部HTMLファイル名")

(defvar *outline-tree-output-html-string-encode-alist*
  '(("&" . "&amp;")
    ("<" . "&lt;")
    (">" . "&gt;")
    ( "\"" . "&quot;")
    (" " . "&nbsp;"))
  "変換する文字参照リスト")

(defvar *outline-tree-output-html-css-string*
"        body {
          color: black;
          background-color: white;
        }
        a:link {
          color: #0033cc;
        }
        a:visited {
          color: navy;
        }
        a:hover {
          color: #ff6633;
        }
        h1 {
          font-size: 1.5em;
          line-height: 1.7em;
          background-color: #ffcc66;
          margin: 0.2em 0em 0em 0em;
          padding: 4px 4px 2px;
          border-width: 1px 1px 1px 3px;
          border-color: #6666ff;
          border-style: solid;
        }
        h2 {
          font-weight: bold;
          font-size: 1.3em;
          line-height: 1.4em;
          background-color: #ccccff;
          margin: 0.2em 0em 0em 0.5em;
          padding: 5px 8px 5px 1ex;
          border-width: 1px 1px 1px 3px;
          border-color: #8888ff;
          border-style: solid;
        }
        h3 {
          font-size: 1.1em;
          line-height: 1.1em;
          background-color: #FFFFCC;
          margin: 0.2em 0em 0em 1em;
          padding: 5px 8px 5px 2ex;
          border-width: 1px 1px 1px 3px;
          border-color: #ffccff;
          border-style: solid;
        }
        h4, h5, h6 {
          line-height: 1.2em;
          font-size: 1.5em;
          margin: 0.2em 0em 0em 1.5em;
          padding: 5px 8px 5px 2ex;
        }
        pre {
          margin: 0.3em 0em 0.6em 2em;
          border-width: 2px;
          border-color: #000000;
          border-style: solid;
          padding: 3px 3px 3px 3px;
        }
        p {
          margin-top: 0.3em;
          margin-right: 1em;
          margin-bottom: 1em;
          margin-left: 2em;
        }
        ul {
          list-style: circle;
          margin-left: 1em;
        }
        ul ul {
          list-style: disc;
        }
        ul ul ul {
          list-style: square;
        }
        ul ul ul ul {
          list-style: none;
        }
        ol {
          margin-left: 1em;
        }
        #toc {
          margin: 1em 1em 1em 1em;
          padding: 0px 1em 0px 1em;
          border: 1px solid #339966;
          border-width: 1px 1px 1px 5px;
          background-color: #eeeeee;
          color: #993366;
        }
")

(defun outline-tree-output-html-css ()
  "HTML出力: CSSを返す"
  (let ((xyzzy-css-string (buf2html-get-ini2css-string 8)))
    (concat
     xyzzy-css-string
     (if (string/= xyzzy-css-string "") "\n" "")
     *outline-tree-output-html-css-string*)))

(defun outline-tree-output-html-frame ()
  "HTML出力: トップHTMLファイル文字列を返す"
  (concat
"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\">
<html lang=\"ja\">
  <head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=Shift_JIS\">
    <meta name=\"GENERATOR\" content=\"outline-tree\">
    <title>%nodename%</title>
  </head>
  <frameset cols=\"300,500\" title=\"index\">
    <frame src=\"" *outline-tree-output-html-frame-toc-file* "\" name=\"toc\" title=\"toc\">
    <frame src=\"" *outline-tree-output-html-frame-main-file* "\" name=\"main\" title=\"main\">
    <noframes>
      <body>
        <a href=\"" *outline-tree-output-html-frame-toc-file* "\">"
   *outline-tree-output-html-frame-toc-file*
   "</a>
        <a href=\"" *outline-tree-output-html-frame-main-file* "\">"
   *outline-tree-output-html-frame-main-file*
   "</a>
      </body>
    </noframes>
  </frameset>
</html>
"))

(defun outline-tree-output-html-header (&optional (css 'outline-tree-output-html-css))
  "HTML出力: メニュー部、メイン部ファイルの先頭から<body>までの文字列を返す"
  (let (css-str)
    (setq css-str
          (cond
           ((stringp css)
            css)
           ((or (functionp css) (and (symbolp css) (fboundp css)))
            (funcall css))
           (t "")))
    (concat
"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">
<html lang=\"ja\">
  <head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=Shift_JIS\">
    <meta http-equiv=\"Content-Style-Type\" content=\"text/css\">
    <style type=\"text/css\">
      <!--
"
     css-str
"
      //-->
    </style>
    <meta name=\"GENERATOR\" content=\"outline-tree\">
    <title>%nodename%</title>
  </head>
  <body>
")))

(defun outline-tree-output-html-footer ()
  "HTML出力: メニュー部、メイン部ファイルの</body>から最後までの文字列を返す"
  "</body>
</html>
")

(defun outline-tree-output-html-frame-simple ()
  "HTML出力: トップHTMLファイル文字列を返す(例)"
  (concat
   "<html><head></head><frameset cols=\"300,500\" title=\"index\">
<frame src=\"" *outline-tree-output-html-frame-toc-file* "\" name=\"toc\" title=\"toc\">
<frame src=\"" *outline-tree-output-html-frame-main-file* "\" name=\"main\" title=\"main\">
</frameset></html>"))
(defun outline-tree-output-html-header-simple (&optional dummy)
  "HTML出力: メニュー部、メイン部ファイルの先頭から<body>までの文字列を返す(例)"
  "<html><head></head><body>")
(defun outline-tree-output-html-footer-simple ()
  "HTML出力: メニュー部、メイン部ファイルの</body>から最後までの文字列を返す(例)"
  "</body></html>")


(require "outline-tree/output-html-range")
(require "outline-tree/output-html-heading")

;; output-depth は現在は :expand のみ
(defun outline-tree-output-html (&optional (type :range) root-node output-depth frame-p
                                           (header 'outline-tree-output-html-header)
                                           (footer 'outline-tree-output-html-footer)
                                           (frame 'outline-tree-output-html-frame)
                                           (css 'outline-tree-output-html-css))
  "HTML 出力
type への指定        : :range, :heading
output-depth への指定: nil, :expand"
  (treeview::with-app (*outline-tree-app-id*)
    (unless (outline-tree-open-p)
      (return-from outline-tree-output-html))
    (unless root-node
      (setq root-node (outline-tree-get-buffer-node-by-window)))
    ;; outline が最新かどうかの判定
    (unless (outline-tree-latest-outline-p-by-node root-node)
      (return-from outline-tree-output-html))

    (let ((output-buffer (outline-tree-set-output-buffer))
          header-str footer-str frame-str
          (output-dir (outline-tree-output-get-output-dir))
          (filename (get-buffer-file-name (outline-tree-get-buffer-by-node root-node)))
          replace-string-alist target-node-count)
      ;; 出力ファイルの上書き確認
      (unless (outline-tree-output-confirm-output-files-p
               (cond (frame-p
                      (list *outline-tree-output-html-frame-frame-file*
                            *outline-tree-output-html-frame-toc-file*
                            *outline-tree-output-html-frame-main-file*))
                     (t
                      (list *outline-tree-output-html-file*)))
               output-dir)
        (return-from outline-tree-output-html))
      ;; ハイライト削除
      (outline-tree-delete-text-highlight)

      ;; 置換文字列作成
      (unless (stringp filename)
        (setq filename ""))
      (if (string-match "^.+[/\\]\\(.+\\)$" filename)
          (setq filename (match-string 1)))
      (if (string-match "^\\(.+\\)\\(\\.[^\\.]+\\)$" filename)
          (setq filename (match-string 1)))
      (push (cons "%filename%" filename) replace-string-alist)
      (push (cons "%nodename%" (outline-tree-data-get-node-name root-node))
            replace-string-alist)

      ;; type が :heading の場合の出力 range の設定
      (when (eq type :heading)
        (cond
         ((eq output-depth :expand)
          (outline-tree-set-data-output-range-tree-by-node root-node))
         (t
          (outline-tree-set-data-contents-range-tree-by-node root-node))))

      ;; 処理対象ノードのカウント
      (setq target-node-count
            (case type
              (:range
               (outline-tree-output-html-range-target-node-count root-node output-depth))
              (:heading
               (outline-tree-output-html-heading-target-node-count root-node output-depth))
              (t
               nil)))

      ;; FRAME HTML, ヘッダ、フッタ 文字列の取得
      (if frame-p
          (setq frame-str
                (cond
                 ((stringp frame)
                  frame)
                 ((or (functionp frame) (and (symbolp frame) (fboundp frame)))
                  (funcall frame))
                 (t ""))))
      (setq header-str
            (cond
             ((stringp header)
              header)
             ((or (functionp header) (and (symbolp header) (fboundp header)))
              (funcall header css))
             (t "")))
      (setq footer-str
            (cond
             ((stringp footer)
              footer)
             ((or (functionp footer) (and (symbolp footer) (fboundp footer)))
              (funcall footer))
             (t "")))

      ;; 置換文字列の適用
      (dolist (x replace-string-alist)
        (if frame-p
            (setq frame-str (substitute-string frame-str (car x) (cdr x))))
        (setq header-str (substitute-string header-str (car x) (cdr x)))
        (setq footer-str (substitute-string footer-str (car x) (cdr x))))

      (cond
       ;; FRAME 有りの場合
       (frame-p
        ;; frame file
        (with-output-to-buffer (output-buffer)
          (format t "~A" frame-str))
        (save-excursion
          (set-buffer output-buffer)
          (write-file (namestring
                       (merge-pathnames *outline-tree-output-html-frame-frame-file*
                                        output-dir)))
          (delete-region (point-min) (point-max)))
        ;; toc file
        (with-output-to-buffer (output-buffer)
          (format t "~A" header-str)
          (case type
            (:range
             (outline-tree-output-html-range-toc root-node target-node-count output-depth frame-p))
            (:heading
             (outline-tree-output-html-heading-toc root-node target-node-count output-depth frame-p))
            (t
             ""))
          (format t "~A" footer-str))
        (save-excursion
          (set-buffer output-buffer)
          (write-file (namestring
                       (merge-pathnames *outline-tree-output-html-frame-toc-file*
                                        output-dir)))
          (delete-region (point-min) (point-max)))
        ;; main file
        (with-output-to-buffer (output-buffer)
          (format t "~A" header-str)
          (case type
            (:range
             (outline-tree-output-html-range-main root-node target-node-count output-depth frame-p))
            (:heading
             (outline-tree-output-html-heading-main root-node target-node-count output-depth frame-p))
            (t
             ""))
          (format t "~A" footer-str))
        (save-excursion
          (set-buffer output-buffer)
          (write-file (namestring
                       (merge-pathnames *outline-tree-output-html-frame-main-file*
                                        output-dir)))
          (delete-region (point-min) (point-max))))
       ;; FRAME 無しの場合
       (t
        (with-output-to-buffer (output-buffer)
          (format t "~A" header-str)
          (case type
            (:range
             (outline-tree-output-html-range-toc root-node target-node-count output-depth frame-p)
             (outline-tree-output-html-range-main root-node target-node-count output-depth frame-p))
            (:heading
             (outline-tree-output-html-heading-toc root-node target-node-count output-depth frame-p)
             (outline-tree-output-html-heading-main root-node target-node-count output-depth frame-p))
            (t
             ""))
          (format t "~A" footer-str))
        (save-excursion
          (set-buffer output-buffer)
          (write-file (namestring
                       (merge-pathnames *outline-tree-output-html-file*
                                        output-dir)))
          (delete-region (point-min) (point-max)))))

      (delete-buffer output-buffer)

      ;; ファイルを開く
#|
      (delete-other-windows)
      (let ((window (get-buffer-window (selected-buffer))))
        (split-window)
        (other-window)
        (find-file (namestring
                    (merge-pathnames
                     (if frame-p
                         *outline-tree-output-html-frame-frame-file*
                       *outline-tree-output-html-file*)
                     output-dir)))
        (set-window window))
|#
      ;; ファイルを実行する
      (shell-execute (merge-pathnames
                      (if frame-p
                          *outline-tree-output-html-frame-frame-file*
                        *outline-tree-output-html-file*)
                      output-dir))
      ))
  (refresh-screen))

;;; output-html.l ends here
