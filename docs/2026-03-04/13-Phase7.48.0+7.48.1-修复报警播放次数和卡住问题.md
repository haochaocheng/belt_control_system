# Phase 7.48.0 + 7.48.1 - 修复报警播放次数和卡住问题

## 时间
2026-03-04 15:03 (北京时间)

## 问题描述

### 问题1：设置播放3次，实际只播放2次
- 触发"沿线急停"保护，设置播放3次
- 实际只听到2次完整播放

### 问题2：播放一次后卡住，后续报警不再播放
- Phase 7.48.0 修复后的新问题
- 触发急停保护，只播放1次就不再播放
- 再触发急停或跑偏保护也不报警
- 日志显示后续报警全部进入队列但永不播放

## 根本原因分析

### Bug 1（Phase 7.48.0 修复）：`handleNextPlayback()` 缺少 `} else if`

代码结构错误，count 模式和 duration 模式的代码混在同一个 if 块中：

```cpp
// 错误结构
if (playMode == "count") {
    currentPlayCount++;  // 第一次 +1
    playAudioFile();
    // ↓ 缺少 } else if，直接跌落到 duration 模式
    // ========== 按时长播放模式 ==========
    currentPlayCount++;  // 第二次 +1（同一次调用中）
    playAudioFile();     // 第二次播放（覆盖第一次）
} else {
    // 未知模式
}
```

**后果**：每次 `handleNextPlayback()` 调用，`currentPlayCount` 递增2次。
- 播放序列：0→2（第1次调用）→ 4（第2次调用）→ 5>3 停止
- 实际只有2次完整播放

### Bug 2（Phase 7.48.1 修复）：`EndOfMedia` 检查过于严格

Phase 7.48.0 在 `onMediaPlayerStateChanged` 中添加了 `mediaStatus == EndOfMedia` 检查：

```cpp
// Phase 7.48.0 代码（过于严格）
if (state == StoppedState) {
    if (m_isPlaying && mediaStatus() == EndOfMedia) {  // ← 问题！
        m_playTimer->start(500);
    }
}
```

**RK3588 GStreamer 后端特性**：音频自然播放结束时，`mediaStatus` 是 `BufferedMedia` 而非 `EndOfMedia`。

日志证据：
```
[DEBUG] 📻 媒体播放器状态变化: StoppedState mediaStatus: BufferedMedia
[DEBUG]   ℹ️  忽略非自然结束的StoppedState (mediaStatus: BufferedMedia)
```

**后果**：
- 自然播放结束也被忽略 → 定时器永不启动
- `m_isPlaying` 一直为 true → 后续报警全部进入队列
- 3次急停 + 1次跑偏都进入队列但永不播放

## 修复方案

### Phase 7.48.0：添加 `} else if` 分支

```cpp
if (m_currentPlayback.playMode == "count") {
    // count 模式逻辑
    currentPlayCount++;
    playAudioFile();
} else if (m_currentPlayback.playMode == "duration") {  // ← 修复！
    // duration 模式逻辑
    currentPlayCount++;
    playAudioFile();
} else {
    // 未知模式
}
```

### Phase 7.48.1：用 `m_hasStartedPlaying` 标志替代 `EndOfMedia` 检查

```cpp
// playAudioFile() 中：
m_hasStartedPlaying = false;  // 新播放前重置

// onMediaPlayerStateChanged() 中：
if (state == PlayingState) {
    m_hasStartedPlaying = true;  // 标记已进入播放
}
if (state == StoppedState) {
    if (m_isPlaying && m_hasStartedPlaying) {
        // 已经经历过 PlayingState → 是自然播放结束
        m_hasStartedPlaying = false;
        m_playTimer->start(500);
    }
    // setSource() 虚假的 StoppedState 在 PlayingState 之前，
    // 此时 m_hasStartedPlaying 为 false，被正确过滤
}
```

**工作原理**：
- `setSource()` 虚假 StoppedState → 发生在 PlayingState 之前 → `m_hasStartedPlaying=false` → 忽略
- 自然播放结束 StoppedState → 发生在 PlayingState 之后 → `m_hasStartedPlaying=true` → 启动定时器
- 不依赖 `mediaStatus` 值 → 跨平台兼容（Qt/GStreamer/PipeWire/PulseAudio）

## 修改文件
1. `src/control/AlarmPlaybackService.cpp` - handleNextPlayback() 结构修复 + onMediaPlayerStateChanged() 逻辑修复
2. `src/control/AlarmPlaybackService.h` - 添加 `m_hasStartedPlaying` 成员变量

## 预期效果
- 播放次数=3 时，准确播放3次完整音频
- 每次播放结束后正确触发下一次播放
- 队列中的后续报警能正常播放
- 不同保护类型（急停、跑偏等）都能正常报警
