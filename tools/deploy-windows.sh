#!/bin/bash
# Build, package and drop the Windows binaries where the real machine can run
# them.  Runs on the WSL host (needs docker for the build and /mnt/c for the
# copy); the per-arch build itself happens in the container via tools/x.
#
#   tools/deploy-windows.sh [DEST]
#
# DEST defaults to /mnt/c/Users/$USER/Downloads/xyzzy-latest, override it when
# the Windows user name differs from the WSL one.
#
# Why a script: the .lc files are architecture dependent (pointer width is
# baked in at byte compile time) and CPack installs them from the *shared*
# source tree, so a package only ships a matching set if bytecompile and
# package run back to back for the same arch.  Doing that by hand once per
# arch is how an amd64 zip ends up with i686 .lc in it.  Byte compiling also
# has to be forced: bytecompile.sh only looks at the arch stamp, never at
# whether a .l is newer than its .lc.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

dest=${1:-/mnt/c/Users/$USER/Downloads/xyzzy-latest}
sha=$(git rev-parse --short HEAD)
version=$(sed -n 's/^project(.*VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt | head -1)
[ -n "$version" ] || { echo "deploy: could not read the version out of CMakeLists.txt" >&2; exit 1; }

[ -d "$dest" ] || mkdir -p "$dest"

# arch -> name used in the deployed directory and the zip
declare -A label=([x86_64]=amd64 [i686]=x86)

for arch in x86_64 i686; do
  name=${label[$arch]}
  echo "### $arch -> xyzzy-$name"

  tools/x build "$arch"
  tools/x bytecompile "$arch" --force
  tools/x build "$arch" --target package

  zip=$root/_build/$arch/xyzzy-$version.zip
  [ -f "$zip" ] || { echo "deploy: $zip was not produced" >&2; exit 1; }

  out=$dest/xyzzy-$name

  # Refuse to touch a running install.  Windows keeps a running .exe open with
  # FILE_SHARE_READ only, so opening it for write fails -- that is the probe.
  # Without this check the rm below deletes whatever is not locked and then
  # dies on the .exe, leaving a half-populated directory: the exe still there
  # but lisp/*.lc and the helper exes gone.  Learned the hard way.
  if [ -e "$out/xyzzy.exe" ] && ! (exec 3<>"$out/xyzzy.exe") 2>/dev/null; then
    echo "deploy: $out/xyzzy.exe is in use; close xyzzy and run again" >&2
    exit 1
  fi

  # Unpack first, swap second, so a failure part way through leaves the
  # existing install alone.  CPack wraps everything in a version directory;
  # flatten it so xyzzy.exe sits at the top of the deployed folder.
  rm -rf "$out.tmp"
  mkdir -p "$out.tmp"
  unzip -q "$zip" -d "$out.tmp"
  inner=$(find "$out.tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
  rm -rf "$out"
  mv "${inner:-$out.tmp}" "$out"
  rm -rf "$out.tmp"

  cp "$zip" "$dest/xyzzy-$version-$sha-llvmmingw-$name.zip"

  # A mismatched .lc set is silent at run time until something breaks oddly,
  # so say out loud what went out.
  stamp=$(cat "$out/lisp/.bytecompile-arch" 2>/dev/null || echo "MISSING")
  printf '  %-12s exe=%s xyzzyenv=%s xyzzycli=%s lc=%s stamp=%s\n' \
    "xyzzy-$name" \
    "$([ -f "$out/xyzzy.exe" ] && echo yes || echo NO)" \
    "$([ -f "$out/xyzzyenv.exe" ] && echo yes || echo NO)" \
    "$([ -f "$out/xyzzycli.exe" ] && echo yes || echo NO)" \
    "$(ls "$out"/lisp/*.lc 2>/dev/null | wc -l)" \
    "$stamp"
  if [ "$stamp" != "$arch" ]; then
    echo "deploy: .lc stamp says '$stamp' but this is $arch" >&2
    exit 1
  fi
done

echo "### deployed to $dest ($sha)"
ls -1 "$dest"
