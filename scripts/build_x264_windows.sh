#!/bin/bash
# ============================================================================
# x264 Compilation Script for Windows (MSYS2)
# ============================================================================
# This script compiles x264 (H.264 encoder) for Windows using MSYS2
#
# Requirements:
#   - MSYS2 with MinGW-w64 toolchain
#   - x264 source code (downloaded by setup script)
#
# Output:
#   - libx264.dll, libx264.lib, headers
#   - Installed to C:/x264
# ============================================================================

set -e  # Exit on error
set -x  # Print commands

echo "========================================"
echo "Building x264 for Windows"
echo "========================================"

# Configuration
DEPS_ROOT=/c/video_deps
X264_SRC=${DEPS_ROOT}/x264_src
X264_INSTALL=/c/x264
JOBS=8

# Check source directory
if [ ! -d "$X264_SRC" ]; then
    echo "ERROR: x264 source not found at $X264_SRC"
    echo "Please run setup_video_dependencies_windows.bat first"
    exit 1
fi

cd "$X264_SRC"

# Clean previous build
echo "Cleaning previous build..."
make distclean 2>/dev/null || true

# Configure x264
echo "Configuring x264..."
./configure \
    --prefix="$X264_INSTALL" \
    --enable-shared \
    --enable-static \
    --enable-pic \
    --disable-cli \
    --bit-depth=8

# Build
echo "Building x264 (using $JOBS threads)..."
make -j${JOBS}

# Install
echo "Installing x264 to $X264_INSTALL..."
make install

# Verify installation
if [ -f "${X264_INSTALL}/lib/libx264.dll.a" ]; then
    echo "========================================"
    echo "x264 Build SUCCESS"
    echo "========================================"
    echo "Installation directory: $X264_INSTALL"
    echo "Library: ${X264_INSTALL}/lib/libx264.dll.a"
    echo "Headers: ${X264_INSTALL}/include/x264.h"
    ls -lh ${X264_INSTALL}/lib/
    echo ""
    echo "Next step: Run build_ffmpeg_windows.sh"
else
    echo "ERROR: x264 build failed - library not found"
    exit 1
fi
