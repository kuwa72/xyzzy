#!/bin/bash
# Run the Windows xyzzy from WSL, against the working tree.
#
#   tools/win-xyzzy.sh --stage              refresh the Windows copy and stop
#   tools/win-xyzzy.sh --test [ARGS...]     run misc/run-tests-batch.l
#   tools/win-xyzzy.sh SCRIPT.l [ARGS...]   run SCRIPT.l with -load
#
# Why this exists: tools/run-tests.sh and the CI jobs drive the mingw build
# under Wine, and Wine is not Windows.  Anything that only breaks on the real
# thing -- ConPTY, the console API, a drive letter in a path -- cannot be
# reproduced from Linux at all.  This copies the build and the Lisp library to
# a directory Windows can see and runs it there through the WSL interop, so a
# coding agent working on the WSL side can check its own work on the target.
#
# The copy is not an optimisation.  xyzzy keeps paths internally in the
# ".../..." form, and a UNC path written that way is not something Win32 will
# open: XYZZYHOME pointing at \\wsl.localhost\... dies with "Permission
# denied" on the first file read.  Only the parts that change while working
# (lisp/, misc/, unittest/, tools/ and the exes) are recopied, so a run after
# an edit costs about a second.
#
# Environment:
#   XYZZY_WIN_DIR      where the Windows copy lives.
#                      Default: %USERPROFILE%\xyzzy-verify, asked of cmd.exe.
#   XYZZY_WIN_ARCH     i686 | x86_64 (default x86_64)
#   XYZZY_WIN_REFRESH  set to 1 to unpack the package again (new dlls, etc.)
#   XYZZY_TEST_*       passed through to the Windows process
#   XYZZY_ONE_TEST_*   passed through too (scratch runners pick one file/test)
#
# **cmd.exe has to be allowed to run outside the sandbox.**  The interop
# reaches Windows over a vsock, and a sandbox that denies socket() turns every
# run into "UtilBindVsockAnyPort: socket failed 1" with no other output.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

[ -d /mnt/c ] || {
  echo "win-xyzzy.sh: no /mnt/c -- this drives Windows from WSL" >&2
  exit 2
}

arch=${XYZZY_WIN_ARCH:-x86_64}
build=$root/_build/$arch
exe=$build/xyzzy-batch.exe
[ -x "$exe" ] || { echo "win-xyzzy.sh: $exe not built" >&2; exit 2; }

# Run a cmd.exe builtin or command with the cwd on a drive, never in the WSL
# share: cmd.exe prints a "UNC paths are not supported" warning for every
# invocation started from \\wsl.localhost, and it is not the thing being
# debugged.
win_sh() {
  (cd /mnt/c && cmd.exe /c "$1")
}

to_wsl_path() {
  local p=${1//\\//}
  case $p in
    [A-Za-z]:*) printf '/mnt/%s%s\n' "$(printf '%s' "${p%%:*}" | tr 'A-Z' 'a-z')" "${p#*:}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

to_win_path() {
  local p=$1
  case $p in
    /mnt/[a-z]/*)
      local drive rest
      drive=$(printf '%s' "${p#/mnt/}" | cut -c1 | tr 'a-z' 'A-Z')
      rest=${p#/mnt/?}
      printf '%s:%s\n' "$drive" "${rest//\//\\}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

win_dir=${XYZZY_WIN_DIR:-}
if [ -z "$win_dir" ]; then
  up=$(win_sh 'echo %USERPROFILE%' | tr -d '\r\n')
  case $up in
    [A-Za-z]:\\*) win_dir="$up\\xyzzy-verify" ;;
    *)
      echo "win-xyzzy.sh: could not work out %USERPROFILE%; set XYZZY_WIN_DIR" >&2
      exit 2 ;;
  esac
fi
dir=$(to_wsl_path "$win_dir")
[ -d "$(dirname "$dir")" ] || {
  echo "win-xyzzy.sh: $(dirname "$dir") does not exist -- is $win_dir the right place?" >&2
  exit 2
}

# The package holds the parts that do not change while working: the grammars,
# the docs, the dictionaries.  Unpacking it once is much cheaper than copying
# 30 MB across the 9p share on every run.
stage_base() {
  local zip
  zip=$(ls -1 "$build"/xyzzy-*.zip 2>/dev/null | sort -V | tail -1) || true
  if [ -z "${zip:-}" ]; then
    echo "win-xyzzy.sh: no package in $build; run 'tools/x package $arch' first" >&2
    exit 2
  fi
  echo "### unpacking $(basename "$zip") into $win_dir"
  # _build is written by the container and is not ours to write (it is root
  # owned), so the unpack happens somewhere disposable.
  local tmp
  tmp=$(mktemp -d)
  unzip -q "$zip" -d "$tmp"
  local inner
  inner=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  inner=${inner:-$tmp}
  mkdir -p "$dir"
  cp -r "$inner"/. "$dir"/
  rm -rf "$tmp"
}

if [ "${1:-}" = --stage ] || [ ! -f "$dir/xyzzy.exe" ] \
   || [ "${XYZZY_WIN_REFRESH:-}" = 1 ]; then
  stage_base
fi

# Everything that moves while working.  The .exe files land next to the
# library rather than under bin/, which is where -load looks for them.
cp -f "$build"/xyzzy-batch.exe "$dir/" 2>/dev/null || true
for e in "$build"/xyzzy.exe "$build"/xyzzycli.exe "$build"/xyzzyenv.exe; do
  [ -f "$e" ] && cp -f "$e" "$dir/" || true
done

# tools/ is here for the tests that drive a helper script (the LSP suite
# starts tools/fake-lsp-server.py); the package does not carry it.
for d in lisp misc unittest tools etc; do
  [ -d "$root/$d" ] || continue
  mkdir -p "$dir/$d"
  # -u: only files that are newer.  The library is 6 MB and the share is slow
  # enough that an unconditional copy is felt on every single run.
  cp -ru "$root/$d/." "$dir/$d/"
done

if [ "${1:-}" = --stage ]; then
  echo "### staged in $win_dir"
  exit 0
fi

# Build the command line.  Everything is written into a .cmd file and that
# file is run, because passing a Lisp form on the cmd.exe command line means
# fighting two levels of quoting (the WSL exec, then cmd) and the arguments
# that survive are not the ones that were meant.
script=""
if [ "${1:-}" = --test ]; then
  script=misc/run-tests-batch.l
  shift || true
elif [ -n "${1:-}" ]; then
  case $1 in
    /*)
      # A scratch file outside the tree: copy it in, the Windows side cannot
      # see /tmp.
      mkdir -p "$dir/scratch"
      cp -f "$1" "$dir/scratch/$(basename "$1")"
      script="scratch/$(basename "$1")" ;;
    *) script=$1 ;;
  esac
  shift || true
fi

if [ -z "$script" ]; then
  echo "win-xyzzy.sh: nothing to run; pass --test or a .l file" >&2
  exit 2
fi

{
  printf '@echo off\r\n'
  printf 'set XYZZYHOME=%s\r\n' "$(to_win_path "$dir")"
  # The suite writes logs next to the exe and reads its exclude lists by
  # relative path; both assume the tree root is the cwd.
  # XYZZY_ONE_TEST_*: 1 つのファイルや 1 つのテストだけを走らせる scratch
  # スクリプトが読む。suite の絞り込みが無いので、絞るときはこれを使う。
  for v in XYZZY_TEST_KNOWN_FAILURES XYZZY_TEST_EXCLUDE \
           XYZZY_TEST_EXCLUDE_EXTRA XYZZY_TEST_UPDATE_KNOWN_FAILURES \
           XYZZY_ONE_TEST_FILE XYZZY_ONE_TEST_NAME; do
    eval "val=\${$v:-}"
    [ -n "$val" ] && printf 'set %s=%s\r\n' "$v" "$val"
  done
  printf 'cd /d %s\r\n' "$(to_win_path "$dir")"
  printf 'xyzzy-batch.exe -q -load %s' "$script"
  for a in "$@"; do printf ' %s' "$a"; done
  printf '\r\n'
  printf 'exit /b %%ERRORLEVEL%%\r\n'
} > "$dir/run.cmd"

printf '### %s on Windows (%s)\n' "$script" "$win_dir"
set +e
(cd "$dir" && cmd.exe /c run.cmd)
rc=$?
set -e
echo "### exit $rc"
exit $rc
