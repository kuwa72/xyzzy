開発者向けドキュメント
======================

このディレクトリはリリースの ZIP / インストーラには入りません。ビルドする側・
コードを直す側の情報です。利用者向けの情報は [docs/user/](../user/index.md) に
あります。

  * [ビルド方法](building.md) — llvm-mingw クロスビルド、MSVC、Linux ncurses
  * [../../CLAUDE.md](../../CLAUDE.md) — このフォークで作業する前提、CI/hook が
    何を止めてくれるか
  * [../../RELEASING.md](../../RELEASING.md) — リリースの出し方
  * [../release-notes/](../release-notes/release-note-next.md) — リリースノート。
    変更を入れる PR では `release-note-next.md` に1行足す ([CLAUDE.md](../../CLAUDE.md) 参照)
  * [plans/](plans/) — 大きめの変更の設計メモ
  * [old/](old/) — 上流由来の古い ChangeLog (歴史的記録)
  * [cp932-cleanup.md](cp932-cleanup.md), [manual-check-cp932.md](manual-check-cp932.md)
    — 文字コード周りの作業メモ
