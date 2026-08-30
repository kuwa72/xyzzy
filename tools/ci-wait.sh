#!/bin/sh
# tools/ci-wait.sh [PR] -- PR の CI が終わるまで待って、結果を 1 画面にまとめる。
#
# **手で `gh pr checks` を何度も叩くのをやめるための道具。** 想定した使い方は
# 「PR を出したらこれをバックグラウンドで走らせて、別の作業を続ける」:
#
#   tools/ci-wait.sh          # 今のブランチの PR
#   tools/ci-wait.sh 124      # 番号を指定
#
# 終了コード: 0 = 全部 pass / 1 = 落ちたものがある / 2 = 時間切れ
#
# 出すもの:
#   * チェックの一覧 (pass/fail と所要時間)
#   * テストスイートの数 — Total / known failures / now passing /
#     unexpected failures の行だけ
#
# **数を手で grep しない。** 毎回同じ 4 つを見ているので、ここに固定する。
# 「now passing」と「unexpected failures」は既知失敗リストとのずれで、
# 見落とすと CI が赤いまま放置されるので必ず出す。
#
# 待つのは `gh pr checks --watch`。**自前の sleep ループを書かない** (前は
# 手で何度も叩いていて、そのせいで待ち時間に何もしないか、逆に待たずに次へ
# 進んでしまっていた)。
set -eu

pr=${1:-}
if [ -z "$pr" ]; then
  pr=$(gh pr view --json number -q .number 2>/dev/null) || {
    echo "ci-wait: このブランチに PR が無い。番号を渡すか PR を作る。" >&2
    exit 2
  }
fi

# CI は MSVC が一番遅くて 9 分前後。3 つのワークフローが並ぶので 30 分見る。
limit=${CI_WAIT_TIMEOUT:-1800}

echo "ci-wait: PR #$pr のチェックを待つ (最大 ${limit}s)"

# --watch は全部終わるまで戻らない。--fail-fast で最初の失敗で戻る。
# 0 = 全部 pass, 1 = どれか fail, 8 = pending (--watch では来ない)。
set +e
timeout "$limit" gh pr checks "$pr" --watch --fail-fast --interval 20 >/dev/null 2>&1
rc=$?
set -e

if [ "$rc" -eq 124 ]; then
  echo "ci-wait: 時間切れ ($limit s)。今の状態:"
  gh pr checks "$pr" || true
  exit 2
fi

echo
echo "===== チェック ====="
gh pr checks "$pr" || true

echo
echo "===== テストスイート ====="
# チェックの link から run の id を拾う。同じ run に複数のジョブがぶら下がる
# ので重複を落とす。
runs=$(gh pr checks "$pr" --json link -q '.[].link' 2>/dev/null \
       | sed -nE 's|.*/runs/([0-9]+)/.*|\1|p' | sort -u)
if [ -z "$runs" ]; then
  echo "(run が拾えなかった)"
else
  for run in $runs; do
    # ログは大きいので、要る行だけ抜く。ジョブ名は先頭のタブ区切りの 1 列目。
    #
    # **行の頭に錨を打つ。** ログの各行は
    #   ジョブ名 <TAB> ステップ名 <TAB> 2026-08-30T04:49:43.1426570Z 本文
    # なので、`Z ` の直後だけを見る。錨無しで探すと、**PR の本文が CI のログに
    # 出てくる場面 (event payload の JSON) で、そこに書いた出力例が拾われる。**
    # 実際に踏んだ: この道具を紹介する PR の本文に実行例を貼ったら、その例が
    # 3 ジョブ分「テストの結果」として並んだ。
    gh run view "$run" --log 2>/dev/null \
      | grep -aE '[0-9]Z (Total [0-9]+ tests|=== (known failures|now passing|unexpected failures))' \
      | awk -F'\t' '{ job = $1; sub(/^[^ ]*Z /, "", $NF); printf "%-26s %s\n", job, $NF }' \
      | sort -u
  done
fi

echo
case "$rc" in
  0) echo "ci-wait: 全部 pass。マージして良い。" ;;
  *) echo "ci-wait: 落ちたものがある。上の一覧を見る。" ;;
esac
exit "$rc"
