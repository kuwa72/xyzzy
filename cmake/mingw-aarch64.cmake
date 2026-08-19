# Cross toolchain: ARM64 Windows (PE) via llvm-mingw.
#
# Build only.  Two things are missing to go further on an x86 host:
#
#   * Wine here executes x86 machine code, so an ARM64 PE cannot be run, and
#     with it neither the test suite nor the byte compiler.
#   * the code generators (gen-src1, gen-src2) are built for the target, so
#     they cannot be run either.  Their output lands in src/core/gen/, which
#     is in the source tree and therefore shared with the other builds, so an
#     x86_64 build has to have produced it first -- tools/x arm-prep does that.
#
# What this does cover is that a second compiler reads the ARM64 code paths.
# Running ARM64 binaries stays with the MSVC job on windows-11-arm.
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(TOOLCHAIN_PREFIX aarch64-w64-mingw32)
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

# Deliberately no CMAKE_CROSSCOMPILING_EMULATOR: see above.

set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")
