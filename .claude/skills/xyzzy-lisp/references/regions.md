# リージョン (regions)

reference/reference.xml から自動生成。95 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*kill-ring*`

- Variable / package: editor / 定義: region.l

```text
killした文字列を格納します。
*kill-ring*は長さが*kill-ring-max*であるリングバッファです。
```

関連: `*kill-ring-max*`, `kill-region`, `yank`, `*selection-ring*`

## `*kill-ring-max*`

- Variable / package: editor / 定義: region.l

```text
killで保存する個数です。*kill-ring*の長さです。
```

## `*rectangle-kill-buffer*`

- Variable / package: editor / 定義: rectangl.l

```text
コピーした矩形を格納します。
中身は矩形の各行の文字列を並べたリストです。
```

関連: `copy-rectangle`, `kill-rectangle`, `yank-rectangle`

## `*selection-ring*`

- Variable / package: editor / 定義: select.l

```text
copy-selectionやkill-selectionで切り取った選択された領域を管理します。
*selection-ring*は*kill-ring*と同様にリングバッファとして管理されます。
```

関連: `yank-selection`, `copy-selection`, `*kill-ring*`

## `append-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `append-rectangle`

```text
コピーしている矩形の各行を現在行以下の行末へ追加します。

使用例：
  こんなのをコピーしているときに
          ┌────┐
          │A       │
          │BC      │
          │DEF     │
          │GHIJ    │
          └────┘
  * の位置で append-rectangle すると
   ┌─────┐      ┌─────┐
   │*-lmn     │      │--lmnA    │
   │--op      │  →  │--opBC    │
   │--        │      │--DEF     │
   │--q       │      │--qGHIJ   │
   └─────┘      └─────┘
```

## `append-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `append-to-register R START END &optional DELETE`

```text
START と END で指定されるリージョンを、レジスタ R に格納されているテキ
ストの末尾へ追加します。 [C-x r a]
R にテキストが入っていないとエラーになります。
DELETE が non-nil ならば同時にリージョンをを削除します。
```

関連: `prepend-to-register`

## `backward-kill-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `backward-kill-paragraph &optional (ARG 1)`

```text
現在のパラグラフの先頭までkillします。
```

関連: `kill-paragraph`, `kill-region`

## `backward-kill-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `backward-kill-word &optional (ARG 1)`

```text
カーソル位置から後方の単語の先頭までを切り取り、キルリングに追加します。
[ESC C-h]
カーソルが単語の途中にある場合は、カーソル位置からその単語の先頭までが、
対象となります。
```

関連: `kill-word`

## `base64-decode-region`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `base64-decode-region FROM TO`

```text
リージョンをBase64デコードします。
```

関連: `si:base64-encode`, `base64-decode-region-to-file`

## `base64-decode-region-to-file`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `base64-decode-region-to-file FILENAME FROM TO`

```text
リージョンをBase64デコードしてファイルに保存します。
```

関連: `si:base64-decode`, `base64-decode-region`

## `capitalize-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `capitalize-region FROM TO`

```text
リージョン内の単語をcapitalizeします。
つまり、単語の先頭を大文字に、それ以外を小文字にします。
```

関連: `downcase-region`, `upcase-region`

## `clear-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `clear-rectangle P1 P2`

```text
P1 と P2 で指定される矩形領域を #\SPC で上書きします。
```

関連: `open-rectangle`, `clear-rectangle-selection`, `operate-on-rectangle`

## `clear-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `clear-rectangle-selection`

```text
矩形選択されたセレクションの領域を #\SPC で上書きします。
```

関連: `open-rectangle-selection`, `clear-rectangle`, `operate-on-rectangle-selection`

## `clear-reverse-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `clear-reverse-region`

```text
reverse-regionで反転表示した部分を元に戻します。
```

関連: `reverse-region`

## `copy-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `copy-rectangle P1 P2`

```text
P1とP2で指定される矩形領域をコピーします。コピーした矩形領域のyankには、
yank-rectangleを使います。
```

関連: `kill-rectangle`, `copy-rectangle-selection`

## `copy-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `copy-rectangle-selection`

```text
マウスで矩形選択されたセレクションの領域をコピーします。yankには
yank-rectangle-selectionを使いますが、yank-rectangleでも行けそうです。
コピーした内容は*kill-ring*ともクリップボードとも違う領域に格納されてい
るようです。
```

関連: `kill-rectangle-selection`, `copy-rectangle`, `operate-on-rectangle-selection`

## `copy-rectangle-selection-to-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `copy-rectangle-selection-to-clipboard`

```text
マウスで矩形選択されたセレクションの領域をクリップボードにコピーします。
```

関連: `kill-rectangle-selection-to-clipboard`, `copy-rectangle-selection`, `copy-to-clipboard`

## `copy-rectangle-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `copy-rectangle-to-register R START END &optional DELETE`

```text
START と END で指定される矩形領域をレジスタ R へコピーします。[C-x r r]
DELETE が non-nil ならば同時に領域を削除します。
コピーした矩形領域の yank には、 insert-register を使います。
```

関連: `copy-rectangle`, `kill-rectangle`, `insert-register`

## `copy-region-as-kill`

- Function / package: editor / 定義: region.l
- 呼び出し: `copy-region-as-kill FROM TO`

```text
リージョンをコピーして、キルリングに追加します。[ESC w]
```

関連: `kill-region`

## `copy-region-to-clipboard`

- Function / package: editor / 定義: region.l
- 呼び出し: `copy-region-to-clipboard FROM TO`

```text
指定されたリージョンをクリップボードにコピーします。

  FROM : リージョンの開始位置を指定します。
  TO   : リージョンの終了位置を指定します。
```

関連: `copy-to-clipboard`

## `copy-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `copy-selection`

```text
選択された領域をコピーして、*selection-ring*の先頭に追加します。 [F8]
追加した内容はyank-selectionで貼り付けられます。
```

関連: `yank-selection`, `kill-selection`

## `copy-selection-to-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `copy-selection-to-clipboard`

```text
選択範囲をクリップボードに転送します。[C-Insert]

使用例：
  ;;; 1. いったんJISに変換して保存
  ;;; 2. [ファイル]-[開く]で文字エンコーディングを[シフトJIS]にして開く
  ;;;    （またはメモ帳などで開く？）
  ;;; 3. 選択してコピー
  (defun tojiscopy ()
    (interactive)
    (let ((ocode *kanji-expected-code*)
          (tempfile (concat (default-directory) "tempfile.txt")))
      (save-excursion
        (set-buffer-kanji-fileio-code 1)
        (write-region (point-min) (point-max) tempfile nil)
        (switch-to-buffer "*JIS*"))
      (pop-to-buffer "*JIS*")
      (setq *kanji-expected-code* 0)
      (find-file tempfile)
      (setq *kanji-expected-code* ocode)
      (selection-whole-buffer)
      (copy-selection-to-clipboard)))
```

関連: `copy-to-clipboard`

## `copy-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `copy-to-register R START END &optional DELETE`

```text
START と END で指定されるリージョンをレジスタ R へコピーします。[C-x r s]
DELETE が non-nil ならば同時にリージョンをを削除します。

コピーしたテキストの yank には、 insert-register を使います。
```

関連: `insert-register`, `append-to-register`

## `delete-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `delete-rectangle P1 P2`

```text
P1 と P2 で指定される矩形領域を削除します。
```

関連: `kill-rectangle`, `delete-rectangle-selection`, `operate-on-rectangle`

## `delete-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `delete-rectangle-selection`

```text
矩形選択されたセレクションの領域を削除します。
```

関連: `kill-rectangle-selection`, `delete-rectangle`, `operate-on-rectangle-selection`

## `delete-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `delete-region FROM TO`

```text
指定された範囲を削除します。
```

## `downcase-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `downcase-region FROM TO`

```text
リージョン内の単語を小文字にします。[C-x C-l]
```

関連: `downcase-word`, `capitalize-region`, `upcase-region`

## `fill-region`

- Function / package: editor / 定義: fill.l
- 呼び出し: `fill-region FROM TO`

```text
リージョン内の各段落に対し、詰め込みを行います。

使用例:
  ;;; バッファ全体を詰め込み
  (fill-region (point-min) (point-max))
```

関連: `fill-paragraph`, `fill-region-as-paragraph`, `fill-column`

## `fill-region-as-paragraph`

- Function / package: editor / 定義: fill.l
- 呼び出し: `fill-region-as-paragraph FROM TO`

```text
リージョンを 1 つの段落として詰め込みます。
詰め込み桁数は、変数 fill-column が参照されます。
```

関連: `fill-paragraph`, `fill-region`, `fill-column`

## `fill-region-hook`

- Variable / package: editor

```text
fill-region/fill-paragraphの最後で実行されます。
```

関連: `auto-fill-hook`

## `hide-restricted-region`

- Variable / package: editor

```text
narrow-to-regionした領域を非表示にするか薄く表示するかを制御します。

  t   : 非表示にします。
  nil : 薄く表示します。
```

関連: `narrow-to-region`

## `indent-region`

- Function / package: editor / 定義: lispmode.l
- 呼び出し: `indent-region FROM TO`

```text
mode-specific-indent-commandがnon-nilならば、指定のリージョンを
mode-specific-indent-commandで一行ずつインデントします。
行末はdelete-trailing-spacesで空白を削除されます。
```

## `insert-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `insert-register R`

```text
レジスタ R の内容をバッファに挿入します。[C-x r i], [C-x r g]
R にテキストまたは矩形領域が入っていないとエラーになります。
```

関連: `copy-to-register`

## `kill-line`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `kill-line &optional LINES`

```text
行をkillします。 killした行は *kill-ring* へ追加されます。 [C-k]
連続して kill-line を実行することで、複数行を一括して
*kill-ring* へ追加することができます。

  LINES 
     nil  : ポイントが行末ならば、その位置の改行コードをkillします。
            ポイントが行末でなければ、その行の行末までkillします。
       0  : ポイントが行頭ならば、前行の行頭までkillします。
            ポイントが行頭でなければ、その行の行頭までkillします。
     その他の整数 : 指定された行数 kill します。
```

関連: `*kill-ring*`, `kill-region`

## `kill-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `kill-paragraph &optional (ARG 1)`

```text
現在のパラグラフの最後までkillします。
```

関連: `kill-region`, `backward-kill-paragraph`

## `kill-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `kill-rectangle P1 P2`

```text
P1とP2で指定される矩形領域をkillします。
killした矩形領域のyankには、yank-rectangleを使います。
通常の*kill-ring*とは別の領域に格納されているようです。
```

関連: `delete-rectangle`, `kill-region`, `kill-rectangle-selection`, `*rectangle-kill-buffer*`

## `kill-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `kill-rectangle-selection`

```text
マウスで矩形選択されたセレクションの領域をkillします。
yankにはyank-rectangle-selectionを使いますが、yank-rectangleでも行けそうです。
killした内容は*kill-ring*ともクリップボードとも違う領域に格納されているようです。
```

関連: `copy-rectangle-selection`, `kill-rectangle`, `operate-on-rectangle-selection`

## `kill-rectangle-selection-to-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `kill-rectangle-selection-to-clipboard`

```text
マウスで矩形選択されたセレクションの領域を削除した後、クリップボードにコ
ピーします。
```

関連: `kill-rectangle-selection`, `copy-rectangle-selection-to-clipboard`

## `kill-region`

- Function / package: editor / 定義: region.l
- 呼び出し: `kill-region FROM TO`

```text
リージョンをkill ringに入れます。 [C-w]

--- kill ringのいい加減な説明 ---
kill-regionした文字列は、*kill-ring*の先頭に追加されます。*kill-ring*は
最大で*kill-ring-max*（標準で16）まで保持できます。最大を越えたら古いも
のから破棄されます。

        *kill-ring*
        ┌─────┐  ─┐
        │"defun"   ←─── kill-regionした内容
        ├──↓──┤    │
        │"length"  │    │
        ├──↓──┤    ├最大*kill-ring-max*個
        │"test"    │    │
        ├──↓──┤    │
        │...       │    │
        └─────┘  ─┘

普通はkill[C-k]してyank[C-y]したら、*kill-ring*の先頭のものしか貼り付け
られませんが、killした直後にyank-pop[M-y]を繰り返すと、*kill-ring*の要素
を順次貼り付けてくれます。
```

関連: `copy-region-as-kill`, `kill-selection`, `zap-to-char`

## `kill-region-to-clipboard`

- Function / package: editor / 定義: region.l
- 呼び出し: `kill-region-to-clipboard FROM TO`

```text
FROMとTOで指定される領域を削除したのち、クリップボードにコピーします。
```

関連: `kill-rectangle-selection-to-clipboard`, `kill-region`

## `kill-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `kill-selection`

```text
選択された領域を切り取り、*selection-ring*の先頭に追加します。 [F7]
追加した内容はyank-selectionで貼り付けられます。
```

関連: `yank-selection`, `copy-selection`

## `kill-selection-to-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `kill-selection-to-clipboard`

```text
セレクションを削除し、クリップボードに転送します。[C-Delete]
矩形選択状態であれば、 kill-rectangle-selection-to-clipboard
を実行します。
```

関連: `kill-region-to-clipboard`, `kill-rectangle-selection-to-clipboard`

## `kill-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `kill-word &optional (ARG 1)`

```text
カーソル位置から前方の単語の末尾までを切り取り、キルリングに追加します。
[ESC d] または [ESC h]
カーソルが単語の途中にある場合は、カーソル位置からその単語の末尾までが、
対象となります。
```

関連: `backward-kill-word`, `kill-region`, `forward-word`

## `mark-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `mark-paragraph`

```text
段落の末尾にマークを、先頭にポイントを設定します。[ESC h]
```

## `mark-whole-buffer`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `mark-whole-buffer &optional ARG`

```text
バッファ全体をリージョンにします。

ARG が
  nil ならバッファの末尾にマークを設定し、バッファの先頭に移動
  non-nil ならバッファの先頭にマークを設定し、バッファの末尾に移動
```

## `mark-word`

- Function / package: editor / 定義: cmds.l
- 呼び出し: `mark-word &optional (ARG 1)`

```text
カーソル位置前方の単語の末尾にマークを設定します。[ESC @]
カーソルが単語の途中にある場合は、その単語の末尾にマークを設定します。
```

関連: `set-mark-command`, `forward-word`

## `open-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `open-rectangle P1 P2`

```text
P1 と P2 で指定される矩形領域に #\SPC を挿入します。
```

関連: `clear-rectangle`, `open-rectangle-selection`, `operate-on-rectangle`

## `open-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `open-rectangle-selection`

```text
矩形選択されたセレクションの領域に #\SPC を挿入します。
```

関連: `clear-rectangle-selection`, `open-rectangle`, `operate-on-rectangle-selection`

## `operate-on-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `operate-on-rectangle P1 P2 C1 C2 &key :copy :delete :clear :open :string`

```text
P1 と P2 で指定されるリージョン中の、 C1 と C2 で定まる矩形領域に対し
てキーワードで指定された操作を行います。

  :copy     コピーする
  :delete   削除する
  :clear    #\SPC で上書き
  :open     #\SPC を挿入
  :string   削除して各行に STRING を挿入

C1, C2 には nil を指定することもできます。この場合、リージョンの開始位
置と終了位置の表示桁が使われます。

-rectangle 系のコマンドの多くはこれを用いて実装されています。


矩形についての補足：
  例えば次の図で / がリージョンの場合 * の部分が操作の対象となります。
         C1             C2                     C1             C2
  -------│-------------│--------      -------│-------------│--------
  -------│------/////////////////      -------│------*******│--------
  ////////////////////////////////      -------│*************│--------
  ////////////////////////////////      -------│*************│--------
  ////////////////////////////////      -------│*************│--------
  /////////////////////////-------      -------│*************│--------
  -------│-------------│--------      -------│-------------│--------
  
  C1, C2 を明示的に指定することはあまりなく、次のいずれかの形になる場合がほとんどでしょう。
  --------------------      --------------------
  ------------////////      ------********//////
  /////*******////////      //////********//////
  /////*******////////      //////********//////
  /////*******////////      //////********//////
  /////*******////////      //////********//////
  /////---------------      //////********------
  --------------------      --------------------
```

関連: `operate-on-rectangle-selection`

## `operate-on-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `operate-on-rectangle-selection &key :copy :delete :clear :open :string`

```text
矩形選択されたセレクションの領域に対してキーワードで指定された操作を行
います。

  :copy     コピーする
  :delete   削除する
  :clear    #\SPC で上書き
  :open     #\SPC を挿入
  :string   削除して各行に STRING を挿入
```

関連: `operate-on-rectangle`, `copy-rectangle-selection`, `kill-rectangle-selection`, `delete-rectangle-selection`, `clear-rectangle-selection`, `open-rectangle-selection`, `string-rectangle-selection`, `*dont-clear-selection*`

## `overwrite-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `overwrite-rectangle`

```text
コピーしている矩形を貼り付けます。既存のテキストに上書きされます。
```

## `paste-from-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `paste-from-clipboard`

```text
クリップボードの内容を貼り付けます。[S-Insert]
```

関連: `paste-rectangle-from-clipboard`, `si:*paste-hook*`

## `paste-rectangle-from-clipboard`

- Function / package: editor / 定義: select.l
- 呼び出し: `paste-rectangle-from-clipboard`

```text
paste-from-clipboardとは異なり、クリップボードの内容を矩形で貼り付けます。
[S-C-Insert]
```

関連: `paste-from-clipboard`

## `prepend-to-register`

- Function / package: editor / 定義: register.l
- 呼び出し: `prepend-to-register R START END &optional DELETE`

```text
START と END で指定されるリージョンを、レジスタ R に格納されているテキ
ストの先頭へ追加します。
R にテキストが入っていないとエラーになります。
DELETE が non-nil ならば同時にリージョンをを削除します。
```

関連: `append-to-register`

## `quote-region`

- Function / package: editor / 定義: region.l
- 呼び出し: `quote-region FROM TO`

```text
指定されたリージョンの先頭に引用を表す接頭子を挿入します。
引用を表す接頭子として *quotation-prefix* を挿入します。
```

関連: `*quotation-prefix*`

## `quoted-printable-decode-region`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `quoted-printable-decode-region FROM TO`

```text
リージョンをQuoted-Printableデコードします。
```

関連: `si:quoted-printable-decode`, `quoted-printable-decode-region-to-file`

## `quoted-printable-decode-region-to-file`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `quoted-printable-decode-region-to-file FILENAME FROM TO`

```text
リージョンをQuoted-Printableデコードしてファイルに保存します。
```

関連: `si:quoted-printable-decode`, `quoted-printable-decode-region`

## `reverse-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `reverse-region FROM TO &optional TEMPORARY`

```text
リージョンを反転表示します。
TEMPORARYがnon nilならば、次のキー入力で反転表示が元に戻ります。
```

関連: `clear-reverse-region`

## `selection-backward-char`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-backward-char &optional (ARG 1)`

```text
後方の文字までをセレクションにします。[S-Left]
```

## `selection-backward-word`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-backward-word &optional (ARG 1)`

```text
後方の単語までをセレクションにします。[S-C-Left]
```

関連: `selection-forward-word`

## `selection-beginning-of-buffer`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-beginning-of-buffer`

```text
カーソル位置からバッファの先頭までをセレクションにします。
beginning-of-bufferと違いマーク自体は変化しません。
```

関連: `beginning-of-buffer`, `selection-end-of-buffer`

## `selection-beginning-of-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-beginning-of-line`

```text
行頭までをセレクションにします。
```

関連: `beginning-of-line`, `selection-end-of-line`

## `selection-beginning-of-virtual-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-beginning-of-virtual-line`

```text
表示行の先頭までをセレクションにします。
```

関連: `beginning-of-virtual-line`, `selection-end-of-virtual-line`

## `selection-end-of-buffer`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-end-of-buffer`

```text
バッファの最後までをセレクションにします。
end-of-bufferと違いマーク自体は変化しません。
```

関連: `end-of-buffer`, `selection-beginning-of-buffer`

## `selection-end-of-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-end-of-line`

```text
行末までをセレクションにします。
```

関連: `selection-beginning-of-line`, `end-of-line`

## `selection-end-of-virtual-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-end-of-virtual-line`

```text
表示行の末尾までをセレクションにします。
```

関連: `end-of-virtual-line`, `selection-beginning-of-virtual-line`

## `selection-forward-char`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-forward-char &optional (ARG 1)`

```text
前方の文字までをセレクションにします。[S-Right]
```

## `selection-forward-word`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-forward-word &optional (ARG 1)`

```text
前方の単語までをセレクションにします。[S-C-Right]
```

関連: `selection-backward-word`

## `selection-next-page`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-next-page &optional (ARG 1)`

```text
次ページまでをセレクションにします。[S-PageDown]
```

関連: `selection-previous-page`

## `selection-next-virtual-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-next-virtual-line &optional (ARG 1)`

```text
次の表示行までをセレクションにします。[S-Down]
```

## `selection-paragraph`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `selection-paragraph`

```text
段落をセレクションにします。
```

## `selection-previous-page`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-previous-page &optional (ARG 1)`

```text
前ページまでをセレクションにします。[S-PageUp]
```

関連: `selection-next-page`

## `selection-previous-virtual-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-previous-virtual-line &optional (ARG 1)`

```text
前の表示行までをセレクションにします。[S-Up]
```

## `selection-start-end`

- Macro / package: editor / 定義: select.l
- 呼び出し: `selection-start-end (START END) &body BODY`

```text
セレクションの開始位置、終了位置を取得します。
セレクションが存在すれば、
局所的にSTARTに開始位置、ENDに終了位置をセットされた環境を作り
BODYを順次評価します。

使用例:
  ;;; セレクションに含まれる文字列を返します。
  (selection-start-end (start end)
    (buffer-substring start end))
  =>"foo"
```

関連: `ed::get-selection-start-end`

## `selection-whole-buffer`

- Function / package: editor / 定義: select.l
- 呼び出し: `selection-whole-buffer`

```text
バッファ全体をセレクションにします。
```

## `shift-region`

- Function / package: editor / 定義: region.l
- 呼び出し: `shift-region START END &optional (COLUMN (TAB-COLUMNS (SELECTED-BUFFER)))`

```text
STARTとENDがある行の範囲をCOLUMN桁だけインデントします。
```

関連: `unshift-region`

## `start-selection`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `start-selection TYPE &optional TEMPORARY POINT`

```text
選択領域の範囲指定を開始します。

  TYPE：選択領域の範囲指定の方法を指定します。 
        1の場合         範囲選択を行で行います。
        2の場合         範囲選択を文字で行います。
        3の場合         範囲選択を矩形で行います。

  TEMPORARY：一時的なものかどうかを指定します。
        tの場合         キー入力されると範囲指定を解除します。
        nilの場合       カーソル移動に応じて範囲を変更します。

使用例：
  ;;; 矩形で範囲指定する。
  (start-selection 3 nil)
  => t
```

関連: `stop-selection`, `get-selection-type`, `set-selection-type`, `fix-selection-point`, `pre-selection-p`

## `start-selection-as-line`

- Function / package: editor / 定義: select.l
- 呼び出し: `start-selection-as-line`

```text
行選択モードを開始します。[F6]
セレクションが存在する場合は、セレクションを解除します。
```

関連: `start-selection-as-region`

## `start-selection-as-region`

- Function / package: editor / 定義: select.l
- 呼び出し: `start-selection-as-region`

```text
文字選択モードを開始します。[S-F6]
文字選択モードが開始されている場合は、矩形選択モードに切替えます。
矩形選択モードが開始されている場合は、文字選択モードに切替えます。
行選択モードが開始されている場合は、選択モードを解除します。
```

関連: `start-selection-as-line`

## `string-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `string-rectangle P1 P2 STRING`

```text
P1 と P2 で指定される矩形領域の各行を文字列 STRING で置き換えます。
```

関連: `string-rectangle-selection`, `operate-on-rectangle`

## `string-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `string-rectangle-selection STRING`

```text
矩形選択されたセレクションの各行を文字列 STRING で置き換えます。
```

関連: `string-rectangle`, `operate-on-rectangle-selection`

## `transpose-paragraphs`

- Function / package: editor / 定義: paragrph.l
- 呼び出し: `transpose-paragraphs &optional (ARG 1)`

```text
段落を次の段落と交換します。
```

関連: `transpose-region`

## `unshift-region`

- Function / package: editor / 定義: region.l
- 呼び出し: `unshift-region START END &optional (COLUMN (TAB-COLUMNS (SELECTED-BUFFER)))`

```text
STARTとENDがある行の範囲をCOLUMN桁だけインデントを戻します。
```

関連: `shift-region`

## `upcase-region`

- Function / package: editor / 定義: builtin.l
- 呼び出し: `upcase-region FROM TO`

```text
リージョン内の単語を大文字にします。[C-x C-u]
```

関連: `upcase-word`, `capitalize-region`, `downcase-region`

## `uudecode-region`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `uudecode-region FROM TO`

```text
リージョンをuudecodeします。
```

関連: `si:uudecode`, `uudecode-region-to-file`

## `uudecode-region-to-file`

- Function / package: editor / 定義: encdec.l
- 呼び出し: `uudecode-region-to-file FILENAME FROM TO`

```text
リージョンをuudecodeしてファイルに保存します。
```

関連: `si:uudecode`, `uudecode-region`

## `yank`

- Function / package: editor / 定義: region.l
- 呼び出し: `yank &optional PREFIX (ARG 0)`

```text
*kill-ring*の先頭の要素を挿入します。[C-y]
```

関連: `*kill-ring*`, `yank-pop`, `yank-rectangle`

## `yank-and-pop`

- Function / package: editor / 定義: region.l
- 呼び出し: `yank-and-pop &optional PREFIX (ARG 0)`

```text
*kill-ring*の先頭の要素をyankした後に、先頭の要素を*kill-ring*からpopします。
*kill-ring*は一要素分短くなります。
```

関連: `yank-pop`

## `yank-pop`

- Function / package: editor / 定義: region.l
- 呼び出し: `yank-pop &optional (ARG 1)`

```text
次の要素をyankします。 [ESC y]
直前のコマンドがyankならば*kill-ring*のポインターをずらして、次の要素
でyankをし直します。
```

関連: `yank`

## `yank-rectangle`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `yank-rectangle`

```text
copy-rectangleやkill-rectangleによって選択された領域を矩形挿入します。
yank-rectangle-selectionのInsert相当の機能のようです。
```

関連: `kill-rectangle`, `yank-rectangle-selection`, `yank-rectangle-as-region`

## `yank-rectangle-as-region`

- Function / package: editor / 定義: rectangl.l
- 呼び出し: `yank-rectangle-as-region`

```text
copy-rectangleで切り取った矩形領域を、
連続した一連の文字列として挿入します。

  ABCDEFG ;
  HIJKLMN ; JKL
  OPQRSTU ; QRS
  VWXYZ   ; XYZの領域をcopy-rectangle

  (yank-rectangle)
  =>JKL
    QRS
    XYZ

  (yank-rectangle-as-region)
  =>JKLQRSXYZ
```

関連: `yank-rectangle`

## `yank-rectangle-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `yank-rectangle-selection &optional ARG`

```text
マウスで矩形選択されたセレクションの領域をyankします。[S-F9]
実行後にどのようにyankするかを質問されます。
  F6    Cancel                  yank中止
  F7    Append                  行末に追加
  F8    Overwrite               上書き
  F9    Insert                  挿入
  F10   Insert as region        文字列にして挿入
```

関連: `yank-rectangle`, `kill-rectangle-selection`

## `yank-selection`

- Function / package: editor / 定義: select.l
- 呼び出し: `yank-selection &optional (ARG 0)`

```text
*selection-ring*の先頭の要素を貼り付けます。[F9]
*selection-ring*へはcopy-selectionもしくはkill-selectionで追加します。
```

関連: `kill-selection`, `copy-selection`

## `yank-selection-and-pop`

- Function / package: editor / 定義: select.l
- 呼び出し: `yank-selection-and-pop &optional (ARG 0)`

```text
*selection-ring*の先頭の要素をyank-selectionした後に、
先頭の要素を*selection-ring*からpopします。
*selection-ring*は一要素分短くなります。
```

関連: `yank-selection`

## `yank-to-clipboard`

- Function / package: editor / 定義: region.l
- 呼び出し: `yank-to-clipboard &optional (ARG 1)`

```text
*kill-ring*の内容をクリップボードに複写します。
```

関連: `copy-to-clipboard`
