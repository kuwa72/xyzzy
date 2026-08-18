# xyzzy cross-build / test environment.
#
# Builds Windows (PE) binaries with mingw-w64 and runs them under Wine, so the
# whole build+test cycle works on a non-Windows host (macOS/Linux) and in CI.
#
# amd64 only: Wine executes x86 machine code, so the container must be x86.
# On Apple Silicon this runs through Docker Desktop's emulation layer.
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

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

# zlib: the repository ships only headers plus prebuilt 32-bit MSVC .lib files,
# so build it from source for both mingw targets.
ARG ZLIB_VERSION=1.3.1
ARG ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
RUN curl -fsSL -o /tmp/zlib.tar.gz "https://zlib.net/fossils/zlib-${ZLIB_VERSION}.tar.gz" \
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

# libffi: the foreign function interface (src/dll.cc) is implemented with hand
# written x86 stack marshalling for MSVC; every other build calls through libffi.
ARG LIBFFI_VERSION=3.4.6
ARG LIBFFI_SHA256=b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e
RUN curl -fsSL -o /tmp/libffi.tar.gz \
      "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz" \
 && echo "${LIBFFI_SHA256}  /tmp/libffi.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/libffi.tar.gz -C /tmp \
 && for target in i686-w64-mingw32 x86_64-w64-mingw32; do \
      rm -rf "/tmp/build-$target" && mkdir "/tmp/build-$target" \
      && (cd "/tmp/build-$target" \
          && "/tmp/libffi-${LIBFFI_VERSION}/configure" \
               --host="$target" --build=x86_64-pc-linux-gnu \
               --prefix="/usr/$target" --libdir="/usr/$target/lib" \
               --includedir="/usr/$target/include" \
               --enable-static --disable-shared --disable-docs >/dev/null \
          && make -j"$(nproc)" >/dev/null \
          && make install >/dev/null); \
    done \
 && rm -rf /tmp/libffi* /tmp/build-*

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
