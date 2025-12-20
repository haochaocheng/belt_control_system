# RK3588 Cross-Compilation Environment - Ubuntu 24.04
# Docker交叉编译环境（用于Windows上构建ARM64二进制文件）
# 只安装交叉编译工具链，开发头文件和库从外部sysroot获取

FROM ubuntu:24.04

# 设置非交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装交叉编译工具链和构建工具（不安装ARM64开发包）
RUN apt-get update && apt-get install -y --no-install-recommends \
    # 交叉编译工具链
    crossbuild-essential-arm64 \
    g++-aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    # 构建工具
    cmake \
    ninja-build \
    make \
    git \
    pkg-config \
    file \
    # Qt工具运行时依赖（AMD64）- qmlimportscanner和qmlcachegen需要
    libpcre2-16-0:amd64 \
    libicu74:amd64 \
    libglib2.0-0:amd64 \
    libdouble-conversion3:amd64 \
    libzstd1:amd64 \
    # 清理缓存
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建ICU符号链接 - Qt Host工具期望ICU 70，但Ubuntu 24.04提供ICU 74
# 创建兼容性符号链接使Qt工具能正常运行
RUN cd /usr/lib/x86_64-linux-gnu && \
    ln -sf libicui18n.so.74 libicui18n.so.70 && \
    ln -sf libicuuc.so.74 libicuuc.so.70 && \
    ln -sf libicudata.so.74 libicudata.so.70

# 设置工作目录
WORKDIR /workspace

# 设置环境变量
ENV PATH="/usr/aarch64-linux-gnu/bin:${PATH}"

# 输出环境信息
CMD ["/bin/bash"]
