# xyzzy cross-build / test environment (mingw-w64 + Wine).
#
# Builds Windows (PE) binaries with mingw-w64 and runs them under Wine, so the
# whole build+test cycle works on a non-Windows host (macOS/Linux) and in CI.
#
# This is the snmsts/modern tree, which already builds with GCC/Clang for a
# Windows target (see the MSYS2 recipe in README.md); the cross toolchain files
# in cmake/mingw-*.cmake point CMake at the mingw-w64 compilers and at Wine as
# the emulator for the code generators that run during the build.
#
# amd64 only: Wine executes x86 machine code, so the container must be x86.
# On Apple Silicon this runs through Docker Desktop's emulation layer.
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# git: the build fetches tree-sitter and its grammars with FetchContent.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      file \
      git \
      gzip \
      imagemagick \
      make \
      mingw-w64-tools \
      g++-mingw-w64-i686 \
      g++-mingw-w64-x86-64 \
      ninja-build \
      python3 \
      tar \
      wine \
      wine32 \
      wine64 \
      x11-utils \
      xauth \
      xvfb \
 && rm -rf /var/lib/apt/lists/*

# zlib: this tree takes zlib from find_package (vcpkg on the MSVC build, the
# distribution package elsewhere).  Debian ships no mingw zlib, so build it
# from source into each target's sysroot, where CMAKE_FIND_ROOT_PATH looks.
ARG ZLIB_VERSION=1.3.1
ARG ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
RUN curl -fsSL --retry 5 --retry-all-errors -o /tmp/zlib.tar.gz \
      "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
 && echo "${ZLIB_SHA256}  /tmp/zlib.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/zlib.tar.gz -C /tmp \
 && for target in i686-w64-mingw32 x86_64-w64-mingw32; do \
      make -C "/tmp/zlib-${ZLIB_VERSION}" -f win32/Makefile.gcc clean >/dev/null 2>&1 || true; \
      make -C "/tmp/zlib-${ZLIB_VERSION}" -f win32/Makefile.gcc \
           PREFIX="${target}-" libz.a \
        && install -d "/usr/${target}/include" "/usr/${target}/lib" \
        && install -m644 "/tmp/zlib-${ZLIB_VERSION}/zlib.h" "/tmp/zlib-${ZLIB_VERSION}/zconf.h" "/usr/${target}/include/" \
        && install -m644 "/tmp/zlib-${ZLIB_VERSION}/libz.a" "/usr/${target}/lib/"; \
    done \
 && rm -rf /tmp/zlib*

# Wine writes into $WINEPREFIX; keep it outside the mounted source tree.
# The prefixes are bootstrapped by the entrypoint, once a display exists: a
# wineboot without one leaves the prefix configured for the null display driver.
ENV WINEPREFIX=/wine \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=mscoree=d \
    DISPLAY=:99

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
