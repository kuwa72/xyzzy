;;; -*- Mode: Lisp; Encoding: utf-8 -*-
;;;
;;; バッファの並び順。**バッファには 2 つの順がある。**
;;;
;;;   内部の順   `Buffer::b_blist`。最後に選んだものが先頭に来る。
;;;   タブの順   バッファバー (Win32 のタブ) に並んでいる見た目の順。
;;;
;;; `buffer-list` の `:buffer-bar-order` と `get-next-buffer` の TAB-ORDER が
;;; 後者を指す。**バッファバーが無いときは前者に落ちる**のが仕様で、
;;; 端末には最初から無く、Win32 でも `buffer-bar` コマンドを実行するまで
;;; 無い。**テストはどちらのプラットフォームでもバーを作らないので、
;;; ここは同じことを聞いている** (だから `featurep` で分けていない)。
;;;
;;; この 2 つの入口は **1216 件のスイートに 1 件も無かった。** seam
;;; (`frontend_tab_order_*`、src/core/fns.h) に付け替えるときに気付いた
;;; (issue #185)。

(defun buffer-order-test-names (buffers)
  (mapcar #'buffer-name buffers))

(deftest buffer-list-returns-every-buffer ()
  "土台。`buffer-list` に今のバッファが居ること。"
  (and (member (selected-buffer) (buffer-list)) t)
  => t)

(deftest buffer-bar-order-falls-back-to-the-internal-order ()
  "**バーが無いときは内部の順を返す。** 0 (= 「並び順を持っていない」) を
返す seam に落ちるので、`:buffer-bar-order t` は素の `buffer-list` と
同じになる。**nil を返す実装にすると、ここが nil になって全バッファが
消える。**"
  (equal (buffer-order-test-names (buffer-list :buffer-bar-order t))
         (buffer-order-test-names (buffer-list)))
  => t)

(deftest buffer-bar-order-nil-is-the-plain-order ()
  ":buffer-bar-order に nil を渡したときはキーワードを付けないのと同じ。"
  (equal (buffer-order-test-names (buffer-list :buffer-bar-order nil))
         (buffer-order-test-names (buffer-list)))
  => t)

(deftest get-next-buffer-top-and-bottom-with-tab-order ()
  "`:top` / `:bottom` に TAB-ORDER を付けても、バーが無いので内部の順の
端が返る。**seam が 0 ではなく `Buffer::b_blist` を返してしまうと
`:bottom` がここで先頭を返す。**"
  (list (eq (get-next-buffer :top nil t) (get-next-buffer :top nil nil))
        (eq (get-next-buffer :bottom nil t) (get-next-buffer :bottom nil nil)))
  => (t t))

(deftest get-next-buffer-with-tab-order-matches-the-internal-order ()
  "バッファを指定したときの次と前。**TAB-ORDER の有無で変わらない。**"
  (let ((bp (selected-buffer)))
    (list (eq (get-next-buffer bp nil t) (get-next-buffer bp nil nil))
          (eq (get-next-buffer bp t t) (get-next-buffer bp t nil))))
  => (t t))

(deftest get-next-buffer-goes-around ()
  "2 つ以上あるとき、次の次で戻ってくる (バッファが 2 つのとき)。
**並び順が輪であることを測る。**"
  (let ((b1 (create-new-buffer "*buffer-order-1*"))
        (b2 (create-new-buffer "*buffer-order-2*")))
    (unwind-protect
        (let ((all (buffer-list)))
          ;; b1 と b2 が両方居て、それぞれの次を 2 回たどると
          ;; どこかで自分に戻る (輪なので、全バッファ数だけ回れば必ず)。
          (let ((bp b1) (n (length all)) (found nil))
            (dotimes (i n)
              (setq bp (get-next-buffer bp nil nil t))
              (when (eq bp b1) (setq found t)))
            (list (and (member b1 all) t)
                  (and (member b2 all) t)
                  found)))
      (delete-buffer b1)
      (delete-buffer b2)))
  => (t t t))

(deftest deleting-a-buffer-takes-it-out-of-the-list ()
  "**バッファが消えたことはフロントエンドにも伝わる**
(`frontend_buffer_deleted`)。Win32 はタブを取り除く。ここで測れるのは
`buffer-list` から消えることだけだが、**seam を呼び忘れると Win32 が
解放済みの `Buffer` を指したタブを持ったままになる。**"
  (let ((bp (create-new-buffer "*buffer-order-deleted*")))
    (let ((there (and (member bp (buffer-list)) t)))
      (delete-buffer bp)
      (list there
            (and (find "*buffer-order-deleted*" (buffer-list)
                       :key #'buffer-name :test #'string=)
                 t))))
  => (t nil))

(deftest deleting-a-buffer-with-tab-order-asked-for ()
  "削除の直後に `:buffer-bar-order` を聞いても壊れないこと。**タブの側に
消えたバッファが残っていると、ここで解放済みのオブジェクトを読む。**"
  (let ((bp (create-new-buffer "*buffer-order-deleted-2*")))
    (delete-buffer bp)
    (and (member (selected-buffer) (buffer-list :buffer-bar-order t)) t))
  => t)
