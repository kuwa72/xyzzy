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

  * `lisp/foreign.l` の `size_t`/`time_t`/`ptrdiff_t`/`void*` のポインタ幅
    判定を、コンパイルした exe 自身の `*features*` を読み取り時に見る
    `#+:64bit`/`#-:64bit` から、ロードした側の `*features*` を見る実行時
    分岐に変えた。これにより byte compile 済みの `.lc` は i686/x86_64 間
    で真にポータブルになり、`tools/bytecompile.sh`/`tools/run-tests.sh` が
    アーキごとに `.lc` を全消し再コンパイルしていたスタンプ機構
    (`lisp/.bytecompile-arch`) が不要になったため削除した。
  * `tools/bytecompile.sh` が `lisp/*.l` を編集しても `--force` を付け
    忘れると `.lc` を再コンパイルしない (アーキスタンプが一致していると
    ファイルの鮮度を見ずに即終了していた) 問題を修正した。
    `misc/bytecompile-batch.l` が `force-recompile` を常に `t` で呼んで
    いたため、`misc/makelc.l` にすでにあった `.l`/`.lc` の mtime 比較が
    死んでいたのが原因。新しく `tools/lc-stale.sh` に切り出した鮮度判定
    を `tools/bytecompile.sh` の事前チェックとして使い、変更の無い
    ファイルは再コンパイルせず、変更したものだけ拾うようにした。
    `tools/run-tests.sh` も同じ鮮度判定で `.lc` が古いままテストを走らせ
    ないようにガードし、宣言だけで未実装だった `--bytecompile` オプション
    を実際に配線した。
  * `tools/x` の Docker 開発環境に `ccache` を導入し、`configure` に
    `CMAKE_C_COMPILER_LAUNCHER`/`CMAKE_CXX_COMPILER_LAUNCHER` を渡す
    ようにした。`_build/$ARCH` はチェックアウトごとの生成物で
    `git worktree` の兄弟間で共有できないため、比較用に別コミットを
    並行ビルドしようとすると毎回フルビルドになり2分以上かかっていた。
    ccache はソースの内容とコンパイラフラグでキャッシュキーを決めるので
    worktree の場所やコミットに関係なく再利用でき、実測でも2回目の
    ビルドが2分26秒から13秒に短縮された。合わせて `tools/x` が
    `git worktree add` した兄弟チェックアウトを個別に
    `/siblings/<ディレクトリ名>` としてコンテナ内にマウントするように
    した (単一チェックアウトのみの場合は何も変わらない)。
