#!/bin/bash
# ============================================================================
# FFmpeg Compilation Script for Windows (MSYS2) - 简化版本
# ============================================================================
# 禁用汇编优化以避免 MinGW 编译问题
# ============================================================================

set -e  # Exit on error
set -x  # Print commands

echo "========================================"
echo "Building FFmpeg 6.0 for Windows"
echo "========================================"

# Configuration
DEPS_ROOT=/c/video_deps
FFMPEG_SRC=${DEPS_ROOT}/ffmpeg-6.0
FFMPEG_INSTALL=/c/ffmpeg
X264_INSTALL=/c/x264
JOBS=4  # 降低并行度以减少内存使用

# Check x264 installation
if [ ! -f "${X264_INSTALL}/lib/libx264.dll.a" ]; then
    echo "ERROR: x264 not found at $X264_INSTALL"
    echo "Please run build_x264_windows.sh first"
    exit 1
fi

# Check FFmpeg source
if [ ! -d "$FFMPEG_SRC" ]; then
    echo "ERROR: FFmpeg source not found at $FFMPEG_SRC"
    echo "Please run setup_video_dependencies_windows.bat first"
    exit 1
fi

cd "$FFMPEG_SRC"

# Clean previous build
echo "Cleaning previous build..."
make distclean 2>/dev/null || true

# Set up environment
export PKG_CONFIG_PATH="${X264_INSTALL}/lib/pkgconfig:${PKG_CONFIG_PATH}"

# Configure FFmpeg - 禁用汇编优化以避免编译错误
echo "Configuring FFmpeg (without assembly optimizations)..."
./configure \
    --prefix="$FFMPEG_INSTALL" \
    --enable-shared \
    --disable-static \
    --enable-gpl \
    --enable-libx264 \
    --enable-decoder=h264 \
    --enable-encoder=libx264 \
    --enable-parser=h264 \
    --disable-programs \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --disable-avdevice \
    --disable-postproc \
    --disable-avfilter \
    --disable-asm \
    --disable-x86asm \
    --extra-cflags="-I${X264_INSTALL}/include" \
    --extra-ldflags="-L${X264_INSTALL}/lib"

# Build
echo "Building FFmpeg (using $JOBS threads)..."
echo "This may take 15-25 minutes without assembly optimizations..."
make -j${JOBS}

# Install
echo "Installing FFmpeg to $FFMPEG_INSTALL..."
make install

# Copy x264 DLL to FFmpeg bin directory
echo "Copying x264 DLL..."
mkdir -p ${FFMPEG_INSTALL}/bin
cp ${X264_INSTALL}/bin/libx264-*.dll ${FFMPEG_INSTALL}/bin/ 2>/dev/null || true

# Verify installation
echo ""
echo "========================================"
echo "Verifying FFmpeg installation..."
echo "========================================"

if [ -f "${FFMPEG_INSTALL}/lib/libavcodec.dll.a" ]; then
    echo "FFmpeg Build SUCCESS"
    echo ""
    echo "Installation directory: $FFMPEG_INSTALL"
    echo ""
    echo "Libraries:"
    ls -lh ${FFMPEG_INSTALL}/bin/*.dll 2>/dev/null || ls -lh ${FFMPEG_INSTALL}/lib/*.dll
    echo ""
    echo "Headers:"
    ls -d ${FFMPEG_INSTALL}/include/libav*
    echo ""
    echo "Note: Built without assembly optimizations for compatibility"
    echo "Performance may be slightly lower, but sufficient for video calling"
    echo ""
    echo "Next step: Run build_pjsip_windows.sh"
else
    echo "ERROR: FFmpeg build failed - libraries not found"
    exit 1
fi

echo ""
echo "========================================"
echo "FFmpeg Build Complete"
echo "========================================"
