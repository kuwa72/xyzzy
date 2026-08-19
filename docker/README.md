# Docker でのローカル確認環境

Windows マシンや MSVC を用意せずに、手元でビルドとユニットテストを回すための環境です。
2 種類あります。

| 環境 | 中身 | 使いどころ |
|---|---|---|
| `linux` | gcc + libncursesw で ncurses フロントエンドをネイティブビルド | 速い。Lisp・エディタコア・バイトコンパイルの確認 |
| `wine` | mingw-w64 で Windows 実行ファイルをクロスビルドし、Wine で実行 | CI (MSVC) に近い確認。Win32 依存コードやテストの再現 |

## 使い方

```bash
docker/dev.sh linux all          # ビルド → バイトコンパイル → テスト
docker/dev.sh wine all           # 同じことを mingw + Wine で
docker/dev.sh wine test          # テストだけ
docker/dev.sh wine build         # ビルドだけ
docker/dev.sh linux shell        # コンテナに入って手で叩く
docker/dev.sh image wine         # イメージを作り直す (Dockerfile を触ったとき)
```

`action` は `configure` / `build` / `bytecompile` / `test` / `run` / `clean` / `all`。
複数並べれば順に走ります (`docker/dev.sh wine build test`)。

### 環境変数

| 変数 | 意味 |
|---|---|
| `XYZZY_ARCH` | `wine` 環境のターゲット。`x86_64` (既定) または `i686` |
| `JOBS` | 並列ビルド数 (既定はコンテナの `nproc`) |
| `XYZZY_TEST_EXCLUDE` | 除外するテスト名をカンマ区切りで。`misc/run-tests-batch.l` 参照 |
| `DISPLAY` | GUI を出すときのディスプレイ。WSLg なら既定の `:0` でそのまま映る |

```bash
XYZZY_ARCH=i686 docker/dev.sh wine all       # 32-bit で確認
XYZZY_TEST_EXCLUDE=foo-test docker/dev.sh wine test
```

### エディタを起動する

```bash
docker/dev.sh linux run    # ncurses 版がその端末で起動する
docker/dev.sh wine run     # Wine で GUI 版。WSLg 経由で Windows のデスクトップに出る
```

## 仕組みと注意点

- ビルドディレクトリは `build-docker/linux`, `build-docker/wine-<arch>`。
  ホストの `build/` とは別なので、Windows 側のビルドと混ざりません。
- コンテナはホストの UID/GID で動くので、生成物が root 所有になりません。
- `lisp/*.lc` と `src/core/gen/` はソースツリーに出ます (どちらも .gitignore 済み)。
  Windows 側のビルドと共用なので、混ざると困るときは `bytecompile` をやり直してください。
- `grammars/*.dll` は**コミット済みのファイル**で、`wine` 環境のビルドは
  これを mingw ビルド版で上書きします。気づけるようスクリプトが警告するので、
  戻すときは `git checkout -- grammars` を。
- `wine` 環境の Wine プレフィックスは `build-docker/wineprefix` です。おかしくなったら
  丸ごと削除すれば作り直されます。
- クロスビルドでは、ビルド中に走るコードジェネレータ (`gen-src1` / `gen-src2`) も
  Windows 実行ファイルになります。`docker/mingw-toolchain.cmake` が
  `CMAKE_CROSSCOMPILING_EMULATOR=wine` を設定して、それを Wine 経由で実行します。
- Wine 上では既知の不具合が出ます (`fix-ole-event-sink-load-typelib` の use-after-free など)。
  `misc/run-tests-batch.l` の既定の除外リストに入っています。
