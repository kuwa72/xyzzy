xyzzy リリースノート
====================

  * バージョン: (未リリース)
  * リリース日: (未リリース)
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

全角文字と旧 function key の衝突を解消する修正を含む。Lisp の文字
オブジェクトがキーの kind (文字・関数キー・マウス等) を保持するように
なり、全角 U+FF00..U+FF3E の文字が関数キーと誤認されなくなった。
関数キーの動作自体は変わらない。


変更
----

  * ファイラ上で全角文字が `Key not bound` になり、日本語のファイル名へ
    インクリメンタルサーチできなかったのを修正した (issue #430)。
    WM_CHAR の非 ASCII を旧 Char に落とさず文字のまま渡し、filer-keymap に
    登録できない全角文字は印刷可能な ASCII と同じ `filer-isearch` に回す。
  * Windows で Alt+全角文字を打つと、旧 Char の function key 空間
    (U+FF00..U+FF3E) と衝突して存在しない meta function key になっていた
    のを修正した (issue #431)。旧 Char は M- 付きの非 ASCII を表せないので、
    Alt を落として文字として扱う。
  * Lisp の文字オブジェクトが lChar (kind + modifier + code point) を
    保持するようになり、全角 U+FF00..U+FF3E の文字と旧 function key を
    区別できるようにした (issue #431)。`#\？` と `#\F17` は旧 encoding では
    同じ値だったが、別の文字として eq・キー割り当て・表示ができる。
    `char-code` は互換のため従来どおり旧 encoding の値を返す。
    `define-key` で全角文字にキーを割り当てられるようになり、明示的な
    束縛は self-insert より優先される。`set-meta-bit` は全角文字に
    M- を付けても meta function key に化けなくなった。
  *
