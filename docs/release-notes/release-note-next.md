xyzzy リリースノート
====================

  * バージョン: (未リリース)
  * リリース日: (未リリース)
  * ホームページ: <https://github.com/kuwa72/xyzzy>


このリリースについて
--------------------

(次のリリースで何が変わるのかを、1〜2 段落で。)


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
  *
