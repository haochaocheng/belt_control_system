# Phase 7.47.90 - 恢复音频直接播放，修复设备完全无声

## 日期
2026-03-04 17:00

## 问题描述
3月3日代码修改后，设备所有音频播放完全无声：
- 开关量模块一离线.wav — 无声音
- 模拟量模块一离线.wav — 无声音
- 沿线急停保护音频 — 无声音（之前正常播放）
- voip.md 日志显示 QMediaPlayer 报告 Playing 状态持续 3.95 秒，但 ALSA 无音频输出

## 根因分析

### 根因一：延迟播放机制（m_pendingPlay）导致 GStreamer 管道状态异常

Phase 7.47.89 将所有 `m_mediaPlayer->play()` 调用替换为 `m_pendingPlay = true`，
然后在 `mediaStatusChanged(LoadedMedia)` 信号处理器内部调用 `m_mediaPlayer->play()`。

**问题本质：** 从 `mediaStatusChanged` 回调内部调用 `play()`，GStreamer 管道正处于
状态转换回调中（LoadingMedia → LoadedMedia 的转换通知），此时发出 play() 请求
导致管道内部状态与 ALSA 音频输出不同步：
- GStreamer 状态机报告 Playing（3.95 秒）
- 但 ALSA 音频输出未收到数据
- 设备扬声器完全无声

### 根因二：移除 setSource(QUrl()) 导致管道残留

Phase 7.47.87 移除了 `m_mediaPlayer->setSource(QUrl())` 清空源操作。
这导致 GStreamer 管道在文件切换时未完全重置，可能与延迟播放机制叠加
产生更严重的状态异常。

### 附加问题：detect-audio-device.sh 未同步更新

3月3日修改了静态 `asound.conf`（rate 48kHz → 24kHz，buffer 200ms → 400ms），
但动态检测脚本 `detect-audio-device.sh` 仍使用旧值（rate 48kHz, buffer 200ms）。
由于 Docker 容器使用动态脚本生成 ALSA 配置，静态文件的优化从未生效。

## 修复方案

### 1. 恢复直接 play() 调用（移除 m_pendingPlay 机制）
- LocalOnly、DualOutput、NetworkTcp（TCP未连接回退）三个分支全部恢复 `m_mediaPlayer->play()`
- 移除 `m_pendingPlay` 成员变量
- 移除 mediaStatusChanged 中的 LoadedMedia 触发逻辑

### 2. 恢复 setSource(QUrl()) 清空源
- 在设置新源前先清空，确保 GStreamer 管道完全重建
- 代价：增加约 111ms 加载延迟，但保证音频正确输出

### 3. 同步更新 detect-audio-device.sh
- rate: 48000 → 24000（与 TTS WAV 采样率一致）
- buffer_time: 200000 → 400000（增大缓冲区容错）

### 4. 保留的改进
- 音频播放队列（m_audioQueue）保留，多模块离线不再互相打断
- <200ms 虚假完成事件过滤保留

## 修改文件
| 文件 | 修改内容 |
|------|---------|
| src/control/CommonControl.cpp | 移除 m_pendingPlay 延迟播放，恢复直接 play()；恢复 setSource(QUrl()) 清空源 |
| src/control/CommonControl.h | 注释掉 m_pendingPlay 成员变量 |
| docker/rk3588/detect-audio-device.sh | rate 48000→24000，buffer_time 200000→400000 |

## 技术教训
1. **不要从 Qt 信号回调内部调用关键 API**：GStreamer 管道状态转换通知期间调用 play()
   可能导致管道状态不一致，表面上报告 Playing 但实际无音频输出
2. **移除 setSource(QUrl()) 需要谨慎**：GStreamer 管道需要明确的重置操作确保状态干净
3. **动态配置脚本与静态配置文件必须同步更新**：detect-audio-device.sh 的 ALSA 配置
   是实际生效的配置，静态 asound.conf 仅作参考
