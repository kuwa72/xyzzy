# 変数と定数 (variables)

reference/reference.xml から自動生成。132 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*activate-hook*`

- Variable / package: editor

```text
バッファがactivateされたときに任意の処理を行うために使用されます。
デフォルトではファイルの修正日付を確認しています。
```

関連: `verify-buffers-file-modtime`, `*deactivate-hook*`

## `*after-save-buffer-hook*`

- Variable / package: editor

```text
多分 save-buffer の最後に実行されます。
```

関連: `save-buffer`

## `*auto-fill-hook`

- Variable / package: editor / 定義: cmds.l

```text
auto-fill-mode の時に、self-insert-command から *last-command-char*
を引数として実行されます。普通は do-auto-fill が設定されています。
多分修正しない方が良いと思います。
※ run-hooks ではなく、 funcall されるので注意すること
```

関連: `auto-fill-mode`, `auto-fill-hook`, `self-insert-command`, `funcall`

## `*before-delete-buffer-hook*`

- Variable / package: editor

```text
delete-bufferを継続するかどうかを制御します。登録された関数が一
つでもnilを返すとdelete-bufferを中止します。

参考：
  ;;; 呼び出し方
  (run-hook-with-args-until-success
       '*before-delete-buffer-hook* (selected-buffer))

使用例：
  (add-hook '*before-delete-buffer-hook* 'func)
  =>(func)
  (defun func (x) (yes-or-no-p "delete-buffer ~A ?" (buffer-name x)))
  =>func
```

関連: `delete-buffer`, `*delete-buffer-hook*`

## `*before-find-file-hook*`

- Variable / package: editor / 定義: files.l

```text
find-fileの最初で実行されます。
※run-hook-with-args-until-successで実行されるので注意すること
```

関連: `find-file`

## `*before-grep-hook*`

- Variable / package: editor / 定義: grep.l

```text
grep起動前に実行されます。
フックの引数は検索キーワード(or regex string)です。
フック実行時のselected-bufferはgrepバッファです。
```

関連: `*grep-hook*`, `*grepd-hook*`, `*before-grepd-hook*`

## `*before-grepd-hook*`

- Variable / package: editor / 定義: grepd.l

```text
grep-dialog起動前に実行されます。
フックの引数は検索キーワード(or regex string)です。
フック実行時のselected-bufferはgrepバッファです。
```

関連: `*grep-hook*`, `*grepd-hook*`, `*before-grep-hook*`

## `*before-save-buffer-hook*`

- Variable / package: editor

```text
多分 save-buffer の最初に実行されます。
※ run-hook-with-args-until-success で実行されるので注意すること
```

関連: `save-buffer`, `run-hook-with-args-until-success`

## `*brackets-is-wildcard-character*`

- Variable / package: lisp

```text
non-nil ならばファイルパスとして渡した文字列中の [...] をワイルドーカー
ドとして扱います。
[共通設定] - [さまざま] - [[...]はワイルドカード(I)] で値を指定すること
ができます。
xyzzy ソース内で定義されており、デフォルト値は t です。
具体的には、wild-pathname-p, pathname-match-p 関数での判定の際に
*brackets-is-wildcard-character* の値が考慮されます。
```

関連: `wild-pathname-p`, `pathname-match-p`

## `*change-buffer-colors-hook*`

- Variable / package: editor

```text
途中
```

## `*change-clipboard-hook*`

- Variable / package: editor

```text
クリップボードに値が設定された時に処理を行うために使用されます。
デフォルトではクリップボードの同期を行っています。

補足：
  xyzzy 0.2.2.250 から利用可能です。
```

## `*command-line-mailto-hook*`

- Variable / package: editor / 定義: estartup.l

```text
コマンドラインで指定された -mailto オプションの引数を元に実行されます。 
※run-hooksではなくfuncallされるので注意すること
```

関連: `起動時処理フロー`

## `*create-buffer-hook*`

- Variable / package: editor

```text
多分create-new-bufferで実行されます。
```

関連: `*default-buffer-mode*`, `create-new-buffer`

## `*deactivate-hook*`

- Variable / package: editor

```text
バッファがdeactivateされたときに任意の処理を行うために使用されま
す。デフォルトではクリップボードの同期を行っています。
```

関連: `*activate-hook*`

## `*debug-output*`

- Variable / package: editor

```text
現在のデバッガに文字列を送信する出力ストリームです。
出力したメッセージはDebugViewやVisualStudioの出力ウィンドウで確認可能です。

補足：
  xyzzy 0.2.2.246 から利用可能です。
```

関連: `si:output-debug-string`, `debug-output-stream-p`

## `*default-load-path*`

- Variable / package: editor / 定義: misc.l

```text
siteinit.lから*load-path*を修正するために用いられます。
siteinit.lの直後に*default-load-path*の内容が、*load-path*にマー
ジされ、*pre-startup-hook*から有効になります。
追加するパスはリストで設定します。

使用例：
  (setq *default-load-path* '("C:/APPLICATIONS/XYZZY/lib"))
```

関連: `*load-path*`

## `*delete-buffer-hook*`

- Variable / package: editor

```text
delete-bufferで実行されます。
```

関連: `delete-buffer`, `*before-delete-buffer-hook*`

## `*drag-and-drop-hook*`

- Variable / package: editor / 定義: mouse.l

```text
D&D時に実行されます。デフォルトでは、D&D先がミニバッファ
ならミニバッファへの入力として扱い、それ以外ならfind-fileする
ようになっています。

※run-hooksではなくfuncallされます。引数は2つで、ドロップされたウィンド
  ウとドロップしたファイルのリストです。
```

## `*etc-path*`

- Variable / package: editor / 定義: misc.l

```text
キーワードファイル等を格納するパスが設定されています。
標準では(merge-pathnames "etc" (si:system-root))が設定されています。

参照例：
  *etc-path*
  => "C:/APPLICATIONS/XYZZY/etc"
```

関連: `etc-path`

## `*find-buffer-package-hook*`

- Variable / package: editor / 定義: lispmode.l

```text
eval-region時のパッケージを決定する際に利用します。

eval-region時パッケージの決定は以下の順序になります。
1.*buffer-package*に代入された値
2.*find-buffer-package-hook*の評価結果

補足：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `eval-region`, `*buffer-package*`, `set-buffer-package`

## `*find-file-file-not-found-hook*`

- Variable / package: editor / 定義: files.l

```text
find-file で指定されたファイルが存在しないときに実行されます。
※run-hook-with-args-until-successで実行されるので注意すること
```

関連: `find-file`, `run-hook-with-args-until-success`

## `*grep-directory-name-hook*`

- Variable / package: editor / 定義: grepd.l

```text
grep-dialogでgrep対象のディレクトリを個々に設定したい場合に実行
されます。
※funcallされるので注意すること
```

関連: `*grep-hook*`

## `*grep-hook*`

- Variable / package: editor / 定義: grep.l

```text
grep起動後に実行されます。
```

関連: `*grepd-hook*`, `*before-grep-hook*`, `*before-grepd-hook*`

## `*grep-ignored-directories*`

- Variable / package: editor / 定義: grepd.l

```text
grep-dialogおよびgresreg-dialogで無視するサブディレクトリを指定します。
標準では以下のディレクトリが設定されています。

  *grep-ignored-directories*
  => ("SCCS" "RCS" "CVS" "MCVS" ".svn" ".git" ".hg" ".bzr" "_MTN" "_darcs" "{arch}")

たとえばtmpを無視したい場合は以下のようにします。

  (require "grepd")
  => t

  (pushnew "tmp" *grep-ignored-directories* :test #'string-equal)
  => ("tmp" "SCCS" "RCS" "CVS" "MCVS" ".svn" ".git" ".hg" ".bzr" "_MTN" "_darcs" "{arch}")
```

## `*grepd-hook*`

- Variable / package: editor / 定義: grepd.l

```text
grep-dialog起動後に実行されます。
```

関連: `*grep-hook*`, `*before-grep-hook*`, `*before-grepd-hook*`

## `*gresreg-directory-name-hook*`

- Variable / package: editor / 定義: gresregd.l

```text
gresreg-dialog で gresreg 対象のディレクトリを個々に設定したい場合
に実行されます。
※funcallで実行されるので注意すること
```

関連: `gresreg-dialog`

## `*history-file-name*`

- Variable / package: editor / 定義: history.l

```text
ヒストリを保存するファイル名です。
nil の場合は関数 history-file-name において
適当に決定されます。

例:
  *history-file-name*
  =>"X:/xyzzy/usr/username/wxp/.xyzzy.history"
```

## `*inhibit-quit*`

- Variable / package: editor

```text
この値が t のとき、 quit-char を入力しても無視されます。
```

関連: `quit-char`

## `*keyword-load-path*`

- Variable / package: editor / 定義: kwd.l

```text
キーワードファイルのパスをリストで設定します。
指定されたキーワードファイルがこのリストから見つからない場合には、
etc-pathで取得されるパスを検索します。

使用例：
  (pushnew (merge-pathnames "keyword" (si:system-root))
           *keyword-load-path* :test #'string=)
```

関連: `load-keyword-file`, `*etc-path*`, `キーワードファイルの書き方`, `キーワードファイルのカスタマイズ`

## `*kill-buffer-kills-scratch*`

- Variable / package: editor / 定義: lispmode.l

```text
*kill-buffer-kills-scratch*がnon-nilの場合には、kill-bufferで
*scratch*が削除可能です。デフォルトはnilになっています。
```

関連: `kill-buffer`

## `*kill-xyzzy-hook*`

- Variable / package: editor

```text
xyzzyの終了時に実行されます。
```

関連: `kill-xyzzy`, `*query-kill-xyzzy-hook*`

## `*last-command*`

- Variable / package: editor

```text
最後に実行したコマンドが入っています。直前の *this-command* の値が設定されます。
```

関連: `*this-command*`

## `*lisp-popup-completion-list*`

- Variable / package: editor / 定義: lispmode.l

```text
lisp-complete-symbol 時の補完候補をポップアップ表示するかを設定します。 

動作:
  *lisp-popup-completion-list*
    :always   ポップアップ表示
    :never    *Completion*バッファで表示

    *popup-completion-list-default*
      :always ポップアップ表示
      :never  *Completion*バッファで表示

    non-nil   ポップアップ表示
    nil       *Completion*バッファで表示
```

関連: `lisp-complete-symbol`, `*popup-completion-list-default*`

## `*load-history-hook*`

- Variable / package: editor / 定義: history.l

```text
.xyzzy処理後に実行されます。コマンドバー、セッション等のヒストリ変
数の読み込みに使用されています。
```

関連: `起動時処理フロー`

## `*load-path*`

- Variable / package: lisp

```text
ライブラリをロードするパスがリストで設定されています。
直接リストを修正するよりも、siteinit.lで *default-load-path* 
に追加する方が好ましいようです。
```

関連: `si:*load-library`, `load-library`, `*default-load-path*`, `find-load-path`

## `*make-backup-filename-hook*`

- Variable / package: editor / 定義: backup.l

```text
（多分触らないほうがいいと思われます）
```

## `*menu-display-length*`

- Variable / package: editor / 定義: app-menu.l

```text
メニューの「最近使ったファイル」で表示されるファイルパスの長さを指定します。
デフォルトでは40です。
```

## `*minibuffer-buffer-name-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファのバッファ名の履歴です。
```

## `*minibuffer-directory-name-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファのディレクトリ名の履歴です。
```

## `*minibuffer-execute-history*`

- Variable / package: editor / 定義: minibuf.l

```text
（詳細不明）
```

## `*minibuffer-file-name-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファのファイル名の履歴です。
```

関連: `add-file-history-to-menu`

## `*minibuffer-lisp-sexp-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファのS式の履歴です。
```

## `*minibuffer-search-string-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファの検索文字の履歴です。
```

## `*minibuffer-symbol-name-history*`

- Variable / package: editor / 定義: minibuf.l

```text
ミニバッファのシンボル名の履歴です。
```

## `*post-command-hook*`

- Variable / package: editor

```text
コマンドループにおいてコマンドの実行後に実行されます。
```

関連: `*pre-command-hook*`

## `*post-startup-hook*`

- Variable / package: editor / 定義: estartup.l

```text
初期設定ファイル.xyzzy実行後に以下の順番でフック変数が評価されま
す。
  1. *load-history-hook*
  2. *init-app-menu-hook*
  3. *command-line-mailto-hook*（-mailtoがある場合）
  4. *process-command-line-hook*（不明なオプションがある場合）
  5. *post-startup-hook*
```

関連: `起動時処理フロー`

## `*pre-abbrev-expand-hook*`

- Variable / package: editor / 定義: abbrev.l

```text
expand-abbrevの最初に実行されます。
```

関連: `expand-abbrev`

## `*pre-command-hook*`

- Variable / package: editor

```text
コマンドループにおいてコマンドの実行前に実行されます。
```

関連: `*post-command-hook*`

## `*pre-startup-hook*`

- Variable / package: editor / 定義: estartup.l

```text
初期設定ファイルsiteinit.l実行後に実行されます。
```

関連: `起動時処理フロー`

## `*prefix-args*`

- Variable / package: editor

```text
コマンドが数引き数付きで呼ばれた場合に設定される変数です。

  (defun test1 ()
    (interactive)
    (message "~s,~s " *prefix-args* *prefix-value*))

例えば、C-u 10 M-x test1と呼び出されると、
*prefix-args* が non nil になり、 *prefix-value* に値が入ります。
```

関連: `*prefix-value*`, `universal-argument`

## `*prefix-value*`

- Variable / package: editor

```text
コマンドが数引き数付きで呼ばれた時に数値が入ります。
```

関連: `*prefix-args*`, `universal-argument`

## `*print-circle*`

- Variable / package: lisp

```text
循環リストの表示を省略形にします

標準はnilです。read-eval-printのループでの
表示は常にtのようです。

(setq *print-circle* nil) => nil
(setq x (list 'a))        => (a)
(setf (cdr x) x)          => #1=(a . #1#)
(princ x)
=> (a a a ...
;;無限に続くのでC-gで終了
(setq *print-circle* t)   => t
(princ x)
#1=(a . #1#)
=> #1=(a . #1#)
```

関連: `*print-length*`

## `*print-completion-list-hook*`

- Variable / package: editor / 定義: complete.l

```text
do-completion実行時に、補完リストを表示するために使用されています。
ポップアップ表示の前に処理されます。 
※funcallで実行されるので注意すること
  
使用例：
  (setq *print-completion-list-hook*
        #'(lambda (list prefix &optional string)
            (popup-string
             (format nil
                     "Possible completions are ~D items:\n~{\n~A~}"
                     (length list) list) (point))))
```

関連: `*popup-completion-list-default*`, `*print-completion-sort-function*`

## `*print-completion-sort-function*`

- Variable / package: editor / 定義: complete.l

```text
do-completion実行時に、補完リストをソートする比較関数を指定します。
デフォルトはstring<です。nilを指定するとソートは行いません。

使用例：
  (setq *print-completion-sort-function* #'string-lessp)

補足：
  xyzzy 0.2.2.244 から利用可能です。
```

関連: `*print-completion-list-hook*`

## `*print-length*`

- Variable / package: lisp

```text
長いリストの表示を途中で打ち切ります。

(setq *print-length* nil) => nil
(princ '(a b c d e f g h i j))
=>(a b c d e f g h i j)

(setq *print-length* 5)   => 5
(princ '(a b c d e f g h i j))
=>(a b c d e ...)
```

関連: `*print-circle*`

## `*print-pretty*`

- Variable / package: lisp

```text
式の表示を見やすくします。

標準はtです。

(flet ((f (x) (princ x) (terpri)))
  (let ((*print-pretty* t))
    (f '('a #'b))  ;;tの時の表示
    (setq *print-pretty* nil)
    (f '('a #'b))));;nilの時の表示
=> ('a #'b)
   ((quote a) (function b))
```

## `*query-kill-buffer-hook*`

- Variable / package: editor / 定義: buffer.l

```text
kill-buffer で実行されます。バッファの破棄を確認するために使用します。
※run-hook-with-args-while-successで実行されるので注意すること。
```

関連: `kill-buffer`, `run-hook-with-args-while-success`

## `*query-kill-xyzzy-hook*`

- Variable / package: editor

```text
xyzzy終了時に実行されます。このフック変数の実行がnilだと終了しません。
[xyzzy:03872]を参照
```

関連: `*kill-xyzzy-hook*`

## `*read-eval*`

- Variable / package: lisp

```text
読み取り時評価(read-time evaluation)を制御します。
*read-eval*がnon-nilなら #. リーダマクロは通常どおり直後のS式を評価した結果を値とします。
nilならreader-errorが発生します。

標準はtです。

(let ((*read-eval* nil))
  (read-from-string "#.(+ 1 1)"))
=> Line 1: リード時の評価が許されていません

(let ((*read-eval* t))
  (read-from-string "#.(+ 1 1)"))
=> 2
   9

補足：
  xyzzy 0.2.2.236 から利用可能です。
```

## `*save-buffer-no-filenames-hook*`

- Variable / package: editor

```text
get-buffer-file-name が nil とかだと実行されます。
使用例:
  (add-hook '*save-buffer-no-filenames-hook*
          #'(lambda ()
              (if (yes-or-no-p "保存しますか")
                  ;;この時点で set-buffer-file-name をしても遅い。
                  ;;emacs-write-file なりを呼んでからnon-nilを渡すべき
                  (emacs-write-file (read-file-name "filename:"))
                ;;次のhookに処理を渡す場合はnilを渡す
                nil)))
```

関連: `save-buffer`, `get-buffer-file-name`

## `*save-history*`

- Variable / package: editor / 定義: history.l

```text
保存するヒストリの個数です。
[共通設定] - [いろいろ] - [保存するヒストリの個数(S)] で値を指定すること
ができます。
```

## `*save-history-hook*`

- Variable / package: editor / 定義: history.l

```text
*kill-xyzzy-hook*実行時に呼び出されます。
コマンドバー、セッション等のヒストリ変数の保存に使用されています。
```

## `*save-resume-info*`

- Variable / package: editor / 定義: history.l

```text
non-nil ならば終了時の状態を保存します。
[共通設定] - [さまざま] - [終了時の状態を保存する(U)] で値を指定すること
ができます。
```

## `*show-match-hook*`

- Variable / package: editor / 定義: search.l

```text
検索で一致したものの表示に使用しています。設定されていなければ、
show-matchが実行されます。
※run-hook-with-args-while-successで実行されるので注意すること。
```

関連: `search-dialog`

## `*sync-kill-ring-with-clipboard*`

- Variable / package: editor / 定義: region.l

```text
non-nil ならば削除バッファとクリップボードを同期します。
[共通設定] - [さまざま] - [削除バッファとクリップボードを同期する(C)] で値を
指定することができます。

  t       : 削除バッファとクリップボードを中途半端に同期します。
            xyzzyから他のアプリに切り替えるタイミングで削除バッファの方が
            新しければ削除バッファの内容をクリップボードにコピーします。
            また、yank (C-y) のタイミングでクリップボードの方が新しければ
            クリップボードの内容を削除バッファにコピーします。
  :always : 削除バッファとクリップボードを完全に同期します。
            削除バッファやクリップボードにコピーされたタイミングで
            すぐに同期します。
            クリップボードにコピーされた内容は削除バッファに追加されてるので、
            yank-pop (M-y) で遡って貼り付けることができます。
  nil     : 削除バッファとクリップボードを同期しません。

補足：
  :always は xyzzy 0.2.2.250 から利用可能です。
```

## `*this-command*`

- Variable / package: editor

```text
現在実行中の関数名のシンボルを格納しています。*last-command*に設定されます。
*pre-command-hook* / *post-command-hook*で特別な処理をかますのに使ったり、
実行中のコマンドを偽ったりできます。
```

関連: `*last-command*`

## `*xyzzyenv-show-flag*`

- Variable / package: editor

```text
make-processで外部コマンドを実行するときのxyzzyenv.exeの
表示を指定します。

  :show      通常のウィンドウ
  :no-active 非アクティブ
  :minimize  最小化
  :maximize  最大化
  :hide      非表示
  上記以外   通常のウィンドウ

補足：
  xyzzy 0.2.2.242 から利用可能です。
```

関連: `make-process`

## `:case-fold`

- Keyword / package: keyword

```text
検索する場合に大文字と小文字を区別するかどうかを指定します。

  t     大文字と小文字を区別しません。
  nil   大文字と小文字を区別します。
```

関連: `scan-buffer`

## `:key`

- Keyword / package: keyword

```text
assoc や member、find などの関数で検索をする際に
各要素に適用する関数を指定します。
言い換えると、:test や :test-not で指定された関数に渡す値を
各要素から“取り出す”方法をこの関数で指定します。

使用例:
  ;; car が 'a である要素を除去する
  (remove 'a '((a . b) (b . x) (c d e) (a f h i) (x y)) :key #'car)
  => ((b . x) (c d e) (x y))
  ;; :test と組み合わせることも可能
  (remove "a" '(("a" . "b") ("b" . "c") ("d" . "a") ("a" . "e") ("b". "b"))
          :test #'string= :key #'car)
  => (("b" . "c") ("d" . "a") ("b" . "b"))
```

関連: `:test`, `:test-not`

## `:no-dup`

- Keyword / package: keyword

```text
検索する場合に同じ位置から行うかどうかを指定します。

  t     ひとつ次から検索を行う。
  nil   同じ位置から検索を行う。
```

関連: `scan-buffer`

## `:regexp`

- Keyword / package: keyword

```text
検索文字列が正規表現か否かを指定します。

  t     検索文字列は正規表現
  nil   検索文字列はただの文字列
```

関連: `scan-buffer`

## `:reverse`

- Keyword / package: keyword

```text
検索する場合に正方向か逆方向かを指定します。

  t     逆方向に検索します。
  nil   正方向に検索します。
```

関連: `scan-buffer`

## `:right-bound`

- Keyword / package: keyword

関連: `scan-buffer`

## `:tail`

- Keyword / package: keyword

```text
検索した場合にカーソルを文字列の先頭か末尾のどちらに位置づけるかを指定します。

  t     カーソルを末尾に位置づけます。
  nil   カーソルを先頭に位置づけます。
```

関連: `scan-buffer`

## `:test`

- Keyword / package: keyword

```text
assoc や member、find などの関数で検索をする際に、
このキーワードに設定した関数を用いて真偽の判定をします。

なお :test-not と同時に指定することはできません。

使用例:
  (assoc "b" '(("a" . 1) ("B" . 2) ("b" . 3) ("c" . 4)))
  => nil
  (assoc "b" '(("a" . 1) ("B" . 2) ("b" . 3) ("c" . 4)) :test #'string=)
  => ("b" . 3)
  (assoc "b" '(("a" . 1) ("B" . 2) ("b" . 3) ("c" . 4)) :test #'string-equal)
  => ("B" . 2)
```

関連: `:test-not`, `:key`

## `:test-not`

- Keyword / package: keyword

```text
assoc や member、find などの関数で検索をする際に、
このキーワードに設定した関数の逆（not）を用いて真偽の判定をします。
  
なお :test と同時に指定することはできません。

使用例:
  ;; "abc" を含む文字列を選ぶ = "abc" を含まない文字列を除去する
  (remove "abc" '("abcd" "test" "xabcx" "abc" "xyz") :test-not #'string-match)
  => ("abcd" "xabcx" "abc")
```

関連: `:test`, `:key`

## `add-history`

- Function / package: editor / 定義: minibuf.l
- 呼び出し: `add-history ITEM VAR`

```text
VAR に ITEM を LRU順で追加します。 *minibuffer-maximum-history-count* 
を超えるときは、最も使用されていないヒストリを削除します。

また、 *minibuffer-enable-add-to-menu* が non-nil のときに、
(get VAR 'add-lru-menu-function) に関数が設定されていれば、
その関数を実行します。例えば、 *minibuffer-file-name-history* には、 
add-file-history-to-menu が設定されており、開いたファイルをメニューの
「最近使ったファイル(F)」に登録しています。

使用例：
  (add-history file '*minibuffer-file-name-history*)
  (add-history cmd '*minibuffer-execute-history*)
```

関連: `*minibuffer-maximum-history-count*`, `*minibuffer-enable-add-to-menu*`

## `auto-fill-hook`

- Variable / package: editor

```text
入力の結果、fill-columnを越えたらdo-auto-fillから実行されます。
```

関連: `*auto-fill-hook`

## `auto-save`

- BufferLocal / package: editor

```text
自動保存を行うかを制御するためのフラグです。
個々のバッファ毎や特定のモードだけしたくないのであれば、使用例の様にロー
カル変数にします。

  t     自動保存する
  nil   自動保存しない

使用例：
  ;;; 現在のバッファは自動保存しないようにする。
  (make-local-variable 'auto-save)
  => t  
  (setq auto-save nil)
  => nil
```

関連: `setup-temp-buffer`

## `buffer-read-only`

- BufferLocal / package: editor

```text
バッファが読み取り専用かどうかを管理します。

  t     バッファは読み取り専用
  nil   バッファは読み書き可能
```

関連: `toggle-read-only`, `setup-temp-buffer`

## `call-arguments-limit`

- Variable / package: lisp

```text
関数に与えることのできる引数の個数の限界値

参照例： 
  call-arguments-limit
  => 536870911
```

関連: `lambda-parameters-limit`

## `char-code-limit`

- Variable / package: lisp

```text
文字コードの限界値を定めている定数(65536)です。
*character-name-hash-table* を設定する
(make-character-name-hash-table) 関数の定義中でのみ使用されています。
xyzzy ソース内で定義されています。
```

関連: `*character-name-hash-table*`, `make-character-name-hash-table`

## `constantp`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `constantp OBJECT`

```text
オブジェクトがconstantかどうかを返します。

  t     オブジェクトはconstant
  nil   オブジェクトはconstantでない

使用例：
  ;;; defvar/defconstantの違い
  (defvar foo 2)
  => foo
  (defconstant bar 3)
  => bar
  (constantp 'foo)
  => nil
  (constantp 'bar)
  => t
```

関連: `defconstant`

## `declaim`

- Macro / package: lisp / 定義: typespec.l
- 呼び出し: `declaim &rest DECL-SPECS`

```text
変数をスペシャル変数にします。proclaim のマクロ版です。
```

関連: `declare`, `proclaim`

## `declare`

- Misc / package: lisp

```text
Common Lispの機能で、「変数を動的に bind しろ」と宣言する事です。
Emacs Lispではそもそも動的にしか bind できないので存在しません。

  (declare (special 変数名))

違いを図示します。

  ;;; 大域変数 x          ┏大域変数━━━━━━┓    Common Lisp/xyzzy lisp：
  (setq x 0)              ┃x │0             ←╂─┐大域変数のxを参照する。
                          ┠─┴────────┨  │(+ 0 12)となる
  ;;; 関数 bar            ┃                    ┃  │
  (defun bar (x)          ┃┏(bar 34)━━━━┓┃  │    Emacs Lisp：
    (foo 12))             ┃┃x │34        ←╂╂─│─┐呼び出しスタックの
                          ┃┠─┴──────┨┃  │  │深いところのxを参照する。
  ;;; 関数 foo            ┃┃                ┃┃  │  │(+ 34 12)となる。
  (defun foo (y)          ┃┃┏(foo 12)━━┓┃┃  │  │
     (+ x y))    ... ※   ┃┃┃y │12      ┃┃┃  │  │
                          ┃┃┠─┴────┨┃┃  │  │
                          ┃┃┃(+ x y)   ─╂╂╂─┴─┘

とあったときに(bar 34)と呼び出すと、古いLispでは(Emacs Lispを含む）
※の時点で x = 34, y = 12と見えます。ところが、Common Lispやxyzzy lispでは
※の時点で x = 0,  y = 12と見えます。

昔Lispはインタープリタだったので、動的バインディングでもよかったんだけど、
コンパイラを作る時に、効率上なにかと問題があってCommon Lisp
では、静的バインディングに変更になりました。

でも、そうすると、古いコードを移植するのが大変になるので、

                          ┏大域変数━━━━━━┓    
                          ┃x │0               ┃
                          ┠─┴────────┨
  ;;; 関数 bar            ┃                    ┃    
  (defun bar (x)          ┃┏(bar 34)━━━━┓┃    Common Lisp/xyzzy lisp：
    (declare (special x)) ┃┃x │34        ←╂╂─┐大域変数ではなく
    (foo 12))             ┃┠─┴──────┨┃  │スタック上のxを参照する。
                          ┃┃                ┃┃  │(+ 34 12)となる。
                          ┃┃┏(foo 12)━━┓┃┃  │
                          ┃┃┃y │12      ┃┃┃  │
                          ┃┃┠─┴────┨┃┃  │
                          ┃┃┃(+ x y)   ─╂╂╂─┘

と書いてやると古いLisp(Emacs Lisp)のように動くという訳。
```

関連: `special`

## `defconstant`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `defconstant NAME VALUE &optional DOC`

```text
定数を宣言します。

使用例：
  ;;; encoding.lの中より
  (defconstant *eol-crlf* 1)
  => *eol-crlf*
```

関連: `constantp`, `defvar`

## `define-history-variable`

- Macro / package: editor / 定義: history.l
- 呼び出し: `define-history-variable NAME &optional (INITIAL-VALUE nil sv) DOC`

```text
ヒストリ変数を定義します。

  NAME          : ヒストリ変数名を指定します。
  INITIAL-VALUE : 初期値を設定します。
  DOC           : 変数の説明を指定します。

ヒストリ変数とは、次回のxyzzyの立ち上げまで値を保持してくれる(lispを書く
人には)便利な変数です。ヒストリ変数がないと各マクロごとに独自の保存方法
をとらないといけませんが、ヒストリ変数のおかげで宣言するだけで変数の状態
を保存することが可能な優れものです。

ただし、一旦作成したヒストリ変数はいつまでも残ってしまうので、
不要になったらed::*history-variable-list*を確認した上で、
unregister-history-variableで削除して下さい。

使用例：
  ;;; grepd.lより
  (define-history-variable *grep-directory-history* nil)
  (define-history-variable *grep-file-history* nil)
```

関連: `register-history-variable`, `unregister-history-variable`

## `defparameter`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `defparameter NAME VALUE &optional DOC`

```text
グローバルなスペシャル変数を宣言し、指定した値に設定します。
defvar に似ていますが、VALUE は省略できません。
また NAME がすでに値を持つ場合でも VALUE が評価され、結果が変数値として
設定されます。
```

関連: `defvar`

## `defstruct`

- Macro / package: lisp / 定義: struct.l
- 呼び出し: `defstruct NAME-AND-OPTIONS &rest REST`

```text
構造体を定義します。C言語のstruct文に相当します。
オプションとして以下のものを指定できます。
以下、xxxx の部分には構造体名が入ります。

  :conc-name         通常、xxxx-スロット名 という名前を持つ関数で変数に
                     アクセスしますが、この名前を変更します。xxxx- 
                     の部分に相当する名前を指定します。
  :constructor       指定したコンストラクタを生成します。
                     複数の :constructor 宣言することができます。 引数には
                       コンストラクタ名 (変数名1 変数名2 ... 変数名n)
                     の様に指定します。&key や &optionalを使用したり、
                     スロットのデフォルト値とは異なるデフォルト値を指定できま
                     す。
                     これ以上の詳細は不明です。
  :copier            コピー関数名を指定したものに変更します。異なる動作をする
                     関数を指定できるわけではありません。
                     コピー関数は、新しい構造体オブジェクトを作ってスロットを
                     コピーします。新旧の構造体で各スロットは、同じオブジェク
                     トを共有します。
  :predicate         指定された構造体であるか否かを調べる関数名を指定します。
                     この名前を持つ述語をシステムが生成します。
                     デフォルトは、 xxxx-p です。
  :include           他の構造体名を指定することで、構造体を継承します。
                     継承した構造体にある変数の宣言が、この構造体でも宣言され
                     ているものとして扱われます。
                     これ以上の詳細は不明です。
  :print-function    オブジェクトを print する時に使われる関数を指定します。
                     format関数の ~A などでオブジェクトをプリントする時に呼び出
                     される関数が変わります。指定する関数は3つの引数をとり、
                     順にオブジェクト、ストリーム、（詳細不明）をとります。
                     第3引数は、pretty printに関する値が来ます。
                     :print-function が指定されない場合、 #S 構文でプリントさ
                     れます。
  :type              （詳細不明）
  :named             （詳細不明）
  :initial-offset    （詳細不明）

引数:
  NAME-AND-OPTIONS   オプションを指定しないときは構造体名、オプションを指定する
                     ときは、
                       (構造体名 (オプション名1 値1) (オプション名2 値2) ... )
                     の様に指定します。
  REST               構造体のスロットを指定します。スロット名のみを書くか、
                       (スロット名 デフォルト値 :type タイプ名 :read-only フラグ) 
                     の様に書いてひとつのスロットを定義します。 
                     :type と :read-only は、逆順にしても片方のみでも構いません。
                     リスト形式で書いた場合、後ろから順に省略できます。
                     タイプ名は、この構造体のオブジェクトであるかどうかを調べる
                     述語の生成に使うことができますが、xyzzy では使われていない
                     ようです。

特にオプション指定しないと make-xxxx, copy-xxxx, xxxx-p, xxxx-変数名 という関数
が作られるようです。 

  make-xxxx     デフォルトのコンストラクタ
  copy-xxxx     デフォルトのコピー関数
  xxxx-p        指定された構造体であるか否かを調べる関数
  xxxx-変数名   変数へのアクセス関数

定義：
  ;;; struct.lの定義
  (defmacro defstruct (name-and-options &rest rest)
    (eval-when (:compile-toplevel :load-toplevel :execute)
      (defstruct-helper name-and-options rest)))

使用例：
  ;;; FTPサーバを表す構造体の場合
  ;;; 初期値を予め指定することも可能
  (defstruct ftpsvr 
     anonymous hostname (port 80))
  => #<structure-definition: ftpsvr>
  (setq f1 (make-ftpsvr))
  => #S(ftpsvr anonymous nil hostname nil port 80)
  (setq f2 (make-ftpsvr  :anonymous t :hostname "ftp.world.com"))
  => #S(ftpsvr anonymous t hostname "ftp.world.com" port 80)
  (setq f3 #S(ftpsvr anonymous nil hostname "localhost"))
  => #S(ftpsvr anonymous nil hostname "localhost" port 80)

  ;;; 人を表す構造体の場合
  (defstruct person
     (name nil :type string)
     age
     (bloodtype "A"))
  => #<structure-definition: person>
  (setq p1 (make-person :name "Mike" :age 19))
  => #S(person name "Mike" age 19 bloodtype "A")
  (person-name p1)
  => "Mike"
  (setq p2 (copy-person p1))
  => #S(person name "Mike" age 19 bloodtype "A")
  (setf (person-bloodtype p1) "O")
  => "O"
  (person-bloodtype p1)
  => "O"
  (person-bloodtype p2)
  => "A"

  ;;; 患者を表す構造体の場合
  (defstruct (patient
             (:conc-name p-)
             (:print-function
              (lambda (o s p)
                (format s "<patient ~A ~D ~A>" (p-name o) (p-age o) (p-sicks o))))
              (:include person))
     (sicks nil :type (or nil list))
     id)
  => #<structure-definition: patient>
  (setq p3 (make-patient :name "Lucy" :age 18 :sicks '("かぜ")))
  => #S(patient name "Lucy" age 18 bloodtype "A" sicks ("かぜ") id nil)
  (format nil "~A" p3)
  => "<patient Lucy 18 (かぜ)>"
```

## `defvar`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `defvar NAME &optional (INITIAL-VALUE () SV) DOC`

```text
グローバルなスペシャル変数を宣言します。
宣言された変数はダイナミックなスコープを持つようになります。
INITIAL-VALUE が与えられた場合、NAME が変数としての値を持たなければ
INITIAL-VALUE を評価し、その結果を変数値として設定します。
```

関連: `defparameter`, `defvar-local`, `defconstant`

## `defvar-local`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `defvar-local NAME INITIAL-VALUE &optional DOC`

```text
変数NAMEがバッファ毎に異なる値を持つようにします。関連する関数として、
defvar/make-local-variable等がありますが、それぞれ機能が異なります。
defvar-localはdefvarと異なり、スペシャル変数とはならないので注意が必要です。

  defvar              : スペシャル変数を作る。
  defvar-local        : 全バッファで変数が独自の値を持つようにする。
  make-local-variable : 特定のバッファで変数が独自の値を持つようにする。

また、defvar-localだけではその変数はローカル変数にはならないようです。バ
ッファでsetqをして初めてローカルになる（local-variable-pがtになる）よう
です。

使用例：
  ;;; defvarとdefvar-localを使ってダイナミックかレキシカルかを確認する。
  (defvar var 3)
  => var  
  (defvar-local var-local 3)
  => var-local
  
  (defun foo () (let ((var 4) (var-local 4)) (bar)))
  => foo
  (defun bar () (format nil "var : ~S, var-local : ~S" var var-local))
  => bar
  
  (foo)
  => "var : 4, var-local : 3"
(defvar-local *dabbrevs-case-fold* nil)
```

関連: `make-local-variable`, `setq-default`, `local-variable-p`, `buffer-local-value`, `defvar`

## `ed::*register-alist*`

- Variable / package: editor / 定義: register.l

```text
レジスタに格納されている値を保持する変数。
中身は (name . datum) の形の連想リストです。
emacs と違い name にはどんな文字でも入るようです。

datum としては(通常は)以下のものが使用できます。
  マーカー
  文字列
  矩形領域(文字列のリスト)
  window configuration
```

関連: `ed::get-register`, `ed::set-register`

## `enable-post-buffer-modified-hook`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `enable-post-buffer-modified-hook ENABLE &optional BUFFER`

```text
post-buffer-modified-hookを有効・無効にします。
カレントバッファの値のみ変更します。

  ENABLE  : non-nil 有効にします
            nil     無効にします
  BUFFER  : 有効にするバッファを指定します。
            省略時やnilを与えた場合はカレントバッファを指定したとみなします。
```

関連: `post-buffer-modified-hook-enabled-p`, `post-buffer-modified-hook`, `[xyzzy:06354]`

## `fmakunbound`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `fmakunbound SYMBOL`

```text
指定されたシンボルの関数定義からの束縛を解消します。
これ以降fboundpはnilを返すようになります。値と関数定義の束縛は独立してい
るので、fmakunboundをしてもboundpの結果は変わりません。

使用例：
  ;;; 関数定義への束縛を解消してみる。
  (defun foo (x) (* x 3))       => foo
  (fboundp 'foo)                => t
  (fmakunbound 'foo)            => foo
  (fboundp 'foo)                => nil
```

関連: `fboundp`

## `function`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `function FN`

```text
関数の関数定義を返します。#'と同じです。

使用例：
  ;;; #'とfunctionとsymbol-functionを比べてみる。
  (defun foo (x) (* x 3))
  => foo
  #'foo
  => #<lexical-closure: foo>
  (function foo)
  => #<lexical-closure: foo>
  (symbol-function 'foo)
  => #<lexical-closure: foo>
```

関連: `symbol-function`, `quote`

## `lambda-list-keywords`

- Variable / package: lisp / 定義: evalmacs.l

```text
ラムダリストキーワードとして使えるシンボルのリストです。

参照例:
  lambda-list-keywords
  =>(&optional &rest &key &aux &body &whole &environment)
```

関連: `interactive`

## `lambda-parameters-limit`

- Variable / package: lisp

```text
lambdaに与えることのできる引数の個数の限界値

参照例： 
  lambda-parameters-limit
  => 536870911
```

関連: `call-arguments-limit`

## `let`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `let ({VAR|(VAR [VALUE])}*) {declaration}* {FORM}*`

```text
ローカルな変数を定義してフォームを評価します。
```

関連: `let*`

## `let*`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `let* ({VAR|(VAR [VALUE])}*) {declaration}* {FORM}*`

```text
letとよく似ています。letと異なり、VARの初期化に先に定義した他のVARを参照
することが可能です。

使用例：
  ;;; letとlet*の違い
  (setq Y 2)
  => 2
  (let (X (Y 1) (Z Y)) (list X Y Z))
  => (nil 1 2)
  (let* (X (Y 1) (Z Y)) (list X Y Z))
  => (nil 1 1)
```

関連: `let`

## `make-list-from-keyword-table`

- Function / package: editor / 定義: kwd.l
- 呼び出し: `make-list-from-keyword-table HASH`

```text
キーワードハッシュテーブルから補完用のリストを作成します。

  HASH：キーワードハッシュテーブル(*xxxx-keyword-hash-table*)を指定

使用例：
  ;;; CSSのキーワードハッシュテーブルを元に
  ;;; 補完用リストを作成して、do-completionする。
  (defun css-completion ()
    (interactive)
    (or *css-completion-list*
        (setq *css-completion-list* (make-list-from-keyword-table *css-keyword-hash-table*))
        (return-from css-completion nil))
    (let ((opoint (point)))
      (when (skip-syntax-spec-backward "w_")
        (let ((from (point)))
          (goto-char opoint)
          (do-completion from opoint :list-ignore-case *css-completion-list*)))))
```

## `makunbound`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `makunbound SYMBOL`

```text
指定されたシンボルの値からの束縛を解消します。
これ以降boundpはnilを返すようになります。値と関数定義の束縛は独立してい
るので、makunboundをしてもfboundpの結果は変わりません。

使用例：
  ;;; 束縛を解消してみる。
  (set 'foo 2)          => 2
  (boundp 'foo)         => t
  (makunbound 'foo)     => foo
  (boundp 'foo)         => nil
```

関連: `boundp`

## `mode-name`

- BufferLocal / package: editor

```text
モードの名前を格納しているローカル変数です。
？mode-nameとbuffer-modeは必ずローカル変数になるのでしょうか？
```

関連: `buffer-mode`

## `multiple-value-bind`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `multiple-value-bind ({VAR}*) VALUES-FORM {declaration}* {FORM}*`

```text
フォームが返す多値を受け取ります。広井さんの"xyzzy Lisp Programming"の
解説が分かり易いので掲載の許可を頂きました。以下を参照して下さい。

--- 引用開始  ---
複数の値を受け取るには、マクロ multiple-value-bind を使うと簡単です。 

multiple-value-bind (&rest vars) values-form &rest form

multiple-value-bind は、多値を返す関数 values-form を評価し、その結果を 
vars で定義した変数にセットします。変数は局所変数として設定されるので、
multiple-value-bind を実行している間だけ有効です。簡単な例を示しましょう。
Common Lisp には、整数でない値を整数に変換する関数 floor, ceiling, 
truncate, round が定義されています。これらの関数は２つの値（多値）を返します。

  (truncate 10 3)
  => 3

  (multiple-value-bind
  (q r)
  (truncate 10 3)
  (format nil "商 ~D, 余り ~D~%" q r))
  => "商 3, 余り 1"

関数 truncate は割り算を行って商と余りを返します。ふつうに truncate を呼
び出すと商を返すだけですが、multiple-value-bind を使うと、商のほかに余り
も受け取ることができます。q と r は truncate が返す値を受け取る変数です。
次に、truncate を評価して結果を変数にセットします。あとは、残りの form 
を順番に評価していきます。 multiple-value-bind は最後に評価した form の
値を返します。

もしも、返される値よりも変数の個数が多い場合、残りの変数には nil がセッ
トされます。逆に、返される値が変数よりも多い場合、余分な値は捨てられます。
次の例を見てください。

  (multiple-value-bind (q)
  (truncate 10 3)
  (list q))
  => (3)
  
  (multiple-value-bind (q r s)
  (truncate 10 3)
  (list q r s))
  => (3 1 nil)

最初の例では、変数 q しか定義されていないので、 q には商がセットされます
が余りは捨てられます。次の例では、変数 s が定義されていますが、truncate 
は２つの値しか返さないので、 s には nil がセットされます。
--- 引用終了 ---
```

関連: `values`, `multiple-value-list`, `multiple-value-setq`, `http://www.geocities.jp/m_hiroi/`

## `multiple-value-list`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `multiple-value-list FORM`

```text
関数が返した多値をリストで返します。

使用例：
  (defun foo () (values 1 2 3))
  => foo
  (foo)
  => 1
     2
     3
  (multiple-value-list (foo))
  => (1 2 3)
```

関連: `values`, `multiple-value-call`, `multiple-value-bind`, `multiple-value-setq`

## `multiple-value-setq`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `multiple-value-setq VARIABLES FORM`

```text
返された多値を個々の変数に設定します。
変数の個数よりもフォームが返した値の数が多いときには余った分は捨てられま
す。少ない場合には、足りない分だけnilが設定されます。

  VARIABLES : 変数のリスト
  FORM      : 評価するフォーム

使用例：
  ;;; valuesで多値を返した場合
  (setq a (values 1 2)) => 1
  a                     => 1
  (multiple-value-setq (a b) (values 1 2))
                        => 1
  a                     => 1
  b                     => 2
```

関連: `multiple-value-bind`, `multiple-value-list`

## `need-not-save`

- BufferLocal / package: editor

```text
保存する必要があるかどうかを設定します。
個々のバッファ毎や特定のモードだけしたくないのであれば、使用例の様にロー
カル変数にします。例えば、*scratch*の様に書き捨てたりするバッファでは、
保存の必要はないので、tになっています。

  t     保存の必要はない
  nil   保存する

使用例：
  ;;; 現在のバッファは保存の必要はなし。
  (make-local-variable 'need-not-save)
  => t
  (setq need-not-save t)
  => t
```

関連: `need-buffer-save-p`, `setup-temp-buffer`

## `nil`

- Variable / package: lisp

```text
偽を表す定数です。
```

関連: `t`

## `nth-value`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `nth-value N FORM`

```text
フォームが返す多値の N 番目を返します。

  N    : リストのインデックスを指定します。0を基底とします。
  FORM : 要素を返すフォームです。

N が多値の数より多い場合は nil を返します。 N が負数であればエラーを
返します。

使用例：
  (nth-value 1 (values 1 2 3 4))
  => 2
  (nth-value 10 (values 1 2 3 4))
  => nil
  (nth-value -3 (values 1 2 3 4))
  => 範囲外の値です: -3

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `nth`, `nthcdr`

## `post-buffer-modified-hook`

- Variable / package: editor

```text
バッファが修正されたときに実行されます。

設定された関数は以下の5引数で呼び出されます。
  BUFFER    : 修正されたバッファ
  OPERATION : 修正された操作の種類
               :insert  文字の挿入
               :delete  文字の削除
               :modify  修正(downcase-wordなど)
  FROM      : 開始位置のポイント
  TO        : 終了位置のポイント
              OPERATIONが:deleteの場合はFROMとTOは同じ値になります。
  UNDO-P    : 修正された状況
               undo     undo
               redo     redo
               nil      その他

注意：
  enable-post-buffer-modified-hookでフックを有効にしないと実行されません。
  対話的でなくても実行されます。
  同じバッファに修正を行うとread-only-bufferエラーになります。
  なんらかのエラーが発生するとフックが無効になります。
  ウィンドウ・バッファを削除したり、
  戻るときにウィンドウ・バッファが切り替わってたりすると、
  きっと良くないことが起こるので、あまり無茶なことはしない方が無難です。

使用例：
  (enable-post-buffer-modified-hook t)
  (defun buffer-modified-hook (buffer operation from to undo-p)
    (message "ope:~A  undo:~A from:~d to:~d" operation undo-p from to))
  (add-hook 'post-buffer-modified-hook 'buffer-modified-hook)
```

関連: `enable-post-buffer-modified-hook`, `post-buffer-modified-hook-enabled-p`

## `post-buffer-modified-hook-enabled-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `post-buffer-modified-hook-enabled-p &optional BUFFER`

```text
バッファでpost-buffer-modified-hookが有効かを判定します。
[xyzzy:06354]を参照
xyzzy 0.2.1.186～
```

関連: `enable-post-buffer-modified-hook`, `post-buffer-modified-hook`

## `proclaim`

- Function / package: lisp / 定義: typespec.l
- 呼び出し: `proclaim DECL-SPEC`

```text
変数をスペシャル変数にします。
declare との違いは、関数であるため引数が評価されることと、効果が大域的で
ある点です。

以下の形で使用します。

  (proclaim '(special var1 var2...))

xyzzy では special 以外の指定をしても効果はありません。
```

関連: `declaim`, `declare`

## `psetq`

- Macro / package: lisp / 定義: evalmacs.l
- 呼び出し: `psetq {VAR FORM}*`

```text
変数に値を設定します。

  (psetq 変数1 値1 変数2 値2 ... 変数N 値N)

上記の様に変数と値の組を任意の数だけ並べることができます。 

setqと似ていますがsetqが頭から順に変数に値を設定していくのに対し、psetq
は値を全て評価した上で設定します。

使用例：
  ; psetq の場合
  (let ((from 1)
        (to 100))
    (psetq from to to from)
    (values from to))
  =>100
  =>1

  ; setq の場合
  (let ((from 1)
        (to 100))
    (setq from to to from)
    (values from to))
  =>100
  =>100
```

関連: `setq`, `psetf`

## `quote`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `quote OBJECT`

```text
OBJECTを評価せずに返します。
single quoteで代用されます。

使用例：
  ;;; quoteと'を使ってみる。
  (quote x)             => x
  'x                    => x
  (eq (quote x) 'x)     => t
```

関連: ```'(backquote)`, `function`

## `register-history-variable`

- Function / package: editor / 定義: history.l
- 呼び出し: `register-history-variable VAR`

```text
すでに定義された変数 VAR をヒストリ変数に登録します。
ファイルに書き込まれるため、変数の内容は readable である必要があります。
readable であるとは、具体的に言うと「文字、文字列、数値、シンボルと
それらのリストで構成されるデータ」のことです。

  VAR : ヒストリ変数に登録する変数のシンボル、もしくはそれらのリスト
```

関連: `define-history-variable`, `unregister-history-variable`

## `rotatef`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `rotatef {PLACE}*`

```text
引数として与えられた値の格納場所の内容をローテーションさせます。

        ┌a ┐  ┌b ┐  ┌c ┐
実行前：│ 1│  │ 2│  │ 3│
        └┬┘  └┬┘  └┬┘
      ┌─┘  ┌─┘  ┌─┘
   (*)┘  ┌─┘  ┌─┘  ┌─(*)
          ↓      ↓      ↓
        ┌a ┐  ┌b ┐  ┌c ┐
実行後：│ 2│  │ 3│  │ 1│
        └─┘  └─┘  └─┘
使用例：
  ;;; a b cに数値を入れてrotatefする。
  (setq a 1 b 2 c 3)    => 3
  (list a b c)          => (1 2 3)
  (rotatef a b c)       => 1
  (list a b c)          => (2 3 1)
```

関連: `setf`, `shiftf`

## `set`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set SYMBOL VALUE`

```text
シンボルの値を設定します。
setq と違って局所変数には影響を与えません。

  SYMBOL : シンボル名
  VALUE  : 設定する値

使用例：
  ;;; foo というシンボルを束縛してみる
  (boundp 'foo)         => nil
  (set 'foo 2)          => 2
  (boundp 'foo)         => t
  foo                   => 2
  ;;; 局所変数には影響しない
  (let ((foo 1))
    (set 'foo 2) foo)   => 1
```

関連: `setq`, `symbol-value`, `makunbound`

## `set-default`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-default SYMBOL VALUE`

```text
この関数は、ただ 1つの symbol と 1 つの value のみを許す点と、その両方を
評価する点とを除き setq-default と同じです (setq-default 参照)。

使用例：
  (set-default (car '(a b c)) 23)
  => 23
```

関連: `setq-default`, `set`

## `set-variable`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `set-variable VAR`

```text
変数 VAR をプロンプトから入力した値に設定します。[C-x a]
VAR の値が文字列なら文字列として、それ以外なら S 式として入力を読み取ります。

VAR が boundp でないとエラーになります。
```

## `setf`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `setf {PLACE NEW-VALUE}*`

```text
このマクロは、変数にアクセスし、その値を変更するために使われます。従来用
いられてきたsetqよりも汎用的であり、setqと全く置き換えて使用することがで
きます。PLACEは、アクセスしようとするデータオブジェクトのある場所を指し、
NEW-VALUEを評価した値がその場所に書き込まれます。

setfは、いくつでもPLACEやNEW-VALUEの対でも受け付けます。そして、同時にで
はなく、順番に値を割り当てます。つまり、最初の引数の対は、二番目の対が評
価される前に評価され、PLACEによって示される場所に値が書き込まれています。
このように、二番目の引数の対は、最初の対の評価によって割り当てられた値を
使うことが可能です。setfは、最後に評価された引数の対によって割り当てられ
た値、あるいは、まったく引数が与えられなかった場合は、nilを返します。

PLACEの形式は以下のどのようなものも可能です：

(1)変数名(レキシカル変数でもスペシャル変数でもよい)

  (setf hoge 1); 変数hogeに1を代入する
  => 1
  hoge
  => 1

(2)アクセス関数
 * 構造体(構造体名＋変数)

  (defstruct foo a b c); 構造体fooを宣言する
  => #<structure-definition: foo>
  (setf hoge (make-foo)); hogeに空のfoo構造体を代入する(ここのsetfはsetqでもよい)
  => #S(foo a nil b nil c nil)
  (setf (foo-a hoge) 10); hogeのスロットaに10を代入する
  => 10
  hoge
  => #S(foo a 10 b nil c nil)

 * 配列(aref, svref, fill-pointer)

  (setf hoge (make-array 3)); hogeに空のベクタを代入する(ここのsetfはsetqでもよい)
  => #(nil nil nil)
  (setf (aref hoge 1) 5); hogeベクタの2番目の数値を5にする
  => 5
  hoge
  => #(nil 5 nil)

 * リスト(car, cdr, first, rest, etc...)

  (setf hoge '("a" "b" "c"))
  => ("a" "b" "c")
  (setf (car (cdr hoge)) "d")
  => "d"
  hoge
  =>("a" "d" "c")

 * 属性リスト(get, getf, symbol-plist)

  (setf (get 'Japan 'language) "Japanese")
  => "Japanese"
  (setf (get 'Japan 'population) 120000000)
  => 120000000
  (symbol-plist 'Japan)
  => (population 120000000 language "Japanese")

 * その他(symbol-value, gethash, symbol-function, documentation, macro-function)
```

関連: `setq`

## `setq`

- Special Form / package: lisp / 定義: builtin.l
- 呼び出し: `setq {VAR FORM}*`

```text
変数に値を設定します。

  (setq 変数1 値1 変数2 値2 ... 変数N 値N)

上記の様に変数と値の組を任意の数だけ並べることができます。

  (setq foo '(1 2 3)) = (set 'foo '(1 2 3))

使用例：
  ;;; setとsetqで同じことをしてみる。
  (set 'foo '(2 3 4))   => (2 3 4)
  foo                   => (2 3 4)
  (setq foo '(1 2 3))   => (1 2 3)
  foo                   => (1 2 3)
```

関連: `setf`, `psetq`

## `setq-default`

- Macro / package: editor / 定義: misc.l
- 呼び出し: `setq-default VAR VAL`

```text
シンボルがローカルでない場合のデフォルトの値を設定します。

この関数は、各 symbol のデフォルト値を、(それに対応する) value に設定し
ます。(symbol は評価しませんが) value は評価します。最初の value を返し
ます。 

デフォルト値は、固有のバッファローカル値を持たないバッファで見られます。 

カレントバッファで symbol がバッファローカルでない場合、これは (この)カ
レントバッファで setq を行なうのと同じことになります。 symbol がカレント
バッファでバッファローカルである場合、カレントバッファで見える値ではなく、
他のバッファがまだバッファローカルな値を持たない場合にそこで見える値を設
定します。

使用例：
  (make-variable-buffer-local 'local)
  => local
  ;; バッファ foo 中:
  (setq local 'foo)
  => foo
  ;; バッファ bar 中:
  local
  => nil
  (setq-default local 'default)
  => default
  local
  => default
  (setq local 'bar)
  => bar
  ;; バッファ baz 中:
  local
  => default
  ;; バッファ foo 中:
  (setq local 'foo)
  => foo
  (default-value 'local)
  => default
```

関連: `default-value`, `set-default`, `make-local-variable`, `defvar-local`

## `shiftf`

- Macro / package: lisp / 定義: setf.l
- 呼び出し: `shiftf {PLACE}+ NEWVALUE`

```text
引数として与えられた値の格納場所の内容をシフトさせます。
(shiftf a b c)とすると以下のようになります。

        ┌a ┐  ┌b ┐  ┌c ┐
実行前：│ 1│  │ 2│  │ 3│
        └─┘  └┬┘  └┬┘
              ┌─┘  ┌─┘
          ┌─┘  ┌─┘  
          ↓      ↓      
        ┌a ┐  ┌b ┐  ┌c ┐
実行後：│ 2│  │ 3│  │ 3│
        └─┘  └─┘  └─┘
```

関連: `rotatef`

## `si:*paste-hook*`

- Variable / package: system

```text
クリップボードから貼り付けるときに実行されます。
```

関連: `paste-from-clipboard`

## `special`

- Misc / package: lisp

```text
declare をごらんください。
```

関連: `declare`

## `special-form-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `special-form-p SYMBOL`

```text
シンボルが特殊形式かどうかを返します。

  SYMBOL : 判定するシンボル

戻り値
  nil      シンボルは特殊形式ではない。
  non-nil  シンボルは特殊形式

  ; 特殊形式を書き出してみる
  (do-all-symbols (i "end")
    (and (special-form-p i)
         (format t "~A~%" i)))
  interactive
  save-restriction
  save-excursion
  save-window-excursion
  *byte-code
  macrolet
  setq
  throw
  return-from
  progn
  let*
  go
  labels
  if
  multiple-value-call
  unwind-protect
  multiple-value-setq
  catch
  tagbody
  eval-when
  let
  multiple-value-bind
  block
  function
  quote
  multiple-value-prog1
  flet
  =>"end"
```

## `symbol-function`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `symbol-function SYMBOL`

```text
シンボルが束縛された関数定義を返します。
fletなどで定義したローカルの関数定義は参照できません。

  SYMBOL : 関数定義を取得するシンボル名

使用例：
  ;;; 関数定義の取得
  (symbol-function 'foo)
  => 関数が定義されていません: foo
  (defun foo (x) (* x 2))
  => foo
  (symbol-function 'foo)
  => #<lexical-closure: foo>
```

関連: `symbol-value`, `function`

## `t`

- Variable / package: lisp

```text
真を表す定数です。
```

関連: `nil`

## `title-bar-format`

- Variable / package: editor

```text
タイトルバーのフォーマットを設定します。

使用例：
  (setq title-bar-format "--%*- %b (%M) [%k:%l] %P %f")

パラメタ：
  %*    変更あり          : **
        書込禁止          : %-
        変更あり・書込禁止: %*
        それ以外          : --
  %#*   変更あり: *
        変更なし: (空白) 
  %r    書込可  : (空白)
        書込禁止: % 
  %#r   書込可        : (空白)
        書込禁止      : %
        不完全バッファ: # 
  %p    プログラム名 
  %v    バージョン 
  %$    プロセスID
  %h    ホスト名 
  %#h   @ホスト名 
  %b    バッファ名 
  %f    File: ファイル名 
  %#f   ファイル名 
  %F    File: ファイル名。ファイル名がなければバッファ名 
  %#F   ファイル名。ファイル名がなければバッファ名 
  %M    モード(マイナーモード含む) 
  %m    モード 
  %k    エンコーディング 
  %l    改行コード 
  %!    xyzzyが管理者として実行されている場合は "管理者: "

備考：
  モードラインのフォーマットとほぼ同様ですが、
  %i, %P, %/ はタイトルバーでは設定できません。

備考：
  %$ は xyzzy 0.2.2.236 から利用可能です。
  %! は xyzzy 0.2.2.247 から利用可能です。
```

関連: `mode-line-format`

## `unregister-history-variable`

- Function / package: editor / 定義: history.l
- 呼び出し: `unregister-history-variable VAR`

```text
変数をヒストリ変数の登録から削除します。
```

関連: `define-history-variable`, `register-history-variable`

## `values`

- Function / package: lisp / 定義: evalmacs.l
- 呼び出し: `values &rest ARGS`

```text
多値で値を返します。

C言語では関数は1つの値しか返すことができませんが、Common Lispでは複数の
値を返す事ができます（リストとは違います）。これを多値（関数）と呼びます。
複数の値を返したい時は、 (values 値1 値2 ..)という構文を使います。

多値関数を呼び出す場合には、複数の戻り値を受け取れるように 
multiple-value-bind または multiple-value-listを使って受け取ります。

互換性：
  Common Lispとxyzzyにはあり。
  muleにはなさそう。
```

関連: `values-list`, `multiple-value-bind`, `multiple-value-list`, `multiple-value-setq`

## `values-list`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `values-list LIST`

```text
指定されたリストを多値として返します。

  (values-list '(a b c)) == (values a b c)
  (values-list list) == (apply #'values list)
```

関連: `values`

## `wild-pathname-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `wild-pathname-p PATHNAME`

```text
ワイルドカード指定されたパスかどうかを返します。

  t     ワイルドカード指定されたパスです。
  nil   ワイルドカード指定されていません。

使用例：
  ;;; ワイルドカードかどうかを調べてみる。
  (wild-pathname-p "site-lisp/*.l")
  => t
```

関連: `*brackets-is-wildcard-character*`, `pathname-match-p`
