# Cross toolchain: 64-bit Windows (PE) via llvm-mingw, executed under Wine.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)
set(TOOLCHAIN_ROOT /opt/llvm-mingw)

set(CMAKE_C_COMPILER   ${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang++)
set(CMAKE_RC_COMPILER  ${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-windres)
set(CMAKE_AR           ${TOOLCHAIN_ROOT}/bin/llvm-ar)
set(CMAKE_RANLIB       ${TOOLCHAIN_ROOT}/bin/llvm-ranlib)

set(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN_ROOT}/${TOOLCHAIN_PREFIX})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# The code generators are built for the target, so they run through Wine.
set(CMAKE_CROSSCOMPILING_EMULATOR /usr/bin/env;WINEPREFIX=/wine;WINEARCH=win64;wine)

# Produce standalone executables, as the MSVC build does.
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")
