#!/bin/bash
# ========================================
# Belt Control System Startup Script
# ========================================
# Date: 2026-01-23 19:45
# Version: FIX 100.300.14
# Purpose: Auto-detect audio device and start application
# ========================================

set -e

echo "========================================="
echo "Belt Control System - Starting..."
echo "========================================="
echo ""

# Auto-detect audio device (ES8388 vs HDMI)
if [ -f /app/detect-audio-device.sh ]; then
    /app/detect-audio-device.sh
else
    echo "Warning: Audio detection script not found, using default config"
fi

# ✅ 2026-02-26 09:50 [Phase 7.47.4]: 自动检测用户并创建 PaddleSpeech 模型符号链接
# ✅ 2026-02-26 10:30 [Phase 7.47.6]: 添加 PADDLESPEECH_HOME 环境变量（更可靠）
# 原因：需要兼容 pi 和 linaro 两个用户的设备
# 效果：自动检测挂载路径，设置环境变量并创建符号链接
echo "========================================="
echo "Setting up PaddleSpeech model paths..."
echo "========================================="

# ✅ 2026-02-26 12:30 [Phase 7.47.8]: 修复路径检测（移除多余的 models 层级）
# 原因：同步脚本同步到 /home/linaro/belt-control-data/tts_models，不是 /home/linaro/belt-control-data/models/tts_models
# 检测模型路径（优先 linaro，其次 pi）
if [ -d "/home/linaro/belt-control-data/tts_models/paddlespeech/models" ]; then
    MODEL_BASE="/home/linaro/belt-control-data/tts_models/paddlespeech/models"
    PADDLESPEECH_HOME="/home/linaro/belt-control-data/tts_models/paddlespeech"
    echo "✅ 检测到 linaro 用户模型路径"
elif [ -d "/home/pi/belt-control-data/tts_models/paddlespeech/models" ]; then
    MODEL_BASE="/home/pi/belt-control-data/tts_models/paddlespeech/models"
    PADDLESPEECH_HOME="/home/pi/belt-control-data/tts_models/paddlespeech"
    echo "✅ 检测到 pi 用户模型路径"
else
    # 回退到容器内路径
    MODEL_BASE="/app/tts_models/paddlespeech/models"
    PADDLESPEECH_HOME="/app/tts_models/paddlespeech"
    echo "⚠️ 使用容器内模型路径（回退方案）"
fi

echo "📂 模型基础路径: $MODEL_BASE"
echo "📂 PADDLESPEECH_HOME: $PADDLESPEECH_HOME"

# ✅ 2026-02-26 10:30 [Phase 7.47.6]: 设置环境变量（最可靠的方案）
# PaddleSpeech 会在 $PADDLESPEECH_HOME/models/ 查找模型
export PADDLESPEECH_HOME="$PADDLESPEECH_HOME"
echo "✅ 已设置 PADDLESPEECH_HOME=$PADDLESPEECH_HOME"

mkdir -p /root/.paddlespeech/models
# ✅ 2026-02-25 [Phase 7.47.6]: 先删除旧链接再创建，避免 "Read-only file system" 错误
# 原因：ln -sf 在目标是目录时会在目录内创建链接，而不是替换目录
rm -rf /root/.paddlespeech/models/fastspeech2_csmsc-zh
rm -rf /root/.paddlespeech/models/pwgan_csmsc-zh
rm -rf /root/.paddlespeech/models/fastspeech2_aishell3-zh
rm -rf /root/.paddlespeech/models/hifigan_aishell3-zh
rm -rf /root/.paddlespeech/models/G2PWModel_1.1
rm -rf /root/.paddlespeech/models/G2PWModel_1.1.zip

# 创建符号链接
ln -sf "$MODEL_BASE/fastspeech2_csmsc-zh" /root/.paddlespeech/models/fastspeech2_csmsc-zh
ln -sf "$MODEL_BASE/pwgan_csmsc-zh" /root/.paddlespeech/models/pwgan_csmsc-zh
ln -sf "$MODEL_BASE/fastspeech2_aishell3-zh" /root/.paddlespeech/models/fastspeech2_aishell3-zh
ln -sf "$MODEL_BASE/hifigan_aishell3-zh" /root/.paddlespeech/models/hifigan_aishell3-zh
ln -sf "$MODEL_BASE/G2PWModel_1.1" /root/.paddlespeech/models/G2PWModel_1.1
ln -sf "$MODEL_BASE/G2PWModel_1.1.zip" /root/.paddlespeech/models/G2PWModel_1.1.zip

echo "✅ PaddleSpeech model symlinks created."
echo ""

# ✅ 2026-02-26 09:50 [Phase 7.47.4]: 自动检测用户并创建 PaddleNLP 模型符号链接
# 原因：需要兼容 pi 和 linaro 两个用户的设备
# 效果：自动检测挂载路径，创建正确的符号链接
echo "========================================="
echo "Setting up PaddleNLP model symlinks..."
echo "========================================="

# ✅ 2026-02-26 12:30 [Phase 7.47.8]: 修复路径检测（移除多余的 models 层级）
# 检测 PaddleNLP 模型路径（优先 linaro，其次 pi）
if [ -d "/home/linaro/belt-control-data/tts_models/paddlenlp" ]; then
    PADDLENLP_BASE="/home/linaro/belt-control-data/tts_models/paddlenlp"
    echo "✅ 检测到 linaro 用户 PaddleNLP 路径"
elif [ -d "/home/pi/belt-control-data/tts_models/paddlenlp" ]; then
    PADDLENLP_BASE="/home/pi/belt-control-data/tts_models/paddlenlp"
    echo "✅ 检测到 pi 用户 PaddleNLP 路径"
else
    # 回退到容器内路径
    PADDLENLP_BASE="/app/tts_models/paddlenlp"
    echo "⚠️ 使用容器内 PaddleNLP 路径（回退方案）"
fi

echo "📂 PaddleNLP 基础路径: $PADDLENLP_BASE"

mkdir -p /root/.paddlenlp/models
rm -rf /root/.paddlenlp/models/bert-base-chinese
ln -sf "$PADDLENLP_BASE/bert-base-chinese" /root/.paddlenlp/models/bert-base-chinese
echo "✅ PaddleNLP model symlinks created."
echo ""

# ✅ 2026-02-26 09:50 [Phase 7.47.4]: 修改 G2PW config.py 使用本地 BERT 路径（兼容多用户）
# 原因：G2PW 的 config.py 中 model_source = 'bert-base-chinese' 是模型名称
#       PaddleNLP 会尝试从网络下载，导致离线环境失败
# 效果：修改为本地路径，确保离线使用
echo "========================================="
echo "Patching G2PW config for offline use..."
echo "========================================="

# 使用之前检测到的 MODEL_BASE 变量
G2PW_CONFIG="$MODEL_BASE/G2PWModel_1.1/config.py"
if [ -f "$G2PW_CONFIG" ]; then
    # 检查是否需要修改（避免重复修改）
    if grep -q "model_source = 'bert-base-chinese'" "$G2PW_CONFIG"; then
        sed -i "s|model_source = 'bert-base-chinese'|model_source = '/root/.paddlenlp/models/bert-base-chinese'|g" "$G2PW_CONFIG"
        echo "✅ G2PW config patched: model_source -> local path"
    else
        echo "✅ G2PW config already patched or different format"
    fi
else
    echo "⚠️ Warning: G2PW config not found at $G2PW_CONFIG"
fi
echo ""

echo "========================================="
echo "Launching application..."
echo "========================================="
echo ""

# Start application
exec /app/belt_control_system
