# Phase 7.47.91 - 修复 dmix 采样率导致 ALSA 初始化失败

## 日期
2026-03-04 18:30

## 问题描述
Phase 7.47.90 部署后，设备仍然完全无声。voip.md 日志显示从应用启动开始就持续报错：
```
ALSA lib pcm_direct.c:1337:(snd1_pcm_direct_initialize_slave) unable to install hw params
ALSA lib pcm_dmix.c:1012:(snd_pcm_dmix_open) unable to initialize slave
```

关键线索：不打开程序，在设备上单独播放音频文件（aplay），音频正常。

## 根因分析

### ALSA 音频链路架构
```
应用程序 → plug (type plug, 可做重采样) → dmix (直接设置硬件, 不做重采样) → hw:1,0 (ES8388)
```

### 根因：dmix rate=24000 不被 ES8388 硬件支持

Phase 7.47.90 将 detect-audio-device.sh 的 `rate` 从 48000 改为 24000（与 TTS WAV 24kHz 一致）。

**问题本质：dmix 插件直接对硬件设备调用 `snd_pcm_hw_params()`，使用配置中的 rate 值。**
dmix 不做采样率转换——它要求硬件必须原生支持该采样率。

ES8388 芯片支持的标准采样率：8000, 11025, 16000, 22050, 32000, 44100, **48000**, 88200, 96000 Hz
**24000 Hz 不在 ES8388 支持列表中。**

因此：
1. dmix 尝试将 hw:1,0 设为 rate=24000
2. ES8388 拒绝（不支持该采样率）
3. `snd1_pcm_direct_initialize_slave()` 返回错误
4. dmix 初始化失败
5. plug 层无法连接 slave → 整个音频输出链路断裂
6. GStreamer alsasink 打开设备失败 → 所有音频无输出

### 为什么设备单独播放正常
在容器外直接运行 `aplay` 时：
- 宿主机有不同的 ALSA 配置（或无 asound.conf）
- 直接使用 `hw:1,0` 绕过 dmix
- aplay 与硬件直接协商采样率（使用硬件支持的值）

### 3月3日 asound.conf 修改的误解
3月3日将 asound.conf 静态文件 rate 从 48000 改为 24000 时，注释写道：
> "ALSA plug 层负责将 24kHz dmix 输出适配硬件支持的采样率"

**这是错误的理解。** plug 层在 dmix 之上（应用侧），不在 dmix 之下（硬件侧）：
```
应用 → plug (这里做重采样) → dmix → hw:1,0 (这里不做重采样)
```
plug 层将应用的采样率转换为 dmix 的采样率，但 dmix 到硬件之间没有转换层。

## 修复方案

### 1. detect-audio-device.sh：rate 24000 → 48000
恢复硬件原生采样率，确保 dmix 能正确初始化 ES8388。

### 2. asound.conf：rate 24000 → 48000
同步修复静态配置文件。

### 3. TTS 默认采样率 24000 → 48000
TTS 合成直接输出 48kHz WAV 文件，全链路零重采样：
- `TTSEngineAdapter.h`：TTSParameters 默认 sampleRate = 48000
- `TTSConfigManager.cpp`：加载配置默认值 48000
- PaddleSpeech 在合成时将 24kHz 模型输出上采样到 48kHz（一次性操作，非实时）

### 4. 保留的改进
- `buffer_time 400000`（400ms）保留，增大缓冲区减少 Underrun
- Phase 7.47.90 的 m_pendingPlay 修复保留

### 修复后的全链路（零重采样）
```
TTS 合成 (48kHz WAV) → GStreamer → alsasink → plug (48kHz, 无需转换) → dmix (48kHz) → hw:1,0 (48kHz) ✅
```

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| docker/rk3588/detect-audio-device.sh | rate 24000 → 48000 |
| docker/rk3588/asound.conf | rate 24000 → 48000 |
| src/control/tts/TTSEngineAdapter.h | TTSParameters 默认 sampleRate 24000 → 48000 |
| src/control/TTSConfigManager.cpp | 加载配置默认值 24000 → 48000 |

## 技术教训
1. **dmix 的 rate 必须是硬件原生支持的值**：dmix 直接设置硬件参数，不做重采样
2. **plug 层在 dmix 上方**：plug 负责应用→dmix 的转换，不负责 dmix→硬件的转换
3. **Buffer Underrun 应通过增大 buffer_time 解决**：不应通过改变 dmix 采样率来避免重采样
4. **ALSA 架构层次**：应用 → plug（格式转换）→ dmix（软件混音）→ hw（硬件），每层职责不同
