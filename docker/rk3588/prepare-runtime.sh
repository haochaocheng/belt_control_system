#!/bin/bash
# 准备运行时依赖库脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUNTIME_LIBS_DIR="$SCRIPT_DIR/runtime-libs"

echo "========================================"
echo "准备 RK3588 运行时依赖库"
echo "========================================"

# 创建运行时库目录
mkdir -p "$RUNTIME_LIBS_DIR"

echo "1. 复制编译好的可执行文件..."
mkdir -p "$RUNTIME_LIBS_DIR/../bin_arm64"
cp "$PROJECT_ROOT/build_rk3588_new/bin_arm64/belt_control_system" \
   "$RUNTIME_LIBS_DIR/../bin_arm64/"
echo "   ✅ belt_control_system 已复制"

echo ""
echo "2. 收集所有运行时依赖库..."

# 定义需要复制的库列表
LIBS=(
    # PJSIP 库
    "pjsua-aarch64-unknown-linux-gnu"
    "pjsua2-aarch64-unknown-linux-gnu"
    "pjsip-aarch64-unknown-linux-gnu"
    "pjsip-simple-aarch64-unknown-linux-gnu"
    "pjsip-ua-aarch64-unknown-linux-gnu"
    "pjmedia-aarch64-unknown-linux-gnu"
    "pjmedia-codec-aarch64-unknown-linux-gnu"
    "pjmedia-videodev-aarch64-unknown-linux-gnu"
    "pjmedia-audiodev-aarch64-unknown-linux-gnu"
    "pjnath-aarch64-unknown-linux-gnu"
    "pjlib-util-aarch64-unknown-linux-gnu"
    "pj-aarch64-unknown-linux-gnu"

    # Sherpa-ONNX RKNN 版本
    "sherpa-onnx-c-api"
    "sherpa-onnx-cxx-api"
    "sherpa-onnx-core"
    "sherpa-onnx-kaldifst-core"
    "sherpa-onnx-fstfar"
    "sherpa-onnx-fst"
    "kaldi-native-fbank-core"
    "onnxruntime"
    "rknnrt"
    "rknn_api"

    # FFmpeg 库（如果有）
    "avcodec"
    "avformat"
    "avutil"
    "swresample"
    "swscale"
)

# 从 rk3588-libs 复制库
echo "   从 rk3588-libs 复制..."
for lib in "${LIBS[@]}"; do
    # 查找库文件（.so 和 .so.* 版本）
    found=0
    for file in "$SCRIPT_DIR/rk3588-libs/lib/lib${lib}.so"*; do
        if [ -f "$file" ]; then
            cp -L "$file" "$RUNTIME_LIBS_DIR/" 2>/dev/null || true
            echo "   ✅ $(basename $file)"
            found=1
        fi
    done

    if [ $found -eq 0 ]; then
        echo "   ⚠️  lib${lib}.so 未找到"
    fi
done

echo ""
echo "3. 复制配置文件..."
cp "$PROJECT_ROOT/config.ini.example" "$RUNTIME_LIBS_DIR/../" || true

echo ""
echo "4. 复制 TTS 模型..."
if [ -d "$PROJECT_ROOT/libs/tts_models" ]; then
    cp -r "$PROJECT_ROOT/libs/tts_models" "$RUNTIME_LIBS_DIR/../"
    echo "   ✅ TTS 模型已复制"
else
    echo "   ⚠️  TTS 模型目录不存在"
fi

echo ""
echo "5. 复制音频文件..."
if [ -d "$PROJECT_ROOT/AUDIO" ]; then
    cp -r "$PROJECT_ROOT/AUDIO" "$RUNTIME_LIBS_DIR/../"
    echo "   ✅ AUDIO 文件已复制"
else
    echo "   ⚠️  AUDIO 目录不存在"
fi

echo ""
echo "========================================"
echo "✅ 运行时依赖准备完成"
echo "========================================"
echo "输出目录: $RUNTIME_LIBS_DIR"
echo ""
echo "下一步: 构建运行时 Docker 镜像"
echo "  cd $SCRIPT_DIR"
echo "  docker build -f Dockerfile.runtime -t belt-control-rk3588:runtime ."
echo ""
