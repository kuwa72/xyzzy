#!/bin/bash
# Prepare a release: bump the version, turn the running notes into this
# version's notes, and start a fresh running file.
#
#   tools/release-prep.sh 0.3.1
#
# Nothing is committed and nothing is pushed.  The point is to do the three
# fiddly edits in one go and leave them in the working tree to be read, because
# the order they go in matters: .github/workflows/release.yml refuses a tag
# whose number disagrees with CMakeLists.txt, and refuses one with no release
# notes.  Doing it by hand is how one of the two gets forgotten.
#
# See RELEASING.md for the whole procedure.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

version=${1:-}
if [ -z "$version" ]; then
  echo "usage: tools/release-prep.sh <version>     e.g. tools/release-prep.sh 0.3.1" >&2
  exit 2
fi

# The tag is v<version>, and release.yml compares its numeric part against
# CMakeLists.txt.  A suffix (0.3.1-rc1) belongs on the tag, not here: CMake's
# project(VERSION ...) only takes numbers.
case $version in
  v*) echo "release-prep: give the version without the v: ${version#v}" >&2; exit 2 ;;
esac
if ! printf '%s' "$version" | grep -qE '^[0-9]+(\.[0-9]+){1,3}$'; then
  echo "release-prep: '$version' is not a numeric version (0.3.1, 0.3.1.2)" >&2
  exit 2
fi

cmake=CMakeLists.txt
notes_next=docs/release-note-next.md
notes=docs/release-note-${version}.md

matches=$(grep -cE '^project\(xyzzy VERSION [0-9.]+' "$cmake" || true)
if [ "$matches" -ne 1 ]; then
  echo "release-prep: expected exactly one project(xyzzy VERSION ...) in $cmake, found $matches" >&2
  exit 1
fi
current=$(sed -nE 's/^project\(xyzzy VERSION ([0-9.]+).*/\1/p' "$cmake")

if [ "$current" = "$version" ]; then
  echo "release-prep: $cmake already says $version" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/v${version}" >/dev/null; then
  echo "release-prep: tag v${version} already exists" >&2
  exit 1
fi
if [ -e "$notes" ]; then
  echo "release-prep: $notes already exists" >&2
  exit 1
fi
if [ ! -f "$notes_next" ]; then
  echo "release-prep: $notes_next is missing; nothing to turn into release notes" >&2
  exit 1
fi

# Only the files this script is about to rewrite matter here.  The tree-sitter
# DLLs under grammars/ show as modified after any local build, so refusing on a
# dirty tree outright would refuse almost always.
dirty=$(git status --porcelain -- "$cmake" "$notes_next")
if [ -n "$dirty" ]; then
  echo "release-prep: commit or stash these first:" >&2
  echo "$dirty" >&2
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != main ]; then
  echo "release-prep: note, you are on '$branch', not main"
fi

echo "release-prep: $current -> $version"

# sed -i is not portable between GNU and BSD, so write and move.
tmp=$(mktemp)
sed -E "s/^project\(xyzzy VERSION [0-9.]+/project(xyzzy VERSION ${version}/" \
  "$cmake" > "$tmp"
mv "$tmp" "$cmake"
grep -nE '^project\(xyzzy VERSION' "$cmake"

# The running file carries "(未リリース)" in the header; the release date is
# whatever day this is run.
if git ls-files --error-unmatch "$notes_next" >/dev/null 2>&1; then
  git mv "$notes_next" "$notes"
else
  mv "$notes_next" "$notes"
fi
today=$(date +%F)
tmp=$(mktemp)
sed -E \
  -e "s/^(  \* バージョン: )\(未リリース\)/\1${version}/" \
  -e "s/^(  \* リリース日: )\(未リリース\)/\1${today}/" \
  "$notes" > "$tmp"
mv "$tmp" "$notes"
head -6 "$notes"

# Start the next one from the template that the release notes themselves came
# from, so the running file is always there to append to.
cat > "$notes_next" <<'TEMPLATE'
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

  *
TEMPLATE

git add "$cmake" "$notes" "$notes_next"

cat <<EOF

release-prep: done, staged but not committed.

  1. read $notes and finish it
       - the "変更" list is whatever accumulated; give it sections
         (ターミナル / フォント / ビルドと配布 …) the way the older notes do
       - delete the placeholder lines
  2. git commit -m "release: ${version}"
  3. open a PR, get it merged into main
  4. git tag v${version} <the merge commit> && git push origin v${version}

Step 4 is what publishes.  A prerelease is the same thing with a suffix on the
tag only -- v${version}-rc1 -- and it needs its own
docs/release-note-${version}-rc1.md, so copy $notes to that name first.
EOF
