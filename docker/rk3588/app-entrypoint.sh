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

# ✅ 2026-02-22 02:05 [Phase 7.46.29]: 创建 PaddleSpeech 模型符号链接
# 原因：PaddleSpeech 在 /root/.paddlespeech/models/ 查找模型，但我们的模型在 /app/tts_models/
# 效果：离线使用预下载的模型，无需网络下载
echo "========================================="
echo "Setting up PaddleSpeech model symlinks..."
echo "========================================="
mkdir -p /root/.paddlespeech/models
# fastspeech2_csmsc 模型
ln -sf /app/tts_models/paddlespeech/models/fastspeech2_csmsc-zh /root/.paddlespeech/models/fastspeech2_csmsc-zh
# pwgan_csmsc 声码器
ln -sf /app/tts_models/paddlespeech/models/pwgan_csmsc-zh /root/.paddlespeech/models/pwgan_csmsc-zh
# G2PW 中文文本转拼音模型（目录和zip文件都需要）
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1 /root/.paddlespeech/models/G2PWModel_1.1
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1.zip /root/.paddlespeech/models/G2PWModel_1.1.zip
echo "PaddleSpeech model symlinks created."
echo ""

echo "========================================="
echo "Launching application..."
echo "========================================="
echo ""

# Start application
exec /app/belt_control_system
