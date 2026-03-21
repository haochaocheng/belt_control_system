# Phase 7.48.70 - 部署测试6项问题修复（第二批）

## 日期：2026-03-21

## 问题清单与修复

### 问题1：只有第一次按R键播放启车预警，第二次和第三次没有声音
**根因**：`onPlaybackFinished()` 有三个分支（stop音频、warning预警、普通）。stop和warning分支播放完成后不重置 `m_isPlayingFromQueue`，导致后续 `playAudio()` 只入队不启动播放。
**日志证据**：第2次按R键看到"音频加入队列"但无"从队列播放"。
**修复**：
1. `m_isStopAudioPlaying` 分支：添加 `m_isPlayingFromQueue = false; m_audioQueue.clear();`
2. `m_isWarningPlaying` ByTime分支：每轮播放前重置 `m_isPlayingFromQueue = false`
3. `m_isWarningPlaying` ByCount分支：继续播放前重置 `m_isPlayingFromQueue = false`
4. ByTime定时器停止分支：重置并清空队列

### 问题2：停车顺序功能展示没有按照启动顺序的方式执行
**根因**：`onDeviceStatusChanged()` 收到 `isRunning=false` 时直接 return，不做任何可视化处理。
**修复**：
1. C++端：新增 `stopSequenceStarted()` 信号，在 `stopDeviceSequence()` 执行前 emit
2. QML端：新增 `onStopSequenceStarted` 处理器，切换到停止Tab并进入 rtPhase=4（停止序列模式）
3. `onDeviceStatusChanged()` 中 `isRunning=false` 时，若 rtPhase===4 则跟踪停用设备进度
4. 进度条和发光边框扩展支持 rtPhase===4

### 问题3：启动顺序启动后在停止时，设备方框还是浅蓝/绿色填充
**根因**：rtStopTimer 只停止刷新定时器但不重置状态，设备卡片颜色绑定仍保持绿色。
**修复**：rtStopTimer 在 rtPhase===4（停止序列）完成后完全重置：isRealtimeActive=false, rtPhase=0, rtActivatedCount=0, 并切回启动Tab。

### 问题4：张紧控制进度条上没有延时时间标签
**根因**：前缀进度条2（启车预警→第一个设备之间）缺少延时标签 UI 组件。
**修复**：在前缀进度条2中添加延时标签 Rectangle+Text，显示第一个设备的延时 `currentDelays[0]`，颜色根据延时长短变化。

### 问题5：启动延时和停止延时共用
**根因**：`loadFromConfig()` 中 `stopDelays` 也调用 `readDeviceStartupDelay()`，与 `startupDelays` 读取同一个DB字段。制动器启动用松闸延时、停止用抱闸延时，应该分开。
**修复**：
1. QML：新增 `readDeviceStopDelay()` 函数，制动器读 `brake_startup_delay`（抱闸），其余设备与启动相同
2. `loadFromConfig()` 中 stopDelays 改用 `readDeviceStopDelay()`
3. C++端 `executeNextDeviceInSequence()`：停止序列时制动器读 `brake_startup_delay` 而非 `release_startup_delay`

### 问题6：启动延时语义修正（"前等待"）
**根因**：`executeNextDeviceInSequence()` 用 `delayIndex = m_currentSequenceIndex - 1`（上一个设备的延时），但用户理解的"1号制动器启动延时"是指上一设备完成后到制动器启动的等待时间（前等待），不是制动器启动后到下一设备的等待时间（后等待）。
**修复**：
1. C++：`delayIndex` 改为 `m_currentSequenceIndex`（即将激活的设备）
2. QML arrowItem：延时标签、颜色、进度计算、编辑弹窗全部从 `currentDelays[index]` 改为 `currentDelays[index + 1]`
3. `getArrowProgress()` 函数同步修正

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `src/control/CommonControl.cpp` | 问题1: 3个分支重置m_isPlayingFromQueue；问题5: 制动器停止读brake_startup_delay；问题6: delayIndex改为前等待；问题2: emit stopSequenceStarted |
| `src/control/CommonControl.h` | 问题2: 新增 stopSequenceStarted() 信号 |
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | 问题2: 停止序列可视化(onStopSequenceStarted+onDeviceStatusChanged处理isRunning=false)；问题3: rtStopTimer重置状态；问题4: 前缀进度条延时标签；问题5: readDeviceStopDelay；问题6: 延时标签/进度改为index+1 |

## 新增 rtPhase 状态说明
- 0 = 空闲
- 1 = 预警中
- 2 = 启动序列运行中
- 3 = 故障
- 4 = 停止序列运行中（新增）
