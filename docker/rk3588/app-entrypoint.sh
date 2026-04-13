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
# ✅ 2026-02-26 14:30 [Phase 7.47.10]: 恢复正确路径（设备实际路径是 /home/linaro/belt-control-data/models/tts_models/）
# ✅ 2026-02-26 16:30 [Phase 7.47.12]: 使用容器内路径 /app/tts_models
# 原因：Docker 挂载 /home/linaro/belt-control-data/models/tts_models → /app/tts_models
#       容器内应使用 /app/tts_models，不是宿主机路径
# 效果：兼容 pi 和 linaro 两种设备
# 检测模型路径（优先 linaro，其次 pi）
# if [ -d "/home/linaro/belt-control-data/models/tts_models/paddlespeech/models" ]; then
#     MODEL_BASE="/home/linaro/belt-control-data/models/tts_models/paddlespeech/models"
#     PADDLESPEECH_HOME="/home/linaro/belt-control-data/models/tts_models/paddlespeech"
#     echo "✅ 检测到 linaro 用户模型路径"
# elif [ -d "/home/pi/belt-control-data/models/tts_models/paddlespeech/models" ]; then
#     MODEL_BASE="/home/pi/belt-control-data/models/tts_models/paddlespeech/models"
#     PADDLESPEECH_HOME="/home/pi/belt-control-data/models/tts_models/paddlespeech"
#     echo "✅ 检测到 pi 用户模型路径"
# else
#     # 回退到容器内路径
#     MODEL_BASE="/app/tts_models/paddlespeech/models"
#     PADDLESPEECH_HOME="/app/tts_models/paddlespeech"
#     echo "⚠️ 使用容器内模型路径（回退方案）"
# fi
# 使用容器内路径，Docker 挂载会自动处理宿主机路径映射
MODEL_BASE="/app/tts_models/paddlespeech/models"
PADDLESPEECH_HOME="/app/tts_models/paddlespeech"
echo "✅ 使用容器内模型路径（Docker 挂载）"

echo "📂 模型基础路径: $MODEL_BASE"
echo "📂 PADDLESPEECH_HOME: $PADDLESPEECH_HOME"

# ✅ 2026-02-26 10:30 [Phase 7.47.6]: 设置环境变量（最可靠的方案）
# PaddleSpeech 会在 $PADDLESPEECH_HOME/models/ 查找模型
export PADDLESPEECH_HOME="$PADDLESPEECH_HOME"
echo "✅ 已设置 PADDLESPEECH_HOME=$PADDLESPEECH_HOME"

# ✅ 2026-02-26 19:35 [Phase 7.47.15]: 设置 PPSPEECH_HOME 环境变量
# 原因：PaddleSpeech 库实际检查的是 PPSPEECH_HOME，不是 PADDLESPEECH_HOME
#       见 paddlespeech/utils/env.py: if 'PPSPEECH_HOME' in os.environ
# 效果：PaddleSpeech 正确使用本地模型，不再尝试下载
export PPSPEECH_HOME="$PADDLESPEECH_HOME"
echo "✅ 已设置 PPSPEECH_HOME=$PPSPEECH_HOME"

mkdir -p /root/.paddlespeech/models
# ✅ 2026-02-26 19:00 [Phase 7.47.14]: 同步 conf 和 datasets 目录
# 原因：PaddleSpeech 使用 ~/.paddlespeech/conf/cache.yaml 验证模型缓存
#       如果缓存哈希不匹配，会尝试重新下载模型
# 效果：使用挂载的缓存配置，避免下载
mkdir -p /root/.paddlespeech/conf
rm -rf /root/.paddlespeech/conf/cache.yaml
ln -sf /app/tts_models/paddlespeech/conf/cache.yaml /root/.paddlespeech/conf/cache.yaml
echo "✅ PaddleSpeech conf symlink created."

# 同步 datasets 目录
rm -rf /root/.paddlespeech/datasets
ln -sf /app/tts_models/paddlespeech/datasets /root/.paddlespeech/datasets
echo "✅ PaddleSpeech datasets symlink created."

# ✅ 2026-02-25 [Phase 7.47.6]: 先删除旧链接再创建，避免 "Read-only file system" 错误
# 原因：ln -sf 在目标是目录时会在目录内创建链接，而不是替换目录
rm -rf /root/.paddlespeech/models/fastspeech2_csmsc-zh
rm -rf /root/.paddlespeech/models/pwgan_csmsc-zh
rm -rf /root/.paddlespeech/models/fastspeech2_aishell3-zh
rm -rf /root/.paddlespeech/models/hifigan_aishell3-zh
# ✅ 2026-02-27 15:30 [Phase 7.47.38]: 添加hifigan_csmsc-zh，修复合成失败（缺失导致PaddleSpeech尝试从网络下载）
rm -rf /root/.paddlespeech/models/hifigan_csmsc-zh
rm -rf /root/.paddlespeech/models/G2PWModel_1.1
rm -rf /root/.paddlespeech/models/G2PWModel_1.1.zip

# 创建符号链接
ln -sf "$MODEL_BASE/fastspeech2_csmsc-zh" /root/.paddlespeech/models/fastspeech2_csmsc-zh
ln -sf "$MODEL_BASE/pwgan_csmsc-zh" /root/.paddlespeech/models/pwgan_csmsc-zh
ln -sf "$MODEL_BASE/fastspeech2_aishell3-zh" /root/.paddlespeech/models/fastspeech2_aishell3-zh
ln -sf "$MODEL_BASE/hifigan_aishell3-zh" /root/.paddlespeech/models/hifigan_aishell3-zh
# ✅ 2026-02-27 15:30 [Phase 7.47.38]: 添加hifigan_csmsc-zh符号链接
ln -sf "$MODEL_BASE/hifigan_csmsc-zh" /root/.paddlespeech/models/hifigan_csmsc-zh
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
# ✅ 2026-02-26 14:30 [Phase 7.47.10]: 恢复正确路径（设备实际路径是 /home/linaro/belt-control-data/models/tts_models/）
# ✅ 2026-02-26 16:30 [Phase 7.47.12]: 使用容器内路径 /app/tts_models
# 原因：Docker 挂载 /home/linaro/belt-control-data/models/tts_models → /app/tts_models
#       容器内应使用 /app/tts_models，不是宿主机路径
# 效果：兼容 pi 和 linaro 两种设备
# 检测 PaddleNLP 模型路径（优先 linaro，其次 pi）
# if [ -d "/home/linaro/belt-control-data/models/tts_models/paddlenlp" ]; then
#     PADDLENLP_BASE="/home/linaro/belt-control-data/models/tts_models/paddlenlp"
#     echo "✅ 检测到 linaro 用户 PaddleNLP 路径"
# elif [ -d "/home/pi/belt-control-data/models/tts_models/paddlenlp" ]; then
#     PADDLENLP_BASE="/home/pi/belt-control-data/models/tts_models/paddlenlp"
#     echo "✅ 检测到 pi 用户 PaddleNLP 路径"
# else
#     # 回退到容器内路径
#     PADDLENLP_BASE="/app/tts_models/paddlenlp"
#     echo "⚠️ 使用容器内 PaddleNLP 路径（回退方案）"
# fi
# 使用容器内路径，Docker 挂载会自动处理宿主机路径映射
PADDLENLP_BASE="/app/tts_models/paddlenlp"
echo "✅ 使用容器内 PaddleNLP 路径（Docker 挂载）"

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

# ✅ 2026-03-16 [Phase 7.48.47]: 预置 NLTK 数据，防止 PaddleSpeech 初始化时联网下载超时
# 原因：PaddleSpeech 内部依赖 NLTK 的 averaged_perceptron_tagger 和 cmudict
#       设备无外网时，NLTK 等待网络超时需要 1-2 分钟，导致界面长时间显示"正在加载"
# 解决：预置数据到 /app/tts_models/nltk_data 或 /root/nltk_data
echo "========================================="
echo "Setting up NLTK data for offline use..."
echo "========================================="

NLTK_DATA_DIR="/app/tts_models/nltk_data"
if [ -d "$NLTK_DATA_DIR" ]; then
    export NLTK_DATA="$NLTK_DATA_DIR"
    echo "✅ NLTK 数据已预置: $NLTK_DATA_DIR"
elif [ -d "/root/nltk_data" ]; then
    export NLTK_DATA="/root/nltk_data"
    echo "✅ 使用已有 NLTK 数据: /root/nltk_data"
else
    # ✅ 2026-03-20 [Phase 7.48.57]: 不再尝试联网下载，直接跳过
    # 原因：即使设了5秒超时，nltk.download()内部有多次重试+DNS解析，仍会卡住很久
    # 旧代码：python3 -c "nltk.download(...)" 尝试联网下载
    echo "⚠️ NLTK 数据未预置，跳过下载（中文TTS不受影响）"
    mkdir -p /root/nltk_data
    export NLTK_DATA="/root/nltk_data"
fi
echo ""

echo "========================================="
echo "Launching application..."
echo "========================================="
echo ""

# ✅ 2026-04-14 [Phase 7.48.88.139]: 启动本机 Mosquitto MQTT Broker
# 原因：模块0-6连接127.0.0.1（本机），每台设备互相独立，避免多台设备Client ID冲突
# 集控模块7连接集控主站的MQTT地址（在集控配置界面单独设置）
if command -v mosquitto &> /dev/null; then
    echo "Starting local Mosquitto MQTT broker..."
    mosquitto -c /etc/mosquitto/conf.d/belt_control.conf -d 2>/dev/null \
        || mosquitto -d 2>/dev/null \
        || echo "⚠️ Mosquitto start failed, MQTT modules may not work"
    sleep 1
    echo "✅ Mosquitto started on 127.0.0.1:1883"
else
    echo "⚠️ Mosquitto not found, skipping local broker"
fi
echo ""

# Start application
exec /app/belt_control_system
