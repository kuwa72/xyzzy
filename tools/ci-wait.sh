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

# **push の直後は「チェックがまだ 1 つも無い」窓がある。** そこで
# `gh pr checks --watch` を呼ぶと待たずに
# `no checks reported on the '...' branch` で 1 を返すので、**落ちたと
# 読めてしまう。** 実際に踏んだ (PR #145)。
#
# **窓は 1 回で終わらない。** force-push でやり直すと run が作り直されるので、
# --watch が戻ったあとにまた「チェックが無い」状態になることがある
# (PR #147 で踏んだ: 180 秒待ってから --watch に入り、そのあと再び空だった)。
# なので「チェックが現れるのを待つ → --watch」を**塊ごと繰り返す。**
no_checks_p () {
  gh pr checks "$pr" 2>&1 | grep -q 'no checks reported'
}

# 実際に fail になったチェックの名前。**pending は数えない。**
failed_checks () {
  gh pr checks "$pr" --json bucket,name \
    -q '.[] | select(.bucket == "fail" or .bucket == "cancel") | .name' 2>/dev/null
}

# **衝突している PR にはチェックが 1 つも付かない。** GitHub は merge ref を
# 作れないので workflow が発火せず、上の窓と**見分けが付かないまま 30 分待つ**
# ことになる。実際に踏んだ (PR #148: base の PR が squash merge された直後で、
# 待っても何も来なかった)。先に見る。
if [ "$(gh pr view "$pr" --json mergeable -q .mergeable 2>/dev/null)" = CONFLICTING ]; then
  echo "ci-wait: PR #$pr は衝突している。**チェックは付かない** (GitHub が"
  echo "ci-wait: merge ref を作れないので workflow が発火しない)。"
  echo "ci-wait: main へ rebase してから出し直す。"
  exit 2
fi

deadline=$(( $(date +%s) + limit ))
announced=0
rc=1
while :; do
  now=$(date +%s)
  [ "$now" -ge "$deadline" ] && { rc=124; break; }

  if no_checks_p; then
    if [ "$announced" -eq 0 ]; then
      echo "ci-wait: チェックがまだ登録されていない。待つ"
      announced=1
    fi
    sleep 10
    continue
  fi

  # --watch は全部終わるまで戻らない。--fail-fast で最初の失敗で戻る。
  # 0 = 全部 pass, 1 = どれか fail, 8 = pending (--watch では来ない)。
  set +e
  timeout "$((deadline - now))" gh pr checks "$pr" --watch --fail-fast --interval 20 \
    >/dev/null 2>&1
  rc=$?
  set -e

  # 戻ったあとに空になっていたら、run が作り直された (force-push など)。
  # **「落ちた」と読まずにもう一周する。**
  if no_checks_p; then
    announced=0
    continue
  fi

  # **非 0 で戻っても、実際に fail になったチェックが 1 つも無いことがある。**
  # force-push の直後などに run が入れ替わると、--watch が「まだ全部 pending」
  # のまま 1 を返す。実際に踏んだ (PR #159: 7 件すべて pending の一覧を出して
  # 「落ちたものがある」と言った)。**落ちたと言うのは fail の行があるときだけ。**
  if [ "$rc" -ne 0 ] && [ -z "$(failed_checks)" ]; then
    echo "ci-wait: --watch が非 0 で戻ったが、fail のチェックは無い。待ち直す"
    announced=0
    sleep 10
    continue
  fi
  break
done

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
