#!/bin/bash
set -e

# 修复 GLIBC 版本问题的 FFmpeg 和 SDL2 编译脚本
# 目标：编译出兼容 glibc 2.31/2.36 的库（与 Qt6 相同）
#
# 核心修改：
# 1. 强制使用 sysroot 的 glibc，而不是容器内的 glibc 2.38
# 2. 添加 --with-libtool-sysroot 确保链接器使用 sysroot
# 3. 使用 -Wl,--sysroot 确保动态链接器也使用 sysroot

echo "========================================="
echo "修复版 FFmpeg 和 SDL2 编译 (兼容 glibc 2.31/2.36)"
echo "========================================="

# 环境变量
export PREFIX=/opt/rk3588-libs
export TOOLCHAIN_PREFIX=aarch64-linux-gnu
export SYSROOT=/opt/sysroot/pi-root
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR=${PREFIX}/lib/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
export CORES=$(nproc)

# 🔑 关键修改：确保使用 sysroot 的 glibc
# 添加 -Wl,--sysroot 和 -Wl,--dynamic-linker 参数
export CFLAGS="-O2 -pipe --sysroot=${SYSROOT} -I${PREFIX}/include -I${SYSROOT}/usr/include -I${SYSROOT}/usr/include/aarch64-linux-gnu"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="--sysroot=${SYSROOT} -L${PREFIX}/lib -L${SYSROOT}/usr/lib/aarch64-linux-gnu -L${SYSROOT}/lib/aarch64-linux-gnu -Wl,-rpath-link,${PREFIX}/lib -Wl,-rpath-link,${SYSROOT}/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,${SYSROOT}/lib/aarch64-linux-gnu -Wl,--sysroot=${SYSROOT} -Wl,--dynamic-linker=${SYSROOT}/lib/ld-linux-aarch64.so.1"

# 创建输出目录
mkdir -p ${PREFIX}/lib ${PREFIX}/include ${PREFIX}/bin

# 工作目录
BUILD_DIR=/tmp/rk3588_build
mkdir -p ${BUILD_DIR}

echo ""
echo "编译配置:"
echo "  目标架构: aarch64"
echo "  工具链: ${TOOLCHAIN_PREFIX}"
echo "  Sysroot: ${SYSROOT}"
echo "  Sysroot glibc: $(${TOOLCHAIN_PREFIX}-gcc --sysroot=${SYSROOT} -print-file-name=libc.so.6)"
echo "  输出目录: ${PREFIX}"
echo "  并行任务: ${CORES}"
echo ""

# ==================== FFmpeg 4.4.4 ====================
build_ffmpeg() {
    echo "========================================="
    echo "重新编译 FFmpeg 4.4.4 (兼容 glibc ≤ 2.36)"
    echo "========================================="

    cd ${BUILD_DIR}

    # 清理旧的编译
    rm -rf ffmpeg-4.4.4

    if [ ! -f "/workspace/video_deps/ffmpeg-4.4.4.tar.xz" ]; then
        echo "❌ 错误: 找不到 /workspace/video_deps/ffmpeg-4.4.4.tar.xz"
        exit 1
    fi

    echo "解压 FFmpeg..."
    tar xf /workspace/video_deps/ffmpeg-4.4.4.tar.xz
    cd ffmpeg-4.4.4

    echo "配置 FFmpeg (使用 sysroot glibc)..."
    ./configure \
        --prefix=${PREFIX} \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN_PREFIX}- \
        --arch=aarch64 \
        --target-os=linux \
        --sysroot=${SYSROOT} \
        --sysinclude=${SYSROOT}/usr/include \
        --extra-cflags="${CFLAGS}" \
        --extra-ldflags="${LDFLAGS}" \
        --extra-libs="-lgcc_s" \
        --pkg-config=pkg-config \
        --enable-shared \
        --disable-static \
        --enable-gpl \
        --enable-libx264 \
        --disable-doc \
        --disable-htmlpages \
        --disable-manpages \
        --disable-podpages \
        --disable-txtpages

    echo "编译 FFmpeg..."
    make -j${CORES}

    echo "安装 FFmpeg..."
    make install

    echo ""
    echo "✅ FFmpeg 编译完成，检查 glibc 依赖..."
    strings ${PREFIX}/lib/libavutil.so | grep GLIBC_ | sort -u | tail -5
    echo ""
}

# ==================== SDL2 2.28.5 ====================
build_sdl2() {
    echo "========================================="
    echo "重新编译 SDL2 2.28.5 (兼容 glibc ≤ 2.36)"
    echo "========================================="

    cd ${BUILD_DIR}

    # 清理旧的编译
    rm -rf SDL2-2.28.5

    if [ ! -d "/workspace/video_deps/SDL2-2.28.5" ]; then
        echo "❌ 错误: 找不到 /workspace/video_deps/SDL2-2.28.5 目录"
        echo "尝试解压..."
        if [ -f "/workspace/video_deps/SDL2-devel-2.28.5-VC.zip" ]; then
            # 这是 VC 版本，需要源码 tar.gz
            echo "❌ 需要 SDL2-2.28.5.tar.gz 源码包，而不是 VC 开发包"
            exit 1
        fi
        exit 1
    fi

    echo "复制 SDL2 源码..."
    cp -r /workspace/video_deps/SDL2-2.28.5 ./
    cd SDL2-2.28.5

    # 如果有 configure 脚本，使用 autotools
    if [ -f "configure" ]; then
        echo "配置 SDL2 (使用 autotools + sysroot glibc)..."
        ./configure \
            --prefix=${PREFIX} \
            --host=${TOOLCHAIN_PREFIX} \
            --with-sysroot=${SYSROOT} \
            --enable-shared \
            --disable-static

        echo "编译 SDL2..."
        make -j${CORES}
        make install
    else
        # 使用 CMake
        echo "配置 SDL2 (使用 CMake + sysroot glibc)..."
        cmake -B build \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
            -DCMAKE_C_COMPILER=${TOOLCHAIN_PREFIX}-gcc \
            -DCMAKE_CXX_COMPILER=${TOOLCHAIN_PREFIX}-g++ \
            -DCMAKE_SYSROOT=${SYSROOT} \
            -DCMAKE_FIND_ROOT_PATH="${SYSROOT};${PREFIX}" \
            -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
            -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
            -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
            -DCMAKE_INSTALL_PREFIX=${PREFIX} \
            -DCMAKE_C_FLAGS="${CFLAGS}" \
            -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
            -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
            -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
            -DBUILD_SHARED_LIBS=ON \
            -DSDL_STATIC=OFF

        echo "编译 SDL2..."
        cmake --build build -j${CORES}
        cmake --install build
    fi

    echo ""
    echo "✅ SDL2 编译完成，检查 glibc 依赖..."
    strings ${PREFIX}/lib/libSDL2*.so | grep GLIBC_ | sort -u | tail -5
    echo ""
}

# ==================== 主流程 ====================

# 按顺序编译
build_ffmpeg
build_sdl2

echo ""
echo "========================================="
echo "✅ 编译完成！"
echo "========================================="
echo ""
echo "检查编译结果的 glibc 版本:"
echo ""
echo "FFmpeg libavutil.so:"
strings ${PREFIX}/lib/libavutil.so* | grep GLIBC_ | sort -Vu | tail -5
echo ""
echo "SDL2 libSDL2-2.0.so:"
strings ${PREFIX}/lib/libSDL2-2.0.so* | grep GLIBC_ | sort -Vu | tail -5
echo ""
echo "Qt6 libQt6Core.so (参考):"
strings /opt/qt-raspi/lib/libQt6Core.so* | grep GLIBC_ | sort -Vu | tail -5
echo ""
echo "⚠️  如果上面的最高版本超过 GLIBC_2.35，说明仍然链接到容器的 glibc 2.38"
echo "✅ 如果最高版本 ≤ GLIBC_2.35，说明成功使用 sysroot 的 glibc"
echo ""
echo "编译的库文件:"
ls -lh ${PREFIX}/lib/*.so* 2>/dev/null | grep -E '(libav|libSDL)' || echo "未找到库文件"
echo ""
