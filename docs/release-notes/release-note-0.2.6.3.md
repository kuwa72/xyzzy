xyzzy リリースノート
====================

  * バージョン: 0.2.6.3
  * リリース日: 2026-03-29
  * ホームページ: <https://github.com/snmsts/xyzzy>


インストール
------------

今回からインストーラ (.exe) も用意してみた。スタートメニューとかアンインストーラとか
PATHの追加とか右クリックの「Open with xyzzy」とか、そういうのを自動でやってくれる。
ただし署名していないので、Windows 11 のスマートアプリコントロールにブロックされる
場合がある。そのときは zip 版をどうぞ。



機能追加
--------

  * いろいろな言語の編集モードを追加した。regexp-keyword ベースの簡易的なもの。
    - json-mode, yaml-mode, python-mode, shell-script-mode
    - javascript-mode, typescript-mode
    - xml-mode, toml-mode, makefile-mode, cmake-mode, dockerfile-mode

  * markdown-mode を追加した。見出し移動、スタイルのトグル、リスト継続、リンクフォローなど。

  * outline-tree2 プラグインを同梱した (OHKUBO Hiroshi 氏作, BSD license)。lisp/wip/ に置いてある。まだ動かない気がする。

  * shebang でモードを自動判定するようにした (*interpreter-mode-alist*)。

  * macOS/Linux 向けにコードジェネレータを移植した。ncurses フロントエンドも cmake でビルドできるようにした。


バグ修正
--------

  * MSVC でビルドすると ComCtl32 v6 のマニフェストが効かなくて Windows 95 風のコントロールになっていたのを修正。リンカが勝手にマニフェストを生成して上書きしていたらしい。

  * 新しい MSVC で sha2.cc がビルドできなくなっていたのを修正。システムヘッダに htobe32 とかが追加されて重複定義になっていた。

  * TreeView で Unicode テキストが化けていたのを修正。

  * Clang 14 ARM64 で make_integer(long long) が無限ループするのを修正。

  * ncurses のクラッシュハンドラを改善した。altstack, SA_SIGINFO, SIGBUS に対応。

  * gc_mark_object を再帰から反復に変更した。深いオブジェクトグラフでスタックオーバーフローしていた。

  * check_stack_depth が実際のスタック境界を見るようにした (POSIX)。


その他
------

  * niftylog と den8view モードを削除した。
  * auto-mode-alist から .doc を削除した。


