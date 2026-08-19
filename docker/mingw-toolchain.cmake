# mingw-w64 クロスコンパイル用ツールチェイン (Debian の g++-mingw-w64 + Wine)
#
#   cmake -B build-docker/wine-x86_64 -G Ninja \
#         -DCMAKE_TOOLCHAIN_FILE=docker/mingw-toolchain.cmake -DMINGW_ARCH=x86_64
#
# MINGW_ARCH: x86_64 (既定) または i686
if(NOT MINGW_ARCH)
    set(MINGW_ARCH x86_64)
endif()

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ${MINGW_ARCH})

set(_prefix ${MINGW_ARCH}-w64-mingw32)
set(CMAKE_C_COMPILER   ${_prefix}-gcc)
set(CMAKE_CXX_COMPILER ${_prefix}-g++)
set(CMAKE_RC_COMPILER  ${_prefix}-windres)

set(CMAKE_FIND_ROOT_PATH /usr/${_prefix})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# ビルド中に走るコードジェネレータ (gen-src1/gen-src2) は Windows 実行ファイルに
# なるので、Wine 経由で実行する。
set(CMAKE_CROSSCOMPILING_EMULATOR wine)
