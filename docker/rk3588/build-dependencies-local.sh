#!/bin/bash
set -e

# RK3588 依赖库交叉编译脚本 - 使用本地源码
# 所有源码从 /workspace/video_deps 挂载

echo "========================================="
echo "RK3588 依赖库交叉编译 (使用本地源码)"
echo "========================================="

# 环境变量
export PREFIX=/opt/rk3588-libs
export TOOLCHAIN_PREFIX=aarch64-linux-gnu
export SYSROOT=/opt/sysroot/pi-root
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR=${PREFIX}/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
export CORES=$(nproc)

# 编译选项
export CFLAGS="-O2 -pipe --sysroot=${SYSROOT} -I${PREFIX}/include -I${SYSROOT}/usr/include -I${SYSROOT}/usr/include/aarch64-linux-gnu"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="--sysroot=${SYSROOT} -L${PREFIX}/lib -L${SYSROOT}/usr/lib/aarch64-linux-gnu -L${SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${PREFIX}/lib"

# 创建输出目录
mkdir -p ${PREFIX}/lib ${PREFIX}/include ${PREFIX}/bin

# 工作目录
BUILD_DIR=/tmp/rk3588_build
mkdir -p ${BUILD_DIR}

# ==================== OpenSSL 3.3.2 ====================
build_openssl() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libssl.so" ]; then
        echo "⏭️  跳过 OpenSSL (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 OpenSSL 3.3.2 (从本地源码)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -f "/workspace/video_deps/openssl-3.3.2.tar.gz" ]; then
        echo "❌ 错误: 找不到 /workspace/video_deps/openssl-3.3.2.tar.gz"
        exit 1
    fi

    echo "解压 OpenSSL..."
    tar xzf /workspace/video_deps/openssl-3.3.2.tar.gz
    cd openssl-3.3.2

    echo "配置 OpenSSL for ARM64..."
    ./Configure linux-aarch64 \
        --prefix=${PREFIX} \
        --openssldir=${PREFIX}/ssl \
        --cross-compile-prefix=${TOOLCHAIN_PREFIX}- \
        shared \
        no-ssl3 \
        no-weak-ssl-ciphers \
        ${CFLAGS} \
        ${LDFLAGS}

    echo "编译 OpenSSL..."
    make -j${CORES}
    make install_sw install_ssldirs

    echo "✅ OpenSSL 3.3.2 编译完成"
}

# ==================== Opus 1.4 ====================
build_opus() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libopus.so" ]; then
        echo "⏭️  跳过 Opus (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 Opus 1.4 (需下载)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "opus-1.4" ]; then
        echo "下载 Opus 1.4..."
        wget https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz
        tar xzf opus-1.4.tar.gz
    fi

    cd opus-1.4

    echo "配置 Opus..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --disable-static

    echo "编译 Opus..."
    make -j${CORES}
    make install

    echo "✅ Opus 1.4 编译完成"
}

# ==================== x264 ====================
build_x264() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libx264.so" ]; then
        echo "⏭️  跳过 x264 (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 x264 (从本地源码)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "/workspace/video_deps/x264_src" ]; then
        echo "❌ 错误: 找不到 /workspace/video_deps/x264_src"
        exit 1
    fi

    echo "复制 x264 源码..."
    cp -r /workspace/video_deps/x264_src ./x264
    cd x264

    echo "转换 x264 所有脚本换行符..."
    # 转换所有可能的脚本文件
    for file in configure config.* *.sh build/*.sh tools/*.sh; do
        if [ -f "$file" ]; then
            sed -i 's/\r$//' "$file" 2>/dev/null || true
        fi
    done
    # 确保可执行
    chmod +x configure config.* 2>/dev/null || true

    echo "配置 x264..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --cross-prefix=${TOOLCHAIN_PREFIX}- \
        --sysroot=${SYSROOT} \
        --enable-shared \
        --enable-pic

    echo "编译 x264..."
    make -j${CORES}
    make install

    echo "✅ x264 编译完成"
}

# ==================== FFmpeg 4.4.4 ====================
build_ffmpeg() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libavcodec.so" ]; then
        echo "⏭️  跳过 FFmpeg (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 FFmpeg 4.4.4 (从本地源码)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -f "/workspace/video_deps/ffmpeg-4.4.4.tar.xz" ]; then
        echo "❌ 错误: 找不到 /workspace/video_deps/ffmpeg-4.4.4.tar.xz"
        exit 1
    fi

    echo "解压 FFmpeg..."
    tar xf /workspace/video_deps/ffmpeg-4.4.4.tar.xz
    cd ffmpeg-4.4.4

    echo "配置 FFmpeg..."
    ./configure \
        --prefix=${PREFIX} \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN_PREFIX}- \
        --arch=aarch64 \
        --target-os=linux \
        --sysroot=${SYSROOT} \
        --extra-cflags="${CFLAGS}" \
        --extra-ldflags="${LDFLAGS}" \
        --pkg-config=pkg-config \
        --enable-shared \
        --disable-static \
        --enable-gpl \
        --enable-libx264 \
        --disable-doc \
        --disable-htmlpages \
        --disable-manpages

    echo "编译 FFmpeg..."
    make -j${CORES}
    make install

    echo "✅ FFmpeg 4.4.4 编译完成"
}

# ==================== SDL2 2.28.5 ====================
build_sdl2() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libSDL2.so" ]; then
        echo "⏭️  跳过 SDL2 (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 SDL2 2.28.5 (需下载源码)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "SDL2-2.28.5" ]; then
        echo "下载 SDL2 2.28.5 源码..."
        wget https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz
        tar xzf SDL2-2.28.5.tar.gz
    fi

    cd SDL2-2.28.5

    echo "配置 SDL2..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --disable-static

    echo "编译 SDL2..."
    make -j${CORES}
    make install

    echo "✅ SDL2 2.28.5 编译完成"
}

# ==================== libjpeg-turbo 3.0.1 ====================
build_libjpeg() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libjpeg.so" ]; then
        echo "⏭️  跳过 libjpeg-turbo (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 libjpeg-turbo 3.0.1 (需下载)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "libjpeg-turbo-3.0.1" ]; then
        echo "下载 libjpeg-turbo 3.0.1..."
        wget https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.1/libjpeg-turbo-3.0.1.tar.gz
        tar xzf libjpeg-turbo-3.0.1.tar.gz
    fi

    cd libjpeg-turbo-3.0.1

    echo "配置 libjpeg-turbo 使用 CMake..."
    cmake -G "Unix Makefiles" \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DCMAKE_FIND_ROOT_PATH="${SYSROOT};${PREFIX}" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_INSTALL_PREFIX=${PREFIX} \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DENABLE_SHARED=ON \
        -DENABLE_STATIC=OFF \
        .

    echo "编译 libjpeg-turbo..."
    make -j${CORES}
    make install

    echo "✅ libjpeg-turbo 3.0.1 编译完成"
}

# ==================== ALSA-lib 1.2.10 ====================
build_alsa() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libasound.so" ]; then
        echo "⏭️  跳过 ALSA-lib (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 ALSA-lib 1.2.10 (需下载)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "alsa-lib-1.2.10" ]; then
        echo "下载 ALSA-lib 1.2.10..."
        wget https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.10.tar.bz2
        tar xjf alsa-lib-1.2.10.tar.bz2
    fi

    cd alsa-lib-1.2.10

    echo "配置 ALSA-lib..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --disable-static \
        --disable-python

    echo "编译 ALSA-lib..."
    make -j${CORES}
    make install

    echo "✅ ALSA-lib 1.2.10 编译完成"
}

# ==================== v4l-utils 1.24.1 ====================
build_v4l_utils() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libv4l2.so" ]; then
        echo "⏭️  跳过 v4l-utils (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 v4l-utils 1.24.1 (需下载)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -d "v4l-utils-1.24.1" ]; then
        echo "下载 v4l-utils 1.24.1..."
        wget https://linuxtv.org/downloads/v4l-utils/v4l-utils-1.24.1.tar.bz2
        tar xjf v4l-utils-1.24.1.tar.bz2
    fi

    cd v4l-utils-1.24.1

    echo "配置 v4l-utils..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --disable-static \
        --disable-v4l-utils \
        --disable-qv4l2 \
        --disable-qvidcap

    echo "编译 v4l-utils..."
    make -j${CORES}
    make install

    echo "✅ v4l-utils 1.24.1 编译完成"
}

# ==================== PJSIP 2.15.1 ====================
build_pjsip() {
    # 检查是否已编译
    if [ -f "${PREFIX}/lib/libpjsip.so" ]; then
        echo "⏭️  跳过 PJSIP (已编译)"
        return 0
    fi

    echo "========================================="
    echo "编译 PJSIP 2.15.1 (从本地源码)"
    echo "========================================="

    cd ${BUILD_DIR}

    if [ ! -f "/workspace/belt_control_system/libs/pjproject-2.15.1.zip" ]; then
        echo "❌ 错误: 找不到 /workspace/belt_control_system/libs/pjproject-2.15.1.zip"
        exit 1
    fi

    echo "解压 PJSIP (使用 Python)..."
    python3 -m zipfile -e /workspace/belt_control_system/libs/pjproject-2.15.1.zip .
    cd pjproject-2.15.1

    echo "设置 PJSIP 脚本执行权限..."
    chmod +x configure aconfigure config.sub config.guess install-sh 2>/dev/null || true
    find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    echo "配置 PJSIP (启用视频支持)..."
    ./configure \
        --prefix=${PREFIX} \
        --host=${TOOLCHAIN_PREFIX} \
        --enable-shared \
        --with-ffmpeg=${PREFIX} \
        --with-sdl=${PREFIX} \
        CFLAGS="${CFLAGS} -I${PREFIX}/include/SDL2" \
        CXXFLAGS="${CXXFLAGS} -I${PREFIX}/include/SDL2" \
        LDFLAGS="${LDFLAGS}" \
        LIBS="-lx264 -lswresample -lz -lv4l2 -ljpeg"

    echo "应用自定义 config_site.h (启用 FFmpeg + SDL)..."
    cp /workspace/belt_control_system/docker/rk3588/pjsip_config_site.h pjlib/include/pj/config_site.h

    echo "编译 PJSIP..."
    make dep
    make -j${CORES}
    make install

    echo "✅ PJSIP 2.15.1 编译完成"
}

# ==================== 主流程 ====================

echo ""
echo "编译目标: ARM64 (aarch64)"
echo "工具链: ${TOOLCHAIN_PREFIX}"
echo "Sysroot: ${SYSROOT}"
echo "输出目录: ${PREFIX}"
echo "并行任务数: ${CORES}"
echo ""

# 按依赖顺序编译
build_openssl
build_opus
build_x264
build_ffmpeg
build_sdl2
build_libjpeg
build_alsa
build_v4l_utils
build_pjsip

echo ""
echo "========================================="
echo "✅ 所有库编译完成！"
echo "========================================="
echo "输出位置: ${PREFIX}"
echo ""
echo "编译的库:"
ls -lh ${PREFIX}/lib/*.so* 2>/dev/null | head -20 || echo "库文件生成中..."
echo ""
