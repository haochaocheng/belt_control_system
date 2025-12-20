# Ubuntu 24.04 ARM64编译环境 - 利用已有Qt和库
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装基础工具
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    # ARM64交叉编译器
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    # 必要的开发库
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制已有的Qt和库（构建时会挂载）
# qt-host: Qt主机工具
# qt-raspi: 交叉编译的Qt库
# 已编译的库: ffmpeg, x264, SDL, PJSIP

# 创建工具链文件
RUN cat > /opt/toolchain.cmake << 'EOF'
# ARM64交叉编译工具链
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 编译器
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# Qt路径（从挂载的目录）
set(QT_HOST_PATH /opt/qt-host)
set(QT_TARGET_PATH /opt/qt-raspi)
set(Qt6_DIR ${QT_TARGET_PATH}/lib/cmake/Qt6)

# 库路径
set(CMAKE_PREFIX_PATH "${QT_TARGET_PATH};/opt/libs")

# 编译标志
set(CMAKE_C_FLAGS "-march=armv8-a")
set(CMAKE_CXX_FLAGS "-march=armv8-a")

# 搜索路径
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# 链接已编译的库
set(CMAKE_EXE_LINKER_FLAGS "-L/opt/libs/lib -Wl,-rpath-link,/opt/libs/lib")
EOF

# 构建脚本
RUN cat > /opt/build.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "Ubuntu 24.04 ARM64 Build with Existing Libs"
echo "=========================================="

# 检查必要的挂载
if [ ! -d "/opt/qt-host" ]; then
    echo "错误: 未挂载qt-host目录"
    exit 1
fi

if [ ! -d "/opt/qt-raspi" ]; then
    echo "错误: 未挂载qt-raspi目录"
    exit 1
fi

cd /workspace
rm -rf build
mkdir build
cd build

echo "配置CMake..."
cmake -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=/opt/toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_HOST_PATH=/opt/qt-host \
    -DQT_COMPILER_PATH=/opt/qt-raspi \
    ..

echo "开始编译..."
ninja -j$(nproc)

echo "✓ 编译完成！"
ls -lh belt_control_system 2>/dev/null || true
EOF

RUN chmod +x /opt/build.sh

WORKDIR /workspace
CMD ["/opt/build.sh"]