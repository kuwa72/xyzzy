# ファイルシステム (filesystem)

reference/reference.xml から自動生成。88 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*auto-encoding-alist*`

- Variable / package: editor / 定義: files.l

```text
エンコーディング判定用の連想リストです。(key . datum) の組で登録します。
find-file または find-file-read-only の際に ENCODING が指定されず、
*find-file-no-auto-encoding* が nil の時、
(string-matchp key filename) が non-nil となった場合、datum をfuncallします。
datum にはエンコーディングもしくはエンコーディングを表す文字列を返す関数を指定します。
```

関連: `*find-file-no-auto-encoding*`, `*find-file-auto-encoding-use-utf8n`, `find-file`

## `*auto-update-per-device-directory*`

- Variable / package: lisp

```text
ファイラで移動したときにドライブ毎のデフォルトのディレクトリについて制御します。

  t   移動するたびに更新する
  nil set-perdevice-directoryで指定したディレクトリに固定する
```

関連: `set-per-device-directory`

## `*default-write-file-directory*`

- Variable / package: editor / 定義: files.l

```text
write-file および emacs-write-file 時のデフォルトのディレクトリを指定します。
```

関連: `emacs-write-file`, `write-file`

## `*find-file-hooks*`

- Variable / package: editor / 定義: files.l

```text
find-file および find-file-read-only で新しいファイルを開くたびに、最後に実行されます。
すでにファイルを開いているバッファが存在した場合には実行されません。
```

関連: `*find-file-read-only-hook*`, `find-file-read-only`, `find-file`

## `*find-file-no-auto-encoding*`

- Variable / package: editor / 定義: files.l

```text
non-nil なら、*auto-encoding-alist* によるエンコーディングの判定が行われず、
ファイルの先頭にエンコーディング情報(-*- Encoding: EUC-JP -*-など)が記述され
ていても無視されます。
```

関連: `*auto-encoding-alist*`, `*find-file-auto-encoding-use-utf8n`, `find-file`

## `*find-file-read-only-hook*`

- Variable / package: editor / 定義: files.l

```text
find-file-read-only でファイルごとに最後に実行されます。
*find-file-hooks* と異なり、すでにファイルが開かれていた場合にも実行されます。
```

関連: `*find-file-hooks*`, `find-file-read-only`

## `*find-other-file-requires-file-name*`

- Variable / package: editor / 定義: files.l

```text
non-nil なら find-other-file のプロンプト時に現在のバッファ名を表示します。
```

関連: `find-other-file`

## `*load-pathname*`

- Variable / package: lisp

```text
現在読み込み中のファイル名（もしくはストリーム名）が入ります。

load-file内でバインドされます。
```

## `append-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `append-file FILENAME &optional NOMSG CHAR-ENCODING EOL-CODE`

```text
バッファの内容を FILENAME に追加書き込みします。
write-file で APPEND を non-nil にした場合と同じです。

  NOMSG         : non-nil ならステータスバーに経過メッセージを表示しません。
  CHAR-ENCODING : エンコーディングを指定します。
  EOL-CODE      : 改行コードを指定します。
```

関連: `write-file`

## `append-trail-slash`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `append-trail-slash STRING`

```text
文字列の末尾に"/"がなければ"/"を追加します。

使用例：
  (append-trail-slash "ffjfj")
  => "ffjfj/"
  (append-trail-slash "ffjfj/")
  => "ffjfj/"
```

関連: `remove-trail-slash`

## `archiver-dll-config-dialog`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `archiver-dll-config-dialog DLL &optional MODE`

```text
アーカイバの設定ダイアログを表示します。

  DLL  : 設定するアーカイバを指定します。
  MODE : （詳細不明）

使用例：
  (archiver-dll-config-dialog :unlha32)
```

## `archiver-dll-version`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `archiver-dll-version DLL`

```text
アーカイバのバージョンを取得します。

  DLL  : アーカイバを指定します。

使用例：
  (archiver-dll-version :unrar32)
  => "0.09"
```

## `cd`

- Function / package: editor / 定義: misc.l
- 呼び出し: `cd DIRECTORY`

```text
バッファが作業しているディレクトリをインタラクティブに変更します。
```

関連: `set-default-directory`

## `chdir`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `chdir &optional DIRNAME`

```text
xyzzy.exeの作業ディレクトリを移動します。
移動した場合は t を、移動しなかった場合は nil を返します。

  DIRNAME : 移動先のディレクトリを絶対パスまたは相対パスで指定します。
            省略時は user-homedir-pathname に移動します。

使用例： 
  (chdir (get-windows-directory))
  => t
  (chdir (get-windows-directory))
  => nil
  (chdir "system32")
  => t
  (chdir "..")
  => t
  (chdir "c:/dir/not/found")
  => c:/dir/not/found
  => 指定されたパスが見つかりません。 

補足：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `cwd`

## `check-valid-pathname`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `check-valid-pathname PATHNAME`

```text
PATHNAMEが存在すればt、そうでなければnilを返します。

使用例：
  ;;; 存在するC:/xyzzy/と存在しないC:/xyzzzy/を比べてみる。
  (check-valid-pathname "C:/xyzzy/")
  => t
  (check-valid-pathname "C:/xyzzzy/")
  => nil
```

関連: `file-exist-p`, `valid-path-p`

## `compile-file-pathname`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `compile-file-pathname PATHNAME`

```text
xyzzy でバイトコンパイルした時の出力ファイル名を返します。
```

## `copy-file`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `copy-file FILE NEW-FILE &key :if-exists :copy-attributes :if-access-denied`

```text
ファイルをコピーします。

  FILE             : コピー元のファイル名を指定します。
  NEW-FILE         : コピー先のファイル名を指定します。
  :copy-attributes : コピーするときの属性を指定します。
                     指定できる属性はget-file-infoを参照して下さい。
  :if-exists       : ファイルが存在しない場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :overwrite      上書きします。
        :newer          新しければ上書きします。
  :if-access-denied : アクセスが拒否された場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :force          強制的にファイルのコピーを試みます。

使用例：
  ;;; ローカルのautoexec.batを マシン名 VENUSの /work/autoexec.batにコピーする。
  (copy-file "c:/autoexec.bat" "//VENUS/work/autoexec.bat"
             :if-exists :overwrite)
```

関連: `rename-file`

## `create-archive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `create-archive ARCHIVE-FILE FILES BASE-DIRECTORY`

```text
アーカイブを作成します。

  ARCHIVE-FILE   : 作成/追加する書庫ファイル名を指定します。指定したファ
                   イルが存在すれば追加、なければ新規作成します。書庫フ
                   ァイルを作成するディレクトリを指定する場合は、フルパ
                   スで指定します。
  FILES          : アーカイブするファイルのリストを指定します。フルパス
                   で指定する必要があります。
  BASE-DIRECTORY : 基準となるディレクトリを指定します。

使用例：
  ;;; foo.lzh に c:/tmp/a.c, c:/tmp/b.c を追加します。
  (create-archive "foo.lzh"
                  '("c:/tmp/a.c" "c:/tmp/b.c")
                  "c:/tmp")
```

関連: `extract-archive`, `delete-file-in-archive`

## `create-directory`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `create-directory DIRNAME &key :if-exists`

```text
ディレクトリを作成します。

  DIRNAME    : 作成対象のディレクトリ
  :if-exists : ディレクトリが存在していたときの動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、t を返します。

戻り値は作成できたかどうかによります。

  t   ディレクトリの作成に成功
  nil ディレクトリの作成に失敗

使用例：
  (create-directory "C:/xyzzy/testdir")
  => t
```

関連: `delete-directory`

## `create-shortcut`

- Function / package: editor / 定義: files.l
- 呼び出し: `create-shortcut SRC DEST &rest REST`

```text
ショートカットを作成します。

  SRC  : ショートカットが指すパスを指定します。
  DEST : ショートカットを作成するパスを指定します。
  REST : 作成するショートカットへのパラメータを与えることが出来ます。
     :description        ドラッグオーバの時やプロパティ表示時に見られる説明
     :arguments          コマンドライン引数
     :working-directory  作業ディレクトリ
     :show               ウィンドウの状態の指定
                            :show      標準のサイズで起動
                            :maximize  最大化状態で起動
                            :minimize  最小化状態で起動
     :appid              アプリケーションID
                         ショートカットのアプリケーションIDを指定します。
                         Windows 7以降ではアプリケーションIDを元に
                         タスクバー上でアイコンがグループ化されます。
                         Vista 以前ではこの引数は単純に無視されます。

使用例：
  ;;; スタートメニューにショートカットを作成する。
  (create-shortcut (merge-pathnames "xyzzy.exe" (si:system-root)) (get-special-folder-location :start-menu))
  => t
  (delete-file (merge-pathnames "xyzzy.exe.lnk" (get-special-folder-location :start-menu)))
  => t

  ;;; 送るメニューにxyzzyを登録する。
  (create-shortcut (merge-pathnames "xyzzy.exe" (si:system-root)) (get-special-folder-location :send-to))
  => t
  (delete-file (merge-pathnames "xyzzy.exe.lnk" (get-special-folder-location :send-to)))
  => t

  ;;; xyzzyと同じアプリケーションIDを指定してデスクトップにxyzzycliを登録する。
  ;;; このショートカットをタスクバーに登録することで、ジャンプリストが利用
  ;;; できるようになる。
  (create-shortcut (merge-pathnames "xyzzycli.exe" (si:system-root))
                   (get-special-folder-location :desktop)
                   :appid (si:*app-user-model-id))
  => t
  (delete-file (merge-pathnames "xyzzycli.exe.lnk" (get-special-folder-location :desktop)))
  => t

補足：
  :appid引数は xyzzy 0.2.2.236 から利用可能です。
```

関連: `resolve-shortcut`, `si:*app-user-model-id`

## `create-shortcut-to-desktop`

- Function / package: editor / 定義: files.l
- 呼び出し: `create-shortcut-to-desktop PATH &rest REST`

```text
デスクトップに PATH へのショートカットを作ります。
```

関連: `create-shortcut`

## `cwd`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `cwd`

```text
xyzzy.exeの作業ディレクトリを返します。プロパティの作業フォルダ(S)の
ディレクトリが返されるのだと思います。

使用例： 
  (cwd)
  =>"D:/WINNT/"
```

関連: `chdir`

## `default-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `default-directory &optional BUFFER`

```text
バッファが作業しているディレクトリを返します。

  BUFFER : バッファを指定します。
           指定がなければカレントバッファになります。

そのバッファでfind-file するときに最初に表示されるディレクトリのことです。
このディレクトリは M-x: cd や set-default-directoryで変更することができ
ます。

使用例：
  ;;; デフォルトディレクトリを移動してみる。
  (default-directory)
  => "C:/applications/xyzzy/site-lisp/"
  (cd "../..")
  => t
  (default-directory)
  => "C:/applications/"
```

関連: `set-default-directory`

## `delete-directory`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete-directory DIRNAME &key :if-does-not-exist :if-access-denied`

```text
ディレクトリを削除します。

  DIRNAME            : 削除するディレクトリ名を指定します。
  :if-does-not-exist : ディレクトリが存在しない場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
  :if-access-denied  : アクセスが拒否された場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :force          強制的に削除を試みます。

削除できたかどうかで戻り値が変わります。

  t   削除に成功
  nil 削除に失敗

使用例：
  (delete-directory "C:/xyzzy/testdir")
  => t
```

関連: `delete-file`, `create-directory`

## `delete-file`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `delete-file FILE &key :if-does-not-exist :if-access-denied :recycle`

```text
ファイルを削除します。

  FILE               : 削除するファイル名を指定します。
  :if-does-not-exist : ファイルが存在しない場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
  :if-access-denied  : アクセスが拒否された場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :force          強制的に削除を試みます。

削除できたかどうかで戻り値が変わります。

  t   削除に成功
  nil 削除に失敗

使用例：  
  (delete-file "C:/xyzzy/test.txt")
  => t
```

関連: `delete-directory`, `rename-file`, `copy-file`

## `delete-file-in-archive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-file-in-archive ARCHIVE-FILE &rest FILES`

```text
アーカイブから指定したファイルを削除します。

  ARCHIVE-FILE : アーカイブを指定します。
  FILES        : 削除するファイルを指定します。

使用例：
  ;;; c:/tmp/foo.lzh から xyz.c を削除します。
  (delete-file-in-archive "c:/tmp/foo.lzh" "xyz.c")
```

関連: `create-archive`, `extract-archive`

## `directory`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `directory PATHNAME &key :absolute :recursive :wild :depth :file-only :show-dots :count :directory-only :callback :file-info :test`

```text
対象ディレクトリ下のファイル名をリストで得ます。

  PATHNAME        : 検索するディレクトリのパスです。
  :absolute       : 検索結果をフルパスで取得します。
  :recursive      : サブディレクトリも対象とするかを制御します。
        t               サブディレクトリの中まで検索
        nil             サブディレクトリの中までは検索しない
  :wild           : ワイルドカード指定です。リストでも可です。
  :depth          : :recursive 指定するときの再帰の深さです。
  :file-only      : ファイルしか検索しません。
  :show-dots      : ディレクトリとして"./"と"../"を加えます。
  :count          : 表示されるファイルの個数を制限します。
  :directory-only : ディレクトリしか検索しません。
  :callback       : 見つかったファイルを引数にしてfuncallします。
                    :file-infoにnon-nilを指定した場合はファイルの属性も
                    引数に指定します。
                    :callbackを指定した場合、directory関数の戻り値は
                    nilです。
  :file-info      : ファイルの属性を取得します。
                    get-file-info で取得できるものと同じです。
  :test           : 見つかったファイルを引数にしてfuncallします。
                    funcallした結果がnilのファイルは無視します。
                    ディレクトリの場合はディレクトリ配下のファイルを
                    すべて無視します。
                    :file-infoにnon-nilを指定した場合はファイルの属性も
                    引数に指定します。

使用例：
  ;;;  "../"は出したいけど、"./"を出したくない場合
  (delete "./" (directory ... :show-dots t) :test #'string=)

  ;;; "C:/"の配下を一覧表示する。
  (directory "C:/" :callback #'(lambda (x) (print x)))

  ;;; ファイル名のソート（大文字小文字区別有り）
  (sort (directory ...) #'string<)

  ;;; ファイル名のソート（大文字小文字区別有り）
  (sort (directory ...) #'string-lessp)

  ;;; .git ディレクトリを無視したい場合
  (directory "." :test #'(lambda (path)
                           (not (and (file-directory-p path)
                                     (string-equal ".git" (pathname-name path)))))
             :absolute t :recursive t)

  ;;; 隠しディレクトリを無視したい場合
  (directory "." :test #'(lambda (path/file-info)
                           (let ((path (car path/file-info))
                                 (attr (cadr path/file-info)))
                             (not (and (file-directory-p path)
                                       (not (zerop (logand attr ed::*file-attribute-hidden*)))))))
             :file-info t :recursive t)

備考：
  :test 引数は xyzzy 0.2.2.242 から利用可能です。
```

## `directory-namestring`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `directory-namestring PATHNAME`

```text
PATHNAMEのディレクトリ部分を返します。

使用例：  
  (directory-namestring "C:/xyzzy/xyzzy.exe")
  => "C:/xyzzy/"
  (directory-namestring "~/test.txt")
  => "C:/HOME/"
  (directory-namestring "/usr/local/bin")
  => "C:/usr/local/"
```

関連: `pathname-directory`, `file-namestring`, `remove-trail-slash`

## `ed::find-file-internal`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-file-internal FILENAME &optional NOWARN (KANJI-CODE nil SVAR) NEWLINE-CODE NOMSG`

```text
ファイルを開きます。find-fileはfind-file-internalを用いて実装されています。
find-fileは複数のファイルを開く機能がありますが、一つのファイルを開くの
であれば、こちらの方が高速です。

  FILENAME : ファイル名
```

関連: `find-file`, `*find-file-hooks*`, `*before-find-file-hook*`, `*find-file-file-not-found-hook*`, `*find-file-auto-mode-function*`, `buffer-read-only`

## `eject-media`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `eject-media DRIVE`

```text
DRIVEに指定したドライブをイジェクトします。
DRIVEはキャラクタで指定します。
使用例：
  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"
  
  (eject-media (svref a 0)) ; イジェクト不可能なドライブ
  =>指定されたデバイス名は無効です。 

  (eject-media #\P)
  =>t
(svref (default-directory) 0))
```

## `emacs-write-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `emacs-write-file FILENAME`

```text
バッファの内容を FILENAME に書き込みます。
同時にバッファ名およびバッファに関連付けられたファイルも変更します。
```

関連: `save-buffer`, `write-file`

## `extract-archive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `extract-archive ARCHIVE-FILE TO-DIRECTORY &rest FILES`

```text
アーカイブを展開します。

ARCHIVE-FILE : 展開するアーカイブを指定します。
TO-DIRECTORY : 展開するディレクトリを指定します。
FILES        : 展開するファイルを指定します。指定しない場合は、全てのフ
               ァイルが展開されます。

使用例：
  ;;; d:/foo.lzh を c:/tmp に展開します。
  (extract-archive "d:/foo.lzh" "c:/tmp")
```

関連: `create-archive`, `delete-file-in-archive`

## `file-directory-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-directory-p PATHNAME`

```text
PATHNAMEがディレクトリならt、そうでなければnilを返します。

使用例：  
  (file-directory-p "C:/xyzzy/")
  => t
  (file-directory-p "C:/xyzzy/xyzzy.exe")
  => nil
  (file-directory-p "~/")
  => t
```

関連: `file-exist-p`

## `file-executable-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-executable-p PATHNAME`

```text
注）何故か実行ファイルでも、tが返らない気がする。
PATHNAMEが実行ファイルか否かを返します。

  t    実行ファイルである。
  nil  実行ファイルではない。
```

関連: `file-exist-p`

## `file-exist-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-exist-p PATHNAME`

```text
PATHNAMEが存在すればt、そうでなければnilを返します。

使用例：  
  (file-exist-p "C:/xyzzy/xyzzy.exe")
  => t
  (file-exist-p "~/")
  => t
```

関連: `check-valid-pathname`, `file-readable-p`, `file-writable-p`, `file-executable-p`, `file-directory-p`, `file-write-time`

## `file-length`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-length PATHNAME`

```text
指定されたファイルの大きさをバイト単位で返します。

  PATHNAME : ファイル名を指定します。

使用例：
  (file-length "C:/xyzzy/xyzzy.exe")
  => 977408
```

## `file-namestring`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-namestring PATHNAME`

```text
PATHNAMEのファイル名の部分を返します。
  
使用例：
  (file-namestring "C:/xyzzy/xyzzy.exe")
  => "xyzzy.exe"
  (file-namestring "C:/Windows/")
  => ""

須田さんの場合：
  ;;; 須田さんは、こんなのを定義しているらしい。
  (defun file-name-directory (filename)
    (directory-namestring filename))

  (defun file-name-nondirectory (filename)
    (file-namestring filename))

  (defun file-name-sans-versions (name)
    "Return FILENAME sans backup versions or strings.
  This is a separate procedure so your site-init or startup file can
  redefine it."
    (substring name 0
             (or (string-match "\\.~[0-9]+~\\'" name)
                 (string-match "~\\'" name)
                 (length name))))
```

関連: `pathname-name`, `directory-namestring`

## `file-newer-than-file-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `file-newer-than-file-p FILE1 FILE2`

```text
ファイルの最終更新日を比較します。
戻り値は以下のとおりです。

  t   file1の方が新しい、もしくはfile2が無効。
  nil file2の方が新しい、file1が無効、時間差が無い、のいずれか。
```

関連: `file-write-time`

## `file-property`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `file-property PATHNAME`

```text
PATHNAMEのファイルのプロパティを表示します。
使用例：
  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (file-property a)
  =>t
```

## `file-readable-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-readable-p PATHNAME`

```text
PATHNAMEが読み取り可能ならt、そうでなければnilを返します。

使用例：
  (file-readable-p "C:/xyzzy/xyzzy.exe")
  => t
  (file-readable-p "~/")
  => nil
```

関連: `file-writable-p`, `file-exist-p`

## `file-writable-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-writable-p PATHNAME`

```text
PATHNAMEが書き込み可能ファイルならt、そうでなければnilを返します。

使用例：  
  (file-writable-p "C:/xyzzy/xyzzy.exe")
  => t
  (file-writable-p "~/")
  => nil
```

関連: `file-readable-p`, `file-exist-p`

## `file-write-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `file-write-time FILENAME`

```text
ファイルの最終更新日をユニバーサルタイム形式で返します。

  FILENAME : ファイル名を指定します。
             フルパスでなければ(default-directory)からの相対パスになります。

使用例：
  ;;; .xyzzyの最終更新日を返します。
  (file-write-time ".xyzzy")
  => 3076147256
```

関連: `set-file-write-time`, `file-newer-than-file-p`, `decode-universal-time`, `format-date-string`, `file-exist-p`, `get-universal-time`

## `find-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-file FILENAME &optional ENCODING NOMSG`

```text
指定されたファイルを開き、カレントバッファをこのファイルにします。 [C-x C-f]
インタラクティブに呼び出すとファイル名をミニバッファで尋ねます。
プレフィックスアーギュメント付きで呼び出すと、ファイルの文字
コードを指定して開くことができます。

  FILENAME : ファイル名、またはファイル名のリストです。
  ENCODING : ファイルの文字コードを指定します。
  NOMSG    : non-nil でステータスバーに状況などを出力しなくなります。
```

関連: `find-other-file`, `find-file-other-window`, `ed::find-file-internal`, `*prefix-args*`

## `find-file-in-archive`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-file-in-archive ARCNAME FILENAME`

```text
アーカイブからファイルを展開して開きます。

  ARCNAME  : アーカイブを指定します。
  FILENAME : 展開するファイルを指定します。

使用例：
  (find-file-in-archive "C:/foo/bar.lzh" "hoge/fuga.txt")
```

関連: `extract-archive`, `find-file`

## `find-file-other-window`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-file-other-window FILENAME &optional ENCODING NOMSG`

```text
指定されたファイルを別のウィンドウで開きます。[C-x 4 f]
```

関連: `find-file`

## `find-file-read-only`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-file-read-only FILENAME &optional ENCODING NOMSG`

```text
ファイル FILENAME を read-only で開きます。
FILENAME はファイルのリストであってもかまいません。

すでに FILENAME を読み込んでいるバッファがある場合、そのバッファを read-only に設定します。
FILENAME を読み込んでいるバッファがない場合は find-file と同様にファイルを読み込み、
バッファを read-only に設定して *find-file-hooks* を実行します。

いずれの場合も最後に *find-file-read-only-hook* を実行します。

  ENCODING : エンコーディングを指定します。
  NOMSG    : non-nil ならステータスバーに経過メッセージを表示しません。
```

関連: `find-file`

## `find-other-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `find-other-file FILENAME &optional ENCODING NOMSG`

```text
現在のバッファを閉じて指定されたファイルを開きます。[C-x C-v]

互換性：
  muleにはなさそう。
```

関連: `*find-other-file-requires-file-name*`, `find-file`

## `format-drive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `format-drive &optional DRIVE QUICK`

```text
ドライブをフォーマットします。

  DRIVE : ドライブを文字で指定します。

使用例：
  (format-drive #\a t)
  => nil
```

## `get-disk-usage`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-disk-usage DIRECTORY &optional RECURSIVEP`

```text
指定されたディレクトリの容量を取得します。

  DIRECTORY  : 情報を取得するディレクトリを指定します。
  RECURSIVEP : サブディレクトリも再帰的にチェックするかを指定します。

戻り値は多値で返します。

  1 ブロックサイズ（バイト）
  2 全ディスク容量（バイト）
  3 空きディスク容量（バイト）
  4 ブロック単位の合計（バイト）
  5 ファイルサイズを単純に加算した合計（バイト）
  6 調べたディレクトリの個数
  7 調べたファイルの個数

使用例：
  (defun my-folder-size (my-dir)
    (interactive "Dfolder name: ")
    (let (my-dir-list (my-total-size  0))
      (setq my-dir-list (directory my-dir
                                   :wile "*.*"
                                   :absolute t
                                   :file-only t
                                   :recursive t
                                   :show-dots nil))
      (dolist (f my-dir-list)
        (setq my-total-size (+ my-total-size (file-length f))))
      (msgbox (format nil "フォルダの使用容量は、~d バイトです。"
                      my-total-size))))
```

## `get-file-attributes`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-file-attributes PATHNAME`

```text
ファイルの属性を返します。ファイルサイズや最終更新日などの情報も一括して取
得したい場合には、get-file-infoを使用しましょう。

  PATHNAME : 属性を取得するファイル名を指定します。

戻り値は以下の値の合計で表されます。

  ed::*file-attribute-readonly*   : 読み取り専用
  ed::*file-attribute-hidden*     : 隠しファイル
  ed::*file-attribute-system*     : システムファイル
  ed::*file-attribute-directory*  : ディレクトリ
  ed::*file-attribute-archive*    : アーカイブ
  ed::*file-attribute-compressed* : 圧縮

使用例：
  ;;; c:\autoexec.batの属性を取得してみる。多分アーカイブになっているので
  ;;; ed::*file-attribute-archive*との論理積が0以外になる。
  (get-file-attributes "c:/autoexec.bat")
  => 32
  (= (get-file-attributes "c:/autoexec.bat") ed::*file-attribute-archive*)
  => t
```

関連: `get-file-info`

## `get-file-info`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-file-info PATHNAME`

```text
ファイルの属性をまとめて取得します。属性・最終更新日・サイズ・短い
名前のリストの形式です。属性は以下の感じで。
  ed::*file-attribute-readonly*
  ed::*file-attribute-hidden*
  ed::*file-attribute-system*
  ed::*file-attribute-directory*
  ed::*file-attribute-archive*
  ed::*file-attribute-compressed*

使用例：
  (setq i (get-file-info (si:system-root)))
  => (16 3208385786 0 "XYZZY")
  (logand (car i) ed::*file-attribute-directory*)
  => 16
  (logand (car i) ed::*file-attribute-hidden*)
  => 0
  (format-date-string "%y/%m/%d %H:%M:%S" (cadr i))
  => "01/09/02 11:16:26"
```

## `get-short-path-name`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `get-short-path-name PATHNAME`

```text
PATHNAMEの8.3形式でのパスを返します。
使用例：
  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (get-short-path-name a)
  =>"C:/APPLIC~2/xyzzy/xyzzy.exe"
```

関連: `truename`

## `insert-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `insert-file FILENAME &optional ENCODING`

```text
指定されたファイルをカーソルの位置に読み込みます。[C-x i]
```

関連: `insert-file-contents`, `insert-buffer`, `find-file`

## `list-archive`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-archive ARCHIVE-FILE &optional FILE-NAME-ONLY`

```text
アーカイブのファイル名一覧を取り出します。

  ARCHIVE-FILE   : 一覧を取得するアーカイブを指定します。
  FILE-NAME-ONLY : 戻り値の形式を指定します。
        t   ファイル名(ディレクトリ名)のみを返します。
        nil ファイル名(ディレクトリ名)、属性、サイズ、タイムスタンプを
            返します。

使用例：
  (list-archive "foo.lzh")
```

関連: `create-archive`

## `make-temp-file-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-temp-file-name &optional PREFIX SUFFIX DIRECTORY DIRECTORY-P`

```text
一時作業用のファイルを作成しそのパスを返します。
ファイルは即時に作成されます。同じようにディレクトリを作成することも可能です。

  PREFIX      : 一時作業用のファイルの接頭子
  SUFFIX      : 一時作業用のファイルの拡張子
                指定が無ければ".tmp"となります。
  DIRECTORY   : 一時作業用のファイルを作成するディレクトリ
                指定が無ければ環境変数TMPに作成されます。
  DIRECTORY-P : ファイルではなくディレクトリを作成する場合
        t       ディレクトリを作成します。
        nil     ファイルを作成します。

使用例：
  ;;; C:\spoolに一時作業用ファイルを作成します。 
  (make-temp-file-name "_den" "tmp" "c:/spool")
  => "c:/spool/_denc0dc.tmp"
```

## `merge-pathnames`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `merge-pathnames PATHNAME &optional DEFAULTS`

```text
パスとファイル名をくっつけます。

  PATHNAME : ファイル名の部分を指定します。
  DEFUALTS : パスの部分を指定します。
             指定しないと(default-directory)のパスが使用されます。

使用例：
  ;;; "c:/foo"と"bar.l"をくっつける。
  (merge-pathnames "bar.l" "c:/foo")
  => "c:/foo/bar.l"

  (merge-pathnames "bar.l" "c:/foo/") <--ディレクトリの末尾に/がつい
  => "c:/foo/bar.l"                      ているかとか気にしなくていい。
```

関連: `file-namestring`, `directory-namestring`, `namestring`

## `new-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `new-file`

```text
ファイルに関連付けられていない新しいバッファ *untitled* を作ります。
```

関連: `get-buffer-create`, `create-new-buffer`

## `path-equal`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `path-equal PATHNAME1 PATHNAME2`

```text
PATHNAME1とPATHNAME2が同じパスを指していればt、そうでなければnilを返します。

使用例：
  (path-equal "C:/Windows/" "c:/windows")
  => t
```

関連: `sub-directory-p`

## `pathname-device`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-device PATHNAME`

```text
PATHNAMEのドライブ名を返します。
使用例：
  (setq a "//SAMURAI/Applications/xyzzy/xyzzy.exe")
  => "//SAMURAI/Applications/xyzzy/xyzzy.exe"

  (pathname-device a)
  => nil

  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  => "C:/Applications/xyzzy/xyzzy.exe"

  (pathname-device a)
  "C"
```

関連: `pathname-type`, `pathname-name`, `pathname-directory`, `pathname-host`

## `pathname-directory`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-directory PATHNAME`

```text
PATHNAMEのディレクトリ名を返します。各階層ごとの名前を要素とするリスト形
式で返されます。
使用例：
  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (pathname-directory a)
  =>("Applications" "xyzzy")
```

関連: `pathname-type`, `pathname-name`, `pathname-device`, `pathname-host`, `directory-namestring`

## `pathname-host`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-host PATHNAME`

```text
PATHNAMEのホスト名を返します。
使用例：
  (setq a "//SAMURAI/Applications/xyzzy/xyzzy.exe")
  =>"//SAMURAI/Applications/xyzzy/xyzzy.exe"

  (pathname-host a)
  =>"SAMURAI"

  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (pathname-host a)
  =>nil
```

関連: `pathname-type`, `pathname-name`, `pathname-directory`, `pathname-device`

## `pathname-match-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-match-p PATHNAME WILDNAME`

```text
PATHNAME が WILDNAME で指定されたワイルドカードにマッチするかどうかを
返します。

  PATHNAME : 検査対象のパス文字列
  WILDNAME : ワイルドカード文字列
             先頭文字が | の場合は否定の意味となる。
             *brackets-is-wildcard-character* の値が non-nil の場合は
             文字列中の [...] をワイルドカードと見なす。

戻り値：
  t    PATHNAME が WILDNAME にマッチする。
  nil  PATHNAME が WILDNAME にマッチしない。

使用例：
  (setq p (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (setq w (merge-pathnames "xyzzy.*" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.*"

  (wild-pathname-p p)
  =>nil

  (wild-pathname-p w)
  =>t

  (pathname-match-p p w)
  =>t

  (pathname-match-p p (concat "|" w))
  =>nil

  (setq w "*/xyzzy.ini")
  =>"*/xyzzy.ini"

  (pathname-match-p p w)
  =>nil

  (pathname-match-p p (concat "|" w))
  =>t
```

関連: `wild-pathname-p`, `*brackets-is-wildcard-character*`

## `pathname-name`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-name PATHNAME`

```text
PATHNAMEのファイル名（拡張子無し）を返します。
使用例：
  (setq a (merge-pathnames "xyzzy.exe" (si:system-root)))
  =>"C:/Applications/xyzzy/xyzzy.exe"

  (pathname-name a)
  =>"xyzzy"
```

関連: `pathname-type`, `pathname-directory`, `pathname-device`, `pathname-host`, `file-namestring`

## `pathname-type`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `pathname-type PATHNAME`

```text
ファイル名の拡張子を取り出します。拡張子がなければnilを返します。

  PATHNAME : 拡張子を取り出すファイル名を指定します。

使用例：
  ;;; foo.lzh
  (pathname-type "foo.lzh")
  =>"lzh"
  (pathname-type "foo/bar/zzz.txt")
  =>"txt"
```

関連: `pathname-name`, `file-namestring`

## `read-file`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `read-file FILENAME &optional ENCODING NOMSG`

```text
バッファをクリアして FILENAME の内容を書き込みます。[C-x C-r]
バッファ名およびバッファに関連付けられたファイルは変更しません。

  ENCODING : エンコーディングを指定します。
  NOMSG    : non-nil ならステータスバーに経過メッセージを表示しません。
```

関連: `find-file`, `insert-file-contents`, `insert-file`

## `remove-trail-slash`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `remove-trail-slash STRING`

```text
STRINGの末尾に"/"があれば削除した文字列を返します。
使用例：
  (remove-trail-slash "ffjfj")
  =>"ffjfj"

  (remove-trail-slash "ffjfj/")
  =>"ffjfj"
```

関連: `append-trail-slash`

## `rename-file`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `rename-file FILE NEW-NAME &key :if-exists :if-access-denied`

```text
ファイル名を変更します。
  
  FILE              : 変更前のファイル名を指定します。
  NEW-NAME          : 変更後のファイル名を指定します。
  :if-exists        : ファイルが存在する場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :overwrite      上書きします。
        :newer          新しければ上書きします。
  :if-access-denied : アクセスが拒否された場合の動作を指定します。
        :error          エラーを出力します。
        :skip           エラーは出力せず、nilを返します。
        :force          強制的にファイル名の変更を試みます。

変更できたかどうかで戻り値が変わります。

  t   変更に成功
  nil 変更に失敗

使用例：
  (rename-file "C:/xyzzy/test.txt" "C:/xyzzy/test2.txt")
  => t
```

関連: `rename`, `rename-buffer`

## `resolve-shortcut`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `resolve-shortcut PATHNAME`

```text
ショートカットからファイル名を求めます。

  PATHNAME : ショートカットを指定します。

使用例：
  (resolve-shortcut "d:/winnt/profiles/henmi2/personal/my documentsへのショートカット.lnk")
  => "G:/My Documents"
```

関連: `create-shortcut`

## `save-all-buffers`

- Function / package: editor / 定義: files.l
- 呼び出し: `save-all-buffers`

```text
すべてのバッファを保存します。
ファイル名があるバッファに対しては確認せずに保存します。
ファイル名がないバッファに対しては、ダイアログで保存するファイルを指定させます。
```

関連: `save-all-buffers-kill-xyzzy`, `save-some-buffers`

## `save-all-buffers-kill-xyzzy`

- Function / package: editor / 定義: files.l
- 呼び出し: `save-all-buffers-kill-xyzzy`

```text
すべてのバッファを保存して xyzzy を終了します。
save-all-buffers と kill-xyzzy の組み合わせです。
```

関連: `save-buffers-kill-xyzzy`, `kill-xyzzy`, `save-some-buffers`, `save-all-buffers`

## `save-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `save-buffer &optional CHAR-ENCODING EOL-CODE`

```text
バッファの内容を、バッファに関連付けられたファイルに書き込みます。[C-x C-s]

バッファに変更が無かった場合は何もしません。
バッファに変更があり、関連付けられたファイルがない場合、エラーになります。

  CHAR-ENCODING : エンコーディングを指定します。
  EOL-CODE      : 改行コードを指定します。
```

関連: `emacs-write-file`, `write-file`, `*before-save-buffer-hook*`, `*after-save-buffer-hook*`, `*save-buffer-no-filenames-hook*`, `make-backup-files`, `backup-by-copying`, `file-precious-flag`, `buffer-truncated-p`, `buffer-modified-p`, `save-all-buffers`, `save-some-buffers`

## `save-buffers-kill-xyzzy`

- Function / package: editor / 定義: files.l
- 呼び出し: `save-buffers-kill-xyzzy &optional VERBOSE`

```text
開いているバッファを保存して xyzzy を終了します。
save-some-buffers と kill-xyzzy の組み合わせです。

  VERBOSE : non-nil の場合保存するファイルごとにダイアログを表示して確認します。
```

関連: `save-all-buffers-kill-xyzzy`, `kill-xyzzy`, `save-some-buffers`

## `save-some-buffers`

- Function / package: editor / 定義: files.l
- 呼び出し: `save-some-buffers &optional VERBOSE (FN #'WRITE-FILE)`

```text
開いているバッファを保存します。[C-x s]
  VERBOSE : non-nilの場合保存するファイルごとにダイアログを表示して確認します。
```

関連: `save-all-buffers`, `save-buffers-kill-xyzzy`, `save-buffer`

## `set-default-directory`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-default-directory DIRECTORY &optional BUFFER`

```text
バッファが作業しているディレクトリを変更します。

  DIRECTORY : ディレクトリを指定します。
  BUFFER    : バッファを指定します。
              指定がなければカレントバッファになります。
```

関連: `default-directory`

## `set-file-write-time`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-file-write-time FILENAME UNIVERSAL-TIME`

```text
ファイルの最終更新日を変更します。

  FILENAME       : ファイル名を指定します。フルパスでなければ
                   (default-directory)からの相対パスになります。
  UNIVERSAL-TIME : 最終更新日をユニバーサルタイム形式で指定します。
```

関連: `file-write-time`, `decode-universal-time`, `format-date-string`

## `set-per-device-directory`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `set-per-device-directory DIRECTORY`

```text
ドライブ毎のデフォルトのディレクトリを設定します。ドライブ毎のデ
フォルトのディレクトリは、ファイラ等で移動すると毎回更新されます。
更新されたくない場合には、*auto-update-per-device-directory*をnil
に設定します。

使用例：
  (set-per-device-directory "D:/foo/bar")
  (set-per-device-directory "E:/bar/foo")
```

関連: `*auto-update-per-device-directory*`

## `special-file-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `special-file-p PATHNAME`

```text
PATHNAMEがデバイスファイル(CON, AUX, NUL, PRN, LPT1/2/3/4, COM1/2/3/4)か
否かを返します。
  t    デバイスファイルである。
  nil  デバイスファイルでない。
```

## `sub-directory-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `sub-directory-p DIRECTORY PARENT`

```text
DIRECTORYがPARENTのサブディレクトリならt、そうでなければnilを返します。

使用例： 
  (sub-directory-p "c:/windows/system" "c:/windows")
  => t
```

関連: `path-equal`

## `tail-f`

- Function / package: editor / 定義: tail-f.l
- 呼び出し: `tail-f FILENAME`

```text
tail コマンドの -f オプションのように、更新され続けるようなファイルを終
端まで読み込み続けようとします。
```

## `truename`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `truename PATHNAME`

```text
相対パスを絶対パスに変えます。

  PATHNAME : 変換するパスを指定します。

使用例：
  ;;; 相対パス及び絶対パスを指定して変換する。
  (truename ".")
  => "C:/applications/xyzzy"
  (truename "C:/applications/xyzzy/")
  => "C:/applications/xyzzy"
```

関連: `get-short-path-name`

## `user-config-path`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `user-config-path`

```text
ユーザ設定を格納しているディレクトリを返します。
ダイアログでの規定値等が格納されるディレクトリです。

起動時オプション -config で指定したり，XYZZYCONFIGPATH
で指定可能です。両方指定された場合，起動時オプションが
優先されます。

使用例：
  (user-config-path)
  =>"H:/xyzzy/usr/Administrator/w2k/"
```

関連: `user-homedir-pathname`, `xyzzy-ini-path`, `si:system-root`

## `user-homedir-pathname`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `user-homedir-pathname`

```text
ユーザーのホームディレクトリを返します。

find-fileしたときに"~/"で参照可能なディレクトリです。
起動時に、このディレクトリに格納されている.xyzzyを読み込みます。
同一PCを複数人で使用していたり、ネットワーク共有されたフォルダに
xyzzyを格納した場合には、ユーザ毎にホームディレクトリの設定して
.xyzzyを切り替えることができます。

ユーザのホームディレクトリは、以下の順番で決定されます。

  1)iniファイル内の[init]homeDir
  2)環境変数 XYZZYHOME
  3)環境変数 HOME
  4)環境変数 HOMEDRIVE + HOMEPATH
  5)iniファイル内の[init]logDir
  6)xyzzy.exeのpath

使用例：
  (user-homedir-pathname)
  => "C:/HOME/"
```

関連: `si:system-root`, `user-config-path`, `xyzzy-ini-path`

## `valid-path-p`

- Function / package: lisp / 定義: builtin.l
- 呼び出し: `valid-path-p PATHNAME`

```text
パスが有効かどうかをチェックします。

  PATHNAME : 有効かどうかをチェックするパス

ここで「有効なパス」というのは、最終的なファイルやディレクトリが存在する
ことを指すのではなく、途中の経路が存在することを指します。ファイルを指し
示している場合には、そのファイル自体の有無は関係ありません。そのファイル
に至るディレクトリが全て存在していることが有効か否かに関わります。

使用例：
  (valid-path-p "foo/bar/zzz.txt")
  =>nil
  (valid-path-p "/autoexec.bat")
  =>t
```

関連: `check-valid-pathname`, `file-exist-p`

## `write-file`

- Function / package: editor / 定義: files.l
- 呼び出し: `write-file FILENAME &optional NOMSG APPEND CHAR-ENCODING EOL-CODE`

```text
バッファの内容を FILENAME に書き込みます。[C-x C-w]
バッファ名およびバッファに関連付けられたファイルは変更しません。

  NOMSG         : non-nil ならステータスバーに経過メッセージを表示しません。
  APPEND        : non-nil ならファイルに追加します。
  CHAR-ENCODING : エンコーディングを指定します。
  EOL-CODE      : 改行コードを指定します。
```

関連: `append-file`, `save-buffer`, `emacs-write-file`, `*default-write-file-directory*`

## `write-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `write-region FROM TO FILENAME &optional APPEND CHAR-ENCODING EOL-CODE`

```text
リージョンをファイルに書き込みます。
APPEND が non nil なら追加書き込みをします。
```

## `wrong-disk`

- Misc / package: lisp

```text
注）どこにもみつからない？
```

関連: `wrong-disk-pathname`

## `wrong-disk-pathname`

- Function / package: lisp
- 呼び出し: `wrong-disk-pathname X`

```text
注）どこにもみつからない？
```

## `xyzzy-ini-path`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `xyzzy-ini-path`

```text
xyzzy.iniのフルパスを返します。

起動時オプション -ini で指定したり，XYZZYINIFILE
で指定可能です。両方指定された場合，起動時オプションが
優先されます。

使用例：
  (xyzzy-ini-path)
  => "H:/xyzzy/usr/Administrator/wxp/xyzzy.ini"

補足：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `user-config-path`, `user-homedir-pathname`, `si:system-root`
