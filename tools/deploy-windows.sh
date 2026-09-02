#!/bin/bash
# Build, package and drop the Windows binaries where the real machine can run
# them.  Runs on the WSL host (needs docker for the build and /mnt/c for the
# copy); the per-arch build itself happens in the container via tools/x.
#
#   tools/deploy-windows.sh [DEST]
#
# DEST is where the flattened per-arch folders go.  With no argument it comes
# from $XYZZY_DEPLOY_DEST, and failing that from the Windows %USERPROFILE%
# asked of cmd.exe -- *not* from $USER.  The WSL account name and the Windows
# account name are often different (kuwa72 vs ykuwa here), and guessing from
# $USER made the script try to mkdir a second user directory under
# /mnt/c/Users, which is not writable.
#
# Why a script: this packages both architectures, and swapping the deployed
# folder needs care (see below) so a partial deploy never looks like a
# working install.  The .lc files sit in the *shared* source tree and are
# portable between i686/x86_64 (lisp/foreign.l resolves pointer width from
# *features* at load time, not at compile time -- see lisp/foreign.l and
# tools/bytecompile.sh), so one arch's build byte compiles the lot, forced,
# and both packages ship that same set.
set -euo pipefail

# Resolve DEST before cd, so a relative argument means what the caller meant.
dest_arg=${1:-}
if [ -n "$dest_arg" ]; then
  dest=$(cd "$(dirname "$dest_arg")" 2>/dev/null && pwd)/$(basename "$dest_arg") \
    || dest=$dest_arg
fi

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# Ask Windows for its own profile directory and translate it to a /mnt path.
windows_downloads() {
  local up
  up=$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n') || return 1
  case $up in
    [A-Za-z]:\\*) ;;
    *) return 1 ;;
  esac
  local drive=${up%%:*}
  local rest=${up#*:}
  printf '/mnt/%s%s/Downloads' \
    "$(printf '%s' "$drive" | tr 'A-Z' 'a-z')" \
    "$(printf '%s' "$rest" | tr '\\' '/')"
}

if [ -z "${dest:-}" ]; then
  dest=${XYZZY_DEPLOY_DEST:-}
fi
if [ -z "$dest" ]; then
  dl=$(windows_downloads) || dl=""
  [ -n "$dl" ] && dest=$dl/xyzzy-latest
fi
if [ -z "$dest" ]; then
  echo "deploy: could not work out where to deploy." >&2
  echo "deploy: pass it, or set XYZZY_DEPLOY_DEST, e.g." >&2
  echo "deploy:   tools/deploy-windows.sh /mnt/c/Users/<you>/Downloads/xyzzy-latest" >&2
  exit 1
fi

# Only ever create the leaf.  Creating parents would mean the path is wrong
# (a mistyped or guessed user name), and /mnt/c/Users is not writable anyway.
if [ ! -d "$dest" ]; then
  parent=$(dirname "$dest")
  if [ ! -d "$parent" ]; then
    echo "deploy: $parent does not exist -- is $dest the right place?" >&2
    exit 1
  fi
  mkdir "$dest"
fi
echo "### deploying to $dest"

sha=$(git rev-parse --short HEAD)
version=$(sed -n 's/^project(.*VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt | head -1)
[ -n "$version" ] || { echo "deploy: could not read the version out of CMakeLists.txt" >&2; exit 1; }

# arch -> name used in the deployed directory and the zip
declare -A label=([x86_64]=amd64 [i686]=x86)

archs="x86_64 i686"

# Build and package *every* arch before touching the destination.  Doing
# build-then-deploy per arch in one loop means a failure on the second arch
# leaves the first one already swapped in: half the destination new, half old,
# and nothing says so.  That is not hypothetical -- the i686 build died on a
# missing build tree (cmake: "_build/i686 is not a directory") *after* amd64
# had been deployed.  tools/x now configures that itself, but a build can
# always fail for some other reason, and the fix for the shape is this order.
bytecompiled=0
for arch in $archs; do
  echo "### building $arch"

  tools/x build "$arch"
  if [ "$bytecompiled" = 0 ]; then
    tools/x bytecompile "$arch" --force
    bytecompiled=1
  fi
  tools/x build "$arch" --target package

  zip=$root/_build/$arch/xyzzy-$version.zip
  [ -f "$zip" ] || { echo "deploy: $zip was not produced" >&2; exit 1; }
done

for arch in $archs; do
  name=${label[$arch]}
  echo "### $arch -> xyzzy-$name"

  zip=$root/_build/$arch/xyzzy-$version.zip
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
  inner=${inner:-$out.tmp}

  # Replace the *contents*, never the directory.  Removing the directory
  # itself fails with EACCES whenever anything on the Windows side holds a
  # handle on it (an Explorer window, a shell sitting in it), and by then the
  # contents are already gone -- which is how this left an empty xyzzy-amd64
  # behind once.  Clearing the contents and copying into the existing
  # directory has no such failure mode.
  # Keep the user's own state.  Without XYZZYCONFIGPATH set, xyzzy puts its
  # config and history under <install>/usr/<user>/<name>/ -- inside the very
  # directory this script replaces.  Wiping it made settings reset on every
  # deploy, which looked like xyzzy failing to save them.
  mkdir -p "$out"
  find "$out" -mindepth 1 -maxdepth 1 ! -name usr -exec rm -rf {} + 2>/dev/null || {
    echo "deploy: could not clear $out (a file in it is in use?)" >&2
    exit 1
  }
  cp -r "$inner"/. "$out"/
  rm -rf "$out.tmp"

  cp "$zip" "$dest/xyzzy-$version-$sha-llvmmingw-$name.zip"

  # A missing binary or an empty .lc set is silent until something breaks
  # oddly later, so say out loud what went out.
  lc=$(ls "$out"/lisp/*.lc 2>/dev/null | wc -l)
  printf '  %-12s exe=%s xyzzyenv=%s xyzzycli=%s lc=%s\n' \
    "xyzzy-$name" \
    "$([ -f "$out/xyzzy.exe" ] && echo yes || echo NO)" \
    "$([ -f "$out/xyzzyenv.exe" ] && echo yes || echo NO)" \
    "$([ -f "$out/xyzzycli.exe" ] && echo yes || echo NO)" \
    "$lc"
  if [ "$lc" -eq 0 ]; then
    echo "deploy: $out/lisp has no .lc files" >&2
    exit 1
  fi
done

echo "### deployed to $dest ($sha)"
ls -1 "$dest"
