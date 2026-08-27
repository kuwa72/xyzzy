;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; lisp/winner.l のテスト。
;;;
;;; 実際の運用では *post-command-hook* から winner-record が呼ばれるが、
;;; テストにはコマンドループが無いので winner-record を明示的に呼ぶ。
;;; 呼ばれる回数と順番は同じなので、記録側のロジックはこれで尽きている。
;;;
;;; リングはグローバルなので、各テストで let して隔離する。漏らすと
;;; 後のテストが前のテストのウィンドウ構成を復元しに行く。

(require "winner")

(defmacro with-winner-state (&body body)
  `(let ((ed::*winner-mode* t)
	 (ed::*winner-undo-ring* nil)
	 (ed::*winner-redo-ring* nil)
	 (ed::*winner-last-signature* nil)
	 (ed::*winner-last-configuration* nil))
     (save-window-excursion
       (delete-other-windows)
       (ed::winner-record)
       ,@body)))

(deftest winner-signature-changes-on-split ()
  "分割すると署名が変わること"
  (with-winner-state
    (let ((before (ed::winner-configuration-signature)))
      (split-window)
      (let ((after (ed::winner-configuration-signature)))
	(values (equal before after)
		(length before)
		(length after)))))
  => nil
  => 1
  => 2)

(deftest winner-signature-ignores-selection ()
  "選択中のウィンドウを移すだけでは署名が変わらないこと
(変わると Leader w u が「さっきのウィンドウへ戻る」だけの操作に化ける)"
  (with-winner-state
    (split-window)
    (let ((a (ed::winner-configuration-signature)))
      (other-window 1)
      (equal a (ed::winner-configuration-signature))))
  => t)

(deftest winner-undo-restores-previous-layout ()
  "分割した後の winner-undo で 1 枚に戻ること"
  (with-winner-state
    (split-window)
    (ed::winner-record)
    (let ((split-count (count-windows)))
      (ed::winner-undo)
      (values split-count (count-windows))))
  => 2
  => 1)

(deftest winner-redo-reapplies ()
  "winner-undo の後の winner-redo で分割が戻ること"
  (with-winner-state
    (split-window)
    (ed::winner-record)
    (ed::winner-undo)
    (let ((undone (count-windows)))
      (ed::winner-redo)
      (values undone (count-windows))))
  => 1
  => 2)

(deftest winner-undo-without-history ()
  "記録が無いときの winner-undo は何もせず nil を返すこと"
  (with-winner-state
    (values (ed::winner-undo) (count-windows)))
  => nil
  => 1)

(deftest winner-redo-without-history ()
  "戻していないときの winner-redo は何もせず nil を返すこと"
  (with-winner-state
    (ed::winner-redo))
  => nil)

(deftest winner-new-change-clears-redo ()
  "戻した後に別の変更を入れたら、やり直し先は捨てられること"
  (with-winner-state
    (split-window)
    (ed::winner-record)
    (ed::winner-undo)
    (let ((redo-before (length ed::*winner-redo-ring*)))
      ;; 別の変更 (今度は左右分割)
      (split-window nil t)
      (ed::winner-record)
      (values redo-before (length ed::*winner-redo-ring*))))
  => 1
  => 0)

(deftest winner-record-is-idempotent ()
  "構成が変わっていなければ何度呼んでも記録が増えないこと
(*post-command-hook* は打鍵ごとに呼ばれるので、ここが効かないと
リングが 1 文字ごとに埋まる)"
  (with-winner-state
    (split-window)
    (ed::winner-record)
    (let ((n (length ed::*winner-undo-ring*)))
      (ed::winner-record)
      (ed::winner-record)
      (ed::winner-record)
      (values n (length ed::*winner-undo-ring*))))
  => 1
  => 1)

(deftest winner-ring-is-bounded ()
  "*winner-ring-max* を超えて溜まらないこと"
  (with-winner-state
    (let ((ed::*winner-ring-max* 3))
      (dotimes (i 6)
	(if (evenp i) (split-window) (delete-other-windows))
	(ed::winner-record))
      (length ed::*winner-undo-ring*)))
  => 3)

(deftest winner-mode-off-records-nothing ()
  "*winner-mode* が nil なら記録しないこと"
  (with-winner-state
    (let ((ed::*winner-mode* nil))
      (split-window)
      (ed::winner-record)
      (length ed::*winner-undo-ring*)))
  => 0)

(deftest winner-hook-and-keys ()
  "*post-command-hook* に入っていて、Leader w u / w r に割り当てられていること"
  (values (and (member 'ed::winner-record ed::*post-command-hook*) t)
	  (lookup-keymap ed::*leader-window-map* #\u)
	  (lookup-keymap ed::*leader-window-map* #\r))
  => t
  => winner-undo
  => winner-redo)
