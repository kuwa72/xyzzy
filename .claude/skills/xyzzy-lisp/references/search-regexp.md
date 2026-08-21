# 検索・正規表現 (search-regexp)

reference/reference.xml から自動生成。40 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*isearch-scanner-hook*`

- Variable / package: editor / 定義: isearch.l

```text
isearch-scannerで実行されます。scan-bufferするパターンを書き換えることが
出来そうです。migemo用？

参考：
  (funcall *isearch-scanner-hook* pattern)
```

## `*wrap-search*`

- Variable / package: editor / 定義: search.l

```text
文字列検索でバッファの最後までいったら、最初に戻るかどうかを制御します。

| search-forward-again で、バッファの最後まで行くと、最初に
| 戻って探しつづけますよね。
| あれって禁止できないでしょうか？

  (setq *wrap-search* nil)

とすればできますけど、たまに禁止したいとなるとちょっと面倒ですね。

| と言うか、それはそれで便利なんだけど、禁止したい時もあるんです。
| 「ここ以降にあるか無いか」と言うことを知りたい時とか・・・

現在位置から最後までを narrow してサーチするとか。
count-matches が 0 だったら無いとか。
検索ダイアログから指定するとか。
```

## `compile-regexp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `compile-regexp REGEXP &optional CASE-FOLD`

```text
正規表現をコンパイルします。
随時正規表現の解析を行わない分、多少検索が早くなるようです。
第二引数にnil以外を指定すると(普通はtを指定します)大文字小文字を区別しません。

  REGEXP     : コンパイルする正規表現
  :case-fold : 大文字小文字を区別するか？
        t       大文字小文字は区別しない。
        nil     大文字小文字をする。

scan-bufferの引数にコンパイルされた正規表現を渡した場合には、
compile-regexpでの指定が有効になり,scan-bufferの引数にある:case-foldは無
視されます。

使用例：
  ;;; "単語.単語:"という正規表現をコンパイルしてみる。
  ;;; 真ん中の'.'は正規表現として扱って欲しくないので、regexp-quoteする。
  (compile-regexp (concat "\\w+" (regexp-quote ".") "\\w+:"))
  => #<compiled regular expression: \w+\.\w+:>
```

関連: `compiled-regexp-source`, `compiled-regexp-case-fold-p`, `regexpp`, `compile-regexp すると一応高速化されるんでしょうか？`

## `compile-regexp すると一応高速化されるんでしょうか？`

- Tips

```text
遅くはならないはずです(^^; ま、せいぜいこの程度ですが。

  (let ((tick (get-internal-real-time)))
    (dotimes (x 100000)
      (string-match "a" "a"))
    (- (get-internal-real-time) tick))
  => 3484
  
  (let ((tick (get-internal-real-time))
        (regexp (compile-regexp "a")))
    (dotimes (x 100000)
      (string-match regexp "a"))
    (- (get-internal-real-time) tick))
  => 2984
```

## `compile-regexp-keyword-list`

- Function / package: editor / 定義: re-kwd.l
- 呼び出し: `compile-regexp-keyword-list LIST`

```text
regexp-keyword-list用に正規表現のコンパイルを行います。
指定するLISTの形式はregexp-keyword-listを参照して下さい。
```

関連: `regexp-keyword-list`

## `compiled-regexp-case-fold-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `compiled-regexp-case-fold-p REGEXP`

```text
コンパイル済みの正規表現が、大文字小文字を区別するようになってい
るかどうかを判定します。

使用例：
  (setq a (compile-regexp "a+bc*d" t))
  => #<compiled regular expression: a+bc*d>
  (compiled-regexp-case-fold-p a)
  => t
```

関連: `compile-regexp`

## `compiled-regexp-source`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `compiled-regexp-source REGEXP`

```text
コンパイル済みの正規表現から元の正規表現を抽出します。

使用例：
  (setq a (compile-regexp "a+bc*d" t))
  => #<compiled regular expression: a+bc*d>
  (compiled-regexp-source a)
  => "a+bc*d"
```

関連: `compile-regexp`, `compiled-regexp-case-fold-p`

## `ed::*last-search-regexp*`

- Variable / package: editor

```text
前回の正規表現検索パターンが保存されています。
```

## `ed::*last-search-string*`

- Variable / package: editor / 定義: search.l

```text
前回の検索語が保存されています。
```

## `Emacs 互換ではない正規表現は結構あるのでしょうか？`

- Tips

```text
\'  \`  \=  \c  \C これだけです。
```

## `looking-at`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `looking-at REGEXP &optional CASE-FOLD`

```text
現在のカーソル位置で前方向に正規表現でマッチしたらt、しなかったらnilを返します。

使用例：
  ;;; カーソル位置が行頭でかつ(とマッチするか?
  (defun rrr ()
    (interactive)
    (if (looking-at "^(")
      (message "ok") (message "bad")))

  ;;; 空白やタブや全角スペースがあれば削除する
  (if (looking-at "[ \t　]*")
      (delete-region (match-beginning 0) (match-end 0)))

参考：
  ;;; looking-at の後方版 (正規表現で後方マッチ)
  ;;; XyzzyWiki 質問箱/175 より
  (defun looking-at-backward (regexp &optional case-fold)
    (save-excursion
      (save-restriction
        (narrow-to-region (point-min) (point))
        (goto-char (point-min))
        (scan-buffer (format nil "~A\\'" regexp)
                     :regexp t :case-fold case-fold))))
```

関連: `looking-for`, `scan-buffer`, `string-match`, `string-looking-at`, `正規表現の表記`

## `looking-back`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `looking-back STRING &optional CASE-FOLD`

```text
現在のカーソル位置から後方向にマッチしたらt、しなかったらnilを返します。

使用例：
  (looking-back "::")
  (looking-back "\\")
  (looking-back "#'")
```

関連: `looking-for`

## `looking-for`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `looking-for STRING &optional CASE-FOLD`

```text
現在のカーソル位置から前方向にマッチしたらt、しなかったらnilを返します。
後方向にマッチしたければlooking-backを、正規表現でマッチしたければ
looking-atを使用します。

使用例：
  (looking-for "^")
  (looking-for "define")
  (looking-for "::")
```

関連: `looking-at`, `looking-back`

## `match-beginning`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `match-beginning REGNUM`

```text
正規表現を使った検索後に一致した先頭のポイントを取得できます。

  REGNUM : 取得したい文字列を指定
        0の場合         正規表現全体に一致する文字列を取得
        1-9の場合       正規表現中のREGNUM番目の括弧に対応した文字列を取得
```

関連: `match-end`, `match-string`

## `match-data`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `match-data &optional DATA`

```text
scan-buffer で検索時点の状態を保持します。複数の検索をした後で、元の
検索の結果で match-string / match-beginning / match-end / replace-match 
を行うことが可能です。

使用例：
  ;;; カーソルより後ろにabcdefと文字列があった場合
  ;;; 検索を2回してからその結果をそれぞれ取得する。
  (let (1st 2nd)
    ; 検索
    (scan-buffer "a\\(\\w*\\)" :regexp t)
    (setq 1st (match-data))
    (scan-buffer "abc\\(\\w*\\)" :regexp t)
    (setq 2nd (match-data))
    ; 結果参照
    (store-match-data 1st)
    (msgbox "~A" (match-string 1))
    (store-match-data 2nd)
    (msgbox "~A" (match-string 1)))
```

関連: `store-match-data`, `scan-buffer`

## `match-end`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `match-end REGNUM`

```text
正規表現を使った検索後に一致した最後のポイントを取得できます。

  REGNUM : 取得したい文字列を指定
        0の場合         正規表現全体に一致する文字列を取得
        1-9の場合       正規表現中のREGNUM番目の括弧に対応した文字列を取得
```

関連: `match-beginning`, `match-string`

## `match-string`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `match-string REGNUM`

```text
正規表現を使った検索後に一致した文字列を取得することができます。
(buffer-substring (match-beginning REGNUM) (match-end REGNUM))に一致します。

  REGNUM : 取得したい文字列を指定
        0の場合         正規表現全体に一致する文字列を取得
        1-9の場合       正規表現中のREGNUM番目の括弧に対応した文字列を取得

使用例：
  ;;; 次に現れるLispのコメントを取得する。
  (progn
    (scan-buffer ";\\([^;\n]+\\)" :regexp t :no-dup nil)
    (match-string 1))
```

関連: `match-beginning`, `match-end`, `match-data`, `store-match-data`, `scan-buffer`, `正規表現の表記`

## `perform-replace`

- Function / package: editor / 定義: search.l
- 呼び出し: `perform-replace PATTERN REPLACEMENT QUERY REGEXP INTERACTIVE-P NOERROR`

```text
バッファを検索して文字列を置換します。特に判断がいらないのならば
scan-bufferするよりも簡単です。replace-bufferを使って実装されています。
  
  PATTERN       : 置換前文字列です。
  REPLACEMENT   : 置換後文字列です。\1, \2 ... \9も使用できます。
  QUERY         : 確認あり？
  REGEXP        : 正規表現？
  INTERACTIVE-P : 対話的かどうか？
                  undoの記録の仕方と、メッセージの出し方が違うだけ
  NOERROR       : 文字列が見つからないときエラーを出す？

互換性：
  muleにはなさそう。
```

関連: `replace-buffer`, `replace-string`, `substitute-string`

## `re-search-backward`

- Function / package: editor / 定義: search.l
- 呼び出し: `re-search-backward REGEXP &optional NOERROR`

```text
正規表現による後方検索をします。[ESC C-s]

  REGEXP  : 正規表現による検索文字列
  NOERROR : 文字列が見つからなかったときの動作を指定します。
        t   nil を返します。
        nil エラーメッセージを出力します。
```

関連: `re-search-forward`

## `re-search-backward-again`

- Function / package: editor / 定義: search.l
- 呼び出し: `re-search-backward-again`

```text
前回の正規表現検索パターンで後方検索します。
```

関連: `ed::*last-search-regexp*`, `re-search-forward-again`

## `re-search-forward`

- Function / package: editor / 定義: search.l
- 呼び出し: `re-search-forward REGEXP &optional NOERROR`

```text
正規表現による前方検索をします。[ESC s]

  REGEXP  : 正規表現による検索文字列
  NOERROR : 文字列が見つからなかったときの動作を指定します。
        t   nil を返します。
        nil エラーメッセージを出力します。
```

関連: `re-search-backward`

## `re-search-forward-again`

- Function / package: editor / 定義: search.l
- 呼び出し: `re-search-forward-again`

```text
前回の正規表現検索パターンで前方検索します。
```

関連: `ed::*last-search-regexp*`, `re-search-backward-again`

## `regexp-keyword-list`

- Variable / package: editor

```text
正規表現を用いたキーワードの色分け機能です。キーワード長は256文
字程度らしいです。

使用例：
  (defvar *c-number-formats*
    (compile-regexp-keyword-list
     '(("\\(^\\|\\_S\\)\\(?:[0-9]+\\.[0-9]*\\|\\.[0-9]+\\)\\(?:e[-+]?[0-9]+\\)?[fl]?\\($\\|\\_S\\)"
        t (:keyword 0 :bold) nil -1 -2)
       ("\\_<[0-9]+e[-+]?[0-9]+[fl]?\\_>" t 1)
       ("\\_<\\([1-9][0-9]*\\|0[0-7]*\\|0x[0-9a-f]+\\)\\(u?l\\|l?u\\|u?i64\\)?\\_>"
        t (:color 1 2 :underline)))))
  (make-local-variable 'regexp-keyword-list)
  (setq regexp-keyword-list *c-number-formats*)

形式：
  (compile-regexp-keyword-list
   '((regexp1 case-fold color [ context [ begin [ end ] ] ] )
     (regexp2 case-fold color [ context [ begin [ end ] ] ] )
     ...
     (regexpN case-fold color [ context [ begin [ end ] ] ] )))

パラメタ：
  regexp  
      正規表現
  case-fold
      non-nil  正規表現のマッチングで大文字小文字を区別しない
      nil      正規表現のマッチングで大文字小文字を区別する
  color
      下の何れかの形式で指定します。
      keyword-color
          0-2       キーワードの1-3の色
          3-5       キーワードの1-3の色でそのキーワードだけ反転 
          6-8       キーワードの1-3の色でその行の端から端まで反転
          9         単なるbold 
          10-18     0-8と同じ色でbold
          :string   文字列の色 
          :comment  コメントの色 
          :tag      タグの色 
      (:keyword keyword-color [attributes])
          keyword-color
              keyword-colorの値
          attributes
              :bold        ボールド 
              :underline   アンダーライン 
              :strike-out  取り消し線 
              :line        一行まるごと 
      (:color foreground [background [attributes]]) 
          foreground
              0-15  前景色
          background 
              0     指定しない
              1-15  背景色
  context
      キーワードが有効な文脈を指定します。下のシンボルもしくは
      シンボルのリストを指定します。指定しない場合には、nilが指
      定されたものとして動作します。
      :string   文字列内部で有効
      :tag      タグの内部で有効
      :comment  コメントの内部で有効
      nil       上記以外で有効
      t         全ての文脈で有効
  begin
      マッチしたテキストの色を付ける部分の開始位置を指定します。
      0-9ならば(match-beginning begin)の位置からです。-1--9なら
      ば(match-end (- begin))の位置からです。指定しないかnilの場合に
      は(match-beginning 0)の位置からです。
  end
      マッチしたテキストの色を付ける部分の終了位置を指定します。
      0-9ならば(match-end end)の位置までです。-1--9ならば
      (match-beginning (- end))の位置までです。指定しないかnilの場合に
      は(match-end 0)の位置までです。
```

関連: `正規表現の表記`

## `regexp-quote`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `regexp-quote REGEXP`

```text
REGEXPのメタ文字をエスケープした表現を返します。
例えば、「正規表現のメタ文字を含む文字列」を含む
正規表現で検索したい場合に便利です。
使用例：
  (regexp-quote "a+b*")
  =>"a\\+b\\*"
```

## `repeat-backward-search`

- Function / package: editor / 定義: search.l
- 呼び出し: `repeat-backward-search`

```text
前回検索した文字列を再度後方検索します。[S-F5]

前回の検索が正規表現によるものであれば正規表現を使って、そうでなければ
そのように実行されます。
```

関連: `repeat-forward-search`, `search-forward-again`, `re-search-forward-again`

## `repeat-forward-search`

- Function / package: editor / 定義: search.l
- 呼び出し: `repeat-forward-search`

```text
前回検索した文字列を再度前方検索します。[F5]

前回の検索が正規表現によるものであれば正規表現を使って、そうでなければ
そのように実行されます。
```

関連: `repeat-backward-search`, `search-forward-again`, `re-search-forward-again`

## `replace-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `replace-buffer PATTERN REPLACEMENT &key :case-fold :tail :regexp :left-bound :right-bound :once :literal :last-match`

```text
バッファ中の文字列を検索して置換します。replace-stringもperform-replace
もこれを使って実装されています。

使用例：
 ;;;  英字と漢字の間に空白を１つあける
 (replace-buffer "\\([A-Za-z0-9_]\\) *\\([\X8200-\X9fff\Xe000-\Xfcff]\\)"
    "\\1 \\2" :regexp t)
```

関連: `replace-string`, `perform-replace`, `substitute-string`, `gresreg`, `正規表現の表記`

## `replace-match`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `replace-match STRING &key :literal`

```text
直前の検索結果に基づいて、 STRING にあるメタ文字を解釈しつつ文字列を置き換
えます。 :literal が nil 以外の場合は、メタ文字を意識しません。

メタ文字：
   \0, \&    一致した文字列全体
   \1 ～ \9  正規表現検索での\(\)に対応する文字列

使用例：
  ;;; <!--文字列-->を[文字列]に置き換える場合
  (when (scan-buffer "<!--\\(.+\\)-->" :regexp t)
    (replace-match "[\\1]"))
  => t
```

関連: `replace-buffer`, `match-data`, `store-match-data`

## `replace-string`

- Function / package: editor / 定義: search.l
- 呼び出し: `replace-string PATTERN REPLACEMENT &optional NOERROR`

```text
バッファを検索して文字列で置換します。perform-replaceを使って実装されて
います。 [M-r]

  PATTERN     : 置換前文字列です。
  REPLACEMENT : 置換後文字列です。
  NOERROR     : 文字列が見つからないときにエラーを出す？

replace系の関数の系譜：
  replace-string         ：interactiveな関数として宣言されている。
    └perform-replace    ：普通はこれで十分の筈
        └replace-buffer ：いろいろと細かく設定したければこれで行う。

使用例：
  (defun test-proc ()
    (interactive)
    (replace-string "aaa" "xxx"))   ;; aaaをxxxに置換
```

関連: `query-replace`, `replace-buffer`, `substitute-string`

## `scan-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `scan-buffer PATTERN &key :no-dup :case-fold :reverse :tail :regexp :limit :left-bound :right-bound :last-match`

```text
バッファを検索します。

  PATTERN      : 検索パターンとして、[文字列]、[正規表現]、[コンパイル済
                 み正規表現]の何れかを指定する。
                 コンパイル済み正規表現の場合は :regexp の値は無視する。
                 また :case-fold 指定も無視され、compile-regexp 時の第2
                 引数の指定が用いられる。

  :no-dup      : 検索方向に対して次のポイントからの検索を指定する。
        nil     - 現在のポイントから検索する。
        non-nil - reverse が nil の場合は、次のポイントから検索する。
                  non-nil の場合は、前のポイントから検索する。

  :case-fold   : ASCII 文字の大文字小文字の区別の方法を指定する。
                 PATTERN が[コンパイル済み正規表現]の場合は、:case-fold
                 指定は意味をもたない。
        nil     - 大文字小文字を区別して検索する。
        :smart  - PATTERN に大文字が含まれていない場合、大文字小文字を区
                  別せずに検索する。
        上記以外- 大文字小文字を区別せずに検索する。

  :reverse     : 検索方向を指定する。
        nil     - バッファの末尾に向かって検索する。
        non-nil - バッファの先頭に向かって検索する。

  :tail        : 検索成功後の移動先ポイントをどこにするかを指定する。
        nil     - 検索成功後、マッチ範囲の先頭((match-beginning 0)のポイ
                  ント)に移動する。
                  bar を検索した場合、:tail が nil なら
                      foo bar baz qux quux ...
                          ^ ポイントはここに移動する。
        non-nil - 検索成功後、マッチ範囲の末尾((match-end 0)のポイント)
                  に移動する。
                  bar を検索した場合、:tail が non-nil なら
                     foo bar baz qux quux ...
                            ^ ポイントはここに移動する。

  :regexp      : PATTERN が [正規表現] であることを指定する。
                 PATTERN が[コンパイル済み正規表現]の場合は、:regexp 指
                 定は意味をもたない。
        nil     - PATTERN を[文字列]とみなす。
        non-nil - PATTERN を[正規表現]とみなす。

  :limit       : 検索範囲をポイント位置で制限する。 
                 文字数制限ではない。
        nil     - 制限なし。
        INTEGER - :reverse が nil の場合は、マッチ末尾文字のポイントが
                  INTEGER 未満となる範囲で検索する。non-nil の場合は、
                  マッチ先頭文字のポイントが INTEGER 以上となる範囲で検
                  索する。
        MARKER  - MARKER に設定されたポイントを上記 INTEGER と見なし検索
                  範囲を制限する。
                  MARKER にポイントが設定されていない((marker-point
                   MARKER) が nil)場合、scan-buffer は nil を返す。
        上記以外- type-error が発生される。

  :left-bound  : [文字列]検索時の左側境界マッチ条件を指定する。
                 正規表現検索の場合は無効。
        nil     - 左側境界に関わらずマッチ成立
        :symbol - マッチ範囲左側境界((match-beginning 0)のポイント)が、
                  以下の何れかの条件を満たせばマッチ成立
                    - バッファの先頭である
                    - バッファの末尾である
                  マッチ範囲左側境界のポイント、もしくは、その前のポイン
                  トの文字が、以下の何れかの条件を満たせばマッチ成立
                    - ASCII 文字でない
                    - syntax-table に word,symbol として登録されていない
                      ((syntax-word-p 文字), (syntax-symbol-p 文字) が
                       nil を返す。)
        上記以外- マッチ範囲左側境界((match-beginning 0)のポイント)が、
                  以下の何れかの条件を満たせばマッチ成立
                    - バッファの先頭である
                    - バッファの末尾である
                  マッチ範囲左側境界のポイント、もしくは、その前のポイン
                  トの文字が、以下の何れかの条件を満たせばマッチ成立
                    - ASCII 文字でない
                    - syntax-table に word として登録されていない
                      ((syntax-word-p 文字)がnilを返す。)

  :right-bound : [文字列]検索時の右側境界マッチ条件を指定する。
                 正規表現検索の場合は無効。
        nil     - 右側境界に関わらずマッチ成立
        :symbol - マッチ範囲右側境界((match-end 0)のポイント)が、以下の
                  何れかの条件を満たせばマッチ成立
                    - バッファの先頭である
                    - バッファの末尾である
                  マッチ範囲右側境界のポイント、もしくは、その前のポイン
                  トの文字が、以下の何れかの条件を満たせばマッチ成立
                    - ASCII 文字でない
                    - syntax-table に word,symbol として登録されていない
                      ((syntax-word-p 文字), (syntax-symbol-p 文字) が
                       nil を返す。)
        上記以外- マッチ範囲右側境界((match-end 0)のポイント)が、以下の
                  何れかの条件を満たせばマッチ成立
                    - バッファの先頭である
                    - バッファの末尾である
                  マッチ範囲右側境界のポイント、もしくは、その前のポイン
                  トの文字が、以下の何れかの条件を満たせばマッチ成立
                    - ASCII 文字でない
                    - syntax-table に word として登録されていない
                      ((syntax-word-p 文字) が nil を返す。)

  :last-match  : 使用効果不明
                 (perform-replace) でのみ用いられている。
                 (<last-match> . <last-match-char>) からなる。
                 <last-match> : 直前のscan-buffer成功時の
                     (match-beginning 0)のポイントを指定
                 <last-match-char>: 直前のscan-buffer成功時の
                     (match-end 0)の前のポイントの文字を指定

戻り値は以下のとおりです。

  t    検索に成功
  nil  検索に失敗

使用例：
  (scan-buffer 検索文字列 :regexp t)
  (scan-buffer 検索文字列 :tail t)
  (scan-buffer 検索文字列 :limit 3000)
  (scan-buffer 検索文字列 :reverse t)
  (scan-buffer 検索文字列 :regexp t :no-dup t)
```

関連: `match-beginning`, `match-end`, `perform-replace`, `make-marker`, `skip-chars-forward`, `正規表現の表記`

## `search-backward`

- Function / package: editor / 定義: search.l
- 呼び出し: `search-backward PATTERN &optional NOERROR`

```text
後方検索をします。[C-r]

  PATTERN: 検索文字列
  NOERROR: 文字列が見つからなかったときの動作を指定します。
        t   nil を返します。
        nil エラーメッセージを出力します。
```

関連: `search-forward`

## `search-backward-again`

- Function / package: editor / 定義: search.l
- 呼び出し: `search-backward-again`

```text
前回の検索語で後方検索します。
```

関連: `ed::*last-search-string*`, `search-forward-again`

## `search-forward`

- Function / package: editor / 定義: search.l
- 呼び出し: `search-forward PATTERN &optional NOERROR`

```text
前方検索をします。[C-s]

  PATTERN: 検索文字列
  NOERROR: 文字列が見つからなかったときの動作を指定します。
        t   nil を返します。
        nil エラーメッセージを出力します。
```

関連: `search-backward`

## `search-forward-again`

- Function / package: editor / 定義: search.l
- 呼び出し: `search-forward-again`

```text
前回の検索語で前方検索します。
```

関連: `ed::*last-search-string*`, `search-backward-again`, `*wrap-search*`

## `skip-chars-backward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-chars-backward CHARS`

```text
skip-chars-forwardの後ろ向きのものです。
```

関連: `skip-chars-forward`, `skip-syntax-spec-backward`

## `skip-chars-forward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-chars-forward CHARS`

```text
指定された文字群を前方方向にスキップします。

  CHARS : スキップする文字群を指定します。

skip-syntax-spec-forwardも似た動作をしますが、これはバッファのシンタック
ステーブルを見てスキップする文字を判断します。目的がはっきりしていれば、
skip-chars-forwardを使用しましょう。

使用例：
  ;;; 半角空白とタブ文字をスキップします。
  (skip-chars-forward " \t")
```

関連: `skip-chars-backward`, `skip-syntax-spec-forward`

## `skip-syntax-spec-backward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-syntax-spec-backward SYNTAX-SPEC`

```text
skip-syntax-spec-forwardの後ろ向きのものです。
```

関連: `skip-syntax-spec-forward`, `skip-chars-backward`, `skip-white-backward`

## `skip-syntax-spec-forward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-syntax-spec-forward SYNTAX-SPEC`

```text
シンタックステーブルのカテゴリ基づいて文字を前方方向にスキップします。

skip-syntax-spec-(for|back)ward は、シンタックステーブルで指定
される文字のカテゴリに基づいて、指定されたカテゴリに属する文字
をスキップする関数です。カテゴリを表す文字は以下の通りです(7 割
ぐらいは Emacs と互換性あり)。

;  ' '(スペース)  空白文字
;  .              記号
;  (              開き括弧
;  )              閉じ括弧
;  $              TeX の $
;  "              文字列の区切り
;  <             1 文字コメントの開始
;  >             1 文字コメントの終了
;  /              C++ の // コメントの終了
;  \              エスケープ文字
;  '              単独で現れたときは記号、シンボルに隣接している場合はシンボル
;  _              シンボルを構成する文字
;  w              単語を構成する文字
;  k              いわゆる半角カナ
;  j              漢字
;  x              ゴミ文字
;  {              タグの開始
;  }              タグの終了

最初に '^' を指定すると、指定したカテゴリ以外という意味になりま
す(正規表現の[^...]と同じ)。カレントバッファのシンタックステー
ブルに基づくので、バッファのモードによって動きが変わってきます。
ちなみに、単語を構成する文字は一般に英数字で、シンボルを構成す
る文字は単語を構成する文字以外で識別子に使えそうな文字という意
味です。

文字の並びには意味はありません。"w_" と"_w" は同じものを意味します。

使用例：
  ;;; ワードの区切りに移動・英字
  (skip-syntax-spec-forward "w_")

  ;;; ワードの区切りに移動・漢字
  (skip-syntax-spec-forward "jk_")
```

関連: `skip-syntax-spec-backward`, `skip-chars-forward`, `skip-white-forward`, `skip-token`

## `store-match-data`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `store-match-data DATA`

```text
match-data で退避しておいた検索時点の状態を戻します。
```

関連: `scan-buffer`, `match-data`

## `正規表現の表記`

- Tips

```text
正規表現の表記方法です。以下は 
  Toy's xyzzy memo - Data Library -
  http://www.carabiner-systems.com/xyzzy/data.html)
からの引用です。

--- 引用 ---
正規表現
regular expression 1999/12/29　Written by Tetsuya Kamei [xyzzy:03768] 

  ^         行頭にマッチ
  $         行末にマッチ
  .         改行文字を除く任意の 1 文字にマッチ
  [...]     文字クラスのどれか 1 文字にマッチ
  [^...]    文字クラスの補集合のどれか 1 文字にマッチ
  *         直前の正規表現の 0 回以上の繰り返しにマッチ (={0,})
  +         直前の正規表現の 1 回以上の繰り返しにマッチ (={1,})
  ?         直前の正規表現の 0 回か 1 回の繰り返しにマッチ (={0,1})
  \{M,N\}   直前の正規表現の M 回以上 N 回以下の繰り返しにマッチ
  \{M,\}    直前の正規表現の M 回以上の繰り返しにマッチ
  \{,N\}    直前の正規表現の N 回以下の繰り返しにマッチ
  \{N\}     直前の正規表現の N 回の繰り返しにマッチ
  \( \)     グルーピング
  \|        選択
  \1 ～ \9  後方参照
  \<        単語の開始にマッチ
  \>        単語の終了にマッチ
  \b        単語の境界にマッチ
  \B        単語の境界以外にマッチ
  \w        英数字にマッチ
  \W        英数字以外にマッチ
  \sc       シンタックスが c の 1 文字にマッチ
  \Sc       シンタックスが c 以外の 1 文字にマッチ
  \`        バッファの先頭にマッチ
  \'        バッファの最後にマッチ
  \         メタキャラクタのエスケープ

  [たぶん xyzzy 0.2.1.186 から]
  *?        直前の正規表現の 0 回以上の最短の繰り返しにマッチ
  +?        直前の正規表現の 1 回以上の最短の繰り返しにマッチ
  ??        直前の正規表現の 0 回か 1 回の最短の繰り返しにマッチ

            (let ((str "aAaaa"))
              (string-match "Aa?" str)
              (format t "[Aa? ] ... ~S: ~D-~D~%"
                      (match-string 0) (match-beginning 0) (match-end 0))
              (string-match "Aa??" str)
              (format t "[Aa??] ... ~S: ~D-~D~%"
                      (match-string 0) (match-beginning 0) (match-end 0)))
            ->[Aa? ] ... "Aa": 1-3
              [Aa??] ... "A": 1-2

  \{M,N\}?  直前の正規表現の M 回以上 N 回以下の最短の繰り返しにマッチ
  \{M,\}?   直前の正規表現の M 回以上の最短の繰り返しにマッチ
  \{,N\}?   直前の正規表現の N 回以下の最短の繰り返しにマッチ
  \(?:regexp\)
            部分正規表現のグルーピングを行うが，後方参照を行わない
            (すなわち\1，\2とかを使って参照できない，と)

  [さらに xyzzy 0.2.2.202 から]
  \_<       シンボルの開始位置にマッチ 
  \_>       シンボルの終了位置にマッチ 
  \_b       シンボルの境界にマッチ 
  \_B       シンボルの境界以外にマッチ 
  \_s       シンボル文字にマッチ 
  \_S       シンボル文字以外にマッチ
```

関連: `Emacs 互換ではない正規表現は結構あるのでしょうか？`
