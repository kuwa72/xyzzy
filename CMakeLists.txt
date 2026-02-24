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
file(MAKE_DIRECTORY ${CMAKE_SOURCE_DIR}/src/core/gen)
file(WRITE ${CMAKE_SOURCE_DIR}/src/core/gen/version-describe.h "${VERSION_DESCRIBE_CONTENT}\n")

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
        /wd4996  # deprecated functions
        /wd4477  # format string type mismatch
        /wd4312  # conversion to pointer of greater size
        /utf-8   # source files are UTF-8
    )
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
if(MSVC)
    target_include_directories(gen-src1 PRIVATE ${SRC_DIR} ${CORE_DIR} ${GEN_DIR})
else()
    target_compile_options(gen-src1 PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}")
endif()

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

# gen-syms -> vars-decl.h, fns-decl.h, symtable-core.cc, symtable-ed.cc, dumpver.cc
add_custom_command(
    OUTPUT ${GEN_DIR}/vars-decl.h ${GEN_DIR}/fns-decl.h
           ${GEN_DIR}/symtable-core.cc ${GEN_DIR}/symtable-ed.cc ${GEN_DIR}/dumpver.cc
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -vars > ${GEN_DIR}/vars-decl.h
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -proto > ${GEN_DIR}/fns-decl.h
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -symtable-core > ${GEN_DIR}/symtable-core.cc
    COMMAND $<TARGET_FILE:gen-src1> gen-syms -symtable-ed > ${GEN_DIR}/symtable-ed.cc
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

else() # !WIN32
# Non-Win32: use pre-generated files, create no-op targets
add_custom_target(gen-src1-run)
add_custom_target(gen-src2-run)
# Verify generated files exist
foreach(_genfile
    ${GEN_DIR}/num-arith.h ${GEN_DIR}/char-width.h ${GEN_DIR}/chtab.cc
    ${GEN_DIR}/ibmext.h ${GEN_DIR}/iso2022state.h ${GEN_DIR}/jisx0212-hash.h
    ${GEN_DIR}/kanjitab.h ${GEN_DIR}/vars-decl.h ${GEN_DIR}/fns-decl.h
    ${GEN_DIR}/symtable-core.cc ${GEN_DIR}/symtable-ed.cc ${GEN_DIR}/dumpver.cc
    ${GEN_DIR}/utf2sjis.h ${GEN_DIR}/msgcode.h ${GEN_DIR}/msgdef.cc)
    if(NOT EXISTS ${_genfile})
        message(FATAL_ERROR "Pre-generated file missing: ${_genfile}\nRun gen tools on Windows first.")
    endif()
endforeach()
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
    ${CORE_DIR}/char.cc
    ${CORE_DIR}/chname.cc
    ${CORE_DIR}/chunk.cc
    ${CORE_DIR}/data.cc
    ${CORE_DIR}/debug.cc
    ${CORE_DIR}/encdec.cc
    ${CORE_DIR}/encoding.cc
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
    ${CORE_DIR}/glyph.cc
    ${CORE_DIR}/dsfmt/dSFMT.cc
    # Generated sources (compiled standalone; gen/symtable-core.cc is #include'd by core/symtable.cc)
    ${GEN_DIR}/chtab.cc
    ${GEN_DIR}/dumpver.cc
    ${GEN_DIR}/msgdef.cc
)

add_library(xyzzy-core STATIC ${CORE_SOURCES})
target_compile_definitions(xyzzy-core PRIVATE UNICODE _UNICODE)
if(MSVC)
    target_include_directories(xyzzy-core PRIVATE ${CORE_DIR} ${GEN_DIR} ${SRC_DIR})
else()
    target_compile_options(xyzzy-core PRIVATE "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}" "SHELL:-iquote ${SRC_DIR}")
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
    ${WIN32_DIR}/utimer.cc
    ${WIN32_DIR}/monitor.cc
    ${WIN32_DIR}/binfo.cc
    ${WIN32_DIR}/doc.cc
    # Win32 specific
    ${WIN32_DIR}/com.cc
    ${WIN32_DIR}/oledata.cc
    ${WIN32_DIR}/dde.cc
    ${WIN32_DIR}/xdde.cc
    ${WIN32_DIR}/dll.cc
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

# Common link libraries for Win32 targets
set(XYZZY_LINK_LIBS
    xyzzy-core
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

# ============================================================
# xyzzy: Main GUI application
# ============================================================
add_executable(xyzzy WIN32 ${WIN32_SOURCES})
target_compile_definitions(xyzzy PRIVATE UNICODE _UNICODE)
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
    target_link_options(xyzzy PRIVATE /STACK:0x2000000)
endif()

# Resource file (windres needs -I, not -iquote, for include paths)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzy PRIVATE ${SRC_DIR}/xyzzy.rc)
    set_source_files_properties(${SRC_DIR}/xyzzy.rc PROPERTIES
        OBJECT_DEPENDS "${CORE_DIR}/resource.h"
        INCLUDE_DIRECTORIES "${CORE_DIR};${SRC_DIR}")
endif()

# ============================================================
# xyzzy-batch: Console version for batch operations (byte-compile, etc.)
# No WIN32 → console subsystem, so execute_process can wait for it.
# batch-main.cc provides main() which calls WinMain(SW_HIDE).
# ============================================================
add_executable(xyzzy-batch ${WIN32_SOURCES} ${WIN32_DIR}/batch-main.cc)
target_compile_definitions(xyzzy-batch PRIVATE UNICODE _UNICODE)
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
    target_link_options(xyzzy-batch PRIVATE /STACK:0x2000000)
endif()
if(CMAKE_RC_COMPILER)
    target_sources(xyzzy-batch PRIVATE ${SRC_DIR}/xyzzy.rc)
    set_source_files_properties(${SRC_DIR}/xyzzy.rc PROPERTIES
        OBJECT_DEPENDS "${CORE_DIR}/resource.h"
        INCLUDE_DIRECTORIES "${CORE_DIR};${SRC_DIR}")
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
    ${CLI_DIR}/cli-conf.cc
    ${CLI_DIR}/cli-symtable-ed.cc
)

add_executable(xyzzy-cli ${CLI_SOURCES})
target_compile_definitions(xyzzy-cli PRIVATE UNICODE _UNICODE)
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
        target_link_options(xyzzy-cli PRIVATE /STACK:0x2000000)
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
    if(NCURSESW_LIBRARY AND NCURSESW_INCLUDE_DIR)
        set(NCURSES_DIR ${CMAKE_SOURCE_DIR}/src/frontend/ncurses)
        set(NCURSES_SOURCES
            ${NCURSES_DIR}/ncurses-main.cc
            ${NCURSES_DIR}/ncurses-stubs.cc
            ${NCURSES_DIR}/ncurses-kbd.cc
            ${CLI_DIR}/cli-conf.cc
            ${NCURSES_DIR}/ncurses-symtable-ed.cc
        )

        add_executable(xyzzy-ncurses ${NCURSES_SOURCES})
        target_compile_definitions(xyzzy-ncurses PRIVATE UNICODE _UNICODE)
        target_compile_options(xyzzy-ncurses PRIVATE
            "SHELL:-iquote ${CORE_DIR}" "SHELL:-iquote ${GEN_DIR}" "SHELL:-iquote ${SRC_DIR}")
        target_include_directories(xyzzy-ncurses PRIVATE ${ZLIB_INCLUDE_DIRS} ${NCURSESW_INCLUDE_DIR})
        target_link_libraries(xyzzy-ncurses PRIVATE
            xyzzy-core
            ${ZLIB_LIBRARIES}
            ${NCURSESW_LIBRARY}
            pthread
        )
        install(TARGETS xyzzy-ncurses RUNTIME DESTINATION bin)
    else()
        message(STATUS "ncursesw not found - skipping xyzzy-ncurses target")
    endif()
endif()

# ============================================================
# Win32-only targets
# ============================================================
if(WIN32)

# xyzzycli: Command-line launcher
add_executable(xyzzycli WIN32 ${SRC_DIR}/xyzzycli.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzycli PRIVATE ${SRC_DIR}/xyzzycli.rc)
endif()
target_compile_definitions(xyzzycli PRIVATE UNICODE _UNICODE)
if(MSVC)
    target_include_directories(xyzzycli PRIVATE ${SRC_DIR} ${CORE_DIR})
else()
    target_compile_options(xyzzycli PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}")
endif()
if(NOT MSVC)
    target_link_options(xyzzycli PRIVATE -static)
endif()

# xyzzyenv: Environment utility
add_executable(xyzzyenv ${SRC_DIR}/xyzzyenv.cc)
if(CMAKE_RC_COMPILER)
    target_sources(xyzzyenv PRIVATE ${SRC_DIR}/xyzzyenv.rc)
endif()
target_compile_definitions(xyzzyenv PRIVATE UNICODE _UNICODE)
if(MSVC)
    target_include_directories(xyzzyenv PRIVATE ${SRC_DIR} ${CORE_DIR})
else()
    target_compile_options(xyzzyenv PRIVATE "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${CORE_DIR}")
endif()
if(NOT MSVC)
    target_link_options(xyzzyenv PRIVATE -static)
endif()

# Browser.dll: WebBrowser ActiveX plugin (ATL-free, IWebBrowser2)
add_library(browser SHARED
    ${WIN32_DIR}/Browser.cpp
    ${SRC_DIR}/xpi.cc
    ${WIN32_DIR}/Browser.def
)
target_compile_definitions(browser PRIVATE BROWSER_EXPORTS WIN32 UNICODE _UNICODE)
if(MSVC)
    target_include_directories(browser PRIVATE ${SRC_DIR} ${WIN32_DIR})
else()
    target_compile_options(browser PRIVATE
        "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${WIN32_DIR}"
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
    ${SRC_DIR}/xpi.cc
    ${WIN32_DIR}/TreeView.def
)
target_compile_definitions(treeview PRIVATE TREEVIEW_EXPORTS WIN32 UNICODE _UNICODE)
if(MSVC)
    target_include_directories(treeview PRIVATE ${SRC_DIR} ${WIN32_DIR})
else()
    target_compile_options(treeview PRIVATE
        "SHELL:-iquote ${SRC_DIR}" "SHELL:-iquote ${WIN32_DIR}")
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
        "XYZZYINIFILE="
        "XYZZYCONFIGPATH="
        $<TARGET_FILE:xyzzy> -q -trace -l unittest/run-tests-helper.l
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

# Install (Win32)
install(TARGETS xyzzy xyzzycli xyzzyenv browser treeview RUNTIME DESTINATION .)
install(TARGETS tail-f RUNTIME DESTINATION etc)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/lisp/ DESTINATION lisp FILES_MATCHING PATTERN "*.l" PATTERN "*.lc")
install(DIRECTORY ${CMAKE_SOURCE_DIR}/etc/ DESTINATION etc)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/docs/ DESTINATION docs)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/reference/ DESTINATION reference OPTIONAL)
install(FILES ${CMAKE_SOURCE_DIR}/LICENSE DESTINATION .)
install(FILES ${CMAKE_SOURCE_DIR}/LEGAL.md DESTINATION . OPTIONAL)

endif() # WIN32

# ============================================================
# Cross-platform tools
# ============================================================

# gendic: EDICT -> xyzzy binary dictionary converter
add_executable(gendic ${SRC_DIR}/gendic.cc)
if(MSVC)
    target_compile_options(gendic PRIVATE /W3)
else()
    target_compile_options(gendic PRIVATE -Wall -std=c++11)
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
# CPack: packaging
# ============================================================
set(CPACK_PACKAGE_NAME "xyzzy")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_GENERATOR "ZIP")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY ON)
set(CPACK_PACKAGE_FILE_NAME "xyzzy-${PROJECT_VERSION}")
include(CPack)
