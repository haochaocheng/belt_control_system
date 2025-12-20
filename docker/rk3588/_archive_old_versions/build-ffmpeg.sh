#!/bin/bash
set -e

echo "==========================================="
echo "FFmpeg ARM64 交叉编译 (glibc 2.36)"
echo "==========================================="

# 检查环境
if [ ! -d "$SYSROOT" ]; then
    echo "❌ 错误: SYSROOT 未设置或不存在"
    exit 1
fi

echo "Sysroot: $SYSROOT"
echo "Target: aarch64-linux-gnu"
echo ""

# 创建临时构建目录
BUILD_DIR="/tmp/ffmpeg-build"
INSTALL_DIR="/opt/rk3588-libs"

mkdir -p $BUILD_DIR
cd $BUILD_DIR

# 下载FFmpeg (如果不存在)
if [ ! -d "ffmpeg" ]; then
    echo "📥 下载 FFmpeg 4.4.5..."
    wget -q https://ffmpeg.org/releases/ffmpeg-4.4.5.tar.xz
    tar -xf ffmpeg-4.4.5.tar.xz
    mv ffmpeg-4.4.5 ffmpeg
    echo "✅ FFmpeg 源码已准备"
fi

cd ffmpeg

echo ""
echo "🔧 配置 FFmpeg..."
echo ""

# 配置FFmpeg用于ARM64交叉编译
./configure \
    --prefix=$INSTALL_DIR \
    --enable-cross-compile \
    --cross-prefix=aarch64-linux-gnu- \
    --arch=aarch64 \
    --target-os=linux \
    --sysroot=$SYSROOT \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --enable-libx264 \
    --disable-debug \
    --disable-programs \
    --disable-ffmpeg \
    --disable-ffplay \
    --disable-ffprobe \
    --extra-cflags="-I$SYSROOT/usr/include -march=armv8-a" \
    --extra-ldflags="-L$SYSROOT/usr/lib/aarch64-linux-gnu -L$SYSROOT/lib/aarch64-linux-gnu" \
    --pkg-config=pkg-config

echo ""
echo "🔨 编译 FFmpeg (仅库文件)..."
echo ""

# 只编译库
make -j$(nproc)

echo ""
echo "📦 安装 FFmpeg 库..."
echo ""

# 安装到rk3588-libs目录
make install

echo ""
echo "✅ FFmpeg 编译完成!"
echo "   库文件位于: $INSTALL_DIR/lib"
echo ""

# 列出编译的库
ls -lh $INSTALL_DIR/lib/libav*.so*

echo ""
echo "==========================================="
