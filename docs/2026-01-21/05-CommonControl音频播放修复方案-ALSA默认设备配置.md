# CommonControl 音频播放修复方案 - ALSA 默认设备配置

**日期**: 2026-01-21 15:30
**版本**: FIX 100.278
**问题**: Qt Multimedia 无法枚举 ALSA 设备，音频播放无声音

---

## 问题分析

### 1. 当前现象
```
[DEBUG] 🔍 CommonControl: 枚举音频输出设备（共 0 个）:
[WARNING] ⚠️  CommonControl: 未找到 ES8388 设备，使用默认设备: ""
[WARNING] PulseAudioService: pa_context_connect() failed
```

- QMediaDevices::audioOutputs() 返回空列表（0 个设备）
- PulseAudio 服务不可用
- 音频文件播放无声音

### 2. 根本原因

**Qt Multimedia 的设备枚举机制**：
- 依赖 PulseAudio 或 Qt 的设备发现机制
- 容器环境中没有 PulseAudio 服务
- Qt 无法通过 D-Bus/PulseAudio 枚举 ALSA 设备

**GStreamer 后端的工作原理**：
- QMediaPlayer 使用 GStreamer 后端播放音频
- GStreamer 有 ALSA sink 插件（alsasink）
- GStreamer 可以直接使用 ALSA 设备，不需要 PulseAudio
- **关键**: GStreamer 会自动使用 ALSA 的"默认设备"（default）

### 3. 为什么 SIP 可以枚举设备？

```cpp
// SipPhoneManager.cpp 使用 PJSIP API
pjmedia_aud_dev_info info[64];
unsigned count = 64;
pj_status_t status = pjsua_enum_aud_devs(info, &count);
```

- PJSIP 直接调用 ALSA API（snd_card_next, snd_ctl_open）
- 不依赖 PulseAudio 或 D-Bus
- 可以在容器环境中工作

---

## 解决方案：配置 ALSA 默认设备

### 方案对比

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| **方案 1**: 使用 PJSIP API 枚举设备 | 可以枚举设备 | CommonControl 不应依赖 SIP 库 | ❌ 架构不合理 |
| **方案 2**: 设置 QT_MEDIA_BACKEND=ffmpeg | 简单 | FFmpeg 后端也可能无法枚举设备 | ⚠️ 已测试，无效 |
| **方案 3**: 配置 ALSA 默认设备 | GStreamer 自动使用，无需代码修改 | 需要添加配置文件 | ✅ **推荐** |
| **方案 4**: 使用 GStreamer 环境变量 | 显式指定设备 | 环境变量复杂，不够灵活 | ⚠️ 备选 |

### 选择方案 3：配置 ALSA 默认设备

**原理**：
1. 创建 ALSA 配置文件（.asoundrc 或 /etc/asound.conf）
2. 设置默认 PCM 设备为 ES8388（plughw:1,0）
3. GStreamer alsasink 自动使用 ALSA 默认设备
4. QMediaPlayer → GStreamer → alsasink → 默认设备 → ES8388 ✅

**优点**：
- ✅ 不需要修改 CommonControl 代码
- ✅ 不需要 Qt Multimedia 枚举设备
- ✅ GStreamer 自动使用配置的默认设备
- ✅ 符合 ALSA/GStreamer 的标准用法

---

## 实施步骤

### Step 1: 创建 ALSA 配置文件

**文件**: `docker/rk3588/asound.conf`

```conf
# ALSA 默认设备配置
# 目的：将 ES8388 音频芯片（Card 1）设置为系统默认设备
# 应用：所有使用 ALSA "default" 设备的程序自动使用 ES8388

pcm.!default {
    type plug
    slave.pcm "hw:1,0"
}

ctl.!default {
    type hw
    card 1
}
```

**说明**：
- `pcm.!default`: 设置默认播放设备（PCM = Pulse Code Modulation）
- `type plug`: 使用 plug 插件（自动格式转换）
- `slave.pcm "hw:1,0"`: 实际硬件设备（Card 1, Device 0 = ES8388）
- `ctl.!default`: 设置默认控制设备（音量控制等）

### Step 2: 修改 Dockerfile

**文件**: `docker/rk3588/Dockerfile`

```dockerfile
# 在适当位置添加（例如 COPY run-ubuntu24-apt.sh 之前）

# ✅ 2026-01-21 15:30 [FIX 100.278] 配置 ALSA 默认设备为 ES8388
# 原因：Qt Multimedia 无法枚举设备，GStreamer 需要默认设备配置
COPY asound.conf /etc/asound.conf
```

### Step 3: 验证配置

**容器内测试**：
```bash
# 1. 查看默认设备
aplay -L | grep default

# 应该输出：
# default
#     Default ALSA Output (currently plugin:default)

# 2. 测试默认设备播放
aplay -D default /app/AUDIO/语音文件/001.wav

# 应该从 ES8388 听到声音 ✅
```

### Step 4: QMediaPlayer 自动使用默认设备

**CommonControl.cpp 代码逻辑**：
```cpp
// ❌ 2026-01-21 14:30 旧代码：尝试枚举设备（容器中失败）
// const QList<QAudioDevice> devices = QMediaDevices::audioOutputs();

// ✅ 2026-01-21 15:30 新策略：不枚举设备，直接创建默认 QAudioOutput
// GStreamer 会自动使用 ALSA 默认设备（/etc/asound.conf 配置的 ES8388）
m_audioOutput = new QAudioOutput(this);
m_audioOutput->setVolume(1.0);  // 音量100%
m_mediaPlayer->setAudioOutput(m_audioOutput);

qDebug() << "🔊 CommonControl: 使用默认音频输出（ALSA default → ES8388）";
```

**工作流程**：
```
QMediaPlayer::play()
  ↓
QAudioOutput (default)
  ↓
GStreamer pipeline
  ↓
alsasink (使用 ALSA "default" 设备)
  ↓
/etc/asound.conf (pcm.!default = hw:1,0)
  ↓
ES8388 硬件设备 🔊
```

---

## 预期效果

### 修复前
```
[DEBUG] 🔍 CommonControl: 枚举音频输出设备（共 0 个）:
[WARNING] ⚠️  CommonControl: 未找到 ES8388 设备，使用默认设备: ""
[播放音频文件] ← 无声音 ❌
```

### 修复后
```
[DEBUG] 🔊 CommonControl: 使用默认音频输出（ALSA default → ES8388）
[QMediaPlayer plays audio] → GStreamer → alsasink → default → ES8388
[播放音频文件] ← 有声音 ✅
```

---

## 技术细节

### ALSA 设备层次结构

```
物理设备: ES8388 音频芯片
  ↓
内核驱动: /dev/snd/pcmC1D0p
  ↓
ALSA 设备名:
  - hw:1,0          (直接硬件访问，格式限制)
  - plughw:1,0      (插件层，自动格式转换) ← 推荐
  - default:CARD=1  (默认设备别名)
  ↓
/etc/asound.conf 配置:
  pcm.!default → plug → hw:1,0
  ↓
应用程序使用 "default" 设备
  ✅ 自动路由到 ES8388
```

### GStreamer alsasink 行为

```cpp
// GStreamer 默认设备选择逻辑（伪代码）
if (device_property_set) {
    use_specified_device();
} else {
    use_alsa_default();  // ← 我们的方案
}

// ALSA 默认设备解析
alsa_default() {
    if (/etc/asound.conf exists) {
        read_pcm_default_from_config();  // ← hw:1,0 (ES8388)
    } else {
        use_card_0();  // Card 0 (HDMI)
    }
}
```

---

## 备选方案 4：GStreamer 环境变量

**如果方案 3 失败，可以尝试**：

### 方法 A: 使用 ALSA_CARD 环境变量

```bash
# run-ubuntu24-apt.sh
-e ALSA_CARD=1 \
```

### 方法 B: 使用 GStreamer 参数

```bash
# 需要修改 Qt Multimedia 的 GStreamer pipeline
# 不推荐（需要深入修改 Qt 源码或使用插件）
```

---

## 总结

| 项目 | 内容 |
|------|------|
| **问题** | Qt Multimedia 无法枚举设备，音频无声 |
| **根因** | 容器无 PulseAudio，Qt 枚举机制失效 |
| **方案** | 配置 ALSA 默认设备为 ES8388 |
| **原理** | GStreamer 自动使用 ALSA default 设备 |
| **修改** | 添加 /etc/asound.conf 配置文件 |
| **优点** | 无需代码修改，符合标准用法 |
| **风险** | 低（ALSA 配置是标准方法） |

---

## 下一步

1. ✅ 创建 asound.conf 配置文件
2. ✅ 修改 Dockerfile 添加配置文件
3. ✅ 简化 CommonControl.cpp 代码（移除设备枚举逻辑）
4. ⏳ 编译部署测试
5. ⏳ 验证音频播放功能
