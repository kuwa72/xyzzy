# xyzzy project instructions

## Issue workflow

Issue に着手するときは、次の順序を必ず守る。

1. `topic/*` ブランチを `main` から作る。
2. TDD で実装する。まず再現テストまたは失敗する回帰テストを書き、失敗を確認してから実装し、同じテストが通ることを確認する。
3. 変更内容と理由を `docs/release-notes/release-note-next.md` に追記する。
4. ローカルのビルドとテストを実行する。xyzzy のテストは `tools/x test <ARCH> --bytecompile` を使い、既知失敗を勝手に変更しない。
5. base を `main` にして PR を作成する。
6. PR 作成後は `tools/ci-wait.sh <PR番号>` をバックグラウンドで実行し、全 CI が終了するまで待つ。`gh pr checks` や `gh run watch` を手で繰り返さない。
7. required check を含む CI がすべて pass したことを確認してから PR をマージする。
8. マージ後に issue が closed になったことと、マージコミットを確認する。

PR を作成して終わりにせず、CI 終了確認・マージ・issue クローズ確認までを issue 対応の完了条件とする。

## Repository rules

- 作業ブランチは `topic/*`、PR の base は常に `main`。
- 変更時はリリースノートを必ず更新する。
- `grammars/**/*.dll` はビルドで変更されてもコミットしない。
- `git add -A` は使わず、変更対象を明示して staging する。
- `misc/known-failures/*.txt` は CI の結果を根拠にせず変更しない。
