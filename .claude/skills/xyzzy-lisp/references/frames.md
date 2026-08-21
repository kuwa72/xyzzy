# フレーム (frames)

reference/reference.xml から自動生成。3 エントリ。
編集しないこと — 直すなら reference/reference.xml を直して再生成する。

## `*pseudo-frame-bar-context-menu*`

- Variable / package: editor / 定義: pframe.l

```text
フレーム・バー上で右クリックしたときに出てくるコンテキストメニューです。
define-popup-menu で作成されています。（作成は app-menu.l）

補足：
  xyzzy 0.2.2.250 から利用可能です。
```

## `*pseudo-frame-bar-context-menu-frame*`

- Variable / package: editor / 定義: pframe.l

```text
フレーム・バー上で選択されているフレームです。ただし、フレームバー上の
コンテキストメニューで取得専用くらいしか使用できません。

補足：
  xyzzy 0.2.2.250 から利用可能です。
```

## `*pseudo-frame-bar-context-menu-handler*`

- Variable / package: editor / 定義: pframe.l

```text
デフォルトのフレーム・バー用コンテキストメニューハンドラです。
標準の動作は *pseudo-frame-bar-context-menu-buffer* を定義し、
*pseudo-frame-bar-context-menu* を返します。

補足：
  xyzzy 0.2.2.250 から利用可能です。
```

関連: `*pseudo-frame-bar-context-menu*`
