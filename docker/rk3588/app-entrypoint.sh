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
# ✅ 2026-02-22 05:25 [Phase 7.46.33]: 添加 aishell3 模型符号链接
# fastspeech2_aishell3 多说话人模型
ln -sf /app/tts_models/paddlespeech/models/fastspeech2_aishell3-zh /root/.paddlespeech/models/fastspeech2_aishell3-zh
# hifigan_aishell3 声码器
ln -sf /app/tts_models/paddlespeech/models/hifigan_aishell3-zh /root/.paddlespeech/models/hifigan_aishell3-zh
# G2PW 中文文本转拼音模型（目录和zip文件都需要）
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1 /root/.paddlespeech/models/G2PWModel_1.1
ln -sf /app/tts_models/paddlespeech/models/G2PWModel_1.1.zip /root/.paddlespeech/models/G2PWModel_1.1.zip
echo "PaddleSpeech model symlinks created."
echo ""

# ✅ 2026-02-22 02:10 [Phase 7.46.30]: 创建 PaddleNLP BERT 模型符号链接
# 原因：G2PW 的 BertTokenizer 需要 bert-base-chinese 模型
# 效果：离线使用预下载的 BERT 词表文件
echo "========================================="
echo "Setting up PaddleNLP model symlinks..."
echo "========================================="
mkdir -p /root/.paddlenlp/models
ln -sf /app/tts_models/paddlenlp/bert-base-chinese /root/.paddlenlp/models/bert-base-chinese
echo "PaddleNLP model symlinks created."
echo ""

# ✅ 2026-02-22 03:30 [Phase 7.46.31]: 修改 G2PW config.py 使用本地 BERT 路径
# 原因：G2PW 的 config.py 中 model_source = 'bert-base-chinese' 是模型名称
#       PaddleNLP 会尝试从网络下载，导致离线环境失败
# 效果：修改为本地路径，确保离线使用
echo "========================================="
echo "Patching G2PW config for offline use..."
echo "========================================="
G2PW_CONFIG="/app/tts_models/paddlespeech/models/G2PWModel_1.1/config.py"
if [ -f "$G2PW_CONFIG" ]; then
    # 检查是否需要修改（避免重复修改）
    if grep -q "model_source = 'bert-base-chinese'" "$G2PW_CONFIG"; then
        sed -i "s|model_source = 'bert-base-chinese'|model_source = '/root/.paddlenlp/models/bert-base-chinese'|g" "$G2PW_CONFIG"
        echo "G2PW config patched: model_source -> local path"
    else
        echo "G2PW config already patched or different format"
    fi
else
    echo "Warning: G2PW config not found at $G2PW_CONFIG"
fi
echo ""

echo "========================================="
echo "Launching application..."
echo "========================================="
echo ""

# Start application
exec /app/belt_control_system
