# Write src/core/gen/version-describe.h from `git describe`.
#
#   cmake -DXYZZY_SOURCE_DIR=<source dir> -P cmake/git-describe.cmake
#
# **This runs at build time, not only at configure time.** The commit changes
# far more often than CMakeLists.txt does, so a hash captured at configure time
# goes stale, and a stale hash in the title bar is worse than no hash: it names
# a build you are not running.  Ninja re-runs this on every build; the header is
# only rewritten when its content changes, so version.cc does not recompile for
# nothing.
#
# What ends up in the title bar and in the About dialog:
#
#   on a tag        xyzzy 0.6.0                   (the release)
#   off a tag       xyzzy 0.6.0-37-g97c4acf       (37 commits past v0.6.0)
#   uncommitted     xyzzy 0.6.0-37-g97c4acf-dirty
#
# The leading "v" of the tag is dropped so this reads the same as the plain
# version next to it ("xyzzy version 0.6.0").

if(NOT DEFINED XYZZY_SOURCE_DIR)
    message(FATAL_ERROR "git-describe.cmake: XYZZY_SOURCE_DIR is not set")
endif()

set(_out "${XYZZY_SOURCE_DIR}/src/core/gen/version-describe.h")
set(_content "/* No git info available - use the plain version string */")

find_package(Git QUIET)
if(GIT_FOUND AND EXISTS "${XYZZY_SOURCE_DIR}/.git")
    # --long always spells out "-<n>-g<hash>".  The short form omits it only
    # when the commit is exactly a tag, so "short == long" means "not on a tag".
    # This comparison used to be the other way round, which made the describe
    # string appear only on releases -- i.e. never where it was wanted.
    # -c safe.directory: the cross build runs in a container as root while the
    # checkout is owned by the host user, and git then refuses with "detected
    # dubious ownership" and exits 128.  Without this the local build silently
    # fell back to the plain version -- which is exactly the build the hash is
    # wanted for.
    set(_git ${GIT_EXECUTABLE} -c safe.directory=${XYZZY_SOURCE_DIR})
    execute_process(
        COMMAND ${_git} describe --tags --dirty --long
        WORKING_DIRECTORY ${XYZZY_SOURCE_DIR}
        OUTPUT_VARIABLE _long
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
        RESULT_VARIABLE _rc)
    execute_process(
        COMMAND ${_git} describe --tags --dirty
        WORKING_DIRECTORY ${XYZZY_SOURCE_DIR}
        OUTPUT_VARIABLE _short
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    if(NOT _rc EQUAL 0)
        # Say so rather than falling through to the "on a tag" branch: that
        # would claim this is a release build when it may well not be.
        set(_content "/* git describe failed - use the plain version string */")
    elseif("${_short}" STREQUAL "${_long}")
        # **Keep only the suffix ("-37-g97c4acf[-dirty]"), not the tag name.**
        # The tag names the *last* release, and CMakeLists.txt is bumped before
        # the tag is pushed, so between those two the describe string says the
        # old version: a 0.7.0 build would call itself "0.6.0-144-gfc2e845e" in
        # the title bar and the About dialog -- naming a release it is not.
        # Prepending PROGRAM_VERSION instead means the display version always
        # starts with the plain version, which is what
        # version-display-string-starts-with-the-plain-version asserts (that
        # test fails locally in exactly that window; CI never saw it because
        # the actions checkout has no tags, so describe finds nothing).
        string(REGEX REPLACE "^v?[0-9]+(\\.[0-9]+)*" "" _suffix "${_short}")
        set(_content "#define PROGRAM_VERSION_DESCRIBE_SUFFIX \"${_suffix}\"")
    else()
        set(_content "/* On a tag - use the plain version string */")
    endif()
endif()

# Only touch the file when the content changes, so that a build with no new
# commits does not recompile version.cc (and everything that links it).
set(_previous "")
if(EXISTS "${_out}")
    file(READ "${_out}" _previous)
endif()
if(NOT "${_previous}" STREQUAL "${_content}\n")
    file(MAKE_DIRECTORY "${XYZZY_SOURCE_DIR}/src/core/gen")
    file(WRITE "${_out}" "${_content}\n")
endif()
