#!/usr/bin/env bash
# Docker でのローカル確認環境のホスト側エントリポイント。
#
#   docker/dev.sh linux all           # ncurses 版をビルド → バイトコンパイル → テスト
#   docker/dev.sh wine all            # mingw クロスビルド → Wine でテスト
#   docker/dev.sh wine test           # テストだけ回す
#   docker/dev.sh linux run           # ncurses 版のエディタを起動
#   docker/dev.sh wine run            # Wine で GUI 版を起動 (WSLg の DISPLAY を使う)
#   docker/dev.sh linux shell         # コンテナに入る
#   docker/dev.sh image [linux|wine]  # イメージを (再)ビルドする
#
# 環境変数:
#   XYZZY_ARCH=x86_64|i686   wine 環境のターゲット (既定 x86_64)
#   JOBS=N                   並列ビルド数 (既定はコンテナの nproc)
#   XYZZY_TEST_EXCLUDE=a,b   除外するテスト (misc/run-tests-batch.l 参照)
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE=("docker" "compose" "-f" "$HERE/compose.yml")

export XYZZY_UID=${XYZZY_UID:-$(id -u)}
export XYZZY_GID=${XYZZY_GID:-$(id -g)}
# HOME はコンテナ内で /work/build-docker/home を指すので、先に作っておく
mkdir -p "$HERE/../build-docker/home"

usage () { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; }

case "${1:-}" in
    image)
        shift
        "${COMPOSE[@]}" build "$@"
        ;;
    linux|wine)
        ENVNAME=$1; shift
        if [ "${1:-}" = shell ]; then
            exec "${COMPOSE[@]}" run --rm "$ENVNAME" bash
        fi
        # イメージが無ければ黙って作る
        if ! docker image inspect "xyzzy-dev-$ENVNAME" >/dev/null 2>&1; then
            "${COMPOSE[@]}" build "$ENVNAME"
        fi
        exec "${COMPOSE[@]}" run --rm "$ENVNAME" docker/ci.sh "$ENVNAME" "$@"
        ;;
    ""|-h|--help|help)
        usage
        ;;
    *)
        echo "unknown command: $1" >&2
        usage >&2
        exit 2
        ;;
esac
