#!/bin/bash
# ============================================================================
# Download FFmpeg 4.4.4 (Stable and tested with PJSIP)
# ============================================================================

set -e
set -x

echo "========================================"
echo "Downloading FFmpeg 4.4.4"
echo "========================================"

DEPS_ROOT=/c/video_deps

cd "$DEPS_ROOT"

# Remove old FFmpeg if exists
if [ -d "ffmpeg-6.0" ]; then
    echo "Removing FFmpeg 6.0..."
    rm -rf ffmpeg-6.0
fi

# Download FFmpeg 4.4.4
if [ ! -f "ffmpeg-4.4.4.tar.xz" ]; then
    echo "Downloading FFmpeg 4.4.4..."
    curl -L -o ffmpeg-4.4.4.tar.xz https://ffmpeg.org/releases/ffmpeg-4.4.4.tar.xz
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to download FFmpeg 4.4.4"
        exit 1
    fi
fi

# Extract
if [ ! -d "ffmpeg-4.4.4" ]; then
    echo "Extracting FFmpeg 4.4.4..."
    tar -xf ffmpeg-4.4.4.tar.xz
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to extract FFmpeg"
        exit 1
    fi
fi

# Create symlink for compatibility with build scripts
ln -sf ffmpeg-4.4.4 ffmpeg-6.0

echo ""
echo "========================================"
echo "FFmpeg 4.4.4 Download Complete"
echo "========================================"
echo "Source directory: $DEPS_ROOT/ffmpeg-4.4.4"
echo "Symlink: $DEPS_ROOT/ffmpeg-6.0 -> ffmpeg-4.4.4"
echo ""
echo "Next: Run build_ffmpeg_windows.sh"
