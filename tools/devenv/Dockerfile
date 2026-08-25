# xyzzy cross-build / test environment (llvm-mingw + Wine).
#
# Builds Windows (PE) binaries with llvm-mingw and runs them under Wine, so the
# whole build+test cycle works on a non-Windows host (macOS/Linux) and in CI.
#
# Why llvm-mingw rather than the mingw-w64 GCC that Debian packages:
#
#   * one toolchain covers i686, x86_64, armv7 and aarch64.  GCC's
#     aarch64-w64-mingw32 exists from GCC 15 but its SEH and C++ exceptions are
#     not implemented, and this tree leans on SEH (the MSVC build asks for /EHa
#     and installs a _set_se_translator), so GCC cannot reach Windows on Arm at
#     all.
#   * this tree is already tuned for Clang: CMakeLists has a Clang branch with
#     -fms-extensions and the windres flags, and cmake/clangarm64-toolchain.cmake
#     builds it with the MSYS2 CLANGARM64 (also Clang, also the GNU ABI).  GCC
#     was the odd one out.
#   * Clang's MSVC compatibility swallows more of what this code base assumes.
#
# UCRT rather than msvcrt, to match what the MSVC build links against.
#
# amd64 only: Wine executes x86 machine code, so the container must be x86.
# On Apple Silicon this runs through Docker Desktop's emulation layer.
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# git: the build fetches tree-sitter and its grammars with FetchContent.
# xz-utils: the llvm-mingw release is a .tar.xz.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      ccache \
      cmake \
      curl \
      file \
      git \
      gzip \
      imagemagick \
      make \
      ninja-build \
      python3 \
      tar \
      wine \
      wine32 \
      wine64 \
      x11-utils \
      xauth \
      xvfb \
      xz-utils \
 && rm -rf /var/lib/apt/lists/*

ARG LLVM_MINGW_VERSION=20260616
ARG LLVM_MINGW_SHA256=534b92e067b22a6b4441f48ae9240a3341b17825d04d577eab0cf85c44b4deda
RUN curl -fsSL --retry 5 --retry-all-errors -o /tmp/llvm-mingw.tar.xz \
      "https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VERSION}/llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64.tar.xz" \
 && echo "${LLVM_MINGW_SHA256}  /tmp/llvm-mingw.tar.xz" | sha256sum -c - \
 && mkdir -p /opt \
 && tar -xJf /tmp/llvm-mingw.tar.xz -C /opt \
 && ln -s "/opt/llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-x86_64" /opt/llvm-mingw \
 && rm -f /tmp/llvm-mingw.tar.xz

ENV PATH=/opt/llvm-mingw/bin:$PATH

# zlib: this tree takes zlib from find_package (vcpkg on the MSVC build, the
# distribution package elsewhere).  Nothing ships a zlib for these targets, and
# llvm-mingw uses a different CRT from the Debian mingw packages, so a library
# built by either cannot be handed to the other: build it here, per target,
# into the sysroot that CMAKE_FIND_ROOT_PATH points at.
ARG ZLIB_VERSION=1.3.1
ARG ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
RUN curl -fsSL --retry 5 --retry-all-errors -o /tmp/zlib.tar.gz \
      "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
 && echo "${ZLIB_SHA256}  /tmp/zlib.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/zlib.tar.gz -C /tmp \
 && for target in i686-w64-mingw32 x86_64-w64-mingw32 aarch64-w64-mingw32; do \
      make -C "/tmp/zlib-${ZLIB_VERSION}" -f win32/Makefile.gcc clean >/dev/null 2>&1 || true; \
      make -C "/tmp/zlib-${ZLIB_VERSION}" -f win32/Makefile.gcc \
           CC="${target}-clang" AR=llvm-ar ARFLAGS=rcs RC="${target}-windres" libz.a \
        && install -d "/opt/llvm-mingw/${target}/include" "/opt/llvm-mingw/${target}/lib" \
        && install -m644 "/tmp/zlib-${ZLIB_VERSION}/zlib.h" "/tmp/zlib-${ZLIB_VERSION}/zconf.h" \
                         "/opt/llvm-mingw/${target}/include/" \
        && install -m644 "/tmp/zlib-${ZLIB_VERSION}/libz.a" "/opt/llvm-mingw/${target}/lib/"; \
    done \
 && rm -rf /tmp/zlib*

# Wine writes into $WINEPREFIX; keep it outside the mounted source tree.
# The prefixes are bootstrapped by the entrypoint, once a display exists: a
# wineboot without one leaves the prefix configured for the null display driver.
# Wine decides how to read and write Unix file names from the locale.  With the
# image's default (POSIX) it is not UTF-8, so a file whose name is not ASCII
# comes back mangled and creating one fails -- which reads exactly like a bug in
# the program under test.  It cost an afternoon once; keep the locale UTF-8.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ENV WINEPREFIX=/wine \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=mscoree=d \
    DISPLAY=:99

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
