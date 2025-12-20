#!/bin/bash
set -e

echo "========================================="
echo "RK3588 交叉编译环境"
echo "========================================="
echo "Qt Host: $QT_HOST_PATH"
echo "Qt Target: $QT_TARGET_PATH"
echo "Sysroot: $SYSROOT"
echo "Toolchain: $TOOLCHAIN_FILE"
echo "========================================="

# 检查必要的目录
if [ ! -d "$QT_TARGET_PATH" ]; then
    echo "❌ 错误: Qt目标路径不存在: $QT_TARGET_PATH"
    echo "   请确保挂载了qt-raspi"
    exit 1
fi

if [ ! -d "$SYSROOT" ]; then
    echo "❌ 错误: Sysroot不存在: $SYSROOT"
    echo "   请确保挂载了RK3588 sysroot"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# 执行传入的命令
exec "$@"
