#!/bin/bash
# ========================================
# ALSA 音频设备自动检测脚本
# ========================================
# 日期: 2026-01-23 19:40
# 版本: FIX 100.300.14
# 目的: 自动检测硬件并生成正确的 ALSA 配置
# 应用: 容器启动时自动执行
#
# 背景:
#   - 不同设备硬件配置不同
#   - linaro@192.168.10.188: Card 1 = ES8388（音质更好）
#   - pi@192.168.1.8: Card 1 = Loopback（虚拟设备）
#   - 需要自动选择最佳音频设备
# ========================================

echo "🔍 检测音频设备..."

# 检查 Card 1 是否是 ES8388
if grep -q "ES8388\|rockchip-es8388" /proc/asound/cards 2>/dev/null; then
    echo "✅ 检测到 ES8388 音频芯片（Card 1），使用高品质音频输出"
    AUDIO_CARD=1
    AUDIO_DEVICE="ES8388"
elif grep -q "rockchiphdmi0" /proc/asound/cards 2>/dev/null; then
    echo "✅ 检测到 HDMI 音频（Card 0），使用 HDMI 音频输出"
    AUDIO_CARD=0
    AUDIO_DEVICE="HDMI"
else
    echo "⚠️  未检测到已知音频设备，使用默认配置（Card 0）"
    AUDIO_CARD=0
    AUDIO_DEVICE="Unknown"
fi

echo "📝 生成 ALSA 配置文件..."

# 生成 ALSA 配置文件
cat > /etc/asound.conf << EOF
# ========================================
# ALSA 默认设备配置（自动生成）
# ========================================
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 检测到的设备: ${AUDIO_DEVICE} (Card ${AUDIO_CARD})
# 生成脚本: /app/detect-audio-device.sh
# ========================================

# PCM 播放设备配置（使用 dmix 提供软件混音）
pcm.!default {
    type plug
    slave.pcm "dmixer"
}

# dmix 配置（软件混音 + 大缓冲区避免 underrun）
pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:${AUDIO_CARD},0"
        period_time 20000    # 20ms per period
        buffer_time 200000   # 200ms total buffer
        rate 48000           # 固定采样率 48kHz
    }
    bindings {
        0 0  # 左声道
        1 1  # 右声道
    }
}

# 控制设备配置（音量控制）
ctl.!default {
    type hw
    card ${AUDIO_CARD}
}

# ========================================
# 设备信息
# ========================================
# 音频设备: ${AUDIO_DEVICE}
# ALSA 设备: hw:${AUDIO_CARD},0
#
# 如果音频输出不正常，请检查：
# 1. 硬件连接（HDMI 线缆、扬声器）
# 2. 音量设置（alsamixer）
# 3. 设备权限（/dev/snd/）
# ========================================
EOF

echo "✅ ALSA 配置已生成"
echo "   设备: ${AUDIO_DEVICE}"
echo "   ALSA: hw:${AUDIO_CARD},0"
echo ""

# 显示检测到的所有音频设备
echo "📋 系统音频设备列表:"
cat /proc/asound/cards
echo ""
