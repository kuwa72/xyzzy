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

  * README とリポジトリの概要が、この木を上流そのもののように見せていたのを直した。
    バッジとダウンロードのリンクが snmsts/xyzzy を指したままで、GitHub の説明文は
    xyzzy-022 のものが残っていた。私家版であること、どこから分岐した木なのか、
    不具合の報告先がここであって上流ではないことを先頭に書いてある。
  * ドキュメントを利用者向け (docs/user/)・開発者向け (docs/dev/)・リリースノート
    (docs/release-notes/) に分けた。README がビルド手順やバージョン体系の詳細まで
    抱えていて「導入とポインタ」になっていなかったのと、機能一覧・キーバインド・
    設定 (GUIダイアログと ini/.xyzzy.history/~/.xyzzy の3層構造)・Lisp拡張の
    書き方がどこにも無かったのを直した。あわせてリリースの ZIP/インストーラに
    docs/dev/ (設計メモ、上流の古い ChangeLog) やリリースノート本体がそのまま
    入ってしまっていたのもやめ、docs/user/ だけを配布物に入れるように
    CMakeLists.txt の install() を変えた。リリースノート自体も docs/ 直下から
    docs/release-notes/ へ移し、それに合わせて `.githooks/pre-push`、
    `.github/workflows/release.yml`、`tools/release-prep.sh`、`RELEASING.md`、
    `CLAUDE.md` が参照するパスを一括で更新した (ファイル名は変えていないので
    `release-note-<版>.md` という命名はそのまま)。
  *
