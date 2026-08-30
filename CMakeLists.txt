cmake_minimum_required(VERSION 3.16)
project(xyzzy VERSION 0.6.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# Default to Release build if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# ============================================================
# Install layout: "unix" (FHS) or "flat" (Windows-style)
# ============================================================
if(NOT INSTALL_LAYOUT)
    if(WIN32)
        set(INSTALL_LAYOUT "flat")
    else()
        set(INSTALL_LAYOUT "unix")
    endif()
endif()
set(INSTALL_LAYOUT "${INSTALL_LAYOUT}" CACHE STRING "Install layout: unix (FHS) or flat (Windows-style)")

if(INSTALL_LAYOUT STREQUAL "unix")
    set(XYZZY_BIN_DIR "bin")
    set(XYZZY_DATA_DIR "share/xyzzy")
    set(XYZZY_DOC_DIR "share/doc/xyzzy")
    set(XYZZY_ETC_DIR "share/xyzzy/etc")
    set(XYZZY_LISP_DIR "share/xyzzy/lisp")
else()
    set(XYZZY_BIN_DIR ".")
    set(XYZZY_DATA_DIR ".")
    set(XYZZY_DOC_DIR "docs")
    set(XYZZY_ETC_DIR "etc")
    set(XYZZY_LISP_DIR "lisp")
endif()

# ============================================================
# Version description from git
# ============================================================
# The version string that the title bar and the About dialog show comes from
# `git describe`, written into src/core/gen/version-describe.h by
# cmake/git-describe.cmake.  **That script runs on every build**, not only at
# configure time: the commit changes far more often than this file does, and a
# stale hash in the title bar is worse than no hash -- it names a build you are
# not running.  The script rewrites the header only when the content changes.
# Run once now so the header exists for the very first configure.
execute_process(
    COMMAND ${CMAKE_COMMAND} -DXYZZY_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -P ${CMAKE_SOURCE_DIR}/cmake/git-describe.cmake)

# Declaring the header as an OUTPUT is what makes the build graph correct:
# version.cc includes it, so the generator knows to run this before compiling
# and to recompile when it changes.  A custom target with no output does not
# achieve that -- it runs, rewrites the header, and the object file is left
# alone (measured with `ninja -d explain`).
#
# DEPENDS is on the git files that say "the commit moved".  `--dirty` also
# reacts to uncommitted edits, which no single file records, so the -dirty
# suffix can be one build behind.  The hash -- which is what tells a local
# build from a release -- is not.
set(GIT_DESCRIBE_DEPS "")
foreach(f HEAD index)
    if(EXISTS "${CMAKE_SOURCE_DIR}/.git/${f}")
        list(APPEND GIT_DESCRIBE_DEPS "${CMAKE_SOURCE_DIR}/.git/${f}")
    endif()
endforeach()
add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/core/gen/version-describe.h
    COMMAND ${CMAKE_COMMAND} -DXYZZY_SOURCE_DIR=${CMAKE_SOURCE_DIR}
            -P ${CMAKE_SOURCE_DIR}/cmake/git-describe.cmake
    DEPENDS ${GIT_DESCRIBE_DEPS} ${CMAKE_SOURCE_DIR}/cmake/git-describe.cmake
    COMMENT "Updating version-describe.h from git describe"
    VERBATIM)
add_custom_target(xyzzy-version-describe
    DEPENDS ${CMAKE_SOURCE_DIR}/src/core/gen/version-describe.h)

# Generate version.h from template (single source of truth: PROJECT_VERSION)
#
# 3 桁の version を書くと CMake は PROJECT_VERSION_TWEAK を「未定義」ではなく
# 空文字で定義する。そのまま version.h に流すと #define PROGRAM_MINOR_REVISION が
# 値無しになり、version.cc の #if がコンパイルエラーになる。空も 0 に倒す。
if(NOT DEFINED PROJECT_VERSION_TWEAK OR PROJECT_VERSION_TWEAK STREQUAL "")
    set(PROJECT_VERSION_TWEAK 0)
endif()
if(NOT DEFINED PROJECT_VERSION_PATCH OR PROJECT_VERSION_PATCH STREQUAL "")
    set(PROJECT_VERSION_PATCH 0)
endif()
configure_file(
    ${CMAKE_SOURCE_DIR}/src/core/version.h.in
    ${CMAKE_SOURCE_DIR}/src/core/gen/version.h
    @ONLY
)

# ============================================================
# tree-sitter: build from source (static, no runtime DLL)
# ============================================================
include(FetchContent)
# Allow FetchContent_Populate (we manage the targets ourselves).  The policy
# only exists from CMake 3.30, and setting an unknown one is a hard error, so
# this has to be asked for rather than stated: cmake_minimum_required says 3.16,
# and Debian bookworm (the cross build container) ships 3.25.
if(POLICY CMP0169)
    cmake_policy(SET CMP0169 OLD)
endif()
FetchContent_Declare(tree-sitter
    GIT_REPOSITORY https://github.com/tree-sitter/tree-sitter
    GIT_TAG        v0.26.2
    GIT_SHALLOW    TRUE)
FetchContent_GetProperties(tree-sitter)
if(NOT tree-sitter_POPULATED)
    FetchContent_Populate(tree-sitter)
endif()
add_library(tree-sitter-core STATIC
    ${tree-sitter_SOURCE_DIR}/lib/src/lib.c)
target_include_directories(tree-sitter-core PUBLIC
    ${tree-sitter_SOURCE_DIR}/lib/include)
# lib/src holds tree-sitter's trimmed copy of ICU, reached as "unicode/...".
# MSVC finds it without being told, because it resolves a quoted include
# against every directory in the include stack, and lib.c is in lib/src.
# GCC only looks in the directory of the file with the directive, so the
# cross build stops at unicode/utf8.h asking for unicode/umachine.h.
# tree-sitter's own build passes -I lib/src for this reason.
target_include_directories(tree-sitter-core PRIVATE
    ${tree-sitter_SOURCE_DIR}/lib/src)

FetchContent_Declare(tree-sitter-c
    GIT_REPOSITORY https://github.com/tree-sitter/tree-sitter-c
    GIT_TAG        v0.24.1
    GIT_SHALLOW    TRUE)
FetchContent_GetProperties(tree-sitter-c)
if(NOT tree-sitter-c_POPULATED)
    FetchContent_Populate(tree-sitter-c)
endif()
add_library(tree-sitter-c-grammar SHARED
    ${tree-sitter-c_SOURCE_DIR}/src/parser.c)
target_include_directories(tree-sitter-c-grammar PRIVATE
    ${tree-sitter-c_SOURCE_DIR}/src)
set_target_properties(tree-sitter-c-grammar PROPERTIES
    OUTPUT_NAME               "tree-sitter-c"
    PREFIX                    ""
    RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/c"
    LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/c")

FetchContent_Declare(tree-sitter-cpp
    GIT_REPOSITORY https://github.com/tree-sitter/tree-sitter-cpp
    GIT_TAG        v0.23.4
    GIT_SHALLOW    TRUE)
FetchContent_GetProperties(tree-sitter-cpp)
if(NOT tree-sitter-cpp_POPULATED)
    FetchContent_Populate(tree-sitter-cpp)
endif()
file(GLOB tree-sitter-cpp-sources
    "${tree-sitter-cpp_SOURCE_DIR}/src/parser.c"
    "${tree-sitter-cpp_SOURCE_DIR}/src/scanner.c"
    "${tree-sitter-cpp_SOURCE_DIR}/src/scanner.cc")
add_library(tree-sitter-cpp-grammar SHARED ${tree-sitter-cpp-sources})
target_include_directories(tree-sitter-cpp-grammar PRIVATE
    ${tree-sitter-cpp_SOURCE_DIR}/src)
set_target_properties(tree-sitter-cpp-grammar PROPERTIES
    OUTPUT_NAME               "tree-sitter-cpp"
    PREFIX                    ""
    RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/cpp"
    LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/cpp")

FetchContent_Declare(tree-sitter-perl
    GIT_REPOSITORY https://github.com/tree-sitter-perl/tree-sitter-perl
    GIT_TAG        release
    GIT_SHALLOW    TRUE)
FetchContent_GetProperties(tree-sitter-perl)
if(NOT tree-sitter-perl_POPULATED)
    FetchContent_Populate(tree-sitter-perl)
endif()
foreach(_hdr array.h ts_assert.h)
    file(COPY ${tree-sitter_SOURCE_DIR}/lib/src/${_hdr}
         DESTINATION ${tree-sitter-perl_SOURCE_DIR}/src/tree_sitter/)
endforeach()
file(COPY ${tree-sitter_SOURCE_DIR}/lib/src/parser.h
     DESTINATION ${tree-sitter-perl_SOURCE_DIR}/src/tree_sitter/)
file(GLOB tree-sitter-perl-sources
    "${tree-sitter-perl_SOURCE_DIR}/src/parser.c"
    "${tree-sitter-perl_SOURCE_DIR}/src/scanner.c")
add_library(tree-sitter-perl-grammar SHARED ${tree-sitter-perl-sources})
target_include_directories(tree-sitter-perl-grammar PRIVATE
    ${tree-sitter-perl_SOURCE_DIR}/src)
set_target_properties(tree-sitter-perl-grammar PROPERTIES
    OUTPUT_NAME               "tree-sitter-perl"
    PREFIX                    ""
    RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/perl"
    LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/perl")

FetchContent_Declare(tree-sitter-markdown
    GIT_REPOSITORY https://github.com/tree-sitter-grammars/tree-sitter-markdown
    GIT_TAG        v0.3.2
    GIT_SHALLOW    TRUE)
FetchContent_GetProperties(tree-sitter-markdown)
if(NOT tree-sitter-markdown_POPULATED)
    FetchContent_Populate(tree-sitter-markdown)
endif()
# Block grammar
file(GLOB tree-sitter-markdown-block-sources
    "${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown/src/parser.c"
    "${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown/src/scanner.c")
add_library(tree-sitter-markdown-grammar SHARED ${tree-sitter-markdown-block-sources})
target_include_directories(tree-sitter-markdown-grammar PRIVATE
    ${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown/src)
set_target_properties(tree-sitter-markdown-grammar PROPERTIES
    OUTPUT_NAME               "tree-sitter-markdown"
    PREFIX                    ""
    RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/markdown"
    LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/markdown")
# Inline grammar
file(GLOB tree-sitter-markdown-inline-sources
    "${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown-inline/src/parser.c"
    "${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown-inline/src/scanner.c")
add_library(tree-sitter-markdown-inline-grammar SHARED ${tree-sitter-markdown-inline-sources})
target_include_directories(tree-sitter-markdown-inline-grammar PRIVATE
    ${tree-sitter-markdown_SOURCE_DIR}/tree-sitter-markdown-inline/src)
set_target_properties(tree-sitter-markdown-inline-grammar PROPERTIES
    OUTPUT_NAME               "tree-sitter-markdown-inline"
    PREFIX                    ""
    RUNTIME_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/markdown"
    LIBRARY_OUTPUT_DIRECTORY  "${CMAKE_BINARY_DIR}/grammars/markdown")

# 文法をソースの隣にも置く: `lisp/ts.l' は (si:system-root)/grammars/ を見に
# 行き、開発中それはリポジトリのルートである。ビルドの出力そのものはビルド
# ツリーに残す (共有の 1 か所から install すると、x86-64 のパッケージに
# ARM64 のライブラリが入った)。
#
# **POST_BUILD ではなく ALL の custom target にしてある。** POST_BUILD は
# 文法がリンクし直された時だけ動くので、**別のアーキテクチャでビルドすると
# grammars/ が前のアーキのまま残る。** そうなると
# `si:load-ts-grammar' が "Bad EXE format" で落ちるが、
# `ts-register-mode' は ignore-errors の中なので**色が付かないだけに見える**
# (ARM64 の DLL が入ったまま x64 で何か月も気付かなかった)。
# `copy_if_different' なので、同じ物なら mtime も触らない。
add_custom_target(grammars-in-source-tree ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:tree-sitter-c-grammar> "${CMAKE_SOURCE_DIR}/grammars/c/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:tree-sitter-cpp-grammar> "${CMAKE_SOURCE_DIR}/grammars/cpp/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:tree-sitter-perl-grammar> "${CMAKE_SOURCE_DIR}/grammars/perl/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:tree-sitter-markdown-grammar> "${CMAKE_SOURCE_DIR}/grammars/markdown/"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            $<TARGET_FILE:tree-sitter-markdown-inline-grammar> "${CMAKE_SOURCE_DIR}/grammars/markdown/"
    COMMENT "Copying the tree-sitter grammars next to the sources")
add_dependencies(grammars-in-source-tree
    tree-sitter-c-grammar
    tree-sitter-cpp-grammar
    tree-sitter-perl-grammar
    tree-sitter-markdown-grammar
    tree-sitter-markdown-inline-grammar)

# ============================================================
# Find zlib (prefer static library for -static linking)
# ============================================================
set(CMAKE_FIND_LIBRARY_SUFFIXES_SAVE ${CMAKE_FIND_LIBRARY_SUFFIXES})
if(WIN32 AND NOT MSVC)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
endif()
find_package(ZLIB)
set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES_SAVE})
if(NOT ZLIB_FOUND)
    if(MSVC)
        # FetchContent fallback: build zlib from source when not found (e.g. no vcpkg)
        include(FetchContent)
        FetchContent_Declare(
            zlib
            URL https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
            URL_HASH SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
            DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        )
        FetchContent_MakeAvailable(zlib)
        set(ZLIB_INCLUDE_DIRS ${zlib_SOURCE_DIR} ${zlib_BINARY_DIR})
        set(ZLIB_LIBRARIES zlibstatic)
    elseif(WIN32)
        message(FATAL_ERROR "zlib not found. Install with: pacman -S mingw-w64-clang-aarch64-zlib")
    else()
        message(FATAL_ERROR "zlib not found. Install with: sudo apt-get install zlib1g-dev")
    endif()
endif()

# Source and generated directories
set(SRC_DIR ${CMAKE_SOURCE_DIR}/src)
set(CORE_DIR ${CMAKE_SOURCE_DIR}/src/core)
set(WIN32_DIR ${CMAKE_SOURCE_DIR}/src/frontend/win32)
set(GEN_DIR ${CMAKE_SOURCE_DIR}/src/core/gen)
file(MAKE_DIRECTORY ${GEN_DIR})

# The code generators (gen-src1, gen-src2) are built for the target, so when the
# target is not the host they cannot be executed directly.  Cross toolchains set
# CMAKE_CROSSCOMPILING_EMULATOR (cmake/mingw-*.cmake point it at Wine); CMake
# applies it on its own only when a custom command names a target, and these
# name $<TARGET_FILE:...> so that the output can be redirected, so put it in by
# hand.  Empty for a native build, where it expands to nothing.
if(CMAKE_CROSSCOMPILING AND CMAKE_CROSSCOMPILING_EMULATOR)
    set(GEN_LAUNCHER ${CMAKE_CROSSCOMPILING_EMULATOR})
else()
    set(GEN_LAUNCHER)
endif()

# Cross compiling with no emulator at all means the generators cannot be run in
# any way.  That is the ARM64 case: Wine on an x86 host executes x86 machine
# code, so an ARM64 PE cannot be started.  Their output is plain tables and
# declarations, identical for every architecture, and it lands in the source
# tree (src/core/gen/), so a build that can run them leaves it behind for this
# one to use -- tools/x arm-prep does exactly that.
if(CMAKE_CROSSCOMPILING AND NOT CMAKE_CROSSCOMPILING_EMULATOR)
    set(XYZZY_RUN_CODEGEN OFF)
else()
    set(XYZZY_RUN_CODEGEN ON)
endif()

# Common defines
add_compile_definitions(
    STRICT
    __XYZZY__
    PRIVCTRL_NODLL
    _CRT_SECURE_NO_DEPRECATE
    UNICODE_TABLE_STATIC
)
if(WIN32)
    add_compile_definitions(_WIN32)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_definitions(DEBUG DEBUG_GC _DEBUG)
else()
    add_compile_definitions(NDEBUG DEBUG_GC)
endif()

# Compiler-specific flags
if(MSVC)
    add_compile_options(
        /W3
        /EHa     # enable SEH-to-C++ exception translation (_set_se_translator)
        /wd4996  # deprecated functions
        /wd4477  # format string type mismatch
        /wd4312  # conversion to pointer of greater size
        /utf-8   # source files are UTF-8
    )
    # On x86 MSVC, make __stdcall the default calling convention.
    # The original xyzzy used -Gz in its Makefile CXXFLAGS for the same purpose.
    # lfunction_proc_* typedefs use explicit __stdcall; /Gz ensures all
    # function definitions match without per-function annotation.
    # On x64/ARM64 __stdcall is silently ignored (= __cdecl), so /Gz is harmless
    # there too, but we only add it on x86 to match the original intent.
    if(CMAKE_SIZEOF_VOID_P EQUAL 4)
        add_compile_options(/Gz)
    endif()
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(
        -fms-extensions
        -fno-operator-names
        -Wno-invalid-token-paste
        -Wno-format
        -Wno-parentheses
        -Wno-unused-value
        -Wno-switch
        -Wno-dangling-else
        -Wno-deprecated-declarations
        -Wno-writable-strings
        -Wno-c++11-narrowing
        -Wno-invalid-source-encoding
        -Wno-shift-negative-value
    )
    if(WIN32)
        set(CMAKE_RC_FLAGS "--codepage=65001 -I${CMAKE_SOURCE_DIR}/src/core -I${CMAKE_SOURCE_DIR}/src/core/gen")
        # No counterpart to the MSVC /Gz below, deliberately: Clang's
        # -fdefault-calling-conv=stdcall reaches into libc++ as well, where
        # unique_ptr deleters are handed the CRT's __cdecl free and stop
        # compiling.  The Lisp ABI only has to be self-consistent, so on Clang
        # it is __cdecl throughout; see LISP_CALL in src/core/cdecl.h.
    endif()
else()
    # GCC / Clang (non-MSVC)
    add_compile_options(
        -fms-extensions
        -fno-operator-names
        -Wno-format
        -Wno-parentheses
        -Wno-unused-value
        -Wno-switch
        -Wno-dangling-else
        -Wno-deprecated-declarations
        -Wno-write-strings
        -Wno-narrowing
        -Wno-shift-negative-value
    )
    if(WIN32)
        # windres defaults to the host code page and would mis-read the UTF-8
        # sources; it also needs the include path the headers are found through,
        # the same way the Clang branch above sets it up.
        set(CMAKE_RC_FLAGS "--codepage=65001 -I${CMAKE_SOURCE_DIR}/src/core -I${CMAKE_SOURCE_DIR}/src/core/gen")
    endif()
endif()

# ============================================================
# gen-src1/gen-src2: Code generators
# On non-Win32, pre-generated files in src/core/gen/ are used directly.
# ============================================================
if(WIN32)

set(GEN_SRC1_SOURCES
    ${SRC_DIR}/gen-main.cc
    ${SRC_DIR}/gen-stdafx.cc
    ${SRC_DIR}/dpp.cc
    ${SRC_DIR}/gen-ctab.cc
    ${SRC_DIR}/gen-fontrange.cc
    ${SRC_DIR}/gen-ibmext.cc
    ${SRC_DIR}/gen-iso2022state.cc
    ${SRC_DIR}/gen-jisx0212-hash.cc
    ${SRC_DIR}/gen-jisx0212-width.cc
    ${SRC_DIR}/gen-ktab.cc
    ${SRC_DIR}/gen-lucida-width.cc
    ${SRC_DIR}/gen-syms.cc
    ${SRC_DIR}/gen-ucs2tab.cc
    ${SRC_DIR}/gen-utf2sjis.cc
)

if(XYZZY_RUN_CODEGEN)

add_executable(gen-src1 ${GEN_SRC1_SOURCES})
target_compile_definitions(gen-src1 PRIVATE GEN_SRC1 WIN32 _CONSOLE)
if(MSVC)
    target_include_directories(gen-src1 PRIVATE ${SRC_DIR} ${CORE_DIR} ${GEN_DIR})
else()
    target_compile_options(gen-src1 PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")
endif()

# gcc/clang は GNU 拡張モード (-std=gnu++11) で unix / linux / i386 を 1 に定義する。
# DEFKWD2(unix) の引数は STR() に渡る前にマクロ展開されるので、そのままだと
# キーワード名が "1" になり unix と linux が衝突して gen-syms が exit(2) する。
if(NOT MSVC)
    target_compile_options(gen-src1 PRIVATE -Uunix -Ulinux -Ui386)
endif()

# ============================================================
# gen-src1 code generation custom commands
# ============================================================

# dpp: num-arith.d -> num-arith.h (takes args, not stdout)
add_custom_command(
    OUTPUT ${GEN_DIR}/num-arith.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> dpp ${SRC_DIR}/num-arith.d ${GEN_DIR}/num-arith.h
    DEPENDS gen-src1 ${SRC_DIR}/num-arith.d ${SRC_DIR}/dpp.cc
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating num-arith.h"
)

# gen-ctab > chtab.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/chtab.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ctab > ${GEN_DIR}/chtab.cc
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating chtab.cc"
)

# gen-ibmext > ibmext.h
add_custom_command(
    OUTPUT ${GEN_DIR}/ibmext.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ibmext > ${GEN_DIR}/ibmext.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating ibmext.h"
)

# gen-iso2022state > iso2022state.h
add_custom_command(
    OUTPUT ${GEN_DIR}/iso2022state.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-iso2022state > ${GEN_DIR}/iso2022state.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating iso2022state.h"
)

# gen-jisx0212-hash > jisx0212-hash.h
add_custom_command(
    OUTPUT ${GEN_DIR}/jisx0212-hash.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-jisx0212-hash > ${GEN_DIR}/jisx0212-hash.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating jisx0212-hash.h"
)

# gen-ktab > kanjitab.h
add_custom_command(
    OUTPUT ${GEN_DIR}/kanjitab.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ktab > ${GEN_DIR}/kanjitab.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating kanjitab.h"
)

# gen-syms -> vars-decl.h, fns-decl.h, symtable-core.cc, symtable-ed.cc, dumpver.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/vars-decl.h ${GEN_DIR}/fns-decl.h
           ${GEN_DIR}/symtable-core.cc ${GEN_DIR}/symtable-ed.cc ${GEN_DIR}/dumpver.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -vars > ${GEN_DIR}/vars-decl.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -proto > ${GEN_DIR}/fns-decl.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -symtable-core > ${GEN_DIR}/symtable-core.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -symtable-ed > ${GEN_DIR}/symtable-ed.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -version > ${GEN_DIR}/dumpver.cc
    DEPENDS gen-src1 ${SRC_DIR}/gen-syms.cc
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating symbol tables"
)

# gen-utf2sjis > utf2sjis.h
add_custom_command(
    OUTPUT ${GEN_DIR}/utf2sjis.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-utf2sjis > ${GEN_DIR}/utf2sjis.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating utf2sjis.h"
)

# Convenience target for all gen-src1 outputs
add_custom_target(gen-src1-run
    DEPENDS
        ${GEN_DIR}/num-arith.h
        ${GEN_DIR}/chtab.cc
        ${GEN_DIR}/ibmext.h
        ${GEN_DIR}/iso2022state.h
        ${GEN_DIR}/jisx0212-hash.h
        ${GEN_DIR}/kanjitab.h
        ${GEN_DIR}/vars-decl.h
        ${GEN_DIR}/fns-decl.h
        ${GEN_DIR}/symtable-core.cc
        ${GEN_DIR}/symtable-ed.cc
        ${GEN_DIR}/dumpver.cc
        ${GEN_DIR}/utf2sjis.h
)

# ============================================================
# gen-src2: Code generator (stage 2)
# Depends on gen-src1 output (gen-msg.cc #include "chtab.cc")
# ============================================================
set(GEN_SRC2_SOURCES
    ${SRC_DIR}/gen-main.cc
    ${SRC_DIR}/gen-msg.cc
)

add_executable(gen-src2 ${GEN_SRC2_SOURCES})
target_compile_definitions(gen-src2 PRIVATE GEN_SRC2 WIN32 _CONSOLE)
if(MSVC)
    target_include_directories(gen-src2 PRIVATE ${SRC_DIR} ${CORE_DIR} ${GEN_DIR})
else()
    target_compile_options(gen-src2 PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")
endif()
# gen-src2 compilation needs chtab.cc from gen-src1
add_dependencies(gen-src2 gen-src1-run)

# ============================================================
# gen-src2 code generation custom commands
# ============================================================

# gen-msg -> msgcode.h, msgdef.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/msgcode.h ${GEN_DIR}/msgdef.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src2> gen-msg -enum > ${GEN_DIR}/msgcode.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src2> gen-msg -c > ${GEN_DIR}/msgdef.cc
    DEPENDS gen-src2
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating message code"
)

add_custom_target(gen-src2-run
    DEPENDS
        ${GEN_DIR}/msgcode.h
        ${GEN_DIR}/msgdef.cc
)

else() # NOT XYZZY_RUN_CODEGEN

# Nothing to run, so nothing to build either: the generators are build tools,
# not part of the product, and the other architectures compile them.  What the
# rest of this file needs is the output and the two target names.
set(XYZZY_GEN_FILES
    num-arith.h chtab.cc ibmext.h iso2022state.h jisx0212-hash.h kanjitab.h
    vars-decl.h fns-decl.h symtable-core.cc symtable-ed.cc dumpver.cc
    utf2sjis.h msgcode.h msgdef.cc)
foreach(_gen ${XYZZY_GEN_FILES})
    if(NOT EXISTS ${GEN_DIR}/${_gen})
        message(FATAL_ERROR
            "src/core/gen/${_gen} is missing, and the code generators cannot be run "
            "for ${CMAKE_SYSTEM_PROCESSOR} (see cmake/mingw-aarch64.cmake).  Run "
            "\"tools/x arm-prep\" first: it builds them for x86_64 and runs them "
            "under Wine, which leaves the files here.")
    endif()
endforeach()
add_custom_target(gen-src1-run)
add_custom_target(gen-src2-run)

endif() # XYZZY_RUN_CODEGEN

else() # !WIN32

set(GEN_SRC1_SOURCES
    ${SRC_DIR}/gen-main.cc
    ${SRC_DIR}/gen-stdafx.cc
    ${SRC_DIR}/dpp.cc
    ${SRC_DIR}/gen-ctab.cc
    ${SRC_DIR}/gen-fontrange.cc
    ${SRC_DIR}/gen-ibmext.cc
    ${SRC_DIR}/gen-iso2022state.cc
    ${SRC_DIR}/gen-jisx0212-hash.cc
    ${SRC_DIR}/gen-jisx0212-width.cc
    ${SRC_DIR}/gen-ktab.cc
    ${SRC_DIR}/gen-lucida-width.cc
    ${SRC_DIR}/gen-syms.cc
    ${SRC_DIR}/gen-ucs2tab.cc
    ${SRC_DIR}/gen-utf2sjis.cc
)

add_executable(gen-src1 ${GEN_SRC1_SOURCES})
target_compile_definitions(gen-src1 PRIVATE GEN_SRC1 _CONSOLE)
target_compile_options(gen-src1 PRIVATE
    "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")

# gcc/clang は GNU 拡張モード (-std=gnu++11) で unix / linux / i386 を 1 に定義する。
# DEFKWD2(unix) の引数は STR() に渡る前にマクロ展開されるので、そのままだと
# キーワード名が "1" になり unix と linux が衝突して gen-syms が exit(2) する。
if(NOT MSVC)
    target_compile_options(gen-src1 PRIVATE -Uunix -Ulinux -Ui386)
endif()

add_custom_command(
    OUTPUT ${GEN_DIR}/num-arith.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> dpp ${SRC_DIR}/num-arith.d ${GEN_DIR}/num-arith.h
    DEPENDS gen-src1 ${SRC_DIR}/num-arith.d ${SRC_DIR}/dpp.cc
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating num-arith.h"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/chtab.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ctab > ${GEN_DIR}/chtab.cc
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating chtab.cc"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/ibmext.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ibmext > ${GEN_DIR}/ibmext.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating ibmext.h"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/iso2022state.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-iso2022state > ${GEN_DIR}/iso2022state.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating iso2022state.h"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/jisx0212-hash.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-jisx0212-hash > ${GEN_DIR}/jisx0212-hash.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating jisx0212-hash.h"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/kanjitab.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-ktab > ${GEN_DIR}/kanjitab.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating kanjitab.h"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/vars-decl.h ${GEN_DIR}/fns-decl.h
           ${GEN_DIR}/symtable-core.cc ${GEN_DIR}/symtable-ed.cc ${GEN_DIR}/dumpver.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -vars > ${GEN_DIR}/vars-decl.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -proto > ${GEN_DIR}/fns-decl.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -symtable-core > ${GEN_DIR}/symtable-core.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -symtable-ed > ${GEN_DIR}/symtable-ed.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-syms -version > ${GEN_DIR}/dumpver.cc
    DEPENDS gen-src1 ${SRC_DIR}/gen-syms.cc
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating symbol tables"
)
add_custom_command(
    OUTPUT ${GEN_DIR}/utf2sjis.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src1> gen-utf2sjis > ${GEN_DIR}/utf2sjis.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating utf2sjis.h"
)

add_custom_target(gen-src1-run
    DEPENDS
        ${GEN_DIR}/num-arith.h
        ${GEN_DIR}/chtab.cc
        ${GEN_DIR}/ibmext.h
        ${GEN_DIR}/iso2022state.h
        ${GEN_DIR}/jisx0212-hash.h
        ${GEN_DIR}/kanjitab.h
        ${GEN_DIR}/vars-decl.h
        ${GEN_DIR}/fns-decl.h
        ${GEN_DIR}/symtable-core.cc
        ${GEN_DIR}/symtable-ed.cc
        ${GEN_DIR}/dumpver.cc
        ${GEN_DIR}/utf2sjis.h
)

set(GEN_SRC2_SOURCES
    ${SRC_DIR}/gen-main.cc
    ${SRC_DIR}/gen-msg.cc
)

add_executable(gen-src2 ${GEN_SRC2_SOURCES})
target_compile_definitions(gen-src2 PRIVATE GEN_SRC2 _CONSOLE)
target_compile_options(gen-src2 PRIVATE
    "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")
add_dependencies(gen-src2 gen-src1-run)
# iconv is needed for UTF-8 -> CP932 conversion in gen-msg.cc
find_library(ICONV_LIB iconv)
if(ICONV_LIB)
    target_link_libraries(gen-src2 PRIVATE ${ICONV_LIB})
endif()

add_custom_command(
    OUTPUT ${GEN_DIR}/msgcode.h ${GEN_DIR}/msgdef.cc
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src2> gen-msg -enum > ${GEN_DIR}/msgcode.h
    COMMAND ${GEN_LAUNCHER} $<TARGET_FILE:gen-src2> gen-msg -c > ${GEN_DIR}/msgdef.cc
    DEPENDS gen-src2
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating message code"
)

add_custom_target(gen-src2-run
    DEPENDS
        ${GEN_DIR}/msgcode.h
        ${GEN_DIR}/msgdef.cc
)

endif() # WIN32

# ============================================================
# xyzzy-core: Static library (Lisp interpreter + text buffer)
# ============================================================
set(CORE_SOURCES
    ${CORE_DIR}/alloc.cc
    ${CORE_DIR}/array.cc
    ${CORE_DIR}/backq.cc
    ${CORE_DIR}/bignum.cc
    ${CORE_DIR}/Buffer.cc
    ${CORE_DIR}/byte-stream.cc
    ${CORE_DIR}/bytecode.cc
    ${CORE_DIR}/ces.cc
    ${CORE_DIR}/conf-io.cc
    ${CORE_DIR}/dll-call.cc
    ${CORE_DIR}/quit-poll.cc
    ${CORE_DIR}/utimer.cc
    ${CORE_DIR}/char.cc
    ${CORE_DIR}/chname.cc
    ${CORE_DIR}/chunk.cc
    ${CORE_DIR}/data.cc
    ${CORE_DIR}/debug.cc
    ${CORE_DIR}/encdec.cc
    ${CORE_DIR}/eaw.cc
    ${CORE_DIR}/encoding.cc
    ${CORE_DIR}/fontmap.cc
    ${CORE_DIR}/environ.cc
    ${CORE_DIR}/eval.cc
    ${CORE_DIR}/except.cc
    ${CORE_DIR}/fileio.cc
    ${CORE_DIR}/glob.cc
    ${CORE_DIR}/guess.cc
    ${CORE_DIR}/gzip.cc
    ${CORE_DIR}/hash.cc
    ${CORE_DIR}/hashpjw.cc
    ${CORE_DIR}/insdel.cc
    ${CORE_DIR}/kanji.cc
    ${CORE_DIR}/keymap.cc
    ${CORE_DIR}/lex.cc
    ${CORE_DIR}/list.cc
    ${CORE_DIR}/lprint.cc
    ${CORE_DIR}/lread.cc
    ${CORE_DIR}/md5c.cc
    ${CORE_DIR}/move.cc
    ${CORE_DIR}/number.cc
    ${CORE_DIR}/package.cc
    ${CORE_DIR}/pathname.cc
    ${CORE_DIR}/pred.cc
    ${CORE_DIR}/random.cc
    ${CORE_DIR}/regex.cc
    ${CORE_DIR}/search.cc
    ${CORE_DIR}/sequence.cc
    ${CORE_DIR}/sha1.cc
    ${CORE_DIR}/sha2.cc
    ${CORE_DIR}/signal.cc
    ${CORE_DIR}/StrBuf.cc
    ${CORE_DIR}/stream.cc
    ${CORE_DIR}/string.cc
    ${CORE_DIR}/structure.cc
    ${CORE_DIR}/symbol.cc
    ${CORE_DIR}/symtable.cc
    ${CORE_DIR}/syntax.cc
    ${CORE_DIR}/system.cc
    ${CORE_DIR}/ucs2.cc
    ${CORE_DIR}/undo.cc
    ${CORE_DIR}/utils.cc
    ${CORE_DIR}/vector.cc
    ${CORE_DIR}/version.cc
    ${CORE_DIR}/wstream.cc
    ${CORE_DIR}/xlist.cc
    ${CORE_DIR}/sock.cc
    ${CORE_DIR}/sockinet.cc
    ${CORE_DIR}/sockssl.cc
    ${CORE_DIR}/resolver.cc
    ${CORE_DIR}/mman.cc
    ${CORE_DIR}/cmdloop.cc
    ${CORE_DIR}/completion.cc
    ${CORE_DIR}/minibuffer-read.cc
    ${CORE_DIR}/window-lisp.cc
    ${CORE_DIR}/process-lisp.cc
    ${CORE_DIR}/menu-lisp.cc
    ${CORE_DIR}/glyph.cc
    ${CORE_DIR}/term.cc
    ${CORE_DIR}/term-lisp.cc
    ${CORE_DIR}/dsfmt/dSFMT.cc
    # Generated sources (compiled standalone; gen/symtable-core.cc is #include'd by core/symtable.cc)
    ${GEN_DIR}/chtab.cc
    ${GEN_DIR}/dumpver.cc
    ${GEN_DIR}/msgdef.cc
)

# The filesystem seam (src/core/vfs.h, class WINFS) is filled in per platform.
# On Windows that is src/frontend/win32/vfs.cc, which the GUI targets compile
# directly; everywhere else it is this, in core, because every POSIX frontend
# needs the same one.
if(NOT WIN32)
    list(APPEND CORE_SOURCES ${CORE_DIR}/vfs-posix.cc)
    # si:load-dll-module の POSIX 版 (dlopen)。呼び出しの側 (make-c-function)
    # はまだ無い -- issue #133 を参照。
    list(APPEND CORE_SOURCES ${CORE_DIR}/dll-posix.cc)
    # INI ファイルの読み書き (Get/WritePrivateProfileStringW)。設定の
    # 読み書き (conf-io.cc) がこの 2 つの上に建っている -- issue #143。
    list(APPEND CORE_SOURCES ${CORE_DIR}/ini-posix.cc)
endif()

add_library(xyzzy-core STATIC ${CORE_SOURCES})
# version.cc reads gen/version-describe.h; make sure it is current first.
add_dependencies(xyzzy-core xyzzy-version-describe)
target_compile_definitions(xyzzy-core PRIVATE UNICODE _UNICODE DSFMT_MEXP=19937)
if(MSVC)
    target_include_directories(xyzzy-core PRIVATE ${CORE_DIR} ${GEN_DIR} ${SRC_DIR})
else()
    target_compile_options(xyzzy-core PRIVATE "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}" "SHELL:-iquote ${SRC_DIR}")
    # number.cc includes gen/num-arith.h which triggers a Clang 14 -O3 ARM64
    # mis-optimization in arithmetic dispatch switches.  Compile at -O1.
    set_source_files_properties(${CORE_DIR}/number.cc PROPERTIES COMPILE_OPTIONS "-O1")
endif()
target_include_directories(xyzzy-core PRIVATE ${ZLIB_INCLUDE_DIRS})
add_dependencies(xyzzy-core gen-src1-run gen-src2-run)

# ============================================================
# Win32 frontend sources (GUI + platform layer)
# Only build on Windows
# ============================================================
if(WIN32)
set(WIN32_SOURCES
    # UI
    ${CORE_DIR}/window-config.cc
    ${CORE_DIR}/textprop-colors.cc
    ${CORE_DIR}/minibuffer-message.cc
    ${WIN32_DIR}/Window.cc
    ${WIN32_DIR}/disp.cc
    ${WIN32_DIR}/colors.cc
    ${WIN32_DIR}/font.cc
    ${WIN32_DIR}/menu.cc
    ${WIN32_DIR}/dialogs.cc
    ${WIN32_DIR}/ldialog.cc
    ${WIN32_DIR}/ChooseFont.cc
    ${WIN32_DIR}/ColorDialog.cc
    ${WIN32_DIR}/msgbox.cc
    ${WIN32_DIR}/statarea.cc
    ${WIN32_DIR}/minibuf.cc
    ${WIN32_DIR}/popup.cc
    ${WIN32_DIR}/popupl.cc
    ${WIN32_DIR}/pane.cc
    ${WIN32_DIR}/filer.cc
    ${WIN32_DIR}/dockbar.cc
    ${WIN32_DIR}/buffer-bar.cc
    ${WIN32_DIR}/fnkey.cc
    ${WIN32_DIR}/preview.cc
    ${WIN32_DIR}/print.cc
    ${WIN32_DIR}/printdlg.cc
    ${WIN32_DIR}/privctrl/privctrl.cc
    ${WIN32_DIR}/privctrl/listviewex.cc
    ${WIN32_DIR}/privctrl/url.cc
    ${WIN32_DIR}/stdctl.cc
    ${WIN32_DIR}/ctl3d.cc
    ${WIN32_DIR}/wheel.cc
    ${WIN32_DIR}/mouse.cc
    # Platform
    ${WIN32_DIR}/init.cc
    ${WIN32_DIR}/toplev.cc
    ${WIN32_DIR}/kbd.cc
    ${WIN32_DIR}/gime.cc
    ${WIN32_DIR}/sysdep.cc
    ${WIN32_DIR}/conf.cc
    ${WIN32_DIR}/vfs.cc
    ${WIN32_DIR}/thread.cc
    ${WIN32_DIR}/monitor.cc
    ${WIN32_DIR}/binfo.cc
    ${WIN32_DIR}/doc.cc
    # Win32 specific
    ${WIN32_DIR}/com.cc
    ${WIN32_DIR}/oledata.cc
    ${WIN32_DIR}/dde.cc
    ${WIN32_DIR}/xdde.cc
    ${WIN32_DIR}/dll.cc
    # tree-sitter 本体は core にある (両フロントエンドが使う)。stdcall の橋は
    # プリビルド DLL が stdcall な Win32 だけの話なので、こちらに残す。
    ${CORE_DIR}/ts.cc
    ${WIN32_DIR}/ts_stdcall_bridge.c
    ${WIN32_DIR}/DnD.cc
    ${WIN32_DIR}/clipboard.cc
    ${WIN32_DIR}/appid.cc
    ${WIN32_DIR}/arc-if.cc
    ${WIN32_DIR}/archiver.cc
    ${WIN32_DIR}/guid.cc
    ${WIN32_DIR}/process.cc
    ${WIN32_DIR}/listen.cc
    ${WIN32_DIR}/ipc.cc
    ${WIN32_DIR}/edict.cc
    ${WIN32_DIR}/usertab.cc
    ${WIN32_DIR}/abbrev.cc
    ${WIN32_DIR}/usertool.cc
    ${WIN32_DIR}/winhelp.cc
    # Support
    ${WIN32_DIR}/assert.cc
    ${WIN32_DIR}/stdafx.cc
    # Symbol table (editor functions)
    ${WIN32_DIR}/symtable-ed.cc
)

# On x86 MSVC: ts_stdcall_bridge.c provides __stdcall wrappers that forward to
# tree-sitter-core.lib's __cdecl exports via /ALTERNATENAME.  This bridges the
# /Gz global default (project) with tree-sitter-core built before /Gz was added.

set(XYZZY_LINK_LIBS
    xyzzy-core
    ${ZLIB_LIBRARIES}
    tree-sitter-core
    comctl32
    imm32
    mpr
    rpcrt4
    wsock32
    crypt32
    secur32
    ole32
    oleaut32
    uuid
)

# ============================================================
# xyzzy: Main GUI application
# ============================================================
add_executable(xyzzy WIN32 ${WIN32_SOURCES})
target_compile_definitions(xyzzy PRIVATE UNICODE _UNICODE DSFMT_MEXP=19937)
if(MSVC)
    target_include_directories(xyzzy PRIVATE ${CORE_DIR} ${WIN32_DIR} ${WIN32_DIR}/privctrl ${GEN_DIR})
else()
    target_compile_options(xyzzy PRIVATE "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${WIN32_DIR}" "SHELL:-iquote ${WIN32_DIR}/privctrl" "SHELL:-iquote ${GEN_DIR}")
endif()
target_include_directories(xyzzy PRIVATE ${ZLIB_INCLUDE_DIRS})
target_link_libraries(xyzzy PRIVATE ${XYZZY_LINK_LIBS})

# Static linking (no DLL dependencies on MSYS2 runtime)
if(NOT MSVC)
    target_link_options(xyzzy PRIVATE -static -Wl,--stack,0x2000000)
else()
    # /LARGEADDRESSAWARE: on 32-bit (x86), doubles the usable address space
    # from ~2GB to ~4GB under WOW64. link.exe does not set this by default
    # (unlike mingw/lld, which does) -- without it, a large project-find-file
    # scan on a real project can exhaust the 32-bit process's address space.
    # A no-op for x64/ARM64, where it is already the default.
    target_link_options(xyzzy PRIVATE /STACK:0x2000000 /MANIFEST:NO /LARGEADDRESSAWARE)
endif()

# Resource file (windres needs -I, not -iquote, for include paths)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzy PRIVATE ${WIN32_DIR}/xyzzy.rc)
    set_source_files_properties(${WIN32_DIR}/xyzzy.rc PROPERTIES
        OBJECT_DEPENDS "${CORE_DIR}/resource.h"
        INCLUDE_DIRECTORIES "${GEN_DIR};${CORE_DIR};${WIN32_DIR}")
endif()

# ============================================================
# xyzzy-batch: Console version for batch operations (byte-compile, etc.)
# No WIN32 → console subsystem, so execute_process can wait for it.
# batch-main.cc provides main() which calls WinMain(SW_HIDE).
# ============================================================
add_executable(xyzzy-batch ${WIN32_SOURCES} ${WIN32_DIR}/batch-main.cc)
target_compile_definitions(xyzzy-batch PRIVATE UNICODE _UNICODE DSFMT_MEXP=19937)
if(MSVC)
    target_include_directories(xyzzy-batch PRIVATE ${CORE_DIR} ${WIN32_DIR} ${WIN32_DIR}/privctrl ${GEN_DIR})
else()
    target_compile_options(xyzzy-batch PRIVATE "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${WIN32_DIR}" "SHELL:-iquote ${WIN32_DIR}/privctrl" "SHELL:-iquote ${GEN_DIR}")
endif()
target_include_directories(xyzzy-batch PRIVATE ${ZLIB_INCLUDE_DIRS})
target_link_libraries(xyzzy-batch PRIVATE ${XYZZY_LINK_LIBS})
if(NOT MSVC)
    target_link_options(xyzzy-batch PRIVATE -static -Wl,--stack,0x2000000)
else()
    # See the xyzzy target above for why /LARGEADDRESSAWARE is here.
    target_link_options(xyzzy-batch PRIVATE /STACK:0x2000000 /MANIFEST:NO /LARGEADDRESSAWARE)
endif()
if(CMAKE_RC_COMPILER)
    target_sources(xyzzy-batch PRIVATE ${WIN32_DIR}/xyzzy.rc)
    set_source_files_properties(${WIN32_DIR}/xyzzy.rc PROPERTIES
        OBJECT_DEPENDS "${CORE_DIR}/resource.h"
        INCLUDE_DIRECTORIES "${GEN_DIR};${CORE_DIR};${WIN32_DIR}")
endif()

endif() # WIN32 (end of xyzzy, xyzzy-batch GUI targets)

# ============================================================
# xyzzy-cli: CLI frontend (links only xyzzy-core, no Win32 GUI)
# Core separation quality test - exposes leaked dependencies.
# ============================================================
set(CLI_DIR ${CMAKE_SOURCE_DIR}/src/frontend/cli)
set(CLI_SOURCES
    ${CLI_DIR}/cli-main.cc
    ${CLI_DIR}/cli-stubs.cc
    ${CLI_DIR}/cli-symtable-ed.cc
)

add_executable(xyzzy-cli ${CLI_SOURCES})
target_compile_definitions(xyzzy-cli PRIVATE UNICODE _UNICODE DSFMT_MEXP=19937)
if(MSVC)
    target_include_directories(xyzzy-cli PRIVATE ${CORE_DIR} ${GEN_DIR})
else()
    target_compile_options(xyzzy-cli PRIVATE "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")
endif()
target_include_directories(xyzzy-cli PRIVATE ${ZLIB_INCLUDE_DIRS})
if(WIN32)
    target_link_libraries(xyzzy-cli PRIVATE
        xyzzy-core
        ${ZLIB_LIBRARIES}
        mpr       # WNetConnectionDialog, WNetOpenEnum (pathname.cc, vfs stubs)
        rpcrt4    # UUID functions (system.cc)
        wsock32   # ntohs etc. (sock.cc in xyzzy-core)
        crypt32   # Certificate chain (sockssl.cc)
        secur32   # SChannel/SSPI (sockssl.cc)
    )
    if(NOT MSVC)
        target_link_options(xyzzy-cli PRIVATE -static -Wl,--stack,0x2000000)
        if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            target_link_options(xyzzy-cli PRIVATE -Wl,--error-limit=0)
        endif()
    else()
        # See the xyzzy target above for why /LARGEADDRESSAWARE is here.
        target_link_options(xyzzy-cli PRIVATE /STACK:0x2000000 /LARGEADDRESSAWARE)
    endif()
else()
    target_link_libraries(xyzzy-cli PRIVATE
        xyzzy-core
        ${ZLIB_LIBRARIES}
        pthread
    )
endif()

# ============================================================
# xyzzy-ncurses: ncurses terminal frontend (Linux/BSD/POSIX)
# ============================================================
if(NOT WIN32)
    # Prefer ncursesw (wide character support) over plain ncurses
    find_library(NCURSESW_LIBRARY ncursesw)
    find_path(NCURSESW_INCLUDE_DIR ncurses.h PATH_SUFFIXES ncursesw)
    # On some systems (e.g. Homebrew on macOS) ncurses.h lives in a
    # ncursesw/ subdirectory; we need both that directory and its parent
    # so that #include <ncurses.h> resolves to the wide-char version.
    if(NCURSESW_INCLUDE_DIR)
        get_filename_component(NCURSESW_INCLUDE_PARENT "${NCURSESW_INCLUDE_DIR}" DIRECTORY)
        if(NOT "${NCURSESW_INCLUDE_PARENT}" STREQUAL "${NCURSESW_INCLUDE_DIR}")
            list(APPEND NCURSESW_INCLUDE_DIR "${NCURSESW_INCLUDE_PARENT}")
        endif()
    endif()
    if(NCURSESW_LIBRARY AND NCURSESW_INCLUDE_DIR)
        set(NCURSES_DIR ${CMAKE_SOURCE_DIR}/src/frontend/ncurses)
        set(NCURSES_SOURCES
            # Shared with the Win32 frontend; not in CORE_SOURCES because
            # xyzzy-cli has no windows to configure and cannot satisfy the
            # Window methods it calls (see src/core/window-config.cc).
            ${CORE_DIR}/window-config.cc
            ${CORE_DIR}/textprop-colors.cc
            ${CORE_DIR}/minibuffer-message.cc
            ${CORE_DIR}/ts.cc
            ${CORE_DIR}/abbrev-columns.cc
            ${NCURSES_DIR}/ncurses-main.cc
            ${NCURSES_DIR}/ncurses-stubs.cc
            ${NCURSES_DIR}/ncurses-kbd.cc
            ${NCURSES_DIR}/ncurses-process.cc
            ${NCURSES_DIR}/ncurses-dialog.cc
            ${NCURSES_DIR}/ncurses-symtable-ed.cc
        )

        add_executable(xyzzy-ncurses ${NCURSES_SOURCES})
        target_compile_definitions(xyzzy-ncurses PRIVATE UNICODE _UNICODE NCURSES_WIDECHAR=1 DSFMT_MEXP=19937)
        target_compile_options(xyzzy-ncurses PRIVATE
            "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}" "SHELL:-iquote ${SRC_DIR}")
        target_include_directories(xyzzy-ncurses PRIVATE ${ZLIB_INCLUDE_DIRS} ${NCURSESW_INCLUDE_DIR})
        target_link_libraries(xyzzy-ncurses PRIVATE
            xyzzy-core
            ${ZLIB_LIBRARIES}
            ${NCURSESW_LIBRARY}
            tree-sitter-core
            pthread
            util
            # 文法は実行時に dlopen する。glibc 2.34 以降は libc に入って
            # いるが、古い glibc と BSD では -ldl が要る。
            ${CMAKE_DL_LIBS}
        )
        # Increase the default stack to 32MB so Lisp loading doesn't overflow.
        # macOS uses -Wl,-stack_size,<hex bytes> to set the main thread stack.
        if(APPLE)
            target_link_options(xyzzy-ncurses PRIVATE -Wl,-stack_size,0x1000000)
        elseif(UNIX)
            target_link_options(xyzzy-ncurses PRIVATE -Wl,-z,stacksize=0x1000000)
        endif()
        # Embed data directory path for runtime file lookup
        if(INSTALL_LAYOUT STREQUAL "unix")
            target_compile_definitions(xyzzy-ncurses PRIVATE
                "XYZZY_DATA_DIR=\"${CMAKE_INSTALL_PREFIX}/${XYZZY_DATA_DIR}\"")
        endif()
        # Install as "xyzzy" on Unix (single binary with --batch)
        set_target_properties(xyzzy-ncurses PROPERTIES OUTPUT_NAME xyzzy)
        install(TARGETS xyzzy-ncurses RUNTIME DESTINATION ${XYZZY_BIN_DIR})
        install(DIRECTORY ${CMAKE_SOURCE_DIR}/lisp/ DESTINATION ${XYZZY_LISP_DIR}
            FILES_MATCHING PATTERN "*.l" PATTERN "*.lc"
            PATTERN "wip" EXCLUDE)   # Win32-specific DLL wrappers
        install(DIRECTORY ${CMAKE_SOURCE_DIR}/etc/ DESTINATION ${XYZZY_ETC_DIR}
            PATTERN "*.bmp" EXCLUDE) # Win32 toolbar bitmaps
        # docs/user/ only -- docs/dev/ and the release notes are for the repo,
        # not the package (see docs/dev/README.md).
        install(DIRECTORY ${CMAKE_SOURCE_DIR}/docs/user/ DESTINATION ${XYZZY_DOC_DIR})
        install(FILES ${CMAKE_SOURCE_DIR}/LICENSE DESTINATION ${XYZZY_DOC_DIR})
        install(FILES ${CMAKE_SOURCE_DIR}/LEGAL.md DESTINATION ${XYZZY_DOC_DIR} OPTIONAL)

        # Bytecompile: compile .l -> .lc using ncurses --batch
        add_custom_target(bytecompile
            COMMAND ${CMAKE_COMMAND}
                -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
                -DXYZZY_EXE=$<TARGET_FILE:xyzzy-ncurses>
                -P ${CMAKE_SOURCE_DIR}/cmake/bytecompile-ncurses.cmake
            DEPENDS xyzzy-ncurses
            COMMENT "Byte-compiling Lisp files (ncurses --batch)"
        )
    else()
        message(STATUS "ncursesw not found - skipping xyzzy-ncurses target")
    endif()
endif()

# ============================================================
# Win32-only targets
# ============================================================
if(WIN32)

# xyzzycli: Command-line launcher
add_executable(xyzzycli WIN32 ${WIN32_DIR}/xyzzycli.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzycli PRIVATE ${WIN32_DIR}/xyzzycli.rc)
    set_source_files_properties(${WIN32_DIR}/xyzzycli.rc PROPERTIES
        INCLUDE_DIRECTORIES "${WIN32_DIR}")
endif()
target_compile_definitions(xyzzycli PRIVATE UNICODE _UNICODE)
if(MSVC)
    target_include_directories(xyzzycli PRIVATE ${WIN32_DIR} ${CORE_DIR})
else()
    target_compile_options(xyzzycli PRIVATE "SHELL:-iquote ${WIN32_DIR}" "SHELL:-iquote ${CORE_DIR}")
endif()
if(NOT MSVC)
    target_link_options(xyzzycli PRIVATE -static)
endif()

# xyzzyenv: Environment utility
add_executable(xyzzyenv ${WIN32_DIR}/xyzzyenv.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzyenv PRIVATE ${WIN32_DIR}/xyzzyenv.rc)
endif()
target_compile_definitions(xyzzyenv PRIVATE UNICODE _UNICODE)
if(NOT MSVC)
    target_link_options(xyzzyenv PRIVATE -static)
endif()

# Browser.dll: WebBrowser ActiveX plugin (ATL-free, IWebBrowser2)
add_library(browser SHARED
    ${WIN32_DIR}/Browser.cpp
    ${WIN32_DIR}/xpi.cc
    ${WIN32_DIR}/Browser.def
)
target_compile_definitions(browser PRIVATE BROWSER_EXPORTS WIN32 UNICODE _UNICODE)
if(MSVC)
    target_include_directories(browser PRIVATE ${WIN32_DIR})
else()
    target_compile_options(browser PRIVATE
        "SHELL:-iquote ${WIN32_DIR}"
        -Wno-pragma-pack)
    target_link_options(browser PRIVATE -static)
endif()
target_link_libraries(browser PRIVATE ole32 oleaut32 uuid)
set_target_properties(browser PROPERTIES
    OUTPUT_NAME "Browser"
    PREFIX ""
)

# TreeView.dll: TreeView common control plugin (MFC-free)
add_library(treeview SHARED
    ${WIN32_DIR}/TreeView.cpp
    ${WIN32_DIR}/xpi.cc
    ${WIN32_DIR}/TreeView.def
)
target_compile_definitions(treeview PRIVATE TREEVIEW_EXPORTS WIN32 UNICODE _UNICODE)
if(MSVC)
    target_include_directories(treeview PRIVATE ${WIN32_DIR})
else()
    target_compile_options(treeview PRIVATE
        "SHELL:-iquote ${WIN32_DIR}")
    target_link_options(treeview PRIVATE -static)
endif()
target_link_libraries(treeview PRIVATE comctl32)
set_target_properties(treeview PROPERTIES
    OUTPUT_NAME "TreeView"
    PREFIX ""
)

# tail-f: File monitoring utility (etc/tail-f.exe)
add_executable(tail-f ${SRC_DIR}/etc/tail-f.cc)
if(NOT MSVC)
    target_link_options(tail-f PRIVATE -static)
endif()

# Bytecompile: compile .l -> .lc and generate dump image
add_custom_target(bytecompile
    COMMAND ${CMAKE_COMMAND}
        -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
        -DXYZZY_EXE=$<TARGET_FILE:xyzzy-batch>
        -P ${CMAKE_SOURCE_DIR}/cmake/bytecompile.cmake
    DEPENDS xyzzy-batch
    COMMENT "Byte-compiling Lisp files and generating dump image"
)

# Testing (Win32 GUI tests)
enable_testing()
add_test(
    NAME xyzzy-unit-tests
    COMMAND ${CMAKE_COMMAND} -E env
        "XYZZYHOME=${CMAKE_SOURCE_DIR}"
        $<TARGET_FILE:xyzzy-batch> -q -load misc/run-tests-batch.l
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)
set_tests_properties(xyzzy-unit-tests PROPERTIES
    TIMEOUT 120
    ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:C:/msys64/clangarm64/bin"
    PASS_REGULAR_EXPRESSION "Total [0-9]+ tests: [0-9]+ passed, [0-4] failed")

# Install (Win32)
install(TARGETS xyzzy xyzzycli xyzzyenv browser treeview RUNTIME DESTINATION ${XYZZY_BIN_DIR})
install(TARGETS tail-f RUNTIME DESTINATION ${XYZZY_ETC_DIR})
install(DIRECTORY ${CMAKE_SOURCE_DIR}/lisp/ DESTINATION ${XYZZY_LISP_DIR} FILES_MATCHING PATTERN "*.l" PATTERN "*.lc")
# The .lc are not interchangeable between targets (the reader fixes pointer
# widths while compiling, see lisp/foreign.l), and they live in the shared
# source tree, so `package` ships whatever the last byte-compile produced --
# silently, if that was another target.  Ship the stamp that says which one it
# was so a mismatched package can be told apart from a good one.
install(FILES ${CMAKE_SOURCE_DIR}/lisp/.bytecompile-arch
        DESTINATION ${XYZZY_LISP_DIR} OPTIONAL)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/etc/ DESTINATION ${XYZZY_ETC_DIR})
# docs/user/ only -- docs/dev/ and the release notes are for the repo, not the
# package (see docs/dev/README.md).
install(DIRECTORY ${CMAKE_SOURCE_DIR}/docs/user/ DESTINATION ${XYZZY_DOC_DIR})
install(DIRECTORY ${CMAKE_SOURCE_DIR}/reference/ DESTINATION ${XYZZY_DOC_DIR}/reference OPTIONAL)
install(FILES ${CMAKE_SOURCE_DIR}/LICENSE DESTINATION ${XYZZY_DOC_DIR})
install(FILES ${CMAKE_SOURCE_DIR}/LEGAL.md DESTINATION ${XYZZY_DOC_DIR} OPTIONAL)

endif() # WIN32

# ============================================================
# Cross-platform tools
# ============================================================

# gendic: EDICT -> xyzzy binary dictionary converter
add_executable(gendic ${SRC_DIR}/gendic.cc)
if(MSVC)
    target_compile_options(gendic PRIVATE /W3)
else()
    target_compile_options(gendic PRIVATE -Wall -std=c++17)
    if(WIN32)
        target_link_options(gendic PRIVATE -static)
    endif()
endif()

# ============================================================
# Cross-platform install
# ============================================================
install(TARGETS xyzzy-cli RUNTIME DESTINATION bin)
install(TARGETS gendic RUNTIME DESTINATION bin)

# ============================================================
# tree-sitter grammars
#
# lisp/ts.l looks for them under (si:system-root)/grammars/<lang>/, the shared
# library and its highlights.scm side by side, so that is the layout to install.
# Without this the packages had the lisp side of tree-sitter and none of the
# grammars, which means no highlighting for the modes that use it.
#
# The libraries come from the targets rather than from grammars/ in the source
# tree: the build writes its output there (RUNTIME_OUTPUT_DIRECTORY) and the
# committed .dll files are still sitting next to it, so reading the directory
# can pick up a library built for another target.  The queries do come from the
# source tree; they are text.
# ============================================================
install(TARGETS tree-sitter-c-grammar
        RUNTIME DESTINATION ${XYZZY_DATA_DIR}/grammars/c
        LIBRARY DESTINATION ${XYZZY_DATA_DIR}/grammars/c)
install(TARGETS tree-sitter-cpp-grammar
        RUNTIME DESTINATION ${XYZZY_DATA_DIR}/grammars/cpp
        LIBRARY DESTINATION ${XYZZY_DATA_DIR}/grammars/cpp)
install(TARGETS tree-sitter-perl-grammar
        RUNTIME DESTINATION ${XYZZY_DATA_DIR}/grammars/perl
        LIBRARY DESTINATION ${XYZZY_DATA_DIR}/grammars/perl)
install(TARGETS tree-sitter-markdown-grammar tree-sitter-markdown-inline-grammar
        RUNTIME DESTINATION ${XYZZY_DATA_DIR}/grammars/markdown
        LIBRARY DESTINATION ${XYZZY_DATA_DIR}/grammars/markdown)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/grammars/
        DESTINATION ${XYZZY_DATA_DIR}/grammars
        FILES_MATCHING PATTERN "*.scm")

# ============================================================
# CPack: packaging
# ============================================================
set(CPACK_PACKAGE_NAME "xyzzy")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_GENERATOR "ZIP")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
set(CPACK_PACKAGE_FILE_NAME "xyzzy-${PROJECT_VERSION}")
include(CPack)
