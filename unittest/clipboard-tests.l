;;; -*- Encoding: utf-8 -*-
;;;
;;; クリップボードの Lisp 入口 3 つ (issue #198)。
;;;
;;; `copy-to-clipboard' / `get-clipboard-data' / `clipboard-empty-p' は
;;; **フロントエンドごとに実装が全く違う**:
;;;
;;;   Win32 (src/frontend/win32/clipboard.cc)
;;;     本物の OS クリップボード。`OpenClipboard' / `EmptyClipboard' /
;;;     `SetClipboardData' で CF_UNICODETEXT を作る。**プロセスをまたぐ。**
;;;   端末 (src/frontend/ncurses/ncurses-stubs.cc)
;;;     プロセス内の `g_clipboard_buf` に持って、OSC 52 で端末へも送る。
;;;     読み出しは OSC 52 を使わず内部バッファを見る (往復に 500ms
;;;     かかるため)。**プロセス内で閉じている。**
;;;   ヘッドレス (src/frontend/cli/cli-stubs.cc)
;;;     何もしない (`nil` / `t`)。**スイートはこの exe を使わない**
;;;     (POSIX は `xyzzy --batch`、Win32 は `xyzzy-batch.exe`) ので、ここは
;;;     測っていない。
;;;
;;; **`(featurep :unix)' で分ける必要は無かった。** issue #198 は分けろと
;;; 書いていたが、下の性質を両方で実際に測ったら**返り値まで全部一致した**
;;; (linux native と Wine x86_64、14 項目)。一致しているものを分けて書くと、
;;; 片方が壊れたときに「元からそういう仕様」に見えてしまう。**分かれるのは
;;; プロセスをまたぐかどうかだけ**で、それは下で 1 件だけ分けてある。

;;; **他のプロセスのクリップボードを壊さないようにする。** Win32 では
;;; `copy-to-clipboard' が OS のクリップボードを本当に置き換えるので、
;;; デスクトップでスイートを走らせた人のコピー内容が消える。テキスト以外の
;;; 形式は戻せないが、テキストなら戻せる。
(defmacro with-saved-clipboard (&body body)
  `(let ((saved (get-clipboard-data)))
     (unwind-protect
         (progn ,@body)
       (when saved
         (copy-to-clipboard saved)))))
(setf (get 'with-saved-clipboard 'ed:lisp-indent-hook) 0)


(deftest clipboard-round-trip ()
  "書いたものが読める。**3 つの入口のうち 2 つを 1 件で通す。**"
  (with-saved-clipboard
    (list (copy-to-clipboard "abc")
          (get-clipboard-data)))
  => (t "abc"))

(deftest clipboard-empty-p-follows-the-copy ()
  "`clipboard-empty-p' が書いた後で nil になる。"
  (with-saved-clipboard
    (copy-to-clipboard "abc")
    (clipboard-empty-p))
  => nil)

;;; **非 ASCII は文字コードで見る。** 表示は stream の encoding を通るので、
;;; 内部が壊れていても正しく見えることがあるし、その逆もある (`--batch` の
;;; stdout が CP932 だった件、issue #229)。`char-code` は内部をそのまま出す。
(deftest clipboard-round-trip-keeps-non-ascii ()
  "端末は UTF-8 の OSC 52、Win32 は CF_UNICODETEXT。**どちらも変換が挟まる。**"
  (with-saved-clipboard
    (copy-to-clipboard "不正 あいう")
    (map 'list #'char-code (get-clipboard-data)))
  => (19981 27491 32 12354 12356 12358))

;;; **改行を文字コードで見るのも同じ理由。** Win32 のクリップボードの約束は
;;; CRLF なので、書くときと読むときで変換が入る。LF 1 個で往復することを
;;; 見ておくと、片側だけ変換を落としたときに分かる。
(deftest clipboard-round-trip-keeps-a-newline ()
  (with-saved-clipboard
    (copy-to-clipboard "a
b")
    (map 'list #'char-code (get-clipboard-data)))
  => (97 10 98))

;;; issue #198 の「空のときの約束」。**両方の実装が同じ形の guard を
;;; 持っている** (`if (!xstring_length (string)) return Qnil;`) ので、
;;; 偶然ではなく約束として書く: **空文字列では何も起きない。** クリップボードを
;;; 空にする Lisp の手段は無い (`EmptyClipboard' は copy の中でしか呼ばれない)。
(deftest clipboard-copying-the-empty-string-changes-nothing ()
  (with-saved-clipboard
    (copy-to-clipboard "abc")
    (list (copy-to-clipboard "")
          (get-clipboard-data)))
  => (nil "abc"))

(deftest clipboard-copy-requires-a-string ()
  "`check_string' が効いている。**シンボルを渡して黙って通ると気付けない。**"
  (with-saved-clipboard
    (handler-case
        (progn (copy-to-clipboard 'foo) :no-error)
      (type-error () :type-error)))
  => :type-error)

;;; **プロセスをまたぐかどうかは分かれる。** 端末の実装は
;;; `g_clipboard_buf` なので、別のプロセスから見ると空である。Win32 は
;;; OS のクリップボードなので親が書いたものが見える。
;;;
;;; **Win32 側はこのテストでは何も測っていない** (期待値をそのまま返す枝に
;;; なっている)。親が書いて子が読む形にすると、**同時に走っている別のプロセスが
;;; クリップボードを置き換えたら落ちる**テストになる。このリポジトリは
;;; 「手元だけ落ちる」を flaky と疑う側に倒してきた (PR #71) ので、**落ちうる
;;; テストを足すより測らないと書く方を選ぶ。**
(deftest clipboard-is-process-local-on-a-terminal ()
  (if (featurep :unix)
      (with-saved-clipboard
        (copy-to-clipboard "abc")
        (eval-in-another-xyzzy '(list (clipboard-empty-p)
                                      (get-clipboard-data))
                               :options "-q"))
    '(t nil))
  => (t nil))
