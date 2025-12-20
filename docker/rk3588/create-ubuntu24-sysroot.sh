#!/bin/bash
# 直接使用Ubuntu 24.04的Docker镜像作为基础，并复制必要的库

echo "创建完整的Ubuntu 24.04 ARM64 sysroot..."

# 使用Docker创建sysroot
docker run --rm -v "$(pwd)/docker/rk3588/ubuntu24-sysroot:/output" ubuntu:24.04 bash -c "
    # 安装基础编译依赖
    apt-get update && apt-get install -y \
        libc6-dev \
        libstdc++-13-dev \
        libgcc-13-dev \
        libssl-dev \
        libsqlite3-dev \
        libasound2-dev \
        libpulse-dev \
        libsdl2-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        libexpat1-dev \
        libicu-dev \
        libglib2.0-dev \
        libdbus-1-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        libx11-dev \
        libxext-dev \
        libxi-dev \
        libxrandr-dev \
        libxcursor-dev \
        libxinerama-dev \
        libxxf86vm-dev \
        libwayland-dev \
        libxcb-dri2-0-dev \
        libbrotli-dev \
        libbz2-dev \
        liblz4-dev \
        libzstd-dev \
        libsystemd-dev \
        libudev-dev \
        libcap-dev \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswscale-dev \
        libswresample-dev \
        2>&1

    # 复制所有库文件到输出目录
    echo '复制库文件...'
    cp -r /usr/lib/aarch64-linux-gnu /output/usr-lib-aarch64-linux-gnu
    cp -r /lib/aarch64-linux-gnu /output/lib-aarch64-linux-gnu
    cp -r /usr/include /output/usr-include

    echo '创建sysroot完成'
"

echo "Sysroot创建完成！"