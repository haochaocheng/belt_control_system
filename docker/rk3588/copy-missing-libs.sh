#!/bin/bash
# 复制缺失的系统库到 rk3588-libs

SRC="/opt/sysroot/pi-root/usr/lib/aarch64-linux-gnu"
DST="/opt/rk3588-libs/lib"

echo "Copying missing system libraries..."

# 所有缺失的库模式
LIBS=(
    "libfreetype.so*"
    "libfontconfig.so*"
    "libharfbuzz.so*"
    "libgraphite2.so*"
    "libglib-2.0.so*"
    "libffi.so*"
    "libXau.so*"
    "libxcb.so*"
    "libxkbcommon.so*"
    "libGLdispatch.so*"
    "libdrm.so*"
    "libudev.so*"
    "libsystemd.so*"
    "libdbus-1.so*"
    "libuuid.so*"
    "libgcrypt.so*"
    "libsndfile.so*"
    "libvorbis*.so*"
    "libogg.so*"
    "libFLAC.so*"
    "libpulse*.so*"
    "libmd.so*"
    "libpcre2*.so*"
    "libexpat.so*"
    "libgpg-error.so*"
)

# Also check lib directory (not just usr/lib)
SRC2="/opt/sysroot/pi-root/lib/aarch64-linux-gnu"

copied=0
for pattern in "${LIBS[@]}"; do
    # Copy from usr/lib/aarch64-linux-gnu
    for file in $SRC/$pattern; do
        if [ -f "$file" ]; then
            cp "$file" "$DST/" 2>/dev/null && ((copied++))
        fi
    done

    # Copy from lib/aarch64-linux-gnu
    for file in $SRC2/$pattern; do
        if [ -f "$file" ]; then
            cp "$file" "$DST/" 2>/dev/null && ((copied++))
        fi
    done
done

echo "Copied $copied library files"
ls -lh "$DST" | wc -l
echo " total files in $DST"
