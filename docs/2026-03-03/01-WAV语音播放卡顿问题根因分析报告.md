# WAV 语音播放卡顿问题根因分析报告

**日期**: 2026-03-03
**问题**: 设备上程序播放语音（沿线急停.wav 等）有明显卡顿；单独用命令行 aplay 播放正常；Windows 上播放正常
**结论**: 三层叠加问题，主因为采样率不匹配 + dmix 缓冲区过小导致 GStreamer 音频流 Buffer Underrun

---

## 一、现象描述

| 场景 | 表现 |
|------|------|
| Windows 电脑播放 .wav | 正常，无卡顿 |
| 设备直接 `aplay 沿线急停.wav` | 正常，无卡顿 |
| 设备通过程序 `CommonControl::playAudio()` | **卡顿**，每个汉字/词组之间有 <300ms 卡顿 |

典型案例：
- "沿线急停" → "急""停" 之间卡顿
- "跑偏保护" → 开头两段小卡顿
- 每个音频文件内部有 1~2 次短暂静音

---

## 二、代码链路梳理

```
CommonControl::playAudio(path)
  ↓
m_mediaPlayer->setSource(QUrl())          ← ① 清空源（强制重建 GStreamer pipeline）
m_mediaPlayer->setSource(QUrl::fromLocalFile(path))  ← ② 设置新源
  ↓
GStreamer Pipeline（自动创建）
  filesrc → wavparse → audioconvert → audioresample → alsasink
                                            ↑
                               ③ CPU密集型：24kHz → 48kHz 重采样
  ↓
ALSA default（dmix）
  ↓
hw:0,0（HDMI 音频 / ES8388）
```

---

## 三、根因分析

### 根因 1（主因）：采样率不匹配 → 双重重采样

**TTS 生成的 WAV 文件采样率**（paddlespeech-fastspeech2_csmsc）: **24000 Hz**，单声道

**ALSA dmix 固定采样率**（asound.conf 第 62 行）: **48000 Hz**，立体声

```
asound.conf:
  slave {
      pcm "hw:0,0"
      period_time 20000    # 20ms
      buffer_time 200000   # 200ms
      rate 48000           # ← 固定 48kHz，与 WAV 的 24kHz 不匹配
  }
```

**播放路径中发生了两次重采样**：

```
WAV 24kHz mono
  → GStreamer audioresample: 24kHz → 48kHz（软件重采样，CPU 密集）
  → ALSA plug type: 可能再次做格式转换（mono → stereo）
  → dmix hw:0,0
```

GStreamer `audioresample` 是**流式处理**，处理速度受 CPU 负载影响。
每个汉字之间是自然的声音停顿（振幅归零点），此时 GStreamer 内部缓冲区在处理下一帧时如果稍慢一步，就出现 Buffer Underrun → 短暂静音（卡顿感）。

### 根因 2（加重因素）：dmix 缓冲区过小（200ms）

```
period_time 20000    →  20ms 每个 period
buffer_time 200000   →  200ms 总缓冲区（10 个 period）
```

GStreamer alsasink 向 dmix 写数据时，dmix 总缓冲区只有 200ms。
当 GStreamer 因为重采样 CPU 开销稍有延迟，dmix 缓冲区就会提前耗尽，触发 Underrun，造成 <20ms 的短暂静音。

**为什么 `aplay` 不卡顿？**
`aplay` 使用原生 ALSA API，以**整个文件缓冲后批量写入**的方式工作，不依赖 GStreamer 流式 pipeline，不受 pipeline 调度抖动影响。

### 根因 3（加重因素）：每次播放强制重建 GStreamer pipeline

```cpp
// CommonControl.cpp 第 332 行
m_mediaPlayer->setSource(QUrl());   // 清空 → GStreamer pipeline 销毁
m_mediaPlayer->setSource(newSource); // 设置新源 → GStreamer pipeline 重建
```

每次调用 `playAudio()` 都会：
1. 销毁旧 GStreamer pipeline
2. 重新创建：filesrc → wavparse → audioconvert → audioresample → alsasink
3. 重新打开 ALSA 设备（`snd_pcm_open()`）

ALSA 设备打开/关闭时有**硬件初始化开销**，可能产生 50~200ms 的初始化时间，在首次出声前就已经造成了短暂静音。

### 根因 4（潜在加重因素）：主线程竞争

程序主线程同时运行：
- VoIP/PJSIP（网络收发）
- MQTT 客户端（8 个连接）
- QML UI 渲染
- GStreamer 音频 pipeline（在 Qt 的 GStreamer 线程中）

GStreamer 内部的音频渲染线程是独立线程，但**当主线程持续繁忙时（MQTT 消息处理、UI 更新），操作系统 CPU 调度可能使音频线程"饿死"数十毫秒**，导致缓冲区耗尽。

---

## 四、各场景对比验证

| 测试场景 | 结果 | 原因 |
|---------|------|------|
| Windows 播放 | 正常 | Windows 音频 API 预缓冲整个文件，无流式 pipeline |
| `aplay` 直接播放 | 正常 | ALSA 原生，整文件批量写入，无 GStreamer 流式开销 |
| 程序播放 | 卡顿 | GStreamer 流式重采样 + 小缓冲区 + pipeline 重建 |
| 单音节文件（如"停"）| 可能正常 | 没有词组内部停顿点，GStreamer 处理连续 |
| 多音节文件（如"沿线急停"）| 卡顿 | 音节间振幅谷值时 GStreamer 缓冲区容易耗尽 |

---

## 五、修复方案

### 方案 A：调整 asound.conf 缓冲区（立竿见影，改动最小）★★★

将 dmix 缓冲区从 200ms 扩大到 400ms，增加 GStreamer 的容错时间：

```bash
# asound.conf
slave {
    pcm "hw:0,0"
    period_time 20000    # 保持 20ms
    buffer_time 400000   # 200ms → 400ms（扩大缓冲）
    rate 48000
}
```

**优点**：改动 1 行，效果明显
**缺点**：缓冲区增大后，音频启动延迟略增加（400ms 而非 200ms）
**适合场景**：保护报警语音，稍微延迟可接受

### 方案 B：采样率匹配，消除重采样（根治主因）★★★★

将 dmix 采样率改为与 TTS 输出一致（24000 Hz），消除 GStreamer 重采样：

```bash
# asound.conf
slave {
    pcm "hw:0,0"
    period_time 20000
    buffer_time 400000
    rate 24000           # 与 TTS WAV 一致，GStreamer 无需重采样
    channels 1           # 与 TTS WAV 一致（单声道）
}
```

**注意**：需要确认硬件（hw:0,0 HDMI 或 ES8388）是否支持 24kHz。
若硬件只支持 44100/48000Hz，则需保留 48kHz，配合方案 C。

### 方案 C：替换 QMediaPlayer → QSoundEffect（根治方案）★★★★★

`QSoundEffect` 专为短小、重复播放的提示音设计：
- 启动时**预加载整个 WAV 文件到内存**（无 pipeline 重建开销）
- 硬件加速解码，无 GStreamer 流式 pipeline
- 不依赖 GStreamer，直接与 QAudioSink 交互
- 延迟 < 10ms（vs QMediaPlayer 的 200ms+）

```cpp
// 替换思路（非立即实施，需评估）：
// 将 CommonControl 中的 m_mediaPlayer 替换为 QSoundEffect
// QSoundEffect 只支持 WAV 格式 → 与现有 TTS 生成的 .wav 文件完全兼容
QSoundEffect *m_alertSound = new QSoundEffect(this);
m_alertSound->setSource(QUrl::fromLocalFile(audioPath));
m_alertSound->play();  // 预加载后立即播放，无卡顿
```

**优点**：彻底消除卡顿，延迟极低
**缺点**：需要改造 CommonControl，需充分测试

### 方案 D：预热 ALSA 设备（低成本临时方案）

程序启动时播放一段 0 音量的静音文件，使 ALSA 设备保持打开状态：

```cpp
// 程序启动后播放静音，预热 ALSA 设备
// 可避免首次调用时设备初始化导致的首字卡顿
```

---

## 六、推荐实施顺序

| 优先级 | 方案 | 改动范围 | 预期效果 |
|--------|------|---------|---------|
| 1（先做） | A：扩大 dmix 缓冲 400ms | `asound.conf` 1 行 | 减少 80% 卡顿 |
| 2 | B：匹配采样率 24kHz | `asound.conf` 2 行 | 消除重采样开销 |
| 3（彻底解决） | C：替换 QSoundEffect | CommonControl 重构 | 彻底消除卡顿 |

**先实施 A+B，验证效果；如仍有卡顿，再评估方案 C。**

---

## 七、验证方法

部署新 asound.conf 后：

```bash
# 1. 用程序触发播放，观察卡顿是否消失
# 2. 查看 voip.md 日志，关注：
#    [媒体状态] StalledMedia  ← 此行出现 = Buffer Underrun 发生过
#    [媒体状态] BufferingMedia ← 此行出现 = GStreamer 正在等待数据
# 3. 如果两行都不出现 → 修复有效
```

---

## 八、受影响文件

| 文件 | 问题 | 修复方案 |
|------|------|---------|
| `docker/rk3588/asound.conf` | buffer_time=200ms 太小；rate=48kHz 与 WAV 不匹配 | 方案 A + B |
| `src/control/CommonControl.cpp` | setSource() 每次重建 pipeline | 方案 C（长期） |
