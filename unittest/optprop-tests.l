;;; -*- Mode: Lisp; Package: USER; Encoding: utf-8 -*-
;;;
;;; optprop-tests.l - Tests for option and local option property sheets

(require "optprop")
(require "loptprop")

(defmacro check (form)
  `(unless ,form
     (error "Check failed: ~S" ',form)))

(defun find-prop-page-template (ident pages)
  (let ((page (find ident pages :key #'(lambda (x) (if (consp x) (car x) x)))))
    (when (consp page)
      (cadr page))))

(defun get-template-caption (tmpl)
  (cadr (find :caption tmpl :key #'(lambda (x) (if (consp x) (car x) nil)))))

(defun get-template-control-labels (tmpl)
  (let ((controls (cdr (find :control tmpl :key #'(lambda (x) (if (consp x) (car x) nil))))))
    (mapcar #'caddr controls)))

(deftest test-option-prop-page-captions ()
  "共通設定のタブ名が正しく整理されていること"
  (let ((captions (mapcar #'(lambda (page)
                              (if (consp page)
                                  (get-template-caption (cadr page))
                                (symbol-name page)))
                          ed::*option-prop-page*)))
    ;; 「全般」と「操作・編集」に改名されていること
    (check (member "全般" captions :test #'string=))
    (check (member "操作・編集" captions :test #'string=))
    (check (not (member "いろいろ" captions :test #'string=)))
    (check (not (member "さまざま" captions :test #'string=)))
    t)
  => t)

(deftest test-local-option-prop-page-captions ()
  "ローカル設定のタブ名が「バッファ設定」に改名されていること"
  (let ((captions (mapcar #'(lambda (page)
                              (if (consp page)
                                  (get-template-caption (cadr page))
                                (symbol-name page)))
                          ed::*local-option-prop-page*)))
    (check (member "バッファ設定" captions :test #'string=))
    (check (not (member "もろもろ" captions :test #'string=)))
    t)
  => t)

(deftest test-disp-page-improvements ()
  "表示タブから「ちゃんと反転する」が削除され、「表示項目」に改められていること"
  (let* ((tmpl (find-prop-page-template 'ed::disp ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (member "表示項目" labels :test #'string=))
    (check (not (member "表示する?" labels :test #'string=)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "ちゃんと反転する" s))) labels)))
    t)
  => t)

(deftest test-read-page-improvements ()
  "読み込みタブの改行判定が「自動判別」等の分かりやすいラベルになり、Mule-UCS設定が削除されていること"
  (let* ((tmpl (find-prop-page-template 'ed::read-file ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "てきとーに" s))) labels)))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "自動判別" s))) labels))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "勘弁しちゃる" s))) labels)))
    t)
  => t)

(deftest test-general-page-improvements ()
  "全般タブからレガシー設定（Global IME, MS-IME 2000）が削除され、Altメニューの文言が改善されていること"
  (let* ((tmpl (find-prop-page-template 'ed::misc ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "Global IME" s))) labels)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "MS-IME 2000" s))) labels)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "なんでALTでメニューが開かない" s))) labels)))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "Altキー単体でメニューを開く" s))) labels))
    t)
  => t)

(deftest test-operation-page-improvements ()
  "操作・編集タブからホイールマウスと[...]ワイルドカードが削除されていること"
  (let* ((tmpl (find-prop-page-template 'ed::misc2 ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "ホイールマウスに反応する" s))) labels)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "ワイルドカード" s))) labels)))
    t)
  => t)

(deftest test-directory-page-improvements ()
  "ディレクトリタブからレガシーなMSVC/MSDN設定が削除されていること"
  (let* ((tmpl (find-prop-page-template 'ed::directory ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "MSVC2.x" s))) labels)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "MSDN Info viewer" s))) labels)))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "HTMLヘルプ" s))) labels))
    t)
  => t)

(deftest test-kinsoku-page-improvements ()
  "禁則処理タブの「表示」「Fill」が分かりやすい文言に改められていること"
  (let* ((tmpl (find-prop-page-template 'ed::kinsoku ed::*option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (member "表示" labels :test #'string=)))
    (check (not (member "Fill" labels :test #'string=)))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "折り返し" s))) labels))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "段落整形" s))) labels))
    t)
  => t)

(deftest test-local-misc-page-improvements ()
  "ローカル設定のバッファ設定タブの文言が改善されていること"
  (let* ((tmpl (find-prop-page-template 'ed::misc ed::*local-option-prop-page*))
         (labels (get-template-control-labels tmpl)))
    (check (not (find-if #'(lambda (s) (and (stringp s) (string-match "文句を言わない" s))) labels)))
    (check (find-if #'(lambda (s) (and (stringp s) (string-match "保存確認しない" s))) labels))
    t)
  => t)
