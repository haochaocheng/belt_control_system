# Phase 7.47.73-74 - 语音卡顿修复 & 连接超时参数修正

**日期**: 2026-03-03
**提交**: `8191731a`（Phase 7.47.73）、`ec5e2b61`（Phase 7.47.74）
**修改文件**:
- `src/control/CommonControl.h`
- `src/control/CommonControl.cpp`
- `docker/rk3588/asound.conf`
- `src/mqtt/MQTTAutoManager.cpp`
- `src/qml/components/device_info/pages/SwitchInputPage.qml`

---

## 一、Phase 7.47.73：用 QSoundEffect 替代 QMediaPlayer 本地播放

### 背景：为什么选择 QMediaPlayer（历史原因）

程序运行在 Docker 容器内，容器无 PulseAudio 服务，Qt Multimedia 无法通过 `QMediaDevices::audioOutputs()` 枚举 ALSA 设备（返回空列表）。

当时的解决方案：使用 `QMediaPlayer → GStreamer → alsasink → ALSA default → ES8388`，GStreamer 的 `alsasink` 可以自动使用 ALSA default 设备，绕过了枚举失败的问题。

记录在 `CommonControl.cpp` 第 58-68 行注释：
```cpp
// ✅ 2026-01-21 15:30 [FIX 100.278] 使用 ALSA 默认设备播放音频
// 背景：
//   - Qt Multimedia 无法在容器中枚举 ALSA 设备（无 PulseAudio）
//   - GStreamer alsasink 自动使用 ALSA "default" 设备
// 工作流程：QMediaPlayer → GStreamer → alsasink → ALSA default → ES8388
```

### 卡顿根因

GStreamer 流式 pipeline 在播放 TTS 生成的 WAV 文件时（24kHz 单声道），因 `asound.conf` dmix 固定 48kHz，需要实时重采样（2x 上采样），CPU 稍有抖动即导致缓冲区耗尽（Buffer Underrun），产生短暂静音（卡顿）。详细分析见：[01-WAV语音播放卡顿问题根因分析报告.md](01-WAV语音播放卡顿问题根因分析报告.md)

### QSoundEffect 为什么可以替代

- 枚举失败 ≠ 播放失败。`QSoundEffect` 使用 `QAudioSink` 直接写 ALSA，不依赖设备枚举
- `QSoundEffect` 预加载整个 WAV 文件到内存，通过 `QAudioSink → ALSA direct` 播放
- 与 `aplay` 走相同路径，无 GStreamer 流式 pipeline 开销，无重采样卡顿
- 仅支持 WAV 格式 —— 与 TTS 生成的 `.wav` 文件完全兼容

### 代码修改

**CommonControl.h**：
```cpp
#include <QSoundEffect>
// ...
QSoundEffect *m_soundEffect;    // 低延迟本地播放（QAudioSink → ALSA direct）
bool m_usingSoundEffect;        // 当前是否由 QSoundEffect 播放
```

**CommonControl.cpp 构造函数**：
```cpp
m_soundEffect->setVolume(1.0);

// ① 播放结束 → onPlaybackFinished()
connect(m_soundEffect, &QSoundEffect::playingChanged, this, [this]() {
    if (!m_soundEffect->isPlaying() && m_usingSoundEffect) {
        m_usingSoundEffect = false;
        onPlaybackFinished();
    }
});

// ② 加载失败 → 自动回退 QMediaPlayer
connect(m_soundEffect, &QSoundEffect::statusChanged, this, [this]() {
    if (m_soundEffect->status() == QSoundEffect::Error && m_usingSoundEffect) {
        m_usingSoundEffect = false;
        m_mediaPlayer->setSource(m_soundEffect->source());
        m_mediaPlayer->play();
    }
});
```

**CommonControl.cpp playAudio() 本地播放分支**：
```cpp
// LocalOnly / NetworkTcp-fallback 改为 QSoundEffect
m_usingSoundEffect = true;
m_playbackTimer.start();
m_soundEffect->setSource(QUrl::fromLocalFile(audioPath));
m_soundEffect->play();
// 旧代码: m_mediaPlayer->play()

// QMediaPlayer Stopped 信号加守卫（防止 QSoundEffect 期间误触发 onPlaybackFinished）
if (state == QMediaPlayer::StoppedState) {
    if (!m_usingSoundEffect) {
        onPlaybackFinished();
    }
}
```

**docker/rk3588/asound.conf**（安全底网）：
```bash
# buffer_time 200000 → 400000（200ms → 400ms）
# 即使 QSoundEffect 不可用，也为 GStreamer 提供更多容错时间
buffer_time 400000
```

### 执行路径

```
QSoundEffect → QAudioSink → ALSA default（同 aplay，无流式卡顿）
    ↓ 若 statusChanged=Error 自动回退
QMediaPlayer → GStreamer → alsasink（+ 400ms 缓冲保障）
```

---

## 二、Phase 7.47.74：修复连接超时设置对服务器断开场景无效的问题

### 问题描述

用户设置"连接超时"为 30 秒，但关闭服务器后只需几秒就播放"连接服务器失败"语音，30 秒设置形同虚设。

### 根因分析

`checkBrokerConnections()` 中有两条触发路径：

```
服务器关闭
    ↓ 立即
serverLostTime = now（onModuleConnected 记录）
    ↓ 每秒检查
路径A：lostSeconds >= 5（硬编码！与用户设置无关）
         → t=5s 触发语音 ← "几秒钟"的原因
路径B：connectingStartTime >= m_brokerConnectTimeout（30s）
         → t=35s 触发语音，但已被路径A的 m_lastBrokerAlertTime 锁住（5分钟去重）
              → 永远触发不到
```

`m_brokerConnectTimeout`（用户设置的 30 秒）只作用于路径B（Connecting 状态超时），路径A 使用了与用户设置完全无关的硬编码 `5`。

### 修复

**MQTTAutoManager.cpp**：

```cpp
// 旧代码（硬编码，与用户设置无关）
if (lostSeconds >= 5) {

// 新代码（使用用户配置的连接超时）
if (lostSeconds >= m_brokerConnectTimeout) {
```

```cpp
// setBrokerConnectTimeout() 下限同步改为 1 秒（旧为 5 秒）
int clamped = qBound(1, seconds, 120);  // 旧: qBound(5, seconds, 120)
```

**SwitchInputPage.qml**：
```qml
// 旧: from: 5
from: 1   // 最小 1 秒
```

### 修复效果

| 用户设置 | 修复前（服务器断开后播放时间） | 修复后 |
|---------|--------------------------|-------|
| 1 秒 | 5 秒（硬编码） | **1 秒** |
| 5 秒 | 5 秒 | **5 秒** |
| 30 秒（默认） | 5 秒（设置无效）| **30 秒** |

---

## 三、待验证

编译部署后按以下顺序测试：

1. **语音卡顿**：触发保护语音，确认 voip.md 日志出现 `[QSoundEffect] 播放结束`（而非旧的 `[本地播放]`），聆听是否仍有卡顿
2. **回退机制**：若出现 `回退到 QMediaPlayer`，表示容器不支持 QSoundEffect，需依赖 asound.conf 400ms 缓冲
3. **连接超时**：设置 5 秒连接超时，关闭服务器，验证 5 秒后播报；设置 30 秒，验证 30 秒后播报

---

## 四、文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | 新增 `QSoundEffect`, `m_usingSoundEffect` |
| `src/control/CommonControl.cpp` | QSoundEffect 初始化、信号连接、playAudio() 分支替换、QMediaPlayer Stopped 守卫 |
| `docker/rk3588/asound.conf` | `buffer_time` 200ms → 400ms |
| `src/mqtt/MQTTAutoManager.cpp` | `serverLostTime` 宽限期改为 `m_brokerConnectTimeout`；`qBound` 下限 5→1 |
| `src/qml/.../SwitchInputPage.qml` | `brokerTimeoutSpin from: 5 → from: 1` |
