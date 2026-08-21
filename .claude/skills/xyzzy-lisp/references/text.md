# テキスト (text)

reference/reference.xml から自動生成。84 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*char-encoding-list*`

- Variable / package: editor / 定義: encoding.l

```text
文字エンコーディングのリストです。ミニバッファからの入力補完候補のリスト
や file-name-dialog のエンコーディングのリストとして使われたりするみたい
です。
文字エンコーディングはクオートしてはいけないみたいですので、定義しなおす
時は注意してください。
```

## `*dabbrev-search-this-buffer-only*`

- Variable / package: editor / 定義: dabbrev.l

```text
dabbrev-expandの検索対象を設定します。

  t   カレントバッファのみを検索します
  nil 全バッファを検索します
```

関連: `dabbrev-expand`

## `*detect-char-encoding-buffer-size*`

- Variable / package: editor

```text
ファイルオープン時の文字エンコーディングの判別に利用するバッファサイズを
指定します。

ファイルの先頭から指定サイズ分を読み込んで、文字エンコーディングを
判別します。

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `detect-char-encoding`, `*detect-char-encoding-mode*`

## `*detect-char-encoding-mode*`

- Variable / package: editor

```text
detect-char-encoding での文字エンコーディングの判別方法を設定します。

  :xyzzy    : xyzzy オリジナルの判別方法を利用します。
              Shift_JIS や半角カタカナに強いですが、
              EUC-JP や UTF-8 では誤判定することが多いです。

  :libguess : libguess (Gauche) の判別方法を利用します。
              Shift_JIS や半角カタカナの判別では
              xyzzy オリジナルの判別方法より劣りますが、
              全体的に誤判定は少ないです。

備考：
  guess-char-encoding はこの変数の影響は受けません。
  常に libguess を利用した判別結果を返します。
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `detect-char-encoding`, `*detect-char-encoding-buffer-size*`

## `*do-completion`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `*do-completion STRING TYPE &optional WORDP LIST`

```text
指定した文字列を条件に従い補完します。

  STRING : 補完したい文字列
  TYPE   : 補完する型
        :symbol-name
        :function-name
        :command-name
        :variable-name
        :non-trivial-symbol-name
        :exist-file-name
        :file-name
        :file-name-list
        :directory-name
        :buffer-name
        :exist-buffer-name
        :list
        :list-ignore-case
  WORD   : nilでなければ単語ごとの補完
  LIST   : TYPE が :list か :list-ignore-case の場合の補完リスト

戻り値は以下のとおりです。

  多値で3つの値が戻ってきますので、multiple-value-bind で受け取るといい
  でしょう。complete.lの中にある do-completion-internal を参考にしてくだ
  さい。以下は場合分けをしています。

        [1] 補完の候補が存在しない場合     :no-completions と nil
        [2] マッチする候補がなかった場合   :no-match と nil
        [3] 与えられた文字列がすでに候補の
            いずれかと一致していて
            補完する必要がない場合
            [3.1] 一致した候補が一つだけ   :solo-match と list と prefix
            [3.2] 複数と一致した場合       :not-unique と list と prefix
        [4] 補完した場合                   補完した結果の文字列と list と prefix

  list は、一致した候補のリスト。
  prefix は、例えばファイル名の補完のときのディレクトリ名とか、
  シンボルの補完のときのパッケージ修飾部分とか。
```

関連: `*print-completion-list-hook*`, `*print-completion-sort-function*`, `*popup-completion-list-default*`

## `*global-abbrev-table*`

- Variable / package: editor / 定義: abbrev.l

```text
グローバルなabbrev-tableを設定します。
```

関連: `expand-abbrev`, `*local-abbrev-table*`, `define-abbrev-table`

## `*local-abbrev-table*`

- BufferLocal / package: editor / 定義: abbrev.l

```text
バッファごとのabbrev-tableを設定します。
ここでの定義は*global-abbrev-table*よりも優先して使用されます。
```

関連: `expand-abbrev`, `*global-abbrev-table*`, `define-abbrev-table`

## `*quotation-prefix*`

- Variable / package: editor / 定義: region.l

```text
引用を表す接頭子です。具体的には、 quote-region したときにリージョンの行頭
に挿入する文字列です。

参考：
  ;;; 初期値ではこんなものが設定されています。
  (defvar *quotation-prefix* "| ")
```

関連: `quote-region`

## `auto-fill-mode`

- Function / package: editor / 定義: fill.l
- 呼び出し: `auto-fill-mode &optional (ARG () SARG)`

```text
自動詰め込みモードの開始と終了をトグルします。
```

関連: `fill-column`, `auto-fill-hook`

## `backward-delete-char-untabify`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-delete-char-untabify &optional (ARG 1)`

```text
カーソル後方の文字を指定文字数分だけ削除します。タブ文字を削除する際は、
適当な数の半角スペースに置き換えられてから削除されます。
```

関連: `delete-backward-char`, `backward-delete-char-untabify-or-selection`, `untabify`

## `backward-delete-char-untabify-or-selection`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-delete-char-untabify-or-selection &optional (N 1)`

```text
セレクションで選択中ならばセレクション全体を、そうでなければカーソルの
後方の文字を指定文字数分だけ削除します。タブ文字を削除する際は、適当な
数の半角スペースに置き換えられてから削除されます。
```

関連: `delete-backward-char`, `backward-delete-char-untabify`

## `buffer-fold-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `buffer-fold-width &optional BUFFER`

```text
折り返しの状態を返します。

  BUFFER : 状態を取得するバッファ

戻り値は以下のとおりです。

  t    ウィンドウ幅で折り返す
  nil  折り返しをしない
  数値 その幅で折り返しをします。

多値で返ってきている t の意味は不明です。
```

関連: `default-fold-width`, `set-buffer-fold-width`

## `char-encoding-display-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-encoding-display-name ENCODING`

```text
エンコーディングの表示名を返します。

実行例：
  (char-encoding-display-name *encoding-utf8*)
  => "Unicode (UTF-8)"
  (char-encoding-display-name *encoding-utf8n*)
  => "Unicode (UTF-8N)"
  (char-encoding-display-name *encoding-sjis*)
  => "日本語(Shift_JIS)"
```

関連: `char-encoding-p`, `char-encoding-name`, `char-encoding-type`, `char-encoding-signature`

## `char-encoding-name`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-encoding-name ENCODING`

```text
エンコーディング名を返します。

実行例：
  (char-encoding-name *encoding-utf8*)
  => "utf8"
  (char-encoding-name *encoding-utf8n*)
  => "utf8n"
  (char-encoding-name *encoding-sjis*)
  => "sjis"
```

関連: `char-encoding-p`, `char-encoding-display-name`, `char-encoding-type`, `char-encoding-signature`

## `char-encoding-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-encoding-p OBJECT`

```text
OBJECTがchar-encoding objectならt、それ以外ならnilを返します。
```

関連: `char-encoding-name`, `char-encoding-display-name`, `char-encoding-type`, `char-encoding-signature`

## `char-encoding-signature`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-encoding-signature ENCODING`

```text
エンコーディングがBOM付きのUTFの場合tを返します。
UTF以外のエンコーディングを指定した場合はnilを返します。

実行例：
  (char-encoding-signature *encoding-utf8*)
  => t
  (char-encoding-signature *encoding-utf8n*)
  => nil
  (char-encoding-signature *encoding-sjis*)
  => nil

補足：
  xyzzy 0.2.2.241 から利用可能です。
```

関連: `char-encoding-p`, `char-encoding-name`, `char-encoding-display-name`, `char-encoding-type`

## `char-encoding-type`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `char-encoding-type ENCODING`

```text
エンコーディングのタイプを返します。
戻り値は以下の通りです。

  :auto-detect
  :binary
  :sjis
  :big5
  :iso2022
  :iso8859
  :windows-codepage
  :utf5
  :utf7
  :utf8
  :utf16

実行例：
  (char-encoding-type *encoding-utf8*)
  => :utf8
  (char-encoding-type *encoding-utf8n*)
  => :utf8
  (char-encoding-type *encoding-sjis*)
  => :sjis

補足：
  xyzzy 0.2.2.241 から利用可能です。
```

関連: `char-encoding-p`, `char-encoding-name`, `char-encoding-display-name`, `char-encoding-signature`

## `clear-all-text-attributes`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `clear-all-text-attributes`

```text
set-text-attribute で設定した属性を全部消します
```

関連: `delete-text-attributes`, `delete-text-attribute-point`, `set-text-attribute`

## `clear-all-text-colors`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `clear-all-text-colors`

```text
set-text-color で付けた属性を消します。

補足:
  この関数は Version 0.0.0.92 にて set-text-color とともに obsolete と
  なりました。
```

関連: `delete-text-attributes`, `set-text-color`

## `dabbrev-expand`

- Function / package: editor / 定義: dabbrev.l
- 呼び出し: `dabbrev-expand &optional ARG`

```text
動的略称展開により候補を順番に表示します。[C-x /]
```

関連: `dabbrev-popup`

## `dabbrev-popup`

- Function / package: editor / 定義: dabbrev.l
- 呼び出し: `dabbrev-popup`

```text
dabbrev-expandのポップアップリスト版です。[C-x \]
```

関連: `dabbrev-expand`, `popup-list`

## `decrease-text-font-size`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `decrease-text-font-size &optional (ARG 1)`

```text
フォントサイズを小さくします。

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `get-text-font`, `set-text-font`, `set-text-fontset`, `get-text-fontset`, `increase-text-font-size`

## `define-abbrev-table`

- Function / package: editor / 定義: abbrev.l
- 呼び出し: `define-abbrev-table TABNAME &optional DEFS`

```text
abbrev-tableを定義します。

  TABNAME : abbrev-tableの名前にあたるシンボル
  DEFS    : 静的略称展開の定義のリスト

また、TABNAMEが*abbrev-table-name-list*に登録され、編集やファイル出力と
いった操作が可能になります。

使用例:
  ;;; c-mode.lの定義
 (defvar *c-mode-abbrev-table* nil)
 (unless *c-mode-abbrev-table*
   (define-abbrev-table '*c-mode-abbrev-table*))
```

関連: `*abbrev-table-name-list*`, `*local-abbrev-table*`, `*global-abbrev-table*`

## `delete-backward-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-backward-char &optional (N 1)`

```text
カーソル後方の文字を指定文字数分だけ削除します。
```

関連: `delete-backward-char-or-selection`, `delete-char`

## `delete-backward-char-or-selection`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-backward-char-or-selection &optional (N 1)`

```text
セレクションがあればセレクション全体を、そうでなければカーソルの後方の
文字を削除します。[C-h]
```

関連: `delete-char-or-selection`

## `delete-blank-lines`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-blank-lines`

```text
カーソルのある行またはその次の行の前後に続く空行を削除します。[C-x C-o]
複数の空行が続く場合は改行文字を一つだけ残します。

なお空行とは半角スペースおよびタブのみからなる行のことです。
```

## `delete-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-char &optional (N 1)`

```text
指定文字数分だけ削除します。
```

関連: `delete-char-or-selection`, `delete-backward-char`

## `delete-char-or-selection`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-char-or-selection &optional (N 1)`

```text
セレクションで選択中ならばセレクション全体を、そうでなければカーソルの位
置の文字を削除します。delete-charとはセレクション時の動作が異なります。
[C-d], [Delete]
```

関連: `delete-char`, `delete-selection`

## `delete-horizontal-spaces`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-horizontal-spaces`

```text
同一行内のカーソル位置の前後の空白を削除します。[ESC \]
```

関連: `just-one-space`

## `delete-text-attribute-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-text-attribute-point POINT`

```text
POINT の位置のテキスト属性を削除します。
テキスト属性のうち POINT の位置を範囲に含むものを削除します。
```

関連: `delete-text-attributes`

## `delete-text-attributes`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-text-attributes TAG &key :test :test-not :key`

```text
set-text-attributeで指定したタグの属性を消します
```

関連: `delete-text-attribute-point`, `delete-text-attributes-if`, `clear-all-text-attributes`, `set-text-attribute`

## `delete-text-attributes-if`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-text-attributes-if TEST &key :key`

```text
テキスト属性のうち、タグが TEST を満たすものをすべて削除します。
```

関連: `delete-text-attributes-if-not`, `delete-text-attributes`

## `delete-text-attributes-if-not`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-text-attributes-if-not TEST &key :key`

```text
テキスト属性のうち、タグが TEST を満たさないものをすべて削除します。
```

関連: `delete-text-attributes-if`, `delete-text-attributes`

## `delete-trailing-spaces`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `delete-trailing-spaces`

```text
ポイント後方の連続するスペースを削除します。
```

## `detect-char-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `detect-char-encoding STRING-OR-STREAM`

```text
STRING-OR-STREAM の文字エンコーディングを判定します。
```

関連: `set-stream-encoding`, `stream-encoding`, `convert-encoding-from-internal`, `convert-encoding-to-internal`, `guess-char-encoding`, `*detect-char-encoding-mode*`, `*detect-char-encoding-buffer-size*`

## `do-completion`

- Function / package: editor / 定義: complete.l
- 呼び出し: `do-completion FROM TO TYPE &optional COMPL WORD LAST-CHAR (POPUP-P *POPUP-COMPLETION-LIST-DEFAULT*)`

```text
テキストの補完をします。
詳細は*do-completionを参照して下さい。

使用例：
  ;;; カーソルの直前のパスを補完します。
  (do-completion (point) 
                 (progn (skip-syntax-spec-backward "^ ") (point))
                 :file-name)
```

関連: `*do-completion`, `*print-completion-list-hook*`, `*print-completion-sort-function*`, `*popup-completion-list-default*`

## `expand-abbrev`

- Function / package: editor / 定義: abbrev.l
- 呼び出し: `expand-abbrev`

```text
カーソル位置で静的略称展開を行います。[C-x ']
abbrev-mode の時は self-insert-command でも実行されます。
```

関連: `abbrev-mode`

## `find-text-attribute`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-text-attribute TAG &key :start :end :from-end :test :test-not :key`

```text
set-text-attributeで指定したタグを検索します。

(progn
  (set-text-attribute 1 6 'my-tag 1)
  (multiple-value-bind (from to tag)
      (find-text-attribute 'my-tag)
    (format t "~d, ~d, ~A" from to tag)))
==> 1, 6, my-tag

| 2. set-text-attribute で、複数範囲に同一 tag を指定した場
|    合、find～ は一番先頭に近いものしか返さない(ところしか
|    見たことがない)のですが、二番目以降を取得することはで
|    きますでしょうか？

find-text-attribute TAG :start POS

で、POS に現在位置+1を与えれば次のが返ってくる予定です。
使ったことないので動くかどうか分かりませんが。

| 3. find-text-attribute の &key 引数は、何か意味を持ってい
|    ますでしょうか？

シーケンスと同様に、:test と :test-not には比較関数を
与えます。また、:key にはアクセス関数(か?)を与えます。
たとえば、tag の形式が

  ("foo" bar)

である場合、

  (find-text-attribute "foo" :test #'equal :key #'car)

とか、

  (find-text-attribute 'bar :test #'eq :key #cadr)

で検索することができる予定です。使ったことないので動く
かどうか分かりませんが。

:test-not は、関数が nil を返した場合に真とする以外は :
test と同様です。:test と :test-not は同時に指定するこ
とはできず、省略した場合は :test #'eql が与えられたも
のとします。また :key を省略した場合は :key #'identity 
が与えられたものとします(たぶん)。
```

関連: `find-text-attribute-if`, `find-text-attribute-if-not`, `find-text-attribute-point`

## `find-text-attribute-if`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-text-attribute-if TEST &key :start :end :from-end :key`

```text
テキスト属性のうち、タグが TEST を満たすものを探し、最初に見つかったものを返します。
多値で、テキスト属性の開始位置・終了位置・タグを返します。

  :start     検索開始位置（デフォルトでは point-min?）
  :end       検索終了位置（デフォルトでは point-max?）
  :from-end  後ろから検索するかどうか
  :key       TEST に渡す前にタグに適用する関数
```

関連: `find-text-attribute-if-not`, `find-text-attribute`, `find-text-attribute-point`, `set-text-attribute`

## `find-text-attribute-if-not`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-text-attribute-if-not TEST &key :start :end :from-end :key`

```text
テキスト属性のうち、タグが TEST を満たさないものを探し、最初に見つかったものを返します。
多値で、テキスト属性の開始位置・終了位置・タグを返します。

  :start     検索開始位置（デフォルトでは point-min?）
  :end       検索終了位置（デフォルトでは point-max?）
  :from-end  後ろから検索するかどうか
  :key       TEST に渡す前にタグに適用する関数
```

関連: `find-text-attribute-if`, `find-text-attribute`, `find-text-attribute-point`, `set-text-attribute`

## `find-text-attribute-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `find-text-attribute-point POINT`

```text
POINT の位置のテキストの属性を多値で返します。

  FROM          属性を付加された開始位置
  TO            属性を付加された終了位置
  TAG           個々の属性を区別するタグ
  FOREGROUND    文字色
  BACKGROUND    背景色
  BOLD          ボールド
  UNDERLINE     下線付き
  STRIKE-OUT    取り消し線
  PREFIX        不明
  EXTEND        不明

使用例：
  ;;; my-tagというタグ名で領域を緑色に設定
  (set-text-attribute (point-min) (point-max) 'my-tag :foreground 2)
  => t
  ;;; カーソル位置にタグがあれば赤色かつボールドに変更
  (multiple-value-bind (from to tag foreground background bold underline strike-out prefix extend)
      (find-text-attribute-point 1)
    (when tag
      (modify-text-attributes tag ; foregroundとbold以外はそのまま設定する。
       :foreground 1              ; 赤色に設定
       :background background
       :bold t                    ; ボールドに設定
       :underline underline
       :strike-out strike-out
       :prefix prefix
       :extend extend)))
  => t
```

関連: `modify-text-attributes`, `find-text-attribute`, `delete-text-attribute-point`

## `following-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `following-char`

```text
カーソルがある位置のキャラクタを返します。
バッファの末尾にカーソルがある場合には、#\NULを返します。

使用例：
  ;;; "長崎市"の'崎'の上にカーソルがある場合
  (following-char)
  => #\崎

  ;;; [EOF]にカーソルがある場合
  (following-char)
  => #\NUL
```

関連: `preceding-char`, `char-after`

## `get-filer-font`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-filer-font`

```text
ファイラのフォント設定を取得します。
フォントを設定していない場合は nil を返します。

使用例：
  (get-filer-font)
  => nil

  (set-filer-font :face "メイリオ" :size 12 :size-pixel-p nil)
  => t

  (get-filer-font)
  => (:face "メイリオ" :size 12 :size-pixel-p nil)

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `set-filer-font`

## `get-text-font`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-text-font LANG`

```text
指定した言語のフォント設定を取得します。

  LANG : フォント設定を変更する言語を指定します。
         :ascii          : ASCII
         :japanese       : 日本語
         :latin          : ラテン文字
         :cyrillic       : キリル文字
         :greek          : ギリシャ語
         :cn-simplified  : 中国語(簡体字)
         :cn-traditional : 中国語(繁体字)
         :ksc5601        : 韓国語
         :georgian       : グルジア文字

使用例：
  (get-text-font :ascii)
  => (:face "Consolas" :size 14 :size-pixel-p nil)

  (get-text-font :japanese)
  => (:face "ＭＳ ゴシック" :size 14 :size-pixel-p nil)

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `set-text-font`, `set-text-fontset`, `get-text-fontset`, `increase-text-font-size`, `decrease-text-font-size`

## `get-text-fontset`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `get-text-fontset`

```text
フォント設定を取得します。

使用例：
  (get-text-fontset)
  => ((:ascii :face "Consolas" :size 14 :size-pixel-p nil)
      (:japanese :face "ＭＳ ゴシック" :size 14 :size-pixel-p nil)
      (:latin :face "Courier New" :size 13 :size-pixel-p nil)
      (:cyrillic :face "Courier New" :size 13 :size-pixel-p nil)
      (:greek :face "Courier New" :size 13 :size-pixel-p nil)
      (:cn-simplified :face "MS Hei" :size 14 :size-pixel-p nil)
      (:cn-traditional :face "MingLiu" :size 14 :size-pixel-p nil)
      (:ksc5601 :face "GulimChe" :size 14 :size-pixel-p nil)
      (:georgian :face "BPG Courier New U" :size 14 :size-pixel-p nil))

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `get-text-font`, `set-text-font`, `set-text-fontset`, `increase-text-font-size`, `decrease-text-font-size`

## `guess-char-encoding`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `guess-char-encoding STRING-OR-STREAM`

```text
STRING-OR-STREAM の文字エンコーディングを判定して、文字エンコーディングの
候補とスコアを返します。

例:
  (guess-char-encoding (convert-encoding-from-internal *encoding-utf8n* "スレ違い"))
  => ((#.(make-utf8-encoding "utf8n" "Unicode (UTF-8N)" :signature nil :windows t :byte-order nil :cjk :jp) . 1.0d0)
      (#.(make-sjis-encoding "sjis" "日本語(Shift_JIS)") . 0.6400000000000001d0))

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `detect-char-encoding`

## `increase-text-font-size`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `increase-text-font-size &optional (ARG 1)`

```text
フォントサイズを大きくします。

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `get-text-font`, `set-text-font`, `set-text-fontset`, `get-text-fontset`, `decrease-text-font-size`

## `indent-for-comment`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `indent-for-comment`

```text
行末にコメント文字列 (comment-start, comment-end) を挿入します。[ESC ;]
コメント位置は comment-indent-function を呼び出した結果で決まります。

コメント挿入後のカーソル位置は comment-start-skip か
comment-start-skip-function で指定できます。
```

## `indent-relative`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `indent-relative`

```text
半角スペースやタブ以外の文字を後方へ向かって検索し、最初に見つかった
場所の行のインデント幅と同じだけ現在行をインデントします。

ちなみに emacs の同名のコマンドとは挙動が違います。
```

関連: `newline-and-indent`

## `indent-to`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `indent-to COLUMN`

```text
指定された桁数までインデントします。現在のカーソル位置が引数より小さけれ
ばスペースを挿入します。そうでなければ何もしません。

  COLUMN : インデントする桁数を指定します。

戻り値は以下のとおりです。

  t   インデントした場合
  nil 何もしなかった場合
```

関連: `indent-relative`, `smart-indentation`

## `insert`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `insert &rest STRING-OR-CHAR`

```text
文字列をバッファに挿入します。

  STRING-OR-CHAR : 挿入する文字列を指定します。
                   &restで受けられているので何個でもOKです。

履歴：
  xyzzyのバージョン0.0.0.45.1よりまえのバージョンでは
  Emacsとinsertの仕様が、やや異なっていました。

  ;;; Emacsの場合
  (insert "abc" "def" "ghi")
  => "abcdefghi"が挿入される

  ;;; xyzzyの場合
  (insert "ab" 4)
  => "abababab"が挿入される

  xyzzyのバージョン0.0.0.45.1以降、Emacsとのinsert互換性が高まって
  います。

  (insert "foo")         => foo          ; 今までと同じ
  (insert "foo" 2)       => foofoo       ; 今までと同じ
  (insert "foo" "bar")   => foobar       ; Emacsと同じ
  (insert "foo" "bar" 2) => foobarfoobar
  (insert #\f "o" #\o)   => foo          ; Emacsと同じ
  (insert #\f "o" #\o 2) => foofoo
  (insert 2)             => エラー
  (insert "foo" 2 "bar") => エラー
  (insert 102 111 111)   => エラー       ; Emacsは  => foo
```

## `just-one-space`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `just-one-space`

```text
カーソル位置の前後にある半角スペースとタブを削除した後、半角スペース
をひとつだけ挿入します。[ESC /]
```

関連: `delete-horizontal-spaces`, `delete-indentation`

## `kinsoku-bol-chars`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-bol-chars &optional BUFFER`

```text
行頭禁則文字の集合を文字列で返します。
```

関連: `kinsoku-eol-chars`, `set-kinsoku-chars`

## `kinsoku-eol-chars`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-eol-chars &optional BUFFER`

```text
行末禁則文字の集合を文字列で返します。
```

関連: `kinsoku-bol-chars`, `set-kinsoku-chars`

## `kinsoku-extend-limit`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-extend-limit &optional BUFFER`

```text
禁則処理でぶら下げる文字数を返します。
```

関連: `kinsoku-bol-chars`, `kinsoku-shorten-limit`, `set-kinsoku-chars`, `kinsoku-goto-column`

## `kinsoku-goto-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-goto-column COLUMN &optional KINSOKU-MODE`

```text
COLUMN桁で禁則処理を施したときの行末に移動します。
```

関連: `kinsoku-bol-chars`, `kinsoku-extend-limit`, `kinsoku-eol-chars`, `kinsoku-shorten-limit`

## `kinsoku-mode`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-mode &optional BUFFER`

```text
禁則処理の状態を表す4ビットのフラグを返します。

  8: 禁則処理を行うとき t
  4: ワードラップするとき t
  2: 改行文字をぶら下げるとき t
  1: 空白文字をぶら下げるとき t
```

関連: `set-kinsoku-chars`, `*fill-kinsoku-mode*`

## `kinsoku-shorten-limit`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `kinsoku-shorten-limit &optional BUFFER`

```text
禁則処理で追い出す文字数を返します。
```

関連: `kinsoku-eol-chars`, `kinsoku-extend-limit`, `set-kinsoku-chars`, `kinsoku-goto-column`

## `list-text-attributes`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `list-text-attributes &optional START END`

```text
バッファ中のテキスト属性をすべて探し、リストにして返します。
範囲を指定した場合、その範囲中に一部でも含まれるものをリストにします。

  START : 検索範囲の開始点
  END   : 検索範囲の終了点
```

関連: `find-text-attribute`, `set-text-attribute`

## `map-char-encoding-region`

- Function / package: editor / 定義: kanji.l
- 呼び出し: `map-char-encoding-region P1 P2 &optional ENCODING`

```text
リージョンの文字列データを文字エンコーディングが ENCODING のデータとして、
xyzzy内部コードへ変換します。
ENCODING が指定されない時は自動判定します。
```

関連: `detect-char-encoding`, `map-char-encoding-selection`, `parse-char-encoding-region`

## `modify-text-attributes`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `modify-text-attributes TAG &key :foreground :background :bold :underline :strike-out :prefix :extend :start :end :test :test-not :key`

```text
set-text-attribute で付けた領域の属性を変更します。
属性は引き継がれません。
例えば、set-text-attribute では :underline t としてから、
modify-text-attributes で :strike-out t としても、
下線と取り消し線の両方が表示される訳ではありません。

  TAG           set-text-attributeで指定したタグ
  :bold         ボールドで表示するかどうか
  :underline    下線付きで表示するかどうか
  :strike-out   取り消し線を表示するかどうか
  :foreground   文字色を整数で指定
  :background   背景色を整数で指定
  :prefix       使い方は不明
  :extend       行末の改行文字以降も変えるかどうか

使用例：
  ;;; バッファ全体をに下線を付けてから取り消し線にする。
  (set-text-attribute (point-min) (point-max) 'all :bold t :foreground 1)
  => t
  (modify-text-attributes 'all :strike-out t)
  => t
  (delete-text-attributes 'all)
  => t
```

関連: `set-text-attribute`

## `modify-text-attributes-if`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `modify-text-attributes-if TEST &key :foreground :background :bold :underline :strike-out :prefix :extend :start :end :key`

```text
テキスト属性のうち、タグが TEST を満たすものすべてについて、属性を変更します。
属性は引き継がれません。
範囲を指定した場合、開始点が範囲に含まれるもののみ変更されます。

  :bold        ボールドで表示するかどうか
  :underline   下線付きで表示するかどうか
  :strike-out  取り消し線を表示するかどうか
  :foreground  文字色を整数で指定
  :background  背景色を整数で指定
  :prefix      行番号部分に表示する文字
  :extend      行末の改行文字以降も変えるかどうか
  :start       検索開始位置
  :end         検索終了位置
  :key         TEST に渡す前にタグに適用する関数
```

関連: `modify-text-attributes-if-not`, `modify-text-attributes`, `set-text-attribute`

## `modify-text-attributes-if-not`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `modify-text-attributes-if-not TEST &key :foreground :background :bold :underline :strike-out :prefix :extend :start :end :key`

```text
テキスト属性のうち、タグが TEST を満たさないものすべてについて、属性を変更します。
属性は引き継がれません。
範囲を指定した場合、開始点が範囲に含まれるもののみ変更されます。

  :bold        ボールドで表示するかどうか
  :underline   下線付きで表示するかどうか
  :strike-out  取り消し線を表示するかどうか
  :foreground  文字色を整数で指定
  :background  背景色を整数で指定
  :prefix      行番号部分に表示する文字
  :extend      行末の改行文字以降も変えるかどうか
  :start       検索開始位置
  :end         検索終了位置
  :key         TEST に渡す前にタグに適用する関数
```

関連: `modify-text-attributes`, `modify-text-attributes-if`

## `newline`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `newline &optional (ARG 1)`

```text
改行を挿入します。[RET], [C-m]
```

関連: `newline-and-indent`

## `open-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `open-line &optional (ARG 1)`

```text
カーソル位置を変えないで改行を挿入します。[C-o]
```

関連: `split-line`

## `overwrite-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `overwrite-char C &optional (ARG 1)`

```text
文字を上書きします。

使用例：
  ;;; 半角空白で上書きする。
  (overwrite-char #\SPC)
  => t
```

## `preceding-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `preceding-char`

```text
カーソルの前の文字を返します。
バッファの先頭にカーソルがある場合には、#\NULを返します。

使用例：
  ;;; カーソルの直前が#\LFDか？つまりカーソルは行頭にあるか？
  (char= (preceding-char) #\LFD)
  => t
```

関連: `following-char`, `char-before`

## `self-insert-command`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `self-insert-command &optional (ARG 1)`

```text
最後に入力されたキー *last-command-char* を挿入モードの如何により
insert / overwrite-char します。
括弧が入力された時に強調表示がなされるのもこの中での作用です。
```

関連: `*auto-fill-hook`

## `set-buffer-fold-width`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-buffer-fold-width WIDTH &optional BUFFER`

```text
テキストの折り返し方法を制御します。[ツール]-[ローカル設定]-[表示]の"テ
キストの折り返し"と同じで、現在のバッファだけに影響します。

  WIDTH  : 折り返しの方法を指定します。
        nil     折り返しません。
        t       ウィンドウの幅で折り返します。
        数値    折り返し位置を指定します。
  BUFFER : ローカル設定するバッファを指定します。
```

関連: `buffer-fold-width`

## `set-filer-font`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-filer-font & :face :size :size-pixel-p`

```text
ファイラのフォントを設定します。
設定を変更した場合は t が、変更点がなかった場合は nil を返します。

  :face         : フォント名を指定します。
  :size         : フォントサイズを指定します。
  :size-pixel-p : フォントサイズがピクセル単位なら t を指定します。

使用例：
  (set-filer-font :face "メイリオ" :size 12)
  => t

  (set-filer-font :face "メイリオ")
  => nil

備考：
  xyzzy 0.2.2.239 から利用可能です。
```

関連: `get-filer-font`

## `set-kinsoku-chars`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-kinsoku-chars BOL-CHARS EOL-CHARS &optional BUFFER`

```text
禁則文字をセットします。
[ツール] - [共通設定] - [禁則処理] からでも、設定できます。

  BOL-CHARS: 行頭にきてはいけない文字の集合。
  EOL-CHARS: 行末にきてはいけない文字の集合。
  BUFFER:    nil ならば共通設定として、バッファが指定されれば
             そのバッファに対してローカルに設定。
```

関連: `kinsoku-bol-chars`, `kinsoku-eol-chars`

## `set-tab-columns`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-tab-columns COLUMN &optional BUFFER`

```text
タブ幅を設定します。

  COLUMN : タブ幅を指定します。1以上32以下の任意の整数です。
           2のべき乗である必要はありません。
  BUFFER : タブ幅を変更するバッファを指定します。
           指定がなければカレントバッファが対象になります。
```

関連: `tab-columns`

## `set-text-attribute`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-text-attribute FROM TO TAG &key :foreground :background :bold :underline :strike-out :prefix :extend`

```text
リージョンに色などの属性を付けます。
付けた属性は delete-text-attributes で消せます。
一括して消す場合には、clear-all-text-attributes を使用します。

  FROM          属性を付加する開始位置
  TO            属性を付加する終了位置
  TAG           個々の属性を区別するタグ
  :bold         ボールドで表示するかどうかを
  :underline    下線付きで表示するかどうかを
  :strike-out   取り消し線を表示するかどうか
  :foreground   文字色を整数で指定
  :background   背景色を整数で指定
  :prefix       使い方は不明
  :extend       行末の改行文字以降も変えるかどうか

色の整数について：
  [ツール]-[共通設定]-[フォント]のところにある表示色になります。

  :foreground 0     : 文字色
              1～15 : 文字1～文字15
  :background 0     : 背景色
              1～15 : 背景1～背景15

  15 より大きい値を指定すると，0～15 の色が繰り返されます。

使用例：
  ;;; バッファ全体を文字1の色にする。
  (set-text-attribute (point-min) (point-max) 'all :bold t :foreground 1)
  => t
  (delete-text-attributes 'all)
  => t
```

関連: `modify-text-attributes`, `find-text-attribute`, `delete-text-attributes`, `clear-all-text-attributes`, `list-text-attributes`, `find-text-attribute-point`

## `set-text-color`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `set-text-color FROM TO &optional FOREGROUND BACKGROUND CHAR EXTEND-P`

```text
指定された領域を装飾します。

  FROM       : 開始位置を指定します。
  TO         : 終了位置を指定します。
  FOREGROUND : 文字の色を番号で指定します。以下を参照
  BACKGROUND : 文字の色を番号で指定します。以下を参照
  CHAR       : （詳細不明）
  EXTEND-P   : （詳細不明）

参考：
  ;;; 番号と色の対応
         R   G   B
       ------------
   0     0   0   0
   1   255   0   0
   2     0 255   0
   3   255 255   0
   4     0   0 255
   5   255   0 255
   6     0 255 255
   7   255 255 255
   8     0   0   0
   9   128   0   0
  10     0 128   0
  11   128 128   0
  12     0   0 128
  13   128   0 128
  14     0 128 128
  15   128 128 128

補足:
  この関数は Version 0.0.0.92 にて obsolete となりました。
```

関連: `set-text-attribute`

## `set-text-font`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-text-font LANG & :face :size :size-pixel-p`

```text
指定した言語のフォント設定を更新します。
変更したい設定のみを指定可能です。
設定を変更した場合は t が、変更点がなかった場合は nil を返します。
変更した設定はxyzzy.iniに保存されます。

  LANG          : フォント設定を変更する言語を指定します。
                  :ascii          : ASCII
                  :japanese       : 日本語
                  :latin          : ラテン文字
                  :cyrillic       : キリル文字
                  :greek          : ギリシャ語
                  :cn-simplified  : 中国語(簡体字)
                  :cn-traditional : 中国語(繁体字)
                  :ksc5601        : 韓国語
                  :georgian       : グルジア文字
  :face         : フォント名を指定します。
  :size         : フォントサイズを指定します。
  :size-pixel-p : フォントサイズがピクセル単位なら t を指定します。

使用例：
  (set-text-font :ascii :size 10)
  => t

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `get-text-font`, `get-text-fontset`, `set-text-fontset`, `increase-text-font-size`, `decrease-text-font-size`

## `set-text-fontset`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-text-fontset FONTSET`

```text
FONTSETで指定したフォントの設定を更新します。
変更したい設定のみを指定可能です。
設定を変更した場合は t が、変更点がなかった場合は nil を返します。
変更した設定はxyzzy.iniに保存されます。

使用例：
  (set-text-fontset '((:ascii :face "Consolas" :size 20 :size-pixel-p t)
                      (:japanese :face "ＭＳ ゴシック" :size 20 :size-pixel-p t)))
  => t

  (set-text-fontset '((:ascii :size 16)))
  => t

  (set-text-fontset (get-text-fontset))
  => nil

備考：
  xyzzy 0.2.2.238 から利用可能です。
```

関連: `get-text-font`, `set-text-font`, `get-text-fontset`, `increase-text-font-size`, `decrease-text-font-size`

## `smart-indentation`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `smart-indentation COLUMN`

```text
行頭からcolumn文字インデントします。
*smart-indentation*がtの時は適度にサボったりするみたいです。
```

関連: `*smart-indentation*`, `indent-to`

## `split-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `split-line`

```text
カーソル位置から行末までのテキストを縦に 1 行下げ、2 行に分割します。[ESC C-o]
```

関連: `open-line`

## `tab-columns`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `tab-columns &optional BUFFER`

```text
タブ幅を返します。タブ幅はset-tab-columnsで設定できます。

  BUFFER : タブ幅を返すバッファを指定します。
           指定がなければカレントバッファが対象となります。
```

関連: `set-tab-columns`

## `tabify`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `tabify FROM TO`

```text
FROM と TO の間にある半角スペースを可能な限りタブ文字で置き換えます。
```

関連: `untabify`

## `transpose-chars`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `transpose-chars &optional (ARG 1 F)`

```text
ポイントのひとつ前の文字を、ポイントの位置の文字と交換します。 [C-t]
ポイント自体はひとつ前に進みます。
```

関連: `transpose-region`

## `transpose-lines`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `transpose-lines &optional (ARG 1)`

```text
カーソルのある行の一つ前の行と、そこから ARG 行先の行とを入れ換えます。[C-x C-t]
ただし ARG が 0 の場合にはマークの前の行と入れ換えます。
```

関連: `transpose-region`

## `transpose-region`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `transpose-region MOVER ARG`

```text
リージョンを入れ換えます。入れ換えるリージョンは MOVER を funcall して
決定されます。

使用例： 
  (transpose-region 'forward-paragraph arg)
```

関連: `transpose-chars`, `transpose-words`, `transpose-lines`, `transpose-sexps`, `transpose-paragraphs`

## `untabify`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `untabify FROM TO`

```text
FROM と TO の間にあるタブ文字を適当な数の半角スペースで置き換えます。
```

関連: `tabify`
