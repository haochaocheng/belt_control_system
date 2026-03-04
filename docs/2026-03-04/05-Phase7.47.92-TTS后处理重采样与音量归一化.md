# Phase 7.47.92 - TTS 后处理：重采样 + 音量归一化

## 日期
2026-03-04 19:30

## 问题描述

### 问题 1：TTS 文件仍为 24kHz
Phase 7.47.91 将 C++ 端和 QML 端默认采样率改为 48000，并通过 `command["sample_rate"]=48000` 传给 Python 服务端。
但设备上生成的 WAV 文件仍然是 24000 Hz。

### 问题 2：TTS 合成音量过小
用户反馈 TTS 播放音量小，即使设备系统音量已调到最大。

## 根因分析

### 问题 1 根因：PaddleSpeech 模型固定输出 24kHz

```
C++ (sampleRate=48000) → JSON command["sample_rate"]=48000
→ Python (fs=48000) → PaddleSpeech tts_executor(fs=48000)
→ 输出仍为 24kHz ❌
```

**根本原因**：`fastspeech2_csmsc` 声学模型 + `hifigan_csmsc` 声码器都在 24kHz 训练。
PaddleSpeech 的 `fs` 参数对这些模型**无效** — 模型内部固定在 24kHz 生成音频波形。

### 问题 2 根因：音量公式只能降低，不能放大

旧代码：
```python
volume_db = 20 * (volume - 1)  # volume=0.8 → -4dB, volume=1.0 → 0dB
audio = audio + volume_db
```

- volume=0.8 → 降低 4dB（约 63% 振幅）
- volume=1.0 → 不变（跳过处理）
- **无法放大**：公式上限是 0dB（原始音量）

TTS 模型原始输出的峰值本身就低（远低于满量程），再降 4dB 更小。

## 修复方案

### 在 Python 端合成后增加后处理

修改 `paddle_tts_service.py` 的 `synthesize_speech()` 函数：

#### 1. 重采样（24kHz → 48kHz）
```python
import soundfile as sf
from scipy.signal import resample_poly
from math import gcd

data, actual_sr = sf.read(output_path)
if actual_sr != sample_rate:
    g = gcd(sample_rate, actual_sr)
    up = sample_rate // g    # 48000/24000 → 2
    down = actual_sr // g    # 24000/24000 → 1
    data = resample_poly(data, up, down)  # 整数倍 2x 上采样
```

使用 `scipy.signal.resample_poly`：
- 24kHz → 48kHz 是整数倍（up=2, down=1），效率最高
- 比 `scipy.signal.resample`（FFT 方法）更适合整数倍转换
- 自动应用抗混叠滤波

#### 2. 音量归一化 + 缩放
```python
import numpy as np

peak = np.max(np.abs(data))
if peak > 0:
    target_peak = 0.891  # -1dB 峰值
    normalized = data * (target_peak / peak)
    data = normalized * volume
```

- 先将峰值归一化到 -1dB（0.891），充分利用动态范围
- 再乘以用户音量系数（volume=0.8 → 最终峰值约 -3dB）
- -1dB 余量避免 DAC 削波

### 效果对比

| 项目 | 旧方案 | 新方案 |
|------|--------|--------|
| 采样率 | 24kHz（模型固定） | 48kHz（后处理重采样） |
| 音量处理 | 只能降低（-4dB） | 归一化后缩放（大幅提升） |
| volume=0.8 效果 | 原始峰值 × 0.63 | 满量程 × 0.71（-3dB） |
| 依赖 | pydub（ffmpeg 告警） | numpy + scipy + soundfile |

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py | 合成后添加重采样+音量归一化后处理 |

## 修复后全链路（零重采样播放）
```
PaddleSpeech (24kHz原始) → Python后处理 (重采样→48kHz + 归一化) → WAV文件 (48kHz)
→ GStreamer → alsasink → plug (48kHz, 无需转换) → dmix (48kHz) → hw:1,0 (48kHz) ✅
```
