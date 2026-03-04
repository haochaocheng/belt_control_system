# Phase 7.48.2 - 最后触发优先逻辑

## 时间
2026-03-04 16:30 (北京时间)

## 需求描述

用户要求更改报警播放逻辑：
- 每一个保护触发，都是从最后一个触发开始从0计次数
- 不用理会已经播放了几次
- 3次之内再次触发同一保护，计数从0开始
- 之前保护触发如果在播放次数之内没有播放完成，被新的触发代替
- 旧的触发报警保护不再播放，次数清零

## 旧逻辑（队列累积模式）

```cpp
// onAlarmTriggered() 中：
if (!m_isPlaying) {
    m_currentPlayback = info;
    handleNextPlayback();
} else {
    // 加入队列
    m_playbackQueue.append(info);
}
```

**行为**：
- 触发A → 播放A（3次）
- 播放A第1次时再触发B → B加入队列
- A播完3次 → 从队列取出B → 播放B（3次）
- 3次触发A = 最多9次播放（3×3）

## 新逻辑（最后触发优先）

```cpp
// onAlarmTriggered() 中：
if (m_isPlaying) {
    stopCurrentPlayback();     // 立即停止当前播放
    m_playbackQueue.clear();   // 清空队列
}
m_currentPlayback = info;      // 设置新触发
handleNextPlayback();          // 从count=0开始播放
```

**行为**：
- 触发A → 播放A（从第1次开始）
- 播放A第1次时再触发B → 立即停止A → 播放B（从第1次开始）
- 播放B第2次时再触发A → 立即停止B → 播放A（从第1次开始）
- 无论触发多少次，同时只有一个保护在播放，始终从第1次开始

## 修改文件
1. `src/control/AlarmPlaybackService.cpp` - `onAlarmTriggered()` 替换队列逻辑为"最后触发优先"

## 预期效果
- 新保护触发时，旧的播放立即停止
- 播放队列始终为空（不累积）
- 每次触发都从第1次开始计数
- 快速连续触发时，只播放最后一个触发的保护
