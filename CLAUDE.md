CLAUDE.md
=========

xyzzy (kuwa72 フォーク) で作業するときの前提。**ここには機械で強制できないことだけ
書く。** 強制できるものは hook と CI にある (下記)。

## すでに機械が止めてくれること

守ろうと意識しなくてよい。破ろうとすると止まる。

| 仕組み | 止めるもの |
| --- | --- |
| `.githooks/pre-commit` | 現在、専用チェックなし（生成DLLは`.gitignore`で除外） |
| `.githooks/pre-push` | `main` への直接 push、`CMakeLists.txt` と一致しないタグ、ノートの無いタグ、`main` 上に無いタグ |
| `.github/workflows/mingw.yml` | 既知失敗以外のテスト失敗 (required check)。毎晩も走る |
| `.github/workflows/build.yml` | 同上を MSVC 3 アーキで。毎週も走る |
| `.github/workflows/release.yml` | バージョン不一致、ノート欠落、`main` 外のタグ、アーキ欠落 |
| `.github/dependabot.yml` | action の放置 (月次、1 PR にまとめて提案) |

定期実行は toolchain の腐り (debian / llvm-mingw / Wine / windows runner / vcpkg)
を、リリースで困る前に見つけるためのもの。**赤いメールが来たらコードではなく足元が
動いたと考える。** public リポジトリは 60 日活動が無いと定期実行が自動停止する。

git hooks は `.git/hooks` が versioned でないため `core.hooksPath` が必要で、
`.claude/settings.json` の SessionStart が `tools/setup-hooks.sh` を毎回走らせて
入れている。**hook が動いていないと思ったら** `git config --get core.hooksPath`
が `.githooks` を返すか見る。

override が要るとき (めったに無い):
`XYZZY_ALLOW_PUSH_MAIN=1` / `XYZZY_SKIP_TAG_CHECK=1`

## 機械が判定できないので守ること

### 変更したら `docs/release-notes/release-note-next.md` に 1 行足す

リリースノートは必須で、無いとリリースが出ない。タグを打つ瞬間にまとめて書くと
辛いので、変更を入れる PR で書き足していく。**何を書くべきかは機械には分からない
ので、これだけは守る必要がある。**

過去のノートは「何を変えたか」だけでなく**なぜそうしたか**を書いてある。それが
自動生成に置き換えていない理由なので、同じ水準で書く。

### known-failures のベースラインは CI の run を根拠にする

`misc/known-failures/*.txt` は既知の失敗リストで、リスト外が落ちたら赤、
**リストに載っているテストが通るようになった場合も赤**になる。

手元の run で出た失敗を安易にリストへ足してはいけない。**`.lc` が無い手元の run は
CI より 2 件多く落ちる** (`image-startup-option`、
`fix-for-FFI-c-function-return-doubl/float-00`)。`tools/x test --bytecompile` を
使っていればこの 2 件は出ないので、**必ず `--bytecompile` を付ける。**
CI で通っているものを既知失敗に登録すると、その瞬間から CI が赤くなる。

**「手元だけ落ちる」と決めつける前に、flaky を疑う。** `uuid-create-4-seq` は
長く「ローカル固有の差分」として扱われていたが、実際は時刻に依存する flaky で
CI でも落ちていた (PR #71 で修正)。手元で落ちたテストが CI で通っているなら、
同じ CI ジョブを何度か回してみると分かることがある。

根拠にするのは CI の run で、それを見る道具が `tools/ci-wait.sh` (次の節)。

詳細は `misc/known-failures/README.md`。

### PR を出したら `tools/ci-wait.sh` を**バックグラウンドで**走らせる

```
tools/ci-wait.sh          # 今のブランチの PR
tools/ci-wait.sh 124      # 番号を指定
```

全チェックが終わるまで待って、チェック一覧と**テストスイートの数を全ジョブ分**
1 画面に出す (`Total` / `known failures` / `now passing` /
`unexpected failures` の 4 行だけ)。終了コードは 0 = 全部 pass、
1 = 落ちた、2 = 時間切れ。

**バックグラウンドで起動して、待つ間は別の作業を続ける。** 前景で待つと手が
止まるので、つい未マージ PR の上に次のブランチを積んでしまい、マージのたびに
stash と rebase の手戻りが出る。

守ること:

* **`gh pr checks` を手で繰り返さない。** `--watch` があるので待てる。
* **`gh run watch <id>` を使わない。** run 1 つしか見ないので、**他の
  workflow がまだ動いているのに 0 で戻ってくる。** PR には build / linux /
  mingw の 3 workflow がぶら下がる。
* **数字を手で grep しない。** 毎回同じ 4 行を見ているので、ここに固定した。

**テストを走らせているのは 6 ジョブで、7 つではない。** `llvm-mingw aarch64`
はビルドだけ (x86 ホストの Wine で aarch64 の exe は動かせない)。
「7 ジョブ緑」と書くとテスト結果を 7 つ見た意味になるので、そう書かない。

既知失敗のベースラインはアーキごとに違う (MSVC x86 は 8 件、x64 と ARM64 は
10 件)。**1 つのジョブだけ見て「既知失敗 N 件」と書かない。**

### PR を積むなら base は `main` にする

未マージ PR の上に次のブランチを作ってよいが、**PR の base はいつも `main`**
にする。base を前の topic ブランチにすると、その PR を
`gh pr merge --delete-branch` した瞬間に **GitHub が上の PR を閉じ、
`gh pr reopen` は「Could not open」で通らない。** PR を作り直すしかなくなる
(#142 → #144 でやった)。

base が `main` でも、前の PR がマージされるまでは差分に前のコミットが混ざって
見えるだけで、マージ後に自然に消える。**閉じた PR を戻せないことに比べれば
安い。**

### リリースの順序

`tools/release-prep.sh <version>` が bump とノートの改名をやる。順序は
bump → ノート → main へマージ → タグ。**タグを先に打つと pre-push と CI が止める**
ので壊れはしないが、順序を覚えておくと手戻りが無い。詳細は `RELEASING.md`。

## 環境の落とし穴

* **ローカル確認は `tools/x`** (Docker + llvm-mingw + Wine)。
  `tools/x configure x86_64` → `build` → `test`。Windows マシンは要らない。
* **出力ゼロで 100% CPU なら `.wxp` を疑う。** ただし**バイナリを作り直した場合は
  もう起きない** — ヘッダに実行ファイルの大きさと更新時刻が入っているので弾かれる
  (issue #219)。残る形は「**バイナリは同じで `lisp/` を触った**」場合で、これは
  識別子では見分けられない。`run-tests.sh` は自動で消す。
  （**「絶対アドレスを持っている」と書いてあったが誤り**。イメージは `lmap`/`rlmap`
  の添字で書いてあり、関数ポインタも入っていない。だから POSIX へ移植できた。）
* **端末版は既定でダンプイメージを使う** (`<設定ディレクトリ>/xyzzy.wxp`、
  対話起動が 832ms → 178ms)。`lisp/` を触りながら試すときは **`-no-image`** を付ける
  か、そのファイルを消す。**`--batch` は既定オフ**なので、テストと
  `tools/bytecompile.sh` は影響を受けない (イメージは Lisp ライブラリ全体を含むので、
  `.lc` を作り直しても識別子では弾けない)。
* **`grammars/*.dll` はビルド生成物で、`.gitignore` により追跡しない。** リリース時は
  CMakeのinstall対象からパッケージへ入る。
* Lisp の API を調べるときは `.claude/skills/xyzzy-lisp`。

## Issue 対応の完了条件

issue に着手したら、TDD で進める。まず再現テストまたは失敗する回帰テストを書いて
失敗を確認し、実装後に同じテストが通ることを確認する。その後、PR を作成し、
`tools/ci-wait.sh <PR番号>` をバックグラウンドで走らせて全 CI の終了を確認する。
required check がすべて pass したら PR をマージし、issue が closed になったことと
マージコミットを確認する。PR 作成や CI 起動だけでは完了としない。

## ブランチ

トランクは `main` 一本。作業は `topic/*` から PR。`develop` は 2026-08-21 に
`archive/develop` タグへ退避して削除済み。
