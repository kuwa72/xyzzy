リリース手順
============

リリースの時期は決めていません。区切りが付いたと判断したときに出します。
やることは「バージョンを上げる」「ノートを書く」「タグを打つ」の 3 つだけで、
ビルドと公開は CI がやります。

前提として、開発は `main` 一本です。変更は topic ブランチから PR で入れ、
`main` は保護されていて mingw の 3 ジョブが required になっています。


ふだんの運用
------------

**`docs/release-notes/release-note-next.md` に書き足しながら進めます。** 変更を入れる PR で、
その PR が何を変えたのかを 1 行足しておきます。リリースを決めた時点でノートが
だいたい書けている状態になるので、タグを打つ瞬間にまとめて書く必要がなくなります。

ノートは必須です。無いとリリースが出ません (後述)。だから溜めておくのが楽です。


手順
----

### 1. 下準備

```
tools/release-prep.sh 0.3.1
```

これが 3 つの編集をまとめてやります。

  * `CMakeLists.txt` の `project(xyzzy VERSION ...)` を上げる
  * `docs/release-notes/release-note-next.md` を `docs/release-notes/release-note-0.3.1.md` に改名し、
    ヘッダのバージョンと日付を埋める
  * 新しい `docs/release-notes/release-note-next.md` を作る

コミットはしません。作業ツリーに置くので、中身を読んでから進めてください。

版番号の付け方は `docs/release-notes/release-note-0.3.0.md` に書いた通りです。

  * PATCH — バグ修正だけ (0.3.1, 0.3.2 …)
  * MINOR — 機能追加や作り直しが入ったとき (0.4.0)
  * MAJOR — 常用に耐えると判断したら 1.0.0

### 2. ノートを仕上げる

`docs/release-notes/release-note-0.3.1.md` を開いて、溜まった箇条書きに見出しを付けます
(ターミナル / フォント / 文字とファイル / ビルドと配布 / 既知の問題 など)。
過去のノートが手本です。プレースホルダの行は消してください。

**何が変わったかだけでなく、なぜそうしたかを書いてあるのが過去のノートの価値です。**
自動生成に置き換えていないのはそのためです。

### 3. コミットして PR

```
git switch -c topic/release-0.3.1
git commit -am "release: 0.3.1"
git push -u origin topic/release-0.3.1
gh pr create --base main
```

CI が緑になったらマージします。

`main` は保護されているので、通常は直接 push できません。admin は bypass できて
しまいますが、直接 push すると PR の CI を通らないまま入るので、リリースの
コミットは PR 経由にしてください。

### 4. タグを打つ

マージコミットにタグを打って push します。**これが公開の引き金です。**

```
git switch main && git pull
git tag v0.3.1
git push origin v0.3.1
```

あとは CI が 3 アーキをビルドして、ZIP・インストーラ・`SHA256SUMS` を付けた
GitHub Release を作ります。20 分ほどかかります。


順序が大事な理由
----------------

`.github/workflows/release.yml` がタグと木の整合性を検証します。**先にタグを
打つと落ちます。** バージョンを上げてノートを書いて `main` に入れてから、
タグです。

落ちるといっても、検証はビルドの前に独立したジョブで走るので 10 秒で終わります。
20 分待たされることはありません。

さらに `.githooks/pre-push` が**push する前に手元で**同じ検証をします (タグが指す
コミットの `CMakeLists.txt` とノートを見るので、CI と同じものを見ています)。順序を
間違えても、リモートに出る前に止まります。

検証している内容:

| 見ているもの | 落ちる条件 |
| --- | --- |
| タグ ↔ `CMakeLists.txt` | タグの数値部が `project(xyzzy VERSION ...)` と違う |
| リリースノート | `docs/release-notes/release-note-<版>.md` が無い、または空 |
| タグの位置 | `main` 上のコミットを指していない |
| 成果物 | ZIP かインストーラが 3 つ揃っていない |
| テスト | 既知失敗以外が落ちた (`misc/known-failures/`) |

タグが `main` 上にあることを要求しているのは、開発が `main` 一本だからです。配る
価値があるものは既にマージされているはずで、そうでない場所のタグは、required
check を一度も通っていないコミットから配ろうとしていることになります。

`main` 以外から配る必要が本当に出た場合 (古い版への hotfix など) は、手元は
`XYZZY_SKIP_TAG_CHECK=1` で越えられますが、CI 側は越えられません。そのときは
release.yml の該当ステップを一時的に外してください。今の運用では起きない想定です。

タグとバージョンを突き合わせているのは、ZIP の名前が cpack 由来 (`PROJECT_VERSION`)
でインストーラのバージョンがタグ由来なので、食い違うと 1 つのリリースに
`xyzzy-0.3.0-amd64.zip` と `xyzzy-9.9.9-amd64-setup.exe` が並び、しかもバイナリ
自身は 3 つ目の答え (`version.h` = `CMakeLists.txt` 由来) を答えてしまうからです。


プレリリース
------------

タグに接尾辞を付けると `--prerelease` で公開され、「最新」の扱いになりません。

```
cp docs/release-notes/release-note-0.3.1.md docs/release-notes/release-note-0.3.1-rc1.md
# 上を編集してコミット、main へ
git tag v0.3.1-rc1 && git push origin v0.3.1-rc1
```

`CMakeLists.txt` は `0.3.1` のままです。CMake の `project(VERSION ...)` は
数字しか持てないので、接尾辞はタグ側にだけ付けます。検証は数値部だけを
突き合わせます。

接尾辞付きのタグは**それ自身のノートが必要**です (`-rc1` なら
`docs/release-notes/release-note-0.3.1-rc1.md`)。過去の `-preview` / `-pr3` も同じように
別ファイルを持っています。


やり直したいとき
----------------

検証で落ちた場合はリリースが作られていないので、タグを消して直して打ち直します。

```
git push origin :refs/tags/v0.3.1
git tag -d v0.3.1
```

**リリースがすでに公開されてしまった場合は、同じ版を打ち直さないでください。**
誰かがもう落としている可能性があります。次の PATCH に進めるほうが安全です。
どうしても消すなら:

```
gh release delete v0.3.1 --yes
git push origin :refs/tags/v0.3.1
git tag -d v0.3.1
```


既知失敗が増えた / 直った場合
-----------------------------

テストは既知失敗リストで gate してあります。リスト外が落ちたら赤、**リストに
載っているテストが通るようになった場合も赤**です。どちらもリリースを止めます。

直し方は `misc/known-failures/README.md` を参照してください。ベースラインの
根拠は必ず CI の run にします。手元の run は `.lc` の有無で結果が変わります。
