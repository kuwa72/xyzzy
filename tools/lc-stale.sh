# Shared by tools/bytecompile.sh and tools/run-tests.sh.  Source this after
# setting $root; it defines stale_files(), which prints every lisp/*.l that
# is newer than its .lc, or that has no .lc at all.
#
# lisp/wip/ is excluded because misc/makelc.l's compile-files excludes it
# too: nothing there is require'd, and some of it overflows the compiler's
# stack.

stale_files() {
  find "$root/lisp" -name '*.l' -not -path '*/wip/*' -print | while read -r l; do
    lc=${l%.l}.lc
    if [ ! -f "$lc" ] || [ "$l" -nt "$lc" ]; then
      echo "  $l"
    fi
  done
}
