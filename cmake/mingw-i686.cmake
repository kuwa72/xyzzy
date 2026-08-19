# Cross toolchain: 32-bit Windows (PE) via llvm-mingw, executed under Wine.
#
# This is the compatibility baseline: it targets the same architecture as the
# x86 MSVC build, so the test suite result here is what the other architectures
# have to reproduce.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86)

set(TOOLCHAIN_PREFIX i686-w64-mingw32)
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

set(CMAKE_CROSSCOMPILING_EMULATOR /usr/bin/env;WINEPREFIX=/wine32;WINEARCH=win32;wine)

set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")
