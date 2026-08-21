# ポジション (positions)

reference/reference.xml から自動生成。93 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*gmark-keep-column*`

- Variable / package: editor / 定義: gmark.l

```text
non-nil なら、global-mark-goto と back-tag-jump の移動の時に行頭へ移動し
ないようになります。
```

## `*page-scroll-keep-window-position*`

- Variable / package: editor / 定義: page.l

```text
next-page実行時にバッファの最後がウィンドウ内にある場合、バッファ
の最後に移動します。previous-pageも同様です。

  t   移動しません
  nil 移動します
```

## `*smart-indentation*`

- Variable / package: editor / 定義: cmds.l

```text
インデント処理の前後で全く変更する必要が無かった場合の制御を設定します。

  nil      位置が同じでも従来通り常に変更する
  t        位置が違う場合のみ変更する（タブとスペースの組み合わせは気にする）
  上記以外 位置が違う場合のみ変更する（タブとスペースの組み合わせは気にしない）
```

関連: `smart-indentation`

## `back-to-indentation`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `back-to-indentation`

```text
カーソルをインデントの末尾（行の最初の空白でない文字）へ移動します。
[ESC m]
```

関連: `beginning-of-line`

## `backward-char`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-char &optional (N 1)`

```text
指定された文字数だけ後方に移動します。行頭ならば前行の終端に位置します。
[C-b], [Left]

互換性：
   Emacsではバッファの先頭ではエラーが発生します。xyzzyではエラーは発生
  しません。その代わり、動けたときは t、動けなければ nil を返します。
```

関連: `forward-char`

## `backward-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-line &optional (N 1)`

```text
N 行後方へ移動します。
移動の前後で goal-column を保存しません。

(backward-line n) と (forward-line (- n)) は同じです。
```

関連: `forward-line`

## `backward-page`

- Function / package: editor / 定義: page.l
- 呼び出し: `backward-page &optional (ARG 1)`

```text
後方の改ページまで移動します。[C-x ]]
改ページが無い場合はバッファの先頭に移動します。
一般には制御文字のform feedが単独である行で改ページを表します。

  ARG : ページ数を指定します。デフォルトは 1 です。
        負の値の場合、逆向きに移動します。
```

関連: `forward-page`

## `backward-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `backward-paragraph &optional (ARG 1)`

```text
カーソルを段落の先頭に移動します。[ESC {]
```

関連: `forward-paragraph`

## `backward-virtual-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-virtual-line &optional (N 1)`

```text
表示行で N 行後方へ移動します。
```

関連: `forward-virtual-line`

## `backward-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-word &optional (N 1)`

```text
カーソルを後方の単語に移動します。[ESC b]
```

関連: `forward-word`, `backward-char`

## `beginning-of-buffer`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `beginning-of-buffer`

```text
カーソルをバッファの先頭に移動します。[ESC <]
元あったカーソル位置にはマークを設定します。

マークを変更しないためには
(goto-char (point-min))を使います。
```

関連: `end-of-buffer`, `set-mark-command`, `selection-beginning-of-buffer`

## `beginning-of-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `beginning-of-line`

```text
行頭に移動します。goto-bolのinteractive版です。[C-a], [C-Left]
```

関連: `end-of-line`, `back-to-indentation`

## `beginning-of-virtual-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `beginning-of-virtual-line`

```text
表示行の行頭に移動します。
goto-virtual-bol の interactive 版です。
```

関連: `goto-virtual-bol`

## `bobp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `bobp`

```text
ポイントがバッファの先頭にあるか否かを返します。
  t    ポイントがバッファの先頭にある。
  nil  ポイントがバッファの先頭にはない。
```

関連: `eobp`

## `bolp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `bolp`

```text
カーソルが行頭にあればt、そうでなければnilを返します。
```

関連: `eolp`

## `count-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `count-column STRING &optional START BUFFER`

```text
文字列 STRING を出力した場合の出力後の桁位置を返します。
START と BUFFER はタブ文字の幅の計算に影響を与えます。

  STRING : 対象文字列
  START  : 出力開始とする桁位置
        nil      桁位置 0 からの出力
        INTEGER  桁位置 INTEGER からの出力 (0 未満の場合 range-error)
  BUFFER : 出力バッファ
        nil      タブ幅として (tab-column) の値を用います。
                 (tab-column (selected-buffer)) の値ではありません。
        BUFFER   タブ幅として (tab-column BUFFER) の値を用います。

戻り値：
  INTEGER   文字列 STRING 出力後の桁位置

補足：
  改行文字 "\n" は桁位置の初期化としては働かず、幅 2 として扱われます。
```

関連: `char-columns`, `current-column`

## `current-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-column`

```text
現在の桁位置を返します。
```

関連: `current-virtual-column`, `goto-column`

## `current-line-columns`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-line-columns`

```text
現在の表示行の桁数を返します。
改行文字 (#\LFD) は 2 桁と扱われます。
```

関連: `current-column`, `char-columns`, `goto-column`

## `current-line-number`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-line-number`

```text
現在の物理行の行番号を返します。
```

関連: `current-virtual-line-number`

## `current-virtual-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-virtual-column`

```text
カーソル位置の表示桁を返します。
※実際の表示が表示行／物理行には依存しません。
(current-virtual-column)
```

関連: `current-column`, `goto-virtual-column`

## `current-virtual-line-number`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `current-virtual-line-number`

```text
現在のポイントが表示行で何行目かを返します。
```

関連: `current-line-number`, `goto-virtual-line`

## `delete-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-marker MARKER`

```text
マーカーを削除します。
オブジェクトはマーカーとして使えなくなります。
成功した場合 t、すでに削除されていた場合は nil を返します。

使用例：
  (delete-marker m)
  => t
  m
  => #<deleted-marker 128914348>
```

関連: `unset-marker`

## `down-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `down-list &optional ARG NO-ERRORS`

```text
カーソルを前方にある ARG 個内側の括弧の後ろに移します。[ESC C-d]

  (setq lst '(a b c)) ; ここから
       ^
  (setq lst '(a b c)) ; ここへ
              ^

前方に括弧が見つからなかった場合、
NO-ERRORS が nil の場合にはエラーを、 t の場合には nil を返します。
また、直近にある括弧しか見つけられないようです。

  (defun test () (setq lst '(a b c))) ; ここから ARG = 2 で down-list すると
     ^                                ; エラーになる
```

関連: `backward-sexp`, `backward-list`, `up-list`

## `ed::get-selection-start-end`

- Function / package: editor / 定義: select.l
- 呼び出し: `get-selection-start-end`

```text
セレクションの開始位置と終了位置を多値で返します。
ただし、矩形選択状態ではnilを返します。
```

## `ed::map-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `map-selection FN`

```text
セレクションの開始位置と終了位置を引数にして関数を呼び出します。

  FN : 呼び出す関数を指定します。呼び出し時には開始位置と終了位置を渡し
       ますので、そのような関数のI/Fにしておかなければなりません。

使用例：
  ;;;
  (defun map-test ()
    (interactive)
    (ed::map-selection #'(lambda (start end) (message (format nil "~s ~s" start end)))))

補足：
  editorパッケージからエクスポートされてないので、ed::をつける必要があります。
  選択の開始位置と終了位置を正確に渡すので、前後関係に注意して下さい。
```

## `end-of-buffer`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `end-of-buffer`

```text
カーソルをバッファの末尾に移動します。[ESC >]
元あったカーソル位置にはマークを設定します。

マークを変更しないためには
(goto-char (point-max))を使います。
```

関連: `beginning-of-buffer`, `set-mark-command`, `selection-end-of-buffer`

## `end-of-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `end-of-line`

```text
現在行の終りに移動します。[C-e], [C-Right]
```

関連: `beginning-of-line`

## `end-of-virtual-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `end-of-virtual-line`

```text
表示行の行末に移動します。
goto-virtual-eol の interactive 版です。
```

関連: `goto-virtual-eol`

## `eobp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `eobp`

```text
ポイントがバッファの最後にあるかどうか調べます。

使用例：
  ;;; バッファの最後までカーソルをひとつひとつ進める？
  (while (not (eobp))
    (forward-char))
```

関連: `bobp`

## `eolp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `eolp`

```text
カーソルが行末にあるかどうか調べます。

  t     カーソルが行末にある
  nil   カーソルは行末にはない
```

関連: `bolp`

## `exchange-point-and-mark`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `exchange-point-and-mark`

```text
カーソルとマークの位置を入れ替えます。[C-x C-x]
```

関連: `mark`, `goto-last-modified-line`, `goto-last-mouse-point`

## `fill-column`

- Variable / package: editor / 定義: fill.l

```text
詰め込み時の折り返しの桁数を保持します。
既定値は 72 です。

使用例:
  ;;; 既定値を 62 に変更する。
  (setq-default fill-column 62)

カレントバッファの値を変更する場合は、関数 set-fill-column
を使用します。
```

関連: `auto-fill-mode`, `set-fill-column`, `fill-prefix`

## `forward-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-char &optional (ARG 1)`

```text
指定された文字数だけ右に移動します。改行があれば次行に移動します。
[C-f], [Right]

互換性： 
  Emacsでは移動できない場合エラーが発生します。xyzzyではエラーは発生し
  ません。その代わり、動けたときは t、動けなければ nil を返します。
```

関連: `backward-char`, `*prefix-args*`

## `forward-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-line &optional (N 1)`

```text
N行後に物理行に移動します。
移動の前後で goal-column を保存しません。

戻り値:
  移動した行数を返します。全く移動できなかったときは nil です。
```

関連: `previous-line`, `forward-virtual-line`, `next-line`, `*prefix-args*`

## `forward-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-list &optional ARG NO-ERRORS`

```text
前方のリストの終端へ移動します。[ESC C-n]
  
  使用例:
    ;;; forward-list で移動する
    ;;; 
    ;;; ^ でポイント位置を表す
    (let ((hoge '(1 2))) (foo hoge) ...)
      ^ 最初はこの位置
    (let ((hoge '(1 2))) (foo hoge) ...)
                        ^ 一回
    (let ((hoge '(1 2))) (foo hoge) ...)
                              二回 ^
```

関連: `forward-sexp`, `up-list`, `backward-list`

## `forward-page`

- Function / package: editor / 定義: page.l
- 呼び出し: `forward-page &optional (ARG 1)`

```text
前方の改ページまで移動します。[C-x []
改ページが無い場合はバッファの末尾に移動します。
一般には制御文字のform feedが単独である行で改ページを表します。

  ARG : ページ数を指定します。デフォルトは 1 です。
        負の値の場合、逆向きに移動します。
```

関連: `backward-page`

## `forward-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `forward-paragraph &optional (ARG 1)`

```text
カーソルを段落の末尾に移動します。[ESC }]
```

関連: `backward-paragraph`

## `forward-virtual-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-virtual-line &optional (ARG 1)`

```text
表示行で次行へ移動します。
```

関連: `forward-line`

## `forward-word`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `forward-word &optional (ARG 1)`

```text
カーソルを前方の単語に移動します。[ESC f]
```

関連: `backward-word`, `forward-char`

## `goal-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goal-column`

```text
現在のゴールカラムを取得します。
[xyzzy:06371] あたりのスレッドを見ると、save-excursionでゴールカラムが保
存されないのは仕様のようです。
```

関連: `set-goal-column`

## `goto-bol`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-bol`

```text
行頭に移動します。

互換性：
  xyzzyオリジナルのようです。
  効率がいいのでこれを使うのが推奨されているみたい。
```

関連: `goto-eol`, `goto-virtual-bol`

## `goto-char`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-char POINT`

```text
指定された位置にカレントバッファのカーソルを移動します。
この位置はpoint, point-min, point-max等のポイントを返す関数を
使用することで得ることが可能です。

  POINT: バッファ上の位置です。整数またはマーカーを利用できます。
         移動できる最小の位置は point-min で取得でき、これよりも小さい
         値を指定した時は point-min の位置に移動します。
         移動できる最大の位置は point-max で取得でき、これよりも大きい
         値を指定した時は point-max の位置に移動します。

戻り値：
  mule では、POINT が返されますが、 xyzzy では常に t です。
```

関連: `point-min`, `point-max`, `what-cursor-position`

## `goto-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-column COLUMN &optional EXCEED-P`

```text
指定された桁位置に移動します。移動した後の桁位置を返します。
current-line-columns が返す値よりも大きな値を指定した場合には、行の終端に
位置します。負の数を指定した場合には、行の先頭に位置します。

  COLUMN : 桁数
```

関連: `goto-virtual-column`, `current-virtual-column`, `current-line-columns`, `goto-line`

## `goto-eol`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-eol`

```text
行末に移動します。

互換性：
  xyzzyオリジナルのようです。
  効率がいいのでこれを使うのが推奨されているみたい。
```

関連: `goto-bol`, `goto-virtual-line`

## `goto-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-line LINE`

```text
指定された行番号にジャンプします。折り返しを有効にしていて表示行にジャン
プしたい場合には、goto-virtual-lineを使用します。[ESC g]
```

関連: `goto-virtual-line`, `goto-char`, `goto-column`, `goto-bol`, `goto-eol`

## `goto-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-marker MARKER`

```text
マーカーのポジションへポイントを移動します。
goto-char と違い、ポイント（数字）を引数として受け取ることはできません。
```

関連: `set-marker`, `goto-char`

## `goto-matched-parenthesis`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-matched-parenthesis &optional ARG`

```text
ポイントに存在するキャラクタが、syntax-open-pもしくはsyntax-close-pを満
たす場合に、対応するキャラクタに移動します。対応する各種括弧に移動するの
に使われます。[ESC ]]
```

## `goto-virtual-bol`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-virtual-bol`

```text
表示行の行頭に移動します。
※実際の表示が表示行／物理行には依存しません。
```

関連: `goto-bol`, `goto-virtual-eol`

## `goto-virtual-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-virtual-column COLUMN &optional EXCEED-P`

```text
指定された表示桁へ移動します。

  COLUMN   : 移動する表示桁位置を指定します。
  EXCEED-P : （詳細不明）

表示桁が折り返しの桁位置よりも大きいときは、折り返しの桁位置で止まります。
※実際の表示が表示行／物理行には依存しません。
```

関連: `goto-column`

## `goto-virtual-eol`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-virtual-eol`

```text
表示行の行末に移動します。
※実際の表示が表示行／物理行には依存しません。
```

関連: `goto-eol`, `goto-virtual-bol`

## `goto-virtual-line`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `goto-virtual-line LINE`

```text
表示行での指定行に移動します。
ウィンドウの表示行／物理行の切替は、「共通設定」－「表示」－「行番号は表示行(D)」
で行います。

参考：
  ファイルイメージ： 
    001| ABCDEFGHIJKLMNOPQR
    002| ABCDEFGHIJKLMNOPQRS
    003| ABCDEFGHIJKLMNOPQRST
    004| ABCDEFGHIJKLMNOPQRSTU
    005| ABCDEFGHIJKLMNOPQRSTUV

                    │
      ┌──────┴──────┐
      ↓                          ↓

  物理行：                        表示行：                      
    001| ABCDEFGHIJKLMNOPQR         001| ABCDEFGHIJKLMNOPQR
    002| ABCDEFGHIJKLMNOPQRS        002| ABCDEFGHIJKLMNOPQRS
    003| ABCDEFGHIJKLMNOPQRST       003| ABCDEFGHIJKLMNOPQRST
    004| ABCDEFGHIJKLMNOPQRST       004| ABCDEFGHIJKLMNOPQRST
       | U                          005| U
    005| ABCDEFGHIJKLMNOPQRST       006| ABCDEFGHIJKLMNOPQRST
       | UV                         007| UV
```

関連: `goto-line`

## `jump-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `jump-to-register R`

```text
レジスタ R に格納されたマーカーの位置へジャンプします。[C-x r j]
R にマーカーが入っていないとエラーになります。
```

関連: `point-to-register`

## `make-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `make-marker &optional BUFFER`

```text
空のマーカーを作って返します。
バッファを編集することで、マーカーの位置もそれに追随して変わります。
マーカーは、 goto-char や buffer-substring、delete-region などのバッ
ファ上の位置を引数にとる関数の引数として使用できます。

  BUFFER : マーカーを作るバッファを指定します。
           指定しなければ、現在のバッファになります。

使用例：
  ;; スクラッチでマーカーを作る
  (setq marker (make-marker (find-buffer "*scratch*")))
  => #<marker: *scratch*: ->

  ;; マーカーに位置を設定する
  (set-marker marker 3)
  => #<marker: *scratch*: 3>

  ;; マーカー位置に移動する
  (goto-char marker)
  => t

  ;; マーカーより手前の内容を削除する
  (goto-char (point-max))
  (delete-region 0 1)
  (marker-point marker)
  => 2

  ;; マーカーより手前に文字列を挿入する
  (goto-char 0)
  (insert "abc")
  (marker-point marker)
  => 5

  ;; マーカー位置に文字列を挿入する
  (goto-char marker)
  (insert "xyz")
  (marker-point marker)
  => 5
```

関連: `point-marker`, `markerp`, `set-marker`, `mark`, `marker-point`, `goto-char`, `process-marker`

## `mark`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `mark &optional FORCE`

```text
マークの位置を数値で返します。

  FORCE：マークが設定されていない場合に処理を継続するか？
        t       エラーとしない、関数はnilを返す
        nil     エラーとする
```

関連: `marker-point`, `make-marker`, `set-mark`, `exchange-point-and-mark`

## `mark-page`

- Function / package: editor / 定義: page.l
- 呼び出し: `mark-page &optional (ARG 0)`

```text
改ページで区切られた領域をリージョンに設定します。[C-x C-p]
改ページが無い場合、バッファ全体がリージョンになります。

  ARG : ページ位置を指定します。デフォルトは 0 です。
```

関連: `forward-page`, `backward-page`

## `marker-buffer`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `marker-buffer MARKER`

```text
マーカーが設定されているバッファを返します。

使用例：
  (marker-buffer m)
  => #<buffer: *scratch*>
```

## `marker-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `marker-point MARKER`

```text
マーカーの位置を数値で返します。
マーカーの位置が設定されていなかったり削除されていたりした場合は nil を返します。

使用例：
  (marker-point m)
  => 62
```

関連: `mark`, `set-marker`

## `narrow-to-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `narrow-to-region FROM TO`

```text
指定した範囲以外を移動・編集できないようにします。[C-x n]
save-restrictionのブロックが終了するか、widenすると元に戻ります。
point-min, point-maxの値も変わります。

使用例：
  C-SPCでマークを付けて、どっかに移動して、C-x n(narrow-to-region)とする
  と、指定したリージョンの外には移動できなくなります。私は置換のときに置き
  換える範囲を制限したり、キーボードマクロの範囲を制限したりするのによく使
  います。あとは、Lispコードの中で特定の範囲だけいじるときなんかにも使いま
  す。
```

関連: `hide-restricted-region`, `save-restriction`, `widen`, `point-min`, `point-max`

## `newline-and-indent`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `newline-and-indent &optional (ARG 1)`

```text
改行後、文字が存在する直前の行と同じ桁数だけインデントをします。
モードに依存したインデントコマンドは使用しません。[LFD], [C-j]
```

関連: `newline`, `indent-relative`

## `next-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `next-line &optional (N 1)`

```text
N行後の物理行に移動します。 
移動の前後で goal-column を保存します。

戻り値:
  1行でも移動できたときは t 、それ以外は nil です。
```

関連: `next-virtual-line`, `previous-line`, `forward-line`, `goal-column`

## `next-line-add-newlines`

- Variable / package: editor

```text
バッファの最後尾でnext-line系の移動をしたときの動作を設定します。

  t   空行を挿入します
  nil 何もしません

使用例：
  (setq next-line-add-newlines t)
```

関連: `next-line`

## `next-virtual-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `next-virtual-line &optional (N 1)`

```text
N行後の表示行に移動します。 [C-n], [Down]
  t    最終行以外の場合
  nil  最終行の場合
```

関連: `next-line`

## `next-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `next-word &optional (ARG 1)`

```text
カーソルを前方の単語の先頭に移動します。
```

関連: `forward-word`

## `point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `point`

```text
この関数は、ポイントの位置を integer として返します。 
goto-char でその位置に飛ぶことが出来ます。バッファの先頭ではpoint-minに
等しく、バッファの最後ではpoint-maxに等しいです。

使用例：
  (point)
  => 175
```

## `point-marker`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `point-marker`

```text
新しいマーカーを作成し、現在のカーソル位置にセットして返します。
```

関連: `set-marker`

## `point-max`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `point-max`

```text
カレントバッファの一番大きなポイント値を返します。narrow-to-region等で、
clipping 制限が用いられてない限り、カレントバッファの大きさになります。 

使用例：
  (point-max)
  => 189568
```

関連: `point-min`, `narrow-to-region`

## `point-min`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `point-min`

```text
カレントバッファの一番小さなポイント値を返します。narrow-to-region等で、
clipping 制限が用いられてない限り 0 になります。 

使用例：
  (point-min)
  => 0
```

関連: `point-max`, `narrow-to-region`

## `point-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `point-to-register R`

```text
新しいマーカーを作って現在位置にセットし、レジスタ R に格納します。
[C-x r SPC]
```

関連: `jump-to-register`

## `pre-selection-p`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `pre-selection-p`

```text
セレクションが存在すれば t しなければ nil を返します。
```

関連: `selection-point`, `selection-mark`, `get-selection-type`, `start-selection`

## `previous-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `previous-line &optional (N 1)`

```text
N行前に移動します。
移動の前後で goal-column を保存します。
(previous-line n) と (next-line (- n)) は同じです。

使用例:
  (previous-line)
```

関連: `forward-line`, `next-line`, `previous-virtual-line`

## `previous-virtual-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `previous-virtual-line &optional (N 1)`

```text
N行前の表示行に移動します。 [C-p], [Up]
  t    先頭行以外の場合
  nil  先頭行の場合
```

関連: `previous-line`

## `previous-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `previous-word &optional (ARG 1)`

```text
カーソルを後方の単語の先頭に移動します。
```

関連: `backward-word`

## `region-beginning`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `region-beginning`

```text
リージョンの開始のポイントを返します。

  ; markやpointとの関係
  (= (region-beginning) (min (mark) (point)))
  =>t
```

関連: `region-end`, `selection-mark`, `mark`, `point`

## `region-end`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `region-end`

```text
リージョンの終端のポイントを返します。

  ; markやpointとの関係
  (= (region-end) (max (mark) (point)))
  =>t
```

関連: `region-beginning`, `selection-point`, `mark`, `point`

## `save-excursion`

- Special Form / package: editor / 定義: builtin.l
- 呼び出し: `save-excursion {FORM}*`

```text
処理の前後でカレントバッファとポイントを保存します。ウィンドウのレイアウ
トは保存しないので注意してください。

ウィンドウのレイアウトも保存したい場合には、save-window-excursionを使います。
```

関連: `save-window-excursion`, `save-restriction`, `set-goal-column`

## `save-restriction`

- Special Form / package: editor / 定義: builtin.l
- 呼び出し: `save-restriction {FORM}*`

```text
narrow-to-regionする前の状態を保存します。ポイントやバッファの位置は保存
しません。ポイントやバッファの位置を保存したい場合には、save-excursionを
使用します。

特定の処理の前後でrestrictionの状態とポイントの両方を保存したい場合には、
以下の様にします。

  ;;; うまくいく書き方
  (save-excursion (save-restriction ... )) 

以下の様に書いてしまった場合、処理の中でrestrictionを掛けると内側の
save-excursionでのポイントの復元がうまくいかないことがあります。注意しま
しょう。

  ;;; うまくいかないことがある書き方
  (save-restriction (save-excursion ... ))

使用例：
    ;;; この時点では narrow-to-region してないとする。
    (save-restriction
      (narrow-to-region FROM-1 TO-1)             ; FROM-1からTO-1に制限する
      (save-restriction
        (narrow-to-region FROM-2 TO-2)           ; FROM-2からTO-2に制限する
        (msgbox "~A ~A" (point-min) (point-max))
      )                                          ; FROM-1からTO-1に制限されている
                                                 ; 状態に戻る
      (msgbox "~A ~A" (point-min) (point-max))
    )                                            ; 制限されなくなる
    (msgbox "~A ~A" (point-min) (point-max))
```

関連: `narrow-to-region`, `save-excursion`

## `selection-mark`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `selection-mark`

```text
セレクションの開始のポイントを返します。
```

関連: `selection-point`, `region-beginning`

## `selection-point`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `selection-point`

```text
セレクションの終端のポイントを返します。
```

関連: `selection-mark`, `region-end`

## `set-fill-column`

- Function / package: editor / 定義: fill.l
- 呼び出し: `set-fill-column &optional (COL (CURRENT-COLUMN))`

```text
詰め込み桁数を指定します。[C-x f]
指定された値は、変数 fill-column に代入されます。

  COL : 詰め込み桁数
        引数がない場合は、現在のカーソル位置の桁数を詰め込み桁数に設定し
        ます。
```

関連: `fill-column`

## `set-goal-column`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-goal-column COLUMN`

```text
ゴールカラムを設定します。save-excursionしてもgoal-columnが破壊されない
ように使用するぐらいでしょうか。

使用例：
  ;;; goal-columnを大事にして編集してみる。
  (let ((g (goal-column)))
    (save-excursion ... )
    (set-goal-column g))
  => t
```

関連: `goal-column`

## `set-mark`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-mark &optional POINT`

```text
ポイントの位置にマークを設定します。

  POINT: マークを設定する位置を指定します。
         範囲外の値を指定してもエラーにはならないようです。
```

関連: `mark`, `set-mark-command`

## `set-mark-command`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `set-mark-command`

```text
マークを設定します。[ESC SPC], [C-@]
ビルトイン関数の set-mark を対話に行うためのものです。

使用例：
  ;;; マークを設定してその位置を取得する。
  (set-mark-command)
  => t
  (mark)
  => 2554
```

関連: `set-mark`, `mark-word`, `mark-sexp`, `mark-defun`

## `set-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `set-marker MARKER &optional POINT`

```text
マーカーにポジションを設定します。
POINT が nil の場合は現在の位置を設定します。

  POINT : マーカーに設定する位置

使用例：
  (setq m (make-marker))
  => #<marker: *scratch*: ->
  (set-marker m)
  => #<marker: *scratch*: 62>
  (marker-point m)
  => 62
```

関連: `point-marker`, `unset-marker`, `make-marker`, `marker-point`, `goto-marker`

## `skip-token`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-token`

```text
多分シンボル構成文字と単語構成文字をスキップします。
（詳細不明）
```

関連: `skip-syntax-spec-forward`

## `skip-white-backward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-white-backward`

```text
空白文字を後方にスキップします。
シンタックステーブル上でwhitespaceとして規定されている文字を後方に
スキップします。他にも影響する要素があるようですが詳細は不明。
```

関連: `skip-white-forward`, `skip-syntax-spec-backward`

## `skip-white-forward`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `skip-white-forward`

```text
空白文字を前方にスキップします
シンタックステーブル上でwhitespaceとして規定されている文字を前方に
スキップします。他にも影響する要素があるようですが詳細は不明。
```

関連: `skip-white-backward`, `skip-syntax-spec-forward`

## `stop-selection`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `stop-selection`

```text
セレクションを解除します。
```

関連: `start-selection`, `fix-selection-point`

## `unset-marker`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `unset-marker MARKER`

```text
マーカーのポジションを解除します。
オブジェクトはマーカーとして残ります。

使用例：
  (unset-marker m)
  => t
  m
  => #<marker: *scratch*: ->
```

関連: `set-marker`, `delete-marker`

## `up-list`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `up-list &optional ARG NO-ERRORS`

```text
カーソルを ARG 個外側の括弧の後ろに移します。

  (setq lst '(a b c)) ; ここから
               ^
  (setq lst '(a b c)) ; ここへ
                    ^

ARG が負の場合には、前の方の括弧へ移動します。

  (setq lst '(a b c)) ; ここから
               ^
  (setq lst '(a b c)) ; ここへ
             ^

外側に括弧が見つからなかった場合、
NO-ERRORS が nil の場合にはエラーを、 t の場合には nil を返します。
```

関連: `forward-sexp`, `forward-list`, `down-list`

## `virtual-bolp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `virtual-bolp`

```text
仮想行の行頭にあるかを返します。
バッファが行を折り返して表示している場合に有効です。

  t     仮想行の行頭にある
  nil   仮想行の行頭にない
```

関連: `virtual-eolp`

## `virtual-eolp`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `virtual-eolp`

```text
仮想行の行末にあるかを返します。
バッファが行を折り返して表示している場合に有効です。

  t     仮想行の行末にある
  nil   仮想行の行末にない
```

関連: `virtual-bolp`

## `what-cursor-position`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `what-cursor-position`

```text
カーソル位置の情報をステータスバーに表示します。[C-x =]
カーソル位置の文字の内部コード値、UNICODE値、
カーソル位置のバッファにおける位置、
桁数などが表示されます。

使用例:
  "w"の位置で情報を見る
  Char: w (0x77 / U+0077 / 0x77[us-ascii])  point=46 of 518(8%)  column 7

  "カ"の位置で情報を見る
  Char: カ (0x834a / U+30ab / 0x252b[jisx0208])  point=152 of 395(38%)  column 0
```

関連: `iso-char-code`, `point`, `current-column`, `*status-bar-format*`

## `widen`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `widen`

```text
narrow-to-regionで制限された領域を元に戻します。[C-x w]
```

関連: `narrow-to-region`
