#!/bin/bash
set -e

###############################################################################
# RK3588 依赖库交叉编译脚本
# 编译 PJSIP, FFmpeg, SDL2, x264 等库
###############################################################################

echo "========================================="
echo "RK3588 依赖库交叉编译"
echo "========================================="

# 配置
PREFIX=/opt/rk3588-libs
SYSROOT=${SYSROOT:-/opt/sysroot}
TOOLCHAIN_PREFIX=aarch64-linux-gnu
BUILD_DIR=/tmp/build_deps
CORES=$(nproc)

# 交叉编译工具
export CC=${TOOLCHAIN_PREFIX}-gcc
export CXX=${TOOLCHAIN_PREFIX}-g++
export AR=${TOOLCHAIN_PREFIX}-ar
export AS=${TOOLCHAIN_PREFIX}-as
export LD=${TOOLCHAIN_PREFIX}-ld
export RANLIB=${TOOLCHAIN_PREFIX}-ranlib
export STRIP=${TOOLCHAIN_PREFIX}-strip

# 编译标志
export CFLAGS="-O2 -march=armv8-a --sysroot=${SYSROOT}"
export CXXFLAGS="-O2 -march=armv8-a --sysroot=${SYSROOT}"
export LDFLAGS="--sysroot=${SYSROOT} -L${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"

mkdir -p ${BUILD_DIR}
mkdir -p ${PREFIX}/{lib,include}

###############################################################################
# 0. OpenSSL (加密库 - 最先编译，其他库可能依赖)
###############################################################################
build_openssl() {
    echo "========================================="
    echo "编译 OpenSSL"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "openssl-3.3.2" ]; then
        echo "下载 OpenSSL 3.3.2 (匹配Windows版本)"
        wget https://www.openssl.org/source/openssl-3.3.2.tar.gz
        tar xzf openssl-3.3.2.tar.gz
    fi

    cd openssl-3.3.2

    # 配置 OpenSSL for ARM64
    ./Configure linux-aarch64 \
        --prefix=${PREFIX} \
        --openssldir=${PREFIX}/ssl \
        --cross-compile-prefix=${TOOLCHAIN_PREFIX}- \
        shared \
        no-ssl3 \
        no-weak-ssl-ciphers \
        ${CFLAGS} \
        ${LDFLAGS}

    make -j${CORES}
    make install_sw install_ssldirs

    echo "✅ OpenSSL 3.3.2 编译完成 (匹配Windows版本)"
}

###############################################################################
# 1. x264 (H.264编码器)
###############################################################################
build_x264() {
    echo "========================================="
    echo "编译 x264"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "x264" ]; then
        git clone --depth 1 https://code.videolan.org/videolan/x264.git
    fi

    cd x264

    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --cross-prefix=${TOOLCHAIN_PREFIX}- \
        --sysroot=${SYSROOT} \
        --enable-shared \
        --enable-static \
        --enable-pic

    make -j${CORES}
    make install

    echo "✅ x264 编译完成"
}

###############################################################################
# 2. FFmpeg (视频处理)
###############################################################################
build_ffmpeg() {
    echo "========================================="
    echo "编译 FFmpeg"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "ffmpeg-4.4.4" ]; then
        # 使用 FFmpeg 4.4.4 以匹配Windows版本
        echo "下载 FFmpeg 4.4.4 (匹配Windows版本)"
        wget https://ffmpeg.org/releases/ffmpeg-4.4.4.tar.xz
        tar xf ffmpeg-4.4.4.tar.xz
    fi

    cd ffmpeg-4.4.4

    ./configure \
        --prefix=${PREFIX} \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN_PREFIX}- \
        --arch=aarch64 \
        --target-os=linux \
        --sysroot=${SYSROOT} \
        --pkg-config=pkg-config \
        --enable-shared \
        --disable-static \
        --enable-gpl \
        --enable-nonfree \
        --enable-libx264 \
        --enable-encoder=libx264 \
        --enable-decoder=h264 \
        --enable-protocol=file,rtp,udp \
        --disable-doc \
        --disable-programs \
        --extra-cflags="-I${PREFIX}/include" \
        --extra-ldflags="-L${PREFIX}/lib"

    make -j${CORES}
    make install

    echo "✅ FFmpeg 4.4.4 编译完成 (匹配Windows版本)"
}

###############################################################################
# 3. SDL2 (媒体库)
###############################################################################
build_sdl2() {
    echo "========================================="
    echo "编译 SDL2"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "SDL2" ]; then
        wget https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz
        tar xzf SDL2-2.28.5.tar.gz
        mv SDL2-2.28.5 SDL2
    fi

    cd SDL2
    mkdir -p build && cd build

    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE=/workspace/belt_control_system/docker/rk3588/toolchain-rk3588.cmake \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DSDL_SHARED=ON \
        -DSDL_STATIC=OFF

    make -j${CORES}
    make install

    echo "✅ SDL2 编译完成"
}

###############################################################################
# 4. PJSIP (SIP协议栈)
###############################################################################
build_pjsip() {
    echo "========================================="
    echo "编译 PJSIP"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "pjproject-2.15.1" ]; then
        # 优先使用本地压缩包 (从Windows环境挂载)
        if [ -f "/workspace/belt_control_system/libs/pjproject-2.15.1.zip" ]; then
            echo "使用本地 pjproject-2.15.1.zip"
            unzip -q /workspace/belt_control_system/libs/pjproject-2.15.1.zip
        elif [ -f "/workspace/belt_control_system/libs/pjproject-2.15.1.7z" ]; then
            echo "使用本地 pjproject-2.15.1.7z"
            7z x /workspace/belt_control_system/libs/pjproject-2.15.1.7z
        else
            echo "从GitHub下载 pjproject 2.15.1"
            wget https://github.com/pjsip/pjproject/archive/refs/tags/2.15.1.tar.gz -O pjproject-2.15.1.tar.gz
            tar xzf pjproject-2.15.1.tar.gz
        fi
    fi

    cd pjproject-2.15.1

    # 配置文件
    cat > user.mak << 'EOF'
export CFLAGS += -fPIC
export LDFLAGS +=
EOF

    # 配置
    ./configure \
        --host=${TOOLCHAIN_PREFIX} \
        --prefix=${PREFIX} \
        --disable-oss \
        --enable-shared \
        --disable-video \
        --disable-sound \
        --disable-ext-sound \
        CFLAGS="${CFLAGS} -fPIC" \
        LDFLAGS="${LDFLAGS}"

    make dep -j${CORES}
    make -j${CORES}
    make install

    echo "✅ PJSIP 2.15.1 编译完成"
}

###############################################################################
# 5. opus (音频编码)
###############################################################################
build_opus() {
    echo "========================================="
    echo "编译 Opus"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "opus" ]; then
        git clone --depth 1 --branch v1.4 https://github.com/xiph/opus.git
    fi

    cd opus

    ./autogen.sh

    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --disable-static

    make -j${CORES}
    make install

    echo "✅ Opus 编译完成"
}

###############################################################################
# 主函数
###############################################################################
main() {
    echo "开始编译依赖库..."
    echo "目标平台: ARM64 (aarch64)"
    echo "安装路径: ${PREFIX}"
    echo "Sysroot: ${SYSROOT}"
    echo "并行任务: ${CORES}"
    echo ""

    # 按依赖顺序编译
    # OpenSSL 最先编译（其他库可能依赖）
    build_openssl
    build_opus
    build_x264
    build_ffmpeg
    build_sdl2
    build_pjsip

    echo ""
    echo "========================================="
    echo "✅ 所有依赖库编译完成！"
    echo "========================================="
    echo "安装路径: ${PREFIX}"
    echo ""
    echo "已编译的库："
    ls -lh ${PREFIX}/lib/*.so* | head -20
    echo ""
    echo "请将 ${PREFIX} 目录复制到项目的 libs/ 目录"
}

# 允许单独编译某个库
if [ $# -eq 0 ]; then
    main
else
    case "$1" in
        openssl)
            build_openssl
            ;;
        x264)
            build_x264
            ;;
        ffmpeg)
            build_ffmpeg
            ;;
        sdl2)
            build_sdl2
            ;;
        pjsip)
            build_pjsip
            ;;
        opus)
            build_opus
            ;;
        *)
            echo "用法: $0 [openssl|x264|ffmpeg|sdl2|pjsip|opus]"
            echo "不带参数则编译所有库"
            exit 1
            ;;
    esac
fi
