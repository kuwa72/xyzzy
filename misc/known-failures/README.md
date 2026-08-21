known failures
==============

The test suite does not pass clean on any target, and it has not for a long
time.  What used to be done about that was to run it with
`continue-on-error: true` -- the whole suite informational, so a real regression
looked exactly like the ten failures that were already there and nobody noticed
either.

These files are the alternative: the failures that are *already known* are
listed by name, and the suite is gated on everything else.  A test that fails
without being listed here fails the build.  A test that is listed here and
passes also fails the build, so that the list cannot quietly rot.

Files
-----

The lists compose; a target is given a comma separated list of them.

    common.txt        fails on every target, both toolchains
    msvc.txt          MSVC (build.yml), all three architectures
    msvc-64bit.txt    MSVC x64 and ARM64
    mingw.txt         llvm-mingw under Wine (mingw.yml), both architectures
    mingw-i686.txt    llvm-mingw i686

So, for example, MSVC ARM64 runs with

    common.txt,msvc.txt,msvc-64bit.txt

`tools/run-tests.sh` picks the mingw combination itself, and the matrix in
`.github/workflows/build.yml` carries the MSVC ones.

This is not the same thing as the exclude lists in `misc/run-tests-batch.l` and
`tools/run-tests.sh`.  Those are for tests that take the *process* down, which
has to be kept out of the run entirely -- a dead process leaves everything
after it unmeasured.  A known failure here runs normally and reports a failure.

Format
------

One test name per line, `#` starts a comment, blank lines are ignored.  Write
the name as the suite prints it (lower case); the comparison is case
insensitive.

**Say why.**  A name on its own becomes permanent, because the next person has
no way to tell a known bug from a test that was inconvenient.  A line of
explanation is what makes it possible to ever take the entry off again.

Working with the list
---------------------

To see where a target stands, run the suite and read the summary block:

    === known failures: 10 listed, 10 matched ===
    === unexpected failures 1: some-test ===
    === now passing, remove from the list 2: old-test other-test ===

To rewrite a list from an actual run instead of editing by hand:

    XYZZY_TEST_UPDATE_KNOWN_FAILURES=misc/known-failures/mingw.txt tools/x test x86_64

That writes the names that failed and nothing else -- every comment in the file
is lost, so it is a starting point for an edit, not a substitute for one.  The
run always exits 0 in this mode, so it cannot be left on in CI.
