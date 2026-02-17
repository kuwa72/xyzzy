cmake_minimum_required(VERSION 3.16)
project(xyzzy VERSION 0.2.6.2 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_C_STANDARD 11)

# Default to Release build if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# ============================================================
# Version description from git
# ============================================================
find_package(Git QUIET)
if(GIT_FOUND AND EXISTS "${CMAKE_SOURCE_DIR}/.git")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --dirty --long
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_DESCRIBE_LONG
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
        RESULT_VARIABLE GIT_DESCRIBE_RESULT
    )
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --dirty
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_DESCRIBE
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(GIT_DESCRIBE_RESULT EQUAL 0 AND NOT "${GIT_DESCRIBE}" STREQUAL "${GIT_DESCRIBE_LONG}")
        # Not exactly on a tag - include describe string
        set(VERSION_DESCRIBE_CONTENT "#define PROGRAM_VERSION_DESCRIBE_STRING \"${GIT_DESCRIBE}\"")
    else()
        set(VERSION_DESCRIBE_CONTENT "/* On tag or no tags - use default version string */")
    endif()
else()
    set(VERSION_DESCRIBE_CONTENT "/* No git info available */")
endif()
file(WRITE ${CMAKE_SOURCE_DIR}/src/gen/version-describe.h "${VERSION_DESCRIBE_CONTENT}\n")

# ============================================================
# Find zlib (prefer static library for -static linking)
# ============================================================
set(CMAKE_FIND_LIBRARY_SUFFIXES_SAVE ${CMAKE_FIND_LIBRARY_SUFFIXES})
if(NOT MSVC)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a)
endif()
find_package(ZLIB)
set(CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES_SAVE})
if(NOT ZLIB_FOUND)
    # Fallback for MSVC: use vendored zlib
    if(MSVC)
        set(ZLIB_INCLUDE_DIRS ${CMAKE_SOURCE_DIR}/src/zlib)
        if(CMAKE_BUILD_TYPE STREQUAL "Debug")
            set(ZLIB_LIBRARIES ${CMAKE_SOURCE_DIR}/src/zlib/Debug/zlib.lib)
        else()
            set(ZLIB_LIBRARIES ${CMAKE_SOURCE_DIR}/src/zlib/Release/zlib.lib)
        endif()
    else()
        message(FATAL_ERROR "zlib not found. Install with: pacman -S mingw-w64-clang-aarch64-zlib")
    endif()
endif()

# Source and generated directories
set(SRC_DIR ${CMAKE_SOURCE_DIR}/src)
set(GEN_DIR ${CMAKE_SOURCE_DIR}/src/gen)
file(MAKE_DIRECTORY ${GEN_DIR})

# Common defines
add_compile_definitions(
    STRICT
    _WIN32
    __XYZZY__
    PRIVCTRL_NODLL
    _CRT_SECURE_NO_DEPRECATE
    UNICODE_TABLE_STATIC
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_definitions(DEBUG DEBUG_GC _DEBUG)
else()
    add_compile_definitions(NDEBUG DEBUG_GC)
endif()

# MinGW/Clang compatibility flags
if(NOT MSVC)
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
    # RC files are UTF-8 encoded
    set(CMAKE_RC_FLAGS "--codepage=65001")
endif()

# ============================================================
# gen-src1: Code generator (stage 1)
# ============================================================
set(GEN_SRC1_SOURCES
    ${SRC_DIR}/gen-main.cc
    ${SRC_DIR}/gen-stdafx.cc
    ${SRC_DIR}/dpp.cc
    ${SRC_DIR}/gen-char-width.cc
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
target_compile_definitions(gen-src1 PRIVATE GEN_SRC1 WIN32 _CONSOLE)
# Use -iquote instead of -I so that <string.h> finds the system header
# rather than src/string.h (project's Lisp string type header)
target_compile_options(gen-src1 PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${GEN_DIR}")

# ============================================================
# gen-src1 code generation custom commands
# ============================================================

# dpp: num-arith.d -> num-arith.h (takes args, not stdout)
add_custom_command(
    OUTPUT ${GEN_DIR}/num-arith.h
    COMMAND $<TARGET_FILE:gen-src1> dpp ${SRC_DIR}/num-arith.d ${GEN_DIR}/num-arith.h
    DEPENDS gen-src1 ${SRC_DIR}/num-arith.d ${SRC_DIR}/dpp.cc
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating num-arith.h"
)

# gen-char-width > char-width.h
add_custom_command(
    OUTPUT ${GEN_DIR}/char-width.h
    COMMAND $<TARGET_FILE:gen-src1> gen-char-width > ${GEN_DIR}/char-width.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating char-width.h"
)

# gen-ctab > chtab.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/chtab.cc
    COMMAND $<TARGET_FILE:gen-src1> gen-ctab > ${GEN_DIR}/chtab.cc
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating chtab.cc"
)

# gen-ibmext > ibmext.h
add_custom_command(
    OUTPUT ${GEN_DIR}/ibmext.h
    COMMAND $<TARGET_FILE:gen-src1> gen-ibmext > ${GEN_DIR}/ibmext.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating ibmext.h"
)

# gen-iso2022state > iso2022state.h
add_custom_command(
    OUTPUT ${GEN_DIR}/iso2022state.h
    COMMAND $<TARGET_FILE:gen-src1> gen-iso2022state > ${GEN_DIR}/iso2022state.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating iso2022state.h"
)

# gen-jisx0212-hash > jisx0212-hash.h
add_custom_command(
    OUTPUT ${GEN_DIR}/jisx0212-hash.h
    COMMAND $<TARGET_FILE:gen-src1> gen-jisx0212-hash > ${GEN_DIR}/jisx0212-hash.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating jisx0212-hash.h"
)

# gen-ktab > kanjitab.h
add_custom_command(
    OUTPUT ${GEN_DIR}/kanjitab.h
    COMMAND $<TARGET_FILE:gen-src1> gen-ktab > ${GEN_DIR}/kanjitab.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating kanjitab.h"
)

# gen-syms -> vars-decl.h, fns-decl.h, symtable.cc, dumpver.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/vars-decl.h ${GEN_DIR}/fns-decl.h
           ${GEN_DIR}/symtable.cc ${GEN_DIR}/dumpver.cc
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -vars > ${GEN_DIR}/vars-decl.h
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -proto > ${GEN_DIR}/fns-decl.h
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -symtable > ${GEN_DIR}/symtable.cc
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -version > ${GEN_DIR}/dumpver.cc
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating symbol tables"
)

# gen-utf2sjis > utf2sjis.h
add_custom_command(
    OUTPUT ${GEN_DIR}/utf2sjis.h
    COMMAND $<TARGET_FILE:gen-src1> gen-utf2sjis > ${GEN_DIR}/utf2sjis.h
    DEPENDS gen-src1
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating utf2sjis.h"
)

# Convenience target for all gen-src1 outputs
add_custom_target(gen-src1-run
    DEPENDS
        ${GEN_DIR}/num-arith.h
        ${GEN_DIR}/char-width.h
        ${GEN_DIR}/chtab.cc
        ${GEN_DIR}/ibmext.h
        ${GEN_DIR}/iso2022state.h
        ${GEN_DIR}/jisx0212-hash.h
        ${GEN_DIR}/kanjitab.h
        ${GEN_DIR}/vars-decl.h
        ${GEN_DIR}/fns-decl.h
        ${GEN_DIR}/symtable.cc
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
target_compile_options(gen-src2 PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${GEN_DIR}")
# gen-src2 compilation needs chtab.cc from gen-src1
add_dependencies(gen-src2 gen-src1-run)

# ============================================================
# gen-src2 code generation custom commands
# ============================================================

# gen-msg -> msgcode.h, msgdef.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/msgcode.h ${GEN_DIR}/msgdef.cc
    COMMAND $<TARGET_FILE:gen-src2> gen-msg -enum > ${GEN_DIR}/msgcode.h
    COMMAND $<TARGET_FILE:gen-src2> gen-msg -c > ${GEN_DIR}/msgdef.cc
    DEPENDS gen-src2
    WORKING_DIRECTORY ${SRC_DIR}
    COMMENT "Generating message code"
)

add_custom_target(gen-src2-run
    DEPENDS
        ${GEN_DIR}/msgcode.h
        ${GEN_DIR}/msgdef.cc
)

# ============================================================
# xyzzy: Main application
# ============================================================
set(XYZZY_SOURCES
    ${SRC_DIR}/alloc.cc
    ${SRC_DIR}/appid.cc
    ${SRC_DIR}/arc-if.cc
    ${SRC_DIR}/archiver.cc
    ${SRC_DIR}/array.cc
    ${SRC_DIR}/assert.cc
    ${SRC_DIR}/backq.cc
    ${SRC_DIR}/bignum.cc
    ${SRC_DIR}/binfo.cc
    ${SRC_DIR}/buffer-bar.cc
    ${SRC_DIR}/Buffer.cc
    ${SRC_DIR}/byte-stream.cc
    ${SRC_DIR}/bytecode.cc
    ${SRC_DIR}/ces.cc
    ${SRC_DIR}/char.cc
    ${SRC_DIR}/chname.cc
    ${SRC_DIR}/ChooseFont.cc
    ${SRC_DIR}/chunk.cc
    ${SRC_DIR}/clipboard.cc
    ${SRC_DIR}/ColorDialog.cc
    ${SRC_DIR}/colors.cc
    ${SRC_DIR}/com.cc
    ${SRC_DIR}/conf.cc
    ${SRC_DIR}/ctl3d.cc
    ${SRC_DIR}/data.cc
    ${SRC_DIR}/dde.cc
    ${SRC_DIR}/debug.cc
    ${SRC_DIR}/dialogs.cc
    ${SRC_DIR}/disp.cc
    ${SRC_DIR}/dll.cc
    ${SRC_DIR}/DnD.cc
    ${SRC_DIR}/doc.cc
    ${SRC_DIR}/dockbar.cc
    ${SRC_DIR}/dsfmt/dSFMT.cc
    ${SRC_DIR}/edict.cc
    ${SRC_DIR}/encdec.cc
    ${SRC_DIR}/encoding.cc
    ${SRC_DIR}/environ.cc
    ${SRC_DIR}/eval.cc
    ${SRC_DIR}/except.cc
    ${SRC_DIR}/fileio.cc
    ${SRC_DIR}/filer.cc
    ${SRC_DIR}/fnkey.cc
    ${SRC_DIR}/font.cc
    ${SRC_DIR}/gime.cc
    ${SRC_DIR}/glob.cc
    ${SRC_DIR}/guess.cc
    ${SRC_DIR}/guid.cc
    ${SRC_DIR}/gzip.cc
    ${SRC_DIR}/hash.cc
    ${SRC_DIR}/hashpjw.cc
    ${SRC_DIR}/init.cc
    ${SRC_DIR}/insdel.cc
    ${SRC_DIR}/ipc.cc
    ${SRC_DIR}/kanji.cc
    ${SRC_DIR}/kbd.cc
    ${SRC_DIR}/keymap.cc
    ${SRC_DIR}/ldialog.cc
    ${SRC_DIR}/lex.cc
    ${SRC_DIR}/list.cc
    ${SRC_DIR}/listen.cc
    ${SRC_DIR}/lprint.cc
    ${SRC_DIR}/lread.cc
    ${SRC_DIR}/md5c.cc
    ${SRC_DIR}/menu.cc
    ${SRC_DIR}/minibuf.cc
    ${SRC_DIR}/mman.cc
    ${SRC_DIR}/monitor.cc
    ${SRC_DIR}/mouse.cc
    ${SRC_DIR}/move.cc
    ${SRC_DIR}/msgbox.cc
    ${SRC_DIR}/number.cc
    ${SRC_DIR}/oledata.cc
    ${SRC_DIR}/package.cc
    ${SRC_DIR}/pane.cc
    ${SRC_DIR}/pathname.cc
    ${SRC_DIR}/popup.cc
    ${SRC_DIR}/popupl.cc
    ${SRC_DIR}/pred.cc
    ${SRC_DIR}/preview.cc
    ${SRC_DIR}/print.cc
    ${SRC_DIR}/printdlg.cc
    ${SRC_DIR}/privctrl/listviewex.cc
    ${SRC_DIR}/privctrl/privctrl.cc
    ${SRC_DIR}/privctrl/url.cc
    ${SRC_DIR}/process.cc
    ${SRC_DIR}/random.cc
    ${SRC_DIR}/regex.cc
    ${SRC_DIR}/resolver.cc
    ${SRC_DIR}/search.cc
    ${SRC_DIR}/sequence.cc
    ${SRC_DIR}/sha1.cc
    ${SRC_DIR}/sha2.cc
    ${SRC_DIR}/signal.cc
    ${SRC_DIR}/sock.cc
    ${SRC_DIR}/sockinet.cc
    ${SRC_DIR}/sockssl.cc
    ${SRC_DIR}/statarea.cc
    ${SRC_DIR}/stdctl.cc
    ${SRC_DIR}/StrBuf.cc
    ${SRC_DIR}/stream.cc
    ${SRC_DIR}/string.cc
    ${SRC_DIR}/structure.cc
    ${SRC_DIR}/symbol.cc
    ${SRC_DIR}/symtable.cc
    ${SRC_DIR}/syntax.cc
    ${SRC_DIR}/sysdep.cc
    ${SRC_DIR}/system.cc
    ${SRC_DIR}/thread.cc
    ${SRC_DIR}/toplev.cc
    ${SRC_DIR}/ucs2.cc
    ${SRC_DIR}/undo.cc
    ${SRC_DIR}/usertab.cc
    ${SRC_DIR}/usertool.cc
    ${SRC_DIR}/utils.cc
    ${SRC_DIR}/utimer.cc
    ${SRC_DIR}/vector.cc
    ${SRC_DIR}/version.cc
    ${SRC_DIR}/vfs.cc
    ${SRC_DIR}/wheel.cc
    ${SRC_DIR}/Window.cc
    ${SRC_DIR}/winhelp.cc
    ${SRC_DIR}/wstream.cc
    ${SRC_DIR}/xdde.cc
    ${SRC_DIR}/xlist.cc
    # Generated sources (compiled standalone; gen/symtable.cc is #include'd by src/symtable.cc)
    ${GEN_DIR}/chtab.cc
    ${GEN_DIR}/dumpver.cc
    ${GEN_DIR}/msgdef.cc
)

add_executable(xyzzy WIN32 ${XYZZY_SOURCES})
target_compile_definitions(xyzzy PRIVATE UNICODE _UNICODE)
target_compile_options(xyzzy PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${SRC_DIR}/privctrl" "SHELL:-iquote ${GEN_DIR}")
target_include_directories(xyzzy PRIVATE ${ZLIB_INCLUDE_DIRS})
add_dependencies(xyzzy gen-src1-run gen-src2-run)

# Link libraries
target_link_libraries(xyzzy PRIVATE
    ${ZLIB_LIBRARIES}
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

# Static linking (no DLL dependencies on MSYS2 runtime)
if(NOT MSVC)
    target_link_options(xyzzy PRIVATE -static -Wl,--stack,0x2000000)
endif()

# Resource file
if(CMAKE_RC_COMPILER)
    target_sources(xyzzy PRIVATE ${SRC_DIR}/xyzzy.rc)
endif()

# ============================================================
# xyzzycli: Command-line launcher
# ============================================================
add_executable(xyzzycli WIN32 ${SRC_DIR}/xyzzycli.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzycli PRIVATE ${SRC_DIR}/xyzzycli.rc)
endif()
target_compile_definitions(xyzzycli PRIVATE UNICODE _UNICODE)
target_compile_options(xyzzycli PRIVATE "SHELL:-iquote ${SRC_DIR}")
if(NOT MSVC)
    target_link_options(xyzzycli PRIVATE -static)
endif()

# ============================================================
# xyzzyenv: Environment utility
# ============================================================
add_executable(xyzzyenv ${SRC_DIR}/xyzzyenv.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzyenv PRIVATE ${SRC_DIR}/xyzzyenv.rc)
endif()
target_compile_definitions(xyzzyenv PRIVATE UNICODE _UNICODE)
target_compile_options(xyzzyenv PRIVATE "SHELL:-iquote ${SRC_DIR}")
if(NOT MSVC)
    target_link_options(xyzzyenv PRIVATE -static)
endif()

# ============================================================
# tail-f: File monitoring utility (etc/tail-f.exe)
# ============================================================
add_executable(tail-f ${SRC_DIR}/etc/tail-f.cc)
if(NOT MSVC)
    target_link_options(tail-f PRIVATE -static)
endif()

# ============================================================
# Bytecompile: compile .l -> .lc and generate dump image
# ============================================================
add_custom_target(bytecompile
    COMMAND ${CMAKE_COMMAND} -E env
        "XYZZYHOME=${CMAKE_SOURCE_DIR}"
        "XYZZYINIFILE="
        "XYZZYCONFIGPATH="
        $<TARGET_FILE:xyzzy> -q -trace -load misc/makelc.l -e "(makelc:makelc-and-exit t)"
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    DEPENDS xyzzy
    COMMENT "Byte-compiling Lisp files and generating dump image"
    USES_TERMINAL
)

# ============================================================
# Testing
# ============================================================
enable_testing()
add_test(
    NAME xyzzy-unit-tests
    COMMAND ${CMAKE_COMMAND} -E env
        "XYZZYHOME=${CMAKE_SOURCE_DIR}"
        "XYZZYINIFILE="
        "XYZZYCONFIGPATH="
        $<TARGET_FILE:xyzzy> -q -trace -l unittest/run-tests-helper.l
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# ============================================================
# Install
# ============================================================
install(TARGETS xyzzy xyzzycli xyzzyenv RUNTIME DESTINATION .)
install(TARGETS tail-f RUNTIME DESTINATION etc)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/lisp/ DESTINATION lisp FILES_MATCHING PATTERN "*.l" PATTERN "*.lc")
install(DIRECTORY ${CMAKE_SOURCE_DIR}/etc/ DESTINATION etc)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/docs/ DESTINATION docs)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/reference/ DESTINATION reference OPTIONAL)
install(FILES ${CMAKE_SOURCE_DIR}/LICENSE DESTINATION .)
install(FILES ${CMAKE_SOURCE_DIR}/LEGAL.md DESTINATION . OPTIONAL)

# ============================================================
# CPack: packaging
# ============================================================
set(CPACK_PACKAGE_NAME "xyzzy")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_GENERATOR "ZIP")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
set(CPACK_PACKAGE_FILE_NAME "xyzzy-${PROJECT_VERSION}")
include(CPack)
