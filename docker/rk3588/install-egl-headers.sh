#!/bin/bash
set -e

# RK3588 sysroot EGL/GLES 头文件安装脚本
# 为交叉编译提供必需的 OpenGL ES 和 EGL 开发头文件

SYSROOT="${SYSROOT:-/opt/sysroot/pi-root}"
INCLUDE_DIR="${SYSROOT}/usr/include"

echo "========================================"
echo "安装 EGL/GLES 头文件到 sysroot"
echo "========================================"
echo "Sysroot: ${SYSROOT}"
echo "Include Dir: ${INCLUDE_DIR}"
echo

# 方法1: 尝试使用系统包管理器安装到 sysroot（如果可用）
if [ -f "/etc/debian_version" ]; then
    echo "检测到 Debian/Ubuntu 系统"

    # 检查是否可以使用 apt-get
    if command -v apt-get &> /dev/null; then
        echo "尝试安装 libegl1-mesa-dev 和 libgles2-mesa-dev..."

        # 创建临时目录
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        # 下载 arm64 包
        echo "下载 arm64 包..."
        apt-get download libegl1-mesa-dev:arm64 libgles2-mesa-dev:arm64 libgl-dev:arm64 2>/dev/null || {
            echo "⚠️  无法通过 apt 下载，尝试方法2..."
        }

        if [ -f libegl1-mesa-dev_*.deb ]; then
            echo "解压包到 sysroot..."
            for deb in *.deb; do
                dpkg-deb -x "$deb" "$SYSROOT"
            done
            echo "✅ 包安装完成"
            rm -rf "$TEMP_DIR"

            # 验证安装
            if [ -f "${INCLUDE_DIR}/EGL/egl.h" ]; then
                echo "✅ EGL 头文件安装成功"
                exit 0
            fi
        fi

        rm -rf "$TEMP_DIR"
    fi
fi

# 方法2: 从标准源手动下载安装 Mesa headers
echo
echo "使用方法2: 从 Khronos 下载标准 EGL/GLES 头文件"
echo

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 创建目录
mkdir -p "${INCLUDE_DIR}/EGL"
mkdir -p "${INCLUDE_DIR}/GLES"
mkdir -p "${INCLUDE_DIR}/GLES2"
mkdir -p "${INCLUDE_DIR}/GLES3"
mkdir -p "${INCLUDE_DIR}/KHR"

echo "下载 Khronos EGL/GLES 标准头文件..."

# EGL 头文件
wget -q https://www.khronos.org/registry/EGL/api/EGL/egl.h -O "${INCLUDE_DIR}/EGL/egl.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/main/api/EGL/egl.h -o "${INCLUDE_DIR}/EGL/egl.h"

wget -q https://www.khronos.org/registry/EGL/api/EGL/eglext.h -O "${INCLUDE_DIR}/EGL/eglext.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/main/api/EGL/eglext.h -o "${INCLUDE_DIR}/EGL/eglext.h"

wget -q https://www.khronos.org/registry/EGL/api/EGL/eglplatform.h -O "${INCLUDE_DIR}/EGL/eglplatform.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/main/api/EGL/eglplatform.h -o "${INCLUDE_DIR}/EGL/eglplatform.h"

# GLES 头文件
wget -q https://www.khronos.org/registry/OpenGL/api/GLES/gl.h -O "${INCLUDE_DIR}/GLES/gl.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES/gl.h -o "${INCLUDE_DIR}/GLES/gl.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES/glext.h -O "${INCLUDE_DIR}/GLES/glext.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES/glext.h -o "${INCLUDE_DIR}/GLES/glext.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES/glplatform.h -O "${INCLUDE_DIR}/GLES/glplatform.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES/glplatform.h -o "${INCLUDE_DIR}/GLES/glplatform.h"

# GLES2 头文件
wget -q https://www.khronos.org/registry/OpenGL/api/GLES2/gl2.h -O "${INCLUDE_DIR}/GLES2/gl2.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES2/gl2.h -o "${INCLUDE_DIR}/GLES2/gl2.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES2/gl2ext.h -O "${INCLUDE_DIR}/GLES2/gl2ext.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES2/gl2ext.h -o "${INCLUDE_DIR}/GLES2/gl2ext.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES2/gl2platform.h -O "${INCLUDE_DIR}/GLES2/gl2platform.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES2/gl2platform.h -o "${INCLUDE_DIR}/GLES2/gl2platform.h"

# GLES3 头文件
wget -q https://www.khronos.org/registry/OpenGL/api/GLES3/gl3.h -O "${INCLUDE_DIR}/GLES3/gl3.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES3/gl3.h -o "${INCLUDE_DIR}/GLES3/gl3.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES3/gl3ext.h -O "${INCLUDE_DIR}/GLES3/gl3ext.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES3/gl3ext.h -o "${INCLUDE_DIR}/GLES3/gl3ext.h"

wget -q https://www.khronos.org/registry/OpenGL/api/GLES3/gl3platform.h -O "${INCLUDE_DIR}/GLES3/gl3platform.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/main/api/GLES3/gl3platform.h -o "${INCLUDE_DIR}/GLES3/gl3platform.h"

# KHR 平台头文件
wget -q https://www.khronos.org/registry/EGL/api/KHR/khrplatform.h -O "${INCLUDE_DIR}/KHR/khrplatform.h" || \
    curl -sL https://raw.githubusercontent.com/KhronosGroup/EGL-Registry/main/api/KHR/khrplatform.h -o "${INCLUDE_DIR}/KHR/khrplatform.h"

# 清理
cd /
rm -rf "$TEMP_DIR"

echo
echo "========================================"
echo "验证头文件安装"
echo "========================================"

# 验证关键头文件
MISSING=0
for header in \
    "${INCLUDE_DIR}/EGL/egl.h" \
    "${INCLUDE_DIR}/EGL/eglext.h" \
    "${INCLUDE_DIR}/EGL/eglplatform.h" \
    "${INCLUDE_DIR}/GLES2/gl2.h" \
    "${INCLUDE_DIR}/GLES2/gl2ext.h" \
    "${INCLUDE_DIR}/GLES3/gl3.h" \
    "${INCLUDE_DIR}/KHR/khrplatform.h"; do

    if [ -f "$header" ]; then
        echo "✅ $header"
    else
        echo "❌ $header (缺失)"
        MISSING=$((MISSING + 1))
    fi
done

echo
if [ $MISSING -eq 0 ]; then
    echo "✅ 所有 EGL/GLES 头文件已成功安装"
    echo
    echo "现在可以继续交叉编译主项目了"
    exit 0
else
    echo "❌ 有 $MISSING 个头文件安装失败"
    exit 1
fi
