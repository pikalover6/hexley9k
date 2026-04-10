# syntax=docker/dockerfile:1
#
# PureDarwin full build environment
# ==================================
# Builds a Darwin 9 (macOS 10.5.7) cross-compilation toolchain on Ubuntu,
# then compiles every patched Darwin project in source/ to produce
# .root.tar.gz files consumed by pd_setup_linux.
#
# Usage (from the repo root):
#   docker build -t puredarwin-builder .
#   docker run --rm -v "$(pwd):/repo" puredarwin-builder
#
# Or use the convenience wrapper:
#   ./docker-build.sh
#
# On Windows:
#   docker build -t puredarwin-builder .
#   docker run --rm -v "%cd%:/repo" puredarwin-builder
#
# ─────────────────────────────────────────────────────────────────────────────
# STAGE 1: Build cctools-port (Apple's ld64, ar, otool, etc. for Linux)
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04 AS cctools-builder
LABEL stage=cctools-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates \
    build-essential cmake ninja-build \
    clang lld llvm \
    libssl-dev zlib1g-dev libxml2-dev \
    uuid-dev libmpc-dev \
    python3 python3-pip \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# cctools-port provides: i386-apple-darwin9-{ld,ar,ranlib,strip,lipo,otool,nm,size}
# and the o64-* wrappers that call clang with the right darwin target flags.
RUN git clone --depth 1 https://github.com/tpoechtrager/cctools-port /opt/cctools-src

# Build cctools for i386-apple-darwin9 (Darwin 9 = macOS 10.5)
RUN cd /opt/cctools-src/cctools \
 && ./configure \
        --target=i386-apple-darwin9 \
        --prefix=/opt/cctools \
        --with-llvm-config=/usr/bin/llvm-config \
 && make -j"$(nproc)" \
 && make install

# Build ldid (lightweight code-signing tool used in cross builds)
RUN git clone --depth 1 https://github.com/nicowillis/ldid /opt/ldid-src \
 && cd /opt/ldid-src \
 && make -j"$(nproc)" \
 && cp ldid /opt/cctools/bin/

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 2: Assemble Darwin 9 SDK headers
# Sources:
#   • XNU 1228.15.4  (darwin 9.7.0 = macOS 10.5.7) – mach/, sys/, kern/, libkern/
#   • Libc 498.1.7   – <stdarg.h>, <stdio.h> Darwin extensions
#   • project headers already present in /repo/source/apple/{CF,IOKitUser,...}
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04 AS sdk-assembler
LABEL stage=sdk-assembler

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates make \
    && rm -rf /var/lib/apt/lists/*

ENV SDK=/opt/darwin9-sdk

# Fetch XNU kernel headers (Darwin 9.7.0 = XNU 1228.15.4)
RUN git clone --depth 1 \
        --branch xnu-1228.15.4 \
        https://github.com/apple-oss-distributions/xnu \
        /tmp/xnu \
 || git clone --depth 1 \
        --branch xnu-1228.15.4.0.1 \
        https://github.com/apple-oss-distributions/xnu \
        /tmp/xnu

# Install XNU exported headers into the SDK.
# 'make exporthdrs' writes to DSTROOT; we point it at $SDK.
RUN cd /tmp/xnu \
 && make exporthdrs DSTROOT="$SDK" 2>/dev/null || true \
 # Fallback: copy the EXPORT_FILES manually if make exporthdrs not available.
 && mkdir -p "$SDK/usr/include" \
 && cp -r osfmk/mach         "$SDK/usr/include/mach"         2>/dev/null || true \
 && cp -r osfmk/machine      "$SDK/usr/include/machine"      2>/dev/null || true \
 && cp -r bsd/sys            "$SDK/usr/include/sys"          2>/dev/null || true \
 && cp -r bsd/machine        "$SDK/usr/include/bsd-machine"  2>/dev/null || true \
 && cp -r libkern/libkern    "$SDK/usr/include/libkern"      2>/dev/null || true \
 && cp -r iokit/IOKit        "$SDK/usr/include/IOKit"        2>/dev/null || true \
 && rm -rf /tmp/xnu

# Fetch Libc 498.1.7 for Darwin-extended stdlib / POSIX headers.
RUN git clone --depth 1 \
        --branch Libc-498.1.7 \
        https://github.com/apple-oss-distributions/Libc \
        /tmp/Libc \
 && mkdir -p "$SDK/usr/include" \
 && cp -r /tmp/Libc/include/*  "$SDK/usr/include/" 2>/dev/null || true \
 && cp -r /tmp/Libc/gen/*.h    "$SDK/usr/include/" 2>/dev/null || true \
 && rm -rf /tmp/Libc

# ─────────────────────────────────────────────────────────────────────────────
# STAGE 3: Full build environment
# Merges the toolchain and SDK, then compiles all Darwin projects.
# ─────────────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Cross-compilation
    clang lld llvm \
    # Build systems
    make cmake ninja-build autoconf automake libtool \
    # Packaging / decompression
    tar gzip bzip2 unzip \
    # Runtime tools needed by build scripts
    openssl xxd git rsync \
    # For pd_setup_linux image assembly
    parted kpartx hfsprogs genisoimage qemu-utils \
    # Misc
    ca-certificates python3 patch \
    && rm -rf /var/lib/apt/lists/*

# Pull in cctools + SDK from earlier stages.
COPY --from=cctools-builder /opt/cctools  /opt/cctools
COPY --from=sdk-assembler   /opt/darwin9-sdk /opt/darwin9-sdk

ENV SDK=/opt/darwin9-sdk
ENV TOOLCHAIN=/opt/cctools

# Add cross-compile tools to PATH.
ENV PATH="$TOOLCHAIN/bin:$PATH"

# Create convenient clang wrapper scripts that bake in the darwin target and
# sysroot so build systems only need to set CC/CXX.
RUN printf '#!/bin/sh\nexec clang -target i386-apple-darwin9 -mmacosx-version-min=10.5 --sysroot %s "$@"\n' \
        "$SDK" > /usr/local/bin/darwin9-cc \
 && printf '#!/bin/sh\nexec clang++ -target i386-apple-darwin9 -mmacosx-version-min=10.5 --sysroot %s "$@"\n' \
        "$SDK" > /usr/local/bin/darwin9-c++ \
 && chmod +x /usr/local/bin/darwin9-cc /usr/local/bin/darwin9-c++

# Expose cross-compile environment variables for build scripts.
ENV DARWIN_CC="darwin9-cc"
ENV DARWIN_CXX="darwin9-c++"
ENV DARWIN_LD="$TOOLCHAIN/bin/i386-apple-darwin9-ld"
ENV DARWIN_AR="$TOOLCHAIN/bin/i386-apple-darwin9-ar"
ENV DARWIN_RANLIB="$TOOLCHAIN/bin/i386-apple-darwin9-ranlib"
ENV DARWIN_STRIP="$TOOLCHAIN/bin/i386-apple-darwin9-strip"
ENV DARWIN_LIPO="$TOOLCHAIN/bin/i386-apple-darwin9-lipo"
ENV DARWIN_SDK="$SDK"

# Mount the PureDarwin repository here at runtime.
WORKDIR /repo

# Default command: run the full build → assemble image.
CMD ["sh", "-c", "./setup/pd_build_linux && echo 'Build complete. Run pd_setup_linux to assemble the disk image.'"]
