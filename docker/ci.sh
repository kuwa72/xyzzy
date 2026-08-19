#!/bin/bash
# コンテナ内で走るビルド/テストスクリプト。ホストからは docker/dev.sh 経由で呼ぶ。
#
#   docker/ci.sh <linux|wine> [action...]
#
# action:
#   configure     cmake を構成する (build-docker/<env>/)
#   build         実行ファイルをビルドする
#   bytecompile   lisp/*.l を .lc にバイトコンパイルする
#   test          misc/run-tests-batch.l でユニットテストを走らせる
#   run           エディタを起動する (linux: ncurses / wine: GUI xyzzy.exe)
#   clean         build-docker/<env>/ を消す
#   all           build → bytecompile → test (既定)
#
# 環境変数: XYZZY_ARCH=x86_64|i686 (wine のみ), JOBS, XYZZY_TEST_EXCLUDE
set -euo pipefail

ENVNAME=${1:-}
shift || true
case "$ENVNAME" in
    linux|wine) ;;
    *) echo "usage: docker/ci.sh <linux|wine> [action...]" >&2; exit 2 ;;
esac
ACTIONS=("$@")
if [ ${#ACTIONS[@]} -eq 0 ]; then ACTIONS=(all); fi

SRC=$(cd "$(dirname "$0")/.." && pwd)
cd "$SRC"

ARCH=${XYZZY_ARCH:-x86_64}
JOBS=${JOBS:-$(nproc)}
OUT=$SRC/build-docker
if [ "$ENVNAME" = linux ]; then
    BUILD=$OUT/linux
else
    BUILD=$OUT/wine-$ARCH
fi
mkdir -p "$BUILD"

# XYZZYINIFILE/XYZZYCONFIGPATH は CI と同じく空にして、ホストの設定を拾わせない。
export XYZZYINIFILE=
export XYZZYCONFIGPATH=

if [ "$ENVNAME" = wine ]; then
    export WINEPREFIX=$OUT/wineprefix
    export WINEARCH=win64
    export WINEDEBUG=${WINEDEBUG:--all}
    if [ ! -f "$WINEPREFIX/system.reg" ]; then
        echo "--- wineboot (初回のみ: $WINEPREFIX)"
        wineboot -i >/dev/null 2>&1 || true
    fi
    # Windows 側から見たパスを渡す (/work → Z:\work)
    XYZZYHOME=$(winepath -w "$SRC")
    export XYZZYHOME
    XYZZY_EXE=$BUILD/xyzzy.exe
    BATCH_EXE=(wine "$BUILD/xyzzy-batch.exe" -q)
else
    export XYZZYHOME=$SRC
    XYZZY_EXE=$BUILD/xyzzy
    # ncurses 版はバッチ実行も同じバイナリの --batch モード。-q は付けない
    # (.lc なしで起動するには通常のブートストラップが必要)。
    BATCH_EXE=("$BUILD/xyzzy" --batch)
fi

step () { echo; echo "=== [$ENVNAME] $* ==="; }

do_configure () {
    step configure
    if [ "$ENVNAME" = linux ]; then
        cmake -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release
    else
        cmake -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE="$SRC/docker/mingw-toolchain.cmake" \
            -DMINGW_ARCH="$ARCH"
    fi
}

do_build () {
    [ -f "$BUILD/CMakeCache.txt" ] || do_configure
    step "build (arch=$ARCH, jobs=$JOBS)"
    if [ "$ENVNAME" = linux ]; then
        cmake --build "$BUILD" --parallel "$JOBS" --target xyzzy-ncurses
    else
        cmake --build "$BUILD" --parallel "$JOBS" --target xyzzy xyzzy-batch xyzzy-cli
    fi
    ls -lh "$BUILD"/xyzzy*
    # grammars/ には CMake がソースツリー直下に成果物を吐く。mingw ビルドはコミット
    # 済みの .dll を置き換えるので、そのつもりがない場合に気づけるよう知らせる。
    if [ "$ENVNAME" = wine ] && ! git -C "$SRC" diff --quiet -- grammars 2>/dev/null; then
        echo "注意: grammars/*.dll が mingw ビルドで置き換わった (戻すなら git checkout -- grammars)"
    fi
}

do_bytecompile () {
    step bytecompile
    if [ "$ENVNAME" = linux ]; then
        cmake --build "$BUILD" --target bytecompile
    else
        rm -f "$BUILD"/xyzzy-batch.wxp
        rm -f "$SRC"/lisp/*.lc
        # 終了時に落ちることがあるが、成否は .lc の本数で判断する (CI と同じ)
        "${BATCH_EXE[@]}" -load misc/bytecompile-batch.l || true
        local n
        n=$(find "$SRC/lisp" -name '*.lc' | wc -l)
        echo "生成した .lc: $n 個"
        [ "$n" -ge 100 ] || { echo "bytecompile 失敗 (.lc が $n 個しかない)" >&2; return 1; }
    fi
}

do_test () {
    step test
    rm -f "$BUILD"/xyzzy-batch.wxp "$BUILD"/xyzzy.wxp
    local log=$BUILD/test.log rc=0
    "${BATCH_EXE[@]}" -load misc/run-tests-batch.l 2>&1 | tee "$log" || rc=$?
    echo
    grep -E '^=== (Running|Skipped|ERROR)|^Total|Failed$' "$log" | tail -20 || true
    echo "--- exit=$rc  Failed: $(grep -c 'Failed' "$log" || true)  ログ: ${log#"$SRC"/}"
    return $rc
}

do_run () {
    step run
    if [ "$ENVNAME" = linux ]; then
        exec "$XYZZY_EXE"
    else
        exec wine "$XYZZY_EXE"
    fi
}

do_clean () {
    step clean
    rm -rf "$BUILD"
}

for action in "${ACTIONS[@]}"; do
    case "$action" in
        configure)   do_configure ;;
        build)       do_build ;;
        bytecompile) do_bytecompile ;;
        test)        do_test ;;
        run)         do_run ;;
        clean)       do_clean ;;
        all)         do_build; do_bytecompile; do_test ;;
        *) echo "unknown action: $action" >&2; exit 2 ;;
    esac
done
