# Phase 7.47.75 - 回退 QSoundEffect & 修复 asound.conf 采样率

**日期**: 2026-03-03
**提交**: `（本次提交）`
**问题**: Phase 7.47.73 部署后语音完全不播放
**修改文件**:
- `src/control/CommonControl.h`
- `src/control/CommonControl.cpp`
- `docker/rk3588/asound.conf`

---

## 一、问题现象（voip.md 日志分析）

Phase 7.47.73 部署后，触发保护语音时日志显示：

```
[QSoundEffect] 播放结束，时长: "0.00" 秒    ← 0秒立刻"结束"
onPlaybackFinished()                         ← 立刻触发
   [QSoundEffect] status: Loading | ...     ← 文件还在加载中！
...
No audio device detected                    ← QSoundEffect 找不到音频设备
   [QSoundEffect] status: Ready | ...       ← 文件已就绪，但播放已"结束"
```

两个叠加问题导致语音完全静默：

| 问题 | 原因 |
|------|------|
| **No audio device detected** | QSoundEffect 通过 QAudioSink 需要 Qt 枚举音频设备，Docker 容器无 PulseAudio → 枚举为空 → 找不到设备（与当初放弃直接枚举改用 QMediaPlayer+GStreamer 的原因完全一致） |
| **播放结束 0.00 秒误触发** | `play()` 调用时文件仍在 Loading 状态，`isPlaying()` 为 false → `playingChanged` 立刻触发 → lambda 条件 `!isPlaying() && m_usingSoundEffect` 满足 → 立刻调用 `onPlaybackFinished()` |

Error 状态的回退机制（statusChanged → QMediaPlayer）也未能生效：文件状态从 Loading 变为 Ready（而非 Error），因此 statusChanged 判断 `status == Error` 的分支永远不触发。

---

## 二、根因总结

QSoundEffect 在 Docker 容器中与 QMediaPlayer 的直接设备枚举失败具有相同的根因：

```
容器内无 PulseAudio 服务
    ↓
Qt Multimedia 枚举音频设备返回空列表
    ↓
QSoundEffect（QAudioSink）：No audio device detected → 静默失败
QMediaPlayer（GStreamer alsasink）：绕过 Qt 枚举 → 正常工作
```

Phase 7.47.73 中"枚举失败 ≠ 播放失败"的判断只适用于 QMediaPlayer+GStreamer，不适用于 QSoundEffect。

---

## 三、修复方案

### 3.1 回退 QSoundEffect → QMediaPlayer（恢复语音播放）

**CommonControl.h**：注释掉 `#include <QSoundEffect>` 和两个成员变量

**CommonControl.cpp**：
- 注释掉构造函数中 `m_soundEffect` 和 `m_usingSoundEffect` 初始化
- 注释掉 QSoundEffect 的 `setVolume()` + 两个 `connect()` 信号连接
- 移除 `playbackStateChanged(Stopped)` 中的 `!m_usingSoundEffect` 守卫
- `LocalOnly` 分支：注释掉 QSoundEffect 调用，恢复 `m_mediaPlayer->play()`
- `NetworkTcp` 未连接分支：注释掉 QSoundEffect 调用，恢复 `m_mediaPlayer->play()`

### 3.2 修改 asound.conf rate 24kHz（缓解 GStreamer 重采样卡顿）

**docker/rk3588/asound.conf**：

```bash
# ❌ 旧值（GStreamer 需实时重采样 24kHz → 48kHz，CPU 开销 → Buffer Underrun → 卡顿）
# rate 48000

# ✅ 新值（与 TTS WAV 采样率一致，GStreamer 无需重采样）
rate 24000
```

**原理**：
```
WAV 24kHz
  → GStreamer audioresample: ❌ 24kHz→48kHz（旧）/ ✅ 无重采样（新）
  → alsasink → dmix（24kHz）
  → ALSA plug 层：块式转换 24kHz → hw:0,0 支持的采样率
  → hw:0,0（HDMI audio）
```

ALSA plug 层的转换是**块式处理**（非 GStreamer 流式 pipeline），不受 CPU 调度抖动影响，不会产生 Buffer Underrun。

**buffer_time 400ms 保持不变**（Phase 7.47.73 已改，作为安全底网）。

---

## 四、执行路径对比

| | 旧路径（Phase 7.47.72 及以前） | Phase 7.47.73（失败）| Phase 7.47.75（本次）|
|--|------|------|------|
| **播放器** | QMediaPlayer | QSoundEffect（失败→静默）| QMediaPlayer |
| **采样率** | 48kHz（重采样） | — | 24kHz（无重采样）|
| **卡顿风险** | 有（Buffer Underrun）| 无声 | 消除主因 |

---

## 五、待验证

编译部署后：

1. **语音恢复**：触发保护语音，日志确认出现 `[状态变化] Playing`（而非 `[QSoundEffect] 播放结束`），聆听是否有声音
2. **卡顿改善**：播放"沿线急停.wav"，确认汉字之间卡顿是否消失（旧日志中的 `StalledMedia`/`BufferingMedia` 不再出现）
3. **采样率兼容**：若硬件不支持 24kHz 导致静音，可将 rate 改回 48000（卡顿恢复但有声）

---

## 六、文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.h` | 注释掉 `#include <QSoundEffect>` 和 `QSoundEffect *m_soundEffect`、`bool m_usingSoundEffect` 声明 |
| `src/control/CommonControl.cpp` | 注释掉 QSoundEffect 全部初始化和信号连接；恢复 LocalOnly/NetworkTcp-fallback 的 `m_mediaPlayer->play()`；移除 `!m_usingSoundEffect` 守卫 |
| `docker/rk3588/asound.conf` | `rate 48000` → `rate 24000`（消除 GStreamer 重采样，彻底修复卡顿主因）|
